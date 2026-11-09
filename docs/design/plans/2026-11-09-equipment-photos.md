# Equipment Photos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gear items get identification photos, check-ins get condition photos, Media gets a Gear gallery, and a chosen cover photo replaces the type icon in the equipment list and gear page header.

**Architecture:** Gear photos are ordinary `media` rows linked by `equipment_id`. A new nullable `media.observation_id` marks a check-in photo, and a new nullable `equipment.cover_media_id` names the cover. Both are plain synced text columns without an FK constraint (sync applies `media` before `equipmentObservations`, and a peer can delete either end), so every reader treats a dangling id as "no check-in" or "no cover". Queries for gear photos live in a new `GearPhotoRepository`, not in the 3,200-line `MediaRepository`.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), the app's HLC sync.

**Spec:** `docs/design/specs/2026-11-09-equipment-photos-design.md`

## Global Constraints

- Schema version **352** (main is 349; open PRs #4327, #4364/#4366 and #4371 claim 348, 350 and 351). Rung goes in `lib/core/database/migrations/ladder/rungs_v340_onward.dart`, the column helper in `lib/core/database/migrations/helpers/`, the beforeOpen backstop in a `before_open_*.dart` part file. Never in `database.dart` beyond the version constant.
- Links only: no photo is ever copied into app storage.
- A "gear photo" is a row with `equipment_id IS NOT NULL` whose media type is photo or video. A "gear-only" row also has `dive_id IS NULL AND site_id IS NULL`.
- Every new user-visible string goes in `lib/l10n/arb/app_en.arb` with the `equipment_photos_` or `media_gearGallery_` prefix, translated into all 11 ARBs in Task 10.
- No em-dashes anywhere. `dart format .` before each commit.
- Each task commits as `feat(equipment): ...` or `feat(media): ...`.

## Review Focus

1. **An image already linked by the old "Linked files" card:** it shows in the new Photos card and not on Linked files (Task 4 test `legacy card lists only non-photo leftovers`).
2. **A PNG or HEIC gear photo at launch:** `EquipmentFileConverter` leaves it linked, regardless of extension (Task 4 test `converter skips photo and video rows by media type`).
3. **A cover whose photo is unlinked here, or deleted by a peer:** the type icon shows. A local unlink also clears `cover_media_id` (Task 3 test `unlinking the cover clears it`, Task 8 test `dangling cover falls back to icon`).
4. **Adding photos to a new check-in, then Cancel:** the photos are unlinked, so no orphan check-in photos remain (Task 7 test `cancel on a new check-in unlinks its photos`).
5. **A row linked to both a dive and a gear item (legacy):** it stays in the ordinary Library. Only gear-only rows leave it (Task 4 test `library hides gear-only rows but keeps dive-linked gear rows`).

---

### Task 1: Schema v352

**Files:**
- Modify: `lib/core/database/tables/media_tables.dart` (add `observationId` after `equipmentId`), `lib/core/database/tables/equipment_tables.dart` (add `coverMediaId` after `parentEquipmentId`), `lib/core/database/database.dart:318` (349 to 352), `lib/core/database/migrations/ladder/rungs_v340_onward.dart`
- Create: `lib/core/database/migrations/helpers/equipment_photo_migrations.dart` (part file with `_assertEquipmentPhotoColumns()`), wire into `app_database_migrations.dart` parts
- Modify: the beforeOpen part that re-asserts columns (follow `_assertNavTrackSourceFileColumn`'s backstop)
- Regenerate: `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background), `dart run tool/generate_sql_column_notes.dart`
- Test: `test/core/database/migration_v352_equipment_photos_test.dart`

**Interfaces:**
- Produces: `MediaData.observationId` (String?), `EquipmentData.coverMediaId` (String?), columns `media.observation_id TEXT`, `equipment.cover_media_id TEXT`.

- [ ] **Step 1: Write the failing migration test.** Copy the shape of `migration_v344_nav_track_source_file_test.dart`. Tests: `v351 database gains media.observation_id and equipment.cover_media_id`, and `beforeOpen re-adds both columns when missing`. Assert that `PRAGMA table_info` lists both columns as nullable TEXT.
- [ ] **Step 2: Run** `flutter test test/core/database/migration_v352_equipment_photos_test.dart`. Expected: FAIL (columns missing).
- [ ] **Step 3: Implement.** Table columns get doc comments, which become the agent column notes. `TextColumn get observationId => text().nullable()();` is "the check-in (equipment_observations.id) this gear photo backs up; null for an identification photo". `TextColumn get coverMediaId => text().nullable()();` is "the media row chosen to represent this item in the equipment list and page header; null shows the type icon". Rung comment: `// v352: media.observation_id and equipment.cover_media_id (issue #3355). Nullable columns, no backfill. Re-asserted in beforeOpen.`
- [ ] **Step 4: Regenerate and run** the migration test, plus `flutter test test/core/database test/features/agent_access/data/resources`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): add schema for gear photos and cover photo`.

### Task 2: Domain fields

**Files:**
- Modify: `lib/features/media/domain/entities/media_item.dart` (field, constructor, `copyWith` with the `_undefined` sentinel, props), `lib/features/media/data/repositories/media_row_mapper.dart`, `lib/features/media/data/repositories/media_repository.dart` (`createMedia` writes `observationId`; `updateMedia` leaves it out, like `colorAdjustment`)
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart` (`coverMediaId`, `copyWith` with `clearCoverMediaId`), `equipment_repository_impl.dart` `_mapRowToEquipment` (`updateEquipment` does NOT write it)
- Modify: `lib/features/agent_access/data/documents/media_document.dart` and the equipment document if one lists columns (add the fields read-only)
- Test: `test/features/media/data/repositories/media_observation_id_round_trip_test.dart`, extend the equipment repository tests

**Interfaces:**
- Produces: `MediaItem.observationId`, `MediaItem.isGearPhoto` (`equipmentId != null && (mediaType == photo || mediaType == video)`), `MediaItem.isCheckInPhoto` (`isGearPhoto && observationId != null`), `EquipmentItem.coverMediaId`.

- [ ] **Step 1: Failing tests.** `createMedia keeps observationId`, `updateMedia does not clear observationId`, `getEquipmentById maps cover_media_id`, `updateEquipment leaves cover_media_id untouched`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement the fields and getters.**
- [ ] **Step 4: Run** the tests and `flutter test test/features/agent_access`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): carry check-in and cover links on media and gear`.

### Task 3: GearPhotoRepository

**Files:**
- Create: `lib/features/equipment/data/repositories/gear_photo_repository.dart`
- Create: `lib/features/equipment/presentation/providers/gear_photo_providers.dart`
- Modify: `lib/features/media/data/repositories/media_repository.dart` `unlinkFromEquipment` (also writes `observationId: Value(null)`), `lib/features/media/data/services/media_unlink_service.dart` `unlinkFromEquipment` (afterwards clears any `equipment.cover_media_id` that named an unlinked id)
- Test: `test/features/equipment/data/repositories/gear_photo_repository_test.dart`

**Interfaces:**
- Produces (repository, all reads ordered by `taken_at` descending, photo and video only):
  - `Future<List<MediaItem>> identificationPhotos(String equipmentId)` (observation_id null)
  - `Future<List<MediaItem>> photosForObservation(String observationId)`
  - `Future<Map<String, List<MediaItem>>> photosByObservation(String equipmentId)` (one read for the Check-ins card)
  - `Future<List<GearPhotoGroup>> gearGallery(Set<String> equipmentIds)`, with `GearPhotoGroup({required String equipmentId, required String name, required List<MediaItem> items})`, groups ordered by newest photo
  - `Future<void> setCover(String equipmentId, String? mediaId)`: a targeted write of `cover_media_id` plus `updatedAt`, then `markRecordPending('equipment')` and `SyncEventBus.notifyLocalChange()`
  - `Future<void> clearCoversNaming(Iterable<String> mediaIds)`: the same write for every item whose cover is one of the ids
- Produces (providers, each `invalidateSelfWhen(repository.watchMediaChanges())`): `identificationPhotosProvider` (family by equipmentId), `checkInPhotosProvider` (family by equipmentId, returns the map), `observationPhotosProvider` (family by observationId), `gearGalleryProvider` (scoped to the validated current diver; ids from `EquipmentRepositoryImpl.visibleIdsAmong`), `equipmentCoverProvider` (family by equipmentId, `MediaItem?`; null when the id dangles or the row is not a gear photo of that item)

- [ ] **Step 1: Failing tests** (in-memory `AppDatabase`): `identificationPhotos excludes check-in photos and documents`, `photosForObservation returns only that check-in's rows`, `gearGallery groups by item and skips items outside the visible set`, `setCover stamps updatedAt and marks equipment pending`, `unlinking the cover clears it`, `unlinkFromEquipment clears observation_id on rows a dive keeps`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `flutter test test/features/media/data`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): query and manage gear photos`.

