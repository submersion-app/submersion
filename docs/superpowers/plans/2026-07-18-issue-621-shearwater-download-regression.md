# Issue #621: Shearwater Download Regression Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore working Shearwater dive-computer downloads (broken for all users since build 114) by reverting the untested on-device request-order change, while preserving issue #480's resume intent app-side.

**Architecture:** The libdivecomputer fork commits `714a2e5` (oldest-first delivery) and `7e8fd9a` (download records behind deleted manifest entries) changed the request pattern sent to real Petrel-family firmware; no Shearwater client had ever issued requests in that order, and all real devices tested (Teric, Perdix 2 AI, Petrel 3) fail on both Android and Windows since build 114 — first bad request aborts the whole pass with zero dives delivered. Fix: revert both fork commits (restoring the upstream-proven, decade-tested newest-first order), and move #480's resume correctness app-side by gating fingerprint advancement on download completeness (a partial newest-first delivery must not advance the resume point, or older dives are stranded — the original #480 bug).

**Tech Stack:** C (libdivecomputer fork, submodule at `packages/libdivecomputer_plugin/third_party/libdivecomputer`, branch `submersion-patches` on `github.com/submersion-app/libdivecomputer`), native CMake tests, Flutter/Dart app layer.

## Global Constraints

- Fork-first push order: the fork commit must be pushed to `origin submersion-patches` BEFORE the main-repo submodule bump is pushed (memory: shearwater-oldest-first).
- No emojis anywhere; `dart format .` clean before commit; `flutter analyze` clean.
- Never pipe `flutter analyze` through `tail`/`head` filters that mask failure (memory: analyze-pipe-masks).
- Use `env -u GITHUB_TOKEN` for `gh`/git push operations (memory: github-token-shadows-keyring).
- PR bodies: no Claude attribution, no session URL (CLAUDE.md).
- The submodule revert must not add or remove source files (the 5 hand-curated per-platform source lists would otherwise drift — memory: libdc-platform-source-lists-drift). Reverting `714a2e5`/`7e8fd9a` only edits `src/shearwater_petrel.c` — safe.
- Commits in the worktree branch `worktree-issue-621-shearwater-ble-connect`; plan commits are pre-authorized (memory: plan-commits-preauthorized).

---

### Task 1: Revert the two Shearwater manifest commits in the libdivecomputer fork and push

**Files:**
- Modify: `packages/libdivecomputer_plugin/third_party/libdivecomputer/src/shearwater_petrel.c` (via `git revert` inside the submodule)

**Interfaces:**
- Produces: fork commit on `submersion-patches` whose `shearwater_petrel_device_foreach` matches upstream behavior again (newest-first forward walk, `count * RECORD_SIZE` manifest append, deleted records counted in progress maximum). Task 3 pins the submodule to this commit.

- [ ] **Step 1: Create revert commit in the submodule**

```bash
cd packages/libdivecomputer_plugin/third_party/libdivecomputer
git checkout -b issue-621-revert-manifest-order 1a47a011a9ae2b2253ccb768efd05d37067acb3c
git revert --no-commit 7e8fd9a 714a2e5
git commit -m "Revert Shearwater oldest-first delivery and behind-deleted manifest downloads

This reverts commits 714a2e5 (Deliver Shearwater Petrel dives oldest to
newest) and 7e8fd9a (Preserve Shearwater manifest records behind deleted
dives).

Both commits changed the dive-payload request pattern sent to real
Petrel-family firmware: payloads were requested oldest-first, and records
hidden behind deleted (0x5A23) manifest entries were requested for the
first time ever. No Shearwater client (Shearwater Cloud, Subsurface,
upstream libdivecomputer) has ever issued requests in that order, and no
hardware validation was performed before shipping. Since the first build
carrying these commits, downloads fail on real devices (Teric, Perdix 2
AI, Petrel 3) on both Android and Windows immediately after the manifest
transfer: the first rejected dive request aborts the whole pass
(shearwater_common_download treats any unexpected response as fatal), so
zero dives are ever delivered.

See submersion-app/submersion#621. The resume-after-partial-download goal
of the original commits (submersion-app/submersion#480) moves to the app
layer: the resume fingerprint now only advances after a download that ran
to completion. Re-landing an on-device ordering change requires hardware
validation first."
```

