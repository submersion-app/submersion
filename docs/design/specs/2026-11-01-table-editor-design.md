# Table Editor Design

**Issue:** [submersion-app/submersion#3422](https://github.com/submersion-app/submersion/issues/3422)
**Date:** 2026-11-01
**Status:** Approved
**Release:** v1.8.4

## Summary

A Table editor page under Settings, Data Tools, with a tab each for dives,
dive sites and dive centers. Each tab is a spreadsheet: the same columns,
sorting and column filters as the list views, with cells you can type into.
Edits wait as highlighted drafts until Save all, which files them under one
change log operation per tab so they can be undone in one step. A block
copied from Excel pastes in as drafts, matched to dives by dive number when
the paste carries one and by table position otherwise, with a summary to
check before anything saves.

## Why

Martin (the reporter) is migrating from Diving Log and has to fill or
correct one field on dive after dive while reading the old logbook beside
Submersion. The single-dive editor is one page per dive, and bulk edit sets
one value across many dives; neither handles a different value per dive.
Diving Log's "table" sheet does, and it is the part of that app he misses.
The need is heavy during a migration and rare afterwards, which is why this
is a tool under Data Tools and not a change to the list views.

## Goals

- Fill or correct one field across many dives, sites or centers without
  leaving one page.
- Find the records that need work from a column header: empty values, or a
  specific value.
- Bring a column or block of values in from a spreadsheet in one paste.
- Review every pending change, in one place, before it is saved.
- Undo a whole Save all in one step, through the change log.

## Non-goals

- Editing from a phone. The page is desktop and tablet only.
- Collections per dive: tags, buddies, equipment, tanks, sightings, dive
  types. Bulk edit and the dive editor handle those.
- Creating or deleting records. The editor changes existing rows only.
- Replacing the list views' table mode, bulk edit, or the import wizard.
- Sync conflict resolution beyond the stale-draft rule below.

## Anti-goals

Things that would make this a failure even if it works:

- A paste that writes values to the wrong dives without saying so. Every
  save shows what it will do first, and a misaligned paste must be visible
  there, not after.
- A cell that overwrites computer-recorded data. Those columns are never
  editable, however the value arrived.
- A number read in the wrong unit or with the wrong decimal separator. A
  weight of "6,5" must become 6.5 in the diver's unit, never 65.
- Silent partial saves. If anything was skipped, the diver is told what and
  why.

## Constraints

- Every displayed and parsed value respects the active diver's unit settings
  and number format (project rule).
- Built on `EntityTableView` and the existing `EntityField` enums
  (`DiveField`, `SiteField`, `DiveCenterField`) so columns, widths, sort and
  column menus behave as they do in the list views. The shared table today
  has row-level taps, a cell menu hook and a cell trailing hook only; cell
  text comes from the field adapter. It needs cell-level hooks for editing,
  draft and flagged states, added in a way the list views do not pay for.
  The shared table recycles rows (`ListView.builder` with a fixed
  `itemExtent`), so draft and focus state live above the rows, never inside
  a cell widget.
- Dives save through `BulkDiveEditService`, which already wraps a batch in
  `ChangeLogScope.bulk` and returns an undo snapshot. Sites and centers save
  through their repositories inside one `ChangeLogScope.bulk` per Save all,
  so the change log's operation revert undoes them. `ChangeLogScope.bulk`
  joins an enclosing scope rather than opening a nested one, so one outer
  scope gives one operation.
- Column filters compile to the query language (`lib/core/query`), the way
  the dive table's header and cell menus do. Today those menus are
  dive-specific (`dive_table_menus.dart`, `dive_column_filter_edits.dart`,
  `dive_cell_filter_options.dart`); sites and centers have none, so the
  menu code is generalised. A column has a filter menu only where its entity
  exposes a query field for it. Sites already expose a `coordinates` query
  field with "is empty" and "is set"; dives expose `visibility`, `weights`
  and `notes`.
- Numbers parse through the locale-aware parser in
  `lib/core/utils/number_input.dart`, which already handles a decimal comma.
- New files follow the repo's size and layout rules (feature folders,
  200 to 400 lines typical, 800 max) and `test/architecture/` guards.
- No new database tables or schema rungs are expected. If the builder finds
  one is needed, that is a design question, not a builder's call.

## The design

### Where it lives

