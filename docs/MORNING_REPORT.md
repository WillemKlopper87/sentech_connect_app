# Status report — Sentech Connect app (updated 2026-10-01)

Short mirror of the platform report: `../sentech_connect_platform/docs/MORNING_REPORT.md` (full detail, decisions, release gates).

**This app (branch `feat/m4-lite-real-api`) is review-ready.** All 13 M4-lite tasks are done, each independently reviewed; the whole-branch review and its fix wave were accepted. `flutter analyze` is clean and 710 tests pass (plus 1 opt-in live integration test, skipped by default).

- Real API repositories: tenant picker/branding, phone OTP with tenant- and customer-bound sessions, consent/privacy (export, deletion), catalogue/orders with idempotent checkout, hosted payment in a locked-down web view with server-status polling, My passes.
- Demo flavour leads with hotspot passes (R15/R35/R129/R349); prod hides features still backed by mocks (Scan, Support, free Wi-Fi).
- Live run against the platform dev stack passed end to end (OTP → consent → order → fake payment → paid → pass → logout). Re-run on freshly built backend images before sign-off.

Open items for this app: Netcash sandbox check of 3-D Secure/EFT redirects in the web view; native isiZulu/Afrikaans review; remaining hard-coded strings on older screens; Android device/APK build evidence; minor follow-ups listed in `.superpowers/sdd/2026-10-01-m4-lite-mobile-real-api/progress.md`.

The platform side: backend core (M0+M1) and coverage service (M3a) are review-ready; the public website is paused after Task 10 of 16 at the owner's request; vouchers/RADIUS (M2) and the admin console are not started. Nothing has been pushed, merged, published or deployed.
