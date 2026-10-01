import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';

/// Completes the customer's profile on the platform (`PATCH /v1/me/profile`:
/// display name and email). The installation address has no M1 endpoint and
/// stays in secure storage on the device via [local].
class HttpRegistrationRepository implements RegistrationRepository {
  HttpRegistrationRepository(this._api, {required this._local});

  final ApiClient _api;
  final RegistrationRepository _local;

  @override
  Future<Either<Failure, Unit>> save(RegistrationDetails details) async {
    final email = details.email.trim();
    final scope = await _api.captureScope();
    final result = await _api.patch<Unit>(
      '/v1/me/profile',
      body: {'display_name': details.fullName.trim(), if (email.isNotEmpty) 'email': email},
      decode: (_) => unit,
      scope: scope,
    );
    if (result.isLeft()) return result;
    // A sign-out or tenant switch during the PATCH wiped the device: do not
    // write the customer's details back after the wipe.
    if (!scope.isCurrent) return const Left(UnauthorizedFailure());
    return _local.save(details);
  }

  @override
  Future<Either<Failure, RegistrationDetails?>> getSaved() => _local.getSaved();

  @override
  Future<void> clear() => _local.clear();
}
