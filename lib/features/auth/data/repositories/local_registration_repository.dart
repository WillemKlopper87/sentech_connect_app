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

  /// Location-derived fields never written to the phone. The location notice
  /// (`consentLocationBody`) says the location is used once and not stored
  /// on the phone, and the address is often reverse-geocoded from GPS. The
  /// platform has no address endpoint yet, so the address lives only in
  /// memory for the registration screen; nothing in the app reads it back.
  static const _notKept = ['address', 'latitude', 'longitude'];

  @override
  Future<Either<Failure, Unit>> save(RegistrationDetails details) async {
    try {
      final json = details.toJson()..removeWhere((k, _) => _notKept.contains(k));
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
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (_notKept.any(json.containsKey)) {
        // Written by an earlier version: drop the address and coordinates
        // from the phone now.
        json.removeWhere((k, _) => _notKept.contains(k));
        await _store.write(_key, jsonEncode(json));
      }
      return Right(RegistrationDetails.fromJson(json));
    } catch (_) {
      return const Left(ServerFailure('Could not read your saved details.'));
    }
  }

  @override
  Future<void> clear() => _store.delete(_key);
}
