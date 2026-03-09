#!/usr/bin/env bash
# ============================================================
# Personal Health Coach — Local Dev Test Runner
# Usage: bash scripts/run_dev_tests.sh
#
# Runs all 4 test layers against local Docker services:
#   1. Backend unit tests   (JUnit5 + Mockito — no Docker)
#   2. AI service tests     (pytest + TestClient — no Docker)
#   3. Backend E2E API tests (pytest + requests — needs Docker)
#   4. Flutter unit tests   (flutter_test — no Docker)
#
# Environment:
#   API_BASE_URL   override backend URL (default: http://localhost:8080/api)
#   AI_SERVICE_URL override AI service URL (default: http://localhost:8000)
#   SKIP_BUILD     set to 1 to skip docker compose build (faster if code unchanged)
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ── Java 17+ (required for Spring Boot 3) ─────────────────
# Use macOS java_home if JAVA_HOME is unset or points to < 17
_java_home_min17=$(/usr/libexec/java_home -v 17+ 2>/dev/null || true)
if [[ -n "$_java_home_min17" ]]; then
    export JAVA_HOME="$_java_home_min17"
fi

# Colour helpers
GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"
BLUE="\033[1;34m"; RESET="\033[0m"; BOLD="\033[1m"

PASS=0; FAIL=0
RESULTS=()

run_layer() {
    local label="$1"; shift
    echo -e "\n${BLUE}=== $label ===${RESET}"
    local output
    if output=$("$@" 2>&1); then
        echo "$output" | tail -5
        echo -e "  ${GREEN}✓ PASS${RESET}"
        ((PASS++))
        RESULTS+=("${GREEN}✓${RESET} $label")
    else
        echo "$output" | tail -20
        echo -e "  ${RED}✗ FAIL${RESET}"
        ((FAIL++))
        RESULTS+=("${RED}✗${RESET} $label")
    fi
}

# ── 1. Docker ──────────────────────────────────────────────
docker info >/dev/null 2>&1 || {
    echo -e "${RED}Docker is not running. Start Docker Desktop first.${RESET}"
    exit 1
}

# ── 2. Start local services ────────────────────────────────
echo -e "\n${YELLOW}Starting local Docker services...${RESET}"
ENV_FILE="env.dev"
[[ ! -f "$ENV_FILE" ]] && ENV_FILE=".env"
[[ ! -f "$ENV_FILE" ]] && {
    echo -e "${RED}No env file found (env.dev or .env). Copy env.dev and fill in secrets.${RESET}"
    exit 1
}

if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
    docker compose --env-file "$ENV_FILE" up -d --wait
else
    docker compose --env-file "$ENV_FILE" up -d --build --wait
fi
echo -e "${GREEN}All services healthy.${RESET}"

# ── 3. Backend unit tests ──────────────────────────────────
run_layer "Backend Unit Tests (JUnit5)" \
    bash -c "cd '$ROOT/backend' && mvn test -q 2>&1"

# ── 4. AI service offline tests ────────────────────────────
run_layer "AI Service Tests (pytest + TestClient)" \
    bash -c "cd '$ROOT/ai-service' && python3 -m pytest tests/ -v --tb=short 2>&1"

# ── 5. Backend E2E API tests ───────────────────────────────
python3 -m pip install -q -r "$ROOT/tests/requirements.txt" 2>/dev/null
run_layer "Backend E2E API Tests (all 33 endpoints)" \
    python3 -m pytest "$ROOT/tests/api/" -v --tb=short \
        --rootdir="$ROOT/tests" \
        -p no:randomly

# ── 6. Flutter unit tests ──────────────────────────────────
run_layer "Flutter Unit Tests" \
    bash -c "cd '$ROOT/mobile' && flutter test 2>&1"

# ── 7. Summary ─────────────────────────────────────────────
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
for r in "${RESULTS[@]}"; do echo -e "  $r"; done
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}$PASS passed  $FAIL failed${RESET}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "\n  ${GREEN}${BOLD}✓  GO — all layers green. Safe to commit and push.${RESET}"
    exit 0
else
    echo -e "\n  ${RED}${BOLD}✗  NO-GO — fix failures before pushing.${RESET}"
    exit 1
fi
