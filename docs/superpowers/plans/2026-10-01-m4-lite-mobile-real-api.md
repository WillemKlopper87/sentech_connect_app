# M4-lite Mobile Real-API Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch the Flutter app from mock repositories to the real Sentech Connect platform API (M1 contract) behind the existing domain interfaces, with a `demo`/`prod` flavor switch, a tenant (ISP) picker with per-tenant branding and flags, phone-number OTP sign-in, hotspot-pass ordering with a hosted-payment hand-off and order polling, "My passes", and POPIA profile/consent/export/delete over the API, while the `demo` flavor keeps working offline.

**Architecture:** Domain entities and repository interfaces stay; each migrated feature gets an `Http*Repository` (Dio) beside its `Mock*Repository`, and `lib/app/locator.dart` picks one per flavor (`--dart-define=APP_FLAVOR=demo|prod`, default `demo`). One `ApiClient` (`lib/core/network/`) owns transport concerns: bearer tokens from secure storage, single-flight silent refresh with one retry, RFC 9457 problem+json to `Failure` mapping, request ids, idempotency keys, per-request timeouts and PII-free logging. A root `TenantCubit` (directory + app-config, persisted choice, cached config for offline launch) drives theming, feature flags, the min-version gate and router guards. Coverage, free Wi-Fi, hotspots, vouchers, account summary, promotions, support and liveness have no backend in M1 and stay mock in both flavors (listed in `stillMockInProd`).

**Tech Stack:** Flutter 3.47 / Dart 3.12, flutter_bloc 9 (cubits), get_it 9, fpdart 1.1 (`Either<Failure, T>`), go_router 18, dio 5 (new), webview_flutter 4 (new, flutter.dev first-party), flutter_secure_storage 11, shared_preferences, flutter_test + bloc_test + mocktail.

**Spec:**
- Platform design (binding): `C:\Users\Wille\Downloads\applications\sentech_connect_platform\docs\superpowers\specs\2026-09-30-sentech-connect-platform-design.md` (§2 principles, §3 order flow, §4 Netcash hosted redirect, §6 mobile app and API contract, §12/§12.1 multi-tenancy and the single app with a tenant picker). A copy lives at `docs/superpowers/specs/2026-09-30-sentech-connect-platform-design.md` in this repo.
- API contract: `C:\Users\Wille\Downloads\applications\sentech_connect_platform\docs\superpowers\plans\2026-10-01-m1-hotspot-commerce-backend.md` (route list and Pydantic schemas) and `apps/api/openapi.json` in the platform repo (M0 routes today; M1 routes once built). If the built OpenAPI differs from a fixture in `test/fixtures/api/`, update the fixture and the mapping in the same task and record a `Ruling:` line in the SDD ledger.
- Mobile context: `docs/app-review.md` (C1 money as cents, S3 tokens, S13 network security), `docs/reconciled-spec.md`, `docs/GOAL.md` (M4-lite scope).

## Global Constraints

Every task implicitly includes these.

- Money (spec §2): "money is integer cents; the server is the authority for prices, totals, entitlements and time." Currency is `ZAR`. No `double` for money anywhere after Task 1.
- API conventions (spec §6): "`/v1` REST"; "RFC 9457 problem-details errors mapped to existing `Failure` types; `Idempotency-Key` on mutating calls; cursor pagination; integer-cent money." Problem bodies carry `type`, `title`, `status`, `code`, `request_id` and optional `detail`.
- App-config (spec §6): "`GET /v1/app-config`: minimum app version, feature flags (RICA/CPE off at launch), legal document versions."
- Auth (spec §6 as amended by M1 ruling R-M1-1): customers sign in with mobile number + SMS OTP; the API issues RS256 access tokens (15 min) and rotating refresh tokens; "tokens in secure storage; biometrics only unlock an existing session; server-side revocation." No `flutter_appauth` in M4-lite.
- App changes (spec §6): "Dio-backed repositories replace each `Mock*Repository` behind the same domain interfaces; `demo`/`prod` flavors". "The in-progress hardening work (secure storage, real biometrics, route guards, consent, network-security-config) is a prerequisite and is reused."
- White-label (spec §12): "One app with an ISP drop-down. `GET /v1/app-config?tenant=<slug>` returns the tenant's branding, legal documents and feature flags; `GET /v1/tenants` is the directory of active, listed ISPs." "Branding is public and must never hold secrets." Customers belong to one tenant: switching tenant ends the session.
- Payments (spec §3/§4): "Payment completion is driven only by the verified Netcash Notify postback"; hosted redirect; "Card data never touches our systems." The app never marks an order paid; it polls the order.
- Hotspot passes (spec §3): "Hotspot passes skip RICA and fulfilment" (RICA stays available behind the `rica` flag for the mock Home 5G flow).
- Clean architecture: presentation -> domain interfaces <- data. Pages/cubits never import `dio` or `ApiClient`. Every repository method returns `Future<Either<Failure, T>>` (fpdart) except the documented `Future<void>` wipe/logout methods. State lives in cubits (`flutter_bloc`); wiring only in `lib/app/locator.dart` (`get_it`, `locator`).
- `demo` flavor (the default, used by every existing test) keeps working with no network: it must never construct `ApiClient`.
- `prod` flavor: `API_BASE_URL` is required and must be `https`, except `http` to `localhost`, `127.0.0.1` or `10.0.2.2` in debug builds (matching `android/app/src/debug/res/xml/network_security_config.xml`).
- Logs never contain tokens, request/response bodies, query strings or phone numbers; everything goes through `PiiScrubber`.
- No secrets, real credentials or payment/SMS accounts anywhere (GOAL hard limit). Test values only.
- Verification commands are `flutter analyze` (must report `No issues found!`) and `flutter test` (all green). No Android SDK exists on this machine: `flutter build apk`, emulator runs and Gradle changes are out of scope.
- Commands (PowerShell, from the repo root `C:\Users\Wille\Downloads\applications\sentech_connect_app`): first `$env:Path += ";C:\src\flutter\bin"` in each new shell. In Git Bash use `export PATH="$PATH:/c/src/flutter/bin"` and `cd /c/Users/Wille/Downloads/applications/sentech_connect_app`. Git warnings about LF vs CRLF are expected and harmless.
- After editing `lib/l10n/app_en.arb`, run `flutter gen-l10n` and commit the regenerated `lib/l10n/app_localizations*.dart`. New keys go into `app_en.arb` only until Task 13 (gen-l10n falls back to English for zu/af).
- Commit only your own files: `git add <explicit paths>`; never `git add -A` or `git add .`. If `index.lock` exists, wait a few seconds and retry. Commit on the current branch (`chore/deps-tests-security`, or whatever branch the executor was started on) with `git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "<message>"`.

## Spec deviations and rulings (decided while planning)

- **R-M4-1 Refresh path.** The M1 plan exposes `POST /v1/auth/token/refresh` (body `{tenant, refresh_token}`), not `/v1/auth/refresh`; the app uses the M1 path. Logout is `POST /v1/auth/logout` (bearer + `{refresh_token}`).
- **R-M4-2 Biometrics unlock, logout revokes.** Logout now revokes the refresh family server-side and forgets the biometric credential (the mock phase kept it). Biometrics are offered on a cold start that finds a stored session: the app starts `AuthStatus.locked` and "Use biometrics" resumes the session through a refresh-token exchange (spec §6 "biometrics only unlock an existing session").
- **R-M4-3 Payment hand-off uses `webview_flutter`.** Netcash Pay Now needs a form POST, which Custom Tabs (`url_launcher` in-app browser) cannot send, and the app must notice the return URL to start polling. `webview_flutter` (flutter.dev, maintained) supports `LoadRequestMethod.post` and a `NavigationDelegate`. Only `https` (plus local `http` in debug) is navigable; no JavaScript channels are added; cache and cookies are cleared on close. The payment method is chosen on the gateway page, so the in-app method selector (`PaymentMethod`) is removed.
- **R-M4-4 Test HTTP adapter.** A small in-repo `FakeHttpAdapter` (implements dio's `HttpClientAdapter`) instead of `http_mock_adapter`: no extra dependency that lags dio releases, and it lets tests gate responses with `Completer`s (needed for the refresh race test), inject transport errors and inspect every request's headers and body.
- **R-M4-5 Flavor = dart-define.** `--dart-define=APP_FLAVOR` and `--dart-define=API_BASE_URL` only; Android `productFlavors` are not added (no Android SDK here to verify Gradle changes).
- **R-M4-6 Branding keys.** The platform's `branding` is a free-form public JSON object. The app reads `primary_color` (`#RRGGBB`) and `logo_url` (`https` only) and ignores everything else.
- **R-M4-7 Order mapping.** Server statuses map to domain `OrderStatus`: `draft`/`awaiting_payment` -> `awaitingPayment`, `failed` -> `paymentFailed`, `paid`/`fulfilled` -> `paid`, `expired` -> `expired`, `cancelled` -> `cancelled`. The API has no customer-facing order number; the app shows `SC-` + the first 8 characters of the order id.
- **R-M4-8 Still mock in prod.** Coverage, free Wi-Fi, hotspots, vouchers, account summary/usage/CPE, promotions, support and RICA liveness have no M1 backend. They stay `Mock*` in both flavors, are listed in `stillMockInProd` and in the README, and are swapped in the locator when their API exists.
- **R-M4-9 Data export.** `GET /v1/me/export` is synchronous; the app shows the JSON on a capture-protected screen instead of "we will email it".
- **R-M4-10 Tenant picker.** If the directory lists exactly one tenant (Sentech at launch) it is selected automatically; the picker is reachable from Account ("Change provider").
- **R-M4-11 Consents.** `terms`, `privacy` and `marketing_sms` are held by the server (`/v1/me/consents`, versions from app-config); `locationCapture` and `ricaCapture` stay device-only.
- **R-M4-12 Transitional shims.** `AuthRepository.logIn` (password) survives Tasks 6-7 and is deleted in Task 8; `CheckoutRepository.pay` survives Task 9 and is replaced in Task 10. Their HTTP implementations return a `Failure`; the prod flavor is not shipped between those tasks.
- **R-M4-13 Local fake gateway.** In debug builds against a local stack, a `fake`-gateway hand-off shows an "Approve/Decline test payment" sheet that calls the API's dev endpoint `POST /v1/dev/payments/{id}/simulate` (never registered by a prod API).
- **R-M4-14 Version gate.** An unparseable `min_app_version` never blocks the app.

## Review Focus

Failure modes most likely to hurt a person using this app; each is pinned by tests in the named task.

1. **Token refresh races** — several requests hitting 401 at once must cause exactly one `POST /v1/auth/token/refresh` (rotation + reuse detection would otherwise revoke the session), each request retried at most once. -> Task 3 (`test/api_client_test.dart`).
2. **Double charge / replayed idempotency keys** — a retry after a timeout must reuse the same `Idempotency-Key` (same order back, not a second one); a 401-retry keeps the key; double-tapping Pay starts one payment attempt. -> Task 3, Task 9 (`test/order_flow_cubits_test.dart`), Task 10 (`test/payment_polling_test.dart`).
3. **Tenant switch leaking data** — tokens issued for tenant A are never sent while tenant B is selected; switching tenant signs out and wipes session data before the new tenant loads. -> Task 3, Task 5 (`test/tenant_cubit_test.dart`), Task 6.
4. **Cleartext / HTTPS enforcement** — a prod build must refuse `http://` to non-local hosts and refuse local `http` in release builds; the payment web view never navigates to non-https URLs. -> Task 2 (`test/app_environment_test.dart`), Task 10 (`test/payment_urls_test.dart`).
5. **Secrets/PII in logs** — log lines never include bearer tokens, refresh tokens, bodies, query strings or phone numbers. -> Task 3.
6. **Offline behaviour** — timeouts and connection errors become `NetworkFailure` with retry UI; a refresh that cannot reach the server never logs the customer out; offline launch uses the cached app-config. -> Task 3, Task 5, Task 10.
7. **Order polling loops** — polling after the hand-off is bounded, stops when the screen closes, tolerates offline blips, and ends in `paid`, `payFailed`, `closed` or `stillPending` (with "Check again"). -> Task 10.
8. **Logout wiping** — logout revokes server-side, clears tokens, the biometric credential and local personal data, even when the server is unreachable; an expired session (refresh rejected) signs the customer out. -> Task 6 (`test/auth_cubit_test.dart`, `test/http_auth_repository_test.dart`).

## File Structure

```
pubspec.yaml                                   (T2 dio, T10 webview_flutter)
dart_test.yaml                                 (T12) declares the `integration` tag
lib/
  main.dart                                    (T4 environment from dart-defines, T6 locked restore)
  app/
    app.dart                                   (T5 TenantCubit + tenant theme, T6 session-expired stream)
    app_version.dart                           (T5) const appVersion (must equal pubspec version)
    locator.dart                               (T4 flavor switch + stillMockInProd; T6-T11 move repos to HTTP)
    main_shell.dart                            (T5 provider row, T11 passes + CPE flag)
    router/app_router.dart                     (T5 tenant guards, T8 profile rule + OTP login, T9-T11 routes)
    theme/app_theme.dart                       (T5) tenant primary colour
  core/
    config/app_environment.dart                (T2) AppFlavor, AppEnvironment, InvalidEnvironment
    error/failure.dart                         (T2) + UnauthorizedFailure, NotFoundFailure, RateLimitedFailure; codes/request ids
    local/tenant_preferences.dart              (T5) persisted tenant slug + cached app-config
    money/money.dart                           (T1) formatRands
    network/api_problem.dart                   (T2) ApiProblem, failureFromDioException
    network/auth_tokens.dart                   (T3) AuthTokens, TokenStore, SecureTokenStore
    network/tenant_context.dart                (T3) current tenant slug + legal versions
    network/session_events.dart                (T3) session-expired broadcast
    network/idempotency.dart                   (T3) newIdempotencyKey, newRequestId
    network/token_refresher.dart               (T3) single-flight refresh
    network/interceptors.dart                  (T3) RequestId, Auth, SafeLog interceptors
    network/api_client.dart                    (T3) ApiClient
    utils/phone_number.dart                    (T6) normaliseZaMobile, maskPhone
    utils/version.dart                         (T5) isVersionAtLeast
  features/
    tenant/domain/entities/tenant.dart, app_config.dart           (T4)
    tenant/domain/repositories/tenant_repository.dart              (T4)
    tenant/data/repositories/mock_tenant_repository.dart, http_tenant_repository.dart (T4)
    tenant/presentation/bloc/tenant_cubit.dart                     (T5)
    tenant/presentation/pages/tenant_picker_page.dart, update_required_page.dart (T5)
    tenant/presentation/widgets/tenant_logo.dart                   (T5)
    auth/domain/entities/otp_challenge.dart                        (T6)
    auth/domain/repositories/auth_repository.dart                  (T6, T8)
    auth/data/repositories/mock_auth_repository.dart, http_auth_repository.dart (T6, T8)
    auth/data/repositories/http_registration_repository.dart       (T7)
    auth/presentation/bloc/auth_cubit.dart                         (T6, T8)
    auth/presentation/bloc/otp_login_cubit.dart                    (T8)
    auth/presentation/bloc/registration_cubit.dart                 (T8)
    auth/presentation/pages/login_page.dart, registration_page.dart (T8)
    privacy/domain/entities/consent_record.dart                    (T7 server purposes)
    privacy/domain/repositories/privacy_repository.dart            (T7 exportJson)
    privacy/data/repositories/http_consent_repository.dart, http_privacy_repository.dart (T7)
    privacy/presentation/bloc/privacy_actions_cubit.dart           (T7 receipt)
    privacy/presentation/pages/data_export_page.dart               (T7)
    privacy/presentation/widgets/consent_gate.dart                 (T7)
    catalog_checkout/domain/entities/plan.dart, order.dart, payment_handoff.dart (T1, T9, T10)
    catalog_checkout/domain/repositories/checkout_repository.dart  (T9, T10)
    catalog_checkout/data/repositories/http_catalog_repository.dart, http_checkout_repository.dart (T9, T10)
    catalog_checkout/data/dev_payment_simulator.dart               (T10)
    catalog_checkout/presentation/bloc/catalog_cubit.dart, checkout_cubit.dart, payment_cubit.dart (T9, T10)
    catalog_checkout/presentation/payment/payment_urls.dart, payment_web_view_page.dart, fake_gateway_sheet.dart (T10)
    catalog_checkout/presentation/pages/*.dart                     (T1, T9, T10, T11)
    passes/domain/entities/pass.dart, passes/domain/repositories/passes_repository.dart (T11)
    passes/data/repositories/mock_passes_repository.dart, http_passes_repository.dart (T11)
    passes/presentation/bloc/passes_cubit.dart, passes/presentation/pages/my_passes_page.dart (T11)
  l10n/app_en.arb (+ generated)                (T5, T7, T8, T11), app_zu.arb, app_af.arb (T13)
test/
  helpers/fake_http_adapter.dart, fixtures.dart, api_harness.dart   (T3)
  fixtures/api/*.json                                                (T3-T11) contract fixtures
  money_test.dart (T1); app_environment_test.dart, api_problem_test.dart (T2); api_client_test.dart (T3);
  http_tenant_repository_test.dart, locator_test.dart (T4); tenant_cubit_test.dart, tenant_ui_test.dart, version_test.dart (T5);
  phone_number_test.dart, http_auth_repository_test.dart, auth_cubit_test.dart (T6); profile_privacy_api_test.dart (T7);
  otp_login_cubit_test.dart, login_page_test.dart, registration_cubit_test.dart (T8);
  http_catalog_repository_test.dart, http_checkout_repository_test.dart (T9, T10); payment_polling_test.dart, payment_urls_test.dart (T10);
  passes_test.dart (T11); integration/live_api_flow_test.dart (T12); l10n_parity_test.dart (T13)
README.md, docs/app-review.md                  (T12)
```

---

### Task 1: Integer-cent money end to end (review item C1)

**Files:**
- Create: `lib/core/money/money.dart`, `test/money_test.dart`
- Modify: `lib/features/catalog_checkout/domain/entities/plan.dart`, `lib/features/catalog_checkout/domain/entities/order.dart`, `lib/features/cart/domain/entities/cart_item.dart`, `lib/features/cart/presentation/bloc/cart_cubit.dart`, `lib/features/catalog_checkout/presentation/bloc/checkout_cubit.dart`, `lib/features/catalog_checkout/data/repositories/mock_catalog_repository.dart`, `lib/features/catalog_checkout/data/repositories/mock_checkout_repository.dart`, `lib/features/cart/presentation/pages/cart_page.dart`, `lib/features/catalog_checkout/presentation/pages/catalog_page.dart`, `lib/features/catalog_checkout/presentation/pages/checkout_page.dart`, `lib/features/catalog_checkout/presentation/pages/payment_page.dart`
- Test: `test/money_test.dart`; update `test/accessibility_test.dart`, `test/checkout_repository_test.dart`, `test/offline_test.dart`, `test/order_flow_cubits_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `String formatRands(int cents, {bool wholeRands = false})`; `Plan.priceCents` (`int`, replaces `priceRands`); `CartItem.lineTotalCents` (`int`); `CartState.totalCents` (`int`); `CheckoutState.totalCents` (`int`); `Order.totalCents` (`int`, replaces `totalRands`; `Order.fromJson` still reads legacy `totalRands`).

- [ ] **Step 1: Write the failing test**

`test/money_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

const _pass = Plan(
  id: 'pass_day',
  name: 'Day pass',
  priceCents: 1999,
  dataDescription: '1 GB · 1 day',
  speedMbps: 10,
  category: ProductCategory.voucher,
);

void main() {
  group('formatRands', () {
    test('formats integer cents as rands with two decimals', () {
      expect(formatRands(54900), 'R549.00');
      expect(formatRands(1999), 'R19.99');
      expect(formatRands(5), 'R0.05');
      expect(formatRands(0), 'R0.00');
      expect(formatRands(-1250), '-R12.50');
    });

    test('wholeRands drops ".00" only when there are no cents', () {
      expect(formatRands(54900, wholeRands: true), 'R549');
      expect(formatRands(54950, wholeRands: true), 'R549.50');
    });
  });

  test('cart totals are exact integer cents', () async {
    final cart = CartCubit()..addItem(_pass);
    cart.setQuantity('pass_day', 3);
    expect(cart.state.items.single.lineTotalCents, 5997);
    expect(cart.state.totalCents, 5997);
    expect(formatRands(cart.state.totalCents), 'R59.97');
    await cart.close();
  });

  test('orders persisted by older builds (totalRands) are read as cents', () {
    final order = Order.fromJson({
      'id': 'o1',
      'orderNumber': 'SEN-1',
      'planName': 'Home 100',
      'totalRands': 549.99,
      'status': 'paid',
    });
    expect(order.totalCents, 54999);
    expect(order.toJson()['totalCents'], 54999);
    expect(Order.fromJson(order.toJson()), order);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/money_test.dart`
Expected: FAIL (compile error: `Target of URI doesn't exist: 'package:sentech_connect_app/core/money/money.dart'` and `No named parameter with the name 'priceCents'`).

- [ ] **Step 3: Add the money helper**

`lib/core/money/money.dart`:

```dart
/// Money is integer cents end to end (platform spec §2, review item C1).
/// Rands only exist as text shown to a person; never parse this back.
String formatRands(int cents, {bool wholeRands = false}) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final rands = abs ~/ 100;
  final remainder = abs % 100;
  if (wholeRands && remainder == 0) return '${sign}R$rands';
  return '${sign}R$rands.${remainder.toString().padLeft(2, '0')}';
}
```

- [ ] **Step 4: Switch the entities to cents**

In `plan.dart` replace `required this.priceRands,` with `required this.priceCents,`, replace `final double priceRands;` with:

```dart
  /// Price in integer cents (ZAR). The server is the authority for prices.
  final int priceCents;
```

and in `props` replace `priceRands` with `priceCents`.

In `cart_item.dart` replace the `lineTotal` getter with:

```dart
  int get lineTotalCents => plan.priceCents * quantity;
```

In `cart_cubit.dart` replace `double get total => ...;` in `CartState` with:

```dart
  int get totalCents => items.fold(0, (sum, i) => sum + i.lineTotalCents);
```

In `checkout_cubit.dart` replace `double get total => ...;` in `CheckoutState` with:

```dart
  int get totalCents => items.fold(0, (sum, i) => sum + i.lineTotalCents);
```

Replace the `Order` class in `order.dart` (keep the `OrderStatus` enum and its comments unchanged) with:

```dart
class Order extends Equatable {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.planName,
    required this.totalCents,
    this.status = OrderStatus.pendingVerification,
  });

  /// Opaque identifier used in routes (`/rica/:orderId`). Never the
  /// customer-facing [orderNumber].
  final String id;
  final String orderNumber;
  final String planName;

  /// Total in integer cents (ZAR); the server owns it.
  final int totalCents;
  final OrderStatus status;

  bool get isOpen => status != OrderStatus.paid;

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        orderNumber: orderNumber,
        planName: planName,
        totalCents: totalCents,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'planName': planName,
        'totalCents': totalCents,
        'status': status.name,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String,
        planName: json['planName'] as String,
        // Builds before integer cents stored `totalRands` as a double.
        totalCents: (json['totalCents'] as num?)?.toInt() ?? (((json['totalRands'] as num?) ?? 0) * 100).round(),
        status: OrderStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => OrderStatus.pendingVerification,
        ),
      );

  @override
  List<Object?> get props => [id, orderNumber, planName, totalCents, status];
}
```

- [ ] **Step 5: Convert the mocks and the screens**

In `mock_catalog_repository.dart` replace each `priceRands: X,` with `priceCents: X00,` (399 -> 39900, 549 -> 54900, 799 -> 79900, 199 -> 19900, 349 -> 34900, 59 -> 5900, 199 -> 19900).

In `mock_checkout_repository.dart` `createOrder`, replace the `total` line and the `totalRands:` argument with:

```dart
    final total = items.fold(0, (sum, i) => sum + i.lineTotalCents);
```

```dart
      totalCents: total,
```

Screens (add `import 'package:sentech_connect_app/core/money/money.dart';` to each):
- `cart_page.dart`: `'R${item.plan.priceRands.toStringAsFixed(2)} each'` -> `'${formatRands(item.plan.priceCents)} each'`; `'R${state.total.toStringAsFixed(2)}'` -> `formatRands(state.totalCents)`.
- `catalog_page.dart`: `TextSpan(text: 'R${plan.priceRands.toStringAsFixed(0)}')` -> `TextSpan(text: formatRands(plan.priceCents, wholeRands: true))`.
- `checkout_page.dart`: `_SummaryCard(items: state.items, total: state.total)` -> `_SummaryCard(items: state.items, totalCents: state.totalCents)`; in `_SummaryCard` replace `required this.total` with `required this.totalCents`, `final double total;` with `final int totalCents;`, `'R${item.lineTotal.toStringAsFixed(2)}'` with `formatRands(item.lineTotalCents)`, and `'R${total.toStringAsFixed(2)}'` with `formatRands(totalCents)`.
- `payment_page.dart`: `Text('Pay R${order.totalRands.toStringAsFixed(2)} securely')` -> `Text('Pay ${formatRands(order.totalCents)} securely')`; `Text('R${order.totalRands.toStringAsFixed(2)}', ...)` -> `Text(formatRands(order.totalCents), ...)`.

- [ ] **Step 6: Update the existing tests**

Replace every `priceRands: N,` with `priceCents: N00,` in `test/accessibility_test.dart` (799 -> 79900, 199 -> 19900, 349 -> 34900), `test/checkout_repository_test.dart` (54900), `test/offline_test.dart` (54900) and `test/order_flow_cubits_test.dart` (54900).

Run: `git grep -n -E "priceRands|totalRands|lineTotal\b|\.total\b" -- lib test`
Expected: only the `totalRands` legacy read in `order.dart` and the `totalRands` key in `test/money_test.dart`.

- [ ] **Step 7: Run the tests**

Run: `flutter test`
Expected: all tests PASS (151 existing + 4 new).

- [ ] **Step 8: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```powershell
git add lib/core/money/money.dart test/money_test.dart lib/features/catalog_checkout/domain/entities/plan.dart lib/features/catalog_checkout/domain/entities/order.dart
git add lib/features/cart/domain/entities/cart_item.dart lib/features/cart/presentation/bloc/cart_cubit.dart lib/features/catalog_checkout/presentation/bloc/checkout_cubit.dart
git add lib/features/catalog_checkout/data/repositories/mock_catalog_repository.dart lib/features/catalog_checkout/data/repositories/mock_checkout_repository.dart
git add lib/features/cart/presentation/pages/cart_page.dart lib/features/catalog_checkout/presentation/pages/catalog_page.dart lib/features/catalog_checkout/presentation/pages/checkout_page.dart lib/features/catalog_checkout/presentation/pages/payment_page.dart
git add test/accessibility_test.dart test/checkout_repository_test.dart test/offline_test.dart test/order_flow_cubits_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "refactor(money): integer cents end to end (review C1)"
```

---

### Task 2: Flavor environment, failure types and problem+json mapping

**Files:**
- Create: `lib/core/config/app_environment.dart`, `lib/core/network/api_problem.dart`, `test/app_environment_test.dart`, `test/api_problem_test.dart`
- Modify: `pubspec.yaml`, `pubspec.lock` (via `flutter pub add dio`), `lib/core/error/failure.dart`

**Interfaces:**
- Consumes: `Failure`, `NetworkFailure`, `ServerFailure`, `ValidationFailure` (existing).
- Produces:
  - `enum AppFlavor { demo, prod }`; `class InvalidEnvironment implements Exception { final String message; }`; `class AppEnvironment { const AppEnvironment({required AppFlavor flavor, Uri? apiBaseUrl}); AppFlavor flavor; Uri? apiBaseUrl; bool get isDemo; static const demo; static const localDevHosts = {'localhost', '127.0.0.1', '10.0.2.2'}; factory AppEnvironment.resolve({required String flavor, required String apiBaseUrl, required bool isDebug}); factory AppEnvironment.fromDefines(); }`
  - `failure.dart`: `ServerFailure([String message, String? requestId])`, `ValidationFailure(String message, [String? code])`, new `UnauthorizedFailure([String message])`, `NotFoundFailure([String message])`, `RateLimitedFailure([String message, Duration? retryAfter])`.
  - `class ApiProblem { int status; String code; String title; String? detail; String? requestId; static ApiProblem? tryParse(int status, Object? data); }`; `Failure failureFromDioException(DioException e)`; `Failure failureFromStatus(int status, ApiProblem? problem, {String? requestId, Duration? retryAfter})`.

- [ ] **Step 1: Add dio**

Run: `flutter pub add dio`
Expected: `pubspec.yaml` gains `dio: ^5.x.y` under `dependencies`; `pubspec.lock` updated.

- [ ] **Step 2: Write the failing tests**

`test/app_environment_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';

void main() {
  group('AppEnvironment.resolve', () {
    test('defaults to demo with no API base URL', () {
      final env = AppEnvironment.resolve(flavor: 'demo', apiBaseUrl: '', isDebug: false);
      expect(env.isDemo, isTrue);
      expect(env.apiBaseUrl, isNull);
    });

    test('prod requires API_BASE_URL', () {
      expect(
        () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: '', isDebug: true),
        throwsA(isA<InvalidEnvironment>()),
      );
    });

    test('prod accepts https and strips a trailing slash', () {
      final env = AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'https://api.example.co.za/', isDebug: false);
      expect(env.isDemo, isFalse);
      expect(env.apiBaseUrl.toString(), 'https://api.example.co.za');
    });

    test('cleartext http is refused for non-local hosts, even in debug', () {
      expect(
        () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'http://api.example.co.za', isDebug: true),
        throwsA(isA<InvalidEnvironment>()),
      );
    });

    test('cleartext http to the emulator host or localhost is allowed only in debug builds', () {
      for (final url in ['http://10.0.2.2:8088', 'http://127.0.0.1:8088', 'http://localhost:8000']) {
        expect(AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: url, isDebug: true).apiBaseUrl.toString(), url);
        expect(
          () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: url, isDebug: false),
          throwsA(isA<InvalidEnvironment>()),
        );
      }
    });

    test('rejects unknown flavors, paths, query strings, credentials and odd schemes', () {
      expect(() => AppEnvironment.resolve(flavor: 'qa', apiBaseUrl: '', isDebug: true), throwsA(isA<InvalidEnvironment>()));
      for (final url in [
        'https://api.example.co.za/v1',
        'https://api.example.co.za?x=1',
        'https://user:pw@api.example.co.za',
        'ftp://api.example.co.za',
        'api.example.co.za',
      ]) {
        expect(
          () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: url, isDebug: true),
          throwsA(isA<InvalidEnvironment>()),
          reason: url,
        );
      }
    });
  });
}
```

`test/api_problem_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_problem.dart';

DioException _bad(int status, Object? data, {Map<String, List<String>> headers = const {}}) {
  final request = RequestOptions(path: '/v1/x');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: request,
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers),
    ),
  );
}

Map<String, Object?> _problem(int status, String code, {String? detail}) => {
      'type': 'about:blank',
      'title': 'Problem',
      'status': status,
      'code': code,
      'request_id': 'rid-123',
      'detail': ?detail,
    };

void main() {
  test('422 maps to a ValidationFailure carrying detail and code', () {
    final f = failureFromDioException(_bad(422, _problem(422, 'invalid_phone', detail: 'Enter a valid South African mobile number.')));
    expect(f, isA<ValidationFailure>());
    expect(f.message, 'Enter a valid South African mobile number.');
    expect((f as ValidationFailure).code, 'invalid_phone');
  });

  test('400 otp_invalid is a ValidationFailure with that code', () {
    final f = failureFromDioException(_bad(400, _problem(400, 'otp_invalid', detail: 'The code is invalid or has expired.')));
    expect((f as ValidationFailure).code, 'otp_invalid');
  });

  test('a validation problem without detail falls back to its title', () {
    final f = failureFromDioException(_bad(409, _problem(409, 'order_not_payable')));
    expect(f.message, 'Problem');
  });

  test('401 is an UnauthorizedFailure', () {
    expect(failureFromDioException(_bad(401, _problem(401, 'invalid_token'))), isA<UnauthorizedFailure>());
  });

  test('404 is a NotFoundFailure with the server detail', () {
    final f = failureFromDioException(_bad(404, _problem(404, 'order_not_found', detail: 'Unknown order.')));
    expect(f, isA<NotFoundFailure>());
    expect(f.message, 'Unknown order.');
  });

  test('429 is a RateLimitedFailure honouring Retry-After', () {
    final f = failureFromDioException(_bad(429, _problem(429, 'rate_limited'), headers: {
      'retry-after': ['60'],
    }));
    expect(f, isA<RateLimitedFailure>());
    expect((f as RateLimitedFailure).retryAfter, const Duration(seconds: 60));
  });

  test('5xx never shows server text but keeps the request id for support', () {
    final f = failureFromDioException(_bad(503, _problem(503, 'internal_error', detail: 'stack trace here')));
    expect(f, isA<ServerFailure>());
    expect(f.message, isNot(contains('stack')));
    expect((f as ServerFailure).requestId, 'rid-123');
  });

  test('a problem body delivered as a String is still parsed', () {
    final f = failureFromDioException(_bad(422, '{"title":"Bad","code":"no_changes","detail":"Send a field."}'));
    expect((f as ValidationFailure).code, 'no_changes');
  });

  test('non-problem error bodies fall back to ServerFailure', () {
    expect(failureFromDioException(_bad(400, '<html>gateway</html>')), isA<ServerFailure>());
  });

  test('timeouts, connection errors and unknown transport errors are NetworkFailure', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.unknown,
    ]) {
      expect(
        failureFromDioException(DioException(requestOptions: RequestOptions(path: '/v1/x'), type: type)),
        isA<NetworkFailure>(),
        reason: type.name,
      );
    }
  });

  test('a bad certificate is a NetworkFailure, never silently accepted', () {
    final f = failureFromDioException(
      DioException(requestOptions: RequestOptions(path: '/v1/x'), type: DioExceptionType.badCertificate),
    );
    expect(f, isA<NetworkFailure>());
    expect(f.message, contains('secure'));
  });

  test('a Failure attached by an interceptor is passed through unchanged', () {
    final f = failureFromDioException(DioException(requestOptions: RequestOptions(path: '/v1/x'), error: const UnauthorizedFailure()));
    expect(f, const UnauthorizedFailure());
  });
}
```

(The `'detail': ?detail` null-aware map entry needs Dart 3.8+; the SDK floor is 3.12.)

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/app_environment_test.dart test/api_problem_test.dart`
Expected: FAIL (compile errors: missing `app_environment.dart`, `api_problem.dart`, `UnauthorizedFailure`).

- [ ] **Step 4: Extend the failure types**

Replace `lib/core/error/failure.dart` with:

```dart
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// Something failed on the server side. [requestId] (from the problem body
/// or the `X-Request-ID` header) lets support find the server log line.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on our end.', this.requestId]);

  final String? requestId;

  @override
  List<Object?> get props => [message, requestId];
}

class NotCoveredFailure extends Failure {
  const NotCoveredFailure([super.message = 'This address is not yet in our coverage area.']);
}

/// The request was understood but refused (4xx). [code] is the API's
/// machine-readable problem code (e.g. `otp_invalid`), or a local code for
/// checks done before calling the API (e.g. `invalid_phone`).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [this.code]);

  final String? code;

  @override
  List<Object?> get props => [message, code];
}

/// No valid session: the customer must sign in again.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Your session has ended. Sign in again.']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'We could not find that.']);
}

class RateLimitedFailure extends Failure {
  const RateLimitedFailure([super.message = 'Too many attempts. Please wait and try again.', this.retryAfter]);

  final Duration? retryAfter;

  @override
  List<Object?> get props => [message, retryAfter];
}
```

- [ ] **Step 5: Implement the environment**

`lib/core/config/app_environment.dart`:

```dart
import 'package:flutter/foundation.dart';

/// `demo` runs entirely on mock repositories (no network, works offline);
/// `prod` talks to the platform API at [AppEnvironment.apiBaseUrl].
enum AppFlavor { demo, prod }

class InvalidEnvironment implements Exception {
  const InvalidEnvironment(this.message);

  final String message;

  @override
  String toString() => 'InvalidEnvironment: $message';
}

/// Build-time configuration from `--dart-define=APP_FLAVOR=demo|prod` and
/// `--dart-define=API_BASE_URL=https://...`. Invalid combinations fail at
/// startup instead of silently falling back.
class AppEnvironment {
  const AppEnvironment({required this.flavor, this.apiBaseUrl});

  static const demo = AppEnvironment(flavor: AppFlavor.demo);

  /// Hosts that may be reached over cleartext HTTP, in debug builds only
  /// (mirrors android/app/src/debug/res/xml/network_security_config.xml).
  static const localDevHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

  final AppFlavor flavor;

  /// Origin of the API (no path); requests use `/v1/...` paths.
  final Uri? apiBaseUrl;

  bool get isDemo => flavor == AppFlavor.demo;

  factory AppEnvironment.fromDefines() => AppEnvironment.resolve(
        flavor: const String.fromEnvironment('APP_FLAVOR', defaultValue: 'demo'),
        apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
        isDebug: kDebugMode,
      );

  factory AppEnvironment.resolve({required String flavor, required String apiBaseUrl, required bool isDebug}) {
    switch (flavor) {
      case 'demo':
        return demo;
      case 'prod':
        return AppEnvironment(flavor: AppFlavor.prod, apiBaseUrl: _checkedBaseUrl(apiBaseUrl, isDebug: isDebug));
      default:
        throw InvalidEnvironment('APP_FLAVOR must be "demo" or "prod", not "$flavor".');
    }
  }

  static Uri _checkedBaseUrl(String raw, {required bool isDebug}) {
    if (raw.trim().isEmpty) {
      throw const InvalidEnvironment('APP_FLAVOR=prod needs --dart-define=API_BASE_URL=https://...');
    }
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw InvalidEnvironment('API_BASE_URL is not an absolute URL: $raw');
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment || (uri.path.isNotEmpty && uri.path != '/')) {
      throw const InvalidEnvironment('API_BASE_URL must be an origin only, e.g. https://api.example.co.za');
    }
    final origin = uri.replace(path: '');
    if (uri.scheme == 'https') return origin;
    if (uri.scheme == 'http' && isDebug && localDevHosts.contains(uri.host)) return origin;
    throw const InvalidEnvironment(
      'API_BASE_URL must use https (http is allowed only for localhost, 127.0.0.1 or 10.0.2.2 in debug builds).',
    );
  }
}
```

- [ ] **Step 6: Implement the problem mapping**

`lib/core/network/api_problem.dart`:

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sentech_connect_app/core/error/failure.dart';

/// An RFC 9457 problem body as the platform sends it
/// (`type`, `title`, `status`, `code`, `request_id`, optional `detail`).
class ApiProblem {
  const ApiProblem({required this.status, required this.code, required this.title, this.detail, this.requestId});

  final int status;
  final String code;
  final String title;
  final String? detail;
  final String? requestId;

  static ApiProblem? tryParse(int status, Object? data) {
    Object? body = data;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } on FormatException {
        return null;
      }
    }
    if (body is! Map) return null;
    final code = body['code'];
    final title = body['title'];
    if (code is! String || title is! String) return null;
    final detail = body['detail'];
    final requestId = body['request_id'];
    return ApiProblem(
      status: status,
      code: code,
      title: title,
      detail: detail is String ? detail : null,
      requestId: requestId is String ? requestId : null,
    );
  }
}

Failure failureFromDioException(DioException e) {
  if (e.error case final Failure failure) return failure;
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const NetworkFailure('The request was cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkFailure('We could not make a secure connection. Check your network and try again.');
    case DioExceptionType.badResponse:
      final response = e.response;
      final status = response?.statusCode ?? 500;
      final problem = ApiProblem.tryParse(status, response?.data);
      final seconds = int.tryParse(response?.headers.value('retry-after') ?? '');
      return failureFromStatus(
        status,
        problem,
        requestId: problem?.requestId ?? response?.headers.value('x-request-id'),
        retryAfter: seconds == null ? null : Duration(seconds: seconds),
      );
  }
}

/// 4xx details are written for customers by the API and are shown as-is;
/// 5xx text is never shown (it can carry internals).
Failure failureFromStatus(int status, ApiProblem? problem, {String? requestId, Duration? retryAfter}) {
  final detail = problem?.detail;
  if (status == 401) return const UnauthorizedFailure();
  if (status == 404) return NotFoundFailure(detail ?? 'We could not find that.');
  if (status == 429) return RateLimitedFailure(detail ?? 'Too many attempts. Please wait and try again.', retryAfter);
  if (status >= 500 || problem == null) return ServerFailure('Something went wrong on our end.', requestId);
  if (status == 403) return ServerFailure(detail ?? 'You are not allowed to do that.', requestId);
  return ValidationFailure(detail ?? problem.title, problem.code);
}
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/app_environment_test.dart test/api_problem_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS (existing `ServerFailure(...)`/`ValidationFailure(...)` calls still compile: the new parameters are optional).

- [ ] **Step 8: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```powershell
git add pubspec.yaml pubspec.lock lib/core/config/app_environment.dart lib/core/network/api_problem.dart lib/core/error/failure.dart test/app_environment_test.dart test/api_problem_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(core): flavor environment with HTTPS enforcement and problem+json failure mapping"
```

---
### Task 3: ApiClient with tokens, single-flight refresh, idempotency keys, request ids and safe logging

**Files:**
- Create: `lib/core/network/auth_tokens.dart`, `lib/core/network/tenant_context.dart`, `lib/core/network/session_events.dart`, `lib/core/network/idempotency.dart`, `lib/core/network/token_refresher.dart`, `lib/core/network/interceptors.dart`, `lib/core/network/api_client.dart`
- Create (test support): `test/helpers/fake_http_adapter.dart`, `test/helpers/fixtures.dart`, `test/helpers/api_harness.dart`, `test/fixtures/api/token_pair.json`
- Test: `test/api_client_test.dart`

**Interfaces:**
- Consumes: `SecureStore`/`InMemorySecureStore` (existing), `PiiScrubber` (existing), `failureFromDioException`, `UnauthorizedFailure`, `NetworkFailure`, `ServerFailure` (Task 2).
- Produces:
  - `class AuthTokens { String accessToken, refreshToken, customerId, tenantSlug; DateTime accessExpiresAt; factory AuthTokens.fromTokenPair(Map<String, Object?> json, {required String tenantSlug, required DateTime now}); bool expiresWithin(Duration margin, DateTime now); Map<String, Object?> toJson(); static AuthTokens? tryFromJson(Object? json); }`
  - `abstract class TokenStore { Future<AuthTokens?> read(); Future<void> write(AuthTokens tokens); Future<void> clear(); }`; `class SecureTokenStore implements TokenStore { SecureTokenStore(SecureStore store); static const key = 'auth_tokens'; }`
  - `class TenantContext { TenantContext({String slug = defaultSlug}); static const defaultSlug = 'sentech'; String slug (validated `^[a-z0-9-]{2,40}$`); String? termsVersion; String? privacyVersion; }`
  - `class SessionEvents { Stream<void> get expired; void sessionExpired(); }`
  - `String newIdempotencyKey([Random? random])` (`app-` + 32 hex); `String newRequestId([Random? random])` (`app-` + 24 hex)
  - `sealed class RefreshOutcome`; `RefreshSucceeded(AuthTokens tokens)`, `RefreshRejected()`, `RefreshUnavailable()`; `class TokenRefresher { static const path = '/v1/auth/token/refresh'; Future<RefreshOutcome> refresh({String? staleAccessToken}); }`
  - `typedef ApiLog = void Function(String line)`; `kAuthenticated`, `kRetried`; `RequestIdInterceptor`, `AuthInterceptor`, `SafeLogInterceptor`
  - `typedef ResponseDecoder<T> = T Function(Object? data)`; `class ApiClient { ApiClient({required Uri baseUrl, required TokenStore tokens, required TenantContext tenant, required SessionEvents sessionEvents, HttpClientAdapter? adapter, ApiLog? log, DateTime Function()? now, Duration connectTimeout = 10 s, Duration receiveTimeout = 20 s}); final TenantContext tenant; late final TokenRefresher refresher; Future<Either<Failure, T>> get<T>(String path, {required ResponseDecoder<T> decode, Map<String, Object?>? query, bool authenticated = true, Duration? timeout}); post<T>(path, {required decode, Object? body, bool authenticated = true, String? idempotencyKey, Duration? timeout}); patch<T>(path, {required decode, Object? body, bool authenticated = true, Duration? timeout}); Future<Either<Failure, Unit>> delete(String path, {bool authenticated = true, Duration? timeout}); }`
  - Test support: `FakeHttpAdapter` (`on(method, path, route)`, `requests`, `requestsTo(method, path)`), `FakeReply(status, [body, headers])`, `FakeReply.problem(status, code, {title, detail, requestId, headers})`, `FakeReply.error(DioExceptionType type)`; `Object? fixture(String name)`, `Map<String, Object?> fixtureMap(String name)`, `Map<String, Object?> tokenPair({String access = 'access-2', String refresh = 'refresh-2', int expiresIn = 900})`; `class ApiHarness { ApiHarness({String tenant = 'sentech'}); FakeHttpAdapter adapter; InMemorySecureStore store; SecureTokenStore tokens; TenantContext tenantContext; SessionEvents events; DateTime now; List<String> logLines; ApiClient api; Future<void> signIn({String access = 'access-1', String refresh = 'refresh-1', Duration validFor = const Duration(minutes: 15), String? tenant}); static const customerId = '7d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d'; }`

- [ ] **Step 1: Write the test support files**

`test/fixtures/api/token_pair.json` (shape of M1 `TokenPairOut`):

```json
{
  "access_token": "access-2",
  "token_type": "Bearer",
  "expires_in": 900,
  "refresh_token": "refresh-2",
  "customer_id": "7d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d"
}
```

`test/helpers/fixtures.dart`:

```dart
import 'dart:convert';
import 'dart:io';

