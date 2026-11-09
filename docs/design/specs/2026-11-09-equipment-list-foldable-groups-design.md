# Equipment list: foldable groups

Issue: #4184 (closes). Part of #3364 (the list page row of its surface table; the
pickers, component sheet and set edit stay open there).

## Why

A diver with a full kit, spares and gear kept in several places scrolls a long
list to find one item, for example one second stage among four. With "Group by
location" on, the list nests type groups inside location groups, but the two
header levels look almost the same (`titleSmall` vs `labelLarge`, neither bold,
type headers not indented), so the reader cannot see where one place ends and the
next begins. Nothing can be folded away, so places and types the diver does not
care about right now are always in the way. The person who filed #4184 asked for
exactly two things: bold location titles, and a way to hide locations they do
not want to see.

## Goals

- The location level reads as the strong level, the type level clearly nested
  under it.
- Every group header on the equipment list page folds and unfolds its group.
- A folded group still says what it holds, so nothing disappears without a trace.
- Folds survive leaving the page, restarting the app, and moving to another
  device (saved per diver, synced).

## Non-goals

- The equipment picker, the add-component sheet and the equipment set edit page
  (the rest of #3364). They keep today's behaviour.
- Table mode, which stays flat.
- Changing how groups are ordered or what the rows show.

## Anti-goals

- A filter result hidden inside a folded group. If the diver searches or filters
  and the match is inside a fold, they must see it.
- Navigating to an item silently rewriting the diver's synced folds.
- The dive site list changing appearance when its header widget is shared.

## Current state (for orientation)

- Rows are flattened into a sealed `_EquipmentListRow` (heading, location
  heading, item, show-more) in
  `lib/features/equipment/presentation/widgets/equipment_list_content.dart`
  (built around :1277, rendered around :1366).
- Headers: `widgets/equipment_location_group_header.dart` and
  `widgets/equipment_group_header.dart`.
- Groups of 5 or more are capped at 3 items with a "Show N more" row
  (`utils/equipment_group_cap.dart`, `widgets/equipment_group_show_more.dart`,
  in-memory `_expandedGroups`). Only the list page uses the cap.
- The dive site list already has a foldable header, `SiteGroupHeader`
  (`lib/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart:31`),
  and the expansion logic in `site_list_content.dart` and
  `lib/features/dive_sites/domain/utils/site_grouping.dart`.
- "Group by location" is stored per diver in `ListArrangements`
  (`equipmentGroupByLocation`, column in `diver_tables.dart:417`, mapped in
  `list_arrangement_columns.dart`, written via `list_arrangement_writes.dart`,
  synced in the list arrangement fact group).

## Design

### Headers

- Lift `SiteGroupHeader` into `lib/shared/widgets/` as one collapsible group
  header and use it on both lists. It gains: an optional leading icon, a caller
  supplied count label, an optional summary line shown under the title while
  folded, and a title weight. The site list keeps its exact current look.
- Location header (outer): leading location-kind icon, title `titleSmall` bold
  (w700), count at the end ("14 items"), chevron (`chevron_right` folded,
  `expand_more` open), indent 16, a divider above every location header but the
  first.
- Type header (inner when grouped by location, outer otherwise): title
  `titleSmall` semibold (w600), count at the end, chevron, indent 40 when nested
  under a location and 16 when it is the outer level.
- The whole header row is the tap target. `Semantics(button: true, expanded:)`,
  with the count in the label.
- Detailed and compact modes both get the headers. With type grouping off and
  location grouping off there are no headers and nothing changes.

### Folded summary line

- Folded location header: the types inside with their counts, in the list's type
  order, as "BCD 2 · Second stage 1 · Tank 4". At most three types, then
  "and N more". Using "Label count" avoids pluralising type names in every
  locale. (my call)
- Folded type header: "N service due" when any item inside is due or overdue,
  using the same service status the rows already show. Nothing otherwise.
- In selection mode, a folded header that holds checked items says
  "2 of 8 selected" (replacing the summary line).

### Storage

- Store the set of folded group keys, not the open ones, so the default is open
  and any new group (new location, new type) appears open. (my call: default
  open, because the list page is for browsing; this answers #3364's first open
  question for the list page only.)
- Keys:
  - location section: `loc:<locationId>`, and `loc:none` for "No location";
  - type group under a location: `loc:<locationId>/type:<typeName>`;
  - type group when not grouped by location: `type:<typeName>`;
  - the ungrouped bucket (type null), if it ever renders a header:
    `type:none`.
  Location and type folds are independent: unfolding a location brings back its
  type groups exactly as they were.
- New nullable TEXT column on `diver_settings`, a JSON array of keys, added to
  `ListArrangements` and the list arrangement column mapping, synced in the
  same fact group as `equipmentGroupByLocation`. Follow the #3783 path for that
  column (schema bump, ladder rung, before-open backstop, serializer default for
  older payloads, repository mapping, `ListArrangementWrites` setter, demo and
  mock providers, agent SQL column notes).
- Keys for deleted locations are left in place; they match nothing. Do not prune
  keys because a group is not on screen right now (it may only be filtered out).
  Cap the stored set at a few hundred keys, dropping the oldest. (builder's call
  on the exact cap)

### Behaviour

1. Tap a header to fold or unfold it; the change is saved at once.
2. Overflow menu gains "Expand all" and "Collapse all", shown only while the page
   shows headers. Collapse all folds the outermost level only (locations when
   grouped by location, types otherwise). Expand all clears every key.
3. The "Show N more" cap and its widget are removed from the list page; folding
   replaces it. Delete `equipment_group_cap.dart` and
   `equipment_group_show_more.dart` if nothing else uses them.
4. While a search or any filter other than the diver's default status view is
   active (`EquipmentFilterState.hasActiveFilters`, type filter included), every
   group renders open, and folds made during that time live only in memory and
   are dropped when the filter clears. The saved folds come back untouched. This
   matches the site list. The Locker's drill-in (third spec) is deliberately not
   a filter: it is its own state, so the saved folds apply on a Locker type page
   with the normal keys. This PR's predicate only has to read the filter state;
   it needs no Locker awareness. (my call)
5. Temporary reveal, event-driven (my call, from the anti-goal):
   - It fires once when a selection arrives from outside the list's own rows: a
     deep link, the `?selected=` desktop redirect, a newly created or cloned
     item, a global search result, the detail item restored at launch, or the
     "hidden by view" snackbar's Show action. Taps and keyboard moves inside the
     list never fire it (the row is already visible).
   - It opens the folds hiding that item for this page instance and scrolls to
     it. It is held in memory and never written to settings.
   - It ends when the diver taps that group's header (which folds it again; the
     saved state was already folded, so nothing is written), when the page is
     disposed, or when a new outside selection replaces it. A later selection
     elsewhere does not close it, so rows never shift under the pointer.
   - The diver can therefore always fold the group holding the detail pane's
     item; the item stays in the pane, it just is not in the visible rows.
