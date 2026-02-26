# Project TODO - Deployment and Production Readiness

This checklist is focused on one goal: a user with the APK can use the full AI Health system end-to-end.

## 1) Infrastructure and Hosting

- [ ] Provision a public server/VPS (or cloud) for `springboot-app`, `fastapi-ai`, and `postgres`.
- [ ] Set DNS records for public API domain (example: `api.yourdomain.com`).
- [ ] Add HTTPS/TLS (Let's Encrypt or managed cert) in front of Spring Boot (Nginx/Caddy/Cloud LB).
- [ ] Restrict AI service to private/internal network only (no public ingress on FastAPI).
- [ ] Configure persistent storage volumes for Postgres and uploaded reports.
- [ ] Configure automated Postgres backups and restore test.

## 2) Secrets and Environment

- [ ] Set strong production secrets:
  - `JWT_SECRET`
  - `POSTGRES_PASSWORD`
  - `GEMINI_API_KEY`
  - `GOOGLE_CLIENT_ID`
- [ ] Store secrets in a secret manager or protected `.env` (never commit).
- [ ] Set production `SPRING_DATASOURCE_*`, `AI_BASE_URL`, and upload directory path.

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

## Work Completed in This Iteration

- [x] Implemented runtime API Base URL support in mobile app.
- [x] Persisted API Base URL in secure storage and auto-applied on app startup.
- [x] Fixed mobile tests and verified Flutter tests pass.
- [x] Built release APK successfully:
  - `mobile/build/app/outputs/flutter-apk/app-release.apk`
