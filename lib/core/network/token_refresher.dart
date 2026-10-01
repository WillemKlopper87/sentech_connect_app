import 'package:dio/dio.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_problem.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';

sealed class RefreshOutcome {
  const RefreshOutcome();
}

final class RefreshSucceeded extends RefreshOutcome {
  const RefreshSucceeded(this.tokens);

  final AuthTokens tokens;
}

/// The session is over: the server refused the refresh token, the stored
/// session could not be read, or it was cleared/replaced while refreshing.
final class RefreshRejected extends RefreshOutcome {
  const RefreshRejected();
}

/// The refresh could not be completed (offline, timeout, 5xx, 408, 429, a
/// WAF page, a malformed body, ...). The session is kept; the original
/// request fails with [failure].
final class RefreshUnavailable extends RefreshOutcome {
  const RefreshUnavailable([this.failure = const NetworkFailure()]);

  final Failure failure;
}

/// Problem `code`s on a 400/403 that mean the refresh token itself is dead.
const _rejectionCodes = {'invalid_refresh_token', 'refresh_token_reused', 'refresh_token_expired'};

/// Single-flight token refresh. Refresh tokens rotate and reuse revokes the
/// whole family on the server, so two parallel refreshes with the same
/// token would sign the customer out: every caller shares one in-flight
/// refresh, and a caller holding an already-replaced access token gets the
/// new tokens without another network call.
///
/// Every refresh call carries an `Idempotency-Key` (the platform returns the
/// SAME new token pair to a repeat of the same refresh token + key within
/// 60 s). That makes a lost response recoverable: if the server rotated the
/// token but the reply never arrived, the retry with the same key gets the
/// new pair instead of tripping reuse detection (which revokes the family).
/// One key is generated per refresh token and reused for every retry of it
/// (inside one operation, and across operations while the token is still
/// unrotated and the key is younger than [keyReuseWindow]); a rotated token
/// always gets a fresh key. The key is never logged.
class TokenRefresher {
  TokenRefresher({
    required this._tokens,
    required this._dio,
    required this._sessionEvents,
    DateTime Function()? now,
    String Function()? newKey,
    this.retryBackoff = const [Duration(milliseconds: 500), Duration(seconds: 1)],
    this.keyReuseWindow = const Duration(seconds: 50),
  }) : _now = now ?? DateTime.now,
       _newKey = newKey ?? newIdempotencyKey;

  static const path = '/v1/auth/token/refresh';

  /// Pauses before each in-operation retry of a transient failure (timeout,
  /// connection error, 502/503/504); its length is the retry count.
  final List<Duration> retryBackoff;

  /// Kept below the server's 60 s replay window, measured from the first
  /// attempt (the server cannot have committed before it).
  final Duration keyReuseWindow;

  final TokenStore _tokens;
  final Dio _dio;
  final SessionEvents _sessionEvents;
  final DateTime Function() _now;
  final String Function() _newKey;
  Future<RefreshOutcome>? _inFlight;
  String? _keyedToken;
  String? _key;
  DateTime? _keyIssuedAt;

  /// [staleAccessToken] is the token the caller used; pass null to force a
  /// network refresh (e.g. to prove a stored session is still valid).
  Future<RefreshOutcome> refresh({String? staleAccessToken}) {
    final running = _inFlight;
    if (running != null) return running;
    final next = _run(staleAccessToken).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = next;
    return next;
  }

  /// Ends the local session because the server no longer accepts it (or it
  /// cannot be read): clears the tokens (best effort, a storage failure must
  /// not swallow the event) and tells the app to sign out.
  Future<void> expireSession() async {
    try {
      await _tokens.clear();
    } on Object {
      // Best effort: the in-memory state is already cleared by the store.
    }
    _sessionEvents.sessionExpired();
  }

