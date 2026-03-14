#!/usr/bin/env bash
# healthcheck.sh — verify both services are live
# Usage: bash scripts/healthcheck.sh [BASE_URL]
# Default BASE_URL: https://healthcoach.duckdns.org

set -euo pipefail

BASE_URL="${1:-https://healthcoach.duckdns.org}"
AI_URL="http://localhost:8000"   # AI service is internal-only; check from VM

PASS=0
FAIL=0

check() {
    local name="$1"
    local url="$2"
    local expected="${3:-200}"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
    if [[ "$http_code" == "$expected" ]]; then
        echo "  [OK]   $name — HTTP $http_code"
        ((PASS++))
    else
        echo "  [FAIL] $name — HTTP $http_code (expected $expected)"
        ((FAIL++))
    fi
}

echo "=== Health Check: $BASE_URL ==="
echo ""

# ── Backend (Spring Boot) ─────────────────────────────────────────────────────
echo "Backend (/actuator/health):"
check "Backend actuator"  "$BASE_URL/actuator/health"        200
check "Backend /api"      "$BASE_URL/api/auth/google/token"  400  # 400 = endpoint exists, bad request without body

# ── AI Service (internal only — run this script on the VM) ───────────────────
echo ""
echo "AI Service (internal):"
check "AI /health"        "$AI_URL/health"                   200
check "AI /docs"          "$AI_URL/docs"                     200

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
