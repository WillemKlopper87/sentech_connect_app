# Sentech Connect — Reconciled Build Spec (v1)

Client: Sentech SOC Ltd · Service Provider: Jalusi Tech
Reconciles the original agentic scaffolding prompt and the follow-up architecture writeup into one spec, with the gaps from review resolved. Android-first, iOS-ready.

---

## 1. Scope framing

This spec produces a **scaffolded architecture with mocked business data**, not a finished production app. "Production-ready" applies to the architecture and security plumbing (DI, error handling, secure storage, SSL pinning, CI-ready structure) — not to business data, which stays behind mock repositories until real backend contracts exist.

All mock implementations satisfy the same `domain/repositories` interfaces the real Dio-backed implementations will use later, so swapping one for the other is a drop-in change. Mock classes are named unambiguously (`MockRicaRepository`, etc.) and gated behind a `--flavor demo` build flavor so they can never be mistaken for a live integration.

## 2. Architecture

Feature-First Clean Architecture, three layers per feature, applied uniformly to every feature module (not just one, as the original tree ambiguously implied):

```
lib/
├── app/                        # app.dart, go_router config, Material 3 theme/tokens
├── core/
│   ├── error/                  # Failure models, exceptions
│   ├── network/                # Dio client + retrofit-generated clients, interceptors
│   ├── security/                # SecureStorage wrapper, SSL pinning, document-at-rest encryption
│   ├── usecases/               # Base UseCase abstract class
│   └── utils/                  # Formatters, validators
└── features/
    ├── auth/
    ├── rica/
    ├── coverage/
    ├── catalog_checkout/
    ├── voucher_scanner/
    ├── account_dashboard/
    └── support/
        ├── data/{datasources,models,repositories}/
        ├── domain/{entities,repositories,usecases}/
        └── presentation/{bloc,pages,widgets}/
```

- **State management:** `flutter_bloc`
- **DI:** `get_it` + `injectable`
- **Error handling:** `fpdart` (`Either<Failure, T>`) — dartz is unmaintained, not used
- **Local storage:** `flutter_secure_storage` for tokens/keys; **Drift** (sqlite) for structured offline cache — Isar dropped due to inconsistent release cadence
- **REST client:** `dio` + `retrofit` for codegen'd typed clients, with interceptors for JWT refresh, cert pinning, logging

## 3. Feature modules

### A. Auth & Profile Security
- OAuth2/OIDC login against Sentech's IdP via **`flutter_appauth`** (named explicitly — no hand-rolled OAuth flow)
- Biometric quick-unlock via `local_auth`
- Tokens in `flutter_secure_storage`; Dio interceptor handles silent refresh

### B. Digital RICA Verification Engine
- Document capture: `camera` plugin for ID (Book/Smart Card/Passport) and Proof of Residence
- **Liveness:** certified vendor SDK behind a `LivenessRepository` interface — **Smile Identity** recommended (South African/African KYC accreditation, ID+liveness in one flow); iProov/FaceTec as enterprise alternatives. `google_mlkit_face_detection` is used only as a cheap client-side pre-check (face present, not blurry, eyes open) before the real liveness call — never as the liveness proof itself, since ML Kit alone has no anti-spoofing and can be beaten by a printed photo or video replay.
- **POPIA compliance (cross-cutting, not a feature):**
  - Captured ID/PoR images encrypted at rest with a per-install key from `flutter_secure_storage`, on top of OS disk encryption
  - Explicit consent screen before capture starts; timestamped consent record sent to backend
  - Camera-cache files deleted immediately on confirmed upload success (2xx) — not left to OS temp cleanup
  - Data-subject "access/delete my data" request path stubbed in Module G

### C. GIS Coverage Qualification
- GPS lookup via `geolocator`; manual address lookup fallback
- Map rendering: **decide explicitly between** `flutter_map` (OSM, free, no vendor billing) and `google_maps_flutter` (Google-billed, richer base layers) — these are not interchangeable, pick one before scaffolding based on cost tolerance and whether Sentech needs Google's base imagery
- Coverage polygons/eligibility served from a coverage API (endpoint TBD with Sentech — flag as an open integration point, not assumed to exist yet)

### D. Product Catalog, Cart & Checkout
- Products: 5G FWA, Business Internet, MiFi passes, Wi-Fi Vouchers
- Cart state via BLoC
- **Payments:** each provider's **hosted/tokenized checkout** (Ozow, PayShap, Peach Payments) behind a common `PaymentGateway` interface — no in-app raw card form, since that requires PCI-DSS scope the app should not take on. WebView or SDK-hosted fields only.

### E. Wi-Fi Voucher Engine & Scanner
- `mobile_scanner` for QR/barcode capture
- Redemption payload submitted directly to Voucher Management Platform

### F. Account Dashboard & Router Management
- Usage meters, plan expiry, CPE/MiFi device list
- **Open dependency:** live MAC address / signal strength requires a TR-069/CWMP or vendor-specific telemetry API — not yet named by Sentech. Scaffold the UI against a mocked `RouterTelemetryRepository`; do not assume a live feed exists until that API is confirmed.

### G. Support & Push Notifications
- FCM for usage alerts, payment receipts, maintenance notices
- FAQ search + support ticket creation against CRM API
- Includes the POPIA data-subject request stub from Module B

## 4. Security posture

- SSL pinning in Dio, **with a backup-pin + remote-config rotation story** so a certificate rotation doesn't lock out the installed base (pin set fetched/refreshed via a signed remote config, not hardcoded with no update path)
- All tokens/keys in `flutter_secure_storage`
- Document-at-rest encryption for RICA captures (see Module B)

## 5. Execution steps

1. `pubspec.yaml` with the reconciled dependency list: `flutter_bloc`, `get_it`, `injectable`, `dio`, `retrofit`, `go_router`, `geolocator`, `mobile_scanner`, `camera`, `google_mlkit_face_detection` (pre-check only), `flutter_secure_storage`, `equatable`, `fpdart`, `flutter_appauth`, `local_auth`, `drift`, one of `flutter_map`/`google_maps_flutter` (explicit choice)
2. Core classes: `Failure` hierarchy, `UseCase` base, `DioClient` with pinning + refresh interceptors, `SecureStorage` wrapper with document encryption helpers, Material 3 theme
3. Domain entities, repository interfaces, and BLoCs for Module B (RICA) and Module C (Coverage), including the `LivenessRepository` and `RouterTelemetryRepository` interfaces as explicit open integration points
4. Mock repositories (named `Mock*Repository`, `--flavor demo`) wired to presentation for a navigable UI demo — explicitly documented as non-production data
5. Unit tests for BLoCs and UseCases

## 6. Open items requiring a decision before/soon after scaffolding
- Liveness vendor selection (Smile Identity vs. alternatives) and contract/accreditation status
- Coverage API and CPE telemetry API endpoints from Sentech
- Maps provider choice (cost decision)
- Payment provider hosted-checkout integration details per gateway
