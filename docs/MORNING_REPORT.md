# Status report — Sentech Connect (updated 2026-10-02, M2 vouchers + RADIUS and the website complete)

**Where we are:** everything in the overnight goal is built and **review-ready**: mobile app, backend core (M0+M1), coverage service (M3a), the public website (M3b, all 16 tasks) and now vouchers + RADIUS/MikroTik (M2). The admin console is not started. Everything is local on feature branches; **nothing has been pushed, merged, published or deployed.**

## Branches and evidence

| Area | Repo / branch | State | Evidence |
|---|---|---|---|
| Mobile app (M4-lite + voucher pass change) | `sentech_connect_app` / `feat/m2-voucher-entitlements` (on top of the app's earlier review-ready work) | Review-ready; latest change: passes tolerate a nullable `order_id` and a `source` field (voucher-redeemed passes have no order) | 712 tests pass, 1 opt-in live test skipped |
| Backend core (M0 + M1) | `sentech_connect_platform` / `m1-hotspot-commerce` | Review-ready: whole-branch review + fix wave accepted | 984 API tests at sign-off |
| Coverage service (M3a) | platform / `m3-coverage-web` | Review-ready: whole-branch review + fix wave accepted | Alembic head 0010 at sign-off |
| Public website (M3b) | platform / `m3b-public-web` | **Complete**: Tasks 1–16 reviewed and accepted; whole-branch review "ready with fixes", fix wave accepted | 859 web tests; `tsc`, `next build`, `npm audit --omit=dev` clean; Playwright e2e (desktop + 375 px, a11y, CSP, budgets, WebGL map) 80 pass / 4 skipped, run once on a private Docker project |
| Vouchers + RADIUS/MikroTik (M2) | platform / `m2-vouchers-radius` (from M3b) | **Complete**: T0–T12, per-task hardened reviews, two whole-branch reviews (vouchers approved; RADIUS no Critical) + fix wave accepted | **2,252 API tests**; migrations **0012–0015**; RADIUS conformance harness **57 PASS** in an isolated Docker project against FreeRADIUS 3.2.7 |
| App ↔ backend live run | — | Passed end to end on 2026-10-01 (OTP → consent → order → fake payment → pass → logout) | Used ~1 h old images and predates M2; **re-run on a fresh build before sign-off** |

Branch chain: `main` → `m0-platform-skeleton` → `m1-hotspot-commerce` → `m3-coverage-web` → `m3b-public-web` → `m2-vouchers-radius`. Review/merge in that order. The app change is a separate branch in the app repo.

## What exists

**Backend (FastAPI, Postgres 18/PostGIS, Redis, Keycloak, Caddy + Cloudflare Tunnel, Prometheus/Grafana/Loki):** forced per-tenant row-level security with guard tests; least-privilege DB logins; phone-OTP login with rotating refresh tokens and reuse detection; tenant lifecycle via audited SECURITY DEFINER functions; catalogue, orders, checkout; payment gateway interface with a fake and a **shape-only Netcash** adapter (gated off in staging/prod until sandbox-verified); per-tenant encrypted payment accounts; entitlements with an append-only usage ledger; notification outbox; POPIA profile/consent/export/deletion; Redis rate limits; daily retention purges; Caddy log masking.

**Coverage (M3a):** GeoJSON import with repair and rollback; public coverage check; address search behind a geocoder interface (offline fake only); hotspot sites; versioned vector tiles; waitlist with encrypted contacts and consent evidence; lead admin; synthetic demo data; self-hosted base-map route.

**Website (M3b, Next.js 16/React 19):** tenant-by-host with sanitised branding; per-request nonce CSP; layout matching the approved mockups; server-side sessions behind sealed cookies, CSRF, rate limits; OTP sign-in and logout; pass catalogue, cart, checkout with consents and double-charge protection; order status page; account portal (passes, orders, profile, SMS consent, data export, deletion); address-first coverage search; MapLibre map on self-hosted PMTiles with hotspot finder; waitlist with Turnstile; per-tenant legal drafts (incl. PAIA manual), support/FAQ with contact form, area pages, sitemap/robots; compose/tunnel wiring and CI e2e. The API sees the visitor's IP through a config-driven trusted-proxy setting (so a move to AWS works).

**Vouchers (M2):** voucher batches with CSPRNG codes (12 symbols plus check symbol), per-tenant HMAC keys, hashed storage; guarded lifecycle (void, extend-only expiry); batch admin API; **PDF/CSV export** sealed in Garage object storage (7 days, 3 single-use downloads, no reprint, crypto-shred); **idempotent redemption** with durable lockout, uniform errors and per-tenant guess caps; redeemed vouchers become entitlements (`source=voucher`); migration 0012.

**NAS registry (M2):** per-tenant MikroTik NAS records with AES-GCM encrypted shared secrets (reseal supported), CIDR validation and denylist, platform-admin approval (Sentech's own tenant is not auto-approved), disable/retire which also disconnects live sessions; hotspot login tokens; migration 0013 and a least-privilege `sentech_radius` DB role.

**RADIUS (M2):** FreeRADIUS 3.2.7 with `rlm_rest` on an internal network talking to an internal `radius-api`; voucher-as-user authorize with MAC/voucher binding, fail-closed rejects and failure-only guess caps; idempotent accounting on cumulative counters; **CoA/Disconnect** (RFC 5176) via a queued worker, with sender/address checks, poison-safe retries and dead-lettering; clients file rendered from the registry and reloaded automatically; MikroTik attribute adapter (other vendors stubbed for M2b); isolation check script run in CI.

**Reconcile and retention (M2):** hourly session reconcile (closes stale/unusable sessions, bounded re-queue), per-tenant fairness and load-shedding design, retention purges (sessions 90 days, export links 30 days); migrations 0014–0015.

**Metrics, alerts, runbooks (M2):** RADIUS and voucher metrics and alerts, regenerated TS client, runbooks `docs/runbooks/radius.md` (NAS onboarding, secret rotation, CoA failing, accounting backlog, Blast-RADIUS, key backup and rotation, pen-test checklist) and `docs/runbooks/voucher-batches.md`.

**Mobile (Flutter):** real API repositories (tenant, OTP session, consent, catalogue/orders, hosted payment, My passes); demo flavour shows hotspot passes; prod hides mock-only features; voucher-redeemed passes display without an order.

**Design and research:** website mockups + PDF (`docs/design/website-mockups/`, approved); research on ISP SaaS and tenant billing (`docs/research/`).

## Owner decisions recorded

2026-10-01: partner API for ISPs with their own app, sign-in per ISP via token exchange (spec §13); billing tiers A (default) and B, Tier C deferred pending counsel (§14); coverage stays inside the main API (§15); SMS budget 5,000 OTP per ISP per hour; map-tile paths may stay unmasked in logs; masked phones show last 4 digits and waitlist locations round to ~100 m; website mockups are the binding design; `PII_KEY` added to the platform `.env` (backup outside the repo).

2026-10-02 (M2, decided autonomously from the preflight; **please confirm or overrule**, cost if wrong is small):
- **Voucher reuse over RADIUS is intended:** a code redeemed in the app can still log in at the hotspot; the device limit applies. Documented in the runbook.
- **Session retention is 90 days** (MAC and session records), overriding the plan's shorter figure.
- **12-symbol codes** (`PFX-XXXX-XXXX-XXXX`, ~54 bits) accepted; spec amended; fallback is 10 symbols with tighter caps. Still an open question below.
- NAS registrations approved by a platform admin; Sentech's own tenant gets an explicit audited approval.
- Anonymous voucher-as-user sessions allowed with MAC/voucher binding (RICA position is a release gate).
- No SMS per redemption; export policy 7 days / 3 downloads / no reprint / crypto-shred, tenant admins only.
- Face value = product price; unsold paper stock expires at the redeem-by date; the pass runs from redemption for the product duration.
- Out of scope, follow-ups: captive-portal page, free ad-gated tier, billing feed, POS/distributor scan.
- Touching the app repo for the nullable `order_id`/`source` change on a feature branch is approved (standing goal).

## Rulings worth your attention

Website (M3b): the web trusts only the API's order status; fake gateway/payments only in dev/test, allowed in staging only with explicit acknowledgement flags (remove before launch); browser mutations need exact Origin plus CSRF; session tokens stay server-side (Redis) and the cookie is an opaque sealed reference; an expired token during a refresh outage gives a retryable 503 rather than a sign-out; the API's Redis rate-limit protocol is preserved; the PAIA manual added as a legal document; branding API widened (migration 0011); contact-message delivery API deferred (release gate); hosting stays portable (Cloudflare Tunnel now, AWS possible).

M2: a dedicated narrow `sentech_radius` DB role (a settable platform-admin flag in the app role was rejected); guess caps count failures only so junk codes cannot lock a tenant out; CoA address required and range-checked (no tenant-chosen UDP targets); accounting idempotent on cumulative counters per grant, session ids tied to the grant; reconcile closes sessions only on NAK/timeout, hourly and bounded; `radius-api` shares a network with the API stack and `radius-worker` shares `radius-data` with `radius-api` (both accepted; the API already holds DB access); RADIUS Redis got its own password (`RADIUS_REDIS_PASSWORD`) after review; migration 0013 was edited in place twice before release, so **dev databases need a volume reset**; small fix diffs with discriminating tests were accepted without a second review.

## Release gates (must happen before launch)

1. **Netcash sandbox verification** (field names, notify validation, 3-D Secure/EFT origins in `PAYMENT_GATEWAY_ORIGINS`), real merchant/ISV terms; remove the fake-payment, fake-SMS, fake-verifier and fake-geocoder acknowledgements from the tunnel overlay.
2. Real SMS provider; Turnstile with hostname/action checks; self-hosted Photon/Nominatim; real coverage import and South Africa PMTiles + attribution.
3. **First green GitHub CI run** (never executed: web e2e, Trivy, RADIUS isolation job); confirm the pinned action SHAs, especially upload-artifact.
4. With `ttli-demo` stopped (its networks collide): rebuild images, re-render `Caddyfile.tunnel`, run `check-caddy-tunnel.sh` and the real-client-IP proof, cold-start smoke, re-run e2e.
5. Keycloak production mode; **key backup and rotation** for `PII_KEY` and the new keys (`VOUCHER_HMAC_KEY`, `VOUCHER_EXPORT_KEY`, `NAS_SECRET_KEY`); NAS master-key rotation is a manual runbook step including resealing secrets under `NAS_SECRET_KEY_PREVIOUS`; voucher HMAC rotation by `key_version` is unbuilt.
6. **Real MikroTik test on a Linux host**, with a VPN path for field routers (WireGuard hub or UDP-capable edge); M2 ships only the VPN-agnostic lab overlay.
7. **FreeRADIUS image digest**: re-verify the pinned digest (`scripts/pin-digests.sh`); live Garage round trip for exports.
8. **Prometheus alert for the `radius-clients` render failure** (re-render and reload are automatic, a failed render is not yet alerted); alert rules have not been run through `promtool`.
9. **Message-Authenticator** is supported but needs RouterOS 7.15 or newer; confirm the version on site and whether hotspots can use `login-by=https`.
10. **Void-after-redeem refund policy** (currently no refund) and the **RICA/ICASA position on anonymous voucher sessions** and 90-day MAC retention: counsel.
11. POPIA: procedure for privacy requests from customers of a suspended ISP; purpose/retention table (audit log, idempotency records); crypto-shred versus backups policy for exports.
12. `needs_review` refund/reconciliation workflow; contact-message delivery API for the website.
13. CSP violation reporting; native isiZulu/Afrikaans review; legal documents and sign-off.
14. Website polish: hero stats need a hotspot count in the meta response.

## Incidents and slips

- **Redis port 6399 (website Task 6):** a test script connected once to a Redis belonging to another local Docker project (one read of a non-existent key; nothing written). Agents are now forbidden to connect to services they did not create.
- **Docker Desktop started once (website Task 15):** an implementer started it for testcontainers; Docker's restart policies brought your `ttli-*`/akaunting containers back up (no connection made to them). Later work used its own project names only.
- **Stray file in `C:\Program Files\Git` (M2 T12):** the agent briefly created a helper file there (outside the repos) and deleted it. Worth a glance if you want certainty.
- **`git stash` during M2 T4:** an implementer stashed and popped within about a minute; the tree was confirmed intact.
- **Mobile:** a repo-wide `dart format` was run and reverted; only the intended files changed.

## OWNER ACTIONS NEEDED

1. **Approve appending secrets to the platform `.env`** (nothing has been written; `dev-up.sh` refuses to start without them): `WEB_SESSION_SECRET`, `VOUCHER_HMAC_KEY`, `VOUCHER_EXPORT_KEY`, `NAS_SECRET_KEY`, `SENTECH_RADIUS_API_SECRET`, `SENTECH_RADIUS_DB_PASSWORD` (then run `scripts/db-roles.sh` on an existing database), `RADIUS_API_SECRET`, `RADIUS_STATUS_SECRET`, `RADIUS_REDIS_PASSWORD`, `GARAGE_S3_KEY_ID`, `GARAGE_S3_SECRET`. Back the keys up outside the repo.
2. **Reset dev database volumes** once (migration 0013 was edited in place); yours to run, your containers were not touched.
3. **Answer the five M2 questions** (end of the M2 plan):
   1. Are 12-symbol voucher codes acceptable on cards and in SMS (spec said `SEN-XXXX-XXXX`)?
   2. Which RouterOS version is on site (Message-Authenticator needs 7.15+), and can hotspots use `login-by=https`?
   3. Who approves NAS registrations operationally (assumed: platform ops)?
   4. Legal: may voucher-as-user sessions stay anonymous under RICA?
   5. Are the export limits (7 days, 3 downloads, no reprint) acceptable to distributors?

## Still to do

- **Admin console** plan and build (ISP portal + Sentech platform console); until then NAS approval, voucher batches and CoA are API-only.
- **Partner API milestone** (spec §13) and **billing Tier B**.
- **Web `/redeem` captive-portal page** (reads the QR fragment, POSTs the code, no third-party scripts): no such page exists on any branch I checked.
- M2b adapters (Ruckus, UniFi, Omada), HotspotBillingFeed outbox (M6a), POS/distributor scan activation, `Framed-IPv6-Address` in CoA, secret mounts/Vault for the clients file, voucher HMAC rotation, platform fee on paper/cash sales.
- Parked minor findings: RADIUS M4, M5, M7, M8 and the rest of M9; voucher minors 4, 7, 8, 9, 10; T10 minors M1, M2, M3, M5 (see the M2 ledger and `review-final-*.md`).

## How to run and review

Platform (Git Bash, from the repo): `scripts/dev-up.sh --build` (needs the `.env` secrets above), then `scripts/smoke.sh http://127.0.0.1:8088`; seed with `python -m sentech_api.devseed` and `scripts/seed-coverage-demo.sh`. RADIUS: with a stack up, `scripts/radius-conformance.sh` (PASS/FAIL per check; 57 expected) and `scripts/check-radius-isolation.sh`; use an isolated Docker project name, not your `ttli-*` stack. API checks from `apps/api`: `ruff check .`, `ruff format --check .`, `mypy src`, `pytest`. Web: `npm test -w apps/web`, `npx tsc --noEmit -p apps/web`, `npm run build -w apps/web`. Mobile: `flutter analyze` and `flutter test`; web demo build `flutter build web --dart-define=APP_FLAVOR=demo`.

Suggested review order: M0/M1, M3a, M3b, then M2 (start with `docs/runbooks/radius.md`, then `review-final-vouchers.md` and `review-final-radius.md`), then the app change `fdfa72b`.

Ledgers with every ruling: `.superpowers/sdd/*/progress.md` in the platform repo (M2 in `2026-10-02-m2-vouchers-radius/`, with `preflight.md`, task reports and reviews alongside); git-ignored.
