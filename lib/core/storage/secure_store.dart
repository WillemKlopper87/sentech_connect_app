/// Key/value storage for anything personal or security-relevant (session,
/// registration details, consent records). Backed by the Android Keystore /
/// iOS Keychain in production ([FlutterSecureStore]); [InMemorySecureStore]
/// is used in tests. Non-sensitive settings (theme, language) stay in
/// SharedPreferences via `AppPreferences`.
abstract class SecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> deleteAll();
}

/// Volatile implementation for tests (and as a safe fallback where no
/// platform keystore exists). Nothing is persisted.
class InMemorySecureStore implements SecureStore {
  InMemorySecureStore([Map<String, String>? seed]) : _data = {...?seed};

  final Map<String, String> _data;

  Map<String, String> get snapshot => Map.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();
}
