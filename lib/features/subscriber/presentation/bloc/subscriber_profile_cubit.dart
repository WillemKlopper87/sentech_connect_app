import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_profile_edit.dart';
import 'package:sentech_connect_app/features/subscriber/domain/profile/profile_validators.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_profile_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

enum ProfilePhase { loading, ready, saving, saved, loadFailed }

/// `account`: the customer has a home internet account, the edit goes to
/// `PATCH /v1/me/subscriber`. `login`: there is no account yet, so the edit
/// goes to the sign-in profile, which the sign-up copies (the way out of
/// `subscriber_profile_invalid`).
enum ProfileMode { account, login }

enum ProfileField { name, email, phone, contact }

class ProfileState extends Equatable {
  const ProfileState({
    this.phase = ProfilePhase.loading,
    this.mode = ProfileMode.account,
    this.accountNo,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.language = 'en',
    this.showErrors = false,
    this.failure,
  });

  final ProfilePhase phase;
  final ProfileMode mode;
  final String? accountNo;
  final String name;
  final String email;
  final String phone;
  final String language;

  /// Field problems appear only after the first save attempt.
  final bool showErrors;

  /// The last read or save failed; the draft is kept for a retry.
  final Failure? failure;

  bool get busy => phase == ProfilePhase.saving;

  ProfileState copyWith({
    ProfilePhase? phase,
    ProfileMode? mode,
    String? accountNo,
    String? name,
    String? email,
    String? phone,
    String? language,
    bool? showErrors,
    Failure? failure,
  }) => ProfileState(
    phase: phase ?? this.phase,
    mode: mode ?? this.mode,
    accountNo: accountNo ?? this.accountNo,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    language: language ?? this.language,
    showErrors: showErrors ?? this.showErrors,
    failure: failure,
  );

  @override
  List<Object?> get props => [phase, mode, accountNo, name, email, phone, language, showErrors, failure];

  // Personal data: never in logs.
  @override
  String toString() => 'ProfileState(phase: $phase, mode: $mode)';
}

/// Edit of the billing contact details. Only the fields that changed are
/// sent. One `Idempotency-Key` per draft: a retry of the same draft reuses
/// it, any edit starts a new one. Held in memory only.
class SubscriberProfileCubit extends Cubit<ProfileState> {
  SubscriberProfileCubit(this._profiles, this._accounts, {String Function()? newKey})
    : _newKey = newKey ?? newIdempotencyKey,
      super(const ProfileState()) {
    load();
  }

  final SubscriberProfileRepository _profiles;
  final SubscriberRepository _accounts;
  final String Function() _newKey;

  String? _key;

  // What the platform holds now (the baseline the draft is compared with).
  String _oName = '';
  String _oEmail = '';
  String _oPhone = '';
  String _oLanguage = 'en';

  bool get _login => state.mode == ProfileMode.login;

  int get _nameMax => _login ? 80 : 120;

  Future<void> load() async {
    emit(const ProfileState());
    final account = await _accounts.getAccount();
    if (isClosed) return;
    final failure = account.match((f) => f, (_) => null);
    if (failure != null) {
      emit(ProfileState(phase: ProfilePhase.loadFailed, failure: failure));
      return;
    }
    final existing = account.getOrElse((_) => null);
    if (existing != null) {
      final p = existing.profile;
      _oName = p?.displayName ?? '';
      _oEmail = p?.email ?? '';
      _oPhone = p?.phoneE164 ?? '';
      _oLanguage = p?.language ?? 'en';
      _emitReady(ProfileMode.account, existing.accountNo);
      return;
    }
    final login = await _profiles.getLoginContact();
    if (isClosed) return;
    login.match((f) => emit(ProfileState(phase: ProfilePhase.loadFailed, failure: f)), (c) {
      _oName = c.displayName ?? '';
      _oEmail = c.email ?? '';
      _oPhone = c.phoneE164;
      _oLanguage = 'en';
      _emitReady(ProfileMode.login, null);
    });
  }

