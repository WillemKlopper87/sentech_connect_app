import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/http_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/http_privacy_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/bloc/privacy_actions_cubit.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _details = RegistrationDetails(
  fullName: ' Thandi Mokoena ',
  email: 'thandi@example.test',
  mobileNumber: '+27821234567',
  address: '12 Main Road, Soweto',
);

void main() {
  late ApiHarness h;

  setUp(() async {
    h = ApiHarness();
    h.tenantContext
      ..termsVersion = '2026-09-30'
      ..privacyVersion = '2026-09-30';
    await h.signIn();
  });

  group('HttpRegistrationRepository', () {
    test('sends the name and email to the profile; the address stays on the device', () async {
      final localStore = InMemorySecureStore();
      final repo = HttpRegistrationRepository(h.api, local: LocalRegistrationRepository(localStore));
      h.adapter.on('PATCH', '/v1/me/profile', (_) => FakeReply(200, fixture('profile_complete.json')));

      expect((await repo.save(_details)).isRight(), isTrue);
      final sent = h.adapter.requestsTo('PATCH', '/v1/me/profile').single;
      expect(sent.data, {'display_name': 'Thandi Mokoena', 'email': 'thandi@example.test'});
      expect(sent.data.toString(), isNot(contains('Soweto')));
      expect((await repo.getSaved()).getOrElse((_) => null)?.address, '12 Main Road, Soweto');
    });

    test('a rejected profile is not saved locally either', () async {
      final localStore = InMemorySecureStore();
      final repo = HttpRegistrationRepository(h.api, local: LocalRegistrationRepository(localStore));
      h.adapter.on('PATCH', '/v1/me/profile', (_) => FakeReply.problem(422, 'validation_error', detail: 'Check your email address.'));
      final failure = (await repo.save(_details)).match((f) => f, (_) => null);
      expect(failure, isA<ValidationFailure>());
      expect(localStore.snapshot, isEmpty);
    });
  });

  group('HttpConsentRepository', () {
    late InMemorySecureStore localStore;
    late HttpConsentRepository repo;

    setUp(() {
      localStore = InMemorySecureStore();
      repo = HttpConsentRepository(
        h.api,
        local: LocalConsentRepository(localStore),
        tenant: h.tenantContext,
        newKey: () => 'app-consent-key-1',
      );
    });

    test('server purposes count only for the CURRENT legal version', () async {
      h.adapter.on('GET', '/v1/me/consents', (_) => FakeReply(200, fixture('consents.json')));
      final terms = (await repo.currentConsent(ConsentPurpose.terms)).getOrElse((f) => throw StateError(f.message));
      final privacy = (await repo.currentConsent(ConsentPurpose.privacy)).getOrElse((f) => throw StateError(f.message));
      expect(terms?.policyVersion, '2026-09-30');
      expect(terms?.synced, isTrue);
      expect(privacy, isNull); // agreed to 2026-08-01, current is 2026-09-30
    });

    test('granting posts purpose, current version and source with an Idempotency-Key', () async {
      h.adapter.on('POST', '/v1/me/consents', (_) => FakeReply(201, fixture('consent_out.json')));
      final record = (await repo.grant(ConsentPurpose.privacy)).getOrElse((f) => throw StateError(f.message));
      final sent = h.adapter.requestsTo('POST', '/v1/me/consents').single;
      expect(sent.data, {'purpose': 'privacy', 'version': '2026-09-30', 'granted': true, 'source': 'app'});
      expect(sent.headers['Idempotency-Key'], 'app-consent-key-1');
      expect(record.grantedAt, DateTime.utc(2026, 10, 1, 10, 2));
    });

    test('device-only consents (location, RICA) never touch the network', () async {
      await repo.grant(ConsentPurpose.locationCapture);
      expect((await repo.currentConsent(ConsentPurpose.locationCapture)).getOrElse((_) => null), isNotNull);
      expect(h.adapter.requests, isEmpty);
    });

    test('without loaded legal versions nothing is recorded', () async {
      h.tenantContext.termsVersion = null;
      final failure = (await repo.grant(ConsentPurpose.terms)).match((f) => f, (_) => null);
      expect((failure! as ValidationFailure).code, 'legal_versions_missing');
      expect(h.adapter.requests, isEmpty);
    });
  });

  group('HttpPrivacyRepository', () {
    test('account deletion is DELETE /v1/me and returns a receipt', () async {
      final repo = HttpPrivacyRepository(h.api, now: () => h.now);
      h.adapter.on('DELETE', '/v1/me', (_) => const FakeReply(204));
      final receipt = (await repo.requestAccountDeletion()).getOrElse((f) => throw StateError(f.message));
      expect(receipt.reference, startsWith('DEL-'));
      expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('the export comes back in-app as pretty JSON', () async {
      final repo = HttpPrivacyRepository(h.api);
      h.adapter.on('GET', '/v1/me/export', (_) => FakeReply(200, fixture('export.json')));
      final receipt = (await repo.requestDataExport()).getOrElse((f) => throw StateError(f.message));
      expect(receipt.reference, 'EXP-${DateTime.utc(2026, 10, 1, 12).millisecondsSinceEpoch}');
      expect(receipt.exportJson, contains('"phone_e164": "+27821234567"'));
    });

    test('local data is wiped only after the server accepted the deletion', () async {
      var wiped = 0;
      var failNext = true;
      h.adapter.on('DELETE', '/v1/me', (_) {
        if (failNext) {
          failNext = false;
          return const FakeReply.error(DioExceptionType.connectionTimeout);
        }
        return const FakeReply(204);
      });
      final cubit = PrivacyActionsCubit(HttpPrivacyRepository(h.api), onAccountDeleted: () async => wiped++);
      addTearDown(cubit.close);

      await cubit.deleteAccount();
      expect(cubit.state.status, PrivacyActionStatus.failed);
      expect(wiped, 0);

      await cubit.deleteAccount();
      expect(cubit.state.status, PrivacyActionStatus.deleted);
      expect(wiped, 1);
    });
  });
}