  Future<RefreshOutcome> _run(String? staleAccessToken) async {
    final AuthTokens? current;
    try {
      current = await _tokens.read();
    } on Object {
      // Keystore read failure: the session is unusable, so end it cleanly
      // instead of reporting "offline" forever.
      await expireSession();
      return const RefreshRejected();
    }
    if (current == null) return const RefreshRejected();
    // Captured with no await since the read: see TokenStore.generation.
    final generation = _tokens.generation;
    if (staleAccessToken != null &&
        current.accessToken != staleAccessToken &&
        !current.expiresWithin(Duration.zero, _now())) {
      return RefreshSucceeded(current);
    }
    try {
      // The server rotates the refresh token. If it rotated but the reply was
      // lost, the retry (same token, same Idempotency-Key) returns the same
      // new pair. Only an app kill between the two attempts (the key is in
      // memory) or a gap over the server's replay window still looks like
      // token reuse and ends the session.
      final response = await _post(current, _keyFor(current.refreshToken), generation);
      final data = response.data;
      if (data is! Map) return const RefreshUnavailable(ServerFailure('We received an unexpected response. Please try again.'));
      final fresh = AuthTokens.fromTokenPair(Map<String, Object?>.from(data), tenantSlug: current.tenantSlug, now: _now());
      // Logged out (or signed in again) while the request was in flight:
      // never write the old session's tokens back. No await before write.
      if (_tokens.generation != generation) return const RefreshRejected();
      await _tokens.write(fresh);
      _forgetKey();
      return RefreshSucceeded(fresh);
    } on DioException catch (e) {
      if (_isRejection(e)) {
        _forgetKey();
        if (_tokens.generation == generation) await expireSession();
        return const RefreshRejected();
      }
      return RefreshUnavailable(failureFromDioException(e));
    } on FormatException {
      return const RefreshUnavailable(ServerFailure('We received an unexpected response. Please try again.'));
    } on Object {
      return const RefreshUnavailable();
    }
  }

  Future<Response<Object?>> _post(AuthTokens current, String key, int generation) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _dio.post<Object?>(
          path,
          data: {'tenant': current.tenantSlug, 'refresh_token': current.refreshToken},
          options: Options(headers: {'Idempotency-Key': key}),
        );
      } on DioException catch (e) {
        if (attempt >= retryBackoff.length || !_isTransient(e)) rethrow;
        final pause = retryBackoff[attempt];
        // A retry sent after the replay window would be treated as reuse.
        if (_now().difference(_keyIssuedAt ?? _now()) + pause >= keyReuseWindow) rethrow;
        await Future<void>.delayed(pause);
        if (_tokens.generation != generation) rethrow; // signed out meanwhile
      }
    }
  }

  String _keyFor(String refreshToken) {
    final issuedAt = _keyIssuedAt;
    final existing = _key;
    if (existing != null && _keyedToken == refreshToken && issuedAt != null && _now().difference(issuedAt) < keyReuseWindow) {
      return existing;
    }
    _keyedToken = refreshToken;
    _keyIssuedAt = _now();
    return _key = _newKey();
  }

  void _forgetKey() {
    _keyedToken = null;
    _key = null;
    _keyIssuedAt = null;
  }

  /// No response at all (timeout, dropped connection) or a gateway error:
  /// the server may or may not have rotated, which the key makes safe.
  static bool _isTransient(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        return status == 502 || status == 503 || status == 504;
      default:
        return false; // incl. bad certificate (never retried), cancel, unknown
    }
  }

  /// Only a 401, or a 400/403 whose problem `code` names a dead refresh token,
  /// ends the session. Everything else (404, 422, 5xx, 408, 429, WAF/HTML
  /// bodies, redirects) is an outage, not a logout.
  static bool _isRejection(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) return true;
    if (status != 400 && status != 403) return false;
    final problem = ApiProblem.tryParse(status!, e.response?.data);
    return problem != null && _rejectionCodes.contains(problem.code);
  }
}
