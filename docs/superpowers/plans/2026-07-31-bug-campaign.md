# Bug Campaign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every one of the 43 open Bug-type GitHub issues an explicit disposition (closed-fixed, closed-duplicate/stale, needs-info comment, or an open PR that fixes it), with all fix PRs delivered as one large parallel batch.

**Architecture:** Phase 0 acts directly on GitHub issues (verify-then-close, consolidate, request info) with no code changes. Phase 1 launches one worktree + one PR per fix, all in parallel, each following an identical failing-test-first protocol. Spec: `docs/superpowers/specs/2026-07-31-bug-campaign-design.md`.

**Tech Stack:** Flutter 3.x, Drift ORM, Riverpod, go_router, vendored libdivecomputer fork, `gh` CLI.

## Global Constraints

- Repo: `submersion-app/submersion`. All `gh` calls: `env -u GITHUB_TOKEN gh ...` (a stale env token shadows the keyring).
- PR bodies: substantive summary only. NEVER include "Generated with Claude Code" attribution or session URLs (CLAUDE.md rule).
- PR titles: `fix(<area>): <summary>`. Body must contain `Fixes #N` for every issue the PR closes.
- Every fix PR must contain a test that fails without the fix. No fix without a reproducing test.
- Before any commit: `dart format .` (whole project). Before any push: `flutter analyze` (whole project; infos are fatal in CI) and `flutter test`.
- Worktree creation (per fix task):

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git worktree add .claude/worktrees/fix-<ISSUE> -b fix/<ISSUE>-<slug> origin/main
cd .claude/worktrees/fix-<ISSUE>
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

- The shell cwd can silently reset to the main checkout between commands: run `pwd` before trusting any build/test/grep output inside a worktree.
- If `git push` dies with exit 1 and no output, the pre-push hook aborted on new test files. Tests were already run locally, so retry as `SKIP_TESTS=1 git push`. Never force-push around it.
- Push branches to `origin`; PRs target `main`.
- Anything displaying units must respect the active diver's unit settings.
- Any user-visible string added or changed must use AppLocalizations with translations in ALL 10 non-English ARB locales, then l10n regen.
- Scope-balloon rule: if a fix requires a schema migration, cross-cutting refactor, or a product decision, STOP that task and report back; do not ship it.
- Comment templates used by Phase 0 tasks:
  - CLOSE-FIXED: "Verified fixed on current main by PR #<PR> (<one-line what changed>). Ships in v1.7.1.118. Closing — please reopen if it persists on 1.7.1.118 or later."
  - STALE: "This was reported against v1.3.x; the dive-computer subsystem has been substantially rewritten since (BLE identity handling, serial transport, per-vendor fixes). Closing as stale — if this still occurs on v1.7.x, please open a fresh report with debug logs (enable Debug mode in Settings). <extra>"
  - NEEDS-INFO: issue-specific text given inside each task.

---

## Phase 0: Triage and consolidation (no code changes)

### Task 1: Verify-and-close the already-fixed set (#280, #737, #358)

These three need no code reading beyond confirming the commits exist on main.

**Files:** none (GitHub only).

**Interfaces:**
- Consumes: nothing.
- Produces: issues #280, #737, #358 closed with CLOSE-FIXED comments.

- [ ] **Step 1: Confirm the fixing commits are on origin/main**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git log --oneline origin/main | grep -E "251840755c1|1b0e7bafd8c|adf2fee6366"
```

Expected: all three commit hashes print. If any is missing, STOP and report.

- [ ] **Step 2: Close #280** (fix merged AND reporter confirmed complete downloads work)

```bash
env -u GITHUB_TOKEN gh issue close 280 -R submersion-app/submersion -r completed \
  -c "Verified fixed on current main by commit 251840755c1 (OSTC nano / hw_ostc3 BLE downloads), and confirmed working by the reporter after the hwOS Tech O2 firmware note. Ships in v1.7.1.118. Closing — please reopen if it persists on 1.7.1.118 or later."
```

- [ ] **Step 3: Close #737**

```bash
env -u GITHUB_TOKEN gh issue close 737 -R submersion-app/submersion -r completed \
  -c "Verified fixed on current main by PR #770 (pins a pure-Dart HKDF for sync data-key derivation, fixing the empty-key failure on Android). Ships in v1.7.1.118. The earlier retest failed because the PR test APK is debug-signed and cannot install over the release build. Closing — please reopen if the passphrase error persists on 1.7.1.118 or later."
```

- [ ] **Step 4: Close #358**

```bash
env -u GITHUB_TOKEN gh issue close 358 -R submersion-app/submersion -r completed \
  -c "The crash class reported here (large-library iCloud adopt running out of memory ~20s after startup) was fixed by three changes on main: delete-all-then-insert bounded adopt memory (adf2fee), batched adopt upserts (98b54b6), and device-local settings preservation on Replace-adopt (5b7ed90). No response since the v1.6.0 confirm request. Closing — please reopen with debug logs if it still crashes on v1.7.x."
```

- [ ] **Step 5: Record dispositions** — append one line per closed issue to `docs/superpowers/plans/2026-07-31-bug-campaign-log.md` (create it: `# Campaign disposition log`, then `- #<N>: closed-fixed, <PR/commit>`). Commit the log at the end of Phase 0, not per task.

### Task 1b: Verify-and-close #680 (fixed by the #554 sync temp dir fix)

Reconnaissance finding: the reported PathNotFoundException matches commit `3fe1b3abadf` "fix(sync): create the sync temp dir before writing (macOS #554)", which landed after v1.6.1+116 and first shipped in 1.7.0+117. The reporter was on 1.6.0.114. Every `Directory(...).create` in the sync tree is already `recursive: true`, and the Dropbox provider has no local directory at all — the shared local temp dir is the only candidate path, and it is fixed.

**Files:** none (GitHub only).

**Interfaces:**
- Consumes: nothing.
- Produces: #680 closed; log updated.

- [ ] **Step 1: Confirm the fix commit is on origin/main**

```bash
git log --oneline origin/main | grep 3fe1b3abadf
```

Expected: one line. If missing, STOP and report.

- [ ] **Step 2: Close #680**

```bash
env -u GITHUB_TOKEN gh issue close 680 -R submersion-app/submersion -r completed \
  -c "Root cause found: the sync engine wrote its base file into a temp directory that was never created on a fresh install — exactly why manually creating the folder fixed it. This was fixed on main (commit 3fe1b3a, 'create the sync temp dir before writing') and first shipped in 1.7.0.117; your report was filed from 1.6.0.114. Closing — please reopen if a fresh install of 1.7.0.117+ still throws PathNotFoundException on first sync."
```

- [ ] **Step 3: Record in the disposition log.**

### Task 2: Diff-verify then close-or-demote #758, #648, #57

These claim recent PRs fixed them; the PR diffs must be read against the reported repro before closing.

**Files:** read-only inspection of merged PR diffs.

**Interfaces:**
- Consumes: nothing.
- Produces: each of #758, #648, #57 either closed with CLOSE-FIXED or left open with a scope-narrowing comment; verdicts recorded in the disposition log; any not-fixed issue reported back to the orchestrator for promotion into Phase 1.

- [ ] **Step 1: Verify #758 against PR #760**

```bash
env -u GITHUB_TOKEN gh pr diff 760 -R submersion-app/submersion
```

Decision rule: the reported repro is dive detail -> "View Site" -> pencil icon opens Edit DIVE instead of Edit Site. If the diff changes the embedded site view's edit action (or the dive->site navigation so the site detail page owns the pencil), close with CLOSE-FIXED citing #760. If the diff only fixes navigation TO the site but not the pencil target, comment what remains and leave open; report to orchestrator.

- [ ] **Step 2: Verify #648 against PRs #740 and #743**

```bash
env -u GITHUB_TOKEN gh pr diff 740 -R submersion-app/submersion
env -u GITHUB_TOKEN gh pr diff 743 -R submersion-app/submersion
grep -rn "overdue" lib/features/home/ lib/features/dashboard/ --include=*.dart -il
```

