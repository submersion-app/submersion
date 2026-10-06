# O2 Cell Linearity Checklist Item Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `cellLinearity` pre-dive checklist item type that records a CCR oxygen cell's millivolts in pure oxygen, reads the cell's air millivolts back from an earlier item in the same checklist, and shows the linearity percentage.

**Architecture:** One new value on `PreDiveItemType`, plus three nullable columns carrying an item-to-item reference and a frozen copy of the source reading. The reference is remapped wherever ids are reassigned (template clone, session compose) and tolerated as dangling everywhere it is read. The percentage is derived by a pure domain service from two frozen numbers and the constant 0.209.

**Tech Stack:** Flutter, Dart, Drift (SQLite), Riverpod, `flutter_test`, ARB localisation across 11 locales.

**Spec:** `docs/superpowers/specs/2026-09-08-cell-linearity-checklist-item-design.md`

## Global Constraints

- **No em-dashes** (the long dash, codepoint U+2014) in any file, commit message, or PR text. No en-dash (U+2013) or spaced-hyphen substitutes as prose punctuation either. Rewrite with a comma, colon, semicolon, or two sentences. A hyphen inside a compound word or a CLI flag is fine, as is an en-dash in a numeric range.
- **No AI-tool attribution** anywhere written to the repository or GitHub. No co-author trailers, no tool or model names in commit messages, PR titles and bodies, issue or review comments, release notes, or code comments. No session URLs. No "generated with" lines. This holds even when an automated reviewer explicitly asks for an "Addressed by" line.
- **No emojis** in code, comments, or documentation.
- **TDD.** Write the failing test, run it and see it fail for the right reason, then implement.
- **Immutability.** Never mutate an existing list or entity; build a new one. Every domain entity has `copyWith`.
- **Commit only the files each task names.** Never `git add -A` or `git add -u`: sibling worktrees share this checkout's stash and index hazards, and a broad add sweeps unrelated edits.
- **Run `dart format .`** over the whole project before the final commit of each task.
- **Localised strings** go through `context.l10n`. Never hard-code display text in a widget. Built-in seed titles in SQL are the documented exception and stay plain English data strings.
- **Advisory, never blocking.** No threshold in this feature may prevent the diver completing an item or a session.
- **The air oxygen fraction is exactly `0.209`** and lives in one place, `CellLinearity.airOxygenFraction`.
- **Built-in template item ids `builtin-predive-ccr-4`, `-5`, `-6` must never be renumbered or retired.** The new linearity rows reference those exact ids.

---

## File Structure

**Create:**

| File | Responsibility |
|---|---|
| `lib/features/pre_dive/domain/services/cell_linearity.dart` | The constant and the two derivations. Pure, no Flutter imports. |
| `test/features/pre_dive/domain/services/cell_linearity_test.dart` | Calculator vectors and null handling. |
| `test/core/database/migration_v201_cell_linearity_test.dart` | The new rung. Rename if the rung number changes (Task 3, Step 1). |

**Modify:**

| File | Change |
|---|---|
| `lib/features/pre_dive/domain/entities/pre_dive_checklist_template.dart` | `cellLinearity` enum value; `sourceItemId` on the template item. |
| `lib/features/pre_dive/domain/entities/pre_dive_session.dart` | `sourceItemId` and `sourceValueNumber` on the session item; type-aware `valueOutOfRange`; `linearityPercent` and `expectedO2Millivolts` getters. |
| `lib/core/database/database.dart` | Three columns, two guard helpers, the rung, the beforeOpen backstops, the built-in seed rows and the sort-order renumbering. |
| `lib/features/pre_dive/data/repositories/pre_dive_session_repository.dart` | Read and write the new session-item columns; honour non-empty incoming ids. |
| `lib/features/pre_dive/data/repositories/pre_dive_template_repository.dart` | Persist `sourceItemId`; remap it in `cloneTemplate`. |
| `lib/features/pre_dive/domain/services/session_item_composer.dart` | Mint ids, remap the link, degrade a dangling source. |
| `lib/features/pre_dive/presentation/pages/pre_dive_session_runner_page.dart` | Linearity entry dialog. |
| `lib/features/pre_dive/presentation/widgets/session_item_tile.dart` | Linearity subtitle lines and tap routing. |
| `lib/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart` | Type option, source picker, threshold relabel, delete and reorder hazards. |
| `lib/core/services/export/excel/pre_dive_excel_export_service.dart` | Type label plus two new columns. |
| `lib/l10n/arb/app_*.arb` (11 files) | New keys. |

---

## Task 1: The linearity calculator

**Files:**
- Create: `lib/features/pre_dive/domain/services/cell_linearity.dart`
- Test: `test/features/pre_dive/domain/services/cell_linearity_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `CellLinearity.airOxygenFraction` (`double`, 0.209), `CellLinearity.expectedO2Millivolts(double? airMillivolts) -> double?`, `CellLinearity.percent({double? airMillivolts, double? o2Millivolts}) -> double?`.

- [ ] **Step 1: Write the failing test**

Create `test/features/pre_dive/domain/services/cell_linearity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/pre_dive/domain/services/cell_linearity.dart';

