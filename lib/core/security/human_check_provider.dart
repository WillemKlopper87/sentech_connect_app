/// The human check ("are you a person") the platform asks for in staging and
/// production on `POST /v1/auth/otp/request` and `POST /v1/me/delete-challenge`
/// (`turnstile_token`, 403 `human_verification_failed` without it).
///
/// SEAM, NOT IMPLEMENTED (task M2, blocked on an owner decision: Turnstile
/// WebView widget, or platform attestation such as Play Integrity / App
/// Attest; see docs/OWNER_ACTIONS.md D4a in the platform repo and
/// docs/BACKEND_CONTRACT_SYNC.md here). Until then the only provider is
/// [NoHumanCheckProvider], which returns null, so no `turnstile_token` is sent.
/// That works against dev and test stacks only; staging and prod answer 403
/// `human_verification_failed` (shown as typed copy, never as a crash).
abstract interface class HumanCheckProvider {
  /// A fresh token for ONE request, or null when this build cannot produce
  /// one. Never cache or log the value.
  Future<String?> token();
}

/// Dev and test builds: no token, so the field is left out of the request.
class NoHumanCheckProvider implements HumanCheckProvider {
  const NoHumanCheckProvider();

  @override
  Future<String?> token() async => null;
}
