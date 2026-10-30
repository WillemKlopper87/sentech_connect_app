import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_problem.dart';
import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';

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
    final f = failureFromDioException(_bad(409, _problem(409, 'something_else')));
    expect(f.message, 'Problem');
  });

  test('401 is an UnauthorizedFailure', () {
    expect(failureFromDioException(_bad(401, _problem(401, 'invalid_token'))), isA<UnauthorizedFailure>());
  });

  test('404 is a NotFoundFailure with the server detail', () {
    final f = failureFromDioException(_bad(404, _problem(404, 'thing_not_found', detail: 'Unknown order.')));
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
    expect(f.message, 'Something went wrong on our end.');
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

  group('headers', () {
    test('duplicated Retry-After and X-Request-ID headers never make the mapper throw (429)', () {
      final f = failureFromDioException(_bad(429, null, headers: {
        'retry-after': ['30', '60'],
        'x-request-id': ['a', 'b'],
      }));
      expect(f, isA<RateLimitedFailure>());
      expect((f as RateLimitedFailure).retryAfter, const Duration(seconds: 30));
    });

    test('duplicated headers never make the mapper throw (503)', () {
      final f = failureFromDioException(_bad(503, null, headers: {
        'retry-after': ['30', '60'],
        'x-request-id': ['rid-a', 'rid-b'],
      }));
      expect(f, isA<ServerFailure>());
      expect((f as ServerFailure).requestId, 'rid-a');
    });

    test('the X-Request-ID header is the request id when the body has none', () {
      final f = failureFromDioException(_bad(500, null, headers: {
        'X-Request-ID': ['hdr-1'],
      }));
      expect((f as ServerFailure).requestId, 'hdr-1');
    });

    test('the body request id wins over the header', () {
      final f = failureFromDioException(_bad(500, _problem(500, 'internal_error'), headers: {
        'x-request-id': ['hdr-1'],
      }));
      expect((f as ServerFailure).requestId, 'rid-123');
    });

    test('Retry-After is clamped to 0..1 hour and malformed values are ignored', () {
      Duration? retry(String value) {
        final f = failureFromDioException(_bad(429, null, headers: {
          'retry-after': [value],
        }));
        return (f as RateLimitedFailure).retryAfter;
      }

      expect(retry('60'), const Duration(seconds: 60));
      expect(retry(' 60 '), const Duration(seconds: 60));
      expect(retry('-5'), Duration.zero);
      expect(retry('999999'), const Duration(hours: 1));
      expect(retry('3600'), const Duration(hours: 1));
      expect(retry('abc'), isNull);
      expect(retry(''), isNull);
      // The HTTP-date form is deliberately not supported.
      expect(retry('Wed, 21 Oct 2026 07:28:00 GMT'), isNull);
    });

    test('429 without Retry-After has no retryAfter', () {
      final f = failureFromDioException(_bad(429, null));
      expect((f as RateLimitedFailure).retryAfter, isNull);
    });
  });

  group('statuses without a usable body', () {
    test('403 without a body is a ServerFailure with the generic message', () {
      final f = failureFromDioException(_bad(403, null));
      expect(f, isA<ServerFailure>());
      expect(f.message, 'Something went wrong on our end.');
    });

    test('403 with a problem body shows its detail', () {
      final f = failureFromDioException(_bad(403, _problem(403, 'forbidden', detail: 'Not yours.')));
      expect(f, isA<ServerFailure>());
      expect(f.message, 'Not yours.');
    });

    test('500 without a body is the generic ServerFailure', () {
      expect(failureFromDioException(_bad(500, null)), const ServerFailure());
    });

    test('404 without a body uses the default message', () {
      expect(failureFromDioException(_bad(404, null)), const NotFoundFailure());
    });

    test('429 without a body uses the default message', () {
      expect(failureFromDioException(_bad(429, null)).message, const RateLimitedFailure().message);
    });

    test('a bad response with no status code is treated as a server error', () {
      final request = RequestOptions(path: '/v1/x');
      final f = failureFromDioException(DioException(
        requestOptions: request,
        type: DioExceptionType.badResponse,
        response: Response<Object?>(requestOptions: request),
      ));
      expect(f, isA<ServerFailure>());
    });
  });

  group('user-facing text from the server is capped', () {
    final huge = 'x' * 5000;

    test('a huge validation detail is truncated with an ellipsis', () {
      final f = failureFromDioException(_bad(422, _problem(422, 'invalid_phone', detail: huge)));
      expect(f.message.length, 300);
      expect(f.message, endsWith('…'));
    });

    test('a huge title is truncated when there is no detail', () {
      final body = {..._problem(409, 'some_conflict'), 'title': huge};
      expect(failureFromDioException(_bad(409, body)).message.length, 300);
    });

    test('404 and 429 details are capped too', () {
      expect(failureFromDioException(_bad(404, _problem(404, 'thing_not_found', detail: huge))).message.length, 300);
      expect(failureFromDioException(_bad(429, _problem(429, 'rate_limited', detail: huge))).message.length, 300);
    });

    test('an emoji straddling the cut is dropped whole, never split', () {
      final detail = '${'x' * 298}\u{1F600}tail';
      final message = failureFromDioException(_bad(422, _problem(422, 'c', detail: detail))).message;
      expect(message, '${'x' * 298}…');
      // No lone surrogate anywhere in the result.
      expect(message.runes.every((r) => r < 0xD800 || r > 0xDFFF), isTrue);
    });

    test('an emoji that ends exactly at the cut is kept', () {
      final detail = '${'x' * 297}\u{1F600}tail';
      final message = failureFromDioException(_bad(422, _problem(422, 'c', detail: detail))).message;
      expect(message, '${'x' * 297}\u{1F600}…');
    });

    test('text at the limit is left alone', () {
      final exact = 'y' * 300;
      expect(failureFromDioException(_bad(422, _problem(422, 'c', detail: exact))).message, exact);
    });
  });

  test('a cancelled request maps to its own NetworkFailure', () {
    final f = failureFromDioException(
      DioException(requestOptions: RequestOptions(path: '/v1/x'), type: DioExceptionType.cancel),
    );
    expect(f, const NetworkFailure('The request was cancelled.'));
  });

  test('a transform timeout is a NetworkFailure', () {
    final f = failureFromDioException(
      DioException(requestOptions: RequestOptions(path: '/v1/x'), type: DioExceptionType.transformTimeout),
    );
    expect(f, isA<NetworkFailure>());
  });

  test('403 module_not_enabled names the module', () {
    final p = ApiProblem.tryParse(403, {'code': 'module_not_enabled', 'title': 'Forbidden', 'module': 'vouchers', 'request_id': 'r'});
    expect(failureFromStatus(403, p), const ModuleDisabledFailure('vouchers'));
  });

  test('a hostile module value is dropped', () {
    final p = ApiProblem.tryParse(403, {'code': 'module_not_enabled', 'title': 'F', 'module': '../x'});
    expect(failureFromStatus(403, p), const ModuleDisabledFailure());
  });

  test('the API client announces a refused module once', () async {
    final h = ApiHarness();
    h.adapter.on('GET', '/v1/me/entitlements', (_) => FakeReply(403,
        {'type': 'about:blank', 'title': 'Forbidden', 'status': 403, 'code': 'module_not_enabled',
         'request_id': 'r', 'module': 'vouchers'}, {'content-type': ['application/problem+json']}));
    final announced = expectLater(h.events.moduleRefused, emits('vouchers'));
    final result = await h.api.get<Object?>('/v1/me/entitlements', authenticated: false, decode: (d) => d);
    expect(result.isLeft(), isTrue);
    await announced;
  });

  test('409 collection_external is its own failure', () {
    final p = ApiProblem.tryParse(409, {'code': 'collection_external', 'title': 'Conflict', 'request_id': 'r'});
    expect(failureFromStatus(409, p), const CollectionExternalFailure());
  });

  test('another 409 stays a plain ValidationFailure', () {
    final p = ApiProblem.tryParse(409, {'code': 'order_not_payable', 'title': 'Conflict', 'request_id': 'r'});
    expect(failureFromStatus(409, p), isA<ValidationFailure>());
  });

  group('typed refusals of the platform', () {
    Failure map(int status, String code, {String? detail, Map<String, List<String>> headers = const {}}) =>
        failureFromDioException(_bad(status, _problem(status, code, detail: detail), headers: headers));

    test('422 binding_required', () {
      final f = map(422, 'binding_required', detail: 'Send a binding.');
      expect(f, isA<BindingRequiredFailure>());
      expect((f as ValidationFailure).code, 'binding_required');
      expect(f.messageIsDetail, isFalse, reason: 'the server wording is not shown');
    });

    test('403 human_verification_failed is not a generic server failure', () {
      expect(map(403, 'human_verification_failed'), isA<HumanVerificationFailedFailure>());
    });

    test('503 human_verification_unavailable keeps Retry-After', () {
      final f = map(503, 'human_verification_unavailable', headers: {'retry-after': ['45']});
      expect(f, const HumanVerificationUnavailableFailure(Duration(seconds: 45)));
      expect(map(503, 'human_verification_unavailable'), const HumanVerificationUnavailableFailure());
    });

    test('403 reauth_required', () {
      expect(map(403, 'reauth_required'), isA<ReauthRequiredFailure>());
    });

    test('503 sms_unavailable', () {
      expect(map(503, 'sms_unavailable', headers: {'retry-after': ['30']}), const SmsUnavailableFailure(Duration(seconds: 30)));
    });

    test('an unknown 503 stays a plain ServerFailure', () {
      expect(map(503, 'db_down'), isA<ServerFailure>());
    });

    test('422 consent_version_outdated', () {
      final f = map(422, 'consent_version_outdated');
      expect(f, isA<ConsentVersionOutdatedFailure>());
      expect((f as ValidationFailure).code, 'consent_version_outdated');
    });

    test('404 subscriber_not_found is a NotFoundFailure subtype; other 404s are not', () {
      expect(map(404, 'subscriber_not_found'), isA<SubscriberNotFoundFailure>());
      expect(map(404, 'subscriber_not_found'), isA<NotFoundFailure>());
      expect(map(404, 'order_not_found'), isNot(isA<SubscriberNotFoundFailure>()));
    });

    test('409 active_service_exists', () {
      final f = map(409, 'active_service_exists', detail: 'Cancel first.');
      expect(f, isA<ActiveServiceExistsFailure>());
      expect((f as ValidationFailure).code, 'active_service_exists');
    });

    test('409 order_not_payable stays a ValidationFailure with its code and keeps a server detail', () {
      final plain = map(409, 'order_not_payable');
      expect(plain, isA<OrderNotPayableFailure>());
      expect((plain as ValidationFailure).code, 'order_not_payable');
      expect(plain.messageIsDetail, isFalse);
      final detailed = map(409, 'order_not_payable', detail: 'Replaced by a newer order.');
      expect(detailed.message, 'Replaced by a newer order.');
      expect((detailed as ValidationFailure).messageIsDetail, isTrue);
    });
  });

  group('customer problem codes (parity audit row 15)', () {
    final refusals = <(int, String, Type)>[
      (409, 'feature_disabled', FeatureDisabledFailure),
      (409, 'order_not_cancellable', OrderNotCancellableFailure),
      (409, 'order_cancelled', OrderCancelledFailure),
      (409, 'support_contact_not_configured', SupportContactNotConfiguredFailure),
      (422, 'invalid_message', InvalidMessageFailure),
      (422, 'invalid_contact', InvalidContactFailure),
      (409, 'invoice_not_payable', InvoiceNotPayableFailure),
      (409, 'customer_link_required', CustomerLinkRequiredFailure),
      (422, 'subscriber_profile_invalid', SubscriberProfileInvalidFailure),
      (409, 'subscriber_plan_inactive', PlanUnavailableFailure),
      (409, 'subscriber_version_unavailable', PlanUnavailableFailure),
      (409, 'plan_kind_mismatch', PlanUnavailableFailure),
      (404, 'subscriber_plan_not_found', PlanUnavailableFailure),
      (409, 'account_closed', ServiceStateFailure),
      (409, 'illegal_transition', ServiceStateFailure),
      (409, 'no_active_entitlement', NoActiveEntitlementFailure),
      (422, 'mac_invalid', MacInvalidFailure),
      (422, 'nas_unavailable', NasUnavailableFailure),
      (422, 'login_url_invalid', LoginUrlInvalidFailure),
      (422, 'controller_not_supported', ControllerNotSupportedFailure),
    ];
    for (final (status, code, type) in refusals) {
      test('$status $code is a typed ValidationFailure that ignores the server wording', () {
        final f = failureFromDioException(_bad(status, _problem(status, code, detail: 'server words')));
        expect(f.runtimeType, type);
        expect(f, isA<ValidationFailure>());
        expect((f as ValidationFailure).code, code);
        expect(f.messageIsDetail, isFalse);
        expect(f.message, isNot(contains('server words')));
      });
    }

    test('404 order_not_found is a NotFoundFailure subtype', () {
      final f = failureFromDioException(_bad(404, _problem(404, 'order_not_found', detail: 'Unknown order.')));
      expect(f, isA<OrderNotFoundFailure>());
      expect(f, isA<NotFoundFailure>());
    });

    test('503 support_unavailable keeps Retry-After and is not a generic server failure', () {
      final f = failureFromDioException(_bad(503, _problem(503, 'support_unavailable'), headers: {'retry-after': ['30']}));
      expect(f, isA<SupportUnavailableFailure>());
      expect((f as SupportUnavailableFailure).retryAfter, const Duration(seconds: 30));
    });

    test('other 409/422 codes and a 5xx with these codes are unchanged', () {
      expect(failureFromDioException(_bad(409, _problem(409, 'something_else'))), isA<ValidationFailure>());
      expect(failureFromDioException(_bad(409, _problem(409, 'something_else'))), isNot(isA<FeatureDisabledFailure>()));
      expect(failureFromDioException(_bad(500, _problem(500, 'feature_disabled'))), isA<ServerFailure>());
    });

    test('order_not_payable keeps its server detail', () {
      final f = failureFromDioException(_bad(409, _problem(409, 'order_not_payable', detail: 'Paid already.')));
      expect(f.message, 'Paid already.');
    });
  });
}
