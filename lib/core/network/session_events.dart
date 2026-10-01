import 'dart:async';

/// Broadcasts "the server no longer accepts this session" (refresh token
/// rejected) so `AuthCubit` can sign the customer out locally.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  void sessionExpired() => _expired.add(null);

  final _providerUnavailable = StreamController<void>.broadcast();

  /// The provider is suspended (403 `tenant_suspended`): the session was
  /// ended locally and the customer should be told why.
  Stream<void> get providerUnavailable => _providerUnavailable.stream;

  void providerSuspended() => _providerUnavailable.add(null);
}
