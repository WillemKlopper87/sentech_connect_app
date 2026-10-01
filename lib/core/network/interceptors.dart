import 'package:dio/dio.dart';
import 'package:sentech_connect_app/core/diagnostics/pii_scrubber.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/network/token_refresher.dart';

/// `RequestOptions.extra` keys.
const kAuthenticated = 'sc.authenticated';
const kRetried = 'sc.retried';
const _kStopwatch = 'sc.stopwatch';

typedef ApiLog = void Function(String line);

/// First value of a header. Never `Headers.value()`: it throws when a proxy
/// or CDN duplicates the header, which would fail the whole request.
String? _firstHeader(Headers? headers, String name) {
  final values = headers?[name];
  return values == null || values.isEmpty ? null : values.first;
}

/// Adds an `X-Request-ID` (kept on retries) for log correlation.
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor([String Function()? newId]) : _newId = newId ?? newRequestId;

  final String Function() _newId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Request-ID', _newId);
    handler.next(options);
  }
}

/// Bearer tokens for `authenticated` requests: proactive refresh shortly
/// before expiry, one refresh + one retry on 401, and never a token issued
/// for a different tenant than the one currently selected.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._tokens,
    required this._tenant,
    required this._refresher,
    required this._dio,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const refreshMargin = Duration(seconds: 30);

  final TokenStore _tokens;
  final TenantContext _tenant;
  final TokenRefresher _refresher;
  final Dio _dio;
  final DateTime Function() _now;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[kAuthenticated] != true) {
      handler.next(options);
      return;
    }
    var tokens = await _tokens.read();
    if (tokens == null || tokens.tenantSlug != _tenant.slug) {
      handler.reject(DioException(requestOptions: options, error: const UnauthorizedFailure()));
      return;
    }
    if (tokens.expiresWithin(refreshMargin, _now())) {
      switch (await _refresher.refresh(staleAccessToken: tokens.accessToken)) {
        case RefreshSucceeded(tokens: final fresh):
          tokens = fresh;
        case RefreshRejected():
          handler.reject(DioException(requestOptions: options, error: const UnauthorizedFailure()));
          return;
        case RefreshUnavailable():
          break; // try the current token; the server decides
      }
    }
    options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final eligible = err.response?.statusCode == 401 &&
        options.extra[kAuthenticated] == true &&
        options.extra[kRetried] != true;
    if (!eligible) {
      handler.next(err);
      return;
    }
    final sent = options.headers['Authorization'];
    final stale = sent is String && sent.startsWith('Bearer ') ? sent.substring(7) : null;
    switch (await _refresher.refresh(staleAccessToken: stale)) {
      case RefreshSucceeded():
        options.extra[kRetried] = true;
        try {
          handler.resolve(await _dio.fetch<Object?>(options));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      case RefreshRejected():
        handler.next(err);
      case RefreshUnavailable():
        handler.next(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'token refresh unavailable',
        ));
    }
  }
}

/// One line per request: method, path (no query), outcome, duration and
/// request id. Never headers or bodies (tokens, phone numbers, OTPs), and
/// the line is passed through PiiScrubber as a safety net.
class SafeLogInterceptor extends Interceptor {
  SafeLogInterceptor(this._log);

  final ApiLog _log;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_kStopwatch] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _log(_line(response.requestOptions, '${response.statusCode}', _firstHeader(response.headers, 'x-request-id')));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = _firstHeader(err.response?.headers, 'x-request-id') ?? err.requestOptions.headers['X-Request-ID'];
    _log(_line(err.requestOptions, '${err.response?.statusCode ?? err.type.name}', requestId is String ? requestId : null));
    handler.next(err);
  }

  String _line(RequestOptions options, String outcome, String? requestId) {
    final stopwatch = options.extra[_kStopwatch];
    final ms = stopwatch is Stopwatch ? stopwatch.elapsedMilliseconds : -1;
    return PiiScrubber.scrub('[api] ${options.method} ${options.uri.path} -> $outcome ${ms}ms rid=${requestId ?? '-'}');
  }
}
