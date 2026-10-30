
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_document_encoder.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/id_image_picker.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/kyc_validators.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';

enum KycFormPhase { editing, preparingPhoto, submitting, submitted }

/// What went wrong with the photo, shown under it (not a submit failure).
enum KycPhotoIssue { permissionDenied, unreadable, tooLarge, failed }

/// Runs [IdDocumentEncoder.encode]; the default does it off the UI isolate.
typedef KycEncode = Future<({EncodedIdDocument? document, IdDocumentIssue? issue})> Function(Uint8List bytes);

Future<({EncodedIdDocument? document, IdDocumentIssue? issue})> encodeInBackground(Uint8List bytes) =>
    compute(_encode, bytes);

({EncodedIdDocument? document, IdDocumentIssue? issue}) _encode(Uint8List bytes) => const IdDocumentEncoder().encode(bytes);

/// The form draft. Held in memory only (never stored, never restored) and
/// emptied the moment the submission is accepted or the form is left.
class KycFormState extends Equatable {
  const KycFormState({
    this.idType = KycIdType.saId,
    this.idNumber = '',
    this.address = '',
    this.consent = false,
    this.photo,
    this.phase = KycFormPhase.editing,
    this.showErrors = false,
    this.failure,
    this.photoIssue,
    this.deniedSource,
  });

  final KycIdType idType;
  final String idNumber;
  final String address;
  final bool consent;

  /// The prepared photo (JPEG), shown as the preview.
  final EncodedIdDocument? photo;
  final KycFormPhase phase;

  /// Field problems appear only after the first submit attempt.
  final bool showErrors;

  /// The last submit failed (the draft and the photo are kept for a retry).
  final Failure? failure;
  final KycPhotoIssue? photoIssue;

  /// Which source the denied permission belongs to.
  final IdImageSource? deniedSource;

  bool get busy => phase == KycFormPhase.preparingPhoto || phase == KycFormPhase.submitting;

  KycFormState copyWith({
    KycIdType? idType,
    String? idNumber,
    String? address,
    bool? consent,
    EncodedIdDocument? photo,
    bool clearPhoto = false,
    KycFormPhase? phase,
    bool? showErrors,
    Failure? failure,
    KycPhotoIssue? photoIssue,
    IdImageSource? deniedSource,
  }) => KycFormState(
    idType: idType ?? this.idType,
    idNumber: idNumber ?? this.idNumber,
    address: address ?? this.address,
    consent: consent ?? this.consent,
    photo: clearPhoto ? null : (photo ?? this.photo),
    phase: phase ?? this.phase,
    showErrors: showErrors ?? this.showErrors,
    failure: failure,
    photoIssue: photoIssue,
    deniedSource: deniedSource,
  );

  @override
  List<Object?> get props => [idType, idNumber, address, consent, photo, phase, showErrors, failure, photoIssue, deniedSource];

  // Personal data: never in logs.
  @override
  String toString() => 'KycFormState(phase: $phase)';
}

class KycFormCubit extends Cubit<KycFormState> {
  KycFormCubit(
    this._repository,
    this._picker, {
    required this.consentVersion,
    DateTime Function()? now,
    String Function()? newKey,
    KycEncode? encode,
  }) : _now = now ?? DateTime.now,
       _newKey = newKey ?? newIdempotencyKey,
       _encode = encode ?? encodeInBackground,
       super(const KycFormState());

  final KycRepository _repository;
  final IdImagePicker _picker;

  /// `app-config.legal.privacy` (`YYYY-MM-DD`), or null when no config is
  /// loaded (then submitting is refused with a retryable failure).
  final String? consentVersion;
  final DateTime Function() _now;
  final String Function() _newKey;
  final KycEncode _encode;

  // One key per logical submission: a retry of the SAME draft reuses it, any
  // edit starts a new one (the platform refuses a key reused with another body).
  String? _key;

  void setIdType(KycIdType type) {
    if (state.busy || type == state.idType) return;
    _key = null;
    emit(state.copyWith(idType: type, idNumber: ''));
  }

  void setIdNumber(String value) {
    _key = null;
    emit(state.copyWith(idNumber: value));
  }

  void setAddress(String value) {
    _key = null;
    emit(state.copyWith(address: value));
  }

  void setConsent(bool value) {
    if (state.busy) return;
    _key = null;
    emit(state.copyWith(consent: value));
  }

  void removePhoto() {
    if (state.busy) return;
    _key = null;
    emit(state.copyWith(clearPhoto: true));
  }

  bool get idNumberValid =>
      KycValidators.isValidIdNumber(state.idType, state.idNumber, KycValidators.sastDate(_now()));
  bool get addressValid => KycValidators.isValidAddress(state.address);

  /// Asks for a photo (camera or gallery), then shrinks it. The previous photo
  /// stays when the customer cancels or the new one cannot be used.
  Future<void> pickPhoto(IdImageSource source) async {
    if (state.busy) return;
    emit(state.copyWith(phase: KycFormPhase.preparingPhoto));
    final picked = await _picker.pick(source);
    if (isClosed) return;
    switch (picked) {
      case IdImagePickCancelled():
        emit(state.copyWith(phase: KycFormPhase.editing));
      case IdImagePickDenied(:final source):
        emit(state.copyWith(phase: KycFormPhase.editing, photoIssue: KycPhotoIssue.permissionDenied, deniedSource: source));
      case IdImagePickFailed():
        emit(state.copyWith(phase: KycFormPhase.editing, photoIssue: KycPhotoIssue.failed));
      case PickedIdImage(:final bytes):
        final encoded = await _encode(bytes);
        if (isClosed) return;
        final document = encoded.document;
        if (document == null) {
          emit(
            state.copyWith(
              phase: KycFormPhase.editing,
              photoIssue: encoded.issue == IdDocumentIssue.tooLarge ? KycPhotoIssue.tooLarge : KycPhotoIssue.unreadable,
            ),
          );
        } else {
          _key = null;
          emit(state.copyWith(phase: KycFormPhase.editing, photo: document));
        }
    }
  }

  Future<void> submit() async {
    if (state.busy || state.phase == KycFormPhase.submitted) return;
    final photo = state.photo;
    if (!idNumberValid || !addressValid || photo == null || !state.consent) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    final version = consentVersion;
    if (version == null) {
      emit(state.copyWith(showErrors: true, failure: const ConsentVersionOutdatedFailure()));
      return;
    }
    final submission = KycSubmission(
      idType: state.idType,
      idNumber: KycValidators.normalizeIdNumber(state.idType, state.idNumber),
      addressText: KycValidators.normalizeAddress(state.address),
      consentVersion: version,
      documentBase64: photo.base64,
    );
    _key ??= _newKey();
    emit(state.copyWith(phase: KycFormPhase.submitting, showErrors: true));
    final result = await _repository.submit(submission, idempotencyKey: _key!);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(phase: KycFormPhase.editing, failure: failure)),
      (_) {
        _key = null;
        // Accepted: nothing personal is kept in memory any longer.
        emit(const KycFormState(phase: KycFormPhase.submitted));
      },
    );
  }

  @override
  Future<void> close() {
    // Leaving the form drops the draft and the photo with it.
    _key = null;
    return super.close();
  }
}
