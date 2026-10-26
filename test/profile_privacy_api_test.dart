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

const _challengeId = '9d1c5e2a-7b3f-4c8d-a6e1-0f2b4c6d8e1a';

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
    test('sends the name and email to the profile; the address is neither sent nor kept on the device', () async {
      final localStore = InMemorySecureStore();
      final repo = HttpRegistrationRepository(h.api, local: LocalRegistrationRepository(localStore));
      h.adapter.on('PATCH', '/v1/me/profile', (_) => FakeReply(200, fixture('profile_complete.json')));

      expect((await repo.save(_details)).isRight(), isTrue);
      final sent = h.adapter.requestsTo('PATCH', '/v1/me/profile').single;
      expect(sent.data, {'display_name': 'Thandi Mokoena', 'email': 'thandi@example.test'});
      expect(sent.data.toString(), isNot(contains('Soweto')));
      expect((await repo.getSaved()).getOrElse((_) => null)?.address, isEmpty);
      expect(localStore.snapshot.values.join(), isNot(contains('Soweto')));
    });

    test('an empty email is left out of the profile update (it would clear the stored one)', () async {
      final repo = HttpRegistrationRepository(h.api, local: LocalRegistrationRepository(InMemorySecureStore()));
      h.adapter.on('PATCH', '/v1/me/profile', (_) => FakeReply(200, fixture('profile_complete.json')));
      const noEmail = RegistrationDetails(fullName: 'Thandi Mokoena', email: '  ', mobileNumber: '+27821234567', address: '12 Main Road');
      expect((await repo.save(noEmail)).isRight(), isTrue);
      expect(h.adapter.requestsTo('PATCH', '/v1/me/profile').single.data, {'display_name': 'Thandi Mokoena'});
    });

    test('a sign-out during the PATCH leaves nothing on the device (stale scope)', () async {
      final localStore = InMemorySecureStore();
      final repo = HttpRegistrationRepository(h.api, local: LocalRegistrationRepository(localStore));
      h.adapter.on('PATCH', '/v1/me/profile', (_) async {
        await h.tokens.clear(); // logout while the request is in flight
        return FakeReply(200, fixture('profile_complete.json'));
      });
      final failure = (await repo.save(_details)).match((f) => f, (_) => null);
      expect(failure, isA<UnauthorizedFailure>());
      expect(localStore.snapshot, isEmpty);
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

    Map<String, Object?> entry(String purpose, String version, {bool granted = true, String at = '2026-10-01T10:01:00Z'}) =>
        {'purpose': purpose, 'version': version, 'granted': granted, 'recorded_at': at};

    void ledger(List<Map<String, Object?>> items) =>
        h.adapter.on('GET', '/v1/me/consents', (_) => FakeReply(200, {'items': items}));

    void accepting() => h.adapter.on('POST', '/v1/me/consents', (options) {
          final body = options.data as Map;
          return FakeReply(201, {
            'purpose': body['purpose'],
            'version': body['version'],
            'granted': body['granted'],
            'recorded_at': '2026-10-01T10:02:00Z',
          });
        });

    setUp(() {
      localStore = InMemorySecureStore();
      repo = HttpConsentRepository(h.api, local: LocalConsentRepository(localStore), tenant: h.tenantContext);
    });

    test('server purposes count only for the CURRENT legal version', () async {
      h.adapter.on('GET', '/v1/me/consents', (_) => FakeReply(200, fixture('consents.json')));
      final terms = (await repo.currentConsent(ConsentPurpose.terms)).getOrElse((f) => throw StateError(f.message));
      final privacy = (await repo.currentConsent(ConsentPurpose.privacy)).getOrElse((f) => throw StateError(f.message));
      expect(terms?.policyVersion, '2026-09-30');
      expect(terms?.synced, isTrue);
      expect(privacy, isNull); // agreed to 2026-08-01, current is 2026-09-30
    });

    test('a sign-out between the ledger read and the write sends no consent', () async {
      h.adapter.on('GET', '/v1/me/consents', (_) async {
        await h.tokens.clear();
        return FakeReply(200, {'items': <Object?>[]});
      });
      accepting();
      final result = await repo.grant(ConsentPurpose.terms);
      expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
      expect(h.adapter.requestsTo('POST', '/v1/me/consents'), isEmpty);
    });

    test('legal versions not loaded yet: currentConsent is a retryable failure, never "not accepted"', () async {
      h.tenantContext
        ..termsVersion = null
        ..privacyVersion = null;
      final result = await repo.currentConsent(ConsentPurpose.terms);
      expect(result.isLeft(), isTrue);
      expect(result.match((f) => f, (_) => null), isNot(isA<ValidationFailure>()));
      expect(h.adapter.requestsTo('GET', '/v1/me/consents'), isEmpty);
    });

    test('granting posts purpose, current version and source with a STABLE Idempotency-Key', () async {
      h.adapter.on('GET', '/v1/me/consents', (_) => FakeReply(200, fixture('consents.json')));
      h.adapter.on('POST', '/v1/me/consents', (_) => FakeReply(201, fixture('consent_out.json')));
      final record = (await repo.grant(ConsentPurpose.privacy)).getOrElse((f) => throw StateError(f.message));
      final sent = h.adapter.requestsTo('POST', '/v1/me/consents').single;
      expect(sent.data, {'purpose': 'privacy', 'version': '2026-09-30', 'granted': true, 'source': 'app'});
      expect(sent.headers['Idempotency-Key'], 'app-consent-sentech-privacy-2026-09-30');
      expect(record.grantedAt, DateTime.utc(2026, 10, 1, 10, 2));
    });

    test('terms are recorded against the TERMS version, privacy against the privacy version', () async {
      h.tenantContext
        ..termsVersion = '2026-09-30'
        ..privacyVersion = '2026-10-01';
      ledger([]);
      accepting();
      await repo.grant(ConsentPurpose.terms);
      await repo.grant(ConsentPurpose.privacy);
      final sent = h.adapter.requestsTo('POST', '/v1/me/consents');
      expect(sent[0].data, containsPair('purpose', 'terms'));
      expect(sent[0].data, containsPair('version', '2026-09-30'));
      expect(sent[1].data, containsPair('purpose', 'privacy'));
      expect(sent[1].data, containsPair('version', '2026-10-01'));
    });

    test('SMS marketing is recorded as marketing_sms against the tenant privacy version', () async {
      h.tenantContext.privacyVersion = '2026-10-01';
      ledger([]);
      accepting();
      await repo.grant(ConsentPurpose.marketingSms);
      final sent = h.adapter.requestsTo('POST', '/v1/me/consents').single;
      expect(sent.data, {'purpose': 'marketing_sms', 'version': '2026-10-01', 'granted': true, 'source': 'app'});
      expect(sent.headers['Idempotency-Key'], 'app-consent-sentech-marketing_sms-2026-10-01');
    });

    test('a double tap shares ONE operation: one read, one write', () async {
      ledger([]);
      accepting();
      final results = await Future.wait([repo.grant(ConsentPurpose.terms), repo.grant(ConsentPurpose.terms)]);
      expect(results.every((r) => r.isRight()), isTrue);
      expect(h.adapter.requestsTo('POST', '/v1/me/consents'), hasLength(1));
      expect(h.adapter.requestsTo('GET', '/v1/me/consents'), hasLength(1));
    });

    test('a retry after a lost response reuses the same key (the server replays, no second ledger row)', () async {
      ledger([]);
      var lost = true;
      h.adapter.on('POST', '/v1/me/consents', (_) {
        if (lost) {
          lost = false;
          return const FakeReply.error(DioExceptionType.receiveTimeout);
        }
        return FakeReply(201, fixture('consent_out.json'));
      });
      expect((await repo.grant(ConsentPurpose.privacy)).isLeft(), isTrue);
      expect((await repo.grant(ConsentPurpose.privacy)).isRight(), isTrue);
      final keys = h.adapter.requestsTo('POST', '/v1/me/consents').map((r) => r.headers['Idempotency-Key']).toSet();
      expect(keys, {'app-consent-sentech-privacy-2026-09-30'});
    });

    test('a purpose already granted for the current version is not written again', () async {
      ledger([entry('terms', '2026-09-30')]);
      final record = (await repo.grant(ConsentPurpose.terms)).getOrElse((f) => throw StateError(f.message));
      expect(record.grantedAt, DateTime.utc(2026, 10, 1, 10, 1));
      expect(h.adapter.requestsTo('POST', '/v1/me/consents'), isEmpty);
    });

    test('a new legal version is a new operation with its own key', () async {
      ledger([entry('terms', '2026-08-01')]);
      accepting();
      await repo.grant(ConsentPurpose.terms);
      expect(h.adapter.requestsTo('POST', '/v1/me/consents').single.headers['Idempotency-Key'], 'app-consent-sentech-terms-2026-09-30');
    });

    test('withdrawing posts granted:false, keyed to the grant it ends', () async {
      ledger([entry('marketing_sms', '2026-09-30', at: '2026-10-01T10:01:00Z')]);
      accepting();
      expect((await repo.withdraw(ConsentPurpose.marketingSms)).isRight(), isTrue);
      final sent = h.adapter.requestsTo('POST', '/v1/me/consents').single;
      expect(sent.data, {'purpose': 'marketing_sms', 'version': '2026-09-30', 'granted': false, 'source': 'app'});
      expect(
        sent.headers['Idempotency-Key'],
        'app-consent-sentech-marketing_sms-2026-09-30-withdraw-${DateTime.utc(2026, 10, 1, 10, 1).millisecondsSinceEpoch}',
      );
    });

    test('withdrawing something that is not granted writes nothing', () async {
      ledger([entry('marketing_sms', '2026-09-30', granted: false)]);
      expect((await repo.withdraw(ConsentPurpose.marketingSms)).isRight(), isTrue);
      ledger([]);
      expect((await repo.withdraw(ConsentPurpose.marketingSms)).isRight(), isTrue);
      expect(h.adapter.requestsTo('POST', '/v1/me/consents'), isEmpty);
    });

    test('a withdrawn purpose no longer counts as consent', () async {
      ledger([entry('marketing_sms', '2026-09-30', granted: false)]);
      expect((await repo.currentConsent(ConsentPurpose.marketingSms)).getOrElse((_) => throw StateError('x')), isNull);
    });

    test('granting again after a withdrawal is a NEW operation (its key names the withdrawal), not a replay', () async {
      ledger([entry('marketing_sms', '2026-09-30', granted: false, at: '2026-10-02T08:00:00Z')]);
      accepting();
      await repo.grant(ConsentPurpose.marketingSms);
      expect(
        h.adapter.requestsTo('POST', '/v1/me/consents').single.headers['Idempotency-Key'],
        'app-consent-sentech-marketing_sms-2026-09-30-after-${DateTime.utc(2026, 10, 2, 8).millisecondsSinceEpoch}',
      );
    });

    test('every key fits the server pattern, even for the longest tenant slug and purpose', () async {
      h.tenantContext.slug = 'a' * 40;
      await h.signIn(); // tokens belong to the active tenant
      ledger([entry('marketing_sms', '2026-09-30', granted: false)]);
      accepting();
      await repo.grant(ConsentPurpose.marketingSms);
      ledger([entry('marketing_sms', '2026-09-30')]);
      await repo.withdraw(ConsentPurpose.marketingSms);
      final posts = h.adapter.requestsTo('POST', '/v1/me/consents');
      expect(posts, hasLength(2));
      for (final request in posts) {
        expect(request.headers['Idempotency-Key'], matches(RegExp(r'^[A-Za-z0-9_.:-]{8,128}$')));
      }
    });

    test('a ledger that cannot be read blocks the write (nothing is guessed)', () async {
      h.adapter.on('GET', '/v1/me/consents', (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect((await repo.grant(ConsentPurpose.terms)).isLeft(), isTrue);
      expect((await repo.withdraw(ConsentPurpose.terms)).isLeft(), isTrue);
      expect(h.adapter.requestsTo('POST', '/v1/me/consents'), isEmpty);
    });

    test('an outdated version is refused by the server and surfaces as a ValidationFailure', () async {
      ledger([]);
      h.adapter.on('POST', '/v1/me/consents', (_) => FakeReply.problem(422, 'consent_version_outdated', title: 'Outdated'));
      final failure = (await repo.grant(ConsentPurpose.terms)).match((f) => f, (_) => null);
      expect((failure! as ValidationFailure).code, 'consent_version_outdated');
    });

    test('device-only consents (location, RICA) never touch the network', () async {
      await repo.grant(ConsentPurpose.locationCapture);
      expect((await repo.currentConsent(ConsentPurpose.locationCapture)).getOrElse((_) => null), isNotNull);
      expect((await repo.withdraw(ConsentPurpose.locationCapture)).isRight(), isTrue);
      expect((await repo.currentConsent(ConsentPurpose.locationCapture)).getOrElse((_) => throw StateError('x')), isNull);
      expect(h.adapter.requests, isEmpty);
    });

    test('without loaded legal versions nothing is recorded', () async {
      h.tenantContext.termsVersion = null;
      final failure = (await repo.grant(ConsentPurpose.terms)).match((f) => f, (_) => null);
      expect((failure! as ValidationFailure).code, 'legal_versions_missing');
      expect(h.adapter.requests, isEmpty);
    });

    test('apiName maps the server purposes; device-only purposes have none', () {
      expect({for (final p in ConsentPurpose.values) p: p.apiName}, {
        ConsentPurpose.terms: 'terms',
        ConsentPurpose.privacy: 'privacy',
        ConsentPurpose.marketingSms: 'marketing_sms',
        ConsentPurpose.locationCapture: null,
        ConsentPurpose.ricaCapture: null,
      });
    });
  });

  group('HttpPrivacyRepository', () {
    test('account deletion is DELETE /v1/me with the re-check code and returns a receipt', () async {
      final repo = HttpPrivacyRepository(h.api, now: () => h.now);
      h.adapter.on('DELETE', '/v1/me', (_) => const FakeReply(204));
      final receipt = (await repo.deleteAccount(challengeId: _challengeId, code: '123456')).getOrElse((f) => throw StateError(f.message));
      expect(receipt.reference, startsWith('DEL-'));
      expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
      expect(h.adapter.requests.single.data, {'challenge_id': _challengeId, 'code': '123456'});
    });

    test('the export request carries the bearer token', () async {
      final repo = HttpPrivacyRepository(h.api);
      h.adapter.on('GET', '/v1/me/export', (_) => FakeReply(200, fixture('export.json')));
      await repo.requestDataExport();
      expect(h.adapter.requestsTo('GET', '/v1/me/export').single.headers['Authorization'], 'Bearer access-1');
    });

    group('refusals reach the screen with the server reason', () {
      Future<PrivacyActionsCubit> failing(String method, String path, FakeReply reply) async {
        h.adapter.on(method, path, (_) => reply);
        var wiped = 0;
        final cubit = PrivacyActionsCubit(HttpPrivacyRepository(h.api), onAccountDeleted: () async => wiped++);
        addTearDown(cubit.close);
        if (method == 'DELETE') {
          h.adapter.on('POST', '/v1/me/delete-challenge', (_) => FakeReply(202, fixture('delete_challenge.json')));
          await cubit.requestDeleteCode();
          await cubit.deleteAccount('123456');
        } else {
          await cubit.requestDataExport();
        }
        expect(wiped, 0, reason: 'a refused request must not wipe anything');
        return cubit;
      }

      test('delete: 409 keeps the problem detail as a ValidationFailure', () async {
        final cubit = await failing('DELETE', '/v1/me', FakeReply.problem(409, 'open_orders', detail: 'Finish or cancel your open orders first.'));
        expect(cubit.state.status, PrivacyActionStatus.failed);
        expect(cubit.state.failure, isA<ValidationFailure>());
        expect(cubit.state.failure!.message, 'Finish or cancel your open orders first.');
      });

      test('delete: 403 keeps the detail', () async {
        final cubit = await failing('DELETE', '/v1/me', FakeReply.problem(403, 'forbidden', detail: 'Deletion is not allowed right now.'));
        expect(cubit.state.failure!.message, 'Deletion is not allowed right now.');
      });

      test('export: 422 and 403 keep the detail', () async {
        final unprocessable = await failing('GET', '/v1/me/export', FakeReply.problem(422, 'export_unavailable', detail: 'Add an email address first.'));
        expect(unprocessable.state.failure!.message, 'Add an email address first.');
        final forbidden = await failing('GET', '/v1/me/export', FakeReply.problem(403, 'forbidden', detail: 'Export is not allowed.'));
        expect(forbidden.state.failure!.message, 'Export is not allowed.');
      });

      test('offline and 5xx carry a failure the screen maps to its own text', () async {
        final offline = await failing('GET', '/v1/me/export', const FakeReply.error(DioExceptionType.connectionError));
        expect(offline.state.failure, isA<NetworkFailure>());
        final broken = await failing('DELETE', '/v1/me', FakeReply.problem(500, 'internal', detail: 'stack trace internals'));
        expect(broken.state.failure, isA<ServerFailure>());
      });
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
      h.adapter.on('POST', '/v1/me/delete-challenge', (_) => FakeReply(202, fixture('delete_challenge.json')));
      await cubit.requestDeleteCode();

      await cubit.deleteAccount('123456');
      expect(cubit.state.status, PrivacyActionStatus.failed);
      expect(wiped, 0);

      await cubit.deleteAccount('123456');
      expect(cubit.state.status, PrivacyActionStatus.deleted);
      expect(wiped, 1);
    });
  });
}
