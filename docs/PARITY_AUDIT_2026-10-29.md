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
| 1 | Subscriber plans and signup | `GET /v1/subscriber-plans` (recurring_hotspot, fixed_wireless; `kyc_required`, `setup_fee_cents`, price), `POST /v1/me/subscriber/signup` (201; 409 `active_service_exists`) | **Done (S1 data foundation, S5 plans and signup, S8 contact details):** plans list and detail, sign-up confirmation (`POST /v1/me/subscriber/signup`, one `Idempotency-Key` per draft, install address for fixed wireless, terms version from app-config, reloaded once on `consent_version_outdated`), Shop card, Account row, `subscriber_profile_invalid` leads to the contact details screen and back to the form with the draft intact; the stale `active_service_exists` is kept typed but never raised (P8) | open: platform P8 (several services per account rule); af/zu copy awaits native review | L | P1 |
| 2 | Subscriber account and services | `GET/PATCH /v1/me/subscriber`; `GET /v1/me/subscriber/services[/{id}]`; `POST .../cancel`, `.../change-plan` (statuses pending, active, suspended, cancelled; `paid_through`, `plan_change_on`, `cancel_effective_on`, `suspend_reason`) | **Done (S1, S3 services, S6 change plan, S7 cancel at period end, S8 contact details):** services list and detail with status banners (including "We are checking your ID" from the ID check status), change plan with confirm and result, cancel at period end with the computed date, contact details edit (`PATCH /v1/me/subscriber`) | open: platform P6 (cancel a pending service, undo a scheduled cancellation); no preview of a plan change amount (API has none) | L | P1 |
| 3 | Billing: invoices and pay | `GET /v1/me/subscriber/invoices[/{id}]`, `POST .../invoices/{id}/checkout` (CheckoutOut, 409 `invoice_not_payable`) | **Done (S2):** invoice list and detail, pay through the existing payment handoff (`POST .../invoices/{id}/checkout`), `invoice_not_payable` and `collection_mode_not_supported` typed | open: platform P11 (invoice PDF link), P12 (dev simulate for invoice payments unverified), P9 (code name for provider-collected money) | M | P2 |
| 4 | KYC / RICA | `GET/POST /v1/me/subscriber/kyc` (JSON capture; status none or record) | **Done (S4, decision D2):** ID check status (none, pending, verified, rejected) and a capture form posting to `POST /v1/me/subscriber/kyc` (ID type, number, address, one JPEG photo, consent); no liveness, no vendor; the mock `LivenessRepository` stays for SIM orders only | open: platform P7 (rejection reason, vendor reference and system verify path), P13 (privacy version as KYC consent); a certified liveness vendor is a later decision | M (L with a vendor) | P3 |
| 5 | Human check: config and attestation | Server accepts Turnstile token (login, delete-challenge, support, leads). `GET /v1/auth/human-check/config` proposed, not built. Play Integrity and App Attest not built either side | **Done for config (feat/p1-support-hc):** `HumanCheckGate` reads the route (API wins, build defines only as fallback), honours `required.*` and null site key; attestation still not built | attestation (Play Integrity, App Attest) | L | P0 |
| 6 | One-tap hotspot login | `POST /v1/me/hotspot/login-token` (201 `LoginTokenOut`: username, password, expires_at, optional controller handoff; needs MAC, flag `hotspot_radius`) | **Blocked** on owner questions Q1 (captive-portal deep link) and Q2 (router types), and platform P5b (bind the token to the first MAC) or the answer on the MAC source; S10 not started | the main "get online now" action for a pass holder; needs a MAC source (platform limits on iOS and Android 10+: see note) | M | P2 |
| 7 | Support | `POST /v1/support/messages` (202, Turnstile + Idempotency-Key); FAQ has no API | **Done (feat/p1-support-hc):** real send (`HttpSupportMessageRepository`) with the human check and a per-submission Idempotency-Key, reference shown; FAQ stays mock (`SupportRepository`, hidden in prod); `url_launcher` mailto only as the `support_contact_not_configured` fallback | none | S | P1 |
| 8 | Hotspots map | `GET /v1/hotspots` (id, name, lat, lon, status live or maintenance, address) | **Done** (branch `feat/p1-hotspots-cancel`): `HttpWifiHotspotsRepository` (`GET /v1/hotspots`, public, tenant-scoped, cursor pages), maintenance chip, address, empty and offline/error states; mock kept for demo only; removed from `stillMockInProd`; the finder is now offered in prod (Shop and order confirmation) | none | S | P1 |
| 9 | Coverage | `GET /v1/coverage/check`, `/coverage/meta`, `/geocode/search`, `/tiles/{layer}/{z}/{x}/{y}.mvt` (confidence, disclaimer_keys, `waitlist_available`, dataset_version) | mock (`MockCoverageRepository`) | real check, waitlist, tiles need a vector-tile renderer and a provider decision (OWNER_ACTIONS D6) | L | P4 |
| 10 | Account dashboard | No single dashboard route. Derived from entitlements, subscriber services and invoices | **Done (S9):** Home rebuilt from entitlements (passes), subscriber services, open invoices (`status=open`) and ID check status, gated on `subscriber_billing`; `MockAccountRepository`, `AccountCubit`, `AccountSummary` and the invented router, MAC suffix, signal bars, GB used and renewal date are deleted | open: platform P10 (fixed-wireless usage and CPE/router status); nothing is shown for them until then | M | P3 |
| 11 | Order cancel | `POST /v1/orders/{order_id}/cancel` (409 `order_not_cancellable`) | **Done** (same branch): `CheckoutRepository.cancelOrder` -> `POST /v1/orders/{id}/cancel`; "Cancel order" with a confirm dialog on the payment screen for an unpaid or failed order (never for paid or closed); `order_not_cancellable` / `order_cancelled` / `order_not_found` use the typed failures and the screen reloads the order after a refusal | none | S | P1 |
| 12 | Free Wi-Fi via rewarded ad | No API (credits, ads and referrals modules do not exist) | **Hidden in prod** (same branch): `lib/app/mock_feature_guard.dart` `freeWifiVisible` reads `stillMockInProd` (and the `credits` module once real); demo/dev/test still show it; code and mock kept; returns with the engagement-credits slices (platform plan `docs/superpowers/plans/2026-10-29-engagement-credits-rebaseline.md`) | real credits engine (G) | S now, L later | G (see gamification plan) |
| 13 | Promotions | No API (no offers route; M9 `GET /v1/me/deals` not built) | **Hidden in prod** (same branch): `promotionsVisible` (banner and `/promotions` route) from the same guard; returns with the engagement-credits slices (`GET /v1/me/deals`) | back with `/me/deals` (G) | S | G |
| 14 | Push notifications | No customer route to register a device; the API only sends SMS and email. M13 push design is not built | local notifications only (`lib/core/notifications`, usage alerts) | needs API `push_device` first; blocks streak reminders and expiry warnings | M each side | G, after P3 |
| 15 | Error-code coverage | see section above | **Done for the listed codes:** the 15 listed codes typed (added in `feat/contract-resync`, af/zu copy awaiting native review); the screens that raise them are still to build | none for typing; screens per their own rows | S | ride along |
| 16 | `GET /v1/me` | `sub, roles, tenant_id, email` | unused (app reads `/v1/me/profile`) | none needed; do not add | none | skip |
| 17 | Contract snapshot | `9d3cba5` | `39f5a44` | **Done** (branch `feat/contract-resync`): snapshot re-synced to platform `d4be7ce`, suspended-in-current fixture and tests added, `BACKEND_CONTRACT_SYNC.md` Known gap 2 closed | S | P0 |

