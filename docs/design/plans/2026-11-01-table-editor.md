# Table Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Table editor under Settings, Data Tools, with a Dives, Sites and Centers tab where cells are typed into or pasted from a spreadsheet, kept as drafts, and saved all at once as one undoable change log operation (issue #3422).

**Architecture:** A new feature `lib/features/table_editor/` holds a generic editing core (drafts, parsers, paste planner, save service, sheet widget) and one `TableEditorEntity` descriptor per tab (dives, sites, centers) that names the editable columns, parses cell text in the diver's units and performs the save. The shared `EntityTableView` gains three cell hooks (tap, builder, background) so the sheet is the same table the list views use. Dives save through `BulkDiveEditService` (which gains a per-dive `WeightAmountOp`), sites and centers through their repositories; every Save all runs inside one `ChangeLogScope.bulk` and one outer `db.transaction`, with inner transactions nesting as savepoints.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`, `FutureProvider`), Drift 2.34 on SQLite, the in-house query engine under `lib/core/query/`, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-11-01-table-editor-design.md` (read its "Amendments recorded while planning" section; it is authoritative where the body differs).

## Global Constraints

- Never write the em-dash character (U+2014), and no en-dash as prose punctuation, in code, comments, tests, ARB values, commit messages or docs.
- Nothing written to the repo or GitHub mentions Claude, Claude Code or Anthropic; no co-author trailers.
- TDD: each task writes its failing test first and runs it red before the implementation.
- Every value shown or parsed respects the active diver's unit settings: `UnitFormatter` for display and conversion, `parseUserDecimal` / `parseUserInt` from `lib/core/utils/number_input.dart` for text (never `double.parse`). `test/architecture/number_parsing_single_source_test.dart` enforces the latter.
- New user-facing strings go into `app_en.arb` AND all ten locale ARBs (ar, de, es, fr, he, hu, it, nl, pt, zh) with real translations (`test/l10n/untranslated_english_values_test.dart` fails on English copied into another locale), then `flutter gen-l10n` runs in the same task, so every task compiles. CI fails if the generated `app_localizations*.dart` drift from the ARBs.
- A shared widget (`lib/shared/widgets/entity_table/`) must not call `context.l10n` during `build`; labels are resolved by the caller and passed in.
- Every `SnackBar(` with an `action:` states `persist:` (`test/architecture/snack_bar_action_times_out_test.dart`); an Undo uses `persist: false` and `duration: const Duration(seconds: 5)`.
- Tests that change process-wide state restore it; `DatabaseService.instance` is set and reset through `setUpTestDatabase()` / `tearDownTestDatabase()` from `test/helpers/test_database.dart`.
- Paths built with `p.join`, never string concatenation (none expected here).
- Files stay under 800 lines; `dive_repository_impl.dart` already exceeds it, so the two new repository methods there are the only additions to it.
- Before committing each task: `dart format` on the touched files and `flutter analyze` clean.
- Run `test/architecture/` and `test/shared/` after any task that adds a file under `lib/`.
- Weights, depths and visibility are stored metric; the editor converts at the cell boundary only.

## Review Focus

1. A diver whose locale uses a decimal comma types `6,5` into Weight: the draft is 6.5 in the diver's weight unit, stored as kg, never 65. Pinned in Task 5 (`decimal comma weight` test).
2. A headerless single column of integers is pasted onto a sheet whose dives are numbered 1 to 20: the values fill by position from the selected cell and are never read as dive numbers. Pinned in Task 7 (`single integer column is positional` test).
3. A sync changes a dive between drafting and Save all: that draft is left out as changed elsewhere, the other drafts save, and the change log shows exactly one operation for the save. Pinned in Task 8 (`stale draft is skipped` and `one operation` tests).
4. An exception in the 40th of 100 dive writes: no dive is changed, the drafts stay, and the error surfaces. Pinned in Task 8 (`all or nothing` test).
5. A library site the profile may not edit receives a pasted name: the cell is reported as read-only and the site keeps its name, while a pasted note on the same site saves. Pinned in Task 6 (`library site` tests) and Task 7 (`read-only cells are skipped` test).

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (modify) | `getWeightsForDives`, `setSingleWeightAmount` (public wrappers over `_weightsForDives`, `_writeWeightDiff`) |
| `lib/features/dive_log/domain/entities/bulk_edit_request.dart` (modify) | `WeightAmountOp` |
| `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` (modify) | `WeightAmountOp` branch of `_applyOp` |
| `lib/core/constants/dive_field.dart`, `dive_field_labels.dart`, `dive_field_extractor.dart`, `dive_field_formatter.dart` (modify) | five new `DiveField` members |
| `lib/features/dive_log/query/dive_column_filters.dart` (modify) | the new members in the filter map or the unfilterable set |
| `lib/shared/widgets/entity_table/entity_table_view.dart` (modify) | `onCellTap`, `cellBuilder`, `cellBackground` hooks |
| `lib/features/table_editor/domain/table_draft.dart` (create) | `TableDraft`, `TableDraftFlag`, `CellPosition` |
| `lib/features/table_editor/domain/table_draft_state.dart` (create) | `TableDraftState`, `TableDraftsNotifier` |
| `lib/features/table_editor/domain/cell_parsers.dart` (create) | pure parsers: number, integer, choice, multi-choice, toggle, degrees |
| `lib/features/table_editor/domain/table_editor_column.dart` (create) | `TableEditorColumn`, `CellEditorKind`, `ChoiceOption`, `CellParseResult` |
| `lib/features/table_editor/domain/table_editor_entity.dart` (create) | `TableEditorEntity<T, F>` interface |
| `lib/features/table_editor/domain/paste_parser.dart` (create) | `parsePasteText`, `PasteBlock` |
| `lib/features/table_editor/domain/paste_planner.dart` (create) | `planPaste`, `PastePlan`, `PasteMatching`, `PasteSkip`, `SheetRow` |
| `lib/features/table_editor/domain/save_summary.dart` (create) | `SaveSummary.from` |
| `lib/features/table_editor/domain/cell_navigation.dart` (create) | `CellMove`, `nextCell` |
| `lib/features/table_editor/entities/dive_table_editor_entity.dart` (create) | dive columns, parse, reload, save via `BulkDiveEditService` |
| `lib/features/table_editor/entities/dive_table_editor_columns.dart` (create) | the column list for dives (kept apart for size) |
| `lib/features/table_editor/entities/site_table_editor_entity.dart` (create) | site columns, coordinate pair rule, library rule, save |
| `lib/features/table_editor/entities/center_table_editor_entity.dart` (create) | center columns, save |
| `lib/features/dive_centers/domain/entities/dive_center.dart` (modify) | `copyWith(clearLatitude:, clearLongitude:)` |
| `lib/features/table_editor/data/table_editor_save_service.dart` (create) | stale check, scope, outer transaction, operation id |
| `lib/core/services/change_log/change_log_scope.dart` (modify, `ChangeLogLabels` at line 39) | `ChangeLogLabels.tableEditor` |
| `lib/features/table_editor/presentation/providers/table_editor_providers.dart` (create) | tab enum, per-tab config, drafts, filter and row providers |
| `lib/features/dive_log/presentation/table/dive_table_menus.dart` (modify) | `filterProvider` parameter |
| `lib/features/query/presentation/table/entity_column_menus.dart` (create) | generic header and cell filter menus for sites and centers |
| `lib/core/query/presentation/column_rules.dart` (create) | `addColumnRule`, `resetColumnRules`, `isColumnFiltered` over a `QueryNode?` |
| `lib/features/table_editor/presentation/widgets/editable_cell.dart` (create) | in-place text, choice and toggle editors |
| `lib/features/table_editor/presentation/widgets/table_editor_sheet.dart` (create) | `TableEditorSheet<T, F>` over `EntityTableView` |
| `lib/features/table_editor/presentation/widgets/save_summary_dialog.dart` (create) | the summary before saving |
| `lib/features/table_editor/presentation/pages/table_editor_page.dart` (create) | tabs, toolbar, guard, width gate, Undo snackbar |
| `lib/features/table_editor/presentation/table_editor_paste.dart` (create) | clipboard read and paste-to-drafts flow |
| `lib/features/settings/presentation/pages/data_tools_page.dart` (modify) | fifth row |
| `lib/core/router/app_router.dart` (modify) | `table-editor` child route under `/settings` |
| `lib/l10n/arb/app_*.arb` (modify) | new keys, listed per task |

