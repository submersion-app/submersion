# Dive matching time-gate + file-import consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the file-import matcher from flagging dives that are far apart in time as duplicates, and let file imports manually Consolidate a matched dive (both prompted by ScubaBoard tester report, post 10791329).

**Architecture:** Part 1 adds a necessary time-gate inside the pure `DiveMatcher` scoring function, fixing every file-import consumer at once. Part 2 ports the already-built-but-orphaned consolidation wiring (`performConsolidations` + `result.diveIdByIndex`) into the live `UniversalAdapter`, reusing `DiveConsolidationService` and the existing review UI (which reacts to the adapter's `supportedDuplicateActions`).

**Tech Stack:** Flutter/Dart, Drift (SQLite), Riverpod, flutter_test + mockito, real-DB test harness (`setUpTestDatabase`).

**Spec:** `docs/superpowers/specs/2026-07-06-dive-matching-time-gate-and-file-import-consolidation-design.md`

## Global Constraints

- All work happens in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-match-consolidate` (branch `worktree-dive-match-consolidate`). Paths below are repo-relative to that root.
- `dart format .` must produce no changes; `flutter analyze` must be clean across the whole project (not a filtered subset).
- No emojis in code, comments, or docs. Immutability; no object/array mutation of shared state. Proper error handling.
- TDD: write the failing test first, watch it fail, then implement.
- Commit messages: conventional style, imperative. Do NOT add `Co-Authored-By` trailers.
- Run codegen before tests (fresh worktree has no `*.g.dart` / `*.mocks.dart`).
- The 15-minute boundary is fixed (approved): a dive pair with `timeScore == 0.0` (starts >= 15 min apart) is never a match.

## File Structure

Production:
- `lib/features/dive_import/domain/services/dive_matcher.dart` — add the time-gate short-circuit in `calculateMatchScore`. (Part 1)
- `lib/features/universal_import/data/services/import_duplicate_checker.dart` — set `matchedExistingSource: true` on the Pass 0 `sourceUuid` match. (Part 2)
- `lib/features/import_wizard/data/adapters/universal_adapter.dart` — add `consolidate` to `supportedDuplicateActions`, treat `consolidate` like `importAsNew` in `_resolveSelections`, and fold consolidate-flagged dives in `performImport`. (Part 2)

Tests:
- `test/features/dive_import/domain/services/dive_matcher_test.dart` — gate unit tests. (Part 1)
- `test/features/universal_import/data/services/import_duplicate_checker_test.dart` — `matchedExistingSource` + far-apart-not-matched. (Part 1 + 2)
- `test/features/import_wizard/data/adapters/universal_adapter_test.dart` — `supportedDuplicateActions` includes `consolidate`. (Part 2)
- `test/features/import_wizard/data/adapters/universal_adapter_consolidate_integration_test.dart` — NEW, real-DB fold. (Part 2)

Reused unchanged: `performConsolidations` (`lib/features/universal_import/presentation/providers/import_consolidation_service.dart`) and its test — the adapter wraps its match map in the existing `ImportDuplicateResult(diveMatches: ...)`, so no signature change.

---

### Task 0: Worktree bootstrap

**Files:** none (environment only).

- [ ] **Step 1: Initialize submodules**

Run: `git -C /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-match-consolidate submodule update --init --recursive`
Expected: submodules checked out (libdivecomputer etc.), no error.

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: "Got dependencies!".

- [ ] **Step 3: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: build completes; `lib/core/database/database.g.dart` and test `*.mocks.dart` exist.

- [ ] **Step 4: Baseline the affected tests compile/pass**

Run: `flutter test test/features/dive_import/domain/services/dive_matcher_test.dart test/features/universal_import/data/services/import_duplicate_checker_test.dart test/features/import_wizard/data/adapters/universal_adapter_test.dart test/features/universal_import/presentation/providers/import_consolidation_service_test.dart`
Expected: all PASS (green baseline before changes).

---

### Task 1: Time-gate in `DiveMatcher`

**Files:**
- Modify: `lib/features/dive_import/domain/services/dive_matcher.dart:24-34`
- Test: `test/features/dive_import/domain/services/dive_matcher_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: no signature change. `DiveMatcher.calculateMatchScore(...)` now returns `0.0` whenever the two start times are >= 15 minutes apart, regardless of depth/duration.

- [ ] **Step 1: Write the failing tests**

Add these tests inside the existing `group('calculateMatchScore', ...)` block in `dive_matcher_test.dart` (after the "handles zero existing depth" test):

```dart
test('gates to 0 for dives months apart even with identical '
    'depth and duration (ScubaBoard report regression)', () {
  // Months apart, both 47 min, similar depth previously scored exactly
  // 0.50 = (0*0.5)+(1*0.3)+(1*0.2) and was flagged as a possible duplicate.
  final score = matcher.calculateMatchScore(
    wearableStartTime: DateTime(2026, 3, 15, 10, 0),
    wearableMaxDepth: 18.0,
    wearableDurationSeconds: 47 * 60,
    existingStartTime: DateTime(2026, 6, 20, 14, 0),
    existingMaxDepth: 18.0,
    existingDurationSeconds: 47 * 60,
  );

  expect(score, 0.0);
  expect(matcher.isPossibleDuplicate(score), isFalse);
});

test('gates to 0 for same-day dives hours apart with identical '
    'depth and duration', () {
  final score = matcher.calculateMatchScore(
    wearableStartTime: DateTime(2026, 3, 15, 9, 0),
    wearableMaxDepth: 18.0,
    wearableDurationSeconds: 45 * 60,
    existingStartTime: DateTime(2026, 3, 15, 14, 0),
    existingMaxDepth: 18.0,
    existingDurationSeconds: 45 * 60,
  );

  expect(score, 0.0);
});

test('gates to 0 exactly at the 15-minute boundary', () {
  final score = matcher.calculateMatchScore(
    wearableStartTime: DateTime(2026, 1, 15, 10, 0),
    wearableMaxDepth: 18.5,
    wearableDurationSeconds: 45 * 60,
    existingStartTime: DateTime(2026, 1, 15, 10, 15),
    existingMaxDepth: 18.5,
    existingDurationSeconds: 45 * 60,
  );

  expect(score, 0.0);
});

test('still scores a near-in-time match within the 15-minute window', () {
  // 14 min apart: timeScore = 1 - ((14-5)/10) = 0.1
  // composite = (0.1*0.5)+(1*0.3)+(1*0.2) = 0.55 -> still a possible match.
  final score = matcher.calculateMatchScore(
    wearableStartTime: DateTime(2026, 1, 15, 10, 0),
    wearableMaxDepth: 18.5,
    wearableDurationSeconds: 45 * 60,
    existingStartTime: DateTime(2026, 1, 15, 10, 14),
    existingMaxDepth: 18.5,
    existingDurationSeconds: 45 * 60,
  );

  expect(score, greaterThan(0.0));
  expect(score, closeTo(0.55, 0.0001));
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_import/domain/services/dive_matcher_test.dart`
Expected: the four new tests FAIL (the months-apart / same-day / boundary tests currently return ~0.5 instead of 0.0).

- [ ] **Step 3: Implement the gate**

In `lib/features/dive_import/domain/services/dive_matcher.dart`, replace the body of `calculateMatchScore` (the block computing `timeScore`, `depthScore`, `durationScore`, and the weighted return) with:

```dart
final timeScore = _calculateTimeScore(wearableStartTime, existingStartTime);

// Time is a NECESSARY condition, not just a weighted term. `_calculateTimeScore`
// is 0.0 once the two starts are >= 15 min apart; with no time evidence, a
// depth + duration coincidence (0.30 + 0.20 = 0.50) must not be able to reach
// the possible-duplicate threshold. Two recordings that do not line up in time
// cannot be the same physical dive.
if (timeScore <= 0) return 0.0;

final depthScore = _calculateDepthScore(wearableMaxDepth, existingMaxDepth);
final durationScore = _calculateDurationScore(
  wearableDurationSeconds,
  existingDurationSeconds,
);

// Weighted composite score
return (timeScore * 0.50) + (depthScore * 0.30) + (durationScore * 0.20);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_import/domain/services/dive_matcher_test.dart`
Expected: PASS, including the pre-existing tests (identical -> >0.9; 8 min -> >0.7; 20 min -> `lessThanOrEqualTo(0.5)` still holds because 20 min now yields exactly 0.0; depth/duration/zero-depth cases have identical times so the gate does not trigger).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_import/domain/services/dive_matcher.dart test/features/dive_import/domain/services/dive_matcher_test.dart
git commit -m "fix(import): gate dive matcher on time so far-apart dives are not flagged as duplicates"
```

---

### Task 2: Checker marks exact re-imports, and no longer matches far-apart dives

**Files:**
- Modify: `lib/features/universal_import/data/services/import_duplicate_checker.dart:709-714`
- Test: `test/features/universal_import/data/services/import_duplicate_checker_test.dart`

**Interfaces:**
- Consumes: `DiveMatcher` time-gate from Task 1 (far-apart pairs now score 0.0, so `_checkDiveDuplicates` Pass 1 does not record them).
- Produces: Pass 0 `sourceUuid` matches now carry `matchedExistingSource: true`; Pass 1 (content) matches keep `matchedExistingSource: false`. This is what makes the wizard default exact re-imports to skip and exclude them from bulk-consolidate.

- [ ] **Step 1: Write the failing tests**

In `import_duplicate_checker_test.dart`, inside `group('Dive duplicates (source_uuid)', ...)`, add a test asserting the flag (reuse the same payload/existing-dive construction the sibling "first-pass source_uuid match takes precedence" test at line 459 already uses; the incoming dive map carries `'sourceUuid': 'XYZ'` and `existingSourceUuidByDiveId` maps the existing dive's id to `'XYZ'`):

```dart
test('source_uuid match flags matchedExistingSource so it defaults to '
    'skip', () {
  final result = const ImportDuplicateChecker().check(
    payload: _payloadWithDive({
      'dateTime': DateTime(2026, 1, 15, 10, 0),
      'maxDepth': 18.0,
      'runtime': const Duration(minutes: 45),
      'sourceUuid': 'XYZ',
    }),
    existingDives: [
      _existingDive(
        id: 'existing-1',
        dateTime: DateTime(2026, 1, 15, 10, 0),
        maxDepth: 18.0,
        runtime: const Duration(minutes: 45),
      ),
    ],
    existingSites: const [],
    existingTrips: const [],
    existingEquipment: const [],
    existingBuddies: const [],
    existingDiveCenters: const [],
    existingCertifications: const [],
    existingTags: const [],
    existingDiveTypes: const [],
    existingSourceUuidByDiveId: const {'existing-1': 'XYZ'},
  );

  final match = result.diveMatchFor(0);
  expect(match, isNotNull);
  expect(match!.matchedExistingSource, isTrue);
});
```

In `group('Dive duplicates (fuzzy)', ...)`, add two tests — the content-match flag and the Part 1 far-apart regression at the checker level:

```dart
test('content (fuzzy) match leaves matchedExistingSource false', () {
  final result = const ImportDuplicateChecker().check(
    payload: _payloadWithDive({
      'dateTime': DateTime(2026, 1, 15, 10, 0),
      'maxDepth': 18.0,
      'runtime': const Duration(minutes: 45),
    }),
    existingDives: [
      _existingDive(
        id: 'existing-1',
        dateTime: DateTime(2026, 1, 15, 10, 2),
        maxDepth: 18.0,
        runtime: const Duration(minutes: 45),
      ),
    ],
    existingSites: const [],
    existingTrips: const [],
    existingEquipment: const [],
    existingBuddies: const [],
    existingDiveCenters: const [],
    existingCertifications: const [],
    existingTags: const [],
    existingDiveTypes: const [],
  );

  final match = result.diveMatchFor(0);
  expect(match, isNotNull);
  expect(match!.matchedExistingSource, isFalse);
});

test('does not match a dive far apart in time even with identical '
    'depth and duration', () {
  final result = const ImportDuplicateChecker().check(
    payload: _payloadWithDive({
      'dateTime': DateTime(2026, 3, 15, 10, 0),
      'maxDepth': 18.0,
      'runtime': const Duration(minutes: 47),
    }),
    existingDives: [
      _existingDive(
        id: 'existing-1',
        dateTime: DateTime(2026, 6, 20, 14, 0),
        maxDepth: 18.0,
        runtime: const Duration(minutes: 47),
      ),
    ],
    existingSites: const [],
    existingTrips: const [],
    existingEquipment: const [],
    existingBuddies: const [],
    existingDiveCenters: const [],
    existingCertifications: const [],
    existingTags: const [],
    existingDiveTypes: const [],
  );

  expect(result.diveMatches, isEmpty);
});
```

Note: `_payloadWithDive` / `_existingDive` are the helper builders this test file already uses for its fuzzy and source_uuid groups. If their names differ, reuse whatever the neighboring tests in this file call to build a single-dive `ImportPayload` and an existing `Dive`. Do not invent new fixtures.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/import_duplicate_checker_test.dart`
Expected: the `matchedExistingSource is true` test FAILS (currently the Pass 0 result has the default `false`). The other two should already pass after Task 1 (they document behavior); if the far-apart test fails, Task 1 was not applied.

- [ ] **Step 3: Implement the flag**

In `import_duplicate_checker.dart`, in `_checkDiveDuplicates`, the Pass 0 block that builds the `sourceUuid` match (currently constructs `DiveMatchResult(diveId: existing.id, score: _sourceUuidMatchScore, timeDifferenceMs: 0, siteName: existing.site?.name)`) — add `matchedExistingSource: true`:

```dart
matches[i] = DiveMatchResult(
  diveId: existing.id,
  score: _sourceUuidMatchScore,
  timeDifferenceMs: 0,
  siteName: existing.site?.name,
  matchedExistingSource: true,
);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/import_duplicate_checker_test.dart`
Expected: PASS (all three new tests plus the existing suite).

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/services/import_duplicate_checker.dart test/features/universal_import/data/services/import_duplicate_checker_test.dart
git commit -m "feat(import): flag exact source_uuid re-imports as existing-source so they default to skip"
```

---

### Task 3: `UniversalAdapter` offers and performs Consolidate for file imports

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (imports; `supportedDuplicateActions` at line 140; `_resolveSelections` at line 699; `performImport` return block at lines 461-476)
- Test: `test/features/import_wizard/data/adapters/universal_adapter_test.dart` (supported-actions unit test)
- Create: `test/features/import_wizard/data/adapters/universal_adapter_consolidate_integration_test.dart` (real-DB fold)

**Interfaces:**
- Consumes: `performConsolidations({required Set<int> indices, required Map<int,String> diveIdByIndex, required ImportDuplicateResult? duplicateResult, required DiveConsolidationService consolidationService, required DiveRepository diveRepository})` returning `ConsolidationSummary(consolidated, failed)` (unchanged); `diveConsolidationServiceProvider` (`Provider<DiveConsolidationService>`); `UddfEntityImportResult` fields `dives` (int), `diveIds` (`List<String>`), `diveIdByIndex` (`Map<int,String>`); `ImportDuplicateResult(diveMatches: Map<int,DiveMatchResult>)`.
- Produces: `UniversalAdapter.supportedDuplicateActions` now includes `DuplicateAction.consolidate`; `performImport` returns a `UnifiedImportResult` whose `consolidatedCount` reflects folded dives, whose `importedCounts[dives]` excludes folded/failed dives, and whose `importedDiveIds` excludes tombstoned standalone dives. File imports never auto-consolidate (`currentComputerId` stays null).

- [ ] **Step 1: Write the failing supported-actions unit test**

In `universal_adapter_test.dart`, add (in whatever top-level `group` covers adapter metadata; if none, add a new `group('supportedDuplicateActions', ...)`):

```dart
test('supports consolidate so the review UI offers it for file imports', () {
  late UniversalAdapter adapter;
  // Reuse this file's existing pattern for obtaining a WidgetRef-backed
  // adapter (the buildBundle tests already construct one via a ProviderScope
  // widget). Capture that adapter here.
  // adapter = UniversalAdapter(ref: capturedRef);
  expect(
    adapter.supportedDuplicateActions,
    containsAll(<DuplicateAction>{
      DuplicateAction.skip,
      DuplicateAction.importAsNew,
      DuplicateAction.consolidate,
    }),
  );
});
```

If constructing the adapter for a pure metadata check is awkward in this harness, instead assert against a directly-constructed adapter using a throwaway container ref, following the exact `UniversalAdapter(ref: ...)` construction the buildBundle tests already use in this file.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart`
Expected: FAIL — `consolidate` is not yet in the set.

- [ ] **Step 3: Add `consolidate` to supported actions and selection resolution**

In `universal_adapter.dart`, change `supportedDuplicateActions` (line 140):

```dart
@override
Set<DuplicateAction> get supportedDuplicateActions => const {
  DuplicateAction.skip,
  DuplicateAction.importAsNew,
  DuplicateAction.consolidate,
};
```

And in `_resolveSelections` (line 715 loop), include consolidate-flagged indices in the import so they are persisted as standalone dives before folding:

```dart
for (final entry in actions.entries) {
  if (entry.value == DuplicateAction.importAsNew ||
      entry.value == DuplicateAction.consolidate) {
    resolved.add(entry.key);
  }
}
```

- [ ] **Step 4: Run to verify the unit test passes**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_test.dart`
Expected: PASS (supported-actions test and the existing suite).

- [ ] **Step 5: Write the failing real-DB integration test**

Create `test/features/import_wizard/data/adapters/universal_adapter_consolidate_integration_test.dart`. Model the DB/service setup on `dive_computer_adapter_consolidate_integration_test.dart` (real `setUpTestDatabase()`, real `DiveRepository()`, real `DiveConsolidationService(diveRepository)`, seed a diver and a target dive), and model the adapter/provider wiring on `universal_adapter_test.dart`'s `performImport` harness (`_TestableImportNotifier.setPayload`, provider overrides, ProviderScope widget to obtain the adapter's `WidgetRef`). Override repos with REAL instances backed by the test DB (not mocks), and override `diveConsolidationServiceProvider` with the real `DiveConsolidationService`.

Scenario and assertions:

```dart
// Arrange:
//  - diver 'diver-1'
//  - existing target dive 'target-dive' at entryTime = DateTime.utc(2026,7,1,9),
//    runtime 40 min, maxDepth 25.0, diverId 'diver-1'
//  - a file-import ImportPayload with ONE dive overlapping the target:
//      { 'dateTime': entryTime, 'maxDepth': 24.5,
//        'runtime': const Duration(minutes: 40), 'sourceUuid': 'sub-1' }
//    (build it with the same payload helper the performImport tests use)
//  - notifier.setPayload(payload)
//
// Act:
final checked = await adapter.checkDuplicates(await adapter.buildBundle());
final result = await adapter.performImport(
  checked,
  {wizard.ImportEntityType.dives: {0}},
  {wizard.ImportEntityType.dives: {0: DuplicateAction.consolidate}},
);

// Assert:
expect(result.consolidatedCount, equals(1));
// dives imported as NEW excludes the folded one:
expect(result.importedCounts[wizard.ImportEntityType.dives] ?? 0, equals(0));
// Only the target dive remains; the standalone import was folded + tombstoned:
final allDives = await db.select(db.dives).get();
expect(allDives, hasLength(1));
expect(allDives.single.id, equals('target-dive'));
```

If `checkDuplicates` does not flag index 0 (e.g. because the seeded times must be within 15 min — they are identical here, so it will), fall back to constructing the `matchResults` directly on the bundle exactly like the download adapter integration test does (`EntityGroup(items: ..., duplicateIndices: {0}, matchResults: {0: DiveMatchResult(diveId: 'target-dive', score: 0.9, timeDifferenceMs: 0)})`), then call `performImport` with that bundle.

- [ ] **Step 6: Run to verify it fails**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_consolidate_integration_test.dart`
Expected: FAIL — `performImport` currently returns `consolidatedCount: 0` and leaves the imported dive standalone (2 dives in the DB).

- [ ] **Step 7: Implement the fold in `performImport`**

Add imports at the top of `universal_adapter.dart`:

```dart
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart'
    show diveConsolidationServiceProvider;
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart'
    show ImportDuplicateResult;
import 'package:submersion/features/universal_import/presentation/providers/import_consolidation_service.dart'
    show performConsolidations;
```

(If `ImportDuplicateResult` or `DiveMatchResult` is already imported in this file, do not duplicate the import — merge the `show` clause instead.)

Replace the final return of `performImport` (currently lines 461-476, from `final result = await importer.import(...)` through the `return UnifiedImportResult(...)`) with:

```dart
final result = await importer.import(
  data: uddfData,
  selections: uddfSelections,
  repositories: repos,
  diverId: currentDiver.id,
  retainSourceDiveNumbers: retainSourceDiveNumbers,
  onProgress: onProgress,
  cancelToken: cancelToken,
);

// Fold consolidate-flagged dives (imported as standalone above) into their
// matched existing dive. File imports never auto-consolidate; these indices
// come only from an explicit user choice in the review step, and each such
// dive always has a match result (the UI offers Consolidate only on matches).
final diveActions =
    duplicateActions[wizard.ImportEntityType.dives] ?? const {};
final consolidateIndices = <int>{
  for (final entry in diveActions.entries)
    if (entry.value == DuplicateAction.consolidate) entry.key,
};

var consolidated = 0;
var consolidationFailed = 0;
if (consolidateIndices.isNotEmpty) {
  final matchResults =
      bundle.groups[wizard.ImportEntityType.dives]?.matchResults ??
      const <int, DiveMatchResult>{};
  final summary = await performConsolidations(
    indices: consolidateIndices,
    diveIdByIndex: result.diveIdByIndex,
    duplicateResult: ImportDuplicateResult(diveMatches: matchResults),
    consolidationService: _ref.read(diveConsolidationServiceProvider),
    diveRepository: repos.diveRepository,
  );
  consolidated = summary.consolidated;
  consolidationFailed = summary.failed;
}

// `importer.import` counted folded (and failed-then-deleted) dives as
// imported; subtract them so the summary reports only genuinely NEW dives.
final counts = _convertImportCounts(result);
final netDives = result.dives - consolidated - consolidationFailed;
if (netDives > 0) {
  counts[wizard.ImportEntityType.dives] = netDives;
} else {
  counts.remove(wizard.ImportEntityType.dives);
}

// Exclude tombstoned standalone dives from the imported-id list.
final removedDiveIds = <String>{
  for (final index in consolidateIndices)
    if (result.diveIdByIndex[index] != null) result.diveIdByIndex[index]!,
};
final netImportedDiveIds = [
  for (final id in result.diveIds)
    if (!removedDiveIds.contains(id)) id,
];

return UnifiedImportResult(
  importedCounts: counts,
  consolidatedCount: consolidated,
  skippedCount: skipped + consolidationFailed,
  importedDiveIds: netImportedDiveIds,
);
```

- [ ] **Step 8: Run to verify the integration test passes**

Run: `flutter test test/features/import_wizard/data/adapters/universal_adapter_consolidate_integration_test.dart`
Expected: PASS — `consolidatedCount == 1`, one dive in the DB, `importedCounts[dives]` is 0.

- [ ] **Step 9: Run the adapter + checker suites together**

Run: `flutter test test/features/import_wizard/data/adapters/ test/features/universal_import/`
Expected: PASS (no regressions in neighboring adapter/import tests).

- [ ] **Step 10: Commit**

```bash
git add lib/features/import_wizard/data/adapters/universal_adapter.dart test/features/import_wizard/data/adapters/universal_adapter_test.dart test/features/import_wizard/data/adapters/universal_adapter_consolidate_integration_test.dart
git commit -m "feat(import): support manual Consolidate for file imports in UniversalAdapter"
```

---

### Task 4: Whole-project verification and manual smoke

**Files:** none (verification only). Also `git add` the spec + plan docs on the first commit here if not already committed.

- [ ] **Step 1: Format**

Run: `dart format .`
Expected: "0 changed" (or re-stage any files it reformats and amend the relevant commit).

- [ ] **Step 2: Analyze (whole project)**

Run: `flutter analyze`
Expected: "No issues found!".

- [ ] **Step 3: Run the full affected-feature test set**

Run: `flutter test test/features/dive_import/ test/features/universal_import/ test/features/import_wizard/`
Expected: all PASS.

- [ ] **Step 4: Manual smoke (per CLAUDE.md — drive the real flow)**

Run: `flutter run -d macos`
Then: import a Subsurface/UDDF file that contains (a) a dive already in the log from a different source and (b) an unrelated dive months from any existing dive.
Expected: (a) shows a possible-duplicate with a Consolidate option that folds into the existing dive; (b) is NOT flagged as a duplicate. Confirm the summary counts read correctly (imported vs consolidated).

- [ ] **Step 5: Commit docs (if not yet committed)**

```bash
git add docs/superpowers/specs/2026-07-06-dive-matching-time-gate-and-file-import-consolidation-design.md docs/superpowers/plans/2026-07-06-dive-matching-time-gate-and-file-import-consolidation.md
git commit -m "docs: spec and plan for dive matching time-gate and file-import consolidation"
```

---

## Self-Review

**Spec coverage:**
- Part 1 time-gate → Task 1 (matcher) + Task 2 (checker regression). ✓
- Part 2 offer consolidate → Task 3 Step 3. ✓
- Part 2 `matchedExistingSource` defaults exact re-imports to skip → Task 2. ✓
- Part 2 fold via `performConsolidations` → Task 3 Step 7. ✓
- Part 2 manual-only (no auto-consolidate) → unchanged `currentComputerId == null`; noted in Task 3 Interfaces. ✓
- Non-goals (no replaceSource, no matcher unification, no auto-consolidate) → honored; nothing in the plan adds them. ✓
- Graceful same-computer/failed fold → covered by reused `performConsolidations` (already tested) + count-as-skipped in Task 3 Step 7. ✓

**Placeholder scan:** No "TBD"/"handle edge cases"/"similar to". The two test-helper references (`_payloadWithDive`/`_existingDive` in Task 2, harness reuse in Task 3) point at concrete existing patterns in the named files, with full arrange/act/assert given — not deferred work.

**Type consistency:** `performConsolidations` called with `duplicateResult: ImportDuplicateResult(...)` matches its actual signature (verified against `import_consolidation_service.dart` and its test). `result.dives` / `result.diveIds` / `result.diveIdByIndex` match `UddfEntityImportResult`. `_resolveSelections`, `_convertImportCounts`, `_countSkipped` names match the current file. `DuplicateAction.consolidate`, `UnifiedImportResult` field names (`importedCounts`, `consolidatedCount`, `skippedCount`, `importedDiveIds`) match the download adapter's usage.