### Task 4: Guards on existing paths

**Files:**
- Modify: `lib/features/media/data/repositories/media_library_repository.dart`. `_galleryRow` becomes `fileType NOT IN (...) AND NOT (equipment_id IS NOT NULL AND dive_id IS NULL AND site_id IS NULL)`. Apply the same exclusion in the map query at about line 523, which builds its own predicate.
- Modify: `lib/features/documents/data/services/equipment_file_converter.dart`: skip any item with `mediaType` photo or video, or with `observationId != null`, before `_acceptedKind`
- Modify: `lib/features/equipment/presentation/widgets/equipment_documents_section.dart`: list only rows where `!item.isGearPhoto` (the leftover paperwork), and hide the card when that filtered list is empty
- Modify: `lib/features/equipment/data/services/equipment_clone_service.dart` `_copyMedia`: skip `isGearPhoto` rows
- Modify: `lib/features/equipment/data/services/equipment_item_fold.dart`: when the survivor's `cover_media_id` is null, take the folded item's
- Modify: `lib/features/equipment/presentation/widgets/equipment_observation_sheet.dart` `confirmDeleteObservation`: after the delete, `unlinkFromEquipment` on that check-in's photo ids; when it had photos, the dialog text is `equipment_photos_deleteCheckInWithPhotos` ("Delete this check-in? Its {count} photos will be removed from Submersion. The files themselves are not touched.")
- Tests: extend `media_library_repository` tests, `equipment_file_converter_test.dart`, `equipment_documents_section_test.dart`, the clone service test, the fold test, and the observation sheet test