6. Keyboard: headers become navigation stops (`KeyboardListItem` with a
   `group:<key>` id, like the site list). Enter toggles, Right opens, Left
   closes, Left on an item jumps to its header and closes it. This replaces the
   current "headings are labels, not folds" rule (comment near :1346).
7. Shift-click range selection walks only visible rows, so a range across a
   folded group does not tick items hidden inside it. Select all still selects
   every matching item, folded or not, and the folded headers then show
   "N of M selected".
8. Turning "Group by location" on or off keeps the saved keys; each layout simply
   reads the keys that apply to it.

## Testing

- Pure helpers (key building, folded summary, row flattening with folds,
  filter-active override, temporary reveal) unit tested without widgets.
- Widget tests: fold and unfold by tap and by keyboard, summary text, selection
  count on a folded header, search opening every group, deep link revealing an
  item without writing settings, shift range skipping folded rows.
- Site list regression: its existing tests stay green with the shared header.
- Migration test for the new column, repository round trip, sync serializer
  default for a payload without the field.

## Left to the builder

- Name and exact API of the shared header widget.
- Where the fold state provider lives and how writes are debounced.
- The exact cap on stored keys.
- Animation (none is fine; the site list does not animate).

## Delivery

One PR, first of three (then #4185 hidden sections, then the Locker view).
Description: `Closes #4184` and `Part of #3364`. Before and after screenshots,
light and dark, phone and desktop widths.
