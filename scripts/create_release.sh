#!/usr/bin/env bash
# ============================================================
# Personal Health Coach — Create a versioned release
#
# Usage: bash scripts/create_release.sh <version>
# Example: bash scripts/create_release.sh 1.2.0
#
# What it does:
#   1. Validates semver format
#   2. Shows commits since last tag (as release note preview)
#   3. Tags the repo as v<version>
#   4. Pushes the tag → triggers CD workflow (.github/workflows/cd.yml)
# ============================================================
set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
    echo "Usage: bash scripts/create_release.sh <version>"
    echo "Example: bash scripts/create_release.sh 1.2.0"
    exit 1
fi

# Validate semver (X.Y.Z)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version must be semver format (e.g. 1.2.0), got: $VERSION"
    exit 1
fi

TAG="v$VERSION"

# Must be on main branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "main" ]]; then
    echo "Error: releases must be created from main branch (currently on: $BRANCH)"
    exit 1
fi

# Must have no uncommitted changes
if ! git diff --quiet || ! git diff --staged --quiet; then
    echo "Error: uncommitted changes detected. Commit or stash them first."
    exit 1
fi

# Pull latest
git pull --ff-only origin main

# Show what will be in this release
PREV_TAG=$(git describe --abbrev=0 --tags 2>/dev/null || echo "")
echo ""
echo "Release notes preview for $TAG:"
echo "────────────────────────────────"
if [[ -n "$PREV_TAG" ]]; then
    git log --oneline "$PREV_TAG"..HEAD --no-merges
else
    git log --oneline -20 --no-merges
fi
echo "────────────────────────────────"
echo ""
read -r -p "Create and push tag $TAG? (y/N) " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"

echo ""
echo "Tag $TAG pushed. CD workflow will now:"
echo "  1. Build backend + AI Docker images → push to GCR"
echo "  2. Deploy to GCP VM (34.45.115.228)"
echo "  3. Build signed APK → publish GitHub Release"
echo ""
echo "Monitor at: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/actions"
