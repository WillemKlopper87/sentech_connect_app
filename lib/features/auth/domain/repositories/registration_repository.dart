import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';

/// Real implementation posts to the BSS/CRM registration endpoint; this
/// phase persists locally only (see docs/prompt-critique.md — no backend
/// exists yet, this mirrors the "local device storage" decision for the
/// registration data specifically).
abstract class RegistrationRepository {
  Future<Either<Failure, Unit>> save(RegistrationDetails details);

  Future<Either<Failure, RegistrationDetails?>> getSaved();
}
