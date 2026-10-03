# Status report — Sentech Connect (updated 2026-10-03: admin console, demo stack, website improvements, admin redesign phase 1 and boot video done)

**Where we are:** since the last report (end of M2, 2026-10-02 morning) five things were built and reviewed: the **admin console** (ISP portal and Sentech platform console, M5a), a **one-command demo stack** that can also run publicly on demoxapp.xyz, **website improvements** (M11), **admin redesign phase 1** (M12, tasks 1-10) and the **app boot video**. Not started: M7 partner API, M8 billing, M9 credits, M10 reseller channel, M2c follow-ups (all have plans). M12 phase 2 is on hold until the usability test (gate G1). **Nothing has been pushed, merged, published or deployed**; the public tunnel has never been started with a real token.

## Branches and evidence

| Area | Repo / branch | State | Evidence |
|---|---|---|---|
| Admin console (M5a) + demo stack + M11 website + M12 phase 1 | platform / `m5-admin-console` (93 commits on top of `m2-vouchers-radius` at `387d079`; HEAD `05de003`) | M5a complete (T1-T14, hardened per-task reviews, two whole-branch reviews, fix waves). Demo stack, tunnel mode and subnets reviewed (no Critical finding). M11 complete. M12 phase 1 complete (broad review, 2 Important fixed, scoped re-review approved) | API **2730 passed / 27 skipped** (full run 674 s after the M12 T5 fix; no API change since, per the ledger); web **2112 passed / 5 skipped** at `05de003` (154 files, fresh run in `fix-phase1-report.md`); `tsc`, message check, `next build` clean; Alembic head **0019** (one head) |
| Admin console, real browser | same | e2e on an isolated HTTPS stack with Keycloak in production mode: 54 pass / 0 fail at M5a T13; M11 website e2e 166/166; M12 task e2e green on private projects (counts per task in the M12 ledger) | Admin e2e is **not in CI yet** (nightly/manual job exists, never run on GitHub) |
| Mobile app | app / `feat/boot-video` (HEAD `37143b5`); it **contains** `feat/m4-lite-real-api` and `feat/m2-voucher-entitlements` (straight line, nothing to merge) | Review-ready; adds the muted boot video | **730 passed, 1 skipped** (full `flutter test` run today, 2026-10-03); boot tests 18 of them; 712 before the boot video (+18 = 730) |
| Earlier platform branches | `m0-platform-skeleton` → `m1-hotspot-commerce` → `m3-coverage-web` → `m3b-public-web` → `m2-vouchers-radius` → `m5-admin-console` | Unchanged since the last report (984 API tests at M1 sign-off; 859 web at M3b; 2,252 API at M2; RADIUS conformance 57 PASS) | See previous ledgers; not re-run today |
| App ↔ backend live run | — | Last passed 2026-10-01; predates M2 and the console | **Not re-run; do it on a fresh build before sign-off** |
| Physical phone / emulator | — | Not available on this host (`adb devices` empty, no Flutter emulator sources). Boot video proven by widget tests only | Not verified on a device |

Review order: M0/M1, M3a, M3b, M2, then `m5-admin-console` (start with the M5a final reviews, then the demo-tunnel review), then the app branch. Platform working tree: only `.superpowers/sdd/2026-10-02-m2-vouchers-radius/progress.md` is dirty (left alone on purpose).

## What exists (new since the last report)

**Admin console (M5a):** staff sign-in through Keycloak (tenant staff and, with a second factor, platform administrators); roles `tenant_admin` (write), `tenant_staff` (read only), `platform_admin`. ISP portal: dashboard, orders, customers (masked by default, POPIA export and erase with reason), pass catalogue, voucher batches (create, activate, void, export), hotspot and NAS registry, leads, staff invitations, branding and support contact, audit trail (reading it is audited). **Sentech platform console:** tenants (create, suspend, offboard, each with typed confirmation), flags, NAS approvals, SMS budgets, platform audit. Hosting: admin host `admin.demoxapp.xyz`, Keycloak face `auth.demoxapp.xyz` (narrow allowlist), reserved tenant labels, split issuer. Runbooks: `docs/runbooks/admin-console.md`, `hosting-demoxapp.md`. Migrations 0016-0019.

**Platform API additions:** tenant-scoped branding function, offboarding with `data_retained`, SMS budgets writable by platform only, read-index migrations, names on order lists (with count-only audit), order summaries and recent orders/passes. Offboarding keeps all data; the erasure process is design only (`docs/runbooks/offboard-purge-design.md`).

