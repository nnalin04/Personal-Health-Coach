# Personal AI Health Intelligence System — Claude Context

## Project Overview
A private, cross-platform health monitoring system with AI-driven insights. Users track workouts, nutrition, body metrics, steps, and medical lab reports. Google Gemini AI analyzes the data to produce health summaries and personalized recommendations.

## Architecture

```
.
├── backend/         # Java 17 + Spring Boot 3.x (REST API, JWT auth, PostgreSQL)
├── ai-service/      # Python 3.11 + FastAPI (Gemini AI, PDF/image parsing)
├── mobile/          # Flutter (Riverpod state management, Dio HTTP client)
├── docker-compose.yml               # Local dev orchestration
├── docker-compose.dev/uat/prod.yml  # Environment-specific compose files
└── deploy_to_gcp_*.sh               # GCP Compute Engine deploy scripts
```

## Key Packages / Modules

### Backend (`backend/src/main/java/com/healthcoach/`)
- `auth/` — JWT + Google OAuth 2.0 authentication
- `workout/` — Exercise logging (sets, reps, volume)
- `food/` — Meal logging (calories, macros)
- `bodymetrics/` — Weight, BMI, body fat, muscle mass
- `steps/` — Daily step tracking
- `medical/` — Medical report upload & lab value extraction
- `healthsummary/` — Aggregated health summaries (7/30/90-day windows)
- `aiclient/` — HTTP client to call the AI service
- `goals/` — User health goals
- `security/` — Spring Security config, JWT filter
- `config/` — App configuration beans

### AI Service (`ai-service/app/`)
- `routers/` — FastAPI route handlers (health, insights, medical parsing)
- `services/` — Business logic (Gemini calls, metric extraction)
- `schemas/` — Pydantic request/response models
- `ai/` — Gemini AI integration
- `utils/` — PDF/image helpers

### Mobile (`mobile/lib/`)
- `core/` — Constants, theme, shared utilities
- `features/` — Screen-level feature modules (auth, dashboard, food, workout, steps, body_metrics, medical, insights, trends, profile, chat, logging)

## Tech Stack
- **Backend**: Java 17, Spring Boot 3, Spring Security, JPA/Hibernate, PostgreSQL 16
- **AI Service**: Python 3.11, FastAPI, Google Gemini 1.5 Flash (`google-generativeai`)
- **Mobile**: Flutter, Riverpod, Dio, `google_sign_in`
- **Infrastructure**: Docker Compose, GCP Compute Engine

## Dev Conventions

### Backend
- REST endpoints follow `/api/<resource>` pattern
- DTOs live in `dto/` packages; entities in their feature package
- Services are `@Service` beans; repos extend `JpaRepository`
- Tests: JUnit 5 + Mockito under `src/test/`

### AI Service
- Pydantic schemas for all request/response models
- Gemini calls go through `ai/` module; keep service layer thin
- Run locally: `uvicorn app.main:app --reload --port 8000`

### Mobile
- One feature = one folder under `lib/features/`
- State: Riverpod providers; HTTP: Dio with auth interceptor
- Backend URL is runtime-configurable via Profile Settings → Connection

## Environment
- Local: `docker-compose up --build -d` → backend :8080, AI service :8000
- Env vars template: `env.dev` (copy and fill `JWT_SECRET`, `POSTGRES_PASSWORD`, `GEMINI_API_KEY`, `GOOGLE_CLIENT_ID`)
- Android emulator default URL: `http://10.0.2.2:8080/api`

## Testing
- Backend: `cd backend && mvn test`
- AI Service: `cd ai-service && python3 -m pytest`
- Mobile: `cd mobile && flutter test`
- E2E: `python3 e2e_verify.py`

## Custom Commands
See `.claude/commands/` for available slash commands:
- `/health-check` — Verify all services are healthy
- `/run-tests` — Run tests across all layers
- `/deploy` — Guided deployment to GCP environments
- `/review` — Review changed code for quality and correctness

## Self-Improvement Protocol (applies to ALL agents and skills)

Every agent and every skill follows these rules on every execution. No exceptions.

### Rule 1 — Self-Reflection Output
Every agent ends its output with a `## Learnings` block:
```
## Learnings
- **Gap:** [something missing from my instructions that I had to improvise]
- **Improvement:** [what should be added/changed in my agent file]
- **Pattern:** [something that appears to be a recurring issue]
- **Split:** [section that felt too heavy and should become its own sub-skill]
```
If there are no learnings, write `## Learnings — nothing to report this run.`
The PM collects all `## Learnings` blocks and writes them to `.claude/memory/learnings.md`.

### Rule 2 — Context Minimization
Skills must load only what is needed for the current task:
- Check `$ARGUMENTS` first. Load only the relevant sub-skill or file path.
- A skill that branches into 3+ distinct modes is a **router** and must be split.
- A router should be ≤ 50 lines. The actual work lives in sub-skills it delegates to.
- Never read files that are not needed for the specific task at hand.

