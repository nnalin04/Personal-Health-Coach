# API Versioning Plan

## Current State
All 33 endpoints use `/api/<resource>` with no version segment.
The live mobile app at `https://healthcoach.duckdns.org` is coupled to these paths.

## Why It Matters (vibe-coding risk)
When AI generates new features quickly, breaking API changes sneak in without a version bump.
Clients on the old mobile version get 404s or parse errors with no way to run the old and new
backend in parallel.

## Migration Strategy — One-Time, When Needed

### Step 1 — Add `/v1` prefix to Spring Boot (zero downtime)
In each controller, change `@RequestMapping("/api/resource")` → `@RequestMapping("/api/v1/resource")`.
Keep the old unversioned path alive as a deprecated alias for one release cycle:

```java
// Example — WorkoutController.java
@RestController
@RequestMapping({"/api/v1/workouts", "/api/workouts"})  // dual mapping during migration
public class WorkoutController { ... }
```

### Step 2 — Update mobile app
Change `app_constants.dart` base URL from `/api` → `/api/v1` and ship a new release.

### Step 3 — Remove deprecated aliases
After the new mobile version has > 90% adoption (Play Console → Android vitals),
remove the unversioned `/api/...` mappings.

## Rule for Future Breaking Changes
Before any change that alters request/response shape or removes a field:
1. Create `/api/v2/...` endpoint with the new contract
2. Keep `/api/v1/...` working until old clients are retired
3. Document the deprecation in `CHANGELOG.md`

## Non-Breaking Changes (no version bump needed)
- Adding new optional response fields
- Adding new endpoints
- Loosening validation constraints

## Do This Before v2.0
| Task | Owner |
|------|-------|
| Add `@RequestMapping` dual-path to all 11 controllers | Backend |
| Update `app_constants.dart` to `/api/v1` | Mobile |
| Update `e2e_prod_test.py` base path | QA |
| Ship mobile update, monitor Play Console crash-free rate | DevOps |
| Remove legacy `/api/...` mappings after 30 days | Backend |