- [ ] **Step 1: Failing tests:** `library hides gear-only rows but keeps dive-linked gear rows` (grid, count and map), `converter skips photo and video rows by media type` (a `.png` photo row stays linked), `legacy card lists only non-photo leftovers`, `clone copies no gear photos`, `fold keeps survivor cover, else takes folded cover`, `deleting a check-in unlinks its photos`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/media test/features/documents test/features/equipment`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): keep gear photos out of the library, documents and clones`.

### Task 5: Attaching gear photos

**Files:**
- Modify: `lib/features/media/domain/value_objects/media_attach_target.dart`: add `final class EquipmentAttachTarget extends MediaAttachTarget { const EquipmentAttachTarget(this.equipmentId, {this.observationId}); }` with both ids in props
- Modify every exhaustive switch the analyzer flags: `media_import_view.dart`, `network_import_targets.dart`, `files_tab_providers.dart`, `files_tab_staging.dart`, `files_tab.dart`, `media_drop_import.dart`, `media_import_review_page.dart`. Equipment behaves like a site (owns every file, no dive matching), stamping `equipmentId` and `observationId`.
- Modify: `lib/features/media/data/services/media_import_service.dart`: `Future<ImportResult> importPhotosForEquipment({required List<AssetInfo> selectedAssets, required String equipmentId, String? observationId})`, the site path's twin. Dedupe against that item's gallery links and local paths through two `GearPhotoRepository` methods: `galleryLinksFor(String equipmentId)` and `linkedLocalPathsFor(String equipmentId)`.
- Create: `lib/features/equipment/presentation/helpers/gear_photo_import_helper.dart` with `GearPhotoImportHelper.importPhotos({context, ref, equipmentId, observationId})` and a testable `linkSelectedAssets(...)`, mirroring `SiteMediaImportHelper`
- Tests: `test/features/media/data/services/media_import_service_equipment_test.dart`, `test/features/equipment/presentation/helpers/gear_photo_import_helper_test.dart`, extend `files_tab_providers` tests

