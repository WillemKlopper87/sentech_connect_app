import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_problem.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/interceptors.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/network/token_refresher.dart';

typedef ResponseDecoder<T> = T Function(Object? data);

/// The only class that talks HTTP. Repositories call it with a path and a
/// decoder and get `Either<Failure, T>` back; transport concerns (tokens,
/// refresh, problem+json, ids, timeouts, logging) live here.
///
/// Threading: create ONE [ApiClient] (and one [TokenStore]) per process and
/// use it only from the main isolate. The in-memory token cache and the
/// single-flight refresh do not work across isolates, so a background isolate
/// would refresh with a stale token and trip the server's reuse detection.
///
/// Redirects are never followed: an API does not redirect, and following one
/// could move a bearer token to another origin. A 3xx is a [ServerFailure].
class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required TokenStore tokens,
    required this.tenant,
    required SessionEvents sessionEvents,
    HttpClientAdapter? adapter,
    ApiLog? log,
    DateTime Function()? now,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 20),
    List<Duration>? refreshRetryBackoff,
    Duration Function()? monotonic,
  }) {
    final options = BaseOptions(
      baseUrl: baseUrl.toString(),
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: receiveTimeout,
      headers: const {'Accept': 'application/json, application/problem+json'},
      contentType: Headers.jsonContentType,
      followRedirects: false,
    );
    final logger = log ?? _defaultLog;
    final refreshDio = Dio(options);
    _dio = Dio(options);
    if (adapter != null) {
      refreshDio.httpClientAdapter = adapter;
      _dio.httpClientAdapter = adapter;
    }
    refreshDio.interceptors.addAll([RequestIdInterceptor(), SafeLogInterceptor(logger)]);
    refresher = TokenRefresher(
      tokens: tokens,
      dio: refreshDio,
      sessionEvents: sessionEvents,
      now: now,
      monotonic: monotonic,
      retryBackoff: refreshRetryBackoff ?? const [Duration(milliseconds: 500), Duration(seconds: 1)],
    );
    _dio.interceptors.addAll([
      RequestIdInterceptor(),
      AuthInterceptor(baseUrl: baseUrl, tokens: tokens, tenant: tenant, refresher: refresher, dio: _dio, now: now),
      SafeLogInterceptor(logger),
    ]);
  }

  final TenantContext tenant;
  late final Dio _dio;
  late final TokenRefresher refresher;

  static void _defaultLog(String line) {
    if (kDebugMode) debugPrint(line);
  }

  Future<Either<Failure, T>> get<T>(
    String path, {
    required ResponseDecoder<T> decode,
    Map<String, Object?>? query,
    bool authenticated = true,
    Duration? timeout,
  }) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query, options: _options(authenticated, timeout, null)), decode);

  Future<Either<Failure, T>> post<T>(
    String path, {
    required ResponseDecoder<T> decode,
    Object? body,
    bool authenticated = true,
    String? idempotencyKey,
    Duration? timeout,
  }) =>
      _send(() => _dio.post<Object?>(path, data: body, options: _options(authenticated, timeout, idempotencyKey)), decode);

  Future<Either<Failure, T>> patch<T>(
    String path, {
    required ResponseDecoder<T> decode,
    Object? body,
    bool authenticated = true,
    Duration? timeout,
  }) =>
      _send(() => _dio.patch<Object?>(path, data: body, options: _options(authenticated, timeout, null)), decode);

  Future<Either<Failure, Unit>> delete(String path, {bool authenticated = true, Duration? timeout}) =>
      _send(() => _dio.delete<Object?>(path, options: _options(authenticated, timeout, null)), (_) => unit);

  Options _options(bool authenticated, Duration? timeout, String? idempotencyKey) => Options(
        extra: {kAuthenticated: authenticated},
        sendTimeout: timeout,
        receiveTimeout: timeout,
        headers: {'Idempotency-Key': ?idempotencyKey},
      );

  Future<Either<Failure, T>> _send<T>(Future<Response<Object?>> Function() call, ResponseDecoder<T> decode) async {
    final Response<Object?> response;
    try {
      response = await call();
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    }
    try {
      return Right(decode(response.data));
    } on Object {
      return const Left(ServerFailure('We received an unexpected response. Please try again.'));
    }
  }
}