Rows that are already **real** and match the API: tenants, app-config (modules, flags, `collection_mode_public`, legal, support), OTP request and verify with binding, token refresh and logout, profile get and patch, consents get and post (`consent_version_outdated`), export, delete challenge and delete, products, orders create, list, get, checkout (`order_not_payable`), entitlements (all statuses, origins, scope kinds), voucher redeem (`voucher_invalid`).

Note on rank 6: the login token is "bound to the device MAC". Android 10+ and iOS hide the real MAC from apps, so the app may not be able to supply it. Open question for the API owner: does the controller handoff (`nas_id` + `login_url`) work without a MAC from the app? This needs a written answer before building (see open questions).

## Subscriber track status (2026-10-30)

Slices S1 to S9 are merged (rows 1, 2, 3, 4, 10 done; plan `docs/superpowers/plans/2026-10-30-subscriber-account-slices.md`), plus the loose ends S8 contact details, the signup terms reload and the "We are checking your ID" banner. Still open:

- Row 6 one-tap login (S10): blocked on owner Q1 and Q2; platform P5b.
- Platform tasks that the app waits for: P5b (MAC binding), P6 (cancel a pending service, undo cancellation), P7 (KYC rejection reason, vendor path), P8 (several services per account), P9 (provider-collected code name), P10 (fixed-wireless usage and CPE status), P11 (invoice PDF), P12 (dev simulate for invoice payments), P13 (KYC consent version).
- af and zu copy for all subscriber screens is a machine draft listed in `docs/L10N_NEEDS_NATIVE_REVIEW.md`.

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