Decision rule: find the home/dashboard overdue-maintenance chip's onTap. If it now routes to the equipment page (`/equipment`), close with CLOSE-FIXED citing #740/#743 and note the reporter's retest was on pre-fix 1.7.0.117. If it still routes to settings, leave open; report to orchestrator (promote to Phase 1 fix list).

- [ ] **Step 3: Verify #57 against PRs #751 and #754**

```bash
env -u GITHUB_TOKEN gh pr diff 751 -R submersion-app/submersion
env -u GITHUB_TOKEN gh pr diff 754 -R submersion-app/submersion
```

Decision rule: #57 has two claims: (a) imported Subsurface deco dives show as no-deco; (b) home page dive counts ignore freshly imported dives. #751/#754 map stopdepth/decostop to sample ceilings, which addresses (a). For (b), check whether the home stale-dives issue (#217 class) was separately fixed: `git log --oneline origin/main | grep -i "home" | head -20`. If (a) fixed but (b) unverifiable, comment: "The deco-detection half of this is fixed on main by #751/#754 (Subsurface/UDDF stop depths now map to sample ceilings; ships in 1.7.1.118). If the home-page counts issue still reproduces on 1.7.1.118, please comment and we'll split it into its own issue." Leave open only if (b) is confirmed still broken on current code; otherwise close as fixed with that comment.

- [ ] **Step 4: Record all three verdicts in the disposition log.**

### Task 3: Code-verify then close-or-demote #141 and #154

**Files:** read-only inspection of `lib/features/planner/` (or `lib/features/planning/`) and `lib/core/database/database.dart` migration ladder.

**Interfaces:**
- Consumes: nothing.
- Produces: #141 and #154 closed or demoted to Phase 1; verdicts in disposition log.

- [ ] **Step 1: Verify #141 (planner in Imperial)**

```bash
grep -rn "feet\|imperial\|Imperial" lib/features/plan* --include=*.dart -l | head
flutter test test/features/plan* 2>&1 | tail -5
```