---

### Task 1: Weights: batch read and a per-dive amount op

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (next to `_weightsForDives` at ~5668 and `_writeWeightDiff` at ~7633)
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_request.dart` (after `WeightsOp`, ~128)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` (`_applyOp`, ~386)
- Test: `test/features/dive_log/data/services/bulk_dive_edit_weight_amount_test.dart`

**Interfaces:**
- Produces: `Future<Map<String, List<domain.DiveWeight>>> getWeightsForDives(List<String> diveIds)` on `DiveRepository` (a dive with no rows has no entry).
- Produces: `Future<void> setSingleWeightAmount(String diveId, double? amountKg, {required WeightType newRowType})` on `DiveRepository`: 0 rows and an amount inserts one row of `newRowType`; 1 row and an amount updates that row in place (same id); 1 row and null deletes it through the diff (tombstoned); 2 or more rows throws `StateError`. No transaction, no notify (same contract as `bulkAddWeights`).
- Produces: `class WeightAmountOp extends BulkCollectionOp { final double? amountKg; final WeightType newRowType; const WeightAmountOp({required this.amountKg, this.newRowType = WeightType.belt}); }`. Applied per dive in `ids`; the snapshot's `priorWeights` already captures prior rows, so `undo` needs no change.

- [ ] **Step 1: Write the failing tests**

Model the file on `bulk_dive_edit_service_test.dart` (its `setUp`, `seed`, `weight` and `weightsOf` helpers).

```dart
test('getWeightsForDives groups rows by dive and omits dives without', ...);
  // seed d1 with weights 3 and 4, d2 with none; expect {d1: [3, 4]} and no d2 key
test('WeightAmountOp inserts one row of the given type on a dive with none', ...);
  // apply WeightAmountOp(amountKg: 6, newRowType: WeightType.integrated) on d1
  // expect one row, amountKg 6, weightType 'integrated'
test('WeightAmountOp updates the single row in place and keeps its id', ...);
  // seed one row, read its id, apply amountKg 8, expect same id, amount 8
test('WeightAmountOp with null deletes the single row', ...);
  // expect weightsOf(d1) empty and a tombstone for diveWeights (read the deletion log the way bulk_dive_edit_service_test checks tombstones)
test('WeightAmountOp throws on a dive with two rows and changes nothing', ...);
  // expectLater(apply, throwsStateError); weightsOf(d1) still [3, 4]
test('undo after WeightAmountOp restores the prior rows', ...);
```

- [ ] **Step 2: Run them red**

Run: `flutter test test/features/dive_log/data/services/bulk_dive_edit_weight_amount_test.dart`
Expected: compile errors on `getWeightsForDives`, `WeightAmountOp`.

- [ ] **Step 3: Implement**

`getWeightsForDives` returns `_weightsForDives(diveIds)`. `setSingleWeightAmount` loads the dive's rows, builds `desired` (the one row with `amountKg` replaced, an empty list for null, or a new `DiveWeight(id: '', diveId:, weightType: newRowType, amountKg:)` when there were none) and calls `_writeWeightDiff(diveId, desired, now)`. In `_applyOp` add `case WeightAmountOp(:final amountKg, :final newRowType): for (final id in ids) { await _diveRepo.setSingleWeightAmount(id, amountKg, newRowType: newRowType); }`. Capture prior weights for the op the way the `WeightsOp` branch does (the existing `priorWeights` read at ~124 keys on op type; extend its condition).

- [ ] **Step 4: Run green**

Run: `flutter test test/features/dive_log/data/services/` (the whole folder, so the existing weight undo tests still pass)
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/domain/entities/bulk_edit_request.dart lib/features/dive_log/data/services/bulk_dive_edit_service.dart test/features/dive_log/data/services/bulk_dive_edit_weight_amount_test.dart
git commit -m "feat(dive-log): set one dive's single weight amount in place"
```

---

### Task 2: Five new `DiveField` members

**Files:**
- Modify: `lib/core/constants/dive_field.dart` (append after `surfaceInterval`), `dive_field_labels.dart`, `dive_field_extractor.dart` (`extractFromDive` and `extractFromSummary`), `dive_field_formatter.dart`
- Modify: `lib/features/dive_log/query/dive_column_filters.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/core/constants/dive_field_new_members_test.dart`

**Interfaces:**
- Produces: `DiveField.excludedFromStats`, `DiveField.excludedFromGasStats`, `DiveField.windDirection`, `DiveField.scrubberType`, `DiveField.scrubberDuration`, appended in that order (saved layouts store members by name, so order only matters for stability). Categories: the two exclusions join whatever category `isFavorite` is in; `windDirection` joins `windSpeed`'s; the scrubber pair joins `setpointLow`'s. `extractFromDive` returns `bool`, `bool`, `String?` (the stored direction), `String?`, `int?` (minutes). `extractFromSummary` returns null for all five. Formatter: bools through the existing yes/no formatting used by `isFavorite`, duration as whole minutes with the existing minutes formatting, strings as is.
- ARB keys (follow the key names `dive_field_labels.dart` uses for its neighbours, one long and one short label each): "Excluded from stats" / "No stats", "Excluded from gas stats" / "No gas stats", "Wind direction" / "Wind dir", "Scrubber type" / "Scrubber", "Scrubber duration" / "Scrubber min".
- Filter map: `windDirection` and `scrubberType` map to their query keys if `diveQueryEntity` has them (check `dive_query_entity.dart`); otherwise all five go into `kUnfilterableDiveColumns`.

- [ ] **Step 1: Write the failing test**

```dart
test('the five new members extract their stored values', () {
  final dive = Dive(..., excludedFromStats: true, excludedFromGasStats: false,
      windDirection: 'NE', scrubberType: 'ExtendAir', scrubberDurationMinutes: 180);
  expect(DiveField.excludedFromStats.extractFromDive(dive), isTrue);
  expect(DiveField.windDirection.extractFromDive(dive), 'NE');
  expect(DiveField.scrubberDuration.extractFromDive(dive), 180);
});
test('every new member has a label, a width and a category', () {
  for (final f in [DiveField.excludedFromStats, ..., DiveField.scrubberDuration]) {
    expect(f.localizedDisplayName(en), isNotEmpty);
    expect(f.defaultWidth, greaterThan(0));
  }
});
```

Use the real `Dive` field names (check `dive.dart` for the scrubber duration and wind direction field names and types; the companion field names are in `BulkScalarInputs`).

- [ ] **Step 2: Run red**

Run: `flutter test test/core/constants/dive_field_new_members_test.dart`
Expected: FAIL, undefined members.

- [ ] **Step 3: Implement**

Append the members and extend every `switch` over `DiveField` that the analyzer flags as non-exhaustive (labels, extractor, formatter, sizing, category). Add the ARB keys to all eleven files and run `flutter gen-l10n`.

- [ ] **Step 4: Run green**

Run: `flutter test test/core/constants/ test/features/dive_log/query/dive_column_filters_census_test.dart test/features/dive_log/presentation/widgets/dive_table_view_sort_test.dart test/l10n/`
Expected: PASS (the census test is the one that fails until step 3 places the members).

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/ lib/features/dive_log/query/dive_column_filters.dart lib/l10n/ test/core/constants/dive_field_new_members_test.dart
git commit -m "feat(dive-log): table columns for stats exclusions, wind direction and scrubber"
```

