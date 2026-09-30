# Sentech Connect Platform — Design Spec

Date: 2026-09-30 · Status: draft for owner review · Scope: backend platform, public web app, mobile-app integration, hotspot access, payments, RICA/fulfilment/CPE (flagged)

Related: [`docs/reconciled-spec.md`](../../reconciled-spec.md) (original app spec), [`docs/app-review.md`](../../app-review.md) (mobile review), [`docs/architecture.md`](../../architecture.md).

## 1. Intent and constraints

**Outcome.** A single backend and catalog that power (a) the Flutter mobile app, (b) a public consumer website with storefront and location-based coverage search, and (c) an admin console. **Launch product: WiFi hotspot access** (passes, digital and paper vouchers, free ad-gated tier, hotspot map). Home 5G / MiFi orders with RICA, delivery and ACS device mapping are built as modules but **feature-flagged off** until ACS device testing completes.

**Audience.** Consumers, self-serve first. Business/government enquiries use a quote form; business plans are an extension point, not launch scope.

**Stack (decided).** Mirrors the owner's TTLI_LMS setup so infrastructure, CI and security tooling are reused:
- FastAPI (Python) modular monolith, SQLAlchemy/Alembic, arq workers
- Next.js 16 web + BFF, TypeScript
- PostgreSQL 18 with PostGIS and row-level security; Redis; Garage (S3-compatible)
- Keycloak (OIDC); Lago (usage/prepaid billing, phase M7); FreeRADIUS
- Caddy; **Cloudflare Tunnel as the only ingress**; Turnstile; ClamAV
- Grafana, Loki, Prometheus, Alloy; digest-pinned, hardened containers
- Test/demo phase: docker compose on one VM behind the tunnel. Later: Sentech's data centre using the same artefacts.

**Greenfield retail platform, existing network systems.** No existing retail BSS/CRM is assumed. Three existing systems are integrated, not replaced: (1) the **ACS** (Go, TR-069/USP, TMF and `/bss/v1` adapters); (2) the **integration layer** designed in `../bss-oss-integration` (TMF641 order intake over ACS, Nokia NSP transport, and the Nokia and Huawei 5G SA cores); (3) the operator's **acquired hotspot BSS**, which runs side by side: this platform owns hotspot sales and entitlements and feeds that BSS with transactions and usage for finance and reporting (see §4, `HotspotBillingFeed`).

**Non-goals (launch).** Usage-based invoicing, router self-service, referrals, business accounts, chat assistant, iOS release, and (see §12) cross-ISP migration, roaming and reseller wholesale — although multi-tenancy itself is built in from M0.

## 2. Architecture

```
Internet ─► Cloudflare (DNS, WAF, Turnstile) ─► cloudflared ─► Caddy
   ├─► Next.js web + BFF (storefront · portal · captive portal · admin)
   ├─► Core API (FastAPI): catalog · customers · orders · payments · vouchers · entitlements
   │                        · notifications · rica* · fulfilment* · cpe*   (*flagged)
   ├─► Coverage service (FastAPI + PostGIS, tile server)
   ├─► Keycloak        ├─► FreeRADIUS ◄── hotspot controllers (MikroTik first)
   └─► Worker (arq): payment reconciliation, SMS/email/push, imports, PDF batches
Data: Postgres · Redis · Garage · ClamAV · Lago      Observability: Grafana/Loki/Prometheus/Alloy
External: Netcash Pay Now · SMS/WhatsApp · KYC vendor* · Network integration layer* (→ ACS, Nokia core, Huawei core) · Hotspot BSS feed · Firebase (push) · geocoder
```

Principles: one public API for all clients; the coverage service is a separate deploy unit; all third parties sit behind interfaces (`PaymentGateway`, `AccessController`, `IdentityVerifier`, `CarrierGateway`, `NetworkGateway`, `HotspotBillingFeed`, `Geocoder`, `Notifier`) with mock implementations; money is integer cents; the server is the authority for prices, totals, entitlements and time.

## 3. Domain model and order flow

Entities: Customer (Keycloak-linked, consent ledger), Address/ServiceLocation, Product/Plan/Price (versioned), Order/OrderLine, Payment, Subscription/Entitlement, Voucher/VoucherBatch, Lead, RicaVerification*, Shipment*, Device* (OUI+serial), AuditLog.

Order state machine:

