# Product Requirements Document
**Product:** Personal AI Health Intelligence System
**Version:** 2026-03-01
**Status:** Draft
**Author:** PM Agent (synthesised from 6 domain expert reports)

---

## 1. Executive Summary

The Personal AI Health Intelligence System is a cross-platform mobile application that centralises a user's health data into a single intelligent hub, replacing the fragmented experience of juggling multiple fitness, nutrition, and medical tracking apps. The system combines a Java Spring Boot backend, a Python FastAPI AI service powered by Google Gemini, and a Flutter mobile app targeting Android (with iOS and web as secondary targets).

The product gives users a single place to log workouts, meals, body metrics, steps, and medical reports. An embedded AI layer analyses this aggregated data to surface personalised health insights, parse uploaded lab reports, and answer natural-language health queries. The result is a health companion that is simultaneously a data logger, an AI analyst, and a personal health dashboard.

The intended audience is health-conscious individuals who want meaningful, AI-driven insights from their own data — not just raw numbers. The system is being built for broader public release and must therefore meet commercial-grade standards for security, reliability, and user experience before launch.

---

## 2. Problem Statement

Health-conscious individuals currently manage their health data across 5–10 separate apps (a fitness tracker, a calorie counter, a blood pressure log, a document scanner for lab results, etc.). None of these tools talk to each other, so no single system can see the full picture. When something is wrong — or going well — users cannot easily connect the dots.

The core problem this product solves, from the user's perspective:
> *"I want one place where all my health data lives, where an AI can look across everything and tell me what it actually means for my health."*

---

## 3. Target Users

### 3.1 Primary Persona — Health-Conscious Individual
- Age: 25–50
- Motivation: Wants to understand their health holistically, not just track individual metrics
- Behaviour: Logs workouts and meals regularly, gets periodic blood work, wants AI explanations not raw numbers
- Pain point: Data is scattered; no single tool connects fitness + nutrition + medical data

### 3.2 Secondary Persona — Health Recovery / Chronic Condition User
- Motivation: Managing a condition (diabetes, hypertension, post-surgery recovery) with medical guidance
- Behaviour: Uploads medical reports frequently, tracks specific biomarkers over time
- Pain point: Cannot easily share AI-interpreted summaries with their doctor

### 3.3 Future Persona — Healthcare Provider (Post-v1.0)
- Out of scope for v1.0 but noted for roadmap planning

---

## 4. Goals & Success Metrics

| Goal | Metric | Target |
|------|--------|--------|
| Production deployment | App accessible via HTTPS on GCP with signed APK | v1.0 release |
| Security baseline | 0 critical security vulnerabilities at launch | cleartext disabled, secrets secured |
| AI insight quality | Users rate AI insights as "useful" | ≥ 70% positive rating |
| Data completeness | All major health domains covered | Workout, Food, Steps, Body Metrics, Medical |
| Mobile screen completion | All core screens fully functional | 100% (currently 8/14 complete) |
| API coverage | All logged data queryable via API | Full CRUD for all entities |
| Onboarding success | New user can log first entry within 3 minutes | Measured via analytics post-launch |

---

## 5. Feature Inventory (Existing)

### 5.1 Backend Features (from java-expert)

The backend exposes **11 REST controller groups** across the following domains:

| Controller | Base Path | Key Methods |
|-----------|-----------|-------------|
| AuthController | `/api/auth` | POST register, POST login, POST google-login, GET me |
| WorkoutController | `/api/workouts` | POST log, GET all, GET by-type |
| FoodController | `/api/food` | POST log, GET all, GET by-date |
| BodyMetricsController | `/api/body-metrics` | POST log, GET all, GET latest |
| StepsController | `/api/steps` | POST log, GET all, GET by-date |
| MedicalReportController | `/api/medical-reports` | POST upload, GET all, GET by-id, DELETE |
| HealthSummaryController | `/api/health-summary` | GET /me (aggregated summary), GET /me/ai-insights |
| LabValuesController | `/api/lab-values` | POST extract (from medical report), GET by-report |
| HealthGoalController | `/api/health-goals` | POST create, GET all, PUT update |
| UserController | `/api/users` | GET profile, PUT update |
| AiMetricsController | `/api/ai/metrics` | POST extract metrics from text |

