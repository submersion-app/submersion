# Bulk Re-parse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-parse many dives from stored raw data at once (selected dives, the whole log, or one computer) through one engine, with a blocking, cancellable progress dialog and a results summary.

**Architecture:** A new `ReparseBatchService` wraps `ReparseService.applyParsedUpdate` in a dive-by-dive loop (parse every source first, then apply), with progress and cancel hooks, inside one change-log bulk scope. A `ReparseBatchNotifier` (StateNotifier, the `SiteLocationBackfillNotifier` pattern) owns one run; a shared modal dialog renders it. Three entry points start runs: the dive list selection bar, a new Data tools page, and the existing per-computer button.

**Tech Stack:** Flutter, Riverpod (StateNotifier via `core/providers/provider.dart`), Drift, go_router, ARB l10n.

**Spec:** `docs/design/specs/2026-11-07-bulk-reparse-design.md`

## Global Constraints

- Never use the em-dash character anywhere (code, comments, strings, commits).
- No new code in `reparse_service.dart` beyond delegating `reparseAllForComputer`; it is already about 1,500 lines (800 is the cap).
- Every new user-visible string goes in `app_en.arb` and is translated into all 11 other locale ARBs; regenerate with `flutter gen-l10n`.
- Re-parse UI is hidden when `ref.watch(deviceCapabilitiesProvider).diveComputerDownload` is false.
- Tests inject `parseFn`; never call `pigeon.DiveComputerHostApi` in tests.
- Dates shown to the diver use `unitFormatterProvider` with `l10n: context.l10n`.
- After adding files under `lib/`, run `flutter test test/architecture/ test/shared/`.

## Review Focus

1. A dive with two sources where the second parse throws: nothing on the dive changes (Task 1 test).
2. Cancel pressed during the last dive: result shows 0 not processed, the dialog still ends in the results state (Task 2 test).
3. Selection containing only manual dives: snackbar, no dialog, no change-log entry (Task 4 test).
4. Per-computer run on a dive combined from computers A and B: B's source row `lastParsedAt` is unchanged (Task 1 test).
5. A failed dive deleted before the results load: the row still renders with "--" for its date and no crash (Task 2 test).

---

### Task 1: Batch engine

**Files:**
- Create: `lib/features/dive_computer/data/services/reparse_batch_service.dart`
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (`reparseAllForComputer` delegates; delete `_reparseAllForComputerInner`)
- Modify: `lib/features/dive_computer/presentation/providers/reparse_providers.dart` (add `reparseBatchServiceProvider`)
- Test: `test/features/dive_computer/data/services/reparse_batch_service_test.dart`

**Interfaces:**
- Produces:
  - `typedef RawDiveParseFn = Future<pigeon.ParsedDive> Function(String vendor, String product, int model, Uint8List rawData);`
  - `class ReparseDiveFailure { final String diveId; final String error; }`
  - `class ReparseBatchResult { final int total; final int succeeded; final int skipped; final int notProcessed; final int profilesPreserved; final List<ReparseDiveFailure> failures; int get failed; bool get cancelled; }` (`cancelled` is `notProcessed > 0`; `total` is the dive id count passed in)
  - `class ComputerRawDataCount { final String? computerId; final String computerName; final int dives; }`
  - `class ReparseBatchService` with constructor `ReparseBatchService(ReparseService reparse)` and:
    - `Future<List<String>> diveIdsWithRawData({required String? diverId})`: distinct dive ids with any source whose `raw_data IS NOT NULL`, joined to `dives` and filtered by `dives.diver_id = ?` when `diverId` is non-null, ordered by `dives.dive_date_time`.
    - `Future<List<String>> diveIdsForComputer(String computerId)`: distinct dive ids with a raw-data source from that computer.
    - `Future<List<String>> withRawData(List<String> diveIds)`: the subset of `diveIds` that has a raw-data source, input order kept.
    - `Future<List<ComputerRawDataCount>> rawDataCountsByComputer({required String? diverId})`: dives with raw data grouped by `computer_id`, with `dive_computers.name` (empty string when the computer row is gone; the page localizes that).
    - `Future<int> diveCountWithoutRawData({required String? diverId})`: the diver's dives (`is_planned = 0`) with no raw-data source.
    - `Future<ReparseBatchResult> run(List<String> diveIds, {required RawDiveParseFn parseFn, String? computerId, void Function(int done, int total)? onProgress, bool Function()? isCancelled})`
  - `final reparseBatchServiceProvider = Provider<ReparseBatchService>((ref) => ReparseBatchService(ref.watch(reparseServiceProvider)));`

