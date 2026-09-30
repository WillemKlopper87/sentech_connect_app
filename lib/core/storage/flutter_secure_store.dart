import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';

/// Keystore/Keychain-backed [SecureStore]. Reads never throw: a corrupt or
/// unreadable entry (e.g. after a restore onto a different device, where the
/// Keystore key no longer exists) is treated as "nothing stored" so the app
/// falls back to a signed-out state instead of crashing at launch.
class FlutterSecureStore implements SecureStore {
  FlutterSecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
