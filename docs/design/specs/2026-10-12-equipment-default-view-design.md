# Configurable default equipment view

Issue: #2628. Release: v1.8.2.

## Problem

The Equipment list opens on its default view, which today is fixed: every
item except Retired, Sold and Wanted gear (#636, #2590, #2025). Spare, Lost,
Loaned Out, In Service and Needs Service gear always shows. A diver who only
wants to see Active gear, or everything except Lost, Sold and Loaned Out, has
to apply a filter each time, because `equipmentFilterProvider` is a session
`StateProvider` and resets on every launch.

## Goal

The diver chooses which statuses the default view includes. The Equipment
list then opens on that view without a filter, the filter badge stays off,
and "Clear all" returns to it.

Success criteria:

- A diver who never touches the setting sees exactly today's list.
- Both examples from the issue ("Active only", "everything except Lost, Sold
  and Loaned Out") can be expressed.
- The choice is per diver and syncs between devices, like other list
  preferences.

## Design

### Storage

A new nullable text column on `diver_settings`, `equipmentDefaultStatuses`:
a JSON array of `EquipmentStatus.name` values. Null means the factory default
(every status except `retired`, `sold` and `wanted`).

- Added by the next free migration rung (v284 at the time of writing) in
  `rungs_v231_onward.dart`, with a helper in
  `migrations/helpers/diver_migrations.dart` and a `before_open` column
  backstop, following v281.
- Existing rows are not backfilled: they stay null and so keep today's view.
- `AppSettings` gains `Set<EquipmentStatus> equipmentDefaultStatuses`, with
  the factory default as its default value. The repository maps null to the
  factory default on read and writes null when the set equals the factory
  default, so an unchanged setting never stores a value.
- Reading is tolerant: unknown names (from a newer build) are dropped; an
  unreadable value, or one that leaves no known status, reads as the factory
  default.
- Sync: the serializer's diver-settings default map gains the column (null),
  and the conflict catalogue gains a field entry whose value formats as the
  localized status names joined by commas.

### Query

`EquipmentFilterQuery._lower(defaultStatus: true)` today adds three
hard-coded `status != retired/sold/wanted` conditions. It instead takes the
diver's set and builds the default view from it:

- When the set equals the factory default, the lowering is unchanged (the
  three `!=` conditions), so default-setting divers run byte-identical SQL.
- Otherwise it is an OR of each included status's own single-status
  lowering. This keeps the retired rule (legacy rows that only flipped
  `isActive` count as retired, but sold and wanted rows do not) instead of a
  naive `status IN (...)`.

`compileEquipmentFilter` gains a `defaultStatuses` parameter.
`queryFilteredEquipmentIdsProvider` reads the set from settings inside its
body (the family key stays `(filter, diverId)`), so an open list re-queries
as soon as the setting changes. `viewRevealingSavedEquipment` (#3068) takes
the set as a parameter from its caller.

Because every "default view" surface goes through these two compile
callers, all of them follow the setting with no further change: the list,
the "3 of 40 items" count total, the status-view and tag-emptied probes, the
save-reveal check, and the tag and Explore navigation entries.

Service-due views are the exception: they keep the factory kit whatever the
setting. The home strip's service chips count clocks over the factory kit,
so a list narrowed by a custom default would show fewer rows than the chip
promised and could hide gear that is due for service. This covers both the
home strip entries and the filter panel's Service Due, Overdue and Due Soon
chips.

`toSavedQuery()` already strips the default view, so saved searches are
unaffected.

### Settings page

A new page, "Default equipment view", at `/settings/equipment-default-view`:

- A short explanation, then a checklist of all nine statuses in enum order,
  with localized names.
- At least one status stays selected: the last selected checkbox is
  disabled.
- "Reset to defaults" restores the factory set; it is disabled while the set
  already is the factory default.
- Changes save immediately, as other settings toggles do.

Reached from:

- A "Default equipment view" row in Settings > Manage, next to Service Types
  and Locations, whose subtitle lists the included statuses.
- An "Edit default" text button on the Status heading row of the Equipment
  filter panel. It opens the settings page; the sheet stays as it was.

### Filter panel

The default-view chip is renamed from "Current Equipment" to "Default View"
in every locale (`equipment_list_filterCurrent`, value and description). Its
behaviour is unchanged: it is selected when no status filter is set, and
"Clear all" returns to it.

### Empty state

When the default view is empty but the diver owns gear outside it
(wishlist items are not owned, so they do not count) (now
likely with, say, "Active only"), the list stops saying "No equipment / Add
your first equipment". It says "No equipment in your default view", explains
that the default view hides the diver's other gear, and offers a "Show All
Equipment" button that sets the All Equipment filter. The Add button is not
shown in this case. With no gear at all, the existing empty state is kept.

### Out of scope

Dive gear pickers, equipment sets, service clocks, statistics and totals
read `isActive`, not the list's default view, and do not change. The status
axis in the filter panel stays a single choice.

## Testing

- Lowering: the factory set produces today's conditions exactly; a custom
  set ORs the single-status lowerings; the retired legacy rule holds inside a
  custom set.
- Repository: null round-trips as the factory default; a custom set
  round-trips; unknown and unreadable values fall back as described; the
  factory set is written as null.
- Migration: the rung adds the column, null for existing rows.
- Sync: the serializer carries the column; the conflict field formats it.
- Providers: changing the setting re-queries the open list; the count total
  follows it.
- Widgets: the settings page (checklist, last-box rule, reset), the Manage
  row and its subtitle, the "Edit default" link, the chip label, and the new
  empty state with its button.
