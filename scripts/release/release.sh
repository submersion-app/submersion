#!/usr/bin/env bash
# Unified release script that orchestrates version bump, changelog, and release.
#
# Runs three steps in sequence:
#   1. Bump version (bump_version.sh)
#   2. Generate changelog (generate_changelog.sh) and amend version commit
#   3. Create release tag and push (create_release.sh)
#
# Usage:
#   ./scripts/release/release.sh --patch              # patch release
#   ./scripts/release/release.sh --minor              # minor release
#   ./scripts/release/release.sh --major              # major release
#   ./scripts/release/release.sh --build              # build number only
#   ./scripts/release/release.sh --patch --beta       # beta pre-release
#   ./scripts/release/release.sh --patch --rc         # release candidate
#   ./scripts/release/release.sh --dry-run --patch    # preview all steps
#   ./scripts/release/release.sh --patch --skip-preflight

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Parse arguments ---
BUMP_TYPE=""
PRERELEASE_LABEL=""
DRY_RUN=false
SKIP_PREFLIGHT=false

for arg in "$@"; do
  case "$arg" in
    --major)           BUMP_TYPE="major" ;;
    --minor)           BUMP_TYPE="minor" ;;
    --patch)           BUMP_TYPE="patch" ;;
    --build)           BUMP_TYPE="build" ;;
    --beta)            PRERELEASE_LABEL="beta" ;;
    --rc)              PRERELEASE_LABEL="rc" ;;
    --alpha)           PRERELEASE_LABEL="alpha" ;;
    --dry-run)         DRY_RUN=true ;;
    --skip-preflight)  SKIP_PREFLIGHT=true ;;
    --help|-h)
      sed -nE '2,/^$/s/^# ?//p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--major|--minor|--patch|--build] [--beta|--rc|--alpha] [--dry-run] [--skip-preflight]"
      exit 1
      ;;
  esac
done

if [ -z "$BUMP_TYPE" ]; then
  echo "Error: No bump type specified."
  echo "Usage: $0 [--major|--minor|--patch|--build] [--beta|--rc|--alpha] [--dry-run] [--skip-preflight]"
  exit 1
fi

# --- Step 1: Bump version ---
echo "========================================"
echo "Step 1/3: Bump version (--$BUMP_TYPE)"
echo "========================================"
echo ""

if [ "$DRY_RUN" = true ]; then
  "$SCRIPT_DIR/bump_version.sh" "--$BUMP_TYPE" --dry-run
else
  "$SCRIPT_DIR/bump_version.sh" "--$BUMP_TYPE" --commit
fi

echo ""

# --- Step 2: Generate changelog ---
echo "========================================"
echo "Step 2/3: Generate changelog"
echo "========================================"
echo ""

if [ "$DRY_RUN" = true ]; then
  "$SCRIPT_DIR/generate_changelog.sh" --dry-run
else
  "$SCRIPT_DIR/generate_changelog.sh"
  git add CHANGELOG.md
  git commit --amend --no-edit
  echo ""
  echo "Amended version commit with CHANGELOG.md"
fi

echo ""

# --- Step 3: Create release ---
echo "========================================"
echo "Step 3/3: Create release"
echo "========================================"
echo ""

CREATE_ARGS=()

if [ -n "$PRERELEASE_LABEL" ]; then
  CREATE_ARGS+=("--$PRERELEASE_LABEL")
fi

if [ "$SKIP_PREFLIGHT" = true ]; then
  CREATE_ARGS+=("--skip-preflight")
fi

if [ "$DRY_RUN" = true ]; then
  CREATE_ARGS+=("--dry-run")
fi

"$SCRIPT_DIR/create_release.sh" "${CREATE_ARGS[@]+"${CREATE_ARGS[@]}"}"

echo ""

# --- Done ---
if [ "$DRY_RUN" = true ]; then
  echo "========================================"
  echo "[Dry run] No changes were made."
  echo "========================================"
else
  echo "========================================"
  echo "Release complete! Monitor CI progress:"
  echo "  ./scripts/release/status.sh --watch"
  echo "========================================"
fi
