# CV17: live coverage in the app Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app's mock coverage check with the platform's live public coverage check, so a customer can search an address or drop a pin, see an honest multi-option answer (5G and LTE, covered or planned), and join or leave the notify-me list with proper consent.

**Architecture:** Follow the app's feature layering (`lib/features/coverage`: domain, data with an HTTP repository and the existing mock for the demo flavor, presentation with cubits and pages). The answer is read from the platform's `options[]` result shape (v2); the app never computes a band, a speed or a verdict. Prod flavor uses HTTP only; demo keeps a (rewritten) mock.

**Tech Stack:** Flutter/Dart, cubit + repository, `flutter_map` (already a dependency) for the pin-drop map, `geolocator` (already a dependency) for an opt-in "use my location"; no new dependency without the owner's approval.

**Spec:** the platform's coverage docs, read-only copy at `C:\tmp\g6\docs\coverage` (`result-v2.md`, `leads-demand.md`, `address-step.md`, `embed-print-share.md`, `native-review-af-zu.md`, `accuracy-audit.md` section on the public check, `basemap.md`) and the platform plan `C:\tmp\g6\docs\superpowers\plans\2026-11-13-coverage-reference-and-multi-technology.md` (CV17 row) and `2026-11-16-coverage-platform-reseller-app-execution.md`. Contract snapshot: `test/contract/openapi.json` (platform `f58b00cf`).

## Global Constraints

- **The server decides.** Status, options, primary option, band, speeds, confidence, `near_boundary`, `notify_available`, disclaimer keys, release label and date all come from `GET /v1/coverage/check`. Band and speed figures appear ONLY when the response carries them (they are withheld for a placeholder ladder, a non-downlink basis, or an unaudited dataset); never infer, round, rank or default them. A missing band means show the technology and status without a speed, in words, never a number.
- **Downlink only, "predicted", never a promise.** Every option shows its direction label (`dataset.measure_label_key`) and the "predicted" framing the server's disclaimer keys require; never present uplink as downlink.
- **Privacy.** Coordinates leave the device only when the customer acts (search, tap the map, or "use my location" after the OS permission prompt); coordinates, addresses and contact details are never logged, put in crash reports, written to disk, or sent anywhere except the platform endpoint of the customer's provider (tenant). Remove the phone-geocoder path for customer input (`geocoding` package) from the coverage flow: address search goes to the platform (`POST /v1/coverage/address` when `capabilities.address_lookup` is true, else `GET /v1/geocode/search`).
- **Consent.** Notify-me (waiting list) and the separate "tell me when coverage arrives" consent (`coverage_arrived`) are each their own tick box, unticked by default, with the consent text version from `GET /v1/coverage/meta` (`waitlist_consent_version`, `coverage_arrived_consent_version`). Submitting needs an `Idempotency-Key` (one per attempt, reused on a retry after an unknown outcome, dropped after a final answer), same rules as the credits redeem. Withdrawal: "leave the list" starts `POST /v1/leads/withdrawal-requests`; the confirmation is a one-time link sent to the contact, never completed by the app alone (`POST /v1/leads/withdrawals` only from that link if the app handles deep links; otherwise out of scope, say so).
- **Counsel and language.** Customer copy for the notify-me and withdrawal flows and every "not a promise" disclaimer is counsel-gated (items C1, C2, C4): use the platform's own copy keys and English text, make Afrikaans and isiZulu drafts that fall back to English for disclaimers, band copy and legal wording (a guard stops machine-drafting claims), and list every af/zu string in `docs/L10N_NEEDS_NATIVE_REVIEW.md`.
- **Gating and failure.** An older server (404, route missing), a provider with no active dataset, rate limiting (429 with `Retry-After`), a timeout or a network failure each get a plain-words state with a retry; never a crash or an empty screen. The coverage entry and the first-run coverage onboarding keep working in the demo flavor.
- Prod flavor never registers the mock (the locator test fails both ways: update `stillMockInProd` / `mockUntilLaterTasks` in the same commit as the registration change). No hosted CI claim; no real credentials; no contact with any external system except tests against fakes. Full `flutter test` baseline for this branch: 2,206 passed, 1 skipped.

## Review Focus