```
draft → coverage_confirmed → awaiting_identity* → awaiting_payment → paid → fulfilment_pending* → shipped* → activated
   failures are resumable states (rica_failed, payment_failed), never dead ends
   any pre-shipment state → cancelled ; paid → refunded (trial / ECTA 7-day cooling-off)
```

- Identity is verified **before** payment for physical/SIM-linked products. Hotspot passes skip RICA and fulfilment (legal confirmation of this assumption is an open input).
- Orders store the price, coverage result and confidence at time of sale.
- Payment completion is driven only by the verified Netcash Notify postback, idempotent on transaction reference, amount-checked against the order.

## 4. Hotspot access, vouchers and payments

**Access path.** Phone → AP → MikroTik hotspot → redirect to captive portal (Next.js page, walled garden) → RADIUS Access-Request/Accounting to FreeRADIUS → Core API/Postgres. Signed-in customers can connect without typing: the app/portal requests a short-lived signed login token and hands it to the controller login URL.

**Entitlements.** A `Pass` product defines minutes, data, speed and device count. Purchase or voucher redemption creates an `Entitlement`. RADIUS replies carry session timeout, rate limit and data cap; accounting writes usage back; expired/exhausted entitlements are cut off server-side (Disconnect/CoA). The free ad-gated tier is server-side: daily cap per account and device, server time only, ad completion via server-side verification where the ad network supports it.

**`AccessController` adapter.** RADIUS is vendor-neutral; an adapter supplies the attribute dictionary, login handoff, session control (Disconnect/CoA, RFC 5176), accounting interpretation and health check.

| Priority | Controller | Notes |
|---|---|---|
| 1 | **MikroTik RouterOS hotspot** | Launch target (M2). Confirm RouterOS version and `Mikrotik-*` attribute support. |
| 2 | **Ruckus** (Unleashed/SmartZone) | WISPr + RADIUS + CoA; carrier-grade. |
| 3 | **Ubiquiti UniFi** | External portal/guest flow; common at small operators. |
| 4 | **TP-Link Omada** | Low-cost external RADIUS portal. |
| extras | Teltonika RutOS, pfSense/CoovaChilli | Noted; not committed. |

Alternatives are delivered in M2b; each must pass a conformance suite (radtest and simulated accounting against the compose stack) and ships with a configuration guide. Vendor behaviours above are to be verified against real devices/docs at M2b.

**Vouchers (digital and paper, one model).**
- `VoucherBatch` (name, product, quantity, expiry, channel) generates codes `SEN-XXXX-XXXX` with a cryptographically secure generator; only a **hash** is stored, the plain code exists only in print/delivery output.
- States: `generated → printed → activated → redeemed | expired | void`. Paper stock is inactive until activated (point of sale, distributor scan, or batch release), so lost/stolen sheets are worthless.
- Paper output: print-ready PDF per batch (code, QR, terms, expiry) stored in Garage; generation, reprints and activation are audit-logged.
- Redemption is one idempotent, rate-limited endpoint used by the app, captive portal and web; errors are generic and raw payloads are never echoed.

