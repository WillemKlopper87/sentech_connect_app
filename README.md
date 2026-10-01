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

Still mock in **both** flavors because the platform has no API for them yet (listed in `stillMockInProd`, `lib/app/locator.dart`): coverage, free Wi-Fi, hotspot map, voucher redemption, account usage/router summary, promotions, support and RICA liveness. A prod build shows their demo data.

## Quick start

```bash
flutter pub get
flutter run              # requires an Android device/emulator, or Chrome/Edge for a web preview
flutter analyze          # should report zero issues
flutter test             # widget + flow tests
```

Building a release APK (what's shipped for demoing on a physical device):

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

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
4. Buy a pass. The local stack uses the platform's fake payment gateway: debug builds show an "Approve / Decline test payment" sheet that calls the dev-only `POST /v1/dev/payments/{id}/simulate` (registered by the API only in env dev/test). With a real gateway (Netcash) the payment page opens in a locked-down web view and the app polls the order until the gateway's server-to-server notification marks it paid.

### Flutter and the pub cache

If the global pub cache is locked down or shared, keep the dependencies local to the repository: `export PUB_CACHE="$(pwd -W)/.dart_tool/pub-cache"` (Git Bash on Windows; PowerShell: `$env:PUB_CACHE = "$PWD\.dart_tool\pub-cache"`) before `flutter pub get`, `flutter analyze` and `flutter test`. `.dart_tool/` is git-ignored.

### Web demo build (screenshots)

`flutter build web --dart-define=APP_FLAVOR=demo` (serve `build/web` with any static server). The demo flavor is fully mock-backed and offline, so it is the easiest way to capture screens without a stack; it is not a supported production web target.

### What is stubbed or fake

- **SMS**: the platform's fake sender stores OTP messages in `sms_outbox`; nothing is sent. Staging and production refuse it.
- **Payments**: the local stack uses the platform's fake gateway (dev simulate endpoint). Netcash is implemented as a request/notification **shape only**: no merchant account has been exercised, so there is no real-money path yet.
- **Maps**: no tile provider is configured; debug/demo builds use public OSM tiles, release builds show a placeholder until `TILE_URL_TEMPLATE`/`TILE_API_KEY` are set.
- **Languages**: Afrikaans and isiZulu cover only the migrated screens; every other string falls back to English. The translations are first drafts that need native review.
- **Mock in both flavors**: see `stillMockInProd` above.

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
| **Release signing** | `android/app/build.gradle.kts` reads `android/key.properties` (git-ignored; copy `android/key.properties.example`). A release build **fails with a clear message** if it is missing. For a throwaway local demo APK only: `SENTECH_ALLOW_DEBUG_SIGNING=true flutter build apk --release` (debug-signed, never distribute). | Upload keystore + passwords (keep in a secret manager; use Play App Signing) |
| **Android application id** | Single source: `sentech.applicationId` in `android/gradle.properties` (override per build with `-Psentech.applicationId=…`, `-Psentech.applicationIdSuffix=.demo`). The Kotlin package/namespace is independent and stays put. | **Final id — cannot change after the first Play upload** |
| **Map tiles** | `--dart-define=TILE_URL_TEMPLATE=https://…/{z}/{x}/{y}.png?key={apiKey} --dart-define=TILE_API_KEY=… [--dart-define=TILE_ATTRIBUTION="…"]`. Public OSM tiles are used only in debug/demo builds; a release build without a provider shows a placeholder and never contacts tile.openstreetmap.org. | Commercial/self-hosted provider + app-restricted key |
| **Push (FCM)** | `NotificationService` interface + Android 13 permission flow are done; no transport. Exact wiring steps are in the doc comment of `lib/core/notifications/notification_service.dart`. | Firebase project, `google-services.json` / APNs key, final application id |
| **Crash reporting** | `CrashReporter` interface + global handlers (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`); reports are PII-scrubbed. Console implementation only; Sentry/Crashlytics plug-in notes are on `CrashReporter`. | Sentry DSN or Firebase project |
| **iOS** | `ios/` generated with `--org za.co.sentech` (bundle id `za.co.sentech.sentechConnectApp`); Info.plist has camera, location-when-in-use and Face ID descriptions. Not built or signed. `permission_handler` needs the `PERMISSION_NOTIFICATIONS=1` macro in the Podfile once it exists. | Apple team id, final bundle id, signing, APNs key |
| **Privacy policy** | `privacyPolicyUrl` placeholder in `lib/core/privacy/privacy_constants.dart` | Published policy URL |
| **Platform API** | `--dart-define=APP_FLAVOR=prod --dart-define=API_BASE_URL=https://…`; tenants, OTP sign-in, passes, orders, payments, entitlements, profile/consents/export/delete. | Production API hostname (then certificate pinning with a backup pin), SMS provider, Netcash merchant account per tenant |
| **Still mock** | Coverage, free Wi-Fi, hotspots, vouchers, usage/router, promotions, support, RICA liveness (`stillMockInProd`). | Backend APIs for each |

### Localisation

`flutter_localizations` + gen-l10n (`l10n.yaml`). Strings live in `lib/l10n/app_{en,zu,af}.arb`; generated Dart is committed (run `flutter gen-l10n` after editing an ARB — CI fails if it is stale). Login, registration, account, support and the consent/notification sheets are migrated; the rest of the app is still English (follow-up). Afrikaans and isiZulu are first drafts and **need review by native speakers**. Users switch language in Account; the choice is stored in SharedPreferences. Use `context.l10n.someKey` in widgets.

### Security and privacy notes

- Personal data (session, registration details, consent records, orders) is stored through `SecureStore` (Android Keystore / iOS Keychain via `flutter_secure_storage`), never SharedPreferences; GPS coordinates are not persisted. Logout revokes the session on the server, forgets the tokens and the biometric unlock, and wipes registration details, local orders, the free-WiFi grant and the in-memory cart; account deletion (`DELETE /v1/me`) wipes everything. On a cold start with a stored session and an enrolled biometric the app starts locked and "Use biometrics" unlocks it. Switching provider (Account > Change provider) signs the customer out first.
- The RICA and Account screens set `FLAG_SECURE` (no screenshots/recents preview) through a small MethodChannel in `MainActivity.kt`. Cleartext HTTP is disabled (`network_security_config.xml`; debug builds allow localhost only). Certificate pinning is deferred until real endpoints exist.
- Order flow is **create order -> RICA identity check -> payment -> confirmation**: the customer is only charged after verification succeeds, and the order is persisted so it can be resumed from the dashboard after a failure or an app restart.

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
- `support_page_test.dart`, `free_wifi_test.dart`, `widget_test.dart` — page-level tests.

## Brand/theme

`lib/app/theme/app_theme.dart` derives light/dark `ColorScheme`s from `docs/brand-tokens.md`. Dark mode uses the brand's own dark-navy (`#00335C`), not a generic black, matching how the Sentech CI manual treats dark pages. The app bar carries a solid brand-colour background rather than sitting transparent, matching the CI manual's coloured-header convention (letterheads, newsletters, internal communiques all use a coloured band, never a colourless one).

Real logo assets live in `assets/brand/logo/`; `shared/widgets/sentech_logo.dart` picks the correct variant (full-colour on light, reversed white on dark) automatically based on `Theme.of(context).brightness`.
