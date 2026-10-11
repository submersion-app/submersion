# Dive list table view UX improvements

Issue: #2984. Release: v1.8.2.

## Problem

The dive list's Table view works but is hard to use:

1. It has no vertical or horizontal scrollbars.
2. Column resizing does not follow the mouse.
3. Column headers have no context menu (hide the column, add or reset a
   filter on it).
4. Surface interval always shows `--`, even when the dive's detail page
   shows a value.
5. Cells have no "filter by this value" menu.

## Causes found in the code

- The dive list renders its own `DiveTableView`, a near copy of the shared
  `EntityTableView` that the other seven lists (sites, trips, equipment,
  buddies, centers, certifications, courses) use. The two have already
  drifted apart (the shared one has `leadingBuilder`, the dive one has its
  own `TableHeaderCell` copy).
- Resize computes `width + details.delta.dx` from the last saved width,
  clamps to the column minimum and saves to the database on every drag
  update. Once the clamp engages, or a rebuild lags the pointer, the edge
  separates from the cursor for the rest of the drag.
- The table reads only the stored `dives.surface_interval_seconds`, which is
  usually empty. The detail page falls back to `getSurfaceInterval`, which
  measures from the previous dive. A `surfaceIntervalsProvider` written for
  the table has no consumers. The query field `surfaceInterval` and the
  Insights statistics each use yet another definition.

## Decisions

| Topic | Decision |
| --- | --- |
| Scope of generic fixes | Scrollbars, resize and "Hide column" apply to every entity table. Filter menus are dive-only. |
| Structure | The dive table moves onto `EntityTableView`; `DiveTableView` and the dive `TableHeaderCell` are deleted. |
| Header "Add filter" | Opens the Refine panel with a default rule for that column added to the draft. |
| Cell menu | Only / Exclude for every filterable column; At least / At most for numbers and dates. |
| Touch | Long-press opens the same menus; secondary tap also works. |
| Surface interval | One SQL definition shared by the table, the query field and Insights. |

## 1. One shared table

### Consolidation

- `enum DiveField` gains `implements EntityField`. The enum body adds
  forwarding getters (`displayName`, `shortLabel`, `icon`, `defaultWidth`,
  `minWidth`, `sortable`, `categoryName`, `localizedDisplayName`,
  `localizedShortLabel`) that call the existing extension members
  explicitly, so the logic stays where it is. `isRightAligned` is new on
  `DiveField`, taking over `DiveTableView._isRightAligned`.
- `DiveFieldAdapter implements EntityFieldAdapter<Dive, DiveField>` carries
  the per-build context the dive columns need: the gas model, the dive-type
  label resolver and the computed surface intervals (section 3).
  `extractValue` delegates to `DiveField.extractFromDive`, except
  `surfaceInterval`, which reads the computed map.
- `dive_list_content.dart` renders `EntityTableView<Dive, DiveField>`.
  `TableViewConfig` is converted to `EntityTableViewConfig<DiveField>` at
  the call site; the stored JSON of the dive table config does not change,
  and `tableViewConfigProvider` keeps its API.

### Scrollbars

- A vertical `Scrollbar` on the right edge of the table body, bound to the
  scrollable body's vertical controller. It sits outside the horizontal
  scroll view, so it never scrolls out of view.
- A horizontal `Scrollbar` along the bottom of the unpinned columns, bound
  to the body's horizontal controller.
- `thumbVisibility` is true on desktop (macOS, Windows, Linux) and the
  platform default on iOS and Android.
- The pinned column's list shows no scrollbar of its own.

### Resize that follows the pointer

- The resize handle becomes a stateful widget. On drag start it records the
  pointer's global x and the column's width. Each update computes
  `clamp(startWidth + (pointerX - startX), minWidth, 600)`, so the edge
  tracks the cursor even after passing the minimum and coming back.
- `EntityTableView` holds the in-progress width in local state, so the
  column redraws on every update without a provider round trip.
- `onResizeColumn` is called once, on drag end (and on drag cancel with the
  last width), not on every update. Persistence is unchanged.

### Header menu: Hide column

- Secondary tap (right-click), or long-press, on a header opens a menu.
- "Hide column" calls a new optional `onHideColumn` callback. Each list's
  config notifier removes the column. It is disabled when only one column
  is left. The existing column picker brings a hidden column back.
- `EntityTableView` takes an optional `headerMenuItems` builder and
  `cellMenuItems` builder. Lists without filters pass neither and get only
  "Hide column".

