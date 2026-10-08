import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/app_version.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/utils/version.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

enum TenantStatus { initial, loading, needsSelection, ready, updateRequired, failure }

class TenantState extends Equatable {
  const TenantState({this.status = TenantStatus.initial, this.tenants = const [], this.config, this.failure});

  final TenantStatus status;
  final List<Tenant> tenants;
  final AppConfig? config;
  final Failure? failure;

  /// Before any config is loaded (and in widget tests without a tenant) the
  /// demo flags apply, which preserves the pre-tenant behaviour.
  FeatureFlags get featureFlags => config?.featureFlags ?? FeatureFlags.demo;

  /// Until a config arrives the app behaves as before (Scan stays visible).
  bool isModuleOn(String key) => config?.isModuleOn(key) ?? key == AppModuleKeys.vouchers;

  bool get isSettled => status != TenantStatus.initial && status != TenantStatus.loading;

  TenantState copyWith({TenantStatus? status, List<Tenant>? tenants, AppConfig? config, Failure? failure}) =>
      TenantState(
        status: status ?? this.status,
        tenants: tenants ?? this.tenants,
        config: config ?? this.config,
        failure: failure,
      );

  @override
  List<Object?> get props => [status, tenants, config, failure];
}

/// Which ISP the app serves (spec §12: one app with a tenant picker).
/// Persists the choice and the last app-config (for offline launches),
/// applies branding/flags/legal versions, and gates too-old app versions.
class TenantCubit extends Cubit<TenantState> {
  TenantCubit({
    required this._repository,
    required this._context,
    required this._preferences,
    String currentAppVersion = appVersion,
    this._onTenantChanging,
    this._onTenantApplied,
  }) : _appVersion = currentAppVersion,
       super(const TenantState());

  final TenantRepository _repository;
  final TenantContext _context;
  final TenantPreferences _preferences;
  final String _appVersion;

  /// Signs the customer out before a different tenant becomes active: tokens,
  /// session and personal data belong to exactly one tenant.
  final Future<void> Function()? _onTenantChanging;

  /// Called with the slug of EVERY tenant that becomes active (including the
  /// first one after a launch or reinstall), before the app is shown for it:
  /// the session stored on the device must belong to that tenant, or be ended
  /// (see `AuthCubit.ensureSessionMatches`). A throw puts the cubit in a
  /// retryable failure state rather than showing a mismatched session.
  final Future<void> Function(String slug)? _onTenantApplied;

  /// The tenant whose session/personal data may be on this device (the saved
  /// or last applied one); null once signed out or before any choice. EVERY
  /// path that activates a different slug signs out first (see `_activate`).
  String? _committedSlug;
  String? _targetSlug;

  /// True when the last failure was loading the directory (retry reloads it)
  /// rather than activating a tenant.
  bool _directoryFailed = false;
  bool _selecting = false;

  static const _unexpected = ServerFailure('Something went wrong. Please try again.');

  Future<void> bootstrap() => _guard(() async {
    emit(state.copyWith(status: TenantStatus.loading));
    final saved = await _loadSavedSlug();
    _committedSlug = saved;
    if (saved != null) {
      await _activate(saved);
    } else {
      await _loadDirectory();
    }
  });

  /// "Change provider" from Account.
  Future<void> openPicker() => _guard(() async {
    emit(state.copyWith(status: TenantStatus.loading));
    await _loadDirectory(autoSelectSingle: false);
  });

  Future<void> cancelPicker() => _guard(() async {
    final config = state.config;
    if (config != null) await _apply(config);
  });

  Future<void> select(Tenant tenant) async {
    // Ignore a second tap while a switch (sign-out + load) is in flight.
    if (_selecting || state.status == TenantStatus.loading) return;
    _selecting = true;
    try {
      await _guard(() async {
        emit(state.copyWith(status: TenantStatus.loading));
        await _activate(tenant.slug);
      });
    } finally {
      _selecting = false;
    }
  }

  Future<void> retry() => _guard(() async {
    emit(state.copyWith(status: TenantStatus.loading));
    final target = _targetSlug;
    if (_directoryFailed || target == null) {
      await _loadDirectory(autoSelectSingle: state.config == null);
    } else {
      await _activate(target);
    }
  });

