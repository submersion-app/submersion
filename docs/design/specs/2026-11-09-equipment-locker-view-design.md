# Equipment list: Locker view

Issue: to be opened before the PR ("Equipment: Locker view"), since every PR
needs one. Builds on the foldable groups change (#4184).

## Why

The equipment list answers "find this item", but not "what do I own". A diver
with dozens of items has no overview of their kit: how many tanks, which kinds
of gear they have, where something needs service. Finding one second stage
means scrolling past every other type first. The Locker gives a one-screen
overview by type, and one tap takes the diver to that type's items.

## Goals

- One screen that shows every kind of gear the diver owns, with counts, grouped
  into families a diver recognises.
- Service needs visible at the overview level.
- One tap from a type to its items, using the list the diver already knows.

## Non-goals

- New row designs. The type page uses today's rows.
- Photos on tiles (#2024, #3355 are separate).
- Opening items in place under a tile (considered and rejected).
- Bulk actions from the Locker itself.

## Anti-goals

- A second list implementation that drifts from the main list (different
  sorting, selection or detail behaviour).
- A tile count that disagrees with what the diver sees after tapping it.

## Design

### View mode

- "Locker" is a fourth view mode on the equipment list, next to Detailed,
  Compact and Table, chosen from the same overflow menu and saved the same way
  (`equipmentListViewMode`, a per-diver text column).
- Only the equipment list offers it. `ListViewMode` is shared by about 30 call
  sites; the builder either adds `locker` to it and keeps it out of the other
  features' menus, or keeps an equipment-only mode. Either way, a build that
  does not know "locker" must read it as Detailed (today `fromName` falls back
  to Detailed, which already does this).

### Layout

- Families, in this order, each listing types in canonical order:
  1. Life support: regulator, first stage, second stage, hose, rebreather, tank,
     transmitter
  2. Buoyancy and trim: BCD through weights
  3. Exposure protection: rash guard through socks
  4. Vision and propulsion: mask, snorkel, fins, DPV
  5. Instruments: computer, instrument, compass
  6. Accessories: light through tool
  7. Transport: bag
  8. Parts: O2 cell, battery
  9. Other: other
  These follow the comment blocks already in `kCanonicalTypeOrder`
  (`lib/features/equipment/domain/constants/equipment_type_order.dart`). Define
  them as a const list of families, and add a test that the families
  concatenated equal `kCanonicalTypeOrder`, so a new type cannot be left out.
  The family order is fixed and does not follow the diver's type order setting.
  (my call)
- A family heading, then a responsive grid of tiles (column count from the pane
  width; three on a phone).
- Only types with at least one item after the active filters get a tile; a
  family with no tiles is not shown.
- Tile: the type's icon (existing type icon helper), the type label, the count.
  A dot in the corner when any item of that type needs service: amber for due
  soon, red for overdue, using the same service status the list rows use. The
  dot is described in the tile's semantics label.

### Filters and search

- The active status, owner, location and tag filters apply to the counts, so a
  tile's count equals the number of rows the type page shows.
- Any non-empty query (`EquipmentFilterState.query`) shows list results instead
  of tiles. The search row and the filter sheet's advanced query edit the same
  field and cannot be told apart, so a query never narrows tile counts; it
  always means "find items". Explore and Ask handoffs, which set a query,
  therefore land on list results. Clearing the query returns to the tiles.
  (my call)
- If the diver already set a type filter in the filter sheet, the Locker shows
  that one tile.

### Tapping a tile (drill-in)

- Drill-in is its own state, not the filter sheet's type filter: an in-memory
  "drilled type" next to the filter state. It narrows the list as an extra
  condition on top of whatever filters are set; the diver's own filters are
  never changed by drilling in or out. (my call)
- The drilled page is the equipment list itself in the list mode the diver used
  before switching to Locker, remembered in memory; Detailed when unknown (after
  a restart) or when it was Table, since Table has no grouping. (my call: no new
  synced column for this)
- Location grouping and the saved folds apply as usual. The drill-in is not a
  filter for the foldable-groups "filters open every group" rule.
- The app bar shows the type as the title with a "Locker" back affordance.
  System back and Escape on desktop do the same. Going back clears only the
  drilled type.
- Choosing a type in the filter sheet while drilled in combines with the drilled
  type as any filter does; an empty result shows the normal empty state, which
  keeps the back affordance.
- The drilled type survives pushing an item's detail and popping back, and
  leaving for another section and returning. It is cleared by going back, by
  choosing another view mode, and by an app restart. Reopening after a restart
  lands on the tiles.
- Drilling in never changes the saved view mode.

### Arriving from elsewhere while the saved mode is Locker

- An entry point that hands the list a filter or a query (home service-due
  chips, tag navigation, global search, Explore and Ask) shows list results in
  the remembered list mode for that visit, so "a list of exactly those" holds.
  The "Locker" back affordance clears that handed-over filter or query and
  returns to the tiles. (my call)
- An entry point that selects an item (the `?selected=` desktop redirect, a new
  or cloned item, the "hidden by view" snackbar) drills into that item's type
  and selects it, which also fires the foldable-groups temporary reveal.
  (my call)

### Wide screens

The Locker fills the list pane. The detail pane is empty until an item is
selected on the type page, then works as today.

### Keyboard

Tiles are focusable. Arrow keys move through the grid, Enter opens a tile.

## Testing

- Families cover the canonical order exactly (the permutation test).
- Tile counts match the type page under each filter kind.
- Service dot for due, overdue, none.
- A query switches to list results and back.
- Drill in and back restores the Locker without changing the saved mode or the
  diver's own filters; saved folds apply on the drilled page.
- A service-due chip handoff shows list results; a `?selected=` redirect drills
  into the item's type.
- An unknown stored view mode reads as Detailed.

## Left to the builder

- How `locker` fits `ListViewMode`, within the constraint above.
- Tile size, spacing and the column breakpoints.
- Where the families constant lives.

## Delivery

One PR, third of three. Open the issue first and link it with `Closes #N`.
Screenshots of the Locker and the drilled-in type page, light and dark, phone
and desktop widths.
