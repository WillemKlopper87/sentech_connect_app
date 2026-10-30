# Subscriber account slices: implementation plan (audit rows 1, 2, 3, 4, 6, 10)

> Docs only. Written for Sonnet builders; the planner verifies each slice before it is pushed to `origin/codex/naas-implementation`.
> Basis: app `origin/main` at `688274a`; platform checkout `C:\tmp\integ` at `ae401a0` (the same snapshot as `test/contract/openapi.json`, 341 operations). Everything under "API facts" was read from platform source (`modules/subscribers/*`, `modules/hotspot/router.py`, `modules/plan_modules/catalog.py`, `modules/appconfig/router.py`) and the OpenAPI file. Items marked **assumption** are recommended defaults the owner can overrule. Items marked **not verified** were not run (no Flutter toolchain, no API stack).
> **Update 2026-10-30 (platform `ab5247a`, snapshot re-synced in S1):** platform tasks P1 to P4 and P5a are DONE. The customer service view is `CustomerServiceOut` (plan_name, kind, price, down/up kbps, `activation_blocker`, `pending_plan_id`/`pending_plan_name`), lists are newest first with the `after` cursor (400 `invalid_cursor`), invoices accept `status=open`, and `LoginTokenIn` is in the OpenAPI file. Where a passage below says the app must infer, join to the plans list, sort client side or work around a missing field, that is superseded by this note and the S1/S3/S9 notes.
> Audit this plan serves: `docs/PARITY_AUDIT_2026-10-29.md`. Contract and typed codes: `docs/BACKEND_CONTRACT_SYNC.md`.

## 0. Summary

- Ten slices (S1 to S10), each shippable alone behind the `subscriber_billing` module gate. Order: data foundation, invoices and pay, services, KYC, plans and signup, change plan, cancel, billing contact, dashboard, one-tap login.
- **Findings that change the audit** (details in section 1 and 5):
  1. The platform has **no liveness or selfie check**. KYC is a JSON capture (ID type and number, address text, consent version, optional single document image) that **staff verify by hand** (four-eyes). The mock `LivenessRepository` (SIM order RICA) is a different flow and is not reused.
  2. `active_service_exists` is **never emitted** by the platform. An account may hold several services; signup after the first just adds one.
  3. ~~`ServiceOut` has no plan name, kind or price.~~ **Fixed (P1, platform `ab5247a`):** the customer service view carries `plan_name`, `kind`, `price`, `down_kbps`, `up_kbps` of the plan version the service is on, also for retired plans. No join to the plans list.
  4. `POST /v1/me/hotspot/login-token` **requires `mac`** (12 to 32 characters) (the request body `LoginTokenIn` is now described in the OpenAPI file, P5a done). The controller hand-off does not remove the MAC. Neither Android nor iOS gives an app the MAC. Section 4 has the options and the owner questions.
  5. A customer **cannot cancel a pending service** (`409 pending_requires_immediate_cancellation`) and there is no "undo cancel" route.
  6. ~~Invoice and service lists are ordered by random UUID.~~ **Fixed (P4):** newest first (invoices by `issue_date`, services by `created_at`), `after` = previous `next_cursor`, `status=open` on invoices, `400 invalid_cursor` for an unknown cursor. The app keeps the API order and does not sort.
- Invoice payment reuses the order payment hand-off almost unchanged: `CheckoutOut` is the same class on both routes (platform imports it from `payments.router`).

## 1. API facts (read from source)

All routes are under the tenant of the signed-in customer. Mutating routes need the `Idempotency-Key` header (`lib/core/network/idempotency.dart`). Errors are RFC 9457 problems with a `code`; `lib/core/network/api_problem.dart` maps them.

### 1.1 Gates (every `/v1/me/subscriber/*` route and `/v1/subscriber-plans`)

| Gate | Source | Response when off | App rule |
|---|---|---|---|
| Flag `subscribers` (deployment kill switch, tenant override) | `check_feature` in `admin_router.py` | `409 feature_disabled` | Not in `app-config.feature_flags` (only `hotspot_passes, rica, cpe, vouchers, hotspot_radius`). Use the module instead. |
| Module `subscriber_billing` (plan + tenant override + kill switch) | `_enabled` in `me_router.py`, `public_router.py` | `403 module_not_enabled` | `GET /v1/app-config` `modules.subscriber_billing` is already the **effective** value (kill switch folded in; `appconfig/router.py:58-64`). `AppModuleKeys.subscriberBilling` exists and is parsed. **Hide every screen when it is false**; still map the two refusals above for races. |
| Collection mode `isp_operated` | `MODE_FORBIDDEN` in `plan_modules/catalog.py` | module forced off | Nothing extra: the module is false. For invoice checkout the platform also answers `409 collection_mode_not_supported` (today `current_collection_mode` is a stub that always returns custodian). |
| Tenant not operational | `_write_locks` | `403 tenant_suspended` | Already typed (`ProviderUnavailableFailure`). |
| Rate limits | `me_router.py` | `429` (reads 120/min, writes 30/min strict) | Already typed (`RateLimitedFailure`). |

### 1.2 `GET /v1/subscriber-plans?tenant=&limit=&cursor=` (public, no session)

Page of `PublicPlanOut`: `id, code, name, description, kind (recurring_hotspot | fixed_wireless), kyc_required, price{amount_cents, currency ZAR}, setup_fee_cents, down_kbps, up_kbps, burst_down_kbps?, burst_up_kbps?, burst_seconds?, fup_bytes?, fup_action, fup_down_kbps?, fup_up_kbps?, max_devices`. Active plans, current version price only. `tenant` defaults to `sentech` (the app must always send the slug). Errors: 404 unknown tenant, 403 `module_not_enabled`, 409 `feature_disabled`. `limit` 1 to 100 (default 20), opaque `cursor`. VAT: prices are `price_cents` of the version; whether VAT-inclusive is **not stated** in the schema (invoice lines carry `vat_rate_bp` and `vat_cents`; `amount` is `gross_cents`). Assumption: plan price is shown as "per month" with no VAT wording; confirm with owner (question Q9).

### 1.3 `GET /v1/me/subscriber` and `PATCH /v1/me/subscriber`

`SubscriberAccountOut`: `id, account_no, kind (individual|business), status (active|closed), profile{display_name, email?, phone_e164?, language en|zu|af}?, service_counts{pending,active,suspended,cancelled -> int}`.
- **404 `subscriber_not_found`** = the customer has no account yet. This is the normal "never signed up" state, not an error screen.
- `PATCH` body (`AccountProfilePatchIn`, all optional, `extra=forbid`): `display_name` 1..120, `email` (regex), `language`, `phone_e164` max 32. Requires `Idempotency-Key`. Returns the account. Validation errors are generic 422 problems with `errors[]`.
- Signup creates the account if missing by **copying the login profile** (`display_name`, `email`, `phone_e164`). If those do not validate: `422 subscriber_profile_invalid` ("update your customer contact details before signing up"). If the copied phone belongs to another customer: `409 customer_link_required`.

### 1.4 `POST /v1/me/subscriber/signup` (201)