## 2. Column and cell filter menus (dive table)

### Column to query mapping

`DiveField` declares the registry path it filters on, or none:

| Column | Query path | Kind |
| --- | --- | --- |
| siteName | `site` | relation |
| tripName | `trip` | relation |
| diveCenterName | `center` | relation |
| diveTypeName | `types` | relation |
| diveComputerModel | `computer` | relation |
| buddy | `buddies` | relation, multi-valued |
| tags | `tags` | relation, multi-valued |
| diveNumber | `diveNumber` | number |
| dateTime | `date` | date |
| maxDepth | `depth` | number |
| avgDepth | `avgDepth` | number |
| bottomTime | `bottomTime` | number |
| runtime | `runtime` | number |
| waterTemp | `waterTemp` | number |
| airTemp | `airTemp` | number |
| visibility | `visibility` | number (numeric values only) |
| sac | `sac` | number |
| cnsEnd | `cnsEnd` | number |
| otu | `otu` | number |
| totalWeight | `weight` | number |
| tankCount | `gasCount` | number |
| ratingStars | `rating` | number |
| surfaceInterval | `surfaceInterval` | number |
| diveName | `name` | text |
| diveMaster | `diveMaster` | text |
| notes | `notes` | text, header only (no cell items) |
| currentStrength | `currentStrength` | enum |
| entryMethod | `entryMethod` | enum |
| exitMethod | `exitMethod` | enum |
| waterType | `waterType` | enum |
| diveMode | `diveMode` | enum |
| isFavorite | `favorite` | bool |

Every other column is unfilterable and its menu offers only "Hide column".
A census test requires every `DiveField` to appear in the mapping or in an
explicit unfilterable set, and every mapped path to resolve in
`appQueryRegistry`.

### Cell menu

Opened by secondary tap or long-press on a cell. A chosen item adds its rule
to `diveFilterProvider` at once: the rule becomes a new top-level child of
`DiveFilterState.query` (an existing single node is wrapped in an `AndNode`),
shows as a normal removable query chip, and is not added when an equal rule
is already a top-level child.

- Text, enum and relation: "Only <value>" (`path = value`) and
  "Exclude <value>" (`NOT (path = value)`, which keeps dives with no value).
  Relations use the related row's id with its display name.
- Number: "Only <value>" matches dives whose value displays as the clicked
  one (a `between` of half a display step either side), "At least <value>"
  and "At most <value>" use bounds widened by half a display step so the
  clicked dive is always included. Values are in the diver's units, so the
  chip reads in those units.
- Date: "Only <day>", "On or after <day>", "On or before <day>", by
  calendar day.
- Multi-valued (buddies, tags): one "With <value>" / "Without <value>" pair
  per value in the cell.
- Empty cell: "Only dives with no <column>" (`:none`) and "Only dives with
  a <column>" (`:any`).
- Visibility values that are legacy bucket labels offer no number items.

### Header menu filter items

- Add filter: opens the Refine panel (`showRefinePanel`) with the Rules
  group expanded on its Builder tab and a default rule for the column
  appended to the draft (`defaultValueFor` for fields; relation columns
  first show the existing ref picker, as the builder's "Add condition"
  does). Show applies it; dismissing the panel discards it.
- Reset filter: removes every top-level child of the query whose condition
  (or negated condition) is on this column's path, and clears the column's
  Refine axis: site (`siteId`), trip (`tripId`), center (`diveCenterId`),
  dive type (`diveTypeId`), depth (`minDepth`, `maxDepth`), date
  (`startDate`, `endDate`), rating (`minRating`), favorite
  (`favoritesOnly`). Rules nested in groups are left alone. Disabled when
  there is nothing to reset.
- A filtered column (a top-level rule on its path, or its axis set) shows a
  small filter icon in its header.

## 3. Surface interval

### One definition

`diveSurfaceIntervalSecondsSql(alias, {previousScope})` in
`lib/features/dive_log/data/repositories/dive_times_sql.dart` returns the
dive's surface interval in seconds:

- the stored `surface_interval_seconds` when present;
- otherwise the gap from the previous dive's exit to this dive's entry,
  where the previous dive uses exactly the predicate and ordering of
  `getPreviousDiveTimes` (any diver, `entry_time` before this dive's
  effective start, or `dive_date_time` before it when `entry_time` is null,
  ordered by `entry_time DESC, dive_date_time DESC`), the previous dive's
  exit is its `exit_time`, else its effective start plus
  `effectiveRuntimeSecondsSql`, and a negative gap is clamped to zero;
