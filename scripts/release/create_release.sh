#!/usr/bin/env bash
# Create and push a GitHub release tag.
#
# Reads the version and build number from pubspec.yaml, runs preflight checks,
# creates a git tag, and pushes it to origin. The CI release workflow
# (.github/workflows/release.yml) triggers on v* tag pushes and handles
# building, signing, and uploading artifacts.
#
# Usage:
#   ./scripts/release/create_release.sh              # release tag: v1.1.0.33
#   ./scripts/release/create_release.sh --beta       # beta tag:    v1.1.0-beta.33
#   ./scripts/release/create_release.sh --rc         # RC tag:      v1.1.0-rc.33
#   ./scripts/release/create_release.sh --dry-run    # show what would happen
#   ./scripts/release/create_release.sh --skip-preflight  # skip checks
#   ./scripts/release/create_release.sh --beta --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"

# --- Parse arguments ---
PRERELEASE_LABEL=""
DRY_RUN=false
SKIP_PREFLIGHT=false

for arg in "$@"; do
  case "$arg" in
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
      echo "Usage: $0 [--beta|--rc|--alpha] [--dry-run] [--skip-preflight]"
      exit 1
      ;;
  esac
done

# --- Extract version from pubspec.yaml ---
VERSION_LINE=$(grep '^version:' "$PUBSPEC")
if [ -z "$VERSION_LINE" ]; then
  echo "Error: Could not find 'version:' in $PUBSPEC"
  exit 1
fi

# Parse "version: 1.1.0+33" into parts
FULL_VERSION=$(echo "$VERSION_LINE" | sed 's/version: *//')
SEMVER=$(echo "$FULL_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$FULL_VERSION" | cut -d'+' -f2)

if [ -z "$SEMVER" ] || [ -z "$BUILD_NUMBER" ]; then
  echo "Error: Could not parse version '$FULL_VERSION' (expected format: X.Y.Z+N)"
  exit 1
fi

# --- Build tag name ---
if [ -n "$PRERELEASE_LABEL" ]; then
  TAG="v${SEMVER}-${PRERELEASE_LABEL}.${BUILD_NUMBER}"
else
  TAG="v${SEMVER}.${BUILD_NUMBER}"
fi

echo "=== Create Release ==="
echo "Pubspec version: $FULL_VERSION"
echo "Tag:             $TAG"
echo ""

# --- Tag collision checks (always run, even with --skip-preflight) ---
if git tag -l "$TAG" | grep -q "$TAG"; then
  echo "Error: Tag '$TAG' already exists locally."
  echo "To delete it: ./scripts/release/delete_release.sh $TAG"
  exit 1
fi

if git ls-remote --tags origin "refs/tags/$TAG" 2>/dev/null | grep -q "$TAG"; then
  echo "Error: Tag '$TAG' already exists on remote."
  echo "To delete it: ./scripts/release/delete_release.sh $TAG"
  exit 1
fi

# --- Preflight checks ---
if [ "$SKIP_PREFLIGHT" = true ]; then
  echo "[Preflight] Skipped (--skip-preflight)"
  echo ""
elif [ "$DRY_RUN" = true ]; then
  echo "[Preflight] Would run these checks:"
  echo "  - Verify on main branch"
  echo "  - Verify clean working tree"
  echo "  - Run dart format --set-exit-if-changed"
  echo "  - Run flutter analyze"
  echo "  - Run flutter test"
  echo ""
else
  echo "=== Preflight Checks ==="
  PREFLIGHT_FAILED=false

  # 1. Branch check
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "  [WARN] Not on main branch (on '$CURRENT_BRANCH')"
    read -rp "  Continue from '$CURRENT_BRANCH'? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 1
    fi
  else
    echo "  [OK] On main branch"
  fi

  # 2. Clean working tree
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "  [FAIL] Uncommitted changes detected"
    PREFLIGHT_FAILED=true
  else
    echo "  [OK] Working tree is clean"
  fi

  # 3. Up to date with remote
  git fetch origin main --quiet 2>/dev/null || true
  LOCAL_SHA=$(git rev-parse HEAD)
  REMOTE_SHA=$(git rev-parse origin/main 2>/dev/null || echo "unknown")
  if [ "$REMOTE_SHA" != "unknown" ] && [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
    echo "  [WARN] Local HEAD differs from origin/main"
  else
    echo "  [OK] Up to date with origin/main"
  fi

  # 4. Format check
  echo "  [..] Running dart format..."
  cd "$PROJECT_DIR"
  if dart format --set-exit-if-changed lib/ test/ > /dev/null 2>&1; then
    echo "  [OK] Code formatting"
  else
    echo "  [FAIL] Code formatting (run: dart format lib/ test/)"
    PREFLIGHT_FAILED=true
  fi

  # 5. Static analysis
  echo "  [..] Running flutter analyze..."
  if flutter analyze --no-fatal-infos > /dev/null 2>&1; then
    echo "  [OK] Static analysis"
  else
    echo "  [FAIL] Static analysis (run: flutter analyze)"
    PREFLIGHT_FAILED=true
  fi

  # 6. Tests
  echo "  [..] Running flutter test..."
  if flutter test > /dev/null 2>&1; then
    echo "  [OK] Tests pass"
  else
    echo "  [FAIL] Tests failing (run: flutter test)"
    PREFLIGHT_FAILED=true
  fi

  echo ""

  if [ "$PREFLIGHT_FAILED" = true ]; then
    echo "Preflight checks failed. Fix the issues above or use --skip-preflight to bypass."
    exit 1
  fi

  echo "All preflight checks passed."
  echo ""
fi

# --- Dry run ---
if [ "$DRY_RUN" = true ]; then
  echo "[Dry run] Would create tag: $TAG"
  echo "[Dry run] Would push tag to origin"
  echo "[Dry run] CI would then build and create GitHub Release"
  exit 0
fi

# --- Create and push ---
echo "Creating tag '$TAG'..."
git tag "$TAG"

echo "Pushing tag to origin..."
git push origin --no-verify "$TAG"

echo ""
echo "=== Done ==="
echo "Tag '$TAG' pushed. The release workflow will now:"
echo "  1. Build all platforms (macOS, Windows, Linux, Android, iOS)"
echo "  2. Create a GitHub Release with artifacts"
if [ -n "$PRERELEASE_LABEL" ]; then
  echo "  3. Mark as pre-release ($PRERELEASE_LABEL)"
fi
echo ""
echo "Monitor progress: gh run list --workflow=release.yml"
