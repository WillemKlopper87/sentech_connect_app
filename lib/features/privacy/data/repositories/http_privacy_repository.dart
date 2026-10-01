import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/privacy_repository.dart';

/// POPIA s23/s24 and Play/App Store in-app deletion, via the platform.
class HttpPrivacyRepository implements PrivacyRepository {
  HttpPrivacyRepository(this._api, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> requestAccountDeletion() async {
    final result = await _api.delete('/v1/me', timeout: const Duration(seconds: 30));
    return result.map((_) {
      final at = _now().toUtc();
      return PrivacyRequestReceipt(reference: 'DEL-${at.millisecondsSinceEpoch}', requestedAt: at);
    });
  }

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> requestDataExport() => _api.get<PrivacyRequestReceipt>(
        '/v1/me/export',
        timeout: const Duration(seconds: 30),
        decode: (data) {
          final map = data! as Map;
          final generated = DateTime.parse(map['generated_at']! as String).toUtc();
          return PrivacyRequestReceipt(
            reference: 'EXP-${generated.millisecondsSinceEpoch}',
            requestedAt: generated,
            exportJson: const JsonEncoder.withIndent('  ').convert(map),
          );
        },
      );
}
