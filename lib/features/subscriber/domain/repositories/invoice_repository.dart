import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';

abstract class InvoiceRepository {
  /// All invoices in the API's order (newest first; the app never sorts).
  /// [openOnly] sends `status=open`. No account is an empty list.
  Future<Either<Failure, List<SubscriberInvoice>>> list({bool openOnly = false});

  /// One invoice with its lines. [NotFoundFailure] for another account's.
  Future<Either<Failure, SubscriberInvoice>> get(String id);

  /// Starts (or reuses) the hosted payment for an open invoice. The same
  /// [idempotencyKey] on a retry of the same attempt is safe.
  Future<Either<Failure, PaymentHandoff>> startCheckout(String id, {required String idempotencyKey});
}
