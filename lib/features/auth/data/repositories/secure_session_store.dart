import 'dart:convert';

import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore(this._store);

  static const _userKey = 'session_user';
  static const _credentialKey = 'session_biometric_credential';

  final SecureStore _store;

  @override
  Future<User?> loadUser() async {
    final raw = await _store.read(_userKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return User(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? '',
        mobileNumber: json['mobileNumber'] as String? ?? '',
      );
    } catch (_) {
      await _store.delete(_userKey); // unreadable record: start signed out
      return null;
    }
  }

  @override
  Future<void> saveUser(User user, {required String tenantSlug}) => _store.write(
        _userKey,
        jsonEncode({
          'id': user.id,
          'fullName': user.fullName,
          'mobileNumber': user.mobileNumber,
          'tenantSlug': tenantSlug,
          'customerId': user.id,
        }),
      );

  @override
  Future<SessionBinding?> loadBinding() async {
    final raw = await _store.read(_userKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final slug = json['tenantSlug'];
      final customer = json['customerId'];
      return slug is String && customer is String ? SessionBinding(tenantSlug: slug, customerId: customer) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> loadBiometricCredential() => _store.read(_credentialKey);

  @override
  Future<void> saveBiometricCredential(String credential) => _store.write(_credentialKey, credential);

  @override
  Future<void> clearAll() async {
    await _store.delete(_userKey);
    await _store.delete(_credentialKey);
  }
}
