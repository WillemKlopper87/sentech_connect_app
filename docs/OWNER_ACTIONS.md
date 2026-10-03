# Owner actions and decisions — what we need from you

**Living checklist. Last updated 2026-10-03.** One place for everything that only you can do or decide. It
gathers the open items from `docs/MORNING_REPORT.md`, the 2026-10-02/03 research memos, specs and plans, the
runbooks and the SDD ledgers (`.superpowers/sdd/*/progress.md`).

## How to answer

- Reply in chat with the **item number and your choice**, for example "H2: tiered" or "L5: accept default".
  Several answers in one message are fine.
- **Defaults hold until you answer.** Work continues on the default. Answering "accept default" closes an
  item.
- Answered items move to **Recently answered** at the bottom, with the date.
- **Priority:**
  - **Blocker for demo**: needed before the public demo on demoxapp.xyz or an app demo.
  - **Before pilot**: needed before real customers of a pilot ISP.
  - **Before launch**: needed before general release.
  - **Later**: needed only before that feature is built or ships.
- Column "Where" points to the document that has the detail. MR = `docs/MORNING_REPORT.md`; plans and specs are
  in `docs/superpowers/plans/` and `docs/superpowers/specs/`; ledgers are `.superpowers/sdd/<milestone>/progress.md`
  (git-ignored, on this PC only).

## Count by priority

| Priority | Items |
|---|---|
| Blocker for demo | 9 |
| Before pilot | 39 |
| Before launch | 18 |
| Later | 72 |
| **Total** | **138** |

---

