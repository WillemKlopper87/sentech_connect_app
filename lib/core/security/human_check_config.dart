import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';

/// Which request a human check is for. [widgetAction] is the Turnstile
/// `action` the server checks: `signin` for the two auth routes, `support`
/// for support messages.
enum HumanCheckAction {
  otpRequest('signin'),
  deleteChallenge('signin'),
  supportMessage('support');

  const HumanCheckAction(this.widgetAction);
  final String widgetAction;
}

/// The server-side human-check settings of a provider, from the public
/// `GET /v1/auth/human-check/config?tenant=<slug>` (platform ae401a0).
class HumanCheckConfig {
  const HumanCheckConfig({
    required this.siteKey,
    required this.baseUrl,
    required this.otpRequestRequired,
    required this.deleteChallengeRequired,
    required this.supportMessageRequired,
    required this.leadRequired,
  });

  /// Both null when the deployment has no Turnstile widget (fake verifier on
  /// dev stacks): no token can be produced then.
  final String? siteKey;
  final String? baseUrl;
  final bool otpRequestRequired;
  final bool deleteChallengeRequired;
  final bool supportMessageRequired;
  final bool leadRequired;

  static HumanCheckConfig fromJson(Object? data) {
    final turnstile = (data! as Map)['turnstile']! as Map;
    final required = turnstile['required']! as Map;
    return HumanCheckConfig(
      siteKey: turnstile['site_key'] as String?,
      baseUrl: turnstile['base_url'] as String?,
      otpRequestRequired: required['otp_request']! as bool,
      deleteChallengeRequired: required['delete_challenge']! as bool,
      supportMessageRequired: required['support_message']! as bool,
      leadRequired: required['lead']! as bool,
    );
  }

  bool requires(HumanCheckAction action) => switch (action) {
    HumanCheckAction.otpRequest => otpRequestRequired,
    HumanCheckAction.deleteChallenge => deleteChallengeRequired,
    HumanCheckAction.supportMessage => supportMessageRequired,
  };
}

abstract interface class HumanCheckConfigRepository {
  Future<Either<Failure, HumanCheckConfig>> fetch(String tenantSlug);
}

/// Public route: no token, no session. Never signs the customer out.
class HttpHumanCheckConfigRepository implements HumanCheckConfigRepository {
  HttpHumanCheckConfigRepository(this._api, {this.timeout = const Duration(seconds: 6)});

  final ApiClient _api;
  final Duration timeout;

  @override
  Future<Either<Failure, HumanCheckConfig>> fetch(String tenantSlug) => _api.get<HumanCheckConfig>(
    '/v1/auth/human-check/config',
    query: {'tenant': tenantSlug},
    authenticated: false,
    timeout: timeout,
    decode: HumanCheckConfig.fromJson,
  );
}
