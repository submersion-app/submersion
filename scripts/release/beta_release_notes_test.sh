#!/usr/bin/env bash
# Tests for beta_release_notes.sh: the per-beta "what to test" text handed to
# TestFlight and Play open testing. Before this script existed the store lanes
# shipped a fixed "automated per-merge build" string, so testers had no way to
# tell what a beta actually changed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$SCRIPT_DIR/beta_release_notes.sh"

fail() { echo "FAIL: $1"; exit 1; }

# --- Grouping and prefix stripping -----------------------------------------

SUBJECTS=$(printf '%s\n' \
  'feat(sync): add incremental changesets' \
  'fix: stop the profile chart flickering' \
  'perf: cache the tissue grid' \
  'chore: bump deps' \
  'ci: retain 30 betas' \
  'docs: update the readme' \
  'test: cover the gauge provider' \
  'refactor: extract a helper')

OUT=$(printf '%s\n' "$SUBJECTS" | "$GEN" --stdin --format apple)

echo "$OUT" | grep -q "New in this build" || fail "Apple output missing the new-work heading"
echo "$OUT" | grep -q "add incremental changesets" || fail "feat subject missing"
echo "$OUT" | grep -q "stop the profile chart flickering" || fail "fix subject missing"
echo "$OUT" | grep -q "cache the tissue grid" || fail "perf subject missing"
echo "$OUT" | grep -q "feat(sync):" && fail "conventional-commit prefix was not stripped"
echo "$OUT" | grep -q "bump deps" && fail "chore leaked into tester-facing notes"
echo "$OUT" | grep -q "retain 30 betas" && fail "ci leaked into tester-facing notes"
echo "$OUT" | grep -q "update the readme" && fail "docs leaked into tester-facing notes"
echo "$OUT" | grep -q "cover the gauge provider" && fail "test leaked into tester-facing notes"
echo "$OUT" | grep -q "extract a helper" && fail "refactor leaked into tester-facing notes"

# Fixes must be separated from new work so testers can target their testing.
echo "$OUT" | grep -q "Fixed" || fail "Apple output missing the fixes heading"

# --- Breaking-change and scope variants ------------------------------------

OUT=$(printf '%s\n' 'feat!: drop the legacy importer' 'fix(ios)!: correct the BLE handshake' \
  | "$GEN" --stdin --format apple)
echo "$OUT" | grep -q "drop the legacy importer" || fail "breaking feat subject missing"
echo "$OUT" | grep -q "correct the BLE handshake" || fail "scoped breaking fix subject missing"
echo "$OUT" | grep -qE '(feat|fix)[(!]' && fail "breaking-change prefix was not stripped"

# --- Duplicate subjects collapse -------------------------------------------

OUT=$(printf '%s\n' 'fix: same thing' 'fix: same thing' 'fix: same thing' \
  | "$GEN" --stdin --format apple)
[ "$(echo "$OUT" | grep -c "same thing")" -eq 1 ] || fail "duplicate subjects were not collapsed"

# --- Play's 500-character limit --------------------------------------------
# Google rejects a release-notes body over 500 chars per locale, so the play
# format must cap itself rather than fail the upload.

LONG=$(for i in $(seq 1 60); do
  echo "feat: add a fairly wordy feature number $i that eats up characters"
done)

