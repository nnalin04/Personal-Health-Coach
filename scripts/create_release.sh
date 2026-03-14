#!/usr/bin/env bash
# create_release.sh — tag a semver release and create a GitHub Release
# Usage: bash scripts/create_release.sh 1.2.0
#
# What it does:
#   1. Validates the version string (semver)
#   2. Previews the changelog since the last tag
#   3. Creates and pushes the git tag vX.Y.Z
#   4. The CD workflow (.github/workflows/cd.yml) triggers automatically,
#      builds the Docker images, deploys to GCP, and attaches the signed APK.

set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
    echo "Usage: bash scripts/create_release.sh <version>"
    echo "Example: bash scripts/create_release.sh 1.2.0"
    exit 1
fi

# Validate semver format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version must be semver format (e.g. 1.2.0)"
    exit 1
fi

TAG="v$VERSION"

# Check tag doesn't already exist
if git rev-parse "$TAG" &>/dev/null; then
    echo "Error: tag $TAG already exists"
    exit 1
fi

# Preview changelog
PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
echo "=== Release Notes Preview: $TAG ==="
if [[ -n "$PREV_TAG" ]]; then
    git log --oneline "$PREV_TAG..HEAD"
else
    git log --oneline -20
fi
echo ""

read -r -p "Create and push tag $TAG? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

git tag "$TAG"
git push origin "$TAG"

echo ""
echo "Tag $TAG pushed. CD workflow will now:"
echo "  1. Build and push Docker images to GCR"
echo "  2. SSH deploy to GCP VM (34.45.115.228)"
echo "  3. Build signed APK and attach to GitHub Release"
echo ""
echo "Monitor: https://github.com/nnalin04/Personal-Health-Coach/actions"
