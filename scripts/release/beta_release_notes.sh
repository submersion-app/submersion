#!/usr/bin/env bash
# Build the tester-facing "what to test" text for a beta build.
#
# The per-merge beta pipeline previously handed TestFlight and Play a fixed
# string ("Beta vX - automated per-merge build"), so testers had no way to tell
# what any given beta actually changed. This script turns the commit range
# between two betas into notes the stores will accept.
#
# Store fields have hard limits that differ per platform, and exceeding them
# fails the upload rather than truncating: Apple's TestFlight whatsNew caps at
# 4000 characters, Google Play's release notes at 500 per locale. Each format
# caps itself and says how many items it dropped.
#
# Usage:
#   beta_release_notes.sh --since <sha> --format apple    # <sha>..HEAD
#   beta_release_notes.sh --range <gitrange> --format play
#   beta_release_notes.sh --stdin --format markdown       # subjects on stdin
#
# An empty --since falls back to the last tag, so the first beta of a release
# still produces real notes.
#
# Formats:
#   apple     TestFlight whatsNew (plain text, 4000 chars). The only format
#             that reaches Apple, and so the only one with non-Apple platform
#             names stripped out of it.
#   play      Play release notes (plain text, 500 chars)
#   markdown  GitHub beta release body (uncapped, keeps internal work)
#
# --cumulative appends a second section covering everything since the last
# production tag, for a tester coming straight from the public release rather
# than from the previous beta. It applies to every format: the capped formats
# emit this build's own delta first and truncate the cumulative tail to fit,
# so the change a tester is asked to exercise is never the part that is cut.
#
# All progress and diagnostics go to stderr; stdout is only ever the notes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANITIZE="$SCRIPT_DIR/sanitize_apple_store_notes.py"

APPLE_LIMIT=4000
PLAY_LIMIT=500
# Room for the "...and N more." line appended after truncation.
TRUNCATION_RESERVE=24

# Held in variables and used unquoted: bash silently fails to match a regex
# written inline with an escaped trailing space, matching 2 of 120 real PR
# titles where the same expression in grep -E matched 49.
# The space after the colon is optional, matching the "): *" the message strip
# below accepts. Requiring it let "ci:foo" strip to "foo", miss this pattern,
# and be classified as prose - leaking internal work into the store formats.
# The leading [a-z]+ must run straight into the colon, so a prose title with a
# colon later in the line ("import dives from Garmin: USB") does not match.
CONVENTIONAL_RE='^[a-z]+(\([^)]*\))?!?:'
FIX_VERB_RE='^(Fix|Fixes|Fixed|Stop|Stops|Resolve|Resolves|Correct|Corrects|Prevent|Prevents|Repair|Repairs|Restore|Restores) '

RANGE=""
FORMAT=""
USE_STDIN=false
SINCE=""
SINCE_GIVEN=false
CUMULATIVE=false

die() { echo "beta_release_notes: $1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --range)  RANGE="${2:-}"; shift 2 ;;
    --since)  SINCE="${2:-}"; SINCE_GIVEN=true; shift 2 ;;
    --stdin)  USE_STDIN=true; shift ;;
    --cumulative) CUMULATIVE=true; shift ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --help|-h)
      sed -nE '2,/^$/s/^# ?//p' "$0"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

case "$FORMAT" in
  apple|play|markdown) ;;
  "") die "--format is required (apple, play, or markdown)" ;;
  *)  die "unknown --format: $FORMAT (expected apple, play, or markdown)" ;;
esac

# --since takes the previous beta's commit and turns it into a range. The
# pipeline knows that commit but not a git range, and on the very first beta it
# knows nothing: an empty value falls back to the last tag so the first beta
# still gets real notes instead of an error.
if [ "$SINCE_GIVEN" = true ]; then
  if [ -n "$SINCE" ]; then
    RANGE="${SINCE}..HEAD"
  else
    # Restricted to the app's own 4-segment tags (vX.Y.Z.BUILD). The repo also
    # carries Flutter's upstream tags, and an unfiltered describe can land on
    # one of those, producing a range of thousands of unrelated commits.
    LAST_TAG=$(git describe --tags --abbrev=0 --match 'v*.*.*.*' 2>/dev/null || echo "")
    if [ -n "$LAST_TAG" ]; then
      echo "No previous beta given; falling back to tag ${LAST_TAG}." >&2
      RANGE="${LAST_TAG}..HEAD"
    else
      echo "No previous beta and no tags; using full history." >&2
      RANGE="HEAD"
    fi
  fi
