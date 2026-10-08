import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sentech_connect_app/core/error/failure.dart';

/// An RFC 9457 problem body as the platform sends it
/// (`type`, `title`, `status`, `code`, `request_id`, optional `detail`).
/// A module key is lower-case letters and underscores only (1-40 chars).
final _moduleKey = RegExp(r'^[a-z_]{1,40}$');

class ApiProblem {
  const ApiProblem({required this.status, required this.code, required this.title, this.detail, this.requestId, this.module});

  final int status;
  final String code;
  final String title;
  final String? detail;
  final String? requestId;

  /// The module a 403 `module_not_enabled` names; null unless it is a valid key.
  final String? module;

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
    final module = body['module'];
    return ApiProblem(
      status: status,
      code: code,
      title: title,
      detail: detail is String ? detail : null,
      requestId: requestId is String ? requestId : null,
      module: module is String && _moduleKey.hasMatch(module) ? module : null,
    );
  }
}

/// Longest server-written text (problem `detail`/`title`) shown to a customer.
const _maxUserText = 300;

/// `Retry-After` is clamped to this range so a hostile or buggy server cannot
/// ask the app to wait forever (or a negative time).
const _maxRetryAfter = Duration(hours: 1);

String _capped(String text) {
  if (text.length <= _maxUserText) return text;
  var end = _maxUserText - 1;
  // Never split a UTF-16 surrogate pair: drop a trailing high surrogate.
  final last = text.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return '${text.substring(0, end)}\u2026';
}

/// First value of a header, or null. Never `Headers.value()`: that throws when
/// a proxy or CDN duplicates the header.
String? _firstHeader(Headers? headers, String name) {
  final values = headers?[name];
  return values == null || values.isEmpty ? null : values.first;
}

/// Only the delta-seconds form is supported; the HTTP-date form and anything
/// malformed are ignored (no Retry-After hint).
Duration? _parseRetryAfter(String? raw) {
  final seconds = int.tryParse(raw?.trim() ?? '');
  if (seconds == null) return null;
  final delay = Duration(seconds: seconds.clamp(0, _maxRetryAfter.inSeconds));
  return delay;
}

/// Maps any [DioException] to a [Failure]. Must never throw.
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
      return failureFromStatus(
        status,
        problem,
        requestId: problem?.requestId ?? _firstHeader(response?.headers, 'x-request-id'),
        retryAfter: _parseRetryAfter(_firstHeader(response?.headers, 'retry-after')),
      );
  }
}

/// 4xx details are written for customers by the API and are shown (capped to
/// 300 characters); 5xx text is never shown (it can carry internals).
///
/// Semantic caveats, kept deliberately: a 403, or any 4xx without a problem
/// body (e.g. an HTML gateway page), becomes a [ServerFailure] even though it
/// is not strictly a server fault, and unknown transport errors become
/// [NetworkFailure].
Failure failureFromStatus(int status, ApiProblem? problem, {String? requestId, Duration? retryAfter}) {
  final detail = problem?.detail == null ? null : _capped(problem!.detail!);
  if (status == 401) return const UnauthorizedFailure();
  if (status == 404) return NotFoundFailure(detail ?? 'We could not find that.');
  if (status == 429) return RateLimitedFailure(detail ?? 'Too many attempts. Please wait and try again.', retryAfter);
  if (status >= 500 || problem == null) return ServerFailure('Something went wrong on our end.', requestId);
  if (status == 403 && problem.code == 'tenant_suspended') return const ProviderUnavailableFailure();
  if (status == 403 && (problem.code == 'module_not_enabled' || problem.code == 'module_disabled')) {
    return ModuleDisabledFailure(problem.module);
  }
  if (status == 403) return ServerFailure(detail ?? 'You are not allowed to do that.', requestId);
  return ValidationFailure(detail ?? _capped(problem.title), problem.code, detail != null);
}