/// Contract fixtures in test/fixtures/api/, copied from the platform's
/// response models (apps/api/openapi.json and the M1 plan's schemas).
/// When the contract changes, change the fixture and the mapping together.
Object? fixture(String name) => jsonDecode(File('test/fixtures/api/$name').readAsStringSync());

Map<String, Object?> fixtureMap(String name) => Map<String, Object?>.from(fixture(name)! as Map);

Map<String, Object?> tokenPair({String access = 'access-2', String refresh = 'refresh-2', int expiresIn = 900}) => {
      ...fixtureMap('token_pair.json'),
      'access_token': access,
      'refresh_token': refresh,
      'expires_in': expiresIn,
    };
```

`test/helpers/fake_http_adapter.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeRoute = FutureOr<FakeReply> Function(RequestOptions request);

class FakeReply {
  const FakeReply(this.status, [this.body, this.headers = const {}]) : errorType = null;

  const FakeReply.error(DioExceptionType this.errorType)
      : status = 0,
        body = null,
        headers = const {};

  factory FakeReply.problem(
    int status,
    String code, {
    String title = 'Problem',
    String? detail,
    String requestId = 'rid-test',
    Map<String, List<String>> headers = const {},
  }) =>
      FakeReply(
        status,
        {
          'type': 'about:blank',
          'title': title,
          'status': status,
          'code': code,
          'request_id': requestId,
          'detail': ?detail,
        },
        {
          'content-type': ['application/problem+json'],
          ...headers,
        },
      );

  final int status;
  final Object? body;
  final Map<String, List<String>> headers;
  final DioExceptionType? errorType;
}

