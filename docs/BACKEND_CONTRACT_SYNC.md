# Backend contract sync

Where the app stands against the platform API, route by route. The contract is `test/contract/openapi.json`, a pretty-printed copy of the platform's `apps/api/openapi.json`.

- **Snapshot source:** platform repo `codex/naas-implementation` at `ab5247a` (2026-10-30), synced with `dart run tool/sync_openapi.dart <file>` (the file was `git show origin/codex/naas-implementation:apps/api/openapi.json`). SHA-256 of the snapshot (LF line endings) starts `51749922306a`. 341 operations. New since `ae401a0`: the customer routes `GET /v1/me/subscriber/services` and `.../services/{service_id}` answer `CustomerServiceOut` (plan_name, kind, price, down_kbps, up_kbps, activation_blocker, pending_plan_id, pending_plan_name; `pending_plan_version_id` is deprecated and not read), service and invoice lists are newest first with the `after` cursor (400 `invalid_cursor` for an unknown one), invoices take `status=open`, and `LoginTokenIn` is in the schema. Earlier snapshots: `ae401a0`, `d4be7ce`, `feat/product-gaps` at `39f5a44`.
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
| `POST /v1/me/hotspot/login-token` | not started | one-tap hotspot login (S10); the request body `LoginTokenIn` is now described in the contract (P5a), so a request-body contract test can be added there |
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
| `GET /v1/subscriber-plans` | data layer done | `SubscriberPlansRepository` (`HttpSubscriberPlansRepository`, demo `MockSubscriberPlansRepository`), all pages, tenant slug always sent, no session; fixture `subscriber_plans_page.json` (`Page_PublicPlanOut_`). No screen yet (S5). Gate: `subscriberBillingOn` (`modules.subscriber_billing`) |
| `GET /v1/me/subscriber` | data layer done | `SubscriberRepository.getAccount()`; `404 subscriber_not_found` is `Right(null)` (never signed up), not an error; fixture `subscriber_account.json` (`SubscriberAccountOut`) |
| `PATCH /v1/me/subscriber` | not started | S8 (billing contact) |
| `POST /v1/me/subscriber/signup` | not started | M3; `409 active_service_exists` is typed already |
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
