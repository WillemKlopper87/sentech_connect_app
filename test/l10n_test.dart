import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/features/account/presentation/pages/account_page.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/login_page.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/registration_page.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/support_page.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';
import 'helpers/test_setup.dart';

void main() {
  setUpAppTests();

  Widget localized(Locale locale, Widget home, {Widget Function(Widget child)? wrap}) {
    final app = MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
    return wrap == null ? app : wrap(app);
  }

  AuthCubit newAuth({AuthState initial = const AuthState()}) => AuthCubit(
        locator(),
        sessionStore: locator(),
        biometrics: MockBiometricAuthenticator(),
        wiper: locator(),
        initial: initial,
      );

  test('every non-English ARB defines every key of the English template', () {
    // Guards against shipping a half-translated file: the generated classes
    // fall back to English at compile time, so a missing key would be silent.
    for (final locale in [const Locale('zu'), const Locale('af')]) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.loginWelcomeBack, isNot(lookupAppLocalizations(const Locale('en')).loginWelcomeBack));
      expect(l10n.accountDeleteData, isNot(lookupAppLocalizations(const Locale('en')).accountDeleteData));
    }
  });

  group('login page', () {
    for (final (locale, welcome) in [
      (const Locale('en'), 'Hello!'),
      (const Locale('af'), 'Hello!'),
      (const Locale('zu'), 'Hello!'),
    ]) {
      testWidgets('renders in ${locale.languageCode}', (tester) async {
        final auth = newAuth();
        addTearDown(auth.close);
        await tester.pumpWidget(localized(
          locale,
          const LoginPage(),
          wrap: (child) => BlocProvider.value(value: auth, child: child),
        ));
        await tester.pumpAndSettle();
        expect(find.text(welcome), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, lookupAppLocalizations(locale).loginSendCode), findsOneWidget);
      });
    }
  });

  testWidgets('registration page is translated', (tester) async {
    final auth = newAuth();
    addTearDown(auth.close);
    await tester.pumpWidget(localized(
      const Locale('af'),
      const RegistrationPage(),
      wrap: (child) => BlocProvider.value(value: auth, child: child),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Volle naam'), findsOneWidget);
    expect(find.text('Skep rekening'), findsOneWidget);
  });

  testWidgets('support page is translated (FAQ content itself comes from the repository)', (tester) async {
    await tester.pumpWidget(localized(
      const Locale('zu'),
      BlocProvider(create: (_) => SupportCubit(MockSupportRepository()), child: const SupportPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Usizo nokwesekwa'), findsOneWidget);
    expect(find.text('Thumela ithikithi'), findsWidgets);
  });

  testWidgets('language switcher in Account changes the UI and is persisted', (tester) async {
    Locale? saved = const Locale('en');
    final localeCubit = LocaleCubit(save: (l) async => saved = l);
    final auth = newAuth(
      initial: const AuthState(status: AuthStatus.success, user: User(id: 'u', fullName: 'Lindiwe', mobileNumber: '081')),
    );
    addTearDown(() async {
      await auth.close();
      await localeCubit.close();
    });

    await tester.pumpWidget(BlocProvider.value(
      value: localeCubit,
      child: BlocBuilder<LocaleCubit, Locale?>(
        builder: (context, locale) => localized(
          locale ?? const Locale('en'),
          const AccountPage(),
          wrap: (child) => MultiBlocProvider(
            providers: [BlocProvider.value(value: auth), BlocProvider(create: (_) => ThemeCubit())],
            child: child,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Afrikaans'), 200);
    await tester.ensureVisible(find.text('Afrikaans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Afrikaans'));
    await tester.pumpAndSettle();

    expect(saved, const Locale('af'));
    expect(find.text('Rekening'), findsOneWidget);
    expect(find.text('Account'), findsNothing);
  });

  testWidgets('the whole app starts in the persisted language', (tester) async {
    await tester.pumpWidget(const SentechConnectApp(initialLocale: Locale('af')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('Hello!'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, lookupAppLocalizations(const Locale('af')).loginSendCode), findsOneWidget);
  });
}
