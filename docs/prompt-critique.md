# Critique: Sentech Connect Flutter Scaffolding Prompt

## Context
Review of the original AI-generated agentic build instruction for the "Sentech Connect" Flutter app (RICA/telecom subscriber app for Sentech's 5G FWA pilot) plus a follow-up architecture/tech-stack writeup, done before either was treated as a build spec. See `reconciled-spec.md` for the resolved, single-source spec that folds in the fixes below.

## Critical gaps

1. **Liveness detection is not fit for RICA's purpose.** `google_mlkit_face_detection` only detects facial landmarks (eyes/smile) — it has no anti-spoofing (a printed photo with cutout eyes, or a video replay, can pass a "blink" prompt). RICA identity verification is a legal compliance requirement, not a UX nicety; using bare ML Kit here is a real fraud vector. Purpose-built liveness/ID-verification SDKs (e.g. Smile Identity, iProov, FaceTec, Onfido — several have Africa-specific accreditation) are the standard tool for this, and the plan should call that out as a vendor decision, not assume ML Kit suffices.

2. **POPIA is never mentioned**, despite the app capturing ID documents, proof of residence, and biometric liveness data — the most sensitive category of personal information under South Africa's Protection of Personal Information Act. The plan should require: encryption at rest for captured documents, explicit consent flows, defined retention/deletion policy, and secure wipe of camera cache files after successful upload (the `camera` plugin writes photos to app cache by default — these must be deleted post-submission, not left for OS cleanup).

3. **Internal contradiction: "production-ready" vs. Step 4's mock repositories.** The mission statement demands a production-ready app; Step 5 of the execution steps says to build mock API repositories wired into the UI "to ensure a fully functional, navigable UI demo." That's a reasonable scaffolding step, but the prompt should say explicitly that output is a demo shell with fake backends, not production-ready — otherwise it's easy to mistake generated mock-backed code for done.

## Other notable gaps

- **Payment compliance unaddressed.** Card payments via Ozow/PayShap/Peach need PCI-DSS-compliant hosted fields/tokenization, not a generic "abstract payment gateway interface." The plan should commit to each provider's hosted checkout/tokenized flow rather than imply a card form is built in-app.
- **CPE/router telemetry has no backend contract.** Module F wants MAC address and live signal strength for customer routers/MiFi — this requires a TR-069/CWMP or vendor-specific telemetry API that's never named. Worth flagging as an unscoped integration, not just a UI screen.
- **fpdart vs dartz:** the prompt offers both; dartz is effectively unmaintained. Should commit to `fpdart`.
- **Isar as local cache:** Isar's maintenance/release cadence has been inconsistent — worth a fallback note (Drift/Hive) rather than treating it as a safe default.
- **Maps ambiguity:** `flutter_map` (free, OSM-based) vs `google_maps_flutter` (Google-billed) are presented as interchangeable ("/"), but they have very different cost and data-licensing implications for coverage polygon rendering — this is a real decision, not a detail.
- **SSL pinning has no rotation story.** Cert pinning without a remote-config/backup-pin strategy risks locking out the entire install base on a cert rotation.
- **OIDC provider unnamed.** "OAuth2/OpenID Connect login" doesn't say against which IdP (Sentech's own IAM? Keycloak/Auth0?) — `flutter_appauth` should be named explicitly rather than implying a hand-rolled OAuth flow.
- **The two documents disagree with each other**: the user's stack table adds `retrofit` (code-gen REST client) not present in the original instruction, drops explicit mention of the biometrics/local-auth package, and softens the maps and error-handling library choices into either/or where the original prompt was more decisive.

## How to resolve the three critical gaps

**1. Liveness detection** — Don't build liveness in-house on top of `google_mlkit_face_detection`; it only tracks facial landmarks and has no anti-spoofing. Swap the `rica` feature's liveness step to a certified vendor SDK behind the same `LivenessRepository` interface:
   - **Smile Identity** is the strongest fit — African/South African accreditation, does ID + liveness + KYC in one flow.
   - iProov / FaceTec are enterprise alternatives (higher cost, used by banks).
   - Keep ML Kit only as a cheap client-side pre-check (face present, not blurry, eyes open) before the real liveness call — never as the liveness proof itself.
   - This is a data-layer swap only; the Clean Architecture shape (`domain/repositories/liveness_repository.dart`) doesn't change.

**2. POPIA compliance** — Treat as a cross-cutting requirement, not a feature:
   - Extend `core/security` with document-level encryption at rest (per-install key via `flutter_secure_storage`) for captured ID/PoR images, on top of OS-level disk encryption.
   - Add an explicit consent screen before RICA capture starts; send a timestamped consent record to the backend.
   - Delete camera-cache files immediately after a confirmed successful upload (on 2xx response) rather than relying on OS temp cleanup.
   - Give Module G (support) a stub "access/delete my data" ticket path, since POPIA requires a channel for data subject requests.

**3. "Production-ready" vs. mock-backed demo** — Resolve by splitting scope explicitly instead of leaving it implicit:
   - Reframe the scaffolding step as: mock repositories implement the same `domain/repositories` interfaces the real Dio-backed implementations will use, so swapping in real APIs later is a drop-in.
   - Name mock code unambiguously (`MockRicaRepository`, a `--flavor demo` build flavor) so it's never mistaken for a real integration.
   - "Production-ready" should describe the architecture/security scaffolding (DI, error handling, secure storage, SSL pinning) — be explicit that business data stays mocked until real API contracts exist.

## Minor
- The directory tree in the original doc has encoding artifacts and shows `data/domain/presentation` sub-layers nested only under `support/`, implying (probably unintentionally) that other feature folders don't get the same layering.