## A. Hosting, demo and housekeeping (things only you can do)

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| A1 | Create the Cloudflare tunnel for demoxapp.xyz. Put `CLOUDFLARE_TUNNEL_TOKEN` and `PUBLIC_DOMAIN=demoxapp.xyz` in `.env`. Add public hostnames `demoxapp.xyz`, `www`, `admin`, `auth`, then `*`, all to `http://caddy:80`. Set SSL mode Full. | We make no Cloudflare changes; the public demo cannot start without it | No public demo; local only | MR "Owner actions" 1; `docs/runbooks/hosting-demoxapp.md` §3 | Blocker for demo |
| A2 | Stop the standalone cloudflared if it uses this tunnel's token (on this PC: `docker stop youthful_hertz`). Leave the ttli connector alone. | Two connectors on one tunnel split traffic, so some requests fail | Not stopped | MR "Owner actions" 2; hosting runbook §3 item 7 | Blocker for demo |
| A3 | Rotate the demo gate password and the demo logins that were pasted into chat. Run `scripts/demo-up.sh gate-hash` and paste only the two printed lines into `.env`. Then run `down --wipe` and `up` for new logins. | Treat them as exposed | Old values remain valid | MR "Incidents" | Blocker for demo |
| A4 | Delete the leftover scratch credential folders. The approval layer blocked agents from deleting them. 1) `C:\Users\Wille\AppData\Local\Temp\sentech-m12t6-1002\` (`demo.env`, `e2e\admin-seed.json`, `e2e\platform-pick.txt`). 2) `C:\Users\Wille\Downloads\applications\sentech_connect_platform\.superpowers\sdd\2026-10-02-m12-admin-portal-redesign\stack-task9\` (`stack.env`, `e2e\admin-seed.json`, `e2e\platform-pick.txt`). 3) `C:\Users\Wille\Downloads\applications\sentech_connect_platform\.superpowers\sdd\2026-10-02-m12-admin-portal-redesign\stack-phase1\` (`scratch.env`, `e2e\admin-seed.json`). | They hold local demo credentials; their stacks no longer exist | Left in place | MR "Incidents" | Blocker for demo |
| A5 | Check and delete `C:\tmp\smoke_token.env` (314 bytes, dated 9 Aug). Its origin is unknown and we never read its contents. | Possible stray credential | Left in place | MR "Incidents" | Blocker for demo |
| A6 | Verify the tunnel with a real session. Run `up --tunnel` and the curl matrix. Sign in to `admin.demoxapp.xyz` in a real browser and enrol the authenticator. Check `__Host-` cookies over HTTPS, gated map tiles and the real client IP (this needs `ttli-demo` stopped, because the networks collide). | None of this has been proven with cloudflared | Unverified | MR release gate 8; hosting runbook §6-§7; M2c plan P6 | Blocker for demo |
| A7 | Turn on Cloudflare Access (free) for `admin.demoxapp.xyz`, or at least the demo password gate. Never put Access on `auth.` | Strangers can otherwise reach the console sign-in and the fake-gateway flows | Gate off | MR "Rulings"; hosting runbook §8.3 | Blocker for demo |
| A8 | Reset the dev database volumes once. Validate the 0018 `CHECK NOT VALID` constraint by hand on any existing database. | Migrations 0013 and 0016-0019 were edited in place | Old volumes may fail | MR "Rulings", "Owner actions" 5 | Blocker for demo |
| A9 | Choose the final hosting: the Sentech data centre or AWS af-south-1. | South African residency in the privacy notice; s72 statement | Sentech data centre (spec §12) | Master spec §12, §16; SDD ledger M3b line 97 | Before pilot |
| A10 | Key backup and rotation: `PII_KEY`, voucher, export and NAS keys, `SENTECH_ADMIN_CLIENT_SECRET`. Also Keycloak production mode, raise HSTS, edge rate limits and a cache rule for `/basemap`, and restrict access to `.env` (icacls). | Losing a key loses data; launch hardening | Keys only in local `.env` | MR release gate 10; `docs/runbooks/radius.md` "Key backup and rotation"; hosting runbook §8.6 | Before launch |
| A11 | Glance at `C:\Program Files\Git` for a stray file. One was created and deleted during M2 T12. | Hygiene | Assumed gone | MR "Incidents" | Later |

## B. Testing, devices and engineering gates

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| B1 | Test on a physical phone or emulator: the boot video, the `adb reverse` / 10.0.2.2 path, and a fresh app ↔ backend live run. | Never verified on a device; the last live run predates M2 | Widget tests only | MR status table, release gate 6 | Blocker for demo |
| B2 | Create a GitHub remote and get a first green CI run: web e2e, admin e2e, Trivy, RADIUS isolation, promtool. Confirm pinned action SHAs and the gitleaks licence. | CI has never run; the checkout has no remote | Local test runs only | MR open decision 9, release gate 7 | Before pilot |
| B3 | Real MikroTik test on a Linux host, with a VPN path (WireGuard) for field routers. Confirm the on-site RouterOS version is 7.15 or later, and whether hotspots can use `login-by=https`. | Message-Authenticator needs 7.15+; only conformance tests exist | RouterOS 7.15+ assumed | MR release gate 5, open decision 8; M2 plan "Open questions" 2 | Before pilot |
| B4 | Arrange usability test G1: two ISP operators and one agent, not Sentech staff, 30-minute sessions; you pick the dates. | M12 phase 2 (tasks 11-18) is blocked until G1 is recorded | Pending | `docs/research/2026-10-02-admin-usability-test-protocol.md`; M12 plan R3 | Before pilot |
| B5 | Get sample coverage exports from the Sentech RF tools (Atoll or other), approved side by side by an RF engineer (coverage gate G1). | Real coverage replaces demo polygons | Demo data | Coverage spec §12 G1 | Before pilot |

## C. Brand and website

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| C1 | A security contact email for `security.txt`, and whether to publish a PGP key. | `security.txt` returns 404 until the contact is set | 404, no PGP | MR open decision 5; website research "Owner inputs" 2 | Before launch |
| C2 | An SVG Sentech brand mark (favicon) and a white logo for dark backgrounds. | A neutral Wi-Fi placeholder ships today | Placeholder | MR open decision 5; SDD ledger M11 line 3 | Before pilot |
| C3 | Confirm the minimal status page is wanted. It only shows API readiness, with no incident history. | Avoids shipping something unwanted | Kept | MR open decision 5 | Later |

## D. Providers and accounts

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| D1 | Netcash: sandbox access and verification, merchant terms per ISP, the ISV (software vendor key) agreement and the rate card. | The payment fields are "shape-only", not verified against the sandbox | Fake gateway | MR release gate 1; `docs/integrations/netcash-pay-now.md`; `payments/netcash_fields.py`; billing research §5.3 | Before pilot |
| D2 | SMS provider: rate card, sender ID, contract. | OTPs, receipts, reseller SMS; the fake sender delivers nothing | Fake SMS | MR release gate 2; reseller spec G2 | Before pilot |
| D3 | Email provider. | Support-message delivery, receipts, staff invitations | Fake email (delivers nothing) | MR release gate 2; `docs/runbooks/support-messages.md` | Before pilot |
| D4 | Cloudflare Turnstile site key and secret, with hostname/action checks. | The human check on forms is fake today | Fake verifier | MR release gate 3 | Before pilot |
| D5 | Keycloak SMTP for the realm. | Needed for verified email and "forgot password" for staff | Off; staff ask their administrator | MR "Rulings"; `docs/runbooks/admin-console.md` "Verified email and SMTP"; M12 plan R11 | Before pilot |
| D6 | Geocoder hosting: a Photon VM (about 8 GB RAM / 20 GB SSD) or Nominatim (coverage D8). Also a map tile provider for app release builds. | Address search uses a fake gazetteer today; the release app shows no map without a provider | Fake geocoder; placeholder map | Coverage spec §11 D8; `config.py` geocoder settings; app `lib/shared/widgets/osm_map.dart` | Before pilot |
| D7 | Firebase project, final Android applicationId and iOS bundle id, APNs auth key, service-account JSON. | Push and WiFi-aware alerts (M13) | No push | WiFi-aware spec R1; M13 plan Task 16 | Later |
| D8 | AdMob account, real ad units, SSV URL, payee legal entity (VAT registered?), withholding-tax set-up. | Rewarded data (M9) | Google test units, fake SSV signer | Credits spec §1, §16; ad-network research §9 Q3 | Later |

## E. Legal, privacy and per-ISP details

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| E1 | Legal review of ALL DRAFT copy: the new privacy notice (`docs/legal/privacy-notice.md`, including its Appendix B with 30 statements to confirm), terms, PAIA manual, RICA paragraph, accessibility statement, cookie notice, cooling-off notice, and the support-message sentence ("not linked to your account, deleted after delivery, within 30 days"). That sentence exists only in the new privacy notice §2.8; the website does not show it yet. Also name who owns the legal review. | Nothing legal may be published as DRAFT | Pages show "DRAFT — needs legal review" | MR open decision 6; website research "Owner inputs" 1; `docs/runbooks/support-messages.md`; SDD ledger M2c line 61 | Before pilot |
| E2 | For each ISP: registered legal name, registration number, physical and postal address, Information Officer and deputy, PAIA manual. | Required in the privacy notice and the PAIA manual; the API field is deferred | `[PLACEHOLDER]` markers | Privacy notice §1.1; website research "Owner inputs" 3 | Before pilot |
| E3 | Confirm the POPIA roles: the ISP is the responsible party and Sentech the operator. Then put operator agreements in place (Sentech with each ISP, and each sub-processor). | The web draft says "Sentech is the responsible party"; the credits spec says the ISP is | Privacy notice: ISP = responsible party (marked CONFIRM) | Privacy notice B1, B2; credits spec §1 item 2 | Before pilot |
| E4 | Sentech's own legal details and Information Officer for the notice. | Operator contact | `[PLACEHOLDER]` | Privacy notice §1.2 | Before pilot |
| E5 | Age rule (18+?) and an age check, yes or no (POPIA s35). | Children's data; credits, ads and Local Zones assume 18+ | "Meant for adults; under 18 with a guardian" (web draft) | Privacy notice §10, B20; Local Zones D5 | Before pilot |
| E6 | Align the marketing choices. The app registration shows email, SMS and push switches, but the platform stores only the SMS choice. | The consent record must match what is shown | SMS only | Privacy notice B18; `customers/schemas.py` line 12 | Before pilot |
| E7 | The app uses the phone's own geocoder (Google or Apple) for coverage search. Either disclose it (s72), or switch the app to our geocoder. | Addresses leave our systems | Disclosed in the draft notice (CONFIRM) | Privacy notice B9 | Before pilot |
| E8 | Retention periods for the audit log, server logs (which include IP addresses), orders and payments, voucher history, account consent records and backups. | No deletion job exists for these | Kept indefinitely | Privacy notice Appendix A, B23 | Before launch |
| E9 | The app keeps registration details (name, address, coordinates) on the phone, while its location consent says the location is not stored on the phone. Fix the text or the storage. | The consent wording must be true | Unchanged | Privacy notice B28 | Before pilot |

## F. Questions for counsel

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| F1 | RICA: may voucher-as-user hotspot sessions stay anonymous, and is 90-day MAC/session retention right? Does RICA apply to WiFi passes at all? | Shapes sign-in and retention | Anonymous voucher sessions allowed; 90 days | MR release gate 4; M2 plan open question 4; privacy notice B7 | Before pilot |
| F2 | POPIA purpose and retention table sign-off; the lawful basis per purpose. | Privacy notice §3 and Appendix A | As drafted | MR release gate 4; privacy notice B3 | Before pilot |
| F3 | ECTA s42 cooling-off: does it apply to hotspot passes? Also s43 disclosures and the platform/ISP liability split. | Checkout copy | "Refund requests are reviewed by your provider" (DRAFT) | `legal.cooling_off_notice` in `apps/web/lib/i18n/messages/en.json`; billing research §5.2 Q6 | Before launch |
| F4 | CPA s63: voucher and pass expiry, credits, cashback. | Expiry rules; cashback stays off | Vouchers up to 730 days; credits 90-day expiry; cashback 0 | Credits spec; M9 plan; reseller spec G3 | Before launch |
| F5 | Direct marketing: the national opt-out registry (CPA 2026), and POPIA s69 for SMS and push marketing, including "STOP" replies. | Marketing consent | SMS offers only with opt-in | MR release gate 4; WiFi-aware spec R4; privacy notice B19 | Before launch |
| F6 | VAT: agent discounts, listing fees, platform fees, agency vs principal, invoices in the ISP's name, abridged invoice rules. | Billing and reseller design | VAT 15%; fees ex VAT; abridged limit R5,000 (unverified) | M8 plan "Legal / tax counsel"; billing research §5.2 Q4 | Before launch |
| F7 | Tax-record retention period (VAT Act / Tax Administration Act), and whether redacting personal data on invoices satisfies POPIA. | Retention and erasure | 5 years; recipient fields redacted on erasure; no purge job | M8 plan counsel Q3, Q4; privacy notice B15 | Before launch |
| F8 | ICASA End-User and Subscriber Service Charter: are the 50/80/100% usage and expiry notices binding for hotspot passes (rules from 23 Jan 2027)? Also resale exemptions. | Notification design (M15) | Treat as a service promise | Customer-app research D4; M15 plan; billing research §5.2 Q7 | Before launch |
| F9 | NPS Act / SARB closed loop / e-money, and FICA accountable-institution status, for the reseller prepaid wallet and any split payments (TPPP). | M10 and Tier C cannot launch without it | Closed-loop wallet, no cash-out | Reseller spec G1; billing research §5.2 Q1-Q3 | Later |
| F10 | Films and Publications Act (s27A / s24C, CSAM reporting) and the Cybercrimes Act for Local Zones. | Local Zones Phase A legal gates G2, G4 | Not built | Local Zones concept §10 | Later |
| F11 | ISPA membership (Sentech and each pilot ISP) for the ECTA s72 safe harbour; a designated s75 agent; an s77 take-down process. | Hosting user content (Local Zones) | Not built | Local Zones concept §10 G1 | Later |
| F12 | Apple App Store 3.2.2 (rewarded ads on iOS): ask App Review, or ship Android first. | M9 iOS strategy | Ask before submitting | MR release gate 4; ad-network research §9 Q4 | Later |

## G. Admin console (M5a, M12) confirmations

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| G1 | Launch persona: the ISP owner/manager on phone and desktop (R1). | Shapes the M12 phase 2 home and navigation | Owner/manager first | M12 plan R1; MR open decision 3 | Before pilot |
| G2 | Tenant-staff MFA: optional per tenant, off by default (R2). Platform admins always need MFA. | Security vs ease | Optional, off | M12 plan R2 | Before pilot |
| G3 | Counter staff (`tenant_staff`) stay read-only. Letting them resend receipts or disconnect is a backend change (BT-5). | Role model | Read-only | M12 plan R8 | Before pilot |
| G4 | "By site" in reports means by hotspot router (NAS). A real NAS-to-site link is backend task BT-4. | Report wording | By router | M12 plan R7 | Before pilot |
| G5 | MFA setup order. Create the first platform admin in Keycloak, run `bootstrap-platform-admin.sh`, then write a manual audit row. The person enrols the authenticator in the same sitting as the temporary password. The alternative is to pre-enrol TOTP. | Until enrolment, anyone with the initial password could enrol their own device | Same-sitting enrolment | `docs/runbooks/admin-console.md` | Before pilot |
| G6 | Staff account provisioning: keep it manual in Keycloak, or give the API a Keycloak admin credential to automate invitations. | A credential that can create users is a large privilege | Manual | MR "Rulings"; SDD ledger M5a T10 | Before pilot |
| G7 | Unmatched admin URLs show the public 404, not a console 404 (a routing choice). | Product polish | Public 404 | MR "Rulings"; M12 ledger | Later |
| G8 | Backend tasks that M12 wants but no plan owns: BT-1 block/unblock, BT-2 gift data, BT-3 remove device, BT-6 print layouts, BT-7 operator notifications. Which, and when? | No buttons ship without a backend | Not built | M12 plan "Backend tasks surfaced" | Later |
| G9 | Require a reason when suspending a tenant? | Audit quality | Optional | SDD ledger M5a line 24 | Later |

## H. Reseller cash channel (M10 spec D1-D11)

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| H1 | D1 Launch model | Shapes the whole channel | A (prepaid wallet, digital vouchers) with B (paper consignment) fallback; pilot ISP + 5 shops, 6 weeks | `specs/2026-10-02-reseller-cash-channel-design.md` §17 | Later |
| H2 | D2 Commission | Agent economics | Flat 8%, set by the ISP per agent | same | Later |
| H3 | D3 Float limits | Risk | R500 / R1,500 / R2,000 tiers; ceiling R2,000 | same | Later |
| H4 | D4 Who pays the SMS per sale | Cost | The ISP | same | Later |
| H5 | D5 Unredeemed voucher validity | CPA s63 | 30 days (3 years is CPA-safe) | same | Later |
| H6 | D6 Smartphone only, or USSD/SMS for feature phones | Reach vs cost | Smartphone web view | same | Later |
| H7 | D7 Void window; may the agent see the code in an emergency? | Fraud | 10 min; no | same | Later |
| H8 | D8 Top-up channels | Cash handling | EFT and bank cash deposit only | same | Later |
| H9 | D9 Agent ID and trading-address evidence, and who checks it | KYC | Spaza registration or ward letter; ISP staff check; no uploads | same | Later |
| H10 | D10 Phone binding for the pilot | Fraud vs ease | Off | same | Later |
| H11 | D11 Agent discount ever paid as credits? | M9 overlap | No | same | Later |

## I. Connect Credits (M9)

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| I1 | A pass bought with credits has no product: make `entitlement.product_id` optional, or use a placeholder product per credit pack? | Data model (M13 free time has the same question) | Optional (nullable) | MR open decision 2(a); M9 plan P6 | Later |
| I2 | Local businesses sign in with revocable scan/manage credentials issued by their ISP, not Keycloak accounts. | Identity model | ISP-issued credentials | MR open decision 2(b); credits spec §9 | Later |
| I3 | Our real cost per MB, and the value per rewarded ad in South Africa ("2 credits per ad" is an assumption). Approve a 4-week capped pilot. | Economics | Launch with caps and measure | Credits spec §16; ad-network research §9 Q1, Q7 | Later |
| I4 | Ad revenue share with ISPs, and who bears invalid-traffic clawbacks. | Commercial | Not set | Ad-network research §9 Q2 | Later |
| I5 | Who sells direct local ads, and which ad categories to block (gambling, alcohol, adult, betting). | Content and sales | Block sensitive categories | Ad-network research §9 Q6, Q8 | Later |

## J. WiFi-aware alerts and free time (M13 spec D1-D8)

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| J1 | D1 Ship v1 with background-location geofence alerts or without? | Store review risk | Build both; enable `wifi_aware` per tenant only after Play review passes | `specs/2026-10-03-wifi-aware-notifications-design.md` §13 | Later |
| J2 | D2 Default free-time grant; may tenants exceed 240 min? | Cost | 60 min / 200 MB / 1 device | same | Later |
| J3 | D3 May paid-pass holders claim free time? | Fairness | Yes | same | Later |
| J4 | D4 Announcement caps and quiet hours | Spam | 1/day, 3/week; quiet 21:00-07:00 | same | Later |
| J5 | D5 Free time for people without the app (web OTP) | Reach | Later milestone | same | Later |
| J6 | D6 Huawei Push Kit / HMS | Device coverage | Local reminders only | same | Later |
| J7 | D7 Firebase: one platform project or one per ISP | Set-up | One platform project | same | Later |
| J8 | D8 Apply for Apple NEHotspotHelper; plan Passpoint/OpenRoaming? | iOS auto-connect | No default stated | same | Later |

## K. Coverage import and rural search (M14 spec D1-D9)

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| K1 | D1 Good/fair/edge thresholds: the defaults, or from the RF team? | Coverage accuracy | Research defaults; low confidence for colour-keyed maps | `specs/2026-10-03-coverage-import-and-rural-search-design.md` §11 | Before pilot |
| K2 | D2 Upload size | Large RF files | 10 MB (100 MB only via a route override) | same | Later |
| K3 | D3 Population and buildings data (WorldPop 2020 CC BY, Google Open Buildings CC BY 4.0) | Estimates and licences | Use both, with attribution | same | Later |
| K4 | D4 Imagery: none, NGI (needs permission) or EOX 2016 | Licence | None | same | Later |
| K5 | D5 Translation budget for isiXhosa, Sesotho, Setswana, Sepedi | Rural reach | English fallback | same | Later |
| K6 | D6 "Coverage arrived" SMS to waitlist leads: consent wording and cost | POPIA and cost | Not sent; staff are told | same | Later |
| K7 | D7 USSD channel: gateway, short code, WASPA | Feature phones | Designed only | same | Later |
| K8 | D9 Share links may include a rounded pin when the user opts in? | Privacy | "Include my pin" off | same | Later |

(Coverage D8, Photon hosting, is item D6.)

## L. Customer app (M15, customer-app research D1-D7)

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| L1 | D1 Hotspot-only ISPs skip the coverage step and address fields at first sign-in | Faster onboarding | Yes (planned in M15) | `research/2026-10-03-customer-app-usability-and-delight.md` §7 | Before pilot |
| L2 | D2 First-connection gift (for example 100 MB or 30 min, funded by M9 credits) | Delight vs cost | Yes, small; not built | same | Later |
| L3 | D3 Languages and translators: zu, af, xh first, then st, tn, nso; paid native reviewers; about 250 app and 650 web strings per language | Reach; native review is a release gate | English only | same; MR release gate 12 | Before launch |
| L4 | D4 Treat ICASA 50/80/100% and expiry notices as binding for hotspot passes (see F8) | Service promise | Yes | same | Before launch |
| L5 | D5 Rename the "Most popular" badge (not backed by sales data) | Honest selling | Renamed to "Our pick" | same; M15 plan | Before pilot |
| L6 | D6 Analytics: server-side counters plus the crash hook only, no third-party trackers | Privacy | Server-side only | same | Before pilot |
| L7 | D7 Mascot "Connie": yes or no, and the name | Brand | Off (owner-gated) | same; M15 plan Task 16 | Later |
| L8 | Boot video: trim to about 3 s and play once per install? (It is 1.6 MB and has not been checked on a device.) | Start-up time and data cost | Plays every start, skippable after 1.5 s | MR open decision 4; customer-app research D7 | Before pilot |

## M. Local Zones (concept D1-D11)

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| M1 | D1 Zone definition | Scope | Hotspot cluster, optional ward link | `specs/2026-10-03-local-zones-concept.md` §9 | Later |
| M2 | D2 Who moderates | Liability | Hybrid: Sentech screens and escalates, the ISP decides local content | same | Later |
| M3 | D3 Launch scope | Risk | Phase A only, resident posts pre-moderated | same | Later |
| M4 | D4 Payments | NPS Act | None in phases A and B | same | Later |
| M5 | D5 Age limit | FPB, POPIA s35 | 18+ | same | Later |
| M6 | D6 Pilot area | Pilot | One ISP, 3 hotspot-cluster zones, 8 weeks, shared with the M9 business pilot | same | Later |
| M7 | D7 Verified (trusted) posters at launch | Trust | ISP staff plus approved institutions, with a pre-election pause | same | Later |
| M8 | D8 Resident safety alerts | Harm | Trusted posters only, structured form | same | Later |
| M9 | D9 Free (zero-rated) browsing of zone pages | Reach | Yes on pilot hotspots | same | Later |
| M10 | D10 Cross-tenant zones | Scope | Later | same | Later |
| M11 | D11 Languages at launch | Reach | English plus the pilot area's main language | same | Later |

## N. Offboarding and erasure

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| N1 | Retention window after offboarding, and the cooling-off period. | Offboarding keeps all data today; do not offboard a tenant with real customers before the purge exists | 90 and 7 days (suggested) | `docs/runbooks/offboard-purge-design.md` "Owner decisions" 1 | Before launch |
| N2 | A second approver for purges: required, and who? | Irreversible deletion | Required (recommended) | same, 2 | Before launch |
| N3 | Which financial records to keep after a purge, for how long, and is anonymisation enough? | Tax vs POPIA | Ask counsel (see F7) | same, 3 | Before launch |
| N4 | Keep a purged tenant's audit-log rows? For how long? | Evidence | Not set | same, 4 | Before launch |
| N5 | Backup retention vs per-tenant key shredding (`PII_KEY` is global today). | Erasure in backups | Data stays until backups age out | same, 5 | Before launch |
| N6 | Who performs the Keycloak, Garage and Redis checklist steps? | Operations | The platform operator | same, 6 | Before launch |
| N7 | POPIA procedure for customers of a suspended ISP. | Rights requests while suspended | None | MR release gate 9 | Before launch |

## O. Billing Tier B (M8) inputs

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| O1 | VAT rate and invoice rules (15%, abridged invoice limit R5,000, 10-digit VAT numbers): confirm with a tax adviser. | Invoices | As listed (unverified) | M8 plan preflight 6 | Later |
| O2 | Tax-record retention (`billing_retention_years`), and who runs the purge. There is no purge job by design. | Retention | 5 years; you run the purge | M8 plan counsel Q3 | Later |
| O3 | Netcash Split Payments field names, the settlement report format, the refund API and chargebacks (checklists S1-S4, R1-R3). | The split fields are set to None until verified | Not verified | M8 plan; `docs/integrations/netcash-pay-now.md` | Later |
| O4 | Fee base: VAT-inclusive (gross) or VAT-exclusive? | Platform fees | Gross | M8 plan owner Q1 | Later |
| O5 | Fees ex VAT; Sentech invoices ISPs from its own finance system? | Invoicing | Yes | M8 plan owner Q2 | Later |
| O6 | Reverse fees on refund? | Ledger | No; manual journal | M8 plan owner Q3 | Later |
| O7 | Definition of an active subscriber for per-active fees. | Fee calculation | Holds an entitlement overlapping the month | M8 plan owner Q4 | Later |
| O8 | Network fee basis for resellers (percent + fixed + per active, or a wholesale price list). | Reseller billing | Percent + fixed + per active | M8 plan owner Q5; billing research §5.1 Q4 | Later |
| O9 | Dunning: SMS cost per tenant and reminder wording. | Collections | Off | M8 plan owner Q6 | Later |
| O10 | Billing period grace, and whether tenants may close their own periods. | Month end | Auto-close 5 days after month end | M8 plan owner Q7 | Later |
| O11 | Settlement import for Tier A too? Logo on invoice PDFs? | Scope | Tier B only; text only | M8 plan owner Q8, Q9 | Later |
| O12 | Akaunting CSV mapping: confirm by importing a sample. | Finance export | Guessed mapping | M8 plan preflight 7 | Later |
| O13 | Commercial: is Tier C needed? Merchant-of-record stance, platform fee basis, settlement terms, small-ticket strategy, prepaid value when a customer moves between ISPs. | Business model | Tiers A and B only | Billing research §5.1 | Later |

## P. Parked items that need a business call (M2, M5a, M7, M12)

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| P1 | 12-symbol voucher codes instead of the spec's `SEN-XXXX-XXXX`: acceptable on cards and in SMS? | Printing | 12 symbols | M2 plan "Open questions" 1 | Before pilot |
| P2 | Who approves NAS (router) registrations operationally? | Operations | Platform operations | M2 plan "Open questions" 3 | Before pilot |
| P3 | Voucher export retention (7 days, 3 downloads) and no reprints: acceptable to distributors? | Distribution | As built | M2 plan "Open questions" 5; MR open decision 8 | Before pilot |
| P4 | Void after redeem means no refund: is that the policy? | Customer fairness | No refund | MR open decision 8 | Before pilot |
| P5 | 20 OTP requests per hour per IP can lock out venues behind shared addresses (CGNAT). Raise it per tenant? | Hotspot venues | 20/h/IP, per-tenant override available | SDD ledger M1 line 18; `config.py` `rate_limit_tenant_overrides` | Before pilot |
| P6 | `approve_nas` lock needs a definer function (a security gap). Fix it in M2c or later? | Correctness under concurrency | Parked | MR "Rulings" parked; SDD ledger M2c line 8 | Before pilot |
| P7 | Extend the reserved tenant-label list; enforce unique staff email (`lower(email)`); dedupe the lead "listed" audit; re-check the export stream status. | Hygiene | Parked | MR "Rulings" parked; SDD ledger M5a | Later |
| P8 | Sandbox (trial) tenants appear in the public `/v1/tenants` list. Expose `directory_listed`? | Partner API sandbox | Listed | M7 plan P16 | Later |

## Q. Recorded but still open in research (vendors)

| # | What is needed | Why | Default until you answer | Where | Priority |
|---|---|---|---|---|---|
| Q1 | USSD aggregator quote and reverse billing; or would you rather use Kazang/Flash (an existing agent network) instead of our own reseller build? | Build vs partner | Build our own (M10) | Reseller research §9 | Later |
| Q2 | Netcash Partner Programme / master-merchant (Netcash as TPPP) option. | Simpler onboarding of ISPs | Each ISP has its own merchant account | Billing research §5.3 Q4-Q5 | Later |

---

## Recently answered

| Date | Decision | Recorded in |
|---|---|---|
| 2026-10-01 | SMS budget default: 5,000 OTP per ISP per hour | SDD ledger M3a line 74 (1); MR "Owner decisions" |
| 2026-10-01 | Phone numbers masked to the last 4 digits (`+27 ** *** 4567`) | SDD ledger M3a line 74 (4) |
| 2026-10-01 | Waitlist location rounded to about 100 m (may be coarsened later) | SDD ledger M3a line 74 (5); `modules/leads/service.py` |
| 2026-10-01 | Map tile paths may stay unmasked in access logs | SDD ledger M3a line 74 (2) |
| 2026-10-01 | Billing tiers A and B approved; C deferred | SDD ledger M3a line 75; master spec §14 |
| 2026-10-01 | Coverage runs inside the main API (R-M3a-1) | Master spec §15; SDD ledger M3a line 79 |
| 2026-10-01 | Website mockups approved and binding | SDD ledger M3b line 52; `docs/design/website-mockups/` |
| 2026-10-01 | Partner API uses token exchange | MR "Owner decisions" |
| 2026-10-02 | Run locally first; public only through the deliberate `up --tunnel` | MR "Owner decisions"; SDD ledger M5a line 10 |
| 2026-10-02 | Domain `demoxapp.xyz`, single-level hosts (`admin.`, `auth.`, `<slug>.`) | MR "Owner decisions"; hosting runbook |
| 2026-10-02 | A new Cloudflare tunnel with new credentials (option B); you create it, we change nothing in Cloudflare | MR "Owner decisions" |
| 2026-10-02 | Subnets option B: configurable, defaults `10.231.250.0/24` and `10.231.251.0/29` | MR "Owner decisions"; hosting runbook §4.1 |
| 2026-10-02 | Random local `.env` secrets approved (scripts append only missing keys, never print values) | MR "Owner decisions" |
| 2026-10-02 | Research defaults for credits: AdMob with test units; businesses belong to an ISP; 1 credit = 1 MB; 2 credits per ad, 8 ads/day, 150/month from ads, 300/month overall; referral 100 + 100 with a 7-day hold; 90-day expiry; no cash-out | Credits spec §1; MR "Owner decisions" |
| 2026-10-02 | Test-app gamification defaults: deterministic streaks, check-ins, tiers, missions and badges; no chance-based rewards | Credits spec §1-§2 |
