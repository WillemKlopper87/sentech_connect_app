# Sentech Connect

A Flutter mobile app for Sentech's 5G Fixed Wireless Access (FWA) subscribers — coverage checking, plan purchase, RICA verification, account management, vouchers, and support, built as a UI + mock-repository phase ahead of real backend integration.

See also:
- [`docs/architecture.md`](docs/architecture.md) — diagrams: navigation flow, Clean Architecture layers, and how a screen talks to its data source.
- [`docs/reconciled-spec.md`](docs/reconciled-spec.md) — the original feature spec this app was built from.
- [`docs/brand-tokens.md`](docs/brand-tokens.md) — brand colours/type extracted from the Sentech CI manual.
- [`docs/prompt-critique.md`](docs/prompt-critique.md) — the design review that shaped several architecture decisions below (RICA liveness vendor, POPIA handling, payment tokenisation).

## What phase this is

The app has two flavors (`--dart-define=APP_FLAVOR=demo|prod`):

- **`demo`** (default in debug/profile): every repository is a mock; works fully offline. All tests run in this flavor.
- **`prod`**: tenants, sign-in (SMS one-time code), catalogue (hotspot passes), orders, payment hand-off, "My passes", profile, consents, data export and account deletion use the Sentech Connect platform API. It **requires** `--dart-define=API_BASE_URL=https://...` (an origin only; https, except cleartext to local dev hosts in debug builds). **Release builds must set `APP_FLAVOR` explicitly** (`demo` or `prod`); a release build without it stops at startup.

Still mock in **both** flavors because the platform has no API for them yet (listed in `stillMockInProd`, `lib/app/locator.dart`): coverage, free Wi-Fi, account usage/router summary, promotions, the support FAQ list and RICA liveness. Sending a support message is real in both flavors (`HttpSupportMessageRepository`, `POST /v1/support/messages`; the demo flavor uses a labelled mock). Voucher redemption is real in prod (`HttpVoucherRepository`, `POST /v1/me/vouchers/redeem`), so the Scan tab shows in both flavors. The hotspot map is real in prod (`GET /v1/hotspots`). In a prod build the Help tab shows only the contact actions (WhatsApp, message support), not the mock FAQ list, and the mock-backed free Wi-Fi and Promotions entry points and the router/usage card are hidden (shown in demo only), so customers never see fabricated account data.

## Quick start

```bash
flutter pub get
flutter run              # requires an Android device/emulator, or Chrome/Edge for a web preview
flutter analyze          # should report zero issues
flutter test             # widget + flow tests
```

