import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeRoute = FutureOr<FakeReply> Function(RequestOptions request);

class FakeReply {
  const FakeReply(this.status, [this.body, this.headers = const {}]) : errorType = null;

  const FakeReply.error(DioExceptionType this.errorType)
      : status = 0,
        body = null,
        headers = const {};

  factory FakeReply.problem(
    int status,
    String code, {
    String title = 'Problem',
    String? detail,
    String requestId = 'rid-test',
    Map<String, List<String>> headers = const {},
  }) =>
      FakeReply(
        status,
        {
          'type': 'about:blank',
          'title': title,
          'status': status,
          'code': code,
          'request_id': requestId,
          'detail': ?detail,
        },
        {
          'content-type': ['application/problem+json'],
          ...headers,
        },
      );

  final int status;
  final Object? body;
  final Map<String, List<String>> headers;
  final DioExceptionType? errorType;
}

/// In-memory stand-in for the network (ruling R-M4-4). Routes are matched on
/// method + path (query ignored); unmatched requests get a 404 problem.
class FakeHttpAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final _routes = <String, FakeRoute>{};

  void on(String method, String path, FakeRoute route) => _routes['${method.toUpperCase()} $path'] = route;

  List<RequestOptions> requestsTo(String method, String path) =>
      requests.where((r) => r.method == method.toUpperCase() && r.uri.path == path).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final route = _routes['${options.method} ${options.uri.path}'];
    final reply = route == null ? FakeReply.problem(404, 'http_404', title: 'Not Found') : await route(options);
    final errorType = reply.errorType;
    if (errorType != null) throw DioException(requestOptions: options, type: errorType);
    return ResponseBody.fromString(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.status,
      headers: {
        'content-type': ['application/json'],
        ...reply.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
