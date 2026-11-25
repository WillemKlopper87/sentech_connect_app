import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';

/// The idempotency key of a waiting-list sign-up that may not have been settled (it was sent and
/// the outcome is unknown, or it was held back and could be tried again). It lives in memory
/// only, never on disk, and is wiped on sign-out and account erase (`DefaultPersonalDataWiper`).
///
/// The scope is the provider, the place (rounded to 5 decimals) and the technology: NOTHING the
/// customer typed (contact, address) is stored or hashed, so the holder cannot leak or confirm a
/// contact. A key is therefore only a hint: when it meets a request the platform sees as a
/// different one it refuses it (`idempotency_key_reused`) and the cubit replaces it once.
///
/// [unknown] is true when the sign-up may have reached the platform (lost response, server
/// error, still processing); false when it was not sent (security check down, rate limit).
class PendingLeadKeys {
  final _entries = <String, ({String key, bool unknown})>{};

  /// `tenant|lat,lon|technology` with the place rounded to 5 decimals (about 1 m).
  static String scopeFor(String tenant, double lat, double lon, TechnologyInterest interest) =>
      '$tenant|${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}|${switch (interest) {
        TechnologyInterest.any => 'any',
        TechnologyInterest.fiveG => '5g',
        TechnologyInterest.lte => 'lte',
      }}';

  ({String key, bool unknown})? pendingFor(String scope) => _entries[scope];

  void put(String scope, String key, {required bool unknown}) => _entries[scope] = (key: key, unknown: unknown);

  void remove(String scope) => _entries.remove(scope);

  void clear() => _entries.clear();

  @override
  String toString() => 'PendingLeadKeys(${_entries.length})';
}