Settings, Data Tools, a new row "Table editor" (title and subtitle are the
builder's wording, localized like the other rows). The page has three tabs:
Dives, Sites, Centers. The active diver's records only.

On a phone-width layout the row still appears, and the page says the editor
needs a wider screen, with nothing else on it. "Desktop and tablet" means
at least `ResponsiveBreakpoints.desktop` (800 px), the width at which the
app switches to the navigation rail.

### The table

Each tab shows the shared table widget with that entity's columns. The
column picker, sort, resize and hide column work as they do in the list
views, and the editor keeps its own column configuration per tab, separate
from the list views' configs, so a migration setup does not change the
diver's everyday list.

The dive tab's header and cell menus offer the same filter rules as the dive
list's table mode. Sites and centers gain the same menus here; the rules map
columns to their query fields the way `dive_column_filters.dart` does for
dives. Each tab also has the entity's query chip row, so a saved query can
narrow the sheet. "Visibility is empty", "Weights is empty" and
"Coordinates is empty" are the filters the issue needs and must all work.

The dive tab starts with the diver's dive table column config as its
default; the other tabs start with their list defaults.

### Editing a cell

Clicking an editable cell opens it for typing in place. Enter commits the
cell and moves down one row in the same column; Tab commits and moves to the
next editable column; Shift+Tab goes back; Escape cancels the cell. A
committed cell becomes a draft: highlighted, with the original value shown
on hover. Clicking a draft again edits the draft; clearing it to empty is a
draft that sets the field to empty; a draft that equals the original is
discarded.

List fields (water type, visibility bands, current, difficulty, entry and
exit, cloud cover and the like) open a pulldown of the entity's values, not
a text box. Yes/no fields toggle. Numbers are typed in the diver's unit, and
the column header shows that unit. Dates and times are not editable in the
first version (they have their own Fix dive times tool).

Double-clicking the dive number, site name or center name opens that
record's normal page. If the tab has drafts, a dialog asks first: Save all,
discard, or stay.

Which columns are editable:

- **Dives:** the scalar fields `BulkField` lists (site, dive center,
  operator, boat, captain, trip, rating, favourite, stats exclusions, water
  type, visibility, current direction and strength, swell, surface
  conditions, entry, exit, altitude, surface pressure, surface interval,
  gradient factors, deco algorithm and conservatism, computer model, wind,
  cloud cover, precipitation, humidity, weather description, dive mode,
  setpoints, diluent, scrubber, notes), plus weights under the rule below.
  Reference fields (site, center, trip, computer) use a pulldown of the
  diver's records, with search. Everything measured by a computer (depths,
  times, temperatures, SAC) and every collection column is read-only.
  Setting a site snaps the site's water type, entry and exit methods and
  dive types onto the dive, as bulk edit does; the save summary names those
  knock-on changes.
- **New dive columns:** the stats exclusions, wind direction, scrubber type
  and scrubber duration have no `DiveField` today. They are appended to
  `DiveField` (new members go at the end, since saved layouts store members
  by name), so they also appear in the dive list's column picker and in
  `DiveFieldAdapter`. The columns stay hidden by default in the list views.
- **Weights:** a dive with no weight rows gets one new row from the cell.
  Its type is the type of the diver's most recently logged weight row, or
  `WeightType.belt` when the diver has none. A dive with one row edits that
  row's amount in place (keeping the row's id, so sync sees an update, not
  a delete and insert). Clearing the cell on a one-row dive deletes that
  row; Undo restores it. A dive with two or more rows shows the total,
  read-only, with a link to the dive. Weight is typed in the diver's weight
  unit. The dive list never loads weight rows, so the editor loads them
  itself for the dives on the sheet.
- **Sites:** name, country, region, city, island, body of water, latitude,
  longitude, max and min depth, altitude, water type, difficulty, entry
  type, exit method, mooring number, hazards, rating, notes. Everything
  computed from dives (dive count, last dived, depths reached) is
  read-only. `location` is derived from city, region and country, and
  `typicalVisibility`, `typicalCurrent` and `bestSeason` have no stored
  column, so those four are read-only too (adding columns would be a schema
  rung, which is out of scope here). Entry type and exit method hold
  several values per site: the pulldown is multi-select, and a paste lists
  values separated by a comma or semicolon.
- **Library (shared) sites:** a site the profile may not edit saves only
  notes and rating today, keeping the library's other values. In the
  editor every other cell of such a site is read-only, with a lock in the
  row, so a draft is never reported as saved when it changed nothing.
- **Centers:** name, street, city, state or province, postal code, country,
  phone, email, website, latitude, longitude, rating, notes. Affiliations and
  dive count are read-only.

Latitude and longitude are two columns, typed as decimal degrees. Dive
centers store the two halves separately. Sites store them as one `GeoPoint`,
so a site's two columns are saved as a pair: a draft on one half of a site
without coordinates is flagged until the other half has a draft too, and
clearing either half on a site with coordinates clears both, which the
summary states. A site with coordinates cleared is "without coordinates"
for the filter again.

### Paste

