import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';

import 'fake_http_adapter.dart';

/// An ApiClient wired to a FakeHttpAdapter, in-memory secure storage and a
/// fixed clock. Shared by every HTTP repository test.
class ApiHarness {
  ApiHarness({String tenant = 'sentech'})
      : adapter = FakeHttpAdapter(),
        store = InMemorySecureStore(),
        tenantContext = TenantContext(slug: tenant),
        events = SessionEvents() {
    tokens = SecureTokenStore(store);
    api = ApiClient(
      baseUrl: Uri.parse('https://api.test'),
      tokens: tokens,
      tenant: tenantContext,
      sessionEvents: events,
      adapter: adapter,
      log: logLines.add,
      now: () => now,
      refreshRetryBackoff: const [Duration.zero, Duration.zero], // keep failure tests fast
    );
  }

  static const customerId = '7d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d';

  final FakeHttpAdapter adapter;
  final InMemorySecureStore store;
  final TenantContext tenantContext;
  final SessionEvents events;
  late final SecureTokenStore tokens;
  late final ApiClient api;
  final logLines = <String>[];
  DateTime now = DateTime.utc(2026, 10, 1, 12);

  Future<void> signIn({
    String access = 'access-1',
    String refresh = 'refresh-1',
    Duration validFor = const Duration(minutes: 15),
    String? tenant,
  }) =>
      tokens.write(AuthTokens(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: now.add(validFor),
        customerId: customerId,
        tenantSlug: tenant ?? tenantContext.slug,
      ));
}