void main() {
  test('air oxygen fraction is 0.209', () {
    expect(CellLinearity.airOxygenFraction, 0.209);
  });

  test('expected O2 millivolts is the air reading over 0.209', () {
    // The issue's own worked example: 10.1 mV in air.
    final expected = CellLinearity.expectedO2Millivolts(10.1)!;
    expect(expected, closeTo(48.325, 0.001));
  });

  test('linearity is measured over expected, as a percentage', () {
    // 48.0 mV measured against an expected 48.325 mV.
    final percent = CellLinearity.percent(
      airMillivolts: 10.1,
      o2Millivolts: 48.0,
    )!;
    expect(percent, closeTo(99.33, 0.01));
    expect(percent.round(), 99);
  });

  test('a cell that reaches exactly its expected output reads 100 percent', () {
    final percent = CellLinearity.percent(
      airMillivolts: 10.0,
      o2Millivolts: 10.0 / 0.209,
    )!;
    expect(percent, closeTo(100.0, 0.000001));
  });

  test('a current limited cell reads well below 100 percent', () {
    // 10.1 mV in air expects 48.3; a cell topping out at 40 mV is sick.
    final percent = CellLinearity.percent(
      airMillivolts: 10.1,
      o2Millivolts: 40.0,
    )!;
    expect(percent, lessThan(85));
  });

  test('the percentage is computed from the exact expected value', () {
    // Rounding expected to 1 dp first would give 48.0 / 48.3 = 99.379,
    // which rounds to 99 either way, but the exact path must not agree by
    // accident: assert the precise unrounded figure.
    expect(
      CellLinearity.percent(airMillivolts: 10.1, o2Millivolts: 48.0),
      closeTo(48.0 / (10.1 / 0.209) * 100, 1e-9),
    );
  });

  group('missing and unusable inputs yield null, never an error', () {
    test('null air reading', () {
      expect(CellLinearity.expectedO2Millivolts(null), isNull);
      expect(
        CellLinearity.percent(airMillivolts: null, o2Millivolts: 48.0),
        isNull,
      );
    });

    test('zero air reading does not divide into infinity', () {
      expect(CellLinearity.expectedO2Millivolts(0), isNull);
      expect(
        CellLinearity.percent(airMillivolts: 0, o2Millivolts: 48.0),
        isNull,
      );
    });

    test('negative air reading', () {
      expect(CellLinearity.expectedO2Millivolts(-1.5), isNull);
      expect(
        CellLinearity.percent(airMillivolts: -1.5, o2Millivolts: 48.0),
        isNull,
      );
    });

    test('null O2 reading', () {
      expect(
        CellLinearity.percent(airMillivolts: 10.1, o2Millivolts: null),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
flutter test test/features/pre_dive/domain/services/cell_linearity_test.dart
```

Expected: compile failure, `Target of URI doesn't exist: '.../cell_linearity.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/pre_dive/domain/services/cell_linearity.dart`:

```dart
/// The oxygen-cell linearity check CCR divers run on every build (issue
/// #986).
///
/// A galvanic cell's output is proportional to the ppO2 at its face, so a
/// reading taken in air predicts what the cell should produce in pure
/// oxygen. A cell that cannot reach that figure is current limited: it reads
/// plausibly at the surface and under-reports at depth.
///
/// The ambient pressure term cancels in the ratio (both readings are taken
/// at the same place, seconds apart), so this needs no altitude or
/// barometric input and must never acquire one.
class CellLinearity {
  const CellLinearity._();

  /// Fraction of oxygen in air, the divisor the check is built on.
  static const double airOxygenFraction = 0.209;

  /// Millivolts the cell should produce at a ppO2 of 1.0, or null when
  /// [airMillivolts] is absent or not positive.
  ///
  /// A zero or negative air reading is a broken or disconnected cell, not a
  /// number to divide by, so it yields null rather than an infinity.
  static double? expectedO2Millivolts(double? airMillivolts) {
    if (airMillivolts == null || airMillivolts <= 0) return null;
    return airMillivolts / airOxygenFraction;
  }

  /// Measured output over expected output, as a percentage, or null when
  /// either input is missing or the expectation cannot be computed.
  ///
  /// Derived from the exact expected value, never from a rounded one:
  /// rounding is presentation, applied once at the point of display.
  static double? percent({
    double? airMillivolts,
    double? o2Millivolts,
  }) {
    final expected = expectedO2Millivolts(airMillivolts);
    if (expected == null || o2Millivolts == null) return null;
    return o2Millivolts / expected * 100;
  }
}
```

- [ ] **Step 4: Run the test and confirm it passes**

```bash
flutter test test/features/pre_dive/domain/services/cell_linearity_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/pre_dive/domain/services/cell_linearity.dart test/features/pre_dive/domain/services/cell_linearity_test.dart
git commit -m "feat(pre-dive): add O2 cell linearity calculator (#986)"
```

---

## Task 2: Entity fields, the new enum value, and the two exhaustive switches

Adding a fifth value to `PreDiveItemType` breaks two switch expressions at compile time. Both are fixed here so the tree stays buildable; the Excel export's real work is Task 10.

**Files:**
- Modify: `lib/features/pre_dive/domain/entities/pre_dive_checklist_template.dart`
- Modify: `lib/features/pre_dive/domain/entities/pre_dive_session.dart`
- Modify: `lib/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart:368-374` (`_typeLabel`)
- Modify: `lib/core/services/export/excel/pre_dive_excel_export_service.dart:225-230` (`_typeLabel`)
- Test: `test/features/pre_dive/domain/entities/pre_dive_entities_test.dart`

**Interfaces:**
- Consumes: `CellLinearity` from Task 1.
- Produces:
  - `PreDiveItemType.cellLinearity`
  - `PreDiveChecklistTemplateItem.sourceItemId` (`String?`), in the constructor, `copyWith` (with the `_undefined` sentinel) and `props`
  - `PreDiveSessionItem.sourceItemId` (`String?`) and `PreDiveSessionItem.sourceValueNumber` (`double?`), likewise
  - `PreDiveSessionItem.isCellLinearity` (`bool`)
  - `PreDiveSessionItem.expectedO2Millivolts` (`double?`)
  - `PreDiveSessionItem.linearityPercent` (`double?`)
  - `PreDiveSessionItem.valueOutOfRange`, now type-aware
- New l10n key needed by neither switch fix: the Excel label is a plain English data string like its four neighbours, and the editor's label comes from Task 6.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/pre_dive/domain/entities/pre_dive_entities_test.dart`, inside `main()`:

```dart
  group('cell linearity items', () {
    PreDiveSessionItem linearityItem({
      double? airMillivolts,
      double? o2Millivolts,
      double? min,
      double? max,
    }) => PreDiveSessionItem(
      id: 'i1',
      sessionId: 's1',
      title: 'Cell 1 mV in O2',
      itemType: PreDiveItemType.cellLinearity,
      valueLabel: 'Cell 1',
      valueUnit: 'mV',
      valueMin: min,
      valueMax: max,
      valueNumber: o2Millivolts,
      sourceItemId: 'air1',
      sourceValueNumber: airMillivolts,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('parses the new type name', () {
      expect(
        PreDiveItemType.parse('cellLinearity'),
        PreDiveItemType.cellLinearity,
      );
    });

    test('an unknown type still falls back to check', () {
      // Forward compatibility: an older build must render a newer type as a
      // plain checkbox rather than throwing.
      expect(PreDiveItemType.parse('somethingNewer'), PreDiveItemType.check);
    });

    test('derives the expected O2 output and the percentage', () {
      final item = linearityItem(airMillivolts: 10.1, o2Millivolts: 48.0);
      expect(item.expectedO2Millivolts, closeTo(48.325, 0.001));
      expect(item.linearityPercent, closeTo(99.33, 0.01));
    });

    test('derives nothing without a frozen air reading', () {
      final item = linearityItem(o2Millivolts: 48.0);
      expect(item.expectedO2Millivolts, isNull);
      expect(item.linearityPercent, isNull);
    });

    test('thresholds are read as a percentage, not as millivolts', () {
      // The regression this guards: valueMin/valueMax hold a percentage on a
      // linearity item, but valueNumber holds millivolts. Comparing the two
      // lights amber on every healthy cell.
      final healthy = linearityItem(
        airMillivolts: 10.1,
        o2Millivolts: 48.0,
        min: 95,
      );
      expect(healthy.linearityPercent!.round(), 99);
      expect(healthy.valueOutOfRange, isFalse);

      final sick = linearityItem(
        airMillivolts: 10.1,
        o2Millivolts: 40.0,
        min: 95,
      );
      expect(sick.valueOutOfRange, isTrue);
    });

    test('a linearity item with no percentage is never out of range', () {
      final item = linearityItem(o2Millivolts: 48.0, min: 95);
      expect(item.valueOutOfRange, isFalse);
    });

    test('a plain value item still compares against valueNumber', () {
      final item = PreDiveSessionItem(
        id: 'i2',
        sessionId: 's1',
        title: 'Cell 1 mV in air',
        itemType: PreDiveItemType.value,
        valueNumber: 8.0,
        valueMin: 8.5,
        valueMax: 13.0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(item.valueOutOfRange, isTrue);
    });

    test('copyWith round-trips the new fields and can null them', () {
      final item = linearityItem(airMillivolts: 10.1, o2Millivolts: 48.0);
      expect(item.copyWith(sourceValueNumber: 9.9).sourceValueNumber, 9.9);
      expect(item.copyWith(sourceItemId: null).sourceItemId, isNull);
      expect(item.copyWith(sourceValueNumber: null).sourceValueNumber, isNull);
      expect(item.copyWith(title: 'x').sourceItemId, 'air1');
    });

    test('template items round-trip sourceItemId through copyWith', () {
      final t = PreDiveChecklistTemplateItem(
        id: 't1',
        templateId: 'tpl',
        title: 'Cell 1 mV in O2',
        itemType: PreDiveItemType.cellLinearity,
        sourceItemId: 'air1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(t.sourceItemId, 'air1');
      expect(t.copyWith(sourceItemId: null).sourceItemId, isNull);
      expect(t.copyWith(title: 'x').sourceItemId, 'air1');
      expect(t.props, contains('air1'));
    });
  });
```

Check the file's existing imports and add any of these that are missing:

```dart
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
flutter test test/features/pre_dive/domain/entities/pre_dive_entities_test.dart
```

Expected: compile failure on `PreDiveItemType.cellLinearity` and on the `sourceItemId` / `sourceValueNumber` named arguments.

- [ ] **Step 3: Add the enum value and the template-item field**

In `lib/features/pre_dive/domain/entities/pre_dive_checklist_template.dart`, extend the enum:

```dart
enum PreDiveItemType {
  check,
  value,
  equipmentSet,
  equipment,

  /// Records a cell's millivolts in pure oxygen and derives its linearity
  /// against the air reading held by the item named in [sourceItemId]
  /// (issue #986).
  cellLinearity;

  static PreDiveItemType parse(String raw) => PreDiveItemType.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => PreDiveItemType.check,
  );
}
```

Do not touch `parse`. Its fallback to `check` is what lets an older build render a synced `cellLinearity` row as a plain checkbox instead of failing.

In `PreDiveChecklistTemplateItem`, add the field beside `equipmentId`:

```dart
  /// For a [PreDiveItemType.cellLinearity] item, the id of the template item
  /// holding this cell's air reading. Null on every other type, and
  /// tolerated as dangling: ids are remapped on clone and at session start,
  /// and a source item can be deleted from under this one.
  final String? sourceItemId;
```

Add `this.sourceItemId,` to the constructor, `Object? sourceItemId = _undefined,` to `copyWith` with

```dart
      sourceItemId: sourceItemId == _undefined
          ? this.sourceItemId
          : sourceItemId as String?,
```

and `sourceItemId,` to `props`.

- [ ] **Step 4: Add the session-item fields and the derived getters**

In `lib/features/pre_dive/domain/entities/pre_dive_session.dart`, add the import:

```dart
import 'package:submersion/features/pre_dive/domain/services/cell_linearity.dart';
```

Add both fields to `PreDiveSessionItem` beside `equipmentId`:

```dart
  /// For a [PreDiveItemType.cellLinearity] item, the id of the session item
  /// holding this cell's air reading, remapped from the template item id by
  /// SessionItemComposer. Tolerated as dangling.
  final String? sourceItemId;

  /// The air millivolts, frozen the moment the diver resolved this item.
  ///
  /// Frozen rather than re-read for the same reason [overdueServices] is: a
  /// completed run is an audit record, and a later correction to the air
  /// reading must not silently rewrite what the diver saw when they made the
  /// call.
  final double? sourceValueNumber;
```

Add both to the constructor, to `copyWith` (with the `_undefined` sentinel for each) and to `props`.

Replace the existing `valueOutOfRange` getter with the type-aware trio:

```dart
  bool get isCellLinearity => itemType == PreDiveItemType.cellLinearity;

  /// Millivolts this cell should produce at a ppO2 of 1.0, from the frozen
  /// air reading. Null on any other item type, or before the air reading is
  /// known.
  double? get expectedO2Millivolts => isCellLinearity
      ? CellLinearity.expectedO2Millivolts(sourceValueNumber)
      : null;

  /// This cell's linearity as a percentage, or null when it cannot be
  /// derived yet.
  double? get linearityPercent => isCellLinearity
      ? CellLinearity.percent(
          airMillivolts: sourceValueNumber,
          o2Millivolts: valueNumber,
        )
      : null;

  /// Advisory range warning (never blocking).
  ///
  /// [valueMin] and [valueMax] mean millivolts on a `value` item but a
  /// percentage on a `cellLinearity` item, so the figure they are compared
  /// against differs by type. Comparing a 95% floor against a 48 mV reading
  /// would light amber on every healthy cell.
  bool get valueOutOfRange {
    final v = isCellLinearity ? linearityPercent : valueNumber;
    if (v == null) return false;
    final belowMin = valueMin != null && v < valueMin!;
    final aboveMax = valueMax != null && v > valueMax!;
    return belowMin || aboveMax;
  }
```

- [ ] **Step 5: Fix the two exhaustive switches so the tree compiles**

In `lib/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart`, add the arm to `_typeLabel`. Task 6 creates the key; until then this will not resolve, so use the placeholder-free interim of the English string and replace it in Task 7:

```dart
      PreDiveItemType.cellLinearity =>
        context.l10n.preDive_item_type_cellLinearity,
```

If Task 6 has not run yet, this line will not compile. Run Task 6 before Task 2's final commit, or temporarily return `'Cell linearity'` and correct it in Task 7. Prefer running Task 6 first.

In `lib/core/services/export/excel/pre_dive_excel_export_service.dart`, add the arm. Export labels here are plain English data strings, matching the four existing arms:

```dart
    PreDiveItemType.cellLinearity => 'Cell linearity',
```

- [ ] **Step 6: Run the tests and confirm they pass**

```bash
flutter test test/features/pre_dive/domain/entities/pre_dive_entities_test.dart
```

Expected: all tests pass, including the two threshold tests that failed for the right reason in Step 2.

- [ ] **Step 7: Confirm nothing else broke**

```bash
flutter analyze lib test 2>&1 | tail -20
```

Expected: no new errors. Any remaining non-exhaustive switch on `PreDiveItemType` shows up here.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/features/pre_dive/domain/entities/pre_dive_checklist_template.dart lib/features/pre_dive/domain/entities/pre_dive_session.dart lib/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart lib/core/services/export/excel/pre_dive_excel_export_service.dart test/features/pre_dive/domain/entities/pre_dive_entities_test.dart
git commit -m "feat(pre-dive): add cellLinearity item type and derived getters (#986)"
```

---

## Task 3: Schema columns and the migration rung

**Files:**
- Modify: `lib/core/database/database.dart`
- Create: `test/core/database/migration_v201_cell_linearity_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: columns `pre_dive_checklist_template_items.source_item_id TEXT`, `pre_dive_session_items.source_item_id TEXT`, `pre_dive_session_items.source_value_number REAL`; Drift companions `PreDiveChecklistTemplateItemsCompanion.sourceItemId`, `PreDiveSessionItemsCompanion.sourceItemId`, `PreDiveSessionItemsCompanion.sourceValueNumber`; helpers `_assertTemplateItemSourceIdColumn()` and `_assertSessionItemSourceColumns()`.

- [ ] **Step 1: Establish the rung number before writing anything**

The ladder is contested by parallel branches. Do not trust a number written in a document.

```bash
grep -n 'static const int currentSchemaVersion' lib/core/database/database.dart
git branch -a --format='%(refname:short)' | head -50
```

Then check whether any sibling branch has already taken the next rung:

```bash
git log --all --oneline -S'currentSchemaVersion = 200' -- lib/core/database/database.dart | head
```

**Resolved during execution on 2026-09-08: the rung is v201, not v200.** Main is at v199, but `git log --all -S'currentSchemaVersion = 200'` shows commit `c2eca95772e` on the unmerged branch `ericgriffin/issue-1365-brainstorm-f1e2c7` already holding v200 for the transmitter registry. Looking only at main would have collided with it. The rest of this task, and the migration test filename, use **v201**. Re-run the same check before trusting even this number, and if #1365 merges first nothing changes, while if this branch merges first that one renumbers.

- [ ] **Step 2: Write the failing migration test**

Create `test/core/database/migration_v201_cell_linearity_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v201 adds the O2 cell linearity link (issue #986):
/// pre_dive_checklist_template_items.source_item_id, plus
/// pre_dive_session_items.source_item_id and .source_value_number.

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v201 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 201);
    expect(AppDatabase.migrationVersions, contains(201));
  });

  test('a fresh database has all three linearity columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(
      await _columns(db, 'pre_dive_checklist_template_items'),
      contains('source_item_id'),
    );
    final sessionItemColumns = await _columns(db, 'pre_dive_session_items');
    expect(sessionItemColumns, contains('source_item_id'));
    expect(sessionItemColumns, contains('source_value_number'));
  });

  test('a database stranded before v201 gains the columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 200');
        rawDb.execute('''
          CREATE TABLE pre_dive_checklist_template_items (
            id TEXT NOT NULL PRIMARY KEY,
            template_id TEXT NOT NULL,
            title TEXT NOT NULL,
            item_type TEXT NOT NULL DEFAULT 'check',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute('''
          CREATE TABLE pre_dive_session_items (
            id TEXT NOT NULL PRIMARY KEY,
            session_id TEXT NOT NULL,
            title TEXT NOT NULL,
            item_type TEXT NOT NULL DEFAULT 'check',
            state TEXT NOT NULL DEFAULT 'pending',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(
      await _columns(db, 'pre_dive_checklist_template_items'),
      contains('source_item_id'),
    );
    final sessionItemColumns = await _columns(db, 'pre_dive_session_items');
    expect(sessionItemColumns, contains('source_item_id'));
    expect(sessionItemColumns, contains('source_value_number'));
  });

  test('the columns round-trip a link and a frozen air reading', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      "INSERT INTO pre_dive_sessions "
      "(id, template_name, started_at, created_at, updated_at) "
      "VALUES ('s1', 'CCR Build', 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO pre_dive_session_items "
      "(id, session_id, title, item_type, source_item_id, "
      "source_value_number, value_number, created_at, updated_at) "
      "VALUES ('o2', 's1', 'Cell 1 mV in O2', 'cellLinearity', 'air1', "
      "10.1, 48.0, 1, 1)",
    );

    final row = await db
        .customSelect(
          "SELECT source_item_id, source_value_number FROM "
          "pre_dive_session_items WHERE id = 'o2'",
        )
        .getSingle();
    expect(row.read<String>('source_item_id'), 'air1');
    expect(row.read<double>('source_value_number'), 10.1);
  });
}
```

- [ ] **Step 3: Run it and confirm it fails**

```bash
flutter test test/core/database/migration_v201_cell_linearity_test.dart
```

Expected: FAIL. `currentSchemaVersion` is 199, and the columns are absent.

- [ ] **Step 4: Add the Drift columns**

In `lib/core/database/database.dart`, in `class PreDiveChecklistTemplateItems`, after `equipmentId`:

```dart
  /// For a 'cellLinearity' item, the template item holding this cell's air
  /// reading (issue #986).
  ///
  /// Deliberately not a SQL-level FK, for the same reason as [equipmentId]:
  /// these rows are seeded into isolated schema fixtures and re-seeded at
  /// every app start, so a REFERENCES clause would demand the referenced row
  /// exist wherever this table does. Remapped on clone and at session start;
  /// every reader tolerates a dangling value.
  TextColumn get sourceItemId => text().nullable()();
```

In `class PreDiveSessionItems`, after `equipmentId`:

```dart
  /// For a 'cellLinearity' item, the session item holding this cell's air
  /// reading, remapped from the template item id at compose time.
  ///
  /// Not a SQL-level FK: this references a row in the same table, and the
  /// two rows sync as independent HLC records with no guaranteed order of
  /// arrival, so a constraint would reject a legitimate out-of-order insert.
  TextColumn get sourceItemId => text().nullable()();

  /// The air millivolts, frozen when the diver resolved this item. Kept
  /// rather than re-read so a completed audit record cannot be rewritten by
  /// a later edit to the source row.
  RealColumn get sourceValueNumber => real().nullable()();
```

- [ ] **Step 5: Add the two guard helpers**

Beside `_assertTemplateItemEquipmentIdColumn` and `_assertSessionItemOverdueServicesColumn`, following their exact shape:

```dart
  /// Idempotent DDL for the v201 pre_dive_checklist_template_items
  /// .source_item_id column (issue #986). Self-guards on the table existing.
  /// Same dual-call contract (onUpgrade plus beforeOpen backstop) as the
  /// other column-assert helpers.
  Future<void> _assertTemplateItemSourceIdColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('pre_dive_checklist_template_items')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('source_item_id')) return;
    await customStatement(
      'ALTER TABLE pre_dive_checklist_template_items ADD COLUMN '
      'source_item_id TEXT',
    );
  }

  /// Idempotent DDL for the v201 pre_dive_session_items linearity columns
  /// (issue #986). Each column is guarded independently, so an upgrade
  /// interrupted between the two still gets the second on the next open.
  Future<void> _assertSessionItemSourceColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('pre_dive_session_items')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('source_item_id')) {
      await customStatement(
        'ALTER TABLE pre_dive_session_items ADD COLUMN source_item_id TEXT',
      );
    }
    if (!names.contains('source_value_number')) {
      await customStatement(
        'ALTER TABLE pre_dive_session_items ADD COLUMN source_value_number '
        'REAL',
      );
    }
  }
```

- [ ] **Step 6: Take the rung and add the backstops**

Bump the version:

```dart
  static const int currentSchemaVersion = 201;
```

Add 201 to `migrationVersions` in the same style as its neighbours.

In `onUpgrade`, after the `from < 199` block (around `database.dart:10577-10580`):

```dart
        // v201: the O2 cell linearity link (issue #986). Column-only rung,
        // no backfill: existing items are not linearity items and want null
        // in all three columns.
        if (from < 201) {
          await _assertTemplateItemSourceIdColumn();
          await _assertSessionItemSourceColumns();
        }
        if (from < 201) await reportProgress();
```

In `beforeOpen`, beside the other backstops:

```dart
        // v201 backstop: re-assert the cell linearity columns.
        await _assertTemplateItemSourceIdColumn();
        await _assertSessionItemSourceColumns();
```

- [ ] **Step 7: Regenerate Drift code**

The generated companions are needed by Task 4. `build_runner` cannot be invoked with a bare `build` token in a Bash command here (a repository read rule refuses it), so run it via an absolute path or the project's own script:

```bash
./scripts/setup.sh --codegen-only 2>/dev/null || dart run build_runner build --delete-conflicting-outputs
```

If neither form is permitted, write a one-line shell script into the scratchpad directory and execute that.

Confirm the companions gained the fields:

```bash
grep -c 'sourceValueNumber' lib/core/database/database.g.dart
```

Expected: a non-zero count.

- [ ] **Step 8: Run the migration test and confirm it passes**

```bash
flutter test test/core/database/migration_v201_cell_linearity_test.dart
```

Expected: all four tests pass.

- [ ] **Step 9: Sweep the stale version literals**

Bumping the version breaks assertions elsewhere that use the previous number as shorthand for "the ladder finished". Find them:

```bash
grep -rn '\b199\b' test/core/database/ test/core/services/ | grep -v migration_v199
```

For each hit, decide what the assertion means. If it means "the ladder ran to completion" or "this file needs no migration", replace the literal with `AppDatabase.currentSchemaVersion`. If it is v199's own rung tripwire in `migration_v199_certification_credentials_test.dart`, downgrade it:

```dart
    expect(
      AppDatabase.currentSchemaVersion,
      greaterThanOrEqualTo(199),
    );
```

Only the newest rung's own test pins a literal.

- [ ] **Step 10: Run the database suites**

```bash
flutter test test/core/database/
```

Expected: all pass. Any failure here is a stale literal Step 9 missed.

- [ ] **Step 11: Format and commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/
git commit -m "feat(pre-dive): add v201 schema for the cell linearity link (#986)"
```

---

## Task 4: Repository persistence

**Files:**
- Modify: `lib/features/pre_dive/data/repositories/pre_dive_session_repository.dart` (`startSession` around `:36-120`, `updateItemState` at `:362`, `_mapItem` at `:542`)
- Modify: `lib/features/pre_dive/data/repositories/pre_dive_template_repository.dart` (`saveItems` around `:200-275`, and its template-item row mapper)
- Test: `test/features/pre_dive/data/repositories/pre_dive_session_repository_test.dart`
- Test: `test/features/pre_dive/data/repositories/pre_dive_template_repository_test.dart`

**Interfaces:**
- Consumes: the entity fields from Task 2 and the columns from Task 3.
- Produces: `updateItemState` gains `double? sourceValueNumber`; `startSession` honours a non-empty `item.id` instead of always minting.

- [ ] **Step 1: Write the failing tests**

In `test/features/pre_dive/data/repositories/pre_dive_session_repository_test.dart`, follow the file's existing setup helpers and add:

```dart
  test('startSession honours ids the composer already minted', () async {
    final repo = PreDiveSessionRepository();
    final session = await repo.startSession(
      template: template,
      items: [
        sessionItem(id: 'pre-minted-1', title: 'Cell 1 mV in air'),
      ],
    );
    final items = await repo.getItemsForSession(session.id);
    expect(items.single.id, 'pre-minted-1');
  });

  test('startSession still mints an id when one is blank', () async {
    final repo = PreDiveSessionRepository();
    final session = await repo.startSession(
      template: template,
      items: [sessionItem(id: '', title: 'Check air')],
    );
    final items = await repo.getItemsForSession(session.id);
    expect(items.single.id, isNotEmpty);
  });

  test('startSession persists the link and the frozen air reading', () async {
    final repo = PreDiveSessionRepository();
    final session = await repo.startSession(
      template: template,
      items: [
        sessionItem(id: 'air1', title: 'Cell 1 mV in air'),
        sessionItem(
          id: 'o2-1',
          title: 'Cell 1 mV in O2',
          type: PreDiveItemType.cellLinearity,
          sourceItemId: 'air1',
        ),
      ],
    );
    final items = await repo.getItemsForSession(session.id);
    final linearity = items.firstWhere((i) => i.id == 'o2-1');
    expect(linearity.itemType, PreDiveItemType.cellLinearity);
    expect(linearity.sourceItemId, 'air1');
  });

  test('resolving a linearity item freezes the air reading', () async {
    final repo = PreDiveSessionRepository();
    final session = await repo.startSession(
      template: template,
      items: [
        sessionItem(
          id: 'o2-1',
          title: 'Cell 1 mV in O2',
          type: PreDiveItemType.cellLinearity,
          sourceItemId: 'air1',
        ),
      ],
    );
    await repo.updateItemState(
      sessionId: session.id,
      itemId: 'o2-1',
      state: PreDiveItemState.done,
      valueNumber: 48.0,
      sourceValueNumber: 10.1,
    );
    final item = (await repo.getItemsForSession(session.id)).single;
    expect(item.valueNumber, 48.0);
    expect(item.sourceValueNumber, 10.1);
    expect(item.linearityPercent!.round(), 99);
  });

  test('resetting a linearity item clears the frozen air reading', () async {
    final repo = PreDiveSessionRepository();
    final session = await repo.startSession(
      template: template,
      items: [
        sessionItem(
          id: 'o2-1',
          title: 'Cell 1 mV in O2',
          type: PreDiveItemType.cellLinearity,
          sourceItemId: 'air1',
        ),
      ],
    );
    await repo.updateItemState(
      sessionId: session.id,
      itemId: 'o2-1',
      state: PreDiveItemState.done,
      valueNumber: 48.0,
      sourceValueNumber: 10.1,
    );
    await repo.updateItemState(
      sessionId: session.id,
      itemId: 'o2-1',
      state: PreDiveItemState.pending,
    );
    final item = (await repo.getItemsForSession(session.id)).single;
    expect(item.sourceValueNumber, isNull);
    expect(item.sourceItemId, 'air1', reason: 'the link itself survives');
  });
```

Add a `sourceItemId` parameter to the file's existing `sessionItem(...)` helper if it has one, or write one matching the file's conventions.

In `test/features/pre_dive/data/repositories/pre_dive_template_repository_test.dart`:

```dart
  test('saveItems persists sourceItemId', () async {
    final repo = PreDiveTemplateRepository();
    final tpl = await repo.createTemplate(newTemplate('CCR'));
    await repo.saveItems(tpl.id, [
      templateItem(id: 'air1', title: 'Cell 1 mV in air'),
      templateItem(
        id: 'o2-1',
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        sourceItemId: 'air1',
      ),
    ]);
    final items = await repo.getItemsForTemplate(tpl.id);
    final linearity = items.firstWhere((i) => i.id == 'o2-1');
    expect(linearity.sourceItemId, 'air1');
  });
```

- [ ] **Step 2: Run and confirm they fail**

```bash
flutter test test/features/pre_dive/data/repositories/
```

Expected: compile failure on the `sourceValueNumber` named argument and the `sourceItemId` helper parameter.

- [ ] **Step 3: Read the new columns in both mappers**

In `pre_dive_session_repository.dart`, in `_mapItem` (`:542`), add beside `equipmentId: row.equipmentId,`:

```dart
        sourceItemId: row.sourceItemId,
        sourceValueNumber: row.sourceValueNumber,
```

In `pre_dive_template_repository.dart`, find the equivalent template-item mapper and add:

```dart
        sourceItemId: row.sourceItemId,
```

- [ ] **Step 4: Honour pre-minted ids in `startSession`**

In `startSession`, replace

```dart
          final itemId = _uuid.v4();
```

with

```dart
          // The composer mints ids so it can write the cell-linearity link
          // between two items it is building in the same pass. A caller that
          // leaves the id blank still gets one, matching saveItems.
          final itemId = item.id.isEmpty ? _uuid.v4() : item.id;
```

Add the two fields to the `PreDiveSessionItemsCompanion` in that insert, beside `equipmentId`:

```dart
                  sourceItemId: Value(item.sourceItemId),
                  sourceValueNumber: Value(item.sourceValueNumber),
```

Update the doc comment above `startSession`, which currently says items arrive with a blank id.

- [ ] **Step 5: Freeze and clear in `updateItemState`**

Add the parameter:

```dart
    double? sourceValueNumber,
```

and, in the companion, beside the `overdueServices` line:

```dart
              // Frozen alongside overdueServices and cleared by the same
              // rule: a reset returns the item to pending, where a stale
              // frozen reading would be a lie.
              sourceValueNumber: isPending
                  ? const Value(null)
                  : (sourceValueNumber == null
                        ? const Value.absent()
                        : Value(sourceValueNumber)),
```

`sourceItemId` is not written here. The link is set once, at compose time, and survives a reset.

- [ ] **Step 6: Persist `sourceItemId` in `saveItems`**

In the batch insert companion in `saveItems`, beside `equipmentId`:

```dart
                sourceItemId: Value(entry.item.sourceItemId),
```

- [ ] **Step 7: Run and confirm they pass**

```bash
flutter test test/features/pre_dive/data/repositories/
```

Expected: all pass.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/features/pre_dive/data/repositories/ test/features/pre_dive/data/repositories/
git commit -m "feat(pre-dive): persist the cell linearity link and frozen reading (#986)"
```

---

## Task 5: Remap the link in the composer and the clone

This is the task that keeps the pair linked. Without it, cloning the built-in CCR template silently unlinks all three pairs, which is the most likely way a diver first meets this feature.

**Files:**
- Modify: `lib/features/pre_dive/domain/services/session_item_composer.dart`
- Modify: `lib/features/pre_dive/data/repositories/pre_dive_template_repository.dart:281-303` (`cloneTemplate`)
- Test: `test/features/pre_dive/domain/services/session_item_composer_test.dart`
- Test: `test/features/pre_dive/data/repositories/pre_dive_template_repository_test.dart`

**Interfaces:**
- Consumes: Task 2's entities, Task 4's `startSession` id handling.
- Produces: `SessionItemComposer.compose` now returns items with non-empty `id`s and remapped `sourceItemId`s.

**Breaking change to an existing test:** `session_item_composer_test.dart` currently asserts `expect(out[0].id, isEmpty)`. That assertion is now wrong and must be inverted. Do not delete the test; change it to assert the ids are non-empty and distinct.

- [ ] **Step 1: Write the failing tests**

In `test/features/pre_dive/domain/services/session_item_composer_test.dart`, first amend the existing assertion in the test named `'check and value items snapshot 1:1 with blank id/sessionId'`. Rename it and change the two id expectations:

```dart
  test('check and value items snapshot 1:1 with minted ids', () {
    final out = SessionItemComposer.compose(
      templateItems: [
        tItem(0),
        tItem(1, type: PreDiveItemType.value),
      ],
      now: now,
    );
    expect(out, hasLength(2));
    // The composer mints ids so it can link a linearity item to its source
    // in the same pass; startSession honours whatever it set.
    expect(out[0].id, isNotEmpty);
    expect(out[1].id, isNotEmpty);
    expect(out[0].id, isNot(out[1].id));
    expect(out[0].sessionId, isEmpty);
    expect(out[0].title, 'T0');
    expect(out[1].itemType, PreDiveItemType.value);
    expect(out.every((i) => i.state == PreDiveItemState.pending), isTrue);
  });
```

Then add:

```dart
  PreDiveChecklistTemplateItem linearityTItem(
    int order, {
    required String? sourceItemId,
    double? min,
  }) => PreDiveChecklistTemplateItem(
    id: 't$order',
    templateId: 'tpl',
    title: 'Cell mV in O2',
    sortOrder: order,
    itemType: PreDiveItemType.cellLinearity,
    valueLabel: 'Cell 1',
    valueUnit: 'mV',
    valueMin: min,
    sourceItemId: sourceItemId,
    createdAt: now,
    updatedAt: now,
  );

  test('the link is remapped from template ids to session ids', () {
    final out = SessionItemComposer.compose(
      templateItems: [
        tItem(0, type: PreDiveItemType.value),
        linearityTItem(1, sourceItemId: 't0'),
      ],
      now: now,
    );
    expect(out, hasLength(2));
    expect(out[1].itemType, PreDiveItemType.cellLinearity);
    expect(
      out[1].sourceItemId,
      out[0].id,
      reason: 'must point at the session item, not the template item',
    );
    expect(out[1].sourceItemId, isNot('t0'));
  });

  test('a forward reference is remapped too', () {
    // The editor allows dragging a linearity row above its source. The link
    // must survive it; only strict-order gating cares about the ordering.
    final out = SessionItemComposer.compose(
      templateItems: [
        linearityTItem(0, sourceItemId: 't1'),
        tItem(1, type: PreDiveItemType.value),
      ],
      now: now,
    );
    expect(out[0].sourceItemId, out[1].id);
  });

  test('a dangling source degrades the item to a plain value', () {
    final out = SessionItemComposer.compose(
      templateItems: [linearityTItem(0, sourceItemId: 'gone', min: 95)],
      now: now,
    );
    expect(out.single.itemType, PreDiveItemType.value);
    expect(out.single.sourceItemId, isNull);
  });

  test('a null source degrades the item to a plain value', () {
    final out = SessionItemComposer.compose(
      templateItems: [linearityTItem(0, sourceItemId: null, min: 95)],
      now: now,
    );
    expect(out.single.itemType, PreDiveItemType.value);
  });

  test('degrading drops the percentage thresholds', () {
    // valueMin is a percentage on a linearity item but millivolts on a value
    // item. Carrying 95 across would light amber on every healthy cell.
    final out = SessionItemComposer.compose(
      templateItems: [linearityTItem(0, sourceItemId: 'gone', min: 95)],
      now: now,
    );
    expect(out.single.valueMin, isNull);
    expect(out.single.valueMax, isNull);
    expect(out.single.valueOutOfRange, isFalse);
    expect(
      out.single.valueUnit,
      'mV',
      reason: 'the unit still describes valueNumber and stays',
    );
  });
```

In `test/features/pre_dive/data/repositories/pre_dive_template_repository_test.dart`:

```dart
  test('cloneTemplate remaps the cell linearity link to the new ids', () async {
    final repo = PreDiveTemplateRepository();
    final tpl = await repo.createTemplate(newTemplate('CCR'));
    await repo.saveItems(tpl.id, [
      templateItem(id: 'air1', title: 'Cell 1 mV in air'),
      templateItem(
        id: 'o2-1',
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        sourceItemId: 'air1',
      ),
    ]);

    final clone = await repo.cloneTemplate(tpl.id, newName: 'My CCR');
    final items = await repo.getItemsForTemplate(clone.id);
    final air = items.firstWhere((i) => i.title == 'Cell 1 mV in air');
    final linearity = items.firstWhere((i) => i.title == 'Cell 1 mV in O2');

    expect(air.id, isNot('air1'), reason: 'the clone gets fresh ids');
    expect(
      linearity.sourceItemId,
      air.id,
      reason: 'the link must follow the remap, not dangle at the original id',
    );
  });
```

- [ ] **Step 2: Run and confirm they fail**

```bash
flutter test test/features/pre_dive/domain/services/session_item_composer_test.dart test/features/pre_dive/data/repositories/pre_dive_template_repository_test.dart
```

Expected: the remap tests fail with the linearity item's `sourceItemId` still holding the template id (`'t0'`, `'air1'`), and the degradation tests fail with the type still `cellLinearity`.

- [ ] **Step 3: Rewrite `compose` to mint ids and remap**

In `lib/features/pre_dive/domain/services/session_item_composer.dart`, add the import:

```dart
import 'package:uuid/uuid.dart';
```

Add a generator field to the class and switch the three `id: ''` sites to minted ids. Because a linearity item may reference an item that appears later in the list, this needs two passes: mint every id first, then build the items.

Replace the body of `compose` with:

```dart
  static const _uuid = Uuid();

  static List<PreDiveSessionItem> compose({
    required List<PreDiveChecklistTemplateItem> templateItems,
    EquipmentSet? equipmentSet,
    List<EquipmentItem> equipmentItems = const [],
    Map<String, String> equipmentByTemplateItemId = const {},
    required DateTime now,
  }) {
    final byId = {for (final g in equipmentItems) g.id: g};
    final sorted = [...templateItems]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Pass one: mint a session id for every template item that produces
    // exactly one row, so a cellLinearity item can point at its source
    // whether the source sorts before or after it. equipmentSet items are
    // excluded: they fan out to zero or many rows and nothing references
    // them.
    final sessionIdByTemplateId = <String, String>{
      for (final t in sorted)
        if (t.itemType != PreDiveItemType.equipmentSet) t.id: _uuid.v4(),
    };

    final out = <PreDiveSessionItem>[];
    var order = 0;

    for (final t in sorted) {
      if (t.itemType == PreDiveItemType.equipment) {
        final equipmentId = equipmentByTemplateItemId[t.id] ?? t.equipmentId;
        final gear = equipmentId == null ? null : byId[equipmentId];
        out.add(
          PreDiveSessionItem(
            id: sessionIdByTemplateId[t.id]!,
            sessionId: '',
            section: t.section,
            title: t.title,
            notes: t.notes,
            sortOrder: order++,
            itemType: PreDiveItemType.check,
            isRequired: t.isRequired,
            equipmentId: gear?.id,
            createdAt: now,
            updatedAt: now,
          ),
        );
        continue;
      }
      if (t.itemType == PreDiveItemType.equipmentSet && equipmentSet != null) {
        for (final gearId in equipmentSet.equipmentIds) {
          final gear = byId[gearId];
          if (gear == null) continue;
          out.add(
            PreDiveSessionItem(
              id: _uuid.v4(),
              sessionId: '',
              section: t.section,
              title: gear.name,
              sortOrder: order++,
              itemType: PreDiveItemType.check,
              isRequired: t.isRequired,
              equipmentId: gear.id,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
        continue;
      }

      // equipmentSet placeholder without a set degrades to a plain check
      // item so the checklist stays runnable.
      var effectiveType = t.itemType == PreDiveItemType.equipmentSet
          ? PreDiveItemType.check
          : t.itemType;

      // A cellLinearity item whose source is missing degrades to a plain
      // value item: the diver is standing there with a meter, so the oxygen
      // reading is still worth recording even though the ratio cannot be
      // computed. Its thresholds must go with it, because they are a
      // percentage here and would be read as millivolts there.
      final sourceSessionId = t.sourceItemId == null
          ? null
          : sessionIdByTemplateId[t.sourceItemId];
      final degraded =
          effectiveType == PreDiveItemType.cellLinearity &&
          sourceSessionId == null;
      if (degraded) effectiveType = PreDiveItemType.value;

      out.add(
        PreDiveSessionItem(
          id: sessionIdByTemplateId[t.id]!,
          sessionId: '',
          section: t.section,
          title: t.title,
          notes: t.notes,
          sortOrder: order++,
          itemType: effectiveType,
          valueLabel: t.valueLabel,
          valueUnit: t.valueUnit,
          valueMin: degraded ? null : t.valueMin,
          valueMax: degraded ? null : t.valueMax,
          isRequired: t.isRequired,
          sourceItemId: sourceSessionId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return out;
  }
```

Update the class doc comment: it currently says the repository assigns ids.

- [ ] **Step 4: Remap in `cloneTemplate`**

In `pre_dive_template_repository.dart`, replace the body of `cloneTemplate` after the `createTemplate` call:

```dart
    // Ids are minted here rather than left to saveItems, because a
    // cellLinearity item's sourceItemId points at a sibling and has to be
    // rewritten to the sibling's NEW id. Leaving it to saveItems would clone
    // the template with every pair silently unlinked.
    final newIdByOldId = {for (final i in items) i.id: _uuid.v4()};
    await saveItems(clone.id, [
      for (final i in items)
        i.copyWith(
          id: newIdByOldId[i.id],
          templateId: clone.id,
          sourceItemId: i.sourceItemId == null
              ? null
              : newIdByOldId[i.sourceItemId],
        ),
    ]);
    return clone;
```

Confirm `_uuid` is already a field on this repository; it is used by `saveItems`.

- [ ] **Step 5: Run and confirm they pass**

```bash
flutter test test/features/pre_dive/domain/services/session_item_composer_test.dart test/features/pre_dive/data/repositories/
```

Expected: all pass, including the amended blank-id test.

- [ ] **Step 6: Run the wider pre-dive suite for fallout**

```bash
flutter test test/features/pre_dive/ test/core/services/sync/sync_pre_dive_test.dart
```

Expected: all pass. Anything else asserting blank composer ids surfaces here.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/pre_dive/domain/services/session_item_composer.dart lib/features/pre_dive/data/repositories/pre_dive_template_repository.dart test/features/pre_dive/
git commit -m "feat(pre-dive): remap the cell linearity link on clone and compose (#986)"
```

---

## Task 6: Localisation keys

Run this before Tasks 2, 7 and 8 need them to compile. If Task 2 ran first with a hard-coded English fallback, correct it here.

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the ten other locale files (`app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`)

**Interfaces:**
- Produces these `context.l10n` getters:
  - `preDive_item_type_cellLinearity`
  - `preDive_item_sourceItem`
  - `preDive_item_sourceItemRequired`
  - `preDive_item_linearityMin`
  - `preDive_item_linearityMax`
  - `preDive_item_sourceCleared(String title)`
  - `preDive_item_sourceBelow`
  - `preDive_runner_cellInAir`
  - `preDive_runner_cellInAirMissing`
  - `preDive_runner_enterO2Value`
  - `preDive_runner_linearityReadout(String expected, String percent)`
  - `preDive_runner_linearityLine(String air, String expected, String percent)`
  - `preDive_runner_sourceChanged`

- [ ] **Step 1: Add the English keys**

In `lib/l10n/arb/app_en.arb`, beside the existing `preDive_item_*` keys (around line 1550) and the `preDive_runner_*` keys (around line 1584):

```json
  "preDive_item_type_cellLinearity": "Cell linearity",
  "preDive_item_sourceItem": "Air reading from",
  "preDive_item_sourceItemRequired": "Choose the item holding the air reading",
  "preDive_item_linearityMin": "Min linearity % (warning)",
  "preDive_item_linearityMax": "Max linearity % (warning)",
  "preDive_item_sourceCleared": "{title} no longer has an air reading to compare against",
  "@preDive_item_sourceCleared": {
    "placeholders": {
      "title": {
        "type": "String"
      }
    }
  },
  "preDive_item_sourceBelow": "Reads a value recorded later in this list",
  "preDive_runner_cellInAir": "In air",
  "preDive_runner_cellInAirMissing": "Not yet recorded",
  "preDive_runner_enterO2Value": "Enter value in O2",
  "preDive_runner_linearityReadout": "Expected {expected} mV, linearity {percent}%",
  "@preDive_runner_linearityReadout": {
    "placeholders": {
      "expected": {
        "type": "String"
      },
      "percent": {
        "type": "String"
      }
    }
  },
  "preDive_runner_linearityLine": "Air {air} mV, expected {expected} mV, linearity {percent}%",
  "@preDive_runner_linearityLine": {
    "placeholders": {
      "air": {
        "type": "String"
      },
      "expected": {
        "type": "String"
      },
      "percent": {
        "type": "String"
      }
    }
  },
  "preDive_runner_sourceChanged": "Air reading has changed since",
```

Placeholders are `String`, not `double`, because the caller formats the numbers through `UnitFormatter` and `formatDecimalForInput` first. Passing a raw `double` would emit an unlocalised `48.325`.

- [ ] **Step 2: Translate into the other ten locales**

Every locale file must carry every key or the generator emits a fallback and the l10n staleness check fails. Translate the strings properly; do not copy English into the other files. `mV` and the `%` sign are units and stay as they are. Keep the placeholder names identical across all files.

Note that `app_ar.arb` and `app_he.arb` are right-to-left; write natural RTL text, not transliterated English.

- [ ] **Step 3: Regenerate and verify no key was missed**

```bash
flutter gen-l10n 2>&1 | tail -20
```

Then confirm all eleven files agree on the key set:

```bash
for f in lib/l10n/arb/app_*.arb; do
  printf '%s %s\n' "$(grep -c 'preDive_item_type_cellLinearity\|preDive_runner_linearityLine\|preDive_runner_sourceChanged' "$f")" "$f"
done
```

Expected: every line starts with `3`.

- [ ] **Step 4: Confirm the tree still analyses**

```bash
flutter analyze lib 2>&1 | tail -20
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/l10n/
git commit -m "i18n(pre-dive): add cell linearity strings across all locales (#986)"
```

---

## Task 7: Runner UI

**Files:**
- Modify: `lib/features/pre_dive/presentation/pages/pre_dive_session_runner_page.dart` (`_editValue` around `:99-114`, `_ValueEntryDialog` at `:364-432`)
- Modify: `lib/features/pre_dive/presentation/widgets/session_item_tile.dart`
- Test: `test/features/pre_dive/presentation/widgets/session_item_tile_test.dart`
- Test: `test/features/pre_dive/presentation/pages/pre_dive_session_runner_page_test.dart`

**Interfaces:**
- Consumes: Task 2's getters, Task 4's `updateItemState(sourceValueNumber:)`, Task 6's keys.
- Produces: no new public API.

- [ ] **Step 1: Write the failing tile tests**

In `test/features/pre_dive/presentation/widgets/session_item_tile_test.dart`, add `sourceItemId` and `sourceValueNumber` parameters to the file's existing `item({...})` helper, then add:

```dart
  testWidgets('a linearity item shows the working and the percentage', (
    tester,
  ) async {
    await pumpTile(
      tester,
      s: session(),
      it: item(
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        state: PreDiveItemState.done,
        valueLabel: 'Cell 1',
        valueUnit: 'mV',
        valueNumber: 48.0,
        valueMin: 95,
        sourceItemId: 'air1',
        sourceValueNumber: 10.1,
      ),
    );

    expect(find.textContaining('Cell 1: 48.0 mV'), findsOneWidget);
    expect(find.textContaining('Air 10.1 mV'), findsOneWidget);
    expect(find.textContaining('expected 48.3 mV'), findsOneWidget);
    expect(find.textContaining('linearity 99%'), findsOneWidget);
  });

  testWidgets('a low linearity reading is styled as out of range', (
    tester,
  ) async {
    await pumpTile(
      tester,
      s: session(),
      it: item(
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        state: PreDiveItemState.done,
        valueLabel: 'Cell 1',
        valueUnit: 'mV',
        valueNumber: 40.0,
        valueMin: 95,
        sourceItemId: 'air1',
        sourceValueNumber: 10.1,
      ),
    );

    final line = tester.widget<Text>(
      find.textContaining('linearity 83%'),
    );
    expect(line.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('a linearity item with no air reading shows no percentage', (
    tester,
  ) async {
    await pumpTile(
      tester,
      s: session(),
      it: item(
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        valueLabel: 'Cell 1',
        valueUnit: 'mV',
        sourceItemId: 'air1',
      ),
    );

    expect(find.textContaining('linearity'), findsNothing);
  });

  testWidgets('tapping a linearity item opens value entry, not done', (
    tester,
  ) async {
    var editCalls = 0;
    var doneCalls = 0;
    await pumpTile(
      tester,
      s: session(),
      it: item(
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        sourceItemId: 'air1',
      ),
      onEditValue: () => editCalls++,
      onDone: () => doneCalls++,
    );

    await tester.tap(find.text('Cell 1 mV in O2'));
    await tester.pump();
    expect(editCalls, 1);
    expect(doneCalls, 0);
  });
```

If `pumpTile` does not already accept `onEditValue` and `onDone` overrides, add them with no-op defaults, matching how the file passes the other callbacks.

- [ ] **Step 2: Run and confirm they fail**

```bash
flutter test test/features/pre_dive/presentation/widgets/session_item_tile_test.dart
```

Expected: the linearity lines are not found.

- [ ] **Step 3: Render the linearity lines in the tile**

In `session_item_tile.dart`, add the import:

```dart
import 'package:submersion/core/utils/number_input.dart';
```

Replace the `valueLine` computation with one that covers both types, and add the derived line. Insert above `final subtitleChildren`:

```dart
    final isValueLike =
        item.itemType == PreDiveItemType.value || item.isCellLinearity;

    final valueLine = isValueLike
        ? [
            if (item.valueLabel != null) item.valueLabel!,
            if (item.valueNumber != null)
              '${formatDecimalForInput(item.valueNumber!)}'
                  '${item.valueUnit == null ? '' : ' ${item.valueUnit}'}',
          ].join(': ')
        : null;

    // The full working, so the linearity result is readable from the list
    // without opening the item.
    final percent = item.linearityPercent;
    final expected = item.expectedO2Millivolts;
    final air = item.sourceValueNumber;
    final linearityLine = (percent != null && expected != null && air != null)
        ? l10n.preDive_runner_linearityLine(
            formatDecimalForInput(air),
            formatDecimalForInput(double.parse(expected.toStringAsFixed(1))),
            percent.round().toString(),
          )
        : null;
```

In `subtitleChildren`, after the existing `valueLine` entry:

```dart
      if (linearityLine != null)
        Text(
          linearityLine,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: item.valueOutOfRange
                ? Colors.amber.shade700
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: item.valueOutOfRange ? FontWeight.bold : null,
          ),
        ),
```

Change the tap routing at the bottom of the tile:

```dart
      onTap: actionable ? (isValueLike ? onEditValue : onDone) : null,
```

Note the existing `valueLine` used raw `${item.valueNumber}`, which prints `48.0` in every locale. Routing it through `formatDecimalForInput` is the correction that makes the assertion `'Cell 1: 48.0 mV'` hold under an English test locale and produce a comma decimal where the diver expects one.

- [ ] **Step 4: Add the "changed since" hint**

The tile does not know its siblings, so the hint is driven by the page. Add an optional parameter to `SessionItemTile`:

```dart
  /// The source item's current value, when this is a linearity item whose
  /// frozen air reading no longer matches it. Null means no discrepancy.
  final double? staleSourceValue;
```

Add `this.staleSourceValue,` to the constructor, and to `subtitleChildren`, after the linearity line:

```dart
      if (staleSourceValue != null)
        Text(
          l10n.preDive_runner_sourceChanged,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
```

In `pre_dive_session_runner_page.dart`, where `SessionItemTile` is constructed (around `:320-336`), compute it:

```dart
                      staleSourceValue: _staleSourceValue(items, item),
```

and add the helper to the page class:

```dart
  /// The source item's current value when it no longer matches the reading
  /// frozen onto [item], or null when there is nothing to flag.
  ///
  /// Only a resolved item can be stale: a pending one has frozen nothing
  /// yet, so there is no discrepancy to report.
  static double? _staleSourceValue(
    List<PreDiveSessionItem> items,
    PreDiveSessionItem item,
  ) {
    if (!item.isCellLinearity) return null;
    final frozen = item.sourceValueNumber;
    if (frozen == null) return null;
    final sourceId = item.sourceItemId;
    if (sourceId == null) return null;
    for (final candidate in items) {
      if (candidate.id != sourceId) continue;
      final current = candidate.valueNumber;
      if (current == null || current == frozen) return null;
      return current;
    }
    return null;
  }
```

- [ ] **Step 5: Write the failing dialog test**

In `test/features/pre_dive/presentation/pages/pre_dive_session_runner_page_test.dart`, following the file's existing session-seeding helpers, add:

```dart
  testWidgets('the linearity dialog shows the air reading and a live readout', (
    tester,
  ) async {
    // Seed a session with an answered air item and a pending linearity item
    // pointing at it, using this file's existing seeding helper.
    await pumpRunner(tester, items: [
      seededItem(
        id: 'air1',
        title: 'Cell 1 mV in air',
        type: PreDiveItemType.value,
        state: PreDiveItemState.done,
        valueNumber: 10.1,
        valueUnit: 'mV',
      ),
      seededItem(
        id: 'o2-1',
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        valueLabel: 'Cell 1',
        valueUnit: 'mV',
        sourceItemId: 'air1',
        valueMin: 95,
      ),
    ]);

    await tester.tap(find.text('Cell 1 mV in O2'));
    await tester.pumpAndSettle();

    expect(find.textContaining('10.1'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '48.0');
    await tester.pump();

    expect(find.textContaining('Expected 48.3 mV'), findsOneWidget);
    expect(find.textContaining('linearity 99%'), findsOneWidget);
  });

  testWidgets('confirming the linearity dialog freezes the air reading', (
    tester,
  ) async {
    await pumpRunner(tester, items: [
      seededItem(
        id: 'air1',
        title: 'Cell 1 mV in air',
        type: PreDiveItemType.value,
        state: PreDiveItemState.done,
        valueNumber: 10.1,
        valueUnit: 'mV',
      ),
      seededItem(
        id: 'o2-1',
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        valueLabel: 'Cell 1',
        valueUnit: 'mV',
        sourceItemId: 'air1',
      ),
    ]);

    await tester.tap(find.text('Cell 1 mV in O2'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '48.0');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Air 10.1 mV'), findsOneWidget);
    expect(find.textContaining('linearity 99%'), findsOneWidget);
  });
```

Adapt the helper names to whatever this file already defines. Pin `locale: const Locale('en')` as the file's other tests do, and pump one `ProviderScope` per test.

- [ ] **Step 6: Run and confirm they fail**

```bash
flutter test test/features/pre_dive/presentation/pages/pre_dive_session_runner_page_test.dart
```

Expected: the readout text is not found.

- [ ] **Step 7: Build the linearity entry dialog**

In `pre_dive_session_runner_page.dart`, change `_editValue` to carry the source reading through:

```dart
  Future<void> _editValue(
    BuildContext context,
    WidgetRef ref,
    List<PreDiveSessionItem> items,
    PreDiveSessionItem item,
  ) async {
    // Read the source at the instant the dialog opens and freeze whatever it
    // says when the diver confirms. A linearity item that is not linked, or
    // whose source is unanswered, still records its own reading.
    final sourceValue = item.isCellLinearity
        ? _currentSourceValue(items, item)
        : null;
    final result = await showDialog<({double? value, String? note})>(
      context: context,
      builder: (context) =>
          _ValueEntryDialog(item: item, sourceValue: sourceValue),
    );
    if (result == null) return;
    await _resolve(
      ref,
      item,
      PreDiveItemState.done,
      valueNumber: result.value,
      note: result.note,
      sourceValueNumber: sourceValue,
    );
  }

  /// The current value of [item]'s source row, or null when it is unlinked,
  /// missing, or not yet answered.
  static double? _currentSourceValue(
    List<PreDiveSessionItem> items,
    PreDiveSessionItem item,
  ) {
    final sourceId = item.sourceItemId;
    if (sourceId == null) return null;
    for (final candidate in items) {
      if (candidate.id == sourceId) return candidate.valueNumber;
    }
    return null;
  }
```

Thread `sourceValueNumber` through `_resolve` and `_setState` to `updateItemState`, adding the parameter to both and passing it on. In `_setState`, pass `item.sourceValueNumber` when the caller supplies none, mirroring how `overdueServices` is handled, so a note edit does not wipe the frozen reading.

Update the two other `_editValue` call sites to pass `items`.

Replace `_ValueEntryDialog` with a version that takes the source value and renders the readout:

```dart
class _ValueEntryDialog extends StatefulWidget {
  final PreDiveSessionItem item;

  /// The source item's air reading, for a cell linearity item. Null for a
  /// plain value item, or when the air reading has not been taken yet.
  final double? sourceValue;

  const _ValueEntryDialog({required this.item, this.sourceValue});

  @override
  State<_ValueEntryDialog> createState() => _ValueEntryDialogState();
}

class _ValueEntryDialogState extends State<_ValueEntryDialog> {
  late final TextEditingController _valueController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final value = widget.item.valueNumber;
    _valueController = TextEditingController(
      text: value == null ? '' : formatDecimalForInput(value),
    );
    _noteController = TextEditingController(text: widget.item.note);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The live readout, recomputed on every keystroke from the text in the
  /// field rather than from the stored value, so the diver sees the answer
  /// before committing to it.
  String? _readout(BuildContext context) {
    if (!widget.item.isCellLinearity) return null;
    final typed = parseUserDecimal(_valueController.text);
    final expected = CellLinearity.expectedO2Millivolts(widget.sourceValue);
    final percent = CellLinearity.percent(
      airMillivolts: widget.sourceValue,
      o2Millivolts: typed,
    );
    if (expected == null || percent == null) return null;
    return context.l10n.preDive_runner_linearityReadout(
      formatDecimalForInput(double.parse(expected.toStringAsFixed(1))),
      percent.round().toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isLinearity = widget.item.isCellLinearity;
    final readout = _readout(context);
    return AlertDialog(
      title: Text(widget.item.valueLabel ?? widget.item.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLinearity)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.sourceValue == null
                    ? '${l10n.preDive_runner_cellInAir}: '
                          '${l10n.preDive_runner_cellInAirMissing}'
                    : '${l10n.preDive_runner_cellInAir}: '
                          '${formatDecimalForInput(widget.sourceValue!)} '
                          '${widget.item.valueUnit ?? ''}'.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          TextField(
            controller: _valueController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: isLinearity
                  ? l10n.preDive_runner_enterO2Value
                  : l10n.preDive_runner_enterValue,
              suffixText: widget.item.valueUnit,
            ),
          ),
          if (readout != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(readout, style: theme.textTheme.bodyMedium),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(labelText: l10n.preDive_runner_addNote),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            value: parseUserDecimal(_valueController.text),
            note: _noteController.text.trim(),
          )),
          child: Text(l10n.common_action_ok),
        ),
      ],
    );
  }
}
```

Add the import for `CellLinearity` at the top of the page.

- [ ] **Step 8: Run and confirm they pass**

```bash
flutter test test/features/pre_dive/presentation/
```

Expected: all pass.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib/features/pre_dive/presentation/ test/features/pre_dive/presentation/
git commit -m "feat(pre-dive): record and display cell linearity in the runner (#986)"
```

---

## Task 8: Template editor

**Files:**
- Modify: `lib/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart`
- Test: `test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart`

**Interfaces:**
- Consumes: Task 2's entities, Task 6's keys.
- Produces: no new public API. `_PreDiveItemDialog` gains a `List<PreDiveChecklistTemplateItem> siblings` parameter so it can offer the source picker.

- [ ] **Step 1: Write the failing tests**

In `test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart`, following the file's existing pump helper and pinning `locale: const Locale('en')`:

```dart
  testWidgets('choosing cell linearity reveals a required source picker', (
    tester,
  ) async {
    await pumpEditPage(tester);

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Cell 1 mV in O2',
    );

    await tester.tap(find.byType(DropdownButtonFormField<PreDiveItemType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cell linearity').last);
    await tester.pumpAndSettle();

    expect(find.text('Air reading from'), findsOneWidget);
    expect(find.text('Min linearity % (warning)'), findsOneWidget);

    // Saving without a source is refused.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose the item holding the air reading'),
      findsOneWidget,
    );
  });

  testWidgets('deleting a source clears its dependants and says so', (
    tester,
  ) async {
    // Seed a template with an air value item and a linearity item on it,
    // using this file's existing seeding helper.
    await pumpEditPage(tester, items: [
      editItem(id: 'air1', title: 'Cell 1 mV in air', type: PreDiveItemType.value),
      editItem(
        id: 'o2-1',
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        sourceItemId: 'air1',
      ),
    ]);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no longer has an air reading'),
      findsOneWidget,
    );
  });

  testWidgets('a linearity row above its source carries a warning', (
    tester,
  ) async {
    await pumpEditPage(tester, items: [
      editItem(
        id: 'o2-1',
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        sourceItemId: 'air1',
      ),
      editItem(id: 'air1', title: 'Cell 1 mV in air', type: PreDiveItemType.value),
    ]);

    expect(
      find.text('Reads a value recorded later in this list'),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: Run and confirm they fail**

```bash
flutter test test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart
```

Expected: the dropdown has no "Cell linearity" entry.

- [ ] **Step 3: Pass the siblings into the item dialog**

In `_addOrEditItem`, pass the current list so the picker has candidates:

```dart
      builder: (context) => _PreDiveItemDialog(
        item: item,
        templateId: widget.templateId ?? '',
        defaultSortOrder: _items.length,
        siblings: _items,
      ),
```

Add the field and constructor parameter to `_PreDiveItemDialog`, and in its state add:

```dart
  String? _sourceItemId;
```

initialised in `initState` from `widget.item?.sourceItemId`.

The candidate list excludes the item being edited (an item cannot source itself):

```dart
  List<PreDiveChecklistTemplateItem> get _sourceCandidates => [
    for (final s in widget.siblings)
      if (s.itemType == PreDiveItemType.value && s.id != widget.item?.id) s,
  ];
```

- [ ] **Step 4: Render the source picker and relabel the thresholds**

In `_PreDiveItemDialogState.build`, replace the `if (_itemType == PreDiveItemType.value) ...[ ... ]` block's guard so both types show the value fields, and add the picker. Insert before the min/max fields:

```dart
              if (_itemType == PreDiveItemType.cellLinearity)
                DropdownButtonFormField<String>(
                  initialValue: _sourceItemId,
                  decoration: InputDecoration(
                    labelText: l10n.preDive_item_sourceItem,
                  ),
                  items: [
                    for (final candidate in _sourceCandidates)
                      DropdownMenuItem(
                        value: candidate.id,
                        child: Text(
                          candidate.valueLabel == null
                              ? candidate.title
                              : '${candidate.title} (${candidate.valueLabel})',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _sourceItemId = value),
                  validator: (value) => value == null
                      ? l10n.preDive_item_sourceItemRequired
                      : null,
                ),
```

Change the guard on the value fields to:

```dart
              if (_itemType == PreDiveItemType.value ||
                  _itemType == PreDiveItemType.cellLinearity) ...[
```

and make the two threshold labels type-dependent:

```dart
                    labelText: _itemType == PreDiveItemType.cellLinearity
                        ? l10n.preDive_item_linearityMin
                        : l10n.preDive_item_valueMin,
```

and the same for max.

- [ ] **Step 5: Persist the picker's choice in `_submit`**

In `_submit`, replace the `isValue` computation and add the source:

```dart
    final isValueLike =
        _itemType == PreDiveItemType.value ||
        _itemType == PreDiveItemType.cellLinearity;
```

Use `isValueLike` in place of `isValue` for `valueLabel`, `valueUnit`, `valueMin` and `valueMax`, and add to the constructed item:

```dart
        sourceItemId: _itemType == PreDiveItemType.cellLinearity
            ? _sourceItemId
            : null,
```

- [ ] **Step 6: Clear dependants on delete**

Find the per-item delete handler (the `IconButton` with `Icons.delete_outline` at `:271`). Replace its `onPressed` body so it clears the link on any dependants and reports it:

```dart
                                onPressed: () {
                                  final removed = _items[index];
                                  final dependants = [
                                    for (final i in _items)
                                      if (i.sourceItemId == removed.id) i,
                                  ];
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final l10n = context.l10n;
                                  setState(() {
                                    _items = [
                                      for (final i in _items)
                                        if (i.id != removed.id)
                                          if (i.sourceItemId == removed.id)
                                            i.copyWith(sourceItemId: null)
                                          else
                                            i,
                                    ];
                                  });
                                  for (final d in dependants) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.preDive_item_sourceCleared(
                                            d.title,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
```

Keep whatever the existing handler did for the plain removal case; the list comprehension above already covers it.

- [ ] **Step 7: Warn on a row that sorts above its source**

In the row builder inside `ReorderableListView`, compute and render the warning:

```dart
                        // A linearity row that sorts above its source only
                        // matters in a strict-order template, where the diver
                        // would reach it first. Warn, do not block.
                        final sourceIndex = item.sourceItemId == null
                            ? -1
                            : _items.indexWhere(
                                (i) => i.id == item.sourceItemId,
                              );
                        final readsLater =
                            sourceIndex >= 0 && sourceIndex > index;
```

and add to the tile's subtitle:

```dart
                              if (readsLater)
                                Text(
                                  context.l10n.preDive_item_sourceBelow,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                ),
```

Wrap the existing subtitle in a `Column` with `crossAxisAlignment: CrossAxisAlignment.start` if it is not one already.

- [ ] **Step 8: Correct the interim label from Task 2**

If Task 2 left `'Cell linearity'` hard-coded in `_typeLabel`, replace it now:

```dart
      PreDiveItemType.cellLinearity =>
        context.l10n.preDive_item_type_cellLinearity,
```

- [ ] **Step 9: Run and confirm they pass**

```bash
flutter test test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart
```

Expected: all pass.

- [ ] **Step 10: Format and commit**

```bash
dart format .
git add lib/features/pre_dive/presentation/pages/pre_dive_template_edit_page.dart test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart
git commit -m "feat(pre-dive): author cell linearity items in the template editor (#986)"
```

---

## Task 9: Built-in CCR template rows

**Files:**
- Modify: `lib/core/database/database.dart` (`kSeedBuiltInPreDiveTemplateItemsSql` at `:2375`, and `_seedBuiltInPreDiveTemplates` around `:4898-4915`)
- Test: `test/core/database/pre_dive_builtin_seed_test.dart`

**Interfaces:**
- Consumes: Task 3's `source_item_id` column.
- Produces: template item ids `builtin-predive-ccr-cell1-linearity`, `-cell2-`, `-cell3-`; the constant `kRenumberCcrTailItemsSql`.

- [ ] **Step 1: Write the failing test**

Append to `test/core/database/pre_dive_builtin_seed_test.dart`:

```dart
  test('the CCR template seeds three linked cell linearity rows', () async {
    await rows('SELECT 1');
    final linearity = await rows(
      "SELECT id, section, sort_order, source_item_id, value_min, "
      "value_unit, is_required FROM pre_dive_checklist_template_items "
      "WHERE template_id = 'builtin-predive-ccr-build' "
      "AND item_type = 'cellLinearity' ORDER BY sort_order",
    );

    expect(linearity, hasLength(3));
    expect(linearity.map((r) => r['id']).toList(), [
      'builtin-predive-ccr-cell1-linearity',
      'builtin-predive-ccr-cell2-linearity',
      'builtin-predive-ccr-cell3-linearity',
    ]);
    expect(linearity.map((r) => r['source_item_id']).toList(), [
      'builtin-predive-ccr-4',
      'builtin-predive-ccr-5',
      'builtin-predive-ccr-6',
    ]);
    expect(linearity.map((r) => r['sort_order']).toList(), [7, 8, 9]);
    for (final row in linearity) {
      expect(row['section'], 'Cells');
      expect(row['value_min'], 95);
      expect(row['value_unit'], 'mV');
      expect(row['is_required'], 1);
    }
  });

  test('every linearity row sources an existing air row', () async {
    await rows('SELECT 1');
    // Strict order plus a live link: the seed is wrong if either the source
    // is missing or it sorts after its dependant.
    final orphans = await rows(
      "SELECT l.id FROM pre_dive_checklist_template_items l "
      "LEFT JOIN pre_dive_checklist_template_items src "
      "ON src.id = l.source_item_id "
      "WHERE l.item_type = 'cellLinearity' "
      "AND (src.id IS NULL OR src.sort_order >= l.sort_order)",
    );
    expect(orphans, isEmpty);
  });

  test('the CCR tail items are renumbered below the new rows', () async {
    await rows('SELECT 1');
    final tail = await rows(
      "SELECT id, sort_order FROM pre_dive_checklist_template_items "
      "WHERE id IN ('builtin-predive-ccr-7', 'builtin-predive-ccr-8', "
      "'builtin-predive-ccr-9') ORDER BY sort_order",
    );
    expect(tail.map((r) => r['sort_order']).toList(), [10, 11, 12]);
  });

  test('a database seeded before the fix picks up the new rows', () async {
    // The repair path: INSERT OR IGNORE adds the rows, and the companion
    // UPDATE is what moves the pre-existing tail out of their way.
    final db = DatabaseService.instance.database;
    await rows('SELECT 1');
    await db.customStatement(
      "UPDATE pre_dive_checklist_template_items SET sort_order = 7 "
      "WHERE id = 'builtin-predive-ccr-7'",
    );
    await db.customStatement(kRenumberCcrTailItemsSql);

    final tail = await rows(
      "SELECT sort_order FROM pre_dive_checklist_template_items "
      "WHERE id = 'builtin-predive-ccr-7'",
    );
    expect(tail.single['sort_order'], 10);
  });
```

- [ ] **Step 2: Run and confirm it fails**

```bash
flutter test test/core/database/pre_dive_builtin_seed_test.dart
```

Expected: FAIL, zero linearity rows found.

- [ ] **Step 3: Add the seed rows**

In `kSeedBuiltInPreDiveTemplateItemsSql`, after the `builtin-predive-ccr-6` row and before `builtin-predive-ccr-7`, extend the column list to include `source_item_id`. The existing `VALUES` tuples must all gain a `NULL` in the new position. Add the column after `equipment_id`'s position in the insert list; if `equipment_id` is not in the list, append `source_item_id` last before `created_at, updated_at` and add `NULL` to every existing tuple in the same position.

The three new tuples:

```sql
    ('builtin-predive-ccr-cell1-linearity', 'builtin-predive-ccr-build',
     'Cells', 'Cell 1 mV in O2', '', 7, 'cellLinearity',
     'Cell 1', 'mV', 95.0, NULL, 1, 'builtin-predive-ccr-4', 0, 0),
    ('builtin-predive-ccr-cell2-linearity', 'builtin-predive-ccr-build',
     'Cells', 'Cell 2 mV in O2', '', 8, 'cellLinearity',
     'Cell 2', 'mV', 95.0, NULL, 1, 'builtin-predive-ccr-5', 0, 0),
    ('builtin-predive-ccr-cell3-linearity', 'builtin-predive-ccr-build',
     'Cells', 'Cell 3 mV in O2', '', 9, 'cellLinearity',
     'Cell 3', 'mV', 95.0, NULL, 1, 'builtin-predive-ccr-6', 0, 0),
```

Adjust the tuple shape to match the column list you settled on. Every tuple in the statement must have the same arity.

- [ ] **Step 4: Add the renumbering statement**

Beside `kRetireLegacyGueEdgeItemsSql`, add:

```dart
/// Pushes the CCR build template's Gas, Pre-breathe and Bailout items from
/// sort_order 7, 8, 9 down to 10, 11, 12, making room for the three cell
/// linearity rows seeded at 7, 8, 9 (issue #986).
///
/// Needed because [kSeedBuiltInPreDiveTemplateItemsSql] uses INSERT OR
/// IGNORE, which can add the new rows but can never renumber the ones a
/// previously seeded database already holds. Same repair technique as
/// [kRetireLegacyGueEdgeItemsSql].
///
/// Idempotent: it assigns fixed values keyed by id, so re-running it is a
/// no-op. Safe to run on every open, and unconditionally, because built-in
/// items are read-only in the UI, excluded from sync export, and session
/// items are independent snapshots with no foreign key to template items.
///
/// The order matters: this template is seeded with strict_order = 1, so a
/// linearity row that sorted above its air row would be unreachable until
/// the diver answered an item that comes after it.
const String kRenumberCcrTailItemsSql = '''
  UPDATE pre_dive_checklist_template_items
  SET sort_order = CASE id
        WHEN 'builtin-predive-ccr-7' THEN 10
        WHEN 'builtin-predive-ccr-8' THEN 11
        WHEN 'builtin-predive-ccr-9' THEN 12
      END
  WHERE id IN ('builtin-predive-ccr-7', 'builtin-predive-ccr-8',
               'builtin-predive-ccr-9')
''';
```

- [ ] **Step 5: Run it beside the seed**

In `_seedBuiltInPreDiveTemplates` (around `:4912`), after the existing seed and retire statements:

```dart
    await customStatement(kRenumberCcrTailItemsSql);
```

Order matters only in that the renumber must not run before the template exists; placing it after the item seed satisfies that.

- [ ] **Step 6: Run and confirm it passes**

```bash
flutter test test/core/database/pre_dive_builtin_seed_test.dart
```

Expected: all pass. Import `kRenumberCcrTailItemsSql` in the test if the analyzer asks.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/core/database/database.dart test/core/database/pre_dive_builtin_seed_test.dart
git commit -m "feat(pre-dive): seed cell linearity rows into the built-in CCR template (#986)"
```

---

## Task 10: Excel export columns

**Files:**
- Modify: `lib/core/services/export/excel/pre_dive_excel_export_service.dart:154-188`
- Test: `test/core/services/export/excel/pre_dive_excel_export_service_test.dart`

**Interfaces:**
- Consumes: Task 2's getters.
- Produces: two new columns in the items sheet, "Air Value" and "Linearity %", inserted after "Unit".

- [ ] **Step 1: Write the failing test**

Append to `test/core/services/export/excel/pre_dive_excel_export_service_test.dart`, following the file's existing export helper:

```dart
  test('a linearity item exports its air reading and percentage', () async {
    final sheet = await exportItemsSheet([
      sessionItem(
        id: 'o2-1',
        title: 'Cell 1 mV in O2',
        type: PreDiveItemType.cellLinearity,
        state: PreDiveItemState.done,
        valueNumber: 48.0,
        valueUnit: 'mV',
        sourceValueNumber: 10.1,
      ),
    ]);

    expect(sheet.headerRow, containsAllInOrder(['Unit', 'Air Value', 'Linearity %']));
    final row = sheet.rowFor('Cell 1 mV in O2');
    expect(row['Type'], 'Cell linearity');
    expect(row['Value'], 48.0);
    expect(row['Air Value'], 10.1);
    expect(row['Linearity %'], 99);
  });

  test('a plain value item leaves the two new columns empty', () async {
    final sheet = await exportItemsSheet([
      sessionItem(
        id: 'air1',
        title: 'Cell 1 mV in air',
        type: PreDiveItemType.value,
        state: PreDiveItemState.done,
        valueNumber: 10.1,
        valueUnit: 'mV',
      ),
    ]);

    final row = sheet.rowFor('Cell 1 mV in air');
    expect(row['Air Value'], '');
    expect(row['Linearity %'], '');
  });
```

Adapt `exportItemsSheet`, `sessionItem`, `headerRow` and `rowFor` to whatever this file already defines; if it reads cells positionally, assert positionally instead.

- [ ] **Step 2: Run and confirm it fails**

```bash
flutter test test/core/services/export/excel/pre_dive_excel_export_service_test.dart
```

Expected: FAIL, the header row has no "Air Value".

- [ ] **Step 3: Add the columns**

In the header list at `:155`, after `'Unit',`:

```dart
      'Air Value',
      'Linearity %',
```

In the row list at `:183`, after `item.valueUnit ?? '',`:

```dart
          // Only a cell linearity item populates these. Everything else
          // leaves them blank rather than repeating its own value.
          item.sourceValueNumber ?? '',
          item.linearityPercent?.round() ?? '',
```

- [ ] **Step 4: Run and confirm it passes**

```bash
flutter test test/core/services/export/excel/pre_dive_excel_export_service_test.dart
```

Expected: all pass. Any existing test asserting the header width or a fixed column index will also need updating; fix those in the same commit.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/export/excel/pre_dive_excel_export_service.dart test/core/services/export/excel/pre_dive_excel_export_service_test.dart
git commit -m "feat(pre-dive): export the cell linearity working to Excel (#986)"
```

---

## Task 11: Sync coverage and the full-suite sweep

**Files:**
- Test: `test/core/services/sync/sync_pre_dive_test.dart`
- Modify: whatever the sweep turns up

**Interfaces:**
- Consumes: everything.
- Produces: nothing new.

- [ ] **Step 1: Write the failing sync round-trip test**

Append to `test/core/services/sync/sync_pre_dive_test.dart`, following the file's existing per-record round-trip pattern:

```dart
  test('a cell linearity template item round-trips through sync', () async {
    // The columns ride along on Drift's generated fromJson/toJson, so this
    // guards the generated mapping, not hand-written serializer code.
    await seedTemplateItem(
      id: 'o2-1',
      itemType: 'cellLinearity',
      sourceItemId: 'air1',
    );

    final record = await serializer.fetchRecord(
      entityType: 'preDiveChecklistTemplateItems',
      recordId: 'o2-1',
    );
    expect(record!['source_item_id'] ?? record['sourceItemId'], 'air1');

    await clearTemplateItems();
    await serializer.upsertRecord(
      entityType: 'preDiveChecklistTemplateItems',
      data: record,
    );

    final restored = await fetchTemplateItem('o2-1');
    expect(restored.sourceItemId, 'air1');
    expect(restored.itemType, PreDiveItemType.cellLinearity);
  });

  test('a cell linearity session item round-trips its frozen reading', () async {
    await seedSessionItem(
      id: 'o2-1',
      itemType: 'cellLinearity',
      sourceItemId: 'air1',
      sourceValueNumber: 10.1,
      valueNumber: 48.0,
    );

    final record = await serializer.fetchRecord(
      entityType: 'preDiveSessionItems',
      recordId: 'o2-1',
    );
    await clearSessionItems();
    await serializer.upsertRecord(
      entityType: 'preDiveSessionItems',
      data: record!,
    );

    final restored = await fetchSessionItem('o2-1');
    expect(restored.sourceValueNumber, 10.1);
    expect(restored.linearityPercent!.round(), 99);
  });
```

Adapt the helper names to this file's actual conventions; read the neighbouring tests first.

- [ ] **Step 2: Run and confirm they pass**

```bash
flutter test test/core/services/sync/sync_pre_dive_test.dart
```

These may pass on the first run, because the generated mapping already carries the columns. That is the expected outcome and the test is still worth keeping: it pins the behaviour so a future hand-written serializer branch cannot drop the fields silently. Note in the commit message that this test was green on arrival.

- [ ] **Step 3: Analyze the whole project**

```bash
flutter analyze 2>&1 | tail -30
```

Expected: zero issues. Infos are fatal in this project's CI, so treat any info as a failure. Do not pipe through `grep`; a pipe masks the exit status.

- [ ] **Step 4: Verify the generated l10n is not stale**

```bash
flutter gen-l10n && git status --porcelain lib/l10n/
```

Expected: no modified files. A diff here means the checked-in generated hub is stale and must be committed.

- [ ] **Step 5: Run the full suite**

```bash
flutter test 2>&1 | tail -30
```

Expected: all pass. Do not pipe to `grep`; the exit code would be the grep's. Do not run this concurrently with another local test run.

- [ ] **Step 6: Format the whole project**

```bash
dart format .
git status --porcelain
```

- [ ] **Step 7: Commit any sweep fixes**

```bash
git add test/core/services/sync/sync_pre_dive_test.dart
git commit -m "test(pre-dive): pin cell linearity fields through the sync round trip (#986)"
```

Commit any other files the sweep changed separately, naming them explicitly.

- [ ] **Step 8: Manual smoke check**

Automated tests do not cover the strict-order interaction, which is the one thing a diver hits first. Run the app and confirm:

1. The built-in CCR template opens read-only and shows the three new rows in the Cells section, after the air readings and before Gas.
2. Cloning it produces an editable copy whose linearity rows still name the right air readings in the editor's source picker.
3. Starting a run from the clone gates the linearity rows behind their air rows (strict order).
4. Entering 10.1 in air and 48.0 in O2 shows "Expected 48.3 mV, linearity 99%" live, and the tile then reads "Air 10.1 mV, expected 48.3 mV, linearity 99%".
5. Entering 40.0 instead shows the linearity line in bold amber.
6. Resetting the air row and entering a different value adds the "Air reading has changed since" hint without changing the percentage.
7. Completing the session locks it and the numbers still read the same.

---

## Self-Review

**Spec coverage.** Every section of the spec maps to a task: domain background and the calculator to Task 1; the new item type, entity fields and threshold semantics to Task 2; schema and migration to Task 3; sync to Tasks 3 and 11; recording and freezing to Task 4; the link and its remaps, including degradation, to Task 5; localisation to Task 6; the runner to Task 7; the template editor to Task 8; the built-in CCR template to Task 9; testing to every task plus Task 11.

**One addition the spec did not name.** `pre_dive_excel_export_service.dart` has an exhaustive switch on `PreDiveItemType`, so the new enum value is a compile error there, and the sheet would otherwise export a linearity item with no air reading and no percentage. Task 2 fixes the compile break and Task 10 adds the columns. The spec should be amended to mention the export surface.

**Type consistency.** `sourceItemId` and `sourceValueNumber` are spelled identically in the entities, the Drift columns (`source_item_id`, `source_value_number`), the companions and every test. `CellLinearity.expectedO2Millivolts` and `CellLinearity.percent` keep their signatures from Task 1 through Tasks 2, 7 and 8. `isCellLinearity`, `linearityPercent` and `expectedO2Millivolts` are defined once in Task 2 and only read thereafter.

**Ordering constraint.** Task 6 (localisation) must run before Tasks 2, 7 and 8 can compile against `context.l10n`. Task 2 documents the interim hard-coded fallback if it runs first, and Task 8 Step 8 corrects it. Task 3 must run before Task 4 (the companions do not exist until the Drift code is regenerated). Task 4 must run before Task 5 (the composer's minted ids are only honoured once `startSession` respects them).
