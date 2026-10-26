# Backend contract sync

Where the app stands against the platform API, route by route. The contract is `test/contract/openapi.json`, a pretty-printed copy of the platform's `apps/api/openapi.json`.

- **Snapshot source:** platform repo `feat/product-gaps` at `39f5a44` (2026-10-26), synced with `dart run tool/sync_openapi.dart <platform>/apps/api/openapi.json`. 340 operations: 51 public or customer, 167 `/v1/admin/*`, 122 `/v1/platform/*`.
- **Contract tests:** `test/contract/openapi_contract_test.dart` checks every fixture in `test/fixtures/api/` against its response schema, every key a decoder reads, the request bodies the app sends (`OtpRequestIn`, `OtpVerifyIn`, `DeleteAccountIn`, `DeleteChallengeIn`), and that every entitlement status, source, origin and scope kind the API can send is typed.
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
| `GET /v1/me/entitlements` | done | `suspended` status, `service` source, nullable `product_id` tolerated; see "Known gaps" |
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

`lib/core/network/api_problem.dart` maps these problem codes; the copy is in en, af and zu (`lib/l10n/failure_copy.dart`).

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
2. **`GET /v1/me/entitlements?status=current` hides suspended passes.** The platform's `current` filter is `status = 'active' AND expires_at > now`, so a `suspended` pass appears only with `status=all` (the app asks for `all` only behind "Show expired passes"). The app is ready to show it (Service suspended, no alerts), but by default the customer will not see it. Backend change proposed: include `suspended` in `current`. This is our assumption, not agreed.
3. **A subscriber's `service` pass** has `source: service` and may have a null `product_id`; both are tolerated.
4. **`DELETE /v1/me` has no 429 in the OpenAPI file**, but the runbook caps delete verifies (10 an hour per customer); the app handles a 429 there like on the sign-in screen.
5. **A customer with no phone number cannot delete through the API.** The app tells them to contact support (the platform's admin POPIA path erases the account).

## What M3 (subscriber screens) builds on

- `ApiClient.delete` with a body and idempotency key, and `post(..., keepSessionOn401: true)` for calls where a 401 is an answer, not a dead session.
- The typed failures above (`SubscriberNotFoundFailure`, `ActiveServiceExistsFailure`, `OrderNotPayableFailure`, `ConsentVersionOutdatedFailure`).
- `PassStatus.suspended` and `PassSource.service`, which a subscriber's service shows up as.
- The module gate `subscriber_billing` from `GET /v1/app-config` (already parsed).
- The contract test pattern: add the fixture to `fixtureSchemas`, the keys to `decoderReads`, the request body keys to the same map.