- [ ] **Step 2: Verify the revert only touched shearwater_petrel.c and matches pre-114 content**

```bash
git diff HEAD~1 --stat            # expect: only src/shearwater_petrel.c
git diff 2b38c6e HEAD -- src/shearwater_petrel.c   # expect: ONLY the V2 signature lines (device_open/setup model param)
```

- [ ] **Step 3: Push the fork branch to submersion-patches**

```bash
env -u GITHUB_TOKEN git push origin HEAD:submersion-patches
```
Expected: fast-forward push succeeds (origin/submersion-patches is at `1a47a01`).

### Task 2: Rewrite the native regression test to lock newest-first behavior (red first)

**Files:**
- Modify: `packages/libdivecomputer_plugin/test/native/test_shearwater_petrel_foreach.c`
- Modify: `packages/libdivecomputer_plugin/test/native/CMakeLists.txt` (comment block only)

**Interfaces:**
- Consumes: the mock transport harness already in the test file (`script_reset`, `set_record`, `script_add_dive`, `run_foreach`, `expect`, `order_is`).
- Produces: test expectations matching upstream (reverted) driver behavior; used by Task 3 to verify the submodule bump.

- [ ] **Step 1: Rewrite the file header comment** to document issue #621: dive payloads MUST be requested newest-first (manifest order); oldest-first and behind-deleted requests broke real Teric/Perdix 2/Petrel 3 hardware in the field; the #480 resume goal now lives app-side (fingerprint advances only after a complete download). Keep the mock-transport description.