---

### Task 3: Cell hooks on `EntityTableView`

**Files:**
- Modify: `lib/shared/widgets/entity_table/entity_table_view.dart` (constructor 110-133, `_buildCell` ~395)
- Test: `test/shared/widgets/entity_table/entity_table_cell_hooks_test.dart`

**Interfaces:**
- Produces three optional constructor parameters:
  - `final void Function(T entity, F field)? onCellTap;` A tap on a cell calls it instead of `onEntityTap` when set and `isSelectionMode` is false. `onEntityDoubleTap` is unchanged.
  - `final Widget? Function(BuildContext context, T entity, F field, String formatted)? cellBuilder;` When it returns non-null, that widget fills the cell's box (same width and height, no padding added by the table) in place of the `Text`.
  - `final Color? Function(T entity, F field)? cellBackground;` A non-null colour paints the cell's own `ColoredBox` above the row background.

- [ ] **Step 1: Write the failing tests**

Reuse the fixture pattern from `test/features/dive_sites/presentation/widgets/site_list_content_table_test.dart` but pump a bare `EntityTableView<_Row, _Field>` with a two-member test `EntityField` enum and adapter, inside `testApp`.

```dart
testWidgets('onCellTap receives the tapped entity and field', ...);  // tap the second cell of row one, expect ('r1', _Field.b) and onEntityTap not called
testWidgets('cellBuilder replaces the text of the cell it returns a widget for', ...);  // builder returns Key('edit') for (r1, b): find.byKey(Key('edit')) findsOneWidget, find.text('b1') findsNothing
testWidgets('cellBackground paints a ColoredBox with the colour', ...);  // tester.widget<ColoredBox>(find.descendant(of: cell, matching: find.byType(ColoredBox))).color == Colors.amber
testWidgets('without the hooks a cell tap still calls onEntityTap', ...);
```

- [ ] **Step 2: Run red**

Run: `flutter test test/shared/widgets/entity_table/entity_table_cell_hooks_test.dart`
Expected: FAIL, undefined named parameters.

- [ ] **Step 3: Implement**

In `_buildCell`, compute `formatted` as today, ask `cellBuilder` first, wrap in `ColoredBox` when `cellBackground` returns a colour, and attach a `GestureDetector(onTap: () => onCellTap!(entity, field), behavior: HitTestBehavior.opaque)` when `onCellTap != null && !widget.isSelectionMode`. Keep the existing menu `GestureDetector` (right-click and long press) as the outer one. Both row `ListView`s go through `_buildCell`, so no other change.

- [ ] **Step 4: Run green**

Run: `flutter test test/shared/ test/features/dive_sites/presentation/widgets/site_list_content_table_test.dart test/features/dive_log/presentation/widgets/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/entity_table/entity_table_view.dart test/shared/widgets/entity_table/entity_table_cell_hooks_test.dart
git commit -m "feat(shared): cell tap, builder and background hooks on EntityTableView"
```

---

### Task 4: Drafts

**Files:**
- Create: `lib/features/table_editor/domain/table_draft.dart`, `lib/features/table_editor/domain/table_draft_state.dart`
- Test: `test/features/table_editor/domain/table_draft_state_test.dart`

**Interfaces:**
- Produces:

```dart
enum TableDraftFlag { unparsable, unknownValue, pairIncomplete, changedElsewhere }

@immutable
class CellPosition { final String entityId; final String fieldName; const CellPosition(this.entityId, this.fieldName); }  // Equatable

@immutable
class TableDraft {
  final String entityId;
  final String fieldName;      // EntityField.name
  final Object? original;      // stored value when drafted (metric, enum name, id)
  final Object? value;         // stored value to write; null clears
  final String? rawText;       // the typed or pasted text, kept for flagged cells
  final TableDraftFlag? flag;
  const TableDraft({required this.entityId, required this.fieldName, required this.original, required this.value, this.rawText, this.flag});
  bool get isSaveable => flag == null;
  bool get overwrites => original != null && original != '' && original != const <Object>[];
  TableDraft copyWith({Object? value, String? rawText, TableDraftFlag? flag, bool clearFlag = false, Object? original});
}

@immutable
class TableDraftState {
  final Map<String, Map<String, TableDraft>> byEntity;   // entityId -> fieldName -> draft
  final CellPosition? editing;
  final CellPosition? selected;
  int get count; int get flaggedCount; bool get isEmpty;
  List<TableDraft> get all; List<TableDraft> get saveable;
  TableDraft? at(String entityId, String fieldName);
  List<TableDraft> forEntity(String entityId);
}

class TableDraftsNotifier extends StateNotifier<TableDraftState> {
  void put(TableDraft draft);          // drops the draft when value == original and flag == null
  void putAll(Iterable<TableDraft> drafts);
  void remove(String entityId, String fieldName);
  void clear();
  void flag(String entityId, String fieldName, TableDraftFlag flag);
  void rebase(String entityId, String fieldName, Object? newOriginal);  // after a stale skip: keeps value, sets original, clears the changedElsewhere flag
  void setEditing(CellPosition? cell);
  void setSelected(CellPosition? cell);
}
```

Value equality for `put` uses `const DeepCollectionEquality().equals` so list values (multi-choice) compare by content.

- [ ] **Step 1: Write the failing tests**

```dart
test('put stores a draft and count follows', ...);
test('put with value equal to original removes any existing draft', ...);
test('put keeps a flagged draft even when value equals original', ...);
test('overwrites is false for null, empty string and empty list originals', ...);
test('rebase keeps the value, replaces original and clears changedElsewhere', ...);
test('saveable excludes flagged drafts', ...);
test('list values compare by content', ...);  // ['a','b'] == ['a','b'] drops the draft
```

- [ ] **Step 2: Run red** (`flutter test test/features/table_editor/domain/table_draft_state_test.dart`, FAIL on missing files)

- [ ] **Step 3: Implement** the two files. Immutable updates only (copy the maps).

- [ ] **Step 4: Run green**

- [ ] **Step 5: Commit**

```bash
git add lib/features/table_editor/domain/table_draft.dart lib/features/table_editor/domain/table_draft_state.dart test/features/table_editor/domain/table_draft_state_test.dart
git commit -m "feat(table-editor): drafts and their notifier"
```

---

### Task 5: Columns, parsers and the dive descriptor

**Files:**
- Create: `lib/features/table_editor/domain/cell_parsers.dart`, `table_editor_column.dart`, `table_editor_entity.dart`
- Create: `lib/features/table_editor/entities/dive_table_editor_columns.dart`, `dive_table_editor_entity.dart`
- Test: `test/features/table_editor/domain/cell_parsers_test.dart`, `test/features/table_editor/entities/dive_table_editor_entity_test.dart`

**Interfaces:**
- Produces in `table_editor_column.dart`:

