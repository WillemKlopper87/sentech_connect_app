import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/interceptors.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/network/token_refresher.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

/// Customer sign-in against the platform (M1 ruling R-M1-1: API-issued
/// RS256 tokens; the tenant slug travels in every auth request body).
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(
    this._api, {
    required this._tokens,
    required this._tenant,
    DateTime Function()? now,
    this.logoutTimeout = const Duration(seconds: 8),
  }) : _now = now ?? DateTime.now;

  static final _sixDigits = RegExp(r'^\d{6}$');

  /// Bounds the whole server-side revoke (including a proactive token
  /// refresh) so a sign-out or tenant switch never waits on a slow network.
  final Duration logoutTimeout;

  final ApiClient _api;
  final TokenStore _tokens;
  final TenantContext _tenant;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber, required String binding}) async {
    final phone = normaliseZaMobile(phoneNumber);
    if (phone == null) {
      return const Left(ValidationFailure('Enter a valid South African mobile number.', 'invalid_phone'));
    }
    return _api.post<OtpChallenge>(
      '/v1/auth/otp/request',
      authenticated: false,
      body: {'tenant': _tenant.slug, 'phone': phone, 'binding': binding},
      decode: (data) {
        final map = data! as Map;
        return OtpChallenge(
          id: map['challenge_id']! as String,
          phoneE164: phone,
          expiresIn: Duration(seconds: map['expires_in_seconds']! as int),
          binding: binding,
          reference: map['reference'] as String?,
        );
      },
    );
  }

  @override
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code}) async {
    if (!_sixDigits.hasMatch(code)) return const Left(ValidationFailure('Enter the 6-digit code.', 'invalid_code'));
    final slug = _tenant.slug;
    final result = await _api.post<AuthTokens>(
      '/v1/auth/otp/verify',
      authenticated: false,
      body: {'tenant': slug, 'challenge_id': challenge.id, 'code': code, 'binding': challenge.binding},
      decode: (data) => AuthTokens.fromTokenPair(Map<String, Object?>.from(data! as Map), tenantSlug: slug, now: _now()),
    );
    switch (result) {
      case Left(value: final failure):
        return Left(failure);
      case Right(value: final tokens):
        await _revokeReplacedSession(newCustomerId: tokens.customerId);
        await _tokens.write(tokens);
        // A brand-new sign-in is all or nothing: no tokens without a profile.
        return _profile(fallbackPhone: challenge.phoneE164, clearTokensOnAnyFailure: true);
    }
  }

  @override
  Future<Either<Failure, User>> resumeSession() async {
    final AuthTokens? tokens;
    try {
      tokens = await _tokens.read();
    } on Object {
      return const Left(UnauthorizedFailure()); // unreadable Keystore: the session is unusable
    }
    if (tokens == null) return const Left(UnauthorizedFailure());
    if (tokens.tenantSlug != _tenant.slug) {
      await _tokens.clear();
      return const Left(UnauthorizedFailure());
    }
    switch (await _api.refresher.refresh()) {
      case RefreshSucceeded():
        // The refresh proved the session; a profile that cannot be loaded
        // right now (offline blip) must not destroy it.
        final profile = await _profile(fallbackPhone: '', clearTokensOnAnyFailure: false);
        final user = profile.match((_) => null, (u) => u);
        if (user == null) return profile;
        // A logout (or another sign-in) that raced the profile request must
        // not be undone by the caller saving this session.
        final current = await _readTokens();
        if (current == null || current.customerId != user.id) return const Left(UnauthorizedFailure());
        return profile;
      case RefreshRejected():
        return const Left(UnauthorizedFailure());
      case RefreshUnavailable():
        return const Left(NetworkFailure());
    }
  }

  /// Server-side revoke is best effort and bounded by [logoutTimeout]: when
  /// the access token is (nearly) expired the session is refreshed FIRST so
  /// the logout carries the current refresh token (a rotated, spent one would
  /// only trip reuse detection), and it is skipped when the server cannot be
  /// reached (a limitation: the refresh family then stays valid until the
  /// server expires it). The local tokens are always forgotten; only a
  /// failure to clear device storage propagates.
  @override
  Future<void> logOut() async {
    try {
      await _revokeStored().timeout(logoutTimeout);
    } on Object {
      // Timeout or any transport surprise: still forget the tokens below.
    }
    await _tokens.clear();
  }

  @override
  Future<bool> sessionMatches({required String tenantSlug, required User user}) async {
    final tokens = await _readTokens();
    return tokens != null && tokens.tenantSlug == tenantSlug && tokens.customerId == user.id;
  }

  @override
  Future<void> discardLocalSession() => _tokens.clear();

  Future<AuthTokens?> _readTokens() async {
    try {
      return await _tokens.read();
    } on Object {
      return null; // unreadable Keystore: no usable session
    }
  }

  /// `POST /v1/auth/logout` for the stored session, if there is one for the
  /// active tenant. Never throws for network reasons. With [replaced] (the
  /// session is being overwritten by a new sign-in) nothing here may sign the
  /// app out: its rejection is not announced and the logout is sent with the
  /// bearer set by hand, outside the interceptor's refresh-and-expire path.
  Future<void> _revokeStored({bool replaced = false}) async {
    var tokens = await _readTokens();
    if (tokens == null || tokens.tenantSlug != _tenant.slug) return;
    if (tokens.expiresWithin(AuthInterceptor.refreshMargin, _now())) {
      switch (await _api.refresher.refresh(staleAccessToken: tokens.accessToken, announceExpiry: !replaced)) {
        case RefreshSucceeded(tokens: final fresh):
          tokens = fresh;
        case RefreshRejected():
          return; // the server already ended it
        case RefreshUnavailable():
          return; // cannot authenticate the revoke right now
      }
    }
    await _api.post<Unit>(
      '/v1/auth/logout',
      body: {'refresh_token': tokens.refreshToken},
      timeout: const Duration(seconds: 5),
      authenticated: !replaced,
      headers: replaced ? {'Authorization': 'Bearer ${tokens.accessToken}'} : null,
      decode: (_) => unit,
    );
  }

  /// Signing in as a different customer over a stored session: revoke the old
  /// customer's refresh family (best effort, bounded) before their tokens are
  /// overwritten, so it does not stay valid on the server.
  Future<void> _revokeReplacedSession({required String newCustomerId}) async {
    final previous = await _readTokens();
    if (previous == null || previous.customerId == newCustomerId) return;
    try {
      await _revokeStored(replaced: true).timeout(logoutTimeout);
    } on Object {
      // Best effort.
    }
  }

  Future<Either<Failure, User>> _profile({required String fallbackPhone, required bool clearTokensOnAnyFailure}) async {
    final result = await _api.get<User>(
      '/v1/me/profile',
      decode: (data) {
        final map = data! as Map;
        return User(
          id: map['id']! as String,
          fullName: (map['display_name'] as String?) ?? '',
          mobileNumber: (map['phone_e164'] as String?) ?? fallbackPhone,
        );
      },
    );
    final failure = result.match((f) => f, (_) => null);
    if (failure != null && (clearTokensOnAnyFailure || failure is UnauthorizedFailure)) await _tokens.clear();
    return result;
  }
}