OUT=$(printf '%s\n' "$LONG" | "$GEN" --stdin --format play)
LEN=${#OUT}
[ "$LEN" -le 500 ] || fail "play format emitted $LEN chars, over Google's 500 limit"
[ "$LEN" -gt 0 ] || fail "play format emitted nothing"
echo "$OUT" | grep -q "more" || fail "play format truncated without telling the reader more was cut"

# --- TestFlight's 4000-character limit --------------------------------------

HUGE=$(for i in $(seq 1 400); do
  echo "feat: add a fairly wordy feature number $i that eats up characters"
done)

OUT=$(printf '%s\n' "$HUGE" | "$GEN" --stdin --format apple)
LEN=${#OUT}
[ "$LEN" -le 4000 ] || fail "Apple format emitted $LEN chars, over Apple's 4000 limit"
[ "$LEN" -gt 0 ] || fail "Apple format emitted nothing"

# Truncation must land on an item boundary, never mid-word.
echo "$OUT" | grep -q "characters$" || echo "$OUT" | grep -q "more" \
  || fail "Apple truncation did not end cleanly"

# --- Empty and no-user-facing-work cases ------------------------------------
# whatsNew must never be blank: Apple shows the field verbatim, and an empty
# string reads to a tester as "the previous build's notes still apply".

OUT=$(printf '' | "$GEN" --stdin --format apple)
[ -n "$OUT" ] || fail "empty range produced empty Apple notes"

OUT=$(printf '%s\n' 'chore: bump deps' 'ci: tweak a workflow' | "$GEN" --stdin --format apple)
[ -n "$OUT" ] || fail "internal-only range produced empty Apple notes"
echo "$OUT" | grep -qi "internal" || fail "internal-only range should say so explicitly"

# --- The placeholder this script replaces must never reappear ---------------

OUT=$(printf '%s\n' 'feat: something real' | "$GEN" --stdin --format apple)
echo "$OUT" | grep -q "automated per-merge build" \
  && fail "output still contains the placeholder string it was written to replace"

# --- Markdown format for the GitHub beta release ----------------------------

OUT=$(printf '%s\n' 'feat: a new thing' 'fix: an old thing' 'chore: noise' \
  | "$GEN" --stdin --format markdown)
echo "$OUT" | grep -q "^### " || fail "markdown format missing section headings"
echo "$OUT" | grep -q "^- a new thing" || fail "markdown format missing bullet for feat"
echo "$OUT" | grep -q "^- an old thing" || fail "markdown format missing bullet for fix"

# The markdown format is the GitHub release body, where the full engineering
# history is useful, so it keeps internal work under its own heading.
echo "$OUT" | grep -q "noise" || fail "markdown format dropped internal work entirely"

# --- Progress output must not contaminate stdout ----------------------------
# generate_changelog.sh wrote its progress lines to stdout, which embedded
# "Found N commit(s)" at the top of every published beta release body.

OUT=$(printf '%s\n' 'feat: a new thing' | "$GEN" --stdin --format markdown 2>/dev/null)
echo "$OUT" | grep -qiE "^(found|changelog:|generating)" \
  && fail "progress output leaked onto stdout"

# --- Argument validation ----------------------------------------------------

if printf '' | "$GEN" --stdin --format bogus >/dev/null 2>&1; then
  fail "an unknown --format was accepted"
fi

if "$GEN" --format apple >/dev/null 2>&1; then
  fail "missing --range/--stdin was accepted"
fi

# --- --since against a real repository --------------------------------------
# The beta pipeline knows the previous beta's commit but not a git range, and
# on the very first beta it knows nothing at all. Both must work.

TMPREPO=$(mktemp -d)
trap 'rm -rf "$TMPREPO"' EXIT
(
  cd "$TMPREPO"
  git init -q .
  git config user.email t@example.com
  git config user.name Test
  git commit -q --allow-empty -m 'feat: the baseline feature'
  git tag v0.0.1.1
  BASE=$(git rev-parse HEAD)
  git commit -q --allow-empty -m 'feat: the new feature'
  # The repository carries Flutter's own upstream tags alongside the app's.
  # Those are 3-segment, and an unfiltered `git describe` picks them up.
  git tag v3.13.0
  git commit -q --allow-empty -m 'chore: internal noise'
  echo "$BASE" > .base
)
BASE=$(cat "$TMPREPO/.base")

OUT=$(cd "$TMPREPO" && "$GEN" --since "$BASE" --format apple 2>/dev/null)
echo "$OUT" | grep -q "the new feature" || fail "--since did not include commits after the baseline"
echo "$OUT" | grep -q "the baseline feature" \
  && fail "--since included the baseline commit itself"

# An empty --since is the first-beta case: fall back to the last tag rather
# than failing, so the very first beta still gets real notes.
# The fallback must land on the app's 4-segment tag, not the Flutter tag that
# sits closer to HEAD; picking the wrong one silently drops real changes.
OUT=$(cd "$TMPREPO" && "$GEN" --since "" --format apple 2>/dev/null)
echo "$OUT" | grep -q "the new feature" \
  || fail "empty --since fell back to a Flutter tag instead of the app's 4-segment tag"
echo "$OUT" | grep -q "the baseline feature" \
  && fail "empty --since should start from the last tag, not the beginning"

# --- Cumulative section for the GitHub beta release body --------------------
# A tester coming straight from the public release needs the whole picture, not
# just this beta's delta. The GitHub body is uncapped, so it carries both.

TMPREPO2=$(mktemp -d)
trap 'rm -rf "$TMPREPO" "$TMPREPO2"' EXIT
(
  cd "$TMPREPO2"
  git init -q .
  git config user.email t@example.com
  git config user.name Test
  git commit -q --allow-empty -m 'feat: the shipped feature'
  git tag v0.0.1.1                       # last production release
  git commit -q --allow-empty -m 'feat: an earlier beta feature'
  git tag v3.13.0                        # a Flutter upstream tag, must be ignored
  git commit -q --allow-empty -m 'chore: internal noise'
  PREV_BETA=$(git rev-parse HEAD)
  git commit -q --allow-empty -m 'fix: a fix only in this beta'
  echo "$PREV_BETA" > .prev
)
PREV_BETA=$(cat "$TMPREPO2/.prev")

OUT=$(cd "$TMPREPO2" && "$GEN" --since "$PREV_BETA" --format markdown --cumulative 2>/dev/null)

echo "$OUT" | grep -q "^## New in this beta" || fail "cumulative mode missing the per-beta heading"
echo "$OUT" | grep -q "^## Everything since v0.0.1.1" \
  || fail "cumulative heading missing or naming the wrong baseline tag"

# The baseline must be the last production tag, not the Flutter tag nearer HEAD.
echo "$OUT" | grep -q "^## Everything since v3.13.0" \
  && fail "cumulative section anchored to a Flutter upstream tag"

# Split at the cumulative heading and check what landed on each side.
INCREMENTAL=$(echo "$OUT" | sed -n '1,/^## Everything since/p')
CUMULATIVE=$(echo "$OUT" | sed -n '/^## Everything since/,$p')

echo "$INCREMENTAL" | grep -q "a fix only in this beta" \
  || fail "per-beta section missing this beta's own change"
echo "$INCREMENTAL" | grep -q "an earlier beta feature" \
  && fail "per-beta section leaked a change from an earlier beta"

echo "$CUMULATIVE" | grep -q "an earlier beta feature" \
  || fail "cumulative section missing an earlier beta's change"
echo "$CUMULATIVE" | grep -q "a fix only in this beta" \
  || fail "cumulative section missing this beta's change"

# Work already in production must not be replayed in either section.
echo "$OUT" | grep -q "the shipped feature" \
  && fail "already-released work appeared in the beta notes"

# Without the flag the output stays exactly as it was.
OUT=$(cd "$TMPREPO2" && "$GEN" --since "$PREV_BETA" --format markdown 2>/dev/null)
echo "$OUT" | grep -q "^## " && fail "non-cumulative markdown gained a section heading"
echo "$OUT" | grep -q "an earlier beta feature" \
  && fail "non-cumulative markdown included earlier betas"

# With no production tag at all there is nothing to be cumulative against, and
# the body must still be valid rather than carrying an empty section.
TMPREPO3=$(mktemp -d)
trap 'rm -rf "$TMPREPO" "$TMPREPO2" "$TMPREPO3"' EXIT
(
  cd "$TMPREPO3"
  git init -q .
  git config user.email t@example.com
  git config user.name Test
  git commit -q --allow-empty -m 'feat: the very first feature'
)
OUT=$(cd "$TMPREPO3" && "$GEN" --since "" --format markdown --cumulative 2>/dev/null)
[ -n "$OUT" ] || fail "cumulative mode with no tags produced nothing"
echo "$OUT" | grep -q "^## Everything since" \
  && fail "cumulative section emitted with no production tag to anchor it"
echo "$OUT" | grep -q "the very first feature" || fail "first-ever build lost its notes"

# The capped formats carry the cumulative section too, truncated to fit. A
# tester arriving straight from the public release needs the whole picture,
# and TestFlight has 4000 characters to spend on it.
# Capture the exit status explicitly. Under set -e a failing command
# substitution aborts the whole script before any assertion runs, which turns
# a real regression into a silent non-zero exit with no message.
OUT=$(cd "$TMPREPO2" && "$GEN" --since "$PREV_BETA" --format apple --cumulative 2>/dev/null) \
  || fail "--cumulative was rejected for the Apple format"
echo "$OUT" | grep -q "a fix only in this beta" \
  || fail "Apple cumulative dropped this beta's own change"
echo "$OUT" | grep -q "an earlier beta feature" \
  || fail "Apple cumulative missing an earlier beta's change"
echo "$OUT" | grep -q "Since v0.0.1" \
  || fail "Apple cumulative heading missing or wrongly versioned"
echo "$OUT" | grep -q "Since v0.0.1.1" \
  && fail "Apple cumulative heading used the 4-segment tag, not the marketing version"
echo "$OUT" | grep -q "the shipped feature" \
  && fail "already-released work appeared in the Apple notes"

OUT=$(cd "$TMPREPO2" && "$GEN" --since "$PREV_BETA" --format play --cumulative 2>/dev/null) \
  || fail "--cumulative was rejected for the play format"
echo "$OUT" | grep -q "an earlier beta feature" \
  || fail "play cumulative missing an earlier beta's change"
[ "${#OUT}" -le 500 ] || fail "play cumulative output exceeded the 500-character cap"

# --- PR titles are the unit of a note ---------------------------------------
# Only 14% of commits on main carry a conventional prefix; the tester-facing
# summary of a change is its PR title, which this repository stores as the
# first body line of the merge commit. A --no-merges walk discarded exactly
# that, so build 1.7.3.5623 shipped "internal changes only" while its range
# contained four user-visible fixes.

TMPREPO4=$(mktemp -d)
trap 'rm -rf "$TMPREPO" "$TMPREPO2" "$TMPREPO3" "$TMPREPO4"' EXIT
(
  cd "$TMPREPO4"
  git init -q -b main .
  git config user.email t@example.com
  git config user.name Test
  git commit -q --allow-empty -m 'feat: the shipped feature'
  git tag v0.0.1.1
  git rev-parse HEAD > .base

  # A PR branch whose own commits are noisy but whose title is clean.
  git checkout -q -b pr-one
  git commit -q --allow-empty -m 'wip: rename a variable'
  git commit -q --allow-empty -m 'address review feedback'
  git checkout -q main
  git merge -q --no-ff pr-one \
    -m 'Merge pull request #1 from org/pr-one' \
    -m 'Show uploaded certification card photos in the wallet'

  # A second PR that first syncs main into its own branch. That inner merge is
  # not on main's first-parent line and must contribute nothing.
  git checkout -q -b pr-two
  git commit -q --allow-empty -m 'more branch work'
  git merge -q --no-ff main -m 'Merge origin/main into pr-two'
  git checkout -q main
  git merge -q --no-ff pr-two \
    -m 'Merge pull request #2 from org/pr-two' \
    -m 'Fix unreliable S3 sync on mobile networks'

  # A PR whose merge message uses CRLF line endings. The repository carries
  # CRLF content, and a stray carriage return would ride into the store text.
  git checkout -q -b pr-crlf
  git commit -q --allow-empty -m 'yet more branch work'
  git checkout -q main
  git merge -q --no-ff --no-commit pr-crlf >/dev/null
  # --cleanup=verbatim is required: git's default cleanup strips the carriage
  # returns, so without it this fixture is vacuous and the assertion below
  # passes whether or not the extractor handles CR at all.
  printf 'Merge pull request #3 from org/pr-crlf\r\n\r\nAdd a CRLF titled change\r\n' \
    | git commit -q --cleanup=verbatim -F -

  # A commit pushed straight to main, belonging to no PR.
  git commit -q --allow-empty -m 'Raise the iOS deployment target to 15.0'
)
BASE4=$(cat "$TMPREPO4/.base")

OUT=$(cd "$TMPREPO4" && "$GEN" --since "$BASE4" --format markdown 2>/dev/null)

echo "$OUT" | grep -q "Show uploaded certification card photos in the wallet" \
  || fail "PR title missing from the notes"
echo "$OUT" | grep -q "Fix unreliable S3 sync on mobile networks" \
  || fail "second PR title missing from the notes"
echo "$OUT" | grep -q "Raise the iOS deployment target to 15.0" \
  || fail "a commit pushed directly to main was dropped"

echo "$OUT" | grep -q "rename a variable" \
  && fail "a PR branch commit leaked into the notes instead of the PR title"
echo "$OUT" | grep -q "address review feedback" \
  && fail "a PR branch commit leaked into the notes instead of the PR title"
echo "$OUT" | grep -q "more branch work" \
  && fail "a PR branch commit leaked into the notes instead of the PR title"
echo "$OUT" | grep -qi "Merge origin/main" \
  && fail "a branch-sync merge leaked into the notes"
echo "$OUT" | grep -qi "^- Merge pull request" \
  && fail "a merge subject leaked into the notes instead of its PR title"

# A CRLF merge message must yield a clean title. The emptiness test in the
# extractor already ignores a carriage return, so the printed line has to be
# stripped of it too.
echo "$OUT" | grep -q "Add a CRLF titled change" \
  || fail "a CRLF-bodied PR title was dropped"
printf '%s' "$OUT" | grep -q $'\r' \
  && fail "a carriage return survived into the notes"

# --- Prose titles are bucketed, not discarded -------------------------------
# 71 of the last 120 PR titles on main are prose with no conventional prefix.
# Discarding them is what emptied the store notes, so a prose title is
# tester-facing work and is bucketed by its leading verb.

OUT=$(printf '%s\n' \
  'Fix unreliable S3 sync on mobile networks' \
  'Stop the Linux opening grant after the fallback has been taken' \
  'Show uploaded certification card photos in the wallet' \
  'Raise the iOS deployment target to 15.0' \
  | "$GEN" --stdin --format apple)

echo "$OUT" | grep -q "unreliable S3 sync" || fail "prose fix title was discarded"
echo "$OUT" | grep -q "certification card photos" || fail "prose feature title was discarded"
echo "$OUT" | grep -q "iOS deployment target" || fail "prose title with no fix verb was discarded"

# Split at the Fixed heading to confirm each title landed in the right bucket.
NEWWORK=$(echo "$OUT" | sed -n '1,/^Fixed$/p')
FIXWORK=$(echo "$OUT" | sed -n '/^Fixed$/,$p')

echo "$FIXWORK" | grep -q "unreliable S3 sync" || fail "a Fix-led title did not land under Fixed"
# Asserted on the part that survives sanitizing: this fixture's title names a
# platform, and the apple format redacts it. Bucketing happens before that, so
# the verb heuristic is still what this checks.
echo "$FIXWORK" | grep -q "opening grant" || fail "a Stop-led title did not land under Fixed"
echo "$NEWWORK" | grep -q "certification card photos" || fail "a Show-led title did not land under new work"

# A conventional prefix still wins over the prose heuristic, in both
# directions: an internal type stays internal even though it is not prose,
# and feat/fix/perf keep their existing mapping.
OUT=$(printf '%s\n' \
  'ci: retain the newest 30 beta releases' \
  'chore: bump deps' \
  'refactor: extract a helper' \
  | "$GEN" --stdin --format apple)
echo "$OUT" | grep -q "retain the newest 30" && fail "a ci-prefixed title reached the Apple notes"
echo "$OUT" | grep -q "bump deps" && fail "a chore-prefixed title reached the Apple notes"
echo "$OUT" | grep -q "extract a helper" && fail "a refactor-prefixed title reached the Apple notes"
echo "$OUT" | grep -qi "internal" || fail "an all-internal range should still say so"

# The message strip accepts ": *", so a colon with no space is still a
# conventional prefix. Requiring the space let "ci:foo" strip to "foo" and then
# fail the prefix test, classifying internal work as prose and shipping it.
OUT=$(printf '%s\n' 'ci:foo' 'chore:bar' 'docs:baz' | "$GEN" --stdin --format apple)
echo "$OUT" | grep -q "foo" && fail "a spaceless ci: prefix leaked into the Apple notes"
echo "$OUT" | grep -q "bar" && fail "a spaceless chore: prefix leaked into the Apple notes"
echo "$OUT" | grep -q "baz" && fail "a spaceless docs: prefix leaked into the Apple notes"

# A prose title with a colon later in the line is not a conventional prefix and
# must stay tester-facing.
OUT=$(printf '%s\n' 'Add site media: photos, videos, and documents' \
  | "$GEN" --stdin --format apple)
echo "$OUT" | grep -q "Add site media" \
  || fail "a prose title containing a colon was misread as a conventional prefix"

# --- The cumulative walk must stop at the range end, not HEAD ----------------
# Replaying an older build's notes while the working tree has advanced would
# otherwise fold every commit merged since into the cumulative section.

TMPREPO5=$(mktemp -d)
trap 'rm -rf "$TMPREPO" "$TMPREPO2" "$TMPREPO3" "$TMPREPO4" "$TMPREPO5"' EXIT
(
  cd "$TMPREPO5"
  git init -q -b main .
  git config user.email t@example.com
  git config user.name Test
  git commit -q --allow-empty -m 'feat: the shipped feature'
  git tag v0.0.1.1
  git rev-parse HEAD > .base
  git commit -q --allow-empty -m 'feat: inside the replayed range'
  git rev-parse HEAD > .end
  git commit -q --allow-empty -m 'feat: merged after the replayed build'
)
BASE5=$(cat "$TMPREPO5/.base")
END5=$(cat "$TMPREPO5/.end")

for fmt in apple markdown; do
  OUT=$(cd "$TMPREPO5" && "$GEN" --range "${BASE5}..${END5}" --format "$fmt" --cumulative 2>/dev/null) \
    || fail "--range with --cumulative failed for $fmt"
  echo "$OUT" | grep -q "inside the replayed range" \
    || fail "$fmt cumulative dropped a change inside the replayed range"
  echo "$OUT" | grep -q "merged after the replayed build" \
    && fail "$fmt cumulative walked past the range end to HEAD"
done

# --since always ends at HEAD, so it must be unaffected by the change.
OUT=$(cd "$TMPREPO5" && "$GEN" --since "$BASE5" --format markdown --cumulative 2>/dev/null)
echo "$OUT" | grep -q "merged after the replayed build" \
  || fail "--since stopped short of HEAD"

# --- The pipeline must actually ask for the cumulative section ---------------
# Supporting --cumulative is not the same as using it. The capped formats
# accepted the flag for a while before beta.yml passed it to them, so
# TestFlight and Play shipped the per-beta delta alone while the capability
# sat unused. Assert the wiring, not just the capability.

WORKFLOW="$SCRIPT_DIR/../../.github/workflows/beta.yml"
if [ -f "$WORKFLOW" ]; then
  for fmt in apple play markdown; do
    grep -A1 -- "--format $fmt" "$WORKFLOW" | grep -q -- "--cumulative" \
      || fail "beta.yml does not pass --cumulative for --format $fmt"
  done
fi

# --- The Apple format is named for its destination ---------------------------
# "store" was ambiguous: Google Play is a store too, and the file it produces
# feeds only the iOS and macOS TestFlight jobs. The rename is hard, so a stale
# --format store invocation must fail loudly rather than silently do nothing.
#
# "store" below is quoted deliberately: a blanket sed over "--format store"
# would otherwise rewrite this assertion to "--format apple" and invert what it
# checks, turning the guard into a test that the new name is rejected.

if printf '%s\n' 'feat: something' | "$GEN" --stdin --format "store" >/dev/null 2>&1; then
  fail "--format store was accepted; the rename to --format apple is incomplete"
fi

OUT=$(printf '%s\n' 'feat: something real' | "$GEN" --stdin --format apple)
echo "$OUT" | grep -q "something real" || fail "--format apple produced no items"

# --- Only the Apple format is sanitized --------------------------------------
# Apple bans references to other platforms in App Store metadata (guideline
# 2.3.10) and PR titles name them constantly. Google Play must NOT be
# sanitized: Android is not a banned word there.

PLATFORM_SUBJECTS=$(printf '%s\n' \
  'fix(android): stop the USB download crashing' \
  'feat: read the Windows certificate store' \
  'fix: parse raw data on Linux')

OUT=$(printf '%s\n' "$PLATFORM_SUBJECTS" | "$GEN" --stdin --format apple)
echo "$OUT" | grep -qi "android" && fail "Android reached the Apple notes"
echo "$OUT" | grep -q "Windows" && fail "Windows reached the Apple notes"
echo "$OUT" | grep -qi "linux" && fail "Linux reached the Apple notes"
echo "$OUT" | grep -q "stop the USB download crashing" \
  || fail "sanitizing dropped the rest of the item"

OUT=$(printf '%s\n' "$PLATFORM_SUBJECTS" | "$GEN" --stdin --format play)
echo "$OUT" | grep -q "Windows" || fail "play notes were sanitized; they must not be"

OUT=$(printf '%s\n' "$PLATFORM_SUBJECTS" | "$GEN" --stdin --format markdown)
echo "$OUT" | grep -q "Windows" || fail "markdown notes were sanitized; they must not be"

# An item that is nothing but a platform name leaves no bare heading behind,
# and the script's existing empty-body fallback takes over.
OUT=$(printf '%s\n' 'feat: Android' | "$GEN" --stdin --format apple)
echo "$OUT" | grep -q "New in this build" \
  && fail "a heading survived after its only item sanitized away"
echo "$OUT" | grep -q "no new changes were recorded" \
  || fail "the empty-body fallback did not fire after every item sanitized away"
[ -n "$OUT" ] \
  || fail "Apple notes came out empty; a tester reads that as 'the previous build's notes still apply'"

echo "PASS: all beta_release_notes tests passed"