```dart
enum CellEditorKind { text, number, integer, choice, multiChoice, toggle, reference }

@immutable
class ChoiceOption { final String value; final String label; const ChoiceOption(this.value, this.label); }

sealed class CellParseResult { const CellParseResult(); }
class CellParsed extends CellParseResult { final Object? value; const CellParsed(this.value); }
class CellRejected extends CellParseResult { final TableDraftFlag flag; const CellRejected(this.flag); }

@immutable
class TableEditorColumn<T, F extends EntityField> {
  final F field;
  final CellEditorKind kind;
  final Object? Function(T entity) valueOf;                       // stored value
  final String Function(T entity, UnitFormatter units) editText;  // text when the cell opens
  final CellParseResult Function(String text, UnitFormatter units, AppLocalizations l10n) parse;
  final List<ChoiceOption> Function(AppLocalizations l10n) choices;   // const [] for non-choice kinds
  final bool Function(T entity) isEditable;                      // default: always
  final String? Function(UnitFormatter units) unitSymbol;        // null for non-number kinds
  final String? Function(T entity, AppLocalizations l10n) readOnlyReason;  // tooltip when !isEditable
}
```

- Produces in `cell_parsers.dart` (pure, no Flutter imports beyond l10n):

```dart
CellParseResult parseTextCell(String text);                       // CellParsed(trimmed), empty -> CellParsed(null)
CellParseResult parseNumberCell(String text, {required double Function(double) toStored, double? min, double? max});  // parseUserDecimal; empty -> null; unparsable or out of range -> CellRejected(unparsable)
CellParseResult parseIntegerCell(String text, {int? min, int? max});   // parseUserInt
CellParseResult parseChoiceCell(String text, List<ChoiceOption> options);   // case-insensitive label or value match; empty -> null; else CellRejected(unknownValue)
CellParseResult parseMultiChoiceCell(String text, List<ChoiceOption> options);  // split on , or ; then parseChoiceCell each; one unknown rejects the cell; value is List<String>
CellParseResult parseToggleCell(String text, AppLocalizations l10n);   // yes/no/true/false/1/0 and l10n yes/no, case-insensitive; empty -> CellParsed(false)
CellParseResult parseDegreesCell(String text, {required double limit});   // parseUserDecimal within +-limit (90 or 180)
```

- Produces in `table_editor_entity.dart`:

```dart
abstract class TableEditorEntity<T, F extends EntityField> {
  EntityFieldAdapter<T, F> get adapter;
  F fieldFromName(String name);
  List<TableEditorColumn<T, F>> get columns;
  TableEditorColumn<T, F>? columnFor(F field);
  String idOf(T entity);
  int? numberOf(T entity);          // dives; null elsewhere
  String? nameOf(T entity);         // sites and centers; null for dives
  /// Adds or adjusts drafts that depend on each other (coordinate pairs). Default returns the input.
  List<TableDraft> reconcile(T entity, List<TableDraft> drafts) => drafts;
  /// Fresh rows for the stale check, by id.
  Future<List<T>> reload(List<String> ids);
  /// Writes the saveable drafts. Called inside the change log scope and the outer transaction.
  Future<void> save(Map<String, List<TableDraft>> draftsByEntity, Map<String, T> fresh);
  /// Extra lines for the save summary (site snapping, pair clearing). Default none.
  List<String> summaryNotes(List<TableDraft> drafts, AppLocalizations l10n) => const [];
}
```

- Produces `DiveTableEditorEntity(DiveRepository diveRepo, BulkDiveEditService bulk, {required Map<String, List<DiveWeight>> weightsByDive, required String Function(String) diveTypeLabel, required GasModel gasModel})` implementing `TableEditorEntity<Dive, DiveField>`. Columns (`dive_table_editor_columns.dart`, `List<TableEditorColumn<Dive, DiveField>> diveEditorColumns(...)`): one per `BulkField` scalar that has a `DiveField`, kind by type: `rating` integer 0 to 5; the booleans toggle; `waterType`, `visibility` band if the column is an enum in `Dive`, `currentDirection`, `currentStrength`, `surfaceConditions`, `entryMethod`, `exitMethod`, `decoAlgorithm`, `cloudCover`, `precipitation`, `diveMode`, `scrubberType`, `windDirection` choice from the matching enum's values (label from the enum's localized name helper used by the dive edit page); `site`, `diveCenter`, `trip`, `diveComputerModel` reference with choices from `allSitesProvider`-style lists passed in; `visibility` (metres), `swellHeight`, `altitude`, `windSpeed` number through the `UnitFormatter` conversion each uses in the dive edit form; `surfacePressure`, `humidity`, setpoints, `diluentO2/He` number; `surfaceInterval`, `gradientFactorLow/High`, `decoConservatism`, `scrubberDuration` integer; `notes`, `diveOperator`, `boatName`, `boatCaptain`, `weatherDescription` text; `totalWeight` number with `toStored: units.weightToKg`, `isEditable: weightsByDive[id]?.length ?? 0) <= 1`, `readOnlyReason` the "{count} weight rows" string. Computer-measured fields have no column.
- `save`: per dive, build `BulkScalarInputs` from the drafts (stored values), `enabled` = the drafted `BulkField`s, `BulkEditRequest(diveIds: [id], scalars: buildScalarCompanion(enabled, inputs), ops: [if site drafted SiteOp(siteId: value), if weight drafted WeightAmountOp(amountKg: value, newRowType: newRowTypeFor(id))])`, then `await bulk.apply(req)`. `newRowTypeFor`: the type of the most recent weight row among `weightsByDive`, else `WeightType.belt`. `reload` = `diveRepo.getDivesByIdsWithoutSamples(ids)`. `summaryNotes` returns the site-snapping line (`tableEditor_summary_siteSnap`, Task 11) when any draft is on the `site` column.

- [ ] **Step 1: Write the failing tests**

`cell_parsers_test.dart`:
```dart
test('decimal comma weight parses to kg for a metric diver', () {  // Review Focus 1
  // with a de_DE locale number format active (see number_input tests for the harness), parseNumberCell('6,5', toStored: (v) => v) == CellParsed(6.5)
});
test('imperial weight converts to kg', ...);  // units with lbs: parseNumberCell('13', toStored: units.weightToKg) ~ 5.897 kg
test('unparsable number is rejected as unparsable', ...);
test('choice matches label case-insensitively and rejects unknown', ...);
test('multi choice splits on comma or semicolon and rejects one unknown', ...);
test('toggle accepts localized yes and no', ...);
test('degrees outside the limit are rejected', ...);
```
`dive_table_editor_entity_test.dart` (database-backed, as in Task 1):
```dart
test('weight column is read-only on a dive with two rows', ...);
test('save writes one dive\'s visibility and weight and leaves the other dive alone', ...);
test('save sets a site through SiteOp so the water type snaps', ...);
test('new weight row takes the latest logged type, belt when none', ...);
test('reload returns fresh rows with weights filled', ...);
```

- [ ] **Step 2: Run red**

- [ ] **Step 3: Implement** the five files. Keep `dive_table_editor_columns.dart` under 400 lines by grouping columns with small local helpers (`_number`, `_choice`, `_text`).

- [ ] **Step 4: Run green**

Run: `flutter test test/features/table_editor/ test/architecture/number_parsing_single_source_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/features/table_editor/ test/features/table_editor/
git commit -m "feat(table-editor): editable columns, cell parsers and the dive descriptor"
```

---

### Task 6: Site and center descriptors

**Files:**
- Create: `lib/features/table_editor/entities/site_table_editor_entity.dart`, `center_table_editor_entity.dart`
- Modify: `lib/features/dive_centers/domain/entities/dive_center.dart` (`copyWith`)
- Test: `test/features/table_editor/entities/site_table_editor_entity_test.dart`, `center_table_editor_entity_test.dart`, `test/features/dive_centers/domain/entities/dive_center_copy_with_test.dart`

