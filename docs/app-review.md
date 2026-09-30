# Sentech Connect — Engineering Review (Sept 2026)

Scope: every feature flow, repository/cubit, Android config and the test setup, read against what a production 5G FWA subscriber app needs. The app is explicitly a UI + mock phase (see README), so findings are split into **fix now** (real defects or cheap hardening that don't depend on a backend) and **design for the backend phase** (things that must not be carried over from mock behaviour).

Severity: **H** = blocks a real release / user-data risk, **M** = should fix before pilot, **L** = polish.

---

## 1. Fixed in this pass

| Item | Change |
|---|---|
| Release builds had no `INTERNET` permission (only debug/profile manifests declared it), so map tiles and every future API call would fail in the release APK | Added to `android/app/src/main/AndroidManifest.xml` |
| 10 s "added to cart" snackbar sat on top of the cart page's Checkout button | Shortened to 3 s |
| `mobile_scanner` 7 API change (`errorBuilder` signature) | Updated `voucher_scanner_page.dart` |
| Tests hit the real OpenStreetMap tile server and did not isolate SharedPreferences / DI | `test/helpers/test_setup.dart` (offline tile provider, mock prefs, fresh locator per test) |

---

## 2. Security and privacy

| # | Sev | Finding | Recommendation |
|---|---|---|---|
| S1 | H | **"Log in with Face ID" is fake.** `logInWithBiometrics()` returns the demo user with no biometric check (no `local_auth`). Anyone who taps the button is in. Label is also iOS-specific on an Android-only build. | Use `local_auth`, gate it behind a previously authenticated session, and rename to "Use biometrics". |
| S2 | H | **PII stored in plaintext `SharedPreferences`**: user id/name/mobile (`AppPreferences`), and full registration details including email, home address and GPS coordinates (`LocalRegistrationRepository`). Logout clears the user keys but **not** the registration details. | Move to `flutter_secure_storage` (Keystore-backed). Wipe everything on logout. Don't persist GPS coordinates at all unless the backend needs them. |
| S3 | H | **No real session/token model.** "Logged in" = a user record on disk. Anyone with file access or a rooted device can forge it. | When the backend lands: OIDC via `flutter_appauth` (already planned), tokens in secure storage, refresh handling, server-side revocation. |
| S4 | H | **Payment happens before RICA.** Customer is charged, cart is cleared, *then* identity verification runs. If RICA fails (`RicaStatus.failure`) there is no retry path or recovery: the order only lives in `GoRouterState.extra`. | Reverse the order or make the order a persisted, resumable entity ("paid — awaiting verification") with a retry screen. |
| S5 | H | **Voucher redemption is client-side theatre.** `_redeem` accepts *any* scanned QR payload or typed string, shows "redeemed — data added", and echoes the raw payload into the UI. A malicious QR can put arbitrary text in front of the user; a real voucher could be redeemed twice. The 2 s `_handled` reset means a QR in view is re-"redeemed" in a loop. | Validate format client-side, send to an idempotent server endpoint, show server result only, never echo raw payload, stop scanning until dismissed. |
| S6 | M | **Free-WiFi daily cap and session are enforced on-device** (prefs + `DateTime.now()`): clear app data or change the clock to get unlimited sessions. `recordAdWatched` also increments *before* the limit check, so the 4th attempt mutates the count. | Server-side entitlement; use server time; real ad-network SSV (server-side verification) callbacks. |
| S7 | M | **No route guards.** `/main`, `/checkout`, `/rica` are reachable without a session (deep links, restored state). `state.extra as Order` throws on null (process death / deep link). | `GoRouter.redirect` + `refreshListenable` on `AuthCubit`; pass an order *id* in the path and load it. |
| S8 | M | **Cart survives logout** by design (see comment in `app.dart`). On a shared device the next user sees it. | Clear cart on logout, or persist per-user. |
| S9 | M | **Release signing uses the debug keystore**; `applicationId` still carries the template TODO. | Real keystore via `key.properties` + Play App Signing. Decide the final application id *now* — it can't change after publishing. |
| S10 | M | **Public OSM tile servers are not for production apps** (flutter_map prints this warning). User viewport also leaks location to the tile host. | Commercial tile provider (MapTiler/Stadia/Mapbox) or self-hosted, key restricted to the app. |
| S11 | M | **No POPIA scaffolding**: no consent record (timestamp/version), no data-export/delete request path, no privacy policy link, no in-app **account deletion** (also a Google Play requirement). Location consent is implicit in the permission prompt only. | Consent screen with stored record before location and RICA capture; "Delete my account/data" in Account; privacy policy link. |
| S12 | M | **RICA capture has no screen-capture protection.** | `FLAG_SECURE` on RICA and account screens. |
| S13 | M | **No certificate pinning / `network_security_config`**, and the plan (prompt-critique.md) had no pin-rotation story. | Add `network_security_config` (cleartext off) now; pinning with backup pins + remote kill-switch when real endpoints exist. |
| S14 | L | `catch (_) {}` swallows errors in registration, geocoding and location with no logging. | Central error reporting (Crashlytics/Sentry) with PII scrubbing. |
| S15 | L | Dependency supply chain: no `dart pub audit`/Dependabot/CI. Release uses `--obfuscate` but no R8/ProGuard review. | Add Dependabot + a CI job running `flutter pub outdated`/OSV scan. |

---

## 3. Correctness and robustness

| # | Sev | Finding |
|---|---|---|
| C1 | M | **Money is `double`** (`priceRands`, `lineTotal`, totals). Use integer cents (or `Decimal`) and let the server own totals. |
| C2 | M | **No input validation anywhere.** Login only checks non-empty; registration has keyboard types but no validators (email format, SA mobile number `0XX XXX XXXX` / `+27`, address required). Nothing is normalised before it is stored. |
| C3 | M | **Failure paths are never exercised.** Mock repos always succeed, so `NetworkFailure`, retry UI, empty states and timeouts are unbuilt/untested (e.g. checkout `failure` has no retry; `RicaStatus.failure` has no UI path forward). |
| C4 | M | **Location**: `getCurrentPosition` has no timeout (can hang); `deniedForever` isn't routed to app settings (`Geolocator.openAppSettings`); `ACCESS_FINE_LOCATION` requested when coarse would do for a coverage check; `high` accuracy drains battery. |
| C5 | M | **Async cubit work doesn't check `isClosed`** (e.g. `AuthCubit.logIn`, `CheckoutCubit.pay` after the user backs out) — can throw "emit after close". |
| C6 | M | **Double-submit**: `pay()` has no idempotency key; order number is a constant (`SEN-48213`). |
| C7 | L | Persistence writes are fire-and-forget (`AppPreferences.saveUser(user)` not awaited). |
| C8 | L | `copyWith` patterns can't set nullable fields back to null (`errorMessage` works only because it isn't coalesced; `user` can't be cleared) — easy to introduce bugs as state grows. |
| C9 | L | Placeholder WhatsApp number `270000000000` and hard-coded 1.3 s splash delay are still in code. |
| C10 | L | Support "ticket" is a `mailto:` hand-off: no reference number, no account/device context, fails without a mail app, nothing to track. |
| C11 | L | `flow_test` couples to fixed pump durations; the forever-running scan-line animation in the kept-alive scanner tab forces that. Pause the animation when the tab isn't active (it already gets `TickerMode`) or disable it under test. |

---

## 4. Architecture

- **Good:** clean feature-first layering, repositories behind interfaces, a single DI file, Either-based failures, cubits are small and readable.
- **Leaks in the seam:** `AuthCubit` calls static `AppPreferences` directly, and `MockFreeWifiRepository` *is* `AppPreferences`. A backend swap would miss these. Put session persistence behind a `SessionStore` interface registered in the locator; do the same for preferences.
- **Static singletons are untestable**; inject `SharedPreferences` (or a store) instead of `getInstance()` everywhere.
- **Navigation passes domain objects via `extra`**, which doesn't survive process death or deep links. Use path params/ids.
- **Missing cross-cutting pieces the critique doc already called for:** HTTP client + interceptors (Dio), environment flavors (`demo` vs `prod`), logging, feature flags, secure storage wrapper. None exist yet; the demo flavor in particular would make "mock vs real" explicit.
- **Dependencies are now current** (go_router 18, flutter_map 8, geolocator 14, mobile_scanner 7, get_it 9, equatable 3). JDK 25 is set as the Java/Kotlin target in `build.gradle.kts` while the README says "JDK 17+" — pick one and document it, or CI will break on machines without JDK 25.

---

## 5. Mobile-app-specific gaps

| Area | Gap | Suggestion |
|---|---|---|
| Offline / connectivity | No offline state at all; FWA customers are precisely the people whose connection may be down when they open the app to report it | Offline banner, cached last-known dashboard, "report outage" that queues and sends later (or SMS/USSD fallback) |
| Push | Registration collects "push" marketing consent but no FCM/notification plumbing exists | FCM + notification categories (usage thresholds, outage, order status) and Android 13+ `POST_NOTIFICATIONS` prompt with rationale |
| Lifecycle | Cart and in-flight checkout aren't persisted; killing the app mid-flow loses state | Persist cart; resumable order state |
| Platform | Only `android/` and `web/` exist — **no `ios/`** | Decide scope; run `flutter create --platforms=ios .` if iOS is required (and fix the "Face ID" wording properly) |
| Accessibility | No semantics labels beyond defaults, no text-scale testing, colour contrast of brand red on white/dark untested, small `IconButton` compact targets | Semantics pass, 200 % text-scale golden tests, 48 dp targets |
| Localisation | Every string hard-coded in English; South Africa has 11 official languages | `flutter_localizations` + ARB files; start with en + one of zu/af/xh to prove the pipeline |
| Performance | `IndexedStack` keeps all five tabs (incl. camera and map) alive | Fine functionally, but lazily build tabs on first visit and dispose the map/camera off-screen |
| Real telco features absent | live usage/CPE telemetry, invoices and payment history, installation booking/order tracking, router management (Wi-Fi name/password, reboot), speed test, outage status, profile editing | Prioritise with the backend contract; usage + invoices + outage status are the highest-value for FWA |
| Release engineering | No CI, no flavors, no crash reporting/analytics, no in-app update prompt, no store listing assets | GitHub Actions: analyze + test + build APK/AAB; Sentry/Crashlytics; `in_app_update` |

---

## 6. Test setup

Current: 4 files, 8 tests, all widget tests, one giant end-to-end flow.

- **Done:** shared `setUpAppTests()` (offline map tiles, mocked prefs, fresh DI per test); flow test made robust to slower transitions.
- **Next:** cubit unit tests with `bloc_test` + `mocktail` (cart rules — one Home 5G plan max; free-WiFi cap/expiry; checkout paying→paid/failure; registration location states); failure-path tests using stub repositories that return `Left(...)`; golden tests for key screens in light/dark/large-text; an `integration_test/` smoke run on an emulator in CI; coverage gate (`flutter test --coverage`).

---

## 7. Suggested order of work

1. **Before anyone demos a release APK:** S1 (fake biometric), S9 (signing/app id), S10 (tile provider), S5 (voucher redeem message), INTERNET fix (done).
2. **Backend-prep sprint:** SessionStore + secure storage (S2/S3), router guards + id-based routes (S7), money as integer cents (C1), validators (C2), `isClosed` guards (C5), Dio client + flavors.
3. **Compliance:** POPIA consent/delete flows (S11), FLAG_SECURE (S12), network security config/pinning (S13), RICA-before-fulfilment ordering (S4).
4. **Product depth:** offline/outage handling, push, usage + invoices, localisation, accessibility pass, CI and crash reporting.

---

## 8. Status: client-side remediation (Oct 2026)

What the mobile app can do alone is done; items marked "backend" need a server, "owner" needs a decision or credential. `flutter analyze`: 0 issues, `flutter test`: all green.

| Finding | Status |
|---|---|
| S1 fake biometrics | Done. `local_auth` behind `BiometricAuthenticator`; button hidden unless a session was established on the device and a biometric is enrolled; label "Use biometrics"; handles cancelled / not enrolled / unavailable / lockout. |
| S2 plaintext PII | Done. `SecureStore` (`flutter_secure_storage`) + `SessionStore`; GPS no longer persisted; logout/delete wipe session, registration, orders, free-WiFi grant and cart. `AuthCubit` no longer touches static prefs. |
| S3 real session/tokens | Backend (OIDC). `SessionStore` is the seam. |
| S4 pay before RICA | Done by reversing the order: create order -> RICA -> pay -> confirmation, persisted and resumable (dashboard banner, retry on RICA/payment failure). |
| S5 fake voucher redeem | Client side done (format validation, typed outcomes, masked code, scan paused until dismissed). Real validation/idempotency: backend. |
| S6 free-WiFi bypass | Mitigated only (monotonic + anchored clock, backwards-clock detection, cap checked before increment). Cannot be fixed client-side: needs a server entitlement API. |
| S7 route guards | Done (redirect + refreshListenable, id-based routes, no `extra` casts). |
| S8 cart survives logout | Done. |
| S9 signing / app id | Seam done (`android/key.properties`, single `sentech.applicationId`, JDK 17). Owner: keystore and final application id. |
| S10 OSM tiles | Seam done (`--dart-define` provider, placeholder in release, attribution). Owner: commercial provider + key. |
| S11 POPIA | Client side done (versioned consent before location and RICA, delete/export requests, privacy link placeholder). Backend: real deletion/export endpoints; owner: policy URL and legal review of wording. |
| S12 FLAG_SECURE | Done (RICA + Account). |
| S13 network security | Cleartext disabled. Pinning deferred until real endpoints exist. |
| S14 error reporting | Interface + global handlers + PII scrubbing done; some `catch (_)` sites still silent. Owner: Sentry/Crashlytics choice. |
| S15 supply chain | CI (analyze, test --coverage) and Dependabot added. |
| C3/C5/C6 | Offline retry UI on checkout, coverage, catalog, dashboard; `isClosed` guards on new async work; double-submit guards and unique order numbers. |
| Mobile gaps | Offline banner, notification permission flow (FCM needs Firebase config: owner), localisation pipeline (en/zu/af for login, registration, account, support; rest is follow-up; zu/af need native review), accessibility pass, iOS project generated (owner: Apple team id and bundle id). |

Not done client-side: money as integer cents (C1), input validators (C2), location timeout/settings routing (C4), full string migration, APK build verification (no Android SDK on the build machine that produced this change).