The page handles a paste (Ctrl or Cmd+V, and a Paste button in the page's
toolbar) when a cell is selected or being edited. The clipboard text is
split on newlines and tabs, the way Excel and Numbers copy a block. A
single value with no tab or newline is pasted into the selected cell only.

**Matching rows.** A block matches rows by dive number when either holds:
its header row's first cell names the dive number column, or it has at
least two columns and every value in the first column is an integer that
is the number of a dive on the sheet. A headerless single column of
integers is never read as dive numbers, since a column of weights or
ratings would qualify; it fills by position. Numbers are matched against
the rows on the sheet under the current filter and query only. A number
that names a dive the filter hides, or no dive at all, is reported and
skipped, so a draft never lands on a row the diver cannot see. Otherwise
the block lands at the selected cell and fills downward in the table's
current order, and a block longer than the rows below is reported as
truncated. On the sites and centers tabs matching is by name in the first
column under the same rule (header named, or at least two columns and every
first-column value is a name on the sheet), and by position otherwise.

**Matching columns.** A header row whose cells name editable columns (in the
app's language, matched case-insensitively against the column labels) maps
the block's columns to those. Without a header, columns fill rightward from
the selected column, skipping read-only columns and reporting that they were
skipped.

**Values.** Numbers are parsed in the diver's number format and unit, so a
decimal comma is a decimal point for a diver whose locale uses one. List
values match the pulldown's labels, case-insensitively; an unknown value is
flagged. Text fields take the text as is. A cell that cannot be parsed
becomes a flagged draft that shows the raw text and is excluded from Save
all until fixed or cleared. Paste never creates a new list entry, site,
center or trip.

**Before saving.** The Save all button opens a summary: cells changed, cells
that need attention, cells that overwrite an existing value (as opposed to
filling an empty one), rows skipped and why, and which row matching was
used (by number, by name, or by position). Save proceeds from this summary.
The same summary opens before saving typed drafts; it is shorter then.

### Saving

Save all writes the tab's drafts in one operation:

- Dives build one `BulkEditRequest` per dive with only that dive's changed
  fields, applied through `BulkDiveEditService` inside one
  `ChangeLogScope.bulk` labelled for the editor, so the change log shows one
  operation and Undo reverts it whole. Weights that create a row use the
  service's `WeightsOp` in add mode. A single-row amount edit needs an
  in-place mode: today `WeightsOp` supports add and replace only, and
  replace deletes and reinserts rows with new ids, which costs tombstones
  and sync churn. The service gains `BulkCollectionMode.update` for weights,
  as `TankSpecsOp` already has for tanks, reusing the single-dive save's
  diff logic. Clearing a one-row dive's weight is a remove of that row.
- Sites and centers call their repositories' update methods per changed
  record inside one `ChangeLogScope.bulk`, and the change log's operation
  revert is the undo.
- **All or nothing.** Every write of a Save all runs inside one database
  transaction, opened inside the change log scope (the scope itself must
  stay outside any transaction). An error anywhere rolls the whole save
  back, the drafts stay on screen, and the error is shown. The per-dive
  calls into `BulkDiveEditService` run inside that outer transaction, so its
  own transaction must nest (a savepoint) rather than open a second one.
- The page shows an Undo in a snackbar after Save all, which runs the
  change log's revert of that operation. A revert can be partial when a
  record changed again since the save; the snackbar then says how many of
  the changes it undid and links to the change log.

**Stale drafts.** Each draft remembers the value the cell showed when the
draft was made. Before the transaction opens, every drafted record is
reread; a draft whose stored value no longer matches the remembered one (a
sync or an import wrote it meanwhile) is flagged as changed elsewhere and
left out of the save, which goes ahead with the rest. The summary before
saving lists them, and afterwards they stay as drafts shown against the new
value, so the diver can keep or drop each one.

**Leaving the page.** With drafts pending, navigating away, switching tab,
or closing the window asks first, through the same discard guard the edit
forms use. Drafts do not survive an app restart.

### Visible result

The page is new, so the PR needs after screenshots only: each tab with a
filter applied and drafts pending, the paste summary, the save summary,
light and dark, desktop and tablet widths.

## Left to the builder

- Exact titles, labels, dialog and summary wording, all localized through
  the ARB files.
- How drafts are stored in the page's provider, and how the shared table is
  told which cells are drafts, flagged or selected.
- The keyboard model for cell focus within a recycled list, as long as
  Enter, Tab, Shift+Tab and Escape behave as described.
- How the three tabs share one editing core. The expectation is a
  per-entity description (columns, parsers, pulldown values, save step) on a
  single workspace, so a fourth entity would be configuration, but the
  shape is the builder's.
- Whether header-row detection and number-column detection in paste live in
  one parser or two, as long as both rules above hold and are unit tested
  with a decimal-comma locale and an imperial diver.
- Column configuration storage for the editor's tabs, reusing the existing
  config repository if it fits.
- How the dive-specific header and cell menu code becomes shared, as long
  as the dive list's menus behave exactly as before.

## Decisions made during review

A builder check of this document raised the questions below. The first four
were put to the maintainer; the rest were settled by the author and are
marked so they can be checked.

| Question | Decision | Whose |
| --- | --- | --- |
| An error mid-save | All or nothing, one transaction | Maintainer |
| Stats exclusions, wind direction, scrubber have no table column | Append them to `DiveField` | Maintainer |
| Clearing a one-row dive's weight | Deletes the row, Undo restores it | Maintainer |
| A pasted dive number the filter hides | Skip and report | Maintainer |
| A headerless single column of integers | Position, never dive numbers | Author |
| New weight row's type | Diver's latest weight type, else belt | Author |
| Site fields with no stored column, and `location` | Read-only | Author |
| Site coordinates as a `GeoPoint` | Saved as a pair, halves flagged until both drafted | Author |
| Library sites | Read-only except notes and rating, lock shown | Author |
| Setting a dive's site snaps site values onto the dive | Keep, name it in the summary | Author |
| Multi-value site entry and exit | Multi-select pulldown, comma or semicolon in a paste | Author |
| Width threshold | `ResponsiveBreakpoints.desktop`, 800 px | Author |
| Partial Undo | Snackbar states how many changes it undid | Author |

## Amendments recorded while planning

Settled while writing `docs/design/plans/2026-11-01-table-editor.md`;
authoritative where the body above differs.

- **Weights op.** The in-place edit is a dedicated `WeightAmountOp` on
  `BulkDiveEditService` (amount or null, plus the type a new row takes),
  applied per dive through a new `DiveRepository.setSingleWeightAmount`
  that reuses the single-dive save's weight diff. Not a new
  `BulkCollectionMode` on `WeightsOp`.
- **Dive tab filters.** The dive list's header and cell menus take a
  `filterProvider` parameter, so the editor's dive tab reuses them whole
  over its own `DiveFilterState`. Sites and centers get a smaller generic
  menu (only empty, only with a value, reset, only this value, exclude this
  value), since they have no menus to reuse.
- **Centers clearing a coordinate.** `DiveCenter.copyWith` gains
  `clearLatitude` and `clearLongitude`; its `??` pattern cannot clear today.
- **Paste trigger.** Ctrl or Cmd+V on the page and a Paste button in the
  toolbar. The app has no platform menu bar to add an Edit item to.
- **Library sites.** Editability is resolved once per sheet through
  `LibraryEditStamper.mayEdit`, so a cell's read-only state is synchronous.
- **Toggles.** A yes/no cell flips on the tap itself rather than opening an
  editor; reached by keyboard it shows a checkbox, and Tab moves on without
  flipping it.
- **Leaving a cell.** Clicking elsewhere, pasting or saving while a text cell
  is open commits what was typed, as a spreadsheet does. Only Escape drops it.
- **Discarding a draft.** A drafted cell's menu offers Discard change, which
  returns the cell to its stored value.
- **Dive tab chips.** The chips show the query rules only. An axis set in the
  Refine panel still filters the rows, and a Clear filters button in the
  toolbar resets the editor's whole dive filter.
- **Paste matching.** A blank first line is data, never a header; a key
  shared by two rows is reported as ambiguous and matched to nothing; a cell
  the row cannot edit is reported by its row's key.
- **Row order.** Enter, Tab and a positional paste follow the order the
  sheet shows (its sort), not the order the list loaded.
- **Double click.** Opens the record from a key column or a read-only cell.
  An editable cell has none, so a click on it opens at once and a double
  click stays on the sheet.
- **Paste matching, single values.** One value is always a value, and a lone
  column has no key to address, so "No" fills a yes/no column. A keyed block
  never fills its own key column, whichever column is selected.
- **Paste with nothing to save.** Skips wait for the save summary; a paste
  that leaves nothing to save says why in a snackbar, since Save all is off.
- **Reference labels.** A label two records share is flagged rather than
  matched to the first of them; the record's id still matches.
- **Scrubber duration.** Flagged until the dive has a type, since a dive shows
  a scrubber only with one.
- **Save all with an open cell.** The cell closes and its text lands as a
  draft first, so it is in the summary and the save.
- **Closing the window.** Not guarded yet: the app's exit handler always
  answers exit, by design, and a prompt there is a change to that contract.

## Out of scope, noted for later

- Phone layout.
- Dates and times.
- Editing collections per dive.
- Creating records from a pasted row that matches nothing.
- Other entities (equipment, buddies, trips).
