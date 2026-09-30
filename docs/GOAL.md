# Overnight goal (set 2026-10-01)

**Goal.** Bring the Sentech Connect platform — backend (FastAPI), public website (Next.js) and the Flutter mobile app — to a **matured, review-ready codebase**: a working vertical slice for the launch product (**WiFi hotspot access: passes and vouchers, multi-tenant, Sentech as the first tenant**), running locally end to end, with tests, docs and an honest list of what is stubbed or still open. The owner reviews in the morning.

**Authority.** The approved spec (`docs/superpowers/specs/2026-09-30-sentech-connect-platform-design.md`, incl. §12 multi-tenancy) is binding; plans argue from it. Work proceeds without check-ins; decisions are recorded as `Ruling:` lines in the SDD ledger (`.superpowers/sdd/<plan>/progress.md`) and summarised in the morning report.

**Order of work (highest value first).**
1. **M0** platform skeleton (plan `docs/superpowers/plans/2026-09-30-m0-platform-skeleton.md`, in progress via subagent-driven development).
2. **M1** backend core: tenant-scoped catalog, customers with phone-number OTP login (Keycloak + SMS provider interface with a fake), hotspot pass orders, payments behind a `PaymentGateway` interface with a **Netcash Pay Now adapter and a fake gateway** (no real keys), entitlements, notifications interface, admin API.
3. **M4-lite** mobile: replace mock repositories with Dio repositories against the real API behind the existing domain interfaces; `demo`/`prod` flavors; tenant picker; keep analyze/tests green (works with the in-progress hardening branch in `sentech_connect_app`).
4. **M3-lite** website: storefront (plans/passes), coverage search + map using the self-hosted-tiles abstraction, account portal basics, per-tenant theming, deployed in the compose stack.
5. **M2** vouchers (digital + paper batch/PDF, activation, redemption) and the FreeRADIUS/MikroTik integration (config, REST backend, conformance harness against `radtest`).
6. Hardening and docs: README/runbooks, OpenAPI + clients in sync, CI green, security review pass, morning report.

**Done = review-ready when.** All of the following hold on each repo's working branch: tests and linters pass; the stack comes up with the smoke script; the mobile app builds/analyzes clean; every stub/fake is named and listed; the README explains how to run and review; a final whole-branch review has been run and its findings fixed or recorded.

**Hard limits (never crossed while unattended).** No pushes, merges, publishes, deploys or Cloudflare changes; no real credentials or payment/SMS accounts; no deleting or overwriting the owner's existing data; no changes outside `sentech_connect_platform` and `sentech_connect_app` (except reading sibling projects); all work stays on feature branches with commits. Anything needing those goes into the morning report as a question.

**Resume instructions (if context is lost).** Read this file, then the SDD ledger at `.superpowers/sdd/*/progress.md` and `git log` on each repo; tasks with a `Task N: complete` line are done. Continue with the next incomplete task/milestone in the order above.

**Morning report.** Write `docs/MORNING_REPORT.md` in the platform repo (what exists, how to run, what's stubbed, rulings made, open questions, suggested next steps), and mirror a short copy in `sentech_connect_app/docs/`.