Body `SubscriberSignupIn` (`extra=forbid`): `plan_id` uuid, `accept_terms_version` (`YYYY-MM-DD`, must equal the platform `terms_version`, which `app-config.legal.terms` publishes), `install_address?` (1..2000, stored encrypted), `term_months?` (1..60). Header `Idempotency-Key` required. Response `SubscriberSignupOut{service: ServiceOut, invoice: SubscriberInvoiceOut, checkout_hint: "/v1/me/subscriber/invoices/{id}/checkout"}`. The service is created `pending` with an **initial invoice** (prorated first month plus setup fee, due in 3 days). The terms consent is recorded server-side (no separate consent call).
Errors: `422 consent_version_outdated` (typed already), `404 subscriber_plan_not_found`, `409 subscriber_plan_inactive`, `409 subscriber_version_unavailable`, `409 account_closed`, `422 subscriber_profile_invalid`, `409 customer_link_required`, `503 service_number_unavailable` (retry). Replay with the same key returns the same service (`Idempotent-Replayed: true`).
**Not enforced at signup:** KYC (checked at activation), install address for fixed wireless, coverage.

### 1.5 `ServiceOut` and the `subscriber_service` state machine

Fields: `id, account_id, plan_id, plan_version_id, service_no, status, suspend_reason (non_payment|customer_request|admin|kyc)?, billed_through?, paid_through?, activated_at?, suspended_at?, cancelled_at?, cancel_effective_on?, pending_plan_version_id?, plan_change_on?, created_at, updated_at`. Dates are `date` except `*_at` (date-time).

Transitions (`state.py`): `pending -> active | cancelled`; `active -> suspended | cancelled`; `suspended -> active | cancelled`; `cancelled -> (none)`.

| From | To | Who/what | Conditions seen in source |
|---|---|---|---|
| (none) | pending | customer signup | initial invoice issued |
| pending | active | **automatic after the first invoice is paid**, only for `recurring_hotspot` when tenant policy `auto_activate_on_first_payment`; `fixed_wireless` is activated by staff | first invoice `paid`, signed contract row, customer linked and active, plan `kyc_required` -> a **verified** KYC must exist (else `kyc_required`, payment still stands, service stays pending) |
| suspended (`non_payment`) | active | automatic when a recurring/reactivation invoice is paid | `paid_through >= today`, contract, customer link |
| suspended (`kyc`) | active | automatic when KYC is verified or an invoice is paid with verified KYC | |
| active | suspended | billing/dunning/staff | `suspend_reason` set |
| active/suspended | cancelled | **customer: scheduled** at `cancel_effective_on` (= `paid_through`, else end of current month); billing performs the terminal move | pending cannot be cancelled by the customer |

`paid_through` = last day the service is funded; set to the invoice `period_end` when an initial, recurring or reactivation invoice is paid (adjustment and proration invoices do not extend it). `billed_through` = last day an invoice has been issued for.

**Pending services (superseded: P2 is done).** The API now sends `activation_blocker` on a pending service, evaluated with the platform's own activation predicates, so the app maps it directly and infers nothing. Mapping: `first_invoice_unpaid` -> "Pay your first invoice to start" (CTA pay); `kyc_required` -> "We need to check your ID" (CTA ID check; with KYC `pending`: "We are checking your ID"); `awaiting_installation` -> "Waiting for installation by your provider"; `customer_link_required` -> "Your account is not linked to your provider yet" (CTA contact provider); `service_contract_required` -> "Your service contract is not signed yet, contact your provider"; `null` (or an unknown future value, `ActivationBlocker.unknown`) -> generic "Activating, this can take a few minutes. Pull to refresh." (hotspot) or "Your provider is setting this up" (fixed wireless). The old inference table below is kept for history only:

| Condition (app side) | Copy intent |
|---|---|
| initial invoice `open` | "Pay your first invoice to start" (CTA: pay) |
| invoice `paid`, plan `kyc_required`, KYC status not `verified` | "We need to check your ID" (CTA: ID check; if `pending`: "We are checking your ID") |
| invoice `paid`, kind `fixed_wireless`, KYC ok | "Waiting for installation by your provider" |
| invoice `paid`, kind `recurring_hotspot`, KYC ok | "Activating, this can take a few minutes" (pull to refresh) |

Suspended copy by `suspend_reason`: `non_payment` -> "Pay your open invoice to restore service" (CTA: invoices); `kyc` -> ID check CTA; `customer_request`, `admin` -> "Paused by your provider, contact support" (CTA: support).

### 1.6 `GET /v1/me/subscriber/services[?limit&after]`, `GET .../services/{id}`

Page of `CustomerServiceOut`, **newest first** (`created_at`, then `id`); `after` is the previous page's `next_cursor`; the app loads all pages in API order (an account has few services; cap at 5 pages of 50) and does not sort. `400 invalid_cursor` for an unknown cursor. `404 service_not_found` for another account's service. `404 subscriber_not_found` when no account.

### 1.7 `POST .../services/{id}/change-plan`