  /// Any unexpected throw (storage, parsing, sign-out) ends in a retryable
  /// failure state instead of leaving the app on `loading` forever.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (_) {
      if (isClosed) return;
      _restoreContext();
      emit(state.copyWith(status: TenantStatus.failure, failure: _unexpected));
    }
  }

  /// A persisted slug is untrusted (tampered prefs, backup restore): an
  /// invalid one is dropped, and because the tenant of any stored session is
  /// then unknown, the customer is signed out.
  Future<String?> _loadSavedSlug() async {
    final raw = await _preferences.loadSlug();
    if (raw == null) return null;
    try {
      TenantContext(slug: raw);
      return raw;
    } on ArgumentError {
      await _preferences.clear();
      await _onTenantChanging?.call();
      return null;
    }
  }

  Future<void> _loadDirectory({bool autoSelectSingle = true}) async {
    final result = await _repository.listTenants();
    if (isClosed) return;
    switch (result) {
      case Left(value: final failure):
        _directoryFailed = true;
        _restoreContext();
        emit(state.copyWith(status: TenantStatus.failure, failure: failure));
      case Right(value: final directory):
        _directoryFailed = false;
        final tenants = directory.tenants;
        // Never pick for the customer from an incomplete directory: the one
        // usable entry may not be the provider they meant.
        if (autoSelectSingle && tenants.length == 1 && !directory.isIncomplete) {
          await _activate(tenants.single.slug);
          return;
        }
        emit(state.copyWith(status: TenantStatus.needsSelection, tenants: tenants));
    }
  }

  /// Signs out if a session of another tenant may exist. False (and a failure
  /// state) when the sign-out itself failed: the tenant must not change then.
  Future<bool> _signOutBeforeChange() async {
    if (_committedSlug == null) return true;
    try {
      await _onTenantChanging?.call();
    } catch (_) {
      if (!isClosed) {
        _restoreContext();
        emit(state.copyWith(status: TenantStatus.failure, failure: _unexpected));
      }
      return false;
    }
    _committedSlug = null;
    return !isClosed;
  }

  Future<void> _activate(String slug) async {
    _targetSlug = slug;
    _directoryFailed = false;
    if (_committedSlug != null && _committedSlug != slug && !await _signOutBeforeChange()) return;
    final result = await _repository.getAppConfig(slug);
    if (isClosed) return;
    switch (result) {
      case Right(value: final config):
        await _persist(slug, config);
        await _apply(config);
      case Left(value: NotFoundFailure()):
        // The tenant was removed or suspended: its session must not outlive
        // it, and the customer chooses again.
        if (!await _signOutBeforeChange()) return;
        await _preferences.clear();
        _targetSlug = null;
        await _loadDirectory();
      case Left(value: final failure):
        final cached = await _cachedConfig(slug);
        if (isClosed) return;
        if (cached != null) {
          await _apply(cached);
        } else {
          _restoreContext();
          emit(state.copyWith(status: TenantStatus.failure, failure: failure));
        }
    }
  }

  /// Remembering the choice is best effort: failing to write must not stop a
  /// config that loaded fine (the customer is simply asked again next launch).
  Future<void> _persist(String slug, AppConfig config) async {
    try {
      await _preferences.saveSlug(slug);
      await _preferences.saveConfigJson(jsonEncode(config.toJson()));
    } catch (_) {}
  }

  Future<void> _apply(AppConfig config) async {
    _applyToContext(config);
    await _onTenantApplied?.call(config.tenant.slug);
    if (isClosed) return;
    _committedSlug = config.tenant.slug;
    final status = isVersionAtLeast(_appVersion, config.minAppVersion)
        ? TenantStatus.ready
        : TenantStatus.updateRequired;
    emit(TenantState(status: status, tenants: state.tenants, config: config));
  }

  void _applyToContext(AppConfig config) {
    _context
      ..slug = config.tenant.slug
      ..termsVersion = config.legal.terms
      ..privacyVersion = config.legal.privacy;
  }

  /// After a failed load/switch the context must still describe the config
  /// shown in `state`, never a mix of two tenants.
  void _restoreContext() {
    final config = state.config;
    if (config != null) _applyToContext(config);
  }

  /// The cache is untrusted storage: anything malformed, or for another
  /// tenant, is ignored.
  Future<AppConfig?> _cachedConfig(String slug) async {
    try {
      final raw = await _preferences.loadConfigJson();
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final config = AppConfig.fromJson(Map<String, Object?>.from(decoded));
      return config.tenant.slug == slug ? config : null;
    } catch (_) {
      return null;
    }
  }
}