/// In-memory stand-in for the network (ruling R-M4-4). Routes are matched on
/// method + path (query ignored); unmatched requests get a 404 problem.
class FakeHttpAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final _routes = <String, FakeRoute>{};

  void on(String method, String path, FakeRoute route) => _routes['${method.toUpperCase()} $path'] = route;

  List<RequestOptions> requestsTo(String method, String path) =>
      requests.where((r) => r.method == method.toUpperCase() && r.uri.path == path).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final route = _routes['${options.method} ${options.uri.path}'];
    final reply = route == null ? FakeReply.problem(404, 'http_404', title: 'Not Found') : await route(options);
    final errorType = reply.errorType;
    if (errorType != null) throw DioException(requestOptions: options, type: errorType);
    return ResponseBody.fromString(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.status,
      headers: {
        'content-type': ['application/json'],
        ...reply.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
```

`test/helpers/api_harness.dart`:

```dart
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
```

- [ ] **Step 2: Write the failing ApiClient tests**

`test/api_client_test.dart`:

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _emptyPage = {'items': <Object>[], 'next_cursor': null};

void main() {
  late ApiHarness h;

  setUp(() => h = ApiHarness());

  Object? id(Object? d) => d;

  test('authenticated calls carry the bearer token and a request id', () async {
    await h.signIn();
    h.adapter.on('GET', '/v1/me/profile', (_) => const FakeReply(200, {'id': 'c1'}));
    final result = await h.api.get('/v1/me/profile', decode: id);
    expect(result.isRight(), isTrue);
    final sent = h.adapter.requests.single;
    expect(sent.headers['Authorization'], 'Bearer access-1');
    expect(sent.headers['X-Request-ID'], matches(RegExp(r'^app-[0-9a-f]{24}$')));
  });

  test('unauthenticated calls never carry Authorization, even when signed in', () async {
    await h.signIn();
    h.adapter.on('GET', '/v1/tenants', (_) => const FakeReply(200, {'tenants': <Object>[]}));
    await h.api.get('/v1/tenants', authenticated: false, decode: id);
    expect(h.adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('concurrent 401s share ONE refresh and each request is retried once', () async {
    await h.signIn();
    final gate = Completer<void>();
    h.adapter.on('GET', '/v1/orders', (r) {
      return r.headers['Authorization'] == 'Bearer access-2' ? const FakeReply(200, _emptyPage) : FakeReply.problem(401, 'invalid_token');
    });
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) async {
      await gate.future;
      return FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2'));
    });

    final calls = [for (var i = 0; i < 3; i++) h.api.get('/v1/orders', decode: id)];
    for (var i = 0; i < 100 && h.adapter.requestsTo('GET', '/v1/orders').length < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    gate.complete();
    final results = await Future.wait(calls);

    expect(results.every((r) => r.isRight()), isTrue);
    final refreshes = h.adapter.requestsTo('POST', '/v1/auth/token/refresh');
    expect(refreshes, hasLength(1));
    expect(refreshes.single.data, {'tenant': 'sentech', 'refresh_token': 'refresh-1'});
    expect(h.adapter.requestsTo('GET', '/v1/orders'), hasLength(6));
    expect((await h.tokens.read())!.refreshToken, 'refresh-2');
  });

  test('a request is retried at most once', () async {
    await h.signIn();
    h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(h.adapter.requestsTo('GET', '/v1/orders'), hasLength(2));
    expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh'), hasLength(1));
  });

  test('a rejected refresh clears the tokens and announces the expired session', () async {
    await h.signIn();
    final expired = expectLater(h.events.expired, emits(null));
    h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply.problem(401, 'invalid_refresh_token'));
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(await h.tokens.read(), isNull);
    await expired;
  });

  test('a refresh that cannot reach the server keeps the session (offline is not a logout)', () async {
    await h.signIn();
    var expiredEvents = 0;
    final sub = h.events.expired.listen((_) => expiredEvents++);
    h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => const FakeReply.error(DioExceptionType.connectionError));
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<NetworkFailure>());
    expect(await h.tokens.read(), isNotNull);
    await Future<void>.delayed(Duration.zero);
    expect(expiredEvents, 0);
    await sub.cancel();
  });

  test('a token about to expire is refreshed before the call (no wasted 401)', () async {
    await h.signIn(validFor: const Duration(seconds: 10));
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    h.adapter.on('GET', '/v1/orders', (r) {
      return r.headers['Authorization'] == 'Bearer access-2' ? const FakeReply(200, _emptyPage) : FakeReply.problem(401, 'invalid_token');
    });
    expect((await h.api.get('/v1/orders', decode: id)).isRight(), isTrue);
    expect(h.adapter.requestsTo('GET', '/v1/orders'), hasLength(1));
  });

  test("tokens issued for another tenant are never sent (tenant switch can't leak a session)", () async {
    await h.signIn(tenant: 'sentech');
    h.tenantContext.slug = 'acme-wifi';
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(h.adapter.requests, isEmpty);
  });

  test('no stored session -> UnauthorizedFailure without touching the network', () async {
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(h.adapter.requests, isEmpty);
  });

  test('the Idempotency-Key survives the 401 retry, so a replay cannot create a second order', () async {
    await h.signIn();
    var first = true;
    h.adapter.on('POST', '/v1/orders', (_) {
      if (first) {
        first = false;
        return FakeReply.problem(401, 'invalid_token');
      }
      return const FakeReply(201, {'id': 'o1'});
    });
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    final key = newIdempotencyKey();
    final result = await h.api.post('/v1/orders', body: {'lines': <Object>[]}, idempotencyKey: key, decode: id);
    expect(result.isRight(), isTrue);
    final sent = h.adapter.requestsTo('POST', '/v1/orders');
    expect(sent.map((r) => r.headers['Idempotency-Key']), [key, key]);
  });

  test('timeouts surface as NetworkFailure', () async {
    h.adapter.on('GET', '/v1/tenants', (_) => const FakeReply.error(DioExceptionType.receiveTimeout));
    final result = await h.api.get('/v1/tenants', authenticated: false, decode: id);
    expect(result.match((f) => f, (_) => null), isA<NetworkFailure>());
  });

  test('a per-request timeout is applied to that request only', () async {
    h.adapter.on('GET', '/v1/tenants', (_) => const FakeReply(200, {'tenants': <Object>[]}));
    await h.api.get('/v1/tenants', authenticated: false, timeout: const Duration(seconds: 3), decode: id);
    await h.api.get('/v1/tenants', authenticated: false, decode: id);
    expect(h.adapter.requests[0].receiveTimeout, const Duration(seconds: 3));
    expect(h.adapter.requests[1].receiveTimeout, const Duration(seconds: 20));
  });

  test('log lines never contain tokens, bodies, phone numbers or query strings', () async {
    await h.signIn(access: 'secret-access-token', refresh: 'secret-refresh-token');
    h.adapter.on('POST', '/v1/auth/otp/request', (_) => const FakeReply(202, {'challenge_id': 'c', 'expires_in_seconds': 300}));
    h.adapter.on('GET', '/v1/products', (_) => const FakeReply(200, _emptyPage));
    h.adapter.on('GET', '/v1/me/profile', (_) => FakeReply.problem(422, 'x', detail: 'phone +27821234567 is bad'));
    await h.api.post('/v1/auth/otp/request', authenticated: false, body: {'tenant': 'sentech', 'phone': '+27821234567'}, decode: id);
    await h.api.get('/v1/products', authenticated: false, query: {'tenant': 'sentech', 'cursor': 'abc'}, decode: id);
    await h.api.get('/v1/me/profile', decode: id);

    final log = h.logLines.join('\n');
    expect(h.logLines, hasLength(3));
    expect(log, contains('POST /v1/auth/otp/request -> 202'));
    for (final secret in ['secret-access-token', 'secret-refresh-token', '+2782', '0821234567', 'tenant=', 'cursor', 'Bearer']) {
      expect(log, isNot(contains(secret)), reason: secret);
    }
  });

  test('a malformed success body is a ServerFailure, not a crash', () async {
    h.adapter.on('GET', '/v1/tenants', (_) => const FakeReply(200, 'not a map'));
    final result = await h.api.get<int>('/v1/tenants', authenticated: false, decode: (d) => (d! as Map)['x'] as int);
    expect(result.match((f) => f, (_) => null), isA<ServerFailure>());
  });

  test('idempotency keys and request ids match the server patterns and do not repeat', () {
    final keys = {for (var i = 0; i < 200; i++) newIdempotencyKey()};
    expect(keys, hasLength(200));
    expect(keys.every(RegExp(r'^[A-Za-z0-9_.:-]{8,128}$').hasMatch), isTrue);
    expect(newRequestId(), matches(RegExp(r'^[A-Za-z0-9._-]{1,64}$')));
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/api_client_test.dart`
Expected: FAIL (compile errors: `api_client.dart`, `auth_tokens.dart`, `session_events.dart`, `tenant_context.dart`, `idempotency.dart` do not exist).

- [ ] **Step 4: Implement tokens, tenant context, session events and ids**

`lib/core/network/auth_tokens.dart`:

```dart
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';

/// The customer's API session. Lives only in secure storage (Keystore /
/// Keychain); [toString] never prints token values.
class AuthTokens extends Equatable {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.customerId,
    required this.tenantSlug,
  });

  /// From a `TokenPairOut` body (`/v1/auth/otp/verify`, `/v1/auth/token/refresh`).
  factory AuthTokens.fromTokenPair(Map<String, Object?> json, {required String tenantSlug, required DateTime now}) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final expiresIn = json['expires_in'];
    final customerId = json['customer_id'];
    if (access is! String || refresh is! String || expiresIn is! int || customerId is! String) {
      throw const FormatException('Malformed token pair');
    }
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: now.toUtc().add(Duration(seconds: expiresIn)),
      customerId: customerId,
      tenantSlug: tenantSlug,
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final String customerId;

  /// Tokens are only valid for the tenant that issued them.
  final String tenantSlug;

  bool expiresWithin(Duration margin, DateTime now) => !now.toUtc().add(margin).isBefore(accessExpiresAt);

  Map<String, Object?> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'accessExpiresAt': accessExpiresAt.toUtc().toIso8601String(),
        'customerId': customerId,
        'tenantSlug': tenantSlug,
      };

  static AuthTokens? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final expiresRaw = json['accessExpiresAt'];
    final expires = expiresRaw is String ? DateTime.tryParse(expiresRaw) : null;
    final customer = json['customerId'];
    final tenant = json['tenantSlug'];
    if (access is! String || refresh is! String || expires == null || customer is! String || tenant is! String) return null;
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: expires.toUtc(),
      customerId: customer,
      tenantSlug: tenant,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, accessExpiresAt, customerId, tenantSlug];

  @override
  String toString() => 'AuthTokens(customer: $customerId, tenant: $tenantSlug, expires: $accessExpiresAt)';
}

abstract class TokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

/// [TokenStore] on [SecureStore], cached in memory so every request does not
/// hit the Keystore. An unreadable record is deleted (start signed out).
class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._store);

  static const key = 'auth_tokens';

  final SecureStore _store;
  AuthTokens? _cache;
  var _loaded = false;

  @override
  Future<AuthTokens?> read() async {
    if (_loaded) return _cache;
    final raw = await _store.read(key);
    AuthTokens? parsed;
    if (raw != null) {
      try {
        parsed = AuthTokens.tryFromJson(jsonDecode(raw));
      } on FormatException {
        parsed = null;
      }
      if (parsed == null) await _store.delete(key);
    }
    _cache = parsed;
    _loaded = true;
    return parsed;
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    _cache = tokens;
    _loaded = true;
    await _store.write(key, jsonEncode(tokens.toJson()));
  }

  @override
  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    await _store.delete(key);
  }
}
```

`lib/core/network/tenant_context.dart`:

```dart
/// The tenant (ISP) the app is currently serving, plus the legal document
/// versions from its app-config. Set by `TenantCubit`; read by HTTP
/// repositories for `?tenant=` and request bodies.
class TenantContext {
  TenantContext({String slug = defaultSlug}) : _slug = _check(slug);

  static const defaultSlug = 'sentech';
  static final _pattern = RegExp(r'^[a-z0-9-]{2,40}$');

  String _slug;

  String get slug => _slug;

  set slug(String value) => _slug = _check(value);

  String? termsVersion;
  String? privacyVersion;

  static String _check(String value) {
    if (!_pattern.hasMatch(value)) throw ArgumentError.value(value, 'slug', 'Invalid tenant slug');
    return value;
  }
}
```

`lib/core/network/session_events.dart`:

```dart
import 'dart:async';

/// Broadcasts "the server no longer accepts this session" (refresh token
/// rejected) so `AuthCubit` can sign the customer out locally.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  void sessionExpired() => _expired.add(null);
}
```

`lib/core/network/idempotency.dart`:

```dart
import 'dart:math';

/// `Idempotency-Key` value (server pattern `^[A-Za-z0-9_.:-]{8,128}$`).
/// Generate ONE key per logical operation and reuse it for every retry.
String newIdempotencyKey([Random? random]) => 'app-${_hex(random ?? Random.secure(), 16)}';

/// `X-Request-ID` value (server pattern `^[A-Za-z0-9._-]{1,64}$`).
String newRequestId([Random? random]) => 'app-${_hex(random ?? Random.secure(), 12)}';

String _hex(Random random, int bytes) =>
    List.generate(bytes, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
```

- [ ] **Step 5: Implement the refresher and interceptors**

`lib/core/network/token_refresher.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';

sealed class RefreshOutcome {
  const RefreshOutcome();
}

final class RefreshSucceeded extends RefreshOutcome {
  const RefreshSucceeded(this.tokens);

  final AuthTokens tokens;
}

/// The server refused the refresh token: the session is over.
final class RefreshRejected extends RefreshOutcome {
  const RefreshRejected();
}

/// The refresh could not be completed (offline, timeout, 5xx, 408, 429).
/// The session is kept; the caller reports a NetworkFailure.
final class RefreshUnavailable extends RefreshOutcome {
  const RefreshUnavailable();
}

/// Single-flight token refresh. Refresh tokens rotate and reuse revokes the
/// whole family on the server, so two parallel refreshes with the same
/// token would sign the customer out: every caller shares one in-flight
/// refresh, and a caller holding an already-replaced access token gets the
/// new tokens without another network call.
class TokenRefresher {
  TokenRefresher({required TokenStore tokens, required Dio dio, required SessionEvents sessionEvents, DateTime Function()? now})
      : _tokens = tokens,
        _dio = dio,
        _sessionEvents = sessionEvents,
        _now = now ?? DateTime.now;

  static const path = '/v1/auth/token/refresh';

  final TokenStore _tokens;
  final Dio _dio;
  final SessionEvents _sessionEvents;
  final DateTime Function() _now;
  Future<RefreshOutcome>? _inFlight;

  /// [staleAccessToken] is the token the caller used; pass null to force a
  /// network refresh (e.g. to prove a stored session is still valid).
  Future<RefreshOutcome> refresh({String? staleAccessToken}) {
    final running = _inFlight;
    if (running != null) return running;
    final next = _run(staleAccessToken).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = next;
    return next;
  }

  Future<RefreshOutcome> _run(String? staleAccessToken) async {
    final current = await _tokens.read();
    if (current == null) return const RefreshRejected();
    if (staleAccessToken != null &&
        current.accessToken != staleAccessToken &&
        !current.expiresWithin(Duration.zero, _now())) {
      return RefreshSucceeded(current);
    }
    try {
      final response = await _dio.post<Object?>(
        path,
        data: {'tenant': current.tenantSlug, 'refresh_token': current.refreshToken},
      );
      final data = response.data;
      if (data is! Map) return const RefreshUnavailable();
      final fresh = AuthTokens.fromTokenPair(Map<String, Object?>.from(data), tenantSlug: current.tenantSlug, now: _now());
      await _tokens.write(fresh);
      return RefreshSucceeded(fresh);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500 && status != 408 && status != 429) {
        await _tokens.clear();
        _sessionEvents.sessionExpired();
        return const RefreshRejected();
      }
      return const RefreshUnavailable();
    } on FormatException {
      return const RefreshUnavailable();
    }
  }
}
```

`lib/core/network/interceptors.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:sentech_connect_app/core/diagnostics/pii_scrubber.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/network/token_refresher.dart';

/// `RequestOptions.extra` keys.
const kAuthenticated = 'sc.authenticated';
const kRetried = 'sc.retried';
const _kStopwatch = 'sc.stopwatch';

typedef ApiLog = void Function(String line);

/// Adds an `X-Request-ID` (kept on retries) for log correlation.
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor([String Function()? newId]) : _newId = newId ?? newRequestId;

  final String Function() _newId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Request-ID', _newId);
    handler.next(options);
  }
}

/// Bearer tokens for `authenticated` requests: proactive refresh shortly
/// before expiry, one refresh + one retry on 401, and never a token issued
/// for a different tenant than the one currently selected.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStore tokens,
    required TenantContext tenant,
    required TokenRefresher refresher,
    required Dio dio,
    DateTime Function()? now,
  })  : _tokens = tokens,
        _tenant = tenant,
        _refresher = refresher,
        _dio = dio,
        _now = now ?? DateTime.now;

  static const refreshMargin = Duration(seconds: 30);

  final TokenStore _tokens;
  final TenantContext _tenant;
  final TokenRefresher _refresher;
  final Dio _dio;
  final DateTime Function() _now;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[kAuthenticated] != true) {
      handler.next(options);
      return;
    }
    var tokens = await _tokens.read();
    if (tokens == null || tokens.tenantSlug != _tenant.slug) {
      handler.reject(DioException(requestOptions: options, error: const UnauthorizedFailure()));
      return;
    }
    if (tokens.expiresWithin(refreshMargin, _now())) {
      switch (await _refresher.refresh(staleAccessToken: tokens.accessToken)) {
        case RefreshSucceeded(tokens: final fresh):
          tokens = fresh;
        case RefreshRejected():
          handler.reject(DioException(requestOptions: options, error: const UnauthorizedFailure()));
          return;
        case RefreshUnavailable():
          break; // try the current token; the server decides
      }
    }
    options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final eligible = err.response?.statusCode == 401 &&
        options.extra[kAuthenticated] == true &&
        options.extra[kRetried] != true;
    if (!eligible) {
      handler.next(err);
      return;
    }
    final sent = options.headers['Authorization'];
    final stale = sent is String && sent.startsWith('Bearer ') ? sent.substring(7) : null;
    switch (await _refresher.refresh(staleAccessToken: stale)) {
      case RefreshSucceeded():
        options.extra[kRetried] = true;
        try {
          handler.resolve(await _dio.fetch<Object?>(options));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      case RefreshRejected():
        handler.next(err);
      case RefreshUnavailable():
        handler.next(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'token refresh unavailable',
        ));
    }
  }
}

/// One line per request: method, path (no query), outcome, duration and
/// request id. Never headers or bodies (tokens, phone numbers, OTPs), and
/// the line is passed through PiiScrubber as a safety net.
class SafeLogInterceptor extends Interceptor {
  SafeLogInterceptor(this._log);

  final ApiLog _log;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_kStopwatch] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _log(_line(response.requestOptions, '${response.statusCode}', response.headers.value('x-request-id')));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.response?.headers.value('x-request-id') ?? err.requestOptions.headers['X-Request-ID'];
    _log(_line(err.requestOptions, '${err.response?.statusCode ?? err.type.name}', requestId is String ? requestId : null));
    handler.next(err);
  }

  String _line(RequestOptions options, String outcome, String? requestId) {
    final stopwatch = options.extra[_kStopwatch];
    final ms = stopwatch is Stopwatch ? stopwatch.elapsedMilliseconds : -1;
    return PiiScrubber.scrub('[api] ${options.method} ${options.uri.path} -> $outcome ${ms}ms rid=${requestId ?? '-'}');
  }
}
```

Note on the "retried at most once" test: the retried request runs through `SafeLogInterceptor` inside the nested `fetch`, so a 401-retry produces two log lines for one logical call. The log test above uses calls that do not retry.

- [ ] **Step 6: Implement the client**

`lib/core/network/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_problem.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/interceptors.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/network/token_refresher.dart';

typedef ResponseDecoder<T> = T Function(Object? data);

/// The only class that talks HTTP. Repositories call it with a path and a
/// decoder and get `Either<Failure, T>` back; transport concerns (tokens,
/// refresh, problem+json, ids, timeouts, logging) live here.
class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required TokenStore tokens,
    required this.tenant,
    required SessionEvents sessionEvents,
    HttpClientAdapter? adapter,
    ApiLog? log,
    DateTime Function()? now,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 20),
  }) {
    final options = BaseOptions(
      baseUrl: baseUrl.toString(),
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: receiveTimeout,
      headers: const {'Accept': 'application/json, application/problem+json'},
      contentType: Headers.jsonContentType,
    );
    final logger = log ?? _defaultLog;
    final refreshDio = Dio(options);
    _dio = Dio(options);
    if (adapter != null) {
      refreshDio.httpClientAdapter = adapter;
      _dio.httpClientAdapter = adapter;
    }
    refreshDio.interceptors.addAll([RequestIdInterceptor(), SafeLogInterceptor(logger)]);
    refresher = TokenRefresher(tokens: tokens, dio: refreshDio, sessionEvents: sessionEvents, now: now);
    _dio.interceptors.addAll([
      RequestIdInterceptor(),
      AuthInterceptor(tokens: tokens, tenant: tenant, refresher: refresher, dio: _dio, now: now),
      SafeLogInterceptor(logger),
    ]);
  }

  final TenantContext tenant;
  late final Dio _dio;
  late final TokenRefresher refresher;

  static void _defaultLog(String line) {
    if (kDebugMode) debugPrint(line);
  }

  Future<Either<Failure, T>> get<T>(
    String path, {
    required ResponseDecoder<T> decode,
    Map<String, Object?>? query,
    bool authenticated = true,
    Duration? timeout,
  }) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query, options: _options(authenticated, timeout, null)), decode);

  Future<Either<Failure, T>> post<T>(
    String path, {
    required ResponseDecoder<T> decode,
    Object? body,
    bool authenticated = true,
    String? idempotencyKey,
    Duration? timeout,
  }) =>
      _send(() => _dio.post<Object?>(path, data: body, options: _options(authenticated, timeout, idempotencyKey)), decode);

  Future<Either<Failure, T>> patch<T>(
    String path, {
    required ResponseDecoder<T> decode,
    Object? body,
    bool authenticated = true,
    Duration? timeout,
  }) =>
      _send(() => _dio.patch<Object?>(path, data: body, options: _options(authenticated, timeout, null)), decode);

  Future<Either<Failure, Unit>> delete(String path, {bool authenticated = true, Duration? timeout}) =>
      _send(() => _dio.delete<Object?>(path, options: _options(authenticated, timeout, null)), (_) => unit);

  Options _options(bool authenticated, Duration? timeout, String? idempotencyKey) => Options(
        extra: {kAuthenticated: authenticated},
        sendTimeout: timeout,
        receiveTimeout: timeout,
        headers: {'Idempotency-Key': ?idempotencyKey},
      );

  Future<Either<Failure, T>> _send<T>(Future<Response<Object?>> Function() call, ResponseDecoder<T> decode) async {
    final Response<Object?> response;
    try {
      response = await call();
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    }
    try {
      return Right(decode(response.data));
    } on Object {
      return const Left(ServerFailure('We received an unexpected response. Please try again.'));
    }
  }
}
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/api_client_test.dart`
Expected: PASS (15 tests). If the concurrency test is flaky, do NOT add sleeps: check that `TokenRefresher.refresh` assigns `_inFlight` before any `await`.
Run: `flutter test`
Expected: all PASS.

- [ ] **Step 8: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```powershell
git add lib/core/network/auth_tokens.dart lib/core/network/tenant_context.dart lib/core/network/session_events.dart lib/core/network/idempotency.dart lib/core/network/token_refresher.dart lib/core/network/interceptors.dart lib/core/network/api_client.dart
git add test/helpers/fake_http_adapter.dart test/helpers/fixtures.dart test/helpers/api_harness.dart test/fixtures/api/token_pair.json test/api_client_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(network): ApiClient with single-flight token refresh, idempotency keys, request ids and PII-free logs"
```

---

### Task 4: Tenant directory and app-config data layer, flavor-aware locator

**Files:**
- Create: `lib/features/tenant/domain/entities/tenant.dart`, `lib/features/tenant/domain/entities/app_config.dart`, `lib/features/tenant/domain/repositories/tenant_repository.dart`, `lib/features/tenant/data/repositories/mock_tenant_repository.dart`, `lib/features/tenant/data/repositories/http_tenant_repository.dart`, `test/fixtures/api/tenants.json`, `test/fixtures/api/app_config.json`
- Modify: `lib/app/locator.dart` (full replacement below), `lib/main.dart`
- Test: `test/http_tenant_repository_test.dart`, `test/locator_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `TokenStore`/`SecureTokenStore`, `TenantContext`, `SessionEvents` (Task 3); `AppEnvironment` (Task 2); `NotFoundFailure`, `NetworkFailure`.
- Produces:
  - `class TenantBranding { const TenantBranding({Color? primaryColor, Uri? logoUrl}); factory TenantBranding.fromJson(Map<String, Object?>); Map<String, Object?> toJson(); }`
  - `class Tenant { const Tenant({required String slug, required String name, required String type, TenantBranding branding = const TenantBranding()}); factory Tenant.fromJson(Map<String, Object?>); Map<String, Object?> toJson(); bool get isReseller; }`
  - `class FeatureFlags { const FeatureFlags({required bool hotspotPasses, required bool rica, required bool cpe}); static const demo = FeatureFlags(hotspotPasses: true, rica: true, cpe: true); fromJson/toJson }`
  - `class LegalVersions { const LegalVersions({required String terms, required String privacy}); fromJson/toJson }`
  - `class AppConfig { const AppConfig({required Tenant tenant, required String minAppVersion, required FeatureFlags featureFlags, required LegalVersions legal}); factory AppConfig.fromJson(Map<String, Object?>) (throws FormatException); Map<String, Object?> toJson(); }`
  - `abstract class TenantRepository { Future<Either<Failure, List<Tenant>>> listTenants(); Future<Either<Failure, AppConfig>> getAppConfig(String slug); }`
  - `MockTenantRepository([SimulatedNetwork? network])` with `static const sentech`, `static const demoConfig`; `HttpTenantRepository(ApiClient api)`.
  - `lib/app/locator.dart`: `void setupLocator({CrashReporter? crashReporter, AppEnvironment environment = AppEnvironment.demo})`; `const stillMockInProd = <Type>[...]`; registers `AppEnvironment`, `TenantContext`, `SessionEvents` in both flavors and `TokenStore` + `ApiClient` in prod only.

- [ ] **Step 1: Add the contract fixtures**

`test/fixtures/api/tenants.json` (M0 `TenantDirectory`):

```json
{
  "tenants": [
    {"slug": "sentech", "name": "Sentech", "type": "operator", "branding": {}},
    {
      "slug": "acme-wifi",
      "name": "Acme Wi-Fi",
      "type": "reseller",
      "branding": {"primary_color": "#123456", "logo_url": "https://cdn.example.test/acme.png", "tagline": "ignored"}
    }
  ]
}
```

`test/fixtures/api/app_config.json` (M0 `AppConfig`; M1 adds per-tenant flags with the same shape):

```json
{
  "tenant": {"slug": "acme-wifi", "name": "Acme Wi-Fi", "type": "reseller", "branding": {"primary_color": "#123456"}},
  "min_app_version": "1.0.0",
  "feature_flags": {"hotspot_passes": true, "rica": false, "cpe": false},
  "legal": {"terms": "2026-09-30", "privacy": "2026-09-30"}
}
```

- [ ] **Step 2: Write the failing tests**

`test/http_tenant_repository_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

void main() {
  late ApiHarness h;
  late HttpTenantRepository repo;

  setUp(() {
    h = ApiHarness();
    repo = HttpTenantRepository(h.api);
  });

  test('lists the ISP directory without authentication', () async {
    h.adapter.on('GET', '/v1/tenants', (_) => FakeReply(200, fixture('tenants.json')));
    final tenants = (await repo.listTenants()).getOrElse((f) => throw StateError(f.message));
    expect(tenants.map((t) => t.slug), ['sentech', 'acme-wifi']);
    expect(tenants[1].isReseller, isTrue);
    expect(tenants[1].branding.primaryColor, const Color(0xFF123456));
    expect(tenants[1].branding.logoUrl, Uri.parse('https://cdn.example.test/acme.png'));
    expect(h.adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('loads app-config for the chosen tenant', () async {
    h.adapter.on('GET', '/v1/app-config', (_) => FakeReply(200, fixture('app_config.json')));
    final config = (await repo.getAppConfig('acme-wifi')).getOrElse((f) => throw StateError(f.message));
    expect(h.adapter.requests.single.uri.queryParameters, {'tenant': 'acme-wifi'});
    expect(config.tenant.name, 'Acme Wi-Fi');
    expect(config.featureFlags, const FeatureFlags(hotspotPasses: true, rica: false, cpe: false));
    expect(config.legal, const LegalVersions(terms: '2026-09-30', privacy: '2026-09-30'));
    expect(config.minAppVersion, '1.0.0');
  });

  test('an unknown or suspended tenant is a NotFoundFailure', () async {
    h.adapter.on('GET', '/v1/app-config', (_) => FakeReply.problem(404, 'tenant_not_found', detail: 'Unknown tenant.'));
    expect((await repo.getAppConfig('gone')).match((f) => f, (_) => null), isA<NotFoundFailure>());
  });

  test('branding ignores non-https logos and malformed colours', () {
    final branding = TenantBranding.fromJson({'primary_color': 'red', 'logo_url': 'http://x.test/logo.png'});
    expect(branding.primaryColor, isNull);
    expect(branding.logoUrl, isNull);
  });

  test('a config missing required fields is rejected, not half-applied', () {
    expect(() => AppConfig.fromJson({'tenant': fixtureMap('app_config.json')['tenant']}), throwsFormatException);
  });

  test('app-config round-trips through JSON (used for the offline cache)', () {
    final config = AppConfig.fromJson(fixtureMap('app_config.json'));
    expect(AppConfig.fromJson(config.toJson()), config);
  });
}
```

`test/locator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/mock_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

import 'helpers/test_setup.dart';

void main() {
  final prod = AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'https://api.example.test', isDebug: false);

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await locator.reset();
  });

  test('demo wires mocks and never creates an API client', () {
    setupLocator();
    registerTestFakes();
    expect(locator<TenantRepository>(), isA<MockTenantRepository>());
    expect(locator.isRegistered<ApiClient>(), isFalse);
  });

  test('prod wires the API client and HTTP repositories', () {
    setupLocator(environment: prod);
    registerTestFakes();
    expect(locator<ApiClient>(), isA<ApiClient>());
    expect(locator<TenantRepository>(), isA<HttpTenantRepository>());
  });

  test('repositories without a backend stay mock in prod (and are listed)', () {
    setupLocator(environment: prod);
    registerTestFakes();
    expect(stillMockInProd, isNotEmpty);
    for (final type in stillMockInProd) {
      final instance = locator.get<Object>(type: type);
      expect(instance.runtimeType.toString(), startsWith('Mock'), reason: '$type');
    }
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/http_tenant_repository_test.dart test/locator_test.dart`
Expected: FAIL (compile errors: tenant feature files, `stillMockInProd`, `environment:` parameter missing).

- [ ] **Step 4: Implement the tenant domain**

`lib/features/tenant/domain/entities/tenant.dart`:

```dart
import 'dart:ui' show Color;

import 'package:equatable/equatable.dart';

/// Public, per-tenant look (spec §12: branding is public and never holds
/// secrets). Only `primary_color` (#RRGGBB) and `logo_url` (https) are read
/// (ruling R-M4-6); anything else is ignored.
class TenantBranding extends Equatable {
  const TenantBranding({this.primaryColor, this.logoUrl});

  static final _hex = RegExp(r'^#([0-9a-fA-F]{6})$');

  final Color? primaryColor;
  final Uri? logoUrl;

  factory TenantBranding.fromJson(Map<String, Object?> json) {
    final colour = json['primary_color'];
    final logo = json['logo_url'];
    Color? parsedColour;
    if (colour is String) {
      final match = _hex.firstMatch(colour);
      if (match != null) parsedColour = Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
    }
    Uri? parsedLogo;
    if (logo is String) {
      final uri = Uri.tryParse(logo);
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) parsedLogo = uri;
    }
    return TenantBranding(primaryColor: parsedColour, logoUrl: parsedLogo);
  }

  Map<String, Object?> toJson() => {
        if (primaryColor case final colour?)
          'primary_color': '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        if (logoUrl case final logo?) 'logo_url': logo.toString(),
      };

  @override
  List<Object?> get props => [primaryColor, logoUrl];
}

/// An ISP served by the platform (spec §12). Customers belong to one tenant.
class Tenant extends Equatable {
  const Tenant({required this.slug, required this.name, required this.type, this.branding = const TenantBranding()});

  factory Tenant.fromJson(Map<String, Object?> json) {
    final slug = json['slug'];
    final name = json['name'];
    final type = json['type'];
    final branding = json['branding'];
    if (slug is! String || name is! String || type is! String) throw const FormatException('Malformed tenant');
    return Tenant(
      slug: slug,
      name: name,
      type: type,
      branding: branding is Map ? TenantBranding.fromJson(Map<String, Object?>.from(branding)) : const TenantBranding(),
    );
  }

  final String slug;
  final String name;

  /// `operator` (runs its own hotspots) or `reseller` (sells on a host network).
  final String type;
  final TenantBranding branding;

  bool get isReseller => type == 'reseller';

  Map<String, Object?> toJson() => {'slug': slug, 'name': name, 'type': type, 'branding': branding.toJson()};

  @override
  List<Object?> get props => [slug, name, type, branding];
}
```

`lib/features/tenant/domain/entities/app_config.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

/// Per-tenant switches (spec §6: RICA/CPE off at launch). A missing flag is
/// treated as OFF, so an unfinished feature never appears by accident.
class FeatureFlags extends Equatable {
  const FeatureFlags({required this.hotspotPasses, required this.rica, required this.cpe});

  /// Demo flavor: everything the mock repositories can show is on.
  static const demo = FeatureFlags(hotspotPasses: true, rica: true, cpe: true);

  final bool hotspotPasses;
  final bool rica;
  final bool cpe;

  factory FeatureFlags.fromJson(Map<String, Object?> json) => FeatureFlags(
        hotspotPasses: json['hotspot_passes'] == true,
        rica: json['rica'] == true,
        cpe: json['cpe'] == true,
      );

  Map<String, Object?> toJson() => {'hotspot_passes': hotspotPasses, 'rica': rica, 'cpe': cpe};

  @override
  List<Object?> get props => [hotspotPasses, rica, cpe];
}

/// Versions (YYYY-MM-DD) of the terms and privacy notice customers accept.
class LegalVersions extends Equatable {
  const LegalVersions({required this.terms, required this.privacy});

  factory LegalVersions.fromJson(Map<String, Object?> json) {
    final terms = json['terms'];
    final privacy = json['privacy'];
    if (terms is! String || privacy is! String) throw const FormatException('Malformed legal versions');
    return LegalVersions(terms: terms, privacy: privacy);
  }

  final String terms;
  final String privacy;

  Map<String, Object?> toJson() => {'terms': terms, 'privacy': privacy};

  @override
  List<Object?> get props => [terms, privacy];
}

/// `GET /v1/app-config?tenant=<slug>`.
class AppConfig extends Equatable {
  const AppConfig({required this.tenant, required this.minAppVersion, required this.featureFlags, required this.legal});

  factory AppConfig.fromJson(Map<String, Object?> json) {
    final tenant = json['tenant'];
    final minVersion = json['min_app_version'];
    final flags = json['feature_flags'];
    final legal = json['legal'];
    if (tenant is! Map || minVersion is! String || flags is! Map || legal is! Map) {
      throw const FormatException('Malformed app-config');
    }
    return AppConfig(
      tenant: Tenant.fromJson(Map<String, Object?>.from(tenant)),
      minAppVersion: minVersion,
      featureFlags: FeatureFlags.fromJson(Map<String, Object?>.from(flags)),
      legal: LegalVersions.fromJson(Map<String, Object?>.from(legal)),
    );
  }

  final Tenant tenant;
  final String minAppVersion;
  final FeatureFlags featureFlags;
  final LegalVersions legal;

  Map<String, Object?> toJson() => {
        'tenant': tenant.toJson(),
        'min_app_version': minAppVersion,
        'feature_flags': featureFlags.toJson(),
        'legal': legal.toJson(),
      };

  @override
  List<Object?> get props => [tenant, minAppVersion, featureFlags, legal];
}
```

`lib/features/tenant/domain/repositories/tenant_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

abstract class TenantRepository {
  /// Directory of active, listed ISPs (`GET /v1/tenants`).
  Future<Either<Failure, List<Tenant>>> listTenants();

  /// Branding, flags, legal versions and minimum app version for [slug].
  /// An unknown or suspended tenant is a `NotFoundFailure`.
  Future<Either<Failure, AppConfig>> getAppConfig(String slug);
}
```

- [ ] **Step 5: Implement the repositories**

`lib/features/tenant/data/repositories/mock_tenant_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

/// Demo flavor: Sentech is the only tenant and every feature flag is on.
class MockTenantRepository implements TenantRepository {
  MockTenantRepository([SimulatedNetwork? network]) : _network = network ?? SimulatedNetwork();

  static const sentech = Tenant(slug: 'sentech', name: 'Sentech', type: 'operator');
  static const demoConfig = AppConfig(
    tenant: sentech,
    minAppVersion: '1.0.0',
    featureFlags: FeatureFlags.demo,
    legal: LegalVersions(terms: '2026-09-30', privacy: '2026-09-30'),
  );

  final SimulatedNetwork _network;

  @override
  Future<Either<Failure, List<Tenant>>> listTenants() async {
    if (_network.failure case final failure?) return Left(failure);
    return const Right([sentech]);
  }

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async {
    if (_network.failure case final failure?) return Left(failure);
    if (slug != sentech.slug) return const Left(NotFoundFailure('Unknown provider.'));
    return const Right(demoConfig);
  }
}
```

`lib/features/tenant/data/repositories/http_tenant_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

class HttpTenantRepository implements TenantRepository {
  HttpTenantRepository(this._api);

  static const _timeout = Duration(seconds: 10);

  final ApiClient _api;

  @override
  Future<Either<Failure, List<Tenant>>> listTenants() => _api.get<List<Tenant>>(
        '/v1/tenants',
        authenticated: false,
        timeout: _timeout,
        decode: (data) {
          final tenants = (data! as Map)['tenants']! as List;
          return [for (final t in tenants) Tenant.fromJson(Map<String, Object?>.from(t as Map))];
        },
      );

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) => _api.get<AppConfig>(
        '/v1/app-config',
        authenticated: false,
        query: {'tenant': slug},
        timeout: _timeout,
        decode: (data) => AppConfig.fromJson(Map<String, Object?>.from(data! as Map)),
      );
}
```

- [ ] **Step 6: Make the locator flavor-aware**

Replace `lib/app/locator.dart` with (imports: keep every existing import and add the ones listed first):

```dart
import 'package:get_it/get_it.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/mock_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
// ...all imports already present in the current file stay unchanged...

final locator = GetIt.instance;

/// Repositories with no platform backend yet (M1 covers tenants, auth,
/// catalog, orders, payments, entitlements and privacy only). They are mock
/// in BOTH flavors (ruling R-M4-8) and are swapped here once their API
/// exists; nothing above this file changes. README lists the same set.
const stillMockInProd = <Type>[
  CoverageRepository,
  FreeWifiRepository,
  WifiHotspotsRepository,
  VoucherRepository,
  AccountRepository,
  PromotionsRepository,
  SupportRepository,
  LivenessRepository,
];

/// [environment] comes from `AppEnvironment.fromDefines()` in main.dart;
/// tests use the default (demo), which never creates an [ApiClient].
void setupLocator({CrashReporter? crashReporter, AppEnvironment environment = AppEnvironment.demo}) {
  locator.registerSingleton<AppEnvironment>(environment);
  _registerPlatformServices(crashReporter);
  _registerStillMockRepositories();
  final baseUrl = environment.apiBaseUrl;
  if (environment.isDemo || baseUrl == null) {
    _registerDemoRepositories();
  } else {
    _registerProdRepositories(baseUrl);
  }
}

void _registerPlatformServices(CrashReporter? crashReporter) {
  // Tests re-register these with fakes (see test/helpers/test_setup.dart).
  locator.registerLazySingleton<ConnectivityService>(() => ConnectivityPlusService());
  locator.registerLazySingleton<SimulatedNetwork>(() => SimulatedNetwork());
  locator.registerSingleton<CrashReporter>(crashReporter ?? ConsoleCrashReporter());
  locator.registerLazySingleton<PlatformClock>(() => SystemPlatformClock());
  locator.registerLazySingleton<SecureStore>(() => FlutterSecureStore());
  locator.registerLazySingleton<BiometricAuthenticator>(() => LocalAuthBiometricAuthenticator());
  locator.registerLazySingleton<SessionStore>(() => SecureSessionStore(locator()));
  locator.registerLazySingleton<NotificationService>(() => PermissionNotificationService());
  locator.registerLazySingleton<TenantContext>(() => TenantContext());
  locator.registerLazySingleton<SessionEvents>(() => SessionEvents());
  locator.registerLazySingleton<PersonalDataWiper>(
    () => DefaultPersonalDataWiper(
      registration: locator(),
      checkout: locator(),
      freeWifi: locator(),
      consent: locator(),
    ),
  );
}

void _registerStillMockRepositories() {
  locator.registerLazySingleton<CoverageRepository>(() => MockCoverageRepository(locator()));
  locator.registerLazySingleton<LivenessRepository>(() => MockLivenessRepository());
  locator.registerLazySingleton<AccountRepository>(() => MockAccountRepository(locator()));
  locator.registerLazySingleton<SupportRepository>(() => MockSupportRepository());
  locator.registerLazySingleton<PromotionsRepository>(() => MockPromotionsRepository());
  locator.registerLazySingleton<VoucherRepository>(() => MockVoucherRepository(locator(), network: locator()));
  locator.registerLazySingleton<FreeWifiRepository>(() => MockFreeWifiRepository(locator(), clock: locator()));
  locator.registerLazySingleton<WifiHotspotsRepository>(() => MockWifiHotspotsRepository());
}

void _registerDemoRepositories() {
  locator.registerLazySingleton<TenantRepository>(() => MockTenantRepository(locator()));
  locator.registerLazySingleton<ConsentRepository>(() => LocalConsentRepository(locator()));
  locator.registerLazySingleton<PrivacyRepository>(() => MockPrivacyRepository(locator()));
  locator.registerLazySingleton<AuthRepository>(() => MockAuthRepository());
  locator.registerLazySingleton<CatalogRepository>(() => MockCatalogRepository(locator()));
  locator.registerLazySingleton<CheckoutRepository>(() => MockCheckoutRepository(locator(), network: locator()));
  locator.registerLazySingleton<RegistrationRepository>(() => LocalRegistrationRepository(locator()));
}

void _registerProdRepositories(Uri baseUrl) {
  locator.registerLazySingleton<TokenStore>(() => SecureTokenStore(locator()));
  locator.registerLazySingleton<ApiClient>(
    () => ApiClient(baseUrl: baseUrl, tokens: locator(), tenant: locator(), sessionEvents: locator()),
  );
  locator.registerLazySingleton<TenantRepository>(() => HttpTenantRepository(locator()));
  locator.registerLazySingleton<ConsentRepository>(() => LocalConsentRepository(locator()));
  locator.registerLazySingleton<PrivacyRepository>(() => MockPrivacyRepository(locator()));
  locator.registerLazySingleton<AuthRepository>(() => MockAuthRepository());
  locator.registerLazySingleton<CatalogRepository>(() => MockCatalogRepository(locator()));
  locator.registerLazySingleton<CheckoutRepository>(() => MockCheckoutRepository(locator(), network: locator()));
  locator.registerLazySingleton<RegistrationRepository>(() => LocalRegistrationRepository(locator()));
}
```

The last six lines of `_registerProdRepositories` are deliberately still mocks; Tasks 6, 7, 9 and 10 replace them one by one with HTTP implementations.

- [ ] **Step 7: Read the environment in main.dart**

In `lib/main.dart`, add `import 'package:sentech_connect_app/core/config/app_environment.dart';` and replace `setupLocator(crashReporter: crashReporter);` with:

```dart
  // Fails fast on an invalid APP_FLAVOR / API_BASE_URL (e.g. http:// to a
  // remote host): the error reaches the crash reporter via runGuarded.
  setupLocator(crashReporter: crashReporter, environment: AppEnvironment.fromDefines());
```

- [ ] **Step 8: Run the tests**

Run: `flutter test test/http_tenant_repository_test.dart test/locator_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS.

- [ ] **Step 9: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```powershell
git add lib/features/tenant/domain/entities/tenant.dart lib/features/tenant/domain/entities/app_config.dart lib/features/tenant/domain/repositories/tenant_repository.dart
git add lib/features/tenant/data/repositories/mock_tenant_repository.dart lib/features/tenant/data/repositories/http_tenant_repository.dart
git add lib/app/locator.dart lib/main.dart test/fixtures/api/tenants.json test/fixtures/api/app_config.json test/http_tenant_repository_test.dart test/locator_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(tenant): ISP directory and app-config repositories; demo/prod locator with still-mock list"
```

---

### Task 5: Tenant picker, tenant branding, min-version gate and tenant switching

**Files:**
- Create: `lib/core/local/tenant_preferences.dart`, `lib/core/utils/version.dart`, `lib/app/app_version.dart`, `lib/features/tenant/presentation/bloc/tenant_cubit.dart`, `lib/features/tenant/presentation/pages/tenant_picker_page.dart`, `lib/features/tenant/presentation/pages/update_required_page.dart`, `lib/features/tenant/presentation/widgets/tenant_logo.dart`
- Modify: `lib/app/theme/app_theme.dart`, `lib/app/app.dart`, `lib/app/router/app_router.dart`, `lib/app/main_shell.dart`, `lib/features/account/presentation/pages/account_page.dart`, `lib/app/locator.dart`, `test/helpers/test_setup.dart`, `lib/l10n/app_en.arb` (+ regenerated `lib/l10n/app_localizations*.dart`)
- Test: `test/version_test.dart`, `test/tenant_cubit_test.dart`, `test/tenant_ui_test.dart`

**Interfaces:**
- Consumes: `TenantRepository`, `Tenant`, `AppConfig`, `FeatureFlags`, `LegalVersions`, `MockTenantRepository` (Task 4); `TenantContext` (Task 3); `NotFoundFailure`, `NetworkFailure`; `AuthCubit.logOut()` (existing).
- Produces:
  - `abstract class TenantPreferences { Future<String?> loadSlug(); Future<void> saveSlug(String slug); Future<String?> loadConfigJson(); Future<void> saveConfigJson(String json); Future<void> clear(); }`; `SharedPrefsTenantPreferences`; `InMemoryTenantPreferences({String? slug, String? configJson})`.
  - `bool isVersionAtLeast(String current, String minimum)`; `const appVersion = '1.0.0'`.
  - `enum TenantStatus { initial, loading, needsSelection, ready, updateRequired, failure }`; `class TenantState { TenantStatus status; List<Tenant> tenants; AppConfig? config; Failure? failure; FeatureFlags get featureFlags; bool get isSettled; }`
  - `class TenantCubit extends Cubit<TenantState> { TenantCubit({required TenantRepository repository, required TenantContext context, required TenantPreferences preferences, String currentAppVersion = appVersion, Future<void> Function()? onTenantChanging}); Future<void> bootstrap(); Future<void> openPicker(); void cancelPicker(); Future<void> select(Tenant tenant); Future<void> retry(); }`
  - `TenantPickerPage`, `UpdateRequiredPage`, `TenantLogo({required Tenant tenant, double height = 32})`.
  - `AppTheme.light({Color? primary})`, `AppTheme.dark({Color? primary})`.
  - Router: `AppRoutes.tenantPicker = '/tenant'`, `AppRoutes.updateRequired = '/update-required'`; `String? tenantRedirect(TenantState tenant, Uri uri)`; `AppRouter(AuthCubit authCubit, {TenantCubit? tenantCubit, String initialLocation})`.
  - `MainShell({..., VoidCallback? onChangeProvider, String? providerName})`; `AccountPage({super.key, VoidCallback? onChangeProvider, String? providerName})`.
  - l10n keys: `tenantPickerTitle`, `tenantPickerSubtitle`, `tenantTypeOperator`, `tenantTypeReseller`, `tenantChangeTitle`, `tenantChangeBody`, `tenantChangeConfirm`, `updateRequiredTitle`, `updateRequiredBody`, `accountProvider`, `accountChangeProvider`.

- [ ] **Step 1: Write the failing tests**

`test/version_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/app_version.dart';
import 'package:sentech_connect_app/core/utils/version.dart';

void main() {
  test('compares dotted versions numerically', () {
    expect(isVersionAtLeast('1.0.0', '1.0.0'), isTrue);
    expect(isVersionAtLeast('1.2.10', '1.2.9'), isTrue);
    expect(isVersionAtLeast('1.2.9', '1.2.10'), isFalse);
    expect(isVersionAtLeast('2.0', '1.9.9'), isTrue);
    expect(isVersionAtLeast('1.0.0+7', '1.0.0'), isTrue);
    expect(isVersionAtLeast('1.0.0', '1.0.1-beta'), isFalse);
  });

  test('an unparseable minimum never blocks the app (ruling R-M4-14)', () {
    expect(isVersionAtLeast('1.0.0', ''), isTrue);
    expect(isVersionAtLeast('1.0.0', 'latest'), isTrue);
  });

  test('appVersion matches the pubspec version', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.substring('version:'.length).trim().split('+').first, appVersion);
  });
}
```

`test/tenant_cubit_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

const _sentech = Tenant(slug: 'sentech', name: 'Sentech', type: 'operator');
const _acme = Tenant(slug: 'acme-wifi', name: 'Acme Wi-Fi', type: 'reseller');

AppConfig configFor(Tenant tenant, {String min = '1.0.0'}) => AppConfig(
      tenant: tenant,
      minAppVersion: min,
      featureFlags: const FeatureFlags(hotspotPasses: true, rica: false, cpe: false),
      legal: const LegalVersions(terms: '2026-09-30', privacy: '2026-09-29'),
    );

class _FakeTenantRepository implements TenantRepository {
  _FakeTenantRepository({this.tenants = const [_sentech]});

  List<Tenant> tenants;
  Failure? listFailure;
  final configs = <String, Either<Failure, AppConfig>>{
    'sentech': Right(configFor(_sentech)),
    'acme-wifi': Right(configFor(_acme)),
  };
  final calls = <String>[];

  @override
  Future<Either<Failure, List<Tenant>>> listTenants() async {
    calls.add('list');
    final failure = listFailure;
    return failure == null ? Right(tenants) : Left(failure);
  }

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async {
    calls.add('config:$slug');
    return configs[slug] ?? const Left(NotFoundFailure());
  }
}

void main() {
  late _FakeTenantRepository repo;
  late TenantContext context;
  late InMemoryTenantPreferences prefs;

  setUp(() {
    repo = _FakeTenantRepository();
    context = TenantContext();
    prefs = InMemoryTenantPreferences();
  });

  TenantCubit build({String version = '1.0.0', Future<void> Function()? onChanging}) => TenantCubit(
        repository: repo,
        context: context,
        preferences: prefs,
        currentAppVersion: version,
        onTenantChanging: onChanging,
      );

  test('a single listed tenant is selected automatically and applied', () async {
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.ready);
    expect(cubit.state.config!.tenant, _sentech);
    expect(context.slug, 'sentech');
    expect(context.termsVersion, '2026-09-30');
    expect(context.privacyVersion, '2026-09-29');
    expect(prefs.slug, 'sentech');
    expect(prefs.configJson, isNotNull);
    await cubit.close();
  });

  test('several tenants and no saved choice ask the customer to pick', () async {
    repo.tenants = [_sentech, _acme];
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.needsSelection);
    expect(cubit.state.tenants, [_sentech, _acme]);
    await cubit.close();
  });

  test('a saved choice skips the directory', () async {
    prefs.slug = 'acme-wifi';
    final cubit = build();
    await cubit.bootstrap();
    expect(repo.calls, ['config:acme-wifi']);
    expect(cubit.state.config!.tenant, _acme);
    expect(context.slug, 'acme-wifi');
    await cubit.close();
  });

  test('an app older than min_app_version is gated', () async {
    repo.configs['sentech'] = Right(configFor(_sentech, min: '2.0.0'));
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.updateRequired);
    await cubit.close();
  });

  test('offline at launch falls back to the cached config of the saved tenant', () async {
    prefs
      ..slug = 'sentech'
      ..configJson = jsonEncode(configFor(_sentech).toJson());
    repo.configs['sentech'] = const Left(NetworkFailure());
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.ready);
    expect(cubit.state.config!.tenant, _sentech);
    await cubit.close();
  });

  test('offline with nothing cached shows a retryable failure', () async {
    repo.listFailure = const NetworkFailure();
    final cubit = build();
    await cubit.bootstrap();
    expect(cubit.state.status, TenantStatus.failure);
    expect(cubit.state.failure, isA<NetworkFailure>());

    repo.listFailure = null;
    await cubit.retry();
    expect(cubit.state.status, TenantStatus.ready);
    await cubit.close();
  });

  test('a saved tenant that no longer exists sends the customer back to the directory', () async {
    prefs.slug = 'gone-isp';
    final cubit = build();
    await cubit.bootstrap();
    expect(repo.calls, ['config:gone-isp', 'list', 'config:sentech']);
    expect(cubit.state.config!.tenant, _sentech);
    expect(prefs.slug, 'sentech');
    await cubit.close();
  });

  test('switching tenant signs out FIRST, then loads the new tenant', () async {
    final events = <String>[];
    final cubit = build(onChanging: () async => events.add('sign-out'));
    await cubit.bootstrap();
    repo.calls.clear();

    await cubit.select(_acme);
    events.addAll(repo.calls);
    expect(events, ['sign-out', 'config:acme-wifi']);
    expect(cubit.state.config!.tenant, _acme);
    expect(context.slug, 'acme-wifi');
    expect(prefs.slug, 'acme-wifi');
    await cubit.close();
  });

  test('choosing the current tenant again does not sign out', () async {
    var signOuts = 0;
    final cubit = build(onChanging: () async => signOuts++);
    await cubit.bootstrap();
    await cubit.select(_sentech);
    expect(signOuts, 0);
    expect(cubit.state.status, TenantStatus.ready);
    await cubit.close();
  });

  test('the picker can be opened from Account and cancelled without changes', () async {
    repo.tenants = [_sentech, _acme];
    prefs.slug = 'sentech';
    final cubit = build();
    await cubit.bootstrap();
    await cubit.openPicker();
    expect(cubit.state.status, TenantStatus.needsSelection);
    cubit.cancelPicker();
    expect(cubit.state.status, TenantStatus.ready);
    expect(cubit.state.config!.tenant, _sentech);
    await cubit.close();
  });
}
```

`test/tenant_ui_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/app_colors.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/features/tenant/presentation/pages/tenant_picker_page.dart';
import 'package:sentech_connect_app/features/tenant/presentation/pages/update_required_page.dart';

const _sentech = Tenant(slug: 'sentech', name: 'Sentech', type: 'operator');
const _acme = Tenant(
  slug: 'acme-wifi',
  name: 'Acme Wi-Fi',
  type: 'reseller',
  branding: TenantBranding(primaryColor: Color(0xFF123456)),
);

class _TwoTenants implements TenantRepository {
  @override
  Future<Either<Failure, List<Tenant>>> listTenants() async => const Right([_sentech, _acme]);

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(AppConfig(
        tenant: slug == 'sentech' ? _sentech : _acme,
        minAppVersion: '1.0.0',
        featureFlags: FeatureFlags.demo,
        legal: const LegalVersions(terms: '2026-09-30', privacy: '2026-09-30'),
      ));
}

void main() {
  TenantCubit cubit({String? savedSlug, Future<void> Function()? onChanging}) => TenantCubit(
        repository: _TwoTenants(),
        context: TenantContext(),
        preferences: InMemoryTenantPreferences(slug: savedSlug),
        onTenantChanging: onChanging,
      );

  Future<void> pump(WidgetTester tester, TenantCubit c, Widget page) async {
    await tester.pumpWidget(BlocProvider.value(value: c, child: MaterialApp(home: page)));
    await tester.pumpAndSettle();
  }

  testWidgets('first run: picking a provider selects it without a sign-out prompt', (tester) async {
    final c = cubit();
    addTearDown(c.close);
    await c.bootstrap();
    await pump(tester, c, const TenantPickerPage());

    expect(find.text('Acme Wi-Fi'), findsOneWidget);
    expect(find.text('Reseller'), findsOneWidget);
    await tester.tap(find.text('Acme Wi-Fi'));
    await tester.pumpAndSettle();
    expect(find.text('Change provider?'), findsNothing);
    expect(c.state.config!.tenant.slug, 'acme-wifi');
  });

  testWidgets('switching from a current provider asks first, then signs out', (tester) async {
    var signOuts = 0;
    final c = cubit(savedSlug: 'sentech', onChanging: () async => signOuts++);
    addTearDown(c.close);
    await c.bootstrap();
    await c.openPicker();
    await pump(tester, c, const TenantPickerPage());

    await tester.tap(find.text('Acme Wi-Fi'));
    await tester.pumpAndSettle();
    expect(find.text('Change provider?'), findsOneWidget);
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();
    expect(signOuts, 1);
    expect(c.state.config!.tenant.slug, 'acme-wifi');
  });

  testWidgets('the update gate explains what to do', (tester) async {
    final c = cubit();
    addTearDown(c.close);
    await pump(tester, c, const UpdateRequiredPage());
    expect(find.text('Update required'), findsOneWidget);
  });

  test('tenant primary colour themes the app; defaults stay on brand', () {
    expect(AppTheme.light().colorScheme.primary, AppColors.sentechBlue);
    expect(AppTheme.light().colorScheme.onPrimary, Colors.white);
    expect(AppTheme.dark().colorScheme.onPrimary, AppColors.darkBlue);
    expect(AppTheme.light(primary: const Color(0xFF123456)).colorScheme.primary, const Color(0xFF123456));
    expect(AppTheme.light(primary: const Color(0xFFFFEE88)).colorScheme.onPrimary, Colors.black);
    expect(AppTheme.dark(primary: const Color(0xFF123456)).colorScheme.primary, isNot(const Color(0xFF123456)));
  });

  group('tenantRedirect', () {
    Uri at(String path) => Uri.parse(path);

    test('waits (no redirect) while the tenant is loading', () {
      expect(tenantRedirect(const TenantState(status: TenantStatus.loading), at('/main')), isNull);
    });

    test('sends everything to the picker when a choice is needed or loading failed', () {
      expect(tenantRedirect(const TenantState(status: TenantStatus.needsSelection), at('/login')), AppRoutes.tenantPicker);
      expect(tenantRedirect(const TenantState(status: TenantStatus.failure), at('/main')), AppRoutes.tenantPicker);
      expect(tenantRedirect(const TenantState(status: TenantStatus.failure), at(AppRoutes.tenantPicker)), isNull);
    });

    test('gates every screen when the app is too old', () {
      expect(tenantRedirect(const TenantState(status: TenantStatus.updateRequired), at('/main')), AppRoutes.updateRequired);
    });

    test('leaves the picker / gate once the tenant is ready', () {
      expect(tenantRedirect(const TenantState(status: TenantStatus.ready), at(AppRoutes.tenantPicker)), AppRoutes.main);
      expect(tenantRedirect(const TenantState(status: TenantStatus.ready), at('/cart')), isNull);
    });
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/version_test.dart test/tenant_cubit_test.dart test/tenant_ui_test.dart`
Expected: FAIL (compile errors for the missing files and `AppTheme.light(primary:)`).

- [ ] **Step 3: Implement version helpers and tenant preferences**

`lib/app/app_version.dart`:

```dart
/// Must equal the `version:` in pubspec.yaml (without +build); a test checks it.
const appVersion = '1.0.0';
```

`lib/core/utils/version.dart`:

```dart
import 'dart:math';

/// True when [current] >= [minimum], comparing dotted numeric versions
/// ("1.2.10" > "1.2.9"). Build (+n) and pre-release (-x) suffixes are
/// ignored. An unparseable [minimum] never blocks the app.
bool isVersionAtLeast(String current, String minimum) {
  final min = _parse(minimum);
  if (min == null) return true;
  final cur = _parse(current);
  if (cur == null) return false;
  for (var i = 0; i < max(cur.length, min.length); i++) {
    final a = i < cur.length ? cur[i] : 0;
    final b = i < min.length ? min[i] : 0;
    if (a != b) return a > b;
  }
  return true;
}

List<int>? _parse(String version) {
  final core = version.split('+').first.split('-').first.trim();
  if (core.isEmpty) return null;
  final parts = <int>[];
  for (final piece in core.split('.')) {
    final n = int.tryParse(piece);
    if (n == null || n < 0) return null;
    parts.add(n);
  }
  return parts;
}
```

`lib/core/local/tenant_preferences.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// The chosen tenant and its last app-config. Both are public, non-personal
/// data (spec §12: branding is public), so SharedPreferences is fine.
abstract class TenantPreferences {
  Future<String?> loadSlug();

  Future<void> saveSlug(String slug);

  Future<String?> loadConfigJson();

  Future<void> saveConfigJson(String json);

  Future<void> clear();
}

class SharedPrefsTenantPreferences implements TenantPreferences {
  static const _slugKey = 'pref_tenant_slug';
  static const _configKey = 'pref_tenant_app_config';

  @override
  Future<String?> loadSlug() async => (await SharedPreferences.getInstance()).getString(_slugKey);

  @override
  Future<void> saveSlug(String slug) async => (await SharedPreferences.getInstance()).setString(_slugKey, slug);

  @override
  Future<String?> loadConfigJson() async => (await SharedPreferences.getInstance()).getString(_configKey);

  @override
  Future<void> saveConfigJson(String json) async => (await SharedPreferences.getInstance()).setString(_configKey, json);

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_slugKey);
    await prefs.remove(_configKey);
  }
}

class InMemoryTenantPreferences implements TenantPreferences {
  InMemoryTenantPreferences({this.slug, this.configJson});

  String? slug;
  String? configJson;

  @override
  Future<String?> loadSlug() async => slug;

  @override
  Future<void> saveSlug(String value) async => slug = value;

  @override
  Future<String?> loadConfigJson() async => configJson;

  @override
  Future<void> saveConfigJson(String json) async => configJson = json;

  @override
  Future<void> clear() async {
    slug = null;
    configJson = null;
  }
}
```

- [ ] **Step 4: Implement the TenantCubit**

`lib/features/tenant/presentation/bloc/tenant_cubit.dart`:

```dart
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/app_version.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/utils/version.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

enum TenantStatus { initial, loading, needsSelection, ready, updateRequired, failure }

class TenantState extends Equatable {
  const TenantState({this.status = TenantStatus.initial, this.tenants = const [], this.config, this.failure});

  final TenantStatus status;
  final List<Tenant> tenants;
  final AppConfig? config;
  final Failure? failure;

  /// Before any config is loaded (and in widget tests without a tenant) the
  /// demo flags apply, which preserves the pre-tenant behaviour.
  FeatureFlags get featureFlags => config?.featureFlags ?? FeatureFlags.demo;

  bool get isSettled => status != TenantStatus.initial && status != TenantStatus.loading;

  TenantState copyWith({TenantStatus? status, List<Tenant>? tenants, AppConfig? config, Failure? failure}) => TenantState(
        status: status ?? this.status,
        tenants: tenants ?? this.tenants,
        config: config ?? this.config,
        failure: failure,
      );

  @override
  List<Object?> get props => [status, tenants, config, failure];
}

/// Which ISP the app serves (spec §12: one app with a tenant picker).
/// Persists the choice and the last app-config (for offline launches),
/// applies branding/flags/legal versions, and gates too-old app versions.
class TenantCubit extends Cubit<TenantState> {
  TenantCubit({
    required TenantRepository repository,
    required TenantContext context,
    required TenantPreferences preferences,
    String currentAppVersion = appVersion,
    Future<void> Function()? onTenantChanging,
  })  : _repository = repository,
        _context = context,
        _preferences = preferences,
        _appVersion = currentAppVersion,
        _onTenantChanging = onTenantChanging,
        super(const TenantState());

  final TenantRepository _repository;
  final TenantContext _context;
  final TenantPreferences _preferences;
  final String _appVersion;

  /// Signs the customer out before a different tenant is loaded: tokens,
  /// session and personal data belong to exactly one tenant.
  final Future<void> Function()? _onTenantChanging;
  String? _targetSlug;

  Future<void> bootstrap() async {
    emit(state.copyWith(status: TenantStatus.loading));
    final saved = await _preferences.loadSlug();
    if (saved != null) {
      await _activate(saved);
    } else {
      await _loadDirectory();
    }
  }

  /// "Change provider" from Account.
  Future<void> openPicker() async {
    emit(state.copyWith(status: TenantStatus.loading));
    await _loadDirectory(autoSelectSingle: false);
  }

  void cancelPicker() {
    final config = state.config;
    if (config != null) _apply(config);
  }

  Future<void> select(Tenant tenant) async {
    final current = state.config?.tenant.slug;
    if (current != null && current != tenant.slug) await _onTenantChanging?.call();
    if (isClosed) return;
    emit(state.copyWith(status: TenantStatus.loading));
    await _activate(tenant.slug);
  }

  Future<void> retry() async {
    final target = _targetSlug;
    if (target == null) return bootstrap();
    emit(state.copyWith(status: TenantStatus.loading));
    await _activate(target);
  }

  Future<void> _loadDirectory({bool autoSelectSingle = true}) async {
    final result = await _repository.listTenants();
    if (isClosed) return;
    switch (result) {
      case Left(value: final failure):
        emit(state.copyWith(status: TenantStatus.failure, failure: failure));
      case Right(value: final tenants):
        if (autoSelectSingle && tenants.length == 1) {
          await _activate(tenants.single.slug);
          return;
        }
        emit(state.copyWith(status: TenantStatus.needsSelection, tenants: tenants));
    }
  }

  Future<void> _activate(String slug) async {
    _targetSlug = slug;
    _context.slug = slug;
    final result = await _repository.getAppConfig(slug);
    if (isClosed) return;
    switch (result) {
      case Right(value: final config):
        await _preferences.saveSlug(slug);
        await _preferences.saveConfigJson(jsonEncode(config.toJson()));
        _apply(config);
      case Left(value: NotFoundFailure()):
        // The saved tenant was removed or suspended: choose again.
        await _preferences.clear();
        _targetSlug = null;
        await _loadDirectory();
      case Left(value: final failure):
        final cached = await _cachedConfig(slug);
        if (isClosed) return;
        if (cached != null) {
          _apply(cached);
        } else {
          emit(state.copyWith(status: TenantStatus.failure, failure: failure));
        }
    }
  }

  void _apply(AppConfig config) {
    _context
      ..slug = config.tenant.slug
      ..termsVersion = config.legal.terms
      ..privacyVersion = config.legal.privacy;
    final status = isVersionAtLeast(_appVersion, config.minAppVersion) ? TenantStatus.ready : TenantStatus.updateRequired;
    emit(TenantState(status: status, tenants: state.tenants, config: config));
  }

  Future<AppConfig?> _cachedConfig(String slug) async {
    final raw = await _preferences.loadConfigJson();
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final config = AppConfig.fromJson(Map<String, Object?>.from(decoded));
      return config.tenant.slug == slug ? config : null;
    } on FormatException {
      return null;
    }
  }
}
```

- [ ] **Step 5: Add the strings**

Add to `lib/l10n/app_en.arb` (before the closing brace; keep valid JSON):

```json
  "tenantPickerTitle": "Choose your internet provider",
  "tenantPickerSubtitle": "Pick the provider you buy Wi-Fi passes from. You can change this later in Account.",
  "tenantTypeOperator": "Network operator",
  "tenantTypeReseller": "Reseller",
  "tenantChangeTitle": "Change provider?",
  "tenantChangeBody": "Switching provider signs you out on this phone. Your account with the current provider is not affected.",
  "tenantChangeConfirm": "Switch",
  "updateRequiredTitle": "Update required",
  "updateRequiredBody": "This version of the app is no longer supported. Install the latest version from your app store to continue.",
  "accountProvider": "PROVIDER",
  "accountChangeProvider": "Change provider"
```

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/app_localizations*.dart`; "untranslated message" warnings for zu/af are expected until Task 13.

- [ ] **Step 6: Implement the pages and logo**

`lib/features/tenant/presentation/widgets/tenant_logo.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

/// Sentech uses the bundled brand asset; other tenants use their public
/// https logo, falling back to an initial when it cannot be loaded.
class TenantLogo extends StatelessWidget {
  const TenantLogo({super.key, required this.tenant, this.height = 32});

  final Tenant tenant;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (tenant.slug == TenantContext.defaultSlug) return SentechLogo(height: height);
    final url = tenant.branding.logoUrl;
    if (url == null) return _initial(context);
    return Image.network(
      url.toString(),
      height: height,
      semanticLabel: tenant.name,
      errorBuilder: (context, _, _) => _initial(context),
    );
  }

  Widget _initial(BuildContext context) => CircleAvatar(
        radius: height / 2,
        backgroundColor: tenant.branding.primaryColor ?? Theme.of(context).colorScheme.primary,
        child: Text(
          tenant.name.isEmpty ? '?' : tenant.name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );
}
```

`lib/features/tenant/presentation/pages/tenant_picker_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/features/tenant/presentation/widgets/tenant_logo.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// The ISP drop-down of spec §12, as a full screen. The router shows it
/// whenever `TenantCubit` needs a choice (or could not load the directory).
class TenantPickerPage extends StatelessWidget {
  const TenantPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<TenantCubit, TenantState>(
      builder: (context, state) {
        final cubit = context.read<TenantCubit>();
        final current = state.config?.tenant.slug;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.tenantPickerTitle),
            automaticallyImplyLeading: false,
            actions: [
              if (current != null)
                IconButton(tooltip: l10n.commonCancel, icon: const Icon(Icons.close), onPressed: cubit.cancelPicker),
            ],
          ),
          body: switch (state.status) {
            TenantStatus.initial || TenantStatus.loading => const Center(child: CircularProgressIndicator()),
            TenantStatus.failure when state.tenants.isEmpty => FailureView(failure: state.failure, onRetry: cubit.retry),
            _ => ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(l10n.tenantPickerSubtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  for (final tenant in state.tenants) ...[
                    Card(
                      child: ListTile(
                        minTileHeight: 64,
                        leading: SizedBox(width: 48, child: Center(child: TenantLogo(tenant: tenant))),
                        title: Text(tenant.name),
                        subtitle: Text(tenant.isReseller ? l10n.tenantTypeReseller : l10n.tenantTypeOperator),
                        trailing: Icon(tenant.slug == current ? Icons.check_circle : Icons.chevron_right),
                        onTap: () => _choose(context, tenant, current),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
          },
        );
      },
    );
  }

  Future<void> _choose(BuildContext context, Tenant tenant, String? current) async {
    final cubit = context.read<TenantCubit>();
    if (current != null && current != tenant.slug) {
      final l10n = context.l10n;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.tenantChangeTitle),
          content: Text(l10n.tenantChangeBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.tenantChangeConfirm)),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await cubit.select(tenant);
  }
}
```

`lib/features/tenant/presentation/pages/update_required_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Shown instead of every screen when app-config's min_app_version is newer
/// than this build. "Retry" re-reads the config (the minimum may be lowered).
class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(l10n.updateRequiredTitle, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(l10n.updateRequiredBody, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton(onPressed: context.read<TenantCubit>().retry, child: Text(l10n.commonRetry)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Tenant colour in the theme**

In `lib/app/theme/app_theme.dart` replace `light()` and `dark()` with the versions below, add `_onColor`, and in `_themeFrom` replace `systemOverlayStyle: SystemUiOverlayStyle.light,` with `systemOverlayStyle: appBarFg == Colors.white ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,`:

```dart
  /// [primary] is the tenant's branding colour (white-label, spec §12);
  /// null keeps the Sentech brand.
  static ThemeData light({Color? primary}) {
    final brand = primary ?? AppColors.sentechBlue;
    final onBrand = _onColor(brand);
    final scheme = ColorScheme.light(
      primary: brand,
      onPrimary: onBrand,
      secondary: AppColors.lightBlue,
      onSecondary: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.darkGrey,
      error: AppColors.red,
      onError: Colors.white,
    );
    return _themeFrom(scheme, scaffoldBg: AppColors.lightBg, appBarBg: brand, appBarFg: onBrand, navBarBg: Colors.white);
  }

  /// Dark mode lightens a tenant colour so it stays readable on navy.
  static ThemeData dark({Color? primary}) {
    final accent = primary == null ? AppColors.lightBlue : Color.lerp(primary, Colors.white, 0.35)!;
    final scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: primary == null ? AppColors.darkBlue : _onColor(accent),
      secondary: AppColors.orange,
      onSecondary: Colors.black,
      surface: AppColors.darkBlue,
      onSurface: Colors.white,
      error: AppColors.red,
      onError: Colors.white,
    );
    return _themeFrom(scheme, scaffoldBg: AppColors.darkBg, appBarBg: AppColors.darkBlue, appBarFg: Colors.white, navBarBg: AppColors.darkSurface);
  }

  static Color _onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? Colors.white : Colors.black;
```

- [ ] **Step 8: Router guards and routes**

In `lib/app/router/app_router.dart`:

1. Add imports: `tenant_cubit.dart`, `tenant_picker_page.dart`, `update_required_page.dart`.
2. In `AppRoutes` add the two routes and include them in `_public`:

```dart
  static const tenantPicker = '/tenant';
  static const updateRequired = '/update-required';
```

```dart
  static const _public = {splash, login, register, tenantPicker, updateRequired};
```

3. Replace `_AuthRefresh` with:

```dart
/// Re-runs the router's redirect whenever the auth or tenant state changes.
class _GuardRefresh extends ChangeNotifier {
  _GuardRefresh(AuthCubit auth, TenantCubit? tenant) {
    _subscriptions = [
      auth.stream.listen((_) => notifyListeners()),
      if (tenant != null) tenant.stream.listen((_) => notifyListeners()),
    ];
  }

  late final List<StreamSubscription<Object?>> _subscriptions;

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
```

4. Add the pure tenant rule next to `authRedirect`:

```dart
/// Tenant rules run before the auth rules: no screen is usable until a
/// tenant is chosen, and none at all when this app version is too old.
String? tenantRedirect(TenantState tenant, Uri uri) {
  final location = uri.path;
  switch (tenant.status) {
    case TenantStatus.initial || TenantStatus.loading:
      return null;
    case TenantStatus.needsSelection || TenantStatus.failure:
      return location == AppRoutes.tenantPicker ? null : AppRoutes.tenantPicker;
    case TenantStatus.updateRequired:
      return location == AppRoutes.updateRequired ? null : AppRoutes.updateRequired;
    case TenantStatus.ready:
      return location == AppRoutes.tenantPicker || location == AppRoutes.updateRequired ? AppRoutes.main : null;
  }
}
```

5. Replace `AppRouter` and the `_buildRouter` signature/redirect/refresh with:

```dart
class AppRouter {
  AppRouter(AuthCubit authCubit, {TenantCubit? tenantCubit, String initialLocation = AppRoutes.splash})
      : _refresh = _GuardRefresh(authCubit, tenantCubit) {
    router = _buildRouter(authCubit, tenantCubit, _refresh, initialLocation);
  }

  final _GuardRefresh _refresh;
  late final GoRouter router;

  void dispose() {
    router.dispose();
    _refresh.dispose();
  }
}

GoRouter _buildRouter(AuthCubit authCubit, TenantCubit? tenantCubit, Listenable refresh, String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refresh,
    redirect: (context, state) =>
        (tenantCubit == null ? null : tenantRedirect(tenantCubit.state, state.uri)) ?? authRedirect(authCubit.state, state.uri),
```

(the rest of `GoRouter(...)` stays). 

6. Replace the splash route's `onFinished` with a version that waits for the tenant:

```dart
        builder: (context, state) => SplashPage(
          onFinished: () async {
            final tenant = tenantCubit;
            if (tenant != null && !tenant.state.isSettled) {
              await tenant.stream.firstWhere((s) => s.isSettled);
            }
            if (!context.mounted) return;
            // A restored session skips login and the first-time coverage step.
            context.go(authCubit.state.isSignedIn ? AppRoutes.main : AppRoutes.login);
          },
        ),
```

7. Add the two routes to `routes:` and pass the provider row to `MainShell`:

```dart
      GoRoute(path: AppRoutes.tenantPicker, builder: (context, state) => const TenantPickerPage()),
      GoRoute(path: AppRoutes.updateRequired, builder: (context, state) => const UpdateRequiredPage()),
```

```dart
        builder: (context, state) => MainShell(
          onOpenCart: () => context.push(AppRoutes.cart),
          onResumeOrder: (order) => context.push(AppRoutes.forOrder(order)),
          onOpenPromotions: () => context.push(AppRoutes.promotions),
          onFindHotspots: () => context.push(AppRoutes.wifiHotspots),
          onChangeProvider: tenantCubit?.openPicker,
          providerName: tenantCubit?.state.config?.tenant.name,
        ),
```

- [ ] **Step 9: Provider row in MainShell and Account**

In `lib/app/main_shell.dart` add constructor params `this.onChangeProvider, this.providerName` with fields `final VoidCallback? onChangeProvider;` and `final String? providerName;`, and replace `const AccountPage(),` with `AccountPage(onChangeProvider: widget.onChangeProvider, providerName: widget.providerName),`.

In `lib/features/account/presentation/pages/account_page.dart`:
- `AccountPage`: `const AccountPage({super.key, this.onChangeProvider, this.providerName});` with the two fields, and `child: SecureScreen(child: _AccountView(onChangeProvider: onChangeProvider, providerName: providerName)),` (drop the `const`).
- `_AccountView`: `const _AccountView({this.onChangeProvider, this.providerName});` with the two fields.
- Insert before `Text(l10n.accountNotifications, style: heading),`:

```dart
              if (onChangeProvider case final changeProvider?) ...[
                Text(l10n.accountProvider, style: heading),
                const SizedBox(height: 8),
                _Bordered(
                  child: ListTile(
                    minTileHeight: 48,
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(l10n.accountChangeProvider),
                    subtitle: providerName == null ? null : Text(providerName!),
                    onTap: changeProvider,
                  ),
                ),
                const SizedBox(height: 24),
              ],
```

- [ ] **Step 10: Wire TenantCubit into the app and the locator**

In `lib/app/locator.dart`, `_registerPlatformServices`, add (import `tenant_preferences.dart`):

```dart
  locator.registerLazySingleton<TenantPreferences>(() => SharedPrefsTenantPreferences());
```

In `test/helpers/test_setup.dart`, `registerTestFakes()`, add (import `package:sentech_connect_app/core/local/tenant_preferences.dart`):

```dart
  locator.registerLazySingleton<TenantPreferences>(() => InMemoryTenantPreferences());
```

In `lib/app/app.dart` (imports: `tenant_cubit.dart`):
- After `_authCubit`, add:

```dart
  // Switching ISP signs the customer out first (ruling: one session per tenant).
  late final TenantCubit _tenantCubit = TenantCubit(
    repository: locator(),
    context: locator(),
    preferences: locator(),
    onTenantChanging: () => _authCubit.logOut(),
  )..bootstrap();
  late final AppRouter _appRouter = AppRouter(_authCubit, tenantCubit: _tenantCubit);
```

  (replacing the old `_appRouter` line).
- `dispose()`: add `_tenantCubit.close();` before `_authCubit.close();`.
- Providers: add `BlocProvider.value(value: _tenantCubit),` after the auth provider.
- In the `BlocBuilder<ThemeCubit, ThemeMode>` builder, replace the `MaterialApp.router(` title/theme lines with:

```dart
            final tenant = context.watch<TenantCubit>().state.config?.tenant;
            final primary = tenant?.branding.primaryColor;
            return MaterialApp.router(
              title: tenant?.name ?? 'Sentech Connect',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(primary: primary),
              darkTheme: AppTheme.dark(primary: primary),
```

- [ ] **Step 11: Run the tests**

Run: `flutter test test/version_test.dart test/tenant_cubit_test.dart test/tenant_ui_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS (`widget_test`, `flow_test`, `l10n_test` boot the whole app: the demo `MockTenantRepository` has one tenant, so the splash continues to login exactly as before).

- [ ] **Step 12: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 13: Commit**

```powershell
git add lib/core/local/tenant_preferences.dart lib/core/utils/version.dart lib/app/app_version.dart lib/features/tenant/presentation
git add lib/app/theme/app_theme.dart lib/app/app.dart lib/app/router/app_router.dart lib/app/main_shell.dart lib/app/locator.dart lib/features/account/presentation/pages/account_page.dart
git add lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zu.dart lib/l10n/app_localizations_af.dart
git add test/helpers/test_setup.dart test/version_test.dart test/tenant_cubit_test.dart test/tenant_ui_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(tenant): ISP picker, tenant theming, min-version gate and sign-out on tenant switch"
```

---

### Task 6: OTP authentication repositories and the session model (lock, logout revoke, expiry)

**Files:**
- Create: `lib/core/utils/phone_number.dart`, `lib/features/auth/domain/entities/otp_challenge.dart`, `lib/features/auth/data/repositories/http_auth_repository.dart`, `test/fixtures/api/otp_request.json`, `test/fixtures/api/profile.json`, `test/fixtures/api/profile_complete.json`
- Modify: `lib/features/auth/domain/repositories/auth_repository.dart`, `lib/features/auth/data/repositories/mock_auth_repository.dart`, `lib/features/auth/presentation/bloc/auth_cubit.dart` (full replacement), `lib/app/app.dart`, `lib/main.dart`, `lib/app/locator.dart`
- Test: `test/phone_number_test.dart`, `test/http_auth_repository_test.dart`, `test/auth_cubit_test.dart` (full replacement)

**Interfaces:**
- Consumes: `ApiClient` (`post`, `get`, `refresher.refresh`), `TokenStore`, `AuthTokens.fromTokenPair`, `TenantContext`, `SessionEvents`, `RefreshSucceeded/RefreshRejected/RefreshUnavailable` (Task 3); `ValidationFailure(message, code)`, `UnauthorizedFailure`, `NetworkFailure` (Task 2); `SessionStore`, `BiometricAuthenticator`, `PersonalDataWiper` (existing).
- Produces:
  - `String? normaliseZaMobile(String input)` (E.164 `+27XXXXXXXXX` for SA mobiles 06x/07x/081-084, else null); `String maskPhone(String e164)` (`+27 82 *** 4567`).
  - `class OtpChallenge { const OtpChallenge({required String id, required String phoneE164, required Duration expiresIn}); }`
  - `abstract class AuthRepository { requestOtp({required String phoneNumber}) -> Either<Failure, OtpChallenge>; verifyOtp({required OtpChallenge challenge, required String code}) -> Either<Failure, User>; resumeSession() -> Either<Failure, User>; Future<void> logOut(); logIn({required String mobileNumber, required String password}) -> Either<Failure, User> (transitional, deleted in Task 8) }`
  - `MockAuthRepository({Duration latency = const Duration(milliseconds: 400)})`, `static const rejectedDemoCode = '000000'`; `HttpAuthRepository(ApiClient api, {required TokenStore tokens, required TenantContext tenant, DateTime Function()? now})`.
  - `AuthStatus.locked`; `static AuthState AuthState.restore({required User? user, required bool hasBiometricCredential, required bool biometricsAvailable})`; `AuthCubit(..., Stream<void>? sessionExpired)`; `Future<void> signedIn(User user, {required bool fresh})`; `Future<void> profileUpdated(User user)`; `registered(User)` (transitional, deleted in Task 8); `logInWithBiometrics({required String reason})` now resumes the stored session; `logOut()` revokes + forgets the biometric credential.

- [ ] **Step 1: Add the fixtures**

`test/fixtures/api/otp_request.json` (M1 `OtpRequestOut`):

```json
{"challenge_id": "3f2b8c1e-5d4a-4e6b-9c7d-1a2b3c4d5e6f", "expires_in_seconds": 300}
```

`test/fixtures/api/profile.json` (M1 `ProfileOut`, a brand-new customer):

```json
{"id": "7d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d", "phone_e164": "+27821234567", "display_name": null, "email": null, "created_at": "2026-10-01T10:00:00Z"}
```

`test/fixtures/api/profile_complete.json`:

```json
{"id": "7d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d", "phone_e164": "+27821234567", "display_name": "Thandi Mokoena", "email": "thandi@example.test", "created_at": "2026-10-01T10:00:00Z"}
```

- [ ] **Step 2: Write the failing tests**

`test/phone_number_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';

void main() {
  for (final (raw, expected) in [
    ('0821234567', '+27821234567'),
    ('082 123 4567', '+27821234567'),
    ('+27 82 123 4567', '+27821234567'),
    ('0027821234567', '+27821234567'),
    ('27821234567', '+27821234567'),
    ('  083-555-0123 ', '+27835550123'),
    ('(072) 123.4567', '+27721234567'),
    ('0611234567', '+27611234567'),
  ]) {
    test('normalises "$raw"', () => expect(normaliseZaMobile(raw), expected));
  }

  for (final raw in ['', '12345', 'abc', '+44 20 7946 0958', '011 123 4567', '0861234567', '0821234567821234567', '+27 82 123']) {
    test('rejects "$raw"', () => expect(normaliseZaMobile(raw), isNull));
  }

  test('masks the middle digits for display', () {
    expect(maskPhone('+27821234567'), '+27 82 *** 4567');
  });
}
```

`test/http_auth_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _challenge = OtpChallenge(
  id: '3f2b8c1e-5d4a-4e6b-9c7d-1a2b3c4d5e6f',
  phoneE164: '+27821234567',
  expiresIn: Duration(minutes: 5),
);

void main() {
  late ApiHarness h;
  late HttpAuthRepository repo;

  setUp(() {
    h = ApiHarness();
    repo = HttpAuthRepository(h.api, tokens: h.tokens, tenant: h.tenantContext, now: () => h.now);
  });

  test('requestOtp sends tenant + E.164 phone, unauthenticated', () async {
    h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply(202, fixture('otp_request.json')));
    final challenge = (await repo.requestOtp(phoneNumber: '082 123 4567')).getOrElse((f) => throw StateError(f.message));
    expect(challenge, _challenge);
    final sent = h.adapter.requests.single;
    expect(sent.data, {'tenant': 'sentech', 'phone': '+27821234567'});
    expect(sent.headers.containsKey('Authorization'), isFalse);
  });

  test('an invalid number is rejected before any request', () async {
    final result = await repo.requestOtp(phoneNumber: '011 123 4567');
    expect((result.match((f) => f, (_) => null)! as ValidationFailure).code, 'invalid_phone');
    expect(h.adapter.requests, isEmpty);
  });

  test('rate limiting surfaces RateLimitedFailure with Retry-After', () async {
    h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply.problem(429, 'rate_limited', headers: {
          'retry-after': ['600'],
        }));
    final failure = (await repo.requestOtp(phoneNumber: '0821234567')).match((f) => f, (_) => null);
    expect((failure! as RateLimitedFailure).retryAfter, const Duration(minutes: 10));
  });

  test('verifyOtp stores the tenant-bound tokens and loads the profile', () async {
    h.adapter.on('POST', '/v1/auth/otp/verify', (_) => FakeReply(200, tokenPair()));
    h.adapter.on('GET', '/v1/me/profile', (_) => FakeReply(200, fixture('profile.json')));
    final user = (await repo.verifyOtp(challenge: _challenge, code: '123456')).getOrElse((f) => throw StateError(f.message));

    expect(user.id, ApiHarness.customerId);
    expect(user.fullName, '');
    expect(user.mobileNumber, '+27821234567');
    expect(h.adapter.requestsTo('POST', '/v1/auth/otp/verify').single.data, {
      'tenant': 'sentech',
      'challenge_id': _challenge.id,
      'code': '123456',
    });
    expect(h.adapter.requestsTo('GET', '/v1/me/profile').single.headers['Authorization'], 'Bearer access-2');
    final stored = (await h.tokens.read())!;
    expect(stored.tenantSlug, 'sentech');
    expect(stored.accessExpiresAt, h.now.add(const Duration(seconds: 900)));
  });

  test('a wrong code keeps the API code and stores nothing', () async {
    h.adapter.on('POST', '/v1/auth/otp/verify', (_) => FakeReply.problem(400, 'otp_invalid', detail: 'The code is invalid or has expired.'));
    final failure = (await repo.verifyOtp(challenge: _challenge, code: '000000')).match((f) => f, (_) => null);
    expect((failure! as ValidationFailure).code, 'otp_invalid');
    expect(await h.tokens.read(), isNull);
  });

  test('a malformed code never reaches the server', () async {
    final failure = (await repo.verifyOtp(challenge: _challenge, code: '12ab')).match((f) => f, (_) => null);
    expect((failure! as ValidationFailure).code, 'invalid_code');
    expect(h.adapter.requests, isEmpty);
  });

  test('resumeSession proves the stored refresh token and reloads the profile', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    h.adapter.on('GET', '/v1/me/profile', (_) => FakeReply(200, fixture('profile_complete.json')));
    final user = (await repo.resumeSession()).getOrElse((f) => throw StateError(f.message));
    expect(user.fullName, 'Thandi Mokoena');
    expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh').single.data, {'tenant': 'sentech', 'refresh_token': 'refresh-1'});
  });

  test('resumeSession with a revoked refresh token fails and forgets the tokens', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply.problem(401, 'invalid_refresh_token'));
    expect((await repo.resumeSession()).match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(await h.tokens.read(), isNull);
  });

  test('resumeSession offline is a NetworkFailure and keeps the tokens', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => const FakeReply.error(DioExceptionType.connectionTimeout));
    expect((await repo.resumeSession()).match((f) => f, (_) => null), isA<NetworkFailure>());
    expect(await h.tokens.read(), isNotNull);
  });

  test('logOut revokes the refresh family with the bearer token, then forgets the tokens', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply(204));
    await repo.logOut();
    final sent = h.adapter.requestsTo('POST', '/v1/auth/logout').single;
    expect(sent.data, {'refresh_token': 'refresh-1'});
    expect(sent.headers['Authorization'], 'Bearer access-1');
    expect(await h.tokens.read(), isNull);
  });

  test('logOut forgets the tokens even when the server is unreachable', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply.error(DioExceptionType.connectionError));
    await repo.logOut();
    expect(await h.tokens.read(), isNull);
    expect(h.store.snapshot.containsKey('auth_tokens'), isFalse);
  });
}
```

Replace `test/auth_cubit_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/secure_session_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';

