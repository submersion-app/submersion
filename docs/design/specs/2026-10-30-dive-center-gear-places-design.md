# Dive center gear places

Issue: #3623. Release: v1.8.4.

## Why

A diver asked for a "Dive center" location type: "I always keep my camera,
computer,... with me but I can leave my BCD at the centre." Gear places today
are Storage, Service shop, Person or Other, and a place is only a typed name.
A dive center fits none of those, and a diver who has already saved the center
in Submersion has to type it again with nothing connecting the two.

So a Dive center place can point at a saved dive center, and that center's page
can answer "what of mine is here?"

## How often this happens

Only for divers who leave gear at a center: regulars at a home center, or a
week's stay on a trip. Most centers in a logbook will never hold gear. That is
why the design keeps the picker short and adds a section only to centers that
hold something.

## Goals

- A new place type, Dive center, next to Storage, Service shop, Person, Other.
- A Dive center place can link to one of the diver's saved dive centers. The
  link is optional, and can be added or removed later by editing the place.
- A saved center's page lists the diver's gear that is there now.
- A linked place's page opens its center.

## Non-goals

- Listing every saved center in the place picker. A diver adds a center as a
  place first, through New place, so the picker lists only places they added.
- Moving gear from the center page.
- Creating a place from the center page.
- A rental or service workflow at the center. A shop that services gear stays a
  Service shop place.
- New CSV or UDDF fields. Import and export keep using the place name.
- Changes to the demo data seeder.

## Anti-goals

- A diver losing a place, or a place's move history, because a center was
  deleted, merged away, or edited on an older device.
- A status changing by itself. Moves only ever offer a status.
- A section or row that appears empty on a center that holds no gear.

## Decided by the maintainer

| Decision | Choice |
| --- | --- |
| Type only, or linked to saved centers | Linked |
| What the link is for | Picking a saved center, and listing gear on its page |
| How a center gets into the picker | Added as a place first, through New place |
| Must a Dive center place be linked | No, the link is optional |

## Behaviour

Choices marked *(call)* were proposed in the design conversation and accepted
in review of the playback.

### Place type

`EquipmentLocationKind.diveCenter`, declared right after `storage`, so headings
read Storage, Dive center, Service shop, Person, Other *(call)*. The enum is
stored by name, so its position is safe to change. It appears wherever kinds
already appear: the picker sections, the Manage list, the Equipment page's
group-by-location headings, the kind dropdown, the conflict dialog.

Use `Icons.store_outlined`, the outlined form of the `Icons.store` that the dive
center picker already uses.

### New place and edit dialog

`equipment_location_edit_dialog.dart` keeps its field order. When Type is Dive
center, a Saved dive center field appears under it, showing "None" or the
center's name, with a way to clear it.

- Tapping it opens `DiveCenterPickerSheet` in a draggable bottom sheet, as
  `trip_cylinder_fill_sheet.dart` does. The list comes from
  `allDiveCentersProvider`, so only the current diver's centers appear.
- Picking a center fills Name when Name is blank, or still holds the name the
  last pick filled in *(call)*. A name the diver typed belongs to them: renaming
  the center never changes it, so "Blue Reef locker" stays as typed.
- Changing Type away from Dive center hides the field and clears the link on
  save *(call)*. Only a change of type does: a place an older device retyped to
  Other keeps its link when edited here.
- Saving a Dive center place with no center is allowed.
- The picker does not create centers from here, matching the fill sheet's
  precedent: a diver with no saved center can type a name now and link later.
  `DiveCenterPickerSheet` currently requires `onCreateNewCenter`; the builder
  chooses how this caller avoids a button that does nothing.

### Center page

`dive_center_detail_page.dart` gains a section titled "Your gear here", above
Rental gear *(call)*.

- It lists gear whose current place links to this center, using the same item
  source as the place page (`itemsAtPlaces` and
  `currentEquipmentLocationsProvider`), sorted by name.
- Each row shows the item's name and localized type, and opens the item. The
  second line adds the place name only when more than one of the diver's places
  links to this center.
- Several places may link to one center *(call)*; the section lists gear from
  all of them, archived places included, since the gear is still there.
- The section and its divider are not built at all when the list is empty.

### Place page

