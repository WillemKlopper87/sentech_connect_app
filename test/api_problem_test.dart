import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_problem.dart';

DioException _bad(int status, Object? data, {Map<String, List<String>> headers = const {}}) {
  final request = RequestOptions(path: '/v1/x');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: request,
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers),
    ),
  );
}

Map<String, Object?> _problem(int status, String code, {String? detail}) => {
      'type': 'about:blank',
      'title': 'Problem',
      'status': status,
      'code': code,
      'request_id': 'rid-123',
      'detail': ?detail,
    };

void main() {
  test('422 maps to a ValidationFailure carrying detail and code', () {
    final f = failureFromDioException(_bad(422, _problem(422, 'invalid_phone', detail: 'Enter a valid South African mobile number.')));
    expect(f, isA<ValidationFailure>());
    expect(f.message, 'Enter a valid South African mobile number.');
    expect((f as ValidationFailure).code, 'invalid_phone');
  });

  test('400 otp_invalid is a ValidationFailure with that code', () {
    final f = failureFromDioException(_bad(400, _problem(400, 'otp_invalid', detail: 'The code is invalid or has expired.')));
    expect((f as ValidationFailure).code, 'otp_invalid');
  });

  test('a validation problem without detail falls back to its title', () {
    final f = failureFromDioException(_bad(409, _problem(409, 'order_not_payable')));
    expect(f.message, 'Problem');
  });

  test('401 is an UnauthorizedFailure', () {
    expect(failureFromDioException(_bad(401, _problem(401, 'invalid_token'))), isA<UnauthorizedFailure>());
  });

  test('404 is a NotFoundFailure with the server detail', () {
    final f = failureFromDioException(_bad(404, _problem(404, 'order_not_found', detail: 'Unknown order.')));
    expect(f, isA<NotFoundFailure>());
    expect(f.message, 'Unknown order.');
  });

  test('429 is a RateLimitedFailure honouring Retry-After', () {
    final f = failureFromDioException(_bad(429, _problem(429, 'rate_limited'), headers: {
      'retry-after': ['60'],
    }));
    expect(f, isA<RateLimitedFailure>());
    expect((f as RateLimitedFailure).retryAfter, const Duration(seconds: 60));
  });

  test('5xx never shows server text but keeps the request id for support', () {
    final f = failureFromDioException(_bad(503, _problem(503, 'internal_error', detail: 'stack trace here')));
    expect(f, isA<ServerFailure>());
    expect(f.message, isNot(contains('stack')));
    expect((f as ServerFailure).requestId, 'rid-123');
  });

  test('a problem body delivered as a String is still parsed', () {
    final f = failureFromDioException(_bad(422, '{"title":"Bad","code":"no_changes","detail":"Send a field."}'));
    expect((f as ValidationFailure).code, 'no_changes');
  });

  test('non-problem error bodies fall back to ServerFailure', () {
    expect(failureFromDioException(_bad(400, '<html>gateway</html>')), isA<ServerFailure>());
  });

  test('timeouts, connection errors and unknown transport errors are NetworkFailure', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.unknown,
    ]) {
      expect(
        failureFromDioException(DioException(requestOptions: RequestOptions(path: '/v1/x'), type: type)),
        isA<NetworkFailure>(),
        reason: type.name,
      );
    }
  });

  test('a bad certificate is a NetworkFailure, never silently accepted', () {
    final f = failureFromDioException(
      DioException(requestOptions: RequestOptions(path: '/v1/x'), type: DioExceptionType.badCertificate),
    );
    expect(f, isA<NetworkFailure>());
    expect(f.message, contains('secure'));
  });

  test('a Failure attached by an interceptor is passed through unchanged', () {
    final f = failureFromDioException(DioException(requestOptions: RequestOptions(path: '/v1/x'), error: const UnauthorizedFailure()));
    expect(f, const UnauthorizedFailure());
  });
}
