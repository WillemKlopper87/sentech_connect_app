import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

/// Per-tenant switches (spec §6: RICA/CPE off at launch). A missing flag is
/// treated as OFF, so an unfinished feature never appears by accident.
class FeatureFlags extends Equatable {
  const FeatureFlags({
    required this.hotspotPasses,
    required this.rica,
    required this.cpe,
    this.vouchers = false,
    this.hotspotRadius = false,
  });

  /// Demo flavor: hotspot passes lead; router/CPE content stays off, as at
  /// launch (RICA stays on for the physical-product demo flow).
  static const demo = FeatureFlags(hotspotPasses: true, rica: true, cpe: false, vouchers: true, hotspotRadius: true);

  final bool hotspotPasses;
  final bool rica;
  final bool cpe;
  final bool vouchers;
  final bool hotspotRadius;

  factory FeatureFlags.fromJson(Map<String, Object?> json) => FeatureFlags(
        hotspotPasses: json['hotspot_passes'] == true,
        rica: json['rica'] == true,
        cpe: json['cpe'] == true,
        vouchers: json['vouchers'] == true,
        hotspotRadius: json['hotspot_radius'] == true,
      );

  Map<String, Object?> toJson() => {
        'hotspot_passes': hotspotPasses,
        'rica': rica,
        'cpe': cpe,
        'vouchers': vouchers,
        'hotspot_radius': hotspotRadius,
      };

  @override
  List<Object?> get props => [hotspotPasses, rica, cpe, vouchers, hotspotRadius];
}

/// Module keys, as named in the platform catalog (`plan_modules/catalog.py`).
abstract final class AppModuleKeys {
  static const vouchers = 'vouchers';
  static const tickets = 'tickets';
  static const credits = 'credits';
  static const wifiAware = 'wifi_aware';
  static const subscriberBilling = 'subscriber_billing';
}

/// Which modules the tenant has switched on. [reported] is false when the
/// server sent no `modules` member (an API older than v2).
class AppModules extends Equatable {
  const AppModules(this._enabled, {this.reported = true});

  static const none = AppModules({}, reported: false);

  final Map<String, bool> _enabled;

  /// False when the server sent no `modules` (an API older than v2).
  final bool reported;

  bool isOn(String key) => _enabled[key] == true;

  AppModules without(String key) => AppModules({..._enabled, key: false});

  factory AppModules.fromJson(Object? json) => json is Map
      ? AppModules({
          for (final MapEntry(:key, :value) in json.entries)
            if (key is String && value is bool) key: value,
        })
      : none;

  Map<String, bool> toJson() => Map.unmodifiable(_enabled);

  @override
  List<Object?> get props => [_enabled, reported];
}

/// The tenant's public support channels. Invalid values are dropped.
class SupportChannels extends Equatable {
  const SupportChannels({this.email, this.phone});

  static final _email = RegExp(r'^[^@\s]{1,64}@[^@\s]{1,190}\.[A-Za-z]{2,}$');
  static final _phone = RegExp(r'^\+?[0-9 ]{6,20}$');

  factory SupportChannels.fromJson(Object? json) {
    if (json is! Map) return const SupportChannels();
    final email = json['email'];
    final phone = json['phone'];
    return SupportChannels(
      email: email is String && _email.hasMatch(email) ? email : null,
      phone: phone is String && _phone.hasMatch(phone) ? phone : null,
    );
  }

  final String? email;
  final String? phone;

  Map<String, Object?> toJson() => {'email': email, 'phone': phone};

  @override
  List<Object?> get props => [email, phone];
}

/// Versions (YYYY-MM-DD) of the terms and privacy notice customers accept.
class LegalVersions extends Equatable {
  const LegalVersions({required this.terms, required this.privacy});

  factory LegalVersions.fromJson(Map<String, Object?> json) {
    final terms = json['terms'];
    final privacy = json['privacy'];
    if (terms is! String || privacy is! String) throw const FormatException('Malformed legal versions');
    return LegalVersions(terms: terms, privacy: privacy);
  }

  final String terms;
  final String privacy;

  Map<String, Object?> toJson() => {'terms': terms, 'privacy': privacy};

  @override
  List<Object?> get props => [terms, privacy];
}

/// `GET /v1/app-config?tenant=<slug>`.
class AppConfig extends Equatable {
  const AppConfig({
    required this.tenant,
    required this.minAppVersion,
    required this.featureFlags,
    required this.legal,
    this.modules = AppModules.none,
    this.support = const SupportChannels(),
    this.buyInApp = true,
  });

  factory AppConfig.fromJson(Map<String, Object?> json) {
    final tenant = json['tenant'];
    final minVersion = json['min_app_version'];
    final flags = json['feature_flags'];
    final legal = json['legal'];
    if (tenant is! Map || minVersion is! String || flags is! Map || legal is! Map) {
      throw const FormatException('Malformed app-config');
    }
    final collectionMode = json['collection_mode_public'];
    return AppConfig(
      tenant: Tenant.fromJson(Map<String, Object?>.from(tenant)),
      minAppVersion: minVersion,
      featureFlags: FeatureFlags.fromJson(Map<String, Object?>.from(flags)),
      legal: LegalVersions.fromJson(Map<String, Object?>.from(legal)),
      modules: AppModules.fromJson(json['modules']),
      support: SupportChannels.fromJson(json['support']),
      buyInApp: switch (collectionMode) {
        {'buy_in_app': final bool b} => b,
        _ => true,
      },
    );
  }

  final Tenant tenant;
  final String minAppVersion;
  final FeatureFlags featureFlags;
  final LegalVersions legal;
  final AppModules modules;
  final SupportChannels support;

  /// False when the provider collects payment itself (`isp_operated`).
  final bool buyInApp;

  /// The module switch for [key]. Before a v2 server reports modules, only
  /// `vouchers` is derived from the feature flag, and everything else is off.
  bool isModuleOn(String key) => modules.reported
      ? modules.isOn(key)
      : key == AppModuleKeys.vouchers && featureFlags.vouchers;

  AppConfig copyWithModules(AppModules m) => AppConfig(
        tenant: tenant,
        minAppVersion: minAppVersion,
        featureFlags: featureFlags,
        legal: legal,
        modules: m,
        support: support,
        buyInApp: buyInApp,
      );

  Map<String, Object?> toJson() => {
        'tenant': tenant.toJson(),
        'min_app_version': minAppVersion,
        'feature_flags': featureFlags.toJson(),
        'legal': legal.toJson(),
        if (modules.reported) 'modules': modules.toJson(),
        'support': support.toJson(),
        'collection_mode_public': {'buy_in_app': buyInApp},
      };

  @override
  List<Object?> get props => [tenant, minAppVersion, featureFlags, legal, modules, support, buyInApp];
}
