#!/usr/bin/env bash
# Bump the version and build number in pubspec.yaml.
#
# Always increments the build number. Optionally bumps major, minor, or patch.
#
# Usage:
#   ./scripts/release/bump_version.sh --patch       # X.Y.Z+N -> X.Y.(Z+1)+(N+1)
#   ./scripts/release/bump_version.sh --minor       # X.Y.Z+N -> X.(Y+1).0+(N+1)
#   ./scripts/release/bump_version.sh --major       # X.Y.Z+N -> (X+1).0.0+(N+1)
#   ./scripts/release/bump_version.sh --build       # X.Y.Z+N -> X.Y.Z+(N+1)
#   ./scripts/release/bump_version.sh --set 2.0.0   # X.Y.Z+N -> 2.0.0+(N+1)
#   ./scripts/release/bump_version.sh --patch --commit  # bump + git commit
#   ./scripts/release/bump_version.sh --dry-run --minor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"

# --- Parse arguments ---
BUMP_TYPE=""
SET_VERSION=""
DRY_RUN=false
AUTO_COMMIT=false

for arg in "$@"; do
  case "$arg" in
    --major)   BUMP_TYPE="major" ;;
    --minor)   BUMP_TYPE="minor" ;;
    --patch)   BUMP_TYPE="patch" ;;
    --build)   BUMP_TYPE="build" ;;
    --set)     BUMP_TYPE="set" ;;
    --commit)  AUTO_COMMIT=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      sed -nE '2,/^$/s/^# ?//p' "$0"
      exit 0
      ;;
    *)
      if [ "$BUMP_TYPE" = "set" ] && [ -z "$SET_VERSION" ]; then
        SET_VERSION="$arg"
      else
        echo "Unknown argument: $arg"
        echo "Usage: $0 [--major|--minor|--patch|--build|--set X.Y.Z] [--commit] [--dry-run]"
        exit 1
      fi
      ;;
  esac
done

if [ -z "$BUMP_TYPE" ]; then
  echo "Error: No bump type specified."
  echo "Usage: $0 [--major|--minor|--patch|--build|--set X.Y.Z] [--commit] [--dry-run]"
  exit 1
fi

if [ "$BUMP_TYPE" = "set" ] && [ -z "$SET_VERSION" ]; then
  echo "Error: --set requires a version argument (e.g., --set 2.0.0)"
  exit 1
fi

# --- Read current version ---
VERSION_LINE=$(grep '^version:' "$PUBSPEC")
if [ -z "$VERSION_LINE" ]; then
  echo "Error: Could not find 'version:' in $PUBSPEC"
  exit 1
fi

FULL_VERSION=$(echo "$VERSION_LINE" | sed 's/version: *//')
SEMVER=$(echo "$FULL_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$FULL_VERSION" | cut -d'+' -f2)

MAJOR=$(echo "$SEMVER" | cut -d'.' -f1)
MINOR=$(echo "$SEMVER" | cut -d'.' -f2)
PATCH=$(echo "$SEMVER" | cut -d'.' -f3)

if [ -z "$MAJOR" ] || [ -z "$MINOR" ] || [ -z "$PATCH" ] || [ -z "$BUILD_NUMBER" ]; then
  echo "Error: Could not parse version '$FULL_VERSION' (expected format: X.Y.Z+N)"
  exit 1
fi

# --- Calculate new version ---
NEW_BUILD=$((BUILD_NUMBER + 1))

case "$BUMP_TYPE" in
  major)
    NEW_SEMVER="$((MAJOR + 1)).0.0"
    ;;
  minor)
    NEW_SEMVER="${MAJOR}.$((MINOR + 1)).0"
    ;;
  patch)
    NEW_SEMVER="${MAJOR}.${MINOR}.$((PATCH + 1))"
    ;;
  build)
    NEW_SEMVER="$SEMVER"
    ;;
  set)
    # Validate format
    if ! echo "$SET_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
      echo "Error: Invalid version format '$SET_VERSION' (expected X.Y.Z)"
      exit 1
    fi
    NEW_SEMVER="$SET_VERSION"
    ;;
esac

NEW_FULL="${NEW_SEMVER}+${NEW_BUILD}"

echo "=== Version Bump ==="
echo "Current: $FULL_VERSION"
echo "New:     $NEW_FULL"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[Dry run] Would update $PUBSPEC"
  exit 0
fi

# --- Update pubspec.yaml ---
sed -i '' "s/^version: .*/version: ${NEW_FULL}/" "$PUBSPEC"

# Verify the change
UPDATED=$(grep '^version:' "$PUBSPEC" | sed 's/version: *//')
if [ "$UPDATED" != "$NEW_FULL" ]; then
  echo "Error: Verification failed. Expected '$NEW_FULL' but found '$UPDATED'"
  exit 1
fi

echo "Updated $PUBSPEC"

if [ "$AUTO_COMMIT" = true ]; then
  git add "$PUBSPEC"
  git commit -m "chore: bump version to $NEW_FULL"
  echo ""
  echo "Next step:"
  echo "  ./scripts/release/create_release.sh    # pushes commits, tags, triggers CI"
else
  echo ""
  echo "Next steps:"
  echo "  git add pubspec.yaml && git commit -m 'chore: bump version to $NEW_FULL'"
  echo "  ./scripts/release/create_release.sh    # pushes commits, tags, triggers CI"
fi