`run` behaviour, which the tests pin:
- Wraps the loop in `ChangeLogScope.bulk(DatabaseService.instance.databaseOrNull, label: ChangeLogLabels.reparse, body: ...)`.
- For each dive: check `isCancelled` first (true means every remaining dive counts as `notProcessed`, then stop). Load its sources with raw data (`getSourcesForDiveReparse`), filtered to `computerId` when given. No sources: `skipped`. Otherwise parse all of them; a source missing vendor, product or model is a failure with error `'Missing dive computer details'`; a parse that throws, or returns `isEmptyParse`, is a failure with `e.toString()` (or `EmptyParseException().toString()`). Any failure: record `ReparseDiveFailure(diveId, firstError)` and apply nothing. All parsed: `applyParsedUpdate` per source (exception there: record the failure, continue to the next dive); `profilePreserved` on any source adds one to `profilesPreserved`; the dive counts as `succeeded`.
- Call `onProgress(done, total)` after every dive, including skipped and failed ones.
- After the loop, call `scheduleSensorSummaryRefresh(changed)` and `scheduleDerivedMetricsRefresh(changed)` once with every succeeded dive id, when non-empty.

`ReparseService.reparseAllForComputer` keeps its signature and returns `(succeeded: r.succeeded, failed: r.failed)` from `ReparseBatchService(this).run(await ReparseBatchService(this).diveIdsForComputer(computerId), parseFn: parseFn, computerId: computerId)`. Its existing tests in `reparse_service_test.dart` and `reparse_service_empty_parse_test.dart` must still pass unchanged.

- [ ] **Step 1: Write the failing tests** in `reparse_batch_service_test.dart`, reusing the in-memory DB setup and the `insertDive` / `insertComputer` / source-insert helper shapes from `reparse_service_test.dart` (copy what you need; a parsed dive from the same `makeParsedDive` shape):
  - `run re-parses every dive and reports succeeded`: 2 dives, 1 source each, `succeeded == 2`, `failed == 0`, `notProcessed == 0`, `total == 2`.
  - `run skips dives with no raw data`: a dive with no source row, `skipped == 1`.
  - `run applies nothing on a dive when one of its sources fails to parse`: dive with sources `src-a` (vendor Shearwater) and `src-b` (vendor Suunto, parse throws); afterwards both rows' `lastParsedAt` are still null and `failures.single.diveId` is the dive.
  - `run counts missing descriptors as a failure`: error `'Missing dive computer details'`.
  - `run with computerId leaves other computers' sources alone`: dive with sources from comp-A and comp-B, `computerId: 'comp-A'`; comp-A row's `lastParsedAt` is set, comp-B row's is null.
  - `run stops when cancelled and reports the rest as not processed`: 3 dives, `isCancelled` returns true after the first `onProgress` call; `succeeded == 1`, `notProcessed == 2`, `cancelled == true`.
  - `run reports progress after every dive`: recorded calls `[(1,3),(2,3),(3,3)]`.
  - `run records one change-log bulk entry`: after a 2-dive run, the change log holds exactly one entry with label `ChangeLogLabels.reparse` (follow how existing change-log scope tests read it; grep `ChangeLogLabels.reparse` under `test/`).
  - `diveIdsWithRawData filters by diver`: dives for diver-1 and diver-2 with raw data; `diverId: 'diver-1'` returns only diver-1's.
  - `rawDataCountsByComputer groups by computer` and `diveCountWithoutRawData counts manual dives`.
