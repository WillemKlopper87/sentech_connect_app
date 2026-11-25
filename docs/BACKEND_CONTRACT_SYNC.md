# Backend contract sync

Where the app stands against the platform API, route by route. The contract is `test/contract/openapi.json`, a pretty-printed copy of the platform's `apps/api/openapi.json`.

- **Snapshot source (latest, 2026-11-10):** platform `codex/naas-implementation` at `4ce8ca8c`, see the 5G section at the end. Earlier: `codex/naas-implementation` at `ab5247a` (2026-10-30), synced with `dart run tool/sync_openapi.dart <file>` (the file was `git show origin/codex/naas-implementation:apps/api/openapi.json`). SHA-256 of the snapshot (LF line endings) starts `51749922306a`. 341 operations. New since `ae401a0`: the customer routes `GET /v1/me/subscriber/services` and `.../services/{service_id}` answer `CustomerServiceOut` (plan_name, kind, price, down_kbps, up_kbps, activation_blocker, pending_plan_id, pending_plan_name; `pending_plan_version_id` is deprecated and not read), service and invoice lists are newest first with the `after` cursor (400 `invalid_cursor` for an unknown one), invoices take `status=open`, and `LoginTokenIn` is in the schema. Earlier snapshots: `ae401a0`, `d4be7ce`, `feat/product-gaps` at `39f5a44`.
- **Contract tests:** `test/contract/openapi_contract_test.dart` checks every fixture in `test/fixtures/api/` against its response schema, every key a decoder reads, the request bodies the app sends (`OtpRequestIn`, `OtpVerifyIn`, `DeleteAccountIn`, `DeleteChallengeIn`), the `status=current` fixture with a suspended pass past `expires_at` (`entitlements_current_suspended.json`), and that every entitlement status, source, origin and scope kind the API can send is typed.
- **Rule:** change the snapshot, the fixtures and the decoders in the same commit.

Status words: **done** (real repository, tested), **mock** (a `Mock*Repository` serves it in both flavors, see `stillMockInProd` in `lib/app/locator.dart`), **not started**, **not for the app** (another client uses it).

## Customer and public routes