Decision rule: the planner was rebuilt after this April report (planner redesign #485-#491, unit-axis fixes #739). Open the planner input widgets and confirm depth/rate inputs convert via the units service (not raw metric assumptions). If unit handling is present and planner tests pass, close: "The planner was rebuilt since this report (#485-#491) and calculator unit handling was overhauled in #739 (ships 1.7.1.118). Closing as resolved by the rebuild — if any specific imperial value still comes out wrong on 1.7.1.118, please reopen with the exact inputs and expected output." If you find a concrete imperial defect while checking, leave open, describe it in a comment, report to orchestrator for Phase 1.

- [ ] **Step 2: Verify #154 (Android `no such column: d.min_temperature`)**

```bash
grep -n "min_temperature\|minTemperature" lib/core/database/database.dart | head -20
grep -rn "min_temperature" lib/core/database/migrations* lib/core/database/ --include=*.dart | head
```

Decision rule: confirm the dives table defines the column and the migration ladder adds it for upgrades from the April-era schema. If yes, close: "This was a schema-migration gap in an early 1.x build. The column and its migration have been in place for many schema versions (current v136+); recent releases migrate old databases through it. Closing — please reopen with the app version and debug logs if any current build still crashes with this error." If the migration ladder somehow skips it for some upgrade path, STOP and report (schema work is out of scope per the spec).

- [ ] **Step 3: Record both verdicts in the disposition log.**

### Task 4: Close stale/duplicate #31, #39; fold #148 into #153

**Files:** read-only check of current Subsurface importer behavior for #148.

**Interfaces:**
- Consumes: nothing.
- Produces: #31, #39, #148 closed; #153 gets an umbrella-status comment; log updated.

- [ ] **Step 1: Close #31 with the STALE template**, extra sentence: "The last retest here showed Perdix 2 downloading successfully on Windows. Any surviving Shearwater download failure on current builds is tracked in #759."

```bash
env -u GITHUB_TOKEN gh issue close 31 -R submersion-app/submersion -r "not planned" -c "<STALE template with the extra sentence>"
```

- [ ] **Step 2: Close #39 with the STALE template**, extra sentence: "Windows dive-computer connection has been through several fix rounds since 1.3.2; the add-computer crash is not reproducible on current builds."

- [ ] **Step 3: Check #148's claim on current main** (sites not linked to dives on Subsurface import):

```bash
grep -rn "site" lib/features/import/ --include=*.dart -il | head
```

Open the Subsurface importer's dive-site handling; confirm whether imported dives link `siteId` to created/matched sites. Record the finding.

- [ ] **Step 4: Close #148**: "Folding into #153, the Subsurface import-quality umbrella. Current state on main: <one sentence from Step 3's finding>. The concrete duplicate-matching defect is being fixed via #756."

- [ ] **Step 5: Comment on #153** (leave open): "Status roll-up: #148 (site assignment) folded in here — current behavior: <finding>. Duplicate buddy/tag matching is being fixed via #756 (PR incoming). Coordinate/media import quality remain open here; fresh reports with sample files welcome."

- [ ] **Step 6: Record all in the disposition log.**

### Task 5: Needs-info comments (#543, #291, #267, #146, #147, #766, #425)

**Files:** none (GitHub only).

**Interfaces:**
- Consumes: nothing.
- Produces: one comment per issue, all left open; log updated.

- [ ] **Step 1: Post each comment** via `env -u GITHUB_TOKEN gh issue comment <N> -R submersion-app/submersion -b "<text>"`:

- #543: "To narrow this down we need the dive that renders like the screenshot: please export that single dive (UDDF) and attach it, and note which computer(s) it came from. The temperature axis scaling looks like a data artifact (e.g., a 0/garbage sample) rather than a chart bug, but the sample will settle it."
- #291: "Still awaiting the items above. One addition: from your `ls /dev/cu.*` output, `/dev/cu.usbserial-ST01C9B7` is present, so the OS sees the FTDI cable. Please enable Debug mode, attempt the download choosing 'Suunto Vyper Air', and attach the debug logs — that will show whether the serial open or the Suunto handshake fails."
- #267: "Still awaiting the debug logs requested above (enable Debug mode, retry, then share the logs). Linux BLE goes through BlueZ and the failure point (scan vs connect vs GATT) is only visible in the logs."
- #146: "Please attach debug logs from a connection attempt (enable Debug mode in Settings first), and if the app fully crashes, the Android crash log if you can retrieve it. Android 16 tightened BLE permission and threading behavior, and the logs will show which call dies."
- #147: "A BLE identity handling fix (PR #682) and OSTC download fixes have landed since this report. Could you retest on v1.7.1.118 when it's out (or current build), and attach debug logs if it still fails?"
- #766: "The pairing-interruption on Android needs logs to localize: please enable Debug mode, reproduce the failed pairing, and attach the logs. Also note your Android version and whether the Petrel 3 was previously paired with the Shearwater app (a stale bond can block a second app from pairing — worth unpairing in system Bluetooth settings and retrying)."
- #425: "The media pipeline was substantially rewritten since 1.5.6 (media store with content-addressed originals, store-backed playback fixes in #713/#727, ships in 1.7.1.118). Could you retest photo visibility across your Macs/iPhone on 1.7.1.118? If photos are still missing on the second device, note whether the affected photos were imported from the system Photos library or from files."

- [ ] **Step 2: Record all seven in the disposition log.**

### Task 6: Rewrite #623 from its Reddit source, then classify

**Files:** none (GitHub + web only).

**Interfaces:**
- Consumes: nothing.
- Produces: #623 has a real repro description in a comment; classification verdict (fix list vs needs-info) reported to the orchestrator and logged.

- [ ] **Step 1: Fetch the Reddit thread** linked in the issue body (https://www.reddit.com/r/submersion/comments/1v020ul/bug_in_statistics/) with WebFetch; extract: what statistic, what the user saw, what they expected, platform/version, any screenshots described.

- [ ] **Step 2: Comment the extracted repro on #623**: "Captured from the linked Reddit thread so this issue is self-contained: <symptom>; <expected>; <platform/version>. (If OP is here: corrections welcome.)"

- [ ] **Step 3: Classify.** If the repro names a specific computable defect (e.g., a wrong aggregate), report "promote to fix list" with the details; if it is vague or data-dependent, post a needs-info follow-up asking for the specific dive data and report "needs-info". Log the verdict.

### Task 7: DC investigation — Shearwater cluster (#759 canonical, #723, #123)

**Files:** read-only: the libdivecomputer fork sources (submodule; locate via `git submodule status`), app-side BLE discovery/name-mapping Dart code.

**Interfaces:**
- Consumes: nothing.
- Produces: per-issue verdict: "provable defect: <file:line> + fix sketch" (promoted to a Phase 1 fix task) or "not provable without hardware" (findings comment posted, issue left open). All verdicts logged and reported to the orchestrator.

- [ ] **Step 1: #759 (download fails after dive list on Perdix AI / Petrel 2).** Review the fork's Shearwater download path — the known regression line is the oldest-first download ordering change (issues #480, #621 history; `git log --oneline -- <fork>/src/shearwater*` in the submodule). Compare current fork state against upstream libdivecomputer's `shearwater_common.c`/`shearwater_predator.c` download loop. Look specifically for: manifest pagination handling after the dive list, and any early-exit condition introduced by the oldest-first patch. Verdict per the Produces contract.

- [ ] **Step 2: #723 (Perdix 3 not recognized via BLE).** Check the fork for the Perdix 3 descriptor (upstream added it in commit 8e564eb5; confirm the fork contains an equivalent) AND check every app-side platform source list for the BLE name filter ("Perdix 3" string) — the five platform source lists drift when the submodule bumps; grep each platform dir for a sibling of the descriptor list. If the name is missing from any layer, that is a provable defect.

- [ ] **Step 3: #123 (Suunto Ocean, Android).** Download the debug logs attached to the issue (`env -u GITHUB_TOKEN gh issue view 123 -R submersion-app/submersion --json comments` for the attachment URL, then fetch). Identify the failing stage (scan filter? GATT connect? Suunto EON protocol handshake?). If the log shows a name/UUID filter miss that is fixable in code, that's provable; otherwise post a findings comment summarizing what the logs show and what additional data would decide it.

- [ ] **Step 4: Log all three verdicts.**

### Task 8: Post the #732 findings comment (investigation already done)

Reconnaissance resolved the HW/USB cluster: #590 and #143 are provable and promoted to Phase 1 fix tasks (Tasks 26 and 27). #732 is NOT fixable in this campaign: there is no VID/PID allowlist to patch — macOS filters serial ports by BSD device-name prefix and Windows by hardware-ID prefix. The Oceanic/Aeris cable is an FTDI chip reprogrammed with a custom PID (0x0403:0xF460 family) that no kernel VCP driver claims, so no `/dev/cu.*` node ever exists; Subsurface succeeds by driving FTDI directly via libusb/libftdi, a transport this app deliberately does not compile (`HAVE_LIBUSB`/`HAVE_HIDAPI` commented out in all four platform configs). A sandboxed macOS build additionally lacks USB/serial entitlements.

**Files:** none (GitHub only).

**Interfaces:**
- Consumes: nothing.
- Produces: #732 commented (left open as the libusb-FTDI tracking issue); log updated.

- [ ] **Step 1: Comment on #732**

```bash
env -u GITHUB_TOKEN gh issue comment 732 -R submersion-app/submersion -b "Traced this. The Aeris/Oceanic USB cable is an FTDI chip reprogrammed with a custom PID, which the operating system's built-in FTDI driver does not claim — so no serial port device ever appears, and Submersion (which talks to serial ports the OS exposes) finds nothing to open. Subsurface works because it drives the FTDI chip directly via libusb/libftdi, a low-level USB transport Submersion does not currently ship. Fixing this properly means adding that transport, which is a feature rather than a small fix; leaving this issue open to track it. Two data points would help confirm: (1) which OS you're using, and (2) on macOS, the output of 'ls /dev/cu.*' with the cable plugged in."
```

- [ ] **Step 2: Log the verdict.**

### Task 9: Commit the disposition log

**Files:** Create: `docs/superpowers/plans/2026-07-31-bug-campaign-log.md`.

**Interfaces:**
- Consumes: log lines appended by Tasks 1-8.
- Produces: committed Phase 0 record; the orchestrator's authoritative input for assembling the final Phase 1 fix list.

- [ ] **Step 1: Verify every one of the 43 issues appears in the log** (fix-list members may still say "pending Phase 1"). Count check: 9 close-fixed verdicts (#280 #737 #358 #680 #758 #648 #57 #141 #154) + 3 dup/stale (#31 #39 #148) + 10 needs-info (#543 #291 #267 #146 #147 #766 #425 #153 #623 #732) + 3 DC investigation verdicts (#759 #723 #123) + 18 fix-list (#757 #736 #764 #647 #756 #158 #71 #190 #644 #765 #636 #222 #214 #218 #152 #110 #590 #143) = 43.

- [ ] **Step 2: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion && git add docs/superpowers/plans/2026-07-31-bug-campaign-log.md && git commit -m "docs: bug campaign phase 0 disposition log"
```

---

## Phase 1: Parallel fix batch (one worktree + one PR per issue)

All 18 tasks launch in parallel (staggered only for CPU contention). Root causes below were traced by read-only reconnaissance on 2026-07-31; re-verify the cited lines before editing (files may have drifted).

**Shared fix cycle** — every Phase 1 task follows these steps with its own branch/test/fix specifics; the checkboxes in each task refer to this cycle:

1. Create the worktree per Global Constraints using the task's branch name; `pwd` check.
2. Write the failing test given in the task.
3. Run it; confirm it fails for the stated reason (not a compile error in the test itself).
4. Implement the fix per the task's direction.
5. Test passes; then `dart format .`, `flutter analyze`, `flutter test` (full suite).
6. Commit with the task's message; push; open the PR with the task's title and `Fixes #N` in the body; post the issue comment if the task specifies one.

**File-collision rule:** Task 16 branches off Task 15's branch (both touch `uddf_full_import_service.dart`) and its PR notes the dependency. Tasks 12 and 25 both touch `dive_detail_page.dart` in distant regions — whichever finishes second rebases before opening its PR.

### Task 10: Fix #757 — buddy filter matches only the legacy scalar column

Branch: `fix/757-buddy-filter`

**Root cause:** all three filter implementations match legacy `dives.buddy` text, which the modern editor never writes (buddies persist only via the `dive_buddies` junction). Global search already does the correct junction join (`dive_repository_impl.dart:2188-2201`).

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:1942-1951`
- Modify: `lib/features/statistics/data/dive_filter_sql.dart:119-125`
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart:258-263` (in-memory `apply()`)
- Test: `test/features/statistics/data/dive_filter_sql_test.dart`, `test/features/dive_log/domain/models/dive_filter_state_test.dart`

**Interfaces:**
- Consumes: existing `DiveFilterState.buddyNameFilter`.
- Produces: no API changes; SQL clause becomes `(d.buddy LIKE ? OR EXISTS (SELECT 1 FROM dive_buddies db JOIN buddies b ON b.id = db.buddy_id WHERE db.dive_id = d.id AND LOWER(b.name) LIKE LOWER(?)))`.

- [ ] **Steps 1-3:** failing test — mirror the seeding helpers at `dive_filter_sql_test.dart:368-380`, but insert the buddy into `buddies` + `dive_buddies` and leave `dives.buddy` NULL:

```dart
test('buddyNameFilter matches junction-table buddies when legacy column is empty', () async {
  // seed a dive with dives.buddy = NULL, a Buddy 'Alice Diver', and a
  // dive_buddies row linking them (reuse this file's insert helpers)
  final filter = DiveFilterState(buddyNameFilter: 'alice');
  // assert the filtered result contains the dive (repository AND DiveFilterSql paths)
});
```

Expected failure: empty result set. Add the mirror case to `dive_filter_state_test.dart` for `apply()` with `dive.buddies` populated and `dive.buddy` null.

- [ ] **Step 4:** apply the OR-EXISTS clause in both SQL builders (keep the legacy `d.buddy LIKE ?` term so old data still matches) and make `DiveFilterState.apply()` check `dive.buddies.any((b) => b.name.toLowerCase().contains(q))` in addition to the scalar. Fix the stale doc comment at `dive_repository_impl.dart:1874`.
- [ ] **Steps 5-6:** commit `fix(dive-log): match buddy filter against the buddies junction table`; PR title same; body `Fixes #757`.

### Task 11: Fix #736 — Save button invisible in Diver Profile sub-pages

Branch: `fix/736-profile-save-visibility`

**Root cause:** the Save `TextButton` in `AppBar.actions` takes `colorScheme.primary` as foreground; in the Tropical theme primary (`0xFF00B4A0`) equals the AppBar background exactly (Console light is ~1.3:1 contrast). Body Weight works because it uses a FAB. The button exists and its handler works — it is invisible.

**Files:**
- Create: `lib/shared/widgets/app_bar_text_action.dart`
- Modify: `lib/features/settings/presentation/pages/insurance_edit_page.dart:170-190`, `medical_info_edit_page.dart:198-199`, `notes_edit_page.dart:149-150`, `personal_info_edit_page.dart:203-204`, `emergency_contacts_edit_page.dart:199-200`, `prior_experience_edit_page.dart:200-201`
- Test: `test/shared/widgets/app_bar_text_action_test.dart` (new), `test/features/settings/presentation/pages/prior_experience_edit_page_test.dart`

**Interfaces:**
- Produces: `class AppBarTextAction extends StatelessWidget { const AppBarTextAction({required this.label, required this.onPressed}); }` — a TextButton styled with `foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onPrimary`.

- [ ] **Steps 1-3:** failing test — pump an `AppBar(actions: [AppBarTextAction(...)])` under the Tropical theme (import the real theme), resolve the rendered text color, and assert it equals `appBarTheme.foregroundColor` and does NOT equal the AppBar background:

```dart
testWidgets('save action is visible against the tropical app bar', (tester) async {
  // pump MaterialApp(theme: tropicalTheme, home: Scaffold(appBar: AppBar(
  //   actions: [AppBarTextAction(label: 'Save', onPressed: () {})])))
  // final text = tester.widget<Text>(find.text('Save'));
  // resolve effective color via DefaultTextStyle/TextButton style
  // expect(color, equals(theme.appBarTheme.foregroundColor));
  // expect(color, isNot(equals(theme.appBarTheme.backgroundColor)));
});
```

(Write it first against a bare `TextButton` to watch it fail — the resolved color will be `primary` == background.)

- [ ] **Step 4:** implement the widget; swap all six pages' AppBar save `TextButton`s to `AppBarTextAction`. Do not change page logic.
- [ ] **Steps 5-6:** commit `fix(settings): make diver-profile save actions visible on same-color app bars`; PR body `Fixes #736`.

### Task 12: Fix #764 — desktop redirect destroys browse context

Branch: `fix/764-preserve-browse-context`

**Root cause:** trip/buddy pages `push('/dives/:id')`, but `dive_detail_page.dart:216-230` self-redirects one frame later with `context.go('/dives?selected=…')`, replacing the whole stack.

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:216-230`
- Test: `test/features/dive_log/presentation/pages/dive_detail_nested_nav_test.dart` (add case) or new `dive_detail_pushed_context_test.dart`

**Interfaces:** no API changes. The redirect gains a guard: only fire when the detail page is the stack root (`!context.canPop()`); a pushed detail page stays standalone with a working back button.

- [ ] **Steps 1-3:** failing test — desktop-size router test: `/trips/:id` -> tap dive -> pushed `/dives/:id`; pump past the post-frame callback; assert the page did NOT relocate to `/dives?selected=` and `canPop()` is true; pop; assert trip detail is restored. Expected failure today: location becomes `/dives?selected=<id>` and canPop is false.
- [ ] **Step 4:** add `!context.canPop() &&` to the redirect condition (keep `_hasRedirected` logic). Do not touch the sibling redirects listed in recon (equipment/site behave correctly).
- [ ] **Steps 5-6:** commit `fix(dive-log): keep pushed dive details on the stack instead of master-detail redirect`; PR body `Fixes #764`.

### Task 13: Fix #647 — settings sections unpoppable, back gesture exits app

Branch: `fix/647-settings-back-gesture`

**Root cause:** `settings_page.dart:358-374` routes most sections via `context.go('/settings?selected=X')` — same path, query mutation, nothing pushed, nothing for Android predictive back to pop. Appearance/Diver Profile are real pushed child routes and work.

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart:358-374` (`_navigateToSection` default branch), `:211-235` (`_SettingsSectionDetailPage` leading button)
- Test: `test/features/settings/presentation/pages/settings_page_test.dart`

**Interfaces:** no API changes; `default:` branch becomes `context.push('$currentPath?selected=$sectionId')`; the manual leading back button becomes `if (context.canPop()) context.pop() else context.go('/settings')`.

- [ ] **Steps 1-3:** failing test — router-based test: open `/settings`, tap the Data section tile, assert `router.canPop()` is true; dispatch a system back (`router.pop()` via `WidgetsBinding.instance.handlePopRoute()` or `tester.binding` maybePop); assert location is `/settings` with no `selected` param and the app did not try to pop the root. Expected failure today: `canPop()` false right after selecting Data.
- [ ] **Step 4:** apply the two changes. Verify deep links to `/settings?selected=data` still render (the query-param branch at `:104-116` is unchanged).
- [ ] **Steps 5-6:** commit `fix(settings): push section detail so system back returns to settings`; PR body `Fixes #647`.

### Task 14: Fix #756 — import duplicate review can't link to existing buddies/tags

Branch: `fix/756-import-link-existing`

**Root cause:** the reviewer offers only Skip (drops the association: skipped indices never enter `buddyIdMapping`/`tagIdMapping`, so `uddf_entity_importer.dart:1829-1834/:1894-1899` silently drop the refs) and Import-as-New (always creates a fresh UUID row). The matched existing id (`EntityMatchResult.existingId`) is computed by `import_duplicate_checker.dart` and thrown away. `_EntityComparisonPanel` (`entity_review_list.dart:715-736`) ignores `availableActions`, which already include `DuplicateAction.consolidate`.

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:244-263` (new param), `:537-543` and `:710-729` (seed mappings), `lib/features/import_wizard/data/adapters/universal_adapter.dart:901-927` (plumb matches through)
- Modify: `lib/features/import_wizard/presentation/widgets/entity_review_list.dart:536-544, 715-736` (offer Link-to-existing / consolidate)
- Test: `test/features/dive_import/data/services/uddf_entity_importer_test.dart`, `test/features/import_wizard/presentation/widgets/entity_review_list_test.dart`

**Interfaces:**
- Produces: `UddfEntityImporter.import(..., {Map<ImportEntityType, Map<String, String>> preResolvedIds = const {}})` — uddfId/name -> existing DB id; seeded entries populate the id mappings before the create loops, so dive linking at `:1829`/`:1894` resolves to the existing record.

- [ ] **Steps 1-3:** failing test — importer test: DB already contains buddy "Nathalie" (id `existing-1`); import a parsed bundle whose dive references buddy "Nathalie" with that index NOT in the selected set and `preResolvedIds: {buddy: {'Nathalie': 'existing-1'}}`; assert: no second buddies row is created AND the imported dive is linked to `existing-1`. Expected failure: parameter doesn't exist yet — first commit the test against the intended signature, watch it fail to compile, then add the param as a no-op and watch the assertion fail (dive has no buddy).
- [ ] **Step 4:** implement the param and seeding; in `universal_adapter.dart` build `preResolvedIds` from each group's `entityMatches` for indices whose action is skip-with-match or consolidate; in `entity_review_list.dart` render a third button "Link to existing" when `availableActions` contains consolidate and a match exists, and make collapsed-header toggle cycle through it. New user-visible strings go through l10n (all 11 ARBs).
- [ ] **Steps 5-6:** commit `fix(import): link skipped duplicate buddies/tags to existing records`; PR body `Fixes #756`.

### Task 15: Fix #158 — UDDF tank volume stored without m³ conversion

Branch: `fix/158-uddf-tank-volume`

**Root cause:** both UDDF import services store `<tankvolume>` verbatim (`uddf_full_import_service.dart:1396-1402`, `uddf_import_service.dart:374-377`) despite the spec defining m³; the exporter mirrors the bug by writing liters (`uddf_export_builders.dart:430-434`). Diving Log writes a 10x-off value (0.111 for an 11.1 L tank), and legacy Submersion exports wrote liters — so use a plausibility ladder, not a blind x1000.

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart` (new helper), `uddf_full_import_service.dart:1396-1402`, `uddf_import_service.dart:374-377`, `uddf_export_builders.dart:430-434`
- Test: `test/core/services/export/uddf/uddf_import_service_test.dart` (update the assertions that encode the bug at `:371,403-404`), `test/integration/uddf_round_trip_test.dart`, new unit tests for the helper

**Interfaces:**
- Produces: `double normalizeUddfTankVolumeToLiters(double raw)` in `uddf_import_parsers.dart`: `raw <= 0.045` -> x1000 (spec m³); `raw <= 0.45` -> x100 (Diving Log quirk); `raw <= 45` -> already liters, keep; else keep unchanged. Export writes spec-correct m³: `tank.volume / 1000`.

- [ ] **Steps 1-3:** failing unit test:

```dart
test('normalizes UDDF tankvolume across exporter conventions', () {
  expect(normalizeUddfTankVolumeToLiters(0.0111), closeTo(11.1, 0.001)); // spec m3
  expect(normalizeUddfTankVolumeToLiters(0.012), closeTo(12.0, 0.001));  // MacDive
  expect(normalizeUddfTankVolumeToLiters(0.111), closeTo(11.1, 0.001));  // Diving Log 10x
  expect(normalizeUddfTankVolumeToLiters(11.1), closeTo(11.1, 0.001));   // legacy liters
  expect(normalizeUddfTankVolumeToLiters(24.0), closeTo(24.0, 0.001));
});
```

Plus an import-service test parsing `<tankvolume>0.0111</tankvolume>` -> tank volume 11.1. Expected failure: helper undefined / import yields 0.0111.

- [ ] **Step 4:** implement helper, call it at both parse sites, switch export to `/ 1000`, update the round-trip test (11.1 L exports as 0.0111, re-imports as 11.1) and the old assertions that encoded the bug.
- [ ] **Steps 5-6:** commit `fix(import): convert UDDF tankvolume to liters with exporter-quirk tolerance`; PR body `Fixes #158`. Do NOT backfill existing DB rows (migration = scope balloon; note it in the PR body as a known limitation).

### Task 16: #71 — Shearwater UDDF gas mix: reproduce first, then fix or close

Branch: `fix/71-shearwater-uddf-gasmix` — **branch off Task 15's branch**, not main (same file).

**Root cause candidate:** Shearwater UDDF has no `<link>` under `<tankdata>`; mix resolution at `uddf_full_import_service.dart:1404-1418` never fires. BUT commit `6a5f634ece8` (#404, merged 2026-07-04) added switchmix->tank materialization and single-tank assignment (`:1608-1647`, `:1836-1869`) which likely already fixes the attached file (five 0/0 placeholder tanks are filtered, one survives, `tanks.length == 1` assignment applies 30/00). The colon/slash id format is NOT the problem (verified byte-identical ids).

**Files:**
- Test: new fixture + case in `test/core/services/export/uddf/uddf_shearwater_multigas_test.dart`
- Modify (only if reproduction fails): `uddf_full_import_service.dart:1621` (drop the `timestamp != null` gate for switchmix), `:1637` (multi-tank assignment), `:86-98` (index mixes by `<name>` as secondary key)

**Interfaces:** none new unless fixing.

- [ ] **Step 1:** download the reporter's file from the issue (`Perdix.AI.3717DD32.267_2025-12-30.uddf.xml` attachment), commit it as `test/dives/issue_71_perdix_single_tank.uddf`.
- [ ] **Step 2:** write the test: run it through `UddfFullImportService`; assert exactly one tank survives and its gas mix is O2=30/He=0 (not Air).
- [ ] **Step 3:** run it. **If it PASSES:** the bug is already fixed — keep the regression test, commit `test(import): lock Shearwater UDDF single-tank gas mix (#71)`, open that PR (body: `Fixes #71` plus one line crediting the #404 fix), and report "already fixed, test-only PR" to the orchestrator. **If it FAILS:** proceed to fix the three residual holes listed under Files, minimally and in this order until the test passes.
- [ ] **Steps 5-6:** commit `fix(import): resolve Shearwater UDDF gas mixes without tankdata links` (fix path only); PR body `Fixes #71`, noting the dependency on the Task 15 branch.

### Task 17: Fix #190 — MySSI CSV maps 0 of 262 columns

Branch: `fix/190-myssi-csv-import`

**Root cause (three stacked defects):** (1) `format_detector.dart:263` parses with the csv package's default CRLF eol — an LF-only file becomes ONE row, and `csvHeaders = rows.first` = every cell in the 8 KB peek (9 commas x 29 lines + 1 = 262, matching the report exactly); no BOM strip on the CSV path (`:259` vs the DL7 path `:243-247`). (2) No MySSI preset exists in `built_in_presets.dart`. (3) The wizard persists an empty mapping which, as `customMappingOverride`, short-circuits the keyword auto-mapper (`csv_import_parser.dart:121` Case 1 beats Case 3's `_autoMapFromHeaders`).

**Files:**
- Modify: `lib/features/universal_import/data/services/format_detector.dart:259-263` (normalize line endings + strip BOM, or pass `eol: '\n'` after normalizing), `lib/features/universal_import/presentation/widgets/field_mapping_step.dart:72,100,137-151` (prefer `state.parsedCsv?.headers` over `detectionResult.csvHeaders`; don't persist an empty mapping as an override), `lib/features/universal_import/data/csv/presets/built_in_presets.dart` (add MySSI preset for the 10 documented headers)
- Test: `test/features/universal_import/data/services/format_detector_test.dart` (also fix the vacuous test at `:216-223` whose expect is gated behind an if), preset tests, new `field_mapping_step` coverage if feasible

**Interfaces:** no new public API; MySSI preset key `myssi`.

- [ ] **Steps 1-3:** failing test — build a 29-line LF-only CSV string with the exact MySSI header (`dive #,Dive Site,Country,Date / Time,Dive Activity,Specialty Dive,Dive type,Duration,Depth,Dive Buddy / Instructor / Center`) and 28 data rows; run `FormatDetector.detect`; assert `csvHeaders` has length 10 (fails today with 262) and the format scores as CSV. Add a BOM variant asserting header[0] == 'dive #' (no BOM prefix). Make the vacuous test's expectation unconditional while you're in the file.
- [ ] **Step 4:** normalize `\r\n|\r|\n` -> `\n` and strip `﻿` before conversion with `eol: '\n'`; add the MySSI preset (map: dive #->diveNumber, Dive Site->siteName, Country->country, Date / Time->dateTime, Duration->duration, Depth->maxDepth, Dive Buddy / Instructor / Center->buddy; leave Dive Activity/Specialty/Dive type unmapped); have the mapping step fall back to parsed headers and seed from the auto-mapper when no preset matches instead of persisting an empty override.
- [ ] **Steps 5-6:** commit `fix(import): parse LF/BOM CSVs correctly and add MySSI preset`; PR body `Fixes #190`.

### Task 18: Fix #644 — PDF logbook ignores detail level; duration uses bottom time

Branch: `fix/644-pdf-export-options`

**Root cause:** (a) `savePdfToFile` (`export_providers.dart:945-963`) ignores its `PdfExportOptions` entirely and calls the legacy single-layout `saveDivesToPdfFile`; the share path (`exportDivesToPdf`, `:240-312`) correctly dispatches `factory.getBuilder(options.template)`. (b) Every PDF surface prints `dive.bottomTime`; the correct value is `Dive.effectiveRuntime` (`dive.dart:285-297`).

**Files:**
- Modify: `lib/features/settings/presentation/providers/export_providers.dart:945-963` (route through the same builder path as `exportDivesToPdf` — extract a shared private `Future<Uint8List> _buildLogbookPdfBytes(PdfExportOptions options)` used by both), `lib/core/services/export/pdf/pdf_export_service.dart:119-120, 273-274, 416-417`, `pdf_template_detailed.dart:146`, `pdf_template_simple.dart:159-160`, `pdf_template_professional.dart:392-393`, `pdf_template_padi.dart:309`, `pdf_template_naui.dart:108-109, 322`, `pdf_shared_components.dart:508-509` (bottomTime -> effectiveRuntime, including summary totals)
- Test: `test/core/services/pdf_templates/pdf_templates_test.dart`, `test/core/services/export/pdf/pdf_export_service_test.dart`

**Interfaces:**
- Consumes: `Dive.effectiveRuntime` (existing).
- Produces: `savePdfToFile` honors `options.template` (and diver metadata like the share path).

- [ ] **Steps 1-3:** failing tests — (a) generate bytes via the save path for the same dive set with two different templates; assert the outputs differ (today: identical). (b) template test: dive with `runtime: 62 min, bottomTime: 50 min`; assert the rendered PDF text contains 62, not 50 (the existing templates tests show how to extract text).
- [ ] **Step 4:** implement (a) by extracting the shared builder call from `exportDivesToPdf` and using it in `savePdfToFile`; implement (b) by switching to `effectiveRuntime` at every listed site including totals. Update the existing "with bottomTime" test names/fixtures honestly.
- [ ] **Steps 5-6:** commit `fix(export): honor PDF detail level on save and print total runtime`; PR body `Fixes #644`.

### Task 19: Fix #765 — manual date entry ignores the date-format setting

Branch: `fix/765-date-entry-format`

**Root cause:** every `showDatePicker` call passes only context/initial/first/last; the input-mode parser/hint comes from `MaterialLocalizations` of the ambient locale (en-US on an English UI), never from Submersion's `DateFormatPreference` (`units.dart:126-151`). PR #768 touched display/export only.

**Files:**
- Create: `lib/shared/widgets/app_date_picker.dart`
- Modify: all `showDatePicker` call sites (recon list, ~22): `dive_edit_page.dart:4151-4157, 4206-4211`, `equipment_edit_page.dart:717`, `equipment_detail_page.dart:1448,1460`, `equipment_list_page.dart:689`, `equipment_attribute_form_section.dart:185`, `service_schedule_dialogs.dart:225`, `certification_edit_page.dart:1067`, `course_edit_page.dart:402`, `trip_edit_page.dart:684`, `incident_edit_page.dart:225`, `checklist_item_edit_sheet.dart:73`, `dive_search_page.dart:726`, `dive_filter_sheet.dart:765`, `fix_dive_times_page.dart:101,117`, `medical_info_edit_page.dart:107`, `insurance_edit_page.dart:98`, `prior_experience_edit_page.dart:109`, `body_weight_edit_page.dart:97`, `healthkit_adapter_steps.dart:226,243`
- Test: new `test/shared/widgets/app_date_picker_test.dart`

**Interfaces:**
- Produces: `Future<DateTime?> showAppDatePicker({required BuildContext context, required DateFormatPreference dateFormat, required DateTime initialDate, required DateTime firstDate, required DateTime lastDate})` — maps the preference to a picker locale (`mmddyyyy`->`en_US`, `ddmmyyyy`->`en_GB`, `yyyymmdd`->`en_CA`, `ddmmyyyyDots`->`de`) and passes `locale:` plus `fieldHintText: dateFormat.display.toLowerCase()`.

- [ ] **Steps 1-3:** failing widget test — pump a button that calls `showAppDatePicker(dateFormat: DateFormatPreference.ddmmyyyy, ...)` with the app's localization delegates; open the picker, switch to input mode (tap the edit icon), type `31/01/2026`, confirm; expect the returned value to be `DateTime(2026, 1, 31)`. Write it against plain `showDatePicker` first to watch it fail (en-US parses 31/01 as invalid).
- [ ] **Step 4:** implement the wrapper; sweep every listed call site to it, sourcing `dateFormat` from the settings provider each page already watches (or `ref.read(settingsProvider).dateFormat`). No behavior change for calendar-mode selection.
- [ ] **Steps 5-6:** commit `fix(ui): honor the date-format setting in manual date entry`; PR body `Fixes #765`.

### Task 20: Fix #636 — retired equipment shown in pickers and default list

Branch: `fix/636-retired-equipment`

**Root cause:** two unsynced "retired" concepts. The edit page saves `status: retired` but leaves `isActive: true` (`equipment_edit_page.dart:762` vs `:784`); `getActiveEquipment` filters only `isActive`; and the dive-edit picker uses `allEquipmentProvider` (no filter at all, `equipment_picker_sheet.dart:25`). The list page defaults to the "All" filter (`equipment_list_content.dart:54,135-136,410`).

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart:784` (derive `isActive: _selectedStatus != EquipmentStatus.retired`), `lib/features/equipment/data/repositories/equipment_repository_impl.dart:23-46` (getActiveEquipment additionally excludes `status == retired` so legacy rows with stale `isActive` are covered), `lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart:25` (watch `activeEquipmentProvider`), `lib/features/equipment/presentation/widgets/equipment_list_content.dart:54` (default filter = Active, "All" stays available in the dropdown)
- Test: `test/features/equipment/data/repositories/equipment_repository_test.dart`, `test/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet_test.dart` (update the `allEquipmentProvider` override to the new provider), `test/features/equipment/presentation/widgets/equipment_list_content_test.dart`

**Interfaces:** no new API; `equipment_set_edit_page.dart:62` already uses `activeEquipmentProvider` — that is the precedent.

- [ ] **Steps 1-3:** failing tests — repository test: seed gear with `status: retired, isActive: true` (the legacy inconsistency); assert `getActiveEquipment()` excludes it (fails today). Picker test: retired item does not appear in the sheet. List test: default filter shows only active.
- [ ] **Step 4:** apply the four changes. Watch the memory note: changing a provider a widget consumes breaks its tests silently — run the full equipment + dive_log widget test set, not just the touched files.
- [ ] **Steps 5-6:** commit `fix(equipment): hide retired gear from pickers and default equipment list`; PR body `Fixes #636`.

### Task 21: Fix #222 — tide times shifted by the device's UTC offset

Branch: `fix/222-tide-time-display`

**Root cause:** dive timestamps are wall-clock-as-UTC by convention (`wall_clock_utc.dart:1-14`); formatters must NOT convert. The tide widgets are the only violators — 15 `.toLocal()` sites across `tide_chart.dart` (184, 210, 318, 342, 458, 461, 732), `tide_times_table.dart` (171, 183, 230, 391, 413), `tide_cycle_graph.dart:474`, `tide_section.dart:369-370`, `dive_detail_page.dart` tide card (3467, 3471-3472, 3598). Reporter's -7h shift = their own PDT offset.

**Files:**
- Modify: the 15 listed sites (drop `.toLocal()`, format via `UnitFormatter.formatTime`/`formatDate` like the rest of the app)
- Test: create `test/features/tides/presentation/widgets/tide_time_format_test.dart`

**Interfaces:** no API changes. Out of scope (comment on the issue instead): the prediction-accuracy half — the harmonic engine needs a true-UTC instant and there is no site timezone column; that is a schema change (scope balloon).

- [ ] **Steps 1-3:** failing test — extract-and-test approach: for one representative widget path (tide_times_table), pump with a tide record whose `highTideTime` is `DateTime.utc(2026, 1, 1, 10, 30)` and assert the rendered string contains `10:30` computed as `DateFormat(pattern).format(raw)` — with the current `.toLocal()` code this fails on any machine whose offset is nonzero; ALSO run once locally with `TZ=America/Los_Angeles flutter test <file>` to confirm the pre-fix failure even if CI is UTC, and note that in the PR.
- [ ] **Step 4:** remove all 15 conversions; keep formatting through `UnitFormatter` so time-format settings still apply. Check `tide_providers.dart:91,132` while there: `DateTime.now()` fed to the same engine is local-kind; align it with the wall-clock convention if the change is a one-liner, otherwise leave and note it.
- [ ] **Steps 5-6:** commit `fix(tides): stop converting wall-clock timestamps to device-local time`; PR body `Fixes #222`, plus issue comment: "Display fix merged. The residual inaccuracy you noticed even after mentally shifting (+7h) is a second, deeper issue — the predictor needs a true-UTC instant, which requires knowing the site's timezone; tracked as follow-up."

### Task 22: Fix #214 — reverse geocoding stores device-locale country names

Branch: `fix/214-geocode-locale`

**Root cause:** no locale pinned anywhere: `placemarkFromCoordinates` (`location_service.dart:198-201`) uses the device locale (no `setLocaleIdentifier`/`localeIdentifier` anywhere in the repo); the Nominatim fallback URL (`:229-232`) sends no `accept-language` param/header. Statistics groups on the raw string, so "Spain"/"Spanien"/"España" split.

**Files:**
- Modify: `lib/core/services/location_service.dart:198-213` (pass/pin locale `en` for the platform geocoder), `:229-236` (add `&accept-language=en` to the URL and an `Accept-Language: en` header), `:279-317` (same for `forwardGeocode`)
- Test: new `test/core/services/location_service_test.dart` (extract `Uri buildReverseGeocodeUri(double lat, double lon)` so the URL is testable), update `test/features/dive_sites/presentation/pages/site_edit_seed_location_test.dart` fake if signatures shift

**Interfaces:**
- Produces: `Uri buildReverseGeocodeUri(double lat, double lon)` (visible for testing) including `accept-language=en`.

- [ ] **Steps 1-3:** failing test — `expect(buildReverseGeocodeUri(36.0, -5.6).queryParameters['accept-language'], 'en')` (function doesn't exist yet / param missing). Keep the fill-only-empty guards untouched (`site_edit_page.dart:162-169`, `uddf_entity_importer.dart:867-868`) — assert one existing fill-only-empty test still passes unchanged.
- [ ] **Step 4:** implement both pins. English-only normalization is deliberate: country names become consistent for grouping. Existing stored rows are NOT rewritten (backfill = data migration, out of scope).
- [ ] **Steps 5-6:** commit `fix(sites): pin reverse-geocode results to English for consistent grouping`; PR body `Fixes #214`, plus issue comment noting new lookups are consistent but previously stored localized names need a manual edit (or a future backfill) to merge statistics rows.

### Task 23: Fix #218 — custom database folder silently reset / silently never set on Linux

Branch: `fix/218-linux-db-location`

**Root cause (both real, both fixed here):** (H1) `main.dart:91-135` resets the custom location to default on ANY access-check failure, on every platform, silently — a macOS-sandbox recovery that is a trapdoor on Linux (no bookmark mechanism, `security_scoped_bookmark_service.dart:22`). (H2) `database_location_service.dart:168-180` swallows every folder-picker exception and returns null; `storage_settings_page.dart:521-528` treats null as "user cancelled" — on Linux the XDG portal can fail entirely and the user sees nothing.

**Files:**
- Modify: `lib/main.dart:91-135` (extract the guard), `lib/core/services/database_location_service.dart` (new `validateCustomLocationAtStartup()`: auto-reset ONLY when `SecurityScopedBookmarkService.isSupported`; on other platforms keep the config and let the open proceed/log), `:168-180` (stop swallowing: return a typed failure `FolderPickError(message)` instead of null-on-exception), `lib/features/settings/presentation/pages/storage_settings_page.dart:521-528` (surface the error in a SnackBar via an existing generic error l10n key; if none exists, add one to all 11 ARBs)
- Test: new `test/core/services/database_location_startup_guard_test.dart` (temp-dir based: file exists -> keep; file missing on non-bookmark platform -> keep config, no reset; bookmark platform + inaccessible -> reset), `test/features/settings/presentation/providers/storage_providers_pick_test.dart` (picker exception surfaces as error, not silent null)

**Interfaces:**
- Produces: `Future<StartupLocationCheck> validateCustomLocationAtStartup()` on `DatabaseLocationService` returning `{kept, resetToDefault, warning}`; `main.dart` becomes a thin caller.

- [ ] **Steps 1-3:** failing tests as listed (the extracted function doesn't exist yet; the picker test currently gets null where a typed error is expected).
- [ ] **Step 4:** implement; preserve the macOS sandbox behavior exactly (that guard exists for a reason); `debugPrint` stays but the user-visible outcome changes only on non-bookmark platforms.
- [ ] **Steps 5-6:** commit `fix(storage): stop silently resetting or ignoring the custom database folder on Linux`; PR body `Fixes #218`.

### Task 24: Fix #152 — Transfer menu leaks English strings

Branch: `fix/152-transfer-l10n`

**Root cause:** the Transfer page is ~95% localized; the leaks are `transfer_page.dart:648` ('Known Computers'), `:762` ('N dives'), `:791` (tooltip 'Download dives'), and — most visible — `DiveComputer.lastDownloadFormatted` (`dive_computer.dart:97-113`): a domain-entity getter with hardcoded English AND a hardcoded US M/D/Y date, leaking into `transfer_page.dart:776`, `device_detail_page.dart:240`, `device_list_page.dart:292`.

**Files:**
- Create: `lib/features/dive_computer/presentation/utils/last_download_formatter.dart` — `String formatLastDownload(BuildContext context, DateTime? lastDownload)` using l10n keys + the diver's date-format setting for the fallback date
- Modify: `transfer_page.dart:648,762,776,791`, `device_detail_page.dart:240`, `device_list_page.dart:292`; mark `lastDownloadFormatted` deprecated (or remove if no non-UI consumer remains)
- Modify: `lib/l10n/arb/app_en.arb` (extend the `transfer_computers_*` namespace; use ICU plural for the dive count, template: `transfer_computers_savedCount`) + the 10 other ARB files; regen
- Test: new `test/l10n/transfer_strings_test.dart` modeled on `test/l10n/ocr_import_strings_test.dart` (iterate all supported locales, assert each new key is non-empty); `test/l10n/arb_parity_test.dart` must stay green

**Interfaces:**
- Produces: `formatLastDownload(BuildContext, DateTime?)`; l10n keys `transfer_computers_knownComputersHeader`, `transfer_computers_diveCount` (plural), `transfer_computers_downloadTooltip`, `transfer_computers_lastDownloadNever/minutesAgo/hoursAgo/yesterday/daysAgo`.

- [ ] **Steps 1-3:** failing test — the locale-iteration test fails because the keys don't exist yet (regen not run). Also a formatter unit test: `lastDownload: null` -> localized 'Never' in de is 'Nie' (not English).
- [ ] **Step 4:** add keys to en + ALL 10 non-en ARBs (project rule — translate, don't copy English), regen, implement the formatter, swap the three screens and the three inline strings.
- [ ] **Steps 5-6:** commit `fix(l10n): localize the remaining Transfer / dive-computer strings`; PR body `Fixes #152`. Note in the PR that pages pushed from Transfer (import wizard, discovery) were not audited here.

### Task 25: Fix #110 — SAC by segment inflated (sidemount worst case)

Branch: `fix/110-segment-sac`

**Root cause:** `_calculateSegmentSac`'s no-pressure-data fallback (`gas_analysis_service.dart:684-699`) computes `proportion = durationSec / totalDuration` where `totalDuration` is derived from the SEGMENT profile it was passed — so proportion ≈ 1.0 and every segment is charged the whole cylinder's pressure drop. Sidemount hits this constantly: with no recorded gas switches `_getActiveTankAtTimestamp` (`:564-570`) pins every segment to one tank whose pressure series is flat during the other tank's stints -> fallback fires. Overall SAC is right because it uses `combineMultiTankPressures` (a different path).

**Files:**
- Modify: `lib/features/dive_log/data/services/gas_analysis_service.dart:653-724` (`_calculateSegmentSac` gains the dive-level duration; fallback prorates against it and interpolates `startPressure` from the DIVE start), call sites `:79` and `:194` (pass the dive profile's total duration)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:2046-2052` (resolve the L/min tank volume per segment via `SacSegment.tankId`, falling back to the first tank with a volume)
- Test: `test/features/dive_log/data/services/gas_analysis_service_segment_sac_test.dart`

**Interfaces:**
- Consumes: existing `SacSegment.tankId`.
- Produces: `_calculateSegmentSac(..., {required int diveDurationSec})` (private; signature change is internal).

- [ ] **Steps 1-3:** failing test — tank 200->100 bar with NO per-sample pressure series; a 30-minute dive split into three equal phase segments; assert the three segments' `pressureUsed` are each ≈33.3 bar and sum to ≈100 (today: each is ≈100, sum ≈300). Add a second case: two tanks of different volumes and per-segment `tankId`s -> the L/min conversion uses each segment's own tank volume.
- [ ] **Step 4:** implement. Do NOT attempt the full sidemount attribution redesign (alternating-tank inference is a design problem — if the fallback fix leaves sidemount segments still misattributed, say so in the PR and issue comment rather than growing scope).
- [ ] **Steps 5-6:** commit `fix(analysis): prorate segment SAC fallback against dive duration, per-segment tank volume`; PR body `Fixes #110`.

### Task 26: Fix #590 — OSTC4 misidentified as OSTC 2 (native matcher)

Branch: `fix/590-ostc4-recognition`

**Root cause:** `dc_filter_hw` accepts any name starting with "OSTC" for every hw_ostc3-family descriptor; `libdc_descriptor_match` (`packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.c:143-232`) keeps the FIRST filter-passing descriptor ("OSTC 2", first table row) unless the exact-name tiebreaker (`strcasecmp_nospace`) fires — which fails for suffixed names like "OSTC4-1234". The `OSTC 4` descriptor exists (model 0x43). Same defect class as the fixed Scubapro HUD (#285) and Perdix 3 (#483) cases. NOTE: the fix corrects identification; the download failure may be separate — scope the PR and issue comment honestly.

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.c:196-230` — after the exact-match tiebreaker, add a normalized-prefix tiebreaker: normalize name and product (lowercase, strip spaces); if normalized name STARTS WITH normalized product, prefer the LONGEST such product ("ostc4-1234" starts with "ostc4" -> "OSTC 4" beats the fallback "OSTC 2", which is not a prefix). Locate and patch EVERY copy: `grep -rln "libdc_descriptor_match" packages/libdivecomputer_plugin` (platform source lists drift — Windows/Linux/Android may compile their own copy or share this file; patch all).
- Test: `packages/libdivecomputer_plugin/test/native/test_descriptor_match_integration.c` — add cases: `"OSTC4" -> product "OSTC 4"`, `"OSTC4 12345" -> "OSTC 4"`, `"OSTC 2" -> "OSTC 2"` (regression), `"OSTC3-1234" -> "OSTC 3"` if that descriptor exists (check the table first).
- Do NOT touch the submodule (`third_party/libdivecomputer`) — the fix lives in the wrapper.

**Interfaces:** none new (internal C function).

- [ ] **Steps 1-3:** failing C test — add the cases, build and run the native tests per `packages/libdivecomputer_plugin/test/native/CMakeLists.txt` (cmake -S packages/libdivecomputer_plugin/test/native -B <scratch>/native-build && cmake --build <scratch>/native-build && ctest --test-dir <scratch>/native-build --output-on-failure). Expected failure: "OSTC4 12345" resolves to "OSTC 2".
- [ ] **Step 4:** implement the tiebreaker in every located copy, keeping the existing exact-match branch first.
- [ ] **Steps 5-6:** commit `fix(dc): resolve suffixed HW OSTC BLE names to the right descriptor`; PR body `Fixes #590` + issue comment: "Your OSTC4 will now identify correctly. If the download still fails after it shows as OSTC 4, please attach debug logs — that would be a separate transport issue we'll track on its own."

### Task 27: Fix #143 — EON Steel advertised over USB the app can't do

Branch: `fix/143-usbhid-transport-honesty`

**Root cause:** the descriptor declares `DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE` (no SERIAL); `mapTransports` (`DiveComputerHostApiImpl.swift:63-79`) folds USBHID into `.usb`, and `.usb` routes to the SERIAL download path (`:219-225`) -> "No USB serial ports found" dead end. No platform has a USB HID transport (`HAVE_HIDAPI` off everywhere; `usbhid.c` compiled as stub). The honest fix: stop advertising USB for USBHID-only devices so users are steered to BLE.

**Files:**
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:63-79` (drop the USBHID->usb mapping; keep USB/SERIAL mapping intact — verify Mares Puck (SERIAL) still advertises usb) and the three sibling implementations: `windows/dive_computer_host_api_impl.cc`, `linux/` equivalent, `android/.../DiveComputerHostApiImpl.kt` (recon: all mirror the same mapping; locate by grepping USBHID per platform)
- Test: nearest existing transport-mapping test (`packages/libdivecomputer_plugin/test/dive_computer_service_test.dart` or `test/native/test_serial_callbacks.c:95-140`); add: descriptor with USBHID|BLE surfaces `[ble]` only; descriptor with SERIAL still surfaces usb.

**Interfaces:** no API shape change; `.usb` simply stops appearing for USBHID-only descriptors.

- [ ] **Steps 1-3:** failing test at whichever layer is testable without hardware (Dart service test with the pigeon fake, or the native callback test) — EON Steel (USBHID|BLE) currently maps to `[usb, ble]`; expect `[ble]`.
- [ ] **Step 4:** implement across all four platforms. Search for any UI copy that special-cases USB for Suunto and adjust if it exists (grep "EON" in `lib/`).
- [ ] **Steps 5-6:** commit `fix(dc): stop advertising USB for USB-HID-only dive computers`; PR body `Fixes #143` + issue comment: "The EON Steel's USB mode is USB-HID, which Submersion's transport layer doesn't implement — the app was wrongly advertising USB and then failing to find a serial port. As of this fix the app offers BLE (which works) and no longer dead-ends you on USB. Leaving a note here: if there's demand for true USB-HID cable support, that's a feature we can track separately."

### Task 28: Fix #759 — Shearwater oldest-first download aborts with zero dives (promoted from Task 7)

Branch: `fix/759-shearwater-partial-download`

**Root cause (Task 7 investigation, fork HEAD 1a47a01):** the oldest-first patch (`shearwater_petrel.c:329-348` in the fork submodule) kept abort-on-first-failure; with the order reversed, one lost BLE notification aborts the pass at the OLDEST dive — zero dives delivered, no partial-import offer, "Download Failed" right after the manifest. `shearwater_common_download` has no retry; the fork already carries an OSTC3 retry wrapper (commit 4ac9867) for the identical failure mode. The existing native test `check_stop_on_failure` encodes the broken behavior as intended.

**Files:**
- Modify (SUBMODULE `packages/libdivecomputer_plugin/third_party/libdivecomputer`, fork repo): `src/shearwater_petrel.c:329-348` — (a) wrap the per-dive `shearwater_common_download` in a 2-3 attempt retry with `dc_iostream_purge` + short backoff, mirroring the hw_ostc3 wrapper; (b) on persistent failure `break` instead of `return rc`, and return `DC_STATUS_SUCCESS` when at least one dive was delivered (preserves the contiguous-oldest-prefix contract from #480; the newest delivered fingerprint stays a valid high-water mark).
- Modify: `packages/libdivecomputer_plugin/test/native/test_shearwater_petrel_foreach.c` — update `check_stop_on_failure` to the new contract; add (a) oldest-dive-fails -> newer dives still delivered, pass succeeds; (b) transient failure -> retry succeeds -> full delivery.

**Submodule workflow:** commit on a branch in the fork, push the fork FIRST, then bump the superproject pointer in the campaign branch (the plugin's five platform source lists only break when files are added/removed — this change adds none).

**Interfaces:** none new; behavior change is partial-success semantics.

- [ ] **Steps 1-3:** update/add the native tests, build and run them (same cmake/ctest flow as Task 26); expect the new cases to fail against the current abort behavior.
- [ ] **Step 4:** implement retry + partial-success in `shearwater_petrel.c`.
- [ ] **Steps 5-6:** native tests green; `flutter analyze` + full `flutter test` still green (Dart side untouched); commit submodule, push fork branch, bump pointer; PR body `Fixes #759` with the honest caveat that the trigger on the reporter's units (transient BLE loss vs unreadable oldest record) needs their logs, but the zero-dives regression is fixed either way.

---

## Delivery

After all Phase 1 PRs are open: post a single summary comment thread to the orchestrating session's final report (not to GitHub) listing every PR, every closed issue, and every needs-info comment, keyed back to the 43-issue count check in Task 9. Any task that ended in "cannot reproduce" or "scope balloon" must appear in that report with its findings comment linked.
