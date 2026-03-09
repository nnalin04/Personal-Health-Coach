#!/usr/bin/env bash
# ============================================================
# Personal Health Coach — Service Health Check
# Usage: bash scripts/healthcheck.sh [--backend-url URL] [--ai-url URL]
#
# Checks:
#   1. Backend Spring Boot actuator (/actuator/health)
#   2. AI FastAPI service (/health)
#
# Exit codes:
#   0 — all services healthy
#   1 — one or more services unhealthy
# ============================================================
set -euo pipefail

BACKEND_URL="${BACKEND_URL:-https://healthcoach.duckdns.org}"
AI_URL="${AI_URL:-http://localhost:8000}"   # AI service is internal; override for local checks

GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"; RESET="\033[0m"; BOLD="\033[1m"

PASS=0; FAIL=0

check() {
    local label="$1"
    local url="$2"
    local expected_field="${3:-status}"

    printf "  Checking %-35s ... " "$label"
    local response http_code body

    body=$(curl -sf --max-time 10 -w "\n%{http_code}" "$url" 2>/dev/null) || {
        echo -e "${RED}UNREACHABLE${RESET}"
        ((FAIL++))
        return
    }

    http_code=$(echo "$body" | tail -1)
    response=$(echo "$body" | head -n -1)

    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        local status
        status=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$expected_field','ok'))" 2>/dev/null || echo "ok")
        echo -e "${GREEN}✓ $http_code — $status${RESET}"
        ((PASS++))
    else
        echo -e "${RED}✗ HTTP $http_code${RESET}"
        ((FAIL++))
    fi
}

echo -e "\n${BOLD}Personal Health Coach — Service Health Check${RESET}"
echo -e "  Backend : $BACKEND_URL"
echo -e "  AI      : $AI_URL"
echo -e "${BOLD}──────────────────────────────────────────────${RESET}"

check "Backend actuator health"     "$BACKEND_URL/actuator/health"  "status"
check "AI service liveness"         "$AI_URL/health"                "status"

echo -e "${BOLD}──────────────────────────────────────────────${RESET}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}All $PASS services healthy.${RESET}\n"
    exit 0
else
    echo -e "  ${RED}${BOLD}$FAIL service(s) unhealthy. $PASS OK.${RESET}\n"
    exit 1
fi
