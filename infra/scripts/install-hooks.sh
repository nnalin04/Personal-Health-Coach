#!/usr/bin/env bash
# Install git hooks for Personal Health Coach.
# Run once after cloning: bash scripts/install-hooks.sh
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$ROOT/.git/hooks"

cp "$ROOT/scripts/pre-commit-hook.sh" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "✓ pre-commit hook installed at $HOOKS_DIR/pre-commit"
echo "  Runs backend + AI service + Flutter unit tests before every commit."
echo "  Skip with: git commit --no-verify"
