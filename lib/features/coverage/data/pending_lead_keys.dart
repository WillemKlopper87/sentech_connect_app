/// The idempotency key of a waiting-list sign-up whose outcome the app could not
/// learn (a lost response, a server error, "still processing", a rate limit). It
/// lives in memory only, never on disk, scoped by provider, and holds only the key
/// and a fingerprint of the request it belongs to, never the contact or the
/// address: it is what makes a retry after the sheet was closed the SAME request,
/// so the platform keeps one lead.
///
/// Cleared on success, on any final answer from the server, and on sign-out and
/// account erase (`DefaultPersonalDataWiper`).
class PendingLeadKeys {
  final _entries = <String, ({int fingerprint, String key})>{};

  ({int fingerprint, String key})? pendingFor(String scope) => _entries[scope];

  void put(String scope, int fingerprint, String key) => _entries[scope] = (fingerprint: fingerprint, key: key);

  void remove(String scope) => _entries.remove(scope);

  void clear() => _entries.clear();

  @override
  String toString() => 'PendingLeadKeys(${_entries.length})';
}
