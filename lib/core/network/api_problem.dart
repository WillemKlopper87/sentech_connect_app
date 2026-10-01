import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sentech_connect_app/core/error/failure.dart';

/// An RFC 9457 problem body as the platform sends it
/// (`type`, `title`, `status`, `code`, `request_id`, optional `detail`).
class ApiProblem {
  const ApiProblem({required this.status, required this.code, required this.title, this.detail, this.requestId});

  final int status;
  final String code;
  final String title;
  final String? detail;
  final String? requestId;

  static ApiProblem? tryParse(int status, Object? data) {
    Object? body = data;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        return null;
      }
    }
    if (body is! Map) return null;
    final code = body['code'];
    final title = body['title'];
    if (code is! String || title is! String) return null;
    final detail = body['detail'];
    final requestId = body['request_id'];
    return ApiProblem(
      status: status,
      code: code,
      title: title,
      detail: detail is String ? detail : null,
      requestId: requestId is String ? requestId : null,
    );
  }
}

Failure failureFromDioException(DioException e) {
  if (e.error case final Failure failure) return failure;
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const NetworkFailure('The request was cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkFailure('We could not make a secure connection. Check your network and try again.');
    case DioExceptionType.badResponse:
      final response = e.response;
      final status = response?.statusCode ?? 500;
      final problem = ApiProblem.tryParse(status, response?.data);
      final seconds = int.tryParse(response?.headers.value('retry-after') ?? '');
      return failureFromStatus(
        status,
        problem,
        requestId: problem?.requestId ?? response?.headers.value('x-request-id'),
        retryAfter: seconds == null ? null : Duration(seconds: seconds),
      );
  }
}

/// 4xx details are written for customers by the API and are shown as-is;
/// 5xx text is never shown (it can carry internals).
Failure failureFromStatus(int status, ApiProblem? problem, {String? requestId, Duration? retryAfter}) {
  final detail = problem?.detail;
  if (status == 401) return const UnauthorizedFailure();
  if (status == 404) return NotFoundFailure(detail ?? 'We could not find that.');
  if (status == 429) return RateLimitedFailure(detail ?? 'Too many attempts. Please wait and try again.', retryAfter);
  if (status >= 500 || problem == null) return ServerFailure('Something went wrong on our end.', requestId);
  if (status == 403) return ServerFailure(detail ?? 'You are not allowed to do that.', requestId);
  return ValidationFailure(detail ?? problem.title, problem.code);
}
