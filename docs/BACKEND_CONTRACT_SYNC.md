# Backend contract sync

Where the app stands against the platform API, route by route. The contract is `test/contract/openapi.json`, a pretty-printed copy of the platform's `apps/api/openapi.json`.

- **Snapshot source:** platform repo `codex/naas-implementation` at `d4be7ce` (2026-10-29), synced with `dart run tool/sync_openapi.dart <file>` (the file was `git show origin/codex/naas-implementation:apps/api/openapi.json`). SHA-256 of the snapshot (LF line endings) starts `6784a439aeaa`. 340 operations: 51 public or customer, 167 `/v1/admin/*`, 122 `/v1/platform/*`. Earlier snapshot: `feat/product-gaps` at `39f5a44`. No customer or public route changed between the two; only admin and platform schemas did.
- **Contract tests:** `test/contract/openapi_contract_test.dart` checks every fixture in `test/fixtures/api/` against its response schema, every key a decoder reads, the request bodies the app sends (`OtpRequestIn`, `OtpVerifyIn`, `DeleteAccountIn`, `DeleteChallengeIn`), the `status=current` fixture with a suspended pass past `expires_at` (`entitlements_current_suspended.json`), and that every entitlement status, source, origin and scope kind the API can send is typed.
- **Rule:** change the snapshot, the fixtures and the decoders in the same commit.

Status words: **done** (real repository, tested), **mock** (a `Mock*Repository` serves it in both flavors, see `stillMockInProd` in `lib/app/locator.dart`), **not started**, **not for the app** (another client uses it).

## Customer and public routes

| Route | App status | Notes |
|---|---|---|
| `GET /v1/tenants` | done | provider picker |
| `GET /v1/app-config` | done | modules, `collection_mode_public`, branding, legal, support |
| `POST /v1/auth/otp/request` | done | sends `binding` (CSPRNG, one per sign-in attempt) and reads `reference`; `turnstile_token` comes from the human check: the Turnstile WebView when the build has `TURNSTILE_SITE_KEY` and `TURNSTILE_BASE_URL` (M2d), nothing otherwise |
| `POST /v1/auth/otp/verify` | done | sends the same `binding`; a wrong or missing binding is `400 otp_invalid` |
| `POST /v1/auth/token/refresh` | done | single-flight refresh |
| `POST /v1/auth/logout` | done | best effort, bounded |
| `GET /v1/me` | not started | the app reads `/v1/me/profile` instead |
| `GET /v1/me/profile`, `PATCH /v1/me/profile` | done | |
| `GET /v1/me/consents`, `POST /v1/me/consents` | done | `422 consent_version_outdated` is now a typed failure |
| `GET /v1/me/export` | done | |
| `POST /v1/me/delete-challenge` | done | step 1 of deleting the account; a 401 (no phone on the account) does not sign the customer out; `turnstile_token` from the same human check (M2d) |
| `DELETE /v1/me` | done | step 2, JSON body `{challenge_id, code}`; `403 reauth_required` for a wrong, used or expired code |
| `GET /v1/hotspots` | done | public, `tenant` query, cursor pages (limit 100); `live` and `maintenance` only; list with maintenance chip, address, empty and error states (fixture `hotspots_page.json` checked against `Page_HotspotPublicOut_`) |
| `POST /v1/orders/{order_id}/cancel` | done | "Cancel order" on the payment screen after a confirm dialog; `order_not_cancellable`, `order_cancelled`, `order_not_found` are the typed failures; the order is reloaded after a refusal |
| `GET /v1/me/entitlements` | done | `suspended` status, `service` source, nullable `product_id` tolerated; `status=current` includes suspended passes (Known gap 2, closed) |
| `POST /v1/me/vouchers/redeem` | done | |
| `POST /v1/me/hotspot/login-token` | not started | one-tap hotspot login |
| `GET /v1/products` | done | |
| `GET /v1/orders`, `POST /v1/orders`, `GET /v1/orders/{order_id}` | done | |
| `POST /v1/orders/{order_id}/cancel` | not started | the app abandons an order, it does not cancel it |
| `POST /v1/orders/{order_id}/checkout` | done | `409 order_not_payable` is a typed failure |
| `POST /v1/payments/{gateway}/notify/{token}` | not for the app | gateway server-to-server |
| `POST /v1/dev/payments/{id}/simulate` | done (dev only) | not in the OpenAPI file; env dev and test only |
| `GET /v1/coverage/check`, `GET /v1/coverage/meta`, `GET /v1/tiles/{layer}/{z}/{x}/{y}.mvt`, `GET /v1/geocode/search` | mock | WP-26 |
| `GET /v1/hotspots` | mock | WP-11 |
| `POST /v1/support/messages` | mock | WP-11 |
| `POST /v1/leads` | not for the app | website form |
| `GET /v1/subscriber-plans` | not started | M3 (subscriber screens) |
| `GET /v1/me/subscriber`, `PATCH /v1/me/subscriber` | not started | M3; `404 subscriber_not_found` is typed already |
| `POST /v1/me/subscriber/signup` | not started | M3; `409 active_service_exists` is typed already |
| `GET /v1/me/subscriber/services`, `GET /v1/me/subscriber/services/{service_id}` | not started | M3 |
| `POST /v1/me/subscriber/services/{service_id}/cancel`, `.../change-plan` | not started | M3 |
| `GET /v1/me/subscriber/invoices`, `.../{invoice_id}` | not started | M3 |
| `POST /v1/me/subscriber/invoices/{invoice_id}/checkout` | not started | M3 |
| `GET /v1/me/subscriber/kyc`, `POST /v1/me/subscriber/kyc` | not started | M3 |
| `GET /v1/pay/{tenant_slug}/{invoice_id}/{token}`, `POST` same | not for the app | public invoice pay page (web) |
| `GET /v1/public/records/evidence` | not for the app | public statement evidence |
| `GET /healthz`, `GET /readyz` | not for the app | |
| `POST /v1/webhooks/email/postmark/{token}`, `POST /v1/webhooks/sms/bulksms/{token}` | not for the app | provider receipts |

