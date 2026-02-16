#!/usr/bin/env bash
# Generate a changelog from conventional commits since the last git tag.
#
# Parses commit messages (feat:, fix:, refactor:, etc.), groups them by type,
# and outputs markdown. By default, prepends the new section to CHANGELOG.md.
#
# Usage:
#   ./scripts/release/generate_changelog.sh              # prepend to CHANGELOG.md
#   ./scripts/release/generate_changelog.sh --notes-only # output to stdout only
#   ./scripts/release/generate_changelog.sh --dry-run    # preview without writing
#   ./scripts/release/generate_changelog.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"
CHANGELOG="$PROJECT_DIR/CHANGELOG.md"

# --- Parse arguments ---
NOTES_ONLY=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --notes-only) NOTES_ONLY=true ;;
    --dry-run)    DRY_RUN=true ;;
    --help|-h)
      sed -nE '2,/^$/s/^# ?//p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--notes-only] [--dry-run]"
      exit 1
      ;;
  esac
done

# --- Read version from pubspec.yaml ---
VERSION_LINE=$(grep '^version:' "$PUBSPEC")
if [ -z "$VERSION_LINE" ]; then
  echo "Error: Could not find 'version:' in $PUBSPEC"
  exit 1
fi

FULL_VERSION=$(echo "$VERSION_LINE" | sed 's/version: *//')
SEMVER=$(echo "$FULL_VERSION" | cut -d'+' -f1)

if [ -z "$SEMVER" ]; then
  echo "Error: Could not parse version '$FULL_VERSION'"
  exit 1
fi

# --- Find previous tag ---
PREV_TAG=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "")

if [ -n "$PREV_TAG" ]; then
  COMMIT_RANGE="${PREV_TAG}..HEAD"
  echo "Changelog: $SEMVER (commits since $PREV_TAG)"
else
  COMMIT_RANGE="HEAD"
  echo "Changelog: $SEMVER (all commits, no previous tag found)"
fi
echo ""

# --- Map commit type to section header ---
section_header() {
  case "$1" in
    feat)     echo "Features" ;;
    fix)      echo "Bug Fixes" ;;
    refactor) echo "Refactoring" ;;
    perf)     echo "Performance" ;;
    docs)     echo "Documentation" ;;
    test)     echo "Tests" ;;
    ci)       echo "CI/CD" ;;
    chore)    echo "Chores" ;;
    *)        echo "Other" ;;
  esac
}

# --- Collect commits grouped by type ---
# Known types in display order
TYPES="feat fix refactor perf docs test ci chore"

# Temp directory for per-type commit lists
TMPDIR_CL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_CL"' EXIT

# Initialize empty files for each type
for t in $TYPES; do
  : > "$TMPDIR_CL/$t"
done
: > "$TMPDIR_CL/other"

COMMIT_COUNT=0

# Read commits and sort into type buckets
while IFS= read -r line; do
  [ -z "$line" ] && continue
  COMMIT_COUNT=$((COMMIT_COUNT + 1))

  # Match "type: description" or "type(scope): description"
  if echo "$line" | grep -qE '^[a-z]+(\([^)]*\))?!?:'; then
    TYPE=$(echo "$line" | sed -E 's/^([a-z]+)(\([^)]*\))?!?:.*/\1/')
    MSG=$(echo "$line" | sed -E 's/^[a-z]+(\([^)]*\))?!?: *//')

    MATCHED=false
    for t in $TYPES; do
      if [ "$TYPE" = "$t" ]; then
        echo "- $MSG" >> "$TMPDIR_CL/$t"
        MATCHED=true
        break
      fi
    done

    if [ "$MATCHED" = false ]; then
      echo "- $MSG" >> "$TMPDIR_CL/other"
    fi
  else
    echo "- $line" >> "$TMPDIR_CL/other"
  fi
done <<EOF
$(git log --format='%s' --no-merges $COMMIT_RANGE 2>/dev/null)
EOF

if [ "$COMMIT_COUNT" -eq 0 ]; then
  echo "No commits found since ${PREV_TAG:-the beginning}."
  echo "Nothing to generate."
  exit 0
fi

# --- Build markdown ---
TODAY=$(date +%Y-%m-%d)
NOTES="## $SEMVER ($TODAY)"
NOTES="$NOTES
"

SECTION_COUNT=0
for t in $TYPES other; do
  if [ -s "$TMPDIR_CL/$t" ]; then
    HEADER=$(section_header "$t")
    NOTES="$NOTES
### $HEADER
"
    NOTES="$NOTES
$(cat "$TMPDIR_CL/$t")
"
    SECTION_COUNT=$((SECTION_COUNT + 1))
  fi
done

echo "Found $COMMIT_COUNT commit(s) in $SECTION_COUNT section(s)."
echo ""

# --- Output ---
if [ "$NOTES_ONLY" = true ]; then
  echo "$NOTES"
  exit 0
fi

if [ "$DRY_RUN" = true ]; then
  echo "[Dry run] Would prepend the following to $CHANGELOG:"
  echo ""
  echo "$NOTES"
  exit 0
fi

# --- Write to CHANGELOG.md ---
# Create CHANGELOG.md with header if it doesn't exist
if [ ! -f "$CHANGELOG" ]; then
  cat > "$CHANGELOG" <<'HEADER'
# Changelog

All notable changes to Submersion are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/).
HEADER
  echo "Created $CHANGELOG"
fi

# Prepend new section after the header block (first 4 lines)
TMPFILE=$(mktemp)
{
  head -n 4 "$CHANGELOG"
  echo ""
  echo "$NOTES"
  tail -n +5 "$CHANGELOG"
} > "$TMPFILE"
mv "$TMPFILE" "$CHANGELOG"

echo "Updated $CHANGELOG"
echo ""
echo "Next steps:"
echo "  git add CHANGELOG.md"
echo "  git diff --cached CHANGELOG.md   # review changes"
