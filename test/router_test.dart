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
      for (final path in ['/', '/login']) {
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

    test('a new customer without a name must complete the profile first', () {
      const fresh = AuthState(status: AuthStatus.success, user: User(id: 'c1', fullName: '', mobileNumber: '+27821234567'), freshSignIn: true);
      expect(authRedirect(fresh, Uri.parse('/main')), AppRoutes.register);
      expect(authRedirect(fresh, Uri.parse(AppRoutes.register)), isNull);
    });

    test('a nameless customer is not pulled off splash or the tenant screens', () {
      const fresh = AuthState(status: AuthStatus.success, user: User(id: 'c1', fullName: ' ', mobileNumber: '+27821234567'));
      for (final path in [AppRoutes.splash, AppRoutes.tenantPicker, AppRoutes.updateRequired]) {
        expect(authRedirect(fresh, Uri.parse(path)), isNull, reason: path);
      }
      expect(authRedirect(fresh, Uri.parse(AppRoutes.login)), AppRoutes.register);
    });

    test('a customer with a name never lands on /register', () {
      expect(authRedirect(_signedIn, Uri.parse(AppRoutes.register)), AppRoutes.main);
    });

    test('/register is protected', () {
      expect(authRedirect(const AuthState(), Uri.parse(AppRoutes.register)), startsWith(AppRoutes.login));
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
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump(const Duration(seconds: 1));
      // A returning customer must accept the (current) terms before the session is ready.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('I agree'));
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
