# Standardize multi-select checkbox placement

Date: 2026-08-14
Branch: `worktree-selection-checkbox-inside-card`

## Problem

Multi-select renders its checkbox in two different places depending on the
entity type.

Dives, dive sites, and buddies put the checkbox **inside** the item card, on the
left, where it takes over the tile's own leading slot. Eight other entity lists
put the checkbox **outside** the card, to its left, in the gap between the
card's margin and the screen edge. The two look like different features.

The split is not accidental. `lib/shared/selection/selectable_row.dart` says so
in its own doc comment:

> `SelectionLeading` swaps a row's existing leading element for a checkbox,
> which suits tiles that own one -- a dive number badge, a site avatar. Many
> rows have no such slot, so the checkbox has to be inserted in front of the
> whole tile instead. This does that without requiring every tile widget to
> grow selection parameters of its own.

`SelectableRow` bought a uniform *mechanism* at the cost of a uniform
*appearance*. It is `Row([SelectionLeading(child: SizedBox.shrink()),
Expanded(child)])` -- the same checkbox primitive as the dive tiles, but handed
an empty leading widget, so the checkbox has nowhere to go but outside.

A second, quieter inconsistency sits inside the "good" group. The three
surfaces that already place the checkbox inside the card do it three different
ways:

- Dives use `SelectionLeading`, an `AnimatedSwitcher` swap (150 ms).
- `SiteListTile` and `BuddyListTile` hand-roll the identical swap as a raw
  `isSelectionMode ? Checkbox : CircleAvatar` ternary, with no animation.
- The site and buddy compact/dense tiles wrap a bare `Checkbox` in
  `Visibility(maintainSize: true)`, which permanently reserves the checkbox's
  width even when no selection mode is active.

## Goals

1. Every list surface renders its selection checkbox inside the item card/row.
2. All of them get there through one shared primitive, so the appearance cannot
   drift again tile by tile.
3. The placement becomes an asserted invariant, not a convention.

## Non-goals

- **Media grids.** `media_grid.dart` draws a circular check icon overlaid on
  the thumbnail rather than a `Checkbox`. Standardizing it means changing the
  affordance, not moving it. Out of scope.
- **The `ListTile` manage pages** (tags, species, equipment service kinds).
  They already wrap their leading icon in `SelectionLeading`, so the checkbox is
  already inside the row and already animated. They have no `Card`, but adding
  one is a visual redesign of three settings-style pages, not a placement fix.
  Out of scope.
- **Table views.** `EntityTableView` and `DiveTableView` use a fixed 48 px
  leading checkbox cell, which is correct for a table. Unchanged.
- **`SavedPlansSheet`.** Uses its own ad-hoc compare-mode state, not
  `SelectionController`. Unchanged.
- No change to selection *behavior*: entry affordances, keyboard handling,
  pruning, and the contextual bar all stay as they are.

## Design

### The shared primitive

Add `lib/shared/selection/selection_checkbox_slot.dart`:

```dart
/// A checkbox inserted at the start of a row that has no leading element.
///
/// Tiles that own a leading widget -- a dive number badge, a site avatar --
/// should use [SelectionLeading] to swap it. Compact and dense tiles start
/// their row with the entity name and have nothing to swap, so the checkbox has
/// to be inserted. This keeps that insertion inside the tile's own padding, and
/// animates the trailing gap along with the checkbox so no dead space is left
/// behind when selection mode ends.
class SelectionCheckboxSlot extends StatelessWidget { ... }
```

It composes `SelectionLeading` with a zero-width child, plus the trailing gap,
so the gap disappears with the checkbox instead of leaving a dangling 12 px.
Same params as `SelectionLeading` (`isSelectionMode`, `isChecked`,
`isSelectable`, `onChanged`) plus a `gap` defaulting to 12.

Delete `lib/shared/selection/selectable_row.dart`.

### Empty-slot behavior: animate, do not reserve

