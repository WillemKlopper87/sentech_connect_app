import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'helpers/test_setup.dart';

const _user = User(id: 'usr_001', fullName: 'Lindiwe', mobileNumber: '081');
const _signedIn = AuthState(status: AuthStatus.success, user: _user);

void main() {
  group('authRedirect', () {
    const signedOut = AuthState();
    const protectedPaths = [
      '/main',
      '/cart',
      '/checkout',
      '/rica/ord_1',
      '/payment/ord_1',
      '/confirmation/ord_1',
      '/promotions',
      '/wifi-hotspots',
      '/coverage',
    ];

    for (final path in protectedPaths) {
      test('signed-out user is sent to /login from $path, remembering the destination', () {
        final redirect = authRedirect(signedOut, Uri.parse(path));
        if (path == '/main') {
          expect(redirect, '/login'); // default landing needs no "from"
        } else {
          expect(Uri.parse(redirect!).path, '/login');
          expect(Uri.parse(redirect).queryParameters['from'], path);
          expect(safeFrom(Uri.parse(redirect).queryParameters['from']), path);
        }
      });

      test('signed-in user may open $path', () {
        expect(authRedirect(_signedIn, Uri.parse(path)), isNull);
      });
    }

    test('public routes stay reachable when signed out', () {
      for (final path in ['/', '/login', '/register']) {
        expect(authRedirect(signedOut, Uri.parse(path)), isNull);
      }
    });

    test('a restored session on /login goes to /main', () {
      expect(authRedirect(_signedIn, Uri.parse('/login')), '/main');
      expect(authRedirect(_signedIn, Uri.parse('/register')), '/main');
    });

    test('a fresh sign-in on /login goes through coverage once, or to the requested route', () {
      const fresh = AuthState(status: AuthStatus.success, user: _user, freshSignIn: true);
      expect(authRedirect(fresh, Uri.parse('/login')), '/coverage');
      expect(authRedirect(fresh, Uri.parse('/login?from=%2Fcart')), '/cart');
    });

    test('unsafe "from" values are ignored', () {
      for (final bad in ['//evil.example', 'https://evil.example', '/login', 'cart', '']) {
        expect(safeFrom(bad), isNull, reason: bad);
      }
      expect(authRedirect(_signedIn, Uri.parse('/login?from=%2F%2Fevil.example')), '/main');
    });
  });

  group('router', () {
    setUpAppTests();

    late AuthCubit auth;
    late AppRouter appRouter;

    Future<void> pumpRouter(WidgetTester tester, {required AuthState initial, required String at}) async {
      auth = AuthCubit(
        locator(),
        sessionStore: locator(),
        biometrics: MockBiometricAuthenticator(),
        wiper: locator(),
        initial: initial,
      );
      appRouter = AppRouter(auth, initialLocation: at);
      addTearDown(() async {
        appRouter.dispose();
        await auth.close();
      });
      await tester.pumpWidget(MultiBlocProvider(
        providers: [
          BlocProvider.value(value: auth),
          BlocProvider(create: (_) => CartCubit()),
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(create: (_) => LocaleCubit()),
        ],
        child: MaterialApp.router(routerConfig: appRouter.router),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('signed-out deep link to /cart lands on login, then returns to /cart after sign-in', (tester) async {
      await pumpRouter(tester, initial: const AuthState(), at: '/cart');
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Your cart'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0810000000');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pw');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Your cart'), findsOneWidget);
    });

    testWidgets('unknown order ids fail gracefully instead of throwing on a missing extra', (tester) async {
      await pumpRouter(tester, initial: _signedIn, at: '/confirmation/does-not-exist');
      expect(tester.takeException(), isNull);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('direct navigation to /rica/:id works without any extra object', (tester) async {
      await pumpRouter(tester, initial: _signedIn, at: '/rica/whatever');
      expect(tester.takeException(), isNull);
      expect(find.text('Verify your identity'), findsOneWidget);
    });

    testWidgets('logging out from a protected screen redirects to /login', (tester) async {
      await pumpRouter(tester, initial: _signedIn, at: '/cart');
      expect(find.text('Your cart'), findsOneWidget);

      await auth.logOut();
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(appRouter.router.state.uri.path, '/login');
    });

    testWidgets('a signed-in user opening /login is sent to /main', (tester) async {
      await pumpRouter(tester, initial: _signedIn, at: '/login');
      expect(appRouter.router.state.uri.path, '/main');
    });
  });
}