`equipment_location_detail_page.dart` gains a row under the kind row, labelled
Saved center, showing the center's name and opening its page. No row when the
place is unlinked, or when the center is not available on this device.

### Status offers

`offeredStatusAfterMove` treats `diveCenter` like `storage` *(call)*: only gear
that was In Service, Loaned Out or Lost is offered Active. A BCD left at a
center while the diver is still diving keeps its status. The diver confirms
every offer, as today.

### Deleting a center

The place stays, with its name, type, notes and history. Only the link clears.
The gear stays at that place, so it now shows on the place page and on no center
page.

## Data

`equipment_locations.dive_center_id`: text, nullable, foreign key to
`dive_centers(id)`, `ON DELETE SET NULL`.

- Schema v328 at time of writing. Renumber if another PR ships that version
  first. Rung in `migrations/ladder/rungs_v231_onward.dart`, an idempotent
  column assert in `migrations/helpers/equipment_location_migrations.dart`,
  re-asserted from `before_open_child_columns.dart`. Never in `database.dart`.
- No backfill, and no existing place changes type.
- The Drift table in `tables/equipment_location_tables.dart` gains the column,
  referencing `DiveCenters` from `tables/site_tables.dart`.
- `EquipmentLocation` gains `diveCenterId`, with `copyWith` able to clear it to
  null. `props` includes it.
- `EquipmentLocationRepository.createLocation` and `updateLocation` carry it.

A link is meaningful only for a Dive center place in the UI, but it is not
enforced in the schema. The center page reads the link alone, so a place an
older device retyped to Other (see below) keeps showing its gear.

## Sync

- The column travels in the row's `toJson`.
- **Older devices.** A record from an older build has no `diveCenterId` key, and
  that must not read as an unlink. `upsertRecord` and `upsertRecords` already
  handle this through `_withLocalForOmitted` (#2553): an omitted key keeps the
  local value, and a key present with a null value is a real unlink. No new code
  is needed; tests pin the behaviour for this column.
- Older builds read `diveCenter` as Other through `fromName`. If a diver edits
  such a place on an older build, its kind is written back as Other. That cannot
  be fixed from this side; the link survives, and the diver can set the type
  again.
- Add `'equipmentLocations': [(field: 'diveCenterId', parent: 'diveCenters',
  nullable: true)]` to the parent table in `sync_service.dart`, so a place whose
  center is gone arrives with the link cleared rather than skipped.
  `diveCenters` already applies before `equipmentLocations`.
- `conflict_reference.dart` already maps `diveCenterId` to `diveCenters`. Add a
  conflict label if the catalogue's guard tests require one.

## Unlink paths

`ON DELETE SET NULL` protects the delete, but a local SET NULL reaches no peer.
Each path below clears the link explicitly, stamps `updated_at`, and marks the
place pending, in the caller's transaction, before the center is deleted:

- `DiveCenterRepository.deleteDiveCenter`, through `clearDiveCenterLinks`.
- Diver deletion in `diver_repository.dart`, next to the existing
  `clearTripCylinderEventCenterLinks` call and before
  `retireDiverEquipmentLocations`, for places that survive their diver.

One helper serves both, following `clearTripCylinderEventCenterLinks`. Diver
merge moves centers and places together by `diver_id` and needs no change.

## Localization

New strings in every ARB file (11 locales), translated, not English copies: the
kind name, the Saved dive center label, its None value, the center page section
title, and the place page row label.

## Documentation

`docs/user/equipment.md`, Locations section: mention dive centers, the link, and
the center page section.

## Tests

- `fromName` round-trip, including `diveCenter`, and an unknown name.
- `offeredStatusAfterMove` for `diveCenter` across statuses.
- Repository: create, update and clear the link.
- Migration: column added from v327, idempotent, existing places keep kind.
- Sync: record with the key, with a null value, and with no key at all, through
  both apply paths; a center missing on arrival clears the link.
- Unlink: deleting a center keeps the place and marks it pending; diver deletion
  does the same for a surviving place.
- Dialog: field appears only for Dive center, name fills only when blank, type
  change clears the link, saving with no center works.
- Center page: section lists linked gear, hides when empty, names the place only
  when several link to the center.
- Place page: row opens the center, absent when unlinked.

## Left to the builder

- The exact widget split and file names for the center page section.
- Provider shape for "gear at this center".
- Wording of the strings, within the labels above.
