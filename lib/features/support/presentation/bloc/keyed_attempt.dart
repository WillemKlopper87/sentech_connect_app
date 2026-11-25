import 'package:sentech_connect_app/features/support/data/pending_ticket_keys.dart';

/// The one-key-per-attempt rule shared by a new ticket and a reply.
///
///  * A first attempt gets a new key, stored in [PendingTicketKeys] BEFORE the
///    request leaves (so closing the screen mid-request does not lose it).
///  * The same text again (a double tap that got through, a retry after a lost
///    answer, a reopened screen) reuses the key: the server then returns the
///    original ticket or message.
///  * A CHANGED text while the earlier attempt is still unknown is not sent
///    under that key (the server would refuse it) and not silently under a new
///    one either (the first may have arrived): [begin] returns null, the caller
///    reads the list or thread first and calls [acknowledge]; the next attempt
///    then gets a new key. Going back to the original text reuses the old key.
///  * [settle] forgets the key (success, a final refusal, a feature switched off).
class KeyedAttempt {
  KeyedAttempt({required this._pending, required this._scope, required this._newKey});

  final PendingTicketKeys _pending;
  final String _scope;
  final String Function() _newKey;

  String? _key;
  int? _fingerprint;
  bool _acknowledged = false;

  /// An earlier attempt of this scope has an unknown outcome.
  bool get hasUnknown => _key != null || _pending.pendingFor(_scope) != null;

  /// The key to send [fingerprint] under, or null when the text changed after an unknown outcome.
  String? begin(int fingerprint) {
    if (_key == null) {
      final earlier = _pending.pendingFor(_scope);
      if (earlier != null) {
        _key = earlier.key;
        _fingerprint = earlier.fingerprint;
      }
    }
    if (_key == null) {
      _key = _newKey();
      _fingerprint = fingerprint;
    } else if (_fingerprint != fingerprint) {
      if (!_acknowledged) return null;
      _key = _newKey();
      _fingerprint = fingerprint;
      _acknowledged = false;
    }
    _pending.put(_scope, _key!, _fingerprint!);
    return _key;
  }

  /// The customer has been shown the list or thread after a changed text.
  void acknowledge() => _acknowledged = true;

  void settle() {
    _key = null;
    _fingerprint = null;
    _acknowledged = false;
    _pending.remove(_scope);
  }
}