- null for the first dive.

`previousScope` is an extra predicate on the previous dive's alias, used by
Insights to apply `DiveStatsScope`.

### Consumers

- The query field `surfaceInterval` uses the expression (divided by 60) for
  both its value and its emptiness, so typed queries, Refine rules and cell
  filters match what the table shows. Saved queries on `surfaceInterval`
  start matching dives whose interval is computed.
- `DiveRepository.getSurfaceIntervals()` runs one
  `SELECT d.id, <expr> FROM dives d` and returns `Map<String, Duration?>`.
  `diveSurfaceIntervalsProvider` exposes it, invalidated on dive changes,
  and computed over all dives, so filtering never changes a dive's
  interval. The unused `surfaceIntervalsProvider` is deleted.
- Insights `getSurfaceIntervalStats` uses the expression, with
  `DiveStatsScope` on the previous dive. Its numbers change for multi-diver
  logs and for dives whose previous dive has no exit time.
- `getSurfaceInterval(id)` (detail page, deco lookback) is unchanged; a
  parity test pins the batch result to it.

## Testing

Written first (TDD):

- `EntityTableView` widget tests: both scrollbars present and tracking;
  a resize drag past the minimum and back keeps the edge under the pointer;
  a resize saves once, on drag end; the header menu hides a column, and the
  last column cannot be hidden; secondary tap and long-press open the
  menus; the filter indicator appears for a filtered column.
- Rule builder unit tests per kind (relation, text, enum, number with
  display rounding and imperial units, date, multi-valued, empty cell),
  duplicate suppression, and reset removing exactly the column's top-level
  rules and axis.
- The mapping census test.
- `surfaceInterval` compiler tests, the batch versus `getSurfaceInterval`
  parity test on a fixture with mixed entry, exit and runtime data, and an
  Insights stats test covering the new definition.
- Existing `DiveTableView` tests move to the shared table or to
  `DiveFieldAdapter`.

## Out of scope

- Filter menus on the other seven entity tables.
- Changing `getSurfaceInterval`'s own lookup.

## Amendments recorded while planning

Authoritative where the body above differs.

1. `DiveTableView` is kept as a thin `ConsumerWidget` over `EntityTableView`
   (same name and constructor, so `dive_list_content.dart` is untouched).
   Its duplicated table code and the dive `TableHeaderCell` are deleted.
2. SAC, CNS end and OTU are header-only (Add and Reset, no cell items). The
   SAC cell can show a unit the `sac` field does not read, and the table's
   CNS end and OTU cells are always empty today.
3. A cell whose display is not the value its field reads offers no value
   items: a runtime derived from timestamps or the profile, an entry
   method inherited from the site, a legacy free-text buddy, a legacy
   visibility bucket, a dive name shown from its site, a computer model
   with no linked computer row.
4. Dive number, rating and tank count use exact values ("integer" kind).
   Durations (bottom time, runtime, surface interval) use whole minutes,
   which is how the cell rounds and how the query fields store them.
5. The dive type column is multi-valued like buddies and tags (With and
   Without per type), since a dive can carry several types.
6. A new performance index `idx_dives_entry_date ON dives(entry_time,
   dive_date_time)` (asserted on open, no schema rung) lets the shared
   surface interval SQL seek the previous dive instead of scanning per
   row. The SQL spells the detail page's ranking as two subqueries for the
   same reason.
7. "Hide column" can hide a pinned column, and clears a sort on the hidden
   column.
8. The localized label switches move from `dive_field.dart` to
   `dive_field_labels.dart` so the file stays under 800 lines once it
   implements `EntityField`.
9. Long-press on a dive table cell opens the cell menu, so on touch a hold
   no longer resolves as a tap there. Commit 899d7f5 removed long-press as
   a way into selection; this adds it back only as a menu gesture, only on
   tables given a cell menu (the dive table).
10. Total Weight and Dive Master are header-only too. List loads never
    hydrate a dive's weights, so the Total Weight cell is always empty while
    the `weight` field reads `dive_weights`; the Dive Master cell shows guide
    names resolved from linked buddies, not the `dive_master` column.
11. Number cell rules keep their bounds inside the field's sanity range, and
    a whole number outside it offers no items, so a rule the menu adds always
    passes the query validator.
12. The resize handle sits on the column's trailing edge, which is the left
    edge in a right-to-left locale, and tracks the pointer there too.
