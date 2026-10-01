import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';

/// Debug builds against a local stack only (ruling R-M4-13): completes a
/// fake-gateway payment through `POST /v1/dev/payments/{id}/simulate`, an
/// endpoint the API registers only for env dev/test (never staging or
/// production). Not part of the domain.
class DevPaymentSimulator {
  DevPaymentSimulator(this._api);

  final ApiClient _api;

  Future<Either<Failure, String>> simulate({
    required String paymentId,
    required bool accepted,
  }) => _api.post<String>(
    '/v1/dev/payments/${Uri.encodeComponent(paymentId)}/simulate',
    body: {'outcome': accepted ? 'accepted' : 'declined'},
    decode: (data) => (data! as Map)['outcome']! as String,
  );
}