const _user = User(id: 'c1', fullName: 'Lindiwe Khumalo', mobileNumber: '+27810000000');

class _RecordingWiper implements PersonalDataWiper {
  int logoutWipes = 0;
  int fullWipes = 0;

  @override
  Future<void> wipeOnLogout() async => logoutWipes++;

  @override
  Future<void> wipeEverything() async => fullWipes++;
}

class _FakeAuthRepository extends MockAuthRepository {
  _FakeAuthRepository() : super(latency: Duration.zero);

  int logOuts = 0;
  int resumes = 0;
  Either<Failure, User> resumeResult = const Right(_user);

  @override
  Future<Either<Failure, User>> resumeSession() async {
    resumes++;
    return resumeResult;
  }

  @override
  Future<void> logOut() async => logOuts++;
}

void main() {
  late InMemorySecureStore secureStore;
  late SecureSessionStore sessionStore;
  late MockBiometricAuthenticator biometrics;
  late _RecordingWiper wiper;
  late _FakeAuthRepository repo;
  late SessionEvents events;

  setUp(() {
    secureStore = InMemorySecureStore();
    sessionStore = SecureSessionStore(secureStore);
    biometrics = MockBiometricAuthenticator();
    wiper = _RecordingWiper();
    repo = _FakeAuthRepository();
    events = SessionEvents();
  });

  AuthCubit build({AuthState initial = const AuthState()}) => AuthCubit(
        repo,
        sessionStore: sessionStore,
        biometrics: biometrics,
        wiper: wiper,
        initial: initial,
        sessionExpired: events.expired,
      );

  Future<AuthCubit> lockedCubit() async {
    await sessionStore.saveUser(_user);
    await sessionStore.saveBiometricCredential(_user.id);
    return build(initial: AuthState.restore(user: _user, hasBiometricCredential: true, biometricsAvailable: true));
  }

  test('biometrics are not offered before any session was established', () async {
    final cubit = build();
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isFalse);
    await cubit.close();
  });

  test('biometric unlock is refused without a stored session, without prompting', () async {
    final cubit = build();
    await cubit.logInWithBiometrics(reason: 'test');
    expect(cubit.state.status, AuthStatus.failure);
    expect(biometrics.authenticateCalls, 0);
    await cubit.close();
  });

  test('signing in persists the session securely and enables biometrics', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    expect(cubit.state.isSignedIn, isTrue);
    expect(cubit.state.freshSignIn, isTrue);
    expect(await sessionStore.loadUser(), _user);
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isTrue);
    await cubit.close();
  });

  test('biometrics are hidden when nothing is enrolled on the device', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    biometrics.nextAvailability = BiometricAvailability.notEnrolled;
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isFalse);
    await cubit.close();
  });

  test('a restored session without usable biometrics opens straight away', () {
    expect(AuthState.restore(user: _user, hasBiometricCredential: true, biometricsAvailable: false).isSignedIn, isTrue);
    expect(AuthState.restore(user: null, hasBiometricCredential: true, biometricsAvailable: true).isSignedIn, isFalse);
  });

  test('a restored session with biometrics starts locked and unlocks after the biometric check', () async {
    final cubit = await lockedCubit();
    expect(cubit.state.status, AuthStatus.locked);
    expect(cubit.state.isSignedIn, isFalse);
    await cubit.logInWithBiometrics(reason: 'test');
    expect(biometrics.authenticateCalls, 1);
    expect(repo.resumes, 1);
    expect(cubit.state.isSignedIn, isTrue);
    expect(cubit.state.freshSignIn, isFalse);
    await cubit.close();
  });

  for (final (result, issue) in [
    (BiometricResult.cancelled, BiometricIssue.cancelled),
    (BiometricResult.notEnrolled, BiometricIssue.notEnrolled),
    (BiometricResult.unavailable, BiometricIssue.unavailable),
    (BiometricResult.lockedOut, BiometricIssue.lockedOut),
    (BiometricResult.permanentlyLockedOut, BiometricIssue.permanentlyLockedOut),
    (BiometricResult.failed, BiometricIssue.failed),
  ]) {
    test('biometric $result leaves the session locked with $issue and never resumes it', () async {
      final cubit = await lockedCubit();
      biometrics.nextResult = result;
      await cubit.logInWithBiometrics(reason: 'test');
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.biometricIssue, issue);
      expect(repo.resumes, 0);
      await cubit.close();
    });
  }

  test('a revoked session found at unlock is forgotten, with a message', () async {
    repo.resumeResult = const Left(UnauthorizedFailure());
    final cubit = await lockedCubit();
    await cubit.logInWithBiometrics(reason: 'test');
    expect(cubit.state.isSignedIn, isFalse);
    expect(cubit.state.errorMessage, 'Your session has ended. Sign in again.');
    expect(cubit.state.biometricsReady, isFalse);
    expect(await sessionStore.loadBiometricCredential(), isNull);
    await cubit.close();
  });

  test('logout revokes server-side, forgets the biometric credential and wipes personal data', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    await cubit.logOut();
    expect(repo.logOuts, 1);
    expect(wiper.logoutWipes, 1);
    expect(await sessionStore.loadUser(), isNull);
    expect(await sessionStore.loadBiometricCredential(), isNull);
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isFalse);
    await cubit.close();
  });

  test('account deletion also revokes and leaves secure storage empty', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    await cubit.signOutAndWipeEverything();
    expect(repo.logOuts, 1);
    expect(wiper.fullWipes, 1);
    expect(secureStore.snapshot, isEmpty);
    await cubit.close();
  });

  test('an expired session (refresh rejected by the server) signs the customer out', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    events.sessionExpired();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isSignedIn, isFalse);
    expect(wiper.logoutWipes, 1);
    await cubit.close();
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/phone_number_test.dart test/http_auth_repository_test.dart test/auth_cubit_test.dart`
Expected: FAIL (compile errors: `phone_number.dart`, `otp_challenge.dart`, `http_auth_repository.dart`, `AuthState.restore`, `signedIn`, `sessionExpired:`).

- [ ] **Step 4: Phone numbers and the challenge entity**

`lib/core/utils/phone_number.dart`:

```dart
final _separators = RegExp(r'[\s\-().]');
final _mobile = RegExp(r'^(6\d|7\d|8[1-4])\d{7}$');

/// South African mobile number in E.164 (`+27821234567`), or null.
/// Accepts 0XX..., +27..., 0027... and 27... with spaces, dashes, dots or
/// brackets. Landlines (01x-05x) and 080/086/087 numbers are rejected; the
/// server checks again (`invalid_phone`).
String? normaliseZaMobile(String input) {
  final digits = input.trim().replaceAll(_separators, '');
  final String national;
  if (digits.startsWith('+27')) {
    national = digits.substring(3);
  } else if (digits.startsWith('0027')) {
    national = digits.substring(4);
  } else if (digits.startsWith('27') && digits.length == 11) {
    national = digits.substring(2);
  } else if (digits.startsWith('0') && digits.length == 10) {
    national = digits.substring(1);
  } else {
    return null;
  }
  return _mobile.hasMatch(national) ? '+27$national' : null;
}

/// `+27821234567` -> `+27 82 *** 4567` (for "we sent a code to ...").
String maskPhone(String e164) {
  if (!e164.startsWith('+27') || e164.length != 12) return e164;
  return '+27 ${e164.substring(3, 5)} *** ${e164.substring(8)}';
}
```

`lib/features/auth/domain/entities/otp_challenge.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A one-time code sent by SMS (`POST /v1/auth/otp/request`).
class OtpChallenge extends Equatable {
  const OtpChallenge({required this.id, required this.phoneE164, required this.expiresIn});

  final String id;
  final String phoneE164;
  final Duration expiresIn;

  @override
  List<Object?> get props => [id, phoneE164, expiresIn];
}
```

- [ ] **Step 5: New repository contract and the mock**

Replace `lib/features/auth/domain/repositories/auth_repository.dart` with:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  /// Sends a one-time code by SMS to a South African mobile number (any
  /// common format; normalised to E.164 first).
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber});

  /// Exchanges the code for a session. The platform creates the account on
  /// first sign-in, so this is registration too (new customers have an
  /// empty `fullName` until they complete their profile).
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code});

  /// Re-opens the session stored on this device. Callers must have passed a
  /// biometric check first (spec §6: biometrics only unlock a session).
  Future<Either<Failure, User>> resumeSession();

  /// Revokes the session server-side (best effort) and forgets the tokens
  /// on this device. Never throws.
  Future<void> logOut();

  /// Password sign-in from the mock phase; deleted with the password form.
  Future<Either<Failure, User>> logIn({required String mobileNumber, required String password});
}
```

Replace `lib/features/auth/data/repositories/mock_auth_repository.dart` with:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

/// Demo flavor: any valid SA mobile gets a code; any 6-digit code except
/// [rejectedDemoCode] signs in (so the wrong-code path can be demoed).
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 400)});

  static const rejectedDemoCode = '000000';
  static const _demoUser = User(id: 'usr_001', fullName: 'Lindiwe Khumalo', mobileNumber: '081 000 0000');

  final Duration latency;

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber}) async {
    await Future<void>.delayed(latency);
    final phone = normaliseZaMobile(phoneNumber);
    if (phone == null) {
      return const Left(ValidationFailure('Enter a valid South African mobile number.', 'invalid_phone'));
    }
    return Right(OtpChallenge(id: 'demo-challenge', phoneE164: phone, expiresIn: const Duration(minutes: 5)));
  }

  @override
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code}) async {
    await Future<void>.delayed(latency);
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return const Left(ValidationFailure('Enter the 6-digit code.', 'invalid_code'));
    if (code == rejectedDemoCode) return const Left(ValidationFailure('The code is invalid or has expired.', 'otp_invalid'));
    return Right(User(id: _demoUser.id, fullName: _demoUser.fullName, mobileNumber: challenge.phoneE164));
  }

  @override
  Future<Either<Failure, User>> resumeSession() async {
    await Future<void>.delayed(latency);
    return const Right(_demoUser);
  }

  @override
  Future<void> logOut() async {}

  @override
  Future<Either<Failure, User>> logIn({required String mobileNumber, required String password}) async {
    await Future<void>.delayed(latency);
    if (mobileNumber.isEmpty || password.isEmpty) {
      return const Left(ValidationFailure('Enter your mobile number and password.'));
    }
    return const Right(_demoUser);
  }
}
```

- [ ] **Step 6: The HTTP repository**

`lib/features/auth/data/repositories/http_auth_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/network/token_refresher.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

/// Customer sign-in against the platform (M1 ruling R-M1-1: API-issued
/// RS256 tokens; the tenant slug travels in every auth request body).
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api, {required TokenStore tokens, required TenantContext tenant, DateTime Function()? now})
      : _tokens = tokens,
        _tenant = tenant,
        _now = now ?? DateTime.now;

  static final _sixDigits = RegExp(r'^\d{6}$');

  final ApiClient _api;
  final TokenStore _tokens;
  final TenantContext _tenant;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber}) async {
    final phone = normaliseZaMobile(phoneNumber);
    if (phone == null) {
      return const Left(ValidationFailure('Enter a valid South African mobile number.', 'invalid_phone'));
    }
    return _api.post<OtpChallenge>(
      '/v1/auth/otp/request',
      authenticated: false,
      body: {'tenant': _tenant.slug, 'phone': phone},
      decode: (data) {
        final map = data! as Map;
        return OtpChallenge(
          id: map['challenge_id']! as String,
          phoneE164: phone,
          expiresIn: Duration(seconds: map['expires_in_seconds']! as int),
        );
      },
    );
  }

  @override
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code}) async {
    if (!_sixDigits.hasMatch(code)) return const Left(ValidationFailure('Enter the 6-digit code.', 'invalid_code'));
    final slug = _tenant.slug;
    final result = await _api.post<AuthTokens>(
      '/v1/auth/otp/verify',
      authenticated: false,
      body: {'tenant': slug, 'challenge_id': challenge.id, 'code': code},
      decode: (data) => AuthTokens.fromTokenPair(Map<String, Object?>.from(data! as Map), tenantSlug: slug, now: _now()),
    );
    switch (result) {
      case Left(value: final failure):
        return Left(failure);
      case Right(value: final tokens):
        await _tokens.write(tokens);
        return _profile(fallbackPhone: challenge.phoneE164);
    }
  }

  @override
  Future<Either<Failure, User>> resumeSession() async {
    final tokens = await _tokens.read();
    if (tokens == null) return const Left(UnauthorizedFailure());
    if (tokens.tenantSlug != _tenant.slug) {
      await _tokens.clear();
      return const Left(UnauthorizedFailure());
    }
    switch (await _api.refresher.refresh()) {
      case RefreshSucceeded():
        return _profile(fallbackPhone: '');
      case RefreshRejected():
        return const Left(UnauthorizedFailure());
      case RefreshUnavailable():
        return const Left(NetworkFailure());
    }
  }

  @override
  Future<void> logOut() async {
    final tokens = await _tokens.read();
    if (tokens == null) return;
    try {
      await _api.post<Unit>(
        '/v1/auth/logout',
        body: {'refresh_token': tokens.refreshToken},
        timeout: const Duration(seconds: 5),
        decode: (_) => unit,
      );
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<Either<Failure, User>> logIn({required String mobileNumber, required String password}) async =>
      const Left(ValidationFailure('Sign in with the one-time code we send to your phone.', 'password_login_removed'));

  Future<Either<Failure, User>> _profile({required String fallbackPhone}) async {
    final result = await _api.get<User>(
      '/v1/me/profile',
      decode: (data) {
        final map = data! as Map;
        return User(
          id: map['id']! as String,
          fullName: (map['display_name'] as String?) ?? '',
          mobileNumber: (map['phone_e164'] as String?) ?? fallbackPhone,
        );
      },
    );
    if (result.isLeft()) await _tokens.clear(); // never keep a half-established session
    return result;
  }
}
```

- [ ] **Step 7: Replace AuthCubit**

Replace `lib/features/auth/presentation/bloc/auth_cubit.dart` with:

```dart
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';

/// [locked]: a session is stored on this device but waits for a biometric
/// unlock (cold start with an enrolled biometric). Not signed in.
enum AuthStatus { initial, loading, success, failure, locked }

/// Why a biometric attempt did not sign the user in. The login page maps
/// these to (localised) guidance; [cancelled] is deliberately silent.
enum BiometricIssue { cancelled, notEnrolled, unavailable, lockedOut, permanentlyLockedOut, failed }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.biometricsReady = false,
    this.biometricIssue,
    this.freshSignIn = false,
  });

  /// The launch state from what is stored on the device (spec §6:
  /// "biometrics only unlock an existing session").
  static AuthState restore({required User? user, required bool hasBiometricCredential, required bool biometricsAvailable}) {
    if (user == null) return const AuthState();
    if (hasBiometricCredential && biometricsAvailable) {
      return AuthState(status: AuthStatus.locked, user: user, biometricsReady: true);
    }
    return AuthState(status: AuthStatus.success, user: user);
  }

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  /// A session exists on this device (biometric credential) AND a biometric
  /// is enrolled: the login page offers "Use biometrics".
  final bool biometricsReady;
  final BiometricIssue? biometricIssue;

  /// True when this session began with an interactive sign-in in this app
  /// run; the router sends brand-new sign-ins through coverage once.
  final bool freshSignIn;

  bool get isSignedIn => status == AuthStatus.success && user != null;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? biometricsReady,
    BiometricIssue? biometricIssue,
    bool? freshSignIn,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      biometricsReady: biometricsReady ?? this.biometricsReady,
      biometricIssue: biometricIssue,
      freshSignIn: freshSignIn ?? this.freshSignIn,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, biometricsReady, biometricIssue, freshSignIn];
}

