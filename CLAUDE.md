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
- Local: `docker compose --env-file env.dev up -d --build --wait` → backend :8080, AI service :8000
- Env vars template: `env.dev` (copy and fill `JWT_SECRET`, `POSTGRES_PASSWORD`, `GEMINI_API_KEY`, `GOOGLE_CLIENT_ID`)
- Android emulator default URL: `http://10.0.2.2:8080/api`

## Dev Loop (local Docker — use this for all feature development)
```
1. Make code changes
2. docker compose --env-file env.dev up -d --build --wait
3. bash scripts/run_dev_tests.sh    ← GO/NO-GO across 4 layers (~60 tests)
4. Fix failures → repeat from step 2
5. When green: commit + push → UAT (run e2e_prod_test.py against GCP)
```
Override backend URL: `API_BASE_URL=http://localhost:8080/api bash scripts/run_dev_tests.sh`

## Testing
- **One command (local Docker):** `bash scripts/run_dev_tests.sh`
- Backend unit: `cd backend && mvn test`
- AI service offline: `cd ai-service && python3 -m pytest tests/ -v`
- E2E API (needs Docker): `cd tests && python3 -m pytest api/ -v`
- Mobile: `cd mobile && flutter test`
- E2E Prod (UAT/GCP): `python3 e2e_prod_test.py`

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

**All work flows through the PM.** Use `/pm [describe what you need]` as the single entry point. Claude acts as PM — no separate PM agent is spawned. The PM plans, delegates to the 4 specialist agents, and synthesises results. If a genuinely new role is needed, `/build-agent` creates it.

```
/pm "fix the workout API bug"
  └─ PM → reviewer (diagnose) → implement fix → qa-tester (verify) → report

/e2e-test
  ├─ devops-engineer  (if services down → deploy first)
  ├─ Android emulator (start if needed)
  ├─ qa-tester        (run tests, document bugs)
  └─ reviewer         (diagnose failing tests → implement fixes)
```

**Agent selection principle:** Agents are only used when there is a genuine conflict (reviewer vs builder, tester vs developer, adversarial security vs optimistic developer, cautious ops vs fast development). Domain knowledge alone is not a reason to spawn a separate agent.

## Skills
All skills are in `.claude/skills/`. Invoke with `/skill-name [optional args]`.

### Central Entry Point
- `/pm [task]` — **Start here for any work.** Claude acts as PM, routes to specialists.

### System Growth
- `/build-agent [role]` — Create a new agent only when the 4 existing agents cannot cover the role.

### Git & Code Quality
- `/commit-push [msg]` — Stage tracked files, draft/use commit message, commit and push
- `/code-review [ref]` — Spawn `reviewer` on changed files; auto-detects domains, one consolidated report

### Project Management
- `/project-status` — Full health dashboard: TODO progress, git velocity, risks, next actions
- `/standup` — Daily standup: yesterday (git log), today (recommended tasks), blockers
- `/task-board [add|done|pending]` — View/update `PROJECT_TODO.MD` interactively
- `/release-notes [ref range]` — Auto-generate categorised release notes from git history
- `/prd [focus area]` — Create Product Requirements Document using all 4 agents in parallel

### QA & Testing
- `/e2e-test [flow]` — **Full E2E on Android emulator.** Checks services (devops-engineer deploys if down), starts emulator, runs API + integration tests, routes bugs through reviewer.
- `/qa-report` — Run all unit test suites, get GO/NO-GO from qa-tester
- `/bug-report [title]` — Guided bug documentation with code search and severity triage
- `/test-coverage` — Coverage matrix, gap analysis, top 5 tests to write next

### UI & Design
- `/ui-review [screen or feature]` — Material Design 3 + accessibility audit via `reviewer` (UX/Mobile domains).