For tiles with no leading element, the checkbox animates in and out and reserves
no space when selection mode is off. Normal browsing keeps its full text width;
entering selection mode nudges the text right over 150 ms.

This is what `SelectableRow` already does today, so the eight converted lists
keep the motion they have and only change *where* the checkbox lands. It also
means the site and buddy compact/dense tiles move off
`Visibility(maintainSize: true)`, giving back the ~40 px gutter they currently
reserve at all times.

### Per-tile treatment

Two treatments, chosen by whether the tile has a leading element to give up.

**Swap (7 tiles).** Wrap the existing leading widget in `SelectionLeading`. No
layout shift at all, because the checkbox occupies the space the icon vacated.

| Tile | File | Leading element |
| --- | --- | --- |
| `CourseCard` | `features/courses/presentation/widgets/course_card.dart` | 48x48 `Container` + icon |
| `CertificationListTile` | `features/certifications/presentation/widgets/certification_list_content.dart` | 48x48 `Container`, agency abbrev |
| `TripListTile` | `features/trips/presentation/widgets/trip_list_content.dart` | `CircleAvatar` in a `Consumer` |
| `DiveCenterListTile` | `features/dive_centers/presentation/widgets/dive_center_list_content.dart` | 48x48 `Container` + store icon |
| `EquipmentListTile` | `features/equipment/presentation/widgets/equipment_list_content.dart` | `CircleAvatar` + type icon |
| `_TransferTile` | `features/media_store/presentation/pages/transfers_page.dart` | plain `Icon` |
| `_ComputerCard` | `features/dive_computer/presentation/pages/device_list_page.dart` | 48x48 `Container` + connection icon |

`TripListTile` is the one with a wrinkle: its `leading:` is a `Consumer` that
resolves the trips feature accent. `SelectionLeading` wraps the `Consumer`
rather than living inside it, so the accent lookup is skipped entirely while the
checkbox is shown.

**Insert (6 tiles).** Add `SelectionCheckboxSlot` as the first child of the
tile's inner `Row`, inside the card's padding. All six currently begin their row
with `Expanded(Text(name))`.

- `features/trips/presentation/widgets/compact_trip_list_tile.dart`
- `features/trips/presentation/widgets/dense_trip_list_tile.dart`
- `features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart`
- `features/dive_centers/presentation/widgets/dense_dive_center_list_tile.dart`
- `features/equipment/presentation/widgets/dense_equipment_list_tile.dart`
- `_ConfigTile` in `features/cylinder_configs/presentation/pages/cylinder_config_list_page.dart`

### Tile parameters

Every tile above gains three params:

```dart
final bool isSelectionMode;
final bool isChecked;
final ValueChanged<bool>? onCheckChanged;
```

They must be **new** params. The existing `isSelected` on most of these tiles
means "focused row in master-detail" and only tints the card background; the
bulk-action checked set is tracked separately in each list content's
`_selectedIds`. Reusing `isSelected` would conflate the two.

`_ConfigTile` already has `isSelectionMode` and `onSelectToggle`, used only to
redirect its tap. It gains `isChecked` and renders the slot.

### Call sites

Eight `SelectableRow` wrappers are removed, passing the params down to the tile
instead:

- `course_list_content.dart`
- `certification_list_content.dart` (three sections: expired, expiring, valid)
- `trip_list_content.dart`
- `dive_center_list_content.dart`
- `equipment_list_content.dart`
- `cylinder_config_list_page.dart`
- `transfers_page.dart`
- `device_list_page.dart`

### Consistency pass

Six tiles in the already-inside group move onto the shared primitives:

| Tile | Change |
| --- | --- |
| `SiteListTile` (`site_list_content.dart`) | ternary -> `SelectionLeading` |
| `BuddyListTile` (`buddy_list_content.dart`) | ternary -> `SelectionLeading` |
| `compact_site_list_tile.dart` | `Visibility` -> `SelectionCheckboxSlot` |
| `dense_site_list_tile.dart` | `Visibility` -> `SelectionCheckboxSlot` |
| `dense_buddy_list_tile.dart` | `Visibility` -> `SelectionCheckboxSlot` |
| `dense_dive_list_tile.dart` | `Visibility` -> `SelectionCheckboxSlot` |