**Interfaces:**
- Produces `SiteTableEditorEntity(SiteRepository repo, {required Future<bool> Function(String siteId) mayEdit, required String? actingDiverId})` over `SiteWithCount` and `SiteField`. Editable columns per the spec's site list; `isEditable` returns true for `notes` and `rating` always, and for every other column only when `!site.isLibrarySite || mayEditResolved[id]` (the entity takes the resolved map `Map<String, bool> editableLibrarySites` instead of a future, so `isEditable` stays synchronous; the provider in Task 9 resolves it). `readOnlyReason` returns the library string. `reconcile`: given a site's drafts, if exactly one of `latitude`/`longitude` is drafted and the site has no coordinates, flag it `pairIncomplete`; if one half is drafted null (cleared) on a site with coordinates, add a draft clearing the other half. `save` builds `site.copyWith(...)` with `location: GeoPoint(lat, lon)` or null, and calls `repo.updateSite(site, actingDiverId: actingDiverId)`. `summaryNotes` adds the pair-clearing line when any coordinate draft is null.
- Produces `CenterTableEditorEntity(DiveCenterRepository repo)` over `DiveCenterRow` and `DiveCenterField`: name, street, city, stateProvince, postalCode, country, phone, email, website text; latitude, longitude degrees; rating integer 0 to 5; notes text. `save` builds the center with `copyWith` and calls `repo.updateDiveCenter`.
- Produces `DiveCenter.copyWith({..., bool clearLatitude = false, bool clearLongitude = false})`.

- [ ] **Step 1: Write the failing tests**

```dart
// site
test('library site the profile may not edit: only notes and rating are editable', ...);  // Review Focus 5
test('one half drafted on a site without coordinates is flagged pairIncomplete', ...);
test('clearing one half on a site with coordinates adds a draft clearing the other', ...);
test('save writes name and coordinates and keeps dive links', ...);
// center
test('save clears a coordinate when the draft is null', ...);
test('save writes name, phone and rating', ...);
// copyWith
test('clearLatitude sets latitude to null', ...);
```

- [ ] **Step 2: Run red**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run green** (`flutter test test/features/table_editor/ test/features/dive_centers/`)

- [ ] **Step 5: Commit**

```bash
git add lib/features/table_editor/entities/ lib/features/dive_centers/domain/entities/dive_center.dart test/features/table_editor/entities/ test/features/dive_centers/domain/
git commit -m "feat(table-editor): site and dive center descriptors"
```

---

### Task 7: Paste parsing and planning

**Files:**
- Create: `lib/features/table_editor/domain/paste_parser.dart`, `paste_planner.dart`
- Test: `test/features/table_editor/domain/paste_parser_test.dart`, `paste_planner_test.dart`

**Interfaces:**
- Produces:

```dart
@immutable
class PasteBlock { final List<List<String>> rows; bool get isSingleValue; int get columnCount; }
PasteBlock parsePasteText(String text);   // split on \r\n or \n, drop one trailing empty line, split each row on \t, do not trim cells beyond \r

enum PasteMatching { byNumber, byName, byPosition }

@immutable
class SheetRow { final String id; final int? number; final String? name; const SheetRow({required this.id, this.number, this.name}); }

enum PasteSkipReason { unknownRow, hiddenRow, readOnlyColumn, unknownColumn, truncated }
@immutable
class PasteSkip { final PasteSkipReason reason; final String detail; final int count; }   // detail: the key or header text; count for truncated

@immutable
class PastePlan<F extends EntityField> {
  final PasteMatching matching;
  final bool hadHeader;
  final List<({String entityId, F field, String text})> cells;
  final List<PasteSkip> skipped;
}

PastePlan<F> planPaste<F extends EntityField>({
  required PasteBlock block,
  required List<SheetRow> rows,            // visible rows in sheet order
  required int selectedRowIndex,
  required List<F> visibleColumns,         // in sheet order
  required int selectedColumnIndex,
  required bool Function(F field) isEditableColumn,
  required F? Function(String header) columnFromLabel,     // case-insensitive label match, null when none
  required bool Function(String header) isKeyHeader,       // the dive number or name column label
  Set<String> hiddenKeys = const {},        // numbers (as text) or names of rows the filter hides
});
```

Rules, in order:
1. Header row: the first row is a header when `isKeyHeader(first cell)` or when every non-empty cell of it maps through `columnFromLabel`. A header cell that maps to nothing produces `PasteSkip(unknownColumn, header)` and that column is dropped.
2. Matching: `byNumber`/`byName` when the header's first cell is the key, or when there is no header, the block has at least two columns, and every first-column value matches a `SheetRow.number` (as text) or `.name` (case-insensitive). Otherwise `byPosition`. A headerless single column is always `byPosition` (Review Focus 2).
3. Key matching: an unmatched key that is in `hiddenKeys` skips as `hiddenRow`, otherwise `unknownRow`.
4. Columns: with a header, the mapped columns; without, the data columns fill rightward from `selectedColumnIndex` over `visibleColumns`, skipping columns where `!isEditableColumn` with one `readOnlyColumn` skip per column.
5. Position: rows fill from `selectedRowIndex`; rows past the end produce one `truncated` skip with the count.
6. `isSingleValue` blocks produce one cell at the selected position (or nothing with a `readOnlyColumn` skip).

- [ ] **Step 1: Write the failing tests**

```dart
test('parsePasteText splits rows and tabs and drops the trailing newline', ...);
test('single integer column is positional', ...);   // Review Focus 2: rows numbered 1..20, block [['6'],['8'],['7']], matching byPosition, cells land on selected row and the two below
test('two columns with every first value a dive number match by number', ...);
test('a header naming the key column matches by number even with one column of data', ...);
test('a hidden dive number is skipped as hiddenRow, an unknown one as unknownRow', ...);
test('read-only columns are skipped and reported once each', ...);   // Review Focus 5
test('rows beyond the sheet are reported as truncated', ...);
test('unknown header is dropped and reported', ...);
test('names match case-insensitively', ...);
```

- [ ] **Step 2: Run red**

- [ ] **Step 3: Implement** the two files (pure Dart, no Flutter).

- [ ] **Step 4: Run green**

- [ ] **Step 5: Commit**

```bash
git add lib/features/table_editor/domain/paste_parser.dart lib/features/table_editor/domain/paste_planner.dart test/features/table_editor/domain/paste_parser_test.dart test/features/table_editor/domain/paste_planner_test.dart
git commit -m "feat(table-editor): parse a pasted block and plan where its cells land"
```

---

### Task 8: Save summary and the save service

**Files:**
- Create: `lib/features/table_editor/domain/save_summary.dart`, `lib/features/table_editor/data/table_editor_save_service.dart`
- Modify: `lib/core/services/change_log/change_log_scope.dart` (`ChangeLogLabels`, line 39: add `tableEditor`)
- Test: `test/features/table_editor/domain/save_summary_test.dart`, `test/features/table_editor/data/table_editor_save_service_test.dart`

**Interfaces:**
- Produces:

```dart
@immutable
class SaveSummary {
  final int changed;          // saveable drafts
  final int needsAttention;   // flagged drafts
  final int overwrites;       // saveable drafts whose original is non-empty
  final int changedElsewhere; // drafts flagged changedElsewhere (subset of needsAttention)
  final List<PasteSkip> skipped;
  final PasteMatching? matching;
  final List<String> notes;
  static SaveSummary from(List<TableDraft> drafts, {PastePlan? lastPaste, List<String> notes = const []});
}

@immutable
class TableEditorSaveResult { final String? operationId; final int saved; final List<TableDraft> changedElsewhere; }

class TableEditorSaveService {
  TableEditorSaveService({AppDatabase? db});   // defaults to DatabaseService.instance.databaseOrNull
  Future<TableEditorSaveResult> save<T, F extends EntityField>({
    required TableEditorEntity<T, F> entity,
    required Map<String, T> rows,       // the sheet's rows by id
    required List<TableDraft> drafts,   // saveable only
  });
}
```