1. A point with no coverage and no nearby area (`options` empty, `nearest` null or present): says so in words, offers notify-me only if the server allows it, never shows a made-up speed. (Task 4)
2. A response with unknown fields, unknown `technology`, `kind`, `confidence`, `status`, or disclaimer keys the app has no copy for: the card still renders with a neutral label, nothing throws. (Task 1)
3. Rapid repeated searches and map taps (debounce, out-of-order responses): only the latest result is shown, no flicker to an older answer, one request per settled input. (Task 3)
4. Two taps on "Notify me", a lost response, or a retry: one lead (idempotency key), the screen shows the real outcome, the contact value is never kept after success or leave. (Task 5)
5. Location permission denied or "while using" revoked, GPS off, a point outside the dataset bounds from `meta`, or a pin dropped at sea: explained, search still works. (Task 3)
6. Rate limit (429) and timeouts on a slow mobile network: the retry respects `Retry-After`, the answer is never shown stale as current (show the dataset version/release label of the answer being displayed). (Task 2)

---

## File structure

- Domain: `lib/features/coverage/domain/entities/{coverage_check,coverage_option,coverage_meta,geocode_match}.dart` (new; keep `coverage_result.dart` only if the demo mock still needs it, else retire it with its tests), `domain/repositories/coverage_repository.dart` (extend).
- Data: `data/repositories/http_coverage_repository.dart` (new), `data/coverage_json.dart` (lenient parsing), `mock_coverage_repository.dart` (rewrite on the new entities for demo).
- Presentation: `presentation/bloc/{coverage_cubit,address_search_cubit,notify_cubit}.dart`, pages `coverage_page.dart` (search + map + result), widgets `coverage_option_card.dart`, `notify_me_sheet.dart`, `leave_list_sheet.dart`.
- Modify: `lib/app/locator.dart`, `lib/app/router/app_router.dart` (coverage onboarding keeps its route), `lib/core/network/api_problem.dart` (typed coverage codes), `lib/l10n/app_{en,af,zu}.arb`, `docs/BACKEND_CONTRACT_SYNC.md`, `docs/L10N_NEEDS_NATIVE_REVIEW.md`.
- Tests: `test/coverage/**` plus contract fixtures and `test/locator_test.dart`.

### Task 1: Domain and lenient parsing

**Interfaces:**
- Produces: `class CoverageCheck { String status; String tenant; int shapeVersion; List<CoverageOption> options; int? primaryIndex; Nearest? nearest; List<String> disclaimerKeys; bool waitlistAvailable; int? datasetVersion; String? releaseLabel; DateTime? releaseDate; }`; `class CoverageOption { String technology; String kind; Band? band; SpeedRange? typicalDown; SpeedRange? busyHourDown; String confidence; bool nearBoundary; bool notifyAvailable; DateTime? expectedDate; String measureLabelKey; String sourceKey; }` (every enum-like field is a lenient string-backed type with an `unknown` member, never a throw); `class CoverageMeta { bounds; datasetVersion; datasetActivatedAt; waitlistConsentVersion; coverageArrivedConsentVersion; attribution; minZoom; maxZoom; layers; }`; `class GeocodeMatch { String label; double lat; double lon; }`; `CoverageCheck.fromJson`, `CoverageMeta.fromJson`.
- [ ] **Step 1: failing tests** (`test/coverage/coverage_json_test.dart`): `parses_the_contract_example_with_two_options`, `a_placeholder_ladder_answer_has_no_band_and_no_figures`, `unknown_technology_kind_confidence_and_status_do_not_throw`, `missing_optional_fields_and_nulls_are_handled`, `nearest_is_read_only_when_options_are_empty`, `primary_index_out_of_range_is_ignored`.
- [ ] **Steps 2 to 5:** run FAIL, implement, run PASS, `flutter analyze`, commit.

### Task 2: HTTP repository

