# Data Sources: one entry per source Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On a multi-source dive, each data source appears once in the Data Sources section: as its comparison table column, whose header carries what the source card used to.

**Architecture:** The per-source menu moves out of `_DataSourceCard` into a shared `_SourceMenuButton`, used by the single-source card and by a new `_SourceColumnHeader` in the comparison table. The section builds one `_SourceActions` per source and hands the table a lookup; the table wraps every cell of a source's column in a tappable, tintable cell using `TableCellVerticalAlignment.intrinsicHeight`, so the tint fills the row without clipping a two-line value.

**Tech Stack:** Flutter widgets, `flutter_test`.

**Spec:** `docs/design/specs/2026-11-27-data-sources-one-entry-per-source-design.md` (issue #5081)

## Global Constraints

- No new user-visible strings; reuse the existing `diveLog_sources_*` keys.
- Single-source and manual-entry dives render as before.
- `DataSourcesSection.cardKey(sourceId)` keys the source's one entry: the header cell on a multi-source dive, the card on a single-source dive.
- Files stay under 800 lines; `data_sources_section.dart` is at 767, so new widgets go in a new part file.
- No em-dashes anywhere, in code, comments or docs.

## Review Focus

- Two sources with long names, both Primary and Viewing chips and both menus at 390 px: no overflow, both menu buttons on screen (Task 1 phone-width test).
- Three or more sources: each header, menu button included, stays within `maxScrollingCellWidth` (Task 1).
- A stale `viewedSourceId` that names no current source: no column tinted, no Viewing chip (Task 2).
- `operationReason` set: the header menu lists its operations disabled under the caption (existing #4527 tests, which tap `more_vert.last`, keep passing).
- Two sources from one computer: neither header offers Remove (existing `data_sources_remove_test.dart`).

---

### Task 1: Column headers carry the card; multi-source cards removed

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/data_source_column_header.dart` (part of `data_sources_section.dart`)
- Modify: `lib/features/dive_log/presentation/widgets/data_sources_section.dart`
- Modify: `lib/features/dive_log/presentation/widgets/data_source_comparison_grid.dart`
- Test: `test/features/dive_log/presentation/widgets/data_sources_section_test.dart`

**Interfaces:**
- Produces:
  - `class _SourceActions { const _SourceActions({VoidCallback? onSetPrimary, VoidCallback? onSplit, VoidCallback? onRemove, VoidCallback? onTap}); bool hasMenuFor(DiveDataSource source); }` where `hasMenuFor` is true when Set primary (non-primary source with `onSetPrimary`), Split or Remove applies (#2974 rule).
  - `_SourceActions _DataSourcesSectionState._actionsFor(DiveDataSource source, {required bool isMultiSource})`, carrying today's gating (Split and Remove only when multi-source, Remove not when `_sharesComputer`).
  - `class _SourceMenuButton extends StatelessWidget { const _SourceMenuButton({required DiveDataSource source, required _SourceActions actions, required String? operationReason}); }` holding today's popup menu (caption, Set primary, Split, Remove), compact density like `_SectionMenu`.
  - `class _SourceColumnHeader extends StatelessWidget { const _SourceColumnHeader({required DiveDataSource source, required bool isViewing, required _SourceActions actions, required String? operationReason}); }`: name (bold when primary, 2 lines, ellipsis), model subtitle (card's rule), a `Wrap` of Primary / Viewing `_Badge`s, and `_SourceMenuButton` when `actions.hasMenuFor(source)`.
  - `_SourceComparisonGrid` gains `required String? viewedSourceId`, `required _SourceActions Function(DiveDataSource) actionsFor`, `required String? operationReason`.
  - `_DataSourceCard` loses `isMultiSource` and `isViewing` (only built for a single source now) and takes `_SourceActions actions`.

- [ ] **Step 1: Write the failing tests**

In the `DataSourcesSection` group:

```dart
testWidgets('a multi-source dive shows one entry per source', (tester) async {
  // two sources, computerModel 'Shearwater Perdix' and 'Suunto D5'
  expect(find.byIcon(Icons.watch), findsNothing); // no source cards
  expect(find.byType(Divider), findsNothing);
  expect(find.text('Suunto D5'), findsOneWidget);
  expect(
    find.descendant(
      of: find.byKey(DataSourcesSection.comparisonGridKey),
      matching: find.byKey(DataSourcesSection.cardKey('src-2')),
    ),
    findsOneWidget,
  );
});

testWidgets('the column header shows the model under a renamed computer', ...);
// computerName 'My Perdix', computerModel 'Shearwater Perdix 2' on src-1:
// both texts are descendants of cardKey('src-1'), each findsOneWidget.

testWidgets('a header whose menu would be empty has no menu button', ...);
// only onSetPrimary given: no more_vert under cardKey('src-1') (primary),
// one under cardKey('src-2').
```

Rewrite the obsolete card tests in place:
- `shows divider between cards` and `three sources show three dividers` become `three sources: one Primary chip, no dividers` (`Divider` findsNothing, `Primary` findsOneWidget, `Secondary` findsNothing).
- `viewing the primary source shows both chips on one card` keeps its assertions (they now hold for the header).
- The phone-width test passes `onSetPrimary`, `onSplit`, `onTapSource` and `viewedSourceId: 'src-1'`, and also asserts both `more_vert` icons have `right <= 390` and `tester.takeException()` is null.
- The three-source scroll test asserts each `cardKey('src-$i')` width `<= DataSourcesSection.maxScrollingCellWidth`.
- Delete the stale comment in `onTapSource callback fires when secondary card is tapped` about the grid header duplicating the model name (Task 2 rewrites that test).

- [ ] **Step 2: Run to see them fail**

Run: `flutter test test/features/dive_log/presentation/widgets/data_sources_section_test.dart`
Expected: the new tests FAIL (cards and divider still present).

- [ ] **Step 3: Implement** the interfaces above. `_buildChildren` returns only the grid on a multi-source dive; the card list is built only for a single source.

- [ ] **Step 4: Run to see them pass**

Run the same file plus `data_sources_provenance_grid_test.dart`, `data_sources_remove_test.dart`, `source_bar_test.dart`, and the four `dive_detail_*` page tests that open a source menu (`dive_detail_multi_source_test.dart`, `dive_detail_page_unlock_operations_test.dart`, `dive_detail_page_unlock_pinned_profile_test.dart`, `dive_detail_page_unlock_operations_end_to_end_test.dart`). Expected: PASS.

- [ ] **Step 5: Commit** `feat(dive-log): Data Sources column headers carry the source card` (explicit paths).

### Task 2: Tap a column to view it; the viewed column is tinted

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/data_source_comparison_grid.dart`
- Modify: `lib/features/dive_log/presentation/widgets/data_source_column_header.dart`
- Test: `test/features/dive_log/presentation/widgets/data_sources_section_test.dart`

**Interfaces:**
- Consumes: `_SourceActions.onTap`, `viewedSourceId` from Task 1.
- Produces: `Widget _SourceComparisonGrid._sourceCell(DiveDataSource s, Widget child)`: a `TableCell(verticalAlignment: TableCellVerticalAlignment.intrinsicHeight)` holding a `Material` coloured `surfaceContainerHighest` when `s.id == viewedSourceId`, else transparent, around an `InkWell(onTap: actionsFor(s).onTap)`; used for the header cell and every value cell.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('tapping any cell of a column views that source', ...);
// maxDepth 31.0 on src-2; tap find.text('31.0m') -> tappedId 'src-2';
// tap find.text('Suunto D5') -> 'src-2'; tap the 30.0m cell -> 'src-1'.

testWidgets('the viewed column is tinted top to bottom', ...);
// viewedSourceId 'src-2': count Materials under comparisonGridKey with
// color == scheme.surfaceContainerHighest equals the number of TableRows
// (header + visible rows); each lies within src-2's header x-range.

testWidgets('a stale viewed id tints nothing and shows no Viewing chip', ...);
// viewedSourceId 'gone': no tinted Material, find.text('Viewing') findsNothing.

testWidgets('the header is a button, selected while viewed', ...);
// tester.getSemantics(find.byKey(cardKey('src-2'))) containsSemantics(
//   isButton: true, isSelected: true); src-1: isSelected false.
```

Replace `the viewed card gets a tinted background, others do not` and `onTapSource callback fires when secondary card is tapped` with the tests above.

- [ ] **Step 2: Run to see them fail** (same command as Task 1). Expected: FAIL.

- [ ] **Step 3: Implement** `_sourceCell` and wrap the header in `Semantics(button: true, selected: isViewing)`.

- [ ] **Step 4: Run** the Task 1 file list. Expected: PASS.

- [ ] **Step 5: Format, analyze, commit** `dart format .`, `flutter analyze`, then `feat(dive-log): tap a Data Sources column to view it`.
