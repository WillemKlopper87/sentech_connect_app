/// The idempotency key of a redeem whose outcome the app could not learn (a
/// lost response, a server error, "still processing", a rate limit). It lives
/// in memory only, never on disk, and is scoped by provider and customer
/// (the caller builds [scope] from both). It is what makes a retry after the
/// customer left the Redeem page the SAME request, so the server returns the
/// original pass instead of spending twice. One entry per scope: while a redeem
/// is pending, the customer can only retry that pack.
///
/// Cleared on success, on any final answer from the server, and on sign-out
/// and account erase (`DefaultPersonalDataWiper`).
class PendingRedeemKeys {
  final _entries = <String, ({int credits, String key})>{};

  ({int credits, String key})? pendingFor(String scope) => _entries[scope];

  void put(String scope, int credits, String key) => _entries[scope] = (credits: credits, key: key);

  void remove(String scope) => _entries.remove(scope);

  void clear() => _entries.clear();
}