`save`: `fresh = await entity.reload(ids)`; for each draft compare `entity.columnFor(field).valueOf(freshRow)` with `draft.original` (deep equality); mismatches go to `changedElsewhere` and out of the write set; then

```dart
String? operationId;
await ChangeLogScope.bulk(db, label: ChangeLogLabels.tableEditor, body: () async {
  operationId = ChangeLogScope.currentOperationId;
  await db.transaction(() => entity.save(grouped, freshById));
});
```

The scope stays outside the transaction (its doc requires that). Any exception propagates after the transaction rolls back; the caller keeps the drafts.

- [ ] **Step 1: Write the failing tests**

`save_summary_test.dart`: counts for a mix of saveable, flagged, overwriting drafts; matching and skipped pass through.

`table_editor_save_service_test.dart` with `DiveTableEditorEntity` on a test database (seed three dives):
```dart
test('saves drafts and reports the operation id', ...);
test('one operation: every written row shares the change log operation', ...);  // Review Focus 3: read the change_log operations table, expect one row labelled tableEditor for the save
test('stale draft is skipped and the others save', ...);   // Review Focus 3: change d2's visibility directly after drafting, save, expect d1 and d3 written, d2 untouched, result.changedElsewhere has d2's draft
test('all or nothing: a failing write leaves every dive unchanged', ...);   // Review Focus 4: a fake entity whose save writes d1 then throws; expect throwsA, d1's row unchanged, operation row absent or empty
test('undo through the change log revert restores the rows', ...);   // settleAll, planOperation(id), execute, expect prior values
```

- [ ] **Step 2: Run red**

- [ ] **Step 3: Implement** the two files and the label constant.

- [ ] **Step 4: Run green** (`flutter test test/features/table_editor/ test/features/change_log/`)

- [ ] **Step 5: Commit**

```bash
git add lib/features/table_editor/domain/save_summary.dart lib/features/table_editor/data/ lib/core/services/change_log/ test/features/table_editor/
git commit -m "feat(table-editor): save all as one change log operation in one transaction"
```

---

### Task 9: Providers, per-tab filters and column menus

**Files:**
- Create: `lib/features/table_editor/presentation/providers/table_editor_providers.dart`
- Create: `lib/core/query/presentation/column_rules.dart`, `lib/features/query/presentation/table/entity_column_menus.dart`
- Modify: `lib/features/dive_log/presentation/table/dive_table_menus.dart` (22, 46), `dive_column_filter_edits.dart` (optional delegation)
- Modify: `lib/l10n/arb/app_*.arb`
- Test: `test/core/query/presentation/column_rules_test.dart`, `test/features/query/presentation/table/entity_column_menus_test.dart`, `test/features/table_editor/presentation/providers/table_editor_providers_test.dart`

**Interfaces:**
- Produces in `column_rules.dart` (pure):

```dart
QueryNode addColumnRule(QueryNode? query, QueryNode rule);     // AND at top level, never nested into an OR, never duplicated (same rules as addDiveTableRule)
QueryNode? resetColumnRules(QueryNode? query, String fieldKey);  // drop every top-level condition on fieldKey; null when nothing is left
bool isColumnFiltered(QueryNode? query, String fieldKey);
```
`addDiveTableRule`, `resetDiveColumnFilter` and `isDiveColumnFiltered` delegate to these over `filter.query` (keep their signatures; their existing tests stay green).

- Produces in `entity_column_menus.dart`:

```dart
List<EntityTableMenuAction> entityColumnHeaderMenuItems({required AppLocalizations l10n, required QueryEntity root, required String fieldKey, required QueryNode? query, required ValueChanged<QueryNode?> onChanged});
  // "Only empty" (isEmpty), "Only with a value" (isSet), "Reset column" when isColumnFiltered; only ops the QueryField supports
List<EntityTableMenuAction> entityColumnCellMenuItems({required AppLocalizations l10n, required QueryEntity root, required String fieldKey, required Object? value, required String valueLabel, required QueryNode? query, required ValueChanged<QueryNode?> onChanged});
  // "Only {valueLabel}" (eq) and "Exclude {valueLabel}" (neq) when the field has eq and the value is non-null; the QueryValue built by the field's FieldType the way dive_cell_filter_options does
```

- `dive_table_menus.dart`: `diveHeaderMenuItems` and `diveCellMenuItems` gain `StateProvider<DiveFilterState> filterProvider = diveFilterProvider` and pass it to `showRefinePanel` and every read/write, so the editor's dive tab reuses the dive list's full menus on its own filter state.

- Produces in `table_editor_providers.dart`:

```dart
enum TableEditorTab { dives, sites, centers }
final tableEditorDraftsProvider = StateNotifierProvider.family<TableDraftsNotifier, TableDraftState, TableEditorTab>(...);
final tableEditorDiveFilterProvider = StateProvider<DiveFilterState>((ref) => const DiveFilterState());
final tableEditorSiteQueryProvider = StateProvider<QueryNode?>((ref) => null);
final tableEditorCenterQueryProvider = StateProvider<QueryNode?>((ref) => null);
final tableEditorDiveConfigProvider = StateNotifierProvider<EntityTableConfigNotifier<DiveField>, EntityTableViewConfig<DiveField>>(...);   // key 'table_editor_dives', default = the diver's dive table config converted with toEntityConfig(), else the dive list default
final tableEditorSiteConfigProvider = ...;      // key 'table_editor_sites', default = the site list default
final tableEditorCenterConfigProvider = ...;    // key 'table_editor_centers'
final tableEditorDivesProvider = FutureProvider<List<Dive>>(...);   // divesProvider narrowed by tableEditorDiveFilterProvider through the same ids family the dive list uses (add a family if the dive path is not one), rows filled with weights via getWeightsForDives
final tableEditorWeightsProvider = FutureProvider<Map<String, List<DiveWeight>>>(...);
final tableEditorSitesProvider = FutureProvider<List<SiteWithCount>>(...);   // the unfiltered sites-with-counts list narrowed with narrowByQuery(siteQueryEntity, tableEditorSiteQueryProvider)
final tableEditorEditableLibrarySitesProvider = FutureProvider<Map<String, bool>>(...);   // LibraryEditStamper().mayEdit per library site on the sheet
final tableEditorCentersProvider = FutureProvider<List<DiveCenterRow>>(...);   // the centers list with counts, narrowByQuery(diveCenterQueryEntity, tableEditorCenterQueryProvider)
final tableEditorSaveServiceProvider = Provider<TableEditorSaveService>(...);
```

- ARB keys (11 files): `tableEditor_menu_onlyEmpty` "Only empty", `tableEditor_menu_onlySet` "Only with a value", `tableEditor_menu_resetColumn` "Reset column", `tableEditor_menu_onlyValue` "Only {value}", `tableEditor_menu_excludeValue` "Exclude {value}". Reuse existing dive menu keys where the English matches instead of adding duplicates.

- [ ] **Step 1: Write the failing tests**

```dart
// column_rules_test
test('addColumnRule ANDs at top level next to an OR group', ...);
test('addColumnRule does not duplicate an identical rule', ...);
test('resetColumnRules drops only that field and returns null when empty', ...);
// entity_column_menus_test
test('header menu offers empty and set for the coordinates field', ...);   // siteQueryEntity 'coordinates'
test('cell menu offers Only and Exclude for a text field with eq', ...);
test('cell menu offers nothing for a null value', ...);
// providers_test
test('editor dive config has its own storage key and does not change the dive list config', ...);
test('dive filter of the editor leaves diveFilterProvider untouched', ...);
```