Body `{new_plan_id}`; returns `ChangeOut{applied: bool, effective_on: date, proration_invoice_id?: uuid}`. Idempotency key required.
- Allowed only when status is `active` or `suspended` (`409 illegal_transition` otherwise), account `active`, and `cancel_effective_on` is null (`409 service_cancellation_scheduled`).
- Target plan must exist (`404 subscriber_plan_not_found`), be active (`409 subscriber_plan_inactive`), have a current version (`409 subscriber_version_unavailable`) and the **same kind** (`409 plan_kind_mismatch`).
- **Upgrade** (new current price > the price of the service's current version): `applied: true`, `effective_on` = today, plan switches now. If `paid_through >= today` a **proration invoice** is issued (`proration_invoice_id`, kind `proration`, due in 3 days, amount = price difference prorated by days remaining in the month). If the target plan is `kyc_required`, a verified KYC is required (`409 kyc_required`).
- **Downgrade or equal price:** `applied: false`, `effective_on` = first day of next month, stored as `pending_plan_version_id` + `plan_change_on`; no invoice.
- Same version as now and nothing pending: no-op, `applied: true`, `proration_invoice_id: null`.
- Refusals when next period is already billed: `409 service_plan_change_already_billed`; `409 service_plan_change_already_invoiced`.
- **No preview route.** The proration amount is known only after the call (read the invoice).

### 1.8 `POST .../services/{id}/cancel`

Body `{reason}` (1..200, trimmed, no control characters). Returns the `ServiceOut` with `cancel_effective_on` set. Never immediate for the customer. The first agreed date survives retries. Pending service -> `409 pending_requires_immediate_cancellation`. Terminal state or other illegal move -> `409 illegal_transition`. No access, invoice or contract changes at scheduling time; billing ends the service on the date (future unpaid recurring invoices are voided then). **No route to withdraw a cancellation.**

### 1.9 Invoices: `GET .../invoices[?limit&after]`, `.../invoices/{id}`, `POST .../invoices/{id}/checkout`

`SubscriberInvoiceOut`: `id, service_id, invoice_no, kind (initial|recurring|proration|reactivation|adjustment; typed as free string), status (open|paid|void|written_off), period_start, period_end, issue_date, due_date, amount{amount_cents}, vat_cents, amount_paid_cents, paid_at?, lines[{position, kind, description, quantity, unit_price_cents, line_total_cents, vat_rate_bp, vat_cents}]`. List items carry `lines: []` in practice (the list query selects no lines; detail loads them; the schema default is empty). **Ordered by `id`** (random), so sort client-side by `issue_date` desc, then `invoice_no`. Not-found: `404 invoice_not_found`.

Checkout returns the **same `CheckoutOut` as orders** (`payment_id, reference, gateway, amount{amount_cents}, method GET|POST, url, fields{}, return_url?`); `return_url` is `{public_web_base_url}/{slug}/checkout/return`, which `isPaymentReturnUrl` in `payment_urls.dart` already recognises. Refusals:

| Status, code | Meaning |
|---|---|
| 409 `invoice_not_payable` | status not `open`, gross <= 0, or already partly paid; or the service is `cancelled` and the invoice is not an `adjustment` |
| 409 `collection_mode_not_supported` | tenant does not use Sentech collection (pay the provider directly) |
| 409 `customer_not_active`, `account_not_active`, `account_changed` | account problem, contact the provider |
| 404 `invoice_not_found`, 403 `tenant_suspended`, 429 | |
Reuses an existing `initiated` payment for the invoice, so a retry is safe. Payment completes only by the gateway notify; `paid_at` and `status: paid` appear after it is processed. Activation after payment can still be gated (KYC, installation), so a paid invoice does not mean an active service.

### 1.10 KYC: `GET /v1/me/subscriber/kyc`, `POST /v1/me/subscriber/kyc` (201)

- Requires an existing subscriber account (`404 subscriber_not_found` before signup) and the module gate.
- `GET` returns `{status:"none"}` or `SubscriberKycOut{status (pending|verified|rejected|erased), id_type (sa_id|passport|company_reg), id_number_last4, consent_version, consent_at, verified_at?}`. Selection: pending first, then verified, then others; rows past `retain_until` are hidden (-> `none`). **No rejection reason is exposed** (P7); staff reasons are `unreadable_document, identity_mismatch, address_incomplete, consent_invalid, other` and a notification is enqueued to the customer on decision.
- `POST` body `SubscriberKycIn` (`extra=forbid`, JSON, **max 7 MiB**): `id_type`, `id_number` (1..32), `address_text` (1..2000, no control characters), `consent_version` (`YYYY-MM-DD`), `consent_via` (`app|web`, default `app`), `document?` (**base64 string**, max 6,990,508 characters; decoded <= 5 MiB; sniffed as **PDF, PNG or JPEG** only). Idempotency key required. A new submission marks any earlier `pending` row `rejected/superseded`. Response 201 `SubscriberKycOut` (status `pending`).
- ID number checks (`validate_id_number`): `sa_id` = 13 digits, valid birth date not in the future, 11th digit `0` or `1`, Luhn; `passport` = 6 to 12 letters/digits (upper-cased); `company_reg` = `NNNN/NNNNNN/NN`. Format only, no registry lookup.
- Errors: `422 invalid_identity_number`, `422 invalid_address`, `422 invalid_consent_version`, `422 invalid_document_encoding`, `422 document_type_not_allowed`, `413 document_too_large`, `503 document_upload_failed` (retry), `409 document_upload_expired` (retry), `409 account_closed`, `403 tenant_suspended`.
- **What the platform accepts today:** text fields plus at most one image/PDF. **Not accepted:** selfie, second document, liveness result, vendor reference. Verification is **manual by staff** (`verify_kyc`, with four-eyes); there is no vendor webhook. Verified KYC unlocks activation of `kyc_required` plans and resumes services suspended with reason `kyc`.

### 1.11 `POST /v1/me/hotspot/login-token` (201, `Cache-Control: no-store`)

Source: `modules/hotspot/router.py`, `hotspot/service.py`. Body (`LoginTokenIn`, `extra=forbid`, max 4096 bytes; **absent from the OpenAPI file**): `mac` (**required**, 12 to 32 chars, normalised to `AA:BB:CC:DD:EE:FF`), `nas_id?` (uuid of a registered, enabled controller), `login_url?` (max 500; requires `nas_id`), `dst?` (max 2000). No `Idempotency-Key` (a retry just issues another token). Response `LoginTokenOut{username "c.<hex>", password (shown once), expires_at (ISO string), handoff?{action_url, fields{}}}`; `handoff` only when `nas_id` and `login_url` are both sent. The token is **bound to the MAC**; RADIUS rejects a token presented from another MAC (`radius/service.py`), single use.
Gates: flag `hotspot_radius` (`409 feature_disabled`; the app already parses `featureFlags.hotspotRadius`), a usable entitlement (`409 no_active_entitlement`), per-IP and per-customer hourly limits (`429 rate_limited`, `Retry-After: 600`). Refusals: `422 mac_invalid`, `422 nas_unavailable`, `422 login_url_invalid`, `422 controller_not_supported`. All eight codes are already typed in the app.

### 1.12 Existing app facts this plan builds on

- Modules/flags: `AppModules.isOn`, `TenantCubit.isModuleOn`, `AppFeatureFlags` (`lib/features/tenant/domain/entities/app_config.dart`); gating example `MainShell` (`showScan`) and `test/module_gating_test.dart`.
- Payment hand-off: `PaymentHandoff`, `paymentHandoffFromJson`, `PaymentWebViewPage`, `payment_urls.dart` (URL allow-list, return URL), `PaymentCubit` poll schedule `defaultPollDelays` (about 52 s), `DevPaymentSimulator` (debug, local only).
- Pass card on Home: `PassesCubit` + `PassSummary`; a subscriber's monthly allowance already arrives as an entitlement with `source: service`, `product_name` = plan name, `data_mb`, `speed_kbps` (platform `access.py` upsert) for `recurring_hotspot`. `fixed_wireless` access goes through the network/AAA module; **no customer route returns its usage** (P10).
- Existing mock RICA (`lib/features/rica/*`, `LivenessRepository` in `stillMockInProd`) belongs to **SIM orders** (Home 5G/MiFi, `requiresIdentityCheck`, flag `rica`) and is unrelated to subscriber KYC.
- `MockAccountRepository`/`AccountRepository`/`AccountCubit` are in `stillMockInProd`; `showRouterCardFor` already hides them in prod.
- Stale typed code: `active_service_exists` -> `ActiveServiceExistsFailure` never fires against this platform. Keep (harmless), do not build UI around it.

## 2. Decisions (assumptions, overrule as needed)

| # | Decision | Recommended default | Why / alternative |
|---|---|---|---|
| D1 | **Entry point in navigation** | No new bottom tab. (a) **Shop tab**: a "Monthly plans" card above the pass list when `modules.subscriber_billing` is on (browsing/buying lives in Shop). (b) **Account tab**: a "Home internet" section with tiles "My services", "Invoices", "ID check" when module on **and** an account exists (or always when module on, so a new customer can find "My services" empty state -> plans). (c) **Home tab**: service card(s) for subscribers (slice 9). Routes are top-level (`/services`, `/services/:id`, `/invoices`, `/invoices/:id`, `/kyc`, `/plans`, `/plans/:id`, `/signup/:planId`) in `AppRoutes`. | A fifth-to-sixth tab would crowd `NavigationBar`; the app already uses Shop for buying. Alternative: put all in Account. |
| D2 | **KYC capture** | Ship now: a form that posts to `POST /v1/me/subscriber/kyc` with ID type, ID number, address text, an **ID document photo** (camera or gallery, one image, JPEG, long edge 2000 px, quality ~80, hard cap 4 MB before base64), explicit consent checkbox. Status screen shows `none/pending/verified/rejected`. **No liveness, no selfie, no vendor.** The existing `LivenessRepository` mock stays untouched for SIM orders and is not shown for subscribers. Needs the new dependency `image_picker` (flutter.dev first-party, **owner approval to add**). Later, with a certified provider (Smile Identity was the earlier recommendation): vendor SDK in the app produces a reference, the platform needs a vendor webhook that calls `verify_kyc` as a system actor, and a field for the vendor reference (P7); legal must confirm what RICA/FICA require for the plan types (not assessed here). | The platform has no place to put a selfie or liveness result, and verification is manual. Building a vendor flow in the app first would collect data the platform cannot store. Question Q3, Q4. |
| D3 | **Invoice pay reuses the order hand-off** | `InvoiceRepository.startCheckout(invoiceId)` returns the existing `PaymentHandoff` via `paymentHandoffFromJson` (same JSON). New `InvoicePaymentCubit` mirrors `PaymentCubit` (states ready/starting/handoff/confirming/stillPending/payFailed/paid/closed) but **polls `GET .../invoices/{id}`** until `status == paid` (same `defaultPollDelays`) and then re-reads the service. Reuse `PaymentWebViewPage`, `payment_urls.dart`, fake-gateway sheet (debug). Extract the shared "open hand-off then confirm" widget logic from `payment_page.dart` only if the diff stays small; otherwise copy the 40 lines and note it. | `CheckoutOut` is identical; only the confirmation read differs. |
| D4 | **Plan change UX** | Plan picker (same-kind active plans except current) -> confirm sheet with the new price and one sentence chosen by price comparison **against the service's current plan price from the plans list**: higher: "Switches now. You will be invoiced the difference for the rest of this month."; lower: "Takes effect on <1st of next month>. Until then you keep your current plan."; unknown current price (retired plan): neutral sentence "The provider decides when this takes effect" and no claim. **No proration amount before confirming** (no preview route; client math would diverge from `prorate_cents`). After success use `ChangeOut`: `applied` -> "Plan changed"; with `proration_invoice_id` a "View invoice" button; not applied -> "Scheduled for <effective_on>". | Matches server logic (`applied = new_price > old_price`) without inventing numbers. The service's own version price can differ from the list's current price if the plan was repriced; the sentence is "usually", and the result screen states what really happened. |
| D5 | **Cancel UX** | Destructive confirm dialog: "Your service stays active until <date>. After that it stops and you will not be billed again." where date = `paid_through` (else last day of this month, same fallback as the server), then a reason chooser (Moving, Too expensive, Not reliable, Other) with optional text; sent as one English string `"<choice>: <text>"` trimmed to 200. No refund claim, no termination fee claim (server: "no credits, no termination fees"). After success the service shows "Ends on <cancel_effective_on>". Hide the Cancel action for `pending` (platform refuses) and show "Contact support to cancel" instead. | The server schedules, never ends immediately. |
| D6 | **Dashboard composition** (slice 9) | Home shows, when module on and an account exists: for each non-cancelled service a card (plan name, status chip, "Paid until <date>" from `paid_through`, banner per section 1.5, open-invoice strip "R.. due <date>" with Pay), plus the existing current-pass card driven by entitlements (monthly allowance and usage for `recurring_hotspot`). `fixed_wireless` shows no usage. Quick actions: Pay invoice (if open), Change plan, Report issue. | One real source per element, nothing invented. |
| D7 | **Dropped mock fields** | `routerName`, `macAddressSuffix`, `signalBars` (no API: needs CPE/ACS, flag `cpe`; show nothing), `usedGB`/`totalGB` (replaced by entitlement `data_mb`/`usedBytes`, hotspot subscribers only), `renewsOn` (replaced by "Paid until" from `paid_through`; the API has no next-invoice date for the customer), `planName` (from plan join or entitlement `product_name`). `AccountRepository`, `MockAccountRepository`, `AccountSummary`, `AccountCubit`, `_UsageCard`, `_CpeCard` and `showRouterCard`/`showRouterCardFor` are removed in slice 9; `AccountRepository` leaves `stillMockInProd` (the locator test forces this). The `cpe` flag then gates nothing on Home until a router/CPE route exists. | |
| D8 | **Signup details** | `term_months` omitted (month to month) unless the owner confirms fixed terms (Q8). `install_address` asked only for `fixed_wireless` and required in the app (the server does not require it). Terms: show the terms link (existing legal gate URLs) and a checkbox; send `accept_terms_version = app-config.legal.terms`. No new human check (the route has none). No coverage check for fixed wireless in this plan (row 9 is separate): show a note "Availability is confirmed by your provider". | |
| D9 | **Pending signup abandonment** | If the customer never pays, the service stays `pending` and cannot be cancelled by them. App: show it with "Pay to start" and a "Contact support" link; do not offer cancel. Platform task P6. | |
| D10 | **Money and dates** | Cents via `Money`/`formatMoney` (existing `core/money`), ZAR only. Dates from the API are plain `date` (Africa/Johannesburg business dates): format them as dates without time-zone shifting (`DateTime.parse` of `YYYY-MM-DD` then show y/m/d only; add a tiny `parseApiDate` helper in slice 1 with a unit test). | Avoids off-by-one near midnight UTC. |
| D11 | **PII handling** | Add `id_number`, `address_text`, `document`, `install_address`, `password`, `username`(token) to `PiiScrubber`; `FLAG_SECURE` on the KYC and login-token screens (`secure_screen.dart` exists); KYC form state lives in the cubit only (not persisted, not restored); the picked image file is deleted after submit or cancel. | POPIA; platform stores these encrypted. |

## 3. Slices (dependency order)

Sizes: S under half a day, M about a day. Every slice: new files follow the existing layout `lib/features/<feature>/{domain/{entities,repositories},data/repositories,presentation/{bloc,pages,widgets}}`, `Either<Failure,T>` returns, no `dio` imports in presentation, demo flavor gets a `Mock*Repository` (no `ApiClient`), prod gets `Http*Repository`; copy goes through ARB (`app_en`, `app_af`, `app_zu` in the same change; `flutter gen-l10n`; parity test) and the af/zu strings are added to `docs/L10N_NEEDS_NATIVE_REVIEW.md`. Update `docs/BACKEND_CONTRACT_SYNC.md` route table in the slice that makes a route real.

Feature folder: `lib/features/subscriber/` (one feature, sub-areas `plans`, `services`, `invoices`, `kyc`, `login` kept in separate files; split into folders only if a file passes ~300 lines).

### S1. Data foundation: gate, entities, plans, account, services reads (M)

- **Built (2026-10-30, branch `feat/subscriber-s1-foundation`):** entities `SubscriberPlan` (+ `SubscriberPlanKind`), `SubscriberAccount` (+ `ServiceCounts`, `SubscriberProfile`), `SubscriberService` (+ `ServiceStatus`, `SuspendReason`, `ActivationBlocker`) read from `CustomerServiceOut` (so the service carries plan name, kind, price, speeds, blocker and scheduled plan name; no join, no client sort), `lib/core/time/api_date.dart` (`parseApiDate`), `SubscriberGate`, routes constants, `PlanUnavailableFailure` and `ServiceStateFailure` (see section 3.1), HTTP and mock repositories, locator wiring (not in `stillMockInProd`), contract fixtures and tests. Original scope text follows. **Add:** domain entities `SubscriberPlan`, `PlanKind`, `SubscriberAccount` (+ `ServiceCounts`), `SubscriberService` (+ `ServiceStatus`, `SuspendReason`), `ApiDate` helper (D10); repositories `SubscriberPlansRepository.list()` (all pages), `SubscriberRepository.getAccount()` returning `Right(null)` for `subscriber_not_found`, `listServices()`, `getService(id)`; `Http*` with decoders; `Mock*` for demo (one recurring plan, one fixed-wireless plan, one active service); `SubscriberGate` (pure function `subscriberBillingOn(TenantState)`); locator wiring; `AppRoutes` constants (no screens yet).
- **Typed failures (new, in `failure.dart`, `_typedRefusals`, `typedFailureText(s)`, ARB `failure*`):** see table in section 3.1; the ones S1 needs: `service_not_found` (generic `NotFoundFailure` is enough, no new class), `subscriber_plan_not_found`/`subscriber_plan_inactive`/`subscriber_version_unavailable` -> `PlanUnavailableFailure`, `account_closed`/`illegal_transition` -> `ServiceStateFailure`. Add `403 module_not_enabled` and `409 feature_disabled` already exist.
- **Screens:** none.
- **Tests:** contract fixtures `subscriber_plans_page.json` (`Page_PublicPlanOut_`), `subscriber_account.json` (`SubscriberAccountOut`), `subscriber_services_page.json` (`Page_ServiceOut_`, one per status incl. `cancel_effective_on` and `pending_plan_version_id`), each registered in `fixtureSchemas` and the keys in `decoderReads` (`test/contract/openapi_contract_test.dart`); repository tests with the fake Dio adapter pattern in `http_checkout_repository_test.dart` (404 -> `Right(null)`, pagination across two pages, unknown status string tolerated or rejected? **reject** unknown `status` with `FormatException` -> `ServerFailure`, the API enum is closed); `ApiDate` unit test; gate test.
- **Gating/mock:** nothing user-visible. Mock only in demo.
- **Done when:** `flutter analyze` and all tests pass; `BACKEND_CONTRACT_SYNC.md` rows for plans/account/services say "data layer done".

### S2. Invoices: list, detail, pay (M)

- **Add:** `SubscriberInvoice`, `InvoiceLine`, `InvoiceStatus`; `InvoiceRepository` `list({bool openOnly})` (all pages in API order, newest first; `openOnly` sends `status=open`; no client sort), `get(id)`, `startCheckout(id)` (idempotency key per tap, reused for a retry of the same attempt; reuse `lib/core/network/idempotency.dart`); `InvoicesCubit`, `InvoiceDetailCubit`, `InvoicePaymentCubit` (D3); pages `InvoicesPage` (open first, then by date), `InvoiceDetailPage` (lines, VAT, status, due date, "Pay now" for `open` and amount > 0), reuse `PaymentWebViewPage`.
- **States:** loading, empty ("No invoices yet"), error + retry (`FailureView`), offline (`NetworkFailure` -> existing offline wording), refresh. Detail: open, paid (with `paid_at`), void/written off (no Pay), `amount_paid_cents > 0` and open -> "Part paid, contact support" (server refuses partial).
- **Failure copy:** `invoice_not_payable` (typed), `collection_mode_not_supported` -> map to `CollectionExternalFailure` ("pay your provider directly"), `customer_not_active`/`account_not_active`/`account_changed` -> `AccountProblemFailure` (new, "contact your provider"), `invoice_not_found` (NotFound), `tenant_suspended` (existing).
- **After payment:** on `paid`, re-read the invoice and its service and show the outcome line from section 1.5 (kyc needed / installation / activating).
- **Tests:** fixtures `subscriber_invoice.json`, `subscriber_invoices_page.json` (`SubscriberInvoiceOut`, `Page_SubscriberInvoiceOut_`), `invoice_checkout.json` (`CheckoutOut`, reuse the shape of `checkout_fake.json`), decoder reads, repo tests (sorting, checkout request carries `Idempotency-Key`, 409 mappings), `InvoicePaymentCubit` tests with fake wait (mirror `payment_polling_test.dart`: paid, stillPending, failed, offline blip), widget tests for list states and pay button visibility, module-off redirect.
- **Gating:** routes `/invoices`, `/invoices/:id` redirect home when the module is off. No navigation entry until S3 (deep link only from S3's service detail); to be reachable alone, add the Account tile here (single tile, shown when module on).
- **Stays mock:** nothing. Dev simulate for invoice payments is **not verified** (P12); until checked, the fake gateway sheet works only if `/v1/dev/payments/{id}/simulate` accepts invoice payments.

### S3. Services: list, detail, status banners, Account entry (M)

- **Add:** `ServicesCubit` (loads account + services + KYC status + open invoices via `status=open`; no plans list needed for the service cards), `ServiceDetailCubit`; `ServiceViewModel` reading plan name, kind, price and speeds straight from `SubscriberService` and mapping `activation_blocker` (plus `suspend_reason` for suspended) to the banner (section 1.5, pure function with table tests; no inference from invoices or KYC; null or `ActivationBlocker.unknown` gives the generic pending copy); pages `ServicesPage` (cards), `ServiceDetailPage` (plan facts, status chip, service number, paid through, scheduled change, scheduled cancellation, actions area for S6/S7 shown only once those slices land, links to invoices and ID check).
- **Entry:** Account tab section "Home internet" (D1b): tiles My services, Invoices (from S2), ID check (S4, hidden until S4 exists); shown when module on.
- **States:** loading; **no account / zero services** -> empty state "You have no home internet service yet" with "See plans" (-> S5 route, hidden until S5; until then plain text); error/offline with retry; per-service banner states; cancelled services collapsed under "Past services".
- **Copy keys:** `serviceStatus{Pending,Active,Suspended,Cancelled}`, banner keys per row of section 1.5, `serviceEndsOn`, `servicePaidUntil`, `servicePlanChangeOn` ("Plan change to <pending_plan_name> on <date>", the name now comes from `pending_plan_name`).
- **Tests:** table test for banner logic (every status, suspend reason and blocker value incl. null and unknown), cubit tests (no-account, two services, one failing invoice call degrades to "no banner" not full error), widget tests for each state, golden-free; module gating test (tile hidden when off).
- **Stays mock:** nothing.

### S4. KYC / ID check (M)

- **Add:** `KycRepository` (`getStatus()`, `submit(KycSubmission)`), `Http` and `Mock` (mock = in-memory pending then verified after 5 s, demo only); `KycCubit` (status load; form state; submit), `KycStatusPage`, `KycFormPage` (ID type chooser, number field with live format check for each type incl. SA ID Luhn and date, address text field, ID photo capture/replace with preview, consent checkbox with text and privacy link, submit). `image_picker` added to `pubspec.yaml` (D2), image shrink in a small `IdDocumentEncoder` (decode, resize, JPEG ~80, base64, size cap 4 MB) kept pure and tested with an in-memory image.
- **States:** status `none` (explain what is needed, Start), `pending` ("We are checking your ID, usually within <provider>'s time; we will notify you" without a made-up SLA), `verified` (id type, last 4, date), `rejected` ("We could not accept it, please submit again", reason unknown, P7), `erased` (treated as none); form: validating, submitting, offline retry that keeps the form and the image; camera/gallery permission denied -> gallery fallback and settings link.
- **Failure copy keys:** `invalid_identity_number` -> `KycInvalidIdFailure`; `invalid_address` -> `KycInvalidAddressFailure`; `invalid_document_encoding`, `document_type_not_allowed`, `document_too_large` -> `KycDocumentRejectedFailure`; `document_upload_failed`, `document_upload_expired` -> `KycUploadFailedFailure` (retry); `invalid_consent_version` -> `ConsentVersionOutdatedFailure`; `kyc_required` -> `KycRequiredFailure` (used in S5/S6); `subscriber_not_found` -> existing (KYC needs an account: the entry is hidden until the customer has an account).
- **Consent:** `consent_version = app-config.legal.privacy` (assumption; the platform only checks the date format) and `consent_via: app`.
- **Entry:** service detail banner CTA, plan detail ("this plan needs an ID check after you sign up"), Account tile "ID check".
- **Tests:** contract fixtures `subscriber_kyc_none.json` (`KycNoneOut`), `subscriber_kyc_pending.json` (`SubscriberKycOut`), request body check for `SubscriberKycIn` (keys sent: `id_type, id_number, address_text, consent_version, consent_via, document`), encoder tests, ID validators table tests (valid and invalid per type), cubit tests (submit success, each 422, offline keeps draft), widget tests for each status, `PiiScrubber` test for the new keys, secure-screen test.
- **Stays mock:** `LivenessRepository` (SIM orders) unchanged and still listed in `stillMockInProd`.

### S5. Plans and signup (M)

- **Add:** `PlansCubit` (list, group by kind, sort price asc), `PlansPage` (cards: name, price per month, speeds, data/FUP wording, setup fee, "ID check needed" chip), `PlanDetailPage` (full facts: burst, FUP action, max devices, description), `SignupPage` (summary: first invoice is prorated, setup fee line, terms checkbox, install address field for fixed wireless, "Sign up" button), `SignupCubit` (one `Idempotency-Key` per form submission, reused on retry of the same draft, new key when plan or address changes), `SubscriberRepository.signup(...)`.
- **Flow:** Plans -> detail -> signup -> success screen showing the initial invoice and "Pay now" (-> S2 pay) and "Pay later" (-> service detail). Pending banner then covers the rest.
- **States:** plans loading/empty ("No plans available right now")/error/offline; signup submitting, success, errors; module off -> card hidden and route redirect; customer without a phone/profile -> `subscriber_profile_invalid` -> "Update your contact details" (button to existing profile page `PATCH /v1/me/profile`; this is the login profile, not the subscriber profile).
- **Failure copy:** `subscriber_profile_invalid` (typed), `customer_link_required` (typed), `consent_version_outdated` (typed; refresh app-config then retry), `PlanUnavailableFailure` (not found/inactive/no version: "This plan is no longer available", reload plans), `ServiceStateFailure` for `account_closed` ("Your account is closed, contact your provider"), `service_number_unavailable` 503 -> "Try again in a moment" (generic retry).
- **Entry:** Shop tab card (D1a).
- **Tests:** request body check `SubscriberSignupIn` (keys `plan_id, accept_terms_version` always; `install_address` only for fixed wireless; `term_months` absent), fixture `subscriber_signup.json` (`SubscriberSignupOut`), cubit tests (idempotency key reuse and rotation, replay, each refusal), widget tests (fixed vs recurring form fields, terms required, module off), router redirect test.
- **Stays mock:** coverage (row 9).

### S6. Change plan (S)

- **Add:** `SubscriberRepository.changePlan(serviceId, newPlanId)` -> `PlanChange{applied, effectiveOn, prorationInvoiceId?}`; `ChangePlanCubit`; `ChangePlanPage` (picker per D4) and confirm sheet; result view.
- **Visibility:** button only when service `active` or `suspended`, `cancel_effective_on == null`; else a disabled explanation ("Not available while cancellation is scheduled", "Available once your service is active"). Same-kind plans only.
- **Failure copy:** `plan_kind_mismatch` (should not happen; `PlanUnavailableFailure`), `service_cancellation_scheduled` -> `CancellationScheduledFailure`, `service_plan_change_already_billed`/`already_invoiced` -> `PlanChangeBilledFailure` ("Your next period is already billed, try again from <1st>"), `kyc_required` -> `KycRequiredFailure` with CTA to S4, `illegal_transition` -> `ServiceStateFailure`.
- **Tests:** fixture `subscriber_change_applied.json`, `subscriber_change_scheduled.json` (`ChangeOut`), request body check `ServicePlanChangeIn`, sentence-choice unit test (higher, lower, equal, unknown price), cubit tests (applied with invoice id, scheduled, no-op, refusals), widget test of the confirm sheet.

### S7. Cancel at period end (S)

- **Add:** `SubscriberRepository.cancel(serviceId, reason)` -> `SubscriberService`; `CancelServiceCubit`, confirm dialog with reason chooser (D5), effective-date computation helper (`paid_through`, else last day of current month) with unit tests including month ends and leap year.
- **Visibility:** hidden for `pending` and `cancelled` and when `cancel_effective_on` already set (show "Ends on <date>"; no undo, P6).
- **Failure copy:** `pending_requires_immediate_cancellation` -> `PendingCancelFailure` ("Contact support to cancel a service that has not started"), `illegal_transition` -> `ServiceStateFailure`.
- **Tests:** fixture `subscriber_service_cancel_scheduled.json` (`ServiceOut`), request body check `SubscriberCancelIn` (`reason` 1..200 trimmed, no control characters), cubit tests (success, replay keeps the first date, each refusal, offline keeps dialog open), widget test of the confirm text with the computed date.

### S8. Billing contact edit (S, optional)

- **Add:** `SubscriberRepository.patchProfile(...)`; `SubscriberProfilePage` (display name, email, phone, language; only changed fields sent; `Idempotency-Key`). Entry: Account "Home internet" section. Client validation mirrors the schema (name 1..120, email regex, phone <= 32). Shows `account_no`. Skip if the owner says the login profile is enough (Q10).
- **Tests:** body shows only set fields, 422 field errors rendered under fields, module off.

### S9. Account dashboard from real data (M) (row 10)

- **Add:** `HomeOverviewCubit` combining `PassesCubit` (existing), services (plan name, price and blocker are on the service already), open invoices (`GET .../invoices?status=open&limit=..`, no paging through every invoice); service cards and invoice strip per D6; remove mock account code per D7; update `MainShell`, `DashboardPage`, `app_router.dart` (`showRouterCardFor` removed), `locator.dart` (`AccountRepository` out of `stillMockInProd` and out of `_registerStillMockRepositories`, `mock_account_repository` deleted), README table row, `BACKEND_CONTRACT_SYNC.md`, audit row 10 marked done.
- **States:** module off or no account -> Home exactly as today (pass-only); account with services -> cards; partial failure (services ok, invoices fail) shows cards and a small "could not load invoices" retry; offline shows last loaded state with an offline chip if cached (cache not required in v1: show `FailureView`); pull to refresh reloads all three sources.
- **Tests:** widget tests for the four combinations (no module, no account, hotspot subscriber with pass, fixed wireless without usage), `locator_test` updated, `main_shell_flavor_test` updated, removal does not leave `cpe` references that fail `flutter analyze`.
- **Dependency:** S1 to S3 (S5 for the empty-state CTA).

### S10. One-tap hotspot login (M) (row 6): blocked on the decision in section 4

Scope depends on the owner's answer. Recommended scope (Option B in section 4): repositories and cubit for the token call, a "Get online" screen opened from a **portal deep link** carrying `mac`, `nas`, `login_url`, then the controller form hand-off. Specified in section 4.4. Do not start before Q1 and Q2 are answered and platform task P5 is scheduled.

### 3.1 New typed failures and copy keys (one place)

Add to `_typedRefusals` (or the 404/503 branches), `typedFailureText`, `typedFailureTexts`, and ARB `failure*` keys. Wording is a draft for en; af/zu follow the draft process.

| Code(s) | Failure class | en copy intent | Slice |
|---|---|---|---|
| `subscriber_plan_not_found`, `subscriber_plan_inactive`, `subscriber_version_unavailable`, `plan_kind_mismatch` | `PlanUnavailableFailure` | This plan is no longer available. | S1 |
| `account_closed`, `illegal_transition` | `ServiceStateFailure` | This service can't be changed right now. | S1 |
| `collection_mode_not_supported` | existing `CollectionExternalFailure` | Pay your provider directly. | S2 |
| `customer_not_active`, `account_not_active`, `account_changed` | `AccountProblemFailure` | There is a problem with your account. Contact your provider. | S2 |
| `invalid_identity_number` | `KycInvalidIdFailure` | Check your ID number. | S4 |
| `invalid_address` | `KycInvalidAddressFailure` | Check your address. | S4 |
| `invalid_document_encoding`, `document_type_not_allowed`, `document_too_large` | `KycDocumentRejectedFailure` | Use a clear JPEG, PNG or PDF photo under 5 MB. | S4 |
| `document_upload_failed`, `document_upload_expired` | `KycUploadFailedFailure` | We could not upload your document. Try again. | S4 |
| `kyc_required` | `KycRequiredFailure` | You need an ID check first. | S4/S6 |
| `service_cancellation_scheduled` | `CancellationScheduledFailure` | This service is already set to end. | S6 |
| `service_plan_change_already_billed`, `service_plan_change_already_invoiced` | `PlanChangeBilledFailure` | Your next period is already billed. Try again after it starts. | S6 |
| `pending_requires_immediate_cancellation` | `PendingCancelFailure` | Contact support to cancel a service that has not started. | S7 |
| `service_not_found`, `invoice_not_found` | existing `NotFoundFailure` | We could not find that. | S1/S2 |
| `invoice_line_limit`, `service_number_unavailable`(503) | generic `ServerFailure` retry | | |

Each class: add a `failure_copy_test` case, parity ARB entries, a row in `BACKEND_CONTRACT_SYNC.md` "Typed problems".

## 4. Row 6: one-tap login (what is possible)

### 4.1 What the API needs

- `mac` is **mandatory** in the body (`min_length=12`). With `nas_id` + `login_url` the response adds the controller form fields, **but the MAC is still required** and is what the token is bound to. RADIUS authorize rejects the token when the Calling-Station-Id MAC differs (`radius/service.py`, "wrong MAC for a token"). So the controller hand-off does **not** avoid the MAC.
- The MAC the router sees is the one the phone presents on that Wi-Fi network. Since Android 10 and iOS 14 this is a **randomised per-network MAC** by default, so it is not the hardware address either.
- Also needed for the hand-off: `nas_id` (platform UUID of the registered controller, not visible to the customer) and `login_url` (the controller's hotspot login URL, must match the registered host).

### 4.2 What the app can supply

| Platform | MAC | Controller identity/login URL |
|---|---|---|
| Android 6+ | `WifiInfo.getMacAddress()` returns the constant `02:00:00:00:00:00`; `NetworkInterface("wlan0").hardwareAddress` is blocked for apps targeting API 30+; no public API for the randomised MAC | not available; the connected SSID/BSSID are available only with location permission and say nothing about `nas_id` |
| iOS | none (no public API) | `NEHotspotNetwork` gives SSID/BSSID with entitlements; no controller data |

(From platform documentation knowledge, **not verified on a device**.) Conclusion: **the app cannot supply the MAC.** Plugins that read `wlan0` or ARP tables are unreliable and risk store rejection; do not use them.

### 4.3 Options

| Option | Idea | Needs | Verdict |
|---|---|---|---|
| A. App sends its own MAC | read from the OS | impossible | rejected |
| **B. Portal deep link (recommended)** | The router's captive-portal login page (MikroTik passes `mac`, `ip`, `link-login-only`, `link-orig` to its hotspot page; **template behaviour not verified**) shows "Open in the app", linking to an App Link / Universal Link `https://<web>/<slug>/hotspot?mac=..&nas=<nas_id>&login_url=<link-login-only>`. The app opens a "Get online" screen, calls the token route with those values, then POSTs `handoff.fields` to `handoff.action_url` (in a hidden WebView or a direct HTTP POST over the Wi-Fi network). | Ops edits the portal template per router and knows each router's `nas_id`; platform task P5a (OpenAPI body); app: App Links (`assetlinks.json`, apple-app-site-association), a WebView or Dart HTTP client bound to the Wi-Fi network (Android `bindProcessToNetwork`, which needs a small native channel) | works with today's platform; depends on ops/template work |
| C. Bind-on-first-use | Platform makes `mac` optional and binds the token to the first MAC that presents it (token is single use and short-lived). The app still needs `nas_id` + `login_url` to do the hand-off, or the user types the username/password into the portal page. | platform change P5b; an app route to learn `nas_id`/`login_url` (still B's deep link, or a captive probe) | removes the MAC problem, not the controller-info problem; weakens the MAC binding (security call for the platform owner) |
| D. Portal-only | Skip one-tap; the portal page itself does the login (customer signs in on the web) | web work, no app work | possible fallback; not "one tap in the app" |
| E. Show credentials | The app shows username/password with copy buttons for the portal form | needs the MAC anyway (B or C) | as a fallback screen inside B/C |

### 4.4 Recommended approach (assumption)

Option **B**, with **C** as a platform improvement the owner may choose, and screen E as the fallback. Slice S10 scope under B:
1. Deep-link route `/hotspot-login` with params `mac`, `nas`, `login_url`, `dst`; validate shape (MAC format, `login_url` http/https, no credentials in URL); reject and show the manual path otherwise.
2. `HotspotLoginRepository.createToken({mac, nasId?, loginUrl?, dst?})` -> `LoginToken{username, password, expiresAt, handoff?}`; no idempotency key; never logged or persisted (scrubber keys `password`, `username`, `mac`).
3. `HotspotLoginCubit`: precondition checks (module `hotspot_radius` flag on, signed in, a current pass from `PassesCubit`); states idle, requesting, handingOff, connected-or-unknown, failed. After the form POST, probe connectivity (`connectivity_plus` plus an HTTPS GET to the tenant's API health host) and show "You are online" or "Open your browser to finish".
4. Failure copy (all typed already): `no_active_entitlement` (buy/redeem), `mac_invalid`/`nas_unavailable`/`login_url_invalid`/`controller_not_supported` ("use the Wi-Fi login page instead"), `feature_disabled`, `429` with `Retry-After` 600.
5. Entry also from the Home current-pass card ("Connect") that simply explains how to start from the Wi-Fi login page, until deep links exist.
6. Tests: URL parser table tests, repo test with the request body, cubit tests with a fake hand-off executor, no logging test.
**Not started until:** owner answers Q1 and Q2 and ops confirms the portal template can carry the parameters.

### 4.5 Questions for the owner (row 6)

See Q1, Q2, Q5 in section 6.

## 5. Risks and platform-side gaps

### 5.1 Platform tasks (missing routes or fields the app needs)

| # | Task | Why the app needs it | Blocks |
|---|---|---|---|
| P1 | **DONE (platform ab5247a).** Add `plan_name`, `kind`, `price` (and optionally speeds) to the customer `ServiceOut` (the export schema `SubscriberServiceExport` already has `plan_name` and `kind`) | service cards cannot be named when the plan is retired or beyond the first page; extra requests otherwise | S3 quality, S9 |
| P2 | **DONE (platform ab5247a).** Add a pending/blocked reason to `ServiceOut` (e.g. `activation_blocker`: `first_invoice_unpaid`, `kyc_required`, `awaiting_installation`, `service_contract_required`, `customer_link_required`) | the app infers it from three sources today (section 1.5) and can be wrong | S3 accuracy |
| P3 | **DONE (platform ab5247a).** Replace `pending_plan_version_id` with `pending_plan_id` + `pending_plan_name` for customers | cannot show which plan a scheduled change targets | S6 polish |
| P4 | **DONE (platform ab5247a).** Order invoice and service lists by `issue_date desc` (keyset cursor) and add `status=open` filter | `ORDER BY id` on random UUIDs: no stable newest-first, "show open invoices" needs every page | S2, S9 |
| P5a | **DONE (platform ab5247a).** Describe `LoginTokenIn` in OpenAPI (`openapi_extra`, like the other `/me` routes) | the contract test cannot check the body today | S10 |
| P5b | (Option C) make `mac` optional and bind on first use, or document the MAC source for each controller kind | one-tap without a portal deep link | S10 |
| P6 | Let the customer cancel a pending service (void the unpaid initial invoice) and add an "undo scheduled cancellation" route | abandoned signups and changed minds | S7 |
| P7 | Expose `rejected_reason` (code) in `SubscriberKycOut`; for a future vendor: a vendor-reference field and a system verify path | the customer cannot tell why a check failed | S4 polish, later vendor |
| P8 | Confirm the product rule on several services per account; `active_service_exists` is documented in the app/audit but the platform never raises it | UI copy and the stale typed failure | S5 |
| P9 | Confirm the code name for "provider collects its own money": the app maps `collection_external` (orders) and the platform's invoice route answers `collection_mode_not_supported`; neither is emitted by orders today | consistent copy | S2 |
| P10 | A customer route for `fixed_wireless` usage and for CPE/router status (platform has `network_usage` only in the export, flag `cpe` off) | usage bar for fixed wireless; the dropped router/signal fields | S9 |
| P11 | (optional) invoice PDF/statement link for the signed-in customer | download/share an invoice | later |
| P12 | Confirm `POST /v1/dev/payments/{id}/simulate` works for invoice payments on dev/test | local end-to-end test of S2 | S2 test |
| P13 | Confirm `app-config.legal.terms` is exactly the `terms_version` signup compares (read: yes, `appconfig/router.py:88` and `me_router.py` both use settings) and whether `privacy` is the right KYC consent version | S4 consent text | S4 |

### 5.2 App-side risks

| Risk | Mitigation |
|---|---|
| Pending reason inferred wrongly | table-driven unit tests; copy kept generic when sources disagree; fixed by P2 |
| Service on a retired plan shows no name | fallback "Your plan"; P1 |
| Large base64 body (up to 7 MiB) on mobile data | compress to <= 4 MB image before encoding, upload timeout 60 s, keep form on failure, show size warning on cellular |
| Image library adds a dependency and permissions | owner approval; use `image_picker` (camera permission only when the user picks camera; gallery needs none on current OS versions); verify iOS `Info.plist` strings (not verified here) |
| PII in logs/crash reports | D11; scrubber test must fail if keys are missing |
| Double submit creating two services | one idempotency key per form instance, button disabled while submitting |
| Payment return without completion | server status only, same as orders (polling, then "Check again") |
| Dates shifting a day | D10 |
| Unknown future enum values (`kind`, `status`) | closed enums reject loudly (contract test catches drift); invoice `kind` is a free string, displayed via a lookup with a safe default |
| Module off mid-session | `403 module_not_enabled`/`409 feature_disabled` -> "Not available from your provider", pop to Home |
| Hotspot token handled in app memory | never persisted or logged; cleared on screen close; FLAG_SECURE |
| Scope creep into coverage/fixed wireless install | out of scope; coverage is row 9 |

## 6. Owner questions

| # | Question | Default if unanswered (assumption) |
|---|---|---|
| Q1 | One-tap login: may ops customise the router captive-portal page to link into the app with `mac`, `nas` (platform controller id) and `login_url`? Is a platform change to bind the token to the first MAC (Option C) acceptable security-wise? | Option B planned; S10 not started |
| Q2 | Which router types does the first launch use (only MikroTik is implemented in the platform; others are stubs)? | MikroTik only |
| Q3 | KYC: is "ID number + address text + one ID document photo, checked by staff" enough for launch, or is a certified vendor (Smile Identity or other) required before any `kyc_required` plan goes live? | Staff verification; vendor later |
| Q4 | Which document should the single photo be: the ID document only, or a combined proof (ID plus address)? Is a selfie required by policy? (Platform accepts neither a second image nor a selfie.) | ID document only |
| Q5 | Is it acceptable that one-tap login works only on the provider's own Wi-Fi when the pass-holder opens the app from the portal page, and not from anywhere? | Yes |
| Q6 | Approve adding the `image_picker` dependency? | Yes |
| Q7 | Entry point: Shop card plus Account section, no new tab (D1)? | Yes |
| Q8 | Do plans have contract terms (`term_months`)? Month-to-month only at launch? | Month to month, field omitted |
| Q9 | Are plan prices VAT-inclusive? How should the first prorated invoice be explained? | Show "per month", show VAT only on the invoice |
| Q10 | Should customers edit billing contact details in the app (S8), or only through the login profile? | Build S8 last, optional |
| Q11 | Cancellation wording: any retention offer or notice-period wording the provider requires? Reasons list? | D5 default |
| Q12 | Should fixed-wireless signup require a coverage check first (row 9 is mock)? | No, provider confirms availability |

## 7. Execution notes for builders

- Branch per slice from `origin/main`, name `feat/subscriber-sN-<slug>`. Implementer model: Sonnet 5.5. The planner verifies (analyze, tests, diff read) before pushing to `origin/codex/naas-implementation`.
- Always in the same commit: snapshot/fixtures/decoders/contract test, repo + cubit + widget tests, ARB (en, af, zu) + generated Dart, `BACKEND_CONTRACT_SYNC.md` row, `docs/L10N_NEEDS_NATIVE_REVIEW.md` entries, and the audit table status.
- Demo flavor must keep working without `ApiClient`; tests default to demo.
- Module gate test for every slice: with `modules.subscriber_billing == false` the entry, routes and tiles are absent.
- Do not touch: order RICA/liveness mocks, coverage, promotions, free Wi-Fi.