## Admin and platform routes

All 289 `/v1/admin/*` and `/v1/platform/*` operations belong to the web consoles. **Not for the app.** No decoder in the app reads them.

## Typed problems

`lib/core/network/api_problem.dart` maps these problem codes; the copy is in en, af and zu (`lib/l10n/failure_copy.dart`). The 15 codes from the 2026-10-29 audit (row 15, below the first ten) are typed but no screen uses them yet: they ride along until support, order cancel, invoices and one-tap login are built. Their af and zu copy is a machine-quality draft: see `docs/L10N_NEEDS_NATIVE_REVIEW.md`. Statuses are those the platform routers use; a 409 or 422 with one of these codes is matched on the code alone.

| Status and code | Failure | Shown as |
|---|---|---|
| 422 `binding_required` | `BindingRequiredFailure` | update the app |
| 403 `human_verification_failed` | `HumanVerificationFailedFailure` | try again |
| 503 `human_verification_unavailable` | `HumanVerificationUnavailableFailure` (keeps `Retry-After`) | try again in N seconds or minutes |
| 403 `reauth_required` | `ReauthRequiredFailure` | "That code did not work" |
| 503 `sms_unavailable` | `SmsUnavailableFailure` | try again in a moment |
| 422 `consent_version_outdated` | `ConsentVersionOutdatedFailure` | review the new terms |
| 404 `subscriber_not_found` | `SubscriberNotFoundFailure` (a `NotFoundFailure`) | no service account with this provider |
| 409 `active_service_exists` | `ActiveServiceExistsFailure` | cancel the service first, or contact your provider |
| 409 `order_not_payable` | `OrderNotPayableFailure` (a `ValidationFailure`, code kept) | as before |
| 409 `feature_disabled` | `FeatureDisabledFailure` | not available from your provider |
| 409 `order_not_cancellable` | `OrderNotCancellableFailure` | this order can no longer be cancelled |
| 409 `order_cancelled` | `OrderCancelledFailure` | this order was cancelled (the API uses it as a reconciliation reason; typed in case it rides a 409) |
| 404 `order_not_found` | `OrderNotFoundFailure` (a `NotFoundFailure`) | we could not find that order |
| 503 `support_unavailable` | `SupportUnavailableFailure` (keeps `Retry-After`) | support messages not available, try later |
| 409 `support_contact_not_configured` | `SupportContactNotConfiguredFailure` | provider has not set up support messages |
| 422 `invalid_message`, `invalid_contact` | `InvalidMessageFailure`, `InvalidContactFailure` | check your message / contact details |
| 409 `invoice_not_payable` | `InvoiceNotPayableFailure` | this invoice can no longer be paid |
| 409 `customer_link_required` | `CustomerLinkRequiredFailure` | account not linked to your provider, contact them |
| 422 `subscriber_profile_invalid` | `SubscriberProfileInvalidFailure` | update your contact details before signing up |
| 409 `no_active_entitlement` | `NoActiveEntitlementFailure` | you need an active pass to get online |
| 422 `mac_invalid`, `nas_unavailable`, `login_url_invalid`, `controller_not_supported` | `MacInvalidFailure`, `NasUnavailableFailure`, `LoginUrlInvalidFailure`, `ControllerNotSupportedFailure` | one-tap login fallbacks: use the Wi-Fi login page / try another hotspot |
| 401 on `delete-challenge` | `DeleteCodeUnavailableFailure` | contact support to delete the account |

