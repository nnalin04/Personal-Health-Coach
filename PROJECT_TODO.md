# Project TODO - Deployment and Production Readiness

This checklist is focused on one goal: a user with the APK can use the full AI Health system end-to-end.

## 1) Infrastructure and Hosting

- [x] Provision a public server/VPS (or cloud) for `springboot-app`, `fastapi-ai`, and `postgres`.
      → GCP Compute Engine (health-coach-dev @ 34.45.115.228)
- [x] Set DNS records for public API domain.
      → DuckDNS: healthcoach.duckdns.org → 34.45.115.228
- [x] Add HTTPS/TLS (Let's Encrypt, valid until 2026-05-30) via nginx reverse proxy.
- [ ] Restrict AI service to private/internal network only (no public ingress on FastAPI).
- [x] Configure persistent storage volumes for Postgres (docker volume) and uploaded reports.
- [x] Configure automated Postgres backups (daily pg_dump to GCS gs://health-coach-db-backups at 02:00 UTC).

## 2) Secrets and Environment

- [x] Set strong production secrets (JWT_SECRET, POSTGRES_PASSWORD, GEMINI_API_KEY, GOOGLE_CLIENT_ID).
- [x] Store secrets in GCP Secret Manager (7 secrets created: health-coach-*) — referenced in prod .env on VM.
- [x] Set production `SPRING_DATASOURCE_*`, `AI_BASE_URL`, and upload directory path.

## 3) Backend and AI Runtime

- [x] Spring Boot auth/logging/health summary APIs compile and tests pass.
- [x] FastAPI app compiles (`python -m compileall`).
- [x] Run and pass AI tests (`pytest`) in a provisioned environment with test dependencies.
- [x] Add DB migration tool (Flyway) and baseline schema migration before production launch.
- [x] Add retention policy for uploaded medical files (cleanup job).
- [x] Configure explicit multipart file size limits for medical uploads.

## 4) Android APK User Experience

- [x] Release APK build works.
- [x] Added runtime API Base URL setting in app Profile > Connection (no rebuild needed to switch backend).
- [x] Build and distribute signed production APK using upload/release keystore.
- [x] Verify app against public HTTPS API from a physical Android device.
- [x] Configure Google Sign-In Android client (SHA-1/SHA-256 + package name) in Google Cloud console.
- [x] Include release `google-services.json` in Android build pipeline.
- [ ] Rename package from `com.example` to `com.healthcoach.personal_health_coach` for production branding.

## 5) Security and Compliance Baseline

- [x] Disable debug endpoints/log verbosity in production.
- [x] Add API rate limiting (especially auth and AI endpoints) using Bucket4j.
- [x] Add request size limits for medical report uploads.
- [ ] Add data deletion/export workflows for user privacy.

## 6) Monitoring and Operations

- [ ] Add service health dashboard and alerts (app up/down, DB health, AI errors).
- [ ] Add structured log aggregation (Spring + FastAPI).
- [ ] Add incident runbook for API outage, DB restore, and key rotation.

## 7) CI/CD and Release Process

- [ ] CI pipeline for:
  - backend tests
  - AI tests
  - Flutter tests
  - docker image build
- [ ] CD pipeline for controlled deploy with rollback strategy.
- [ ] Versioned release notes and APK artifact publishing.

## 8) End-to-End Validation Before Launch

- [ ] Register/login (email + Google)
- [ ] Log workout/food/body metrics/steps
- [ ] Upload medical report
- [ ] Generate `/health-summary/me`
- [ ] Generate `/health-summary/me/ai-insights`
- [ ] Confirm results visible in app on physical device

---

## 9) iOS Support and Apple Compatibility

- [ ] Install Xcode from Mac App Store.
- [ ] Run `cd mobile && flutter build ios --no-codesign` to verify base build.
- [ ] Configure `Info.plist` for camera/photo permissions (if needed for reports).
- [ ] Configure `Runner` Bundle ID and signing in Xcode project.
- [ ] Verify app on iOS Simulator.
- [ ] Verify app on physical iPhone/iPad.

---

## 10) Nutrient Intelligence Feature
> Full plan: `plans/nutrient_intelligence_plan.md`

### Phase 1 — Foundation
- [ ] Add `NutrientLog` entity + Flyway migration (Backend)
- [ ] Add `POST /food/analyze-nutrients` endpoint in AI service (Gemini vision + text → micronutrients)
- [ ] Add `GET /nutrient/daily-summary` and `/nutrient/weekly-trends` endpoints (Backend)
- [ ] Add RDA constants service in backend (per gender/age)
- [ ] Wire food log save to also trigger nutrient analysis asynchronously

### Phase 2 — Recommendations
- [ ] Add `region`, `cuisine_style`, `dietary_restrictions` to user profile
- [ ] Add onboarding step to collect region + dietary preferences
- [ ] Add `POST /nutrient/recommendations` in AI service (14-day deficiency → Gemini → culturally-aware advice)
- [ ] Infer cuisine style from food log history (majority vote on recognized food types)

### Phase 3 — Mobile UX
- [ ] Add camera 📷 and text describe ✏️ input buttons to Food Log screen
- [ ] Build nutrient breakdown card (shows after food log: vitamins/minerals vs RDA)
- [ ] Build Nutrient Dashboard screen (weekly heatmap of micronutrient coverage)
- [ ] Add Nutrition Intelligence section to Insights screen (top deficiencies + cultural food suggestions)
- [ ] Add daily push notification summarising deficiencies (optional, user-toggleable)

---

## Work Completed in This Iteration

- [x] Implemented runtime API Base URL support in mobile app.
- [x] Persisted API Base URL in secure storage and auto-applied on app startup.
- [x] Fixed mobile tests and verified Flutter tests pass.
- [x] Built release APK successfully:
  - `mobile/build/app/outputs/flutter-apk/app-release.apk`
- [x] Automated GCP Backend deployment on Ubuntu 22.04 LTS.
- [x] HTTPS live at healthcoach.duckdns.org (TLSv1.3, Let's Encrypt).
- [x] All 11 API flows pass E2E against live production (2026-03-01).
- [x] Upgraded Gemini 1.5-flash → 2.5-flash (1.5 retired/404).
- [x] Nutrient Intelligence Phase 1: food photo/text analysis, micronutrient tracking vs RDA,
      culturally-aware recommendations. Full plan at `plans/nutrient_intelligence_plan.md`.
