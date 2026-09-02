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
#   ./scripts/release/generate_changelog.sh --no-attribution  # no credits
#   ./scripts/release/generate_changelog.sh --help
#
# Each bullet is credited to the person who wrote it and the PR that merged it,
# and first-time contributors get their own closing section. The authorship map
# comes from contributors.sh, which degrades to unattributed bullets rather
# than failing when the GitHub API is unavailable. Set
# CHANGELOG_ATTRIBUTION_FILE to inject a map instead of resolving one.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"
CHANGELOG="$PROJECT_DIR/CHANGELOG.md"

# --- Parse arguments ---
NOTES_ONLY=false
DRY_RUN=false
ATTRIBUTION=true

for arg in "$@"; do
  case "$arg" in
    --notes-only) NOTES_ONLY=true ;;
    --dry-run)    DRY_RUN=true ;;
    --no-attribution) ATTRIBUTION=false ;;
    --help|-h)
      sed -nE '2,/^$/s/^# ?//p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 [--notes-only] [--dry-run] [--no-attribution]"
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
# When HEAD itself is tagged (e.g., during CI release), git describe returns
# the current tag, producing an empty commit range. Detect this and use the
# parent commit to find the *previous* tag instead.
CURRENT_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null || echo "")
if [ -n "$CURRENT_TAG" ]; then
  PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
else
  PREV_TAG=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "")
fi

# Progress goes to stderr: --notes-only is redirected into a release body, and
# these lines were being published as part of it.
if [ -n "$PREV_TAG" ]; then
  COMMIT_RANGE="${PREV_TAG}..HEAD"
  echo "Changelog: $SEMVER (commits since $PREV_TAG)" >&2
else
  COMMIT_RANGE="HEAD"
  echo "Changelog: $SEMVER (all commits, no previous tag found)" >&2
fi
echo "" >&2

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

# --- Resolve who wrote what -------------------------------------------------
# An injected map keeps the test suite off the network. Otherwise the lookup
# runs here; it is allowed to come back empty, in which case every bullet
# renders exactly as it did before credits existed.
ATTR_FILE=""
if [ "$ATTRIBUTION" = true ]; then
  if [ -n "${CHANGELOG_ATTRIBUTION_FILE:-}" ]; then
    ATTR_FILE="$CHANGELOG_ATTRIBUTION_FILE"
  else
    ATTR_FILE="$TMPDIR_CL/attribution"
    "$SCRIPT_DIR/contributors.sh" --range "$COMMIT_RANGE" > "$ATTR_FILE" \
      || : > "$ATTR_FILE"
  fi
fi

# " by @octocat in #42", degrading to " by @octocat" and then to nothing. A
# commit with no login is left bare rather than credited to a display name:
# an @mention that does not resolve is worse than no credit at all.
attribution_for() {
  [ -n "$ATTR_FILE" ] || return 0
  [ -f "$ATTR_FILE" ] || return 0
  awk -F'\t' -v s="$1" '
    $1 == "commit" && $2 == s {
      if ($3 == "") exit
      printf " by @%s", $3
      if ($4 != "") printf " in #%s", $4
      exit
    }' "$ATTR_FILE"
}

COMMIT_COUNT=0

# Read commits and sort into type buckets
while IFS=$'\t' read -r sha line; do
  [ -z "$line" ] && continue
  COMMIT_COUNT=$((COMMIT_COUNT + 1))
  SUFFIX=$(attribution_for "$sha")

  # Match "type: description" or "type(scope): description"
  if echo "$line" | grep -qE '^[a-z]+(\([^)]*\))?!?:'; then
    TYPE=$(echo "$line" | sed -E 's/^([a-z]+)(\([^)]*\))?!?:.*/\1/')
    MSG=$(echo "$line" | sed -E 's/^[a-z]+(\([^)]*\))?!?: *//')

    MATCHED=false
    for t in $TYPES; do
      if [ "$TYPE" = "$t" ]; then
        echo "- $MSG$SUFFIX" >> "$TMPDIR_CL/$t"
        MATCHED=true
        break
      fi
    done

    if [ "$MATCHED" = false ]; then
      echo "- $MSG$SUFFIX" >> "$TMPDIR_CL/other"
    fi
  else
    echo "- $line$SUFFIX" >> "$TMPDIR_CL/other"
  fi
done <<EOF
$(git log --format='%H%x09%s' --no-merges $COMMIT_RANGE 2>/dev/null)
EOF

if [ "$COMMIT_COUNT" -eq 0 ]; then
  echo "No commits found since ${PREV_TAG:-the beginning}." >&2
  echo "Nothing to generate." >&2
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

# Last, the way GitHub's own generated notes place it: the reader has seen
# what shipped before being told who is new.
if [ -n "$ATTR_FILE" ] && [ -f "$ATTR_FILE" ]; then
  NEW_CONTRIBUTORS=$(awk -F'\t' '
    $1 == "new" && $2 != "" {
      line = "- @" $2 " made their first contribution"
      if ($3 != "") line = line " in #" $3
      print line
    }' "$ATTR_FILE")
  if [ -n "$NEW_CONTRIBUTORS" ]; then
    NOTES="$NOTES
### New Contributors
"
    NOTES="$NOTES
$NEW_CONTRIBUTORS
"
    SECTION_COUNT=$((SECTION_COUNT + 1))
  fi
fi

echo "Found $COMMIT_COUNT commit(s) in $SECTION_COUNT section(s)." >&2
echo "" >&2

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