/// Holds the signed-in session. Tokens live in secure storage behind the
/// repository; this cubit stores the [User] and the biometric marker via
/// [SessionStore]. Logout and account deletion revoke server-side and wipe
/// local personal data; a session the server rejects (see
/// `SessionEvents.expired`) signs the customer out.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(
    this._repository, {
    required this._sessionStore,
    required this._biometrics,
    required this._wiper,
    AuthState initial = const AuthState(),
    Stream<void>? sessionExpired,
  }) : super(initial) {
    _expiry = sessionExpired?.listen((_) => _onSessionExpired());
  }

  final AuthRepository _repository;
  final SessionStore _sessionStore;
  final BiometricAuthenticator _biometrics;
  final PersonalDataWiper _wiper;
  StreamSubscription<void>? _expiry;

  void _emitIfOpen(AuthState next) {
    if (!isClosed) emit(next);
  }

  /// Password sign-in from the mock phase; deleted with the password form.
  Future<void> logIn({required String mobileNumber, required String password}) async {
    _emitIfOpen(state.copyWith(status: AuthStatus.loading));
    final result = await _repository.logIn(mobileNumber: mobileNumber, password: password);
    await result.match(
      (failure) async => _emitIfOpen(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (user) => signedIn(user, fresh: true),
    );
  }

  /// Re-checks whether the "Use biometrics" button should be offered.
  Future<void> refreshBiometrics() async {
    final credential = await _sessionStore.loadBiometricCredential();
    final availability = credential == null ? BiometricAvailability.unavailable : await _biometrics.availability();
    _emitIfOpen(state.copyWith(
      biometricsReady: credential != null && availability == BiometricAvailability.available,
      errorMessage: state.errorMessage,
      biometricIssue: state.biometricIssue,
    ));
  }

  /// Unlocks the stored session. [reason] is the (localised) system prompt.
  Future<void> logInWithBiometrics({required String reason}) async {
    final credential = await _sessionStore.loadBiometricCredential();
    if (credential == null) {
      _emitIfOpen(state.copyWith(status: AuthStatus.failure, biometricsReady: false, biometricIssue: BiometricIssue.unavailable));
      return;
    }
    _emitIfOpen(state.copyWith(status: AuthStatus.loading));
    final outcome = await _biometrics.authenticate(reason: reason);
    if (outcome != BiometricResult.success) {
      _emitIfOpen(state.copyWith(status: AuthStatus.failure, biometricIssue: _issueFor(outcome)));
      return;
    }
    final result = await _repository.resumeSession();
    await result.match(
      (failure) async {
        if (failure is UnauthorizedFailure) {
          // The server revoked it: the stored session is useless now.
          await _sessionStore.clearAll();
          _emitIfOpen(AuthState(status: AuthStatus.failure, errorMessage: failure.message));
          return;
        }
        _emitIfOpen(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message));
      },
      (user) => signedIn(user, fresh: false),
    );
  }

  BiometricIssue _issueFor(BiometricResult result) => switch (result) {
        BiometricResult.cancelled => BiometricIssue.cancelled,
        BiometricResult.notEnrolled => BiometricIssue.notEnrolled,
        BiometricResult.unavailable => BiometricIssue.unavailable,
        BiometricResult.lockedOut => BiometricIssue.lockedOut,
        BiometricResult.permanentlyLockedOut => BiometricIssue.permanentlyLockedOut,
        _ => BiometricIssue.failed,
      };

  /// After an interactive sign-in ([fresh]) or a biometric unlock.
  Future<void> signedIn(User user, {required bool fresh}) async {
    await _sessionStore.saveUser(user);
    await _sessionStore.saveBiometricCredential(user.id);
    _emitIfOpen(state.copyWith(status: AuthStatus.success, user: user, freshSignIn: fresh));
  }

  /// Registration page of the mock phase; deleted with it in favour of
  /// [profileUpdated].
  Future<void> registered(User user) => signedIn(user, fresh: true);

  /// After the customer completed or edited their profile.
  Future<void> profileUpdated(User user) async {
    await _sessionStore.saveUser(user);
    _emitIfOpen(state.copyWith(status: AuthStatus.success, user: user));
  }

  /// Revokes the session server-side, forgets it (incl. the biometric
  /// credential) and wipes personal data held on the device.
  Future<void> logOut() async {
    _emitIfOpen(const AuthState()); // route guards react immediately
    await _repository.logOut();
    await _sessionStore.clearAll();
    await _wiper.wipeOnLogout();
  }

  /// After a confirmed account deletion: nothing about the customer is left.
  Future<void> signOutAndWipeEverything() async {
    _emitIfOpen(const AuthState());
    await _repository.logOut();
    await _sessionStore.clearAll();
    await _wiper.wipeEverything();
  }

  Future<void> _onSessionExpired() async {
    if (state.isSignedIn || state.status == AuthStatus.locked) await logOut();
  }

  @override
  Future<void> close() async {
    await _expiry?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 8: Wire it up**

`lib/app/locator.dart`, `_registerProdRepositories`: replace `locator.registerLazySingleton<AuthRepository>(() => MockAuthRepository());` with

```dart
  locator.registerLazySingleton<AuthRepository>(
    () => HttpAuthRepository(locator(), tokens: locator(), tenant: locator()),
  );
```

(import `http_auth_repository.dart`).

`lib/app/app.dart`: add `sessionExpired: locator<SessionEvents>().expired,` to the `AuthCubit(...)` arguments (import `session_events.dart`).

`lib/main.dart`: replace the `savedUser` line and the `initialAuthState:` argument with (imports: `biometric_authenticator.dart`):

```dart
  final sessionStore = locator<SessionStore>();
  final savedUser = await sessionStore.loadUser();
  final credential = await sessionStore.loadBiometricCredential();
  final biometricsAvailable = savedUser != null &&
      credential != null &&
      await locator<BiometricAuthenticator>().availability() == BiometricAvailability.available;
```

```dart
    initialAuthState: AuthState.restore(
      user: savedUser,
      hasBiometricCredential: credential != null,
      biometricsAvailable: biometricsAvailable,
    ),
```

- [ ] **Step 9: Run the tests**

Run: `flutter test test/phone_number_test.dart test/http_auth_repository_test.dart test/auth_cubit_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS (the password login page still works through the transitional `logIn`; `router_test`'s "logging out from a protected screen" still lands on /login).

- [ ] **Step 10: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 11: Commit**

```powershell
git add lib/core/utils/phone_number.dart lib/features/auth/domain/entities/otp_challenge.dart lib/features/auth/domain/repositories/auth_repository.dart
git add lib/features/auth/data/repositories/mock_auth_repository.dart lib/features/auth/data/repositories/http_auth_repository.dart lib/features/auth/presentation/bloc/auth_cubit.dart
git add lib/app/locator.dart lib/app/app.dart lib/main.dart test/fixtures/api/otp_request.json test/fixtures/api/profile.json test/fixtures/api/profile_complete.json
git add test/phone_number_test.dart test/http_auth_repository_test.dart test/auth_cubit_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(auth): OTP auth repositories, biometric unlock of stored sessions, revoking logout"
```

---

### Task 7: Profile, consent ledger, data export and account deletion over the API

**Files:**
- Create: `lib/features/auth/data/repositories/http_registration_repository.dart`, `lib/features/privacy/data/repositories/http_consent_repository.dart`, `lib/features/privacy/data/repositories/http_privacy_repository.dart`, `lib/features/privacy/presentation/pages/data_export_page.dart`, `test/fixtures/api/consents.json`, `test/fixtures/api/consent_out.json`, `test/fixtures/api/export.json`
- Modify: `lib/features/privacy/domain/entities/consent_record.dart`, `lib/features/privacy/presentation/widgets/consent_gate.dart`, `lib/features/privacy/domain/repositories/privacy_repository.dart`, `lib/features/privacy/presentation/bloc/privacy_actions_cubit.dart`, `lib/features/account/presentation/pages/account_page.dart`, `lib/app/locator.dart`, `lib/l10n/app_en.arb` (+ generated)
- Test: `test/profile_privacy_api_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `TenantContext.termsVersion/privacyVersion`, `newIdempotencyKey` (Task 3); `LocalConsentRepository`, `LocalRegistrationRepository`, `RegistrationRepository`, `ConsentRepository`, `PrivacyRepository`, `PrivacyActionsCubit` (existing); `ValidationFailure`, `ServerFailure`.
- Produces:
  - `ConsentPurpose` gains `terms`, `privacy`, `marketingSms`; `extension ConsentPurposeApi on ConsentPurpose { String? get apiName; }` (`terms`, `privacy`, `marketing_sms`, else null = device-only).
  - `HttpConsentRepository(ApiClient api, {required ConsentRepository local, required TenantContext tenant, String Function()? newKey})`
  - `PrivacyRequestReceipt({required String reference, required DateTime requestedAt, String? exportJson})`; `HttpPrivacyRepository(ApiClient api, {DateTime Function()? now})`.
  - `HttpRegistrationRepository(ApiClient api, {required RegistrationRepository local})` (PATCH `/v1/me/profile` `display_name`/`email`; address stays on the device).
  - `PrivacyActionsState({PrivacyActionStatus status, PrivacyRequestReceipt? receipt})`.
  - `DataExportPage({required String json})`.
  - l10n keys: `dataExportTitle`, `dataExportBody`, `consentLegalBody`.

- [ ] **Step 1: Add the fixtures**

`test/fixtures/api/consents.json` (M1 `ConsentState`):

```json
{"items": [
  {"purpose": "terms", "version": "2026-09-30", "granted": true, "recorded_at": "2026-10-01T10:01:00Z"},
  {"purpose": "privacy", "version": "2026-08-01", "granted": true, "recorded_at": "2026-08-02T09:00:00Z"}
]}
```

`test/fixtures/api/consent_out.json` (M1 `ConsentOut`):

```json
{"purpose": "privacy", "version": "2026-09-30", "granted": true, "recorded_at": "2026-10-01T10:02:00Z"}
```

`test/fixtures/api/export.json` (M1 `CustomerExport`, trimmed):

```json
{
  "generated_at": "2026-10-01T12:00:00Z",
  "profile": {"id": "7d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d", "phone_e164": "+27821234567", "display_name": "Thandi Mokoena", "email": "thandi@example.test", "created_at": "2026-10-01T10:00:00Z"},
  "consents": [{"purpose": "terms", "version": "2026-09-30", "granted": true, "recorded_at": "2026-10-01T10:01:00Z"}],
  "orders": [],
  "payments": [],
  "entitlements": []
}
```

- [ ] **Step 2: Write the failing tests**

`test/profile_privacy_api_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/http_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/http_privacy_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/bloc/privacy_actions_cubit.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _details = RegistrationDetails(
  fullName: ' Thandi Mokoena ',
  email: 'thandi@example.test',
  mobileNumber: '+27821234567',
  address: '12 Main Road, Soweto',
);

void main() {
  late ApiHarness h;

  setUp(() async {
    h = ApiHarness();
    h.tenantContext
      ..termsVersion = '2026-09-30'
      ..privacyVersion = '2026-09-30';
    await h.signIn();
  });

  group('HttpRegistrationRepository', () {
    test('sends the name and email to the profile; the address stays on the device', () async {
      final localStore = InMemorySecureStore();
      final repo = HttpRegistrationRepository(h.api, local: LocalRegistrationRepository(localStore));
      h.adapter.on('PATCH', '/v1/me/profile', (_) => FakeReply(200, fixture('profile_complete.json')));

      expect((await repo.save(_details)).isRight(), isTrue);
      final sent = h.adapter.requestsTo('PATCH', '/v1/me/profile').single;
      expect(sent.data, {'display_name': 'Thandi Mokoena', 'email': 'thandi@example.test'});
      expect(sent.data.toString(), isNot(contains('Soweto')));
      expect((await repo.getSaved()).getOrElse((_) => null)?.address, '12 Main Road, Soweto');
    });

    test('a rejected profile is not saved locally either', () async {
      final localStore = InMemorySecureStore();
      final repo = HttpRegistrationRepository(h.api, local: LocalRegistrationRepository(localStore));
      h.adapter.on('PATCH', '/v1/me/profile', (_) => FakeReply.problem(422, 'validation_error', detail: 'Check your email address.'));
      final failure = (await repo.save(_details)).match((f) => f, (_) => null);
      expect(failure, isA<ValidationFailure>());
      expect(localStore.snapshot, isEmpty);
    });
  });

  group('HttpConsentRepository', () {
    late InMemorySecureStore localStore;
    late HttpConsentRepository repo;

    setUp(() {
      localStore = InMemorySecureStore();
      repo = HttpConsentRepository(
        h.api,
        local: LocalConsentRepository(localStore),
        tenant: h.tenantContext,
        newKey: () => 'app-consent-key-1',
      );
    });

    test('server purposes count only for the CURRENT legal version', () async {
      h.adapter.on('GET', '/v1/me/consents', (_) => FakeReply(200, fixture('consents.json')));
      final terms = (await repo.currentConsent(ConsentPurpose.terms)).getOrElse((f) => throw StateError(f.message));
      final privacy = (await repo.currentConsent(ConsentPurpose.privacy)).getOrElse((f) => throw StateError(f.message));
      expect(terms?.policyVersion, '2026-09-30');
      expect(terms?.synced, isTrue);
      expect(privacy, isNull); // agreed to 2026-08-01, current is 2026-09-30
    });

    test('granting posts purpose, current version and source with an Idempotency-Key', () async {
      h.adapter.on('POST', '/v1/me/consents', (_) => FakeReply(201, fixture('consent_out.json')));
      final record = (await repo.grant(ConsentPurpose.privacy)).getOrElse((f) => throw StateError(f.message));
      final sent = h.adapter.requestsTo('POST', '/v1/me/consents').single;
      expect(sent.data, {'purpose': 'privacy', 'version': '2026-09-30', 'granted': true, 'source': 'app'});
      expect(sent.headers['Idempotency-Key'], 'app-consent-key-1');
      expect(record.grantedAt, DateTime.utc(2026, 10, 1, 10, 2));
    });

    test('device-only consents (location, RICA) never touch the network', () async {
      await repo.grant(ConsentPurpose.locationCapture);
      expect((await repo.currentConsent(ConsentPurpose.locationCapture)).getOrElse((_) => null), isNotNull);
      expect(h.adapter.requests, isEmpty);
    });

    test('without loaded legal versions nothing is recorded', () async {
      h.tenantContext.termsVersion = null;
      final failure = (await repo.grant(ConsentPurpose.terms)).match((f) => f, (_) => null);
      expect((failure! as ValidationFailure).code, 'legal_versions_missing');
      expect(h.adapter.requests, isEmpty);
    });
  });

  group('HttpPrivacyRepository', () {
    test('account deletion is DELETE /v1/me and returns a receipt', () async {
      final repo = HttpPrivacyRepository(h.api, now: () => h.now);
      h.adapter.on('DELETE', '/v1/me', (_) => const FakeReply(204));
      final receipt = (await repo.requestAccountDeletion()).getOrElse((f) => throw StateError(f.message));
      expect(receipt.reference, startsWith('DEL-'));
      expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('the export comes back in-app as pretty JSON', () async {
      final repo = HttpPrivacyRepository(h.api);
      h.adapter.on('GET', '/v1/me/export', (_) => FakeReply(200, fixture('export.json')));
      final receipt = (await repo.requestDataExport()).getOrElse((f) => throw StateError(f.message));
      expect(receipt.reference, 'EXP-${DateTime.utc(2026, 10, 1, 12).millisecondsSinceEpoch}');
      expect(receipt.exportJson, contains('"phone_e164": "+27821234567"'));
    });

    test('local data is wiped only after the server accepted the deletion', () async {
      var wiped = 0;
      var failNext = true;
      h.adapter.on('DELETE', '/v1/me', (_) {
        if (failNext) {
          failNext = false;
          return const FakeReply.error(DioExceptionType.connectionTimeout);
        }
        return const FakeReply(204);
      });
      final cubit = PrivacyActionsCubit(HttpPrivacyRepository(h.api), onAccountDeleted: () async => wiped++);
      addTearDown(cubit.close);

      await cubit.deleteAccount();
      expect(cubit.state.status, PrivacyActionStatus.failed);
      expect(wiped, 0);

      await cubit.deleteAccount();
      expect(cubit.state.status, PrivacyActionStatus.deleted);
      expect(wiped, 1);
    });
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/profile_privacy_api_test.dart`
Expected: FAIL (compile errors: missing HTTP repositories, `ConsentPurpose.terms`, `exportJson`).

- [ ] **Step 4: Server consent purposes**

In `lib/features/privacy/domain/entities/consent_record.dart`, replace the `ConsentPurpose` enum with:

```dart
enum ConsentPurpose {
  /// One-off use of the device location for the coverage check (device-only).
  locationCapture,

  /// Processing of face/ID data for RICA identity verification (device-only).
  ricaCapture,

  /// Terms of Service acceptance, held by the server (`/v1/me/consents`).
  terms,

  /// Privacy notice acknowledgement, held by the server.
  privacy,

  /// Marketing by SMS, held by the server.
  marketingSms,
}

extension ConsentPurposeApi on ConsentPurpose {
  /// The platform's purpose name, or null for consents that only exist on
  /// this device (ruling R-M4-11).
  String? get apiName => switch (this) {
        ConsentPurpose.terms => 'terms',
        ConsentPurpose.privacy => 'privacy',
        ConsentPurpose.marketingSms => 'marketing_sms',
        ConsentPurpose.locationCapture || ConsentPurpose.ricaCapture => null,
      };
}
```

In `lib/features/privacy/presentation/widgets/consent_gate.dart`, add a case to the `body` switch:

```dart
      ConsentPurpose.terms || ConsentPurpose.privacy || ConsentPurpose.marketingSms => l10n.consentLegalBody,
```

Add to `lib/l10n/app_en.arb`:

```json
  "consentLegalBody": "To use the app you need to accept the Terms of Service and the Privacy notice.",
  "dataExportTitle": "Your data",
  "dataExportBody": "This is the personal information we hold about you. Keep it private."
```

Run: `flutter gen-l10n`

- [ ] **Step 5: Consent and privacy repositories**

`lib/features/privacy/data/repositories/http_consent_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';

/// Terms, privacy and SMS-marketing consents live in the platform's
/// versioned ledger (spec §8 POPIA); device-only consents (location, RICA
/// capture) stay in [local].
class HttpConsentRepository implements ConsentRepository {
  HttpConsentRepository(this._api, {required ConsentRepository local, required TenantContext tenant, String Function()? newKey})
      : _local = local,
        _tenant = tenant,
        _newKey = newKey ?? newIdempotencyKey;

  final ApiClient _api;
  final ConsentRepository _local;
  final TenantContext _tenant;
  final String Function() _newKey;

  String? _currentVersion(ConsentPurpose purpose) =>
      purpose == ConsentPurpose.terms ? _tenant.termsVersion : _tenant.privacyVersion;

  @override
  Future<Either<Failure, ConsentRecord?>> currentConsent(ConsentPurpose purpose) async {
    final name = purpose.apiName;
    if (name == null) return _local.currentConsent(purpose);
    final version = _currentVersion(purpose);
    if (version == null) return const Right(null);
    return _api.get<ConsentRecord?>(
      '/v1/me/consents',
      decode: (data) {
        final items = ((data! as Map)['items']! as List).cast<Map<Object?, Object?>>();
        final item = items.where((i) => i['purpose'] == name).firstOrNull;
        if (item == null || item['granted'] != true || item['version'] != version) return null;
        return ConsentRecord(
          purpose: purpose,
          policyVersion: version,
          grantedAt: DateTime.parse(item['recorded_at']! as String).toUtc(),
          synced: true,
        );
      },
    );
  }

  @override
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose) async {
    final name = purpose.apiName;
    if (name == null) return _local.grant(purpose);
    final version = _currentVersion(purpose);
    if (version == null) {
      return const Left(ValidationFailure('We could not load the legal documents. Try again.', 'legal_versions_missing'));
    }
    return _api.post<ConsentRecord>(
      '/v1/me/consents',
      body: {'purpose': name, 'version': version, 'granted': true, 'source': 'app'},
      idempotencyKey: _newKey(),
      decode: (data) {
        final map = data! as Map;
        return ConsentRecord(
          purpose: purpose,
          policyVersion: map['version']! as String,
          grantedAt: DateTime.parse(map['recorded_at']! as String).toUtc(),
          synced: true,
        );
      },
    );
  }

  /// Server-held consents are written synchronously; device-only ones never
  /// sync. Nothing is ever pending.
  @override
  Future<List<ConsentRecord>> unsyncedRecords() async => const [];

  @override
  Future<void> markSynced(Iterable<ConsentRecord> records) => _local.markSynced(records);

  /// Clears the device copy; the server ledger is the audit trail and goes
  /// with `DELETE /v1/me`.
  @override
  Future<void> clear() => _local.clear();
}
```

In `lib/features/privacy/domain/repositories/privacy_repository.dart` replace `PrivacyRequestReceipt` with:

```dart
class PrivacyRequestReceipt extends Equatable {
  const PrivacyRequestReceipt({required this.reference, required this.requestedAt, this.exportJson});

  final String reference;
  final DateTime requestedAt;

  /// The export itself, when the server returns it immediately
  /// (`GET /v1/me/export`); null when it is delivered another way.
  final String? exportJson;

  @override
  List<Object?> get props => [reference, requestedAt, exportJson];
}
```

`lib/features/privacy/data/repositories/http_privacy_repository.dart`:

```dart
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/privacy_repository.dart';

/// POPIA s23/s24 and Play/App Store in-app deletion, via the platform.
class HttpPrivacyRepository implements PrivacyRepository {
  HttpPrivacyRepository(this._api, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> requestAccountDeletion() async {
    final result = await _api.delete('/v1/me', timeout: const Duration(seconds: 30));
    return result.map((_) {
      final at = _now().toUtc();
      return PrivacyRequestReceipt(reference: 'DEL-${at.millisecondsSinceEpoch}', requestedAt: at);
    });
  }

  @override
  Future<Either<Failure, PrivacyRequestReceipt>> requestDataExport() => _api.get<PrivacyRequestReceipt>(
        '/v1/me/export',
        timeout: const Duration(seconds: 30),
        decode: (data) {
          final map = data! as Map;
          final generated = DateTime.parse(map['generated_at']! as String).toUtc();
          return PrivacyRequestReceipt(
            reference: 'EXP-${generated.millisecondsSinceEpoch}',
            requestedAt: generated,
            exportJson: const JsonEncoder.withIndent('  ').convert(map),
          );
        },
      );
}
```

`lib/features/auth/data/repositories/http_registration_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';

/// Completes the customer's profile on the platform (`PATCH /v1/me/profile`:
/// display name and email). The installation address has no M1 endpoint and
/// stays in secure storage on the device via [local].
class HttpRegistrationRepository implements RegistrationRepository {
  HttpRegistrationRepository(this._api, {required RegistrationRepository local}) : _local = local;

  final ApiClient _api;
  final RegistrationRepository _local;

  @override
  Future<Either<Failure, Unit>> save(RegistrationDetails details) async {
    final email = details.email.trim();
    final result = await _api.patch<Unit>(
      '/v1/me/profile',
      body: {'display_name': details.fullName.trim(), if (email.isNotEmpty) 'email': email},
      decode: (_) => unit,
    );
    if (result.isLeft()) return result;
    return _local.save(details);
  }

  @override
  Future<Either<Failure, RegistrationDetails?>> getSaved() => _local.getSaved();

  @override
  Future<void> clear() => _local.clear();
}
```

- [ ] **Step 6: Show the export in-app**

In `privacy_actions_cubit.dart` replace `PrivacyActionsState` with:

```dart
class PrivacyActionsState extends Equatable {
  const PrivacyActionsState({this.status = PrivacyActionStatus.idle, this.receipt});

  final PrivacyActionStatus status;
  final PrivacyRequestReceipt? receipt;

  @override
  List<Object?> get props => [status, receipt];
}
```

and in `requestDataExport()` replace the final `emit(...)` with:

```dart
    final PrivacyRequestReceipt? receipt = result.match((_) => null, (r) => r);
    emit(PrivacyActionsState(
      status: receipt != null ? PrivacyActionStatus.exportRequested : PrivacyActionStatus.failed,
      receipt: receipt,
    ));
```

`lib/features/privacy/presentation/pages/data_export_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';

/// The customer's data export (`GET /v1/me/export`). Capture-protected:
/// it is all their personal data in one place.
class DataExportPage extends StatelessWidget {
  const DataExportPage({super.key, required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.dataExportTitle)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.dataExportBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SelectableText(json, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
```

In `account_page.dart`, in the `BlocListener<PrivacyActionsCubit, ...>` listener, replace the `exportRequested` branch with (import `data_export_page.dart`):

```dart
        if (state.status == PrivacyActionStatus.exportRequested) {
          final json = state.receipt?.exportJson;
          if (json != null) {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DataExportPage(json: json)));
          } else {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.accountDownloadDataDone)));
          }
        } else if (state.status == PrivacyActionStatus.failed) {
```

- [ ] **Step 7: Register the prod implementations**

In `_registerProdRepositories` of `lib/app/locator.dart` replace the `ConsentRepository`, `PrivacyRepository` and `RegistrationRepository` lines with (imports for the three HTTP classes):

```dart
  locator.registerLazySingleton<ConsentRepository>(
    () => HttpConsentRepository(locator(), local: LocalConsentRepository(locator()), tenant: locator()),
  );
  locator.registerLazySingleton<PrivacyRepository>(() => HttpPrivacyRepository(locator()));
  locator.registerLazySingleton<RegistrationRepository>(
    () => HttpRegistrationRepository(locator(), local: LocalRegistrationRepository(locator())),
  );
```

- [ ] **Step 8: Run the tests**

Run: `flutter test test/profile_privacy_api_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS (`privacy_test.dart` keeps passing: the mock's receipt has no `exportJson`, so Account still shows the snackbar).

- [ ] **Step 9: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```powershell
git add lib/features/auth/data/repositories/http_registration_repository.dart lib/features/privacy/data/repositories/http_consent_repository.dart lib/features/privacy/data/repositories/http_privacy_repository.dart
git add lib/features/privacy/presentation/pages/data_export_page.dart lib/features/privacy/domain/entities/consent_record.dart lib/features/privacy/presentation/widgets/consent_gate.dart
git add lib/features/privacy/domain/repositories/privacy_repository.dart lib/features/privacy/presentation/bloc/privacy_actions_cubit.dart lib/features/account/presentation/pages/account_page.dart lib/app/locator.dart
git add lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zu.dart lib/l10n/app_localizations_af.dart
git add test/fixtures/api/consents.json test/fixtures/api/consent_out.json test/fixtures/api/export.json test/profile_privacy_api_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(privacy): profile, consent ledger, export and deletion over the platform API"
```

---

### Task 8: OTP login screen, profile completion and the new-customer route rule

**Files:**
- Create: `lib/features/auth/presentation/bloc/otp_login_cubit.dart`
- Modify: `lib/features/auth/presentation/pages/login_page.dart` (full replacement), `lib/features/auth/presentation/pages/registration_page.dart`, `lib/features/auth/presentation/bloc/registration_cubit.dart`, `lib/features/auth/presentation/bloc/auth_cubit.dart` (delete `logIn`, `registered`), `lib/features/auth/domain/repositories/auth_repository.dart`, `lib/features/auth/data/repositories/mock_auth_repository.dart`, `lib/features/auth/data/repositories/http_auth_repository.dart` (delete `logIn`), `lib/app/router/app_router.dart`, `lib/l10n/app_en.arb` (+ generated)
- Test: `test/otp_login_cubit_test.dart`, `test/login_page_test.dart`, `test/registration_cubit_test.dart`; update `test/widget_test.dart`, `test/flow_test.dart`, `test/router_test.dart`, `test/accessibility_test.dart`, `test/l10n_test.dart`

**Interfaces:**
- Consumes: `AuthRepository.requestOtp/verifyOtp`, `OtpChallenge`, `normaliseZaMobile`, `maskPhone`, `AuthCubit.signedIn/profileUpdated/logOut/logInWithBiometrics`, `AuthStatus.locked`, `MockAuthRepository.rejectedDemoCode` (Task 6); `ConsentRepository.grant`, `ConsentPurpose.terms/privacy/marketingSms` (Task 7); `AppEnvironment.isDemo` (Task 2, registered in Task 4).
- Produces:
  - `enum OtpStep { phone, code }`; `enum OtpLoginStatus { idle, sending, verifying, failure, verified }`; `typedef CountdownTicker = Stream<int> Function(int seconds)`; `class OtpLoginState { OtpStep step; OtpLoginStatus status; OtpChallenge? challenge; Failure? failure; int resendIn; User? user; bool get busy; }`; `class OtpLoginCubit { OtpLoginCubit(AuthRepository repository, {Duration resendCooldown = const Duration(seconds: 30), CountdownTicker? ticker}); Future<void> submitPhone(String input); Future<void> submitCode(String code); Future<void> resend(); void changeNumber(); }`
  - `LoginPage({super.key, bool demoMode = false})` (no `onRegister`).
  - `RegistrationCubit(RegistrationRepository repository, {ConsentRepository? consents, String initialMobile = ''})`, `RegistrationState.acceptedTerms`, `setAcceptedTerms(bool)`.
  - Router: `/register` is protected; a signed-in customer with an empty `fullName` is sent to `/register` ("complete your profile").
  - `AuthRepository` no longer has `logIn`; `AuthCubit` no longer has `logIn`/`registered`.
  - l10n keys: `loginSendCode`, `loginPhoneInvalid`, `loginNewCustomerHint`, `loginWelcomeBackName` (`{name}`), `loginNotYou`, `otpSentTo` (`{phone}`), `otpCodeHint`, `otpVerify`, `otpResend`, `otpResendIn` (`{seconds}` int), `otpChangeNumber`, `otpInvalidCode`, `otpDemoHint`, `registerAcceptTerms`.

- [ ] **Step 1: Write the failing cubit tests**

`test/otp_login_cubit_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/otp_login_cubit.dart';

class _CountingRepo extends MockAuthRepository {
  _CountingRepo() : super(latency: Duration.zero);

  int requests = 0;

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber}) {
    requests++;
    return super.requestOtp(phoneNumber: phoneNumber);
  }
}

Stream<int> _instantTicker(int seconds) => Stream.fromIterable([for (var i = seconds - 1; i >= 0; i--) i]);

void main() {
  late _CountingRepo repo;

  setUp(() => repo = _CountingRepo());

  test('a valid number moves to the code step and runs the resend countdown', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('082 123 4567');
    expect(cubit.state.step, OtpStep.code);
    expect(cubit.state.challenge!.phoneE164, '+27821234567');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.resendIn, 0);
    await cubit.close();
  });

  test('an invalid number is rejected locally and never sent', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('011 123 4567');
    expect(cubit.state.status, OtpLoginStatus.failure);
    expect((cubit.state.failure! as ValidationFailure).code, 'invalid_phone');
    expect(repo.requests, 0);
    await cubit.close();
  });

  test('resend is ignored while the countdown runs', () async {
    final never = StreamController<int>();
    final cubit = OtpLoginCubit(repo, ticker: (_) => never.stream);
    await cubit.submitPhone('0821234567');
    expect(cubit.state.resendIn, 30);
    await cubit.resend();
    expect(repo.requests, 1);
    await cubit.close();
    await never.close();
  });

  test('resend after the countdown asks for a new code', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await Future<void>.delayed(Duration.zero);
    await cubit.resend();
    expect(repo.requests, 2);
    await cubit.close();
  });

  test('a wrong code reports otp_invalid and stays on the code step', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode(MockAuthRepository.rejectedDemoCode);
    expect(cubit.state.step, OtpStep.code);
    expect((cubit.state.failure! as ValidationFailure).code, 'otp_invalid');
    await cubit.close();
  });

  test('a malformed code is rejected locally', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode('12 34');
    expect((cubit.state.failure! as ValidationFailure).code, 'invalid_code');
    await cubit.close();
  });

  test('a correct code emits the signed-in user', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode('123456');
    expect(cubit.state.status, OtpLoginStatus.verified);
    expect(cubit.state.user!.mobileNumber, '+27821234567');
    await cubit.close();
  });

  test('changeNumber returns to the phone step', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    cubit.changeNumber();
    expect(cubit.state, const OtpLoginState());
    await cubit.close();
  });
}
```

`test/registration_cubit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/registration_cubit.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';