- [ ] **Step 2: Run red**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run green** (`flutter test test/core/query/ test/features/query/ test/features/dive_log/query/ test/features/table_editor/ test/l10n/`)

- [ ] **Step 5: Commit**

```bash
git add lib/core/query/presentation/column_rules.dart lib/features/query/presentation/table/ lib/features/dive_log/query/dive_column_filter_edits.dart lib/features/dive_log/presentation/table/dive_table_menus.dart lib/features/table_editor/presentation/providers/ lib/l10n/ test/core/query/ test/features/query/ test/features/table_editor/
git commit -m "feat(table-editor): per-tab filters, configs and column menus for every entity"
```

---

### Task 10: The sheet: editable cells and keyboard

**Files:**
- Create: `lib/features/table_editor/domain/cell_navigation.dart`, `lib/features/table_editor/presentation/widgets/editable_cell.dart`, `table_editor_sheet.dart`
- Modify: `lib/l10n/arb/app_*.arb`
- Test: `test/features/table_editor/domain/cell_navigation_test.dart`, `test/features/table_editor/presentation/widgets/table_editor_sheet_test.dart`

**Interfaces:**
- Produces in `cell_navigation.dart`:

```dart
enum CellMove { none, down, next, previous }
/// Next editable position, or null at the sheet's edge. Enter: same column, next row; Tab: next editable column, wrapping to the next row's first editable column; Shift+Tab the reverse.
CellPosition? nextCell({required CellPosition from, required CellMove move, required List<String> rowIds, required List<String> editableFieldNames});
```

- Produces `EditableCell` (StatefulWidget): `EditableCell({required CellEditorKind kind, required String initialText, required List<ChoiceOption> choices, bool initialToggle = false, List<String> initialSelection = const [], required void Function(String text, CellMove move) onCommitText, required void Function(Object? value, CellMove move) onCommitValue, required VoidCallback onCancel})`. Text, number and integer kinds render a `TextField` (autofocus, select all, `onSubmitted` commits with `CellMove.down`; a `Focus.onKeyEvent` maps Tab to `next`, Shift+Tab to `previous`, Escape to `onCancel`). Choice renders a `DropdownMenu` opened at once; multiChoice a popup of `CheckboxListTile`s with a Done button; toggle commits the flipped value immediately; reference renders a searchable `DropdownMenu` (`enableFilter: true`).