- [ ] **Step 2: Run** `flutter test test/features/dive_computer/data/services/reparse_batch_service_test.dart`. Expected: FAIL (file does not exist).
- [ ] **Step 3: Implement** the service, the provider and the `reparseAllForComputer` delegation.
- [ ] **Step 4: Run** the new test file plus `reparse_service_test.dart` and `reparse_service_empty_parse_test.dart`. Expected: all PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): add a batch re-parse engine with progress and cancel`.

### Task 2: Strings, run notifier and the progress and results dialog

**Files:**
- Modify: `lib/l10n/arb/app_*.arb` (12 files), regenerate `app_localizations*.dart`
- Create: `lib/features/dive_computer/presentation/providers/reparse_batch_provider.dart`
- Create: `lib/features/dive_computer/presentation/widgets/reparse_batch_dialog.dart`
- Test: `test/features/dive_computer/presentation/widgets/reparse_batch_dialog_test.dart`

**Interfaces:**
- Consumes: Task 1's `ReparseBatchService`, `ReparseBatchResult`, `RawDiveParseFn`.
- Produces:
  - `sealed class ReparseBatchState`; `ReparseBatchIdle`; `ReparseBatchRunning({required int done, required int total, required bool cancelling})`; `ReparseBatchFinished({required ReparseBatchResult result, required List<ReparseFailedDive> failedDives})`.
  - `class ReparseFailedDive { final String diveId; final int? diveNumber; final DateTime? date; final String? siteName; final String error; }` (date and site come from `diveRepositoryProvider`'s `getDivesByIdsWithoutSamples`; a dive missing from that result keeps nulls).
  - `class ReparseBatchNotifier extends StateNotifier<ReparseBatchState>` with `Future<void> start(List<String> diveIds, {String? computerId})`, `void cancel()`, `void reset()`.
  - `final reparseBatchProvider = StateNotifierProvider<ReparseBatchNotifier, ReparseBatchState>(...)`.
  - `final reparseParseFnProvider = Provider<RawDiveParseFn>((ref) => pigeon.DiveComputerHostApi().parseRawDiveData);` (tests override it).
  - `Future<void> runReparseBatch(BuildContext context, WidgetRef ref, List<String> diveIds, {String? computerId})`: shows the dialog (`barrierDismissible: false`, wrapped in `PopScope(canPop: false)` until finished), starts the run, and returns when the dialog closes; resets the notifier on close.

Strings (English; translate all locales):
- `reparseBatch_progressTitle`: "Re-parsing dives"
- `reparseBatch_progressCount(done, total)`: "Re-parsing {done} of {total} dives"
- `reparseBatch_cancelling`: "Cancelling..."
- `reparseBatch_resultTitle`: "Re-parse finished"
- `reparseBatch_resultSummary(succeeded, total)`: "Re-parsed {succeeded} of {total} dives."
- `reparseBatch_resultFailed(count)`: plural, "{count} failed." / "1 failed."
- `reparseBatch_resultNotProcessed(count)`: plural, "{count} not processed (cancelled)."
- `reparseBatch_resultSkipped(count)`: plural, "{count} had no raw data and were skipped."
- `reparseBatch_resultProfilesPreserved(count)`: plural, "{count} combined dives kept their combined profile."
- `reparseBatch_failedListHeader`: "Failed dives"
- `reparseBatch_failedDiveTitle(number)`: "Dive {number}"; `reparseBatch_failedDiveUnnumbered`: "Unnumbered dive"
- `reparseBatch_missingDescriptors`: "Missing dive computer details" (the engine's English error is mapped to this in the dialog)
- `reparseBatch_confirmTitle`: "Re-parse dives"
- `reparseBatch_confirmMessage(count)`: "Re-run the dive parser on {count} dives with stored raw data. Your notes, sites, buddies and other edits are preserved."
- `reparseBatch_confirmSkipped(count)`: plural, "{count} selected dives have no raw data and will be skipped."
- `reparseBatch_noneWithRawData`: "None of the selected dives have stored raw data to re-parse."
- `diveLog_selection_tooltip_reparse`: "Re-parse"
- `settings_reparseDives_title`: "Re-parse dives"; `settings_reparseDives_subtitle`: "Re-run the dive parser on every dive with stored raw data"
- `settings_reparseDives_withRawData(count)`: "{count} dives with raw data"; `settings_reparseDives_withoutRawData(count)`: "{count} dives without raw data (not re-parsed)"; `settings_reparseDives_unknownComputer`: "Unknown computer"; `settings_reparseDives_none`: "No dives have stored raw data to re-parse."; `settings_reparseDives_button`: "Re-parse all"

Dialog layout: running state shows title, `LinearProgressIndicator(value: done / total)`, the count line and a Cancel `TextButton` (label `common_action_cancel`, or `reparseBatch_cancelling` and disabled while cancelling). Finished state shows the summary line, then each non-zero failed / not processed / skipped / preserved line, then (when failures exist) the header and a `ListView` of `ListTile`s (title: dive number or unnumbered; subtitle: formatted date, site name when present, error on its own line). Tapping a tile pops the dialog then `context.push('/dives/<id>')`. A Done `FilledButton` closes it.

- [ ] **Step 1: Add the strings** to all 12 ARBs (anchor next to the existing `diveComputer_detail_reparseAll*` group in each file) and run `flutter gen-l10n`.
- [ ] **Step 2: Write the failing widget tests** in `reparse_batch_dialog_test.dart` (override `reparseParseFnProvider` and `reparseBatchServiceProvider` with a fake service whose `run` is driven by a `Completer` per dive):
  - `shows progress and count while running`: finds `LinearProgressIndicator` and "Re-parsing 1 of 3 dives".
  - `cancel disables the button and shows Cancelling`.
  - `cancel during the last dive still ends in results` (Review Focus 2).
  - `results list failed dives and tapping one opens the dive`: with a GoRouter test harness, tap the tile, expect location `/dives/d2`.
  - `a failed dive missing from the repository renders with -- date` (Review Focus 5).
  - `back gesture does not close the dialog while running`.
- [ ] **Step 3: Run** the test file. Expected: FAIL.
- [ ] **Step 4: Implement** the provider file and dialog file.
- [ ] **Step 5: Run** the test file. Expected: PASS. Also `flutter test test/l10n/`.
- [ ] **Step 6: Commit** `feat(dive-computer): add the bulk re-parse progress and results dialog`.

### Task 3: Per-computer button uses the shared flow

**Files:**
- Modify: `lib/features/dive_computer/presentation/widgets/dive_computer_actions_card.dart` (`_executeReparseAll`)
- Test: `test/features/dive_computer/presentation/widgets/dive_computer_actions_card_reparse_test.dart` (new, or extend an existing actions card test if one exists)

**Interfaces:**
- Consumes: `runReparseBatch` (Task 2), `ReparseBatchService.diveIdsForComputer` (Task 1).

`_executeReparseAll` resolves `diveIdsForComputer(computer.id)`, returns when empty, else `await runReparseBatch(context, ref, ids, computerId: computer.id)`. The confirmation dialog and its source-based count stay as they are. The now-unused `diveComputer_detail_reparseAllProgress`, `...Success` and `...Partial` strings are removed from all ARBs only if no other code references them (grep first).

- [ ] **Step 1: Write the failing test** `confirming re-parse all opens the progress dialog filtered to this computer`: fake batch service records `run`'s `computerId`; expect it equals the computer's id and the "Re-parsing dives" title appears.
- [ ] **Step 2: Run it.** Expected: FAIL (snackbar flow).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): show progress and results for a computer's re-parse`.

