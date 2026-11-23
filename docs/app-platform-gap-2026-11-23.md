# App vs platform API: gap report (2026-11-23)

Derived from two files and the app's `lib/` code, nothing else: the app's snapshot before this task (platform `ab5247a` era plus the 5G sync, 330 paths, 387 operations) and the platform's `apps/api/openapi.json` at `f58b00cf` (548 paths, 635 operations), now the snapshot in `test/contract/openapi.json`. "Used" means a route string or decoder exists in `lib/`. Where a fact cannot be read from these sources it says "unknown".

## 1. What this task did

- `feat/5g-usage-unlock` (2 commits, tip `fc7a39f`) fast-forwarded into `feat/app-g7-0` (no conflicts). Before the re-sync: `flutter analyze` no issues; full `flutter test` 2,054 passed, 1 skipped.
- Snapshot re-synced (commit `ccda12a`). After: `flutter analyze` no issues; full `flutter test` 2,054 passed, 1 skipped (the contract test, including every fixture check, passed with no fixture or model change).

## 2. Contract size

| | Paths | Operations | `/v1/admin/*` | `/v1/platform/*` | Customer and public |
|---|---|---|---|---|---|
| Old snapshot | 330 | 387 | unknown (not split) | unknown (not split) | unknown |
| New (f58b00cf) | 548 | 635 | 367 | 195 | 73 |

249 operations were added and 1 removed. The removed one is `GET /v1/admin/subscribers/export` (staff only). Of the 249 added, 10 are customer or public (listed below); all others are `/v1/admin/*` (store 115, tickets 15, coverage 14, credits 13, network 5, and smaller groups) or `/v1/platform/*` (network 27, assurance 6, tickets 8, staff 4, credits 4, incidents 3, coverage-demand 1).

## 3. Incompatible changes to what the app already uses

None found. Every schema diff for a customer route is additive:

| Schema | Change | Effect on the app |
|---|---|---|
| `OtpRequestIn`, `OtpVerifyIn`, `TokenPairOut` | optional `device_token` added | App neither sends nor reads it. Unused, not breaking. It would give the device a reserved OTP budget for the phone (see the field description), so it is a P2 hardening, not a requirement |
| `KycOut` | `has_document` added; `consent_via` enum gains `store` | App does not read either; the app always sends `consent_via: app` |
| `sentech_api__modules__subscribers__schemas__PlanOut` (public subscriber plans) | `min_band_key`, `required_technology`, `sell_without_band` added | Ignored by the app. Unknown whether the platform now refuses a signup for a plan the address cannot be served by, and with which problem code; the signup route's request and response did not change |
| `FeatureFlags` | `ticketing` added (default false) | Not read by the app |
| `CoverageMetaOut` | `coverage_arrived_consent_version` now required | App's coverage is a mock, no decoder reads it |
| `CoverageCheckOut` | `band`, `options`, `nearest`, `primary_index` and provenance fields added | Same, mock only |
| `POST /v1/leads` | request and response changed | Not used by the app (marked "not for the app" in the sync doc) |

No operation used by the app changed its parameters, request body or responses (operation-level diff checked for all 635; the changed ones are all admin, platform or `POST /v1/leads`). No schema was removed.

## 4. Customer-facing areas the app does not yet use

