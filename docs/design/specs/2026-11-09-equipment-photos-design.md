# Equipment photos: identification photos, check-in photos, a Gear gallery

Issue: #3355. Release: v1.8.5.

## Intent

Divers want pictures of their gear in the app for two different reasons:

1. **Identification.** What the item looks like, its serial number label,
   its markings. Pure reference, tied to the item and to no particular moment.
2. **Condition.** A photo that backs up something specific the diver found:
   "second stage free-flowed at the surface", "chafe near the hose crimp".
   That photo belongs with the finding, so it carries the finding's date and
   dive.

The app already records condition findings as **check-ins** (the
`ObservationsCard` on the gear page, `EquipmentObservations` table), but a
check-in cannot hold a photo. The gear page has no photo grid at all; its
only attachment card is the legacy "Linked files" card
(`EquipmentDocumentsSection`), which since #3333 only shows paperwork the
Documents library could not take, and has no Add button.

## Goals

- A **Photos** card on the gear page for identification photos: add, view
  full screen, remove.
- **Check-in photos:** a check-in can carry photos, added in the check-in
  sheet, shown as a small strip under that check-in's note on the gear page
  (the owner chose this over a separate condition-photo gallery on the gear
  page).
- A **Gear gallery** in the Media section that shows and manages every gear
  photo, both kinds, grouped by item, with check-in photos marked.
- A **cover photo**: the diver can choose one photo to represent the item.
  It replaces the type icon in the equipment list and in the gear page
  header.

## Non-goals

- No camera capture inside the app. The diver takes the picture with the
  phone's camera and picks it from the photo library (desktop: picks a file).
- No change to the Documents library or to how receipts and warranties are
  handled.
- The cover photo does not replace the type icon anywhere other than the
  equipment list and the gear page header (pickers, dive gear tree, trip
  packing rows, diver figure, set pages all keep the icon).
- No photo editing, cropping or colour adjustment beyond what the shared
  media viewer already offers.

## Anti-goals (a failure even if it works)

- **Copying photos into app storage.** The app keeps links only; it never
  owns or copies the originals (standing owner rule). Every gear photo is a
  link to the device photo library or a user-managed file, exactly like dive
  and site photos.
- **A gear photo turning into a "document".** `EquipmentFileConverter` moves
  gear-linked files into the Documents library at every launch and after each
  sync. It must never touch a gear photo, under any file type.
- **The same picture listed twice** on the gear page (once in Photos or a
  check-in strip, again on the "Linked files" card).
- **A gear photo showing up as a dive photo.** Gear photos stay out of dive
  galleries, dive photo grids, the dive card photo backgrounds and the
  Library's ordinary views, even when the check-in was made on a dive.

## Decided behaviour

### Gear page: Photos card

- New card on the gear detail page, above Check-ins. Header "Photos", an Add
  button, a grid like the dive site's (`SiteMediaSection` look and feel,
  without site categories or the "photos from dives" group).
- Shows the item's identification photos (gear photos not attached to a
  check-in).
- Tap opens the shared full-screen viewer, scoped to the item's
  identification photos.
- Bulk selection (the existing selection controls) to remove photos.
  Removing unlinks: the row leaves the library unless a dive or site still
  uses it; the file itself is never touched (same rule as every other unlink).
- An action on a photo, "Use as cover photo" (and "Remove cover photo" on the
  current one), sets or clears the cover. The current cover is marked in the
  grid.
- Empty state with a short line explaining what the card is for.
- On web (no `mediaAttach` capability) the card shows photos but offers no
  Add, selection or cover actions, matching the site section.

### Check-ins

- The check-in sheet (`showEquipmentObservationSheet`) gets a photos row:
  existing photos as thumbnails, an Add button, and a remove control on each.
  The sheet opens from the gear page, the dive page and the incident page;
  photos work the same from all three.
- On the gear page's Check-ins card, a check-in with photos shows a small
  strip of thumbnails under its note. Tap opens the viewer scoped to that
  check-in's photos.
- Deleting a check-in unlinks its photos (same unlink rule as above), and the
  delete confirmation says so when the check-in has photos.

### Media section: Gear gallery

- Gear photos (both kinds) appear **only** in the Gear gallery (owner
  decision). They stay out of the Library's ordinary views: Grid, Timeline,
  By dive, Map, smart albums, "Photos of me", slideshows, and every count
  those views show. Today `MediaLibraryRepository` leaves out only
  signatures and documents (`_nonGalleryFileTypes`), so gear photo rows need
  the same treatment in every library query, count and map query.
