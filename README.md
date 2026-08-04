# Sentech Connect

A Flutter mobile app for Sentech's 5G Fixed Wireless Access (FWA) subscribers — coverage checking, plan purchase, RICA verification, account management, vouchers, and support, built as a UI + mock-repository phase ahead of real backend integration.

See also:
- [`docs/architecture.md`](docs/architecture.md) — diagrams: navigation flow, Clean Architecture layers, and how a screen talks to its data source.
- [`docs/reconciled-spec.md`](docs/reconciled-spec.md) — the original feature spec this app was built from.
- [`docs/brand-tokens.md`](docs/brand-tokens.md) — brand colours/type extracted from the Sentech CI manual.
- [`docs/prompt-critique.md`](docs/prompt-critique.md) — the design review that shaped several architecture decisions below (RICA liveness vendor, POPIA handling, payment tokenisation).

## What phase this is

Every business-data repository (plans, coverage, RICA, promotions, etc.) is **mock-backed** — real network calls, camera capture, GPS, and maps *are* wired up and functional, but the data they read/write about products, orders, and coverage is fake. The point of this phase is a fully navigable, architecturally real app that a backend team can plug into by swapping mock repository implementations for real ones, without touching anything above the repository layer. See "Swapping a mock for a real backend" below.

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

Requires the Android SDK (platform 36, build-tools) and a JDK 17+ — see `flutter doctor` if either is missing. Gradle will prompt to auto-install missing SDK components on first build if `cmdline-tools` is present.

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
| `rica` | Liveness capture screen (camera + consent) before service activation | `RicaCubit` |
| `account_dashboard` | Usage meter, CPE/router status, quick actions (top up / upgrade / report issue) | `AccountCubit` |
| `voucher_scanner` | Real camera QR/barcode scanning (`mobile_scanner`) with manual-entry fallback | stateful, no Cubit (camera lifecycle only) |
| `wifi_voucher` | Ad-gated free WiFi (3/day cap, simulated ad, live countdown) + nearby-hotspot map sorted by distance | `FreeWifiCubit`, `WifiHotspotsCubit` |
| `promotions` | Loyalty points + current offers, linked from the dashboard | `PromotionsCubit` |
| `support` | FAQ search, WhatsApp deep link, ticket-by-email | `SupportCubit` |
| `account` | Profile, manual light/dark theme toggle, logout | reads `AuthCubit` + `ThemeCubit` |

### App-root state (survives navigation)

Provided once in `lib/app/app.dart` via `MultiBlocProvider`, not per-route:

- **`AuthCubit`** — logged-in session. Persisted to device storage (`AppPreferences`/`shared_preferences`) so closing the app doesn't log the user out; the splash screen checks this and skips straight to the dashboard for a returning session.
- **`CartCubit`** — cart contents. Survives from Shop → Cart → Checkout without being recreated.
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
| Local persistence (session, theme, ad-cap counters, registration) | `shared_preferences` | `core/local/app_preferences.dart` |
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
- **`go_router` + Hero transitions:** RICA → Confirmation uses `context.go()`, not `context.pushReplacement()`. The latter triggered an intermittent Flutter Hero-controller assertion when combined with the always-mounted `IndexedStack` shell underneath. If you see `'manifest.fromHero == newManifest.toHero'` assertions, check for a `pushReplacement` earlier in that navigation chain.
- **`fpdart`'s `Order` vs the app's `Order` entity:** `catalog_checkout/domain/entities/order.dart` defines an `Order` class that collides with `fpdart`'s own `Order` typeclass. Files that need both import fpdart with `hide Order`.
- **Geocoding package API:** pinned to `geocoding: ^5.0.0` — the `3.x` line has an outdated internal `compileSdk` that fails release builds against modern Android Gradle Plugin versions. Don't downgrade without checking the build still succeeds.

## Testing

- `test/widget_test.dart` — smoke test, app boots to login through the splash.
- `test/flow_test.dart` — full end-to-end journey: splash → login → coverage → catalog → cart → checkout → RICA → confirmation → dashboard → scan tab → support tab.
- `test/support_page_test.dart` — FAQ search/expand, ticket dialog validation.
- `test/free_wifi_test.dart` — ad-cap enforcement, session countdown, daily limit.

Run `flutter test` for all of them. Widget tests mock `shared_preferences` automatically in Flutter's test environment; no manual setup needed beyond `SharedPreferences.setMockInitialValues({})` where a test cares about a clean slate (see `free_wifi_test.dart`).

## Brand/theme

`lib/app/theme/app_theme.dart` derives light/dark `ColorScheme`s from `docs/brand-tokens.md`. Dark mode uses the brand's own dark-navy (`#00335C`), not a generic black, matching how the Sentech CI manual treats dark pages. The app bar carries a solid brand-colour background rather than sitting transparent, matching the CI manual's coloured-header convention (letterheads, newsletters, internal communiques all use a coloured band, never a colourless one).

Real logo assets live in `assets/brand/logo/`; `shared/widgets/sentech_logo.dart` picks the correct variant (full-colour on light, reversed white on dark) automatically based on `Theme.of(context).brightness`.
