import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/invoice_json.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/subscriber_json.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';

/// `/v1/me/subscriber/invoices*`. All calls need a session.
class HttpInvoiceRepository implements InvoiceRepository {
  HttpInvoiceRepository(this._api);

  /// A customer has few invoices; 5 pages of 50 covers any realistic account.
  static const pageSize = 50;
  static const maxPages = 5;

  final ApiClient _api;

  @override
  Future<Either<Failure, List<SubscriberInvoice>>> list({bool openOnly = false}) async {
    final result = await fetchAllPages<SubscriberInvoice>(
      _api,
      path: '/v1/me/subscriber/invoices',
      cursorParam: 'after',
      item: subscriberInvoiceFromJson,
      scope: await _api.captureScope(),
      authenticated: true,
      query: {if (openOnly) 'status': 'open'},
      pageSize: pageSize,
      maxPages: maxPages,
    );
    return result.match(
      (failure) => failure is SubscriberNotFoundFailure ? const Right([]) : Left(failure),
      Right.new,
    );
  }

  @override
  Future<Either<Failure, SubscriberInvoice>> get(String id) async => _api.get<SubscriberInvoice>(
    '/v1/me/subscriber/invoices/${Uri.encodeComponent(id)}',
    scope: await _api.captureScope(),
    decode: (data) => subscriberInvoiceFromJson(Map<String, Object?>.from(data! as Map)),
  );

  @override
  Future<Either<Failure, PaymentHandoff>> startCheckout(String id, {required String idempotencyKey}) async =>
      _api.post<PaymentHandoff>(
        '/v1/me/subscriber/invoices/${Uri.encodeComponent(id)}/checkout',
        scope: await _api.captureScope(),
        idempotencyKey: idempotencyKey,
        timeout: const Duration(seconds: 30),
        decode: (data) {
          final handoff = paymentHandoffFromJson(Map<String, Object?>.from(data! as Map));
          // 'demo' is the mock repository's marker and skips URL validation;
          // a real server must never be able to use it.
          if (handoff.isDemo) throw const FormatException('Unexpected demo gateway from the API');
          return handoff;
        },
      );
}