void main() {
  late LocalConsentRepository consents;
  late RegistrationCubit cubit;

  setUp(() {
    consents = LocalConsentRepository(InMemorySecureStore());
    cubit = RegistrationCubit(
      LocalRegistrationRepository(InMemorySecureStore()),
      consents: consents,
      initialMobile: '+27821234567',
    )
      ..setFullName('Thandi Mokoena')
      ..setEmail('thandi@example.test')
      ..setAddress('12 Main Road, Soweto');
  });

  tearDown(() => cubit.close());

  test('the verified mobile number is prefilled', () {
    expect(cubit.state.mobileNumber, '+27821234567');
  });

  test('cannot submit before accepting the terms', () async {
    await cubit.submit();
    expect(cubit.state.submitStatus, SubmitStatus.idle);
  });

  test('submitting records terms and privacy consent, and SMS marketing only when chosen', () async {
    cubit
      ..setAcceptedTerms(true)
      ..setMarketingSms(true);
    await cubit.submit();
    expect(cubit.state.submitStatus, SubmitStatus.submitted);
    for (final purpose in [ConsentPurpose.terms, ConsentPurpose.privacy, ConsentPurpose.marketingSms]) {
      expect((await consents.currentConsent(purpose)).getOrElse((_) => null), isNotNull, reason: '$purpose');
    }
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/otp_login_cubit_test.dart test/registration_cubit_test.dart`
Expected: FAIL (compile errors: `otp_login_cubit.dart` missing; `consents:`, `initialMobile:`, `setAcceptedTerms` undefined).

- [ ] **Step 3: Implement the OTP cubit**

`lib/features/auth/presentation/bloc/otp_login_cubit.dart`:

```dart
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

enum OtpStep { phone, code }

enum OtpLoginStatus { idle, sending, verifying, failure, verified }

/// Emits the seconds left, counting down to 0.
typedef CountdownTicker = Stream<int> Function(int seconds);

Stream<int> _secondsTicker(int seconds) =>
    Stream<int>.periodic(const Duration(seconds: 1), (i) => seconds - i - 1).take(seconds);

class OtpLoginState extends Equatable {
  const OtpLoginState({
    this.step = OtpStep.phone,
    this.status = OtpLoginStatus.idle,
    this.challenge,
    this.failure,
    this.resendIn = 0,
    this.user,
  });

  final OtpStep step;
  final OtpLoginStatus status;
  final OtpChallenge? challenge;
  final Failure? failure;

  /// Seconds until "Resend code" is enabled.
  final int resendIn;
  final User? user;

  bool get busy => status == OtpLoginStatus.sending || status == OtpLoginStatus.verifying;

  /// A status change replaces [failure] (null unless given); a countdown
  /// tick keeps it.
  OtpLoginState copyWith({OtpStep? step, OtpLoginStatus? status, OtpChallenge? challenge, Failure? failure, int? resendIn, User? user}) =>
      OtpLoginState(
        step: step ?? this.step,
        status: status ?? this.status,
        challenge: challenge ?? this.challenge,
        failure: status != null ? failure : (failure ?? this.failure),
        resendIn: resendIn ?? this.resendIn,
        user: user ?? this.user,
      );

  @override
  List<Object?> get props => [step, status, challenge, failure, resendIn, user];
}

/// Phone number -> SMS code -> signed in. Sign-in and sign-up are the same
/// flow: the platform creates the account on the first verified code.
class OtpLoginCubit extends Cubit<OtpLoginState> {
  OtpLoginCubit(this._repository, {this.resendCooldown = const Duration(seconds: 30), CountdownTicker? ticker})
      : _ticker = ticker ?? _secondsTicker,
        super(const OtpLoginState());

  static final _sixDigits = RegExp(r'^\d{6}$');

  final AuthRepository _repository;
  final Duration resendCooldown;
  final CountdownTicker _ticker;
  StreamSubscription<int>? _countdown;

  Future<void> submitPhone(String input) async {
    if (state.busy) return;
    if (normaliseZaMobile(input) == null) {
      emit(state.copyWith(
        status: OtpLoginStatus.failure,
        failure: const ValidationFailure('Enter a valid South African mobile number.', 'invalid_phone'),
      ));
      return;
    }
    await _send(input);
  }

  Future<void> resend() async {
    final challenge = state.challenge;
    if (state.busy || challenge == null || state.resendIn > 0) return;
    await _send(challenge.phoneE164);
  }

  Future<void> _send(String phone) async {
    emit(state.copyWith(status: OtpLoginStatus.sending));
    final result = await _repository.requestOtp(phoneNumber: phone);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: OtpLoginStatus.failure, failure: failure)),
      (challenge) {
        emit(state.copyWith(
          step: OtpStep.code,
          status: OtpLoginStatus.idle,
          challenge: challenge,
          resendIn: resendCooldown.inSeconds,
        ));
        _startCountdown();
      },
    );
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = _ticker(resendCooldown.inSeconds).listen((left) {
      if (!isClosed) emit(state.copyWith(resendIn: left));
    });
  }

  Future<void> submitCode(String code) async {
    final challenge = state.challenge;
    if (state.busy || challenge == null) return;
    final trimmed = code.trim();
    if (!_sixDigits.hasMatch(trimmed)) {
      emit(state.copyWith(status: OtpLoginStatus.failure, failure: const ValidationFailure('Enter the 6-digit code.', 'invalid_code')));
      return;
    }
    emit(state.copyWith(status: OtpLoginStatus.verifying));
    final result = await _repository.verifyOtp(challenge: challenge, code: trimmed);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: OtpLoginStatus.failure, failure: failure)),
      (user) {
        _countdown?.cancel();
        emit(state.copyWith(status: OtpLoginStatus.verified, user: user));
      },
    );
  }

  void changeNumber() {
    _countdown?.cancel();
    emit(const OtpLoginState());
  }

  @override
  Future<void> close() async {
    await _countdown?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 4: Registration becomes "complete your profile"**

In `lib/features/auth/presentation/bloc/registration_cubit.dart`:
- Add `this.acceptedTerms = false,` to the `RegistrationState` constructor, the field `final bool acceptedTerms;` (doc: "Terms of Service + Privacy notice accepted (required)"), a `bool? acceptedTerms` parameter in `copyWith` (`acceptedTerms: acceptedTerms ?? this.acceptedTerms`), and `acceptedTerms` in `props`.
- Replace the cubit's constructor, add the setter and replace `submit()` (imports: `consent_record.dart`, `consent_repository.dart`):

```dart
  RegistrationCubit(this._repository, {ConsentRepository? consents, String initialMobile = ''})
      : _consents = consents,
        super(RegistrationState(mobileNumber: initialMobile));

  final RegistrationRepository _repository;
  final ConsentRepository? _consents;

  void setAcceptedTerms(bool v) => emit(state.copyWith(acceptedTerms: v));
```

```dart
  /// Saves the profile, then records the legal consents (POPIA: versioned,
  /// timestamped, server-held in prod). Nothing is submitted without the
  /// terms being accepted.
  Future<void> submit() async {
    if (!state.acceptedTerms || state.submitStatus == SubmitStatus.submitting) return;
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final saved = await _repository.save(state.toDetails());
    if (isClosed) return;
    if (saved.isLeft()) {
      emit(state.copyWith(submitStatus: SubmitStatus.failed));
      return;
    }
    final consents = _consents;
    if (consents != null) {
      for (final purpose in [
        ConsentPurpose.terms,
        ConsentPurpose.privacy,
        if (state.marketingSms) ConsentPurpose.marketingSms,
      ]) {
        final granted = await consents.grant(purpose);
        if (isClosed) return;
        if (granted.isLeft()) {
          emit(state.copyWith(submitStatus: SubmitStatus.failed));
          return;
        }
      }
    }
    emit(state.copyWith(submitStatus: SubmitStatus.submitted));
  }
```

In `lib/features/auth/presentation/pages/registration_page.dart`:
- `create:` becomes:

```dart
      create: (context) => RegistrationCubit(
        locator(),
        consents: locator(),
        initialMobile: context.read<AuthCubit>().state.user?.mobileNumber ?? '',
      ),
```

- In `_RegistrationViewState`, add `initState` that prefills the read-only mobile field:

```dart
  @override
  void initState() {
    super.initState();
    _mobileController.text = context.read<RegistrationCubit>().state.mobileNumber;
  }
```

- Make the mobile `TextField` read-only: add `readOnly: true,` and remove its `onChanged` (the number was verified by SMS).
- Replace the `submitted` listener branch with:

```dart
          if (state.submitStatus == SubmitStatus.submitted) {
            // The router guard then moves the customer on (coverage for a fresh sign-in).
            final auth = context.read<AuthCubit>();
            auth.profileUpdated(User(
              id: auth.state.user?.id ?? 'usr_new',
              fullName: state.fullName.trim(),
              mobileNumber: auth.state.user?.mobileNumber ?? state.mobileNumber,
            ));
          }
```

- Add `state.acceptedTerms &&` to `canSubmit`, and directly above the submit button insert:

```dart
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.acceptedTerms,
                    onChanged: (v) => cubit.setAcceptedTerms(v ?? false),
                    title: Text(l10n.registerAcceptTerms),
                  ),
                  const SizedBox(height: 8),
```

- [ ] **Step 5: Remove the password path**

- `auth_repository.dart`: delete the `logIn` method and its doc comment.
- `mock_auth_repository.dart` and `http_auth_repository.dart`: delete their `logIn` overrides.
- `auth_cubit.dart`: delete `logIn(...)` and `registered(...)`.

- [ ] **Step 6: Strings**

Add to `lib/l10n/app_en.arb`:

```json
  "loginSendCode": "Send code",
  "loginPhoneInvalid": "Enter a valid South African mobile number, e.g. 082 123 4567.",
  "loginNewCustomerHint": "New here? Enter your number and we'll create your account.",
  "loginWelcomeBackName": "Welcome back, {name}",
  "@loginWelcomeBackName": {"placeholders": {"name": {"type": "String"}}},
  "loginNotYou": "Not you? Sign out",
  "otpSentTo": "We sent a 6-digit code to {phone}.",
  "@otpSentTo": {"placeholders": {"phone": {"type": "String"}}},
  "otpCodeHint": "6-digit code",
  "otpVerify": "Verify",
  "otpResend": "Resend code",
  "otpResendIn": "Resend code in {seconds}s",
  "@otpResendIn": {"placeholders": {"seconds": {"type": "int"}}},
  "otpChangeNumber": "Change number",
  "otpInvalidCode": "That code is not right or has expired. Try again or ask for a new code.",
  "otpDemoHint": "Demo mode: any 6-digit code except 000000 works.",
  "registerAcceptTerms": "I accept the Terms of Service and the Privacy notice"
```

Run: `flutter gen-l10n`

- [ ] **Step 7: Replace the login page**

Replace `lib/features/auth/presentation/pages/login_page.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/otp_login_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/dot_grid_panel.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

/// Sign-in and sign-up in one: mobile number -> SMS code. New customers
/// complete their profile next (router rule). A locked session (cold start
/// with an enrolled biometric) can be unlocked with "Use biometrics".
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.demoMode = false});

  /// Shows the "any 6-digit code works" hint (demo flavor only).
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OtpLoginCubit(locator()),
      child: _LoginView(demoMode: demoMode),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.demoMode});

  final bool demoMode;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().refreshBiometrics();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _biometricMessage(BiometricIssue? issue) => switch (issue) {
        null || BiometricIssue.cancelled => null,
        BiometricIssue.notEnrolled => context.l10n.biometricNotEnrolled,
        BiometricIssue.unavailable => context.l10n.biometricUnavailable,
        BiometricIssue.lockedOut => context.l10n.biometricLockedOut,
        BiometricIssue.permanentlyLockedOut => context.l10n.biometricPermanentlyLockedOut,
        BiometricIssue.failed => context.l10n.biometricFailed,
      };

  String _otpMessage(Failure failure) {
    final l10n = context.l10n;
    if (failure is ValidationFailure) {
      switch (failure.code) {
        case 'invalid_phone':
          return l10n.loginPhoneInvalid;
        case 'otp_invalid' || 'invalid_code':
          return l10n.otpInvalidCode;
      }
    }
    if (failure is NetworkFailure) return "You're offline. Check your connection and try again.";
    return failure.message;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      body: MultiBlocListener(
        listeners: [
          BlocListener<AuthCubit, AuthState>(
            listenWhen: (previous, current) => previous.status != current.status,
            listener: (context, state) {
              if (state.status != AuthStatus.failure) return;
              final message = state.errorMessage ?? _biometricMessage(state.biometricIssue);
              if (message != null) _snack(message);
            },
          ),
          BlocListener<OtpLoginCubit, OtpLoginState>(
            listenWhen: (previous, current) => previous.status != current.status || previous.step != current.step,
            listener: (context, state) {
              if (state.status == OtpLoginStatus.failure && state.failure != null) _snack(_otpMessage(state.failure!));
              if (state.status == OtpLoginStatus.verified && state.user != null) {
                context.read<AuthCubit>().signedIn(state.user!, fresh: true);
              }
              if (state.step == OtpStep.phone) _codeController.clear();
            },
          ),
        ],
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, auth) => BlocBuilder<OtpLoginCubit, OtpLoginState>(
            builder: (context, otp) {
              final busy = auth.status == AuthStatus.loading || otp.busy;
              final name = auth.isSignedIn ? null : auth.user?.fullName.trim();
              final firstName = (name == null || name.isEmpty) ? null : name.split(' ').first;
              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: SentechLogo(height: 44)),
                      const SizedBox(height: 24),
                      const DotGridPanel(height: 130),
                      const SizedBox(height: 24),
                      Text(
                        firstName == null ? l10n.loginWelcomeBack : l10n.loginWelcomeBackName(firstName),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.loginSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      if (auth.biometricsReady) ...[
                        OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () => context.read<AuthCubit>().logInWithBiometrics(reason: l10n.biometricPromptReason),
                          icon: const Icon(Icons.fingerprint),
                          label: Text(l10n.loginUseBiometrics),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => context.read<AuthCubit>().logOut(),
                          child: Text(l10n.loginNotYou),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(l10n.loginOr, style: theme.textTheme.bodyMedium),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (otp.step == OtpStep.phone) ..._phoneStep(context, otp, busy) else ..._codeStep(context, otp, busy),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(BuildContext context, OtpLoginState otp, bool busy) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<OtpLoginCubit>();
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        textInputAction: TextInputAction.send,
        onSubmitted: busy ? null : cubit.submitPhone,
        decoration: InputDecoration(hintText: l10n.loginMobileHint),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.loginNewCustomerHint,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: busy ? null : () => cubit.submitPhone(_phoneController.text),
        child: otp.status == OtpLoginStatus.sending ? const _ButtonSpinner() : Text(l10n.loginSendCode),
      ),
    ];
  }

  List<Widget> _codeStep(BuildContext context, OtpLoginState otp, bool busy) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<OtpLoginCubit>();
    return [
      Text(l10n.otpSentTo(maskPhone(otp.challenge!.phoneE164)), style: theme.textTheme.bodyLarge),
      const SizedBox(height: 12),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        textInputAction: TextInputAction.done,
        onSubmitted: busy ? null : cubit.submitCode,
        decoration: InputDecoration(hintText: l10n.otpCodeHint),
      ),
      if (widget.demoMode) ...[
        const SizedBox(height: 6),
        Text(l10n.otpDemoHint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: busy ? null : () => cubit.submitCode(_codeController.text),
        child: otp.status == OtpLoginStatus.verifying ? const _ButtonSpinner() : Text(l10n.otpVerify),
      ),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: busy || otp.resendIn > 0 ? null : cubit.resend,
            child: Text(otp.resendIn > 0 ? l10n.otpResendIn(otp.resendIn) : l10n.otpResend),
          ),
          TextButton(onPressed: busy ? null : cubit.changeNumber, child: Text(l10n.otpChangeNumber)),
        ],
      ),
    ];
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}
```

- [ ] **Step 8: Router: OTP login and the profile rule**

In `lib/app/router/app_router.dart`:
- `_public` becomes `{splash, login, tenantPicker, updateRequired}` (`/register` is now protected).
- In `authRedirect`, directly after the signed-out block, insert:

```dart
  // New customers (first verified code) have no name yet: complete the
  // profile before anything else.
  if (auth.user!.fullName.trim().isEmpty) {
    return location == AppRoutes.register ? null : AppRoutes.register;
  }
```

- Login route builder becomes (import `app_environment.dart`):

```dart
        builder: (context, state) => LoginPage(demoMode: locator<AppEnvironment>().isDemo),
```

- [ ] **Step 9: Write the login widget test**

`test/login_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/login_page.dart';

import 'helpers/test_setup.dart';

void main() {
  setUpAppTests();

  late AuthCubit auth;

  setUp(() {
    locator.registerSingleton<AuthRepository>(MockAuthRepository(latency: Duration.zero));
    auth = AuthCubit(locator(), sessionStore: locator(), biometrics: MockBiometricAuthenticator(), wiper: locator());
  });

  tearDown(() => auth.close());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(BlocProvider.value(value: auth, child: const MaterialApp(home: LoginPage(demoMode: true))));
    await tester.pumpAndSettle();
  }

  testWidgets('phone -> code -> signed in', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '082 123 4567');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();

    expect(find.text('We sent a 6-digit code to +27 82 *** 4567.'), findsOneWidget);
    expect(find.text('Resend code in 30s'), findsOneWidget);
    expect(find.textContaining('Demo mode'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await tester.pump();
    expect(auth.state.isSignedIn, isTrue);
    expect(auth.state.freshSignIn, isTrue);
  });

  testWidgets('an invalid number shows guidance and stays on the phone step', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '011 123 4567');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    expect(find.textContaining('valid South African mobile number'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Verify'), findsNothing);
  });

  testWidgets('a wrong code explains and keeps the customer signed out', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0821234567');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '000000');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('not right or has expired'), findsOneWidget);
    expect(auth.state.isSignedIn, isFalse);
  });

  testWidgets('resend is disabled during the countdown and enabled after it', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0821234567');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Resend code in 30s')).onPressed, isNull);
    await tester.pump(const Duration(seconds: 31));
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Resend code')).onPressed, isNotNull);
  });
}
```

- [ ] **Step 10: Update the existing tests to the OTP flow**

`test/widget_test.dart`: replace `expect(find.text('Log in'), findsOneWidget);` with `expect(find.text('Send code'), findsOneWidget);`.

`test/flow_test.dart`: replace the three lines from `await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0810000000');` through the `Log in` tap with:

```dart
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0810000000');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // mock OTP request delay
    await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
```

(the following `await tester.pumpAndSettle();` stays).

`test/router_test.dart`, test "signed-out deep link to /cart ...": replace the password/`Log in` lines with:

```dart
      await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0810000000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
```

and add to the `authRedirect` group (the file's `_user` has a non-empty `fullName`):

```dart
    test('a new customer without a name must complete the profile first', () {
      const fresh = AuthState(status: AuthStatus.success, user: User(id: 'c1', fullName: '', mobileNumber: '+27821234567'), freshSignIn: true);
      expect(authRedirect(fresh, Uri.parse('/main')), AppRoutes.register);
      expect(authRedirect(fresh, Uri.parse(AppRoutes.register)), isNull);
    });

    test('a customer with a name never lands on /register', () {
      expect(authRedirect(_signedIn, Uri.parse(AppRoutes.register)), AppRoutes.main);
    });

    test('/register is protected', () {
      expect(authRedirect(const AuthState(), Uri.parse(AppRoutes.register)), startsWith(AppRoutes.login));
    });
```

(add `import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';` if missing).

`test/accessibility_test.dart`: `loginPage(auth)` becomes `BlocProvider.value(value: auth, child: const LoginPage())`; in "login: no overflow ..." replace the label list with `for (final label in ['Send code'])` and delete the line entering text into `'Password'`.

`test/l10n_test.dart`: replace the `group('login page', ...)` body with:

```dart
  group('login page', () {
    for (final (locale, welcome) in [
      (const Locale('en'), 'Welcome back'),
      (const Locale('af'), 'Welkom terug'),
      (const Locale('zu'), 'Siyakwamukela futhi'),
    ]) {
      testWidgets('renders in ${locale.languageCode}', (tester) async {
        final auth = newAuth();
        addTearDown(auth.close);
        await tester.pumpWidget(localized(
          locale,
          const LoginPage(),
          wrap: (child) => BlocProvider.value(value: auth, child: child),
        ));
        await tester.pumpAndSettle();
        expect(find.text(welcome), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, lookupAppLocalizations(locale).loginSendCode), findsOneWidget);
      });
    }
  });
```

Run: `git grep -n -E "logIn\(|registered\(|loginPasswordHint|onRegister" -- lib test`
Expected: no matches.

- [ ] **Step 11: Run the tests**

Run: `flutter test test/otp_login_cubit_test.dart test/registration_cubit_test.dart test/login_page_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS.

- [ ] **Step 12: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 13: Commit**

```powershell
git add lib/features/auth/presentation/bloc/otp_login_cubit.dart lib/features/auth/presentation/pages/login_page.dart lib/features/auth/presentation/pages/registration_page.dart lib/features/auth/presentation/bloc/registration_cubit.dart
git add lib/features/auth/presentation/bloc/auth_cubit.dart lib/features/auth/domain/repositories/auth_repository.dart lib/features/auth/data/repositories/mock_auth_repository.dart lib/features/auth/data/repositories/http_auth_repository.dart lib/app/router/app_router.dart
git add lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zu.dart lib/l10n/app_localizations_af.dart
git add test/otp_login_cubit_test.dart test/registration_cubit_test.dart test/login_page_test.dart test/widget_test.dart test/flow_test.dart test/router_test.dart test/accessibility_test.dart test/l10n_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(auth): SMS OTP login with resend timer, profile completion with legal consents"
```

---

### Task 9: Hotspot-pass catalogue and orders over the API (stable idempotency keys)

**Files:**
- Create: `lib/features/catalog_checkout/data/repositories/http_catalog_repository.dart`, `lib/features/catalog_checkout/data/repositories/http_checkout_repository.dart`, `test/fixtures/api/products_page_1.json`, `test/fixtures/api/products_page_2.json`, `test/fixtures/api/order_draft.json`, `test/fixtures/api/orders_page.json`
- Modify: `lib/features/catalog_checkout/domain/entities/plan.dart`, `lib/features/catalog_checkout/domain/entities/order.dart`, `lib/features/catalog_checkout/domain/repositories/checkout_repository.dart`, `lib/features/catalog_checkout/data/repositories/mock_checkout_repository.dart`, `lib/features/catalog_checkout/presentation/bloc/catalog_cubit.dart`, `lib/features/catalog_checkout/presentation/bloc/checkout_cubit.dart`, `lib/features/catalog_checkout/presentation/bloc/payment_cubit.dart`, `lib/features/catalog_checkout/presentation/pages/catalog_page.dart`, `lib/features/catalog_checkout/presentation/pages/checkout_page.dart`, `lib/features/catalog_checkout/presentation/pages/payment_page.dart`, `lib/features/catalog_checkout/presentation/pages/confirmation_page.dart`, `lib/features/account_dashboard/presentation/pages/dashboard_page.dart`, `lib/app/router/app_router.dart`, `lib/app/locator.dart`
- Test: `test/http_catalog_repository_test.dart`, `test/http_checkout_repository_test.dart`; extend `test/order_flow_cubits_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `TenantContext`, `newIdempotencyKey` (Task 3); `formatRands` (Task 1); `TenantCubit.state.featureFlags` (Task 5); `NotFoundFailure`, `ValidationFailure`.
- Produces:
  - `ProductCategory.hotspotPass` (label `Wi-Fi passes`); `String describePass({required int durationMinutes, int? dataMb})`; `Plan planFromProductJson(Map<String, Object?> json)`.
  - `OrderStatus` gains `paymentFailed`, `expired`, `cancelled`; `Order.isOpen` = pendingVerification | awaitingPayment | paymentFailed; `OrderStatus orderStatusFromApi(String status)`; `Order orderFromJson(Map<String, Object?> json)` (order number `SC-` + first 8 id chars, upper case).
  - `CheckoutRepository.createOrder({required List<CartItem> items, String? idempotencyKey})` (the same key returns the same order).
  - `HttpCatalogRepository(ApiClient api, TenantContext tenant)`; `HttpCheckoutRepository(ApiClient api, {String Function()? newKey})`.
  - `CheckoutCubit(CheckoutRepository repository, CartCubit cartCubit, {String Function()? newKey})` (one key per reviewed cart).
  - `CatalogState.availableCategories`; `PaymentStatus.closed`.
  - `CheckoutPage({required onOrderCreated, bool requiresIdentityCheck = true})`.

- [ ] **Step 1: Add the fixtures**

`test/fixtures/api/products_page_1.json` (M1 `Page[ProductOut]`):

```json
{
  "items": [
    {"id": "0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a01", "sku": "PASS-1H", "name": "1 Hour Pass", "description": "Quick browsing", "price": {"amount_cents": 1500, "currency": "ZAR"}, "duration_minutes": 60, "data_mb": 1024, "speed_kbps": 10240, "max_devices": 1},
    {"id": "0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a02", "sku": "PASS-1D", "name": "Day Pass", "description": "All day", "price": {"amount_cents": 4900, "currency": "ZAR"}, "duration_minutes": 1440, "data_mb": 5120, "speed_kbps": null, "max_devices": 2}
  ],
  "next_cursor": "WzEsIjBiMGMiXQ"
}
```

`test/fixtures/api/products_page_2.json`:

```json
{
  "items": [
    {"id": "0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a03", "sku": "PASS-7D", "name": "Week Pass", "description": "", "price": {"amount_cents": 14900, "currency": "ZAR"}, "duration_minutes": 10080, "data_mb": null, "speed_kbps": 20480, "max_devices": 3}
  ],
  "next_cursor": null
}
```

`test/fixtures/api/order_draft.json` (M1 `OrderOut`):

```json
{
  "id": "5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f10",
  "status": "draft",
  "total": {"amount_cents": 3000, "currency": "ZAR"},
  "lines": [
    {"product_id": "0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a01", "sku": "PASS-1H", "name": "1 Hour Pass", "unit_price": {"amount_cents": 1500, "currency": "ZAR"}, "quantity": 2, "line_total": {"amount_cents": 3000, "currency": "ZAR"}, "duration_minutes": 60, "data_mb": 1024, "speed_kbps": 10240, "max_devices": 1}
  ],
  "created_at": "2026-10-01T10:00:00Z",
  "paid_at": null,
  "fulfilled_at": null,
  "cancelled_at": null,
  "expired_at": null
}
```

`test/fixtures/api/orders_page.json`:

```json
{
  "items": [
    {"id": "5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f12", "status": "fulfilled", "total": {"amount_cents": 1500, "currency": "ZAR"}, "lines": [{"product_id": "0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a01", "sku": "PASS-1H", "name": "1 Hour Pass", "unit_price": {"amount_cents": 1500, "currency": "ZAR"}, "quantity": 1, "line_total": {"amount_cents": 1500, "currency": "ZAR"}, "duration_minutes": 60, "data_mb": 1024, "speed_kbps": 10240, "max_devices": 1}], "created_at": "2026-10-01T11:00:00Z", "paid_at": "2026-10-01T11:01:00Z", "fulfilled_at": "2026-10-01T11:01:00Z", "cancelled_at": null, "expired_at": null},
    {"id": "5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f11", "status": "failed", "total": {"amount_cents": 4900, "currency": "ZAR"}, "lines": [{"product_id": "0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a02", "sku": "PASS-1D", "name": "Day Pass", "unit_price": {"amount_cents": 4900, "currency": "ZAR"}, "quantity": 1, "line_total": {"amount_cents": 4900, "currency": "ZAR"}, "duration_minutes": 1440, "data_mb": 5120, "speed_kbps": null, "max_devices": 2}], "created_at": "2026-10-01T10:30:00Z", "paid_at": null, "fulfilled_at": null, "cancelled_at": null, "expired_at": null}
  ],
  "next_cursor": null
}
```

- [ ] **Step 2: Write the failing tests**

`test/http_catalog_repository_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

void main() {
  late ApiHarness h;
  late HttpCatalogRepository repo;

  setUp(() {
    h = ApiHarness();
    repo = HttpCatalogRepository(h.api, h.tenantContext);
  });

  test('follows the cursor across pages and maps passes to integer-cent plans', () async {
    h.adapter.on('GET', '/v1/products', (r) {
      return FakeReply(200, fixture(r.uri.queryParameters['cursor'] == null ? 'products_page_1.json' : 'products_page_2.json'));
    });
    final plans = (await repo.getProducts()).getOrElse((f) => throw StateError(f.message));

    expect(plans.map((p) => p.name), ['1 Hour Pass', 'Day Pass', 'Week Pass']);
    expect(plans.first.priceCents, 1500);
    expect(plans.first.category, ProductCategory.hotspotPass);
    expect(plans.first.dataDescription, '1 GB · 1 hour');
    expect(plans.first.speedMbps, 10);
    expect(plans[1].speedMbps, 0);
    expect(plans[2].dataDescription, 'Unlimited data · 7 days');

    final first = h.adapter.requests.first.uri.queryParameters;
    expect(first['tenant'], 'sentech');
    expect(h.adapter.requests[1].uri.queryParameters['cursor'], 'WzEsIjBiMGMiXQ');
    expect(h.adapter.requests.every((r) => !r.headers.containsKey('Authorization')), isTrue);
  });

  test('offline is a NetworkFailure the catalogue can retry', () async {
    h.adapter.on('GET', '/v1/products', (_) => const FakeReply.error(DioExceptionType.connectionError));
    expect((await repo.getProducts()).match((f) => f, (_) => null), isA<NetworkFailure>());
  });

  test('a non-ZAR price is refused rather than shown wrongly', () async {
    final page = fixtureMap('products_page_2.json');
    final item = Map<String, Object?>.from((page['items']! as List).first as Map)..['price'] = {'amount_cents': 100, 'currency': 'USD'};
    h.adapter.on('GET', '/v1/products', (_) => FakeReply(200, {'items': [item], 'next_cursor': null}));
    expect((await repo.getProducts()).match((f) => f, (_) => null), isA<ServerFailure>());
  });

  test('pass descriptions', () {
    expect(describePass(durationMinutes: 60, dataMb: 1024), '1 GB · 1 hour');
    expect(describePass(durationMinutes: 1440, dataMb: 5120), '5 GB · 1 day');
    expect(describePass(durationMinutes: 120, dataMb: 1536), '1.5 GB · 2 hours');
    expect(describePass(durationMinutes: 30, dataMb: 500), '500 MB · 30 min');
    expect(describePass(durationMinutes: 10080, dataMb: null), 'Unlimited data · 7 days');
  });
}
```

`test/http_checkout_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _pass = Plan(
  id: '0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a01',
  name: '1 Hour Pass',
  priceCents: 1500,
  dataDescription: '1 GB · 1 hour',
  speedMbps: 10,
  category: ProductCategory.hotspotPass,
);

void main() {
  late ApiHarness h;
  late HttpCheckoutRepository repo;

  setUp(() async {
    h = ApiHarness();
    repo = HttpCheckoutRepository(h.api, newKey: () => 'app-generated-key');
    await h.signIn();
  });

  test('createOrder sends product ids and quantities with the caller key; the server owns the total', () async {
    h.adapter.on('POST', '/v1/orders', (_) => FakeReply(201, fixture('order_draft.json')));
    final order = (await repo.createOrder(items: const [CartItem(plan: _pass, quantity: 2)], idempotencyKey: 'app-cart-key-123'))
        .getOrElse((f) => throw StateError(f.message));

    final sent = h.adapter.requestsTo('POST', '/v1/orders').single;
    expect(sent.data, {
      'lines': [
        {'product_id': _pass.id, 'quantity': 2},
      ],
    });
    expect(sent.headers['Idempotency-Key'], 'app-cart-key-123');
    expect(order.id, '5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f10');
    expect(order.status, OrderStatus.awaitingPayment); // hotspot passes skip RICA
    expect(order.totalCents, 3000);
    expect(order.orderNumber, 'SC-5E9B7C1A');
    expect(order.planName, '1 Hour Pass × 2');
  });

  test('createOrder without a key still sends one', () async {
    h.adapter.on('POST', '/v1/orders', (_) => FakeReply(201, fixture('order_draft.json')));
    await repo.createOrder(items: const [CartItem(plan: _pass, quantity: 1)]);
    expect(h.adapter.requests.single.headers['Idempotency-Key'], 'app-generated-key');
  });

  test('an empty cart never reaches the server', () async {
    expect((await repo.createOrder(items: const [])).isLeft(), isTrue);
    expect(h.adapter.requests, isEmpty);
  });

  test('server-side validation (e.g. an inactive pass) comes back as a ValidationFailure', () async {
    h.adapter.on('POST', '/v1/orders', (_) => FakeReply.problem(422, 'product_unavailable', detail: 'That pass is no longer on sale.'));
    final failure = (await repo.createOrder(items: const [CartItem(plan: _pass, quantity: 1)])).match((f) => f, (_) => null);
    expect(failure, const ValidationFailure('That pass is no longer on sale.', 'product_unavailable'));
  });

  test('the open order is the newest unpaid one (failed payments are resumable)', () async {
    h.adapter.on('GET', '/v1/orders', (_) => FakeReply(200, fixture('orders_page.json')));
    final open = (await repo.getOpenOrder()).getOrElse((f) => throw StateError(f.message));
    expect(open!.id, '5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f11');
    expect(open.status, OrderStatus.paymentFailed);
    expect(open.isOpen, isTrue);
  });

  test('an unknown order is a NotFoundFailure', () async {
    h.adapter.on('GET', '/v1/orders/nope', (_) => FakeReply.problem(404, 'order_not_found', detail: 'Unknown order.'));
    expect((await repo.getOrder('nope')).match((f) => f, (_) => null), isA<NotFoundFailure>());
  });

  test('every server status maps to a domain status', () {
    expect(orderStatusFromApi('draft'), OrderStatus.awaitingPayment);
    expect(orderStatusFromApi('awaiting_payment'), OrderStatus.awaitingPayment);
    expect(orderStatusFromApi('failed'), OrderStatus.paymentFailed);
    expect(orderStatusFromApi('paid'), OrderStatus.paid);
    expect(orderStatusFromApi('fulfilled'), OrderStatus.paid);
    expect(orderStatusFromApi('expired'), OrderStatus.expired);
    expect(orderStatusFromApi('cancelled'), OrderStatus.cancelled);
    expect(() => orderStatusFromApi('refunded'), throwsFormatException);
  });
}
```

Append to `test/order_flow_cubits_test.dart`, inside `main()` (add imports `package:sentech_connect_app/features/cart/domain/entities/cart_item.dart` and `package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart` if missing):

```dart
  group('CheckoutCubit idempotency', () {
    test('a retry after a failure reuses the SAME key (no second order for one cart)', () async {
      final keys = <String?>[];
      final recording = _KeyRecordingCheckout(repo, keys);
      var n = 0;
      final cubit = CheckoutCubit(recording, cart, newKey: () => 'app-key-${n++}');
      network.offline = true;
      await cubit.createOrder();
      network.offline = false;
      await cubit.createOrder();
      expect(keys, ['app-key-0', 'app-key-0']);
      expect(cubit.state.status, CheckoutStatus.created);
      await cubit.close();
    });

    test('a new checkout (new cart review) gets a new key', () async {
      final keys = <String?>[];
      var n = 0;
      String key() => 'app-key-${n++}';
      final first = CheckoutCubit(_KeyRecordingCheckout(repo, keys), cart, newKey: key);
      await first.createOrder();
      final second = CheckoutCubit(_KeyRecordingCheckout(repo, keys), cart, newKey: key);
      await second.createOrder();
      expect(keys.toSet(), hasLength(2));
      await first.close();
      await second.close();
    });

    test('the demo repository honours the key like the server does', () async {
      final a = (await repo.createOrder(items: cart.state.items, idempotencyKey: 'app-same')).getOrElse((_) => throw StateError('a'));
      final b = (await repo.createOrder(items: cart.state.items, idempotencyKey: 'app-same')).getOrElse((_) => throw StateError('b'));
      expect(b.id, a.id);
    });
  });
```

and at the bottom of the file (top level):

```dart
class _KeyRecordingCheckout implements CheckoutRepository {
  _KeyRecordingCheckout(this._inner, this.keys);

  final CheckoutRepository _inner;
  final List<String?> keys;

  @override
  Future<Either<Failure, Order>> createOrder({required List<CartItem> items, String? idempotencyKey}) {
    keys.add(idempotencyKey);
    return _inner.createOrder(items: items, idempotencyKey: idempotencyKey);
  }

  @override
  Future<Either<Failure, Order>> getOrder(String orderId) => _inner.getOrder(orderId);

  @override
  Future<Either<Failure, Order?>> getOpenOrder() => _inner.getOpenOrder();

  @override
  Future<Either<Failure, Order>> markIdentityVerified(String orderId) => _inner.markIdentityVerified(orderId);

  @override
  Future<Either<Failure, Order>> pay({required String orderId, required PaymentMethod method}) =>
      _inner.pay(orderId: orderId, method: method);

  @override
  Future<void> clearLocalOrders() => _inner.clearLocalOrders();
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/http_catalog_repository_test.dart test/http_checkout_repository_test.dart test/order_flow_cubits_test.dart`
Expected: FAIL (compile errors: missing HTTP repositories, `ProductCategory.hotspotPass`, `idempotencyKey:`, `newKey:`, `OrderStatus.paymentFailed`).

- [ ] **Step 4: Domain changes**

`plan.dart`: add `hotspotPass` to `ProductCategory` (after `voucher`) and the label case `ProductCategory.hotspotPass => 'Wi-Fi passes',`.

`order.dart`: replace the enum and `isOpen` with:

```dart
enum OrderStatus {
  /// Created from the cart; RICA verification still required (Home 5G, flagged).
  pendingVerification,

  /// Ready to pay (identity verified, or not needed: hotspot passes skip RICA).
  awaitingPayment,

  /// The last payment attempt failed or was declined; paying again is safe.
  paymentFailed,

  /// Paid; the server creates the entitlements.
  paid,

  /// Not paid in time (server-side expiry); it can no longer be paid.
  expired,

  cancelled,
}
```

```dart
  bool get isOpen =>
      status == OrderStatus.pendingVerification || status == OrderStatus.awaitingPayment || status == OrderStatus.paymentFailed;
```

`checkout_repository.dart`: replace `createOrder` with:

```dart
  /// Creates an order from the cart. [idempotencyKey] identifies this
  /// checkout attempt: repeating the call with the same key (e.g. after a
  /// timeout) returns the SAME order instead of creating a second one.
  Future<Either<Failure, Order>> createOrder({required List<CartItem> items, String? idempotencyKey});
```

`mock_checkout_repository.dart`: add the field `final _ordersByKey = <String, String>{};`, change the signature to `createOrder({required List<CartItem> items, String? idempotencyKey})`, and directly after the empty-cart check insert:

```dart
    if (idempotencyKey != null) {
      final existingId = _ordersByKey[idempotencyKey];
      final existing = existingId == null ? null : (await _load()).where((o) => o.id == existingId).firstOrNull;
      if (existing != null) return Right(existing);
    }
```

and before `return Right(order);`:

```dart
    if (idempotencyKey != null) _ordersByKey[idempotencyKey] = order.id;
```

- [ ] **Step 5: The HTTP repositories**

`lib/features/catalog_checkout/data/repositories/http_catalog_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';

/// The tenant's active hotspot passes (`GET /v1/products?tenant=`), public.
class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository(this._api, this._tenant);

  static const pageSize = 50;
  static const maxPages = 10;

  final ApiClient _api;
  final TenantContext _tenant;

  @override
  Future<Either<Failure, List<Plan>>> getProducts() async {
    final plans = <Plan>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final result = await _api.get<(List<Plan>, String?)>(
        '/v1/products',
        authenticated: false,
        timeout: const Duration(seconds: 15),
        query: {'tenant': _tenant.slug, 'limit': pageSize, 'cursor': ?cursor},
        decode: _decodePage,
      );
      switch (result) {
        case Left(value: final failure):
          return Left(failure);
        case Right(value: (final items, final next)):
          plans.addAll(items);
          cursor = next;
      }
      if (cursor == null) break;
    }
    return Right(plans);
  }

  static (List<Plan>, String?) _decodePage(Object? data) {
    final map = data! as Map;
    final items = map['items']! as List;
    return ([for (final item in items) planFromProductJson(Map<String, Object?>.from(item as Map))], map['next_cursor'] as String?);
  }
}

/// M1 `ProductOut` -> [Plan]. Rejects anything but ZAR.
Plan planFromProductJson(Map<String, Object?> json) {
  final price = json['price']! as Map;
  if (price['currency'] != 'ZAR') throw FormatException('Unsupported currency ${price['currency']}');
  final speedKbps = json['speed_kbps'] as int?;
  return Plan(
    id: json['id']! as String,
    name: json['name']! as String,
    priceCents: price['amount_cents']! as int,
    dataDescription: describePass(durationMinutes: json['duration_minutes']! as int, dataMb: json['data_mb'] as int?),
    speedMbps: speedKbps == null ? 0 : speedKbps ~/ 1000,
    category: ProductCategory.hotspotPass,
  );
}

/// "1 GB · 1 hour", "Unlimited data · 7 days".
String describePass({required int durationMinutes, int? dataMb}) {
  final String data;
  if (dataMb == null) {
    data = 'Unlimited data';
  } else if (dataMb % 1024 == 0) {
    data = '${dataMb ~/ 1024} GB';
  } else if (dataMb >= 1024) {
    data = '${(dataMb / 1024).toStringAsFixed(1)} GB';
  } else {
    data = '$dataMb MB';
  }
  final String duration;
  if (durationMinutes % 1440 == 0) {
    final days = durationMinutes ~/ 1440;
    duration = days == 1 ? '1 day' : '$days days';
  } else if (durationMinutes % 60 == 0) {
    final hours = durationMinutes ~/ 60;
    duration = hours == 1 ? '1 hour' : '$hours hours';
  } else {
    duration = '$durationMinutes min';
  }
  return '$data · $duration';
}
```

`lib/features/catalog_checkout/data/repositories/http_checkout_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';

/// Orders on the platform (`/v1/orders`). The server owns prices, totals,
/// order state and resumability, so nothing is stored on the device.
class HttpCheckoutRepository implements CheckoutRepository {
  HttpCheckoutRepository(this._api, {String Function()? newKey}) : _newKey = newKey ?? newIdempotencyKey;

  static const _openStatuses = {'draft', 'awaiting_payment', 'failed'};

  final ApiClient _api;
  final String Function() _newKey;

  @override
  Future<Either<Failure, Order>> createOrder({required List<CartItem> items, String? idempotencyKey}) async {
    if (items.isEmpty) return const Left(ValidationFailure('Your cart is empty.'));
    return _api.post<Order>(
      '/v1/orders',
      body: {
        'lines': [
          for (final item in items) {'product_id': item.plan.id, 'quantity': item.quantity},
        ],
      },
      idempotencyKey: idempotencyKey ?? _newKey(),
      decode: (data) => orderFromJson(Map<String, Object?>.from(data! as Map)),
    );
  }

  @override
  Future<Either<Failure, Order>> getOrder(String orderId) => _api.get<Order>(
        '/v1/orders/${Uri.encodeComponent(orderId)}',
        timeout: const Duration(seconds: 10),
        decode: (data) => orderFromJson(Map<String, Object?>.from(data! as Map)),
      );

  @override
  Future<Either<Failure, Order?>> getOpenOrder() => _api.get<Order?>(
        '/v1/orders',
        query: {'limit': 20},
        decode: (data) {
          for (final item in (data! as Map)['items']! as List) {
            final map = Map<String, Object?>.from(item as Map);
            if (_openStatuses.contains(map['status'])) return orderFromJson(map);
          }
          return null;
        },
      );

  /// Hotspot passes skip RICA (spec §3); identity checks are flagged off.
  @override
  Future<Either<Failure, Order>> markIdentityVerified(String orderId) async =>
      const Left(ValidationFailure('Identity checks are not needed for this order.', 'rica_disabled'));

  /// Replaced by the hosted-payment hand-off in the next task.
  @override
  Future<Either<Failure, Order>> pay({required String orderId, required PaymentMethod method}) async =>
      const Left(ServerFailure('Online payment is not available yet.'));

  @override
  Future<void> clearLocalOrders() async {}
}

OrderStatus orderStatusFromApi(String status) => switch (status) {
      'draft' || 'awaiting_payment' => OrderStatus.awaitingPayment,
      'failed' => OrderStatus.paymentFailed,
      'paid' || 'fulfilled' => OrderStatus.paid,
      'expired' => OrderStatus.expired,
      'cancelled' => OrderStatus.cancelled,
      _ => throw FormatException('Unknown order status $status'),
    };

/// M1 `OrderOut` -> [Order]. The API has no customer-facing number, so the
/// app shows `SC-` + the first 8 characters of the id (ruling R-M4-7).
Order orderFromJson(Map<String, Object?> json) {
  final id = json['id']! as String;
  final total = json['total']! as Map;
  if (total['currency'] != 'ZAR') throw FormatException('Unsupported currency ${total['currency']}');
  final lines = (json['lines']! as List).cast<Map<Object?, Object?>>();
  final String planName;
  if (lines.length == 1) {
    final quantity = lines.single['quantity']! as int;
    final name = lines.single['name']! as String;
    planName = quantity > 1 ? '$name × $quantity' : name;
  } else {
    planName = '${lines.length} items';
  }
  return Order(
    id: id,
    orderNumber: 'SC-${id.replaceAll('-', '').substring(0, 8).toUpperCase()}',
    planName: planName,
    totalCents: total['amount_cents']! as int,
    status: orderStatusFromApi(json['status']! as String),
  );
}
```

- [ ] **Step 6: Cubits**

`checkout_cubit.dart` (import `package:sentech_connect_app/core/network/idempotency.dart`): replace the constructor and `createOrder` with:

```dart
  CheckoutCubit(this._repository, CartCubit cartCubit, {String Function()? newKey})
      : _idempotencyKey = (newKey ?? newIdempotencyKey)(),
        super(CheckoutState(items: cartCubit.state.items));

  final CheckoutRepository _repository;

  /// One key per reviewed cart: a retry after a timeout (when the server may
  /// already have created the order) gets the same order back, never a
  /// second one (review C6; spec §6 Idempotency-Key).
  final String _idempotencyKey;

  Future<void> createOrder() async {
    if (state.status == CheckoutStatus.creating) return; // double-tap guard
    emit(state.copyWith(status: CheckoutStatus.creating));
    final result = await _repository.createOrder(items: state.items, idempotencyKey: _idempotencyKey);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: CheckoutStatus.failure, failure: failure)),
      (order) => emit(state.copyWith(status: CheckoutStatus.created, order: order)),
    );
  }
```

`catalog_cubit.dart`: add to `CatalogState`:

```dart
  /// Categories that actually have products, in display order (prod has
  /// only hotspot passes; demo has Home 5G, MiFi and vouchers).
  List<ProductCategory> get availableCategories =>
      ProductCategory.values.where((c) => allProducts.any((p) => p.category == c)).toList();
```

and replace the success branch in `load()` and `selectCategory` with:

```dart
      (products) {
        final loaded = state.copyWith(status: CatalogStatus.loaded, allProducts: products);
        final categories = loaded.availableCategories;
        final selected = categories.isEmpty || categories.contains(state.selectedCategory) ? state.selectedCategory : categories.first;
        emit(loaded.copyWith(selectedCategory: selected));
      },
```

```dart
  /// Ignores categories with nothing to show (e.g. "Top up" -> vouchers in prod).
  void selectCategory(ProductCategory category) {
    if (state.status == CatalogStatus.loaded && !state.availableCategories.contains(category)) return;
    emit(state.copyWith(selectedCategory: category));
  }
```

`payment_cubit.dart`: add `closed` to `PaymentStatus` (doc: "Expired or cancelled: cannot be paid any more.") and replace `_statusFor` with:

```dart
  PaymentStatus _statusFor(Order order) => switch (order.status) {
        OrderStatus.pendingVerification => PaymentStatus.needsVerification,
        OrderStatus.awaitingPayment || OrderStatus.paymentFailed => PaymentStatus.ready,
        OrderStatus.paid => PaymentStatus.paid,
        OrderStatus.expired || OrderStatus.cancelled => PaymentStatus.closed,
      };
```

- [ ] **Step 7: Screens and routes**

`catalog_page.dart`:
- `_SegmentedRow` gets `required this.categories` (`final List<ProductCategory> categories;`) and builds `Row(children: categories.map(seg).toList())`.
- In the list, replace the `_SegmentedRow(...)` and following `SizedBox` with:

```dart
              if (state.availableCategories.length > 1) ...[
                _SegmentedRow(
                  categories: state.availableCategories,
                  selected: state.selectedCategory,
                  onSelect: (c) => context.read<CatalogCubit>().selectCategory(c),
                ),
                const SizedBox(height: 16),
              ],
```

- In `_PlanCard`: the per-month suffix becomes `text: plan.category == ProductCategory.home5g || plan.category == ProductCategory.mifi ? '/mo' : '',` and the description line becomes:

```dart
                plan.speedMbps > 0 ? '${plan.dataDescription} · up to ${plan.speedMbps} Mbps' : plan.dataDescription,
```

`checkout_page.dart`: add `this.requiresIdentityCheck = true` / `final bool requiresIdentityCheck;` to `CheckoutPage`, and:
- info text: `requiresIdentityCheck ? 'Next we verify your identity (required by RICA). You are only charged after that succeeds.' : 'You pay on a secure payment page. Your pass starts as soon as the payment is confirmed.'`
- button: `Text(requiresIdentityCheck ? 'Verify identity to continue' : 'Continue to payment')` (drop the `const`).
- `_SummaryCard` gets `required this.dueLabel` (`final String dueLabel;`), passed `dueLabel: requiresIdentityCheck ? 'Due after verification' : 'Total due'`, and uses `row(dueLabel, formatRands(totalCents), total: true)`.

`payment_page.dart`: directly after the `loadFailed` branch in the builder add:

```dart
          if (state.status == PaymentStatus.closed) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('This order can no longer be paid. Start a new order from Shop.', textAlign: TextAlign.center),
              ),
            );
          }
```

`confirmation_page.dart`: replace the non-paid branch with:

```dart
        if (order.status != OrderStatus.paid) {
          // Deep link / restored state pointing at an order that is not
          // complete: never claim "connected" for an unpaid order.
          final closed = order.status == OrderStatus.expired || order.status == OrderStatus.cancelled;
          final message = switch (order.status) {
            OrderStatus.expired => 'Order #${order.orderNumber} expired before it was paid. You have not been charged.',
            OrderStatus.cancelled => 'Order #${order.orderNumber} was cancelled. You have not been charged.',
            _ => 'Order #${order.orderNumber} is not complete yet.',
          };
          return Scaffold(
            appBar: AppBar(title: const Text('Order')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    closed
                        ? ElevatedButton(onPressed: onDone, child: const Text('Back to dashboard'))
                        : ElevatedButton(onPressed: () => onResume(order), child: const Text('Continue your order')),
                  ],
                ),
              ),
            ),
          );
        }
```

`dashboard_page.dart`, `_ResumeOrderBanner.build`: replace the subtitle `Text(needsVerification ? ... : ...)` text with

```dart
                      switch (order.status) {
                        OrderStatus.pendingVerification => 'Verify your identity to continue',
                        OrderStatus.paymentFailed => 'Your last payment did not go through. Try again.',
                        _ => 'Complete your payment',
                      },
```

`app_router.dart`:
- `AppRoutes.forOrder` becomes:

```dart
  static String forOrder(Order order) => switch (order.status) {
        OrderStatus.pendingVerification => ricaFor(order.id),
        OrderStatus.awaitingPayment || OrderStatus.paymentFailed => paymentFor(order.id),
        OrderStatus.paid || OrderStatus.expired || OrderStatus.cancelled => confirmationFor(order.id),
      };
```

- checkout route child becomes:

```dart
            child: CheckoutPage(
              requiresIdentityCheck: tenantCubit?.state.featureFlags.rica ?? true,
              onOrderCreated: (order) => context.push(AppRoutes.forOrder(order)),
            ),
```

`lib/app/locator.dart`, `_registerProdRepositories`: replace the catalog and checkout lines with (imports for the two HTTP classes):

```dart
  locator.registerLazySingleton<CatalogRepository>(() => HttpCatalogRepository(locator(), locator()));
  locator.registerLazySingleton<CheckoutRepository>(() => HttpCheckoutRepository(locator()));
```

- [ ] **Step 8: Run the tests**

Run: `flutter test test/http_catalog_repository_test.dart test/http_checkout_repository_test.dart test/order_flow_cubits_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS (demo flow unchanged: mock orders start `pendingVerification`, so `forOrder` still routes to RICA).

- [ ] **Step 9: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```powershell
git add lib/features/catalog_checkout/data/repositories/http_catalog_repository.dart lib/features/catalog_checkout/data/repositories/http_checkout_repository.dart
git add lib/features/catalog_checkout/domain/entities/plan.dart lib/features/catalog_checkout/domain/entities/order.dart lib/features/catalog_checkout/domain/repositories/checkout_repository.dart lib/features/catalog_checkout/data/repositories/mock_checkout_repository.dart
git add lib/features/catalog_checkout/presentation/bloc/catalog_cubit.dart lib/features/catalog_checkout/presentation/bloc/checkout_cubit.dart lib/features/catalog_checkout/presentation/bloc/payment_cubit.dart
git add lib/features/catalog_checkout/presentation/pages/catalog_page.dart lib/features/catalog_checkout/presentation/pages/checkout_page.dart lib/features/catalog_checkout/presentation/pages/payment_page.dart lib/features/catalog_checkout/presentation/pages/confirmation_page.dart
git add lib/features/account_dashboard/presentation/pages/dashboard_page.dart lib/app/router/app_router.dart lib/app/locator.dart
git add test/fixtures/api/products_page_1.json test/fixtures/api/products_page_2.json test/fixtures/api/order_draft.json test/fixtures/api/orders_page.json
git add test/http_catalog_repository_test.dart test/http_checkout_repository_test.dart test/order_flow_cubits_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(shop): hotspot passes and orders over the API with per-checkout idempotency keys"
```

---

### Task 10: Hosted-payment hand-off (web view), local fake-gateway approval and bounded order polling

**Files:**
- Create: `lib/features/catalog_checkout/domain/entities/payment_handoff.dart`, `lib/features/catalog_checkout/data/dev_payment_simulator.dart`, `lib/features/catalog_checkout/presentation/payment/payment_urls.dart`, `lib/features/catalog_checkout/presentation/payment/payment_web_view_page.dart`, `lib/features/catalog_checkout/presentation/payment/fake_gateway_sheet.dart`, `test/fixtures/api/checkout_fake.json`, `test/fixtures/api/checkout_netcash.json`
- Modify: `pubspec.yaml`, `pubspec.lock` (via `flutter pub add webview_flutter`), `lib/features/catalog_checkout/domain/repositories/checkout_repository.dart`, `lib/features/catalog_checkout/domain/entities/plan.dart` (delete `PaymentMethod`), `lib/features/catalog_checkout/data/repositories/mock_checkout_repository.dart`, `lib/features/catalog_checkout/data/repositories/http_checkout_repository.dart`, `lib/features/catalog_checkout/presentation/bloc/payment_cubit.dart` (full replacement), `lib/features/catalog_checkout/presentation/pages/payment_page.dart` (full replacement), `lib/app/router/app_router.dart`, `lib/app/locator.dart`
- Test: `test/payment_polling_test.dart`, `test/payment_urls_test.dart`; update `test/http_checkout_repository_test.dart`, `test/checkout_repository_test.dart`, `test/order_flow_cubits_test.dart`

**Interfaces:**
- Consumes: `CheckoutRepository.getOrder`, `OrderStatus` incl. `paymentFailed/expired/cancelled`, `HttpCheckoutRepository`, `PaymentStatus.closed` (Task 9); `ApiClient` (Task 3); `AppEnvironment.localDevHosts` (Task 2); `formatRands` (Task 1).
- Produces:
  - `enum PaymentHandoffMethod { get, post }`; `class PaymentHandoff { String paymentId, reference, gateway; PaymentHandoffMethod method; Uri url; Map<String, String> fields; int amountCents; static const demoGateway = 'demo'; static const fakeGateway = 'fake'; bool get isDemo; bool get isFakeGateway; }`
  - `CheckoutRepository.startPayment({required String orderId}) -> Future<Either<Failure, PaymentHandoff>>` (replaces `pay`; `PaymentMethod` is deleted).
  - `class DevPaymentSimulator { DevPaymentSimulator(ApiClient api); Future<Either<Failure, String>> simulate({required String paymentId, required bool accepted}); }`
  - `bool isPaymentReturnUrl(Uri uri)`; `bool isAllowedPaymentUrl(Uri uri, {required bool allowLocalHttp})`; `Uri getHandoffUri(PaymentHandoff handoff)`; `String formBody(Map<String, String> fields)`.
  - `PaymentWebViewPage({required PaymentHandoff handoff})` (pops `true` on a return URL, `false` on close); `Future<bool?> showFakeGatewaySheet(BuildContext context, PaymentHandoff handoff)`.
  - `enum PaymentStatus { loading, loadFailed, needsVerification, ready, starting, handoff, confirming, stillPending, payFailed, paid, closed }`; `const defaultPollDelays`; `PaymentState { status, order, handoff, failure }`; `PaymentCubit(CheckoutRepository repository, CartCubit cartCubit, String orderId, {List<Duration> pollDelays = defaultPollDelays, Future<void> Function(Duration)? wait})` with `load()`, `pay()`, `handoffFinished()`, `checkAgain()`.
  - `PaymentPage({required onPaid, required onNeedsVerification, required VoidCallback onClosed, bool showIdentityVerified = true, DevPaymentSimulator? devSimulator})`.

- [ ] **Step 1: Add the web view and the fixtures**

Run: `flutter pub add webview_flutter`
Expected: `webview_flutter: ^4.x.y` added to `pubspec.yaml`.

`test/fixtures/api/checkout_fake.json` (M1 `CheckoutOut`, fake gateway as in the local stack):

```json
{"payment_id": "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d", "reference": "SC5E9B7C1A", "gateway": "fake", "amount": {"amount_cents": 3000, "currency": "ZAR"}, "method": "GET", "url": "https://fake-gateway.invalid/pay", "fields": {"reference": "SC5E9B7C1A", "amount_cents": "3000"}}
```

`test/fixtures/api/checkout_netcash.json` (SHAPE-ONLY, like the M1 Netcash adapter; field names unverified):

```json
{"payment_id": "9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6e", "reference": "SC5E9B7C1A", "gateway": "netcash", "amount": {"amount_cents": 3000, "currency": "ZAR"}, "method": "POST", "url": "https://paynow.netcash.co.za/site/paynow.aspx", "fields": {"m1": "test-service-key", "p2": "SC5E9B7C1A", "p4": "30.00"}}
```

- [ ] **Step 2: Write the failing tests**

`test/payment_urls_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_urls.dart';

void main() {
  test('our return URLs end the hand-off (any host: they only trigger polling)', () {
    expect(isPaymentReturnUrl(Uri.parse('https://www.example.test/sentech/checkout/accepted')), isTrue);
    expect(isPaymentReturnUrl(Uri.parse('https://www.example.test/acme-wifi/checkout/declined')), isTrue);
    expect(isPaymentReturnUrl(Uri.parse('http://127.0.0.1:3000/sentech/checkout/return')), isTrue);
    expect(isPaymentReturnUrl(Uri.parse('https://paynow.netcash.co.za/site/paynow.aspx')), isFalse);
    expect(isPaymentReturnUrl(Uri.parse('https://www.example.test/checkout/accepted')), isFalse);
  });

  test('only https is navigable; local http only when allowed (debug)', () {
    expect(isAllowedPaymentUrl(Uri.parse('https://paynow.netcash.co.za/x'), allowLocalHttp: false), isTrue);
    expect(isAllowedPaymentUrl(Uri.parse('http://paynow.netcash.co.za/x'), allowLocalHttp: true), isFalse);
    expect(isAllowedPaymentUrl(Uri.parse('http://10.0.2.2:3000/x'), allowLocalHttp: true), isTrue);
    expect(isAllowedPaymentUrl(Uri.parse('http://10.0.2.2:3000/x'), allowLocalHttp: false), isFalse);
    for (final url in ['javascript:alert(1)', 'intent://pay#Intent;end', 'file:///etc/hosts', 'data:text/html,hi']) {
      expect(isAllowedPaymentUrl(Uri.parse(url), allowLocalHttp: true), isFalse, reason: url);
    }
  });

  test('GET hand-offs carry the fields in the query; POST bodies are form-encoded', () {
    final handoff = PaymentHandoff(
      paymentId: 'p1',
      reference: 'SC1',
      gateway: 'fake',
      method: PaymentHandoffMethod.get,
      url: Uri.parse('https://fake-gateway.invalid/pay?x=1'),
      fields: const {'reference': 'SC1', 'amount_cents': '3000'},
      amountCents: 3000,
    );
    expect(getHandoffUri(handoff).queryParameters, {'x': '1', 'reference': 'SC1', 'amount_cents': '3000'});
    expect(formBody(const {'p3': '1 Hour Pass', 'a&b': 'c=d'}), 'p3=1+Hour+Pass&a%26b=c%3Dd');
  });
}
```

`test/payment_polling_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';

const _pass = Plan(id: 'p', name: '1 Hour Pass', priceCents: 1500, dataDescription: '1 GB · 1 hour', speedMbps: 10, category: ProductCategory.hotspotPass);

final _handoff = PaymentHandoff(
  paymentId: 'pay1',
  reference: 'SC1',
  gateway: 'netcash',
  method: PaymentHandoffMethod.post,
  url: Uri.parse('https://paynow.netcash.co.za/site/paynow.aspx'),
  amountCents: 1500,
);

/// Load returns [loadStatus]; each poll takes the next scripted reply.
class _ScriptedCheckout implements CheckoutRepository {
  _ScriptedCheckout({this.loadStatus = OrderStatus.awaitingPayment, List<Either<Failure, OrderStatus>>? polls}) : polls = polls ?? [];

  final OrderStatus loadStatus;
  final List<Either<Failure, OrderStatus>> polls;
  int getCalls = 0;
  int startCalls = 0;
  Completer<void>? startGate;

  Order _order(OrderStatus s) => Order(id: 'o1', orderNumber: 'SC-O1', planName: '1 Hour Pass', totalCents: 1500, status: s);

  @override
  Future<Either<Failure, Order>> getOrder(String orderId) async {
    getCalls++;
    if (getCalls == 1) return Right(_order(loadStatus));
    final next = polls.isEmpty ? const Right<Failure, OrderStatus>(OrderStatus.awaitingPayment) : polls.removeAt(0);
    return next.map(_order);
  }

  @override
  Future<Either<Failure, PaymentHandoff>> startPayment({required String orderId}) async {
    startCalls++;
    await startGate?.future;
    return Right(_handoff);
  }

  @override
  Future<Either<Failure, Order>> createOrder({required List<CartItem> items, String? idempotencyKey}) => throw UnimplementedError();

  @override
  Future<Either<Failure, Order?>> getOpenOrder() => throw UnimplementedError();

  @override
  Future<Either<Failure, Order>> markIdentityVerified(String orderId) => throw UnimplementedError();

  @override
  Future<void> clearLocalOrders() async {}
}

void main() {
  late CartCubit cart;
  late List<Duration> waits;

  setUp(() {
    cart = CartCubit()..addItem(_pass);
    waits = [];
  });

  tearDown(() => cart.close());

  Future<PaymentCubit> ready(_ScriptedCheckout repo, {List<Duration> delays = defaultPollDelays, Future<void> Function(Duration)? wait}) async {
    final cubit = PaymentCubit(repo, cart, 'o1', pollDelays: delays, wait: wait ?? (d) async => waits.add(d));
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  test('polls until the server marks the order paid, then clears the cart', () async {
    final repo = _ScriptedCheckout(polls: [const Right(OrderStatus.awaitingPayment), const Right(OrderStatus.awaitingPayment), const Right(OrderStatus.paid)]);
    final cubit = await ready(repo);
    await cubit.pay();
    expect(cubit.state.status, PaymentStatus.handoff);
    expect(cubit.state.handoff, _handoff);
    await cubit.handoffFinished();
    expect(cubit.state.status, PaymentStatus.paid);
    expect(repo.getCalls, 1 + 3);
    expect(waits, defaultPollDelays.take(3).toList());
    expect(cart.state.items, isEmpty);
    await cubit.close();
  });

  test('a declined payment ends polling with a retryable failure and keeps the cart', () async {
    final repo = _ScriptedCheckout(polls: [const Right(OrderStatus.paymentFailed)]);
    final cubit = await ready(repo);
    await cubit.pay();
    await cubit.handoffFinished();
    expect(cubit.state.status, PaymentStatus.payFailed);
    expect((cubit.state.failure! as ValidationFailure).code, 'payment_failed');
    expect(cart.state.items, isNotEmpty);
    await cubit.close();
  });

  test('polling is bounded: no confirmation within the schedule -> stillPending, then silence', () async {
    final repo = _ScriptedCheckout();
    final cubit = await ready(repo, delays: const [Duration.zero, Duration.zero, Duration.zero]);
    await cubit.pay();
    await cubit.handoffFinished();
    expect(cubit.state.status, PaymentStatus.stillPending);
    expect(repo.getCalls, 1 + 3);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.getCalls, 1 + 3);

    repo.polls.add(const Right(OrderStatus.paid));
    await cubit.checkAgain();
    expect(cubit.state.status, PaymentStatus.paid);
    await cubit.close();
  });

  test('offline blips while polling are tolerated', () async {
    final repo = _ScriptedCheckout(polls: [const Left(NetworkFailure()), const Right(OrderStatus.paid)]);
    final cubit = await ready(repo);
    await cubit.pay();
    await cubit.handoffFinished();
    expect(cubit.state.status, PaymentStatus.paid);
    await cubit.close();
  });

  test('closing the screen stops polling', () async {
    final repo = _ScriptedCheckout();
    final gate = Completer<void>();
    final cubit = await ready(repo, wait: (_) => gate.future);
    await cubit.pay();
    final polling = cubit.handoffFinished();
    await cubit.close();
    gate.complete();
    await polling;
    expect(repo.getCalls, 1);
  });

  test('double-tapping Pay starts ONE payment attempt', () async {
    final repo = _ScriptedCheckout()..startGate = Completer<void>();
    final cubit = await ready(repo);
    final first = cubit.pay();
    final second = cubit.pay();
    repo.startGate!.complete();
    await Future.wait([first, second]);
    expect(repo.startCalls, 1);
    await cubit.close();
  });

  test('an expired order is reported as closed, not payable', () async {
    final cubit = await ready(_ScriptedCheckout(loadStatus: OrderStatus.expired));
    expect(cubit.state.status, PaymentStatus.closed);
    await cubit.close();
  });

  test('an order whose last payment failed opens ready to retry, with the reason', () async {
    final cubit = await ready(_ScriptedCheckout(loadStatus: OrderStatus.paymentFailed));
    expect(cubit.state.status, PaymentStatus.payFailed);
    await cubit.close();
  });
}
```

Append to `test/http_checkout_repository_test.dart` (inside `main`; add `import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';`):

```dart
  test('startPayment returns the hosted hand-off from /checkout (fake gateway, GET)', () async {
    h.adapter.on('POST', '/v1/orders/o1/checkout', (_) => FakeReply(200, fixture('checkout_fake.json')));
    final handoff = (await repo.startPayment(orderId: 'o1')).getOrElse((f) => throw StateError(f.message));
    expect(handoff.isFakeGateway, isTrue);
    expect(handoff.method, PaymentHandoffMethod.get);
    expect(handoff.amountCents, 3000);
    expect(handoff.fields['reference'], 'SC5E9B7C1A');
    expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
  });

  test('startPayment supports the Netcash form POST shape', () async {
    h.adapter.on('POST', '/v1/orders/o1/checkout', (_) => FakeReply(200, fixture('checkout_netcash.json')));
    final handoff = (await repo.startPayment(orderId: 'o1')).getOrElse((f) => throw StateError(f.message));
    expect(handoff.method, PaymentHandoffMethod.post);
    expect(handoff.url.host, 'paynow.netcash.co.za');
  });

  test('an order that can no longer be paid is a ValidationFailure', () async {
    h.adapter.on('POST', '/v1/orders/o1/checkout', (_) => FakeReply.problem(409, 'order_not_payable', detail: 'An order that is expired cannot be paid.'));
    final failure = (await repo.startPayment(orderId: 'o1')).match((f) => f, (_) => null);
    expect((failure! as ValidationFailure).code, 'order_not_payable');
  });
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/payment_urls_test.dart test/payment_polling_test.dart test/http_checkout_repository_test.dart`
Expected: FAIL (compile errors: `payment_handoff.dart`, `payment_urls.dart`, `startPayment`, `defaultPollDelays`).

- [ ] **Step 4: Hand-off entity and repository contract**

`lib/features/catalog_checkout/domain/entities/payment_handoff.dart`:

```dart
import 'package:equatable/equatable.dart';

enum PaymentHandoffMethod { get, post }

/// Where the customer pays (spec §4: hosted redirect; card data never
/// touches the app or the platform). GET = open [url] with [fields] as the
/// query; POST = submit [fields] as a form to [url].
class PaymentHandoff extends Equatable {
  const PaymentHandoff({
    required this.paymentId,
    required this.reference,
    required this.gateway,
    required this.method,
    required this.url,
    this.fields = const {},
    required this.amountCents,
  });

  /// Demo flavor: confirmed instantly, nothing to open.
  static const demoGateway = 'demo';

  /// The platform's fake gateway (local stack / tests).
  static const fakeGateway = 'fake';

  final String paymentId;
  final String reference;
  final String gateway;
  final PaymentHandoffMethod method;
  final Uri url;
  final Map<String, String> fields;
  final int amountCents;

  bool get isDemo => gateway == demoGateway;

  bool get isFakeGateway => gateway == fakeGateway;

  @override
  List<Object?> get props => [paymentId, reference, gateway, method, url, fields, amountCents];
}
```

In `checkout_repository.dart` replace the `pay` method (and its doc comment) with:

```dart
  /// Starts (or resumes) payment of an order that needs no further identity
  /// check and returns where the customer pays. Idempotent on the server:
  /// calling again returns the same open attempt. The order only becomes
  /// `paid` when the gateway's server-to-server notification arrives, so
  /// callers poll [getOrder] afterwards; the app never marks it paid.
  Future<Either<Failure, PaymentHandoff>> startPayment({required String orderId});
```

and import `payment_handoff.dart` (drop the `plan.dart` import if unused). In `plan.dart` delete the `PaymentMethod` enum and its `PaymentMethodLabel` extension.

- [ ] **Step 5: Mock and HTTP implementations**

`mock_checkout_repository.dart`: replace `pay(...)` with (import `payment_handoff.dart`):

```dart
  /// Demo gateway: the charge is confirmed instantly (still verify-before-
  /// charge, still idempotent), so the polling step finds the order paid.
  @override
  Future<Either<Failure, PaymentHandoff>> startPayment({required String orderId}) async {
    await Future<void>.delayed(_latency);
    if (_network.failure case final failure?) return Left(failure);
    final orders = await _load();
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return const Left(ServerFailure('We could not find that order.'));
    final order = orders[index];
    if (order.status == OrderStatus.pendingVerification) {
      return const Left(ValidationFailure('Verify your identity before paying.'));
    }
    if (failNextPayment) {
      failNextPayment = false;
      return const Left(ServerFailure('The payment was not completed. You have not been charged.'));
    }
    if (order.status != OrderStatus.paid) {
      orders[index] = order.copyWith(status: OrderStatus.paid);
      await _save(orders);
    }
    return Right(PaymentHandoff(
      paymentId: 'pay_${order.id}',
      reference: order.orderNumber,
      gateway: PaymentHandoff.demoGateway,
      method: PaymentHandoffMethod.get,
      url: Uri.parse('about:blank'),
      amountCents: order.totalCents,
    ));
  }
```

`http_checkout_repository.dart`: replace the transitional `pay(...)` with (import `payment_handoff.dart`; drop the `plan.dart` import if unused):

```dart
  @override
  Future<Either<Failure, PaymentHandoff>> startPayment({required String orderId}) => _api.post<PaymentHandoff>(
        '/v1/orders/${Uri.encodeComponent(orderId)}/checkout',
        timeout: const Duration(seconds: 30),
        decode: (data) => paymentHandoffFromJson(Map<String, Object?>.from(data! as Map)),
      );
```

and add at the bottom:

```dart
/// M1 `CheckoutOut` -> [PaymentHandoff].
PaymentHandoff paymentHandoffFromJson(Map<String, Object?> json) {
  final amount = json['amount']! as Map;
  if (amount['currency'] != 'ZAR') throw FormatException('Unsupported currency ${amount['currency']}');
  final method = switch (json['method']) {
    'GET' => PaymentHandoffMethod.get,
    'POST' => PaymentHandoffMethod.post,
    final other => throw FormatException('Unknown checkout method $other'),
  };
  return PaymentHandoff(
    paymentId: json['payment_id']! as String,
    reference: json['reference']! as String,
    gateway: json['gateway']! as String,
    method: method,
    url: Uri.parse(json['url']! as String),
    fields: Map<String, String>.from(json['fields']! as Map),
    amountCents: amount['amount_cents']! as int,
  );
}
```

`lib/features/catalog_checkout/data/dev_payment_simulator.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';

/// Debug builds against a local stack only (ruling R-M4-13): completes a
/// fake-gateway payment through `POST /v1/dev/payments/{id}/simulate`, an
/// endpoint the API never registers in production. Not part of the domain.
class DevPaymentSimulator {
  DevPaymentSimulator(this._api);

  final ApiClient _api;

  Future<Either<Failure, String>> simulate({required String paymentId, required bool accepted}) => _api.post<String>(
        '/v1/dev/payments/${Uri.encodeComponent(paymentId)}/simulate',
        body: {'outcome': accepted ? 'accepted' : 'declined'},
        decode: (data) => (data! as Map)['outcome']! as String,
      );
}
```

- [ ] **Step 6: URL rules, web view and the fake-gateway sheet**

`lib/features/catalog_checkout/presentation/payment/payment_urls.dart`:

```dart
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';

/// The platform's accept/decline/redirect URLs look like
/// `{web}/{tenant-slug}/checkout/{accepted|declined|return}`. Reaching one
/// only ends the hand-off; the order state always comes from the API.
final _returnPath = RegExp(r'^/[a-z0-9-]{2,40}/checkout/(accepted|declined|return)/?$');

bool isPaymentReturnUrl(Uri uri) => (uri.scheme == 'https' || uri.scheme == 'http') && _returnPath.hasMatch(uri.path);

/// The web view only ever navigates to https (and `about:blank`); local
/// cleartext only when [allowLocalHttp] (debug builds, local stack).
bool isAllowedPaymentUrl(Uri uri, {required bool allowLocalHttp}) {
  if (uri.scheme == 'https') return uri.host.isNotEmpty;
  if (uri.scheme == 'http') return allowLocalHttp && AppEnvironment.localDevHosts.contains(uri.host);
  return uri.scheme == 'about' && uri.path == 'blank';
}

Uri getHandoffUri(PaymentHandoff handoff) => handoff.fields.isEmpty
    ? handoff.url
    : handoff.url.replace(queryParameters: {...handoff.url.queryParameters, ...handoff.fields});

String formBody(Map<String, String> fields) =>
    fields.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
```

`lib/features/catalog_checkout/presentation/payment/payment_web_view_page.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_urls.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the gateway's payment page (ruling R-M4-3). Pops `true` when the
/// gateway sends the customer back to a return URL, `false` when closed.
/// Either way the caller polls the order: only the server-to-server
/// notification marks it paid. No JavaScript channels are exposed to the
/// page; cache, local storage and cookies are cleared on close.
class PaymentWebViewPage extends StatefulWidget {
  const PaymentWebViewPage({super.key, required this.handoff});

  final PaymentHandoff handoff;

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  var _progress = 0;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // gateway pages need JS
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onNavigationRequest: _onNavigation,
      ));
    final handoff = widget.handoff;
    if (!isAllowedPaymentUrl(handoff.url, allowLocalHttp: kDebugMode)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close(false));
      return;
    }
    if (handoff.method == PaymentHandoffMethod.post) {
      _controller.loadRequest(
        handoff.url,
        method: LoadRequestMethod.post,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: Uint8List.fromList(utf8.encode(formBody(handoff.fields))),
      );
    } else {
      _controller.loadRequest(getHandoffUri(handoff));
    }
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (isPaymentReturnUrl(uri)) {
      _close(true);
      return NavigationDecision.prevent;
    }
    return isAllowedPaymentUrl(uri, allowLocalHttp: kDebugMode) ? NavigationDecision.navigate : NavigationDecision.prevent;
  }

  void _close(bool returned) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(returned);
  }

  @override
  void dispose() {
    unawaited(_controller.clearCache());
    unawaited(_controller.clearLocalStorage());
    unawaited(WebViewCookieManager().clearCookies());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close payment', onPressed: () => _close(false)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Secure payment'),
            Text(widget.handoff.url.host, style: theme.textTheme.bodyMedium?.copyWith(color: theme.appBarTheme.foregroundColor)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
```

`lib/features/catalog_checkout/presentation/payment/fake_gateway_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';

/// Debug + local stack only (ruling R-M4-13). true = approve, false =
/// decline, null = dismissed.
Future<bool?> showFakeGatewaySheet(BuildContext context, PaymentHandoff handoff) => showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Test payment (local stack)', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('No money moves. This simulates the payment gateway for ${formatRands(handoff.amountCents)}.'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve test payment')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Decline test payment')),
            ],
          ),
        ),
      ),
    );
```

- [ ] **Step 7: Replace the PaymentCubit**

Replace `lib/features/catalog_checkout/presentation/bloc/payment_cubit.dart` with:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';

enum PaymentStatus {
  loading,

  /// Order not found / could not be loaded; see [PaymentState.failure].
  loadFailed,

  /// Identity has not been verified yet; the page sends the customer to RICA.
  needsVerification,
  ready,

  /// Asking the server for the hosted payment page.
  starting,

  /// The page must open [PaymentState.handoff], then call `handoffFinished`.
  handoff,

  /// Polling the order until the gateway's notification has been processed.
  confirming,

  /// No confirmation within the polling window; "Check again" is offered.
  stillPending,

  /// Declined / failed; the order is still payable, retrying is safe.
  payFailed,
  paid,

  /// Expired or cancelled: cannot be paid any more.
  closed,
}

/// About 52 s in total; the first check is immediate.
const defaultPollDelays = <Duration>[
  Duration.zero,
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 5),
  Duration(seconds: 8),
  Duration(seconds: 8),
  Duration(seconds: 10),
  Duration(seconds: 10),
];

class PaymentState extends Equatable {
  const PaymentState({this.status = PaymentStatus.loading, this.order, this.handoff, this.failure});

  final PaymentStatus status;
  final Order? order;
  final PaymentHandoff? handoff;
  final Failure? failure;

  PaymentState copyWith({PaymentStatus? status, Order? order, PaymentHandoff? handoff, Failure? failure}) => PaymentState(
        status: status ?? this.status,
        order: order ?? this.order,
        handoff: handoff ?? this.handoff,
        failure: failure,
      );

  @override
  List<Object?> get props => [status, order, handoff, failure];
}

/// Pay for an order: start the hosted payment, hand off to the gateway,
/// then poll the order (bounded) until the server says paid / failed. The
/// order comes from the repository by id, so this survives process death.
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(
    this._repository,
    this._cartCubit,
    this.orderId, {
    List<Duration> pollDelays = defaultPollDelays,
    Future<void> Function(Duration)? wait,
  })  : _pollDelays = pollDelays,
        _wait = wait ?? ((d) => Future<void>.delayed(d)),
        super(const PaymentState()) {
    load();
  }

  static const _declined = ValidationFailure('The payment was not completed. You have not been charged.', 'payment_failed');

  final CheckoutRepository _repository;
  final CartCubit _cartCubit;
  final String orderId;
  final List<Duration> _pollDelays;
  final Future<void> Function(Duration) _wait;

  Future<void> load() async {
    emit(state.copyWith(status: PaymentStatus.loading));
    final result = await _repository.getOrder(orderId);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: PaymentStatus.loadFailed, failure: failure)),
      (order) => emit(state.copyWith(
        status: _statusFor(order),
        order: order,
        failure: order.status == OrderStatus.paymentFailed ? _declined : null,
      )),
    );
  }

  PaymentStatus _statusFor(Order order) => switch (order.status) {
        OrderStatus.pendingVerification => PaymentStatus.needsVerification,
        OrderStatus.awaitingPayment => PaymentStatus.ready,
        OrderStatus.paymentFailed => PaymentStatus.payFailed,
        OrderStatus.paid => PaymentStatus.paid,
        OrderStatus.expired || OrderStatus.cancelled => PaymentStatus.closed,
      };

  Future<void> pay() async {
    if (const {PaymentStatus.starting, PaymentStatus.handoff, PaymentStatus.confirming}.contains(state.status)) return;
    emit(state.copyWith(status: PaymentStatus.starting));
    final result = await _repository.startPayment(orderId: orderId);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: PaymentStatus.payFailed, failure: failure)),
      (handoff) => emit(state.copyWith(status: PaymentStatus.handoff, handoff: handoff)),
    );
  }

  /// Called by the page once the gateway page is closed / returned.
  Future<void> handoffFinished() async {
    if (state.status != PaymentStatus.handoff) return;
    await _confirm();
  }

  Future<void> checkAgain() async {
    if (state.status != PaymentStatus.stillPending) return;
    await _confirm();
  }

  Future<void> _confirm() async {
    emit(state.copyWith(status: PaymentStatus.confirming));
    for (final delay in _pollDelays) {
      await _wait(delay);
      if (isClosed) return;
      final result = await _repository.getOrder(orderId);
      if (isClosed) return;
      final order = switch (result) {
        Right(value: final o) => o,
        Left() => null, // offline blip: keep waiting, bounded by the schedule
      };
      if (order == null) continue;
      switch (order.status) {
        case OrderStatus.paid:
          _cartCubit.clear();
          emit(state.copyWith(status: PaymentStatus.paid, order: order));
          return;
        case OrderStatus.paymentFailed:
          emit(state.copyWith(status: PaymentStatus.payFailed, order: order, failure: _declined));
          return;
        case OrderStatus.expired || OrderStatus.cancelled:
          emit(state.copyWith(status: PaymentStatus.closed, order: order));
          return;
        case OrderStatus.pendingVerification || OrderStatus.awaitingPayment:
          break;
      }
    }
    emit(state.copyWith(status: PaymentStatus.stillPending));
  }
}
```

- [ ] **Step 8: Replace the payment page**

Replace `lib/features/catalog_checkout/presentation/pages/payment_page.dart` with:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/dev_payment_simulator.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/fake_gateway_sheet.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_web_view_page.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Pay for an order on the gateway's hosted page, then wait for the server
/// to confirm. Reached from checkout, RICA success or the dashboard banner.
class PaymentPage extends StatelessWidget {
  const PaymentPage({
    super.key,
    required this.onPaid,
    required this.onNeedsVerification,
    required this.onClosed,
    this.showIdentityVerified = true,
    this.devSimulator,
  });

  final void Function(Order order) onPaid;
  final void Function(Order order) onNeedsVerification;
  final VoidCallback onClosed;

  /// "Identity verified" header (only when the RICA flag is on).
  final bool showIdentityVerified;

  /// Local stack + debug only (ruling R-M4-13).
  final DevPaymentSimulator? devSimulator;

  Future<void> _handOff(BuildContext context, PaymentHandoff handoff) async {
    final cubit = context.read<PaymentCubit>();
    if (handoff.isDemo) {
      await cubit.handoffFinished();
      return;
    }
    final simulator = devSimulator;
    if (handoff.isFakeGateway && kDebugMode && simulator != null) {
      final approve = await showFakeGatewaySheet(context, handoff);
      if (approve != null) await simulator.simulate(paymentId: handoff.paymentId, accepted: approve);
      await cubit.handoffFinished();
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => PaymentWebViewPage(handoff: handoff)),
    );
    await cubit.handoffFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: BlocConsumer<PaymentCubit, PaymentState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          final order = state.order;
          if (state.status == PaymentStatus.handoff && state.handoff != null) _handOff(context, state.handoff!);
          if (order == null) return;
          if (state.status == PaymentStatus.paid) onPaid(order);
          if (state.status == PaymentStatus.needsVerification) onNeedsVerification(order);
        },
        builder: (context, state) {
          final cubit = context.read<PaymentCubit>();
          final theme = Theme.of(context);
          switch (state.status) {
            case PaymentStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case PaymentStatus.loadFailed:
              return FailureView(failure: state.failure, onRetry: cubit.load);
            case PaymentStatus.closed:
              return _Message(
                text: 'This order can no longer be paid. You have not been charged.',
                action: ElevatedButton(onPressed: onClosed, child: const Text('Back to dashboard')),
              );
            case PaymentStatus.confirming:
              return const _Message(
                text: 'Confirming your payment. This can take a minute; your order is saved if you leave this screen.',
                action: CircularProgressIndicator(),
              );
            case PaymentStatus.stillPending:
              return _Message(
                text: 'We have not received confirmation from the payment provider yet. '
                    'If you completed the payment, check again in a moment.',
                action: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(onPressed: cubit.checkAgain, child: const Text('Check again')),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: cubit.pay, child: const Text('Pay again')),
                  ],
                ),
              );
            default:
              break;
          }
          final order = state.order;
          if (order == null) return const SizedBox.shrink();
          final busy = state.status == PaymentStatus.starting || state.status == PaymentStatus.handoff;
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OrderCard(order: order, showIdentityVerified: showIdentityVerified),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.payments_outlined, size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Card, Instant EFT, PayShap and more: you choose on the secure payment page.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        if (state.status == PaymentStatus.payFailed) ...[
                          const SizedBox(height: 16),
                          FailureView(failure: state.failure, compact: true, onRetry: cubit.pay),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'You pay on the provider\'s secure page. We never see or store your card details.',
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: busy ? null : cubit.pay,
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text('Pay ${formatRands(order.totalCents)} securely'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action});

  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              Center(child: action),
            ],
          ),
        ),
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.showIdentityVerified});

  final Order order;
  final bool showIdentityVerified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (showIdentityVerified) ...[
                const Icon(Icons.verified, size: 18, color: Color(0xFF6F9126)),
                const SizedBox(width: 8),
                Expanded(child: Text('Identity verified', style: theme.textTheme.bodyMedium)),
              ] else
                const Spacer(),
              Text('#${order.orderNumber}', style: theme.textTheme.bodyMedium),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(order.planName, style: theme.textTheme.titleMedium)),
              Text(formatRands(order.totalCents), style: theme.textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 9: Route and locator**

`app_router.dart`, payment route child (imports: `package:flutter/foundation.dart`, `dev_payment_simulator.dart`):

```dart
            child: PaymentPage(
              showIdentityVerified: tenantCubit?.state.featureFlags.rica ?? true,
              devSimulator: kDebugMode && locator.isRegistered<DevPaymentSimulator>() ? locator<DevPaymentSimulator>() : null,
              onPaid: (order) => context.go(AppRoutes.confirmationFor(order.id)),
              onNeedsVerification: (order) => context.push(AppRoutes.ricaFor(order.id)),
              onClosed: () => context.go(AppRoutes.main),
            ),