- [ ] **Step 1: Failing tests:** `importPhotosForEquipment links rows with equipmentId and observationId`, `importPhotosForEquipment skips an asset already linked to the item`, `files tab stamps equipment and check-in on an equipment session`, `linkSelectedAssets reports the count and invalidates the gear providers`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter analyze` (zero issues), then the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): attach photos to gear and check-ins`.

### Task 6: Photos card on the gear page

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_photos_section.dart` (`EquipmentPhotosSection({required EquipmentItem equipment})`)
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart`: insert it directly above `ObservationsCard`
- Test: `test/features/equipment/presentation/widgets/equipment_photos_section_test.dart`

Behaviour: header `equipment_photos_title` ("Photos") with an `Icons.photo_library` icon, the selection button, and an Add button (`equipment_photos_add`), which calls `GearPhotoImportHelper.importPhotos`. A 4-column grid of `MediaThumbnailTile`; the cover tile carries a small star badge. Tap opens `openMediaViewer(context, items, id)`. A long press is not used. Bulk selection (`SelectionController`, `SelectionAppBar` with `SelectionBarShell.pane`) offers Remove (`unlinkEquipmentMedia`, confirm dialog `equipment_photos_removeConfirm`) and, with exactly one checked, `equipment_photos_setCover` ("Use as cover photo") or `equipment_photos_clearCover` ("Remove cover photo") when that one is the cover. Empty state `equipment_photos_empty` ("Add photos of this item, its serial number label or markings, for reference."). On a device without `deviceCapabilities.mediaAttach`, there is no Add, no selection and no cover action.

- [ ] **Step 1: Failing widget tests:** `shows identification photos and not check-in photos`, `set cover from selection calls setCover`, `cover tile shows the badge`, `remove confirms then unlinks`, `no add or selection without mediaAttach`, `empty state text`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the tests and `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): photos card on the gear page`.

### Task 7: Check-in photos

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_observation_repository.dart` `create`: an optional `String? id`, used instead of `_uuid.v4()` when given
- Modify: `lib/features/equipment/presentation/widgets/equipment_observation_sheet.dart`: `_Draft` gets an `id` (`existing?.id ?? uuid` generated when the draft opens). The editor shows a photos row (`equipment_photos_checkInPhotos`, "Photos"): `observationPhotosProvider(draft.id)` thumbnails, each with a remove control, plus an Add control calling `GearPhotoImportHelper.importPhotos(equipmentId:, observationId: draft.id)`. `_save` passes `id: draft.id` to `create`. Closing a NEW draft without saving (Cancel, dismissing the sheet) unlinks `photosForObservation(draft.id)`.
- Modify: `lib/features/equipment/presentation/widgets/observations_card.dart` `_ObservationRow`: under the subtitle, a strip of 44px thumbnails from `checkInPhotosProvider(equipment.id)[observation.id]`. Tap opens `openMediaViewer` on that check-in's photos.
- Tests: extend `equipment_observation_sheet_test.dart` and `observations_card_test.dart`

- [ ] **Step 1: Failing tests:** `editor lists the check-in's photos`, `save of a new check-in uses the draft id`, `cancel on a new check-in unlinks its photos`, `cancel on an existing check-in keeps its photos`, `row shows a strip only when the check-in has photos`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/equipment test/features/safety`. The incident page opens the sheet, so its tests count. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): photos on check-ins`.

