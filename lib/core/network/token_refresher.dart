import 'package:dio/dio.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_problem.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
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
class TokenRefresher {
  TokenRefresher({required this._tokens, required this._dio, required this._sessionEvents, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const path = '/v1/auth/token/refresh';

  final TokenStore _tokens;
  final Dio _dio;
  final SessionEvents _sessionEvents;
  final DateTime Function() _now;
  Future<RefreshOutcome>? _inFlight;

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
      // KNOWN FAILURE MODE: the server rotates the refresh token. If this
      // request succeeds on the server but the response is lost (connection
      // drops, app killed), the stored token is already spent and the next
      // refresh is treated as reuse, which revokes the session family. That
      // needs an idempotent/grace-window refresh on the platform; the app
      // cannot tell the two cases apart.
      final response = await _dio.post<Object?>(
        path,
        data: {'tenant': current.tenantSlug, 'refresh_token': current.refreshToken},
      );
      final data = response.data;
      if (data is! Map) return const RefreshUnavailable(ServerFailure('We received an unexpected response. Please try again.'));
      final fresh = AuthTokens.fromTokenPair(Map<String, Object?>.from(data), tenantSlug: current.tenantSlug, now: _now());
      // Logged out (or signed in again) while the request was in flight:
      // never write the old session's tokens back. No await before write.
      if (_tokens.generation != generation) return const RefreshRejected();
      await _tokens.write(fresh);
      return RefreshSucceeded(fresh);
    } on DioException catch (e) {
      if (_isRejection(e)) {
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