```

`locator.dart`, end of `_registerProdRepositories` (imports: `package:flutter/foundation.dart`, `dev_payment_simulator.dart`):

```dart
  // The dev simulate endpoint only exists on non-production APIs; the app
  // offers it only in debug builds (ruling R-M4-13).
  if (kDebugMode) locator.registerLazySingleton<DevPaymentSimulator>(() => DevPaymentSimulator(locator()));
```

- [ ] **Step 10: Update the existing tests**

`test/checkout_repository_test.dart` (mock): replace the three payment tests with:

```dart
  test('payment is refused until identity is verified (verify-before-charge)', () async {
    final order = unwrap(await repo.createOrder(items: _items));
    expect((await repo.startPayment(orderId: order.id)).isLeft(), isTrue);
    expect(unwrap(await repo.getOrder(order.id)).status, OrderStatus.pendingVerification);
  });

  test('verify then startPayment confirms the order (demo gateway); starting again does not charge twice', () async {
    final order = unwrap(await repo.createOrder(items: _items));
    await repo.markIdentityVerified(order.id);
    final handoff = (await repo.startPayment(orderId: order.id)).getOrElse((_) => throw StateError('start'));
    expect(handoff.isDemo, isTrue);
    expect(handoff.amountCents, order.totalCents);
    expect(unwrap(await repo.getOrder(order.id)).status, OrderStatus.paid);
    expect((await repo.startPayment(orderId: order.id)).isRight(), isTrue);
    expect((await repo.getOpenOrder()).getOrElse((_) => null), isNull);
  });

  test('a declined payment leaves the order awaitingPayment so it can be retried', () async {
    final order = unwrap(await repo.createOrder(items: _items));
    await repo.markIdentityVerified(order.id);
    repo.failNextPayment = true;
    expect((await repo.startPayment(orderId: order.id)).isLeft(), isTrue);
    expect(unwrap(await repo.getOrder(order.id)).status, OrderStatus.awaitingPayment);
    expect((await repo.startPayment(orderId: order.id)).isRight(), isTrue);
    expect(unwrap(await repo.getOrder(order.id)).status, OrderStatus.paid);
  });
