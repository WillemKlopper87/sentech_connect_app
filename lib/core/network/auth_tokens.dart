import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';

/// The customer's API session. Lives only in secure storage (Keystore /
/// Keychain); [toString] never prints token values.
class AuthTokens extends Equatable {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.customerId,
    required this.tenantSlug,
  });

  /// From a `TokenPairOut` body (`/v1/auth/otp/verify`, `/v1/auth/token/refresh`).
  factory AuthTokens.fromTokenPair(Map<String, Object?> json, {required String tenantSlug, required DateTime now}) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final expiresIn = json['expires_in'];
    final customerId = json['customer_id'];
    if (access is! String || refresh is! String || expiresIn is! int || customerId is! String) {
      throw const FormatException('Malformed token pair');
    }
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: now.toUtc().add(Duration(seconds: expiresIn)),
      customerId: customerId,
      tenantSlug: tenantSlug,
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final String customerId;

  /// Tokens are only valid for the tenant that issued them.
  final String tenantSlug;

  bool expiresWithin(Duration margin, DateTime now) => !now.toUtc().add(margin).isBefore(accessExpiresAt);

  Map<String, Object?> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessExpiresAt': accessExpiresAt.toUtc().toIso8601String(),
        'customerId': customerId,
        'tenantSlug': tenantSlug,
      };

  static AuthTokens? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final expiresRaw = json['accessExpiresAt'];
    final expires = expiresRaw is String ? DateTime.tryParse(expiresRaw) : null;
    final customer = json['customerId'];
    final tenant = json['tenantSlug'];
    if (access is! String || refresh is! String || expires == null || customer is! String || tenant is! String) return null;
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: expires.toUtc(),
      customerId: customer,
      tenantSlug: tenant,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, accessExpiresAt, customerId, tenantSlug];

  @override
  String toString() => 'AuthTokens(customer: $customerId, tenant: $tenantSlug, expires: $accessExpiresAt)';
}

abstract class TokenStore {
  /// Bumped by every [write] and [clear]. A refresh captures it when it starts
  /// and discards its result if it changed, so a logout (or a new sign-in)
  /// during an in-flight refresh is never overwritten by the stale tokens.
  int get generation;

  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

/// [TokenStore] on [SecureStore], cached in memory so every request does not
/// hit the Keystore. An unreadable record is deleted (start signed out).
class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._store);

  static const key = 'auth_tokens';

  final SecureStore _store;
  AuthTokens? _cache;
  var _loaded = false;
  var _generation = 0;

  @override
  int get generation => _generation;

  @override
  Future<AuthTokens?> read() async {
    if (_loaded) return _cache;
    final raw = await _store.read(key);
    AuthTokens? parsed;
    if (raw != null) {
      try {
        parsed = AuthTokens.tryFromJson(jsonDecode(raw));
      } on FormatException {
        parsed = null;
      }
      if (parsed == null) await _store.delete(key);
    }
    _cache = parsed;
    _loaded = true;
    return parsed;
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    _generation++;
    _cache = tokens;
    _loaded = true;
    await _store.write(key, jsonEncode(tokens.toJson()));
  }

  @override
  Future<void> clear() async {
    _generation++;
    _cache = null;
    _loaded = true;
    await _store.delete(key);
  }
}
