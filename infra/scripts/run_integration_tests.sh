#!/usr/bin/env bash
# ============================================================
# Personal Health Coach — Integration Test Runner
# Usage:
#   bash scripts/run_integration_tests.sh             # local Docker
#   bash scripts/run_integration_tests.sh prod        # production
#   bash scripts/run_integration_tests.sh both        # local + prod
#
# Environment overrides:
#   LOCAL_API_URL   default: http://localhost:8080/api
#   LOCAL_AI_URL    default: http://localhost:8000
#   PROD_API_URL    default: https://healthcoach.duckdns.org/api
#
# What this tests (real running services, no mocks):
#   1. Complete user journey (register → log all → AI insights → export)
#   2. Nutrient intelligence cross-service flow
#   3. Medical report pipeline (PDF → AI extraction → DB → summary)
#   4. Auth & JWT security (tampered tokens, 401s, duplicate reg)
#   5. Cross-user data isolation (User A data invisible to User B)
#   6. Negative edge cases (bad inputs, concurrent requests, no 500s)
#
# Generates: test-reports/integration/report.html
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-local}"
REPORT_DIR="$ROOT/test-reports/integration"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"
BLUE="\033[1;34m"; RESET="\033[0m"; BOLD="\033[1m"

echo -e "\n${BOLD}Personal Health Coach — Integration Tests${RESET}"
echo -e "Target: ${YELLOW}${TARGET}${RESET}\n"

# ── Validate target ────────────────────────────────────────────────────────────
if [[ ! "$TARGET" =~ ^(local|prod|both)$ ]]; then
    echo -e "${RED}Invalid target '$TARGET'. Use: local | prod | both${RESET}"
    exit 1
fi

# ── Install test dependencies ──────────────────────────────────────────────────
echo -e "${BLUE}Installing test dependencies...${RESET}"
python3 -m pip install -q \
    requests==2.32.3 \
    pytest==8.3.3 \
    pytest-timeout==2.3.1 \
    pytest-html==4.1.1 \
    pytest-xdist==3.6.1

# ── For local target: verify services are reachable ────────────────────────────
LOCAL_API="${LOCAL_API_URL:-http://localhost:8080/api}"
PROD_API="${PROD_API_URL:-https://healthcoach.duckdns.org/api}"

check_service() {
    local label="$1"
    local url="$2"
    local health_url="$3"
    echo -ne "  Checking $label... "
    if curl -sf "$health_url" >/dev/null 2>&1; then
        echo -e "${GREEN}UP${RESET}"
        return 0
    else
        echo -e "${RED}UNREACHABLE${RESET}"
        return 1
    fi
}

if [[ "$TARGET" == "local" || "$TARGET" == "both" ]]; then
    echo -e "\n${BLUE}=== Checking local services ===${RESET}"
    if ! check_service "Backend" "$LOCAL_API" "${LOCAL_API_URL:-http://localhost:8080}/actuator/health"; then
        echo -e "${RED}Backend not reachable at $LOCAL_API${RESET}"
        echo -e "Start services: ${YELLOW}docker compose --env-file env.dev up -d --wait${RESET}"
        if [[ "$TARGET" == "local" ]]; then exit 1; fi
    fi
fi

if [[ "$TARGET" == "prod" || "$TARGET" == "both" ]]; then
    echo -e "\n${BLUE}=== Checking production services ===${RESET}"
    if ! check_service "Prod Backend" "$PROD_API" "${PROD_API_URL:-https://healthcoach.duckdns.org}/actuator/health"; then
        echo -e "${YELLOW}Production may be slow to respond — proceeding anyway${RESET}"
    fi
fi

# ── Create report directory ────────────────────────────────────────────────────
mkdir -p "$REPORT_DIR"

# ── Run integration tests ──────────────────────────────────────────────────────
echo -e "\n${BLUE}=== Running Integration Tests (target: $TARGET) ===${RESET}"

REPORT_FILE="$REPORT_DIR/report_${TIMESTAMP}_${TARGET}.html"
JUNIT_FILE="$REPORT_DIR/junit_${TIMESTAMP}_${TARGET}.xml"

set +e
INTEGRATION_TARGET="$TARGET" \
LOCAL_API_URL="${LOCAL_API_URL:-http://localhost:8080/api}" \
LOCAL_AI_URL="${LOCAL_AI_URL:-http://localhost:8000}" \
PROD_API_URL="${PROD_API_URL:-https://healthcoach.duckdns.org/api}" \
python3 -m pytest \
    "$ROOT/tests/integration/" \
    -v \
    --tb=short \
    --timeout=120 \
    -p no:randomly \
    --html="$REPORT_FILE" \
    --self-contained-html \
    --junitxml="$JUNIT_FILE" \
    -m integration \
    2>&1
EXIT_CODE=$?
set -e

# ── Report summary ─────────────────────────────────────────────────────────────
echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  HTML Report: ${BLUE}$REPORT_FILE${RESET}"
echo -e "  JUnit XML:   ${BLUE}$JUNIT_FILE${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "\n  ${GREEN}${BOLD}✓  ALL INTEGRATION TESTS PASSED${RESET}"
    echo -e "  ${GREEN}Open report: open \"$REPORT_FILE\"${RESET}\n"
else
    echo -e "\n  ${RED}${BOLD}✗  INTEGRATION TESTS FAILED${RESET}"
    echo -e "  ${YELLOW}Check report for details: open \"$REPORT_FILE\"${RESET}\n"
fi

exit $EXIT_CODE