`DenseDiveListTile` has no reference anywhere in `lib/` -- it is reachable only
from its own two test files. It is included for consistency rather than deleted;
whether to delete it is a separate decision for the maintainer.

## Testing

### The contract is the regression guard

`test/helpers/selection_contract.dart` already runs against every converted
surface, and already carries a `CheckedIndicator { checkbox, custom }` enum so
grids can opt out of checkbox assertions. Its checkbox assertion currently reads:

```dart
expect(
  find.byType(Checkbox),
  findsWidgets,
  reason: 'selection mode must render checkboxes in the leading slot',
);
```

The reason string claims the leading slot; the assertion only proves a checkbox
exists somewhere on screen. That gap is exactly what the outside-card layouts
passed through.

Add a `rowRoot` finder parameter. Dart cannot express "required only when
`indicator == CheckedIndicator.checkbox`", so it is declared `Finder? rowRoot`
and enforced at the top of the helper:

```dart
assert(
  indicator != CheckedIndicator.checkbox || rowRoot != null,
  'checkbox surfaces must declare the row root the checkbox has to live inside',
);
```

An assert rather than a silent skip: a surface that forgets `rowRoot` must fail,
because "no assertion ran" is the failure mode this whole change exists to
close. Then assert:

```dart
expect(
  find.descendant(of: rowRoot, matching: find.byType(Checkbox)),
  findsOneWidget,
  reason: 'the checkbox must render inside the row, not beside it',
);
```

Each list passes its tile type (`find.byType(EquipmentListTile).first`, etc.).
Grid surfaces keep `CheckedIndicator.custom` and pass no `rowRoot`.

### Order of work

1. Extend the contract helper and thread `rowRoot` through every existing
   caller. This must **fail** on all eight outside-card surfaces before any tile
   is touched. That red run is the proof the fix is real.
2. Add `SelectionCheckboxSlot` with unit tests: the zero-width to checkbox
   transition, the gap animating with it, and `isSelectable: false` rendering
   nothing.
3. Convert the seven swap tiles, then the six insert tiles, then the eight call
   sites. Delete `selectable_row.dart`.
4. Consistency pass on the six site/buddy/dive tiles.
5. Confirm the contract is green everywhere.

### Existing tests to update

- `test/features/dive_computer/presentation/pages/device_list_page_test.dart`
  anchors on `find.byType(SelectableRow).first`. It is the only test that names
  the type; it must move to the tile type.
- Tile-level presence checks in `compact_site_list_tile_test.dart`,
  `dense_site_list_tile_test.dart`, `compact_dive_list_tile_test.dart`, and
  `dense_dive_list_tile_test.dart` assert `find.byType(Checkbox)` is present.
  They should keep passing, since the checkbox still renders; verify rather than
  assume.
- No test anywhere currently asserts checkbox position relative to a `Card`, so
  there is no existing structural assertion to contradict.

## Risks

**Content built outside the builder.** Converting list surfaces in this codebase
has twice produced a silent freeze: `*ListContent` widgets compute
`final content = asyncValue.when(...)` near the top of `build`, and if the rows
are captured there rather than built inside the
`ValueListenableBuilder<SelectionState>`, the app bar swaps correctly but no
checkbox ever renders. Any surface whose builder needs restructuring must build
its content inside the listener. `verifySelectionContract` catches it.

**Compact app bar overflow.** The compact/master-pane bars in `*ListContent`
widgets lay out as a `Row` with no flex on `FeatureAppBarTitle`. This work does
not add bar controls, so it should not trigger it, but any surface touched
should have its title wrapped in `Flexible` if it is not already.

**Localized width.** The insert treatment shifts text right by ~40 px when
selection mode is entered. Dense rows in long-translation locales are the
tightest case; check for overflow in a long locale on at least one dense
surface.