```

`test/order_flow_cubits_test.dart`:
- In "decline -> retry -> paid clears the cart only on success", replace the second `await payment.pay();` with:

```dart
      await payment.pay();
      expect(payment.state.status, PaymentStatus.handoff);
      await payment.handoffFinished();
```

- In `_KeyRecordingCheckout`, replace the `pay` override with:

```dart
  @override
  Future<Either<Failure, PaymentHandoff>> startPayment({required String orderId}) => _inner.startPayment(orderId: orderId);
```

  (import `payment_handoff.dart`).

Run: `git grep -n -E "PaymentMethod|\.pay\(orderId" -- lib test`
Expected: no matches.

- [ ] **Step 11: Run the tests**

Run: `flutter test test/payment_urls_test.dart test/payment_polling_test.dart test/http_checkout_repository_test.dart test/checkout_repository_test.dart test/order_flow_cubits_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS (`flow_test` still taps "Pay R..." and reaches the confirmation: the demo hand-off is confirmed instantly and the first poll finds the order paid).

- [ ] **Step 12: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 13: Commit**

```powershell
git add pubspec.yaml pubspec.lock lib/features/catalog_checkout/domain/entities/payment_handoff.dart lib/features/catalog_checkout/domain/entities/plan.dart lib/features/catalog_checkout/domain/repositories/checkout_repository.dart
git add lib/features/catalog_checkout/data/dev_payment_simulator.dart lib/features/catalog_checkout/data/repositories/mock_checkout_repository.dart lib/features/catalog_checkout/data/repositories/http_checkout_repository.dart
git add lib/features/catalog_checkout/presentation/payment lib/features/catalog_checkout/presentation/bloc/payment_cubit.dart lib/features/catalog_checkout/presentation/pages/payment_page.dart lib/app/router/app_router.dart lib/app/locator.dart
git add test/fixtures/api/checkout_fake.json test/fixtures/api/checkout_netcash.json test/payment_urls_test.dart test/payment_polling_test.dart test/http_checkout_repository_test.dart test/checkout_repository_test.dart test/order_flow_cubits_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(payments): hosted payment hand-off in a locked-down web view with bounded order polling"
```

---

### Task 11: "My passes" (entitlements) and the CPE flag on the dashboard

**Files:**
- Create: `lib/features/passes/domain/entities/pass.dart`, `lib/features/passes/domain/repositories/passes_repository.dart`, `lib/features/passes/data/repositories/mock_passes_repository.dart`, `lib/features/passes/data/repositories/http_passes_repository.dart`, `lib/features/passes/presentation/bloc/passes_cubit.dart`, `lib/features/passes/presentation/pages/my_passes_page.dart`, `test/fixtures/api/entitlements_page.json`
- Modify: `lib/app/locator.dart`, `lib/app/router/app_router.dart`, `lib/app/main_shell.dart`, `lib/features/account_dashboard/presentation/pages/dashboard_page.dart`, `lib/features/catalog_checkout/presentation/pages/confirmation_page.dart`, `lib/l10n/app_en.arb` (+ generated)
- Test: `test/passes_test.dart`

**Interfaces:**
- Consumes: `ApiClient` (Task 3); `SimulatedNetwork` (existing); `TenantCubit.state.featureFlags.cpe` (Task 5); `FailureView` (existing).
- Produces:
  - `enum PassStatus { scheduled, active, expired, exhausted, revoked }`; `class Pass { String id, orderId, productName; PassStatus status; DateTime startsAt, expiresAt; int durationMinutes; int? dataMb; int? speedKbps; int maxDevices; int usedBytes; bool get isCurrent; double? get dataUsedFraction; }`; `Pass passFromJson(Map<String, Object?> json)`.
  - `abstract class PassesRepository { Future<Either<Failure, List<Pass>>> getPasses({bool includeExpired = false}); }`; `MockPassesRepository({DateTime Function()? now, SimulatedNetwork? network})`; `HttpPassesRepository(ApiClient api)`.
  - `enum PassesStatus { loading, loaded, failure }`; `PassesState { status, passes, includeExpired, failure }`; `PassesCubit(PassesRepository repository)` with `load()`, `setIncludeExpired(bool)`.
  - `MyPassesPage`; `AppRoutes.passes = '/passes'`; `MainShell({..., VoidCallback? onOpenPasses, bool showRouterCard = true})`; `DashboardPage({..., VoidCallback? onOpenPasses, bool showRouterCard = true})`; `ConfirmationPage({..., VoidCallback? onViewPasses})`.
  - l10n keys: `passesTitle`, `passesEmpty`, `passesShowExpired`, `passesStatusActive`, `passesStatusScheduled`, `passesStatusExpired`, `passesStatusExhausted`, `passesStatusRevoked`, `passesExpires` (`{date}`), `passesStarts` (`{date}`), `passesDevices` (`{count}` int), `dashboardMyPasses`, `confirmationViewPasses`.

- [ ] **Step 1: Fixture**

`test/fixtures/api/entitlements_page.json` (M1 `Page[EntitlementOut]`):

```json
{
  "items": [
    {"id": "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e01", "order_id": "5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f10", "product_id": "0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a01", "product_name": "1 Hour Pass", "status": "active", "starts_at": "2026-10-01T10:05:00Z", "expires_at": "2026-10-01T11:05:00Z", "duration_minutes": 60, "data_mb": 1024, "speed_kbps": 10240, "max_devices": 1, "used_seconds": 600, "used_bytes": 268435456},
    {"id": "c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e02", "order_id": "5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f10", "product_id": "0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a01", "product_name": "1 Hour Pass", "status": "scheduled", "starts_at": "2026-10-01T11:05:00Z", "expires_at": "2026-10-01T12:05:00Z", "duration_minutes": 60, "data_mb": 1024, "speed_kbps": 10240, "max_devices": 1, "used_seconds": 0, "used_bytes": 0}
  ],
  "next_cursor": null
}
```

- [ ] **Step 2: Write the failing tests**

`test/passes_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/http_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/mock_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/presentation/pages/my_passes_page.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

void main() {
  group('HttpPassesRepository', () {
    late ApiHarness h;

    setUp(() async {
      h = ApiHarness();
      await h.signIn();
    });

    test('loads current entitlements for the signed-in customer', () async {
      h.adapter.on('GET', '/v1/me/entitlements', (_) => FakeReply(200, fixture('entitlements_page.json')));
      final passes = (await HttpPassesRepository(h.api).getPasses()).getOrElse((f) => throw StateError(f.message));
      expect(passes, hasLength(2));
      expect(passes.first.status, PassStatus.active);
      expect(passes.first.isCurrent, isTrue);
      expect(passes.first.dataUsedFraction, closeTo(0.25, 0.0001));
      expect(passes.first.expiresAt, DateTime.utc(2026, 10, 1, 11, 5));
      expect(h.adapter.requests.single.uri.queryParameters['status'], 'current');
      expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('"show expired" asks for all entitlements', () async {
      h.adapter.on('GET', '/v1/me/entitlements', (_) => const FakeReply(200, {'items': <Object>[], 'next_cursor': null}));
      await HttpPassesRepository(h.api).getPasses(includeExpired: true);
      expect(h.adapter.requests.single.uri.queryParameters['status'], 'all');
    });

    test('an unknown status is refused rather than shown as valid', () {
      final item = Map<String, Object?>.from((fixtureMap('entitlements_page.json')['items']! as List).first as Map)..['status'] = 'paused';
      expect(() => passFromJson(item), throwsFormatException);
    });
  });

  group('PassesCubit', () {
    test('offline shows a retryable failure, then loads', () async {
      final network = SimulatedNetwork()..offline = true;
      final cubit = PassesCubit(MockPassesRepository(network: network));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, PassesStatus.failure);
      expect(cubit.state.failure, isA<NetworkFailure>());
      network.offline = false;
      await cubit.load();
      expect(cubit.state.status, PassesStatus.loaded);
      expect(cubit.state.passes, isNotEmpty);
      await cubit.close();
    });

    test('showing expired passes reloads with them included', () async {
      final cubit = PassesCubit(MockPassesRepository());
      await Future<void>.delayed(Duration.zero);
      final current = cubit.state.passes.length;
      await cubit.setIncludeExpired(true);
      expect(cubit.state.includeExpired, isTrue);
      expect(cubit.state.passes.length, greaterThan(current));
      await cubit.close();
    });
  });

  testWidgets('My passes lists each pass with its status and expiry', (tester) async {
    final cubit = PassesCubit(MockPassesRepository(now: () => DateTime.utc(2026, 10, 1, 12)));
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(home: BlocProvider.value(value: cubit, child: const MyPassesPage())));
    await tester.pumpAndSettle();
    expect(find.text('My passes'), findsOneWidget);
    expect(find.text('Day Pass'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('Expires'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/passes_test.dart`
Expected: FAIL (compile errors: the passes feature does not exist).

- [ ] **Step 4: Domain and data**

`lib/features/passes/domain/entities/pass.dart`:

```dart
import 'package:equatable/equatable.dart';

enum PassStatus { scheduled, active, expired, exhausted, revoked }

/// A hotspot entitlement bought with a pass (`GET /v1/me/entitlements`).
/// The server owns time, usage and status (spec §2).
class Pass extends Equatable {
  const Pass({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.durationMinutes,
    this.dataMb,
    this.speedKbps,
    required this.maxDevices,
    this.usedBytes = 0,
  });

  final String id;
  final String orderId;
  final String productName;
  final PassStatus status;
  final DateTime startsAt;
  final DateTime expiresAt;
  final int durationMinutes;
  final int? dataMb;
  final int? speedKbps;
  final int maxDevices;
  final int usedBytes;

  bool get isCurrent => status == PassStatus.active || status == PassStatus.scheduled;

  /// 0..1 of the data cap used, or null for uncapped passes.
  double? get dataUsedFraction {
    final cap = dataMb;
    if (cap == null || cap == 0) return null;
    return (usedBytes / (cap * 1024 * 1024)).clamp(0, 1).toDouble();
  }

  @override
  List<Object?> get props => [id, orderId, productName, status, startsAt, expiresAt, durationMinutes, dataMb, speedKbps, maxDevices, usedBytes];
}

/// M1 `EntitlementOut` -> [Pass].
Pass passFromJson(Map<String, Object?> json) {
  final status = PassStatus.values.where((s) => s.name == json['status']).firstOrNull;
  if (status == null) throw FormatException('Unknown entitlement status ${json['status']}');
  return Pass(
    id: json['id']! as String,
    orderId: json['order_id']! as String,
    productName: json['product_name']! as String,
    status: status,
    startsAt: DateTime.parse(json['starts_at']! as String).toUtc(),
    expiresAt: DateTime.parse(json['expires_at']! as String).toUtc(),
    durationMinutes: json['duration_minutes']! as int,
    dataMb: json['data_mb'] as int?,
    speedKbps: json['speed_kbps'] as int?,
    maxDevices: json['max_devices']! as int,
    usedBytes: json['used_bytes'] as int? ?? 0,
  );
}
```

`lib/features/passes/domain/repositories/passes_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

abstract class PassesRepository {
  /// Current (active + scheduled) passes, or all of them with [includeExpired].
  Future<Either<Failure, List<Pass>>> getPasses({bool includeExpired = false});
}
```

`lib/features/passes/data/repositories/mock_passes_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';

/// Demo flavor: one active Day Pass and, when asked, one expired pass.
class MockPassesRepository implements PassesRepository {
  MockPassesRepository({DateTime Function()? now, SimulatedNetwork? network})
      : _now = now ?? DateTime.now,
        _network = network ?? SimulatedNetwork();

  final DateTime Function() _now;
  final SimulatedNetwork _network;

  @override
  Future<Either<Failure, List<Pass>>> getPasses({bool includeExpired = false}) async {
    if (_network.failure case final failure?) return Left(failure);
    final now = _now().toUtc();
    final active = Pass(
      id: 'pass_demo_1',
      orderId: 'ord_demo_1',
      productName: 'Day Pass',
      status: PassStatus.active,
      startsAt: now.subtract(const Duration(hours: 2)),
      expiresAt: now.add(const Duration(hours: 22)),
      durationMinutes: 1440,
      dataMb: 5120,
      speedKbps: 10240,
      maxDevices: 2,
      usedBytes: 1288490188,
    );
    final expired = Pass(
      id: 'pass_demo_0',
      orderId: 'ord_demo_0',
      productName: '1 Hour Pass',
      status: PassStatus.expired,
      startsAt: now.subtract(const Duration(days: 3)),
      expiresAt: now.subtract(const Duration(days: 3)).add(const Duration(hours: 1)),
      durationMinutes: 60,
      dataMb: 1024,
      speedKbps: 10240,
      maxDevices: 1,
    );
    return Right(includeExpired ? [active, expired] : [active]);
  }
}
```

`lib/features/passes/data/repositories/http_passes_repository.dart`:

```dart
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';

class HttpPassesRepository implements PassesRepository {
  HttpPassesRepository(this._api);

  static const maxPages = 10;

  final ApiClient _api;

  @override
  Future<Either<Failure, List<Pass>>> getPasses({bool includeExpired = false}) async {
    final passes = <Pass>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final result = await _api.get<(List<Pass>, String?)>(
        '/v1/me/entitlements',
        query: {'status': includeExpired ? 'all' : 'current', 'limit': 50, 'cursor': ?cursor},
        decode: (data) {
          final map = data! as Map;
          return (
            [for (final item in map['items']! as List) passFromJson(Map<String, Object?>.from(item as Map))],
            map['next_cursor'] as String?,
          );
        },
      );
      switch (result) {
        case Left(value: final failure):
          return Left(failure);
        case Right(value: (final items, final next)):
          passes.addAll(items);
          cursor = next;
      }
      if (cursor == null) break;
    }
    return Right(passes);
  }
}
```

- [ ] **Step 5: Cubit, page and strings**

Add to `lib/l10n/app_en.arb`:

```json
  "passesTitle": "My passes",
  "passesEmpty": "You have no active passes. Buy one in Shop.",
  "passesShowExpired": "Show expired passes",
  "passesStatusActive": "Active",
  "passesStatusScheduled": "Starts later",
  "passesStatusExpired": "Expired",
  "passesStatusExhausted": "Used up",
  "passesStatusRevoked": "Cancelled",
  "passesExpires": "Expires {date}",
  "@passesExpires": {"placeholders": {"date": {"type": "String"}}},
  "passesStarts": "Starts {date}",
  "@passesStarts": {"placeholders": {"date": {"type": "String"}}},
  "passesDevices": "Up to {count} devices",
  "@passesDevices": {"placeholders": {"count": {"type": "int"}}},
  "dashboardMyPasses": "My passes",
  "confirmationViewPasses": "View my passes"
```

Run: `flutter gen-l10n`

`lib/features/passes/presentation/bloc/passes_cubit.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';

enum PassesStatus { loading, loaded, failure }

class PassesState extends Equatable {
  const PassesState({this.status = PassesStatus.loading, this.passes = const [], this.includeExpired = false, this.failure});

  final PassesStatus status;
  final List<Pass> passes;
  final bool includeExpired;
  final Failure? failure;

  PassesState copyWith({PassesStatus? status, List<Pass>? passes, bool? includeExpired, Failure? failure}) => PassesState(
        status: status ?? this.status,
        passes: passes ?? this.passes,
        includeExpired: includeExpired ?? this.includeExpired,
        failure: failure,
      );

  @override
  List<Object?> get props => [status, passes, includeExpired, failure];
}

class PassesCubit extends Cubit<PassesState> {
  PassesCubit(this._repository) : super(const PassesState()) {
    load();
  }

  final PassesRepository _repository;

  /// Also the retry entry point.
  Future<void> load() async {
    emit(state.copyWith(status: PassesStatus.loading));
    final result = await _repository.getPasses(includeExpired: state.includeExpired);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: PassesStatus.failure, failure: failure)),
      (passes) => emit(state.copyWith(status: PassesStatus.loaded, passes: passes)),
    );
  }

  Future<void> setIncludeExpired(bool value) async {
    emit(state.copyWith(includeExpired: value));
    await load();
  }
}
```

`lib/features/passes/presentation/pages/my_passes_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

class MyPassesPage extends StatelessWidget {
  const MyPassesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.passesTitle)),
      body: BlocBuilder<PassesCubit, PassesState>(
        builder: (context, state) {
          final cubit = context.read<PassesCubit>();
          if (state.status == PassesStatus.loading) return const Center(child: CircularProgressIndicator());
          if (state.status == PassesStatus.failure) return FailureView(failure: state.failure, onRetry: cubit.load);
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.passesShowExpired),
                  value: state.includeExpired,
                  onChanged: cubit.setIncludeExpired,
                ),
                if (state.passes.isEmpty)
                  Padding(padding: const EdgeInsets.only(top: 24), child: Text(l10n.passesEmpty, textAlign: TextAlign.center))
                else
                  for (final pass in state.passes) ...[_PassCard(pass: pass), const SizedBox(height: 12)],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  const _PassCard({required this.pass});

  final Pass pass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final format = DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm();
    final status = switch (pass.status) {
      PassStatus.active => l10n.passesStatusActive,
      PassStatus.scheduled => l10n.passesStatusScheduled,
      PassStatus.expired => l10n.passesStatusExpired,
      PassStatus.exhausted => l10n.passesStatusExhausted,
      PassStatus.revoked => l10n.passesStatusRevoked,
    };
    final fraction = pass.dataUsedFraction;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(pass.productName, style: theme.textTheme.titleMedium)),
                Chip(label: Text(status), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              pass.status == PassStatus.scheduled
                  ? l10n.passesStarts(format.format(pass.startsAt.toLocal()))
                  : l10n.passesExpires(format.format(pass.expiresAt.toLocal())),
              style: theme.textTheme.bodyMedium,
            ),
            Text(l10n.passesDevices(pass.maxDevices), style: theme.textTheme.bodyMedium),
            if (fraction != null && pass.isCurrent) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: fraction),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Routes, dashboard entry and locator**

`app_router.dart`: add `static const passes = '/passes';` to `AppRoutes`, the route (imports: `passes_cubit.dart`, `my_passes_page.dart`):

```dart
      GoRoute(
        path: AppRoutes.passes,
        builder: (context, state) => BlocProvider(create: (_) => PassesCubit(locator()), child: const MyPassesPage()),
      ),
```

add to the `MainShell(...)` arguments:

```dart
          onOpenPasses: () => context.push(AppRoutes.passes),
          showRouterCard: tenantCubit?.state.featureFlags.cpe ?? true,
```

and to the `ConfirmationPage(...)` arguments: `onViewPasses: () => context.go(AppRoutes.passes),`.

`main_shell.dart`: add `this.onOpenPasses, this.showRouterCard = true` with fields `final VoidCallback? onOpenPasses;` and `final bool showRouterCard;`, and pass `onOpenPasses: widget.onOpenPasses, showRouterCard: widget.showRouterCard,` to `DashboardPage`.

`dashboard_page.dart`: add the same two constructor params/fields to `DashboardPage`; directly after the `BlocBuilder<OpenOrderCubit, Order?>` entry insert:

```dart
              if (onOpenPasses case final openPasses?) ...[
                Card(
                  child: ListTile(
                    minTileHeight: 56,
                    leading: const Icon(Icons.wifi_tethering),
                    title: Text(context.l10n.dashboardMyPasses),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: openPasses,
                  ),
                ),
                const SizedBox(height: 16),
              ],
```

and replace `_CpeCard(summary: summary), const SizedBox(height: 16),` with:

```dart
              // Router telemetry needs the CPE/ACS integration (flag `cpe`, off at launch).
              if (showRouterCard) ...[
                _CpeCard(summary: summary),
                const SizedBox(height: 16),
              ],
```

(import `package:sentech_connect_app/l10n/l10n.dart` if missing).

`confirmation_page.dart`: add `this.onViewPasses` / `final VoidCallback? onViewPasses;` to `ConfirmationPage`, pass it to `_ConfirmationView`, and above the existing "Back to dashboard" button in `_ConfirmationView` insert:

```dart
              if (onViewPasses case final viewPasses?) ...[
                OutlinedButton(onPressed: viewPasses, child: Text(context.l10n.confirmationViewPasses)),
                const SizedBox(height: 10),
              ],
```

`locator.dart`: in `_registerDemoRepositories` add `locator.registerLazySingleton<PassesRepository>(() => MockPassesRepository(network: locator()));`; in `_registerProdRepositories` add `locator.registerLazySingleton<PassesRepository>(() => HttpPassesRepository(locator()));` (imports for the three classes).

- [ ] **Step 7: Run the tests**

Run: `flutter test test/passes_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS (demo flags keep the router card; `flow_test` still finds "Back to dashboard" on the confirmation screen).

- [ ] **Step 8: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```powershell
git add lib/features/passes lib/app/locator.dart lib/app/router/app_router.dart lib/app/main_shell.dart lib/features/account_dashboard/presentation/pages/dashboard_page.dart lib/features/catalog_checkout/presentation/pages/confirmation_page.dart
git add lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zu.dart lib/l10n/app_localizations_af.dart
git add test/fixtures/api/entitlements_page.json test/passes_test.dart
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "feat(passes): My passes from /v1/me/entitlements; router card behind the cpe flag"
```

---

### Task 12: Opt-in live integration test and README for the local stack

**Files:**
- Create: `test/integration/live_api_flow_test.dart`, `dart_test.yaml`
- Modify: `README.md`, `docs/app-review.md`
- Test: `test/integration/live_api_flow_test.dart` (skipped unless `INTEGRATION_API_BASE_URL` and `INTEGRATION_PLATFORM_DIR` are set)

**Interfaces:**
- Consumes: `ApiClient`, `SecureTokenStore`, `TenantContext`, `SessionEvents`, `newIdempotencyKey` (Task 3); `HttpTenantRepository` (Task 4); `HttpAuthRepository` (Task 6); `HttpCatalogRepository`, `HttpCheckoutRepository` (Tasks 9-10); `DevPaymentSimulator` (Task 10); `HttpPassesRepository` (Task 11); `stillMockInProd` (Task 4).
- Produces: the documented way to run the app and the live test against the platform's local compose stack (Caddy on `127.0.0.1:8088`, fake SMS in `sms_outbox`, fake payment gateway).

- [ ] **Step 1: Write the integration test**

`dart_test.yaml`:

```yaml
tags:
  integration:
    description: Talks to a running platform stack; skipped unless INTEGRATION_API_BASE_URL is set.
```

`test/integration/live_api_flow_test.dart`:

```dart
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
import 'package:sentech_connect_app/features/tenant/data/repositories/http_tenant_repository.dart';

/// OTP -> order -> fake-gateway payment -> entitlement against the
/// platform's local compose stack. Needs:
///   INTEGRATION_API_BASE_URL  e.g. http://127.0.0.1:8088 (Caddy)
///   INTEGRATION_PLATFORM_DIR  the sentech_connect_platform checkout (to read
///                             the fake SMS from Postgres via docker compose)
/// and the dev seed: `python -m sentech_api.devseed sentech` in the api container.
final _baseUrl = Platform.environment['INTEGRATION_API_BASE_URL'];
final _platformDir = Platform.environment['INTEGRATION_PLATFORM_DIR'];
final String? _skip = _baseUrl == null || _platformDir == null
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

    final plans = _ok<List<dynamic>>(await HttpCatalogRepository(api, tenant).getProducts(), 'catalogue');
    expect(plans, isNotEmpty, reason: 'run the dev seed: python -m sentech_api.devseed sentech');

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
```

(`_ok` keeps the test readable across the different `Either` types; a failing step names itself in the error.)

- [ ] **Step 2: Run it without a stack (must skip, not fail)**

Run: `flutter test test/integration/live_api_flow_test.dart`
Expected: `+0 ~1: All tests skipped.` (or equivalent "skipped" output), exit code 0.

- [ ] **Step 3: Run it against the local stack (only if the platform stack is up)**

From the platform repo (Git Bash): `scripts/dev-up.sh && docker compose --env-file .env -f infra/docker-compose.yml -f infra/docker-compose.observability.yml -f infra/docker-compose.dev.yml exec -T api python -m sentech_api.devseed sentech`. Then, from this repo in PowerShell:

```powershell
$env:INTEGRATION_API_BASE_URL = "http://127.0.0.1:8088"
$env:INTEGRATION_PLATFORM_DIR = "C:\Users\Wille\Downloads\applications\sentech_connect_platform"
flutter test test/integration/live_api_flow_test.dart
```

Expected: PASS. If the stack is not running (or M1 is not built yet), skip this step and record "live integration not run: <reason>" in the SDD ledger; it is not a gate for this task.

- [ ] **Step 4: Update the README**

In `README.md`:
- Replace the "## What phase this is" paragraph with:

```markdown
## What phase this is

The app has two flavors (`--dart-define=APP_FLAVOR`):

- **`demo`** (default): every repository is a mock; works fully offline. All tests run in this flavor.
- **`prod`**: tenants, sign-in (SMS one-time code), catalogue (hotspot passes), orders, payment hand-off, "My passes", profile, consents, data export and account deletion use the Sentech Connect platform API (`--dart-define=API_BASE_URL=...`, https required).

Still mock in **both** flavors because the platform has no API for them yet (listed in `stillMockInProd`, `lib/app/locator.dart`): coverage, free Wi-Fi, hotspot map, voucher redemption, account usage/router summary, promotions, support and RICA liveness. A prod build shows their demo data.
```

- Add a new section after "## Quick start":

```markdown
## Running against the local platform stack

1. Start the platform stack (in `sentech_connect_platform`, Git Bash): `scripts/dev-up.sh`, then seed passes: `docker compose --env-file .env -f infra/docker-compose.yml -f infra/docker-compose.observability.yml -f infra/docker-compose.dev.yml exec -T api python -m sentech_api.devseed sentech`. Caddy listens on `127.0.0.1:8088`.
2. Run the app in the prod flavor (debug build):
   - Android emulator: `flutter run --dart-define=APP_FLAVOR=prod --dart-define=API_BASE_URL=http://10.0.2.2:8088` (`10.0.2.2` is the emulator's alias for the host).
   - Desktop/web: `flutter run --dart-define=APP_FLAVOR=prod --dart-define=API_BASE_URL=http://127.0.0.1:8088`.
   - Physical device over USB: `adb reverse tcp:8088 tcp:8088`, then use `http://127.0.0.1:8088`.
   Cleartext HTTP works **only in debug builds and only to localhost, 127.0.0.1 or 10.0.2.2** (`android/app/src/debug/res/xml/network_security_config.xml` plus the check in `AppEnvironment`); any other `http://` URL, or any `http://` in a release build, stops the app at startup. Use `https://` for every real environment.
3. Sign in with any South African mobile number. The fake SMS provider writes the code to Postgres: `docker compose ... exec -T postgres psql -U sentech -d sentech -tAc "SELECT body FROM sms_outbox ORDER BY created_at DESC LIMIT 1"`.
4. Buy a pass. The local stack uses the platform's fake payment gateway: debug builds show an "Approve / Decline test payment" sheet that calls the dev-only `POST /v1/dev/payments/{id}/simulate`. With a real gateway (Netcash) the payment page opens in a locked-down web view and the app polls the order until the gateway's server-to-server notification marks it paid.

Live integration test (skipped unless both variables are set; not part of the normal `flutter test` gate):

```powershell
$env:INTEGRATION_API_BASE_URL = "http://127.0.0.1:8088"
$env:INTEGRATION_PLATFORM_DIR = "C:\Users\Wille\Downloads\applications\sentech_connect_platform"
flutter test test/integration/live_api_flow_test.dart
```
```

- In "### Security and privacy notes" replace the logout sentence with: "Logout revokes the session on the server, forgets the tokens and the biometric unlock, and wipes registration details, local orders, the free-WiFi grant and the in-memory cart; account deletion (`DELETE /v1/me`) wipes everything. On a cold start with a stored session and an enrolled biometric the app starts locked and \"Use biometrics\" unlocks it. Switching provider (Account > Change provider) signs the customer out first."
- In the "Build configuration and owner decisions" table, replace the "Free WiFi / vouchers / orders / account deletion" row with:

```markdown
| **Platform API** | `--dart-define=APP_FLAVOR=prod --dart-define=API_BASE_URL=https://…`; tenants, OTP sign-in, passes, orders, payments, entitlements, profile/consents/export/delete. | Production API hostname (then certificate pinning with a backup pin), SMS provider, Netcash merchant account per tenant |
| **Still mock** | Coverage, free Wi-Fi, hotspots, vouchers, usage/router, promotions, support, RICA liveness (`stillMockInProd`). | Backend APIs for each |
```

- [ ] **Step 5: Update the review status**

In `docs/app-review.md`, section 8 table: change the `S3 real session/tokens` row to `Done (M4-lite). API-issued tokens in secure storage, single-flight refresh, server-side revocation on logout; biometrics only unlock a stored session.`, and in the final "Not done client-side" sentence remove "money as integer cents (C1)," and add a row `| C1 money | Done (M4-lite): integer cents end to end. |`.

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: all PASS, the integration test reported as skipped.

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```powershell
git add dart_test.yaml test/integration/live_api_flow_test.dart README.md docs/app-review.md
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "test(integration): opt-in OTP-to-entitlement run against the local stack; README for prod flavor"
```

---

### Task 13: Localisation of the new strings (en first; zu/af English fallback)

**Files:**
- Create: `test/l10n_parity_test.dart`
- Modify: `lib/l10n/app_zu.arb`, `lib/l10n/app_af.arb` (+ regenerated `lib/l10n/app_localizations*.dart`), `README.md` (Localisation section)
- Test: `test/l10n_parity_test.dart`

**Interfaces:**
- Consumes: every key added to `app_en.arb` in Tasks 5, 7, 8 and 11.
- Produces: zu/af ARBs that define every English key (English text where no translation exists yet), and a test that keeps them in step.

- [ ] **Step 1: Write the failing parity test**

`test/l10n_parity_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String locale) =>
    Map<String, Object?>.from(jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map);

Iterable<String> _messageKeys(Map<String, Object?> arb) => arb.keys.where((k) => !k.startsWith('@'));

void main() {
  final en = _arb('en');

  for (final locale in ['zu', 'af']) {
    test('$locale defines every English key (no silent English fallbacks)', () {
      final other = _arb(locale);
      final missing = _messageKeys(en).where((k) => !other.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'add these keys to app_$locale.arb: $missing');
    });

    test('$locale keeps every placeholder of the English message', () {
      final other = _arb(locale);
      final placeholder = RegExp(r'\{(\w+)\}');
      for (final key in _messageKeys(en)) {
        final source = en[key];
        final translated = other[key];
        if (source is! String || translated is! String) continue;
        final expected = placeholder.allMatches(source).map((m) => m.group(1)).toSet();
        final actual = placeholder.allMatches(translated).map((m) => m.group(1)).toSet();
        expect(actual, expected, reason: '$locale/$key');
      }
    });
  }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/l10n_parity_test.dart`
Expected: FAIL listing the missing keys for zu and af (`tenantPickerTitle`, ..., `confirmationViewPasses`).

- [ ] **Step 3: Add the keys to zu and af**

Append to both `lib/l10n/app_zu.arb` and `lib/l10n/app_af.arb` (before the closing brace) every key added to `app_en.arb` in Tasks 5, 7, 8 and 11, **with the English text copied unchanged**, i.e. exactly these 41 keys: `tenantPickerTitle`, `tenantPickerSubtitle`, `tenantTypeOperator`, `tenantTypeReseller`, `tenantChangeTitle`, `tenantChangeBody`, `tenantChangeConfirm`, `updateRequiredTitle`, `updateRequiredBody`, `accountProvider`, `accountChangeProvider`, `consentLegalBody`, `dataExportTitle`, `dataExportBody`, `loginSendCode`, `loginPhoneInvalid`, `loginNewCustomerHint`, `loginWelcomeBackName`, `loginNotYou`, `otpSentTo`, `otpCodeHint`, `otpVerify`, `otpResend`, `otpResendIn`, `otpChangeNumber`, `otpInvalidCode`, `otpDemoHint`, `registerAcceptTerms`, `passesTitle`, `passesEmpty`, `passesShowExpired`, `passesStatusActive`, `passesStatusScheduled`, `passesStatusExpired`, `passesStatusExhausted`, `passesStatusRevoked`, `passesExpires`, `passesStarts`, `passesDevices`, `dashboardMyPasses`, `confirmationViewPasses`. (Placeholder metadata `@...` entries live only in `app_en.arb`.) Do not machine-translate: isiZulu and Afrikaans wording needs a native speaker (README note below).

Run: `flutter gen-l10n`
Expected: no "untranslated messages" warnings.

- [ ] **Step 4: README note**

In `README.md`, "### Localisation", append: "Strings added for the platform integration (provider picker, OTP sign-in, profile completion, data export, My passes) are present in `app_zu.arb` and `app_af.arb` **in English** so every key exists (`test/l10n_parity_test.dart` enforces this); they need translation and review by native isiZulu and Afrikaans speakers before release. Payment, checkout and confirmation screens are still hard-coded English (pre-existing follow-up)."

- [ ] **Step 5: Run the tests**

Run: `flutter test test/l10n_parity_test.dart test/l10n_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```powershell
git add lib/l10n/app_zu.arb lib/l10n/app_af.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zu.dart lib/l10n/app_localizations_af.dart test/l10n_parity_test.dart README.md
git -c user.name="WillemKlopper87" -c user.email="jakoklopper@gmail.com" commit -m "chore(l10n): zu/af keys for the platform screens (English fallback, native review needed)"
```

---

## Self-Review

**Spec coverage** (brief scope + spec §6/§12):
- Clean seam with `Http*Repository` beside `Mock*Repository`, flavor selection in the locator, default `demo`, prod base URL with HTTPS enforcement except local debug: Tasks 2, 4 (+ per-repo swaps in 6, 7, 9, 10, 11).
- Dio client: auth header from secure storage, single-flight refresh + one retry, problem+json -> `Failure` incl. `NetworkFailure` on timeouts/offline, request ids, idempotency keys on mutating calls (orders, consents; checkout is idempotent by construction server-side, logout/delete need none), per-request timeouts, no PII/tokens in logs: Tasks 2, 3.
- Tenant picker with persisted choice, app-config theming (name/logo/primary colour), legal versions (fed to consents), feature flags (RICA copy/route, CPE card, hotspot catalogue), min-version gate: Tasks 4, 5 (flags consumed in 9, 10, 11).
- OTP login + registration (E.164 SA numbers, OTP entry, resend timer, errors), biometrics only unlocking an existing session: Tasks 6, 8.
- Catalogue + order creation + hosted-payment hand-off (web view; ruling R-M4-3) + polling/resume (dashboard banner and `forOrder` routing), RICA off for passes: Tasks 9, 10.
- Entitlements ("My passes"): Task 11.
- Profile/consent/delete/export over the API with HTTP variants of the existing consent/privacy repositories: Task 7.
- Free Wi-Fi/voucher/coverage/hotspots (and the other backend-less repositories) stay mock through flavor-aware registration, stated in code (`stillMockInProd`), README and ruling R-M4-8: Tasks 4, 12.
- Money in integer cents end to end (C1): Task 1, kept in every mapper (`priceCents`, `totalCents`, `amountCents`, ZAR-only decoding).
- Tests: repository tests on `FakeHttpAdapter` (justified in R-M4-4) with contract fixtures (`test/fixtures/api/`), cubit tests, widget tests for login, tenant picker, update gate and My passes, refresh concurrency, offline/timeout, problem+json mapping, opt-in live integration test: Tasks 2-12.
- README for the local stack (`http://10.0.2.2:8088`, cleartext debug-only): Task 12. l10n (en first, zu/af English fallback, native-review note): Task 13.
- Not covered on purpose: Android build flavors and `flutter build apk` (no Android SDK; R-M4-5), certificate pinning (needs final hostnames; README owner row), Drift offline cache, push, deep links and hotspot auto-connect (full M4, not M4-lite).

**Placeholder scan.** Every code step carries complete code or an exact, anchored replacement. Steps that edit existing files name the anchor text to replace (e.g. the `pay` method, the splash `onFinished`, the `_CpeCard` line). Two deliberate transitional shims are named in ruling R-M4-12 and removed by explicit steps in Tasks 8 and 10. The only conditional step is Task 12 Step 3 (needs a running platform stack); it states how to record a skip.

**Type and name consistency.** Checked across tasks: `ApiClient.get/post/patch/delete` and `refresher` (T3) as used in T4, T6, T7, T9-T12; `TenantContext.slug/termsVersion/privacyVersion` (T3) set by `TenantCubit._apply` (T5) and read by `HttpConsentRepository` (T7) and `HttpCatalogRepository` (T9); `AuthTokens.fromTokenPair` (T3) in `HttpAuthRepository` (T6); `SessionEvents.expired` (T3) -> `AuthCubit(sessionExpired:)` (T6); `ValidationFailure(message, code)` codes `invalid_phone`, `invalid_code`, `otp_invalid`, `legal_versions_missing`, `payment_failed`, `rica_disabled` consistent between producers and the login page/tests; `OrderStatus` values (T9) handled exhaustively in `forOrder`, `PaymentCubit._statusFor`/`_confirm` (T9/T10) and `orderStatusFromApi`; `CheckoutRepository.createOrder(items:, idempotencyKey:)` (T9) and `startPayment(orderId:)` (T10) match the mock, HTTP and test fakes; `PaymentHandoff.isDemo/isFakeGateway` (T10) used by the page and the integration test; `stillMockInProd` (T4) referenced in README (T12); `FeatureFlags.demo` used by `MockTenantRepository` and `TenantState.featureFlags`; l10n keys listed in Task 13 equal the ones added in Tasks 5, 7, 8, 11.

**Review Focus coverage.** 1 refresh races -> `api_client_test` "concurrent 401s share ONE refresh", "retried at most once" (T3). 2 double charge/idempotency -> `api_client_test` "Idempotency-Key survives the 401 retry" (T3), `order_flow_cubits_test` "CheckoutCubit idempotency" (T9), `payment_polling_test` "double-tapping Pay" (T10). 3 tenant leak -> `api_client_test` "tokens issued for another tenant are never sent" (T3), `tenant_cubit_test` "switching tenant signs out FIRST" (T5), `tenant_ui_test` (T5). 4 cleartext -> `app_environment_test` (T2), `payment_urls_test` (T10). 5 logs -> `api_client_test` "log lines never contain ..." (T3). 6 offline -> `api_problem_test` timeouts (T2), `api_client_test` "refresh that cannot reach the server keeps the session" (T3), `tenant_cubit_test` cached config (T5), `payment_polling_test` "offline blips" (T10), `passes_test` (T11). 7 polling loops -> `payment_polling_test` bounded/close/checkAgain (T10). 8 logout wiping -> `auth_cubit_test` logout/deletion/expiry and `http_auth_repository_test` "logOut forgets the tokens even when the server is unreachable" (T6).

**Risks to watch while executing.** (a) M1 is being reconciled with the code: before Tasks 6-11, diff the fixtures against `apps/api/openapi.json` in the platform repo (once it has the M1 routes) and fix fixture + mapper together. (b) `webview_flutter` cannot run in `flutter test`; the web view is only exercised through `payment_urls_test` and must be smoke-tested on a device later (record in the SDD ledger). (c) dio's JSON transformer must decode `application/problem+json`; `ApiProblem.tryParse` also accepts a String body if a dio version does not. (d) The null-aware map entries (`'key': ?value`) need Dart >= 3.8; the SDK floor here is 3.12.
