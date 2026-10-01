import 'dart:async';

/// Broadcasts "the server no longer accepts this session" (refresh token
/// rejected) so `AuthCubit` can sign the customer out locally.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  void sessionExpired() => _expired.add(null);
}
