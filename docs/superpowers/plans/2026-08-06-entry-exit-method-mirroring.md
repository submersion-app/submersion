# Entry/Exit Method Mirroring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the single-dive edit form, the exit-method picker mirrors the entry-method picker until the user explicitly changes exit, so the common identical-entry-and-exit dive needs one selection instead of two.

**Architecture:** Pure edit-form state change inside `_DiveEditPageState`: one new boolean `_exitMethodLinked` plus updated `onChanged` closures on the two `EnumPickerRow` call sites in `_environmentRows`. No schema, entity, sync, import/export, statistics, or bulk-edit changes — both concrete values are always stored.

**Tech Stack:** Flutter widget tests (`flutter_test`), Riverpod provider overrides, in-memory Drift test database via existing `test_database.dart` helpers.

**Spec:** `docs/superpowers/specs/2026-08-06-entry-exit-method-mirroring-design.md`

## Global Constraints

- Bulk edit must be untouched: the bulk layout (`_buildBulkForm`) shares the same `_entryMethod` / `_exitMethod` state fields — mirroring logic must live ONLY in the single-dive `EnumPickerRow` `onChanged` closures, never in a shared setter or in the `_enumDropdown` handlers.
- Opening an existing dive and saving without touching either picker must never change stored values (no backfill of an empty exit).
- No new l10n strings, no database/entity changes.
- All Dart code must pass `dart format .` with no changes (run before every commit).
- `flutter analyze` treats infos as fatal in CI — run it on the whole project and fix everything it reports in touched files.
- Never pipe `flutter analyze` or `flutter test` output through `tail`/`head` in a way that masks the exit code.

## Codebase Orientation (read once before Task 1)

Key facts an implementer needs, all verified against the current tree:

- `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (~4400 lines) hosts BOTH the single-dive form and the bulk-edit form in one `ConsumerStatefulWidget` state class.
  - State fields `_entryMethod` / `_exitMethod` (type `EntryMethod?`) are declared at lines 190-191.
  - Existing-dive load populates them at lines 614-615.
  - Single-dive form pickers: two `EnumPickerRow<EntryMethod>` widgets at lines ~3562-3575 inside `_environmentRows`, which is spread into `ConditionsSection` (collapsed by default: `_isExpanded('conditions', defaultValue: false)`).
  - Bulk form pickers: `_enumDropdown<EntryMethod>` wrapped in `_gatedRow(BulkField.entryMethod, ...)` / `_gatedRow(BulkField.exitMethod, ...)` at lines ~1356-1379. DO NOT TOUCH THESE.
- `EntryMethod` enum (`lib/core/constants/enums.dart:237`): `shore`, `boat`, `backRoll`, `giantStride`, `seatedEntry`, `ladder`, `platform`, `jetty`, `other`.
- `EnumPickerRow` (`lib/shared/widgets/forms/enum_picker_row.dart`) opens a modal bottom sheet of `ListTile` options; choosing "Not specified" calls `onChanged(null)`; dismissing the sheet calls nothing.
- English strings (used as widget-test finders): row labels `'Entry Method'` / `'Exit Method'`, options `'Shore Entry'`, `'Boat Entry'`, `'Ladder'`, `'Giant Stride'`, clear option `'Not specified'`, section header `'Conditions'`, save button `'Save'`.
- `FormSection` header: the whole header row (including the plain-cased label text) is wrapped in the toggle `InkWell`, so `tester.tap(find.text('Conditions'))` expands the section. Collapsed sections do NOT mount their children.

Widget-test traps (learned the hard way in this codebase):

- `pumpAndSettle` TIMES OUT on a NEW `DiveEditPage` (a continuous animation never settles). For new-dive tests use a bounded pump loop. For existing-dive tests `pumpAndSettle` works.
- The form is a lazy `ListView`: widgets below viewport+cacheExtent are not in the element tree, so `find` returns nothing and `ensureVisible` throws. Use `tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first)`.
- Set a tall test view (`tester.view.physicalSize = const Size(1200, 4000)` with `devicePixelRatio = 1.0`) to minimize scrolling.
- When a bottom sheet is open, the page rows behind it are still in the tree — tap sheet options via `find.widgetWithText(ListTile, ...)` (only the sheet uses `ListTile`), and make row-value assertions only AFTER the sheet has closed.

---

### Task 1: New-dive mirroring (link, follow, break, clear)

**Files:**
- Create: `test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (state field ~line 191, two `EnumPickerRow` closures ~lines 3562-3575)

