# Link photos to gear (issue #5046)

## Intent

A diver can already say who is in a photo (people), what lives in it
(species) and how to file it (tags). Issue #5046 asks for the same for gear:
"this photo shows my drysuit", set from the photo, and the other way round,
from the gear item, by picking existing photos.

The link means "this gear appears in this photo" (gear in action). The photo
stays an ordinary dive photo: it keeps its dive, stays in the Library and is
never turned into a gear photo.

## Goals

- Link a photo or video to any number of gear items, and a gear item to any
  number of photos.
- Set the links from the photo viewer, from a Library multi-selection, and
  from the gear item's page.
- See the links in both places: gear chips on the photo, and an "In dive
  photos" card on the gear page.
- Links sync between devices like people and species tags.

## Non-goals

- Linking documents or signatures (gear already has its own attachment path
  for invoices and receipts, issue #1517).
- Linking a gear set or bundle; links name single items.
- Placing the gear on the image (no boxes, unlike face tags).
- Deriving links from the dives a gear item was used on (approach 2 below).
- A Library filter or query-language term for gear. A chip opens the gear
  page instead; a Library filter can come later.
- Carrying links in exports (UDDF, CSV and the like).

## Anti-goals

- A linked dive photo must never count as a gear photo: it must not appear in
  the item's Photos card, be offered as the item's cover, appear in Media's
  Equipment gallery, or match the Library's "Attached to: Equipment" filter.
  `media.equipment_id` is never written by this feature.
- Linking must never move a photo off its dive, hide it from the Library, or
  touch the file.

## Approaches considered

1. **A `media_equipment` link table (chosen).** A synced junction table with
   one row per photo and gear pair, the same shape as `media_tags` and
   `media_people`. It is the only approach that records "this photo shows
   this item", and it reuses proven sync, tombstone and sitting patterns.
2. **Derive the item's photos from its dives** through `dive_equipment`. No
   schema or sync work, but it is not linking: an item worn on 300 dives
   would collect thousands of photos that mostly do not show it, and the
   diver cannot say which do. Rejected.
3. **One auto-created tag per gear item.** Rejected: it fills the diver's tag
   list with gear names, and renaming or deleting the gear leaves those tags
   stale.

Eric chose approach 1, the "gear in action" meaning, and the picker sheet
for the gear page (below).

## Data

New table `media_equipment`, defined in `lib/core/database/tables/` (never in
`database.dart`), modelled on `MediaPeople` and `MediaTags`:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text, primary key | uuid. A surrogate key, so a pair unlinked and linked again never collides with its own tombstone (#347). |
| `media_id` | text, FK `media.id`, ON DELETE CASCADE | |
| `equipment_id` | text, FK `equipment.id`, ON DELETE CASCADE | |
| `created_at` | int | epoch ms |
| `hlc` | text, nullable | the link's own clock, stamped when it is marked pending |

Indexes: unique on `(media_id, equipment_id)`, and one on `equipment_id` for
the gear page.

Rows are created and deleted, never edited, like `media_tags`.

Schema: the next free schema version (387 is current; take whatever is next
at merge time), with the rung under `lib/core/database/migrations/` and a
table backstop in `before_open_table_backstops.dart`, following the v326
`media_people` rung.

Sync, following `media_people` at every point it is wired:

- change log policy: `tracked`, with parent `media` through `media_id`;
- `sync_repository.dart` table map, `sync_data_serializer.dart` (payload
  field, export, import, apply and delete cases), `sync_service.dart` record
  types and parent references;
- the repo's guard tests (sync parent refs completeness, record catalog)
  name anything else that has to know about the table.

Deletes:

- A deleted photo takes its links with it, and an undone photo delete brings
  them back, the way `media_row_restore.dart` restores `media_tags`.
- A deleted gear item takes its links with it, stamped so the delete syncs
  (a silent FK cascade never reaches peers). Follow how equipment deletion
  already handles its other child rows.

### Which photos and which gear can be linked

- Photos and videos only: `MediaItem` that is neither a document, a
  signature nor a gear photo (`isGearPhoto`). Dive photos, site photos and
  library photos with no dive all qualify.
- Gear: items visible to the active diver, the same set the equipment list
  shows. Retired or inactive items can be linked and stay linked.

### Which links each diver sees

A link is shown only where the active diver can see both ends: the photo by
the Library's diver scope (`_diverScope` in the media repositories: a photo
on another diver's dive is hidden, a photo with no dive is visible), and the
gear item by the equipment list's rules, shares included (#2046). So a shared
item's "In dive photos" card and pickers list only the active diver's
visible photos, and a photo shows no chip for gear the active diver cannot
see (unshared or transferred since). Hidden links are kept, not deleted; they
reappear if both ends become visible again.

### "The dives with this gear"

Both pickers use the gear page's own notion of an item's dives (the union
`getExposureSamplesForEquipment` computes: the `dive_equipment` junction,
cylinder and regulator links, transmitter serials, and a parent item's dives
from a child's install date), so a cylinder, regulator or transmitter opens
on its dives and agrees with the dive count its page shows. The picker needs
the dive ids only, not the samples, and must stay fast at 15,000 dives.

## Photo side

### Viewer: the Gear card

The viewer's info panel (and its phone sheet, which shows the same panel)
gets a **Gear** card directly below the Tags card, built like
`MediaInfoTagsSection`:

- The linked items as chips (gear type icon and name), in name order. A chip
  opens that item's page (`/equipment/<id>`).
- "No gear linked" when there are none. The card is shown even when empty,
  so it is a way in on every width, as the Tags card is.
- **Edit gear**, shown only while the photo's sitting is over this photo
  (the same rule as Edit tags), opens the gear picker.

Not shown for documents, signatures and gear photos.

### Gear picker (photo to gear)

A sheet with a search field and a checklist:

- **On this dive**: the gear used on the photo's dive (by the same rule as
  "The dives with this gear", read the other way), shown first. Absent when the photo has no dive or the dive has no gear.
- **Your gear**: every other item, grouped by gear type in the order the
  equipment list uses.

Checking and unchecking is held in the photo's sitting and written on Save,
like tags:

- `PhotoRecord` gains `gear` (the linked items as the chips show them),
  read by `photo_record_reader.dart`.
- A `photoGearField` holds `MediaGearEdits` (added and removed ids), modelled
  on `MediaTagEdits`, so a link made on another device during the sitting is
  kept.
- `photo_edit_save_service.dart` applies the edits on Save.

### Library: Link to gear

The Library's selection bar gets **Link to gear** next to Edit tags. It
opens the same picker for the whole selection, with the semantics and write
timing of the existing bulk Edit tags action (an item linked to every
selected photo shows checked, to some shows mixed). Selected items that
cannot be linked (documents, signatures, gear photos) are left out; the
action is hidden when none of the selection qualifies.

## Gear side

### The "In dive photos" card

A new card on the gear item's page, below the Photos card, separate from it
so dive shots never mix with identification shots or become the cover.

- Linked photos newest first, as a thumbnail grid using the existing media
  grid pieces; a tap opens the viewer over the linked photos.
- The header shows the count. The card shows at most two rows of
  thumbnails; past that, **Show all** opens a page with the full grid, so an
  item linked to 2,000 photos does not build a 2,000-tile card. The Show all
  page is read-only (it opens the viewer); removing links beyond the first
  two rows is done by unchecking them in the photo picker, or from the
  photo's own Gear card.
- Empty: a one-line invitation and the **Link photos** action.

Editing follows the gear page's sittings (issue #4527), like the Photos card:
the card has its own pencil, and while it is unlocked **Link photos** and
removing a photo (selection plus Unlink) are held in the gear item's sitting
until Save. Held as added and removed photo ids, so they merge with links
made from the photo side.

### Photo picker (gear to photos)

**Link photos** opens a sheet titled "Link photos to <item name>":

- Two choices at the top: **Dives with this gear** (photos from the item's
  dives, as defined above, grouped by dive, newest first) and
  **All photos** (every linkable photo, grouped by dive or date as the
  Library groups them). It opens on Dives with this gear, or on All photos
  when the item is on no dive.
- Photos already linked show checked; unchecking one removes the link.
- The confirm button names the change ("Link 3 photos"), and the result is
  held in the sitting.
- It must stay fast for a diver with 15,000 dives and tens of thousands of
  photos: grids build lazily and the query pages or streams.

## Range

Check these ends before calling the UI done:

- A diver with no photos, and one with tens of thousands.
- A gear item linked to no photos, to one, and to thousands.
- A photo linked to no gear and to ten items (chips wrap).
- Long gear names in chips and in the picker.
- Phone and desktop widths, light and dark.

## Calls made in design (Eric can overrule)

- A chip opens the gear page rather than a filtered Library.
- The Library bulk action "Link to gear" is in scope.
- The gear page card is always shown, with an empty state.
- The gear page card caps at two rows with Show all.
- Gear page linking is held in the gear item's sitting, like the Photos card.
- A link shows only where the active diver can see both the photo and the
  gear; hidden links are kept.
- "Dives with this gear" uses the gear page's own dive union, not only the
  `dive_equipment` junction.
- The Show all page is read-only.

## Left to the builder

- Widget and file names, provider shapes, and how the picker's queries page.
- Gear type icons and chip styling (reuse what the equipment list uses).
- String wording, within the repo's UX copy conventions; all new strings go
  through l10n.
