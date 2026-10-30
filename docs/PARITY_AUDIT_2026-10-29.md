# Parity audit: mobile app against the platform API (2026-10-29)

Question from the owner: does the app match the main app (the platform API)? Short answer: **no. The app covers the hotspot-pass customer (sign-in, privacy, catalog, orders, payment, passes, voucher redeem) for real, and nothing else.** The recurring-subscriber lane, one-tap hotspot login, support, coverage, hotspots and the account dashboard are missing or mock.

> **Plan for rows 1, 2, 3, 4, 6 and 10:** `docs/superpowers/plans/2026-10-30-subscriber-account-slices.md` (API facts read from platform source, ten slices, decisions, owner questions, platform tasks). It corrects two audit assumptions: the platform never emits `active_service_exists`, and KYC has no liveness step (staff verify a JSON capture).

## Method

- API side: platform repo `origin/codex/naas-implementation` at `9d3cba5`: `apps/api/openapi.json` (340 operations), routers under `apps/api/src/sentech_api/modules/`, error codes in the customer routers, `entitlements/repository.py`, `tenants/flags.py`, `plan_modules/catalog.py`.
- App side: this repo at `9b3340f`: `lib/` (204 Dart files), `lib/app/locator.dart` (`stillMockInProd`), `lib/core/network/api_problem.dart`, `test/contract/openapi.json`, and `docs/BACKEND_CONTRACT_SYNC.md` (the 2026-10-26 sync at `39f5a44`).
- Diff of the app's snapshot against `9d3cba5`: **the same 340 operations; no customer or public route was added, removed or renamed.** Only admin schemas changed (`ReconMatchOut`, `SettlementBatchOut`, `SettlementBatchDetailOut`, new `SettlementWaitingLineOut`, all admin) and the `Branding` description text (an encoding difference, no field change). The app's gaps are therefore not drift; they are work that was never started (the M3 block) plus three behaviour changes below.
- Not run: no Flutter toolchain, no API stack. Everything below is read from code and the OpenAPI file.

## What changed since the last sync (behaviour, not routes)

| Change | Evidence | App effect |
|---|---|---|
| `GET /v1/me/entitlements?status=current` now **includes `suspended` passes**, even past `expires_at` (list only; RADIUS and vouchers still require `active`). Closes "Known gap 2" in `BACKEND_CONTRACT_SYNC.md`. | `apps/api/src/sentech_api/modules/entitlements/repository.py:78-82` | None needed to show them: `PassSummary.of` (`lib/features/passes/presentation/pass_summary.dart:34`) already treats suspended as the server's word and `UsageAlertPolicy` skips them. Add a fixture with a suspended pass past `expires_at` and a widget test that it shows under "current". S. |
| Human-check config route `GET /v1/auth/human-check/config` is **still not in the API** (no route, not in OpenAPI). OTP request needs a human-check token in staging and prod (`config.py:914-920` `otp_human_check_required`). | grep of `apps/api/src`, `openapi.json` | Unchanged: the app takes `TURNSTILE_SITE_KEY` and `TURNSTILE_BASE_URL` as build defines. The gap stays open (item 2 below). |
| `POST /v1/support/messages` also requires a Turnstile token and an `Idempotency-Key`. | OpenAPI description of `/v1/support/messages` | The app's human check is wired only for OTP request and delete-challenge. Support must use it too when it goes real. |
| Entitlement `origin_type` already allows `free_time`, `credits`, `sponsored`, `roaming`; `source` allows only `order, voucher, admin, service`. | `entitlements/schemas.py:11-15`, migration 0049 | App already types all four origins (`PassOrigin`); `PassSource` falls back to `unknown`. No change. A `credits` source will need a contract bump when the credits engine lands (see the gamification plan). |
| The new 409 reconciliation error codes and the settlement changes are admin or platform side. | `components.schemas` diff | Not for the app. |
| Module catalog now lists `credits, listings, zones, wifi_aware, sponsorship, marketplace, tickets` as module keys. The app reads `modules` as an open map and knows five keys. | `plan_modules/catalog.py` | Fine; add keys only when a screen exists. |

## Typed problem codes the app does not handle

The app maps 10 codes (see `BACKEND_CONTRACT_SYNC.md`). Customer routers emit more; each falls through to a generic failure today. Codes read from `apps/api/src/sentech_api/modules/{orders,hotspot,subscribers,support,vouchers}/router*.py`:

| Code | Route | Needed for |
|---|---|---|
| `feature_disabled` (409) | vouchers redeem, hotspot login-token, orders | any flag-gated screen (show "not available from your provider" instead of an error) |
| `order_not_cancellable`, `order_cancelled`, `order_not_found` | orders cancel and read | order cancel (item 7) |
| `no_active_entitlement`, `mac_invalid`, `nas_unavailable`, `login_url_invalid`, `controller_not_supported` | `POST /v1/me/hotspot/login-token` | one-tap login (item 3) |
| `invoice_not_payable`, `customer_link_required`, `subscriber_profile_invalid` | subscriber invoices, signup, profile | M3 (item 1) |
| `support_unavailable`, `support_contact_not_configured`, `invalid_message`, `invalid_contact` | support messages | support (item 4) |

