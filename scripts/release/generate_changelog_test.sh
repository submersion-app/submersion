#!/usr/bin/env bash
# Tests for generate_changelog.sh --notes-only, the Sparkle/appcast release
# notes path. Its stdout is piped into generate_release_notes_html.sh and
# published inside the update dialog, so progress output must stay on stderr:
# the v1.7.2.4977 appcast shipped "Changelog: 1.7.2 (commits since ...)" and
# "Found 82 commit(s) in 7 section(s)." as the opening lines of the notes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$SCRIPT_DIR/generate_changelog.sh"

fail() { echo "FAIL: $1"; exit 1; }

# Build a scratch repository with a tagged release and conventional commits
# after it, mirroring the state the release workflow runs from.
TMPREPO=$(mktemp -d)
trap 'rm -rf "$TMPREPO"' EXIT
(
  cd "$TMPREPO"
  git init -q
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m "chore: initial"
  git tag v1.0.0.1
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m "feat: a new thing"
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m "fix: an old thing"
)

STDOUT=$(cd "$TMPREPO" && "$GEN" --notes-only 2>/dev/null)
STDERR=$(cd "$TMPREPO" && "$GEN" --notes-only 2>&1 >/dev/null)

# Progress lines belong on stderr, never in the published notes body.
echo "$STDOUT" | grep -qiE '^(changelog:|found |generating|nothing to generate)' \
  && fail "progress output leaked onto --notes-only stdout"

# The notes must start with the version heading, not blank filler or noise.
[ -n "$STDOUT" ] || fail "--notes-only produced no output"
echo "$STDOUT" | head -1 | grep -q '^## ' \
  || fail "--notes-only does not start with the version heading"

# The commit content itself must be present.
echo "$STDOUT" | grep -q "a new thing" || fail "feat commit missing from notes"
echo "$STDOUT" | grep -q "an old thing" || fail "fix commit missing from notes"

# The progress lines still exist for humans running the script interactively.
echo "$STDERR" | grep -q "^Changelog: " || fail "progress summary missing from stderr"
echo "$STDERR" | grep -q "commit(s) in" || fail "commit count missing from stderr"


# --- Contributor attribution ------------------------------------------------
# The authorship map is injected rather than looked up, so this suite never
# needs a network or a GitHub token. contributors.sh has its own tests.
FEAT_SHA=$(cd "$TMPREPO" && git log --format='%H' --grep='a new thing' -1)
FIX_SHA=$(cd "$TMPREPO" && git log --format='%H' --grep='an old thing' -1)

ATTR=$(mktemp)
trap 'rm -rf "$TMPREPO" "$ATTR"' EXIT
{
  printf 'commit\t%s\t%s\t%s\n' "$FEAT_SHA" "octocat" "42"
  printf 'commit\t%s\t%s\t%s\n' "$FIX_SHA" "ericgriffin" ""
  printf 'new\t%s\t%s\n' "octocat" "42"
} > "$ATTR"

ATTRIBUTED=$(cd "$TMPREPO" && CHANGELOG_ATTRIBUTION_FILE="$ATTR" \
  "$GEN" --notes-only 2>/dev/null)

echo "$ATTRIBUTED" | grep -q '^- a new thing by @octocat in #42$' \
  || fail "bullet is missing its author and PR: $(echo "$ATTRIBUTED" | grep 'a new thing')"

# A commit that reached main without a PR still credits its author.
echo "$ATTRIBUTED" | grep -q '^- an old thing by @ericgriffin$' \
  || fail "bullet without a PR should still name the author"

# The first-contribution callout goes last, after every type section.
echo "$ATTRIBUTED" | grep -q '^### New Contributors$' \
  || fail "New Contributors section missing"
echo "$ATTRIBUTED" | grep -q '^- @octocat made their first contribution in #42$' \
  || fail "first-contribution line missing or misworded"
[ "$(echo "$ATTRIBUTED" | grep -n '^### ' | tail -1 | cut -d: -f2-)" = "### New Contributors" ] \
  || fail "New Contributors is not the last section"

# An unmapped commit renders exactly as it did before attribution existed.
PARTIAL=$(mktemp)
printf 'commit\t%s\t%s\t%s\n' "$FEAT_SHA" "octocat" "42" > "$PARTIAL"
UNMAPPED=$(cd "$TMPREPO" && CHANGELOG_ATTRIBUTION_FILE="$PARTIAL" \
  "$GEN" --notes-only 2>/dev/null)
echo "$UNMAPPED" | grep -q '^- an old thing$' \
  || fail "an unmapped commit must render as a plain bullet"
echo "$UNMAPPED" | grep -q '^### New Contributors$' \
  && fail "New Contributors must be suppressed when there are none"
rm -f "$PARTIAL"

# --no-attribution reproduces the pre-credits body byte for byte.
PLAIN=$(cd "$TMPREPO" && CHANGELOG_ATTRIBUTION_FILE="$ATTR" \
  "$GEN" --notes-only --no-attribution 2>/dev/null)
echo "$PLAIN" | grep -q '@' && fail "--no-attribution still emitted a handle"
[ "$PLAIN" = "$STDOUT" ] || fail "--no-attribution differs from the un-attributed body"

# The default path resolves authorship itself. This scratch repo has no
# remote and the test environment has no token, so it exercises the
# degradation: notes are still produced, with no handles invented.
DEFAULT=$(cd "$TMPREPO" && GH=/nonexistent-gh "$GEN" --notes-only 2>/dev/null)
[ -n "$DEFAULT" ] || fail "the default path produced no notes"
echo "$DEFAULT" | grep -q '^- a new thing' \
  || fail "the default path lost the commit content"
echo "$DEFAULT" | grep -q 'made their first contribution' \
  && fail "a first contribution was claimed with no API available"

echo "PASS: all generate_changelog tests passed"