- The Gear gallery is its own entry in the Media section (not a filter of the
  ordinary Library). It shows every gear photo (both kinds), grouped by item,
  reusing the library grid, selection and the existing equipment group header
  (`EquipmentGroupHeader`).
- It shows only photos of gear the active diver can see (their own items and
  items shared with them, per the equipment `VisibilityFilter`). The
  library's `_diverScope` treats any row without a dive as visible to every
  profile, so the Gear gallery must scope through the equipment row instead.
- Check-in photos carry a small marker so the two kinds are distinguishable.
- Tapping a group header opens that gear item's page.
- Manage: the library's existing selection and its remove action work here.
  The viewer opened from here shows which check-in a photo came from, when it
  has one.

### Cover photo

- Chosen explicitly from the Photos card. No automatic pick: an item with no
  chosen cover shows its type icon exactly as today.
- Only identification photos can be the cover (a damage close-up is a poor
  stand-in for the item).
- Shown as a rounded square thumbnail where the type icon sits, in the
  equipment list rows and the gear page header.
- If the cover photo is removed, unlinked, or cannot be shown on this device
  (missing file, not synced yet), the type icon shows instead. A removed
  cover clears the choice.

## Constraints from the codebase

- **Links only:** reuse the existing link paths (`PhotoPickerService` and the
  library asset link on mobile, `LocalFileLinkService` on desktop), the same
  ones the dive and site Add photos actions use.
- **Media rows already link to gear:** `media.equipment_id` (v189, #1517),
  with `mediaForEquipmentProvider` and `unlinkEquipmentMedia`. Identification
  photos are media rows with that link.
- **Legacy "Linked files" card:** must list only rows that are not photos or
  videos and not check-in photos, so it keeps showing just the leftover
  paperwork. Any image already linked to gear by the old card (the converter
  leaves those alone) shows up in the new Photos card instead.
- **Converter:** `EquipmentFileConverter` must skip every photo and video row
  and every check-in photo, by media type, not by file extension. Today it
  happens to skip JPEGs only because they need re-encoding; that must not be
  the guard.
- **Schema and sync:** any new column syncs. New tables and migration rungs go
  in `lib/core/database/tables/` and `lib/core/database/migrations/` (never in
  `database.dart`). A column the sync serializer carries must be added to its
  arm on both sides and covered by the existing sync round-trip tests.
- **Clone (owner decision):** a cloned item gets no photos and no cover.
  `EquipmentCloneService._copyMedia` copies every equipment-linked media row
  today; it must skip photo and video rows (both kinds), so an old unit's
  serial-label photo never lands on the new unit. Leftover non-photo files
  on the legacy card keep today's copy behaviour.
- **Item fold** (`equipment_item_fold.dart`): the surviving item keeps its
  own cover; if it has none, it takes the folded item's cover. Photos move
  with the fold as other gear media already does.
- **Deletes:** deleting a gear item already partitions its media (rows still
  used by a dive or site survive with the gear link cleared; the rest go).
  Check-in photos go with their item the same way.
- **Units:** nothing here displays units.
- **l10n:** every new string goes through ARB with translations.

## Left to the builder

- **How a photo records its check-in.** The natural shape is a nullable
  `observation_id` on `media` (synced, set-null on delete, with the repository
  doing the unlink so the HLC is stamped), with `equipment_id` also set so the
  Gear gallery, grouping and item delete keep working unchanged. Another shape
  is fine if it keeps those properties.
- **How the cover is stored.** The natural shape is a nullable
  `cover_media_id` on `equipment` (synced). Clearing it when its media row
  goes is the builder's call (repository or a beforeOpen backstop).
- **Where the Gear gallery's entry sits in Media** (a console section tab, a
  chip on the Library toolbar, or similar), as long as it is reachable in one
  tap from the Media screen and reuses the library grid and selection.
- Thumbnail sizes, exact layout, marker icon, and wording, within the
  existing design language.
- Whether the viewer for check-in photos is a new scope of an existing viewer
  page or a new small page.

## Calls made during design (owner did not rule on these)

- Photos card sits above Check-ins on the gear page.
- Only identification photos can be the cover.
- No automatic cover; the icon stays until the diver picks one.
- The cover appears in the equipment list and the gear page header only.
- Deleting a check-in unlinks its photos rather than turning them into
  identification photos.
- Gear photos never appear in dive galleries, even for a check-in made on a
  dive.
- The Gear gallery shows only gear the active diver can see.
- Item fold: the surviving item keeps its cover, or takes the folded item's
  when it has none.
- Whatever media types the site Add photos picker accepts (photos, and videos
  where it offers them) are accepted here too.