**Interfaces:**
- Consumes: `DiveEditPage(embedded: true)` create-mode constructor; test helpers `setUpTestDatabase()` / `tearDownTestDatabase()` (`test/helpers/test_database.dart`) and `getBaseOverrides()` (`test/helpers/mock_providers.dart`); `DiveRepository` from `dive_repository_impl.dart`.
- Produces: state field `bool _exitMethodLinked` (initialized `true`) in `_DiveEditPageState` — Task 2 adds its load-time initialization. Test-file helpers `pumpFrames`, `expandConditions`, `pickMethod`, `buildOverrides`, `pumpEditPage` — Tasks 2 and 3 add tests to this same file using them.

- [ ] **Step 1: Write the test file with helpers and four failing tests**

Create `test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// New-dive pages host a continuous animation, so pumpAndSettle never
/// settles; a bounded pump loop drains async work and animations instead.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The Conditions section is collapsed by default and its children are not
/// mounted while collapsed. The whole header row (including the label text)
/// is the toggle tap target.
Future<void> expandConditions(WidgetTester tester) async {
  final header = find.text('Conditions');
  await tester.scrollUntilVisible(
    header,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(header);
  await pumpFrames(tester);
}

/// Opens the EnumPickerRow labeled [rowLabel] and taps the sheet option
/// [optionText]. Sheet options are ListTiles; page rows are not, so
/// widgetWithText(ListTile, ...) cannot hit the row behind the sheet.
Future<void> pickMethod(
  WidgetTester tester,
  String rowLabel,
  String optionText,
) async {
  final row = find.text(rowLabel);
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(row);
  await pumpFrames(tester);
  await tester.tap(find.widgetWithText(ListTile, optionText));
  await pumpFrames(tester);
}

void main() {
  group('DiveEditPage entry/exit mirroring (new dive)', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    List<dynamic> buildOverrides(List<dynamic> base) {
      return [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith((ref) {
          return DiveListNotifier(repository, ref);
        }),
        customTankPresetsProvider.overrideWith((ref) async => []),
      ];
    }

    Future<void> pumpNewDivePage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DiveEditPage(embedded: true)),
          ),
        ),
      );
      await pumpFrames(tester);
    }

    testWidgets('selecting entry method fills exit method', (tester) async {
      await pumpNewDivePage(tester);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Shore Entry');

      // Entry row value + mirrored exit row value.
      expect(find.text('Shore Entry'), findsNWidgets(2));
    });

    testWidgets('exit follows subsequent entry changes while linked', (
      tester,
    ) async {
      await pumpNewDivePage(tester);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Shore Entry');
      await pickMethod(tester, 'Entry Method', 'Boat Entry');

      expect(find.text('Boat Entry'), findsNWidgets(2));
      expect(find.text('Shore Entry'), findsNothing);
    });

    testWidgets('touching exit breaks the link for the session', (
      tester,
    ) async {
      await pumpNewDivePage(tester);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Shore Entry');
      await pickMethod(tester, 'Exit Method', 'Ladder');
      await pickMethod(tester, 'Entry Method', 'Boat Entry');

      // Entry changed alone; exit kept its explicit value.
      expect(find.text('Boat Entry'), findsOneWidget);
      expect(find.text('Ladder'), findsOneWidget);
    });

    testWidgets('clearing entry while linked clears exit', (tester) async {
      await pumpNewDivePage(tester);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Shore Entry');
      await pickMethod(tester, 'Entry Method', 'Not specified');

      expect(find.text('Shore Entry'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart`

