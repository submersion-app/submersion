# Selection Checkbox Inside Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every entity list renders its multi-select checkbox inside the item card, through one shared primitive, with the placement asserted by the selection contract.

**Architecture:** Two treatments chosen per tile. Tiles that own a leading widget (icon container, `CircleAvatar`) wrap it in the existing `SelectionLeading`, which swaps it for a checkbox with no layout shift. Tiles with no leading widget insert a new `SelectionCheckboxSlot` as the first child of their inner `Row`, inside the card's padding. The `SelectableRow` wrapper that put checkboxes outside cards is deleted. `verifySelectionContract` gains a `rowRoot` finder so "inside the card" is enforced, not merely conventional.

**Tech Stack:** Flutter 3.x, Material 3, Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-14-selection-checkbox-placement-design.md`

## Global Constraints

- All Dart must pass `dart format .` with no changes. Run `dart format .` before every commit.
- `flutter analyze` must be clean. Infos are fatal in CI.
- Work happens in the worktree `.claude/worktrees/selection-checkbox-inside-card` on branch `worktree-selection-checkbox-inside-card`. Never `cd` to the main checkout.
- No emojis in code, comments, or docs.
- Anything displaying units respects the active diver's unit settings. No task here touches unit formatting.
- Tile parameters added by this plan are named exactly `isSelectionMode`, `isChecked`, `onCheckChanged`. Do not reuse `isSelected`, which already means different things in different features (checkbox value in `DenseSiteListTile`, focus tint in `DenseTripListTile`).
- Every commit must leave `flutter test` green. Tasks are ordered so no feature is left half-converted across a commit boundary.
- Test runs can be slow; allow a 600000 ms timeout on full-suite commands.

---

### Task 1: The `SelectionCheckboxSlot` primitive

**Files:**
- Create: `lib/shared/selection/selection_checkbox_slot.dart`
- Test: `test/shared/selection/selection_checkbox_slot_test.dart`

**Interfaces:**
- Consumes: `SelectionLeading` from `lib/shared/selection/selection_leading.dart` (params `child`, `isSelectionMode`, `isChecked`, `isSelectable`, `onChanged`).
- Produces: `SelectionCheckboxSlot({Key? key, required bool isSelectionMode, required bool isChecked, bool isSelectable = true, ValueChanged<bool>? onChanged, double gap = 12})`. Every later task uses this for tiles with no leading widget.

- [ ] **Step 1: Write the failing test**

Create `test/shared/selection/selection_checkbox_slot_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/selection/selection_checkbox_slot.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Row(children: [child]))); 

  group('SelectionCheckboxSlot', () {
    testWidgets('renders nothing measurable when not in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SelectionCheckboxSlot(isSelectionMode: false, isChecked: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(
        tester.getSize(find.byType(SelectionCheckboxSlot)).width,
        0,
        reason: 'the slot must reserve no width outside selection mode',
      );
    });

    testWidgets('renders a checkbox and a gap in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SelectionCheckboxSlot(isSelectionMode: true, isChecked: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
      expect(
        tester.getSize(find.byType(SelectionCheckboxSlot)).width,
        greaterThan(12),
        reason: 'the slot must occupy the checkbox width plus the gap',
      );
    });

    testWidgets('reports the checked value', (tester) async {
      await tester.pumpWidget(
        host(
          const SelectionCheckboxSlot(isSelectionMode: true, isChecked: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('reports taps through onChanged', (tester) async {
      bool? received;
      await tester.pumpWidget(
        host(
          SelectionCheckboxSlot(
            isSelectionMode: true,
            isChecked: false,
            onChanged: (value) => received = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(received, isTrue);
    });

    testWidgets('renders nothing for a non-selectable row', (tester) async {
      await tester.pumpWidget(
        host(
          const SelectionCheckboxSlot(
            isSelectionMode: true,
            isChecked: false,
            isSelectable: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(tester.getSize(find.byType(SelectionCheckboxSlot)).width, 0);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/shared/selection/selection_checkbox_slot_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:submersion/shared/selection/selection_checkbox_slot.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/shared/selection/selection_checkbox_slot.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/shared/selection/selection_leading.dart';

/// A checkbox inserted at the start of a row that has no leading element.
///
/// Tiles that own a leading widget -- a dive number badge, a site avatar --
/// use [SelectionLeading] to swap it for the checkbox. Compact and dense tiles
/// start their row with the entity name and have nothing to swap, so the
/// checkbox has to be inserted instead. This keeps that insertion inside the
/// tile's own padding, so the checkbox reads as part of the card rather than
/// floating beside it.
///
/// Nothing is reserved when selection mode is off: the slot collapses to zero
/// width, and the gap collapses with it rather than leaving the row's first
/// element indented by a checkbox that is not there.
class SelectionCheckboxSlot extends StatelessWidget {
  final bool isSelectionMode;
  final bool isChecked;

  /// False for rows that cannot be acted on, such as built-in reference data.
  final bool isSelectable;

  final ValueChanged<bool>? onChanged;

  /// Space between the checkbox and the row's first real element.
  final double gap;

  const SelectionCheckboxSlot({
    super.key,
    required this.isSelectionMode,
    required this.isChecked,
    this.isSelectable = true,
    this.onChanged,
    this.gap = 12,
  });

  static const Duration _gapDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final showCheckbox = isSelectionMode && isSelectable;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectionLeading(
          isSelectionMode: isSelectionMode,
          isChecked: isChecked,
          isSelectable: isSelectable,
          onChanged: onChanged,
          child: const SizedBox.shrink(),
        ),
        // The gap belongs to the checkbox, so it collapses with it.
        AnimatedSize(
          duration: _gapDuration,
          child: SizedBox(width: showCheckbox ? gap : 0),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/shared/selection/selection_checkbox_slot_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/shared/selection/selection_checkbox_slot.dart test/shared/selection/selection_checkbox_slot_test.dart
git commit -m "feat(selection): add SelectionCheckboxSlot for tiles with no leading widget"
```

---

### Task 2: Teach the contract to check placement

**Files:**
- Modify: `test/helpers/selection_contract.dart:23-55`
- Modify (add `rowRoot` argument only): `test/features/dive_log/presentation/widgets/dive_list_content_test.dart`, `test/features/dive_sites/presentation/widgets/site_list_content_test.dart`, `test/features/buddies/presentation/widgets/buddy_list_content_test.dart`, `test/features/tags/presentation/pages/tag_manage_page_test.dart`, `test/features/marine_life/presentation/pages/species_manage_page_test.dart`, `test/features/equipment/presentation/pages/service_kind_list_page_test.dart`

**Interfaces:**
- Produces: `verifySelectionContract(..., Finder? rowRoot)`. Asserted non-null whenever `indicator == CheckedIndicator.checkbox`. Callers pass a finder matching exactly one row root, e.g. `find.byType(EquipmentListTile).first`. Every later task adds this argument for its own feature.

The six surfaces modified here already place the checkbox inside the row, so they pass immediately. The eight outside-card surfaces are deliberately left untouched — each is converted in its own task, where the missing `rowRoot` produces that feature's red run.

- [ ] **Step 1: Add the parameter and the placement assertion**

In `test/helpers/selection_contract.dart`, add `Finder? rowRoot,` to the parameter list after `indicator`, and add this assert as the first statement in the function body:

```dart
  // A surface that forgets to declare its row root must fail rather than
  // silently skip the placement check -- an assertion that can be skipped is
  // indistinguishable from no assertion, which is how the outside-card layouts
  // passed this contract for so long.
  assert(
    indicator != CheckedIndicator.checkbox || rowRoot != null,
    'checkbox surfaces must declare the row root the checkbox has to live '
    'inside',
  );
```

Then replace the existing checkbox block (currently lines 49-55):

```dart
  if (indicator == CheckedIndicator.checkbox) {
    expect(
      find.byType(Checkbox),
      findsWidgets,
      reason: 'selection mode must render checkboxes in the leading slot',
    );
    expect(
      find.descendant(of: rowRoot!, matching: find.byType(Checkbox)),
      findsOneWidget,
      reason: 'the checkbox must render inside the row, not beside it',
    );
  }
```

Also update the doc comment above `enum CheckedIndicator` to document `rowRoot`:

```dart
/// [rowRoot] finds exactly one row's root widget. The checkbox must render
/// inside it, which is what keeps every list drawing the checkbox in the card
/// rather than beside it. Required for [CheckedIndicator.checkbox] surfaces.
```

- [ ] **Step 2: Add `rowRoot` to the six already-passing surfaces**

For each file below, add one `rowRoot:` argument to its `verifySelectionContract(` call:

| Test file | Argument to add |
| --- | --- |
| `dive_list_content_test.dart` | `rowRoot: find.byType(DiveListTile).first,` |
| `site_list_content_test.dart` | `rowRoot: find.byType(SiteListTile).first,` |
| `buddy_list_content_test.dart` | `rowRoot: find.byType(BuddyListTile).first,` |
| `tag_manage_page_test.dart` | `rowRoot: find.byType(ListTile).first,` |
| `species_manage_page_test.dart` | `rowRoot: find.byType(ListTile).first,` |
| `service_kind_list_page_test.dart` | `rowRoot: find.byType(ListTile).first,` |

Add the matching import for each tile type if the test file does not already import it. If a surface's default view mode renders a compact or dense tile instead of the type named above, use the type actually rendered — check by running the test and reading the failure.

The two media surfaces (`dive_media_section_selection_test.dart`, `site_media_section_test.dart`) pass `CheckedIndicator.custom` and need no change; confirm they still pass.

- [ ] **Step 3: Run the six surfaces plus the media opt-outs**

Run:
```bash
flutter test test/features/dive_log/presentation/widgets/dive_list_content_test.dart test/features/dive_sites/presentation/widgets/site_list_content_test.dart test/features/buddies/presentation/widgets/buddy_list_content_test.dart test/features/tags/presentation/pages/tag_manage_page_test.dart test/features/marine_life/presentation/pages/species_manage_page_test.dart test/features/equipment/presentation/pages/service_kind_list_page_test.dart test/features/media/presentation/widgets/dive_media_section_selection_test.dart test/features/media/presentation/widgets/site_media_section_test.dart
```
Expected: PASS. These six already render the checkbox inside the row.

- [ ] **Step 4: Confirm the contract now catches the eight outside-card surfaces**

Run: `flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart`
Expected: FAIL on the assert — "checkbox surfaces must declare the row root the checkbox has to live inside". This is the proof the new assertion is reachable. Do not fix it here; Task 5 converts trips.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add test/helpers/selection_contract.dart test/features/dive_log test/features/dive_sites test/features/buddies test/features/tags test/features/marine_life test/features/equipment
git commit -m "test(selection): assert the checkbox renders inside the row"
```

Note: the eight unconverted surfaces are failing at this commit. That is expected and is resolved feature by feature in Tasks 3-10. If a green-at-every-commit history is required, squash Tasks 2-11 at the end.

---

### Task 3: Courses

**Files:**
- Modify: `lib/features/courses/presentation/widgets/course_card.dart`
- Modify: `lib/features/courses/presentation/widgets/course_list_content.dart:540-553`
- Test: `test/features/courses/presentation/widgets/course_list_content_test.dart`

**Interfaces:**
- Consumes: `SelectionLeading` from Task 1's sibling file `lib/shared/selection/selection_leading.dart`.
- Produces: `CourseCard` gains `isSelectionMode`, `isChecked`, `onCheckChanged`.

- [ ] **Step 1: Add `rowRoot` to the courses contract call (the failing test)**

In `test/features/courses/presentation/widgets/course_list_content_test.dart`, add to the `verifySelectionContract(` call:

```dart
        rowRoot: find.byType(CourseCard).first,
```

Add `import 'package:submersion/features/courses/presentation/widgets/course_card.dart';` if absent.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/courses/presentation/widgets/course_list_content_test.dart`
Expected: FAIL — "the checkbox must render inside the row, not beside it". The checkbox is currently a sibling of `CourseCard` inside `SelectableRow`, not a descendant.

- [ ] **Step 3: Give `CourseCard` selection parameters**

In `course_card.dart`, add to the field list and constructor:

```dart
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;
```

```dart
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
```

Add the import:

```dart
import 'package:submersion/shared/selection/selection_leading.dart';
```

- [ ] **Step 4: Wrap the 48x48 status container**

In `course_card.dart`, the `Row` inside `Padding(padding: const EdgeInsets.all(16))` starts with a `Container(width: 48, height: 48, ...)` holding the school/check icon. Wrap that entire `Container` in `SelectionLeading`:

```dart
              children: [
                // Status icon, which becomes the checkbox in selection mode.
                SelectionLeading(
                  isSelectionMode: isSelectionMode,
                  isChecked: isChecked,
                  onChanged: onCheckChanged,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: course.isCompleted
                          ? Colors.green.withValues(alpha: 0.15)
                          : colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      course.isCompleted
                          ? Icons.check_circle_outline
                          : Icons.school_outlined,
                      // keep the existing color and size arguments unchanged
                    ),
                  ),
                ),
                const SizedBox(width: 16),
```

Keep every existing argument of the `Container` and `Icon` exactly as it is; only the wrapping changes.

- [ ] **Step 5: Replace `SelectableRow` at the call site**

In `course_list_content.dart` around lines 540-553, the tile is currently built as `Padding(bottom: 8) > SelectableRow(... child: CourseCard(...))`. Remove the `SelectableRow` wrapper and pass its three selection arguments to `CourseCard` instead:

```dart
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CourseCard(
              // keep every existing CourseCard argument unchanged
              isSelectionMode: _isSelectionMode,
              isChecked: _selectedIds.contains(course.id),
              onCheckChanged: (_) => _selection.toggle(course.id),
            ),
          );
```

Use whatever names this file already uses for the selection-mode flag, the checked id set, and the controller; they match the `SelectableRow` arguments being removed. Delete the now-unused `selectable_row.dart` import.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/courses/presentation/widgets/course_list_content_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/courses test/features/courses
git commit -m "feat(courses): move the selection checkbox inside the course card"
```

---

### Task 4: Certifications

**Files:**
- Modify: `lib/features/certifications/presentation/widgets/certification_list_content.dart` (tile at ~:712, `_buildLeadingIcon`, and three `SelectableRow` call sites at ~:567, ~:587, ~:607)
- Test: `test/features/certifications/presentation/widgets/certification_list_content_test.dart`

**Interfaces:**
- Produces: `CertificationListTile` gains `isSelectionMode`, `isChecked`, `onCheckChanged`.

- [ ] **Step 1: Add `rowRoot` to the contract call (the failing test)**

```dart
        rowRoot: find.byType(CertificationListTile).first,
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/certifications/presentation/widgets/certification_list_content_test.dart`
Expected: FAIL — "the checkbox must render inside the row, not beside it".

- [ ] **Step 3: Give `CertificationListTile` selection parameters**

Add the same three fields and constructor entries as Task 3 Step 3, and the `selection_leading.dart` import.

- [ ] **Step 4: Wrap the leading icon**

`CertificationListTile` renders `Card > ListTile(leading: _buildLeadingIcon(context), ...)`. Wrap the call, not the method body, so the 48x48 agency badge stays intact:

```dart
          leading: SelectionLeading(
            isSelectionMode: isSelectionMode,
            isChecked: isChecked,
            onChanged: onCheckChanged,
            child: _buildLeadingIcon(context),
          ),
```

- [ ] **Step 5: Replace `SelectableRow` at all three call sites**

The expired, expiring, and valid sections each wrap the tile. For each, delete the `SelectableRow` wrapper and move its `isSelectionMode`, `isChecked`, and `onChanged` arguments onto `CertificationListTile` as `isSelectionMode`, `isChecked`, and `onCheckChanged`. All three sections must be converted; leaving one produces a list where two sections look different from the third. Delete the now-unused `selectable_row.dart` import.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/certifications/presentation/widgets/certification_list_content_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/certifications test/features/certifications
git commit -m "feat(certifications): move the selection checkbox inside the card"
```

---

### Task 5: Trips

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart` (`TripListTile` at ~:775, `SelectableRow` at ~:657-662)
- Modify: `lib/features/trips/presentation/widgets/compact_trip_list_tile.dart`
- Modify: `lib/features/trips/presentation/widgets/dense_trip_list_tile.dart`
- Test: `test/features/trips/presentation/widgets/trip_list_content_test.dart`

**Interfaces:**
- Consumes: `SelectionCheckboxSlot` from Task 1.
- Produces: `TripListTile`, `CompactTripListTile`, and `DenseTripListTile` each gain `isSelectionMode`, `isChecked`, `onCheckChanged`.

This is the first task using both treatments. Trips renders `TripListTile` for detailed, `CompactTripListTile` for compact, and `DenseTripListTile` for dense and table, switched at `trip_list_content.dart:637-656`. All three must be converted, because the contract runs against whichever the default view mode selects.

- [ ] **Step 1: Add `rowRoot` to the contract call (the failing test)**

```dart
        rowRoot: find.byType(TripListTile).first,
```

If the test's default view mode renders a different variant, use that type instead — the failure message names what was found.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart`
Expected: FAIL — "the checkbox must render inside the row, not beside it".

- [ ] **Step 3: Convert `TripListTile` (swap treatment)**

Add the three fields, the constructor entries, and the `selection_leading.dart` import. Its `leading:` is a `Consumer` that resolves the trips feature accent. Wrap the `Consumer` itself, so the accent lookup is skipped entirely while the checkbox is shown:

```dart
          leading: SelectionLeading(
            isSelectionMode: isSelectionMode,
            isChecked: isChecked,
            onChanged: onCheckChanged,
            child: Consumer(
              builder: (context, ref, _) {
                // keep the existing accent resolution and CircleAvatar body
                // exactly as it is
              },
            ),
          ),
```

- [ ] **Step 4: Convert `DenseTripListTile` (insert treatment)**

Add the three fields, the constructor entries, and:

```dart
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
```

The tile's `Row` currently begins with `Expanded(child: Text(trip.name, ...))`. Insert the slot ahead of it as the first child:

```dart
            child: Row(
              children: [
                SelectionCheckboxSlot(
                  isSelectionMode: isSelectionMode,
                  isChecked: isChecked,
                  onChanged: onCheckChanged,
                  gap: 8,
                ),
                // Trip name (expanded)
                Expanded(
                  child: Text(
                    trip.name,
```

`gap: 8` rather than the default 12, because this row's own horizontal padding is already 16 and its internal spacing is 8.

- [ ] **Step 5: Convert `CompactTripListTile` (insert treatment)**

Same as Step 4: add the three fields, the constructor entries, the `selection_checkbox_slot.dart` import, and insert `SelectionCheckboxSlot` as the first child of the `Row` that currently starts with `Expanded(child: Text(trip.name))`. This tile's padding is `EdgeInsets.all(10)`, so use the default gap by omitting the `gap` argument.

- [ ] **Step 6: Replace `SelectableRow` at the call site**

At `trip_list_content.dart:657-662` the switch result is wrapped in `SelectableRow`. Pass the three arguments into each branch of the `switch` that builds the tile instead, and return the tile directly. Delete the now-unused `selectable_row.dart` import.

- [ ] **Step 7: Run the trips tests**

Run: `flutter test test/features/trips/`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/trips test/features/trips
git commit -m "feat(trips): move the selection checkbox inside the trip card"
```

---

### Task 6: Dive centers

**Files:**
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart` (`DiveCenterListTile` at ~:743, `SelectableRow` at ~:658)
- Modify: `lib/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart`
- Modify: `lib/features/dive_centers/presentation/widgets/dense_dive_center_list_tile.dart`
- Test: `test/features/dive_centers/presentation/widgets/dive_center_list_content_test.dart`

**Interfaces:**
- Produces: `DiveCenterListTile`, `CompactDiveCenterListTile`, `DenseDiveCenterListTile` each gain `isSelectionMode`, `isChecked`, `onCheckChanged`.

- [ ] **Step 1: Add `rowRoot` to the contract call (the failing test)**

```dart
        rowRoot: find.byType(DiveCenterListTile).first,
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_centers/presentation/widgets/dive_center_list_content_test.dart`
Expected: FAIL — "the checkbox must render inside the row, not beside it".

- [ ] **Step 3: Convert `DiveCenterListTile` (swap treatment)**

Add the three fields, the constructor entries, and the `selection_leading.dart` import. Its `Row` inside `Padding(EdgeInsets.all(16))` starts with a `Container(width: 48, height: 48, ...)` holding `Icon(Icons.store)`. Wrap that `Container` in `SelectionLeading` exactly as Task 3 Step 4 does for `CourseCard`, keeping every existing `Container` and `Icon` argument unchanged.

- [ ] **Step 4: Convert `DenseDiveCenterListTile` (insert treatment)**

Add the three fields, the constructor entries, the `selection_checkbox_slot.dart` import, and insert `SelectionCheckboxSlot` as the first child of the `Row` that currently starts with `Expanded(child: Text(center.name))`:

```dart
            child: Row(
              children: [
                SelectionCheckboxSlot(
                  isSelectionMode: isSelectionMode,
                  isChecked: isChecked,
                  onChanged: onCheckChanged,
                  gap: 8,
                ),
                Expanded(
                  child: Text(
```

- [ ] **Step 5: Convert `CompactDiveCenterListTile` (insert treatment)**

Same as Step 4, omitting the `gap` argument (its padding is `EdgeInsets.all(10)`).

- [ ] **Step 6: Replace `SelectableRow` at the call site**

At `dive_center_list_content.dart:658`, drop the wrapper and pass the three arguments into each branch of the view-mode switch. Delete the now-unused `selectable_row.dart` import.

- [ ] **Step 7: Run the dive centers tests**

Run: `flutter test test/features/dive_centers/`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_centers test/features/dive_centers
git commit -m "feat(dive-centers): move the selection checkbox inside the card"
```

---

### Task 7: Equipment

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`EquipmentListTile` at ~:829, `SelectableRow` at ~:738)
- Modify: `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_list_content_test.dart`

**Interfaces:**
- Produces: `EquipmentListTile` and `DenseEquipmentListTile` gain `isSelectionMode`, `isChecked`, `onCheckChanged`.

Equipment renders `EquipmentListTile` for both detailed and compact modes, and `DenseEquipmentListTile` for dense and table.

- [ ] **Step 1: Add `rowRoot` to the contract call (the failing test)**

```dart
        rowRoot: find.byType(EquipmentListTile).first,
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_list_content_test.dart`
Expected: FAIL — "the checkbox must render inside the row, not beside it".

- [ ] **Step 3: Convert `EquipmentListTile` (swap treatment)**

Add the three fields, the constructor entries, and the `selection_leading.dart` import. It renders `Card > ListTile(leading: CircleAvatar(...))`. Wrap the `CircleAvatar`:

```dart
        leading: SelectionLeading(
          isSelectionMode: isSelectionMode,
          isChecked: isChecked,
          onChanged: onCheckChanged,
          child: CircleAvatar(
            // keep the existing overdue/accent backgroundColor logic and the
            // Icon child exactly as they are
          ),
        ),
```

The overdue-service error coloring is a status signal and must be preserved untouched inside the `CircleAvatar`.

- [ ] **Step 4: Convert `DenseEquipmentListTile` (insert treatment)**

Add the three fields, the constructor entries, the `selection_checkbox_slot.dart` import, and insert `SelectionCheckboxSlot` as the first child of its `Row`, with `gap: 8`.

- [ ] **Step 5: Replace `SelectableRow` at the call site**

At `equipment_list_content.dart:738`, the `switch` on `viewMode` produces `tile`, which is then wrapped. Move the three arguments into both branches of the switch and return the tile directly. Delete the now-unused `selectable_row.dart` import.

- [ ] **Step 6: Run the equipment tests**

Run: `flutter test test/features/equipment/`
Expected: PASS. This directory also holds `service_kind_list_page_test.dart`, which Task 2 already wired.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/equipment test/features/equipment
git commit -m "feat(equipment): move the selection checkbox inside the card"
```

---

### Task 8: Cylinder configs

**Files:**
- Modify: `lib/features/cylinder_configs/presentation/pages/cylinder_config_list_page.dart` (`_ConfigTile` at ~:248-272, `SelectableRow` at ~:136-146)
- Test: `test/features/cylinder_configs/presentation/cylinder_config_list_page_test.dart`

**Interfaces:**
- Produces: `_ConfigTile` gains `isChecked` and `onCheckChanged`. It already has `isSelectionMode` and `onSelectToggle`.

`_ConfigTile` is a bare `ListTile` with no `leading:` at all, so it takes the insert treatment. It already accepts `isSelectionMode` but uses it only to redirect its tap.

- [ ] **Step 1: Add `rowRoot` to the contract call (the failing test)**

`_ConfigTile` is private, so the test cannot name its type. Use the `ListTile` it renders:

```dart
        rowRoot: find.byType(ListTile).first,
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/cylinder_configs/presentation/cylinder_config_list_page_test.dart`
Expected: FAIL — "the checkbox must render inside the row, not beside it".

- [ ] **Step 3: Give `_ConfigTile` a checked flag and a leading slot**

Add to `_ConfigTile`:

```dart
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;
```

with `this.isChecked = false,` and `this.onCheckChanged,` in the constructor, plus:

```dart
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
```

Then give the `ListTile` a leading slot holding the checkbox:

```dart
    return ListTile(
      leading: isSelectionMode
          ? SelectionCheckboxSlot(
              isSelectionMode: isSelectionMode,
              isChecked: isChecked,
              onChanged: onCheckChanged,
              gap: 0,
            )
          : null,
      title: Text(config.name),
      // keep subtitle, trailing, and onTap exactly as they are
    );
```

`gap: 0` because `ListTile` already provides the spacing between `leading` and `title`. The `isSelectionMode ? ... : null` guard keeps `ListTile` from reserving leading width when selection mode is off, which a zero-width non-null leading would not do.

- [ ] **Step 4: Replace `SelectableRow` at the call site**

At `cylinder_config_list_page.dart:136-146`, drop the wrapper and pass `isChecked` and `onCheckChanged` to `_ConfigTile` alongside the `isSelectionMode` and `onSelectToggle` it already receives. Delete the now-unused `selectable_row.dart` import.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/cylinder_configs/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/cylinder_configs test/features/cylinder_configs
git commit -m "feat(cylinder-configs): move the selection checkbox inside the row"
```

---

### Task 9: Media-store transfers

**Files:**
- Modify: `lib/features/media_store/presentation/pages/transfers_page.dart` (`_TransferTile` at ~:203-245, `SelectableRow` at ~:117-135)
- Test: `test/features/media_store/transfers_page_test.dart`

**Interfaces:**
- Produces: `_TransferTile` gains `isSelectionMode`, `isChecked`, `onCheckChanged`.

- [ ] **Step 1: Add `rowRoot` to the contract call (the failing test)**

`_TransferTile` is private; use the `ListTile` it renders:

```dart
        rowRoot: find.byType(ListTile).first,
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/media_store/transfers_page_test.dart`
Expected: FAIL — "the checkbox must render inside the row, not beside it".

- [ ] **Step 3: Convert `_TransferTile` (swap treatment)**

Add the three fields, the constructor entries, and the `selection_leading.dart` import. Wrap its state `Icon`:

```dart
    return ListTile(
      leading: SelectionLeading(
        isSelectionMode: isSelectionMode,
        isChecked: isChecked,
        onChanged: onCheckChanged,
        child: Icon(
          icon,
          color: entry.state == 'failed'
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      ),
      title: Text(label),
      // keep the rest of the ListTile exactly as it is
    );
```

- [ ] **Step 4: Replace `SelectableRow` at the call site**

At `transfers_page.dart:117-135` the tile may be wrapped in a `GestureDetector` inside `SelectableRow`. Remove only the `SelectableRow`, keep the `GestureDetector` if present, and pass the three arguments to `_TransferTile`. Delete the now-unused `selectable_row.dart` import.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/media_store/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/media_store test/features/media_store
git commit -m "feat(media-store): move the selection checkbox inside the transfer row"
```

---

### Task 10: Dive computers

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_list_page.dart` (`_ComputerCard` at ~:299-346, `SelectableRow` at ~:217-236)
- Test: `test/features/dive_computer/presentation/pages/device_list_page_test.dart:54`

**Interfaces:**
- Produces: `_ComputerCard` gains `isSelectionMode`, `isChecked`, `onCheckChanged`.

This is the only test that references `SelectableRow` by type, so it must be re-anchored here rather than in Task 11.

- [ ] **Step 1: Re-anchor the `SelectableRow` reference and add `rowRoot`**

At `device_list_page_test.dart:54`, `find.byType(SelectableRow).first` is used as a row anchor. `_ComputerCard` is private, so anchor on the `Card` it renders:

```dart
    find.byType(Card).first,
```

Remove the now-unused `selectable_row.dart` import from the test. Add to the `verifySelectionContract(` call:

```dart
        rowRoot: find.byType(Card).first,
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_computer/presentation/pages/device_list_page_test.dart`
Expected: FAIL — "the checkbox must render inside the row, not beside it".

- [ ] **Step 3: Convert `_ComputerCard` (swap treatment)**

Add the three fields, the constructor entries, and the `selection_leading.dart` import. Its `Row` inside `Padding(EdgeInsets.all(16))` starts with a `Container(width: 48, height: 48, ...)` holding the connection-type icon. Wrap that `Container` in `SelectionLeading`, keeping the favorite-tinted `decoration` and the `Icon` arguments exactly as they are.

- [ ] **Step 4: Replace `SelectableRow` at the call site**

At `device_list_page.dart:217-236`, drop the wrapper and pass the three arguments to `_ComputerCard`. Delete the now-unused `selectable_row.dart` import.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_computer/`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_computer test/features/dive_computer
git commit -m "feat(dive-computer): move the selection checkbox inside the device card"
```

---

### Task 11: Delete `SelectableRow`

**Files:**
- Delete: `lib/shared/selection/selectable_row.dart`

**Interfaces:**
- Consumes: nothing. All eight former call sites were converted in Tasks 3-10.
- Produces: nothing. This task exists to make the old placement unreachable, so the pattern cannot be reintroduced by copying a neighbor.

- [ ] **Step 1: Confirm there are no references left**

Run: `grep -rn "SelectableRow\|selectable_row" lib/ test/`
Expected: no output. If anything is listed, convert that call site using the treatment from whichever of Tasks 3-10 matches its tile shape before continuing.

- [ ] **Step 2: Delete the file**

```bash
git rm lib/shared/selection/selectable_row.dart
```

- [ ] **Step 3: Verify the tree still builds and the suite passes**

Run: `flutter analyze`
Expected: no issues.

Run: `flutter test`
Expected: PASS. Every surface is now converted, so the whole suite should be green here for the first time since Task 2.

- [ ] **Step 4: Commit**

```bash
dart format .
git add -A
git commit -m "refactor(selection): remove SelectableRow now that no list places the checkbox outside the card"
```

---

### Task 12: Consistency pass on the already-inside tiles

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (`SiteListTile` checkbox at ~:1352-1372)
- Modify: `lib/features/dive_sites/presentation/widgets/compact_site_list_tile.dart:39-70`
- Modify: `lib/features/dive_sites/presentation/widgets/dense_site_list_tile.dart:60-73`
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart` (`BuddyListTile` checkbox at ~:952-966)
- Modify: `lib/features/buddies/presentation/widgets/dense_buddy_list_tile.dart:52-76`
- Modify: `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart:284-315`
- Test: the existing tests for each of those tiles

**Interfaces:**
- Consumes: `SelectionLeading` and `SelectionCheckboxSlot`.
- Produces: no new parameters. These tiles already carry the state they need. Do **not** rename their existing `isSelected` fields — on `DenseSiteListTile` that field is the checkbox value, on other features it is the focus tint, and renaming would churn call sites and tests for no user-visible gain. Feed the existing field into the shared widget instead.

These six already draw the checkbox inside the card, so the contract passes before and after. The change is that they stop hand-rolling it: the two ternaries gain the 150 ms swap animation they lack, and the four `Visibility(maintainSize: true)` wrappers stop reserving checkbox width when selection mode is off.

- [ ] **Step 1: Convert the two raw ternaries to `SelectionLeading`**

In `site_list_content.dart`, `SiteListTile` currently renders:

```dart
                SizedBox(
                  width: 40,
                  height: 40,
                  child: isSelectionMode
                      ? Center(child: Checkbox(...))
                      : CircleAvatar(...),
                ),
```

Replace the ternary with a swap, keeping the `SizedBox` and the existing `CircleAvatar` arguments:

```dart
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SelectionLeading(
                      isSelectionMode: isSelectionMode,
                      isChecked: isSelected,
                      onChanged: (_) => onTap?.call(),
                      child: CircleAvatar(
                        // keep the existing CircleAvatar arguments unchanged
                      ),
                    ),
                  ),
                ),
```

Use whichever field this tile already binds to `Checkbox(value: ...)` as `isChecked`, and whatever it already passes as `onChanged`.

Apply the same transformation to `BuddyListTile` in `buddy_list_content.dart`, whose ternary sits in `ListTile.leading`.

- [ ] **Step 2: Convert the four `Visibility` wrappers to `SelectionCheckboxSlot`**

In each of `compact_site_list_tile.dart`, `dense_site_list_tile.dart`, `dense_buddy_list_tile.dart`, and `dense_dive_list_tile.dart`, replace the block:

```dart
                Visibility(
                  visible: isSelectionMode,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
```

with:

```dart
                SelectionCheckboxSlot(
                  isSelectionMode: isSelectionMode,
                  isChecked: isSelected,
                  onChanged: (_) => onTap?.call(),
                  gap: 8,
                ),
```

`dense_dive_list_tile.dart` wraps its `Checkbox` in a `SizedBox(width: 36) > Stack > Visibility` rather than a bare `Visibility`; remove the `SizedBox` and `Stack` along with it, since the slot sizes itself.

These four tiles reduce their left padding to make room for the always-reserved checkbox (`dense_site_list_tile.dart` uses `left: 8` where `dense_trip_list_tile.dart` uses `horizontal: 16`). Now that the slot reserves nothing, restore the left padding to match the horizontal padding on the same tile, so rows do not sit 8 px further left than their converted neighbors.

- [ ] **Step 3: Run the affected feature suites**

Run:
```bash
flutter test test/features/dive_sites/ test/features/buddies/ test/features/dive_log/
```
Expected: PASS. The tile-level tests assert `find.byType(Checkbox)` is present, which still holds. If a test asserted a fixed row width or a left offset, update it to the new padding and note the change in the commit body.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_sites lib/features/buddies lib/features/dive_log test/features/dive_sites test/features/buddies test/features/dive_log
git commit -m "refactor(selection): put sites, buddies, and dense dives on the shared checkbox widgets"
```

---

### Task 13: Full verification

**Files:** none modified unless a failure is found.

**Interfaces:**
- Consumes: everything from Tasks 1-12.
- Produces: a branch ready for review.

- [ ] **Step 1: Confirm formatting across the whole project**

Run: `dart format --set-exit-if-changed .`
Expected: exit 0, "0 changed".

- [ ] **Step 2: Confirm analysis across the whole project**

Run: `flutter analyze`
Expected: "No issues found!". Do not pipe this command; a pipe masks its exit status.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all tests pass. Allow up to 600000 ms.

- [ ] **Step 4: Confirm the invariant actually holds everywhere**

Run: `grep -rn "rowRoot" test/ | wc -l`
Expected: 14 — one per checkbox surface. The two media surfaces use `CheckedIndicator.custom` and correctly have none.

Run: `grep -rn "Visibility(" lib/features/dive_sites lib/features/buddies lib/features/dive_log | grep -i checkbox`
Expected: no output. No hand-rolled checkbox visibility remains.

- [ ] **Step 5: Verify the change by eye**

Run: `flutter run -d macos`

Enter selection mode on at least one converted list from each treatment — equipment (swap) and trips in dense mode (insert) — and confirm the checkbox appears inside the card, the animation is smooth, and no row shifts unexpectedly when leaving selection mode.

- [ ] **Step 6: Commit any fixes**

If Steps 1-5 required changes:

```bash
dart format .
git add -A
git commit -m "fix(selection): address verification findings"
```

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: the shared primitive to Task 1; the contract hole to Task 2; the seven swap tiles to Tasks 3, 4, 5, 6, 7, 9, 10; the six insert tiles to Tasks 5, 6, 7, 8; the eight call sites to Tasks 3-10; `SelectableRow` deletion to Task 11; the consistency pass to Task 12; the risks to Tasks 12 and 13.

**Deviation from the spec, deliberate.** The spec ordered the contract change as a single up-front red run across all eight surfaces. That would leave the tree red for eight consecutive commits. Task 2 instead wires only the six surfaces that already pass, and each feature task supplies its own red run. The tree is still red between Tasks 2 and 11; Task 2 notes the squash option if a fully green history is required.

**Naming consistency.** Tile parameters are `isSelectionMode`, `isChecked`, `onCheckChanged` in every task. The shared widget parameter is `onChanged` in both `SelectionLeading` and `SelectionCheckboxSlot`; tiles pass their `onCheckChanged` into it. `rowRoot` is the contract parameter throughout.

**Known gap, accepted.** `DenseDiveListTile` has no reference in `lib/` and is exercised only by its own tests. Task 12 converts it for consistency rather than deleting it; deletion is a maintainer decision outside this plan.