- [ ] **Step 2: Replace the six checks** with these (full bodies; `want` arrays are the deliverable):
  - `check_newest_first`: records `[3,2,1]` (slot 0 newest) → delivered `{3,2,1}`, `rc == DC_STATUS_SUCCESS`, contract_ok.
  - `check_deleted_records_skipped`: records `[4, D, 3, D, 2, 1]` → delivered `{4,3}` (upstream truncates the append at `count * RECORD_SIZE`, so dives behind deleted records are not requested — documented as a known upstream data-loss limitation, intentionally restored pending hardware-validated re-fix; reference #480/#621 in the comment).
  - `check_stop_on_failure`: records `[3,2,1]`, dive 2 scripted to fail → `rc == DC_STATUS_TIMEOUT`, delivered `{3}` (newest prefix).
  - `check_fingerprint_resume`: records `[4,3,D,2,1]`, resume fingerprint = dive 2 → delivered `{4,3}`.
  - `check_progress_accounting`: records `[2, D, 1]` → delivered `{2}` only (truncation), final progress `current == 2 * NSTEPS`, `maximum == 4 * NSTEPS` (deleted records count into maximum and progress does NOT reach 100% — known upstream cosmetic behavior, documented).
  - `check_multi_page`: page 0 = 48 valid ids 49..2, page 1 slot 0 = id 1 → delivered `{49..1}` descending.

- [ ] **Step 3: Update the CMakeLists comment** above `test_shearwater_petrel_foreach` ("must deliver dives oldest first ..." → "must request dive payloads newest-first, manifest order — issue #621: ascending-order requests broke real Shearwater hardware; #480 resume is handled app-side").

- [ ] **Step 4: Build and run — expect FAIL against the current (pre-revert) submodule pointer**

```bash
cd packages/libdivecomputer_plugin/test/native
cmake -B build -S . && cmake --build build --target test_shearwater_petrel_foreach
./build/test_shearwater_petrel_foreach
```
Expected: FAIL lines (delivered order is oldest-first because the submodule still has the reverted-in-Task-1 commits checked out only in the fork branch; the worktree submodule checkout is updated in Task 3).

### Task 3: Pin the submodule to the revert commit, drop the stale patch mirrors (green)

**Files:**
- Modify: submodule pointer `packages/libdivecomputer_plugin/third_party/libdivecomputer`
- Delete: `packages/libdivecomputer_plugin/patches/0003-shearwater-oldest-first.patch`
- Delete: `packages/libdivecomputer_plugin/patches/0004-shearwater-manifest-deleted-records.patch`

**Interfaces:**
- Consumes: fork commit from Task 1; test expectations from Task 2.

- [ ] **Step 1:** `cd packages/libdivecomputer_plugin/third_party/libdivecomputer && git checkout issue-621-revert-manifest-order` (detach at the new commit is fine).
- [ ] **Step 2:** `git rm packages/libdivecomputer_plugin/patches/0003-shearwater-oldest-first.patch packages/libdivecomputer_plugin/patches/0004-shearwater-manifest-deleted-records.patch`; then `grep -rn '0003-shearwater\|0004-shearwater' --exclude-dir=third_party .` → expect no remaining references.
- [ ] **Step 3: Rebuild and run the native test — expect PASS**

```bash
cd packages/libdivecomputer_plugin/test/native
cmake --build build --target test_shearwater_petrel_foreach && ./build/test_shearwater_petrel_foreach
```
Expected: `All shearwater_petrel_foreach tests passed.`
Also build+run the other native targets that compile petrel/common sources: `cmake --build build && ctest --test-dir build` → all pass.
- [ ] **Step 4: Commit** (submodule bump + deleted patches + test rewrite + CMake comment, one commit):

```bash
git add packages/libdivecomputer_plugin
git commit -m "fix(shearwater): restore newest-first dive downloads (#621)"
```

### Task 4: Gate fingerprint advancement on download completeness (TDD)

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`
- Test: `test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart`

**Interfaces:**
- Produces: `DiveComputerAdapter.setDownloadedDives(List<DownloadedDive> dives, {bool downloadComplete = true})`; `_updateComputerAfterImport(..., {required bool advanceFingerprint})`. Task 5 passes `downloadComplete: state.isComplete` from the wizard.

- [ ] **Step 1: Write the failing test** in `dive_computer_adapter_test.dart` (follow the file's existing fake/mocks setup for `performImport` tests):

```dart
group('partial download fingerprint gating', () {
  test('a complete download advances the fingerprint', () async {
    // arrange adapter with computer + two downloaded dives (existing helpers)
    adapter.setDownloadedDives(dives); // downloadComplete defaults to true
    await adapter.performImport(bundle, selections, {});
    expect(computerRepository.lastFingerprintUpdates, isNotEmpty);
  });

  test('an interrupted download imports dives but keeps the old fingerprint',
      () async {
    adapter.setDownloadedDives(dives, downloadComplete: false);
    final result = await adapter.performImport(bundle, selections, {});
    expect(result.importedCounts[ImportEntityType.dives], dives.length);
    expect(computerRepository.lastFingerprintUpdates, isEmpty);
  });
});
```
(Adapt names to the file's existing fake repository; if the fake lacks a fingerprint-update recorder, add `lastFingerprintUpdates` to it.)

- [ ] **Step 2: Run to verify failure**: `flutter test test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart` → the new second test fails (fingerprint advanced) or fails to compile (named param missing) — both acceptable red states.

- [ ] **Step 3: Implement** in `dive_computer_adapter.dart`:
  - Add field `bool _downloadWasComplete = true;`
  - `setDownloadedDives`:

```dart
  /// Load the list of downloaded dives into this adapter.
  ///
  /// Called by the wizard when the download completes, or when the user
  /// imports the dives delivered before an interrupted download.
  /// [downloadComplete] records whether the native download ran to
  /// completion. Dives are delivered newest-first (issue #621: real
  /// Shearwater hardware rejects any other request order), so a partial
  /// delivery is a newest-suffix of the logbook: advancing the resume
  /// fingerprint from it would strand every older dive that was never
  /// delivered (issue #480). Partial imports therefore keep the previous
  /// fingerprint.
  void setDownloadedDives(
    List<DownloadedDive> dives, {
    bool downloadComplete = true,
  }) {
    _downloadedDives = List.unmodifiable(dives);
    _downloadWasComplete = downloadComplete;
  }
```
  - `performImport` call site:

```dart
    final wasCancelled = cancelToken?.isCancelled ?? false;
    await _updateComputerAfterImport(
      comp,
      imported,
      wasCancelled ? processedDives : _downloadedDives,
      advanceFingerprint: _downloadWasComplete,
    );
```
  - `_updateComputerAfterImport`: add `{required bool advanceFingerprint}`; wrap the `selectNewestFingerprint`/`updateLastFingerprint` block in `if (advanceFingerprint)`. Keep dive-count increment and `updateLastDownload` unconditional. Update its doc comment: import-phase cancellation still advances (import order is chronological, so `processedDives` is an oldest-prefix of a COMPLETE delivery — safe); download-phase interruption must not.

- [ ] **Step 4: Run tests to verify pass**: `flutter test test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart test/features/import_wizard/data/adapters/dive_computer_adapter_reimport_test.dart` → PASS.
- [ ] **Step 5: Commit**: `git commit -m "fix(import): only advance DC resume fingerprint after a complete download (#621)"`

### Task 5: Wire completeness through the wizard and fix stale ordering comments

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/dc_adapter_steps.dart:400` (`_captureAndAdvance`)
- Modify: `lib/features/dive_computer/presentation/widgets/download_step_widget.dart:20-27,246` (doc comments only)
- Test: `test/features/import_wizard/presentation/widgets/dc_adapter_download_step_force_full_test.dart` (existing suite must stay green; add partial-capture assertion if the file already fakes an interrupted state)

**Interfaces:**
- Consumes: `setDownloadedDives(..., downloadComplete:)` from Task 4; `DownloadState.isComplete`.

- [ ] **Step 1:** In `_captureAndAdvance`:

```dart
    widget.adapter.setDownloadedDives(
      state.downloadedDives,
      downloadComplete: state.isComplete,
    );
```
- [ ] **Step 2:** Replace the `onImportPartial` comment in `dc_adapter_steps.dart` (lines ~383-389) and the `onImportPartial` doc comment in `download_step_widget.dart` (lines 20-27, and the note near line 246): dives arrive newest-first; a partial set is kept but the resume fingerprint does not advance; the next download re-fetches from the top and duplicate detection skips already-imported dives.
- [ ] **Step 3:** `flutter test test/features/import_wizard/ test/features/dive_computer/` → PASS (fix any test that asserted fingerprint-advance-on-partial to the new contract).
- [ ] **Step 4:** Commit: `git commit -m "fix(import): thread download completeness into the wizard capture path (#621)"`

### Task 6: Full verification

- [ ] `dart format .` → no changes (or commit formatting).
- [ ] `flutter analyze` → 0 issues (full output, unfiltered).
- [ ] `flutter test test/features/import_wizard/ test/features/dive_computer/` and the native `ctest` suite → all pass.
- [ ] Grep for leftover claims: `grep -rn 'oldest-first\|oldest first' lib/ packages/libdivecomputer_plugin/test/ --include='*.dart' --include='*.c' --include='*.txt'` → only historical docs/release notes remain.

### Task 7: Push, PR, memory

- [ ] Push worktree branch: `env -u GITHUB_TOKEN git push -u origin worktree-issue-621-shearwater-ble-connect` (if the main-tree pre-push hook fails on known-flaky unrelated tests, isolate per memory flaky-backup-tests-full-suite before considering `--no-verify`).
- [ ] Open PR to `main`: title `fix(shearwater): restore newest-first downloads broken since build 114 (#621)`. Body: regression evidence (build window, submodule delta, three devices/two platforms), root cause, the revert + app-side gating design, what #480 keeps (partial import + dedup) and loses (device-side resume — follow-up requires hardware validation), and smoke-test instructions including clearing the poisoned Android bond (forget the DC in Bluetooth settings, power-cycle the DC) because repeated failed sessions leave stale bond keys (`status=5`). No attribution/session lines.
- [ ] Update memory: `project_shearwater_oldest_first_480.md` (oldest-first REVERTED for #621 — request order is firmware-sensitive, never ship DC protocol-order changes without hardware smoke) and add `project_shearwater_download_regression_621.md`; update `MEMORY.md` index.

## Self-Review

- Spec coverage: regression revert (Tasks 1-3), resume preservation (Tasks 4-5), verification (Task 6), delivery (Task 7). The user's Teric connect failure is addressed as documentation (bond clearing) — no code change, matching the evidence that `BleIoStream.kt` is unchanged since build 113.
- Placeholder scan: Task 4 Step 1 asks the implementer to adapt to the existing fake — acceptable because the exact fake API must be read from the test file; the assertion contract is fully specified.
- Type consistency: `setDownloadedDives(..., {bool downloadComplete = true})` used identically in Tasks 4 and 5; `advanceFingerprint` named param defined and consumed in Task 4 only.
