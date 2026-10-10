# Equipment Clone: Design

Status: approved in design review, 2026-10-09. Target release: v1.8.2.

## Problem

A diver who owns two of the same thing (a sidemount pair of regulators, twin
tanks, a second identical drysuit undergarment, spare O2 cells) has to enter
every field of the second item by hand, then rebuild its service clocks, add it
to the same equipment sets and attach the same invoice. Cloning an existing
item removes that retyping.

## User flow

1. On the equipment detail page (phone and wide layouts), the overflow menu
   gains **Clone**, beside Transfer and Delete.
2. Clone pushes `/equipment/new?cloneFrom=<sourceId>`, the same full-page push
   "Add part" uses with `?parent=`.
3. The New Equipment form opens titled **Clone Equipment**, pre-filled from the
   source (rules below). Nothing is written until Save.
4. Cancel leaves no trace.
5. Save creates the clone, copies its extras (below), and replaces the form
   with the **clone's** detail page, showing an "Equipment cloned" snackbar.

## What the form pre-fills

Copied from the source as-is:

- type, status, brand, model
- purchase date, purchase price, purchase currency
- notes
- type attributes (size, thickness, buoyancy, colour and the rest of the
  curated catalog) and custom fields
- the parent the source is fitted to (still checked by the form's existing
  parent validation on save)
- reminder overrides (`customReminderEnabled`, `customReminderDays`)
- tags, as the new item's tag selection
- the source's current location, as the new item's first location

Changed on the clone:

| Field | Clone gets | Why |
| --- | --- | --- |
| Name | `<source name> (copy)`, the suffix localized | Tells the two apart in lists until renamed |
| Serial number | blank | A serial identifies one physical item |
| O2 cell slot attribute | blank | Two cells must not claim the same slot |
| Child install date attribute | blank | The clone inherits its parent's dives from its own creation, not from the original's install date |

The legacy service fields (`lastServiceDate`, `serviceIntervalDays`) are not
copied: they are frozen on existing rows only, and service is tracked through
clocks, which are copied separately.

## What Save copies beyond the form

After `addEquipment` commits the clone (and its tags, in that same
transaction) and the first location is recorded, an `EquipmentCloneService`
copies three kinds of extras from source to clone:

- **Service clocks.** For each of the source's schedules: kind, enabled flag,
  day, dive and hour intervals, other exposure intervals, and per-item price
  and currency. The baseline (`anchorDate`, `anchorSetAt`) is never copied, so
  the clone's clocks count from its own purchase or creation. `addEquipment`
  already auto-attaches default clocks for the type (`auto-<kind>-<id>`); when
  the clone already has a clock of a source schedule's kind, that clock is
  updated with the source's settings instead of a second one being created.
  Auto-attached clocks with no counterpart on the source are left alone.
- **Equipment set membership.** The clone is added to every set that contains
  the source.
- **Documents and photos.** Each media row attached to the source
  (`media.equipment_id = source`) gets a new row: new id, `equipment_id` set to
  the clone, `dive_id` and `site_id` cleared (the copy belongs to the clone
  only), and every file and store reference carried over (`source_type`, path,
  `content_hash`, remote ids and upload stamps). The media store is
  content-addressed and reference-counted by `content_hash`, so the stored file
  is shared and is only purged once no row references it; unlinking or
  deleting the clone's copy never removes the original's.

Never copied: service records, observations, condition findings, location
history, fitted components and children, shares, transfer history.

## Failure handling

The existing `addEquipment` treats its post-commit steps (auto-attached clocks)
as best effort: once the row is committed, a failure is logged and never
rethrown, because a rethrow would invite a retry that duplicates the item. The
clone follows the same rule:

- Each of the three extras steps is caught on its own, so one failing does not
  skip the others, and the log names the step that failed.
- `copyExtras` returns the set of steps that failed. If it is non-empty, the
  page shows a second snackbar: the item was cloned, but some of its service
  clocks, sets or documents could not be copied. This mirrors the existing
  `equipment_edit_locationFailed` snackbar.
- A failure to read the source when the form opens shows the page's existing
  not-found or error state.

## Architecture

- **Route.** `newEquipment` (`/equipment/new`) reads `cloneFrom` from the query
  string and passes it to `EquipmentEditPage(cloneFromId: ...)`.
- **`EquipmentEditPage`.** A new `cloneFromId` parameter. The page stays in
  create mode (`isEditing` is false). In clone mode it watches
  `equipmentItemProvider(cloneFromId)`, seeds the form from
  `cloneFormSeed(source, copySuffix)` through the same initializer edit mode
  uses, loads the source's tags as the selection (with no stored baseline,
  as a new item), seeds `_initialLocation` from the source's current location,
  and shows the clone title. On save it calls the clone service after
  `addEquipment` and navigates to the clone.
- **`cloneFormSeed`** (pure, in `lib/features/equipment/domain/services/`):
  returns the `EquipmentItem` the form starts from: the source with a blank
  id, the suffixed name, no serial, no legacy service fields, and the cell slot
  and install date attributes removed.
- **`EquipmentCloneService`** (`lib/features/equipment/data/services/`): one
  method, `copyExtras({sourceId, cloneId})`, returning the failed steps. It
  depends on the service schedule, equipment set and media repositories.
- **Detail page.** A `clone` entry in `_buildMenuItems` and its case in the
  menu handler.

## Strings

New ARB keys, translated in every locale: the Clone menu label, the Clone
Equipment page title, the `{name} (copy)` name pattern, the "Equipment cloned"
snackbar, and the partial-copy warning.

## Testing

- `cloneFormSeed` unit tests: name suffix, serial cleared, cell slot and
  install date removed, other attributes and custom fields kept, legacy service
  fields dropped.
- `EquipmentCloneService` tests against an in-memory database: clocks copied
  without baseline, a source clock merged into the auto-attached clock of the
  same kind (no duplicate), set membership added, media rows duplicated with
  the shared `content_hash` and cleared dive and site links, and one failing
  step not stopping the others and being reported.
- `EquipmentEditPage` widget tests: clone mode pre-fills the form (suffixed
  name, blank serial, clone title); saving creates a second item and calls
  the clone service.
- Equipment detail page widget test: the overflow menu offers Clone and it
  pushes the clone route.
