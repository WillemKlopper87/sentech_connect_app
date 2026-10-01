import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

/// The tenant (ISP) the app is currently serving, plus the legal document
/// versions from its app-config. Set by `TenantCubit`; read by HTTP
/// repositories for `?tenant=` and request bodies.
class TenantContext {
  TenantContext({String slug = defaultSlug}) : _slug = _check(slug);

  static const defaultSlug = 'sentech';

  String _slug;

  String get slug => _slug;

  set slug(String value) => _slug = _check(value);

  String? termsVersion;
  String? privacyVersion;

  static String _check(String value) {
    if (!Tenant.slugPattern.hasMatch(value)) throw ArgumentError.value(value, 'slug', 'Invalid tenant slug');
    return value;
  }
}