- Produces `TableEditorSheet<T, F extends EntityField>` (ConsumerWidget): `TableEditorSheet({required TableEditorTab tab, required TableEditorEntity<T, F> entity, required List<T> rows, required StateNotifierProvider<EntityTableConfigNotifier<F>, EntityTableViewConfig<F>> configProvider, required EntityTableHeaderMenuBuilder<F>? headerMenuBuilder, required EntityTableCellMenuBuilder<T, F>? cellMenuBuilder, required bool Function(F) isColumnFiltered, required void Function(String entityId) onOpenRecord})`. It wires `EntityTableView` with: `onCellTap` sets `editing` when the column is editable (a tap on a read-only cell shows its `readOnlyReason` in a tooltip-style SnackBar-free overlay: use `Tooltip.ensureTooltipVisible` on a wrapping `Tooltip`); `cellBuilder` returns `EditableCell` for the editing cell, and for a drafted cell a `Tooltip(message: l10n.tableEditor_original(formattedOriginal))` around the formatted draft value (flagged cells show `rawText` and the flag's message); `cellBackground` returns `colorScheme.tertiaryContainer` for a draft, `errorContainer` for a flagged draft, null otherwise; `onEntityDoubleTap` = `onOpenRecord`. Commit: parse through `entity.columnFor(field).parse(text, units, l10n)`, build the `TableDraft` (original = `column.valueOf(row)`, `rawText` = text, flag from `CellRejected`), run `entity.reconcile(row, draftsForRow)`, `putAll`, then `setEditing(nextCell(...))`.

- ARB keys (11 files): `tableEditor_original` "Was: {value}", `tableEditor_flag_unparsable` "Not a valid value", `tableEditor_flag_unknownValue` "Not in the list", `tableEditor_flag_pairIncomplete` "Needs both latitude and longitude", `tableEditor_flag_changedElsewhere` "Changed elsewhere since you edited it", `tableEditor_libraryReadOnly` "Library site: only notes and rating can be edited here", `tableEditor_weightRows` "{count} weight rows, edit them in the dive" (plural), `tableEditor_multiChoice_done` "Done".

- [ ] **Step 1: Write the failing tests**

```dart
// cell_navigation_test
test('down moves to the same column in the next row and null at the last row', ...);
test('next wraps to the next row\'s first editable column', ...);
test('previous from the first editable column wraps to the previous row\'s last', ...);
// table_editor_sheet_test (testApp, DiveTableEditorEntity over two in-memory dives, overrides as site_list_content_table_test does)
testWidgets('tapping an editable cell opens a TextField with the current value in the diver\'s unit', ...);
testWidgets('Enter commits a draft, paints it and moves down', ...);   // enterText '12', testTextInput.receiveAction(done); draft at (d1, visibility) == 12 m stored; editing now (d2, visibility)
testWidgets('Escape cancels without a draft', ...);
testWidgets('an unparsable value is flagged and shows the raw text', ...);
testWidgets('a draft equal to the original is dropped', ...);
testWidgets('a read-only weight cell does not open an editor', ...);
testWidgets('double tap calls onOpenRecord', ...);
```

- [ ] **Step 2: Run red**

- [ ] **Step 3: Implement** the three files; `table_editor_sheet.dart` stays under 400 lines by keeping draft-to-widget rendering in `editable_cell.dart` helpers.

- [ ] **Step 4: Run green** (`flutter test test/features/table_editor/ test/shared/ test/l10n/`)

- [ ] **Step 5: Commit**

```bash
git add lib/features/table_editor/ lib/l10n/ test/features/table_editor/
git commit -m "feat(table-editor): in-place cell editing with keyboard movement"
```

---

### Task 11: The page, paste flow, summary, Undo, guard, route and Data Tools row

**Files:**
- Create: `lib/features/table_editor/presentation/pages/table_editor_page.dart`, `lib/features/table_editor/presentation/widgets/save_summary_dialog.dart`, `lib/features/table_editor/presentation/table_editor_paste.dart`
- Modify: `lib/features/settings/presentation/pages/data_tools_page.dart`, `lib/core/router/app_router.dart` (next to the `data-quality` child route, ~1502)
- Modify: `lib/l10n/arb/app_*.arb`
- Test: `test/features/table_editor/presentation/pages/table_editor_page_test.dart`, `test/features/table_editor/presentation/table_editor_paste_test.dart`, `test/features/settings/presentation/pages/data_tools_page_test.dart` (modify: five rows)

**Interfaces:**
- Route: `GoRoute(path: 'table-editor', name: 'tableEditor', builder: (context, state) => const TableEditorPage())` under `/settings`; Data Tools row `tool(Icons.grid_on, l10n.settings_tableEditor_title, l10n.settings_tableEditor_subtitle, '/settings/table-editor')`.
- `TableEditorPage` (ConsumerStatefulWidget): `Scaffold` with `AppBar(title, bottom: TabBar(Dives, Sites, Centers))`, actions: draft count chip, Paste (`IconButton`, enabled when a cell is selected or editing), Save all (`FilledButton`, enabled when `saveable.isNotEmpty`). Body: when `!ResponsiveBreakpoints.isDesktop(context)` a centred `Text(l10n.tableEditor_needsWiderScreen)` and nothing else; otherwise `TabBarView` of three `TableEditorSheet`s wrapped in each entity's `QueryChipsFrame` (sites and centers) or the dive active filter chips (dives, over `tableEditorDiveFilterProvider`). `PopScope(canPop: drafts.isEmpty, onPopInvokedWithResult: ...)` with the `forms_discard_*` dialog copied from `EditFormScaffold._confirmDiscard`; switching tabs with drafts on the current tab asks the same dialog. `onOpenRecord`: with drafts, a three-button dialog (Save all and open, Discard and open, Stay); then `context.push` to the record's detail route (the one the list pages use).
- Paste flow (`table_editor_paste.dart`): `Future<PastePlan<F>?> readAndPlanPaste<T, F extends EntityField>({required BuildContext context, required TableEditorEntity<T, F> entity, required List<T> rows, required List<F> visibleColumns, required CellPosition selected, required Set<String> hiddenKeys})` reads `Clipboard.getData(Clipboard.kTextPlain)` (catch `PlatformException` as `passport_scan_sheet.dart` does), builds `SheetRow`s and the label matcher from `field.localizedDisplayName(l10n)`, calls `planPaste`, then `applyPastePlan(plan, entity, rowsById, units, l10n, notifier)` parses each cell with its column and `putAll`s the drafts (after `reconcile` per row). `hiddenKeys` for dives: numbers of all the diver's dives not on the sheet (one id/number read); for sites and centers: names not on the sheet. A `CallbackShortcuts` on the page binds `control+V` and `meta+V` to the same flow. The last `PastePlan` is kept in page state for the summary.
- `SaveSummaryDialog.show(BuildContext context, SaveSummary summary) -> Future<bool>` lists `changed`, `needsAttention`, `overwrites`, `changedElsewhere`, each skip, the matching line and `notes`; Save proceeds on true.
- Save all: `summary = SaveSummary.from(drafts.all, lastPaste:, notes: entity.summaryNotes(...))`; on confirm `result = await saveService.save(...)`; `notifier.clear()` for saved drafts, `notifier.rebase(...)` for `result.changedElsewhere` with the fresh value and flag them `changedElsewhere`; refresh the tab's rows provider; show `SnackBar(content: Text(l10n.tableEditor_saved(result.saved)), duration: const Duration(seconds: 5), persist: false, action: SnackBarAction(label: l10n.tableEditor_undo, onPressed: _undo))` where `_undo` runs `changeLogRepository.settleAll()`, `revert.execute(await revert.planOperation(operationId))` and shows `tableEditor_undoneAll` or `tableEditor_undonePartial(result.reverted, total)`. A thrown save shows `SnackBar(content: Text(l10n.tableEditor_saveFailed))` and keeps the drafts.
- ARB keys (11 files): `settings_tableEditor_title` "Table editor", `settings_tableEditor_subtitle` "Edit many dives, sites or centers in a spreadsheet", `settings_data_dataTools_subtitle` updated to "Fix dive times, link buddies, retype gear, data quality, table editor", `tableEditor_title` "Table editor", `tableEditor_tab_dives` "Dives", `tableEditor_tab_sites` "Sites", `tableEditor_tab_centers` "Centers", `tableEditor_needsWiderScreen` "The table editor needs a wider window. Open it on a tablet or a computer.", `tableEditor_saveAll` "Save all", `tableEditor_paste` "Paste", `tableEditor_draftCount` "{count} unsaved" (plural), `tableEditor_summary_title` "Save changes?", `tableEditor_summary_changed` "{count} cells change" (plural), `tableEditor_summary_attention` "{count} need attention and will not be saved" (plural), `tableEditor_summary_overwrite` "{count} replace an existing value" (plural), `tableEditor_summary_changedElsewhere` "{count} changed elsewhere since you edited them" (plural), `tableEditor_summary_matching_number` "Pasted rows matched by dive number", `tableEditor_summary_matching_name` "Pasted rows matched by name", `tableEditor_summary_matching_position` "Pasted rows placed by position", `tableEditor_summary_siteSnap` "Setting a site also sets its water type, entry, exit and dive types on the dive", `tableEditor_summary_pairClear` "Clearing one coordinate clears both", `tableEditor_skip_readOnlyColumn` "{column} is read-only", `tableEditor_skip_unknownRow` "No row for {key}", `tableEditor_skip_hiddenRow` "{key} is hidden by the filter", `tableEditor_skip_truncated` "{count} rows past the end of the sheet" (plural), `tableEditor_skip_unknownColumn` "No column named {header}", `tableEditor_saved` "{count} changes saved" (plural), `tableEditor_saveFailed` "Nothing was saved. Fix the error and try again.", `tableEditor_undo` "Undo", `tableEditor_undoneAll` "Changes undone", `tableEditor_undonePartial` "Undid {reverted} of {total} changes", `tableEditor_open_saveAndOpen` "Save all and open", `tableEditor_open_discardAndOpen` "Discard and open", `tableEditor_open_stay` "Stay".

- [ ] **Step 1: Write the failing tests**

```dart
// data_tools_page_test: findsNWidgets(5) and the new title
// table_editor_page_test (testAppRouter with the page route and stub detail routes; surface 1200x800)
testWidgets('shows three tabs and the dive sheet', ...);
testWidgets('narrow window shows only the wider screen message', ...);  // surface 600x800
testWidgets('Save all is disabled without drafts and enabled with one', ...);
testWidgets('leaving with drafts asks first', ...);   // tap back, expect forms_discard_title
testWidgets('Save all shows the summary then saves and offers Undo', ...);
testWidgets('double tap with drafts offers Save all and open', ...);
// table_editor_paste_test (unit, fake clipboard via TestDefaultBinaryMessengerBinding mock of SystemChannels.platform 'Clipboard.getData')
test('two-column paste with dive numbers lands by number and flags an unknown list value', ...);
test('clipboard failure yields null and no drafts', ...);
```

- [ ] **Step 2: Run red**

- [ ] **Step 3: Implement** the page (under 400 lines; the dialogs and the paste flow live in their own files), the route, the row and the ARB keys; run `flutter gen-l10n`.

- [ ] **Step 4: Run green**

Run: `flutter test test/features/table_editor/ test/features/settings/presentation/pages/data_tools_page_test.dart test/l10n/ test/architecture/ test/shared/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/table_editor/ lib/features/settings/presentation/pages/data_tools_page.dart lib/core/router/app_router.dart lib/l10n/ test/features/table_editor/ test/features/settings/
git commit -m "feat(table-editor): the Table editor page under Data Tools"
```

---

### Task 12: Whole-repo verification

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format lib test && flutter analyze`
Expected: no changes from format, no analyzer issues.

- [ ] **Step 2: Generated l10n is current**

Run: `flutter gen-l10n && git status --porcelain lib/l10n`
Expected: empty.

- [ ] **Step 3: Run the affected suites**

Run: `flutter test test/features/table_editor test/features/dive_log test/features/dive_sites test/features/dive_centers test/features/query test/core test/shared test/architecture test/l10n test/features/settings test/features/change_log`
Expected: PASS. If a run is slow or hangs under load, follow the repo's test-run notes (private TMPDIR, `FLUTTER_SHIM_OFF=1`).

- [ ] **Step 4: Commit any formatting fallout**

```bash
git add -A lib test
git commit -m "chore(table-editor): format and analyzer fixes"
```

Only if step 1 changed files; otherwise skip.
