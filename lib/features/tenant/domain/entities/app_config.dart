import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

/// Per-tenant switches (spec §6: RICA/CPE off at launch). A missing flag is
/// treated as OFF, so an unfinished feature never appears by accident.
class FeatureFlags extends Equatable {
  const FeatureFlags({required this.hotspotPasses, required this.rica, required this.cpe});

  /// Demo flavor: everything the mock repositories can show is on.
  static const demo = FeatureFlags(hotspotPasses: true, rica: true, cpe: true);

  final bool hotspotPasses;
  final bool rica;
  final bool cpe;

  factory FeatureFlags.fromJson(Map<String, Object?> json) => FeatureFlags(
        hotspotPasses: json['hotspot_passes'] == true,
        rica: json['rica'] == true,
        cpe: json['cpe'] == true,
      );

  Map<String, Object?> toJson() => {'hotspot_passes': hotspotPasses, 'rica': rica, 'cpe': cpe};

  @override
  List<Object?> get props => [hotspotPasses, rica, cpe];
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
  const AppConfig({required this.tenant, required this.minAppVersion, required this.featureFlags, required this.legal});

  factory AppConfig.fromJson(Map<String, Object?> json) {
    final tenant = json['tenant'];
    final minVersion = json['min_app_version'];
    final flags = json['feature_flags'];
    final legal = json['legal'];
    if (tenant is! Map || minVersion is! String || flags is! Map || legal is! Map) {
      throw const FormatException('Malformed app-config');
    }
    return AppConfig(
      tenant: Tenant.fromJson(Map<String, Object?>.from(tenant)),
      minAppVersion: minVersion,
      featureFlags: FeatureFlags.fromJson(Map<String, Object?>.from(flags)),
      legal: LegalVersions.fromJson(Map<String, Object?>.from(legal)),
    );
  }

  final Tenant tenant;
  final String minAppVersion;
  final FeatureFlags featureFlags;
  final LegalVersions legal;

  Map<String, Object?> toJson() => {
        'tenant': tenant.toJson(),
        'min_app_version': minAppVersion,
        'feature_flags': featureFlags.toJson(),
        'legal': legal.toJson(),
      };

  @override
  List<Object?> get props => [tenant, minAppVersion, featureFlags, legal];
}