### Rule 3 — Size Thresholds (auto-flag for splitting)
- **Skill SKILL.md > 200 lines** → flag as split candidate in `## Learnings`
- **Agent .md > 150 lines** → flag as split candidate in `## Learnings`
- The `/split-skill` skill handles splitting; `/improve` handles targeted rewrites.

### Rule 4 — Continuous Improvement Cycle
```
Execute task → append ## Learnings → PM stores to .claude/memory/learnings.md
     ↑                                                         ↓
  (improved)   ←  /retrospective updates agent/skill files  ←  (accumulated)
```
Run `/retrospective` periodically (after 5+ tasks) or whenever the system feels slow or imprecise.
Run `/improve [name]` for a targeted rewrite of a specific agent or skill.
Run `/split-skill [name]` when a skill exceeds the size threshold.

### Rule 5 — System Inventory
Skills and agents are listed in `.claude/memory/README.md`. After any `/build-agent`, `/split-skill`, or `/improve`, that file is updated to reflect the current state of the system.

## Orchestration Model

**All work flows through the Project Manager.** Use `/pm [describe what you need]` as the single entry point for any task. The PM creates an execution plan, routes to specialists, and synthesises results. If a new role is missing, PM uses `/build-agent` to create it automatically.

```
/pm "fix the workout API bug"
  └─ project-manager → java-expert (fix) → qa-tester (verify) → report

/e2e-test
  ├─ devops-engineer  (if services down → deploy first)
  ├─ Android emulator (start if needed)
  ├─ qa-tester        (run tests, document bugs)
  └─ project-manager  (route bugs to right engineers)
```

## Skills
All skills are in `.claude/skills/`. Invoke with `/skill-name [optional args]`.

### Central Entry Point
- `/pm [task]` — **Start here for any work.** PM orchestrates all agents needed.

### System Growth
- `/build-agent [role]` — Create a new agent + 2 skills for a missing role. PM calls this automatically when needed.

### Git & Code Quality
- `/commit-push [msg]` — Stage tracked files, draft/use commit message, commit and push
- `/code-review [ref]` — Multi-expert parallel review (java + python + flutter agents)

### Project Management
- `/project-status` — Full health dashboard: TODO progress, git velocity, risks, next actions
- `/standup` — Daily standup: yesterday (git log), today (recommended tasks), blockers
- `/task-board [add|done|pending]` — View/update `PROJECT_TODO.md` interactively
- `/release-notes [ref range]` — Auto-generate categorised release notes from git history

### QA & Testing
- `/e2e-test [flow]` — **Full E2E on Android emulator.** Checks services (DevOps deploys if down), starts emulator, runs API + integration tests, routes bugs through PM.
- `/qa-report` — Run all unit test suites, get GO/NO-GO from qa-tester
- `/bug-report [title]` — Guided bug documentation with code search and severity triage
- `/test-coverage` — Coverage matrix, gap analysis, top 5 tests to write next

### UI & Design
- `/ui-review [screen or feature]` — Material Design 3 + accessibility audit via ui-designer. Routes code fixes to flutter-expert via PM.

### Security
- `/security-audit [full|backend|mobile|ai-service|auth|deps]` — OWASP audit via security-engineer. Routes all fixes through PM.

### DevOps & Infrastructure
- `/deploy-check [dev|uat|prod]` — Pre-deploy checklist + env audit. GO/NO-GO before running deploy script.
- `/service-logs [service] [--lines N]` — Container logs + devops-engineer crash diagnosis
- `/env-audit [dev|uat|prod|all]` — Audit env files for missing/placeholder secrets
- `/rollback [dev|uat|prod]` — Root-cause assessment + guided rollback. Always confirms before acting.

## Agents (`.claude/agents/`)
Each agent has deep project-specific knowledge. All findings route to `project-manager`.

### Orchestration
- `project-manager` — Central coordinator. Routes ALL work. Builds new agents via `/build-agent` when a role is missing.

### Code Experts
- `java-expert` — Spring Boot, Spring Security, JPA, JWT, REST API design
- `python-expert` — FastAPI, Pydantic, Gemini AI, async Python
- `flutter-expert` — Flutter, Dart, Riverpod, Dio, mobile UI

### Quality & Design
- `qa-tester` — Full E2E incl. Android emulator. Requests deployments from devops if services are down. Routes bugs via PM.
- `ui-designer` — Material Design 3, accessibility (WCAG), UX flows, design consistency

### Infrastructure & Security
- `devops-engineer` — Docker, GCP, env validation, deployment, incident response
- `security-engineer` — OWASP Mobile Top 10, API Security Top 10, JWT, data privacy, CVE scanning