  void _emitReady(ProfileMode mode, String? accountNo) {
    _key = null;
    emit(
      ProfileState(
        phase: ProfilePhase.ready,
        mode: mode,
        accountNo: accountNo,
        name: _oName,
        email: _oEmail,
        phone: _oPhone,
        language: _oLanguage,
      ),
    );
  }

  void _edit(ProfileState next) {
    if (state.busy) return;
    _key = null;
    emit(next);
  }

  void setName(String v) => _edit(state.copyWith(phase: _editable, name: v));
  void setEmail(String v) => _edit(state.copyWith(phase: _editable, email: v));
  void setPhone(String v) => _edit(state.copyWith(phase: _editable, phone: v));
  void setLanguage(String v) => _edit(state.copyWith(phase: _editable, language: v));

  // An edit after a save puts the form back to "ready".
  ProfilePhase get _editable => ProfilePhase.ready;

  /// The problems with the draft as it stands (empty when it can be saved).
  Set<ProfileField> get issues {
    final out = <ProfileField>{};
    if (validName(state.name, max: _nameMax) == null) out.add(ProfileField.name);
    final email = state.email.trim();
    final phone = state.phone.trim();
    if (email.isNotEmpty && validEmail(email) == null) out.add(ProfileField.email);
    if (!_login && phone.isNotEmpty && validPhone(phone) == null) out.add(ProfileField.phone);
    final hasPhone = _login || phone.isNotEmpty;
    if (email.isEmpty && !hasPhone) out.add(ProfileField.contact);
    return out;
  }

  /// What would be sent; empty when nothing changed.
  SubscriberProfilePatch get patch {
    final name = validName(state.name, max: _nameMax);
    final email = state.email.trim();
    final phone = _login ? null : validPhone(state.phone);
    return SubscriberProfilePatch(
      displayName: name != null && name != _oName ? name : null,
      email: email.isNotEmpty && email != _oEmail ? email : null,
      clearEmail: email.isEmpty && _oEmail.isNotEmpty,
      phoneE164: !_login && phone != null && phone != _oPhone ? phone : null,
      clearPhone: !_login && state.phone.trim().isEmpty && _oPhone.isNotEmpty,
      language: !_login && state.language != _oLanguage ? state.language : null,
    );
  }

  bool get hasChanges => !patch.isEmpty;

  Future<void> save() async {
    if (state.busy || (state.phase != ProfilePhase.ready && state.phase != ProfilePhase.saved)) return;
    if (issues.isNotEmpty) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    final change = patch;
    if (change.isEmpty) return;
    final key = _key ??= _newKey();
    emit(state.copyWith(phase: ProfilePhase.saving));
    if (_login) {
      final result = await _profiles.patchLoginContact(
        displayName: change.displayName,
        email: change.email,
        clearEmail: change.clearEmail,
      );
      if (isClosed) return;
      result.match((f) => emit(state.copyWith(phase: ProfilePhase.ready, failure: f, showErrors: true)), (c) {
        _oName = c.displayName ?? '';
        _oEmail = c.email ?? '';
        _key = null;
        emit(state.copyWith(phase: ProfilePhase.saved, name: _oName, email: _oEmail));
      });
      return;
    }
    final result = await _profiles.patchProfile(change, idempotencyKey: key);
    if (isClosed) return;
    result.match((f) => emit(state.copyWith(phase: ProfilePhase.ready, failure: f, showErrors: true)), (
      SubscriberAccount a,
    ) {
      final p = a.profile;
      _oName = p?.displayName ?? _oName;
      _oEmail = p?.email ?? '';
      _oPhone = p?.phoneE164 ?? '';
      _oLanguage = p?.language ?? _oLanguage;
      _key = null;
      emit(
        state.copyWith(
          phase: ProfilePhase.saved,
          name: _oName,
          email: _oEmail,
          phone: _oPhone,
          language: _oLanguage,
        ),
      );
    });
  }
}