**Interfaces:**
- Produces: `CoverageRepository { Future<CoverageCheck> check({required double lat, required double lon}); Future<CoverageMeta> meta(); Future<List<GeocodeMatch>> search(String query); Future<bool> addressLookupAvailable(); Future<LeadAccepted> submitLead(NotifyRequest r, {required String idempotencyKey}); Future<void> requestWithdrawal(WithdrawalRequest r); }` and `HttpCoverageRepository` (tenant query parameter from the app's tenant config, as the other repositories do); typed failures: `CoverageUnavailable` (404 or no active dataset), `RateLimited(retryAfter)`, `Network`, `Timeout`, `Validation`.
- [ ] **Step 1: failing tests** against a fake adapter: `check_sends_lat_lon_and_tenant`, `meta_is_cached_per_session_and_refreshed_on_version_change` (decide the simplest safe rule and say it), `search_prefers_post_address_when_capabilities_allow_else_geocode_get`, `a_429_carries_retry_after`, `an_older_server_without_the_route_maps_to_unavailable_not_a_crash`, `submit_lead_sends_the_idempotency_key_and_both_consents_separately`, `no_coordinates_or_contact_values_appear_in_logged_requests` (use the SafeLogInterceptor test pattern).
- [ ] **Steps 2 to 5:** run FAIL, implement, run PASS, contract fixtures (`test/contract`), commit. Record contract facts and problem codes found in `docs/BACKEND_CONTRACT_SYNC.md` (read `C:\tmp\g6\apps\api\src\sentech_api\modules\coverage` and `leads` routers for exact codes, rate limits and body shapes first).

### Task 3: Search, map pin-drop and location

**Interfaces:** `AddressSearchCubit` (debounced query, results, selection; stale responses dropped by a generation counter), `CoverageCubit` (`checkAt(lat, lon)` with the same generation rule; states `idle | loading | ready(CoverageCheck) | unavailable | rateLimited(until) | error`), the page's `flutter_map` with the platform's tiles only if `meta.layers` and the tile route are usable with the existing map stack (read `docs/coverage/basemap.md`; if the tile layer needs a dependency or a policy decision, ship search plus a plain pin-drop on the base map and record the gap), `useMyLocation()` behind the OS permission prompt with a plain explanation and a denied state.
- [ ] **Failing tests:** `out_of_order_responses_show_only_the_latest`, `rapid_typing_sends_one_request_per_settled_query`, `a_point_outside_meta_bounds_is_explained_without_a_request`, `location_permission_denied_still_allows_search`, `closing_the_page_emits_nothing_after_close`. Run FAIL, implement, run PASS, commit.

### Task 4: Result cards

**Interfaces:** `CoverageOptionCard` for each option (primary first, in the server's order), showing technology, covered or planned with the expected date, the band in words and speed range ONLY if present, confidence in words, near-boundary note, the direction label, the "predicted, not a promise" disclaimer from the server's `disclaimer_keys` mapped to app copy (unknown key falls back to the generic disclaimer), the release label and date, and attribution from `meta`. Empty state for no options (with `nearest` distance band words when present). `notify_available` decides whether the notify action is offered. Accessibility: semantics labels, text scaling, colour never the only signal.
- [ ] **Failing tests:** `shows_no_speed_when_the_server_withholds_the_band`, `shows_primary_option_first_and_all_options`, `planned_shows_the_expected_date_and_notify`, `empty_options_with_nearest_uses_distance_band_words`, `unknown_disclaimer_key_falls_back_to_the_generic_text`, `large_text_does_not_overflow`, `figures_are_never_shown_without_the_predicted_wording`. Run FAIL, implement, run PASS, commit.

### Task 5: Notify me and leave the list

**Interfaces:** `NotifyCubit` (one idempotency key per attempt, reused after unknown outcomes, dropped after a final answer; a double tap sends one request; nothing emitted after close; the contact value is cleared from state after success), `NotifyMeSheet` (contact type and value, area as chosen, two separate consent tick boxes unticked by default showing the server's consent text version, plain result), `LeaveListSheet` (request withdrawal, tells the customer a confirmation link was sent, never claims removal until the link is used).
- [ ] **Failing tests:** `consents_start_unticked_and_are_sent_separately`, `a_double_tap_sends_one_request`, `a_retry_after_an_unknown_outcome_reuses_the_key`, `the_contact_is_cleared_after_success`, `withdrawal_never_claims_removal_before_the_link`, `an_older_server_hides_the_notify_action`. Run FAIL, implement, run PASS, commit.

### Task 6: Locator, gating, demo mock and onboarding

- [ ] Register `HttpCoverageRepository` in prod and the rewritten mock in demo (update the locator lists and test in the same commit); the first-run coverage onboarding route keeps working in both flavors; the demo mock returns believable v2 answers including a placeholder (no band) case, a planned case and an empty case. Failing tests first: `prod_flavor_never_registers_the_mock_coverage_repository`, `onboarding_still_lands_on_coverage_after_a_fresh_sign_in`, `demo_mock_covers_covered_planned_and_empty`. Run FAIL, implement, run PASS, commit.

### Task 7: Languages and docs

- [ ] Add every new string to en, af, zu (af and zu drafts fall back to English for disclaimers, band copy and legal wording), keep `l10n_parity_test.dart` and `tool/l10n_coverage.dart` green, list every af/zu string and the counsel-gated copy in `docs/L10N_NEEDS_NATIVE_REVIEW.md`, update `docs/BACKEND_CONTRACT_SYNC.md` (facts, codes, rate limits, the retired phone-geocoder path), commit.

### Task 8: Full run, review, push gate

- [ ] `flutter analyze` clean; the full `flutter test` (baseline 2,206 passed, 1 skipped) in the background; append "Build notes" to this plan (built, deviations, assumptions, test counts, not built: for example the tile layer if it needed a decision, deep-link withdrawal, offline cache). Independent read-only review (privacy of coordinates and contacts, idempotency and consent, stale-response races, the no-figures-without-band rule, mock unreachable in prod), fixes as ONE list, then ask the owner before pushing.

## Self-review notes

- Spec coverage: result v2 (tasks 1, 4), address lookup and geocode (tasks 2, 3), leads, consent and withdrawal (task 5), privacy and gating (global constraints, tasks 2, 6), copy (task 7). Not covered on purpose: staff counter coverage (platform only), embed and print (web only), the tile layer if it needs a dependency decision (reported, not forced).
- Risks for the builder: the tile layer and map stack, whether `check` requires `tenant`, and which problem codes the lead routes return (read the platform routers first).

## Build notes (2026-11-26)

**Built (tasks 1 to 7, commits 3ad78fb, 32b62ab, 177b30f, 826ada1, f4f89a0, 87ddcc0, ced5e50):** v2 entities and lenient parsing; `HttpCoverageRepository` (check, meta cache, capabilities, address search with POST address or older GET, leads, withdrawal request) with typed failures; `CoverageCubit`, `AddressSearchCubit`, `LocationCubit` (generation guards, debounce, bounds from meta, Retry-After countdown); the screen with search, pin drop on the existing base map, my-location behind the OS prompt, skip button; option cards, notices and data footer; `NotifyCubit`/`NotifyMeSheet` (two separate unticked consents, one key per attempt, `PendingLeadKeys` in memory, wiped on sign-out), `WithdrawalCubit`/`LeaveListSheet` (never claims removal); locator (prod HTTP, demo mock, test fails if prod gets the mock); en/af/zu strings, native-review lists and a guard test; contract fixtures and docs.

**Tests:** full `flutter test` 2,371 passed, 1 skipped (baseline 2,206 + 165); `flutter analyze` no issues. Not run on a device or against a server.

**Deviations:** (1) the mock rewrite moved from task 6 to task 3 so every commit keeps a working demo flow; its tests came with it. (2) The platform's vector tile layer is NOT drawn (needs a vector-tile package: owner decision); pin drop on the existing base map instead. (3) Timeouts share `NetworkFailure` (the app's existing mapping) instead of a separate Timeout type. (4) `addressLookupAvailable` returns `Either<Failure,bool>` like the other repositories. (5) Task 3 page tests and task 4 card tests were written after the code they cover (cubit, repository, notify and locator tests were red first; the page tests were mutation-checked). (6) A speed range is shown only when the response carries both a band and the range; the direction line shows on every covered option and on a planned option only when the basis is not downlink.

**Assumptions:** meta cached 10 minutes per provider and dropped on another dataset version; 350 ms map-tap and 450 ms search debounce; 30 s wait when 429 has no Retry-After; a check with `dataset_version` null and no options is "not available"; the cooling-off notice is the platform's DRAFT text.

**Not built:** vector coverage layer; deep link to complete a withdrawal; offline cache; technology filter chips, print, share, embed and palette toggle (web only); `audited_figures` table; staff counter checks; real af/zu copy.

**Release blockers/open:** cooling-off text is a DRAFT (counsel C1); consent and leave wording is counsel-gated; af/zu are machine drafts or English.
