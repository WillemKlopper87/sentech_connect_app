import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';

/// Terms, privacy and SMS-marketing consents live in the platform's
/// versioned ledger (spec §8 POPIA); device-only consents (location, RICA
/// capture) stay in [local].
class HttpConsentRepository implements ConsentRepository {
  HttpConsentRepository(
    this._api, {
    required this._local,
    required this._tenant,
    String Function()? newKey,
  }) : _newKey = newKey ?? newIdempotencyKey;

  final ApiClient _api;
  final ConsentRepository _local;
  final TenantContext _tenant;
  final String Function() _newKey;

  String? _currentVersion(ConsentPurpose purpose) =>
      purpose == ConsentPurpose.terms ? _tenant.termsVersion : _tenant.privacyVersion;

  @override
  Future<Either<Failure, ConsentRecord?>> currentConsent(ConsentPurpose purpose) async {
    final name = purpose.apiName;
    if (name == null) return _local.currentConsent(purpose);
    final version = _currentVersion(purpose);
    if (version == null) return const Right(null);
    return _api.get<ConsentRecord?>(
      '/v1/me/consents',
      decode: (data) {
        final items = ((data! as Map)['items']! as List).cast<Map<Object?, Object?>>();
        final item = items.where((i) => i['purpose'] == name).firstOrNull;
        if (item == null || item['granted'] != true || item['version'] != version) return null;
        return ConsentRecord(
          purpose: purpose,
          policyVersion: version,
          grantedAt: DateTime.parse(item['recorded_at']! as String).toUtc(),
          synced: true,
        );
      },
    );
  }

  @override
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose) async {
    final name = purpose.apiName;
    if (name == null) return _local.grant(purpose);
    final version = _currentVersion(purpose);
    if (version == null) {
      return const Left(ValidationFailure('We could not load the legal documents. Try again.', 'legal_versions_missing'));
    }
    return _api.post<ConsentRecord>(
      '/v1/me/consents',
      body: {'purpose': name, 'version': version, 'granted': true, 'source': 'app'},
      idempotencyKey: _newKey(),
      decode: (data) {
        final map = data! as Map;
        return ConsentRecord(
          purpose: purpose,
          policyVersion: map['version']! as String,
          grantedAt: DateTime.parse(map['recorded_at']! as String).toUtc(),
          synced: true,
        );
      },
    );
  }

  /// Server-held consents are written synchronously; device-only ones never
  /// sync. Nothing is ever pending.
  @override
  Future<List<ConsentRecord>> unsyncedRecords() async => const [];

  @override
  Future<void> markSynced(Iterable<ConsentRecord> records) => _local.markSynced(records);

  /// Clears the device copy; the server ledger is the audit trail and goes
  /// with `DELETE /v1/me`.
  @override
  Future<void> clear() => _local.clear();
}