Expected: the first, second, and fourth tests FAIL (exit row does not mirror — e.g. `findsNWidgets(2)` finds 1). The third test may PASS already (independent pickers also satisfy it); that is fine — it exists to guard the link-breaking behavior once mirroring lands. If tests fail for navigation reasons instead (finder not found, tap off-screen), fix the test navigation first — the failure must be the missing feature, not broken plumbing.

- [ ] **Step 3: Implement mirroring in dive_edit_page.dart**

In `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, add the state field directly below `_exitMethod` (line ~191):

```dart
  EntryMethod? _entryMethod;
  EntryMethod? _exitMethod;
  // Exit mirrors entry until the user edits the exit picker directly.
  // Single-dive form only; the bulk layout's dropdowns share these value
  // fields but must never trigger mirroring.
  bool _exitMethodLinked = true;
```

Then replace the two `EnumPickerRow` closures in `_environmentRows` (lines ~3562-3575):

```dart
      EnumPickerRow<EntryMethod>(
        label: l10n.diveLog_edit_label_entryMethod,
        value: _entryMethod,
        values: EntryMethod.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() {
          _entryMethod = v;
          if (_exitMethodLinked) _exitMethod = v;
        }),
      ),
      EnumPickerRow<EntryMethod>(
        label: l10n.diveLog_edit_label_exitMethod,
        value: _exitMethod,
        values: EntryMethod.values,
        displayName: (v) => v.localizedName(l10n),
        onChanged: (v) => setState(() {
          _exitMethod = v;
          _exitMethodLinked = false;
        }),
      ),
```

Do NOT modify the `_enumDropdown` handlers in `_buildBulkForm` (lines ~1356-1379).

- [ ] **Step 4: Run the tests to verify all four pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart`

Expected: 4 tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart
git commit -m "Mirror exit method from entry method on new dives"
```

---

### Task 2: Link state when opening an existing dive

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (load path, lines ~614-615)
- Modify: `test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart` (add a second group)

**Interfaces:**
- Consumes: `bool _exitMethodLinked` from Task 1; test helpers `pumpFrames`, `expandConditions`, `pickMethod`, `buildOverrides` from Task 1's file; `DiveRepository.createDive(Dive)` and the `Dive` entity constructor.
- Produces: load-time initialization `_exitMethodLinked = _exitMethod == null || _exitMethod == _entryMethod;` — Task 3 relies on this exact rule for the empty-exit case.

- [ ] **Step 1: Add two failing tests for existing dives**

Append a second group inside `main()` in `dive_edit_entry_exit_mirror_test.dart`. Add these imports at the top of the file:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
```

```dart
  group('DiveEditPage entry/exit mirroring (existing dive)', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    List<dynamic> buildOverrides(List<dynamic> base) {
      return [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith((ref) {
          return DiveListNotifier(repository, ref);
        }),
        customTankPresetsProvider.overrideWith((ref) async => []),
      ];
    }

    Dive buildDive({EntryMethod? entry, EntryMethod? exit}) => Dive(
      id: 'dive-entry-exit',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 28, 10, 0),
      entryTime: DateTime(2026, 3, 28, 10, 5),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 20.0,
      entryMethod: entry,
      exitMethod: exit,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );

    Future<void> pumpExistingDivePage(
      WidgetTester tester,
      String diveId,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: buildOverrides(overrides).cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DiveEditPage(diveId: diveId, embedded: true),
            ),
          ),
        ),
      );
      // Existing-dive pages settle normally (no perpetual animation).
      await tester.pumpAndSettle();
    }

    testWidgets('equal saved values open linked: entry change updates both', (
      tester,
    ) async {
      final created = await repository.createDive(
        buildDive(entry: EntryMethod.shore, exit: EntryMethod.shore),
      );
      await pumpExistingDivePage(tester, created.id);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Boat Entry');

      expect(find.text('Boat Entry'), findsNWidgets(2));
      expect(find.text('Shore Entry'), findsNothing);
    });

    testWidgets('differing saved values open unlinked: exit stays put', (
      tester,
    ) async {
      final created = await repository.createDive(
        buildDive(entry: EntryMethod.giantStride, exit: EntryMethod.ladder),
      );
      await pumpExistingDivePage(tester, created.id);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Boat Entry');

      expect(find.text('Boat Entry'), findsOneWidget);
      expect(find.text('Ladder'), findsOneWidget);
      expect(find.text('Giant Stride'), findsNothing);
    });
  });
```

