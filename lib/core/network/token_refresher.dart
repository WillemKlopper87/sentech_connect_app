import 'package:dio/dio.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';

sealed class RefreshOutcome {
  const RefreshOutcome();
}

final class RefreshSucceeded extends RefreshOutcome {
  const RefreshSucceeded(this.tokens);

  final AuthTokens tokens;
}

/// The server refused the refresh token: the session is over.
final class RefreshRejected extends RefreshOutcome {
  const RefreshRejected();
}

/// The refresh could not be completed (offline, timeout, 5xx, 408, 429).
/// The session is kept; the caller reports a NetworkFailure.
final class RefreshUnavailable extends RefreshOutcome {
  const RefreshUnavailable();
}

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

  Future<RefreshOutcome> _run(String? staleAccessToken) async {
    final current = await _tokens.read();
    if (current == null) return const RefreshRejected();
    if (staleAccessToken != null &&
        current.accessToken != staleAccessToken &&
        !current.expiresWithin(Duration.zero, _now())) {
      return RefreshSucceeded(current);
    }
    try {
      final response = await _dio.post<Object?>(
        path,
        data: {'tenant': current.tenantSlug, 'refresh_token': current.refreshToken},
      );
      final data = response.data;
      if (data is! Map) return const RefreshUnavailable();
      final fresh = AuthTokens.fromTokenPair(Map<String, Object?>.from(data), tenantSlug: current.tenantSlug, now: _now());
      await _tokens.write(fresh);
      return RefreshSucceeded(fresh);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500 && status != 408 && status != 429) {
        await _tokens.clear();
        _sessionEvents.sessionExpired();
        return const RefreshRejected();
      }
      return const RefreshUnavailable();
    } on FormatException {
      return const RefreshUnavailable();
    }
  }
}
