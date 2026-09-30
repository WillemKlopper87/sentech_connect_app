import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';

class LocalRegistrationRepository implements RegistrationRepository {
  LocalRegistrationRepository(this._store);

  static const _key = 'registration_details';

  final SecureStore _store;

  @override
  Future<Either<Failure, Unit>> save(RegistrationDetails details) async {
    try {
      // GPS coordinates are only needed transiently (coverage check); the
      // typed/geocoded address is what a backend would receive, so the
      // coordinates are deliberately not persisted.
      final json = details.toJson()
        ..remove('latitude')
        ..remove('longitude');
      await _store.write(_key, jsonEncode(json));
      return Right(unit);
    } catch (_) {
      return const Left(ServerFailure('Could not save your details on this device.'));
    }
  }

  @override
  Future<Either<Failure, RegistrationDetails?>> getSaved() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null) return const Right(null);
      return Right(RegistrationDetails.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (_) {
      return const Left(ServerFailure('Could not read your saved details.'));
    }
  }

  @override
  Future<void> clear() => _store.delete(_key);
}