**Demo stack (`scripts/demo-up.sh`, runbook `docs/runbooks/demo.md`):** own Docker project `sentech-demo` (other projects refused), loopback ports 8088 / 8180 / 8000, seeded Demo ISP (six passes, two voucher batches, six customers, one pending NAS, four leads, three staff logins). Commands: `up`, `status`, `creds`, `codes` (fake-SMS codes), `pay PHONE|all` (finishes fake-gateway checkouts), `reseed [--new-vouchers]`, `down [--wipe]`, `routes`, `gate-hash`, `--lan`, `--ports-offset`, `--state-dir`. **`up --tunnel`** runs the same demo on demoxapp.xyz behind our own cloudflared connector (staging build, `public-demo` typed every time, connector started last, never restarts by itself), with an optional **storefront password gate** (`DEMO_BASIC_AUTH_USER` / `DEMO_BASIC_AUTH_HASH`, extended to `/v1/*` by default). **Configurable subnets** (option B): `SENTECH_STACK_SUBNET` / `SENTECH_EDGE_SUBNET`, defaults `10.231.250.0/24` and `10.231.251.0/29`, with a consistency and overlap preflight, so it runs beside the ttli stacks. Tests: `test-demo-up.sh` 230, `test-tunnel-net.sh` 70, scripts pytest 44 passed / 2 skipped (as reported at the tunnel review follow-up).

**Website improvements (M11, all copy marked DRAFT):** self-hosted preloaded fonts and byte budgets, loading skeletons and friendlier 404/500, `security.txt` (404 until a contact is set), accessibility statement, cookie notice, fuller privacy/terms/PAIA structure with conditional RICA section, hotspot FAQ in seven groups, minimal `/status` page (probes the API itself), favicon and share cards, phone header fixed (196 → 108 px), e2e guard so tests cannot hit the default stack.

**Admin redesign phase 1 (M12 T1-T10):** calm Sentech-branded tokens and sentence-case type (scoped; public site untouched), admin kit v2 and `/console/_kit` (dev only), plain-language copy and glossary hints, status tabs / one toolbar / result counts / phone card view, audit log in sentences, slim phone header with account menu, Sentech-branded Keycloak login theme (English-only locale, local fonts), danger zones with typed-name confirmation, loading / not-found / error states, section settings, pass duration in friendly units, router options with an always-visible unsigned-router warning. Usability test protocol: `docs/research/2026-10-02-admin-usability-test-protocol.md`.

**Mobile:** muted **boot video** plays in parallel with start-up (skippable after 1.5 s, 12 s watchdog, reduce-motion shows a static logo, `BOOT_VIDEO=false` disables it).

**Research and plans (docs only):** ad networks, credits economics, local business listings, cash-to-voucher reseller channel, tenant billing, admin UX audit, ISP admin benchmark, website improvements; plans for M2c, M7, M8, M9, M10, M11, M12 and specs for credits (M9) and the reseller channel (M10).

## Owner decisions recorded

- **Domain `demoxapp.xyz` through a new Cloudflare tunnel** (option B: new credentials, owner creates the tunnel and places the token in `.env`; we make no Cloudflare changes). **Single-level hosts** only (Universal SSL): `demoxapp.xyz`, `admin.`, `auth.`, `<slug>.demoxapp.xyz`; reserved labels (admin, www, api, auth, keycloak, grafana, status ...) are never tenants.
- **Subnets option B:** configurable, new free defaults (above).
- **Random local `.env` secrets approved** (2026-10-02); the scripts append only missing keys and never print values.
- **Run locally first;** public exposure only through the deliberate `up --tunnel`.
- Earlier (still in force): partner API with token exchange; billing tiers A and B (C deferred); SMS budget 5,000 OTP per ISP per hour; website mockups binding.
- **Research defaults for credits (spec `2026-10-02-engagement-credits-design.md`):** AdMob with Google **test ad units** and a fake SSV signer (real account is a release gate); businesses belong to an **ISP tenant**; **1 credit = 1 MB**, ad = 2 credits, 8 ads/day, 150/month from ads, 300/month overall, referral 100 + 100 after a paid pass and 7-day hold, 90-day expiry, no cash-out or transfer. All are per-tenant settings.
- **Defaults taken, overridable (admin redesign, ledger R1-R14):** launch persona is the ISP owner/manager on phone and desktop (R1); tenant-staff MFA optional and off by default, still required for platform admins (R2); usability test with two ISP operators and one agent before phase 2 (R3); counter staff stay read-only (R8); Keycloak "forgot password" off until SMTP exists (R11).
- Demo stack: tunnel stays staging; seeding of a staging stack runs in a one-off `dev` container (documented workaround).

