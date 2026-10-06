# Equipment locations: design

Date: 2026-10-05
Release: v1.8.2

## Problem

A diver wants to know where each piece of gear is: on a shelf or in a bin
when stored, at a shop when sent off for service, with a friend when lent.

The app already records an item's state through `EquipmentStatus` (Active,
Spare, Needs Service, In Service, Retired, Sold, Loaned Out, Lost), so "it is
away being serviced" can be said today. What cannot be said is *where*: which
shop, which bin, which friend. Service records carry a free-text `provider`,
but nothing describes where an item is right now or where it has been.

Location is a separate dimension from status. Status says what state an item
is in; location says where it is. This feature adds location and leaves
status as it is, apart from offering a status change after a move.

## Goals

1. Look up one item's current location from its detail page.
2. See what is at a place: filter the equipment list by location, group the
   list under one heading per location, and list the items at a place from
   that place's own page.
3. Keep a location history per item, with backdating and correction.
4. Move many items at once from the equipment list's multi-select.
5. Carry the current location through the equipment CSV export and back in
   through the Submersion CSV import.

## Non-goals

- Location in UDDF export or import.
- A household location list shared across diver profiles.
- Changing status automatically. The app offers a status change; the diver
  confirms it.
- Group-by-location on the dive gear surfaces (dive view, gear picker,
  equipment sets, printed logbook). Grouping by location applies to the
  Equipment page only.

## Decisions

| Question | Decision |
| --- | --- |
| How is a location entered? | Picked from a list of named places the diver keeps, with inline creation. Renaming a place renames it everywhere. |
| Where does the truth live? | An append-only move log. The current location is the latest move. There is no current-location column on `equipment`. |
| Status and location | Independent, with a one-tap offer after a move (table below). |
| Scope of the place list | Per diver, like tags, service types and dive centers. |
| Assemblies and installed parts | A move offers to move the parts too (default yes). Each part gets its own move row and keeps its own history. |
| List grouping | An Equipment-page-only "Group by location" switch, stored as its own synced setting. Type sub-headings stay inside each location heading when type grouping is on. |
| CSV | Export writes the current place's name. Import matches or creates the place and records one move. |

## Data model

### `equipment_locations`

A per-diver catalog of places, synced as a top-level entity
(`equipmentLocations`, `entityHasUpdatedAt: true`).

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, PK | UUID |
| `diver_id` | text, nullable, FK `divers` | Same shape as `tags.diver_id` and `service_kinds.diver_id` |
| `name` | text | Required, trimmed, non-empty |
| `kind` | text | `storage`, `serviceShop`, `person` or `other`. An unknown name (written by a newer peer) reads as `other`. |
| `notes` | text, default `''` | Address, phone, locker number |
| `is_archived` | bool, default false | Archived places leave the picker but stay in history and on items still there |
| `created_at`, `updated_at` | int | Epoch ms |
| `hlc` | text, nullable | Hybrid logical clock |

There is no unique constraint on `(diver_id, name)`. A unique index would make
a diver merge or a two-device race fail; the Manage page warns about a
duplicate name instead.

### `equipment_location_moves`

An append-only log, one row per move, synced as a parent-gated child of
equipment (`equipmentLocationMoves`, `entityHasUpdatedAt: false`), shaped
like `equipment_ownership_events`.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, PK | UUID |
| `equipment_id` | text, FK `equipment`, ON DELETE CASCADE | |
| `location_id` | text, nullable, FK `equipment_locations`, ON DELETE SET NULL | Null means the location was cleared ("No location") |
| `moved_at` | int | Epoch ms. Defaults to now; the diver can backdate it. |
| `note` | text, default `''` | e.g. "Annual regulator service, quoted $120" |
| `created_at` | int | Epoch ms. Breaks ties on `moved_at`. |
| `hlc` | text, nullable | The child's own clock, restamped on every edit |

Indexes: `(equipment_id, moved_at)` and `(location_id)`.

### Current location

An item's current location is its move with the greatest `moved_at`, ties
broken by `created_at`, then by `id`. An item with no moves, or whose latest
move has a null `location_id`, has no location.

Editing or deleting a move recomputes the current location; nothing else
needs updating, because nothing else stores it.

### Why a log and not a column

A current-location column on `equipment` would have to be recomputed on
every history edit, and a move would stamp the whole equipment row's clock,
so a move on one device could overwrite a concurrent edit (notes, say) made
to the same item on another. With the log as the only truth, each move
syncs as its own row and moves from two devices merge.

If list performance ever calls for it, a local, unsynced cache table can be
added later, as `equipment_service_status` does for service-due filtering.

## Behaviour

### Moving an item

The Move sheet is the one place a move starts: the detail page, the bulk
action and the per-place page all open it.

