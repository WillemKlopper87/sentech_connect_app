import 'package:flutter/services.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'helpers/first_run_tenant.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/pages/legal_gate_page.dart';

import 'helpers/test_setup.dart';

const _user = User(
  id: 'usr_001',
  fullName: 'Lindiwe Khumalo',
  mobileNumber: '+27810000000',
);

class _FlakyConsents extends LocalConsentRepository {
  _FlakyConsents(super.store);

  bool offline = false;

  @override
  Future<Either<Failure, ConsentRecord?>> currentConsent(
    ConsentPurpose purpose,
  ) async =>
      offline ? const Left(NetworkFailure()) : super.currentConsent(purpose);

  @override
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose) async =>
      offline ? const Left(NetworkFailure()) : super.grant(purpose);
}

void main() {
  setUpAppTests();

  late _FlakyConsents consents;
  late AuthCubit auth;

  setUp(() {
    consents = _FlakyConsents(InMemorySecureStore());
    auth = AuthCubit(
      locator(),
      sessionStore: locator(),
      biometrics: MockBiometricAuthenticator(),
      wiper: locator(),
      initial: const AuthState(status: AuthStatus.success, user: _user),
      consents: consents,
    );
  });

  tearDown(() => auth.close());

  Future<void> pumpGate(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const LegalGatePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('English fallback legal text is disclosed for isiZulu', (
    tester,
  ) async {
    await pumpGate(tester, locale: const Locale('zu'));
    expect(find.byKey(const Key('legal-language-note')), findsOneWidget);
    expect(find.text('This text is only in English for now.'), findsOneWidget);
    expect(
      find.text('Terms link is unavailable. Please try again later.'),
      findsOneWidget,
    );
  });
  testWidgets('English legal text needs no fallback note', (tester) async {
    await pumpGate(tester);
    expect(find.byKey(const Key('legal-language-note')), findsNothing);
  });

  testWidgets(
    'configured Terms and privacy links use their public destinations',
    (tester) async {
      final tenant = await firstRunTenant(
        cpe: false,
        branding: TenantBranding.fromJson({
          'legal_urls': {
            'terms': 'https://legal.example.test/terms',
            'privacy': 'https://legal.example.test/privacy',
          },
        }),
      );
      addTearDown(tenant.close);
      final opened = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            opened.add((call.arguments as Map)['url'] as String);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: auth),
            BlocProvider.value(value: tenant),
          ],
          child: const MaterialApp(home: LegalGatePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Terms link is unavailable. Please try again later.'),
        findsNothing,
      );
      await tester.tap(find.text('Read the Terms'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read our privacy policy'));
      await tester.pumpAndSettle();
      expect(opened, [
        'https://legal.example.test/terms',
        'https://legal.example.test/privacy',
      ]);
      expect(
        auth.state.legal,
        LegalStatus.required,
        reason: 'reading never grants consent',
      );
    },
  );

  testWidgets('legal notice and buttons react to early language choice', (
    tester,
  ) async {
    final locale = LocaleCubit(save: (_) async {});
    addTearDown(locale.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: auth),
          BlocProvider.value(value: locale),
        ],
        child: BlocBuilder<LocaleCubit, Locale?>(
          builder: (context, selected) => MaterialApp(
            locale: selected,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LegalGatePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('isiZulu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal-language-note')), findsOneWidget);
    expect(
      find.text(lookupAppLocalizations(const Locale('zu')).consentAgree),
      findsOneWidget,
    );
    expect(auth.state.legal, LegalStatus.required);
  });

  testWidgets(
    'without current consent it asks; I agree records terms and privacy',
    (tester) async {
      await pumpGate(tester);
      expect(
        find.textContaining('accept the Terms of Service'),
        findsOneWidget,
      );
      expect(auth.state.legal, LegalStatus.required);

      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(auth.state.legal, LegalStatus.accepted);
      for (final purpose in [ConsentPurpose.terms, ConsentPurpose.privacy]) {
        expect(
          (await consents.currentConsent(purpose)).getOrElse((_) => null),
          isNotNull,
          reason: '$purpose',
        );
      }
    },
  );

  testWidgets(
    'a failed check is shown as a failure with Retry, not as a request to accept',
    (tester) async {
      consents.offline = true;
      await pumpGate(tester);
      expect(auth.state.legal, LegalStatus.unavailable);
      expect(
        find.textContaining('could not check the Terms of Service'),
        findsOneWidget,
      );
      expect(find.text('I agree'), findsNothing);

      consents.offline = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('I agree'), findsOneWidget);
    },
  );

  testWidgets(
    'someone who already agreed is not asked, even after a failed attempt',
    (tester) async {
      await consents.grant(ConsentPurpose.terms);
      await consents.grant(ConsentPurpose.privacy);
      consents.offline = true;
      await pumpGate(tester);
      expect(find.text('I agree'), findsNothing);

      consents.offline = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(auth.state.legal, LegalStatus.accepted);
    },
  );

  testWidgets(
    'a recording that fails offers Retry and keeps the customer signed in',
    (tester) async {
      await pumpGate(tester);
      consents.offline = true;
      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(auth.state.legal, LegalStatus.unavailable);
      expect(auth.state.isSignedIn, isTrue);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('Sign out leaves the session', (tester) async {
    await pumpGate(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.state.isSignedIn, isFalse);
  });
}