**Data Entities:** User, WorkoutLog, FoodLog, BodyMetrics, StepsLog, MedicalReport, LabValues, HealthGoal

**Auth Model:** JWT (HS256, 24-hour expiry) for standard login; Google OAuth for social login. Tokens stored via `flutter_secure_storage` on mobile.

### 5.2 AI Features (from python-expert)

The AI service exposes **4 FastAPI routes**:

| Route | Method | Purpose |
|-------|--------|---------|
| `/analyze-health` | POST | Generates personalised health recommendations from aggregated health data |
| `/parse-medical-report` | POST | Extracts structured data from medical report text |
| `/extract-metrics` | POST | Extracts specific health metrics (HR, BP, glucose, etc.) from free text |
| `/health` | GET | Service health check |

**Gemini Integrations:**
1. **Health Recommendations** — Takes workout, food, steps, body metrics summary → returns personalised insights and action items
2. **Medical Report Parsing** — Text-based extraction of diagnoses, medications, test results from clinical documents
3. **Medical Vision Parsing** — Multimodal (image) parsing of scanned medical documents
4. **Metrics Extraction** — Structured extraction of numerical health metrics from unstructured text

**RAG Support:** Stubbed — `_retrieve_knowledge()` is hardcoded and not yet connected to a real knowledge base.

### 5.3 Mobile Features (from flutter-expert)

**15 screens across 10 feature areas:**

| Screen | Status | Key Actions |
|--------|--------|-------------|
| Login | Complete | Email/password login, Google sign-in |
| Register | Complete | Account creation with profile setup |
| Dashboard | Complete | Health summary, quick stats, navigation hub |
| Add Workout | Complete | Log workout type, duration, calories |
| Add Food | Complete | Log meal with calories and macros |
| Add Body Metrics | Complete | Log weight, BMI, body fat |
| Add Steps | Placeholder | UI shell only — no submit logic |
| View Trends | Partial | Charts render but data is hardcoded in places |
| AI Insights | Partial | Connects to AI service; loading/error states incomplete |
| Medical Hub | Partial | Report upload UI present; full hub navigation incomplete |
| Upload Medical Report | Complete | Camera + file picker, sends to backend |
| Chat / AI Logging | Partial | Natural language logging via AI; parse failure is silent |
| Profile Settings | Partial | 3 of 4 tabs functional; missing "Health Goals" tab |
| Dashboard Shell | Complete | Bottom nav routing (4 tabs) |
| Logging Screen | Partial | FAB present but tap action not wired |

**State Management:** Riverpod — `authController`, `apiClient`, `tokenStorage`, `appConfigStorage`

---

## 6. Feature Requirements (Planned)

Features are derived from the PROJECT_TODO.md backlog, expert gap analysis, and user direction. Priority: P1 = must-have for v1.0, P2 = v1.1, P3 = future.

