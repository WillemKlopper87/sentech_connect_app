import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/privacy/privacy_constants.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/account/presentation/pages/account_page.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/mock_privacy_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/bloc/privacy_actions_cubit.dart';
import 'package:sentech_connect_app/features/privacy/presentation/widgets/consent_gate.dart';
import 'helpers/test_setup.dart';

class _GrantCountingConsent extends LocalConsentRepository {
  _GrantCountingConsent(super.store);

  int grants = 0;

  @override
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose) {
    grants++;
    return super.grant(purpose);
  }
}

void main() {
  group('LocalConsentRepository', () {
    late InMemorySecureStore store;

    setUp(() => store = InMemorySecureStore());

    test('records the purpose, the policy version and a UTC timestamp', () async {
      final at = DateTime.utc(2026, 9, 30, 8, 15);
      final repo = LocalConsentRepository(store, now: () => at);

      final record = (await repo.grant(ConsentPurpose.ricaCapture)).getOrElse((_) => throw StateError('x'));

      expect(record.purpose, ConsentPurpose.ricaCapture);
      expect(record.policyVersion, privacyPolicyVersion);
      expect(record.grantedAt, at);
      expect(record.grantedAt.isUtc, isTrue);
      expect((await repo.currentConsent(ConsentPurpose.ricaCapture)).getOrElse((_) => null), record);
      // Purposes are independent.
      expect((await repo.currentConsent(ConsentPurpose.locationCapture)).getOrElse((_) => record), isNull);
    });

    test('consent given to an older policy version no longer counts', () async {
      await LocalConsentRepository(store, policyVersion: 'v1').grant(ConsentPurpose.locationCapture);
      final v2 = LocalConsentRepository(store, policyVersion: 'v2');
      expect((await v2.currentConsent(ConsentPurpose.locationCapture)).getOrElse((_) => throw StateError('x')), isNull);
    });

    test('unsynced records can be collected and marked as synced for the backend hand-off', () async {
      final repo = LocalConsentRepository(store);
      await repo.grant(ConsentPurpose.locationCapture);
      final pending = await repo.unsyncedRecords();
      expect(pending, hasLength(1));

      await repo.markSynced(pending);
      expect(await repo.unsyncedRecords(), isEmpty);
      expect((await repo.currentConsent(ConsentPurpose.locationCapture)).getOrElse((_) => null)?.synced, isTrue);
    });

    test('clear removes every record', () async {
      final repo = LocalConsentRepository(store);
      await repo.grant(ConsentPurpose.locationCapture);
      await repo.clear();
      expect(store.snapshot, isEmpty);
    });
  });

  group('ensureConsent', () {
    late InMemorySecureStore store;
    late LocalConsentRepository repo;
    bool? result;

    setUp(() {
      store = InMemorySecureStore();
      repo = LocalConsentRepository(store);
      result = null;
    });

    Future<void> pumpGate(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async =>
                    result = await ensureConsent(context, ConsentPurpose.locationCapture, repository: repo),
                child: const Text('capture'),
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('asks first, and only proceeds (and stores a record) when the customer agrees', (tester) async {
      await pumpGate(tester);
      await tester.tap(find.text('capture'));
      await tester.pumpAndSettle();
      expect(find.text('Your privacy'), findsOneWidget);
      // The notice is truthful: nothing kept on the phone, and the address
      // lookup goes through the phone's own map service.
      expect(find.textContaining('not stored on your phone'), findsOneWidget);
      expect(find.textContaining("phone's map service (Google or Apple)"), findsOneWidget);
      expect(store.snapshot, isEmpty); // nothing recorded before agreeing

      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect((await repo.currentConsent(ConsentPurpose.locationCapture)).getOrElse((_) => null), isNotNull);
    });

    testWidgets('declining blocks the capture and records nothing', (tester) async {
      await pumpGate(tester);
      await tester.tap(find.text('capture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(store.snapshot, isEmpty);
    });

    testWidgets('a double tap shows ONE dialog and records ONE consent', (tester) async {
      final counting = _GrantCountingConsent(store);
      var results = <bool>[];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                // Two taps in the same frame (before any dialog can block the second).
                onPressed: () async => results = await Future.wait([
                  ensureConsent(context, ConsentPurpose.locationCapture, repository: counting),
                  ensureConsent(context, ConsentPurpose.locationCapture, repository: counting),
                ]),
                child: const Text('capture'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('capture'));
      await tester.pumpAndSettle();
      expect(find.text('Your privacy'), findsOneWidget);
      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(counting.grants, 1);
      expect(results, [true, true], reason: 'both callers get the answer');
    });

    testWidgets('an existing valid consent skips the dialog', (tester) async {
      await repo.grant(ConsentPurpose.locationCapture);
      await pumpGate(tester);
      await tester.tap(find.text('capture'));
      await tester.pumpAndSettle();
      expect(find.text('Your privacy'), findsNothing);
      expect(result, isTrue);
    });
  });

  group('PrivacyActionsCubit', () {
    test('account deletion wipes local data only AFTER the server accepts it', () async {
      final network = SimulatedNetwork()..offline = true;
      var wiped = 0;
      final cubit = PrivacyActionsCubit(MockPrivacyRepository(network), onAccountDeleted: () async => wiped++);
      addTearDown(cubit.close);

      await cubit.deleteAccount();
      expect(cubit.state.status, PrivacyActionStatus.failed);
      expect(wiped, 0);

      network.offline = false;
      await cubit.deleteAccount();
      expect(cubit.state.status, PrivacyActionStatus.deleted);
      expect(wiped, 1);
    });

    test('data export is a request, not a wipe', () async {
      var wiped = 0;
      final cubit = PrivacyActionsCubit(MockPrivacyRepository(), onAccountDeleted: () async => wiped++);
      addTearDown(cubit.close);
      await cubit.requestDataExport();
      expect(cubit.state.status, PrivacyActionStatus.exportRequested);
      expect(wiped, 0);
    });
  });

  group('Account page', () {
    setUpAppTests();

    late AuthCubit auth;
    late InMemorySecureStore secureStore;

    Future<void> pumpAccount(WidgetTester tester) async {
      await locator<SessionStore>().saveUser(const User(id: 'usr_001', fullName: 'Lindiwe Khumalo', mobileNumber: '081'), tenantSlug: 'sentech');
      await locator<SessionStore>().saveBiometricCredential('usr_001');
      secureStore = locator<SecureStore>() as InMemorySecureStore;
      auth = AuthCubit(
        locator(),
        sessionStore: locator(),
        biometrics: MockBiometricAuthenticator(),
        wiper: locator<PersonalDataWiper>(),
        initial: const AuthState(
          status: AuthStatus.success,
          user: User(id: 'usr_001', fullName: 'Lindiwe Khumalo', mobileNumber: '081'),
        ),
      );
      addTearDown(auth.close);
      await tester.pumpWidget(MultiBlocProvider(
        providers: [
          BlocProvider.value(value: auth),
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider(create: (_) => LocaleCubit()),
        ],
        child: const MaterialApp(home: AccountPage()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('"Delete my account & data" confirms, then signs out and leaves nothing stored', (tester) async {
      await pumpAccount(tester);
      expect(secureStore.snapshot, isNotEmpty);

      await tester.scrollUntilVisible(find.text('Delete my account & data'), 200);
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account & data'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);

      // Cancel leaves everything in place.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.state.isSignedIn, isTrue);

      await tester.tap(find.text('Delete my account & data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete everything'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(auth.state.isSignedIn, isFalse);
      expect(auth.state.biometricsReady, isFalse);
      expect(secureStore.snapshot, isEmpty);
    });

    testWidgets('"Download my data" files a request and confirms it', (tester) async {
      await pumpAccount(tester);
      await tester.scrollUntilVisible(find.text('Download my data'), 200);
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download my data'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Request received'), findsOneWidget);
      expect(auth.state.isSignedIn, isTrue);
    });
  });
}
