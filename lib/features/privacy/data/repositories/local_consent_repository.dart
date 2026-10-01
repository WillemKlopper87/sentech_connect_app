import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/privacy/privacy_constants.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';

class LocalConsentRepository implements ConsentRepository {
  LocalConsentRepository(this._store, {DateTime Function()? now, String? policyVersion})
      : _now = now ?? DateTime.now,
        _policyVersion = policyVersion ?? privacyPolicyVersion;

  static const _key = 'consent_records';

  final SecureStore _store;
  final DateTime Function() _now;
  final String _policyVersion;

  Future<Map<ConsentPurpose, ConsentRecord>> _load() async {
    final raw = await _store.read(_key);
    if (raw == null) return {};
    try {
      final records = (jsonDecode(raw) as List)
          .map((e) => ConsentRecord.fromJson(e as Map<String, dynamic>))
          .whereType<ConsentRecord>();
      return {for (final r in records) r.purpose: r};
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<ConsentPurpose, ConsentRecord> records) =>
      _store.write(_key, jsonEncode(records.values.map((r) => r.toJson()).toList()));

  @override
  Future<Either<Failure, ConsentRecord?>> currentConsent(ConsentPurpose purpose) async {
    final record = (await _load())[purpose];
    if (record == null || record.policyVersion != _policyVersion) return const Right(null);
    return Right(record);
  }

  @override
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose) async {
    try {
      final records = await _load();
      final record = ConsentRecord(
        purpose: purpose,
        policyVersion: _policyVersion,
        grantedAt: _now().toUtc(),
      );
      records[purpose] = record;
      await _save(records);
      return Right(record);
    } catch (_) {
      return const Left(ServerFailure('Could not save your consent on this device.'));
    }
  }

  @override
  Future<Either<Failure, Unit>> withdraw(ConsentPurpose purpose) async {
    try {
      final records = await _load();
      if (records.remove(purpose) != null) await _save(records);
      return const Right(unit);
    } catch (_) {
      return const Left(ServerFailure('Could not save your choice on this device.'));
    }
  }

  @override
  Future<List<ConsentRecord>> unsyncedRecords() async =>
      (await _load()).values.where((r) => !r.synced).toList();

  @override
  Future<void> markSynced(Iterable<ConsentRecord> synced) async {
    final records = await _load();
    for (final s in synced) {
      final existing = records[s.purpose];
      if (existing != null && existing.grantedAt == s.grantedAt) {
        records[s.purpose] = existing.copyWith(synced: true);
      }
    }
    await _save(records);
  }

  @override
  Future<void> clear() => _store.delete(_key);
}
