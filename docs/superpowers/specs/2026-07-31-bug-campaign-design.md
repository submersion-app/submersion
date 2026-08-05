# Bug Campaign: Triage and Fix All Open Bug-Type Issues

Date: 2026-07-31
Status: Approved design, pending user spec review
Scope snapshot: 43 open issues with GitHub issue type "Bug" as of 2026-07-31

## Goal

Every open Bug-type issue ends this campaign with an explicit disposition:
closed as fixed, closed as duplicate/stale, an open PR that fixes it, or a
needs-info comment. Fixes are delivered as one large batch of PRs, one
worktree and one PR per issue.

## Out of scope

- Issues without the "Bug" issue type, even if bug-like (#746, #731, #707,
  #700, #699, #767). They receive at most a consolidation comment if a
  Bug-typed issue duplicates them.
- Speculative fixes for hardware-dependent dive computer bugs whose defect
  cannot be proven from source, logs, or protocol documentation alone.
- Feature work discovered along the way (file separately).

## Phase 0: Triage and consolidation (before any fix work)

Every "close" below is gated on verifying the claim against current main
(reading the fixing PR diff or the relevant code path). Nothing closes on
memory or assumption alone.

### 0a. Close as fixed (verify, cite fixing PR, invite reopen)

| Issue | Basis to verify |
| --- | --- |
| #280 OSTC nano BLE download | Fix merged (251840755c1); reporter confirmed working |
| #737 sync passphrase error | PR #770 (pure-Dart HKDF pin); ships in 1.7.1.118 |
| #758 edit site from dive shows dive editor | PR #760 embedded dive-to-site navigation |
| #648 overdue maintenance opens wrong menu | PRs #740/#743 dashboard routing; reporter retested pre-fix build |
| #57 deco data wrong after Subsurface import | PRs #751/#754 ceiling mapping; if partial, comment narrowing remaining scope instead of closing |
| #358 iCloud sync crash on iOS | OOM/adopt fixes (adf2fee, 98b54b6, 5b7ed90); reporter silent since confirm request |
| #141 dive planner broken in Imperial | Planner redesign (#485-491) + unit fixes (#739); verify imperial path end to end |
| #154 Android "no such column: d.min_temperature" | April-era schema report; verify migration ladder covers the column, close as resolved-by-migration |
| #680 sync PathNotFoundException | Reconnaissance traced it to the #554 sync-temp-dir fix (commit 3fe1b3a), shipped in 1.7.0.117; reporter was on 1.6.0.114 |

### 0b. Close as duplicate or stale (comment pointing at canonical issue)

Consolidation is by root cause, not vendor.

| Issue | Disposition |
| --- | --- |
| #31 Windows Teric/Perdix/Deep6 failures | Stale (v1.3.x era, DC subsystem rewritten; last comment shows Perdix 2 working). Close with retest request; canonical for any surviving download failure is #759 |
| #39 Windows add-computer crash (v1.3.2) | Stale; close with retest request |
| #148 Subsurface sites not assigned to dives | Fold into #153 (Subsurface import quality umbrella) after checking current importer behavior |

Shearwater issues deliberately NOT merged: #723 (recognition), #766
(Android pairing), #759 (download fails after dive list; canonical for the
#480/#621 regression line) are distinct root-cause classes.

### 0c. Needs-info comment, leave open, no code

#543 (temperature graph, awaiting feedback), #291 (Suunto Vyper USB,
awaiting feedback), #267 (Peregrine Linux BLE, logs already requested),
#146 (EON Core Android 16 crash: request crash log), #147 (OSTC 2 BT:
retest request post-#682), #766 (Petrel 3 Android pairing: request debug
logs).

#623 (Statistics bug) is only a Reddit link: fetch the thread, write the
actual repro into the issue as a comment, then classify it into fix list
or needs-info.