## Open owner decisions

1. **Reseller channel (M10 spec D1-D11):** D1 launch model A with B fallback and pilot ISP plus five shops; D2 commission (flat 8% or tiered); D3 float limits R500 / R1,500 / R2,000, ceiling R2,000; D4 who pays the SMS (ISP by default); D5 unredeemed validity 30 days or 3 years (CPA-safe); D6 smartphone only or USSD/SMS for feature phones; D7 void window 10 min; D8 top-up channels (EFT and cash deposit only by default); D9 agent ID evidence and who checks; D10 phone binding; D11 discount ever paid as credits (default no).
2. **Credits (M9 plan, two defaults to confirm):** (a) a pass bought with credits has no product behind it, so `entitlement.product_id` becomes optional (alternative: a placeholder product per credit pack); (b) local businesses sign in with revocable scan/manage credentials issued by their ISP, not Keycloak accounts. Also unverified: our real cost per MB and the South African rewarded-ad value ("2 credits per ad" is an assumption; launch with caps and measure 4 weeks); cashback stays off until counsel confirms (CPA s63); ad revenue share with ISPs, AdMob payee entity, iOS strategy (Apple 3.2.2), 18+ rule.
3. **Admin redesign, three confirmations:** persona (R1), tenant-staff MFA (R2), usability test (R3). Defaults stand until you answer. **Arrange the usability test** (two ISP operators, one agent, not Sentech staff; you pick dates); phase 2 (tasks 11-18) cannot start without it. G1 is still "pending".
4. **Boot video trim:** the video is 1.6 MB and its length / trim has not been decided (not verified on a device).
5. **Security contact e-mail** for `security.txt` (and PGP key yes/no), **SVG brand mark** for the favicon (a neutral Wi-Fi placeholder ships), confirm the minimal status page is wanted.
6. **Legal review of all DRAFT copy:** privacy, terms, PAIA manual, RICA applicability, accessibility statement, cookie notice; per-tenant legal-entity and Information Officer fields are deferred.
7. **Offboard erasure design** (`offboard-purge-design.md`): retention window after offboarding (suggested 90 days), cooling-off (7 days) and four more decisions listed there.
8. Earlier open questions still unanswered: RouterOS version on site and `login-by=https`, anonymous voucher sessions under RICA, export limits, void-after-redeem refund policy.
9. Admin e2e in CI, and a GitHub remote (the platform checkout has no remote, so CI cannot run).

## Rulings worth your attention

- **Admin security model kept strict:** Keycloak login plus a `staff_user` row plus second factor for platform admins; staff invitations are provisioned **manually** in Keycloak (an API credential able to create users was judged too large a privilege); `verifyEmail` is not enforced without SMTP.
- **Names on order lists** add a count-only sensitive-read audit (names never enter audit or logs); customer lists use Active / Erased tabs (no combined All).
- **Offboard keeps all data** today; the dialog says so. Do not offboard a tenant with real customers before the purge process exists.
- **Demo through the tunnel is the staging build:** the dev payment route does not exist there; strangers can still use the fake gateway's order flow and the request side of the fake SMS sender (never read codes). The password gate is default **off**, strongly recommended; Cloudflare Access (free) is the preferred gate and should also cover `admin.demoxapp.xyz`. The mobile app cannot pass basic auth, so for an app demo use local `adb reverse` or set `DEMO_GATE_API=0`.
- **Keycloak public face** is an allowlist (login pages, logout, keys, theme); token, userinfo, account console and master realm are 404 (path-trick probes tested).
- **Admin CSS/heading changes are scoped** to the console; the owner-approved public mockup headings stay. `style-src-attr 'unsafe-inline'` stays (React style props).
- **Phone menu** moves focus to the new page heading for up to 3 s (the heading arrives after the route changes); unmatched admin URLs still show the public 404 (product routing decision, parked).
- Customer actions that ship: resend receipt SMS and disconnect now. Block, gift data and remove device have no backend and no buttons.
- Migrations 0016-0019 were edited in place before release and 0018 uses `CHECK NOT VALID` (validate by hand on an existing database). **Dev databases need a volume reset** (as already noted for 0013).
- Parked: `approve_nas` lock needs a definer function, reserved-label list extension, lead dedupe, unique `lower(email)` on staff, export stream status re-check; M2 minors from the earlier report.

