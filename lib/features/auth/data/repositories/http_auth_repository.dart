import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/network/token_refresher.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

/// Customer sign-in against the platform (M1 ruling R-M1-1: API-issued
/// RS256 tokens; the tenant slug travels in every auth request body).
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api, {required this._tokens, required this._tenant, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static final _sixDigits = RegExp(r'^\d{6}$');

  final ApiClient _api;
  final TokenStore _tokens;
  final TenantContext _tenant;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber}) async {
    final phone = normaliseZaMobile(phoneNumber);
    if (phone == null) {
      return const Left(ValidationFailure('Enter a valid South African mobile number.', 'invalid_phone'));
    }
    return _api.post<OtpChallenge>(
      '/v1/auth/otp/request',
      authenticated: false,
      body: {'tenant': _tenant.slug, 'phone': phone},
      decode: (data) {
        final map = data! as Map;
        return OtpChallenge(
          id: map['challenge_id']! as String,
          phoneE164: phone,
          expiresIn: Duration(seconds: map['expires_in_seconds']! as int),
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
      body: {'tenant': slug, 'challenge_id': challenge.id, 'code': code},
      decode: (data) => AuthTokens.fromTokenPair(Map<String, Object?>.from(data! as Map), tenantSlug: slug, now: _now()),
    );
    switch (result) {
      case Left(value: final failure):
        return Left(failure);
      case Right(value: final tokens):
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
        return _profile(fallbackPhone: '', clearTokensOnAnyFailure: false);
      case RefreshRejected():
        return const Left(UnauthorizedFailure());
      case RefreshUnavailable():
        return const Left(NetworkFailure());
    }
  }

  /// The server call is best effort and bounded; the local tokens are always
  /// forgotten. Only a failure to clear them (device storage) propagates, so
  /// the caller knows the device may still hold a session.
  @override
  Future<void> logOut() async {
    AuthTokens? tokens;
    try {
      tokens = await _tokens.read();
    } on Object {
      tokens = null; // cannot revoke what cannot be read; still forget it below
    }
    try {
      if (tokens != null) {
        await _api.post<Unit>(
          '/v1/auth/logout',
          body: {'refresh_token': tokens.refreshToken},
          timeout: const Duration(seconds: 5),
          decode: (_) => unit,
        );
      }
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<Either<Failure, User>> logIn({required String mobileNumber, required String password}) async =>
      const Left(ValidationFailure('Sign in with the one-time code we send to your phone.', 'password_login_removed'));

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
