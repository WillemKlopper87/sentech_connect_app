import 'dart:convert';

import 'package:dio/dio.dart' show DioExceptionType;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _path = '/v1/me/subscriber/kyc';

const _submission = KycSubmission(
  idType: KycIdType.saId,
  idNumber: '8001015009087',
  addressText: '1 Main Road Sandton 2196',
  consentVersion: '2026-09-30',
  documentBase64: 'QUJD',
);

Failure? _failure<T>(Either<Failure, T> e) => e.match((f) => f, (_) => null);

void main() {
  late ApiHarness h;
  late HttpKycRepository repo;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    repo = HttpKycRepository(h.api);
  });

  group('status', () {
    test('none is no record', () async {
      h.adapter.on('GET', _path, (_) => FakeReply(200, fixture('subscriber_kyc_none.json')));
      expect((await repo.getStatus()).getOrElse((f) => throw f), isNull);
    });

    test('pending maps every field and never carries the ID number', () async {
      h.adapter.on('GET', _path, (_) => FakeReply(200, fixture('subscriber_kyc_pending.json')));
      final record = (await repo.getStatus()).getOrElse((f) => throw f)!;
      expect(record.status, KycStatus.pending);
      expect(record.idType, KycIdType.saId);
      expect(record.idNumberLast4, '9087');
      expect(record.consentVersion, '2026-09-30');
      expect(record.consentAt, DateTime.utc(2026, 10, 30, 8, 15));
      expect(record.verifiedAt, isNull);
    });

    test('verified and rejected map; erased is treated as none', () async {
      final base = fixtureMap('subscriber_kyc_pending.json');
      for (final (status, expected) in [
        ('verified', KycStatus.verified),
        ('rejected', KycStatus.rejected),
        ('erased', null),
      ]) {
        h.adapter.on('GET', _path, (_) => FakeReply(200, {...base, 'status': status}));
        expect((await repo.getStatus()).getOrElse((f) => throw f)?.status, expected, reason: status);
      }
    });

    test('an unknown status is a loud failure, not a guess', () async {
      h.adapter.on('GET', _path, (_) => FakeReply(200, {...fixtureMap('subscriber_kyc_pending.json'), 'status': 'weird'}));
      expect(_failure(await repo.getStatus()), isA<ServerFailure>());
    });

    test('no subscriber account is its own failure; offline is a NetworkFailure', () async {
      h.adapter.on('GET', _path, (_) => FakeReply.problem(404, 'subscriber_not_found'));
      expect(_failure(await repo.getStatus()), isA<SubscriberNotFoundFailure>());
      h.adapter.on('GET', _path, (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect(_failure(await repo.getStatus()), isA<NetworkFailure>());
    });
  });

  group('submit', () {
    test('sends exactly the SubscriberKycIn keys with the idempotency key and returns the pending record', () async {
      h.adapter.on('POST', _path, (_) => FakeReply(201, fixture('subscriber_kyc_pending.json')));
      final result = await repo.submit(_submission, idempotencyKey: 'app-key-0001');
      expect(result.getOrElse((f) => throw f).status, KycStatus.pending);
      final request = h.adapter.requestsTo('POST', _path).single;
      expect(request.headers['Idempotency-Key'], 'app-key-0001');
      final body = jsonDecode(jsonEncode(request.data)) as Map<String, Object?>;
      expect(body.keys.toSet(), {'id_type', 'id_number', 'address_text', 'consent_version', 'consent_via', 'document'});
      expect(body['id_type'], 'sa_id');
      expect(body['consent_via'], 'app');
      expect(body['document'], 'QUJD');
    });

    test('a submission without a photo leaves document out', () {
      const none = KycSubmission(
        idType: KycIdType.passport,
        idNumber: 'A1234567',
        addressText: 'x',
        consentVersion: '2026-09-30',
      );
      expect(none.toJson().containsKey('document'), isFalse);
    });

    test('a submission never prints personal data', () {
      expect(_submission.toString(), isNot(contains('8001015009087')));
      expect(_submission.toString(), isNot(contains('Main Road')));
    });

    final cases = <(int, String, Matcher)>[
      (422, 'invalid_identity_number', isA<KycInvalidIdFailure>()),
      (422, 'invalid_address', isA<KycInvalidAddressFailure>()),
      (422, 'invalid_document_encoding', isA<KycDocumentRejectedFailure>()),
      (422, 'document_type_not_allowed', isA<KycDocumentRejectedFailure>()),
      (413, 'document_too_large', isA<KycDocumentRejectedFailure>()),
      (503, 'document_upload_failed', isA<KycUploadFailedFailure>()),
      (409, 'document_upload_expired', isA<KycUploadFailedFailure>()),
      (422, 'invalid_consent_version', isA<ConsentVersionOutdatedFailure>()),
      (409, 'kyc_required', isA<KycRequiredFailure>()),
      (404, 'subscriber_not_found', isA<SubscriberNotFoundFailure>()),
      (409, 'account_closed', isA<ServiceStateFailure>()),
    ];
    for (final (status, code, matcher) in cases) {
      test('$status $code maps to a typed failure', () async {
        h.adapter.on('POST', _path, (_) => FakeReply.problem(status, code));
        expect(_failure(await repo.submit(_submission, idempotencyKey: 'app-key-0001')), matcher);
      });
    }

    test('offline is a NetworkFailure', () async {
      h.adapter.on('POST', _path, (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect(_failure(await repo.submit(_submission, idempotencyKey: 'app-key-0001')), isA<NetworkFailure>());
    });
  });

  group('mock', () {
    test('starts empty, turns pending then verified after the delay, keeping only the last four', () async {
      var now = DateTime.utc(2026, 10, 30, 8);
      final mock = MockKycRepository(now: () => now);
      expect((await mock.getStatus()).getOrElse((f) => throw f), isNull);
      final sent = (await mock.submit(_submission, idempotencyKey: 'app-key-0001')).getOrElse((f) => throw f);
      expect(sent.status, KycStatus.pending);
      expect(sent.idNumberLast4, '9087');
      expect((await mock.getStatus()).getOrElse((f) => throw f)!.status, KycStatus.pending);
      now = now.add(const Duration(seconds: 5));
      expect((await mock.getStatus()).getOrElse((f) => throw f)!.status, KycStatus.verified);
    });
  });
}