`429` is already generic (`RateLimitedFailure` with `Retry-After`).

## Parity table

Status: **real** (HTTP repository, contract-tested), **mock** (`Mock*Repository` in prod, listed in `stillMockInProd`, `lib/app/locator.dart:79`), **missing** (no code). Effort: S under 1 day, M 1 to 3 days, L over 3 days. Ordered by rank.

| Rank | Area | API capability | App state | Gap | Effort | Slice |
|---|---|---|---|---|---|---|
| 1 | Subscriber plans and signup | `GET /v1/subscriber-plans` (recurring_hotspot, fixed_wireless; `kyc_required`, `setup_fee_cents`, price), `POST /v1/me/subscriber/signup` (201; 409 `active_service_exists`) | missing (typed failures only) | whole plan picker, signup form, KYC branch | L | P1 |
| 2 | Subscriber account and services | `GET/PATCH /v1/me/subscriber`; `GET /v1/me/subscriber/services[/{id}]`; `POST .../cancel`, `.../change-plan` (statuses pending, active, suspended, cancelled; `paid_through`, `plan_change_on`, `cancel_effective_on`, `suspend_reason`) | missing | service list and detail, change plan, cancel at period end, suspended banner with reason | L | P1 |
| 3 | Billing: invoices and pay | `GET /v1/me/subscriber/invoices[/{id}]`, `POST .../invoices/{id}/checkout` (CheckoutOut, 409 `invoice_not_payable`) | missing | invoice list and detail, pay via existing payment handoff (reuse `PaymentHandoff` and web view) | M | P2 |
| 4 | KYC / RICA | `GET/POST /v1/me/subscriber/kyc` (JSON capture; status none or record) | mock: `LivenessRepository` and `RicaCubit` use a fake liveness check | decide: capture form posting to the API plus a certified liveness vendor, or API-side capture only | M (L with a vendor) | P3 |
| 5 | Human check: config and attestation | Server accepts Turnstile token (login, delete-challenge, support, leads). `GET /v1/auth/human-check/config` proposed, not built. Play Integrity and App Attest not built either side | **Done for config (feat/p1-support-hc):** `HumanCheckGate` reads the route (API wins, build defines only as fallback), honours `required.*` and null site key; attestation still not built | attestation (Play Integrity, App Attest) | L | P0 |
| 6 | One-tap hotspot login | `POST /v1/me/hotspot/login-token` (201 `LoginTokenOut`: username, password, expires_at, optional controller handoff; needs MAC, flag `hotspot_radius`) | missing | the main "get online now" action for a pass holder; needs a MAC source (platform limits on iOS and Android 10+: see note) | M | P2 |
| 7 | Support | `POST /v1/support/messages` (202, Turnstile + Idempotency-Key); FAQ has no API | **Done (feat/p1-support-hc):** real send (`HttpSupportMessageRepository`) with the human check and a per-submission Idempotency-Key, reference shown; FAQ stays mock (`SupportRepository`, hidden in prod); `url_launcher` mailto only as the `support_contact_not_configured` fallback | none | S | P1 |
| 8 | Hotspots map | `GET /v1/hotspots` (id, name, lat, lon, status live or maintenance, address) | **Done** (branch `feat/p1-hotspots-cancel`): `HttpWifiHotspotsRepository` (`GET /v1/hotspots`, public, tenant-scoped, cursor pages), maintenance chip, address, empty and offline/error states; mock kept for demo only; removed from `stillMockInProd`; the finder is now offered in prod (Shop and order confirmation) | none | S | P1 |
| 9 | Coverage | `GET /v1/coverage/check`, `/coverage/meta`, `/geocode/search`, `/tiles/{layer}/{z}/{x}/{y}.mvt` (confidence, disclaimer_keys, `waitlist_available`, dataset_version) | mock (`MockCoverageRepository`) | real check, waitlist, tiles need a vector-tile renderer and a provider decision (OWNER_ACTIONS D6) | L | P4 |
| 10 | Account dashboard | No single dashboard route. Derived from entitlements, subscriber services and invoices | **Done (S9):** Home rebuilt from entitlements (passes), subscriber services, open invoices (`status=open`) and ID check status, gated on `subscriber_billing`; `MockAccountRepository`, `AccountCubit`, `AccountSummary` and the invented router, MAC suffix, signal bars, GB used and renewal date are deleted; router/CPE status and fixed-wireless usage show nothing until platform task P10 | rebuild from real data once ranks 1 to 3 exist; remove invented fields (router, MAC suffix, signal) | M | P3 |
| 11 | Order cancel | `POST /v1/orders/{order_id}/cancel` (409 `order_not_cancellable`) | **Done** (same branch): `CheckoutRepository.cancelOrder` -> `POST /v1/orders/{id}/cancel`; "Cancel order" with a confirm dialog on the payment screen for an unpaid or failed order (never for paid or closed); `order_not_cancellable` / `order_cancelled` / `order_not_found` use the typed failures and the screen reloads the order after a refusal | none | S | P1 |
| 12 | Free Wi-Fi via rewarded ad | No API (credits, ads and referrals modules do not exist) | **Hidden in prod** (same branch): `lib/app/mock_feature_guard.dart` `freeWifiVisible` reads `stillMockInProd` (and the `credits` module once real); demo/dev/test still show it; code and mock kept; returns with the engagement-credits slices (platform plan `docs/superpowers/plans/2026-10-29-engagement-credits-rebaseline.md`) | real credits engine (G) | S now, L later | G (see gamification plan) |
| 13 | Promotions | No API (no offers route; M9 `GET /v1/me/deals` not built) | **Hidden in prod** (same branch): `promotionsVisible` (banner and `/promotions` route) from the same guard; returns with the engagement-credits slices (`GET /v1/me/deals`) | back with `/me/deals` (G) | S | G |
| 14 | Push notifications | No customer route to register a device; the API only sends SMS and email. M13 push design is not built | local notifications only (`lib/core/notifications`, usage alerts) | needs API `push_device` first; blocks streak reminders and expiry warnings | M each side | G, after P3 |
| 15 | Error-code coverage | see section above | **Done for the listed codes:** the 15 listed codes typed (added in `feat/contract-resync`, af/zu copy awaiting native review); the screens that raise them are still to build | none for typing; screens per their own rows | S | ride along |
| 16 | `GET /v1/me` | `sub, roles, tenant_id, email` | unused (app reads `/v1/me/profile`) | none needed; do not add | none | skip |
| 17 | Contract snapshot | `9d3cba5` | `39f5a44` | **Done** (branch `feat/contract-resync`): snapshot re-synced to platform `d4be7ce`, suspended-in-current fixture and tests added, `BACKEND_CONTRACT_SYNC.md` Known gap 2 closed | S | P0 |

