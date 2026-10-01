import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';

/// Terms, privacy and SMS-marketing consents live in the platform's
/// versioned, append-only ledger (spec §8 POPIA); device-only consents
/// (location, RICA capture) stay in [local].
///
/// Every ledger write carries a STABLE `Idempotency-Key`
/// (`app-consent-<tenant>-<purpose>-<version>`, plus a suffix naming the
/// earlier ledger entry it follows when the customer changes their mind), so a
/// double tap, a retry or a lost response can never add a second row. Writes
/// first read the latest decision: a purpose that is already in the wanted
/// state is not written again.
class HttpConsentRepository implements ConsentRepository {
  HttpConsentRepository(
    this._api, {
    required this._local,
    required this._tenant,
  });

  static const _legalVersionsMissing = ValidationFailure('We could not load the legal documents. Try again.', 'legal_versions_missing');

  final ApiClient _api;
  final ConsentRepository _local;
  final TenantContext _tenant;

  // Concurrent calls for the same purpose share one operation.
  final _grants = <ConsentPurpose, Future<Either<Failure, ConsentRecord>>>{};
  final _withdrawals = <ConsentPurpose, Future<Either<Failure, Unit>>>{};

  /// There is no separate marketing version: SMS marketing is recorded against
  /// the tenant's privacy-notice version (Task 8 ruling: the platform has no
  /// separate marketing version).
  String? _currentVersion(ConsentPurpose purpose) =>
      purpose == ConsentPurpose.terms ? _tenant.termsVersion : _tenant.privacyVersion;

  static Future<T> _shared<T>(Map<ConsentPurpose, Future<T>> running, ConsentPurpose purpose, Future<T> Function() run) {
    final existing = running[purpose];
    if (existing != null) return existing;
    return running[purpose] = run().whenComplete(() {
      running.remove(purpose);
    });
  }

  /// The latest decision per purpose.
  Future<Either<Failure, Map<String, _LedgerEntry>>> _ledger() => _api.get<Map<String, _LedgerEntry>>(
        '/v1/me/consents',
        decode: (data) {
          final items = ((data! as Map)['items']! as List).cast<Map<Object?, Object?>>();
          return {for (final i in items) i['purpose']! as String: _LedgerEntry.fromServer(i)};
        },
      );

  @override
  Future<Either<Failure, ConsentRecord?>> currentConsent(ConsentPurpose purpose) async {
    final name = purpose.apiName;
    if (name == null) return _local.currentConsent(purpose);
    final version = _currentVersion(purpose);
    if (version == null) return const Right(null);
    return (await _ledger()).map((ledger) {
      final entry = ledger[name];
      if (entry == null || !entry.granted || entry.version != version) return null;
      return entry.toRecord(purpose);
    });
  }

  @override
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose) {
    if (purpose.apiName == null) return _local.grant(purpose);
    return _shared(_grants, purpose, () => _grant(purpose));
  }

  Future<Either<Failure, ConsentRecord>> _grant(ConsentPurpose purpose) async {
    final name = purpose.apiName!;
    final version = _currentVersion(purpose);
    if (version == null) return const Left(_legalVersionsMissing);
    final ledger = await _ledger();
    final failure = ledger.match((f) => f, (_) => null);
    if (failure != null) return Left(failure);
    final entry = ledger.getOrElse((_) => const {})[name];
    if (entry != null && entry.granted && entry.version == version) return Right(entry.toRecord(purpose));

    // First grant of this version: the plain stable key. After a withdrawal
    // of the same version the key names that withdrawal, so a re-grant is a
    // new operation instead of a replay of the first grant.
    final base = _baseKey(name, version);
    final afterWithdrawal = entry != null && !entry.granted && entry.version == version;
    return _api.post<ConsentRecord>(
      '/v1/me/consents',
      body: {'purpose': name, 'version': version, 'granted': true, 'source': 'app'},
      idempotencyKey: afterWithdrawal ? '$base-after-${entry.recordedAt.millisecondsSinceEpoch}' : base,
      decode: (data) => _LedgerEntry.fromServer(data! as Map).toRecord(purpose),
    );
  }

  @override
  Future<Either<Failure, Unit>> withdraw(ConsentPurpose purpose) {
    if (purpose.apiName == null) return _local.withdraw(purpose);
    return _shared(_withdrawals, purpose, () => _withdraw(purpose));
  }

  Future<Either<Failure, Unit>> _withdraw(ConsentPurpose purpose) async {
    final name = purpose.apiName!;
    final version = _currentVersion(purpose);
    if (version == null) return const Left(_legalVersionsMissing);
    final ledger = await _ledger();
    final failure = ledger.match((f) => f, (_) => null);
    if (failure != null) return Left(failure);
    final entry = ledger.getOrElse((_) => const {})[name];
    if (entry == null || !entry.granted) return const Right(unit); // nothing is granted: already as wanted
    return _api.post<Unit>(
      '/v1/me/consents',
      body: {'purpose': name, 'version': version, 'granted': false, 'source': 'app'},
      idempotencyKey: '${_baseKey(name, version)}-withdraw-${entry.recordedAt.millisecondsSinceEpoch}',
      decode: (_) => unit,
    );
  }

  String _baseKey(String name, String version) => 'app-consent-${_tenant.slug}-$name-$version';

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

class _LedgerEntry {
  const _LedgerEntry({required this.version, required this.granted, required this.recordedAt});

  factory _LedgerEntry.fromServer(Map<Object?, Object?> map) => _LedgerEntry(
        version: map['version']! as String,
        granted: map['granted']! as bool,
        recordedAt: DateTime.parse(map['recorded_at']! as String).toUtc(),
      );

  final String version;
  final bool granted;
  final DateTime recordedAt;

  ConsentRecord toRecord(ConsentPurpose purpose) =>
      ConsentRecord(purpose: purpose, policyVersion: version, grantedAt: recordedAt, synced: true);
}
