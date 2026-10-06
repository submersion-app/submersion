# Import Duplicate Required-Selection Implementation Plan (v2 — import_wizard target)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change the active unified import review step so every suspected duplicate (probable or possible) requires an explicit user decision before the Import button enables. Issue [#200](https://github.com/submersion-app/submersion/issues/200).

**Architecture:** Approach B from the spec — add an orthogonal `pendingDuplicateReview: Map<ImportEntityType, Set<int>>` field to `ImportWizardState`. `setBundle` populates it from `EntityGroup.duplicateIndices` and clears auto-defaulted `duplicateActions` for those indices. Per-row actions (`setDuplicateAction`, `toggleSelection`) and bulk actions drain the set. The Import button reads `!hasPendingReviews` as an additional gate. Adapter-specific `supportedDuplicateActions` controls which bulk buttons render.

**Tech Stack:** Flutter 3.x, Riverpod (StateNotifier), Dart 3, flutter_test, Material 3.

**Spec:** `docs/superpowers/specs/2026-04-12-import-duplicate-required-selection-design.md`

**Working directory:** All commands run from `.worktrees/issue-200-require-duplicate-selection/`. Branch: `feature/issue-200-require-duplicate-selection`.

**Starting context:** The branch has one prior commit on top of main — the Task-7 l10n cherry-pick (`0a849978278`) which adds the `universalImport_*` keys the UI will consume. All other prior work was discarded.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` | Add `pendingDuplicateReview` field + helpers, modify `setBundle`/`setDuplicateAction`/`toggleSelection`, add `applyBulkAction`/`firstPendingLocation`/`debugSetState`, add `PendingLocation` type. |
| `lib/features/import_wizard/presentation/widgets/review_step.dart` | Gate Import button, pending-hint bar above button, banner-copy addendum. |
| `lib/features/import_wizard/presentation/widgets/entity_review_list.dart` | Sort pending to top within duplicate sections, bulk-action row at top when `pendingFor(type).isNotEmpty`, pass `isPending` to cards. Includes private `_EntityDuplicateCard` pending visual state. |
| `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart` | Add `isPending` parameter — warning border + "Decide" expand label + "Needs decision" pill when pending. |
| `lib/features/import_wizard/presentation/widgets/needs_decision_pill.dart` | New shared pill widget. |
| `lib/l10n/arb/app_en.arb` | Add `universalImport_semantics_needsDecision` key. |
| `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart` | Extend with state/notifier tests for pending behavior. |

**Files to create:**

| File | Responsibility |
|---|---|
| `test/features/import_wizard/presentation/widgets/review_step_pending_test.dart` | Widget tests for gate, hint, sort, bulk buttons, visual state. |
| `test/features/import_wizard/presentation/providers/issue_200_regression_test.dart` | Explicit regression guard. |

**Files NOT touched:**

- `lib/features/universal_import/**` — orphan dead code; left alone.
- `lib/features/import_wizard/data/adapters/**` — adapter interfaces unchanged.
- `lib/features/dive_import/domain/services/dive_matcher.dart` — scoring unchanged.

---

## Task 1: Add pendingDuplicateReview field + helpers to ImportWizardState

**Files:**
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`
- Test: `test/features/import_wizard/presentation/providers/import_wizard_state_test.dart` (create if absent; otherwise extend)

- [ ] **Step 1: Check if state tests exist**

Run: `ls test/features/import_wizard/presentation/providers/`

If `import_wizard_state_test.dart` does not exist, create it. Otherwise, append tests to the existing file's last `group(...)`.

- [ ] **Step 2: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';

void main() {
  group('ImportWizardState.pendingDuplicateReview', () {
    test('defaults to empty map', () {
      const state = ImportWizardState();
      expect(state.pendingDuplicateReview, isEmpty);
    });

    test('hasPendingReviews false when all sets empty', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: <int>{},
          ImportEntityType.sites: <int>{},
        },
      );
      expect(state.hasPendingReviews, isFalse);
    });

    test('hasPendingReviews true when any set non-empty', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: <int>{},
          ImportEntityType.sites: {3},
        },
      );
      expect(state.hasPendingReviews, isTrue);
    });

    test('totalPending sums across types', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: {0, 1, 2},
          ImportEntityType.sites: {5},
        },
      );
      expect(state.totalPending, 4);
    });

    test('pendingFor returns empty for missing type', () {
      const state = ImportWizardState();
      expect(state.pendingFor(ImportEntityType.dives), isEmpty);
    });

    test('pendingFor returns set for present type', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: {1, 4},
        },
      );
      expect(state.pendingFor(ImportEntityType.dives), {1, 4});
    });

    test('copyWith updates pendingDuplicateReview', () {
      const state = ImportWizardState();
      final updated = state.copyWith(
        pendingDuplicateReview: {
          ImportEntityType.dives: {0, 1},
        },
      );
      expect(updated.pendingDuplicateReview[ImportEntityType.dives], {0, 1});
    });

    test('copyWith preserves pendingDuplicateReview when not passed', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: {2},
        },
      );
      final updated = state.copyWith(currentStep: 1);
      expect(updated.pendingDuplicateReview[ImportEntityType.dives], {2});
    });
  });
}
```

- [ ] **Step 3: Run to confirm fails**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_state_test.dart`
Expected: FAIL with undefined `pendingDuplicateReview`, `hasPendingReviews`, `totalPending`, `pendingFor`.

- [ ] **Step 4: Add field + constructor param + copyWith + helpers**

In `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`:

In the `ImportWizardState` constructor (line 17-30), after `this.duplicateActions = const {},`, add:

```dart
    this.pendingDuplicateReview = const {},
```

After the `duplicateActions` field declaration (around line 42), add:

```dart
  /// Per-entity-type set of indices whose duplicate status is flagged but
  /// whose resolution has not yet been explicitly chosen by the user.
  ///
  /// An index is present in this set when the row was flagged as a suspected
  /// duplicate and the user has not yet explicitly acted on it. Per-row and
  /// per-tab bulk actions remove indices from the relevant set. The Import
  /// button is gated on this set being empty across all types.
  final Map<ImportEntityType, Set<int>> pendingDuplicateReview;
```

In the `copyWith` method signature (around line 69-86), after `Map<ImportEntityType, Map<int, DuplicateAction>>? duplicateActions,` add:

```dart
    Map<ImportEntityType, Set<int>>? pendingDuplicateReview,
```

In the `copyWith` body (around line 87-104), after the `duplicateActions:` line, add:

```dart
      pendingDuplicateReview:
          pendingDuplicateReview ?? this.pendingDuplicateReview,
```

After the closing `}` of `copyWith` but before the closing `}` of the `ImportWizardState` class, add:

```dart
  /// Pending-review indices for a given entity type. Empty if none.
  Set<int> pendingFor(ImportEntityType type) {
    return pendingDuplicateReview[type] ?? const {};
  }

  /// Whether any entity type has at least one pending-review row.
  bool get hasPendingReviews =>
      pendingDuplicateReview.values.any((set) => set.isNotEmpty);

  /// Total count of pending-review rows across all entity types.
  int get totalPending =>
      pendingDuplicateReview.values.fold(0, (sum, s) => sum + s.length);
```

- [ ] **Step 5: Run tests to verify pass**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_state_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 6: Format + commit**

```bash
dart format lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_state_test.dart
git add lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_state_test.dart
git commit -m "feat: add pendingDuplicateReview to ImportWizardState

Introduces an orthogonal map of per-entity-type index sets to track
suspected duplicates that still need an explicit user decision before
the import can proceed. Adds hasPendingReviews / totalPending /
pendingFor helpers."
```

---

## Task 2: Populate pendingDuplicateReview in setBundle; clear auto-default actions for pending

**Files:**
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` (the `setBundle` method, around lines 151-192)
- Test: `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

**Key semantic change:** today `setBundle` auto-defaults probable-match actions to `skip` and possible-match actions to `importAsNew`. After this task, both are left **absent** from `duplicateActions` and added to `pendingDuplicateReview` instead. The user must explicitly choose before the row gets a recorded action.

- [ ] **Step 1: Read the existing notifier test file to understand helpers**

Run: `head -60 test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

Look for any existing bundle-building helpers (e.g., `buildBundle`, `makeBundle`). Reuse those. If none, inline minimal fixtures.

- [ ] **Step 2: Write failing tests**

Append to `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`:

```dart
group('setBundle populates pendingDuplicateReview', () {
  test('probable dive duplicate goes into pending, NOT duplicateActions',
      () async {
    final bundle = _bundleWithProbableDiveDuplicate(index: 0);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.setBundle(bundle);

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.dives), {0});
    expect(state.duplicateActions[ImportEntityType.dives], anyOf(isNull, isEmpty));
    expect(state.selections[ImportEntityType.dives], isNot(contains(0)));
  });

  test('possible dive duplicate goes into pending, NOT duplicateActions',
      () async {
    final bundle = _bundleWithPossibleDiveDuplicate(index: 0);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.setBundle(bundle);

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.dives), {0});
    expect(state.duplicateActions[ImportEntityType.dives], anyOf(isNull, isEmpty));
    expect(state.selections[ImportEntityType.dives], isNot(contains(0)));
  });

  test('non-dive duplicate (no matchResults) goes into pending', () async {
    final bundle = _bundleWithUnscoredSiteDuplicate(index: 0);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.setBundle(bundle);

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.sites), {0});
    expect(state.selections[ImportEntityType.sites], isNot(contains(0)));
  });

  test('non-duplicate rows are NOT pending and ARE selected', () async {
    final bundle = _bundleWithOneCleanAndOneDuplicateDive();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.setBundle(bundle);

    final state = container.read(importWizardNotifierProvider);
    // Index 0 = clean, index 1 = duplicate
    expect(state.selections[ImportEntityType.dives], contains(0));
    expect(state.pendingFor(ImportEntityType.dives), {1});
  });

  test('empty duplicates produce empty pending', () async {
    final bundle = _bundleWithOneCleanDive();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.setBundle(bundle);

    final state = container.read(importWizardNotifierProvider);
    expect(state.hasPendingReviews, isFalse);
    expect(state.totalPending, 0);
  });
});
```

Bundle builder helpers (inline at top of the test file if no shared helper exists):

```dart
ImportBundle _bundleWithProbableDiveDuplicate({required int index}) {
  final items = [
    EntityItem(
      diveData: DiveData(
        startTime: DateTime(2024, 1, 1, 10, 0),
        maxDepth: 20.0,
        bottomTime: const Duration(minutes: 30),
      ),
      displayName: 'Incoming dive',
      displaySubtitle: null,
      existingData: null,
    ),
  ];
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.file,
      displayName: 'Test',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: items,
        duplicateIndices: {index},
        matchResults: {
          index: const DiveMatchResult(
            diveId: 'existing-1',
            score: 0.9,
            timeDifferenceMs: 0,
            depthDifferenceMeters: 0.0,
            durationDifferenceSeconds: 0,
          ),
        },
      ),
    },
  );
}

ImportBundle _bundleWithPossibleDiveDuplicate({required int index}) {
  final items = [
    EntityItem(
      diveData: DiveData(
        startTime: DateTime(2024, 1, 1, 10, 0),
        maxDepth: 20.0,
        bottomTime: const Duration(minutes: 30),
      ),
      displayName: 'Incoming dive',
      displaySubtitle: null,
      existingData: null,
    ),
  ];
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.file,
      displayName: 'Test',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: items,
        duplicateIndices: {index},
        matchResults: {
          index: const DiveMatchResult(
            diveId: 'existing-1',
            score: 0.55,
            timeDifferenceMs: 600000,
            depthDifferenceMeters: 3.0,
            durationDifferenceSeconds: 480,
          ),
        },
      ),
    },
  );
}

ImportBundle _bundleWithUnscoredSiteDuplicate({required int index}) {
  final items = [
    EntityItem(
      diveData: null,
      displayName: 'Blue Hole',
      displaySubtitle: null,
      existingData: null,
    ),
  ];
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.file,
      displayName: 'Test',
    ),
    groups: {
      ImportEntityType.sites: EntityGroup(
        items: items,
        duplicateIndices: {index},
        matchResults: null,
      ),
    },
  );
}

ImportBundle _bundleWithOneCleanAndOneDuplicateDive() {
  final items = [
    EntityItem(
      diveData: DiveData(
        startTime: DateTime(2024, 6, 15, 10, 0),
        maxDepth: 10.0,
        bottomTime: const Duration(minutes: 20),
      ),
      displayName: 'Clean dive',
      displaySubtitle: null,
      existingData: null,
    ),
    EntityItem(
      diveData: DiveData(
        startTime: DateTime(2024, 1, 1, 10, 0),
        maxDepth: 20.0,
        bottomTime: const Duration(minutes: 30),
      ),
      displayName: 'Dup dive',
      displaySubtitle: null,
      existingData: null,
    ),
  ];
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.file,
      displayName: 'Test',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: items,
        duplicateIndices: {1},
        matchResults: {
          1: const DiveMatchResult(
            diveId: 'existing-2',
            score: 0.9,
            timeDifferenceMs: 0,
            depthDifferenceMeters: 0.0,
            durationDifferenceSeconds: 0,
          ),
        },
      ),
    },
  );
}

ImportBundle _bundleWithOneCleanDive() {
  final items = [
    EntityItem(
      diveData: DiveData(
        startTime: DateTime(2024, 6, 15, 10, 0),
        maxDepth: 10.0,
        bottomTime: const Duration(minutes: 20),
      ),
      displayName: 'Clean dive',
      displaySubtitle: null,
      existingData: null,
    ),
  ];
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.file,
      displayName: 'Test',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: items,
        duplicateIndices: const {},
        matchResults: null,
      ),
    },
  );
}
```

**Note:** The exact class names (`EntityItem`, `DiveData`, `DiveMatchResult`, `ImportSourceInfo`, `ImportSourceType`) must match the project's actual classes. Read `lib/features/import_wizard/domain/models/import_bundle.dart` and `lib/features/dive_import/domain/services/dive_matcher.dart` to confirm signatures before committing to the helper shapes. Adjust as needed.

The test also requires an override of `importWizardNotifierProvider` to inject a test adapter. If no existing test helper does this, the simplest approach is:

```dart
final testProviderContainer = () {
  final container = ProviderContainer(overrides: [
    importWizardNotifierProvider.overrideWith(
      (ref) => ImportWizardNotifier(_TestAdapter()),
    ),
  ]);
  return container;
};

class _TestAdapter implements ImportSourceAdapter {
  @override
  String get defaultTagName => 'Test Import';

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
        DuplicateAction.skip,
        DuplicateAction.importAsNew,
        DuplicateAction.consolidate,
      };

  // Other methods throw UnimplementedError — tests never exercise them.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
```

- [ ] **Step 3: Run to confirm FAIL**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart --name "setBundle populates pendingDuplicateReview"`
Expected: FAIL — probable/possible duplicate cases fail because `setBundle` currently writes to `duplicateActions`.

- [ ] **Step 4: Modify setBundle**

In `import_wizard_providers.dart`, replace the `setBundle` method body (lines 151-192) with:

```dart
  void setBundle(ImportBundle bundle) {
    final selections = <ImportEntityType, Set<int>>{};
    final pendingReview = <ImportEntityType, Set<int>>{};

    for (final entry in bundle.groups.entries) {
      final type = entry.key;
      final group = entry.value;

      final allIndices = Set<int>.from(
        List.generate(group.items.length, (i) => i),
      );
      selections[type] = allIndices.difference(group.duplicateIndices);

      if (group.duplicateIndices.isNotEmpty) {
        pendingReview[type] = Set<int>.from(group.duplicateIndices);
      }
    }

    state = state.copyWith(
      bundle: bundle,
      selections: selections,
      // Auto-default duplicateActions removed — pending indices are decided
      // explicitly by the user via setDuplicateAction or applyBulkAction.
      duplicateActions: const {},
      pendingDuplicateReview: pendingReview,
      currentStep: 1,
      clearError: true,
    );
  }
```

- [ ] **Step 5: Run to verify PASS**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart --name "setBundle populates pendingDuplicateReview"`
Expected: PASS.

- [ ] **Step 6: Run full notifier file and check for regressions**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`
Expected: All green. If any previously-passing test assumed auto-defaults in `duplicateActions`, it will now fail — update those tests to assert against `pendingDuplicateReview` instead. Do not restore the old behavior.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart
git add lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart
git commit -m "feat: populate pendingDuplicateReview in setBundle; drop auto-default actions

setBundle now records every suspected-duplicate index into the
pendingDuplicateReview set and leaves duplicateActions empty for
those rows. The user must explicitly choose an action before the
row gets a recorded resolution. Both probable and possible matches
are treated as 'needs decision' — no silent defaults."
```

---

## Task 3: Drain pending on per-row actions; add debugSetState

**Files:**
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` (`setDuplicateAction` and `toggleSelection` methods, around lines 199-300)
- Test: `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
group('setDuplicateAction drains pending', () {
  test('setDuplicateAction with skip drains pending and syncs selections',
      () async {
    final container = _containerWithOnePendingDive();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.setDuplicateAction(
      ImportEntityType.dives, 0, DuplicateAction.skip,
    );

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.dives), isEmpty);
    expect(state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.skip);
    expect(state.selections[ImportEntityType.dives], isNot(contains(0)));
  });

  test('setDuplicateAction with importAsNew drains pending and selects',
      () async {
    final container = _containerWithOnePendingDive();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.setDuplicateAction(
      ImportEntityType.dives, 0, DuplicateAction.importAsNew,
    );

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.dives), isEmpty);
    expect(state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.importAsNew);
    expect(state.selections[ImportEntityType.dives], contains(0));
  });

  test('setDuplicateAction with consolidate drains pending and selects',
      () async {
    final container = _containerWithOnePendingDive();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.setDuplicateAction(
      ImportEntityType.dives, 0, DuplicateAction.consolidate,
    );

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.dives), isEmpty);
    expect(state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.consolidate);
    expect(state.selections[ImportEntityType.dives], contains(0));
  });
});

group('toggleSelection drains pending', () {
  test('toggleSelection on a pending index drains it', () async {
    final container = _containerWithOnePendingDive();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.toggleSelection(ImportEntityType.dives, 0);

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.dives), isEmpty);
    expect(state.selections[ImportEntityType.dives], contains(0));
  });

  test('toggleSelection on a non-pending index does not change pending',
      () async {
    final container = _containerWithOneCleanAndOnePendingDive();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    // index 0 = clean (selected), index 1 = pending
    notifier.toggleSelection(ImportEntityType.dives, 0);

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.dives), {1});
    expect(state.selections[ImportEntityType.dives], isNot(contains(0)));
  });
});
```

Helpers:

```dart
ProviderContainer _containerWithOnePendingDive() {
  final container = ProviderContainer(overrides: [
    importWizardNotifierProvider.overrideWith(
      (ref) => ImportWizardNotifier(_TestAdapter()),
    ),
  ]);
  container.read(importWizardNotifierProvider.notifier).setBundle(
    _bundleWithProbableDiveDuplicate(index: 0),
  );
  return container;
}

ProviderContainer _containerWithOneCleanAndOnePendingDive() {
  final container = ProviderContainer(overrides: [
    importWizardNotifierProvider.overrideWith(
      (ref) => ImportWizardNotifier(_TestAdapter()),
    ),
  ]);
  container.read(importWizardNotifierProvider.notifier).setBundle(
    _bundleWithOneCleanAndOneDuplicateDive(),
  );
  return container;
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart --name "drains pending"`
Expected: FAIL — the setDuplicateAction and toggleSelection methods do not touch `pendingDuplicateReview` yet.

- [ ] **Step 3: Add `_drainPending` helper and modify `setDuplicateAction` and `toggleSelection`**

In `import_wizard_providers.dart`, add below the `setDuplicateAction` method:

```dart
  /// Returns a new pending-review map with the given indices removed from
  /// the set for [type]. If the resulting set is empty, the type key is
  /// removed from the map entirely (keeps `hasPendingReviews` fast).
  Map<ImportEntityType, Set<int>> _drainPending(
    ImportEntityType type,
    Set<int> indices,
  ) {
    final current = state.pendingFor(type);
    if (current.isEmpty) return state.pendingDuplicateReview;
    final updated = current.difference(indices);
    final newMap = Map<ImportEntityType, Set<int>>.from(
      state.pendingDuplicateReview,
    );
    if (updated.isEmpty) {
      newMap.remove(type);
    } else {
      newMap[type] = updated;
    }
    return newMap;
  }
```

Replace the `setDuplicateAction` method body with:

```dart
  void setDuplicateAction(
    ImportEntityType type,
    int index,
    DuplicateAction action,
  ) {
    final actionsForType =
        state.duplicateActions[type] ?? const <int, DuplicateAction>{};
    final updatedActions = Map<int, DuplicateAction>.from(actionsForType)
      ..[index] = action;

    final currentSelection = Set<int>.from(
      state.selections[type] ?? const <int>{},
    );
    if (action == DuplicateAction.skip) {
      currentSelection.remove(index);
    } else {
      currentSelection.add(index);
    }

    final updatedPending = _drainPending(type, {index});

    state = state.copyWith(
      duplicateActions: {...state.duplicateActions, type: updatedActions},
      selections: {...state.selections, type: currentSelection},
      pendingDuplicateReview: updatedPending,
    );
  }
```

Replace the `toggleSelection` method body with:

```dart
  void toggleSelection(ImportEntityType type, int index) {
    final current = state.selections[type] ?? const <int>{};
    final updated = Set<int>.from(current);
    if (updated.contains(index)) {
      updated.remove(index);
    } else {
      updated.add(index);
    }

    final updatedPending = _drainPending(type, {index});

    state = state.copyWith(
      selections: {...state.selections, type: updated},
      pendingDuplicateReview: updatedPending,
    );
  }
```

- [ ] **Step 4: Add `debugSetState`**

Near the end of the `ImportWizardNotifier` class (before the closing `}`), add:

```dart
  @visibleForTesting
  void debugSetState(ImportWizardState newState) {
    state = newState;
  }
```

Add `package:flutter/foundation.dart` import at the top of the file if not already present:

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 5: Run to verify PASS**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`
Expected: All tests pass including the 5 new tests.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart
git add lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart
git commit -m "feat: drain pendingDuplicateReview on per-row user actions

setDuplicateAction and toggleSelection both now remove the acted-upon
index from the pending set. _drainPending helper keeps the invariant
that empty type sets are removed from the map. Adds debugSetState
(visibleForTesting) for widget tests that seed state directly."
```

---

## Task 4: applyBulkAction

**Files:**
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`
- Test: `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

Applies an action to every pending-review index for a type in a single state emission. For `consolidate`, filters to probable-match indices only.

- [ ] **Step 1: Write failing tests**

```dart
group('applyBulkAction', () {
  test('skip drains all pending for type and sets resolutions', () async {
    final container = _containerWithTwoPendingDives();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.applyBulkAction(ImportEntityType.dives, DuplicateAction.skip);

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.dives), isEmpty);
    expect(state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.skip);
    expect(state.duplicateActions[ImportEntityType.dives]?[1],
        DuplicateAction.skip);
    expect(state.selections[ImportEntityType.dives],
        isNot(containsAny(<int>{0, 1})));
  });

  test('importAsNew drains all pending and selects them', () async {
    final container = _containerWithTwoPendingDives();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.applyBulkAction(
        ImportEntityType.dives, DuplicateAction.importAsNew);

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.dives), isEmpty);
    expect(state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.importAsNew);
    expect(state.selections[ImportEntityType.dives], containsAll({0, 1}));
  });

  test('consolidate drains only probable matches, leaves weak pending',
      () async {
    final container = _containerWithMixedConfidenceDives();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.applyBulkAction(
        ImportEntityType.dives, DuplicateAction.consolidate);

    final state = container.read(importWizardNotifierProvider);
    // Index 0 probable → consolidated; index 1 weak → stays pending
    expect(state.pendingFor(ImportEntityType.dives), {1});
    expect(state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.consolidate);
    expect(state.duplicateActions[ImportEntityType.dives]?.containsKey(1),
        isFalse);
  });

  test('no-op when pending for type is empty', () async {
    final container = _containerWithTwoPendingDives();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.applyBulkAction(ImportEntityType.dives, DuplicateAction.skip);
    // Second call: pending is empty
    notifier.applyBulkAction(
        ImportEntityType.dives, DuplicateAction.importAsNew);

    final state = container.read(importWizardNotifierProvider);
    // First call won, resolutions are skip
    expect(state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.skip);
  });

  test('non-dive bulk action drains pending and updates selection', () async {
    final container = _containerWithOnePendingSite();
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.applyBulkAction(
        ImportEntityType.sites, DuplicateAction.importAsNew);

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingFor(ImportEntityType.sites), isEmpty);
    expect(state.selections[ImportEntityType.sites], contains(0));
  });
});
```

Helpers (add alongside the existing bundle-builder helpers):

```dart
ProviderContainer _containerWithTwoPendingDives() {
  final bundle = ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.file,
      displayName: 'Test',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [
          EntityItem(
            diveData: DiveData(
              startTime: DateTime(2024, 1, 1, 10, 0),
              maxDepth: 20.0,
              bottomTime: const Duration(minutes: 30),
            ),
            displayName: 'Dup 1',
            displaySubtitle: null,
            existingData: null,
          ),
          EntityItem(
            diveData: DiveData(
              startTime: DateTime(2024, 1, 2, 10, 0),
              maxDepth: 25.0,
              bottomTime: const Duration(minutes: 35),
            ),
            displayName: 'Dup 2',
            displaySubtitle: null,
            existingData: null,
          ),
        ],
        duplicateIndices: const {0, 1},
        matchResults: {
          0: const DiveMatchResult(
            diveId: 'e1',
            score: 0.9,
            timeDifferenceMs: 0,
            depthDifferenceMeters: 0.0,
            durationDifferenceSeconds: 0,
          ),
          1: const DiveMatchResult(
            diveId: 'e2',
            score: 0.9,
            timeDifferenceMs: 0,
            depthDifferenceMeters: 0.0,
            durationDifferenceSeconds: 0,
          ),
        },
      ),
    },
  );
  final container = ProviderContainer(overrides: [
    importWizardNotifierProvider.overrideWith(
      (ref) => ImportWizardNotifier(_TestAdapter()),
    ),
  ]);
  container.read(importWizardNotifierProvider.notifier).setBundle(bundle);
  return container;
}

ProviderContainer _containerWithMixedConfidenceDives() {
  final bundle = ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.file,
      displayName: 'Test',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [
          EntityItem(
            diveData: DiveData(
              startTime: DateTime(2024, 1, 1, 10, 0),
              maxDepth: 20.0,
              bottomTime: const Duration(minutes: 30),
            ),
            displayName: 'Probable',
            displaySubtitle: null,
            existingData: null,
          ),
          EntityItem(
            diveData: DiveData(
              startTime: DateTime(2024, 1, 2, 10, 0),
              maxDepth: 20.0,
              bottomTime: const Duration(minutes: 30),
            ),
            displayName: 'Possible',
            displaySubtitle: null,
            existingData: null,
          ),
        ],
        duplicateIndices: const {0, 1},
        matchResults: {
          0: const DiveMatchResult(
            diveId: 'e1',
            score: 0.9,
            timeDifferenceMs: 0,
            depthDifferenceMeters: 0.0,
            durationDifferenceSeconds: 0,
          ),
          1: const DiveMatchResult(
            diveId: 'e2',
            score: 0.55,
            timeDifferenceMs: 600000,
            depthDifferenceMeters: 3.0,
            durationDifferenceSeconds: 480,
          ),
        },
      ),
    },
  );
  final container = ProviderContainer(overrides: [
    importWizardNotifierProvider.overrideWith(
      (ref) => ImportWizardNotifier(_TestAdapter()),
    ),
  ]);
  container.read(importWizardNotifierProvider.notifier).setBundle(bundle);
  return container;
}

ProviderContainer _containerWithOnePendingSite() {
  final container = ProviderContainer(overrides: [
    importWizardNotifierProvider.overrideWith(
      (ref) => ImportWizardNotifier(_TestAdapter()),
    ),
  ]);
  container.read(importWizardNotifierProvider.notifier).setBundle(
    _bundleWithUnscoredSiteDuplicate(index: 0),
  );
  return container;
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart --name "applyBulkAction"`
Expected: FAIL — method undefined.

- [ ] **Step 3: Implement `applyBulkAction`**

In `import_wizard_providers.dart`, directly below `setDuplicateAction` (and after the `_drainPending` helper from Task 3), add:

```dart
  /// Apply [action] to every pending-review index for [type] in a single
  /// state update.
  ///
  /// For [DuplicateAction.consolidate], only indices whose
  /// `DiveMatchResult.score >= 0.7` are consolidated; weaker matches remain
  /// pending. For other actions, every pending index is affected.
  ///
  /// No-op if the type has no pending indices or (for consolidate) no
  /// probable matches.
  void applyBulkAction(ImportEntityType type, DuplicateAction action) {
    final pending = state.pendingFor(type);
    if (pending.isEmpty) return;

    final Set<int> affected;
    if (action == DuplicateAction.consolidate) {
      final matchResults = state.bundle?.groups[type]?.matchResults;
      if (matchResults == null) return;
      affected = pending.where((i) {
        final match = matchResults[i];
        return match != null && match.score >= 0.7;
      }).toSet();
    } else {
      affected = pending;
    }

    if (affected.isEmpty) return;

    final actionsForType =
        state.duplicateActions[type] ?? const <int, DuplicateAction>{};
    final updatedActions = Map<int, DuplicateAction>.from(actionsForType);
    final currentSelection = Set<int>.from(
      state.selections[type] ?? const <int>{},
    );
    for (final i in affected) {
      updatedActions[i] = action;
      if (action == DuplicateAction.skip) {
        currentSelection.remove(i);
      } else {
        currentSelection.add(i);
      }
    }

    final updatedPending = _drainPending(type, affected);

    state = state.copyWith(
      duplicateActions: {...state.duplicateActions, type: updatedActions},
      selections: {...state.selections, type: currentSelection},
      pendingDuplicateReview: updatedPending,
    );
  }
```

- [ ] **Step 4: Run to verify PASS**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart --name "applyBulkAction"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart
git add lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart
git commit -m "feat: add applyBulkAction for tab-level bulk resolution

Unified bulk action across dive and non-dive entity types. For
consolidate, only drains probable matches (score >= 0.7); weaker
matches remain pending. Single state emission."
```

---

## Task 5: firstPendingLocation + PendingLocation type

**Files:**
- Modify: `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`
- Test: `test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
group('firstPendingLocation', () {
  test('returns null when nothing pending', () {
    final container = ProviderContainer(overrides: [
      importWizardNotifierProvider.overrideWith(
        (ref) => ImportWizardNotifier(_TestAdapter()),
      ),
    ]);
    addTearDown(container.dispose);

    final loc = container
        .read(importWizardNotifierProvider.notifier)
        .firstPendingLocation();
    expect(loc, isNull);
  });

  test('returns first pending dive when dives have pending', () {
    final container = _containerWithTwoPendingDives();

    final loc = container
        .read(importWizardNotifierProvider.notifier)
        .firstPendingLocation();

    expect(loc, isNotNull);
    expect(loc!.type, ImportEntityType.dives);
    expect(loc.index, 0);
  });
});
```

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart --name "firstPendingLocation"`
Expected: FAIL — method and type undefined.

- [ ] **Step 3: Add `PendingLocation` class and `firstPendingLocation` method**

At the top of `import_wizard_providers.dart`, before the `ImportWizardState` class, add:

```dart
/// A (type, index) pair identifying a pending-review row.
class PendingLocation {
  const PendingLocation({required this.type, required this.index});
  final ImportEntityType type;
  final int index;
}
```

In the notifier class, below `applyBulkAction`, add:

```dart
  /// Location of the first pending-review row across all entity tabs in
  /// enum order. Returns null if no pending rows exist.
  ///
  /// Used by the review step UI to jump the user to the first row that
  /// still needs a decision when the Import button is gated.
  PendingLocation? firstPendingLocation() {
    for (final type in ImportEntityType.values) {
      final pending = state.pendingFor(type);
      if (pending.isEmpty) continue;
      final sorted = pending.toList()..sort();
      return PendingLocation(type: type, index: sorted.first);
    }
    return null;
  }
```

- [ ] **Step 4: Run to verify PASS**

Run: `flutter test test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart --name "firstPendingLocation"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart
git add lib/features/import_wizard/presentation/providers/import_wizard_providers.dart test/features/import_wizard/presentation/providers/import_wizard_notifier_test.dart
git commit -m "feat: add firstPendingLocation for review-jump target

Returns the first pending (type, index) pair in enum order. The
review step UI uses this to animate the DefaultTabController to
the matching tab when the user taps the Review button above the
gated Import button."
```

---

## Task 6: Add semantics l10n key + NeedsDecisionPill widget

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`
- Create: `lib/features/import_wizard/presentation/widgets/needs_decision_pill.dart`

- [ ] **Step 1: Add ARB key**

In `lib/l10n/arb/app_en.arb`, insert alphabetically among `universalImport_semantics_*` keys:

```json
  "universalImport_semantics_needsDecision": "Suspected duplicate, needs decision",
  "@universalImport_semantics_needsDecision": {
    "description": "Screen reader label for the 'Needs decision' pill on a pending duplicate row"
  },
```

- [ ] **Step 2: Regenerate locales**

Run: `flutter gen-l10n`
Expected: completes without errors. Untranslated-message warnings are expected for non-English locales.

- [ ] **Step 3: Create NeedsDecisionPill widget**

Create `lib/features/import_wizard/presentation/widgets/needs_decision_pill.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Pill indicating a row is a suspected duplicate that still needs an
/// explicit user decision before the import can proceed.
///
/// Used by the review step's duplicate card widgets when their `isPending`
/// flag is true.
class NeedsDecisionPill extends StatelessWidget {
  const NeedsDecisionPill({super.key, required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.universalImport_semantics_needsDecision,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.tertiary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.tertiary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.universalImport_pending_needsDecision,
              style: TextStyle(
                color: colorScheme.tertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write a minimal widget test**

Create `test/features/import_wizard/presentation/widgets/needs_decision_pill_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/needs_decision_pill.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _pump(ColorScheme colorScheme) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: NeedsDecisionPill(colorScheme: colorScheme),
    ),
  );
}

void main() {
  testWidgets('renders localized text and warning icon', (tester) async {
    await tester.pumpWidget(_pump(const ColorScheme.light()));
    expect(find.text('Needs decision'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run test, confirm PASS**

Run: `flutter test test/features/import_wizard/presentation/widgets/needs_decision_pill_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/import_wizard/presentation/widgets/needs_decision_pill.dart test/features/import_wizard/presentation/widgets/needs_decision_pill_test.dart
git add lib/features/import_wizard/presentation/widgets/needs_decision_pill.dart test/features/import_wizard/presentation/widgets/needs_decision_pill_test.dart lib/l10n/arb/app_en.arb lib/l10n/
git commit -m "feat: add NeedsDecisionPill shared widget and l10n key

Localized pill used by pending duplicate rows in the review step.
Icon+color+text combo is colorblind-safe. Semantics label announced
to screen readers."
```

---

## Task 7: DuplicateActionCard pending visual state

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart`
- Test: `test/features/import_wizard/presentation/widgets/duplicate_action_card_pending_test.dart` (create)

Add an `isPending` parameter. When true:
- Card shape gets a 4-px warning-colored border.
- Expand-collapse label says "Decide" instead of whatever today's label is (likely "Compare dives").
- A `NeedsDecisionPill` renders in the header region.

- [ ] **Step 1: Read the current card to understand its structure**

Run: `cat lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart | head -120`

Note the existing parameter list, where the match-score badge renders, and the expand button's label source.

- [ ] **Step 2: Write failing widget tests**

Create `test/features/import_wizard/presentation/widgets/duplicate_action_card_pending_test.dart`. Mirror the structure of the existing test file for this widget if one exists. If none exists, base the fixture on the card's constructor.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/duplicate_action_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final item = EntityItem(
    diveData: DiveData(
      startTime: DateTime(2024, 1, 1, 10, 0),
      maxDepth: 20.0,
      bottomTime: const Duration(minutes: 30),
    ),
    displayName: 'Test dive',
    displaySubtitle: null,
    existingData: null,
  );
  const matchResult = DiveMatchResult(
    diveId: 'existing-1',
    score: 0.85,
    timeDifferenceMs: 60000,
    depthDifferenceMeters: 0.1,
    durationDifferenceSeconds: 0,
  );

  Widget pump({required bool isPending}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DuplicateActionCard(
          item: item,
          matchResult: matchResult,
          currentAction: null,
          availableActions: const {
            DuplicateAction.skip,
            DuplicateAction.importAsNew,
            DuplicateAction.consolidate,
          },
          onActionChanged: (_) {},
          existingDiveId: 'existing-1',
          isPending: isPending,
        ),
      ),
    );
  }

  group('DuplicateActionCard pending state', () {
    testWidgets('shows NeedsDecisionPill when pending', (tester) async {
      await tester.pumpWidget(pump(isPending: true));
      expect(find.text('Needs decision'), findsOneWidget);
    });

    testWidgets('does not show pill when not pending', (tester) async {
      await tester.pumpWidget(pump(isPending: false));
      expect(find.text('Needs decision'), findsNothing);
    });

    testWidgets('renders 4-px warning border when pending', (tester) async {
      await tester.pumpWidget(pump(isPending: true));
      final card = tester.widget<Card>(find.byType(Card).first);
      final shape = card.shape as RoundedRectangleBorder?;
      expect(shape, isNotNull);
      expect(shape!.side.width, 4);
    });
  });
}
```

- [ ] **Step 3: Run — expect FAIL**

Run: `flutter test test/features/import_wizard/presentation/widgets/duplicate_action_card_pending_test.dart`
Expected: FAIL — `isPending` parameter undefined.

- [ ] **Step 4: Add `isPending` to DuplicateActionCard**

In `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart`:

- Add `isPending` to the constructor with default `false`.
- Add the corresponding final field.
- In `build()`, wrap the card with a `RoundedRectangleBorder` shape conditioned on `isPending`.
- In the header region (where the match-score badge currently renders), conditionally render `NeedsDecisionPill` when `isPending`.

Add import at the top:

```dart
import 'package:submersion/features/import_wizard/presentation/widgets/needs_decision_pill.dart';
```

Locate the `Card` widget's instantiation (likely wrapped in `return Card(...)` or a similar scope). Add or modify the `shape:` parameter:

```dart
shape: RoundedRectangleBorder(
  side: isPending
      ? BorderSide(color: Theme.of(context).colorScheme.tertiary, width: 4)
      : BorderSide.none,
  borderRadius: BorderRadius.circular(12),
),
```

In the header `Row`, add a pending-pill rendering next to the existing match-score badge:

```dart
if (isPending) ...[
  const SizedBox(width: 8),
  NeedsDecisionPill(colorScheme: Theme.of(context).colorScheme),
],
```

For the expand button label — find where "Compare dives" (or whatever the existing label is) is rendered. Change the conditional to show `context.l10n.universalImport_dive_decideAction` when `isPending && !isExpanded`.

- [ ] **Step 5: Run to verify PASS**

Run: `flutter test test/features/import_wizard/presentation/widgets/duplicate_action_card_pending_test.dart`
Expected: PASS.

- [ ] **Step 6: Run full widget test suite for import_wizard to catch regressions**

Run: `flutter test test/features/import_wizard/presentation/widgets/`
Expected: all tests pass. Existing callers pass `isPending: false` by default, so existing tests are unaffected.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart test/features/import_wizard/presentation/widgets/duplicate_action_card_pending_test.dart
git add lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart test/features/import_wizard/presentation/widgets/duplicate_action_card_pending_test.dart
git commit -m "feat: add pending visual state to DuplicateActionCard

isPending parameter (default false) adds a warning-colored card
border, a NeedsDecisionPill in the header, and swaps the expand
label to 'Decide' while collapsed."
```

---

## Task 8: EntityReviewList — sort pending to top + bulk action row + pass isPending

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/entity_review_list.dart`
- Test: `test/features/import_wizard/presentation/widgets/entity_review_list_pending_test.dart` (create)

Changes:

1. `EntityReviewList` gains new required props: `pendingIndices: Set<int>`, `availableActions: Set<DuplicateAction>`, `onBulkAction: void Function(DuplicateAction)`.
2. Sort pending indices to the TOP of each duplicate section (both "Potential Duplicates" and "Possible Duplicates").
3. Insert a `_BulkActionRow` widget between the header row and the item lists, shown only when `pendingIndices.isNotEmpty`.
4. Pass `isPending: pendingIndices.contains(index)` to each `DuplicateActionCard` instantiation (line 142, 151, 161).
5. For non-dive `_EntityDuplicateCard` (lines 393-512), add an analogous `isPending` parameter and visual state — use the same pattern as Task 7: warning border + NeedsDecisionPill + "Decide" label when pending.

- [ ] **Step 1: Read the current EntityReviewList in full** (already partly read). Focus on lines 393-512 (`_EntityDuplicateCard`).

- [ ] **Step 2: Write failing widget tests**

Create `test/features/import_wizard/presentation/widgets/entity_review_list_pending_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('EntityReviewList pending UI', () {
    testWidgets('shows bulk action row only when pending is non-empty',
        (tester) async {
      // No pending → no bulk row
      await tester.pumpWidget(_pump(
        group: _sampleGroup(),
        pendingIndices: const <int>{},
      ));
      expect(find.textContaining('Skip all'), findsNothing);

      // With pending → bulk row visible
      await tester.pumpWidget(_pump(
        group: _sampleGroup(),
        pendingIndices: const {0},
      ));
      await tester.pump();
      expect(find.textContaining('Skip all'), findsOneWidget);
    });

    testWidgets(
      'bulk row shows only buttons for supported actions',
      (tester) async {
        await tester.pumpWidget(_pump(
          group: _sampleGroup(),
          pendingIndices: const {0},
          availableActions: const {DuplicateAction.skip, DuplicateAction.importAsNew},
        ));
        await tester.pump();
        expect(find.textContaining('Skip all'), findsOneWidget);
        expect(find.textContaining('Import all'), findsOneWidget);
        expect(find.textContaining('Consolidate'), findsNothing);
      },
    );

    testWidgets('Consolidate matched button disabled when count is zero',
        (tester) async {
      // Group has pending but matchResult with score < 0.7 → consolidate count 0
      await tester.pumpWidget(_pump(
        group: _sampleGroupPossibleOnly(),
        pendingIndices: const {0},
      ));
      await tester.pump();
      final consolidate = find.ancestor(
        of: find.textContaining('Consolidate'),
        matching: find.byType(OutlinedButton),
      );
      expect(consolidate, findsOneWidget);
      final button = tester.widget<OutlinedButton>(consolidate);
      expect(button.onPressed, isNull);
    });
  });
}
```

Plus helpers `_pump`, `_sampleGroup`, `_sampleGroupPossibleOnly` — build `EntityGroup` fixtures like Task 2's `_bundleWithProbableDiveDuplicate` but return the group directly.

- [ ] **Step 3: Modify `EntityReviewList`**

Add to constructor:
```dart
final Set<int> pendingIndices;
final Set<DuplicateAction> availableActionsForBulk;
final void Function(DuplicateAction) onBulkAction;
```

(Note: `availableActions` already exists — reuse it. Rename or alias if needed.)

In `build`, after the header row padding (line 121), add:

```dart
if (pendingIndices.isNotEmpty)
  _BulkActionRow(
    type: group.items.isNotEmpty && group.items.first.diveData != null
        ? 'dive'
        : 'entity',
    pendingCount: pendingIndices.length,
    matchableConsolidateCount: _matchableConsolidateCount(),
    availableActions: availableActions,
    onBulkAction: onBulkAction,
  ),
```

Modify `_sortedDuplicateIndices` (or create a new helper) to return pending-first, then the rest in match-score order:

```dart
List<int> _sortedDuplicateIndices({required double minScore, double? maxScore}) {
  final all = <int>[];
  final matchResults = group.matchResults;
  if (matchResults == null) return all;

  for (final entry in matchResults.entries) {
    final score = entry.value.score;
    if (score < minScore) continue;
    if (maxScore != null && score >= maxScore) continue;
    all.add(entry.key);
  }

  final pendingFirst = all.where(pendingIndices.contains).toList();
  final rest = all.where((i) => !pendingIndices.contains(i)).toList();
  rest.sort((a, b) =>
      matchResults[b]!.score.compareTo(matchResults[a]!.score));
  return [...pendingFirst, ...rest];
}
```

For the `_buildDuplicateCard` and `_buildEntityDuplicateCard` internals, pass `isPending: pendingIndices.contains(index)` through to the card widget.

Add `_BulkActionRow` as a private class at the bottom of the file (or as a new separate file if the existing file is getting large). It renders `OutlinedButton.icon`s filtered by `availableActions`:

```dart
class _BulkActionRow extends StatelessWidget {
  final String type;  // 'dive' or 'entity'
  final int pendingCount;
  final int matchableConsolidateCount;
  final Set<DuplicateAction> availableActions;
  final void Function(DuplicateAction) onBulkAction;

  const _BulkActionRow({
    required this.type,
    required this.pendingCount,
    required this.matchableConsolidateCount,
    required this.availableActions,
    required this.onBulkAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (availableActions.contains(DuplicateAction.skip))
            OutlinedButton.icon(
              onPressed: () => onBulkAction(DuplicateAction.skip),
              icon: const Icon(Icons.block, size: 16),
              label: Text(
                context.l10n.universalImport_bulk_skipAll(pendingCount),
              ),
            ),
          if (availableActions.contains(DuplicateAction.importAsNew))
            OutlinedButton.icon(
              onPressed: () => onBulkAction(DuplicateAction.importAsNew),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: Text(
                type == 'dive'
                    ? context.l10n.universalImport_bulk_importAllAsNew(pendingCount)
                    : context.l10n.universalImport_bulk_importAll(pendingCount),
              ),
            ),
          if (availableActions.contains(DuplicateAction.consolidate))
            OutlinedButton.icon(
              onPressed: matchableConsolidateCount > 0
                  ? () => onBulkAction(DuplicateAction.consolidate)
                  : null,
              icon: const Icon(Icons.merge_type, size: 16),
              label: Text(
                context.l10n.universalImport_bulk_consolidateMatched(
                  matchableConsolidateCount,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

Add `_matchableConsolidateCount()` helper on `EntityReviewList`:

```dart
int _matchableConsolidateCount() {
  final matchResults = group.matchResults;
  if (matchResults == null) return 0;
  return pendingIndices
      .where((i) => (matchResults[i]?.score ?? 0) >= 0.7)
      .length;
}
```

Add `l10n_extension` import if not already present:

```dart
import 'package:submersion/l10n/l10n_extension.dart';
```

For `_EntityDuplicateCard` (lines 393-512), add `isPending` parameter in the same way as `DuplicateActionCard` — warning border, NeedsDecisionPill, "Decide" label.

- [ ] **Step 4: Update caller in `review_step.dart`**

In `review_step.dart:269-284` (`_EntityTab.build`), pass the new props:

```dart
return SingleChildScrollView(
  child: EntityReviewList(
    group: group,
    selectedIndices: selectedIndices,
    duplicateActions: duplicateActions,
    availableActions: availableActions,
    pendingIndices: state.pendingFor(type),
    onToggleSelection: (i) => notifier.toggleSelection(type, i),
    onDuplicateActionChanged: (i, a) =>
        notifier.setDuplicateAction(type, i, a),
    onBulkAction: (action) => notifier.applyBulkAction(type, action),
    onSelectAll: () => notifier.selectAll(type),
    onDeselectAll: () => notifier.deselectAll(type),
    existingDiveIdForIndex: (i) => group.matchResults?[i]?.diveId ?? '',
    projectedDiveNumbers: projectedDiveNumbers,
  ),
);
```

- [ ] **Step 5: Run widget tests — expect PASS**

Run: `flutter test test/features/import_wizard/presentation/widgets/`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/import_wizard/presentation/widgets/entity_review_list.dart lib/features/import_wizard/presentation/widgets/review_step.dart test/features/import_wizard/presentation/widgets/entity_review_list_pending_test.dart
git add lib/features/import_wizard/presentation/widgets/entity_review_list.dart lib/features/import_wizard/presentation/widgets/review_step.dart test/features/import_wizard/presentation/widgets/entity_review_list_pending_test.dart
git commit -m "feat: EntityReviewList pending-first sort + bulk-action row

Pending duplicates now sort to the top of each duplicate section.
A bulk-action row renders above the list when pending is non-empty,
showing only buttons for actions the adapter supports. _EntityDuplicateCard
also gains pending visual state for non-dive duplicates."
```

---

## Task 9: Gate Import button + pending hint bar in ReviewStep

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/review_step.dart`
- Test: `test/features/import_wizard/presentation/widgets/review_step_pending_test.dart` (create)

- [ ] **Step 1: Write failing widget tests**

Create `test/features/import_wizard/presentation/widgets/review_step_pending_test.dart` using `notifier.debugSetState` (Task 3) to seed pending state. Verify:

1. `Import Selected` button is disabled when any tab has pending duplicates.
2. Pending hint text "N duplicate(s) need a decision" is visible above the button.
3. Tapping `Review` calls `firstPendingLocation` and animates the tab.
4. When all pending is drained (via `setDuplicateAction` or `applyBulkAction`), the button re-enables.
5. Banner copy appends "Each needs a decision before importing." when pending.

(Full test code follows the shape of Task 10 in the original plan — adapt imports for the import_wizard module.)

- [ ] **Step 2: Run — expect FAIL**

Run: `flutter test test/features/import_wizard/presentation/widgets/review_step_pending_test.dart`

- [ ] **Step 3: Modify `_BottomBar` to gate and show hint**

In `review_step.dart:314-362`, extend `_BottomBar` to accept `hasPendingReviews` and `totalPending`, plus the containing widget provides a `Review` callback that calls `firstPendingLocation`.

Change the `_BottomBar` constructor to:

```dart
const _BottomBar({
  required this.counts,
  required this.onImport,
  this.onBack,
  required this.hasPendingReviews,
  required this.totalPending,
  required this.onReviewPending,
});
```

Replace the build body with:

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final parts = <String>[];
  if (counts.importing > 0) parts.add('${counts.importing} new');
  if (counts.consolidating > 0) parts.add('${counts.consolidating} merging');
  if (counts.skipping > 0) parts.add('${counts.skipping} skipped');
  final countsText = parts.isEmpty ? 'Nothing selected' : parts.join(', ');

  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPendingReviews) ...[
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: theme.colorScheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.universalImport_pending_gateHint(totalPending),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onReviewPending,
                    child: Text(context.l10n.universalImport_pending_reviewAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (onBack != null)
                TextButton(onPressed: onBack, child: const Text('Back')),
              Expanded(
                child: Text(
                  countsText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              FilledButton(
                onPressed: hasPendingReviews ? null : onImport,
                child: const Text('Import Selected'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

Add `l10n_extension` import if not already present:

```dart
import 'package:submersion/l10n/l10n_extension.dart';
```

- [ ] **Step 4: Wire the new props through `_MultiTypeLayout`**

In `_MultiTypeLayout.build`, replace the `_BottomBar(...)` instantiation at line 204 with:

```dart
Builder(
  builder: (ctx) => _BottomBar(
    counts: counts,
    onImport: onImport,
    onBack: onBack,
    hasPendingReviews: state.hasPendingReviews,
    totalPending: state.totalPending,
    onReviewPending: () {
      final loc = notifier.firstPendingLocation();
      if (loc == null) return;
      final tabIdx = types.indexOf(loc.type);
      if (tabIdx < 0) return;
      DefaultTabController.maybeOf(ctx)?.animateTo(tabIdx);
    },
  ),
),
```

- [ ] **Step 5: Run widget tests — expect PASS**

Run: `flutter test test/features/import_wizard/presentation/widgets/review_step_pending_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/import_wizard/presentation/widgets/review_step.dart test/features/import_wizard/presentation/widgets/review_step_pending_test.dart
git add lib/features/import_wizard/presentation/widgets/review_step.dart test/features/import_wizard/presentation/widgets/review_step_pending_test.dart
git commit -m "feat: gate Import button + add pending-hint bar with Review jump

The Import Selected button is disabled while any tab has pending-
review duplicates. A warning-colored hint row above the button
shows the pending count and a Review button that animates to the
first pending tab via firstPendingLocation."
```

---

## Task 10: Banner copy addendum (if the active flow has a duplicates banner)

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/review_step.dart` or `entity_review_list.dart`

This task depends on whether the active flow has a prominent duplicates banner like the old `ImportReviewStep` did. Look at the `EntityReviewList` header (`_SectionLabel` at line 137 / 146) and the `review_step.dart` top area.

If there is no separate summary banner, skip this task.

If there is a banner or a visible "N duplicates found" label, add a secondary line (styled bodySmall, FontWeight.w600, colorScheme.onTertiaryContainer or similar) reading `context.l10n.universalImport_summary_decidesRequired` whenever `state.hasPendingReviews`.

- [ ] **Step 1: Inspect the current UI**

Run: `cat lib/features/import_wizard/presentation/widgets/review_step.dart lib/features/import_wizard/presentation/widgets/entity_review_list.dart | grep -i "duplicate\|banner\|found" | head -20`

- [ ] **Step 2: If a banner exists, extend it with a conditional addendum line**

(Exact code depends on where it lives; follow the style of nearby copy.)

- [ ] **Step 3: If no banner exists, skip this task** and proceed to Task 11. Leave a note in the commit chain that the `universalImport_summary_decidesRequired` key is unused on this PR and can be removed in a cleanup sweep.

---

## Task 11: Issue #200 regression test

**File:**
- Create: `test/features/import_wizard/presentation/providers/issue_200_regression_test.dart`

Self-contained test file that explicitly guards against the original bug returning.

- [ ] **Step 1: Create the test file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';

/// Regression test for https://github.com/submersion-app/submersion/issues/200.
///
/// Suspected-duplicate rows (probable OR possible) must not receive a silent
/// default action. The Import button stays gated until the user explicitly
/// decides for every flagged duplicate.
///
/// Before this fix:
///   - Probable duplicates (score >= 0.7) auto-defaulted to skip.
///   - Possible duplicates (0.5 <= score < 0.7) auto-defaulted to importAsNew.
/// After the fix:
///   - Both enter pendingDuplicateReview and receive NO default action.
///   - The user must call setDuplicateAction or applyBulkAction to resolve.
///
/// This file inlines its fixtures so it is not affected by helper refactors
/// in other test files.
void main() {
  group('issue #200: suspected duplicates require explicit selection', () {
    test('probable duplicate is pending and has NO default action', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithProbableDuplicate());

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), {0});
      expect(state.duplicateActions[ImportEntityType.dives],
          anyOf(isNull, isEmpty),
          reason:
              'No auto-default skip/importAsNew may be recorded — this would '
              're-introduce the issue #200 silent-default bug.');
    });

    test('possible duplicate is pending and has NO default action', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithPossibleDuplicate());

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), {0});
      expect(state.duplicateActions[ImportEntityType.dives],
          anyOf(isNull, isEmpty));
    });

    test('explicit skip resolves pending', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithProbableDuplicate());
      expect(container.read(importWizardNotifierProvider).hasPendingReviews,
          isTrue);

      notifier.setDuplicateAction(
          ImportEntityType.dives, 0, DuplicateAction.skip);

      final state = container.read(importWizardNotifierProvider);
      expect(state.hasPendingReviews, isFalse);
      expect(state.duplicateActions[ImportEntityType.dives]?[0],
          DuplicateAction.skip);
    });

    test('bulk skip resolves pending', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithProbableDuplicate());
      notifier.applyBulkAction(ImportEntityType.dives, DuplicateAction.skip);

      final state = container.read(importWizardNotifierProvider);
      expect(state.hasPendingReviews, isFalse);
    });

    test('importAsNew resolves pending and selects the dive', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithProbableDuplicate());
      notifier.setDuplicateAction(
          ImportEntityType.dives, 0, DuplicateAction.importAsNew);

      final state = container.read(importWizardNotifierProvider);
      expect(state.hasPendingReviews, isFalse);
      expect(state.selections[ImportEntityType.dives], contains(0));
    });
  });
}

ProviderContainer _freshContainer() {
  final container = ProviderContainer(overrides: [
    importWizardNotifierProvider.overrideWith(
      (ref) => ImportWizardNotifier(_TestAdapter()),
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

ImportBundle _bundleWithProbableDuplicate() {
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.file,
      displayName: 'Test',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [
          EntityItem(
            diveData: DiveData(
              startTime: DateTime(2024, 1, 1, 10, 0),
              maxDepth: 20.0,
              bottomTime: const Duration(minutes: 30),
            ),
            displayName: 'Duplicate dive',
            displaySubtitle: null,
            existingData: null,
          ),
        ],
        duplicateIndices: const {0},
        matchResults: {
          0: const DiveMatchResult(
            diveId: 'existing-1',
            score: 0.9,
            timeDifferenceMs: 0,
            depthDifferenceMeters: 0.0,
            durationDifferenceSeconds: 0,
          ),
        },
      ),
    },
  );
}

ImportBundle _bundleWithPossibleDuplicate() {
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.file,
      displayName: 'Test',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [
          EntityItem(
            diveData: DiveData(
              startTime: DateTime(2024, 1, 1, 10, 0),
              maxDepth: 20.0,
              bottomTime: const Duration(minutes: 30),
            ),
            displayName: 'Possible dup',
            displaySubtitle: null,
            existingData: null,
          ),
        ],
        duplicateIndices: const {0},
        matchResults: {
          0: const DiveMatchResult(
            diveId: 'existing-1',
            score: 0.55,
            timeDifferenceMs: 600000,
            depthDifferenceMeters: 3.0,
            durationDifferenceSeconds: 480,
          ),
        },
      ),
    },
  );
}

class _TestAdapter implements ImportSourceAdapter {
  @override
  String get defaultTagName => 'Test Import';

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
        DuplicateAction.skip,
        DuplicateAction.importAsNew,
        DuplicateAction.consolidate,
      };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
```

Note: the exact class/field names (`DiveData`, `EntityItem`, `ImportSourceInfo`, etc.) MUST match the project's current models. If any differs (e.g., `duration` vs `bottomTime`, `diveDateTime` vs `startTime`), adjust to match.

- [ ] **Step 2: Run**

Run: `flutter test test/features/import_wizard/presentation/providers/issue_200_regression_test.dart`
Expected: 5/5 PASS.

- [ ] **Step 3: Commit**

```bash
dart format test/features/import_wizard/presentation/providers/issue_200_regression_test.dart
git add test/features/import_wizard/presentation/providers/issue_200_regression_test.dart
git commit -m "test: add issue #200 regression test against ImportWizardState

Self-contained test file guarding that suspected duplicates (both
probable and possible) never receive a silent default action and
require an explicit user decision before the Import button enables."
```

---

## Task 12: Final verification

- [ ] **Step 1: Full feature test sweep**

Run: `flutter test test/features/import_wizard/`
Expected: all pass.

- [ ] **Step 2: Analyze + format**

Run: `flutter analyze lib/features/import_wizard/ test/features/import_wizard/`
Expected: No issues.

Run: `dart format --set-exit-if-changed lib/features/import_wizard/ test/features/import_wizard/`
Expected: 0 changed.

- [ ] **Step 3: Broader suite (regression check)**

Run: `flutter test test/features/universal_import/ test/features/dive_import/`
Expected: all pre-existing tests still pass. The orphan `universal_import/` code wasn't touched; its tests should still pass unmodified.

- [ ] **Step 4: Manual smoke test**

Defer to user. Run `flutter run -d macos` and exercise:

1. Import a file with known duplicates.
2. Confirm Import button is disabled until each pending row has an explicit decision.
3. Confirm pending rows sort to top with warning border + "Needs decision" pill.
4. Try bulk Skip all / Import all as new.
5. Try Review button — it should jump to the tab with unresolved duplicates.
6. Resolve everything; confirm Import button enables and performs a successful import.
7. Non-duplicate rows still behave as before.

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| State field + helpers | 1 |
| setBundle populates + clears defaults | 2 |
| setDuplicateAction / toggleSelection drain | 3 |
| applyBulkAction | 4 |
| firstPendingLocation + PendingLocation | 5 |
| Semantics l10n key + NeedsDecisionPill | 6 |
| DuplicateActionCard pending visual | 7 |
| EntityReviewList sort + bulk + _EntityDuplicateCard pending | 8 |
| Import gate + pending hint + Review jump | 9 |
| Banner copy addendum | 10 (conditional) |
| Regression test | 11 |
| Final verification | 12 |

**Placeholder scan:** none — every code snippet is complete.

**Type consistency:** `PendingLocation.type` / `.index`, `pendingDuplicateReview`, `hasPendingReviews`, `pendingFor`, `_drainPending`, `isPending` are consistent across tasks.

**Risks for the implementer:**

- Exact model signatures (`DiveData`, `EntityItem`, etc.) must be read from source; the helpers assume specific field names. Step 1 of most tasks instructs to read the relevant file.
- The `_EntityDuplicateCard` in `entity_review_list.dart` is a private class — adding `isPending` to it requires modifying a private field; the public API change is on `EntityReviewList` passing `pendingIndices` down.
- The `_TestAdapter` must implement whatever the real `ImportSourceAdapter` interface requires. If the interface is small and stable, use an explicit implementation; if large, the `noSuchMethod` fallback is acceptable since tests don't exercise unused methods.