| Route | App status | Notes |
|---|---|---|
| `GET /v1/tenants` | done | provider picker |
| `GET /v1/app-config` | done | modules, `collection_mode_public`, branding, legal, support |
| `POST /v1/auth/otp/request` | done | sends `binding` (CSPRNG, one per sign-in attempt) and reads `reference`; `turnstile_token` comes from the human check: the Turnstile WebView with the site key and base URL from `GET /v1/auth/human-check/config` (the build defines `TURNSTILE_SITE_KEY` and `TURNSTILE_BASE_URL` only when that route fails), skipped when `required.otp_request` is false or `site_key` is null |
| `POST /v1/auth/otp/verify` | done | sends the same `binding`; a wrong or missing binding is `400 otp_invalid` |
| `POST /v1/auth/token/refresh` | done | single-flight refresh |
| `POST /v1/auth/logout` | done | best effort, bounded |
| `GET /v1/me` | not started | the app reads `/v1/me/profile` instead |
| `GET /v1/me/profile`, `PATCH /v1/me/profile` | done | |
| `GET /v1/me/consents`, `POST /v1/me/consents` | done | `422 consent_version_outdated` is now a typed failure |
| `GET /v1/me/export` | done | |
| `POST /v1/me/delete-challenge` | done | step 1 of deleting the account; a 401 (no phone on the account) does not sign the customer out; `turnstile_token` from the same human check (M2d; skipped when `required.delete_challenge` is false) |
| `DELETE /v1/me` | done | step 2, JSON body `{challenge_id, code}`; `403 reauth_required` for a wrong, used or expired code |
| `GET /v1/hotspots` | done | public, `tenant` query, cursor pages (limit 100); `live` and `maintenance` only; list with maintenance chip, address, empty and error states (fixture `hotspots_page.json` checked against `Page_HotspotPublicOut_`) |
| `POST /v1/orders/{order_id}/cancel` | done | "Cancel order" on the payment screen after a confirm dialog; `order_not_cancellable`, `order_cancelled`, `order_not_found` are the typed failures; the order is reloaded after a refusal |
| `GET /v1/me/entitlements` | done | `suspended` status, `service` source, nullable `product_id` tolerated; `status=current` includes suspended passes (Known gap 2, closed) |
| `POST /v1/me/vouchers/redeem` | done | |
| `POST /v1/support/messages` | done | 202 `{reference}`, shown to the customer to quote. Body `tenant, topic (connecting, payment, pass, account, other), reply {type email or phone, value}, message (10 to 2000 after trimming), order_ref (optional), turnstile_token`; required `Idempotency-Key` header, one key per submission and reused for a retry of the same draft (a changed draft gets a new key, otherwise 422 `idempotency_key_reused`). Public: no session sent. Human check action `support`. Failures typed: `support_unavailable` (Retry-After), `support_contact_not_configured` (the form offers a mailto fallback to the app-config support email), `invalid_message`, `invalid_contact`, 429, 403/503 human check. `HttpSupportMessageRepository`; demo flavor uses `MockSupportMessageRepository` (reference `DEMO-0001`) |
| `GET /v1/auth/human-check/config` | done | `HttpHumanCheckConfigRepository` + `HumanCheckGate`, see Human check (M2d) |
| `POST /v1/me/hotspot/login-token` | done (S10) | `HttpHotspotLoginRepository` posts an empty body (no `mac`: the app cannot read its own; the platform binds the login to the first device that signs in, platform P5b), no Idempotency-Key. Fixture `login_token.json` checked against `LoginTokenOut`; the body checked against the inline `LoginTokenIn` schema. The `handoff` member is ignored |
| `GET /v1/products` | done | |
| `GET /v1/orders`, `POST /v1/orders`, `GET /v1/orders/{order_id}` | done | |
| `POST /v1/orders/{order_id}/cancel` | not started | the app abandons an order, it does not cancel it |
| `POST /v1/orders/{order_id}/checkout` | done | `409 order_not_payable` is a typed failure |
| `POST /v1/payments/{gateway}/notify/{token}` | not for the app | gateway server-to-server |
| `POST /v1/dev/payments/{id}/simulate` | done (dev only) | not in the OpenAPI file; env dev and test only |
| `GET /v1/coverage/check`, `GET /v1/coverage/meta`, `GET /v1/coverage/capabilities` | done (CV17) | `HttpCoverageRepository`, public (no session), `tenant` query; see "Public coverage (CV17)" |
| `POST /v1/coverage/address` | done (CV17) | the platform finds the place for a typed address (the phone's geocoder is no longer used for it); the address is in the body only |
| `GET /v1/geocode/search` | NOT used (CV17 review) | it puts the typed address in the URL; with the address step off the app disables the address field instead |
| `GET /v1/tiles/{layer}/{z}/{x}/{y}.mvt` | not used (CV17) | vector tiles need a renderer the app does not have; a plain pin-drop on the existing base map is used |
| `GET /v1/hotspots` | mock | WP-11 |
| `POST /v1/support/messages` | mock | WP-11 |
| `POST /v1/leads`, `POST /v1/leads/withdrawal-requests` | done (CV17) | the waiting list from the app (`source: app`); the withdrawal request starts leaving the list |
| `POST /v1/leads/withdrawals` | not for the app | only the one-time link's page confirms a withdrawal; the app has no deep link for it |
| `GET /v1/subscriber-plans` | data layer done | `SubscriberPlansRepository` (`HttpSubscriberPlansRepository`, demo `MockSubscriberPlansRepository`), all pages, tenant slug always sent, no session; fixture `subscriber_plans_page.json` (`Page_PublicPlanOut_`). No screen yet (S5). Gate: `subscriberBillingOn` (`modules.subscriber_billing`) |
| `GET /v1/me/subscriber` | data layer done | `SubscriberRepository.getAccount()`; `404 subscriber_not_found` is `Right(null)` (never signed up), not an error; fixture `subscriber_account.json` (`SubscriberAccountOut`) |
| `PATCH /v1/me/subscriber` | not started | S8 (billing contact) |
| `POST /v1/me/subscriber/signup` | done (S5) | `SubscriberRepository.signup(planId, termsVersion, idempotencyKey, installAddress?)` -> `SubscriberSignup{service, invoice}` (201); body `plan_id` + `accept_terms_version` (= `app-config.legal.terms`) always, `install_address` for fixed wireless only, `term_months` never; one `Idempotency-Key` per form draft (reused on retry, rotated on edit and on `consent_version_outdated`); **no human check** on this route; refusals: `consent_version_outdated`, `subscriber_plan_not_found`/`subscriber_plan_inactive`/`subscriber_version_unavailable` (`PlanUnavailableFailure`), `account_closed` (`ServiceStateFailure`, own sentence), `subscriber_profile_invalid`, `customer_link_required`, 503 `service_number_unavailable` (generic retry); `active_service_exists` and `kyc_required` are not emitted here; fixture `subscriber_signup.json` (`SubscriberSignupOut`) |
| `GET /v1/me/subscriber/services`, `GET /v1/me/subscriber/services/{service_id}` | data layer done | `SubscriberRepository.listServices()` (all pages, at most 5 of 50, `after` = `next_cursor`, API order kept: newest first) and `getService(id)`; `CustomerServiceOut` carries the plan facts, `activation_blocker` and the scheduled plan change; no account is an empty list; fixture `subscriber_services_page.json` (`Page_CustomerServiceOut_`). Unknown `status`, `kind`, `suspend_reason` fail loudly (`ServerFailure`); an unknown `activation_blocker` reads as `ActivationBlocker.unknown`. Screens done (S3): `/services` and `/services/:serviceId` (module-gated, bounce home when `subscriber_billing` is off), banners from `activation_blocker` / `suspend_reason` (pure `serviceBannerFor`), scheduled cancel and plan-change notes; Account tab "Home internet" section (`subscriberAccountEntries()` registry in `presentation/subscriber_entries.dart`) |
| `POST /v1/me/subscriber/services/{service_id}/cancel`, `.../change-plan` | not started | M3 |
| `GET /v1/me/subscriber/invoices`, `.../{invoice_id}` | done (S2) | `InvoiceRepository.list({openOnly})` (all pages, API order = newest first, no client sort, `status=open`) and `get(id)`; `SubscriberInvoiceOut`; fixtures `subscriber_invoice.json`, `subscriber_invoices_page.json`. Screens `InvoicesPage`, `InvoiceDetailPage`; routes `/invoices`, `/invoices/:invoiceId` gated by `subscriber_billing`; entry in the Account Home internet section |
| `POST /v1/me/subscriber/invoices/{invoice_id}/checkout` | done (S2) | answers the order `CheckoutOut` (200); `InvoicePaymentCubit` reuses the web view and URL checks and polls the invoice; `Idempotency-Key` per attempt; fixture `invoice_checkout.json`. Dev simulate for invoice payments not verified (P12) |
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
| 409 `collection_mode_not_supported` | `CollectionExternalFailure` (same as `collection_external`) | pay your provider directly |
| 409 `customer_not_active`, `account_not_active`, `account_changed` | `AccountProblemFailure` (a `ValidationFailure`, code kept) | problem with your account, contact your provider |
| 409 `customer_link_required` | `CustomerLinkRequiredFailure` | account not linked to your provider, contact them |
| 422 `subscriber_profile_invalid` | `SubscriberProfileInvalidFailure` | update your contact details before signing up |
| 404 `subscriber_plan_not_found`, 409 `subscriber_plan_inactive`, `subscriber_version_unavailable`, `plan_kind_mismatch` | `PlanUnavailableFailure` (a `ValidationFailure`, code kept) | this plan is no longer available |
| 409 `account_closed`, `illegal_transition` | `ServiceStateFailure` (a `ValidationFailure`, code kept) | this service can't be changed right now |
| 409 `service_cancellation_scheduled` | `CancellationScheduledFailure` | this service is already set to end |
| 409 `service_plan_change_already_billed`, `service_plan_change_already_invoiced` | `PlanChangeBilledFailure` (code kept) | your next period is already billed, try again after it starts |
| 409 `pending_requires_immediate_cancellation` | `PendingCancelFailure` | contact support to cancel a service that has not started |
| 404 `service_not_found` | existing `NotFoundFailure` | we could not find that |
| 400 `invalid_cursor` | generic `ValidationFailure` (code kept) | not shown: the app only sends cursors the API gave it |
| 409 `no_active_entitlement` | `NoActiveEntitlementFailure` | you need an active pass to get online |
| 422 `mac_invalid`, `nas_unavailable`, `login_url_invalid`, `controller_not_supported` | `MacInvalidFailure`, `NasUnavailableFailure`, `LoginUrlInvalidFailure`, `ControllerNotSupportedFailure` | one-tap login fallbacks: use the Wi-Fi login page / try another hotspot |
| 401 on `delete-challenge` | `DeleteCodeUnavailableFailure` | contact support to delete the account |
| 422 `invalid_identity_number` | `KycInvalidIdFailure` | check your ID number |
| 422 `invalid_address` | `KycInvalidAddressFailure` | check your address |
| 422 `invalid_document_encoding`, `document_type_not_allowed`, 413 `document_too_large` | `KycDocumentRejectedFailure` (code kept) | use a clear JPEG or PNG photo under 5 MB |
| 503 `document_upload_failed`, 409 `document_upload_expired` | `KycUploadFailedFailure` (code kept) | we could not upload your document, try again |
| 422 `invalid_consent_version` | `ConsentVersionOutdatedFailure` | review the latest terms (the app sends `app-config.legal.privacy`) |
| 409 `kyc_required` | `KycRequiredFailure` | you need an ID check first (used by signup and plan change) |
| 409 or 422 `unlock_not_available`, 409 `unlock_limit_reached`, `unlock_order_open`, `unlock_service_inactive` | `UnlockNotAvailableFailure`, `UnlockLimitReachedFailure`, `UnlockOrderOpenFailure`, `UnlockServiceInactiveFailure` | 5G data unlock refusals (unlock-order POST; `unlock_not_available` is also 422 on checkout) |
| 409 `unlock_payment_held` | `UnlockPaymentHeldFailure` | checkout of a data-unlock order: payment is being reviewed, do not pay again |
| 409 `idempotency_in_progress` | `IdempotencyInProgressFailure` | still processing, try again in a moment |
| 409 `wallet_frozen`, 409 `customer_inactive` | `WalletFrozenFailure`, `CustomerInactiveFailure` | credits routes: wallet frozen by the provider, or account not active; says so in plain words and disables earning and redeeming |
| 503 `credits_paused` (with `Retry-After`) | `CreditsPausedFailure` (keeps `retryAfter`) | credits are paused for the platform or the provider; balances still read |
| 409 `insufficient_credits`, 409 `redemption_limit_reached`, 422 `pack_not_offered` | `InsufficientCreditsFailure`, `RedemptionLimitReachedFailure`, `PackNotOfferedFailure` | redeem refusals |
| 409 `earn_refused` | `EarnRefusedFailure` | check-in refused by the device or address limits; the server gives no reason on purpose |
| 404 on a coverage or leads route (route missing, with or without a problem body), no active dataset | `CoverageUnavailableFailure` | plain words and a retry, never a crash or an empty screen |
| 503 `address_lookup_unavailable`, 503 `geocoder_unavailable` (with `Retry-After`) | `AddressSearchUnavailableFailure` (keeps `retryAfter`) | address search is off or failed; the location button and the map still work |
| 422 `outside_service_area`, 422 `coordinates_swapped` | `OutsideServiceAreaFailure` | the place is not in South Africa |
| 404, 409 `feature_disabled`, 403 `module_not_enabled` on a credits route | `CreditsNotAvailableFailure` | the repository maps all three to "feature unavailable": the screens hide it, no error, no empty page |

## ID check data handling (slice S4)

`POST /v1/me/subscriber/kyc` carries an ID number, a home address and a photo of an ID document. What the app does with them:

- **Sent once, kept nowhere.** The draft lives in `KycFormCubit` memory only: no `SharedPreferences`, no secure storage, no restore after the app is killed. After a successful send the state is emptied; leaving the form drops it. The picked file is read into memory and deleted at once on Android and iOS (the plugin hands back its own cache copy; on desktop the path may be the original, so it is never deleted there).
- **The photo is re-encoded**: decoded, rotated by its EXIF flag, scaled to a 2000 px long edge, saved as JPEG quality 80 with a fresh, empty EXIF block (no location or device data), under 4 MB. The platform accepts 5 MiB (base64 body up to 7 MiB).
- **Never logged**: `KycSubmission`, `KycFormState` print a redacted `toString`; `PiiScrubber` removes `id_number`, `address_text`, `document` and `install_address` values from any crash or log line; the ApiClient does not log bodies. The ID number is not obscured on screen but autocorrect, suggestions and keyboard learning are off.
- **Screens are capture-protected** (`SecureScreen`, `FLAG_SECURE` on Android).
- **Consent**: `consent_version` is `app-config.legal.privacy` and `consent_via` is `app`. The platform only checks the date format (P13); the privacy notice text is the tenant's configured URL.
- **Platform side** (read from `subscribers/kyc*.py`): ID number and address are stored encrypted, the document goes to private object storage, only the last four characters come back, and records past `retain_until` read as `none`.
- **Permissions**: the system photo picker (Android) and `PHPicker` (iOS) need none. The camera uses `android.permission.CAMERA` (already declared for the voucher scanner; the plugin asks at run time) and `NSCameraUsageDescription` (text extended). `NSPhotoLibraryUsageDescription` is added because App Store policy wants the entry; the app passes `requestFullMetadata: false` so iOS never prompts for the photo library.
- **Store forms** (owner action): Play Data safety must declare "Personal info: government ID numbers, address" and "Photos" as collected, sent to the provider, not shared with third parties, encrypted in transit, deletable on request; the iOS privacy nutrition label needs "Sensitive Info" / "Other User Content" linked to the user, used for App Functionality. The app has no `PrivacyInfo.xcprivacy` yet; the app's own manifest (declaring the ID, address and photo data types, no tracking) should be added before the iOS release, and the plugin manifests checked at that time (not verified here).

## Sign-in security (backend P3 and P4)

- The `binding` is 32 bytes from `Random.secure()` as base64url without padding (43 characters). It lives in memory with the sign-in attempt and is never logged (the log lines carry no bodies and `PiiScrubber` also removes `binding`, `code`, `turnstile_token` and token values).
- One binding per attempt: a resend reuses it (a new request closes only earlier codes of the same binding, and at most 3 codes per phone are live). A new binding is made when the number changes or the flow starts over.
- Dev and test accept sign-in without a human check. **Staging and prod do not**: the app needs the Turnstile build defines below (M2d).

## Human check (M2d)

- **Tier B is built: Turnstile in a WebView** (`TurnstileWebViewProvider`, `lib/core/security/turnstile/`). Tier A (platform attestation, Play Integrity and App Attest) is not built; the research doc (platform repo `docs/research/2026-10-26-mobile-human-check-attestation.md`, verdict GO WITH CHANGES) orders it second.
- **Tier idea.** The repositories only know `HumanCheckProvider` (one per action, from `HumanCheckGate.forAction`). Attestation is added later as a second provider and composed as "attestation preferred, Turnstile as fallback" in `_registerHumanCheck` (`lib/app/locator.dart`); no repository, cubit or screen changes. The server rule stays "a token that is sent is always checked".
- **What is sent.** `turnstile_token` on `POST /v1/auth/otp/request` and `POST /v1/me/delete-challenge`, from a NEW widget run for every request (a resend or a retry gets a new token; a token is never cached, reused or logged). Widget action is `signin`, the only action those routes accept.
- **Hostname rule.** The platform's `TurnstileVerifier` accepts a token only when Cloudflare reports a hostname equal to, or a subdomain of, `SENTECH_TURNSTILE_ALLOWED_HOSTNAMES` (default in staging and prod: the public web hostname). The app loads the widget page as an HTML string with `TURNSTILE_BASE_URL` as base URL, so the page origin is that hostname and Cloudflare reports it. The same hostname must be listed on the Turnstile widget in Cloudflare.
- **Outcomes.** Cancel: nothing is sent and the screen returns to where it was, no error. Widget error, expiry or widget timeout: two quiet resets, then "Try again" in the sheet. No network or a page that does not load in 25 s: "Try again" at once. The check could not be shown at all: `HumanVerificationUnavailableFailure`. The server's 403 `human_verification_failed` and 503 `human_verification_unavailable` (with `Retry-After`) keep their existing typed copy.
- **Demo flavor** never has a WebView and registers no check provider.

## Known gaps and findings

1. **M2d, human check: where the Turnstile site key comes from. RESOLVED (platform `ae401a0`, app `HumanCheckGate`).** The platform now serves the public `GET /v1/auth/human-check/config?tenant=<slug>` (`turnstile.site_key|null`, `base_url|null`, `required.{otp_request, delete_challenge, support_message, lead}`, `Cache-Control: max-age=60`). **Precedence: the API wins**; the `--dart-define=TURNSTILE_SITE_KEY` / `TURNSTILE_BASE_URL` values are only the fallback when the route fails (or answers a key/URL the app cannot use). The answer is fetched on the first check, never at app start, and cached 60 s per provider slug (a failed answer is remembered 15 s). `required.<action>` false: no WebView, no token. `site_key` null (fake verifier on dev stacks): no widget, no token; `POST /v1/support/messages` has `turnstile_token` as a required body field, so the app then sends the dev-stack constant `dev-turnstile-pass` (a real verifier refuses it). Widget action is `signin` for OTP request and delete challenge and `support` for support messages. Lead forms are not in the app, so `required.lead` is read but unused.
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

## Update 2026-10-30 (S9: dashboard from real data)

- Audit row 10 is done. Home composes real sources only: entitlements (`PassesCubit`), `GET /v1/me/subscriber/services`, `GET /v1/me/subscriber/invoices?status=open` and `GET /v1/me/subscriber/kyc` (`HomeOverviewCubit`; each source loads and fails on its own, pull to refresh reloads all). The subscriber sections exist only when `modules.subscriber_billing` is on; with it off Home is the pass-only dashboard and nothing subscriber-related is requested.
- `AccountRepository` left `stillMockInProd`; `MockAccountRepository`, `AccountCubit`, `AccountSummary` (router name, MAC suffix, signal bars, GB used/total, renewal date) and `showRouterCardFor` are deleted. "Paid until" comes from the service's `paid_through`; usage stays on the pass (entitlement). The `cpe` flag now gates nothing on Home.
- Open gap (platform task P10): no customer route for fixed-wireless usage or CPE/router status, so Home shows neither.

## Subscriber track status (2026-10-30)

- **Built against the contract** (fixtures validated against `test/contract/openapi.json`): `GET /v1/subscriber-plans`, `GET|PATCH /v1/me/subscriber`, `GET /v1/me/subscriber/services[/{id}]`, `POST .../services/{id}/change-plan` and `.../cancel`, `POST /v1/me/subscriber/signup`, `GET /v1/me/subscriber/invoices[/{id}]` and `POST .../invoices/{id}/checkout`, `GET|POST /v1/me/subscriber/kyc`. All screens sit behind `modules.subscriber_billing` (`subscriberBillingOn`).
- **Contact details (S8):** `PATCH /v1/me/subscriber` sends only the changed fields (`display_name` 1..120, `email` pattern, `phone_e164`, `language`) with an `Idempotency-Key`; refusals `profile_invalid` (422), `profile_unavailable` and `account_closed` (409) are typed and a `validation_error` carries the rejected field names (`ValidationFailure.fields`). For a customer with no account yet (the `subscriber_profile_invalid` case on signup, which copies the sign-in profile) the same screen edits the sign-in profile with `PATCH /v1/me/profile` (name up to 80, email); the phone is the sign-in identity and read only.
- **Terms version:** a `consent_version_outdated` on signup makes the app re-read `GET /v1/app-config` once (`TenantCubit.refreshConfig`, no loading state), clears the acceptance box when the version changed, and the next submit names the new version with a new `Idempotency-Key`.
- **ID check on the banner:** the services list and detail read `GET /v1/me/subscriber/kyc` only when a service waits for it; `pending` shows "We are checking your ID", `verified` falls back to the generic message, `rejected` or unreadable keeps the ID check prompt.
- **Open platform tasks:** P6, P7, P8, P9, P10, P11, P12, P13 (see the plan, section 5). P5b (token without `mac`, bound on first use) is built in the app (S10) against the platform, now on origin (`codex/naas-implementation` at `8fbcdbd`).

## One-tap hotspot login (S10, audit row 6, 2026-10-30)

- **Snapshot:** `test/contract/openapi.json` matches platform `codex/naas-implementation` at `8fbcdbd` (P5b is on origin; re-sync confirmed byte-identical).
- **Request:** `POST /v1/me/hotspot/login-token`, body `{}`. `LoginTokenIn` (`extra=forbid`) has `mac` (12 to 32 chars, optional since P5b), `nas_id`, `login_url`, `dst`; the app sends none. No `Idempotency-Key` (each call issues a new login). Response 201 `LoginTokenOut{username, password, expires_at, handoff?}`, `Cache-Control: no-store`. Without `mac` the login lives `hotspot_unbound_token_ttl_seconds` (default 300) and binds to the first device that signs in; at three outstanding unbound logins the oldest is superseded (never a 429). A second device is refused by the controller.
- **Codes that can still occur with an empty body:** `409 feature_disabled` (flag `hotspot_radius` off), `409 no_active_entitlement`, `429 rate_limited` (per-address and per-customer hourly limits, `Retry-After: 600`), plus the generic 401, 413, 415, 503. **Cannot occur** without `mac`, `nas_id` and `login_url`: `mac_invalid`, `nas_unavailable`, `login_url_invalid`, `controller_not_supported` (they stay typed; the screen would show their copy). MikroTik is the only controller at launch, other controller kinds answer `422 controller_not_supported`, and only on the hand-off path, which the app does not use.
- **Hand-off ignored:** the app never sends `nas_id` or `login_url`, so `handoff` is absent; if a future platform sends it anyway it is not read and nothing is posted to the controller from the app. The customer signs in on the Wi-Fi login page, opened by "Open Wi-Fi login page" (`http://neverssl.com`, plain HTTP that never redirects to HTTPS, so the captive portal can intercept it; the Android `generate_204` probe is unsuitable).
- **Gates in the app:** the entry shows only with flag `hotspot_radius` on (app-config `feature_flags`) and an entitlement that is `active` and not past `expires_at`; the route `/get-online` redirects to Home when the flag is off. The login is held in memory only, the screen is capture-protected, copies leave the clipboard after 60 seconds (or when the screen closes) if it still holds the copied text.
- **Countdown** uses the device clock against `expires_at`; a large clock error shows the wrong time left (the platform decides validity).

## 5G data usage and paid unlock (fiveg_service, C5c-2, 2026-11-10): SYNCED

- **Snapshot:** `test/contract/openapi.json` re-synced with `dart run tool/sync_openapi.dart C:/tmp/c5c/apps/api/openapi.json` from the platform branch `feat/c5c-backend` / `codex/naas-implementation` at `4ce8ca8c` (the file last changed at `ff02a054`, "regenerate openapi snapshot and TS client for customer unlock (C5c-1)"). 387 operations; SHA-256 of the snapshot (LF) starts `061592ef9068`. Not run against a live backend.
- **Fixtures** `fiveg_usage_{normal,cut_off,slow_lane_restoring,fup,pending_failed}.json` are checked against `DataUsageOut` (with `OfferOut`, `PendingUnlockOut`) and `fiveg_unlock_order.json` against `OrderOut`; `pendingFixtureFiles` is gone. `order_draft.json` and `orders_page.json` now carry the required `kind`. `OrderOut.kind` is `pass | data_unlock`; `OrderLineOut.product_id` is nullable (a data-unlock line has none) and the app never reads it; the order decoder still treats an absent `kind` as a pass (tolerant of old servers, the contract now always sends it).
- **No request-body schema for `POST /v1/me/subscriber/services/{service_id}/data/unlock-orders`:** the platform reads the body through a dependency, so the snapshot has no `requestBody` for it (the contract test asserts that). The body is exactly `{"product_code": string}` plus the required `Idempotency-Key` header; the request test in `test/fiveg_service/http_fiveg_repository_test.dart` pins it. Answers 201 `OrderOut`.
- **Other snapshot changes picked up:** `EntitlementOut.source` gained `credits` (`PassSource.credits`, maps to `PassOrigin.credits`).
- **Problem codes:** `unlock_not_available` (422 on both the unlock-order POST and `POST /v1/orders/{id}/checkout`; the typed table matches 409 and 422 on the code alone), `unlock_limit_reached`, `unlock_order_open`, `unlock_service_inactive` (409), `unlock_payment_held` (409 on checkout of a data-unlock order whose payment is held, succeeded or refunded: `UnlockPaymentHeldFailure`; the payment screen enters `PaymentStatus.paymentHeld`, which offers no pay, retry or cancel, only "Back to Home", with the "being reviewed, do not pay again, support will confirm" copy) and `idempotency_in_progress` (409 on the unlock-order POST when the same key raced a first use: `IdempotencyInProgressFailure`, friendly "still processing, try again in a moment" copy; the `UnlockCubit` keeps the key so the next tap is the same request).
- **`pending_unlock` behaviour:** the platform omits it while the order's payment is held, succeeded or refunded, and it can show `status: "failed"`. A failed unlock order stays resumable and blocks a new purchase (`unlock_order_open`) until cancelled. The app: `unlock_order_open` re-reads the usage and resumes the pending order, failed or not, on the shared payment screen, which already offers "Try again" and "Cancel order" for a failed order; no pending order listed after `unlock_order_open` shows `unlock_payment_held` copy (assumption: the platform only omits it for held, succeeded or refunded payments); if the usage re-read itself fails the original `unlock_order_open` copy is shown. The pending card on the 5G screen keeps its wording ("waiting for payment, continue"): for a failed order it leads to the payment screen's retry or cancel. No backend change is needed.
- **Open assumptions (unchanged, still to confirm with the platform):** `cycle_end` is the last day of the cycle (inclusive); `offers[].bytes_mb` is megabytes; `out_of_bundle` shows "allowance used up, not cut off"; the slow-lane copy hard-codes 5/2 Mbit/s; any 404 on the data routes is "feature off or not eligible"; restore polling is 10 s x 18. `PendingUnlockOut.status` is a free string in the schema; the app only compares it to order statuses for display.

Not verified against a running backend: nothing in this section was run against the real platform.

## Credits (rewards), G7, 2026-11-25: BUILT, NOT RUN AGAINST A SERVER

Read from the platform code at `f58b00cf` (`apps/api/src/sentech_api/modules/credits/{router,engagement_router,views,gate,redemption,pause,schemas}.py`) and the snapshot. Not run against a live backend.

**Routes (all customer token; staff tokens get 403 `customer_required`):** `GET /v1/me/credits` (`CreditsOut`), `GET /v1/me/credits/ledger?limit&cursor` (`CreditEntryPage`, newest first, keyset cursor, 400 `invalid_cursor` for a bad one), `POST /v1/me/credits/redeem` (body `{"credits": int}`, 201 `EntitlementOut` with `source` and `origin_type` `credits`), `GET /v1/me/streak` (`StreakOut`), `POST /v1/me/streak/claim` (200 `StreakClaimOut`, no body), `GET /v1/me/missions` (`MissionsOut`), `GET /v1/me/badges` (`BadgesOut`).

**Gates (every route):** 409 `feature_disabled` when the tenant's `credits` flag is off, then 403 `module_not_enabled` (module key `credits`) when the plan module is off. The two POSTs are "mutating": they also answer 503 `credits_paused` with `Retry-After: 300` when the deployment kill switch or the tenant's pause is on. The five reads keep working while paused. Rate limits: reads 120/min, redeem and claim 20/min (429, `RateLimitedFailure`). The app-config carries the flag as `feature_flags.credits` (absent or false is off) and the module as `modules.credits`; the app shows the entry only when BOTH are on.

**Idempotency:** `Idempotency-Key` is REQUIRED on redeem and claim (400 `idempotency_key_required`; 8 to 128 characters of `A-Za-z0-9_.:-`, else 400 `idempotency_key_invalid`). The same key with the same request replays the stored answer (a redeem returns the original pass and never spends twice). The same key with a DIFFERENT request is refused with 422 `idempotency_key_reused`, so the app starts a new key whenever the pack size changes and reuses the key only to retry the same pack. 409 `idempotency_in_progress` means the first request is still running: retry with the same key. A second claim with a NEW key the same Johannesburg day answers 200 `claimed: false` with what the first claim paid (not an error). The claim stores its `earn_refused` / `wallet_frozen` / `customer_inactive` refusal under the key; a redeem refusal rolls back and is not stored. The optional `X-Device-Id` header on the claim feeds a device velocity check; the app does not send it. **Open item (owner's call):** sending it needs an install id and a privacy decision, so it is not built.

**After a lost response (review fix):** a redeem whose outcome is unknown (network, 5xx, `idempotency_in_progress`, 429) keeps its key in an in-memory holder scoped by provider and customer (never on disk). While it is unresolved only that pack can be tried again, with the same key, even after leaving and reopening the page; success, any final answer, sign-out and account erase clear it, and the wallet is read again after any failed redeem.

**Problem codes found:**

| Route | Status and code | Meaning |
|---|---|---|
| any credits route | 409 `feature_disabled`, 403 `module_not_enabled` | feature off |
| redeem, claim | 503 `credits_paused` | paused (`Retry-After` 300 s) |
| redeem, claim | 409 `wallet_frozen`, 409 `customer_inactive` | frozen wallet, inactive account |
| redeem | 409 `insufficient_credits` | not enough AVAILABLE credits (pending ones are not spendable) |
| redeem | 409 `redemption_limit_reached` | daily limit of packs (`pack_daily_max`, default 3, counted per Johannesburg day; not in `rates`) |
| redeem | 422 `pack_not_offered` | `credits` is not one of `rates.pack_sizes` |
| redeem | 422 `validation_error` | body is not `{"credits": int >= 1}` |
| redeem, claim | 422 `idempotency_key_reused` | the key was used with a different request (the app never does this) |
| claim | 409 `earn_refused` | device or address velocity; no reason given, by design |

**Facts the screens rely on:**

- `rates` (in `CreditsOut`): `mb_per_credit` (default 1, so 1 credit = 1 MB), `ad_credits` (unused, no ads), `pack_sizes` (default 50, 100, 250), `expiry_days` (default 90). Nothing is hard-coded in the app. A redeemed pack's data is `credits x mb_per_credit` MB; its validity (`pack_validity_minutes`, default 1440) and speed are NOT in `rates`: the app shows them from the returned pass (`expires_at`, `speed_kbps`).
- **Expiring soon:** `CreditsOut.expiring_30d` exists (credits that expire within 30 days). The home page shows the banner when it is above zero, with the server's number; nothing is computed from the ledger. There is no field for WHEN, so the banner says "within 30 days". Platform follow-up: an `earliest_expiry_at` would let it say the date.
- **Johannesburg day:** `StreakOut.day` is today in Africa/Johannesburg; `claimed_today` and `run_days` follow it. The app shows `day` and never derives a day from the phone clock or time zone.
- **Capped earn:** `StreakClaimOut.capped_by` names the limit that held credits back (`ad_daily`, `ad_monthly`, `overall_monthly`, `mission_monthly`, `offer_monthly`; an unfamiliar value gets the generic explanation) with `credits: 0`. `CapsOut.overall_month` against `overall_monthly_cap` is the server's own count; the home page says the monthly limit is reached when the count is at or above the cap.
- **Tier:** `CreditsOut.tier` is a free string (`none`, `silver`, `gold`, or null); an unfamiliar value shows no tier. `StreakOut.tier` is a closed enum.
- **Missions and badges:** `progress`, `target` and `status` (`in_progress`, `ready`, `completed`) are the server's. Mission keys today: `first_checkin`, `profile_complete`, `first_purchase`, `first_voucher`, `first_redemption`, `checkins_20`, `purchases_3_month`; badge keys: `first_checkin`, `streak_7`, `streak_30`, `streak_100`, `missions_3`, `missions_10`, `first_redemption`, `tier_silver`, `tier_gold`. The server sends no title, so the app maps these keys to localised names and falls back to a neutral label for an unknown key. A `ready` mission is paid by the next server evaluation.
- Ledger `source` values seen in the platform: `streak`, `streak_bonus`, `mission`, `pack_redemption`, `admin`, `ad`, `referral`, `offer`; the app labels known ones and falls back to the kind (earned, spent, expired, taken back, forfeited).

**Client behaviour worth knowing:** the enums `kind` (ledger), `status` (mission) and `StreakOut.tier` decode an unfamiliar value to an `unknown` member instead of failing the page; the contract test still requires every current value to map to a known member. A 409 `feature_disabled` on a credits route also tells the tenant cubit to hide the credits module at once. Dates on badges and pass expiry use the phone's local time zone for display, as My passes does (only check-in days follow Johannesburg, and those come from the server). In demo, the mock wallet resets on sign-out and a mock redeem adds its pass to the demo passes list.

**Platform follow-ups:** (1) an expiry date next to `expiring_30d`; (2) `pack_daily_max` and how many packs are left today in `rates` or `CreditsOut`, so Redeem can be disabled before a 409; (3) a `paused` flag on `GET /v1/me/credits` so the app can explain a pause before the customer taps; (4) mission and badge titles (or a documented key list) so a new key is not shown with a generic name; (5) `RedeemIn` is declared inline and has no named schema in the snapshot.

Not verified against a running backend: nothing in this section was run against the real platform.

## Public coverage (CV17), 2026-11-26: BUILT, NOT RUN AGAINST A SERVER

Read from the platform code at `f58b00cf` (`apps/api/src/sentech_api/modules/coverage/{router,tiles_router,schemas,options,service,geocode}.py`, `modules/leads/{router,schemas,withdrawal_router,human,contact}.py`, `docs/coverage/*`) and the snapshot (it already holds every route below). Not run against a live backend.

**Routes (all public: no session is sent; `tenant` is optional and defaults to `sentech` on the server, the app always sends the provider's slug):**

| Route | Used for | Limits and notes |
|---|---|---|
| `GET /v1/coverage/check?lat&lon&tenant` | the answer (`CoverageCheckOut`, shape v2) | 60 per minute per client address, 3,000 per minute per tenant; `public, max-age=60`; coordinates are quantised to 5 decimals on the server and the app rounds to 5 before it sends; 422 `outside_service_area` / `coordinates_swapped`; 429 `rate_limited` with `Retry-After`; a provider with no active dataset still answers 200 (`not_covered`, `dataset_version` null) |
| `GET /v1/coverage/meta?tenant` | `CoverageMetaOut`: `dataset_version`, `bounds` `[west, south, east, north]`, the consent text versions `waitlist_consent_version` and `coverage_arrived_consent_version`, `attribution`, `layers` | same limits as the check; the app caches it per provider for ten minutes and drops it when a check answers from another dataset version |
| `GET /v1/coverage/capabilities` | `address_lookup` (is the address step on) | read once per provider per session; a 404 (older server) means "use the older search" |
| `POST /v1/coverage/address?tenant` body `{q}` (3 to 200 characters) | address search, answer `{matched, results[{label, lat, lon, precision}]}` | 30 per minute per client address and one hit per ladder step (up to three), 1,500 per minute per tenant; `no-store`; 503 `address_lookup_unavailable` when no provider is configured (`Retry-After` 30 when it failed); the address is in the body only, never in a URL |
| `GET /v1/geocode/search?q&limit&tenant` | NOT used by the app | the address would be in the query string; with `address_lookup` false (or capabilities 404) the app disables the address field (words: address search is not available, use your location or the map). A capabilities network failure is "unknown", not "off", and is read again; the answer is cached for ten minutes |
| `POST /v1/leads` | the waiting list | `Idempotency-Key` REQUIRED (400 `idempotency_key_required`/`_invalid`); body `tenant, contact{type phone or email, value}, address_text (5 to 300), lat, lon, technology_interest (5g, lte, any), consent{granted, version}, arrival_consent{granted, version}, store (not sent), source ("app"), turnstile_token` (REQUIRED); 10 per hour per client address; 202 `{status: received}` for new and repeat sign-ups alike; 8 KiB body; 422 `consent_required`, `consent_version_outdated` (also for a wrong arrival version), `invalid_contact`, `outside_service_area`, `idempotency_key_reused`; 403 `human_verification_failed`; 503 `human_verification_unavailable` (`Retry-After` 30); 404 `tenant_not_found` |
| `POST /v1/leads/withdrawal-requests` | start leaving the list | body `tenant, contact, turnstile_token`; ALWAYS 202 `received` for a well-formed request, whether or not the contact is on the list; a one-time link (24 hours) goes to the contact; 10 per hour per client, 3 per contact per day; no Idempotency-Key |
| `POST /v1/leads/withdrawals` | confirm with the link's token | NOT called by the app: the link opens the platform's web page (`/leads/withdraw#tenant=...&t=...`, token in the fragment) and only that page confirms |

**The answer (`CoverageCheckOut`) as the app reads it:** `status`, `options[]` in the server's fixed order (`5g`, `lte`), `primary_index`, `nearest` (only when there are no options), `disclaimer_keys`, `waitlist_available` (legacy, read only for an answer with no options), `dataset_version`. Per option: `technology`, `kind` (covered or planned), `band {key, rank, notify}` or null, `typical_down`, `busy_hour_down`, `confidence`, `expected_date`, `near_boundary`, `notify_available`, `dataset {version, release_label, release_date, source_label (a message key), measure_direction, measure_label_key}`. `typical_up` is reserved and always null and is not read. `dataset.audited_figures` (only when the audit gate is open) is not read: the app shows the option's own range, never the dataset's per-band table.

**Rules the app follows (platform `docs/coverage/result-v2.md`):** the server decides everything. A band and a speed range exist only for a covered option of a downlink dataset with an approved ladder and a passed audit; the app shows a range only when the response carries BOTH a band and the range, and drops both for a planned option or a basis that is not downlink; a missing band is "coverage is predicted here" in words with no figure; every option names what its figures measure (`coverage.measure.*`, an unknown key reads as "we do not know"); the primary option is shown first and the rest keep the server's order; `notify_available` decides whether "Notify me" is offered; an empty `options` with a `nearest` shows its distance band in words; `dataset_version` null with nothing found is "not available", never "no coverage".

**Copy keys:** the response carries KEYS, never text. The disclaimer keys in the response (`coverage.estimate`, `coverage.indoor`, `commerce.cooling_off`, `coverage.planned_date`) differ from the platform's i18n catalogue names (`coverage.disclaimer.estimate`, `coverage.indoor_disclaimer`, `legal.cooling_off_notice`, `coverage.disclaimer.planned_date`); the app maps the response keys, as the website does, and an unknown key shows one generic "predictions, not guarantees" text. A covered answer always carries the estimate, indoor and cooling-off notices, as on the website. The cooling-off text is the platform's own DRAFT wording ("DRAFT - needs legal review ...") and must be replaced together with the website's (counsel item C1).

**Human check:** both lead routes verify a Turnstile token with the widget action `lead`; `GET /v1/auth/human-check/config` reports `required.lead: true` always. The app asks `HumanCheckGate` for `HumanCheckAction.lead` (the WebView widget with the platform's site key) and, on a dev stack with no widget, sends the public dev pass `dev-turnstile-pass`, as the support message does.

**Consent:** two separate tick boxes, both unticked: the waiting list (`consent`, version `waitlist_consent_version`) and the optional "tell me if coverage arrives or improves" (`arrival_consent`, version `coverage_arrived_consent_version`, platform item K6; nothing is sent under it yet). The app always sends `arrival_consent` with the real `granted` value; a meta without both versions (an older server) hides the waiting list. A `consent_version_outdated` refusal clears both boxes, reads the meta again and asks the customer to read and tick again.

**Idempotency (leads):** one key per attempt. A retry of the same request after an unknown outcome (network, 5xx, `idempotency_in_progress`, 429, security check unavailable) reuses the key (in memory only, scoped by provider, wiped on sign-out and erase); a changed request or a final answer starts a new key; the platform refuses one key for two different requests (`idempotency_key_reused`). The platform treats a retry as the same request only when the body (without the Turnstile token) is identical, which is why the app keeps a fingerprint of the request with the key.

**Withdrawal:** "leave the list" only STARTS it. The app never claims the contact was removed: that happens when the contact opens the one-time link and confirms on the website. The app has no deep link for the confirmation (out of scope; a platform app link would be needed).

**Retired path:** the coverage screen no longer geocodes a typed address with the phone's map service (`geocoding` package, Google or Apple); the address goes to the platform. The `geocoding` package is still used by registration (reverse geocoding the install address). The location notice no longer says the map service is used when it is opened from the coverage screen.

**Map:** the platform's coverage layers are Mapbox vector tiles (`meta.layers[].url_template`, `.mvt`); the app's map stack (`flutter_map` raster tiles from `TILE_URL_TEMPLATE`) cannot draw them without a vector-tile package, which needs the owner's approval. The coverage layer is therefore not drawn; the customer searches, drops a pin or uses their location on the existing base map, and the answer comes from the check. The base map's tile host still sees the viewport (the existing policy in `osm_map.dart`).

**Fixtures:** `coverage_check_{two_options,placeholder,planned,nearest}.json` (`CoverageCheckOut`), `coverage_meta.json`, `coverage_capabilities.json`, `coverage_address.json`, `lead_accepted.json`, `withdrawal_requested.json` are validated against the snapshot, and every status, technology, kind, confidence, direction, distance band and precision the API can send is asserted to decode (the direction `unknown` reads as unknown).

**Platform follow-ups:** (1) the app needs a way to draw the coverage layer: raster tiles, or an owner decision to add a vector-tile package; (2) turn the address step on (`GEOCODER_PROVIDER=photon`) for every deployment the app uses: without it the app has no address search at all (location and map still work), because the older `GET /v1/geocode/search` carries the address in the URL and the app does not use it; (3) the cooling-off notice is a DRAFT (C1); (4) a universal or app link for `/leads/withdraw` would let the app complete a withdrawal; (5) the response disclaimer keys and the catalogue keys have different names (harmless, but one list would be easier to keep in step).

Not verified against a running backend: nothing in this section was run against the real platform, and the screens were not run on a device (no GPS permission prompt, no Turnstile WebView, no real map).

**Independent review fixes (2026-11-26):**
- *Privacy:* no address ever goes in a URL (see the route table). Lead coordinates are rounded to the same 5 decimals as the check. A meta with no active dataset is not cached, and the "no data yet" retry reads it again (`meta(refresh: true)`).
- *Idempotency (leads):* the key is stored in the in-memory holder BEFORE the request leaves and removed only on success or a final refusal, even if the sheet was closed meanwhile; backing out of the security check changes nothing. The holder is scoped by provider, the place rounded to 5 decimals and the technology, and stores only the key and an "unknown outcome" flag: nothing the customer typed (contact, address) is stored or hashed in it. Because a key is then only a hint, a request the platform sees as different answers 422 `idempotency_key_reused` and the cubit replaces the key once and sends again.
- *Wording:* only network, server and still-processing say "may not have finished". A security check outage (client or 503 `human_verification_unavailable`) and a 429 say the details were not sent or saved. The "may not have finished" notice shows only for the same provider, place and technology.
- *Rate limits:* after a 429 the check, the address search and the lead are held until `Retry-After` has passed (default 30 s when it is missing); the pin stays, the countdown is a live region, and the lead button waits.
- *Result rules:* a band exists for a `covered` option only; an option of an unknown kind is a neutral card (technology, no band, no "predicted coverage" wording) under a neutral title when nothing is covered or planned. The direction line ("predicted download speeds, measured outdoors") shows only on a card that shows a figure. An unknown technology always reads as the neutral "Network". The footer date follows the language.
- *Consent:* the coverage screen asks its own device-only purpose `coverageLocation`, separate from `locationCapture`, which registration still asks with the sentence that the phone's map service (Google or Apple) turns a position into an address. Agreeing to one never skips the other's notice (tested in both orders). Chosen because it is the smallest change the consent store already supports (one enum value, no server mapping).
- *Settings:* `deniedForever` and location-services-off offer "Open settings" (`Geolocator.openAppSettings` / `openLocationSettings`).
- *Release blocker (counsel C1):* the cooling-off notice shown on a covered answer is the platform's DRAFT text ("DRAFT - needs legal review ..."). The app build must NOT ship to production until counsel has settled it and both the website and `coverageDisclaimerCoolingOff` carry the final wording.

## Support tickets, G7, 2026-11-26: BUILT, NOT RUN AGAINST A SERVER

Read from the platform code at `f58b00cf` (`apps/api/src/sentech_api/modules/support/{me_router,schemas_tickets,incidents_router,enabled,state}.py`, `docs/runbooks/support-ticketing.md`, `support-messages.md`) and the snapshot (it already holds every route below). Not run against a live backend.

**Routes (customer token; staff tokens are refused):**

| Route | Used for | Limits and notes |
|---|---|---|
| `GET /v1/me/tickets?cursor&limit` | the customer's tickets, newest first (`Page[MyTicketItem]`) | keyset cursor, default 20; a ticket that has no public message yet (staff opened it with only an internal note) is not listed |
| `POST /v1/me/tickets` | open a ticket, body `{category, body, order_id?}`, 201 `{reference}` | `Idempotency-Key` required; `body` 1 to 4000 characters; `category` is a slug from the categories route; `order_id` must be one of the customer's own orders (404 `order_not_found`); 5 per customer per hour by default (a platform setting, 1 to 100; 429 with `Retry-After`) |
| `GET /v1/me/tickets/categories` | what a ticket can be about (`{items: [{slug, name}]}`) | only active, public categories; the app never hard-codes one |
| `GET /v1/me/tickets/{reference}` | one ticket with its public messages (`MyTicketDetail`) | reference pattern `^[A-Z]{3}-[A-Z0-9]{8}$` (the app refuses anything else before it builds a path); another customer's reference is 404 `ticket_not_found` |
| `POST /v1/me/tickets/{reference}/messages` | reply, body `{body}`, 201 `MyTicketItem` | `Idempotency-Key` required; 1 to 4000 characters; 30 per customer per hour by default (a platform setting, 1 to 1000); REOPENS a solved ticket; a closed one is 409 `ticket_closed` |
| `POST /v1/me/tickets/{reference}/close` | the customer marks it solved, 200 `MyTicketItem` | no body; the new status is `resolved` (NOT `closed`); 409 `ticket_closed`, 409 `ticket_already_resolved`, 409 `ticket_version_conflict` |
| `GET /v1/support/incidents?tenant&site_id` | public incident notices (`PublicIncidentList`) | no sign-in; 60 per minute per client; cached 30 seconds; open incidents and those resolved in the last 24 hours; an incident without a site is always included; when ticketing is off the answer is an empty list (not a 409) |
| `POST /v1/support/messages` | the existing contact form, unchanged | when the provider has ticketing on, the server turns the message into a ticket `SUP-XXXXXXXX` (no email); the app keeps the same call and its receipt wording |

**The single switch (runbook, owner decision 18 November 2026):** the `tickets` plan module turns ticketing on for a provider; the `ticketing` feature flag is Sentech's kill switch and must be on for the deployment (and not turned off for the provider). On every ticket route the server answers 409 `feature_disabled` when ticketing is off for the provider, and that covers BOTH the flag and the module (the kill switch is folded into `module_enabled`); no ticket route uses the plan-module guard, so 403 `module_not_enabled` is not expected from these routes (the app still maps it, as the shared client hides a module on it). The app opens the entry only when the module `tickets` is on AND `feature_flags.ticketing` is literally `true` AND the app config has loaded. On current servers the two are equal (the app-config route sets `feature_flags.ticketing` from the effective module); the AND only matters for older servers, where a missing flag or missing `modules` reads as off.

**What the customer routes return, and what the app shows:** `status` is `new`, `open`, `pending_customer`, `on_hold`, `resolved`, `closed` (an unfamiliar value shows a neutral label). `awaiting_reply` is true when support answered last and the ticket is not closed: the app says support is waiting for the customer's reply and nothing about response times (the customer routes carry no target or time). A message `author` is `you` or `support` only: no staff name or id exists. `body` is null once the retention job has removed the text (365 days after closing): the app says the text is no longer available. A category staff keep private is shown by the server as `other` / "Support". Internal notes, events, assignees and times never reach these routes.

**Problem codes found:**

| Route | Status and code | Meaning in the app |
|---|---|---|
| any ticket route | 409 `feature_disabled`, 403 `module_not_enabled`, plain 404 (older server) | feature off: entry hidden, contact form stays (`TicketsNotAvailableFailure`); the 409 also tells the tenant cubit to hide the `tickets` module at once |
| get, reply, close | 404 `ticket_not_found` | `TicketNotFoundFailure`: plain words, back to the list |
| create | 404 `order_not_found` | the optional order link is not used by the v1 screens |
| create | 422 `category_not_found` | the topic is gone: the categories are read again |
| create, reply | 422 `idempotency_key_reused` | the key was used with a different body (the app starts a new key once) |
| create, reply | 409 `idempotency_in_progress` | still processing: the same key is retried |
| create, reply | 429 `rate_limited` with `Retry-After` | the send button is held until the wait passes |
| create, reply | 400 `idempotency_key_required` / `idempotency_key_invalid` | cannot happen with the app's `app-` + 32 hex key |
| reply, close | 409 `ticket_closed` | plain refusal, the thread is read again |
| close | 409 `ticket_already_resolved`, 409 `ticket_version_conflict` | the thread is read again |
| create, reply | 422 `validation_error` | empty or over-long body; the app validates first |

**Idempotency:** create and reply each need an `Idempotency-Key`; the fingerprint is the keyed hash of the request body, so the same key with a different body is 422 `idempotency_key_reused`. One key per attempt, kept in an in-memory holder (scoped by provider and customer, and by reference for a reply; the key and a one-way hash of the category and text, never the text, so a CHANGED text is never sent under the old key even from a screen opened later) after an outcome the app cannot know (network, 5xx, `idempotency_in_progress`), dropped after success, a final refusal or a 429 (the server stores nothing for a 429, so the attempt is settled and a changed text needs no check), wiped on sign-out and erase (`DefaultPersonalDataWiper`). After an unknown outcome the app reads the ticket list or thread again before it lets the customer send a different text, and counts that check only when the read SUCCEEDED and was shown; a failed read keeps the "may not have been sent" notice and sends nothing. A key is not kept after a restart, so "will not be sent twice" holds only while the app session lasts. The hash is portable (no integer above 2^53, which a web build cannot hold; `test/web_safe_literals_test.dart` guards it).

**Privacy:** ticket text is never logged (the request log carries method and path; `PiiScrubber` masks a reference such as `TKT-7K3M9Q2A` in a path), never written to disk or preferences, never put in a route argument or deep link, and a draft lives in memory only while the screen is open. It is cleared on success and on sign-out.

**Client behaviour worth knowing:** the gate is `ticketsOn` (module `tickets` AND `feature_flags.ticketing` literally `true` AND a loaded config). When it is on, the Help tab shows "New ticket" and "My tickets" in place of the one-way "Submit a ticket" button, plus the incident notice when the provider has an open incident (the Help tab scrolls, so the actions stay reachable at large text); Account gets a "My tickets" row. The dashboard's "Report issue" opens a new ticket when ticketing is on (so the report shows under My tickets; no category is preselected, because the categories are the provider's own and none is identifiable by key) and is the one-way form otherwise. The one-way form (`POST /v1/support/messages`) is unchanged and is the way to reach support when ticketing is off, and every ticket screen that finds the feature unavailable (list, new ticket, a thread) shows a "Message support" button that opens it. The account contact sheet does NOT offer the form (it offers e-mail, phone and WhatsApp). The routes `/support/tickets`, `/support/tickets/new` and `/support/tickets/{reference}` go home when the config is loaded and ticketing is off (switching it off while a page is open closes the page and its draft with it). A 409 `feature_disabled` on any ticket route, and a plain 404 on the list, categories or create route (a server without the routes; a 404 `ticket_not_found` on one thread is not), hides the module at once, in memory, so the Help tab goes back to the old form. The demo flavor registers a mock (tickets, categories, one open incident) and its demo config turns the module and the flag on; the prod flavor never registers it (locator test in both directions). A pending ticket or reply key is wiped on sign-out and account erase; in the demo, sign-out also puts the demo tickets back.

**Sign-out and links (L9):** a signed-out deep link to a ticket sends the customer to the login screen with `from=/support/tickets` (the list), never the reference, and nothing in the app logs router locations; the reference does appear in the path of a request but `PiiScrubber` masks it in the log. A solved ticket (`resolved`) is reopened by a reply for a limited time (the platform auto-closes tickets solved more than `SENTECH_TICKET_AUTO_CLOSE_DAYS` ago, default 7); the app says "a few days" and does not state the number.

**Not in the app (on purpose):** attachments, router or Wi-Fi actions (staff routes only), push notifications for replies (no device-token route), live polling (the thread is read on open and on pull to refresh), deep links to a ticket, the optional order link (the route takes it; the app has no order picker for it), escalation (staff only).

**Fixtures:** `tickets_page.json`, `ticket_detail.json`, `ticket_categories.json`, `ticket_created.json`, `incidents_public.json` are validated against the snapshot; every status, author, severity and incident status the API can send is asserted to decode; the 4000-character body limit is asserted against the schema.

**Platform follow-ups:** (1) the customer thread has no `is_closed` or `can_reply` flag: the app derives it from `status == closed`; (2) there is no per-ticket "last support reply" time, so the list shows `updated_at` only; (3) the hourly limits are only visible on the 429: the app cannot show how many are left; (4) nothing links to the incident route from the platform's own site yet; (5) create returns only the `reference`: returning the ticket header too would save the app a second read; (6) the contact form becomes a ticket (`SUP-`) on a provider with ticketing on, but the form has no session, so it is never tied to the customer and never shows under My tickets: say so to customers or add a link when signed in.

Not verified against a running backend: nothing in this section was run against the real platform, and the screens were not run on a device.

## Checking for drift

Before syncing the snapshot, ask what the platform's newer contract would do to the app:

```
dart run tool/check_contract_drift.dart ../sentech_connect_platform/apps/api/openapi.json
dart run tool/check_contract_drift.dart <file> --json      # same findings as JSON
dart run tool/check_contract_drift.dart <file> --snapshot <saved.json> --manifest <manifest.json>
```

It compares the saved snapshot (`test/contract/openapi.json`) with the given platform file for the operations the app calls, listed in `test/contract/used_operations.json`. Exit code 0 means no BREAKING finding, 1 means at least one, 64 means a usage or input error (missing or invalid file, unknown option). Output is sorted, so two runs on the same files are identical.

- **BREAKING** (exit 1): a used operation removed; a new required parameter (query, path, header) or a parameter that became required; a new required request-body field or a field that became required; a request enum value removed; a response field removed (any field of the 2xx JSON response counts as read, which is conservative); a request or response type changed (including a type added or dropped, such as `null`).
- **RISK** (exit 0): an enum value added to a response enum. The app's parsers are mostly lenient (an unknown value maps to an "unknown" case), so this is not breaking, but the tool cannot tell which parsers decode strictly: check those. Also a request field removed from the schema (a body that forbids extra fields would now reject it).
- **ADDITIVE** (exit 0): new optional parameters, request or response fields, and new request enum values on used operations.
- **NEW CUSTOMER-FACING ROUTES**: operations in the platform file that are not in the snapshot and not used by the app, for any non-admin, non-platform path (`/v1/me`, `/v1/public`, `/v1/coverage`, `/v1/support`, `/v1/geocode`, `/v1/leads`, `/v1/hotspots`, and so on). `/v1/admin`, `/v1/platform`, `/v1/payments`, `/v1/pay` and `/v1/webhooks` are never listed.

**The manifest.** `test/contract/used_operations.json` is the list of `{method, path}` the app calls (path as an OpenAPI template, for example `/v1/orders/{order_id}/cancel`). `test/contract/used_operations_test.dart` keeps it honest: every string literal in `lib/` that starts with `/v1/` must be in the manifest (interpolations such as `${Uri.encodeComponent(id)}` and OpenAPI `{name}` both normalise to `{}`), every manifest path must be called from `lib/`, and every operation must exist in the saved snapshot. To update it: add the line (method in lower case, entries sorted by path then method) when you add a repository call, remove it when you remove one. Limits of the extraction: the HTTP method is not extracted from the code, only the path, so the method comes from the manifest and is checked against the snapshot; a path built as a constant plus a suffix (the ticket thread and `unlock-orders` routes) is not a literal, so its entry carries `"composed": true` and the test requires a literal prefix for it; a path that is not in the platform contract at all (the dev payment simulator) is listed under `outsideContract`. A path assembled from several variables with no `/v1/` literal would not be seen. Parameter names in a template count: a platform rename such as `{order_id}` to `{id}` shows as the operation removed.

**Not covered.** The tool reads the contract, not the app: it cannot know which response fields a decoder really reads, which enum parsers are strict, or behaviour (status codes, error problem types, rate limits). Response status codes and error bodies are not compared. Fixtures and decoders are still checked by `openapi_contract_test.dart` after a sync.

**Where it runs.** Hosted CI is blocked for this repository, so this is a local check: run it before every `tool/sync_openapi.dart`, read the report, fix the app for anything BREAKING (or agree the change with the platform), then sync and commit the snapshot with the model changes. If hosted CI is available later, an optional step (text only, no workflow is changed here) would check out the platform repo, run `dart run tool/check_contract_drift.dart <platform>/apps/api/openapi.json`, and fail the job on exit code 1.

**Tests.** `test/contract/check_contract_drift_test.dart` runs the tool on small documents in `test/contract/drift_fixtures/` (one per detection: removed operation, new required parameter, new required body field, removed response field, changed type, removed request enum value, added response enum value, new optional field, new customer route, new admin route, unchanged, bad input), on the snapshot against itself (no BREAKING), and, when `C:\tmp\g6\apps\api\openapi.json` exists, on that older platform copy (must not crash; skipped otherwise).

**Last run, 26 November 2026**, platform `bec7a9b4` (`apps/api/openapi.json`, 555 paths) against the saved snapshot (548 paths): 60 used operations checked; BREAKING 0, RISK 0, ADDITIVE 0, new customer-facing routes 0 (exit 0). The platform's 8 new operations since the snapshot are all under `/v1/admin` (stock capture) and are not listed.
