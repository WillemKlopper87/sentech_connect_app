# App support tickets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a signed-in customer raise a support ticket from the app, follow its replies, answer, close it, and see known network incidents, using the platform's customer ticket routes, while the existing one-way contact form stays as the fallback when ticketing is off.

**Architecture:** Follow the app's feature layering in `lib/features/support` (domain, data with HTTP and mock repositories, presentation with cubits and pages), copying the patterns of `lib/features/credits` (typed failures, lenient parsing, one idempotency key per attempt, an in-memory pending-key holder wiped on sign-out, gating on tenant module AND flag, mock for the demo flavor only).

**Tech Stack:** Flutter/Dart, cubit + repository, existing `ApiClient`; no new dependency.

**Spec:** platform docs, read-only copy at `C:\tmp\g6`: `docs/runbooks/support-ticketing.md` (what the customer routes do, the single switch, rate limits, retention, what a customer sees), `docs/runbooks/support-messages.md`, `docs/superpowers/specs/2026-10-06-support-ticketing-design.md`; server code `apps/api/src/sentech_api/modules/support`; contract snapshot `test/contract/openapi.json` (platform `f58b00cf`): `GET/POST /v1/me/tickets`, `GET /v1/me/tickets/categories`, `GET /v1/me/tickets/{reference}`, `POST /v1/me/tickets/{reference}/close`, `POST /v1/me/tickets/{reference}/messages`, public `GET /v1/support/incidents`, and the existing `POST /v1/support/messages` contact form.

## Global Constraints