Rows that are already **real** and match the API: tenants, app-config (modules, flags, `collection_mode_public`, legal, support), OTP request and verify with binding, token refresh and logout, profile get and patch, consents get and post (`consent_version_outdated`), export, delete challenge and delete, products, orders create, list, get, checkout (`order_not_payable`), entitlements (all statuses, origins, scope kinds), voucher redeem (`voucher_invalid`).

Note on rank 6: the login token is "bound to the device MAC". Android 10+ and iOS hide the real MAC from apps, so the app may not be able to supply it. Open question for the API owner: does the controller handoff (`nas_id` + `login_url`) work without a MAC from the app? This needs a written answer before building (see open questions).

## Suggested slice order

The owner's v1 is "all planned items plus an updated app". Order by what a paying customer needs first, and by dependency.

- **P0 (S + M, do first):** re-sync the contract and the suspended fixture (17); human-check config endpoint on the API plus the app reading it (5, Tier B only). Attestation (Tier A) is a separate, later slice.
- **P1 (S each, parallelisable):** support send (7), hotspots (8), order cancel (11), typed codes (15). Remove or hide the mock-backed free Wi-Fi and promotions cards in prod (12, 13).
- **P2 (M):** subscriber invoices and pay (3) needs P3 first for the account; hotspot login token (6) after the MAC question is answered.
- **P3 (L):** subscriber plans, signup, services, change plan, cancel (1, 2), with `subscriber_billing` module gate; KYC (4) in the same slice because plans can be `kyc_required`; then the dashboard (10) from real data.
- **P4 (L):** coverage check, waitlist and tiles (9), after the tile provider decision.
- **G:** engagement and credits (12, 13, 14) per `docs/superpowers/plans/2026-10-29-engagement-credits-rebaseline.md` in the platform repo. It cannot start in the app until the API has the credits module and the push device route.

Dependencies: 3 depends on 1 and 2 (an invoice belongs to a service); 10 depends on 1 to 3; 14 depends on an API route that does not exist; 5 (Tier A) depends on the API's attestation verifier, which does not exist.

## Housekeeping to fold into `BACKEND_CONTRACT_SYNC.md` with P0

- Known gap 2 is resolved on the API: change to "fixed in the platform at `9d3cba5`; app unchanged".
- Add the support-message Turnstile requirement to the "Human check" section.
- Update the snapshot line to `9d3cba5` after the re-sync.
- The "not started" statuses in the route table stay accurate; this document is the ranked view of them.

## Open questions

1. Hotspot login without a MAC: can the app request a token without a MAC (controller handoff only), or is a MAC mandatory for every flavor?
2. Which customers does v1 target first: hotspot-pass buyers (done) or recurring subscribers (P3, large)? The ranking assumes both are v1 because the API gates both.
3. RICA/KYC: does the API-side capture suffice (the `/v1/me/subscriber/kyc` JSON), or must the app add a certified liveness vendor (Smile Identity was the prior recommendation)?
4. Map tiles for coverage: provider decision (OWNER_ACTIONS D6) before P4.
5. Should the prod flavor hide the mock-backed free Wi-Fi and promotions cards now? Recommended default (assumption): yes, behind the `credits` and `vouchers` module flags, until the API exists.
