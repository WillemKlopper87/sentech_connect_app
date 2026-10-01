import 'dart:ui' show Color;

import 'package:equatable/equatable.dart';

/// Public, per-tenant look (spec §12: branding is public and never holds
/// secrets). Only `primary_color` (#RRGGBB) and `logo_url` (https) are read
/// (ruling R-M4-6); anything else is ignored.
class TenantBranding extends Equatable {
  const TenantBranding({this.primaryColor, this.logoUrl});

  static final _hex = RegExp(r'^#([0-9a-fA-F]{6})$');

  /// Longer logo URLs are ignored (they are never legitimate CDN links).
  static const maxLogoUrlLength = 2048;

  final Color? primaryColor;
  final Uri? logoUrl;

  factory TenantBranding.fromJson(Map<String, Object?> json) {
    final colour = json['primary_color'];
    final logo = json['logo_url'];
    Color? parsedColour;
    if (colour is String) {
      final match = _hex.firstMatch(colour);
      if (match != null) parsedColour = Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
    }
    Uri? parsedLogo;
    if (logo is String) {
      final uri = logo.length <= maxLogoUrlLength ? Uri.tryParse(logo) : null;
      // https only, a real host, and no embedded credentials (userinfo).
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty) parsedLogo = uri;
    }
    return TenantBranding(primaryColor: parsedColour, logoUrl: parsedLogo);
  }

  Map<String, Object?> toJson() => {
        if (primaryColor case final colour?)
          'primary_color': '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        if (logoUrl case final logo?) 'logo_url': logo.toString(),
      };

  @override
  List<Object?> get props => [primaryColor, logoUrl];
}

/// An ISP served by the platform (spec §12). Customers belong to one tenant.
class Tenant extends Equatable {
  const Tenant({required this.slug, required this.name, required this.type, this.branding = const TenantBranding()});

  factory Tenant.fromJson(Map<String, Object?> json) {
    final slug = json['slug'];
    final name = json['name'];
    final type = json['type'];
    final branding = json['branding'];
    if (slug is! String || name is! String || type is! String) throw const FormatException('Malformed tenant');
    if (!slugPattern.hasMatch(slug)) throw const FormatException('Malformed tenant slug');
    if (name.isEmpty || name.length > maxTextLength || type.isEmpty || type.length > maxTextLength) {
      throw const FormatException('Malformed tenant');
    }
    return Tenant(
      slug: slug,
      name: name,
      type: type,
      branding: branding is Map ? TenantBranding.fromJson(Map<String, Object?>.from(branding)) : const TenantBranding(),
    );
  }

  /// Tenant slugs are lowercase letters, digits and hyphens (2-40 chars).
  static final slugPattern = RegExp(r'^[a-z0-9-]{2,40}$');

  /// Longest accepted `name` / `type`.
  static const maxTextLength = 80;

  final String slug;
  final String name;

  /// `operator` (runs its own hotspots) or `reseller` (sells on a host network).
  final String type;
  final TenantBranding branding;

  bool get isReseller => type == 'reseller';

  Map<String, Object?> toJson() => {'slug': slug, 'name': name, 'type': type, 'branding': branding.toJson()};

  @override
  List<Object?> get props => [slug, name, type, branding];
}