- **Gate:** the entry shows only when the tenant plan module `tickets` is on AND the `ticketing` flag is literally `true` and the app config is loaded (the runbook: one switch per provider, the module decides while Sentech's kill switch flag is on). A missing flag, missing module, no config, older server (404), 409 `feature_disabled` or 403 `module_not_enabled` means NO ticket screens and the existing contact form stays the way to reach support; never a crash or an empty screen. Reuse the credits gating helpers and the `refuseModule` session hook.
- **Idempotency:** `POST /v1/me/tickets` and `POST .../messages` each need an `Idempotency-Key`: one key per attempt, reused only after outcomes the app cannot know (network, 5xx, `idempotency_in_progress`, 429), dropped after success or a final refusal or a changed body (server answers 422 `idempotency_key_reused`), a double tap sends one request, nothing emitted after the page closes. Keep unknown-outcome keys in an in-memory holder scoped by tenant slug and user id (and ticket reference for replies), cleared on success, final refusal, sign-out and erase (add to `DefaultPersonalDataWiper` with a test). After an unknown outcome, refresh the ticket list or thread before allowing a different body.
- **Privacy:** ticket text is personal data. Never log it, never put it in crash reports or analytics, never write it to disk or shared preferences; hold a draft only in memory while the screen is open and clear it on success and on sign-out. Show the ticket REFERENCE, never internal ids. No router or Wi-Fi actions in the app (those are staff-only routes). No attachments in v1.
- **Honesty:** show only what the customer routes return. Do NOT promise response times or an SLA (the customer routes carry none); `awaiting_reply` means the provider is waiting for the customer. Show only customer-visible messages the server returns (internal notes never reach the customer). Never claim a ticket is resolved before the server's status says so. Incidents come from the public incidents route only; never invent a cause or time to fix.
- **Rate limits:** the server allows 5 new tickets and 30 messages per customer per hour (429 with `Retry-After`): hold the send button until the wait passes and explain in words.
- **Limits and validation:** respect the server's body and category rules (read `MyTicketCreateIn` and `MyMessageIn` and the router for lengths); validate before sending; the category list comes from `GET /v1/me/tickets/categories`, never hardcoded; an optional order link only if the app already has an order reference to offer.
- **Language:** English first; Afrikaans and isiZulu are machine drafts listed in `docs/L10N_NEEDS_NATIVE_REVIEW.md`; copy that makes a promise or states a policy (retention, response expectations) stays English until reviewed.
- Prod flavor never registers a mock (locator test both directions, update the lists in the same commit). No hosted CI claim, no real credentials, no contact with any external system (tests use fakes). Baseline: full `flutter test` is 2,387 passed, 1 skipped on this branch's base.

## Review Focus

1. A lost response when sending a ticket or a reply: the customer retries, goes back and reopens, or edits the text: exactly one ticket or message, never a duplicate and never the wrong text under an old key. (Task 3)
2. A ticket closed or changed by staff while the customer has the thread open: reply to a closed ticket gets a plain refusal and a refreshed thread, no crash. (Task 3, 4)
3. Ticketing switched off mid-session or an older server: entries disappear or show plain words, the contact form still works, drafts are not kept. (Task 6)
4. A very long thread, many tickets, cursor paging with duplicates and an ended list, pull to refresh while a send is in flight. (Task 3, 4)
5. Ticket text in logs, crash reports, route arguments, deep links or restored state after the app is killed: none. (Task 2, 6)
6. Unknown status, category or author type values from a newer server: neutral display, never a throw. (Task 1)

---

### Task 1: Domain and lenient parsing

**Interfaces:** `Ticket { String reference; TicketStatus status; String categoryKey; String categoryName; bool awaitingReply; DateTime createdAt; DateTime updatedAt; }`, `TicketThread extends Ticket { List<TicketMessage> messages; }`, `TicketMessage { String authorType; String body; DateTime createdAt; }` (author types lenient: customer, staff, unknown), `TicketCategory { String key; String name; }`, `Incident { String id; String title; IncidentSeverity severity; IncidentStatus status; String body; DateTime startedAt; DateTime? resolvedAt; List<IncidentUpdate> updates; }`, `TicketPage { List<Ticket> items; String? nextCursor; }`; enum-like fields are string-backed with an `unknown` member.
- [ ] Failing tests first (run red): `parses_the_contract_examples`, `unknown_status_author_severity_do_not_throw`, `nulls_and_missing_optional_fields_are_handled`, `messages_keep_order_and_never_expose_staff_ids`. Then implement, green, analyze, commit.

### Task 2: HTTP repository and typed failures

**Interfaces:** `SupportTicketsRepository { Future<List<TicketCategory>> categories(); Future<TicketPage> list({String? cursor}); Future<TicketThread> get(String reference); Future<String> create({required String categoryKey, required String body, String? orderId, required String idempotencyKey}); Future<Ticket> reply(String reference, {required String body, required String idempotencyKey}); Future<Ticket> close(String reference); Future<List<Incident>> incidents({String? siteId}); }`, `HttpSupportTicketsRepository`; typed failures for the problem codes you find in the server code (not found, closed, rate limited with retry-after, validation, idempotency reuse and in progress, feature disabled, module not enabled, an older server).
- [ ] Failing tests first against a real `ApiClient` over a fake adapter: `create_sends_the_idempotency_key_and_body`, `reply_to_a_closed_ticket_maps_to_a_closed_failure`, `a_429_carries_retry_after`, `an_older_server_without_the_route_maps_to_unavailable`, `list_follows_the_cursor`, `no_ticket_text_or_reference_appears_in_logged_requests`, `incidents_sends_the_tenant_and_optional_site`. Implement, green, contract fixtures, record the problem codes, limits and body rules in `docs/BACKEND_CONTRACT_SYNC.md`, commit.

### Task 3: Cubits

**Interfaces:** `TicketsCubit` (list, refresh, load more, states loading/ready/unavailable/error), `NewTicketCubit` (categories load, draft in memory only, validate, `submit()` with the one-key rule and an in-memory `PendingTicketKeys` holder), `TicketThreadCubit` (load, refresh, `reply()` with the key rule, `close()`, polling none: refresh on open and pull), `IncidentsCubit` (load, silent failure: incidents are never a blocking error).
- [ ] Failing tests first: `a_double_tap_sends_one_ticket`, `a_retry_after_an_unknown_outcome_reuses_the_key`, `a_changed_body_after_an_unknown_outcome_refreshes_first`, `reply_to_a_closed_ticket_refreshes_the_thread`, `closing_mid_request_emits_nothing_after_close`, `stale_refresh_does_not_overwrite_a_sent_reply`, `a_failed_incidents_load_does_not_block_the_page`, `the_draft_is_cleared_on_success_and_never_persisted`. Implement, green, commit.

### Task 4: Screens

**Interfaces:** `TicketsPage` (list with status and awaiting-reply cue, empty state, pull to refresh, load more), `NewTicketPage` (category picker from the server, body field with the server's limit, validation, rate-limit hold, clear success state showing the reference), `TicketThreadPage` (messages in order with author labels, reply box, close action with confirm, closed state explained), an incidents notice card on the Help home when an open incident exists. Accessibility: semantics, tap targets, text scaling, status never by colour alone.
- [ ] Failing widget tests first: `list_shows_awaiting_reply_and_empty_state`, `create_validates_and_shows_the_reference_after_success`, `send_is_held_during_a_rate_limit_wait`, `thread_shows_messages_in_order_and_hides_nothing_staff_only`, `closed_ticket_hides_the_reply_box_and_says_why`, `large_text_does_not_overflow`, `incident_card_shows_only_server_text`. Implement, green, commit.

### Task 5: Gating, entries, mock hygiene, wiper

- [ ] `ticketsOn(state)` (module `tickets` AND flag `ticketing` literally true AND config ready); entries: "My tickets" and "Contact support" in the Help/Support area and Account; when off the existing contact form is unchanged; `/support/tickets*` routes redirect when off; 409 `feature_disabled` hides the entry through the same refuse-module hook as credits; demo flavor gets a mock with believable tickets and `tickets` on in the demo config; locator registration and the lists/test updated in the same commit; `PendingTicketKeys` wired into `DefaultPersonalDataWiper` with a test. Failing tests first: `entry_is_hidden_when_the_module_or_flag_is_off`, `an_unknown_flag_reads_as_off`, `prod_flavor_never_registers_the_mock_tickets_repository`, `the_contact_form_still_works_when_ticketing_is_off`, `sign_out_clears_the_pending_ticket_keys`. Implement, green, commit.

### Task 6: Languages and docs

- [ ] Every new string in en, af, zu (af and zu drafts, response-expectation or retention wording English only), parity and coverage tests green, `docs/L10N_NEEDS_NATIVE_REVIEW.md` updated, `docs/BACKEND_CONTRACT_SYNC.md` updated (routes, codes, limits, the single switch, what is NOT in the app), commit.

### Task 7: Full run and notes

- [ ] `flutter analyze` clean, the full `flutter test` in the background (baseline 2,387 passed, 1 skipped), "Build notes" appended to this plan (built, deviations, assumptions, test counts, not built: attachments, push notifications, router actions, live polling, deep links). Then an independent review and the owner's approval before any push.

## Self-review notes

- Spec coverage: customer routes (tasks 2 to 4), incidents (tasks 2, 3, 4), gating and the contact-form fallback (task 5), privacy and idempotency (global constraints, tasks 2, 3, 5), copy (task 6).
- Not covered on purpose: attachments, push notifications for replies (the platform has no device-token route), the router tools on a ticket (staff only), live updates.
- Risks for the builder: the body and category limits and exact problem codes (read the server code), whether the contact form is also a ticket source when ticketing is on (the runbook says the public form becomes a ticket instead of the old email: keep the old form call working and say so), and the flag/module names in the app config.