### Task 8: Cover photo avatar

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_avatar.dart`: `EquipmentAvatar({required EquipmentItem item, required double radius, Color? backgroundColor, Color? iconColor})`. When `item.coverMediaId != null` and `equipmentCoverProvider(item.id)` yields a row, it shows a rounded square (radius/4 corners) holding `MediaItemView(item: cover, thumbnail: true, fit: BoxFit.cover, onImageFailed: fallback)`. Otherwise it shows today's `CircleAvatar` with `equipmentTypeIcon`.
- Modify: `equipment_list_content.dart:1673` (list tile leading; keep the overdue colours for the icon fallback) and both header spots in `equipment_detail_page.dart` (about line 400, radius 20; about line 517, radius 32)
- Test: `test/features/equipment/presentation/widgets/equipment_avatar_test.dart`

- [ ] **Step 1: Failing tests:** `no cover shows the type icon`, `cover shows the photo`, `dangling cover falls back to icon`, `cover that fails to load falls back to icon`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/equipment`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(equipment): show the chosen cover photo for gear`.

### Task 9: Gear gallery in Media

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_console_scaffold.dart`: `MediaConsoleSection.gear`, placed after `library`, label `media_gearGallery_tab` ("Gear"), offered on every device (a browser sees the gallery read-only)
- Modify: `lib/features/media/presentation/pages/media_section_page.dart`: the switch arm builds `GearGalleryView()`
- Create: `lib/features/media/presentation/pages/gear_gallery_view.dart`: a scrolling list of groups from `gearGalleryProvider`. Each group has a header row (item name and `media_gearGallery_count` "{count} photos") that opens `/equipment/<id>`, then a 4-column `MediaThumbnailTile` grid. A check-in photo carries a small `Icons.fact_check_outlined` badge. Selection plus Remove work as in Task 6, using `MediaUnlinkService.unlinkFromEquipment`. Empty state: `media_gearGallery_empty` ("Photos you add to your gear and its check-ins show up here.").
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart`: an optional `String? Function(MediaItem)? captionFor`, shown as the viewer's subtitle line. `openMediaViewer` gains the same optional named parameter. The gallery passes a caption built from the check-in (`equipment_photos_checkInCaption`, "Check-in: {title}, {date}"), using `EquipmentObservation.displayTitle` and the diver's date format.
- Tests: `test/features/media/presentation/pages/gear_gallery_view_test.dart`, extend the media console scaffold test

- [ ] **Step 1: Failing tests:** `gear tab is offered and shows groups`, `check-in photos carry the badge`, `header tap navigates to the item`, `remove unlinks selected photos`, `viewer shows the check-in caption`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test test/features/media/presentation`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): gear gallery`.

### Task 10: Translations and full verification

- [ ] **Step 1:** Translate every new `equipment_photos_*` and `media_gearGallery_*` key into the 10 non-English ARBs, keeping placeholders and ICU plurals intact. Run `flutter gen-l10n`.
- [ ] **Step 2:** `dart format .`, then `flutter analyze` (expected: No issues found), then `flutter test test/architecture test/shared test/core/database test/core/services/sync test/features/equipment test/features/media test/features/documents test/features/agent_access test/features/safety`. Expected: all pass.
- [ ] **Step 3: Commit** `feat(equipment): translate gear photo strings`.
- [ ] **Step 4:** Build macOS debug and capture the after screenshots for the five before shots. Also capture the Gear gallery, the Photos card with a cover chosen, and the check-in sheet with photos.
