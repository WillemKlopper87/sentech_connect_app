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

  bool get isSettled => status != TenantStatus.initial && status != TenantStatus.loading;

  TenantState copyWith({TenantStatus? status, List<Tenant>? tenants, AppConfig? config, Failure? failure}) => TenantState(
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
  })  : _appVersion = currentAppVersion,
        super(const TenantState());

  final TenantRepository _repository;
  final TenantContext _context;
  final TenantPreferences _preferences;
  final String _appVersion;

  /// Signs the customer out before a different tenant is loaded: tokens,
  /// session and personal data belong to exactly one tenant.
  final Future<void> Function()? _onTenantChanging;
  String? _targetSlug;

  Future<void> bootstrap() async {
    emit(state.copyWith(status: TenantStatus.loading));
    final saved = await _preferences.loadSlug();
    if (saved != null) {
      await _activate(saved);
    } else {
      await _loadDirectory();
    }
  }

  /// "Change provider" from Account.
  Future<void> openPicker() async {
    emit(state.copyWith(status: TenantStatus.loading));
    await _loadDirectory(autoSelectSingle: false);
  }

  void cancelPicker() {
    final config = state.config;
    if (config != null) _apply(config);
  }

  Future<void> select(Tenant tenant) async {
    final current = state.config?.tenant.slug;
    if (current != null && current != tenant.slug) await _onTenantChanging?.call();
    if (isClosed) return;
    emit(state.copyWith(status: TenantStatus.loading));
    await _activate(tenant.slug);
  }

  Future<void> retry() async {
    final target = _targetSlug;
    if (target == null) return bootstrap();
    emit(state.copyWith(status: TenantStatus.loading));
    await _activate(target);
  }

  Future<void> _loadDirectory({bool autoSelectSingle = true}) async {
    final result = await _repository.listTenants();
    if (isClosed) return;
    switch (result) {
      case Left(value: final failure):
        emit(state.copyWith(status: TenantStatus.failure, failure: failure));
      case Right(value: final tenants):
        if (autoSelectSingle && tenants.length == 1) {
          await _activate(tenants.single.slug);
          return;
        }
        emit(state.copyWith(status: TenantStatus.needsSelection, tenants: tenants));
    }
  }

  Future<void> _activate(String slug) async {
    _targetSlug = slug;
    _context.slug = slug;
    final result = await _repository.getAppConfig(slug);
    if (isClosed) return;
    switch (result) {
      case Right(value: final config):
        await _preferences.saveSlug(slug);
        await _preferences.saveConfigJson(jsonEncode(config.toJson()));
        _apply(config);
      case Left(value: NotFoundFailure()):
        // The saved tenant was removed or suspended: choose again.
        await _preferences.clear();
        _targetSlug = null;
        await _loadDirectory();
      case Left(value: final failure):
        final cached = await _cachedConfig(slug);
        if (isClosed) return;
        if (cached != null) {
          _apply(cached);
        } else {
          emit(state.copyWith(status: TenantStatus.failure, failure: failure));
        }
    }
  }

  void _apply(AppConfig config) {
    _context
      ..slug = config.tenant.slug
      ..termsVersion = config.legal.terms
      ..privacyVersion = config.legal.privacy;
    final status = isVersionAtLeast(_appVersion, config.minAppVersion) ? TenantStatus.ready : TenantStatus.updateRequired;
    emit(TenantState(status: status, tenants: state.tenants, config: config));
  }

  Future<AppConfig?> _cachedConfig(String slug) async {
    final raw = await _preferences.loadConfigJson();
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final config = AppConfig.fromJson(Map<String, Object?>.from(decoded));
      return config.tenant.slug == slug ? config : null;
    } on FormatException {
      return null;
    }
  }
}
