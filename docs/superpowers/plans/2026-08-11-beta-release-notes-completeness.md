# Beta Release Notes Completeness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the beta "what to test" notes describe the build on every
channel, by reading PR titles instead of prefixed commit subjects and by
extending the cumulative since-production section to the store formats.

**Architecture:** One file changes: `scripts/release/beta_release_notes.sh`.
Its `subjects_in_range()` switches from a `--no-merges` commit walk to a
first-parent walk that yields PR titles; its `classify_subjects()` buckets
prose titles by leading verb instead of discarding them; and the guard that
rejects `--cumulative` for the capped formats is removed so TestFlight and Play
carry both sections. No workflow file changes: `.github/workflows/beta.yml`
already generates all three formats once in `precheck` and shares them as the
`beta-notes` artifact, so every channel inherits the fix.

**Tech Stack:** bash 3.2 (macOS system bash must work), git, awk, POSIX
coreutils. Tests are plain bash scripts already wired into `ci.yaml`'s
`script-tests` job.

## Global Constraints

- Design spec: `docs/superpowers/specs/2026-08-11-beta-release-notes-completeness-design.md`.
- Work happens in the worktree `.claude/worktrees/beta-notes-completeness` on
  branch `fix/beta-notes-completeness`. Do not check this branch out in the
  main tree.
- TestFlight `whatsNew` cap is **4000** characters; Play release notes cap is
  **500** characters per locale. Both stores **reject** an over-limit body
  rather than truncating it.
- Output must never be empty: a blank `whatsNew` reads to a tester as "the
  previous build's notes still apply".
- All progress and diagnostics go to **stderr**; stdout is only ever the notes.
- No emojis in code, comments, or documentation.
- **Bash regexes must be held in a variable and used unquoted**
  (`re='...'; [[ "$s" =~ $re ]]`). Inlining a regex with an escaped trailing
  space (`[[ "$s" =~ ^(feat|fix)...:\  ]]`) silently fails to match. This was
  verified: the inline form matched 2 of 120 real PR titles where the same ERE
  in `grep -E` matched 49.
- `git describe` must always pass `--match 'v*.*.*.*'`. The repository carries
  Flutter's own 3-segment upstream tags and an unfiltered describe lands on
  one, producing a range of thousands of unrelated commits.
- Run the test script directly (`./scripts/release/beta_release_notes_test.sh`);
  it is not part of `flutter test`.

---

## File Structure

| File | Responsibility | Change |
| --- | --- | --- |
| `scripts/release/beta_release_notes.sh` | Turn a commit range into tester-facing notes in three formats | Modify: `subjects_in_range`, `classify_subjects`, cumulative gating, store rendering |
| `scripts/release/beta_release_notes_test.sh` | Behavioural tests for the above | Modify: add temp-repo cases, invert one assertion |
| `docs/superpowers/specs/2026-08-11-...-design.md` | Approved design | Already committed, read-only |

`.github/workflows/beta.yml` and `.github/workflows/ci.yaml` are **not**
modified. The test script is already registered in `ci.yaml`'s `script-tests`
job, which has no `if:` gate and always runs.

---

### Task 1: Read PR titles instead of branch commits

**Files:**
- Modify: `scripts/release/beta_release_notes.sh:157-160` (`subjects_in_range`)
- Test: `scripts/release/beta_release_notes_test.sh` (append before the final
  `echo "PASS: ..."` line)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `subjects_in_range <gitrange>` prints one line per mainline entry
  to stdout, and its progress line to stderr. Later tasks call it unchanged.

- [ ] **Step 1: Write the failing test**

Append to `scripts/release/beta_release_notes_test.sh`, immediately before the
final `echo "PASS: all beta_release_notes tests passed"` line:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./scripts/release/beta_release_notes_test.sh`

Expected: FAIL, with `FAIL: PR title missing from the notes`. The current
`--no-merges` walk emits the branch commits and drops the merge bodies.

- [ ] **Step 3: Replace the commit walk with a first-parent walk**

Replace `subjects_in_range()` at `scripts/release/beta_release_notes.sh:157-160`:

```bash
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
          if (line[i] ~ /[^ \t\r]/) { print line[i]; break }
      } else {
        print subject
      }
    }
  '
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./scripts/release/beta_release_notes_test.sh`

Expected: PASS for the new block. The pre-existing `--since` tests at lines
131-167 also still pass: their repositories have no merges, so every commit is
a first-parent commit and is emitted by its subject.

- [ ] **Step 5: Verify against real history**

Run, from the worktree:

```bash
git log --first-parent --format='%x01%P%x02%s%x02%b' \
  3322bea62b48d9e1da64d806d48e7731d4e6df5f..8ff9b87c7bd139ceb40c01bb54f6c525d10c95aa \
  | awk 'BEGIN{RS="\001";FS="\002"} NF<3{next} {p=$1;s=$2;b=$3; if(p~/ /){ if(s !~ /^Merge pull request #/) next; n=split(b,l,"\n"); for(i=1;i<=n;i++) if(l[i]~/[^ \t\r]/){print l[i];break} } else print s}'