## Release gates (before any launch)

1. **Netcash sandbox verification** and real merchant terms; remove fake-payment, fake-SMS, fake-verifier and fake-geocoder acknowledgements from the tunnel overlay.
2. **Real SMS and e-mail providers** (OTP, receipts, support-message delivery, staff invitations); **Keycloak SMTP** so verified e-mail and "forgot password" can be switched on.
3. **Turnstile** with hostname/action checks; self-hosted geocoder; real coverage import and South Africa PMTiles with attribution.
4. **Counsel:** NPS Act / e-money for the reseller wallet, FICA, VAT, CPA s63 (vouchers, credits, cashback), opt-out registry (marketing consent), Apple App Store 3.2.2 (rewarded ads), RICA / ICASA on anonymous voucher sessions and 90-day MAC retention, POPIA purpose and retention table.
5. **Real MikroTik test on a Linux host** with a VPN path for field routers; RouterOS 7.15+ for Message-Authenticator.
6. **Phone device test** of the app (including the boot video and the 10.0.2.2 / `adb reverse` path); re-run the app ↔ backend live run on fresh builds.
7. **First green GitHub CI run** (never executed: web e2e, admin e2e, Trivy, RADIUS isolation, promtool step); confirm pinned action SHAs.
8. **Tunnel real-session verification:** the connector, public hostnames, DNS, `__Host-` cookies over HTTPS, a real browser sign-in to `admin.demoxapp.xyz`, gated map tiles, and the real-client-IP proof through Cloudflare were **not** proven (only against throwaway stacks without cloudflared).
9. **Offboard erasure process** built before any real tenant is offboarded; POPIA procedure for customers of a suspended ISP.
10. Key backup and rotation (`PII_KEY`, voucher, export and NAS keys, the new `SENTECH_ADMIN_CLIENT_SECRET`); Keycloak production mode on the real host; raise HSTS; edge rate limits for the admin host.
11. Real ad account, ad units and payout/tax set-up (before M9 ships); real FreeRADIUS image digest check; Garage round trip for exports; alert for a failed `radius-clients` render (M2c).
12. Native isiZulu / Afrikaans review, CSP violation reporting, legal documents signed off, contact-message delivery API.

## Incidents and slips

- **Redis port 6399 (website T6, earlier):** one read of a missing key on another project's Redis; nothing written. Agents may only touch services they created.
- **Docker Desktop started once (website T15, earlier)** by an implementer for testcontainers; ttli containers came back up by their own restart policy. Later work used its own project names only.
- **Stray file in `C:\Program Files\Git` (M2 T12):** created briefly and deleted; worth a glance.
- **Repo-wide `dart format` (app):** run once and reverted.
- **An agent printed its own shell environment** into its tool output once (a mistyped `eval`, subnets task). It reported no repository secrets in it. `render-caddy.sh` also opened the repo `.env` (no output kept); the script now reads only the eleven subnet keys.
- **Playwright global setup targeted the default stack** (found in M11 T1). Now guarded: it refuses the default stack unless explicitly allowed.
- **Private scratch credential files that agents could not delete** (the approval layer blocked removal; the Docker projects themselves were wiped). **Please delete these yourself:**
  - `C:\Users\Wille\AppData\Local\Temp\sentech-m12t6-1002\` (contains `demo.env`, `e2e\admin-seed.json`, `e2e\platform-pick.txt`; `state` is empty)
  - `C:\Users\Wille\Downloads\applications\sentech_connect_platform\.superpowers\sdd\2026-10-02-m12-admin-portal-redesign\stack-task9\` (`stack.env`, `e2e\admin-seed.json`, `e2e\platform-pick.txt`)
  - `...\2026-10-02-m12-admin-portal-redesign\stack-phase1\` (`scratch.env`, `e2e\admin-seed.json`) found by my file listing; the ledger only says the project was wiped
  - Not mine to explain: `C:\tmp\smoke_token.env` (314 bytes, dated 9 Aug, origin not verified; contents not read)
  - All paths under `.superpowers/` are git-ignored; the stacks they belonged to no longer exist.
- **Exposed in chat:** a demo gate password and the demo logins were pasted into a chat. Treat them as exposed: generate a new gate with `scripts/demo-up.sh gate-hash`, and `down --wipe` then `up` to get new demo logins before any public run.
- **Windows encoding slip (M12 T6):** an intermediate commit was amended after a default text encoding mangled seven ellipses; the corrected package was re-reviewed. Agents now read and write UTF-8 explicitly.
- A `git stash`/pop in M2 T4 (earlier) was confirmed intact. One usage-limit interruption of M12 T9; resumed with the existing failing tests kept.

## OWNER ACTIONS NEEDED

1. **Cloudflare (only you can):** create the tunnel, put `CLOUDFLARE_TUNNEL_TOKEN` and `PUBLIC_DOMAIN=demoxapp.xyz` in `.env`, add public hostnames `demoxapp.xyz`, `www`, `admin`, `auth`, `*` (exact names first) all to `http://caddy:80`, SSL mode Full; optional Access policy on `admin.demoxapp.xyz`.
2. **Stop your standalone cloudflared** if it uses this tunnel's token (on this PC `youthful_hertz`): `docker stop youthful_hertz`. Leave the ttli connector alone.
3. **Delete the leftover scratch credential files** listed above; **rotate** the gate password and demo logins that were pasted into chat.
4. Answer or accept the defaults in "Open owner decisions"; arrange the usability test.
5. Reset dev database volumes once (migrations edited in place); the `.env` secret additions you approved are appended by the scripts when missing.

