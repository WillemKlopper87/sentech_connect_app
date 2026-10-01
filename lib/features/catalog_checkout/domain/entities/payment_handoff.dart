import 'package:equatable/equatable.dart';

enum PaymentHandoffMethod { get, post }

/// Where the customer pays (spec §4: hosted redirect; card data never
/// touches the app or the platform). GET = open [url] with [fields] as the
/// query; POST = submit [fields] as a form to [url].
class PaymentHandoff extends Equatable {
  const PaymentHandoff({
    required this.paymentId,
    required this.reference,
    required this.gateway,
    required this.method,
    required this.url,
    this.fields = const {},
    required this.amountCents,
  });

  /// Demo flavor: confirmed instantly, nothing to open.
  static const demoGateway = 'demo';

  /// The platform's fake gateway (local stack / tests).
  static const fakeGateway = 'fake';

  final String paymentId;
  final String reference;
  final String gateway;
  final PaymentHandoffMethod method;
  final Uri url;
  final Map<String, String> fields;
  final int amountCents;

  bool get isDemo => gateway == demoGateway;

  bool get isFakeGateway => gateway == fakeGateway;

  @override
  List<Object?> get props => [
    paymentId,
    reference,
    gateway,
    method,
    url,
    fields,
    amountCents,
  ];
}
