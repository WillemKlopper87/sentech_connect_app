import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';

/// The human check ("are you a person") the platform asks for in staging and
/// production on `POST /v1/auth/otp/request` and `POST /v1/me/delete-challenge`
/// (`turnstile_token`, 403 `human_verification_failed` without it).
///
/// Providers, by tier (see docs/BACKEND_CONTRACT_SYNC.md, "Human check"):
///  * future tier A: platform attestation (Play Integrity / App Attest), no
///    visible step; it is NOT built yet;
///  * tier B (task M2d): `TurnstileWebViewProvider`, the Cloudflare Turnstile
///    widget in a WebView, for every device;
///  * dev, test and the demo flavor: [NoHumanCheckProvider], no token.
/// An attestation provider is added later by composing it with the Turnstile
/// one (try attestation, fall back to Turnstile) behind this same interface,
/// so neither repository nor any screen changes.
abstract interface class HumanCheckProvider {
  /// A fresh token for ONE request, or null when this build cannot produce
  /// one (no token is then sent). Throws [HumanCheckCancelled] when the
  /// customer backed out and [HumanCheckUnavailable] when the check could not
  /// run (no network, widget failure). Never cache, reuse or log the value.
  Future<String?> token();
}

/// The customer closed the check without finishing it. Not an error: the
/// screen goes back to where it was.
class HumanCheckCancelled implements Exception {
  const HumanCheckCancelled();

  @override
  String toString() => 'HumanCheckCancelled';
}

/// The check could not run or finish (no network, the widget failed or timed
/// out after retries). Carries no detail on purpose: never a token.
class HumanCheckUnavailable implements Exception {
  const HumanCheckUnavailable();

  @override
  String toString() => 'HumanCheckUnavailable';
}

/// Dev and test builds: no token, so the field is left out of the request.
class NoHumanCheckProvider implements HumanCheckProvider {
  const NoHumanCheckProvider();

  @override
  Future<String?> token() async => null;
}

/// Asks [provider] for one token and turns its refusals into typed failures,
/// so a repository can return `Left` instead of throwing. The ONE place both
/// repositories use.
Future<Either<Failure, String?>> acquireHumanCheck(HumanCheckProvider provider) async {
  try {
    return Right(await provider.token());
  } on HumanCheckCancelled {
    return const Left(HumanCheckCancelledFailure());
  } on HumanCheckUnavailable {
    return const Left(HumanVerificationUnavailableFailure());
  } on Object {
    // A provider bug must not crash the request path or leak into logs.
    return const Left(HumanVerificationUnavailableFailure());
  }
}

/// The only token the platform FAKE verifier (dev and test stacks, which report
/// `site_key: null` in the human-check config) accepts. `POST /v1/support/messages`
/// has `turnstile_token` as a required body field, so with no widget the app
/// sends this. A real verifier refuses it (403 `human_verification_failed`).
const devTurnstilePass = 'dev-turnstile-pass';