## Sign-in security (backend P3 and P4)

- The `binding` is 32 bytes from `Random.secure()` as base64url without padding (43 characters). It lives in memory with the sign-in attempt and is never logged (the log lines carry no bodies and `PiiScrubber` also removes `binding`, `code`, `turnstile_token` and token values).
- One binding per attempt: a resend reuses it (a new request closes only earlier codes of the same binding, and at most 3 codes per phone are live). A new binding is made when the number changes or the flow starts over.
- Dev and test accept sign-in without a human check. **Staging and prod do not**: the app needs the Turnstile build defines below (M2d).

## Human check (M2d)

- **Tier B is built: Turnstile in a WebView** (`TurnstileWebViewProvider`, `lib/core/security/turnstile/`). Tier A (platform attestation, Play Integrity and App Attest) is not built; the research doc (platform repo `docs/research/2026-10-26-mobile-human-check-attestation.md`, verdict GO WITH CHANGES) orders it second.
- **Tier idea.** The repositories only know `HumanCheckProvider`. Attestation is added later as a second provider and composed as "attestation preferred, Turnstile as fallback" in `_registerHumanCheck` (`lib/app/locator.dart`); no repository, cubit or screen changes. The server rule stays "a token that is sent is always checked".
- **What is sent.** `turnstile_token` on `POST /v1/auth/otp/request` and `POST /v1/me/delete-challenge`, from a NEW widget run for every request (a resend or a retry gets a new token; a token is never cached, reused or logged). Widget action is `signin`, the only action those routes accept.
- **Hostname rule.** The platform's `TurnstileVerifier` accepts a token only when Cloudflare reports a hostname equal to, or a subdomain of, `SENTECH_TURNSTILE_ALLOWED_HOSTNAMES` (default in staging and prod: the public web hostname). The app loads the widget page as an HTML string with `TURNSTILE_BASE_URL` as base URL, so the page origin is that hostname and Cloudflare reports it. The same hostname must be listed on the Turnstile widget in Cloudflare.
- **Outcomes.** Cancel: nothing is sent and the screen returns to where it was, no error. Widget error, expiry or widget timeout: two quiet resets, then "Try again" in the sheet. No network or a page that does not load in 25 s: "Try again" at once. The check could not be shown at all: `HumanVerificationUnavailableFailure`. The server's 403 `human_verification_failed` and 503 `human_verification_unavailable` (with `Retry-After`) keep their existing typed copy.
- **Demo flavor** never has a WebView and registers no check provider.

## Known gaps and findings

