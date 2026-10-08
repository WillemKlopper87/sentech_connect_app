import 'dart:ui' show Color;

import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/core/utils/tenant_slug.dart';

/// Public, per-tenant look (spec §12: branding is public and never holds
/// secrets). Reads color, logo and optional public Terms/privacy URLs.
/// Unknown branding fields are ignored.
class TenantBranding extends Equatable {
  const TenantBranding({
    this.primaryColor,
    this.logoUrl,
    this.termsUrl,
    this.privacyUrl,
    this.whatsAppNumber,
    this.secondaryColor,
    this.accentColor,
    this.logoAlt,
    this.appDisplayName,
    this.coolingOffUrl,
    this.serviceCharterUrl,
    this.complaintsUrl,
    this.paiaUrl,
  });

  static final _hex = RegExp(r'^#([0-9a-fA-F]{6})$');

  /// Longer logo URLs are ignored (they are never legitimate CDN links).
  static const maxLogoUrlLength = 2048;

  final Color? primaryColor;
  final Uri? logoUrl;
  final Uri? termsUrl;
  final Uri? privacyUrl;
  final String? whatsAppNumber;

  /// Second brand colour. Contrast is enforced by the theme, not here.
  final Color? secondaryColor;

  /// Parsed but not applied: no surface uses an accent colour yet (ruling).
  final Color? accentColor;

  /// Plain text for the logo's screen-reader label (1-120 chars once cleaned).
  final String? logoAlt;

  /// Plain text shown as the app title (1-40 chars once cleaned).
  final String? appDisplayName;
  final Uri? coolingOffUrl;
  final Uri? serviceCharterUrl;
  final Uri? complaintsUrl;
  final Uri? paiaUrl;

  /// Control characters and bidi overrides/isolates are removed from any
  /// server text that reaches the screen.
  static final _unsafeText = RegExp(
    r'[\u0000-\u001F\u007F\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );

  static String? _text(Object? value, int max) {
    if (value is! String) return null;
    final cleaned = value.replaceAll(_unsafeText, '').trim();
    return cleaned.isEmpty || cleaned.length > max ? null : cleaned;
  }

  /// `#rrggbb` only; anything else is ignored.
  static Color? _colour(Object? value) {
    if (value is! String) return null;
    final match = _hex.firstMatch(value);
    return match == null
        ? null
        : Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  static String _hexOf(Color colour) =>
      '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static String? validWhatsAppNumber(Object? value) =>
      value is String && RegExp(r'^\+27[0-9]{9}$').hasMatch(value)
      ? value
      : null;

  /// Matches the existing public legal URL contract (maximum 500 chars).
  static Uri? _legalUrl(Object? value) {
    if (value is! String ||
        value.length > 500 ||
        RegExp(r'\s').hasMatch(value)) {
      return null;
    }
    final uri = Uri.tryParse(value);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  factory TenantBranding.fromJson(Map<String, Object?> json) {
    final logo = json['logo_url'];
    Uri? parsedLogo;
    if (logo is String) {
      final uri = logo.length <= maxLogoUrlLength ? Uri.tryParse(logo) : null;
      // https only, a real host, and no embedded credentials (userinfo).
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty) {
        parsedLogo = uri;
      }
    }
    final legal = json['legal_urls'];
    return TenantBranding(
      primaryColor: _colour(json['primary_color']),
      logoUrl: parsedLogo,
      termsUrl: legal is Map ? _legalUrl(legal['terms']) : null,
      privacyUrl: legal is Map ? _legalUrl(legal['privacy']) : null,
      whatsAppNumber: validWhatsAppNumber(json['whatsapp_number']),
      secondaryColor: _colour(json['secondary_color']),
      accentColor: _colour(json['accent_color']),
      logoAlt: _text(json['logo_alt'], 120),
      appDisplayName: _text(json['app_display_name'], 40),
      coolingOffUrl: legal is Map ? _legalUrl(legal['cooling-off']) : null,
      serviceCharterUrl: legal is Map
          ? _legalUrl(legal['service-charter'])
          : null,
      complaintsUrl: legal is Map ? _legalUrl(legal['complaints']) : null,
      paiaUrl: legal is Map ? _legalUrl(legal['paia']) : null,
    );
  }

  Map<String, Object?> toJson() => {
    'whatsapp_number': ?validWhatsAppNumber(whatsAppNumber),
    if (primaryColor case final colour?) 'primary_color': _hexOf(colour),
    if (secondaryColor case final colour?) 'secondary_color': _hexOf(colour),
    if (accentColor case final colour?) 'accent_color': _hexOf(colour),
    if (logoUrl case final logo?) 'logo_url': logo.toString(),
    'logo_alt': ?logoAlt,
    'app_display_name': ?appDisplayName,
    if (termsUrl != null ||
        privacyUrl != null ||
        coolingOffUrl != null ||
        serviceCharterUrl != null ||
        complaintsUrl != null ||
        paiaUrl != null)
      'legal_urls': {
        if (termsUrl case final terms?) 'terms': terms.toString(),
        if (privacyUrl case final privacy?) 'privacy': privacy.toString(),
        if (coolingOffUrl case final url?) 'cooling-off': url.toString(),
        if (serviceCharterUrl case final url?)
          'service-charter': url.toString(),
        if (complaintsUrl case final url?) 'complaints': url.toString(),
        if (paiaUrl case final url?) 'paia': url.toString(),
      },
  };

  @override
  List<Object?> get props => [
    primaryColor,
    logoUrl,
    termsUrl,
    privacyUrl,
    whatsAppNumber,
    secondaryColor,
    accentColor,
    logoAlt,
    appDisplayName,
    coolingOffUrl,
    serviceCharterUrl,
    complaintsUrl,
    paiaUrl,
  ];
}

/// An ISP served by the platform (spec §12). Customers belong to one tenant.
class Tenant extends Equatable {
  const Tenant({
    required this.slug,
    required this.name,
    required this.type,
    this.branding = const TenantBranding(),
  });

  factory Tenant.fromJson(Map<String, Object?> json) {
    final slug = json['slug'];
    final name = json['name'];
    final type = json['type'];
    final branding = json['branding'];
    if (slug is! String || name is! String || type is! String) {
      throw const FormatException('Malformed tenant');
    }
    if (!slugPattern.hasMatch(slug)) {
      throw const FormatException('Malformed tenant slug');
    }
    if (name.isEmpty ||
        name.length > maxTextLength ||
        type.isEmpty ||
        type.length > maxTextLength) {
      throw const FormatException('Malformed tenant');
    }
    return Tenant(
      slug: slug,
      name: name,
      type: type,
      branding: branding is Map
          ? TenantBranding.fromJson(Map<String, Object?>.from(branding))
          : const TenantBranding(),
    );
  }

  /// Tenant slugs are lowercase letters, digits and hyphens (2-40 chars);
  /// the one regex lives in core (`tenantSlugPattern`).
  static final slugPattern = tenantSlugPattern;

  /// Longest accepted `name` / `type`.
  static const maxTextLength = 80;

  final String slug;
  final String name;

  /// `operator` (runs its own hotspots) or `reseller` (sells on a host network).
  final String type;
  final TenantBranding branding;

  bool get isReseller => type == 'reseller';

  Map<String, Object?> toJson() => {
    'slug': slug,
    'name': name,
    'type': type,
    'branding': branding.toJson(),
  };

  @override
  List<Object?> get props => [slug, name, type, branding];
}