- [ ] **Step 2: Run the new group to verify the second test fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart`

Expected: 'equal saved values' PASSES already (Task 1 initialized `_exitMethodLinked = true` and the load path does not yet overwrite it — equal values happen to behave linked). 'differing saved values' FAILS: without load-time initialization the page still considers the pickers linked, so changing entry drags exit along ('Ladder' disappears, 'Boat Entry' found twice).

- [ ] **Step 3: Initialize link state in the load path**

In `dive_edit_page.dart`, extend the conditions-loading block (lines ~614-615):

```dart
          _entryMethod = dive.entryMethod;
          _exitMethod = dive.exitMethod;
          _exitMethodLinked =
              _exitMethod == null || _exitMethod == _entryMethod;
```

- [ ] **Step 4: Run the full test file to verify all six pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart`

Expected: 6 tests PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart
git commit -m "Initialize entry/exit link state when loading an existing dive"
```

---

### Task 3: No silent backfill on untouched save + full verification

**Files:**
- Modify: `test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart` (one test added to the existing-dive group)
- No production changes expected — this is a regression guard proving the Task 1/2 implementation does not write on load.

**Interfaces:**
- Consumes: `buildDive`, `pumpExistingDivePage`, `expandConditions` from Task 2; `DiveRepository.getDiveById(String) → Future<Dive?>`; save button label `'Save'` (rendered by `EditFormScaffold`).
- Produces: nothing consumed later; final gate before review.

- [ ] **Step 1: Add the untouched-save test**

Append inside the existing-dive group from Task 2:

```dart
    testWidgets('untouched open-and-save never backfills an empty exit', (
      tester,
    ) async {
      final created = await repository.createDive(
        buildDive(entry: EntryMethod.shore, exit: null),
      );
      await pumpExistingDivePage(tester, created.id);
      await expandConditions(tester);

      // Exit row shows no value on load — only the entry row has one.
      expect(find.text('Shore Entry'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getDiveById(created.id);
      expect(saved!.entryMethod, EntryMethod.shore);
      expect(saved.exitMethod, isNull);
    });
```

- [ ] **Step 2: Run the test file — all seven should pass with no production change**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart`

Expected: 7 tests PASS. If this test fails because exit was saved as `shore`, mirroring leaked into the load path — re-check that Task 2 only sets `_exitMethodLinked` and never assigns `_exitMethod` outside the two `onChanged` closures.

- [ ] **Step 3: Guard the neighbors — run the surrounding suites**

Run: `flutter test test/features/dive_log/presentation/pages/`

Expected: all tests in the directory PASS (this covers the existing edit-page tests and every bulk-edit test, proving bulk behavior is untouched). Note: some suites in this repo are flaky only in the FULL test run, not per-directory; if something unrelated fails here, re-run that file alone before assuming this change broke it.

- [ ] **Step 4: Analyze and format the whole project**

```bash
flutter analyze
dart format .
```

Expected: analyze reports no issues (infos are fatal in CI); format changes nothing.

- [ ] **Step 5: Commit**

```bash
git add test/features/dive_log/presentation/pages/dive_edit_entry_exit_mirror_test.dart
git commit -m "Guard against exit-method backfill on untouched save"
```

---

## Out of Scope (verbatim from spec)

- Bulk edit (`bulk_edit_field_set.dart` and the bulk layout inside `dive_edit_page.dart`): entry and exit dropdowns stay fully independent.
- Database schema, `Dive` entity, sync/HLC handling.
- UDDF export/import, MacDive import, statistics, dive detail page display.
- l10n: no new strings.
- No visual link indicator on the exit row.