### 6.1 Fix Cleartext Traffic (CRITICAL SECURITY)
- **Priority:** P1
- **User Story:** As a user, I want my health data transmitted securely so that it cannot be intercepted.
- **Acceptance Criteria:**
  - [ ] `android:usesCleartextTraffic="true"` removed from AndroidManifest.xml
  - [ ] All API calls use HTTPS
  - [ ] Backend served behind HTTPS (nginx + Let's Encrypt or GCP HTTPS LB)
  - [ ] App tested on production-like HTTPS environment
- **Technical Notes:** Requires backend HTTPS setup before mobile change can be finalised

### 6.2 HTTPS + Production Infrastructure
- **Priority:** P1
- **User Story:** As a user, I want the app to be reliably available so I can log my health data anytime.
- **Acceptance Criteria:**
  - [ ] GCP Compute Engine instance has a static IP
  - [ ] Nginx configured as reverse proxy with SSL termination
  - [ ] Let's Encrypt certificate auto-renewed
  - [ ] Docker Compose production config (`docker-compose.prod.yml`) finalised
  - [ ] Automated startup on VM reboot
- **Technical Notes:** Blocks all other production readiness work

### 6.3 Secrets Management
- **Priority:** P1
- **User Story:** As a developer/operator, I want secrets never committed to source control so that the system is not compromised.
- **Acceptance Criteria:**
  - [ ] JWT secret, DB password, Gemini API key stored in GCP Secret Manager or equivalent
  - [ ] No secrets in `env.dev`, `env.prod` files committed to git
  - [ ] `.gitignore` updated to exclude all `.env*` files
  - [ ] CI/CD injects secrets at deploy time
- **Technical Notes:** Backend and AI service both need this

### 6.4 Complete Add Steps Screen
- **Priority:** P1
- **User Story:** As a user, I want to log my daily steps so I can track my activity level.
- **Acceptance Criteria:**
  - [ ] Steps input form submits to `POST /api/steps`
  - [ ] Success confirmation shown
  - [ ] Steps visible in dashboard summary and trends
- **Technical Notes:** Backend endpoint exists; only the mobile submit action is missing

### 6.5 Wire Logging Screen FAB
- **Priority:** P1
- **User Story:** As a user, I want the "+" button on the logging screen to open the log entry flow so I can quickly record health data.
- **Acceptance Criteria:**
  - [ ] FAB tap navigates to a quick-log selector (workout/food/steps/metrics)
  - [ ] Selected type opens corresponding Add screen
- **Technical Notes:** `logging_screen.dart` — FAB `onPressed` is currently empty

### 6.6 Fix Profile Settings — Health Goals Tab
- **Priority:** P1
- **User Story:** As a user, I want to set and view my health goals so I can track my progress against them.
- **Acceptance Criteria:**
  - [ ] 5th tab ("Health Goals") added to ProfileSettings screen
  - [ ] Displays goals from `GET /api/health-goals`
  - [ ] Allows creating and editing goals
  - [ ] Navigation mismatch (5 titles / 4 screens) resolved
- **Technical Notes:** Backend already has full HealthGoal CRUD

### 6.7 AI Insights Error & Loading States
- **Priority:** P1
- **User Story:** As a user, I want to understand what's happening when AI insights are loading or unavailable, so I'm not confused by a blank screen.
- **Acceptance Criteria:**
  - [ ] Loading skeleton shown while AI insights are fetching
  - [ ] Meaningful error message shown if AI service is unreachable
  - [ ] "Retry" button on error state
  - [ ] Chat logging: parse failure shows inline error message (not silent)
- **Technical Notes:** `ai_insights_screen.dart` and chat feature

### 6.8 Package Name Rebranding
- **Priority:** P1
- **User Story:** As a product owner, I want the app to be published under `com.healthcoach` so it can be submitted to the Play Store.
- **Acceptance Criteria:**
  - [ ] AndroidManifest.xml: package changed from `com.example.*` to `com.healthcoach.*`
  - [ ] All relevant Android build files updated
  - [ ] App ID consistent across all environments
- **Technical Notes:** Already partially done per git log; verify completeness

### 6.9 User Onboarding Flow
- **Priority:** P2
- **User Story:** As a new user, I want a brief guided introduction to the app so I know what to do first.
- **Acceptance Criteria:**
  - [ ] 3-step onboarding shown on first launch only
  - [ ] Explains: log your data / get AI insights / track trends
  - [ ] "Skip" option available
  - [ ] Onboarding completion stored persistently
- **Technical Notes:** New screens; use `appConfigStorage` to track completion

### 6.10 Delete & Update Log Entries
- **Priority:** P2
- **User Story:** As a user, I want to correct or remove log entries I entered incorrectly.
- **Acceptance Criteria:**
  - [ ] DELETE endpoint added for WorkoutLog, FoodLog, StepsLog, BodyMetrics
  - [ ] PUT/PATCH endpoint for editing log entries
  - [ ] Mobile: swipe-to-delete or edit action on log list items
- **Technical Notes:** Backend currently only has POST + GET for most log types

### 6.11 Data Pagination
- **Priority:** P2
- **User Story:** As a user who has been logging for months, I want the app to load quickly even with large amounts of history.
- **Acceptance Criteria:**
  - [ ] All list endpoints support `?page=&size=` query parameters
  - [ ] Mobile implements infinite scroll or "Load More" on history screens
- **Technical Notes:** Backend has no pagination currently; affects WorkoutLog, FoodLog, StepsLog, BodyMetrics

### 6.12 "View Full Details" on Analysis Cards
- **Priority:** P2
- **User Story:** As a user, I want to tap on an AI insight card to see its full explanation.
- **Acceptance Criteria:**
  - [ ] `analysis_card.dart` "View Full Details" button navigates to a detail view
  - [ ] Detail view shows full AI recommendation text
- **Technical Notes:** Currently a no-op; needs a detail screen or bottom sheet

### 6.13 Database Backups
- **Priority:** P2
- **User Story:** As a user, I trust that my health history will not be lost.
- **Acceptance Criteria:**
  - [ ] Automated daily PostgreSQL backups configured
  - [ ] Backups stored in GCP Cloud Storage
  - [ ] Backup restore procedure documented and tested
- **Technical Notes:** GCP-side infrastructure task

### 6.14 Monitoring & Alerting
- **Priority:** P2
- **User Story:** As an operator, I want to know when the system is down before users report it.
- **Acceptance Criteria:**
  - [ ] Uptime monitoring configured (GCP Cloud Monitoring or UptimeRobot)
  - [ ] Alert sent when any service is down for > 2 minutes
  - [ ] Basic log aggregation in place
- **Technical Notes:** GCP-side infrastructure task

### 6.15 RAG Knowledge Base for AI
- **Priority:** P3
- **User Story:** As a user, I want the AI to give me advice grounded in established health research, not just my personal data patterns.
- **Acceptance Criteria:**
  - [ ] `_retrieve_knowledge()` connected to a real vector store (e.g., Vertex AI Matching Engine or FAISS)
  - [ ] Health guideline documents ingested into the knowledge base
  - [ ] AI responses cite knowledge base sources
- **Technical Notes:** Significant AI service work; currently fully stubbed

### 6.16 Password Change & Account Management
- **Priority:** P3
- **User Story:** As a user, I want to change my password and manage my account settings.
- **Acceptance Criteria:**
  - [ ] `PUT /api/auth/password` endpoint implemented
  - [ ] Mobile profile screen: "Change Password" option
  - [ ] Account deletion with data wipe option (GDPR consideration)
- **Technical Notes:** Backend currently has no password change endpoint

### 6.17 Data Export
- **Priority:** P3
- **User Story:** As a user, I want to export all my health data so I can share it with my doctor or switch apps.
- **Acceptance Criteria:**
  - [ ] `GET /api/users/me/export` endpoint returns full data export (JSON or CSV)
  - [ ] Mobile: "Export my data" option in profile settings
- **Technical Notes:** No export capability currently exists

---

## 7. Non-Functional Requirements

### 7.1 Security (from security-engineer)

| Requirement | Priority | Current State |
|-------------|----------|---------------|
| Disable cleartext traffic | P1 — CRITICAL | ❌ Enabled in AndroidManifest |
| HTTPS for all API traffic | P1 | ❌ Not yet configured on server |
| JWT secret in secrets manager | P1 | ❌ Likely in env file |
| Rate limiting on all sensitive endpoints | P1 | ⚠️ Only auth + medical covered |
| flutter_secure_storage for tokens | P1 | ✅ Already implemented |
| JWT HS256 with 24h expiry | P1 | ✅ Already implemented |
| `android:debuggable` false in release | P1 | ✅ Confirmed off |
| `android:allowBackup` false | Recommended | ✅ Confirmed off |
| Input validation on all API endpoints | P2 | ⚠️ Partial |
| GDPR data deletion capability | P3 | ❌ Not implemented |

### 7.2 Performance

| Requirement | Target |
|-------------|--------|
| API response time (p95) | < 500ms for data queries |
| AI insight generation | < 10 seconds (acceptable for async) |
| App cold start | < 3 seconds on mid-range Android |
| Medical report upload | < 30 seconds including AI parsing |

### 7.3 Accessibility (from ui-designer)

- All interactive elements must have semantic labels for screen readers
- Minimum touch target size: 48×48dp (per Material Design 3)
- Colour contrast ratio ≥ 4.5:1 for all text
- Loading and error states required on all data-fetching screens (currently missing on 8+ screens)
- Form validation messages must be descriptive (not just "Error")

### 7.4 Reliability & Uptime

- Target uptime: 99.5% (post-v1.0 production deployment)
- Automated DB backups: daily, retained for 30 days
- Service auto-restart on failure (Docker restart policy)
- Health check endpoints must return correct status codes

---

## 8. UX Requirements (from ui-designer)

### 8.1 Screen Completeness Target for v1.0

| Screen | Current State | v1.0 Target |
|--------|--------------|-------------|
| Login | ✅ Complete | Maintain |
| Register | ✅ Complete | Maintain |
| Dashboard | ✅ Complete | Add empty state |
| Add Workout | ✅ Complete | Maintain |
| Add Food | ✅ Complete | Maintain |
| Add Body Metrics | ✅ Complete | Maintain |
| Upload Medical Report | ✅ Complete | Maintain |
| Dashboard Shell | ✅ Complete | Maintain |
| Add Steps | ❌ Placeholder | Wire submit action (6.4) |
| View Trends | ⚠️ Partial | Replace hardcoded data with live API |
| AI Insights | ⚠️ Partial | Add loading/error states (6.7) |
| Medical Hub | ⚠️ Partial | Complete navigation (6.6 related) |
| Chat / AI Logging | ⚠️ Partial | Fix silent parse failure (6.7) |
| Profile Settings | ⚠️ Partial | Add Health Goals tab (6.6) |
| Logging Screen | ⚠️ Partial | Wire FAB (6.5) |

### 8.2 Design Standards

- Adhere to Material Design 3 throughout (currently compliant at theme level)
- Use app `ThemeData` consistently — no hardcoded colours in widgets
- `AppTheme.primaryColor`, `AppTheme.backgroundColor`, `AppTheme.cardColor` used universally
- `AppTheme.headingStyle` and `AppTheme.bodyStyle` used for typography

### 8.3 Key UX Flows for v1.0

1. **New User Onboarding** (see 6.9): First launch → guided intro → dashboard
2. **Daily Health Logging**: Dashboard → "+" FAB → select type → log entry → confirmation → back to dashboard
3. **AI Insights Request**: Dashboard → AI Insights tab → loading state → insights display → tap card → full detail
4. **Medical Report Upload**: Medical Hub → Upload Report → camera/file picker → upload → AI parsing → parsed results display
5. **Trend Review**: Dashboard → Trends tab → select metric → chart with real data

### 8.4 Empty States

Every data-listing screen must have a designed empty state (illustration + prompt text + CTA button) for when no data has been logged yet.

---

## 9. Infrastructure & Deployment (from devops-engineer)

### 9.1 Environments

| Environment | Backend | AI Service | Database | State |
|-------------|---------|-----------|----------|-------|
| Local | localhost:8080 | localhost:8000 | PostgreSQL (Docker) | ✅ Functional |
| Dev (GCP) | GCP VM HTTP | GCP VM HTTP | PostgreSQL (Docker on VM) | ⚠️ HTTP only |
| UAT | Not yet configured | Not yet configured | — | ❌ Missing |
| Production | GCP VM (planned HTTPS) | GCP VM (planned HTTPS) | PostgreSQL (VM) | ❌ Not production-ready |

### 9.2 Deployment Model

- **Platform:** GCP Compute Engine (single VM, e2-medium)
- **Orchestration:** Docker Compose (backend + AI service + PostgreSQL + nginx)
- **Deploy script:** `deploy_to_gcp.sh` / `deploy_to_gcp_complete.sh`
- **Mobile:** Flutter APK, signed with release keystore, distributed via Play Store (planned)

### 9.3 Production Readiness Checklist (v1.0 blockers)

- [ ] HTTPS configured with valid SSL certificate (nginx + Let's Encrypt)
- [ ] Secrets moved out of env files into GCP Secret Manager
- [ ] PostgreSQL backup strategy implemented (daily, Cloud Storage)
- [ ] `android:usesCleartextTraffic` disabled (requires HTTPS first)
- [ ] Package name fully rebranded to `com.healthcoach` across all build files
- [ ] Monitoring + alerting configured
- [ ] VM auto-start on reboot tested
- [ ] Production docker-compose file finalised and validated
- [ ] All `TODO` markers in deploy scripts resolved

### 9.4 Pending Infrastructure Tasks (from PROJECT_TODO.md)

Top 10 of 22 pending items:
1. Configure HTTPS with SSL certificate
2. Set up GCP Secret Manager for all secrets
3. Configure automated PostgreSQL backups
4. Set up monitoring and alerting
5. Create UAT environment
6. Finalise production Docker Compose configuration
7. Set up CI/CD pipeline (GitHub Actions)
8. Configure CDN for static assets
9. Implement database migration strategy (Flyway/Liquibase)
10. Load testing and performance benchmarking before launch

---

## 10. Out of Scope

The following are explicitly excluded from v1.0:

- **Wearable device integrations** (Apple Watch, Fitbit, Garmin) — future roadmap
- **Healthcare provider portal** — for medical professionals to view patient data
- **iOS App Store release** — Android Play Store is the v1.0 target; iOS is v2.0
- **Web application** — mobile-only for v1.0
- **Social / community features** — no friend networks, sharing, or leaderboards
- **Third-party health app sync** (Apple Health, Google Fit) — future roadmap
- **Payment / subscription system** — v1.0 is free / personal use
- **RAG knowledge base** — AI responses use Gemini without grounding in v1.0 (P3)
- **Multi-language / localisation** — English only for v1.0
- **Offline mode** — requires connectivity for all AI and data features

---

## 11. Release Plan

| Milestone | Features | Success Criteria |
|-----------|---------|-----------------|
| **v0.9 — Security & Infrastructure** | 6.1, 6.2, 6.3, 6.8 (HTTPS + secrets + cleartext fix + rebranding) | App runs on HTTPS, zero critical security findings |
| **v1.0 — Production Ready** | 6.4, 6.5, 6.6, 6.7 (all screen completions + error states) | All 15 screens functional, signed APK published to Play Store internal track |
| **v1.1 — Polish & Data Integrity** | 6.9, 6.10, 6.11, 6.12, 6.13, 6.14 (onboarding + CRUD + pagination + backups + monitoring) | User onboarding flow live, full log CRUD, automated backups running |
| **v1.2 — Intelligence Upgrade** | 6.15, 6.16, 6.17 (RAG + account management + data export) | AI responses grounded in health knowledge base, full account self-service |

---

## 12. Open Questions

1. **JWT Secret Rotation** — What is the plan for rotating the JWT secret without invalidating all active user sessions?
2. **GCP Project Structure** — Is there a single GCP project for all environments, or separate projects for dev/prod? (Affects IAM and billing)
3. **Play Store Developer Account** — Is a Google Play developer account set up under the `com.healthcoach` identity?
4. **Gemini API Billing** — What is the expected monthly cost at scale, and is there a budget cap or quota configured?
5. **Data Retention Policy** — How long should user health data be retained after account deletion? (GDPR requirement)
6. **Beta Testing Strategy** — Before broad public release, is there a closed beta or limited pilot planned?
7. **Medical Disclaimer** — The AI provides health insights; what legal disclaimer language is required to avoid medical advice liability?
8. **RAG Knowledge Base Source** — When the RAG feature (6.15) is implemented, what is the authoritative source for health guidelines (WHO, NHS, AHA)?

---

## 13. Appendix

### A. Current Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart), Riverpod state management |
| Backend | Java 17 + Spring Boot 3 + Spring Security |
| AI Service | Python 3.x + FastAPI + Google Gemini (gemini-1.5-pro / gemini-2.0-flash) |
| Database | PostgreSQL (via Docker) |
| Auth | JWT HS256 + Google OAuth 2.0 |
| Storage | GCP Cloud Storage (medical report images) |
| Infrastructure | GCP Compute Engine (Docker Compose) |
| Token Storage (mobile) | flutter_secure_storage |
| Rate Limiting | Bucket4j (Spring Boot) |

### B. API Endpoint Reference (from java-expert)

```
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/google-login
GET    /api/auth/me

POST   /api/workouts
GET    /api/workouts
GET    /api/workouts?type={type}

POST   /api/food
GET    /api/food
GET    /api/food?date={date}

POST   /api/body-metrics
GET    /api/body-metrics
GET    /api/body-metrics/latest

POST   /api/steps
GET    /api/steps
GET    /api/steps?date={date}

POST   /api/medical-reports          (multipart upload)
GET    /api/medical-reports
GET    /api/medical-reports/{id}
DELETE /api/medical-reports/{id}

GET    /api/health-summary/me
GET    /api/health-summary/me/ai-insights

POST   /api/lab-values/extract
GET    /api/lab-values?reportId={id}

POST   /api/health-goals
GET    /api/health-goals
PUT    /api/health-goals/{id}

GET    /api/users/me
PUT    /api/users/me

POST   /api/ai/metrics/extract
```

### C. AI Capabilities Reference (from python-expert)

```
POST /analyze-health
  Input:  HealthAnalysisRequest { workouts[], foodLogs[], bodyMetrics[], steps[], goals[] }
  Output: HealthRecommendationResponse { recommendations[], insights[], actionItems[] }
  Model:  gemini-1.5-pro

POST /parse-medical-report
  Input:  MedicalReportRequest { reportText, reportType }
  Output: ParsedMedicalReport { diagnoses[], medications[], testResults[], recommendations[] }
  Model:  gemini-1.5-pro

POST /extract-metrics
  Input:  ExtractMetricsRequest { text }
  Output: ExtractMetricsResponse { metrics{} }
  Model:  gemini-2.0-flash

GET /health
  Output: { status: "healthy", service: "ai-service" }
```

### D. Known Technical Debt

| Item | Area | Severity |
|------|------|----------|
| Cleartext traffic enabled | Security/Android | Critical |
| RAG `_retrieve_knowledge()` is hardcoded stub | AI Service | High |
| No pagination on list endpoints | Backend | High |
| Biomarker trend data hardcoded in Flutter | Mobile | High |
| No DELETE/UPDATE on most log entities | Backend | Medium |
| Broad `except Exception` clauses in AI service | AI Service | Medium |
| No timeout configuration on Gemini calls | AI Service | Medium |
| AI Insights screen missing loading/error states | Mobile/UX | Medium |
| Profile Settings navigation mismatch (5 titles / 4 screens) | Mobile/UX | Medium |
| No CI/CD pipeline | DevOps | Medium |
| No automated DB backup | DevOps | High |

---

*PRD generated by PM Agent using parallel domain expert review (java-expert, python-expert, flutter-expert, devops-engineer, ui-designer, security-engineer). Re-run `/prd` at each milestone to update.*