fi

if [ "$USE_STDIN" = false ] && [ -z "$RANGE" ]; then
  die "one of --range <gitrange>, --since <sha>, or --stdin is required"
fi

# The commit the notes are being written for. The cumulative section walks from
# the last production tag up to this, not to HEAD: replaying an older build's
# notes while the working tree has advanced would otherwise fold in everything
# merged since. --since always ends at HEAD, so only --range can differ.
RANGE_END="HEAD"
case "$RANGE" in
  "")      ;;                          # --stdin: no walk happens at all
  *..*)    RANGE_END="${RANGE##*..}" ;; # "A..B" ends at B; "A.." ends at HEAD
  *)       RANGE_END="$RANGE" ;;        # a bare revision, e.g. "HEAD"
esac
[ -n "$RANGE_END" ] || RANGE_END="HEAD"

# --- Sort subjects into tester-facing buckets -------------------------------
#
# Only feat/fix/perf describe something a tester can exercise. Everything else
# (chore, ci, docs, test, refactor, unconventional subjects) is internal: it is
# kept for the GitHub release body but withheld from the store fields, where
# the character budget is scarce and the audience is not the development team.

FEATURES=""
FIXES=""
IMPROVEMENTS=""
INTERNAL=""

append_line() {
  # $1 = current value, $2 = line. Emits the new value.
  if [ -z "$1" ]; then printf '%s' "$2"; else printf '%s\n%s' "$1" "$2"; fi
}

# Collapse duplicate subjects, preserving first-seen order. Cherry-picks and
# revert/reapply pairs otherwise list the same line several times.
dedupe() {
  [ -n "$1" ] || return 0
  printf '%s\n' "$1" | awk '!seen[$0]++'
}

# Fills the four bucket variables from the subjects passed as $1. Called more
# than once in cumulative mode, so it resets the buckets on entry.
classify_subjects() {
  FEATURES=""
  FIXES=""
  IMPROVEMENTS=""
  INTERNAL=""

  while IFS= read -r subject; do
    [ -n "$subject" ] || continue
    message=$(printf '%s' "$subject" | sed -E 's/^[a-z]+(\([^)]*\))?!?: *//')
    case "$subject" in
      feat\(*\)*:*|feat:*|feat!:*|feat\(*\)!:*)
        FEATURES=$(append_line "$FEATURES" "$message") ;;
      fix\(*\)*:*|fix:*|fix!:*|fix\(*\)!:*)
        FIXES=$(append_line "$FIXES" "$message") ;;
      perf\(*\)*:*|perf:*|perf!:*|perf\(*\)!:*)
        IMPROVEMENTS=$(append_line "$IMPROVEMENTS" "$message") ;;
      *)
        # Everything that is not feat/fix/perf. A subject with any other
        # conventional prefix (chore, ci, docs, test, refactor, build, style)
        # is internal by definition. A subject without one is a prose PR
        # title, which is real tester-facing work, so it is bucketed by its
        # leading verb rather than dropped.
        #
        # An infrastructure PR titled in prose therefore surfaces as
        # tester-facing. That is the deliberate direction of the error: the
        # defect being fixed is under-reporting, and prefixing the PR title
        # "ci:" keeps it internal when that is wanted.
        if [[ "$subject" =~ $CONVENTIONAL_RE ]]; then
          INTERNAL=$(append_line "$INTERNAL" "$message")
        elif [[ "$subject" =~ $FIX_VERB_RE ]]; then
          FIXES=$(append_line "$FIXES" "$message")
        else
          FEATURES=$(append_line "$FEATURES" "$message")
        fi
        ;;
    esac
  done <<EOF
$1
EOF

  FEATURES=$(dedupe "$FEATURES")
  FIXES=$(dedupe "$FIXES")
  IMPROVEMENTS=$(dedupe "$IMPROVEMENTS")
  INTERNAL=$(dedupe "$INTERNAL")
}

