/// A one-time hotspot login (`LoginTokenOut`). The password is shown once and
/// is never persisted or logged: keep this object in memory only, and note
/// that [toString] hides both fields.
///
/// The optional controller hand-off (`handoff.action_url` + `fields`) is
/// deliberately not read: the app does not post it to the controller in this
/// version, the customer signs in on the Wi-Fi login page.
class LoginToken {
  const LoginToken({
    required this.username,
    required this.password,
    required this.expiresAt,
  });

  final String username;
  final String password;

  /// When the platform stops accepting the login (device clock, UTC).
  final DateTime expiresAt;

  @override
  String toString() => 'LoginToken(expiresAt: $expiresAt)';

  @override
  bool operator ==(Object other) =>
      other is LoginToken &&
      other.username == username &&
      other.password == password &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(username, password, expiresAt);
}
