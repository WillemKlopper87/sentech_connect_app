/// The idempotency key of a ticket or a reply whose outcome the app could not
/// learn (a lost response, a server error, "still processing", a rate limit).
/// It lives in memory only, never on disk, and is wiped on sign-out and account
/// erase (`DefaultPersonalDataWiper`).
///
/// It is what makes a retry after the customer left the screen the SAME request,
/// so the server returns the original ticket or message instead of making a
/// second one. The scope is the provider, the customer and, for a reply, the
/// ticket reference.
///
/// NOTHING the customer typed is stored: an entry is a key and a one-way number
/// ([fingerprint], a hash of the category and text) that only answers
/// "is this the same text as the attempt that has the key?". The number cannot
/// give the text back; it is kept so that a CHANGED text after an unknown outcome
/// is never sent under the old key, even on a screen opened later.
class PendingTicketKeys {
  final _entries = <String, ({String key, int fingerprint})>{};

  /// `tenant|user|new`: the one new-ticket attempt a customer can have pending.
  static String createScope(String tenant, String user) => '$tenant|$user|new';

  /// `tenant|user|reply|REFERENCE`: one pending reply per ticket.
  static String replyScope(String tenant, String user, String reference) => '$tenant|$user|reply|$reference';

  /// A hash of the two parts, for equality only (is this the same text as the attempt that has
  /// the key?). Portable: it uses no integer above 2^53, which a web build cannot hold. It is
  /// stable only inside this process, which is all the in-memory holder needs; a collision
  /// would at worst send a changed text under the old key, and the server then refuses it
  /// (422 `idempotency_key_reused`) and the cubit replaces the key once.
  static int fingerprint(String first, [String second = '']) => Object.hash(first, second);

  ({String key, int fingerprint})? pendingFor(String scope) => _entries[scope];

  void put(String scope, String key, int fingerprint) => _entries[scope] = (key: key, fingerprint: fingerprint);

  void remove(String scope) => _entries.remove(scope);

  void clear() => _entries.clear();

  @override
  String toString() => 'PendingTicketKeys(${_entries.length})';
}