## Still to do (recommended order)

1. **M2c follow-ups** (8 tasks, planned, not started): `/redeem` QR page, stale RADIUS-clients alert, security minors, website hero hotspot count, contact-message delivery.
2. **M7 partner API** (13 tasks) → **M8 billing Tier B** (12 tasks, migrations 0024-0027) → **M9 engagement and Connect Credits** (19 tasks) → **M10 reseller channel** (16 tasks). Plans exist in `docs/superpowers/plans/`; ledgers hold only the plan path.
3. **M12 phase 2** (tasks 11-18: Today home, grouped navigation, search, customer timeline, reports, saved filters, optional staff MFA 0050) after the usability test G1.
4. Offboard purge build, M2b adapters (Ruckus, UniFi, Omada), billing feed, POS scan, voucher HMAC rotation.

## How to run and review

**Demo (Git Bash, repo root, Docker Desktop running, ports 8088 / 8180 / 8000 free):**
1. `scripts/demo-up.sh` (first run 5-10 minutes; asks before appending missing `.env` keys), then `scripts/demo-up.sh creds`, `codes`, `scripts/demo-totp.sh`.
2. URLs: `http://localhost:8088` (Sentech site), `http://demo.localhost:8088` (Demo ISP), `http://admin.localhost:8088` (console).
3. Public: stop any standalone cloudflared on the same token, set `.env` (token, domain), `scripts/demo-up.sh gate-hash` for a new gate (paste only the two printed lines into `.env`), then `scripts/demo-up.sh up --tunnel` (type `continue` and `public-demo`). After a reboot run it again.
4. Stop: `scripts/demo-up.sh down` (data kept); reset: `down --wipe` (type the project name).

**Checks:** API from `apps/api`: `ruff check .`, `ruff format --check .`, `mypy src`, `pytest`. Web: `npm test -w apps/web` (under load use `--pool=forks --maxWorkers=1`), `npx tsc --noEmit -p apps/web`, `npm run build -w apps/web`. Scripts: `bash scripts/test-demo-up.sh`, `bash scripts/test-tunnel-net.sh`. Mobile: `flutter analyze`, `flutter test` (730). RADIUS conformance as before (57). On Windows use Git Bash at `C:\Program Files\Git\bin\bash.exe` (the PATH `bash` is a broken WSL).

Ledgers with every ruling: `.superpowers/sdd/*/progress.md` in the platform repo (git-ignored): M5a `2026-10-02-m5a-admin-console/`, demo `2026-10-02-demo-stack/` (`demo-report.md`, `subnets-report.md`, `review-demo-tunnel.md`), M11, M12 (`review-final-phase1.md`), M2c (preparation only). Not verified here: anything needing Cloudflare, a real device, GitHub CI, or Docker (not run for this refresh).
