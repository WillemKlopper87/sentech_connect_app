import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_document_encoder.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_image_picker.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/kyc_form_cubit.dart';

class FakePicker implements IdImagePicker {
  FakePicker(this.result);
  IdImagePickResult result;
  final sources = <IdImageSource>[];
  @override
  Future<IdImagePickResult> pick(IdImageSource source) async {
    sources.add(source);
    return result;
  }
}

class FakeKycRepository implements KycRepository {
  final submissions = <KycSubmission>[];
  final keys = <String>[];
  Either<Failure, KycRecord> reply = Right(
    KycRecord(
      status: KycStatus.pending,
      idType: KycIdType.saId,
      idNumberLast4: '9087',
      consentVersion: '2026-09-30',
      consentAt: DateTime.utc(2026, 10, 30),
    ),
  );

  @override
  Future<Either<Failure, KycRecord?>> getStatus() async => const Right(null);

  @override
  Future<Either<Failure, KycRecord>> submit(KycSubmission submission, {required String idempotencyKey}) async {
    submissions.add(submission);
    keys.add(idempotencyKey);
    return reply;
  }
}

Future<({EncodedIdDocument? document, IdDocumentIssue? issue})> _okEncode(Uint8List bytes) async =>
    (document: EncodedIdDocument(Uint8List.fromList([0xff, 0xd8, 0xff, 9])), issue: null);