#425 (linked photos missing on iCloud-synced device) was reported on
1.5.6.108; the media pipeline has since been rewritten (media store
phases, #713/#727). Comment asking for a retest on current version.

#153 (Subsurface import quality umbrella) stays open as the canonical
umbrella; comment summarizing what the campaign fixes concretely (#756)
and what #148's verification found.

### 0d. Investigate, fix only if provable without hardware

#590 (OSTC4 misidentified as OSTC 2: recognition-table class, likely
provable), #723 (Perdix 3 BLE recognition), #732 (Aeris Epic "No USB
serial ports found": FTDI enumeration), #143 (EON Steel USB ID), #123
(Suunto Ocean Android: debug logs attached to issue, read them), #759
(Shearwater download fails after dive list: canonical for the #480/#621
regression line, which has traced history in the libdivecomputer fork's
oldest-first logic and may be provable from it).

Provable means: the defect is demonstrable from libdivecomputer source,
device ID/recognition tables, attached logs, or protocol documentation,
and the fix is testable without the device. Otherwise the issue gets a
findings comment and moves to needs-info.

## Phase 1: Fix campaign (one large batch)

Fix list (own worktree + own PR each): #765, #764, #757, #756, #736,
#647, #644, #636, #222, #218, #214, #190, #158, #152, #110, #71, plus
the DC fixes reconnaissance proved provable (#590 recognition matcher,
#143 transport mislabel), plus #623 if the Reddit repro pans out.
(#680 moved to close-as-fixed and #732 to needs-info after
reconnaissance; see the implementation plan.)

Execution model:

- All fixes launch together as parallel subagent tasks; no review/merge
  gates between fixes. All PRs are delivered as a single review pass.
- Launches are staggered a few at a time only for CPU/codegen contention,
  not for sequencing.
- Known file collision: #158 and #71 both touch the UDDF importer. The
  second branches off the first's branch; its PR notes the dependency.
  Any other collision discovered mid-flight is handled the same way.
- Two issues collapsing into one root cause mid-fix produce one PR with
  "Fixes #a, fixes #b" and a comment on both issues.

Per-fix workflow (identical for every issue):

1. Create worktree; run `git submodule update --init --recursive`,
   `flutter pub get`, `dart run build_runner build
   --delete-conflicting-outputs` (worktrees inherit none of these).
2. Reproduce the bug as a failing test FIRST (systematic-debugging +
   test-driven-development skills). No PR ships without a test that fails
   pre-fix.
3. Minimal root-cause fix; respect active diver unit settings for
   anything unit-facing.
4. `dart format .`, `flutter analyze` (whole project, infos are fatal in
   CI), full test suite.
5. PR titled `fix(<area>): <summary>` with `Fixes #N`. No Claude
   attribution lines or session URLs in the PR body (CLAUDE.md rule).
   Push with `env -u GITHUB_TOKEN` so gh uses the keyring token.

## Error handling

- Cannot reproduce: post findings comment on the issue, reclassify as
  needs-info, no PR.
- Scope balloons (schema migration, cross-cutting refactor, design
  decision needed): stop that fix, surface to the user, do not ship a
  surprise PR. The rest of the batch continues.
- Subagent failure or dead worktree: reassign the issue to a fresh
  worktree; never commit from a half-initialized tree.

## Success criteria

- All 43 Bug-type issues have an explicit disposition recorded on GitHub.
- Every fix PR contains a test that fails without the fix.
- Every PR is green on CI (format, analyze, tests) at delivery.
- Duplicate clusters are consolidated with cross-linking comments before
  fix PRs open.

## Constraints and conventions

- GitHub operations via `env -u GITHUB_TOKEN gh ...`.
- Verify `pwd` before trusting any command output inside worktrees (cwd
  can silently reset to the main checkout).
- New test files can make the pre-push hook abort silently; if a push
  dies with no output, retry with the hook's documented escape hatch
  rather than force-pushing.
- Commits only within each fix's worktree branch; no direct commits to
  main except this spec and the plan document.
