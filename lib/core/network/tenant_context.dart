import 'package:sentech_connect_app/core/utils/tenant_slug.dart';

/// The tenant (ISP) the app is currently serving, plus the legal document
/// versions from its app-config. Set by `TenantCubit`; read by HTTP
/// repositories for `?tenant=` and request bodies.
class TenantContext {
  TenantContext({String slug = defaultSlug}) : _slug = _check(slug);

  static const defaultSlug = 'sentech';

  String _slug;
  int _generation = 0;

  /// Also detects changing away and back during a pending operation.
  int get generation => _generation;

  String get slug => _slug;

  set slug(String value) {
    final checked = _check(value);
    if (checked != _slug) _generation++;
    _slug = checked;
  }

  String? termsVersion;
  String? privacyVersion;

  static String _check(String value) {
    if (!tenantSlugPattern.hasMatch(value)) {
      throw ArgumentError.value(value, 'slug', 'Invalid tenant slug');
    }
    return value;
  }
}
