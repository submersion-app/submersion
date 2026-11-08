# Trip gear: pick several items in one pass

Issue #4205. The trip's Gear tab adds one item per round trip through its
Add sheet. The dive editor's equipment picker has been multi-select since
#2175: every row has a checkbox and nothing is added until **Add N** is
pressed. The trip should use that same selection.

## Background

Both screens already open the same widget,
`lib/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart`
(`EquipmentPickerSheet`). They differ only in how they call it.

| | Dive editor (`dive_edit_page.dart`, `_showEquipmentPicker`) | Trip Gear tab (`trip_gear_add_sheet.dart`, `_pickItem`) |
|---|---|---|
| Callback | `onEquipmentConfirmed` (multi-select, checkboxes, Cancel / Add N) | `onEquipmentSelected` (tap one row, sheet closes) |
| `hideSpare` | true | true |
| `hideAssemblyParts` | true | off |
| `offerLeftKit` | true (a dive logged after the fact) | off |
| `overlapNote` | shared gear on another profile's dive (#2853) | none |

The issue's steps (Add, From my equipment, pick, then Add again for each
next item) come from the single-select callback. After the change: Add,
From my equipment, tick N items, **Add N**.

`_apply` in `trip_gear_add_sheet.dart` already takes a list. It packs the
non-cylinders, puts tanks on the cylinder board as slots, skips tanks
already on the board and drops members no longer shared with the diver.
The set path uses it with several items today, so the write side needs no
change.

## Scope

1. **Multi-select picker on the trip.** In `_pickItem`, replace
   `onEquipmentSelected` with `onEquipmentConfirmed`. The sheet returns
   `List<EquipmentItem>?`, and the `_Way.equipment` branch passes the whole
   list to `_apply` (with `setName: null`, as now). Cancel or dismissal
   returns null and writes nothing.
2. **Hide assembly parts, as the dive picker does.** Set
   `hideAssemblyParts: true`. A packed assembly already takes its installed
   parts to the trip (`gearOnTrip` in `trip_gear_scope.dart`, #2727), so
   offering the parts next to it invites packing them twice. The picker's
   own switch still brings them back. This covers a twinset too: its tanks
   are banded and manifolded, and splitting them means draining the set and
   plugging the manifold outlet, so a twinset travels as one unit and its
   single tanks are not offered by default. (Most twinsets are one tank
   item with the twin-set role, which the picker offers as one row and the
   board takes as one slot; this only matters for one entered as an
   assembly of two tanks.)
3. **Keep `offerLeftKit` off.** A trip looks ahead, and the picker's doc
   comment already says trips leave it off. That difference from the dive
   editor is deliberate.
4. **No `overlapNote`.** That note is about another profile's overlapping
   dive and does not apply to packing.
5. **Doc comments.** In `EquipmentPickerSheet`, update the
   `hideAssemblyParts` comment so it lists the trip among its callers.
6. **User docs.** `docs/user/trips.md` line 75 lists the Add options. Add
   that **From my equipment** lets you tick several items and add them with
   **Add N**. The same paragraph leaves out **Scan a tag**, so add that
   while editing it.

No new strings. `equipment_components_pickerConfirm` ("Add N") and the
picker's title and empty states are already neutral.

Out of scope: the chooser sheet itself (From my equipment / An equipment
set / Scan a tag / Rental cylinders). The dive editor shows those as
separate buttons. Flattening the trip's chooser to match would save one
more tap, but it is a layout change to the Gear tab and is left to a
follow-up if wanted.

## Tests (first)

In `test/features/trips/presentation/widgets/gear/trip_gear_tab_test.dart`,
update the three tests that tap one row and expect the sheet to close and
write:

- "From my equipment packs a picked item"
- "From my equipment makes a picked cylinder a slot"
- "a failed Add says so without the exception"

Each now ticks the row and then taps **Add 1**.

New tests:

- Ticking a BCD, fins and a tank, then **Add 3**, packs the BCD and fins
  in one `pack` call and appends one slot for the tank.
- Cancel after ticking writes nothing.
- **Add** is disabled before anything is ticked.
- With an assembly and its installed part both active, the part is hidden
  and the show-parts switch is offered.
- Gear already packed or on the board is not offered (already covered by
  `selectedEquipmentIds`; check that an existing test asserts it, and add
  one if none does).

The picker's own behaviour (checkbox order, header layout, empty states)
is covered by the picker's tests and is not repeated here.

## Screenshots

`trip_gear_add_sheet.dart` is under `lib/**/presentation/`, so the PR needs
before and after screenshots of the From my equipment sheet (single-select
before, checkboxes and Add N after) at phone and desktop widths.

## PR

Branch `github-issue-4205-trip-gear-multi-select` off `main`. The
description says `Closes #4205`.
