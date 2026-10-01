@Tags(['integration'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_auth_repository.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/dev_payment_simulator.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/http_passes_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/http_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';

/// OTP -> consent -> order -> fake-gateway payment -> entitlement against the
/// platform's local compose stack. Needs:
///   INTEGRATION_API_BASE_URL  e.g. http://127.0.0.1:8088 (Caddy)
///   INTEGRATION_PLATFORM_DIR  the sentech_connect_platform checkout (to read
///                             the fake SMS from Postgres via docker compose)
/// and a seeded catalogue for the `sentech` tenant (see README).
final _baseUrl = Platform.environment['INTEGRATION_API_BASE_URL'];
final _platformDir = Platform.environment['INTEGRATION_PLATFORM_DIR'];
final String? _skip = (_baseUrl?.isEmpty ?? true) || (_platformDir?.isEmpty ?? true)
    ? 'Set INTEGRATION_API_BASE_URL and INTEGRATION_PLATFORM_DIR to run against the local stack'
    : null;

Future<String> _latestOtpCode(String phoneE164) async {
  final result = await Process.run(
    'docker',
    [
      'compose', '--env-file', '.env',
      '-f', 'infra/docker-compose.yml',
      '-f', 'infra/docker-compose.observability.yml',
      '-f', 'infra/docker-compose.dev.yml',
      'exec', '-T', 'postgres', 'psql', '-U', 'sentech', '-d', 'sentech', '-tAc',
      // phoneE164 comes from the API's own normalised response (+27 and digits).
      "SELECT body FROM sms_outbox WHERE to_e164 = '$phoneE164' ORDER BY created_at DESC LIMIT 1",
    ],
    workingDirectory: _platformDir,
  );
  if (result.exitCode != 0) throw StateError('could not read sms_outbox: ${result.stderr}');
  final match = RegExp(r'\b(\d{6})\b').firstMatch(result.stdout as String);
  if (match == null) throw StateError('no OTP SMS found for the test number');
  return match.group(1)!;
}

T _ok<T>(dynamic either, String step) => (either as dynamic).getOrElse((f) => throw StateError('$step: ${f.message}')) as T;

void main() {
  test('OTP sign-in -> order -> fake-gateway payment -> entitlement (local stack)', () async {
    HttpOverrides.global = null; // real sockets, whatever the test binding set
    final tokens = SecureTokenStore(InMemorySecureStore());
    final tenant = TenantContext();
    final api = ApiClient(baseUrl: Uri.parse(_baseUrl!), tokens: tokens, tenant: tenant, sessionEvents: SessionEvents());

    final config = _ok<dynamic>(await HttpTenantRepository(api).getAppConfig('sentech'), 'app-config');
    expect(config.featureFlags.hotspotPasses, isTrue);
    tenant
      ..termsVersion = config.legal.terms
      ..privacyVersion = config.legal.privacy;

    final auth = HttpAuthRepository(api, tokens: tokens, tenant: tenant);
    // A fresh number per run keeps the per-phone OTP rate limit out of the way.
    final phone = '082${Random().nextInt(9000000) + 1000000}';
    final challenge = _ok<dynamic>(await auth.requestOtp(phoneNumber: phone), 'otp request');
    final code = await _latestOtpCode(challenge.phoneE164 as String);
    final user = _ok<dynamic>(await auth.verifyOtp(challenge: challenge, code: code), 'otp verify');
    expect(user.mobileNumber, challenge.phoneE164);
    expect(await tokens.read(), isA<AuthTokens>());

    // Terms and privacy go to the append-only consent ledger, as the app's legal gate does.
    final consents = HttpConsentRepository(api, local: LocalConsentRepository(InMemorySecureStore()), tenant: tenant);
    _ok<dynamic>(await consents.grant(ConsentPurpose.terms), 'consent terms');
    _ok<dynamic>(await consents.grant(ConsentPurpose.privacy), 'consent privacy');

    final plans = _ok<List<dynamic>>(await HttpCatalogRepository(api, tenant).getProducts(), 'catalogue');
    expect(plans, isNotEmpty, reason: 'seed at least one hotspot pass for the sentech tenant (see README)');

    final checkout = HttpCheckoutRepository(api);
    final order = _ok<Order>(
      await checkout.createOrder(items: [CartItem(plan: plans.first, quantity: 1)], idempotencyKey: newIdempotencyKey()),
      'create order',
    );
    expect(order.status, OrderStatus.awaitingPayment);
    expect(order.totalCents, plans.first.priceCents);

    final handoff = _ok<dynamic>(await checkout.startPayment(orderId: order.id), 'checkout');
    expect(handoff.isFakeGateway, isTrue, reason: 'the local stack uses the fake gateway');
    _ok<String>(await DevPaymentSimulator(api).simulate(paymentId: handoff.paymentId as String, accepted: true), 'simulate');

    var paid = false;
    for (var i = 0; i < 20 && !paid; i++) {
      paid = _ok<Order>(await checkout.getOrder(order.id), 'poll').status == OrderStatus.paid;
      if (!paid) await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(paid, isTrue);

    final passes = _ok<List<dynamic>>(await HttpPassesRepository(api).getPasses(), 'entitlements');
    expect(passes.where((p) => p.orderId == order.id), isNotEmpty);

    await auth.logOut();
    expect(await tokens.read(), isNull);
  }, skip: _skip, timeout: const Timeout(Duration(minutes: 2)));
}
