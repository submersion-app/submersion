# Beta release notes completeness

Date: 2026-08-11
Status: approved, ready for implementation planning

## Problem

TestFlight's "What to Test" text for beta builds is frequently a single
sentence:

> This build contains internal changes only - build, CI, refactoring, and test
> work. Please retest your usual workflows and report anything that behaves
> differently.

Build 1.7.3.5623 shipped that text while its commit range contained four
genuinely tester-facing changes: an S3 sync fix on mobile networks (#942), GPS
capture as profile samples (#926), certification card photos in the wallet, and
a home photo ribbon refresh.

### Root cause A: the classifier requires conventional-commit prefixes

`scripts/release/beta_release_notes.sh` reads commit subjects with
`git log --format='%s' --no-merges` and buckets them by literal `feat:` /
`fix:` / `perf:` prefixes. Every other subject falls to `INTERNAL`, and only
the first three buckets reach the store formats. When a range contains no
prefixed commit, the store text falls through to the non-empty fallback.

Measured on `main`: of the last 300 non-merge commits, **42 (14%)** carry a
`feat` / `fix` / `perf` prefix. The remaining 86% are prose subjects written on
PR branches.

The descriptive, tester-facing summary of each change lives in the **PR title**,
which this repository stores as the first body line of the merge commit — and
`--no-merges` discards exactly that.

### Root cause B: `--cumulative` is markdown-only by design

Line 98 rejects `--cumulative` for the `store` and `play` formats, so
TestFlight and Play have never carried the "everything since the last
production release" section.

### This is not a regression

The script has not been modified since it was introduced on 2026-08-06
(`git log -S'CUMULATIVE'` returns a single commit, 69c79183601). PR #918, the
suspected cause, is additive-only (67 insertions, 0 deletions) and touches the
Sparkle appcast HTML path, not this script.

Replaying the current script against every beta range since the pipeline
shipped, using each build's real `sourceSha` from its published
`metadata.json`, produces the "internal changes only" fallback **7 times before
#918 and 4 times after**. What changed is range size: builds 5090-5187 covered
multi-day ranges and produced 20-33 items; the per-merge cadence now covers 2-4
PRs per beta, and a 3-PR range frequently contains zero prefixed commits.

## Channel map

Beta notes are generated once in `beta.yml`'s `precheck` job (the only job with
`fetch-depth: 0`) and shared as the `beta-notes` artifact, so every lane
describes the build identically.

| Channel | Source | Before | After |
| --- | --- | --- | --- |
| TestFlight (iOS + macOS) | `store`, 4000 char cap | Often the fallback sentence | Per-beta delta plus cumulative, truncated to fit |
| Play open testing | `play`, 500 char cap | Often the fallback sentence | Per-beta delta plus cumulative, truncated to fit |
| Sparkle beta (macOS DMG, Windows EXE) | `markdown --cumulative` via `generate_release_notes_html.sh` | Complete but noisy: 546 lines for build 5623 | Same structure, roughly 130 lines of PR titles |
| GitHub beta release body | `markdown --cumulative` | Same as Sparkle | Same as Sparkle |

`generate_changelog.sh` and the stable Sparkle/appcast path are **out of
scope**: unprefixed commits fall into its `other` bucket (line 128), which the
output loop emits (line 152), so production update dialogs are already
complete.

## Design

### 1. PR titles as the unit of a note

Replace `subjects_in_range()`'s `--no-merges` walk with a first-parent walk of
`main`:

```
git log --first-parent <range>
  merge whose subject matches "Merge pull request #N from ..."
      -> first non-empty line of %b (the PR title)
  any other first-parent commit
      -> its subject (direct push to main, or a squash merge)
```

`--first-parent` excludes merges made *inside* a PR branch. The 5605..5623
range contains "Merge origin/main into the certification wallet card photos
branch"; that commit is not on main's first-parent line and is dropped without
a special case.

One walk covers the merge-PR flow, squash merges, and direct pushes, so no
separate fallback mode is needed. Over the last 120 mainline entries the walk
yields 111 PR merges and 9 direct commits, with nothing unclassifiable.

`--stdin` keeps its current meaning (classify the subjects given) so the
existing unit tests remain valid.

### 2. Bucket prose titles instead of discarding them

Of those 120 PR titles, 49 carry a conventional prefix and 71 are prose.

- **Prefixed** titles keep today's mapping: `feat` / `fix` / `perf` are
  tester-facing; `chore` / `ci` / `docs` / `test` / `refactor` / `build` /
  `style` are internal.
- **Prose** titles are bucketed by leading verb. `Fix`, `Fixes`, `Fixed`,
  `Stop`, `Stops`, `Resolve`, `Resolves`, `Correct`, `Corrects`, `Prevent`,
  `Prevents`, `Repair`, `Restore` map to **Fixed**. Every other prose title
  maps to **New in this build**.

The verb list is drawn from the observed data: the 71 prose titles lead with
`Fix` 13 times, `Add` 9 times, `Show` 3 times, `Stop` twice, and a long tail of
other imperative verbs.

**Accepted trade-off:** an infrastructure PR titled in prose (for example
"Raise the iOS deployment target to 15.0") surfaces as tester-facing. That is
the deliberate direction of the error, because the defect being fixed is
under-reporting. Conventional prefixes still take precedence, so titling a PR
`ci: ...` keeps it internal when that is wanted.

### 3. Cumulative section on every format

Remove the guard at line 98 that rejects `--cumulative` for `store` and `play`.
All three formats then render two sections: the per-beta delta, then everything
since the last production tag.

Two supporting rules:

- **The per-beta section is emitted first.** Truncation consumes only the
  cumulative tail, so the "what to test" ask is never the part that gets cut.
- **Cumulative items are deduplicated against the per-beta list in the capped
  formats only.** On Play that reclaims roughly 200 of 500 characters. Markdown
  is uncapped and its heading promises "Everything since <tag>", so it keeps
  the complete list and repeats this beta's items, as it does today. This also
  leaves the existing markdown assertions in
  `beta_release_notes_test.sh:191-223` valid unchanged.

The last production tag is resolved with the existing
`git describe --tags --abbrev=0 --match 'v*.*.*.*'`, which is restricted to the
app's own four-segment tags because the repository also carries Flutter's
upstream three-segment tags. Per-beta tags live in the `beta-builds`
repository, never here, so the describe lands on the last production release.

**Sizing.** At build 5623 the cumulative list is 123 PR titles, about 8160
characters rendered. That exceeds TestFlight's 4000 cap as well as Play's 500,
so mid-release both stores truncate:

- TestFlight: the per-beta delta plus roughly 55 cumulative items and
  "...and 68 more."
- Play: the per-beta delta plus 2-3 cumulative items and "...and ~120 more."

Early in a release cycle both fit without truncation. The existing truncator
handles the cap and already refuses to leave a heading with nothing beneath it
(lines 284-290).

The store and play cumulative heading uses the marketing version rather than
the four-segment tag: strip the final dot-segment, so `v1.7.2.4977` renders as
"Since v1.7.2". Markdown keeps the full tag, as it does today.

**Fallback interaction.** The "internal changes only" text at line 247 now
fires only when *both* sections are empty of tester-facing items. A beta whose
own delta is entirely internal but which follows tester-facing work earlier in
the release emits an empty per-beta section plus a populated cumulative
section, not the fallback sentence.

### 4. Sparkle and the GitHub release body

No workflow change. `beta.yml:184` already copies `beta-notes.md` into the
Sparkle HTML pipeline, so both inherit the PR-title fix automatically.

The `Internal` section stays in the markdown format for both channels. PR
titles alone cut build 5623's Sparkle body from 546 lines to roughly 130.

### 5. Tests

`scripts/release/beta_release_notes_test.sh` is 247 lines of `--stdin` cases,
which cannot exercise a git walk. Add temp-repo cases following the pattern
`scripts/release/generate_changelog_test.sh` established in PR #918: a scratch
repository containing a PR merge, a branch-sync merge, a direct commit, and a
production tag.

New assertions:

- A PR merge contributes its title, not its branch commits.
- A branch-sync merge contributes nothing.
- A direct commit on main contributes its subject.
- A prose title leading with `Fix` lands under Fixed; other prose lands under
  new work.
- A conventional prefix still overrides the prose heuristic in both directions.
- `store` and `play` both emit the cumulative section.
- The per-beta section survives truncation when the cumulative section
  overflows.
- Play output stays at or below 500 characters; store at or below 4000.
- A beta with an all-internal delta but tester-facing work earlier in the
  release emits the cumulative section rather than the fallback sentence.
- The fallback sentence still appears when both sections are empty.

The existing assertion at line 243, that `--cumulative --format store` fails,
inverts.

## Out of scope

- `generate_changelog.sh` and the stable Sparkle/appcast path.
- The `precheck`-generates-once architecture and the `beta-notes` artifact
  shape.
- The store character caps.
- The guarantee that output is never empty: a blank TestFlight `whatsNew` reads
  to a tester as "the previous build's notes still apply", so the fallback text
  at line 247 stays, it just becomes rare.
