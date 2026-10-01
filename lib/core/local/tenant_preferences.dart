import 'package:shared_preferences/shared_preferences.dart';

/// The chosen tenant and its last app-config. Both are public, non-personal
/// data (spec §12: branding is public), so SharedPreferences is fine.
abstract class TenantPreferences {
  Future<String?> loadSlug();

  Future<void> saveSlug(String slug);

  Future<String?> loadConfigJson();

  Future<void> saveConfigJson(String json);

  Future<void> clear();
}

class SharedPrefsTenantPreferences implements TenantPreferences {
  static const _slugKey = 'pref_tenant_slug';
  static const _configKey = 'pref_tenant_app_config';

  @override
  Future<String?> loadSlug() async => (await SharedPreferences.getInstance()).getString(_slugKey);

  @override
  Future<void> saveSlug(String slug) async => (await SharedPreferences.getInstance()).setString(_slugKey, slug);

  @override
  Future<String?> loadConfigJson() async => (await SharedPreferences.getInstance()).getString(_configKey);

  @override
  Future<void> saveConfigJson(String json) async => (await SharedPreferences.getInstance()).setString(_configKey, json);

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_slugKey);
    await prefs.remove(_configKey);
  }
}

class InMemoryTenantPreferences implements TenantPreferences {
  InMemoryTenantPreferences({this.slug, this.configJson});

  String? slug;
  String? configJson;

  @override
  Future<String?> loadSlug() async => slug;

  @override
  Future<void> saveSlug(String value) async => slug = value;

  @override
  Future<String?> loadConfigJson() async => configJson;

  @override
  Future<void> saveConfigJson(String json) async => configJson = json;

  @override
  Future<void> clear() async {
    slug = null;
    configJson = null;
  }
}