```

Expected: exactly these four lines, in this order:

```
Fix unreliable S3 sync on mobile networks (#942)
Capture GPS reported as profile samples (fixes #926)
Show uploaded certification card photos in the wallet
Refresh the home photo ribbon when a photo is deleted
```

- [ ] **Step 6: Commit**

```bash
git add scripts/release/beta_release_notes.sh scripts/release/beta_release_notes_test.sh
git commit -m "fix(beta): read PR titles instead of PR branch commits

The notes generator walked commits with --no-merges, which reads a PR
branch's working commits and discards the merge commit whose body holds
the PR title. Those branch commits mostly carry no conventional prefix,
so they were bucketed as internal and never reached TestFlight or Play.

Walk main's first-parent line instead: a PR merge contributes its title,
a direct commit contributes its subject, and a merge made inside a PR
branch is not on the line at all."
```

---

### Task 2: Bucket prose titles instead of discarding them

**Files:**
- Modify: `scripts/release/beta_release_notes.sh:128-155` (`classify_subjects`)
- Test: `scripts/release/beta_release_notes_test.sh` (append before the final
  `echo "PASS: ..."` line)

**Interfaces:**
- Consumes: `subjects_in_range` from Task 1.
- Produces: `classify_subjects <subjects>` continues to set the four globals
  `FEATURES`, `FIXES`, `IMPROVEMENTS`, `INTERNAL`. Task 3 reads all four.

- [ ] **Step 1: Write the failing test**

Append to `scripts/release/beta_release_notes_test.sh`, before the final
`echo "PASS: ..."` line:

```bash
# --- Prose titles are bucketed, not discarded -------------------------------
# 71 of the last 120 PR titles on main are prose with no conventional prefix.
# Discarding them is what emptied the store notes, so a prose title is
# tester-facing work and is bucketed by its leading verb.

OUT=$(printf '%s\n' \
  'Fix unreliable S3 sync on mobile networks' \
  'Stop the Linux opening grant after the fallback has been taken' \
  'Show uploaded certification card photos in the wallet' \
  'Raise the iOS deployment target to 15.0' \
  | "$GEN" --stdin --format store)

echo "$OUT" | grep -q "unreliable S3 sync" || fail "prose fix title was discarded"
echo "$OUT" | grep -q "certification card photos" || fail "prose feature title was discarded"
echo "$OUT" | grep -q "iOS deployment target" || fail "prose title with no fix verb was discarded"

# Split at the Fixed heading to confirm each title landed in the right bucket.
NEWWORK=$(echo "$OUT" | sed -n '1,/^Fixed$/p')
FIXWORK=$(echo "$OUT" | sed -n '/^Fixed$/,$p')

echo "$FIXWORK" | grep -q "unreliable S3 sync" || fail "a Fix-led title did not land under Fixed"
echo "$FIXWORK" | grep -q "Linux opening grant" || fail "a Stop-led title did not land under Fixed"
echo "$NEWWORK" | grep -q "certification card photos" || fail "a Show-led title did not land under new work"

# A conventional prefix still wins over the prose heuristic, in both
# directions: an internal type stays internal even though it is not prose,
# and feat/fix/perf keep their existing mapping.
OUT=$(printf '%s\n' \
  'ci: retain the newest 30 beta releases' \
  'chore: bump deps' \
  'refactor: extract a helper' \
  | "$GEN" --stdin --format store)
echo "$OUT" | grep -q "retain the newest 30" && fail "a ci-prefixed title reached the store notes"
echo "$OUT" | grep -q "bump deps" && fail "a chore-prefixed title reached the store notes"
echo "$OUT" | grep -q "extract a helper" && fail "a refactor-prefixed title reached the store notes"
echo "$OUT" | grep -qi "internal" || fail "an all-internal range should still say so"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./scripts/release/beta_release_notes_test.sh`

Expected: FAIL with `FAIL: prose fix title was discarded`. Prose subjects
currently fall to `INTERNAL`, which the store format drops, so the output is
the "internal changes only" fallback.

- [ ] **Step 3: Declare the two regexes as globals**

Insert immediately after the `TRUNCATION_RESERVE=24` line at
`scripts/release/beta_release_notes.sh:37`:

```bash
# Held in variables and used unquoted: bash silently fails to match a regex
# written inline with an escaped trailing space, matching 2 of 120 real PR
# titles where the same expression in grep -E matched 49.
CONVENTIONAL_RE='^[a-z]+(\([^)]*\))?!?: '
FIX_VERB_RE='^(Fix|Fixes|Fixed|Stop|Stops|Resolve|Resolves|Correct|Corrects|Prevent|Prevents|Repair|Repairs|Restore|Restores) '
```

- [ ] **Step 4: Replace the catch-all arm of the classifier**

In `classify_subjects`, replace the final `case` arm at
`scripts/release/beta_release_notes.sh:144-145`, which currently reads:

```bash
      *)
        INTERNAL=$(append_line "$INTERNAL" "$message") ;;
```

with:

```bash
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
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `./scripts/release/beta_release_notes_test.sh`

Expected: PASS. Watch specifically that the pre-existing assertions at lines
25-42 still hold: `chore`, `ci`, `docs`, `test` and `refactor` subjects must
still be absent from store output, which the `CONVENTIONAL_RE` branch
preserves.

- [ ] **Step 6: Commit**

```bash
git add scripts/release/beta_release_notes.sh scripts/release/beta_release_notes_test.sh
git commit -m "fix(beta): bucket prose PR titles instead of discarding them

Only 49 of the last 120 PR titles on main carry a conventional prefix.
The other 71 fell to the internal bucket, which the store formats drop,
so most betas described themselves to testers as internal-only.

A title with a non-feat/fix/perf conventional prefix stays internal; a
prose title is bucketed by its leading verb, defaulting to new work."
```

---

### Task 3: Carry the cumulative section on the store formats

**Files:**
- Modify: `scripts/release/beta_release_notes.sh:95-100` (remove the guard),
  `:191-219` (markdown branch), `:221-254` (store rendering)
- Test: `scripts/release/beta_release_notes_test.sh:242-245` (invert), plus a
  new block before the final `echo "PASS: ..."` line

**Interfaces:**
- Consumes: `subjects_in_range` (Task 1), `classify_subjects` and its four
  globals (Task 2), and the existing `append_line`, `dedupe`, `add`,
  `add_section` helpers.
- Produces: `subtract <list> <remove>` prints `<list>` with every line that
  appears in `<remove>` removed, order preserved, and exits 0 even when
  everything is removed.

- [ ] **Step 1: Invert the assertion that forbids the combination**

Replace `scripts/release/beta_release_notes_test.sh:242-245`, which currently
reads:

```bash
# The cumulative section is meaningless for the length-capped store formats.
if (cd "$TMPREPO2" && "$GEN" --since "$PREV_BETA" --format store --cumulative) >/dev/null 2>&1; then
  fail "--cumulative was accepted for the store format"
fi
```

with:

```bash
# The capped formats carry the cumulative section too, truncated to fit. A
# tester arriving straight from the public release needs the whole picture,
# and TestFlight has 4000 characters to spend on it.
OUT=$(cd "$TMPREPO2" && "$GEN" --since "$PREV_BETA" --format store --cumulative 2>/dev/null)
echo "$OUT" | grep -q "a fix only in this beta" \
  || fail "store cumulative dropped this beta's own change"
echo "$OUT" | grep -q "an earlier beta feature" \
  || fail "store cumulative missing an earlier beta's change"
echo "$OUT" | grep -q "Since v0.0.1" \
  || fail "store cumulative heading missing or wrongly versioned"
echo "$OUT" | grep -q "Since v0.0.1.1" \
  && fail "store cumulative heading used the 4-segment tag, not the marketing version"
echo "$OUT" | grep -q "the shipped feature" \
  && fail "already-released work appeared in the store notes"

OUT=$(cd "$TMPREPO2" && "$GEN" --since "$PREV_BETA" --format play --cumulative 2>/dev/null)
echo "$OUT" | grep -q "an earlier beta feature" \
  || fail "play cumulative missing an earlier beta's change"
[ "${#OUT}" -le 500 ] || fail "play cumulative output exceeded the 500-character cap"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./scripts/release/beta_release_notes_test.sh`

Expected: FAIL. The script still calls `die` for
`--cumulative --format store`, so `$OUT` is empty and the first `grep -q`
fails with `FAIL: store cumulative dropped this beta's own change`.

- [ ] **Step 3: Remove the guard and resolve the baseline once**

Delete `scripts/release/beta_release_notes.sh:95-100` entirely:

```bash
# The store formats have a few hundred to a few thousand characters to spend on
# this build alone; a second, longer section would only crowd out the delta the
# tester is being asked to exercise.
if [ "$CUMULATIVE" = true ] && [ "$FORMAT" != markdown ]; then
  die "--cumulative applies to --format markdown only (got: $FORMAT)"
fi
```

Then insert, immediately after the `classify_subjects "$SUBJECTS"` call at
line 170:

```bash
# --- Resolve the cumulative baseline ----------------------------------------
# Only the app's own 4-segment tags are production releases. The repository
# also carries Flutter's 3-segment upstream tags, and per-beta tags live in
# the beta-builds repository, never here.
STABLE_TAG=""
if [ "$CUMULATIVE" = true ]; then
  STABLE_TAG=$(git describe --tags --abbrev=0 --match 'v*.*.*.*' 2>/dev/null || echo "")
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
```

- [ ] **Step 4: Rewrite the markdown branch to use the resolved tag**

Replace `scripts/release/beta_release_notes.sh:191-219` (the whole
`if [ "$FORMAT" = markdown ]; then ... fi` block) with:

```bash
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
  classify_subjects "$(subjects_in_range "${STABLE_TAG}..HEAD")"
  render_markdown "No changes recorded since $STABLE_TAG."
  exit 0
fi
```

- [ ] **Step 5: Add the cumulative section to the store rendering**

Replace `scripts/release/beta_release_notes.sh:241-243`, which currently reads:

```bash
add_section "New in this build" "$FEATURES"
add_section "Improved" "$IMPROVEMENTS"
add_section "Fixed" "$FIXES"
```

with:

```bash
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

  classify_subjects "$(subjects_in_range "${STABLE_TAG}..HEAD")"
  FEATURES=$(subtract "$FEATURES" "$BETA_FEATURES")
  IMPROVEMENTS=$(subtract "$IMPROVEMENTS" "$BETA_IMPROVEMENTS")
  FIXES=$(subtract "$FIXES" "$BETA_FIXES")

  # One flattened section rather than three: at a 500-character budget every
  # repeated heading costs an item. The marketing version reads better to a
  # tester than the 4-segment build tag, so v1.7.2.4977 becomes v1.7.2.
  EARLIER=$(printf '%s\n%s\n%s' "$FEATURES" "$IMPROVEMENTS" "$FIXES" | sed '/^$/d')
  add_section "Since ${STABLE_TAG%.*}" "$EARLIER"
fi
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `./scripts/release/beta_release_notes_test.sh`

Expected: PASS, including the pre-existing markdown cumulative assertions at
lines 191-223, which are unchanged because markdown keeps its complete list,
and the Play cap test at line 63.

- [ ] **Step 7: Verify the fallback still fires only when both sections are empty**

Run:

```bash
printf 'chore: bump deps\nci: tweak a workflow\n' \
  | ./scripts/release/beta_release_notes.sh --stdin --format store
```

Expected: the "This build contains internal changes only" sentence. With no
`--cumulative` and no tester-facing items, `LINES` is empty and the fallback
is correct.

- [ ] **Step 8: Commit**

```bash
git add scripts/release/beta_release_notes.sh scripts/release/beta_release_notes_test.sh
git commit -m "feat(beta): carry the since-production section on the store formats

TestFlight and Play rejected --cumulative, so a tester arriving from the
public release saw only the current beta's delta, and saw nothing at all
when that delta was internal. Both now carry the per-beta section first,
then everything since the last production tag, truncated to fit.

The cumulative list is deduplicated against the per-beta section in the
capped formats only, reclaiming roughly 200 of Play's 500 characters.
Markdown promises everything in its heading and keeps the full list."
```

---

### Task 4: Verify against real beta history

**Files:**
- No production changes expected. If this task finds a defect, fix it in
  `scripts/release/beta_release_notes.sh` and add the covering case to
  `scripts/release/beta_release_notes_test.sh`.

**Interfaces:**
- Consumes: the finished script from Tasks 1-3.
- Produces: nothing. This is a verification gate.

- [ ] **Step 1: Reproduce the reported build**

Run, from the worktree:

```bash
./scripts/release/beta_release_notes.sh \
  --range 3322bea62b48d9e1da64d806d48e7731d4e6df5f..8ff9b87c7bd139ceb40c01bb54f6c525d10c95aa \
  --format store 2>/dev/null
```

Expected: **not** the "internal changes only" sentence. The output must
contain "unreliable S3 sync", "profile samples", "certification card photos"
and "photo ribbon", split across a new-work heading and a `Fixed` heading.

This is the exact range that shipped build 1.7.3.5623 with a one-sentence
"What to Test".

- [ ] **Step 2: Check the store cap against a full release cycle**

Run:

```bash
./scripts/release/beta_release_notes.sh \
  --since 3322bea62b48d9e1da64d806d48e7731d4e6df5f \
  --format store --cumulative 2>/dev/null | wc -c

./scripts/release/beta_release_notes.sh \
  --since 3322bea62b48d9e1da64d806d48e7731d4e6df5f \
  --format play --cumulative 2>/dev/null | wc -c
```

Expected: store at or below 4000, play at or below 500. The cumulative list at
this point in the cycle is roughly 123 PR titles and 8160 characters, so both
must truncate, and the store output must end with "...and N more."

- [ ] **Step 3: Confirm no heading is left dangling**

Run:

```bash
./scripts/release/beta_release_notes.sh \
  --since 3322bea62b48d9e1da64d806d48e7731d4e6df5f \
  --format play --cumulative 2>/dev/null
```

Expected: every heading in the output is followed by at least one `- ` item.
A heading immediately followed by "...and N more." or by end-of-output means
the dangling-heading trim at lines 284-290 did not cover the new section.

- [ ] **Step 4: Confirm the markdown body still parses as the Sparkle input**

Run:

```bash
./scripts/release/beta_release_notes.sh \
  --since 3322bea62b48d9e1da64d806d48e7731d4e6df5f \
  --format markdown --cumulative 2>/dev/null \
  | ./scripts/generate_release_notes_html.sh | head -40
```

Expected: valid HTML with both `## ` headings rendered. This is the exact
pipeline `beta.yml:184` runs for the macOS and Windows update dialogs.

- [ ] **Step 5: Run the full script-test suite**

Run:

```bash
./scripts/release/beta_release_notes_test.sh
./scripts/release/generate_changelog_test.sh
./scripts/generate_release_notes_html_test.sh
./scripts/generate_appcast_beta_test.sh
```

Expected: all four print their PASS line. These are the scripts wired into
`ci.yaml`'s `script-tests` job.

- [ ] **Step 6: Commit any fixes**

If Steps 1-5 required a change:

```bash
git add scripts/release/beta_release_notes.sh scripts/release/beta_release_notes_test.sh
git commit -m "fix(beta): <what the real-history check found>"
```

If nothing needed fixing, skip this step. Do not create an empty commit.

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
| --- | --- |
| 1. PR titles as the unit of a note | Task 1 |
| 2. Bucket prose titles by leading verb | Task 2 |
| 3. Cumulative on every format, per-beta first, dedup in capped formats, marketing version, fallback only when both empty | Task 3 (Steps 3-7) |
| 4. Sparkle and GitHub inherit, Internal stays in markdown | Task 3 Step 4 (markdown keeps `render_markdown`, which emits Internal), verified Task 4 Step 4 |
| 5. Tests: PR title, branch-sync exclusion, direct commit, prose bucketing, prefix override, cumulative in store and play, per-beta survives truncation, caps respected | Task 1 Step 1, Task 2 Step 1, Task 3 Step 1, Task 4 Steps 2-3 |
| Out of scope: `generate_changelog.sh`, stable appcast, artifact shape, caps, non-empty guarantee | Not modified; `generate_changelog_test.sh` run as a regression guard in Task 4 Step 5 |

**Type consistency:** `subjects_in_range` and `classify_subjects` keep their
existing signatures and the four globals `FEATURES`, `FIXES`, `IMPROVEMENTS`,
`INTERNAL`. The one new function is `subtract`, defined in Task 3 Step 3 and
used in Task 3 Step 5. `STABLE_TAG` is set in Task 3 Step 3 and read in Steps
4 and 5. `CONVENTIONAL_RE` and `FIX_VERB_RE` are defined in Task 2 Step 3 and
used in Task 2 Step 4.

**Known risk:** Task 3 Step 5 reuses `classify_subjects`, which resets the four
globals on entry. The per-beta values are saved into `BETA_*` before the second
call and the `add_section` calls for the per-beta sections happen before it, so
the reset is safe. Any future edit that moves an `add_section` call below the
second `classify_subjects` would silently emit cumulative data under a per-beta
heading.
