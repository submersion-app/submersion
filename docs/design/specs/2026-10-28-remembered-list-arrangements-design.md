# Remembered list arrangements (issue #3748)

## Intent

A diver sorts, groups or switches the view of a list, closes the app, and
the list comes back exactly as they left it, on this device and on their
other synced devices. There is no new settings entry and no separate
"default": the last choice made is the choice.

Today every list except part of Equipment forgets its sort and grouping on
restart and falls back to a hardcoded starting order (Saved Dive Plans
always reopens on Max. Depth, for example). The in-list view-mode toggle and
the Dives "group by trips" toggle are also forgotten: they start each launch
from the value under Settings > Appearance > Sections.

## Goals

- Every list below comes back with the sort field, sort direction, grouping
  and view mode it was left in.
- The arrangement belongs to the diver profile. Switching profiles brings
  back that diver's own arrangement.
- It syncs between devices with the rest of the diver's settings.
- A change synced in from another device, or made on the Appearance page,
  shows in a list that is already open.

## Non-goals

- No settings UI for these values. The Appearance > Sections view-mode and
  "group trips" entries stay and simply show the same saved value.
- No change to table mode's column-header sort. It is already saved per
  diver and synced in `view_configs`.
- No change to picker sheets that have their own sort (for example the "Add
  buddy" picker's `buddyPickerSortProvider`). They keep their fixed starting
  order.
- No change to the media library sort, which is already saved and synced.

## Anti-goals

- Rewriting any diver's existing settings on upgrade. A diver who never
  touched a list keeps today's starting order.
- A load race that overwrites a choice: a change made while the diver's
  settings row is still loading must not be lost when the load lands (the
  #998 / #2564 trap in `SettingsNotifier`).
- A synced value from a newer or older app version breaking a list. An
  unknown value falls back to the starting order.

## Scope: the lists

| List | Sort (field + direction) | Grouping | View mode |
| --- | --- | --- | --- |
| Dives | `diveSortProvider` | `diveListGroupTripsProvider` (already a column) | already a column |
| Saved Dive Plans | `divePlanSortProvider` | none | none |
| Trips | `tripSortProvider` | none | already a column |
| Courses | `courseSortProvider` | none | already a column |
| Buddies | `buddySortProvider` | none | already a column |
| Dive Centers | `diveCenterSortProvider` | none | already a column |
| Dive Sites | `siteSortProvider` | `siteGroupByProvider` | already a column |
| Certifications | `certificationSortProvider` | `certificationGroupByProvider` | already a column |
| Equipment | `equipmentSortProvider` | gear arrangement and group-by-location (moving, see below) | already a column |

## Decided with the maintainer

1. **Last left, not a default.** The in-list choice is saved the moment it is
   made. There is no separate default value.
2. **View mode and "group by trips" are included.** Today they are seeded
   once from diver settings and then held as a session-only override. They
   become the saved value itself: a change in the list writes the diver's
   settings, and the Appearance entry shows the same value.
3. **Per diver.** All of these live in the diver's synced settings row
   (`diver_settings`), next to the view-mode columns already there.
4. **Their own sync clock.** The arrangement columns sync under a clock of
   their own, not the settings row's clock. Without it, every sort tap would
   restamp the whole settings row, and a sort on a device holding stale
   settings would silently put back gradient factors, units or ppO2 limits
   changed on another device. Sorting is one of the most frequent taps in
   the app, so this is not an edge case.
5. **Equipment's grouping moves to per diver as well.** The gear arrangement
   (`equipment_arrangement`: type order and direction, group by type, item
   sort) and the Equipment page's group-by-location switch
   (`equipment_group_by_location`) move from the app-wide key/value
   `settings` table into the diver's settings row. The arrangement keeps
   serving every surface that reads it today: dive view, edit form, gear
   picker, equipment sets and the PDF logbook export.

## Behaviour

- **Saving.** Choosing a sort field, flipping direction, changing grouping or
  switching view mode saves to the active diver's settings at once.
- **Reading.** Each list's providers read from the active diver's settings
  rather than copying a value once at launch. A profile switch, a synced
  change or an Appearance change shows in an open list.
- **Never set.** A column that was never written (null) reads as today's
  starting order for that list. A fresh database and an upgraded one behave
  the same until the diver changes something.
- **Unknown value.** A stored field or grouping name this app version does
  not know reads as the starting order for that list. It is not rewritten,
  so a newer device's choice survives on the row.
- **Conflicts.** The arrangement columns form one group with one clock. An
  arrangement change and a settings change made on different devices both
  survive. Two arrangement changes on two devices (even to different lists)
  resolve last writer wins for the whole group. Accepted.

## The arrangement clock

- Extend the existing column-group mechanism (`SyncFactGroups` and
  `mergeFactGroups` in `lib/core/services/sync/sync_fact_groups.dart`, used
  by media today) to `diverSettings` with one group, `listArrangement`, and a
  new nullable clock column (for example `list_arrangement_hlc`).
- The group holds every new sort and grouping column, the moved Equipment
  arrangement and group-by-location columns, and the existing view-mode
  columns and `groupTripsInDiveList`. The in-list view toggles are as
  frequent as sort taps, so they need the same protection.
- A local change to a group column stamps the group clock and marks the row
  pending without restamping the row clock. A change to any other setting
  stamps the row clock as today. The Appearance page's view-mode and "group
  trips" entries write through the group path too.
- Merge: the peer wins the group only on a strictly newer group clock; the
  rest of the row merges by the row clock as today.
- An older app version on another device sends no group clock, so its row
  clock stands in (the mechanism's existing fallback). A settings change
  made on an old device can then carry its stale arrangement over a newer
  one. Accepted as a mixed-version limitation that ends when every device
  upgrades.
- Every surface that consumes `SyncFactGroups` today (sync merge, export
  watermark, the Nearby export planner, the sync conflict screen's field
  catalogue) must handle the new group; the conflict catalogue needs labels
  for the new columns.

## Moving Equipment's grouping

- No adoption write. The new per-diver Equipment columns start empty. While
  a diver's column is empty, the app reads the old app-wide value
  (`equipment_arrangement`, `equipment_group_by_location`) as that diver's
  arrangement, falling back to the defaults if the key was never written.
  The first change the diver makes saves the per-diver value, and from then
  on the app-wide key is ignored for that diver.
- Because nothing is written at upgrade, no row gets a fresh clock and no
  device diverges from another. Every device reads the same synced app-wide
  key, so they show the same thing.
- A profile created later, with an empty column, also starts from the
  app-wide value: what every diver on that device sees today.
- After the move the app stops writing the app-wide keys. They stay in
  place, unread once a diver has a value, for older app versions.
- An older app version keeps reading and writing the app-wide keys. Its
  changes reach upgraded devices only for divers who never changed the
  arrangement there. Accepted as a mixed-version limitation.
- The PDF export, which reads the arrangement directly from the repository
  today, reads the active diver's value through the same fallback.

## Constraints

- New `diver_settings` columns need a schema rung, a `before_open` column
  backstop, and the sync serializer and wire handling every diver-settings
  column gets. The schema version is claimed against open PRs at build time.
- New columns are nullable with no backfill rung, per the rule that a
  migration never rewrites existing settings.
- Writes from list surfaces wait for the diver's settings to finish loading
  before saving, like `setAutoTagImports`.
- `database.dart` takes no new table or rung; migrations go under
  `lib/core/database/migrations/`. `before_open.dart` is at its line cap, so a
  new backstop goes in a part file.
- `settings_providers.dart` is already about 3,800 lines. New list-arrangement
  code goes in its own file rather than growing it.

## Left to the builder

- Column shape: one column per value, or one encoded column per list (for
  example `field|direction`), as long as each list reads independently and
  an unknown value falls back per list.
- How the gear arrangement is stored per diver (JSON text is fine; it is JSON
  in the key/value table today).
- Whether list providers become derived providers over the settings state or
  small notifiers. They must follow diver switches and synced changes.
- Test layout, and whether a shared encoder/decoder serves every
  `SortState<T>`.
