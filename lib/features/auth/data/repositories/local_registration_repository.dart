import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';

class LocalRegistrationRepository implements RegistrationRepository {
  static const _prefsKey = 'sentech_registration_details';

  @override
  Future<Either<Failure, Unit>> save(RegistrationDetails details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(details.toJson()));
      return Right(unit);
    } catch (_) {
      return const Left(ServerFailure('Could not save your details on this device.'));
    }
  }

  @override
  Future<Either<Failure, RegistrationDetails?>> getSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return const Right(null);
      return Right(RegistrationDetails.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (_) {
      return const Left(ServerFailure('Could not read your saved details.'));
    }
  }
}