void main() {
  late FakeKycRepository repo;
  late FakePicker picker;
  var keyCounter = 0;

  KycFormCubit build({String? consent = '2026-09-30', KycEncode? encode}) => KycFormCubit(
    repo,
    picker,
    consentVersion: consent,
    now: () => DateTime.utc(2026, 10, 30, 8),
    newKey: () => 'app-key-${++keyCounter}',
    encode: encode ?? _okEncode,
  );

  Future<void> fillValid(KycFormCubit c) async {
    c.setIdNumber('8001015009087');
    c.setAddress('1 Main Road\nSandton  2196');
    c.setConsent(true);
    await c.pickPhoto(IdImageSource.gallery);
  }

  setUp(() {
    repo = FakeKycRepository();
    picker = FakePicker(PickedIdImage(Uint8List.fromList([1, 2, 3])));
    keyCounter = 0;
  });

  test('submit sends normalised values and the photo as base64, then empties the draft', () async {
    final c = build();
    await fillValid(c);
    await c.submit();
    expect(c.state.phase, KycFormPhase.submitted);
    final sent = repo.submissions.single;
    expect(sent.idType, KycIdType.saId);
    expect(sent.idNumber, '8001015009087');
    expect(sent.addressText, '1 Main Road Sandton 2196');
    expect(sent.consentVersion, '2026-09-30');
    expect(sent.documentBase64, isNotNull);
    // Nothing personal stays in the state after the send.
    expect(c.state.idNumber, isEmpty);
    expect(c.state.address, isEmpty);
    expect(c.state.photo, isNull);
    await c.close();
  });

  test('an invalid draft shows errors and sends nothing', () async {
    final c = build();
    c.setIdNumber('8001015009088'); // bad checksum
    await c.submit();
    expect(c.state.showErrors, isTrue);
    expect(c.idNumberValid, isFalse);
    expect(c.addressValid, isFalse);
    expect(repo.submissions, isEmpty);
    await c.close();
  });

  test('photo and consent are required', () async {
    final c = build();
    c.setIdNumber('8001015009087');
    c.setAddress('1 Main Road');
    await c.submit();
    expect(repo.submissions, isEmpty);
    c.setConsent(true);
    await c.submit();
    expect(repo.submissions, isEmpty, reason: 'still no photo');
    await c.close();
  });

  test('a failure keeps the draft and the photo; retrying the same draft reuses the key, an edit rotates it', () async {
    final c = build();
    await fillValid(c);
    repo.reply = const Left(NetworkFailure());
    await c.submit();
    expect(c.state.failure, isA<NetworkFailure>());
    expect(c.state.phase, KycFormPhase.editing);
    expect(c.state.photo, isNotNull);
    expect(c.state.idNumber, '8001015009087');
    await c.submit();
    expect(repo.keys, ['app-key-1', 'app-key-1']);
    c.setAddress('2 Other Road');
    await c.submit();
    expect(repo.keys.last, 'app-key-2');
    await c.close();
  });

  for (final (name, failure) in <(String, Failure)>[
    ('invalid id', const KycInvalidIdFailure()),
    ('invalid address', const KycInvalidAddressFailure()),
    ('document rejected', const KycDocumentRejectedFailure()),
    ('upload failed', const KycUploadFailedFailure()),
    ('consent outdated', const ConsentVersionOutdatedFailure()),
    ('kyc required', const KycRequiredFailure()),
  ]) {
    test('a $name refusal is kept on the form for the customer to fix', () async {
      final c = build();
      await fillValid(c);
      repo.reply = Left(failure);
      await c.submit();
      expect(c.state.failure, failure);
      expect(c.state.phase, KycFormPhase.editing);
      await c.close();
    });
  }

  test('without a loaded privacy version the send is refused with a retryable failure', () async {
    final c = build(consent: null);
    await fillValid(c);
    await c.submit();
    expect(c.state.failure, isA<ConsentVersionOutdatedFailure>());
    expect(repo.submissions, isEmpty);
    await c.close();
  });

  group('photo', () {
    test('camera and gallery are passed through', () async {
      final c = build();
      await c.pickPhoto(IdImageSource.camera);
      expect(picker.sources, [IdImageSource.camera]);
      expect(c.state.photo, isNotNull);
      await c.close();
    });

    test('cancel keeps the previous photo', () async {
      final c = build();
      await c.pickPhoto(IdImageSource.gallery);
      final first = c.state.photo;
      picker.result = const IdImagePickCancelled();
      await c.pickPhoto(IdImageSource.gallery);
      expect(c.state.photo, same(first));
      expect(c.state.photoIssue, isNull);
      await c.close();
    });

    test('denied permission is reported with its source (gallery fallback in the UI)', () async {
      final c = build();
      picker.result = const IdImagePickDenied(IdImageSource.camera);
      await c.pickPhoto(IdImageSource.camera);
      expect(c.state.photoIssue, KycPhotoIssue.permissionDenied);
      expect(c.state.deniedSource, IdImageSource.camera);
      expect(c.state.phase, KycFormPhase.editing);
      await c.close();
    });

    test('an unreadable or too-large photo is reported and not kept', () async {
      final c = build(encode: (_) async => (document: null, issue: IdDocumentIssue.unreadable));
      await c.pickPhoto(IdImageSource.gallery);
      expect(c.state.photoIssue, KycPhotoIssue.unreadable);
      expect(c.state.photo, isNull);
      await c.close();
      final big = build(encode: (_) async => (document: null, issue: IdDocumentIssue.tooLarge));
      await big.pickPhoto(IdImageSource.gallery);
      expect(big.state.photoIssue, KycPhotoIssue.tooLarge);
      await big.close();
    });

    test('a picker failure is reported; remove clears the photo', () async {
      final c = build();
      picker.result = const IdImagePickFailed();
      await c.pickPhoto(IdImageSource.gallery);
      expect(c.state.photoIssue, KycPhotoIssue.failed);
      picker.result = PickedIdImage(Uint8List.fromList([1]));
      await c.pickPhoto(IdImageSource.gallery);
      c.removePhoto();
      expect(c.state.photo, isNull);
      await c.close();
    });
  });

  test('changing the ID type clears the number', () async {
    final c = build();
    c.setIdNumber('8001015009087');
    c.setIdType(KycIdType.passport);
    expect(c.state.idNumber, isEmpty);
    expect(c.state.idType, KycIdType.passport);
    await c.close();
  });

  test('the state never prints personal data', () {
    const state = KycFormState(idNumber: '8001015009087', address: '1 Main Road');
    expect(state.toString(), isNot(contains('8001015009087')));
    expect(state.toString(), isNot(contains('Main')));
  });
}
