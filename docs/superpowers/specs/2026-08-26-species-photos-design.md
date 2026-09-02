# Species photos: tag photos with the marine life in them. Design

**Status:** design approved in brainstorming 2026-08-26, spec awaiting review
**Depends on:** `2026-08-26-species-page-design.md` (the Species page, the
`SeenSpeciesTile`, and the detail page's Sightings section). Build after that
branch merges.
**Branches:** phase A on `worktree-species-photos`, phase B on
`worktree-species-photo-surfaces`, each cut from `origin/main` once its
predecessor has merged.
**Origin:** user feedback on the Marine Life feature, part 2 of 3.

## 1. Problem

Photos in Submersion belong to a dive or a site. To see every picture of a
whale shark, a diver has to remember which dives had one, open each, and
scroll its media. Nothing links a photo to the species in it, even though the
schema has carried a `media_species` table for that purpose since schema
version 20; `media_repository.dart` states outright that nothing reads or
writes it. The user asked for two things: add photos directly to a species,
and see all photos of species X in one place.

## 2. Locked decisions

Made during brainstorming on 2026-08-26, in this order:

1. A species is a **tag on a photo that is already attached to a dive or a
   site**. The "attached or absent" rule for media rows is not touched: no
   new attachment kind, no change to the orphan sweep, unlink or deletion
   cascades.
2. "Add photos" to a species imports from the camera roll through the
   existing **reviewed import** (match each photo to a dive or site first,
   insert second), then tags what was imported. Photos that resolve to
   nothing are skipped, as they are today.
3. Tagging a species on a photo whose dive has no sighting of it **adds the
   sighting** (count 1, no notes) and links the tag to it. Untagging never
   removes a sighting.
4. Surfaces, in two phases. Phase A: the species detail gallery, the tag
   picker, the import, and the photo viewer's species sheet and chips.
   Phase B: cover photos on the Species page tiles, photo counts on dive
   detail sighting rows, and a species facet in the media library.
5. **No schema change.** Uniqueness of (photo, species) is enforced in the
   repository and every gallery query uses `DISTINCT`. The table's bounding
   box and notes columns stay unused. Reason: the schema-version ladder has
   four open claims (v165 to v168), and a unique index would still not stop
   two devices creating two rows for the same tag before they sync.
6. The tag picker is a purpose-built page; a photo's tags are edited from a
   bottom sheet opened by a viewer action, the same convention as the info
   sheet.
7. The cover photo of a species is **derived** (its newest tagged photo),
   never chosen. A chosen cover would have to live on the species row, and
   built-in species rows are re-seeded per device and never sync, so the
   choice would not follow the diver to their other devices.

## 3. Data

### 3.1 The existing table

`MediaSpecies` (`lib/core/database/database.dart`): `id`, `mediaId`
(references `media`, cascade), `speciesId` (references `species`, cascade),
`sightingId` (references `sightings`, set null), `bboxX/Y/Width/Height`,
`notes`, `createdAt`. Indexes `idx_media_species_media` and
`idx_media_species_species` already exist. No `hlc` column, and none is
added: like `site_species`, it is a clockless child.

### 3.2 Domain

- `MediaSpeciesTag` (`lib/features/media/domain/entities/media_item.dart`)
  already models a row and is reused unchanged.
- New `SpeciesTagCandidateGroup` (`lib/features/media/domain/entities/`):
  one dive that has a sighting of the species, with `diveId`, `diveNumber`,
  `diveDateTime`, `siteName`, `sightingId` and the untagged `List<MediaItem>`
  on it. Feeds the picker's grouped grid.
- New `SpeciesTagChip`: `speciesId`, `storedName`, `category` and
  `isBuiltIn`; the localized name is resolved at display time from the id,
  as every other species surface does. Feeds the viewer chips and the sheet.

### 3.3 `MediaSpeciesRepository`

`lib/features/media/data/repositories/media_species_repository.dart`, new.
Reads the database through `DatabaseService.instance.database` and maps
media rows through the existing `mediaItemFromRow` in
`media_row_mapper.dart`. Methods:

- `getTagsForMedia(mediaId)` and `getTagsForMediaIds(ids)` (chunked, keyed by
  media id).
- `getMediaForSpecies(speciesId, {diverId})`: `media JOIN media_species`,
  `DISTINCT` on `media.id`, left join enrichment as `getMediaForDive` does,
  scoped to the diver through the photo's dive while keeping site-only
  photos (`media.dive_id IS NULL OR dives.diver_id = ?`, the library's own
  rule), newest `taken_at` first.
- `getCoverMediaBySpecies({diverId})`: one query using
  `ROW_NUMBER() OVER (PARTITION BY species_id ORDER BY taken_at DESC)` to pick
  the newest tagged photo per species. Returns `Map<String, MediaItem>`.
- `getTagCandidatesForSpecies(speciesId, {diverId})`: dives with a sighting
  of the species and their media rows that have no tag for it, grouped as
  `SpeciesTagCandidateGroup`, newest dive first.
- `getPhotoCountsBySpeciesForDive(diveId)`: `Map<String, int>` from
  `media_species JOIN media` grouped by species.
- `addTag({mediaId, speciesId, sightingId})`: returns the existing row when
  one already links that photo and species; otherwise inserts, calls
  `markRecordPending(entityType: 'mediaSpecies', ...)` and notifies the sync
  event bus.
- `removeTag({mediaId, speciesId})`: selects the row id by the pair, deletes
  by id, `logDeletion(entityType: 'mediaSpecies', recordId: id)`, notifies.
- `watchTagChanges()`: `tableUpdates` on `media_species`.

Errors propagate; the widgets show error states.

### 3.4 Sync registration

Copy the `site_species` registration point for point, with
`'media_species': 'mediaSpecies'`:

- `sync_data_serializer.dart`: the `SyncData` field, constructor default,
  `toJson` key and `fromJson` parse; the `_baseTables` entry in the same
  position as the JSON key (the streaming parity test checks the order); the
  full-export call; `fetchRecord`, `upsertRecord`, `upsertRecords`,
  `recordIdsFor`, `_syncTableFor` and `deleteRecord` arms; and
  `_exportMediaSpecies(hlcSince)`, which for an incremental export selects
  rows whose parent `media.hlc` advanced, else the full table. The Drift row
  class is `MediaSpecy`.
- `sync_service.dart`: the `mergeOrder` entry after `media` and `species`
  (a tag needs both parents), `entityHasUpdatedAt['mediaSpecies'] = false`,
  and `parentRefs['mediaSpecies']` with `mediaId` and `speciesId` both
  non-nullable (a tag dies with its parent). `sightingId` needs no entry:
  `sightings` is not a deletable parent in that map.
- Every sync test that enumerates synced tables (`sync_parent_refs_completeness_test`,
  `sync_serializer_upsert_test`, `sync_data_serializer_batch_coverage_test`,
  `sync_serializer_fetch_record_test`, `sync_deletion_propagation_test`,
  `sync_extra_entities_round_trip_test`, `sync_base_streaming_parity_test`)
  gains the `mediaSpecies` tuple. `sync_repository.dart` needs no change:
  `markRecordPending` and `logDeletion` are generic on entity type.

## 4. Tagging service

`SpeciesTaggingService` (`lib/features/media/data/services/`), composed of
`MediaSpeciesRepository`, `MediaRepository` and `SpeciesRepository`:

- `tagPhoto(mediaId, speciesId)`: loads the media row. If it has a dive,
  looks up the dive's sighting of the species and adds one (count 1) when
  missing, then adds the tag with that `sightingId`. If the photo is
  site-only, adds the tag with a null `sightingId`. Returns the tag.
- `tagPhotos(mediaIds, speciesId)`: `tagPhoto` in sequence; a failure on one
  photo is recorded and the rest continue; returns counts and failures.
- `untagPhoto(mediaId, speciesId)`: removes the tag only.

Sighting creation goes through `SpeciesRepository.addSighting`, so the dive
detail page, the Species page and statistics all refresh through the
existing `sightings` tick.

## 5. Importing photos into a species

From the species detail page, **Add photos** runs the library import with a
species attached:

1. `showPhotoPicker` with the unbounded window `MediaImportView` uses.
2. `MediaImportReviewPage` with the same candidates, so the diver sees each
   photo's dive or site match and can correct it.
3. `MediaImportView.importResolved` is extended to return the imported
   `MediaItem`s (its `ImportResult.imported` lists already exist per group),
   and `SpeciesPhotoImportHelper.importPhotosForSpecies` tags each returned
   item through `SpeciesTaggingService.tagPhotos`.
4. The result snackbar reports photos added to the species, photos skipped
   because they matched nothing, and failures, reusing the import's
   existing strings where they fit.

No new `MediaAttachTarget` case: the species is applied after the attach,
never instead of it.

## 6. Phase A user interface

### 6.1 Species detail page: Photos section

Between the statistics section and the Sightings section: a header
"Photos ({n})" with two actions, **Tag photos** and **Add photos**, then a
three-column grid of `MediaThumbnailTile`s (each wrapped for tap, since the
tile itself has no `onTap`). Empty state: a short line saying photos tagged
with this species appear here, with the two actions still shown. Tapping a
thumbnail opens `SpeciesPhotoViewerPage(speciesId, initialMediaId)`.

Providers (`lib/features/media/presentation/providers/species_media_providers.dart`):
`mediaSpeciesRepositoryProvider`, `speciesTaggingServiceProvider`,
`mediaForSpeciesProvider(speciesId)` (ticks on `media_species`, `media` and
`media_enrichment`), `speciesTagCandidatesProvider(speciesId)` (also ticks on
`sightings`), `mediaTagsProvider(mediaId)`, `speciesCoverMediaProvider`, and
`diveSpeciesPhotoCountsProvider(diveId)`. All scoped by
`currentDiverIdProvider`; none watches the Statistics filter.

### 6.2 `SpeciesPhotoViewerPage`

A wrapper like `TripPhotoViewerPage`: resolves `mediaForSpeciesProvider`,
then renders the shared `MediaViewerPage` with that list and the initial id.

### 6.3 `SpeciesTagPickerPage`

Pushed full screen from **Tag photos**. Sections per
`SpeciesTagCandidateGroup`, header "#{diveNumber} · {date} · {site}", a
`DragSelectGridView` of `MediaThumbnailTile`s driven by a
`SelectionController`, a "Select all" action, and a bottom bar with "Tag {n}
photos". Confirm calls `tagPhotos`, pops with the count, and the detail page
shows a snackbar. Empty state: "No untagged photos on dives where you
logged this species" with a hint pointing at Add photos.

### 6.4 Photo viewer

- A "Species" `IconButton` in the top overlay beside Info opens
  `showMediaSpeciesSheet(context, item)`: a `DraggableScrollableSheet` like
  the info sheet. Body: the photo's dive sightings as `FilterChip`s, checked
  when tagged; toggling calls `tagPhoto` / `untagPhoto`. Below them, "Other
  species" opens the existing `SpeciesPickerSheet`; picking one tags the
  photo (and adds the sighting). For a site-only photo the chips row is
  absent and only the search is offered.
- The bottom metadata overlay gains a wrapping row of tag chips (category
  icon plus localized name); tapping one pushes `/species/{id}`. Reads
  `mediaTagsProvider(item.id)`.

## 7. Phase B user interface

- **Species page cover:** `SeenSpeciesTile` gains `MediaItem? cover`; when
  present the leading avatar is a `MediaItemView(thumbnail: true)` clipped to
  a circle, else the category avatar as before. The page watches
  `speciesCoverMediaProvider` once and passes each tile its entry.
- **Dive detail sighting rows:** a trailing chip "{n} photos" (photo icon and
  count) when `diveSpeciesPhotoCountsProvider(diveId)[speciesId] > 0`, next to
  the existing count badge. Tapping it opens the dive's viewer scoped to the
  photos tagged with that species (`DiveSpeciesPhotoViewerPage(diveId,
  speciesId)`, a wrapper that filters `mediaForDiveProvider` by
  `getTagsForMediaIds`).
- **Media library facet:** `MediaLibraryFilter.speciesId` with the same
  sentinel `copyWith` and `toJson`/`fromJson` treatment as `siteId`;
  `_baseWhere` adds `EXISTS (SELECT 1 FROM media_species ms WHERE
  ms.media_id = media.id AND ms.species_id = ?)`; the filter sheet gets a
  species chooser (the manage-page style picker dialog), the active-filter
  chips get a species chip labelled with the localized name, and smart
  albums round-trip the field.

## 8. Integrity rules

- A species with tags is **in use**: `SpeciesRepository.isSpeciesInUse`
  counts tags as well as sightings, and the manage page's delete eligibility
  reads a new `tagCountsBySpecies()` next to `sightingCountsBySpecies()`.
- `deleteSpecies` hard-deletes the species' tags the way it hard-deletes
  `site_species` rows, relying on the species tombstone downstream.
- `MediaRepository.idsWithUserMetadata` includes tagged photos, so
  unlinking a tagged photo warns like unlinking a photo with a manual time.
- `MediaRepository`'s watch stream adds `media_species` to its table set so
  grids that show tag state tick.
- Removing a sighting keeps the tag; the FK nulls `sightingId`.
- Deleting a photo cascades its tags locally; on other devices the `media`
  tombstone plus the non-nullable `parentRefs` entry removes them.

## 9. Localization

New keys in all 11 locales, `media_species_*` for the viewer sheet and
chips, `marineLife_speciesPhotos_*` for the detail section, picker and
import result, `marineLife_speciesDetail_photosTitle`, `diveLog_detail_sightingPhotos`
for the sighting-row chip, and `media_library_filter_species*` for the
facet. Plurals use ICU syntax. Placeholder metadata in `app_en.arb` only.

## 10. Testing

- Repository (in-memory Drift): `addTag` is idempotent; `getMediaForSpecies`
  is distinct and newest first and diver-scoped; candidates exclude tagged
  photos and group by dive with the sighting id; cover is the newest per
  species; per-dive counts; `removeTag` tombstones by row id.
- Service: tagging creates the sighting once and links it; a second tag of
  the same species on another photo of the same dive reuses the sighting;
  a site-only photo tags with a null sighting; untag leaves the sighting.
- Sync: the enumerating suites listed in 3.4 cover registration; one
  round-trip test tags a photo on device A and asserts the tag, and the
  sighting, on device B.
- Widgets (router-backed, base overrides): Photos section with grid,
  actions, empty state and viewer navigation; picker grouping, select all,
  confirm count, empty state; viewer sheet chip toggling and "Other
  species"; overlay chips navigate; import helper tags what the review
  returns (stubbed picker); phase B: cover avatar vs category avatar,
  sighting-row chip and its viewer scope, library facet chip, sheet chooser
  and smart-album round trip.
- l10n parity; one full `flutter test` run per PR.

## 11. Out of scope

- Bounding boxes and per-tag notes (columns stay unused).
- A chosen cover photo; a species reference image without a dive.
- Species photos in PDF or UDDF export.
- Automatic species recognition.
- Tagging site-only photos from the site page (the viewer's search path
  covers them).