1. Pick a place: search over the diver's non-archived places, grouped by
   kind, plus "No location". "New place..." creates one inline, its name
   prefilled from the search text (the pattern the site picker uses since
   #2988), with a kind chosen in the same step.
2. Set the date (defaults to now) and an optional note.
3. Confirm. One move row is written per item.
4. **Parts prompt.** If any moved item has assembly components or installed
   children (`parentEquipmentId`), ask "Also move its N parts?" (default
   yes). Yes writes a move for each part with the same place, date and note.
5. **Status offer.** Shown only when it would change something:

| Moved to | Offers | Only when the current status is |
| --- | --- | --- |
| Service shop | In Service | anything except In Service, Retired or Sold |
| Person | Loaned Out | anything except Loaned Out, Retired or Sold |
| Storage | Active | In Service, Loaned Out or Lost |
| Other, or No location | nothing | |

For a bulk move the offer covers every eligible item in one prompt ("Also
mark 4 items In Service?"); ineligible items are left alone.

### History

The detail page's Location card lists the most recent moves, with "Show
all" for the full list. Tapping an entry opens it for editing (place, date,
note) or deletion. History is ordered by `moved_at` descending.

### Places

- A place used by any move can only be archived. A never-used place can be
  deleted.
- An archived place still appears on items currently there, in history, and
  as a heading when grouping by location. It can be restored.
- The name is required and trimmed. Typing a name that matches another of
  the diver's places (case-insensitive) shows a warning but does not block.

## Screens

### Equipment detail page

A new **Location** card near the top, in its own widget file (the detail page
is already past the size guideline):

- The current place with its kind icon, "since <date>" (the app's date
  format), and the latest move's note. "No location set" when there is none.
- A **Move** button.
- The last three moves, then "Show all".

### New equipment form

An optional **Location** picker on the create form only. Picking a place
writes the item's first move, dated at creation. Existing items change
location only through Move, so every change lands in history.

### Equipment list

- **Bulk action:** "Move to location" in the multi-select bar, beside Edit
  tags. Opens the Move sheet for the selection.
- **Filter:** a Location section in the equipment filter sheet. Pick one or
  more places, or "No location".
- **Group by location:** a switch in the Equipment page's sort sheet, saved
  as its own key in the synced app settings, separate from the shared
  `EquipmentArrangement`. When on:
  - One heading per place, ordered by kind (Storage, Service shop, Person,
    Other), then by name, with "No location" last. An archived place gets a
    heading while items are there. Each heading shows its item count.
  - Inside each location heading, the shared arrangement applies as it does
    today: type sub-headings when type grouping is on (and the type order is
    not None), then the item sort.
  - When off, the list behaves exactly as it does today.

### Settings > Manage > Locations

A new tile beside Service types, routed under `/equipment/locations` (before
the `:equipmentId` catch-all).

- Places grouped by kind, each with the number of items there now.
  Archived places sit in a collapsed section.
- Add, edit (name, kind, notes), archive, restore, and delete a never-used
  place.
- Tapping a place opens it: its details and the items there now, each
  opening its equipment detail page.

## CSV

- **Export:** a `Location` column, appended after `Notes` so readers that
  take the older columns by offset are unaffected (the convention #2201 set),
  holding the current place's name, empty when there is none. The cell goes
  through `sanitizeCsvField`.
- **Import (Submersion CSV):** a non-empty `Location` cell is matched,
  case-insensitively, to one of the importing diver's non-archived places;
  failing that, an archived one; failing that, a new place of kind Other is
  created. The item gets one move to it, dated at import time. A blank cell
  or a missing column writes nothing.

## Sync, schema and lifecycle

- **Schema:** one rung at v268 (main reached 264 while this was built, and
  265 to 267 are claimed by open branches).
  It creates both tables and indexes. An idempotent before-open backstop
  asserts them; it lives in a part file, because `before_open.dart` is at
  794 of its 800-line limit. New tables do not raise
  `minimumCompatibleSchemaVersion`.
- **Sync registration:** both entities in `SyncData`, `_baseTables`,
  `_buildSyncData`, the fetch, upsert, delete and record-id arms,
  `hlcTargets`, `mergeOrder` (places before moves, moves after equipment),
  `entityHasUpdatedAt`, and `parentRefs` (move to equipment, required; move to
  place, optional). Moves join `parentGatedChildEntities` and
  `parentGatedTables`, and their table joins `_assertChildHlcColumns`.
  `locationId` gets a conflict-reference target and label.
- **Deleting an item** deletes its moves and logs their deletions, as
  `deleteEquipment` already does for shares, tags and trip links.
- **Deleting a place** is allowed only while no move references it. If a
  peer adds a move to it concurrently, that move syncs with a null
  `location_id` and reads as "No location".
- **Deleting a diver profile:** the diver's places are deleted, except those
  still referenced by moves on gear that survives the deletion (gear the
  diver had transferred, or moves the diver made on gear shared with them).
  Those places are reassigned to the referencing gear's owner and marked
  pending for sync, mirroring `retireDiverServiceKinds`. When gear of more
  than one owner references a place, it goes to the owner of the earliest
  such move.
- **Transfer:** an item's moves go with it unchanged. The new owner sees the
  previous owner's place names; their next move picks from their own list.
- **Diver merge:** `equipment_locations` has a `diver_id` column, so the
  existing schema-driven repoint covers it. Moves have no diver column.
- **Backup:** covered, since a backup copies the whole database file.

## Testing

TDD throughout.

- **Repository:** current location (latest wins, tie-break on `created_at`
  then `id`, backdating, a cleared location, edit and delete recompute);
  archive and delete rules; the duplicate-name check; bulk moves; parts
  expansion.
- **Status offer:** each row of the table, as a pure function.
- **Migration:** the rung from the previous version, the backstop on a
  database missing the tables, and a fresh `onCreate`.
- **Sync:** the guards that enumerate synced tables and parent-gated
  children, the serializer coverage tests, and a round trip in which two
  devices edit the same move.
- **Diver lifecycle:** delete with reassignment of a referenced place, and
  merge.
- **CSV:** export column, import match, import create, blank cell.
- **Widgets:** Location card (empty, current, archived place), Move sheet
  (new place inline, parts prompt, each status offer), Manage > Locations
  (archive versus delete, counts, items here), bulk move, the Location
  filter, grouping with and without type sub-headings.
- `test/architecture/` and `test/shared/` after adding files under `lib/`.