### Task 4: Dive list "Re-parse" bulk action

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_bulkActions`, new `_reparseSelected`)
- Test: `test/features/dive_log/presentation/widgets/dive_list_reparse_action_test.dart`

**Interfaces:**
- Consumes: `ReparseBatchService.withRawData`, `runReparseBatch`.

Add `BulkAction(id: 'reparse', icon: Icons.restart_alt, label: l10n.diveLog_selection_tooltip_reparse, onInvoke: _reparseSelected)` after `new_trip` and before the rules action, only when `ref.watch(deviceCapabilitiesProvider).diveComputerDownload`. `_reparseSelected`: `withRawData(selected)`; empty gives the `reparseBatch_noneWithRawData` snackbar; else confirm with `reparseBatch_confirmTitle`, `reparseBatch_confirmMessage(n)` plus `reparseBatch_confirmSkipped(selected - n)` when non-zero, buttons Cancel and `common_action_reparse`; on confirm `runReparseBatch(context, ref, ids)`. Return the `BulkActionOutcome` the other actions return for done and cancelled (read `bulk_action.dart`). If `dive_list_content.dart` would pass 800 lines with this, put `_reparseSelected` in a new `dive_list_reparse_action.dart` helper function taking `(BuildContext, WidgetRef, Set<String>)`.

- [ ] **Step 1: Write the failing tests**: `selection bar offers Re-parse`; `Re-parse on manual-only selection shows the snackbar and runs nothing` (Review Focus 3); `Re-parse confirms with the skipped count, then runs the dives with raw data`; `Re-parse is absent when the device cannot parse` (override `deviceCapabilitiesProvider`).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS, plus the existing `dive_list_content` selection tests (`flutter test test/features/dive_log/presentation/widgets/`).
- [ ] **Step 5: Commit** `feat(dive-log): re-parse selected dives from the dive list`.

### Task 5: Data tools "Re-parse dives" page

**Files:**
- Create: `lib/features/settings/presentation/pages/reparse_dives_page.dart`
- Modify: `lib/features/settings/presentation/pages/data_tools_page.dart` (new row, capability gated)
- Modify: `lib/core/router/app_router.dart` (`GoRoute(path: 'reparse-dives', name: 'reparseDives', builder: ... const ReparseDivesPage())` next to `fix-dive-times`)
- Test: `test/features/settings/presentation/pages/reparse_dives_page_test.dart`; extend `test/features/settings/presentation/pages/data_tools_page_test.dart`

**Interfaces:**
- Consumes: `ReparseBatchService.rawDataCountsByComputer`, `.diveCountWithoutRawData`, `.diveIdsWithRawData`; `validatedCurrentDiverIdProvider`; `runReparseBatch`.
- Produces: `final reparseDivesOverviewProvider = FutureProvider<({List<ComputerRawDataCount> byComputer, int withoutRawData})>` in the page file, invalidated by `dive_data_sources` table updates (the `rawDataCountProvider` pattern, `ref.invalidateSelfWhen`).

Page: `AppBar(title: settings_reparseDives_title)`, a total line `settings_reparseDives_withRawData(sum)`, one `ListTile` per computer (name or `settings_reparseDives_unknownComputer`, trailing count), the without-raw-data line, and a `FilledButton.icon(Icons.restart_alt)` labelled `settings_reparseDives_button`, disabled with `settings_reparseDives_none` shown when the sum is 0. Pressing it confirms (`reparseBatch_confirmTitle` / `reparseBatch_confirmMessage(sum)`), then `runReparseBatch(context, ref, await diveIdsWithRawData(diverId: ...))`. The row on Data tools uses `Icons.restart_alt`, the two `settings_reparseDives_*` title and subtitle strings, route `/settings/reparse-dives`.

- [ ] **Step 1: Write the failing tests**: `data tools lists Re-parse dives when the device can parse` and `...hides it when it cannot`; `page shows per-computer counts and the without count`; `button disabled with the none message when there is no raw data`; `confirming runs every dive with raw data for the active diver`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both test files plus `flutter test test/architecture/ test/shared/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(settings): add a Data tools page to re-parse every dive`.

### Task 6: Whole-branch verification

- [ ] **Step 1:** `dart format .` then `flutter analyze` (whole repo). Expected: no issues.
- [ ] **Step 2:** `flutter test test/features/dive_computer/ test/features/settings/ test/features/dive_log/presentation/ test/architecture/ test/shared/ test/l10n/`. Expected: all pass.
- [ ] **Step 3:** After screenshots of the Data tools page, the Re-parse dives page, the dive list selection overflow menu, the progress dialog and the results dialog with a failure.