subjects_in_range() {
  echo "Reading commits in ${1}..." >&2
  # Walk the first-parent line of main. Each entry is either a PR merge, whose
  # body's first line is the PR title, or a commit made straight to main.
  #
  # A --no-merges walk read the PR branch's own commits instead, which are
  # working notes ("address review feedback") and mostly carry no conventional
  # prefix, so they were bucketed as internal and never reached the stores.
  #
  # --first-parent also excludes merges made *inside* a PR branch, so a
  # branch-sync merge ("Merge origin/main into <branch>") needs no special
  # case: it is not on this line.
  #
  # Records are separated by \001 and fields by \002 because a commit body is
  # multi-line and may contain anything else.
  git log --first-parent --format='%x01%P%x02%s%x02%b' "$1" | awk '
    BEGIN { RS = "\001"; FS = "\002" }
    NF < 3 { next }
    {
      parents = $1
      subject = $2
      body = $3
      if (parents ~ / /) {
        # More than one parent: a merge. Only GitHub PR merges describe user
        # work; anything else on this line is a manual merge and is skipped.
        if (subject !~ /^Merge pull request #/) next
        n = split(body, line, "\n")
        for (i = 1; i <= n; i++)
          # A CRLF commit message leaves a trailing carriage return on every
          # line. The emptiness test above already ignores it, so the title
          # must be stripped of it too or it rides into the store text.
          if (line[i] ~ /[^ \t\r]/) { sub(/\r$/, "", line[i]); print line[i]; break }
      } else {
        print subject
      }
    }
  '
}

# --- Collect commit subjects ------------------------------------------------

if [ "$USE_STDIN" = true ]; then
  SUBJECTS=$(cat)
else
  SUBJECTS=$(subjects_in_range "$RANGE")
fi

classify_subjects "$SUBJECTS"

# --- Resolve the cumulative baseline ----------------------------------------
# Only the app's own 4-segment tags are production releases. The repository
# also carries Flutter's 3-segment upstream tags, and per-beta tags live in
# the beta-builds repository, never here.
STABLE_TAG=""
if [ "$CUMULATIVE" = true ]; then
  # Described from the range end, not HEAD, so replaying an older build finds
  # the production tag that was current for that build.
  STABLE_TAG=$(git describe --tags --abbrev=0 --match 'v*.*.*.*' "$RANGE_END" 2>/dev/null || echo "")
  [ -n "$STABLE_TAG" ] \
    || echo "No production tag found; omitting the cumulative section." >&2
fi

# Remove from $1 every line that also appears in $2, order preserved. The
# cumulative range contains this beta's own commits; on Play, where the whole
# budget is 500 characters, printing them twice is the difference between
# showing the release and showing three lines of it.
subtract() {
  [ -n "$1" ] || return 0
  if [ -z "$2" ]; then printf '%s' "$1"; return 0; fi
  printf '%s\n' "$1" | grep -Fxv -f <(printf '%s\n' "$2") || true
}

# --- Markdown: the GitHub beta release body ---------------------------------

render_markdown() {
  local emitted=false
  emit_section() {
    [ -n "$2" ] || return 0
    [ "$emitted" = true ] && echo ""
    echo "### $1"
    echo ""
    printf '%s\n' "$2" | sed 's/^/- /'
    emitted=true
  }
  emit_section "New features" "$FEATURES"
  emit_section "Bug fixes" "$FIXES"
  emit_section "Performance" "$IMPROVEMENTS"
  emit_section "Internal" "$INTERNAL"
  [ "$emitted" = true ] || echo "$1"
}

if [ "$FORMAT" = markdown ]; then
  # Without --cumulative, or with no production tag to anchor to, the body is
  # exactly this beta's delta.
  if [ "$CUMULATIVE" = false ] || [ -z "$STABLE_TAG" ]; then
    render_markdown "No changes recorded since the previous beta."
    exit 0
  fi

  # With it, the per-beta delta is the headline and a second section carries
  # everything since the last production release, for a tester arriving
  # straight from the public build. This body is uncapped and its heading
  # promises everything, so it repeats this beta's items rather than
  # deduplicating them the way the capped formats do.
  echo "## New in this beta"
  echo ""
  render_markdown "No changes recorded since the previous beta."
  echo ""
  echo "## Everything since $STABLE_TAG"
  echo ""
  classify_subjects "$(subjects_in_range "${STABLE_TAG}..${RANGE_END}")"
  render_markdown "No changes recorded since $STABLE_TAG."
  exit 0
fi

# --- Capped formats: plain text within a hard character budget --------------

if [ "$FORMAT" = play ]; then LIMIT=$PLAY_LIMIT; else LIMIT=$APPLE_LIMIT; fi

# Build the full untruncated line list, tagging item lines so truncation can
# report how many were dropped and so a heading is never left dangling.
LINES=""
add() { LINES=$(append_line "$LINES" "$1"); }

add_section() {
  items="$2"

  # Apple bans references to other platforms in App Store metadata (App Review
  # guideline 2.3.10), and PR titles name them constantly. `apple` is the only
  # format that reaches Apple; `play` must NOT be sanitized, because Android is
  # not a banned word on Google Play, and `markdown` keeps everything for the
  # GitHub release body.
  #
  # This runs per item rather than over the finished body because the body is
  # assembled item by item and then truncated against a hard character budget:
  # sanitizing afterwards would invalidate that arithmetic and could re-orphan
  # a heading. An item left empty, or reduced to the replacement phrase alone,
  # is dropped so the heading above it is not left bare.
  if [ "$FORMAT" = apple ] && [ -n "$items" ]; then
    # The leading letter may be either case: an item is the start of its own
    # line, so the sanitizer capitalises a replacement that lands there.
    items=$(printf '%s\n' "$items" | "$SANITIZE" \
      | sed -e '/^[[:space:]]*$/d' \
            -e '/^[[:space:]]*[Oo]ther platforms[[:space:]]*$/d' \
            -e '/^[[:space:]]*[Aa]nother store[[:space:]]*$/d')
  fi

  [ -n "$items" ] || return 0
  [ -n "$LINES" ] && add "H:"
  add "H:$1"
  while IFS= read -r item; do
    [ -n "$item" ] && add "I:- $item"
  done <<EOF
$items
EOF
}

# This beta's delta is emitted first so that truncation only ever eats the
# cumulative tail: the change a tester is being asked to exercise is never the
# part that gets cut.
add_section "New in this build" "$FEATURES"
add_section "Improved" "$IMPROVEMENTS"
add_section "Fixed" "$FIXES"

if [ "$CUMULATIVE" = true ] && [ -n "$STABLE_TAG" ]; then
  BETA_FEATURES="$FEATURES"
  BETA_IMPROVEMENTS="$IMPROVEMENTS"
  BETA_FIXES="$FIXES"

  classify_subjects "$(subjects_in_range "${STABLE_TAG}..${RANGE_END}")"
  FEATURES=$(subtract "$FEATURES" "$BETA_FEATURES")
  IMPROVEMENTS=$(subtract "$IMPROVEMENTS" "$BETA_IMPROVEMENTS")
  FIXES=$(subtract "$FIXES" "$BETA_FIXES")

  # One flattened section rather than three: at a 500-character budget every
  # repeated heading costs an item. The marketing version reads better to a
  # tester than the 4-segment build tag, so v1.7.2.4977 becomes v1.7.2.
  EARLIER=$(printf '%s\n%s\n%s' "$FEATURES" "$IMPROVEMENTS" "$FIXES" | sed '/^$/d')
  add_section "Since ${STABLE_TAG%.*}" "$EARLIER"
fi

if [ -z "$LINES" ]; then
  if [ -n "$INTERNAL" ]; then
    echo "This build contains internal changes only - build, CI, refactoring," \
      "and test work. Please retest your usual workflows and report anything" \
      "that behaves differently."
  else
    echo "This beta matches the previous build; no new changes were recorded."
  fi
  exit 0
fi

# Accumulate lines until the next one would breach the budget, then keep
# scanning to count the items left out.
OUT=""
dropped=0
truncated=false

while IFS= read -r tagged; do
  kind="${tagged%%:*}"
  line="${tagged#*:}"

  if [ "$truncated" = true ]; then
    [ "$kind" = "I" ] && dropped=$((dropped + 1))
    continue
  fi

  if [ -z "$OUT" ]; then candidate="$line"; else candidate="$OUT"$'\n'"$line"; fi
  if [ "${#candidate}" -gt $((LIMIT - TRUNCATION_RESERVE)) ]; then
    truncated=true
    [ "$kind" = "I" ] && dropped=$((dropped + 1))
    continue
  fi
  OUT="$candidate"
done <<EOF
$LINES
EOF

# Truncation can leave a heading with nothing under it, which reads as though
# that section were empty rather than cut.
while [ -n "$OUT" ]; do
  last="${OUT##*$'\n'}"
  case "$last" in
    "- "*) break ;;
    *) if [ "$last" = "$OUT" ]; then OUT=""; else OUT="${OUT%$'\n'*}"; fi ;;
  esac
done

if [ "$dropped" -gt 0 ]; then
  if [ -n "$OUT" ]; then
    OUT="$OUT"$'\n'"...and $dropped more."
  else
    OUT="...and $dropped more."
  fi
fi

printf '%s\n' "$OUT"