| Area | Platform routes (operations) | Audience | App status | Recommended priority for a customer app |
|---|---|---|---|---|
| Credits (G7) | `GET /v1/me/credits`, `/credits/ledger`, `POST /credits/redeem`, `GET /me/missions`, `/me/badges`, `/me/streak`, `POST /me/streak/claim` (7; already in the old snapshot) | Customer | No code in `lib/` (no `credits` feature) | P1: this is G7 |
| Support tickets | `GET/POST /v1/me/tickets`, `GET /me/tickets/categories`, `GET /me/tickets/{reference}`, `POST .../close`, `POST .../messages` (6, new); `GET /v1/support/incidents` (1, public, new); flag `FeatureFlags.ticketing` | Customer | Not used. The app only has the public one-way `POST /v1/support/messages`; `SupportRepository` (help content) is still a mock (`stillMockInProd`) | P1: a real Help and "raise a ticket" flow replaces the mock; also show current incidents on Help or Home |
| Coverage (CV17) | `GET /v1/coverage/check`, `/coverage/meta`, `GET /v1/geocode/search`, `GET /v1/tiles/{layer}/{z}/{x}/{y}.mvt`, `POST /v1/coverage/address` (new), `GET /v1/coverage/capabilities` (new), `POST /v1/leads`, `POST /v1/leads/withdrawal-requests` (new), `POST /v1/leads/withdrawals` (new) (9) | Customer and public | Mock only (`CoverageRepository` is in `stillMockInProd`; no HTTP coverage repository) | P1: check coverage, then register interest (notify me) and withdraw it. Without this the app cannot gate fixed-wireless signup by band. Depends on the `modules`/flags in app-config (unknown which) |
| Subscriber self-service, remainder | none missing: `GET /v1/me/subscriber` and `PATCH`, `signup`, `services`, `services/{id}`, `cancel`, `change-plan`, `kyc` GET and POST, `invoices`, `invoices/{id}`, `invoices/{id}/checkout` are all used (`lib/features/subscriber`). `GET /v1/me` is not used (app reads `/me/profile`) | Customer | Done. `docs/BACKEND_CONTRACT_SYNC.md` rows for `cancel`, `change-plan` and `PATCH /me/subscriber` still say "not started" although code exists: the doc is stale | P3: refresh the doc |
| Invoices and payments | `invoices` list, detail, checkout (3) and orders list, create, get, checkout, cancel (5) used. `GET/POST /v1/pay/{tenant_slug}/{invoice_id}/{token}` (2) is the public web pay page | Customer, web | Used by the app; pay page is web, not for the app | None |
| 5G usage and unlock | `GET .../services/{id}/data`, `POST .../data/unlock-orders` | Customer | Used (merged this task) | None |
| Router and Wi-Fi settings | No customer route. The only router routes are staff: `/v1/admin/tickets/{ticket_id}/router`, `/router/operations`, `/router/wifi`, `/v1/platform/tickets/{ticket_id}/router`, `/router/refresh`, plus `/v1/admin/network/cpe-*` and `/device-management/*` | Staff only | n/a | Not available to a customer app today. Customer-side change of Wi-Fi name or password would need a new platform route (unknown whether planned) |
| Notifications and push | No device-token or push registration route exists in the contract (searched paths for push, device, notif). Staff `admin/messaging` (7) is outbound email and SMS tooling. The `device_token` field above is for OTP, not push | n/a | The app has local notification code (`lib/core/notifications`) only | P3: needs a platform route first |
| Hotspot vouchers | `POST /v1/me/vouchers/redeem` (1) used; `POST /v1/me/hotspot/login-token` used; `GET /v1/hotspots` used. Voucher batch management is `/v1/admin/voucher-batches*` (8) and `/v1/admin/voucher-exports/download` | Customer redeem; staff batches | Done for redeem. `FreeWifiRepository` (mock, `stillMockInProd`) has no matching route in the contract | P2: remove or hide the free-Wi-Fi mock in prod (as the G7 plan says) |
| Public portal | `GET /v1/public/portal/{slug}/{key}` (1) | Public, hotspot captive page bundle | Not used. Purpose for an app: unknown | P3 |
| Storefront (reseller store) | 115 operations under `/v1/admin/store/*`. No customer or public store route found | Staff only | n/a | Not for the app; the old reseller question is moot, there is nothing customer-facing in the contract |
| Public records evidence | `GET /v1/public/records/evidence` (1) | Public | Not used | Not for the app |
| Account lifecycle | `/v1/me` GET and `DELETE`, `/me/profile`, `/me/consents`, `/me/export`, `/me/delete-challenge`, `/me/entitlements` | Customer | Used, except `GET /v1/me` | None |

## 5. Staff and admin-only areas (not for the app)

| Area | Operations |
|---|---|
| `/v1/admin/*` (all) | 367 in total: store 115, network 45, coverage 19, tickets 15, credits 13, billing 11, services 11, subscribers 11, leads 7, messaging 7, invoices 7, voucher-batches 8, and about 60 smaller groups |
| `/v1/platform/*` (all) | 195 in total: tenants 43, network 31, onboarding 24, settlement 10, reconciliation 9, payment-account 8, tickets 8, plans 5, element-manager 5, refunds 5 and smaller groups |
| Gateway and provider callbacks | `POST /v1/payments/{gateway}/notify/{token}`, `POST /v1/webhooks/email/postmark/{token}`, `POST /v1/webhooks/sms/bulksms/{token}` |
| Health | `GET /healthz`, `GET /readyz` |

No decoder in `lib/` reads any of these.

## 6. Recommended order for the customer app

1. G7 credits (7 routes, already in the contract).
2. Coverage over HTTP plus notify-me and withdraw, replacing the mock.
3. Customer tickets and current incidents, replacing the help mock.
4. Remove the free-Wi-Fi mock from prod; refresh `docs/BACKEND_CONTRACT_SYNC.md` rows.
5. Later, if wanted: OTP `device_token`; push (needs a platform route).

## 7. App feature branches under `C:\tmp\app-*`

Checked with `git merge-base --is-ancestor <branch> origin/main` (origin/main `ae267b8`):

| Worktree | Branch | In origin/main |
|---|---|---|
| app-a | `feat/p1-support-hc` | Yes |
| app-b | `feat/p1-hotspots-cancel` | Yes |
| app-p0 | `feat/contract-resync` | Yes |
| app-plan | `docs/subscriber-slices` | Yes |
| app-s1 | `feat/subscriber-s1-foundation` | Yes |
| app-s2 | `feat/subscriber-s2-invoices` | Yes |
| app-s3 | `feat/subscriber-s3-services` | Yes |
| app-s4 | `feat/subscriber-s4-kyc` | Yes |
| app-s5 | `feat/subscriber-s5-signup` | Yes |
| app-s6 | `feat/subscriber-s6-s7-change-cancel` | Yes |
| app-s8 | `feat/subscriber-s8-polish` | Yes |
| app-s9 | `feat/subscriber-s9-dashboard` | Yes |
| app-s10, app-shots | `feat/s10-hotspot-login`, detached `ae267b8` | Yes (it is the tip) |
| app-5g | `feat/5g-usage-unlock` | **No** (2 ahead; now in `feat/app-g7-0`) |

So the only unmerged feature work was the 5G branch. After this branch merges, origin/main contains every `app-*` branch.

## 8. Not verified

- No run against a live platform; only the saved contract and fixtures. Fixtures for the new customer routes (tickets, coverage address and capabilities, lead withdrawal, incidents) do not exist yet: they belong to the slices that use them.
- Behaviour of fixed-wireless signup against the new plan fields (`min_band_key`, `required_technology`, `sell_without_band`): unknown.
