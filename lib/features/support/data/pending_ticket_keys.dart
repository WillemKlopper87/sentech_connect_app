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
/// ([fingerprint], a 64-bit hash of the category and text) that only answers
/// "is this the same text as the attempt that has the key?". The number cannot
/// give the text back; it is kept so that a CHANGED text after an unknown outcome
/// is never sent under the old key, even on a screen opened later.
class PendingTicketKeys {
  final _entries = <String, ({String key, int fingerprint})>{};

  /// `tenant|user|new`: the one new-ticket attempt a customer can have pending.
  static String createScope(String tenant, String user) => '$tenant|$user|new';

  /// `tenant|user|reply|REFERENCE`: one pending reply per ticket.
  static String replyScope(String tenant, String user, String reference) => '$tenant|$user|reply|$reference';

  /// FNV-1a (64 bit) over the UTF-16 code units of the two parts, with a separator
  /// between them. Not a secret: an equality check.
  static int fingerprint(String first, [String second = '']) {
    var hash = 0xcbf29ce484222325;
    void mix(int unit) {
      hash ^= unit;
      hash = hash * 0x100000001b3; // wraps at 64 bits
    }

    for (final unit in first.codeUnits) {
      mix(unit);
    }
    mix(0x1f);
    for (final unit in second.codeUnits) {
      mix(unit);
    }
    return hash;
  }

  ({String key, int fingerprint})? pendingFor(String scope) => _entries[scope];

  void put(String scope, String key, int fingerprint) => _entries[scope] = (key: key, fingerprint: fingerprint);

  void remove(String scope) => _entries.remove(scope);

  void clear() => _entries.clear();

  @override
  String toString() => 'PendingTicketKeys(${_entries.length})';
}