Building a release APK (what's shipped for demoing on a physical device):

```bash
# demo flavor (mock-backed, offline)
flutter build apk --release --obfuscate --split-debug-info=build/debug-info --dart-define=APP_FLAVOR=demo

# prod flavor (real platform API; API_BASE_URL is an https origin only)
flutter build apk --release --obfuscate --split-debug-info=build/debug-info --dart-define=APP_FLAVOR=prod --dart-define=API_BASE_URL=https://api.example.com
```

A release build without `APP_FLAVOR` stops at startup with an error screen.

Requires the Android SDK (platform 36, build-tools) and **JDK 17** (Flutter's own Gradle template targets Java/Kotlin 17, and so does this project) — see `flutter doctor` if either is missing. Gradle will prompt to auto-install missing SDK components on first build if `cmdline-tools` is present.

## Running against the local platform stack

Prerequisites: Docker, and a checkout of `sentech_connect_platform`.

1. Start the stack (platform repo, Git Bash): `scripts/dev-up.sh`. Caddy listens on `127.0.0.1:8088`. Make sure the `sentech` tenant has at least one active hotspot pass: run `docker compose --env-file .env -f infra/docker-compose.yml -f infra/docker-compose.observability.yml -f infra/docker-compose.dev.yml exec -T api python -m sentech_api.devseed sentech` once the platform ships that seed module, or create products with `POST /v1/admin/products` using a token from `scripts/dev-token.sh` (`DEV_ROLE=tenant_admin`).
2. Run the app in the prod flavor (debug build):
   - Android emulator: `flutter run --dart-define=APP_FLAVOR=prod --dart-define=API_BASE_URL=http://10.0.2.2:8088` (`10.0.2.2` is the emulator's alias for the host).
   - iOS simulator, desktop or web: `flutter run --dart-define=APP_FLAVOR=prod --dart-define=API_BASE_URL=http://localhost:8088` (`127.0.0.1` also works).
   - Physical Android device over USB: `adb reverse tcp:8088 tcp:8088`, then use `http://127.0.0.1:8088`.

   Cleartext HTTP is accepted **only in debug builds and only to `localhost`, `127.0.0.1` or `10.0.2.2`** (`android/app/src/debug/res/xml/network_security_config.xml` plus the check in `AppEnvironment`); any other `http://` URL, or any `http://` in a release build, stops the app at startup. Use `https://` for every real environment.
3. Sign in with a South African mobile number. The fake SMS provider writes the code to Postgres instead of sending it (platform repo): `docker compose --env-file .env -f infra/docker-compose.yml -f infra/docker-compose.observability.yml -f infra/docker-compose.dev.yml exec -T postgres psql -U sentech -d sentech -tAc "SELECT body FROM sms_outbox ORDER BY created_at DESC LIMIT 1"`.
   The app sends a sign-in `binding` (a random secret per sign-in attempt, the same one on the code request and on verify) and shows "Use the SMS that shows reference AB12". Deleting the account needs a fresh SMS code too: Account > Delete my account sends a code to the number on the account, then asks for it. Both work against the local dev and test stack as they are.

   **Human check (task M2d).** The platform asks for a human check (`turnstile_token`) in staging and production. The app shows Cloudflare Turnstile in a WebView ("Quick check: confirm you are a person") when the build has `--dart-define=TURNSTILE_SITE_KEY=<public site key>` and `--dart-define=TURNSTILE_BASE_URL=https://<public web hostname of the platform>`. The API does not expose these two values (gap recorded in `docs/BACKEND_CONTRACT_SYNC.md`). The Turnstile widget in Cloudflare must list that hostname and the platform must accept it (`SENTECH_TURNSTILE_ALLOWED_HOSTNAMES`). Without both defines the app sends no token, which only dev and test stacks accept; against staging or production, sign-in and "send me a code" for deletion then fail with 403 `human_verification_failed`. Set both or neither: one without the other stops the app at startup. In dev and test the platform still accepts a code requested without a binding; staging and prod require it (the app always sends one).
4. Buy a pass. The local stack uses the platform's fake payment gateway: debug builds show an "Approve / Decline test payment" sheet that calls the dev-only `POST /v1/dev/payments/{id}/simulate` (registered by the API only in env dev/test). With a real gateway (Netcash) the payment page opens in a locked-down web view and the app polls the order until the gateway's server-to-server notification marks it paid.

### Flutter and the pub cache

If the global pub cache is locked down or shared, keep the dependencies local to the repository: `export PUB_CACHE="$(pwd -W)/.dart_tool/pub-cache"` (Git Bash on Windows; PowerShell: `$env:PUB_CACHE = "$PWD\.dart_tool\pub-cache"`) before `flutter pub get`, `flutter analyze` and `flutter test`. `.dart_tool/` is git-ignored.

### Web demo build (screenshots)

`flutter build web --dart-define=APP_FLAVOR=demo` (serve `build/web` with any static server). The demo flavor is fully mock-backed and offline, so it is the easiest way to capture screens without a stack; it is not a supported production web target.

### What is stubbed or fake

- **SMS**: the platform's fake sender stores OTP messages in `sms_outbox`; nothing is sent. Staging and production refuse it. The fake sender also writes the `Code ref XXXX` reference into the message.
- **Human check**: the Turnstile WebView is built (M2d) but untested on real devices and against real Cloudflare keys; platform attestation (Play Integrity, App Attest) is not built. Dev and test accept sign-in without a token.
- **Payments**: the local stack uses the platform's fake gateway (dev simulate endpoint). Netcash is implemented as a request/notification **shape only**: no merchant account has been exercised, so there is no real-money path yet.
- **Maps**: no tile provider is configured; debug/demo builds use public OSM tiles, release builds show a placeholder until `TILE_URL_TEMPLATE`/`TILE_API_KEY` are set.
- **Languages**: Afrikaans and isiZulu cover only the migrated screens; every other string falls back to English. The translations are first drafts that need native review.
- **Mock in both flavors**: see `stillMockInProd` above and the route table under "Mock repositories and their real routes".

### Live integration test

`test/integration/live_api_flow_test.dart` (tag `integration`) runs OTP sign-in, consent, catalogue, order, fake-gateway checkout, `simulate accepted`, polling to `paid` and the entitlement check against a running stack. It is **skipped unless both variables are set**, so `flutter test` stays green offline. It reads the OTP via `docker compose` in the platform checkout, uses a fresh random phone number per run, and needs a seeded `sentech` catalogue:

```powershell
$env:INTEGRATION_API_BASE_URL = "http://127.0.0.1:8088"
$env:INTEGRATION_PLATFORM_DIR = "C:\Users\Wille\Downloads\applications\sentech_connect_platform"
flutter test test/integration/live_api_flow_test.dart
```

## Build configuration and owner decisions

Nothing below contains a real secret; each item needs an input from the owner before a production release.

| Area | How it is wired | Owner input needed |
|---|---|---|
| **Release signing** | `android/app/build.gradle.kts` reads `android/key.properties` (git-ignored; copy `android/key.properties.example`). A release build **fails with a clear message** if it is missing. For a throwaway local demo APK only: `SENTECH_ALLOW_DEBUG_SIGNING=true flutter build apk --release --dart-define=APP_FLAVOR=demo` (or `APP_FLAVOR=prod --dart-define=API_BASE_URL=https://…`; debug-signed, never distribute). | Upload keystore + passwords (keep in a secret manager; use Play App Signing) |
| **Android application id** | Single source: `sentech.applicationId` in `android/gradle.properties` (override per build with `-Psentech.applicationId=…`, `-Psentech.applicationIdSuffix=.demo`). The Kotlin package/namespace is independent and stays put. | **Final id — cannot change after the first Play upload** |
| **Map tiles** | `--dart-define=TILE_URL_TEMPLATE=https://…/{z}/{x}/{y}.png?key={apiKey} --dart-define=TILE_API_KEY=… [--dart-define=TILE_ATTRIBUTION="…"]`. Public OSM tiles are used only in debug/demo builds; a release build without a provider shows a placeholder and never contacts tile.openstreetmap.org. | Commercial/self-hosted provider + app-restricted key |
| **Push (FCM)** | `NotificationService` interface + Android 13 permission flow are done; no transport. Exact wiring steps are in the doc comment of `lib/core/notifications/notification_service.dart`. | Firebase project, `google-services.json` / APNs key, final application id |
| **Crash reporting** | `CrashReporter` interface + global handlers (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`); reports are PII-scrubbed. Console implementation only; Sentry/Crashlytics plug-in notes are on `CrashReporter`. | Sentry DSN or Firebase project |
| **iOS** | `ios/` generated with `--org za.co.sentech` (bundle id `za.co.sentech.sentechConnectApp`); Info.plist has camera, location-when-in-use and Face ID descriptions. Not built or signed. `permission_handler` needs the `PERMISSION_NOTIFICATIONS=1` macro in the Podfile once it exists. | Apple team id, final bundle id, signing, APNs key |
| **Privacy policy** | `privacyPolicyUrl` placeholder in `lib/core/privacy/privacy_constants.dart` | Published policy URL |
| **Platform API** | `--dart-define=APP_FLAVOR=prod --dart-define=API_BASE_URL=https://…`; tenants, OTP sign-in, passes, orders, payments, entitlements, profile/consents/export/delete. | Production API hostname (then certificate pinning with a backup pin), SMS provider, Netcash merchant account per tenant |
| **Still mock** | Coverage, free Wi-Fi, usage/router, promotions, support, RICA liveness (`stillMockInProd`). See the table below. | Backend APIs for each |

### Mock repositories and their real routes

These repositories are listed in `stillMockInProd` (`lib/app/locator.dart`) and are mock in **both** flavors. The real routes below come from `test/contract/openapi.json`. Nothing here is swapped yet. Paths are under `lib/features/`.

| Area | Mock file | Real API route today | Swapped in |
|---|---|---|---|
| Coverage | `coverage/data/repositories/mock_coverage_repository.dart` | `GET /v1/coverage/check?lat&lon&tenant`, `GET /v1/coverage/meta`, `GET /v1/tiles/{layer}/{z}/{x}/{y}.mvt`, `GET /v1/geocode/search` | WP-26 |
| Free WiFi | `wifi_voucher/data/repositories/mock_free_wifi_repository.dart` | none yet (free time) | WP-23 |
| Hotspots | real: `wifi_voucher/data/repositories/http_wifi_hotspots_repository.dart` (mock for demo) | `GET /v1/hotspots?tenant&bbox&cursor&limit` | done |
| Usage and router | `account_dashboard/data/repositories/mock_account_repository.dart` | none yet (network) | WP-17 |
| Promotions | `promotions/data/repositories/mock_promotions_repository.dart` | none yet (listings) | WP-24 |
| Subscriber account (signup, services, invoices, KYC) | not built yet (M3) | `GET/PATCH /v1/me/subscriber`, `POST /v1/me/subscriber/signup`, `.../services`, `.../invoices`, `.../kyc`, `GET /v1/subscriber-plans` | M3 |
| Support FAQ | `support/data/repositories/mock_support_repository.dart` | no FAQ API on the platform | none planned |
| Support message (real) | `support/data/repositories/http_support_message_repository.dart` | `POST /v1/support/messages` (Idempotency-Key, 202 `{reference}`) | done |
| RICA liveness | `rica/data/repositories/mock_liveness_repository.dart` | none (needs a vendor) | not in the V1 app |

### Modules and branding

- **Modules.** `GET /v1/app-config` carries `modules` (booleans for `vouchers`, `tickets`, `credits`, `wifi_aware`, `subscriber_billing`) and `collection_mode_public.buy_in_app`. The app hides what a provider has switched off (for example Scan follows `vouchers`).
- **Missing means off.** A key that is absent or not a boolean is off. When the server sends no `modules` at all (an older API), only `vouchers` follows `feature_flags.vouchers` and every other module is off. A missing `collection_mode_public` means the app may sell in the app.
- **A refusal wins.** A 403 `module_not_enabled` hides that feature at once, in memory only, until the next config load. There is no refetch and no retry loop.
- **Buy from your provider.** When `buy_in_app` is false, the buy sheet and the cart describe the product but offer no payment, and say who to contact instead.
- **The offline cache** keeps modules, support channels and branding, so a launch without a connection shows the last known provider.
- **Branding is data only.** Colours must be `#rrggbb` and pass the theme contrast rule (4.5:1). Links and the logo must be https with a host and no userinfo. The logo alt text and the display name are plain `Text`, length-capped, with control and bidi characters removed. There is no HTML and no WebView for branding. The accent colour is parsed but not applied.
- **Entitlements** are read defensively: `origin_type`, `scope[].kind`, `funded_by_other` and `home_serving_differs` are optional, unknown values degrade to a safe default, and none is shown yet. An unknown entitlement **status** still fails the load, so a pass the customer paid for is never silently dropped. `suspended` (the provider paused the service) is a known status: the pass shows as "Service suspended" with no countdown or bar, and it gets no usage or expiry alerts. `source: service` and a null `product_id` are accepted.

### Localisation

`flutter_localizations` + gen-l10n (`l10n.yaml`). Strings live in `lib/l10n/app_{en,zu,af}.arb`; generated Dart is committed (run `flutter gen-l10n` after editing an ARB — CI fails if it is stale). Login, registration, account, support and the consent/notification sheets are migrated; the rest of the app is still English (follow-up). Afrikaans and isiZulu are first drafts and **need review by native speakers**; the newest drafts are listed in `docs/L10N_NEEDS_NATIVE_REVIEW.md`. Users switch language in Account; the choice is stored in SharedPreferences. Use `context.l10n.someKey` in widgets. Strings added for the platform integration (provider picker, OTP sign-in, profile completion, data export, My passes, payment hand-off copy, time/size units, dashboard quick actions) are present in `app_zu.arb` and `app_af.arb` **in English** so every key exists (`test/l10n_parity_test.dart` enforces this); they need translation and review by native isiZulu and Afrikaans speakers before release. Payment, checkout and confirmation screens are still largely hard-coded English (pre-existing follow-up).

### Security and privacy notes

- Personal data (session, registration details, consent records, orders) is stored through `SecureStore` (Android Keystore / iOS Keychain via `flutter_secure_storage`), never SharedPreferences; GPS coordinates are not persisted. Logout revokes the session on the server, forgets the tokens and the biometric unlock, and wipes registration details, local orders, the free-WiFi grant and the in-memory cart; account deletion wipes everything, but only after the server accepted it: `POST /v1/me/delete-challenge` (code by SMS to the number on the account), then `DELETE /v1/me` with `{challenge_id, code}`; a wrong code (403 `reauth_required`) deletes nothing and wipes nothing, and a customer whose account has no phone number is told to contact support. On a cold start with a stored session and an enrolled biometric the app starts locked and "Use biometrics" unlocks it. Switching provider (Account > Change provider) signs the customer out first.
- Human check (M2d): the Turnstile page is an HTML string loaded with the platform web origin as base URL, with JavaScript on and one one-way channel; the WebView may only show that origin and `challenges.cloudflare.com` (everything else is blocked), keeps the default user agent, and is created fresh for each request. The token is held in memory until the request is made: never stored, reused, shown or logged (`PiiScrubber` also removes `token` and `turnstile_token` values). Only the public site key is in the build; the secret key lives on the platform.
- The RICA and Account screens set `FLAG_SECURE` (no screenshots/recents preview) through a small MethodChannel in `MainActivity.kt`. Cleartext HTTP is disabled (`network_security_config.xml`; debug builds allow localhost only). Certificate pinning is deferred until real endpoints exist.
- Order flow (prod): **create order -> hosted payment (gateway web view) -> passes**. The order is held server-side and payment is confirmed by the server (the app only polls its status); hotspot orders skip RICA. The demo flavor keeps the mock **order -> RICA -> payment -> confirmation** flow, with the order persisted locally so it can be resumed from the dashboard.

## Architecture

**Feature-First Clean Architecture** — each feature module has up to three layers:

```
lib/features/<feature>/
├── domain/         # Pure Dart. Entities, repository interfaces, no Flutter/Bloc imports.
├── data/           # Repository implementations (currently: Mock*Repository).
└── presentation/   # Cubit (state) + Flutter widgets (pages).
```

`domain/repositories/*.dart` is the seam: swap `MockCoverageRepository` for `HttpCoverageRepository` and nothing in `presentation/` changes, because the Cubit only ever talks to the interface.

Full diagram: [`docs/architecture.md`](docs/architecture.md).

### Feature modules

| Feature | What it does | Key state |
|---|---|---|
| `auth` | Login, biometric login, registration (with device-location capture + reverse geocoding), session persistence, splash | `AuthCubit` (app-root), `RegistrationCubit` |
| `coverage` | Address/GPS-based 5G FWA coverage check with a real interactive map | `CoverageCubit` |
| `catalog_checkout` | Product catalog (Home 5G / MiFi / Vouchers), checkout, payment method selection, RICA hand-off, order confirmation | `CatalogCubit`, `CheckoutCubit` |
| `cart` | Multi-item cart, shared across the whole app session | `CartCubit` (app-root) |
| `rica` | Liveness capture screen (camera + POPIA consent) that verifies identity before payment | `RicaCubit` |
| `account_dashboard` | Usage meter, CPE/router status, quick actions (top up / upgrade / report issue) | `AccountCubit` |
| `voucher_scanner` | Real camera QR/barcode scanning (`mobile_scanner`) with manual-entry fallback; redemption goes through `VoucherRepository` (typed results, idempotent), raw payloads are never shown | `VoucherCubit` |
| `privacy` | POPIA consent records, data export / account deletion requests | `PrivacyActionsCubit` |
| `wifi_voucher` | Ad-gated free WiFi (3/day cap, simulated ad, live countdown) + nearby-hotspot map sorted by distance | `FreeWifiCubit`, `WifiHotspotsCubit` |
| `promotions` | Loyalty points + current offers, linked from the dashboard | `PromotionsCubit` |
| `support` | FAQ search, WhatsApp deep link, ticket-by-email | `SupportCubit` |
| `account` | Profile, manual light/dark theme toggle, logout | reads `AuthCubit` + `ThemeCubit` |

### App-root state (survives navigation)

Provided once in `lib/app/app.dart` via `MultiBlocProvider`, not per-route:

- **`AuthCubit`** — logged-in session. Persisted through `SessionStore` (secure storage) so closing the app doesn't log the user out; the splash screen checks this and skips straight to the dashboard for a returning session. `AppRouter` (`lib/app/router/app_router.dart`) redirects signed-out users to `/login` (remembering where they were going) and keeps signed-in users off `/login`.
- **`CartCubit`** — cart contents. Survives from Shop → Cart → Checkout without being recreated; cleared when the user signs out.
- **`ConnectivityCubit`** — online/offline, drives the global offline banner. **`LocaleCubit`** — chosen UI language (persisted).
- **`ThemeCubit`** — light/dark/system choice, also persisted.

### Dependency injection

`lib/app/locator.dart` registers every repository interface against its (currently mock) implementation using `get_it`:

```dart
locator.registerLazySingleton<CoverageRepository>(() => MockCoverageRepository());
```

Cubits receive their repository through the constructor (`CoverageCubit(locator())`), never reach into the locator themselves beyond that — keeps them unit-testable with a fake repository, as `test/free_wifi_test.dart` and `test/support_page_test.dart` do.

### Navigation

`go_router`, configured in `lib/app/router/app_router.dart`. Two kinds of routes:

- **Full-screen pushed routes** (splash, login, register, coverage, cart, checkout, RICA, confirmation, promotions, WiFi hotspots) — one screen, no bottom nav.
- **`MainShell`** (`lib/app/main_shell.dart`) — the persistent bottom-nav shell (Home/Shop/Scan/Support/Account) built with `IndexedStack` so each tab keeps its scroll position and state when you switch away and back. Inactive tabs are wrapped in `TickerMode(enabled: false)` so their animations (and the camera on the Scan tab) actually pause when off-screen — see "Known gotchas" below for why that matters.

Full route graph: [`docs/architecture.md`](docs/architecture.md).

### Real device integrations already wired

| Capability | Package | Where |
|---|---|---|
| Camera QR/barcode scanning | `mobile_scanner` | `voucher_scanner/presentation/pages/voucher_scanner_page.dart` |
| Device GPS | `geolocator` | `coverage`, `auth/registration`, `wifi_voucher/wifi_hotspots_cubit.dart` |
| Reverse geocoding (coords → street address) | `geocoding` | `core/utils/reverse_geocode.dart` |
| Interactive map (OpenStreetMap, no API key) | `flutter_map` + `latlong2` | `shared/widgets/osm_map.dart` |
| Secure storage (session, registration, consent, orders, free-WiFi state) | `flutter_secure_storage` | `core/storage/` |
| Non-sensitive prefs (theme, language) | `shared_preferences` | `core/local/app_preferences.dart` |
| Biometric login | `local_auth` (behind `BiometricAuthenticator`) | `core/biometrics/` |
| Connectivity / offline banner | `connectivity_plus` (behind `ConnectivityService`) | `core/network/`, `app/connectivity_cubit.dart` |
| Notification permission (Android 13+) | `permission_handler` (behind `NotificationService`) | `core/notifications/` |
| WhatsApp / email deep links | `url_launcher` | `shared/actions/support_actions.dart` |

### What's still a placeholder / needs a real decision

- **WhatsApp number** (`shared/actions/support_actions.dart`, `whatsAppNumber` constant) — obviously fake, swap before shipping.
- **Ad-gated free WiFi** uses a *simulated* ad (a 6-second countdown dialog), not a real ad network — needs a Google AdMob account + unit IDs to go live (see `wifi_voucher/presentation/pages/watch_ad_dialog.dart`).
- **RICA liveness** should be a certified vendor (Smile Identity recommended — see `docs/prompt-critique.md`), not `google_mlkit_face_detection` alone; the RICA screen currently mocks the liveness result via `MockLivenessRepository`.
- **Offline map tile caching** ("pre-load South Africa, refresh monthly on WiFi") was explicitly scoped *out* of this pass — `OsmMap` fetches live OSM tiles each time. Worth its own design task (storage budget, background sync, cache invalidation) before building.
- **Coverage / CPE telemetry / promotions / hotspot APIs** are all named `Mock*Repository` because Sentech's real endpoints for these don't exist yet or weren't provided.

## Swapping a mock for a real backend

1. Implement the domain repository interface, e.g. `class HttpCoverageRepository implements CoverageRepository`.
2. Change one line in `lib/app/locator.dart`:
   ```dart
   locator.registerLazySingleton<CoverageRepository>(() => HttpCoverageRepository(dio));
   ```
3. Nothing in `presentation/` needs to change — `CoverageCubit` only knows about `CoverageRepository`, not which implementation backs it.

## Known gotchas (read before touching these areas)

- **`IndexedStack` + camera:** `VoucherScannerPage` lives in `MainShell`'s `IndexedStack`, which never disposes tabs when you switch away. Without the `WidgetsBindingObserver` + `TickerMode.valuesOf` lifecycle handling already in `voucher_scanner_page.dart`, the camera stays open in the background and can end up stuck in an error state after the app backgrounds. If you add another camera/heavy-resource screen to the shell, copy this pattern.
- **`go_router` + Hero transitions:** Payment → Confirmation uses `context.go()`, not `context.pushReplacement()`. The latter triggered an intermittent Flutter Hero-controller assertion when combined with the always-mounted `IndexedStack` shell underneath. If you see `'manifest.fromHero == newManifest.toHero'` assertions, check for a `pushReplacement` earlier in that navigation chain.
- **`fpdart`'s `Order` vs the app's `Order` entity:** `catalog_checkout/domain/entities/order.dart` defines an `Order` class that collides with `fpdart`'s own `Order` typeclass. Files that need both import fpdart with `hide Order`.
- **Geocoding package API:** pinned to `geocoding: ^5.0.0` — the `3.x` line has an outdated internal `compileSdk` that fails release builds against modern Android Gradle Plugin versions. Don't downgrade without checking the build still succeeds.

## Testing

`flutter test` runs everything (CI also runs `flutter analyze` and `--coverage`). `test/helpers/test_setup.dart` gives widget tests an in-memory secure store, fake clock/connectivity/notification/biometric services and an offline map tile provider.

- `flow_test.dart` — end-to-end journey: login -> coverage -> catalog -> cart -> checkout -> RICA -> payment -> confirmation -> tabs.
- `router_test.dart` — auth redirect rules, deep links, id-based routes (no `extra`).
- `auth_cubit_test.dart`, `registration_repository_test.dart` — biometrics gating, secure session, wipe on logout/delete.
- `checkout_repository_test.dart`, `order_flow_cubits_test.dart` — persisted/resumable orders, verify-before-pay, retry paths.
- `voucher_test.dart`, `free_wifi_repository_test.dart` — typed voucher outcomes, scan-loop guard, tamper-aware free-WiFi cap.
- `privacy_test.dart`, `notifications_test.dart`, `secure_screen_test.dart`, `l10n_test.dart`, `accessibility_test.dart` (2.0 text scale, 48dp targets), `offline_test.dart`, `osm_map_test.dart`, `diagnostics_test.dart`.
- `binding_generator_test.dart`, `otp_login_cubit_test.dart` (binding reuse on resend, new binding on number change), `delete_account_flow_test.dart` (two-step delete: success, 403, 401 keeps the session, 409, 429), `typed_failure_copy_test.dart`, `api_problem_test.dart` (typed problem codes).
- `support_page_test.dart`, `free_wifi_test.dart`, `widget_test.dart` — page-level tests.

**OpenAPI contract snapshot.** `test/contract/openapi.json` is a copy of the platform's `apps/api/openapi.json`, so the contract tests run offline. Refresh it with `dart run tool/sync_openapi.dart ../sentech_connect_platform/apps/api/openapi.json`. The route-by-route status of the app against that file is in `docs/BACKEND_CONTRACT_SYNC.md` and commit the refreshed snapshot together with any model change. CI fails when the snapshot is stale. The drift check needs the `PLATFORM_REPO_TOKEN` secret, a fine-grained token with contents:read on the platform repo only (without it the check is skipped with a notice). The repo variable `PLATFORM_REF` optionally overrides the platform branch (default `codex/naas-implementation`).

## Brand/theme

`lib/app/theme/app_theme.dart` derives light/dark `ColorScheme`s from `docs/brand-tokens.md`. Dark mode uses the brand's own dark-navy (`#00335C`), not a generic black, matching how the Sentech CI manual treats dark pages. The app bar carries a solid brand-colour background rather than sitting transparent, matching the CI manual's coloured-header convention (letterheads, newsletters, internal communiques all use a coloured band, never a colourless one).

Real logo assets live in `assets/brand/logo/`; `shared/widgets/sentech_logo.dart` picks the correct variant (full-colour on light, reversed white on dark) automatically based on `Theme.of(context).brightness`.
