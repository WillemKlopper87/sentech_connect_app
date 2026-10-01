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
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';
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

    group('the legal consent step (terms + privacy)', () {
      AuthState signedInWith(LegalStatus legal) => AuthState(status: AuthStatus.success, user: _user, legal: legal);

      test('every state but accepted keeps a signed-in customer on /consent', () {
        for (final legal in [LegalStatus.unchecked, LegalStatus.required, LegalStatus.unavailable]) {
          final state = signedInWith(legal);
          expect(authRedirect(state, Uri.parse('/main')), AppRoutes.consent, reason: '$legal');
          expect(authRedirect(state, Uri.parse(AppRoutes.consent)), isNull, reason: '$legal');
          expect(authRedirect(state, Uri.parse(AppRoutes.login)), AppRoutes.consent, reason: '$legal');
        }
      });

      test('splash and the tenant screens keep their own flow', () {
        final state = signedInWith(LegalStatus.required);
        for (final path in [AppRoutes.splash, AppRoutes.tenantPicker, AppRoutes.updateRequired]) {
          expect(authRedirect(state, Uri.parse(path)), isNull, reason: path);
        }
      });

      test('once accepted, /consent leads on to the app (or the requested route)', () {
        final state = signedInWith(LegalStatus.accepted);
        expect(authRedirect(state, Uri.parse(AppRoutes.consent)), AppRoutes.main);
        expect(authRedirect(state, Uri.parse('${AppRoutes.consent}?from=%2Fcart')), '/cart');
      });

      test('the profile step comes before the consent step', () {
        const nameless = AuthState(
          status: AuthStatus.success,
          user: User(id: 'c1', fullName: '', mobileNumber: '+27821234567'),
          legal: LegalStatus.required,
        );
        expect(authRedirect(nameless, Uri.parse(AppRoutes.consent)), AppRoutes.register);
        expect(authRedirect(nameless, Uri.parse(AppRoutes.register)), isNull);
      });

      test('a customer with a name but no consent is never let into /register either', () {
        expect(authRedirect(signedInWith(LegalStatus.required), Uri.parse(AppRoutes.register)), AppRoutes.consent);
      });

      test('the deep link survives the consent and profile steps as from', () {
        final consent = authRedirect(signedInWith(LegalStatus.unchecked), Uri.parse('/cart'))!;
        expect(Uri.parse(consent).path, AppRoutes.consent);
        expect(Uri.parse(consent).queryParameters['from'], '/cart');

        const nameless = AuthState(status: AuthStatus.success, user: User(id: 'c1', fullName: '', mobileNumber: '+27821234567'));
        final register = authRedirect(nameless, Uri.parse('/login?from=%2Fpayment%2Ford_1'))!;
        expect(Uri.parse(register).path, AppRoutes.register);
        expect(Uri.parse(register).queryParameters['from'], '/payment/ord_1');
        // and after the profile is complete it leads there
        expect(authRedirect(_signedIn, Uri.parse(register)), '/payment/ord_1');
      });

      test('a gate route is never accepted as a "from"', () {
        expect(safeFrom('/consent'), isNull);
        expect(safeFrom('/register'), isNull);
      });
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

    Future<void> pumpRouter(WidgetTester tester, {required AuthState initial, required String at, bool gated = false}) async {
      auth = AuthCubit(
        locator(),
        sessionStore: locator(),
        biometrics: MockBiometricAuthenticator(),
        wiper: locator(),
        initial: initial,
        consents: gated ? locator<ConsentRepository>() : null,
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
      // The hotspot-only dashboard no longer shows a long-running spinner, so
      // let the mock shell repositories (catalog, support) finish their delays.
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('signed-out deep link to /cart lands on login, then returns to /cart after sign-in', (tester) async {
      await pumpRouter(tester, initial: const AuthState(), at: '/cart', gated: true);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Your cart'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0810000000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump(const Duration(seconds: 1));
      // A returning customer meets the consent step (terms + privacy) before anything else.
      await tester.pumpAndSettle();
      await tester.tap(find.text('I agree')); // the consent step
      await tester.pumpAndSettle();

      expect(find.text('Your cart'), findsOneWidget);
    });

    testWidgets('a restored session without current consent meets the consent step first, then reaches the deep link', (tester) async {
      await pumpRouter(tester, initial: _signedIn, at: '/cart', gated: true);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Your cart'), findsNothing);

      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(find.text('Your cart'), findsOneWidget);
    });

    testWidgets('a restored session that already agreed is not asked again', (tester) async {
      await locator<ConsentRepository>().grant(ConsentPurpose.terms);
      await locator<ConsentRepository>().grant(ConsentPurpose.privacy);
      await pumpRouter(tester, initial: _signedIn, at: '/cart', gated: true);
      expect(find.text('Terms of Service'), findsNothing);
      expect(find.text('Your cart'), findsOneWidget);
    });

    testWidgets('the consent step can be left by signing out', (tester) async {
      await pumpRouter(tester, initial: _signedIn, at: '/main', gated: true);
      expect(find.text('Terms of Service'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(auth.state.isSignedIn, isFalse);
      expect(find.text('Welcome back'), findsOneWidget);
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
      // No TenantCubit in this router: the cpe flag defaults to OFF, so no router card.
      expect(find.text('Living room router'), findsNothing);
      expect(find.text('Buy a pass'), findsWidgets);
      expect(appRouter.router.state.uri.path, '/main');
    });
  });
}