**Hotspot billing feed (`HotspotBillingFeed`).** The acquired hotspot BSS stays in place. Paid passes and voucher activations/redemptions produce an outbox event; a worker posts them to that BSS through an adapter (API/file format per that system's documentation, an open input), with idempotent retries and a daily reconciliation count. The feed is one-way: this platform remains the authority for sales, vouchers and entitlements, and a feed failure never blocks a sale or a login.

**Netcash Pay Now (`PaymentGateway`).** Hosted redirect (form POST with service key; Accept/Decline/Redirect URLs for the customer, server-to-server Notify for truth). Methods available through Netcash include cards, Instant EFT (Ozow), Capitec Pay, PayShap, Scan to Pay and SCode (cash at retail), per Netcash's public documentation; exact parameters and postback verification are taken from Netcash's programmers' guide at build time. Daily reconciliation against settlement reports flags mismatches. Card data never touches our systems.

## 5. Coverage service and public web app

**Coverage service.** PostGIS polygons per technology (5G/LTE) with confidence, plus hotspot sites, imported as versioned datasets with rollback (candidate sources: the owner's GIS/RF planning and drive-test platforms — unconfirmed). `Geocoder` interface with a self-hosted default (Photon/Nominatim on an OSM South Africa extract) and optional Google Places. `GET /v1/coverage/check?lat&lon` returns `covered` (technology, typical and busy-hour speed ranges, confidence), `planned` (expected date) or `not_covered`; the latter two offer a waitlist Lead. Vector tiles for coverage/hotspot layers come from PostGIS via a tile server; the **base map is a self-hosted Protomaps/PMTiles file for South Africa**, rendered with MapLibre GL JS. Copy states 5G vs LTE explicitly and includes the indoor-coverage disclaimer and trial/cooling-off notice.

**Web app (Next.js 16, SSR/ISR).** Acquisition: address-first home, coverage map, hotspot finder, generated per-suburb/town landing pages. Shop: plans/devices, hotspot passes, vouchers, cart, Netcash checkout, confirmation and tracking. Account: sign-in, orders, active passes/vouchers, RICA status*, data export/delete. Trust/legal: fair-use and speed ranges, ICASA service charter, terms, cooling-off/returns, POPIA notice, complaints. Support: FAQ, Turnstile-protected contact form, WhatsApp link. Mobile-first and bandwidth-light, WCAG 2.2 AA, English first with i18n ready for isiZulu/Afrikaans, same brand tokens as the app, no third-party trackers.

## 6. Mobile app and API contract

- `/v1` REST, OpenAPI generated by FastAPI, breaking-change check in CI; TypeScript and Dart clients generated from it.
- RFC 9457 problem-details errors mapped to existing `Failure` types; `Idempotency-Key` on mutating calls; cursor pagination; integer-cent money.
- `GET /v1/app-config`: minimum app version, feature flags (RICA/CPE off at launch), legal document versions.
- Auth: Keycloak OIDC + PKCE via `flutter_appauth`; mobile number + SMS OTP primary; tokens in secure storage; biometrics only unlock an existing session; server-side revocation. Web uses the same realm with a BFF HttpOnly session.
- Endpoint groups (launch): catalog/coverage/hotspots, identity/profile/consents/export/delete, checkout/orders, entitlements/vouchers/free-wifi/hotspot login token, notifications, support. Flagged: RICA, shipments, CPE/router.
- App changes: Dio-backed repositories replace each `Mock*Repository` behind the same domain interfaces; `demo`/`prod` flavors; Drift offline cache (hotspots, passes, FAQ); push via FCM (requires owner's Firebase project); deep links; hotspot auto-connect; in-app account deletion. The in-progress hardening work (secure storage, real biometrics, route guards, consent, network-security-config) is a prerequisite and is reused.

## 7. RICA, fulfilment and CPE/ACS (feature-flagged)

- **RICA:** state machine `not_started → consented → documents_captured → vendor_check → passed | failed | manual_review`; `IdentityVerifier` interface (Smile Identity planned, mock until contracted); documents encrypted in Garage, ClamAV-scanned, retention-scheduled; exportable record; admin review queue; failures always retryable.
- **Fulfilment:** `Shipment` with carrier, tracking, events and proof of delivery; `Device` stock by OUI+serial (`in_stock → reserved → shipped → delivered → active`); `CarrierGateway` (manual admin updates first); collection/return path for trial/cooling-off.
- **CPE/ACS mapping:** on delivery or first Inform, the platform sends a service order through the `NetworkGateway` (§7A), which drives the ACS (`POST /bss/v1/mappings` with account id, `oui_serial`, plan; router changes via `POST /bss/v1/orders` using our order id as idempotent `external_order_id`, polled by `command_key`; ACS webhooks and read-only reconciliation). The ACS documentation states it is not yet qualified for production/UAT and lacks hardware qualification, so everything sits behind `NetworkGateway` with a mock until device testing passes.

## 7A. Network integration gateway (SIM, CPE, 5G SA cores)

The "API bridge/gate" is the integration layer already designed in `../bss-oss-integration` (one process and database; order engine with write-ahead outbox, retry, dead-lettering, derived state and drift detection; adapters for ACS, Nokia NSP, the Nokia core and the Huawei core). This platform does not duplicate it; it is a client of it.

```
Core API ──NetworkGateway (TMF641 order, idempotent external_order_id)──► Integration layer
   ▲  TMF688 events · TMF642 alarms · TMF638 service state ◄───────────────┤ adapters: ACS (exists) · Nokia core · Huawei core · Nokia NSP (later)
```

- **Responsibilities.** Retail platform: customers, SIM inventory (ICCID, IMSI, status, batch/profile reference) and CPE inventory (OUI+serial, IMEI), and the commercial order. Integration layer: translate service orders into ACS and core operations and report state. It is a translator, not a system of record.
- **Commands (canonical):** ActivateSubscriber, Suspend, Resume, Bar, ChangeProfile (plan/QoS/slice/DNN), SwapSIM, Delete, Get; plus CPE bind/unbind and router settings via the ACS adapter. Mapped to TMF641/640/638/639 (TMF633 for plan→service spec, TMF656 for failed provisioning).
- **Planes.** The platform never calls the 3GPP service-based interfaces (Nudm/Nsmf/Npcf); subscriber and policy data are provisioned through each vendor's management/provisioning interface (Huawei MAE-CN/NSMF, Nokia vendor interface, or 3GPP Provisioning MnS where a core supports it — the outcome of the vendor question list in `bss-oss-integration/docs/vendors`).
- **Dual core.** The target core (and whether a subscriber needs records in both) is data in the integration layer, never a branch in retail code; the gateway keeps desired vs observed state per core and per ACS device.
- **SIM key material.** Ki/OPc, transport keys, PIN/PUK/ADM never reach the retail platform or the gateway. The SIM vendor's encrypted key file is imported directly into the core's HSM-backed tooling; the platform holds identifiers and state only.
- **Risk controls.** SIM swap requires step-up verification, a cooling-off, customer notification, dual approval and an audit entry; IMEI-lock/EIR binding and barring are supported where the cores allow; CPE-to-SIM-to-customer binding is recorded and mismatches reported from ACS (TR-181 cellular objects) raise alerts.
- **Reconciliation.** Periodic read-only drift reports (retail inventory vs each core vs ACS); never auto-delete.
- **Testing.** A mock core (REST/SOAP/LDAP fakes with latency, partial failure, duplicates and "success on one core only") and mock ACS; adapter fixtures are shape-only until replaced by captures from a real lab core (per the integration project's ADR 0007); canary subscribers before production.
- **Phasing (inside M6).** (1) read-only inventory and reconciliation; (2) activate/suspend/resume on one core; (3) second core; (4) plan/slice/DNN change; (5) SIM swap, and eSIM (GSMA SGP.22/SGP.32) only if the CPE has an eUICC.
- **Standards referenced:** TM Forum Open APIs (TMF622/641/640/638/639/633/656/642/688), Broadband Forum TR-069, TR-369 (USP), TR-181 Device:2 (incl. cellular objects), TR-098, TR-143; 3GPP TS 28.532/28.541 (provisioning MnS), TS 29.503/29.505 (for understanding only), TS 33.501.

## 8. Security, compliance, operations

- **Edge/containers:** tunnel-only ingress, Turnstile on public forms, Caddy trusting `CF-Connecting-IP` only from cloudflared, TTLI-style security headers, non-root read-only digest-pinned containers, private data networks.
- **App security:** per-module authorisation plus Postgres RLS, rate limits per IP/account/endpoint, separate authenticated paths for Netcash, RADIUS and ACS, secrets via env now and Vault/sealed secrets later, Gitleaks/Trivy in CI, certificate pinning with backup pins once hostnames are final.
- **POPIA:** consent ledger (versioned, timestamped), purpose/retention table, export and deletion via API, information officer contact, breach runbook, operator agreements (Netcash, SMS, KYC).
- **RICA/consumer law:** configurable verification steps (rules tightening in 2026), ECTA supplier disclosures and 7-day cooling-off at checkout, month-to-month start (CPA 24-month cap), ICASA service charter on the site. Legal review required.
- **Audit:** append-only log of price changes, batch generation/activation, RICA decisions, refunds.
- **Ops:** Grafana/Loki/Prometheus with business metrics and alerts (payment notify failures, RADIUS outage); nightly Postgres and Garage backups with restore drills; RADIUS/captive portal are the availability-critical path (cache, health checks, hotspots fail closed); environments: local dev → tunnel test stack → staging/production in Sentech's data centre.

## 9. Testing

pytest unit and contract tests; property-style tests for order, voucher and entitlement state machines; fake Netcash server (accept, decline, duplicate/late Notify, amount mismatch, forged postback) plus sandbox run pre-launch; FreeRADIUS integration tests with `radtest`/accounting for active, expired and exhausted entitlements per controller adapter; coverage golden-point and import-rollback tests; Playwright e2e with accessibility and performance budgets; Flutter widget, cubit and failure-path tests against a stub server; nightly mobile integration against the tunnel stack; Gitleaks, Trivy, dependency audit, ZAP baseline and a manual pre-launch pen-test checklist (payments, vouchers, RADIUS).

## 10. Delivery order

| # | Milestone | Outcome |
|---|---|---|
| M0 | Platform skeleton | Compose stack behind the tunnel, Keycloak, Core API skeleton + OpenAPI, CI, observability |
| M1 | Catalog, customers, hotspot passes | Buy/view passes in app and web (Netcash sandbox), entitlements, notifications |
| M2 | Vouchers and RADIUS (MikroTik) | Digital/paper batches, activation, admin batch + PDF tools, FreeRADIUS + captive portal on a real MikroTik |
| M2b | Alternative controllers | Ruckus, UniFi, Omada adapters with conformance suites and config guides |
| M3 | Coverage service and public web | Address search, map, hotspot finder, landing pages, storefront and portal, waitlist |
| M4 | Mobile integration | Real repositories, `prod` flavor, offline cache, push, deep links, auto-connect |
| M5 | Launch hardening | Pen-test fixes, POPIA/legal review, backup/restore drill, load test, cutover plan |
| M6 | RICA, fulfilment, SIM/CPE via network gateway (flagged) | Enabled after ACS device testing passes; core adapters after the vendor question list is answered (phases in §7A) |
| M6a | Hotspot billing feed | One-way feed of sales/usage to the acquired hotspot BSS (can ship with M2 if its API is available) |
| M7 | Later | Lago usage billing, router self-service, referrals |

M0–M2 first (they deliver the launch product and retire the riskiest integrations, Netcash and MikroTik RADIUS); M3 and M4 then run in parallel.

## 11. Open inputs (none block the design)

Netcash merchant account and service key; MikroTik RouterOS version and current hotspot configuration; SMS provider; KYC vendor decision; Firebase project; final domain names and mobile application id; coverage data source and format; hotspot site list; legal sign-off (RICA applicability to hotspot passes, ECTA/CPA disclosures, POPIA); confirmation of the three alternative controllers after hands-on verification; the acquired hotspot BSS's API or file format; answers to `bss-oss-integration/docs/vendors/vendor-question-list.md` (does each core expose Provisioning MnS or only a vendor interface; exact UDM/UDR products and releases, licensing, change windows, whether subscribers must exist in both cores, IMEI-lock/EIR support); lab core access; SIM vendor key-file and HSM import process; which CPE firmware exposes USIM/ICCID/IMEI via TR-181.

## 12. Multi-tenancy, white-label and cross-ISP federation

Added 2026-09-30. The platform serves other ISPs as well as Sentech: both ISPs that run their own hotspots/networks and resellers that sell access on Sentech's network. Launch runs with Sentech as the only tenant; tenancy foundations are built into M0 because retrofitting them is far costlier than building them in.

**Tenants.** A `tenant` has a type — `operator` (runs its own hotspots and controllers) or `reseller` (sells access on a host operator's network under its own brand) — plus branding, domains, a payment account, a directory-listing flag and a status (`active`/`suspended`). Sentech is the platform-owner tenant (fixed id `00000000-0000-0000-0000-000000000001`, slug `sentech`) and also the first operator tenant.

**Isolation (M0).** Every business table carries `tenant_id` and is protected by Postgres row-level security. Each request/transaction runs as the non-owner role `sentech_app` with the tenant set transaction-locally (`SET LOCAL`), so scope cannot leak across pooled connections. A `platform_admin` role may cross tenants; every such session must name an actor and is written to the audit log. The audit log is append-only (triggers, revoked privileges and RLS) and tenant-scoped. RADIUS controllers (NAS) and hotspots are registered to a tenant. Tests prove one tenant cannot read or write another's rows and that a session with no tenant sees nothing.

**Identity.** One Keycloak realm; the access token carries `tenant_id` (from a user attribute) and realm roles. Customers belong to one tenant: the same phone number in two tenants is two separate accounts, linked only by an explicit, consent-based migration. Tokens without a valid tenant are rejected unless they hold `platform_admin`.

**White-label in the single app.** One app with an ISP drop-down. `GET /v1/app-config?tenant=<slug>` returns the tenant's branding, legal documents and feature flags; `GET /v1/tenants` is the directory of active, listed ISPs. The website resolves the tenant from its domain/subdomain. ISP-branded store builds later come from the same code, one flavor per ISP. Branding is public and must never hold secrets.

**Compare and migrate (post-launch).** A public directory lists opt-in ISPs, hotspots and published pass prices. A verified customer picks a target ISP and consents to share named details; the target creates the account, the source releases it, and unused prepaid value transfers under the tenants' agreed policy. Each ISP is its own POPIA responsible party, so nothing is shared without consent and every step is audited.

**Roaming (later).** A customer of ISP A using ISP B's hotspot: RADIUS realm proxying back to the home ISP, plus a settlement ledger between tenants.

**Resellers on Sentech's network (later).** A reseller buys wholesale from its host operator (price list, capacity caps); its passes create entitlements on the host's controllers, with a settlement ledger between the two.

**Money.** Each ISP has its own Netcash merchant account so funds go directly to that ISP; the platform bills its own fee separately (assumption; to be confirmed commercially).

**Phasing.**

| When | What |
|---|---|
| M0 | Tenant table (Sentech seeded), RLS-scoped tenant sessions, tenant-aware JWT, audit log and app-config, ISP directory, cross-tenant isolation tests, Keycloak tenant mapper |
| M1 | Tenant-scoped catalog, pricing, payments and entitlements; per-tenant flags; tenant drop-down in the app (Sentech only at first) |
| M2-M4 | Per-tenant controllers/RADIUS, theming, public directory and compare view |
| After launch | Second-tenant onboarding (the acceptance test for isolation), migration flow, reseller wholesale and settlement, then roaming |

**Open inputs.** Commercial terms for tenant onboarding and platform fees; per-tenant Netcash accounts; operator agreements and POPIA responsibilities between Sentech and each ISP; which controllers each tenant uses; wholesale price lists for resellers. Market and standards research (ISP SaaS landscape; multi-tenancy, OpenRoaming and TM Forum guidance) is being gathered and will refine this section.

### 12.1 Requirements refined by research (2026-10-01)

Source: `docs/research/2026-10-01-isp-saas-market-and-standards.md`. Directional; legal items need counsel.

**Must (by launch).** RLS on every tenant table, enforced through a non-owner role with transaction-scoped tenant context, and a CI guard that every table with `tenant_id` has enabled+forced RLS and a policy (M0); tenant claim in tokens verified server-side (M0); tenant lifecycle states (trial, active, suspended, offboarded) and automated onboarding/offboarding; per-tenant branding tokens, legal documents and feature flags; a tenant→deployment mapping table so a large ISP can later move to its own database/stamp; POPIA operator-agreement template, sub-processor list and breach runbook; per-tenant RICA data and retention; redirect-only payments via Netcash with an explicit merchant-of-record decision; tenant id on every log, metric and trace; tenant-aware rate limits and queue fairness; South-African hosting; tested per-tenant restore; a single app with a tenant picker.

**Should (launch to +6 months).** Per-tenant envelope encryption for PII and RICA documents; a metering store for subscriber/session/transaction counts and usage-based platform billing; deployment rings and feature flags; status page and per-component SLOs (RADIUS auth availability separately); HMAC-signed webhooks and an API versioning policy; self-service data export; ASVS L2 review and pen test; SOC 2/ISO gap assessment; custom domains with automated TLS; per-tenant licence/exemption verification at onboarding; a consent-stamped migration saga; subscriber and voucher import tools (Splynx, Mikhmon, MikroTik User Manager); load-shedding resilience (idempotent accounting, session reconciliation, offline voucher redemption).

**Could (later).** Silo/stamp tier for large ISPs; bilateral roaming through a platform RADIUS proxy with CDRs and a settlement ledger; per-ISP app builds from each ISP's own developer account; a TM Forum facade (TMF620/622/666/678/668); OpenRoaming/Passpoint; ISO 27001 certification.

**Decisions and open questions.**
- Identity: one Keycloak realm for customers with `tenant_id` now; evaluate Keycloak Organizations in M1 (technology preview in v25; check its status in the pinned version). Staff RBAC and ISP-admin delegation stay in the app database.
- Merchant of record: each ISP's own Netcash account (funds direct) is the working assumption; Sentech collecting on behalf of ISPs raises payment-facilitator/trust-account/FICA questions, so counsel is required before any shared-collection model.
- POPIA roles: ISP = responsible party, platform = operator; the cross-ISP directory, migration and roaming data may make Sentech a responsible party for that processing, so counsel is required.
- App stores: launch one app with a tenant picker (Apple 4.2.6 permits an aggregated picker; 4.3 bans duplicate bundle ids; 5.1.1(v) requires in-app account deletion); per-ISP builds only from each ISP's own developer account.
- Global (cross-tenant) data such as the directory and migration hand-offs lives in a separate schema behind audited SECURITY DEFINER functions, never in tenant tables.