### Performance & Documentation
- `/performance-analysis [mobile|backend|ai-service|full]` — Bottleneck detection across Flutter/Riverpod, Spring Boot/JPA, FastAPI/Gemini. Produces ranked optimization report with quick-win table.
- `/api-docs [yaml|swagger-ui|both]` — Generate OpenAPI 3.0 spec (`docs/openapi.yaml`) by reading controllers + DTOs. Optionally adds springdoc live Swagger UI at `/swagger-ui.html` (disabled in prod).

### Agent Memory
- `/memory store <type> <tags> "<content>"` — Persist a typed insight/decision/pattern/error across sessions into `.claude/memory/agent-memory.json`. Types: `insight`, `decision`, `pattern`, `error`, `observation`.
- `/memory query [type] [tag]` — Retrieve non-expired entries filtered by type/tag. Agents should run this at task start.
- `/memory clean` — Remove entries past their 30-day TTL.
- `/memory export` — Print full memory store as JSON.

### Security
- `/security-audit [full|backend|mobile|ai-service|auth|deps]` — OWASP audit via security-engineer.

### DevOps & Infrastructure
- `/deploy-check [dev|uat|prod]` — Pre-deploy checklist + env audit. GO/NO-GO before running deploy script.
- `/service-logs [service] [--lines N]` — Container logs + devops-engineer crash diagnosis
- `/env-audit [dev|uat|prod|all]` — Audit env files for missing/placeholder secrets
- `/rollback [dev|uat|prod]` — Root-cause assessment + guided rollback. Always confirms before acting.

### Self-Improvement
- `/retrospective` — Process accumulated learnings, update agent/skill files system-wide
- `/improve [name]` — Targeted improvement of one agent or skill using its learnings
- `/split-skill [name]` — Split an oversized skill into router + focused sub-skills

## Hooks (`.claude/hooks/`)
Hooks run automatically before/after tool calls — no configuration needed beyond `settings.json`.

| Hook | File | Trigger | What it does |
|------|------|---------|--------------|
| PreToolUse | `pre-tool-use.sh` | Every `Bash` call | Adds `-i` to bare `rm`, expands `ll`/`la` aliases, warns on writes to system paths |

## Ruflo / claude-flow — Decision Record
Reviewed `github.com/ruvnet/ruflo`. Extracted all useful concepts natively. **MCP server not used** because:
- The npm-published package internals differ from the reviewed GitHub source (root `package.json` has only `semver`+`zod` as deps — no MCP SDK, unverifiable)
- `terminal/execute` tool in the tool registry allows arbitrary shell execution — unsafe even with whitelisting (process itself runs with full filesystem access)
- Supply-chain risk cannot be fully eliminated without a reproducible build

**What was extracted natively (zero runtime dependency):**
| Ruflo concept | Native replacement | Where |
|--------------|-------------------|-------|
| `memory/store` + `memory/query` | `/memory` skill + `agent-memory.json` | `.claude/skills/memory/` |
| Performance profiling | `/performance-analysis` skill | `.claude/skills/performance-analysis/` |
| API documentation | `/api-docs` skill | `.claude/skills/api-docs/` |
| PreToolUse hook patterns | `pre-tool-use.sh` | `.claude/hooks/` |
| Swarm agent coordination | Claude Code's native `Agent` tool | Already built-in (92% architectural match) |

## Agents (`.claude/agents/`)
Only 4 agents exist — each represents a genuine task conflict, not just domain expertise.

| Agent | Conflict | When to use |
|-------|----------|-------------|
| `reviewer` | Builder vs Reviewer — same context can't objectively review its own code | Code review, UX audit, architecture review, performance analysis, bug diagnosis |
| `qa-tester` | Developer vs Tester — can't objectively test what you just built | E2E testing, integration verification, GO/NO-GO verdicts |
| `security-engineer` | Developer vs Attacker — optimistic builder vs adversarial auditor | Security audits, OWASP checks, vulnerability scanning |
| `devops-engineer` | Implementation vs Operations — fast development vs cautious infra changes | GCP, Docker, deployment, incident response, env validation |
