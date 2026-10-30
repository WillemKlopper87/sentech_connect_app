import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

/// `SubscriberSignupOut`: the new `pending` service and its initial invoice
/// (prorated first month plus setup fee). A replay of the same request answers
/// the same pair.
class SubscriberSignup extends Equatable {
  const SubscriberSignup({required this.service, required this.invoice});

  final SubscriberService service;
  final SubscriberInvoice invoice;

  @override
  List<Object?> get props => [service, invoice];
}
