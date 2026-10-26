import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/privacy_repository.dart';

/// POPIA s23/s24 and Play/App Store in-app deletion, via the platform.
class HttpPrivacyRepository implements PrivacyRepository {
  HttpPrivacyRepository(
    this._api, {
    DateTime Function()? now,
    this._humanCheck = const NoHumanCheckProvider(),
  }) : _now = now ?? DateTime.now;

  static final _sixDigits = RegExp(r'^\d{6}$');

  final ApiClient _api;
  final DateTime Function() _now;
  final HumanCheckProvider _humanCheck;

  @override
  Future<Either<Failure, DeleteChallenge>> requestDeleteChallenge() async {
    // The human-check token is sent only when a provider has one. The default
    // provider has none, so the request has no body.
    final check = await acquireHumanCheck(_humanCheck);
    final checkFailure = check.match((f) => f, (_) => null);
    if (checkFailure != null) return Left(checkFailure);
    final humanCheck = check.match((_) => null, (t) => t);
    final result = await _api.post<DeleteChallenge>(
      '/v1/me/delete-challenge',
      body: humanCheck == null ? null : {'turnstile_token': humanCheck},
      timeout: const Duration(seconds: 30),
      scope: await _api.captureScope(),
      // A 401 here means "no phone on this account", not "signed out".
      keepSessionOn401: true,
      decode: (data) {
        final map = data! as Map;
        return DeleteChallenge(
          challengeId: map['challenge_id']! as String,
          expiresIn: Duration(seconds: map['expires_in_seconds']! as int),
          reference: map['reference'] as String?,
        );
      },
    );
    return result.mapLeft((failure) => failure is UnauthorizedFailure ? const DeleteCodeUnavailableFailure() : failure);
  }

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> deleteAccount({required String challengeId, required String code}) async {
    if (challengeId.isEmpty) return const Left(ReauthRequiredFailure());
    if (!_sixDigits.hasMatch(code)) return const Left(ValidationFailure('Enter the 6-digit code.', 'invalid_code'));
    final result = await _api.delete(
      '/v1/me',
      body: {'challenge_id': challengeId, 'code': code},
      timeout: const Duration(seconds: 30),
      scope: await _api.captureScope(),
    );
    return result.map((_) {
      final at = _now().toUtc();
      return PrivacyRequestReceipt(reference: 'DEL-${at.millisecondsSinceEpoch}', requestedAt: at);
    });
  }

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> requestDataExport() async => _api.get<PrivacyRequestReceipt>(
        '/v1/me/export',
        timeout: const Duration(seconds: 30),
        scope: await _api.captureScope(),
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
