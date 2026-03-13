#!/usr/bin/env bash
# ============================================================
# Pre-commit hook — Personal Health Coach
#
# Runs fast unit tests before every commit to catch regressions.
# Install: bash scripts/install-hooks.sh
#
# Skip for emergency: git commit --no-verify
# ============================================================
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"; RESET="\033[0m"

echo -e "${YELLOW}[pre-commit] Running fast unit tests...${RESET}"

FAIL=0

# ── Backend unit tests (no Docker, ~10s) ──────────────────────────────────────
_java_home_min17=$(/usr/libexec/java_home -v 17+ 2>/dev/null || true)
[[ -n "$_java_home_min17" ]] && export JAVA_HOME="$_java_home_min17"

echo -n "  Backend unit tests... "
if cd "$ROOT/backend" && mvn test -q 2>/dev/null; then
    echo -e "${GREEN}PASS${RESET}"
else
    echo -e "${RED}FAIL${RESET}"
    FAIL=1
fi

# ── AI service tests (no Docker, ~5s) ─────────────────────────────────────────
echo -n "  AI service tests...   "
if cd "$ROOT/ai-service" && python3 -m pytest tests/ -q --no-header --no-cov 2>/dev/null; then
    echo -e "${GREEN}PASS${RESET}"
else
    echo -e "${RED}FAIL${RESET}"
    FAIL=1
fi

# ── Flutter unit tests (~5s) ──────────────────────────────────────────────────
# Ensure flutter is found (git hooks run with a minimal PATH)
FLUTTER_CMD="$(command -v flutter 2>/dev/null || echo /opt/homebrew/bin/flutter)"
echo -n "  Flutter unit tests... "
if cd "$ROOT/mobile" && "$FLUTTER_CMD" test 2>/dev/null; then
    echo -e "${GREEN}PASS${RESET}"
else
    echo -e "${RED}FAIL${RESET}"
    FAIL=1
fi

cd "$ROOT"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}[pre-commit] All checks passed.${RESET}"
    exit 0
else
    echo -e "${RED}[pre-commit] Tests failed. Fix before committing.${RESET}"
    echo -e "${YELLOW}To skip (emergency only): git commit --no-verify${RESET}"
    exit 1
fi