1. **M2d, human check: where the Turnstile site key comes from (open gap on the platform side).** The API exposes NO Turnstile site key and no web page URL: not in `GET /v1/tenants/{slug}/app-config` and not in any other route of the OpenAPI file (the web gets its key from its own `TURNSTILE_SITE_KEY` setting). We did not invent an API change. The app therefore takes two build-time values, `--dart-define=TURNSTILE_SITE_KEY=...` (the PUBLIC site key) and `--dart-define=TURNSTILE_BASE_URL=https://<public web hostname>`. Proposed backend change, our assumption and not agreed: the small public `GET /v1/auth/human-check/config?tenant=` from the research doc (`docs/research/2026-10-26-mobile-human-check-attestation.md` section 5.6) returning `turnstile.site_key` and `turnstile.base_url`, so an owner change needs no app release. When it exists, only `TurnstileConfig` (`lib/core/security/turnstile/turnstile_config.dart`) changes. Without both defines the build sends no token (right for dev and test stacks only).
2. **`GET /v1/me/entitlements?status=current` and suspended passes: closed.** The platform's `current` filter now includes `suspended` passes, even past `expires_at` (list only; RADIUS and voucher redemption still need `active`), fixed at platform `9d3cba5`. The app needed no behaviour change: a suspended pass is shown as Service suspended (never as expired, no countdown, no usage bar), is not `isCurrent` (not usable or connectable), and `UsageAlertPolicy` skips it. Covered by `entitlements_current_suspended.json` and tests in `test/passes_test.dart`, `test/dashboard_pass_card_test.dart`, `test/contract/openapi_contract_test.dart`.
3. **A subscriber's `service` pass** has `source: service` and may have a null `product_id`; both are tolerated.
4. **`DELETE /v1/me` has no 429 in the OpenAPI file**, but the runbook caps delete verifies (10 an hour per customer); the app handles a 429 there like on the sign-in screen.
5. **A customer with no phone number cannot delete through the API.** The app tells them to contact support (the platform's admin POPIA path erases the account).

## What M3 (subscriber screens) builds on

- `ApiClient.delete` with a body and idempotency key, and `post(..., keepSessionOn401: true)` for calls where a 401 is an answer, not a dead session.
- The typed failures above (`SubscriberNotFoundFailure`, `ActiveServiceExistsFailure`, `OrderNotPayableFailure`, `ConsentVersionOutdatedFailure`).
- `PassStatus.suspended` and `PassSource.service`, which a subscriber's service shows up as.
- The module gate `subscriber_billing` from `GET /v1/app-config` (already parsed).
- The contract test pattern: add the fixture to `fixtureSchemas`, the keys to `decoderReads`, the request body keys to the same map.

## Update 2026-10-29

Audit against platform `9d3cba5`: no customer or public route changed since `39f5a44`. `status=current` on entitlements now includes suspended passes (Known gap 2 is fixed on the API). The human-check config route is still not built. The ranked gap list, per-area table and slice order are in `docs/PARITY_AUDIT_2026-10-29.md`.

## Update 2026-10-29 (P0 part 1: re-sync)

Snapshot re-synced to platform `d4be7ce` (see the top of this file); suspended-in-current fixture and tests added; the 15 customer problem codes from audit row 15 typed. Audit row 17 is done. Not done here: the human-check config route (`GET /v1/auth/human-check/config`, audit row 5); the API route is being built separately and the app will read it in a later slice. Pointer: `docs/PARITY_AUDIT_2026-10-29.md`.

## Update 2026-10-30 (P1: hotspots, order cancel, mock entry points)

- `GET /v1/hotspots` is real (audit row 8) and `POST /v1/orders/{order_id}/cancel` is wired (row 11). `WifiHotspotsRepository` left `stillMockInProd`; the demo flavour keeps the mock.
- **Free Wi-Fi by rewarded ad (row 12) and Promotions (row 13) are hidden in prod.** They have no API: `FreeWifiRepository` and `PromotionsRepository` stay in `stillMockInProd`. One switch, `lib/app/mock_feature_guard.dart` (`freeWifiVisible`, `promotionsVisible`), reads that list: a non-demo build hides the Free Wi-Fi card and the promotions banner and redirects `/promotions` home; demo, dev and test builds show them. In prod the Shop shows a plain "Find hotspots near me" entry instead of the ad card.
- They return with the engagement-credits slices (platform plan `docs/superpowers/plans/2026-10-29-engagement-credits-rebaseline.md`): swap the repository in `locator.dart`, remove it from `stillMockInProd` (a test fails otherwise), and Free Wi-Fi additionally needs the provider's `credits` module on (`AppModuleKeys.credits`). No other change is needed to bring the entry points back.
