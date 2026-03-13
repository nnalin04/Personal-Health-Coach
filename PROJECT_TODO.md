# Project TODO - Deployment and Production Readiness

This checklist is focused on one goal: a user with the APK can use the full AI Health system end-to-end.

## 1) Infrastructure and Hosting

- [x] Provision a public server/VPS (or cloud) for `springboot-app`, `fastapi-ai`, and `postgres`.
      → GCP Compute Engine (health-coach-dev @ 34.45.115.228)
- [x] Set DNS records for public API domain.
      → DuckDNS: healthcoach.duckdns.org → 34.45.115.228
- [x] Add HTTPS/TLS (Let's Encrypt, valid until 2026-05-30) via nginx reverse proxy.
- [x] Restrict AI service to private/internal network only (no public ingress on FastAPI).
      → nginx blocks /api/health and /api/nutrient externally; prod compose has no port:8000 mapping.
- [x] Configure persistent storage volumes for Postgres (docker volume) and uploaded reports.
- [x] Configure automated Postgres backups (daily pg_dump to GCS gs://health-coach-db-backups at 02:00 UTC).

## 2) Secrets and Environment

- [x] Set strong production secrets (JWT_SECRET, POSTGRES_PASSWORD, GEMINI_API_KEY, GOOGLE_CLIENT_ID).
- [x] Store secrets in GCP Secret Manager (7 secrets created: health-coach-\*) — referenced in prod .env on VM.
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
- [x] Rename package from `com.example` to `com.healthcoach.personal_health_coach` for production branding.
      → Already `com.healthcoach.personal_health_coach` in mobile/android/app/build.gradle.kts.

## 5) Security and Compliance Baseline

- [x] Disable debug endpoints/log verbosity in production.
- [x] Add API rate limiting (especially auth and AI endpoints) using Bucket4j.
- [x] Add request size limits for medical report uploads.
- [x] Add data deletion/export workflows for user privacy.
      → DELETE /api/users/me (204) + GET /api/users/me/export (full JSON data export).

## 6) Monitoring and Operations

- [x] Add service health dashboard and alerts (app up/down, DB health, AI errors).
      → AiServiceHealthIndicator bean + /actuator/health (show-details: always) + scripts/healthcheck.sh + docs/monitoring.md.
- [x] Add structured log aggregation (Spring + FastAPI).
      → logback-spring.xml (JSON via logstash-logback-encoder) + ai-service JSON formatter.
- [x] Add incident runbook for API outage, DB restore, and key rotation.
      → docs/runbook.md.

## 7) CI/CD and Release Process

- [x] CI pipeline for:
  - backend tests (JUnit5, H2 in-memory)
  - AI tests (pytest + TestClient)
  - Flutter tests
  - iOS compile check (flutter build ios --no-codesign on macos-latest)
      → .github/workflows/ci.yml (triggers on PR + push to main).
- [x] CD pipeline for controlled deploy with rollback strategy.
      → .github/workflows/cd.yml (triggers on v*.*.* tags; builds GCR images, deploys to VM via SSH).
- [x] Versioned release notes and APK artifact publishing.
      → scripts/create_release.sh + CD workflow publishes signed APK to GitHub Release.

## 8) End-to-End Validation Before Launch

- [x] Register/login (email + Google)
- [x] Log workout/food/body metrics/steps
- [x] Upload medical report
- [x] Generate `/health-summary/me`
- [x] Generate `/health-summary/me/ai-insights`
- [x] Confirm results visible in app on physical device
      → All 11 API flows PASS against live prod (e2e_prod_test.py, 2026-03-01).

---

## 9) iOS Support and Apple Compatibility

- [ ] Install Xcode from Mac App Store. ⚠️ USER ACTION REQUIRED.
- [x] Run `cd mobile && flutter build ios --no-codesign` to verify base build.
      → Added to CI as `ios-compile` job on macos-latest runner (.github/workflows/ci.yml).
- [x] Configure `Info.plist` for camera/photo permissions (if needed for reports).
      → NSCamera, NSMicrophone, NSPhotoLibrary, NSLocalNetwork all declared in mobile/ios/Runner/Info.plist.
- [ ] Configure `Runner` Bundle ID and signing in Xcode project. ⚠️ USER ACTION REQUIRED (needs Xcode).
- [ ] Verify app on iOS Simulator. ⚠️ USER ACTION REQUIRED (needs Xcode installed).
- [ ] Verify app on physical iPhone/iPad. ⚠️ USER ACTION REQUIRED (needs Apple Developer account + device).

---

## 10) Nutrient Intelligence Feature

> Full plan: `plans/nutrient_intelligence_plan.md`

### Phase 1 — Foundation

- [x] Add `NutrientLog` entity + Flyway migration (Backend)
- [x] Add `POST /food/analyze-nutrients` endpoint in AI service (Gemini vision + text → micronutrients)
- [x] Add `GET /nutrient/daily-summary` and `/nutrient/weekly-trends` endpoints (Backend)
- [x] Add RDA constants service in backend (per gender/age)
- [x] Wire food log save to also trigger nutrient analysis asynchronously

### Phase 2 — Recommendations

- [x] Add `region`, `cuisine_style`, `dietary_restrictions` to user profile
- [x] Add onboarding step to collect region + dietary preferences
- [x] Add `POST /nutrient/recommendations` in AI service (14-day deficiency → Gemini → culturally-aware advice)
- [x] Infer cuisine style from food log history (majority vote on recognized food types)

### Phase 3 — Mobile UX

- [x] Add camera 📷 and text describe ✏️ input buttons to Food Log screen
- [x] Build nutrient breakdown card (shows after food log: vitamins/minerals vs RDA)
- [x] Build Nutrient Dashboard screen (weekly heatmap of micronutrient coverage)
- [x] Add Nutrition Intelligence section to Insights screen (top deficiencies + cultural food suggestions)
- [x] Add daily push notification summarising deficiencies (optional, user-toggleable)

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

---

## 11) Health OS Architecture Pivot (2026-03-14)

> Full spec: `Health OS Architecture and Roadmap.md`

### Phase 1 — Infrastructure + Monorepo ✅
- [x] Restructure to monorepo: `services/orchestrator`, `services/ai-engine`, `apps/mobile-app`, `libs/shared-schema`, `infra/`
- [x] Archive Flutter app to `apps/flutter-legacy/`
- [x] Replace `postgres:16` with `pgvector/pgvector:pg16` in all compose files
- [x] Add RabbitMQ 3.13 to docker-compose (local + prod)
- [x] Add Redis 7 to docker-compose (for RAG Redis Streams)
- [x] V5 Flyway migration: `CREATE EXTENSION vector`, `taste_profiles`, `knowledge_base`, `omni_chat_tasks`, WatermelonDB `updated_at` columns

### Phase 2 — Mobile Foundation + Sync ✅
- [x] Bootstrap React Native + Expo (blank-typescript) in `apps/mobile-app`
- [x] Install WatermelonDB + Zustand + @react-navigation
- [x] 3-page minimalist UI: OnboardingScreen, DashboardScreen, OmniChatScreen
- [x] `POST /api/v1/sync/pull` and `POST /api/v1/sync/push` WatermelonDB sync endpoints
- [ ] WatermelonDB schema definition (Model classes for MealLog, BloodMetrics, etc.) — Phase 2b
- [ ] Full push phase upsert logic in SyncController — Phase 2b
- [ ] TasteProfile loading from DB for OmniChat user context — Phase 2b

### Phase 3 — AI Intelligence + Smart Routing ✅
- [x] Smart Router in FastAPI (`app/routers/smart_router.py`) — classifies FOOD | REPORT | TEXT
- [x] RabbitMQ producer (`TaskPublisher.java`) in Spring Boot — food.vision, medical.ocr, rag.correlate routing keys
- [x] RabbitMQ consumer (`rabbitmq_consumer.py`) in FastAPI — dispatches to Smart Router
- [x] `POST /api/v1/chat/upload` OmniChat endpoint in Spring Boot — returns taskId + "PROCESSING"
- [x] `spring-boot-starter-amqp` + `spring-boot-starter-websocket` added to pom.xml
- [x] `aio-pika`, `langchain`, `pgvector`, `psycopg2-binary` added to AI service requirements.txt
- [ ] WebSocket notification back to mobile on task completion — Phase 3b
- [ ] GCS file upload for food images and PDFs — Phase 3b

### Phase 4 — Clinical OCR + RAG (Pending)
- [ ] Google Cloud Document AI integration for medical PDF parsing
- [ ] LangChain + pgvector RAG correlation engine
- [ ] Knowledge Base seeding with ICMR dietary guidelines + FSSAI RDA data
- [ ] WebSocket bridge (STOMP over WS) for real-time task notifications
- [ ] Graceful fallback conversation when food confidence < 0.80

### Phase 5 — Compliance + Regional Refinement (Pending)
- [ ] DPDP Act compliance: AES-256 `@ColumnTransformer` on sensitive medical fields
- [ ] Consent management: `consent_version` + `withdrawal_requested` flow
- [ ] 72-hour breach notification documentation
- [ ] Quick-commerce receipt parsing (Blinkit/Instamart OCR)
- [ ] Full security audit against Health OS threat model
