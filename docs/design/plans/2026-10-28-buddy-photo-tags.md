# Tag People in Photos and Videos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver tag buddies and themself ("Me") on photos (with a face box) and videos (at a moment), see those tags in the viewer, and find a person's media from the buddy page and the library filter.

**Architecture:** One new synced child table, `media_people`, mirrors `media_species` for storage and sync, but rows are editable and carry `updated_at`. A `MediaPeopleRepository` owns every read and write, scoped to the viewing diver. The viewer gains a people chip row, a face-box layer inside the PhotoView child, and a tag mode modelled on colour adjustment's pick-white mode (`ColorAdjustViewerMixin`).

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, photo_view, video_player, flutter_test.

**Spec:** `docs/design/specs/2026-10-28-buddy-photo-tags-design.md` (mockup in `docs/design/specs/assets/2026-10-28-buddy-photo-tags-mockup.html`). Read both.

## Global Constraints

- Schema version **326** (v319, v321, v322 are held by open PR #3726 and v325 is #3786's; planned as 323, renumbered at merge after #3748 took 323 and #3728 took 324). `minimumCompatibleSchemaVersion` stays 308: the change is additive.
- Tables go in `lib/core/database/tables/`, rungs and helpers in `lib/core/database/migrations/`; `database.dart` only gains the table in its `tables:` list, the version constant and the `migrationVersions` entry.
- Exactly one of `buddy_id` / `diver_id` is set on a row; box columns are all set or all null; normalised 0 to 1 against the full image.
- A profile sees only its own tags: buddy tags whose buddy has `buddies.diver_id` = the viewing diver, and Me tags whose `diver_id` = the viewing diver. A buddy's `linked_diver_id` is never treated as Me.
- "Me" in `MediaLibraryFilter` is a flag (`includeMe`), never a diver id.
- Videos that cannot play (Linux, `MediaSourceType.serviceConnector`, a missing file) allow only "Tag without a spot"; their moment chips show the time and do not seek.
- Tags and dive buddies stay independent: no code path adds or removes a `dive_buddies` row except the user's "Add" on the offer.
- Media stays links only; nothing copies image data.
- No new package or native dependency. Works on macOS, Windows, Linux, iOS, Android.
- New UI goes in new widget files; `media_viewer_page.dart` gets only wiring. Files 200 to 400 lines typical, 800 max.
- Every user-visible string in `app_en.arb` and all 10 other ARBs (ar, de, es, fr, he, hu, it, nl, pt, zh), real translations, `flutter gen-l10n` run last (Task 12).
- Paths via `p.join`; tests restore any global state they replace (`addTearDown`).
- No em-dashes in code, comments, strings or docs.

## Review Focus

1. **A buddy merged into one already tagged on the same photo**: the photo ends with one tag for the survivor, not two; undo brings both back. Test in Task 5.
2. **A saved smart album naming a deleted or merged buddy**: merge repoints it; a deleted buddy alone drops the facet rather than matching nothing (same rule as tags). Tests in Tasks 4 and 5.
3. **Shared media seen by a second profile**: profile B sees none of profile A's chips, boxes or filter matches, and tag mode cannot edit them. Tests in Tasks 2 and 4.
4. **A photo with no stored width/height**: boxes still place correctly once the image decodes (size comes from `MediaItemView.onImageSize`); before that, tag mode offers only "Tag without a spot". Test in Task 7.
5. **Tagging on an unplayable video** (Linux or connector): only "Tag without a spot" is offered; an existing moment chip shows its time and tapping it does nothing. Test in Task 8.

---

## File Structure

Create:
- `lib/core/database/tables/media_people_tables.dart`: the `MediaPeople` table.
- `lib/core/database/migrations/helpers/media_people_migrations.dart`: `_assertMediaPeopleSchema()` (part file).
- `lib/features/media/domain/entities/media_person_tag.dart`: `MediaPersonTag`, `FaceBox`, `MediaPersonChip`.
- `lib/features/media/data/repositories/media_people_repository.dart`: reads and writes.
- `lib/features/media/data/repositories/media_people_buddy_merge.dart`: merge repoint, dedupe, undo, smart-album buddy repoint.
- `lib/features/media/presentation/providers/media_people_providers.dart`
- `lib/features/media/presentation/helpers/face_box_geometry.dart`: pure tap/box mapping.
- `lib/features/media/presentation/widgets/people_tags/media_people_chips_row.dart`
- `lib/features/media/presentation/widgets/people_tags/face_box_layer.dart`
- `lib/features/media/presentation/widgets/people_tags/people_tag_viewer_mixin.dart`
- `lib/features/media/presentation/widgets/people_tags/people_tag_hint.dart`
- `lib/features/media/presentation/widgets/people_tags/people_tag_editor.dart`: the pending/editable box with handles.
- `lib/features/media/presentation/widgets/people_tags/person_picker_sheet.dart`
- `lib/features/media/presentation/widgets/people_tags/add_to_dive_offer.dart`
- `lib/features/media/presentation/widgets/people_tags/video_tag_marks.dart`
- `lib/features/buddies/presentation/widgets/buddy_photos_section.dart`

Modify (anchors, not exhaustive line numbers):
- `lib/core/database/database.dart` (tables list near `MediaTags,` line 119; `currentSchemaVersion` line 298; `migrationVersions` after `320,`)
- `lib/core/database/migrations/app_database_migrations.dart` (part list)
- `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v320 rung)
- `lib/core/database/migrations/before_open_table_backstops.dart` (beside `_assertNearbySchema()`)
- `lib/core/database/migrations/helpers/sync_migrations.dart` (hlc list beside `'media_tags'`)
- `lib/core/data/repositories/sync_repository.dart` (table map beside `'mediaTags'`)
- `lib/core/services/sync/sync_data_serializer.dart` (every `'mediaSpecies'` arm)
- `lib/core/services/sync/sync_service.dart` (record types ~1960, `hasUpdatedAt` map ~2961, parent refs ~3429)
- `lib/features/media/data/repositories/media_repository.dart` (`deleteMedia`, `deleteMultipleMedia`)
- `lib/features/media/data/repositories/media_row_restore.dart`
- `lib/features/media/data/repositories/media_library_repository.dart` (`_baseWhere`, `watchMediaChanges`)
- `lib/features/media/domain/entities/media_library_filter.dart`
- `lib/features/buddies/data/repositories/buddy_repository.dart` (`deleteBuddy`)
- `lib/features/buddies/data/repositories/buddy_merge_repository.dart` (`mergeBuddies`, `undoMerge`, `bulkDeleteBuddies`, `BuddyMergeSnapshot`)
- `lib/features/divers/data/repositories/diver_delete_steps.dart` (`diverDiveSteps`)
- `lib/features/media/presentation/widgets/media_item_view.dart` (`onImageSize`)
- `lib/features/media/presentation/widgets/media_viewer_toolbar.dart` (people action)
- `lib/features/media/presentation/pages/media_viewer_page.dart` (wiring only)
- `lib/features/media/presentation/widgets/media_library_filter_sheet.dart`, `media_library_active_filter_chips.dart`
- `lib/features/buddies/presentation/pages/buddy_detail_page.dart` (mount section)
- `lib/l10n/arb/app_*.arb` (11 files) and generated `app_localizations*.dart`

Tests (create): one file per task named below, under the mirrored `test/` path.

---

### Task 1: The `media_people` table and the v326 rung

**Files:**
- Create: `lib/core/database/tables/media_people_tables.dart`, `lib/core/database/migrations/helpers/media_people_migrations.dart`
- Modify: `database.dart`, `app_database_migrations.dart`, `rungs_v231_onward.dart`, `before_open_table_backstops.dart`
- Test: `test/core/database/migration_v326_media_people_test.dart`

**Interfaces:**
- Produces: Drift table `MediaPeople` (accessor `db.mediaPeople`, data class `MediaPeopleData`, companion `MediaPeopleCompanion`) with columns `id` (text pk), `mediaId` (FK `media`, cascade), `buddyId` (nullable FK `buddies`, cascade), `diverId` (nullable FK `divers`, cascade), `bboxX`, `bboxY`, `bboxWidth`, `bboxHeight` (nullable real), `videoPositionMs` (nullable int), `createdAt`, `updatedAt` (int), `hlc` (nullable text). Indexes `idx_media_people_media` on `media_id`, `idx_media_people_buddy` on `buddy_id`, `idx_media_people_diver` on `diver_id`, created in `_assertMediaPeopleSchema()`.

- [ ] **Step 1: Write the failing migration test**, modelled on `migration_v320_nearby_peers_test.dart`:
  - `'v326 is in the ladder and did not move the sync floor'`: `currentSchemaVersion >= 326`, `migrationVersions` contains 326, `minimumCompatibleSchemaVersion` is not 326, step count from the version below 326 is one more than from 326.
  - `'a v320 database gains media_people with its columns and indexes on open'`: a `PRAGMA user_version = 320` memory DB (with `divers`, `buddies`, `media` stubs) opened as `AppDatabase` has `media_people` with exactly the columns above, and the three indexes in `PRAGMA index_list('media_people')`.
  - `'the backstop recreates media_people when a parallel branch skipped it'`: a DB at `user_version = 326` without the table gains it on open.
- [ ] **Step 2: Run** `flutter test test/core/database/migration_v326_media_people_test.dart`. Expected: FAIL (no table, version 320).
- [ ] **Step 3: Implement.** Table class with a doc comment saying why it carries `updated_at` (rows are edited: box moved, person changed) unlike `MediaSpecies`. Register in `database.dart` `tables:` after `MediaTags`; `currentSchemaVersion = 326`; append `326,` to `migrationVersions` with a comment naming #1745 and that 319/321/322 are held by #3726 and the floor does not move. Helper `_assertMediaPeopleSchema()` in a part file (create table if missing, then `CREATE INDEX IF NOT EXISTS` for each index); add the `part` line; rung `if (from < 326) { await _assertMediaPeopleSchema(); } if (from < 326) await reportProgress();`; call it from the table backstops.
- [ ] **Step 4: Regenerate and run.** `dart run build_runner build --delete-conflicting-outputs` (or `bash scripts/setup.sh` if denied), then the test. Expected: PASS. Also run `flutter test test/core/database` (the before-open guard lives there).
- [ ] **Step 5: Commit** `feat(media): media_people table at schema v326`.

### Task 2: Domain entities and `MediaPeopleRepository`

**Files:**
- Create: `lib/features/media/domain/entities/media_person_tag.dart`, `lib/features/media/data/repositories/media_people_repository.dart`
- Test: `test/features/media/data/repositories/media_people_repository_test.dart` (reuse `species_photo_fixtures.dart`; add `insertTestBuddy({required String id, required String name, String? diverId})` to it)

**Interfaces:**
- Consumes: `db.mediaPeople` (Task 1).
- Produces:
  - `class FaceBox extends Equatable { final double x, y, width, height; }` with `FaceBox.clamped(...)` that clamps to [0, 1] and keeps width/height at least `FaceBox.minSize = 0.02`.
  - `class MediaPersonTag extends Equatable { String id; String mediaId; String? buddyId; String? diverId; FaceBox? box; Duration? videoPosition; DateTime createdAt; DateTime updatedAt; bool get isMe => diverId != null; }` with `copyWith`.
  - `class MediaPersonChip extends Equatable { MediaPersonTag tag; String? buddyName; }` (null name for Me).
  - `MediaPeopleRepository` (same `_db` / `SyncRepository` / `SyncEventBus` idiom as `MediaSpeciesRepository`):
    - `Stream<void> watchTagChanges()`
    - `Future<List<MediaPersonTag>> getTagsForMedia(String mediaId, {required String? diverId})`: scoped (Global Constraints), ordered Me first, then buddy name, then `videoPosition`.
    - `Future<List<MediaPersonChip>> getChipsForMedia(String mediaId, {required String? diverId})`
    - `Future<MediaPersonTag> addTag({required String mediaId, String? buddyId, String? diverId, FaceBox? box, Duration? videoPosition})`: asserts exactly one person; on a **photo** (`media.file_type != 'video'`) a second tag of the same person **replaces** the first's box (returns the existing row, updated) rather than adding a row; on a video a new row per moment.
    - `Future<void> updateTag(MediaPersonTag tag)`: writes person, box, position, `updatedAt`, marks pending.
    - `Future<void> removeTag(String tagId)`: deletes and tombstones `mediaPeople`.
    - `Future<List<MediaItem>> getMediaForBuddy(String buddyId, {required String? diverId})`: distinct, newest first, `_diverScope` rule as in `MediaSpeciesRepository.getMediaForSpecies`.
    - `Future<void> deleteForMedia(List<String> mediaIds)` and `Future<void> deleteForBuddies(List<String> buddyIds)`: delete and tombstone in chunks of 500; run inside the caller's transaction, do not notify.

- [ ] **Step 1: Write failing tests:**
  - `'addTag stores a buddy face box and marks the row pending'`: box round-trips; `getTagsForMedia` returns it; a pending sync record exists for `mediaPeople`.
  - `'addTag rejects a row with both or neither person'`: throws `ArgumentError`.
  - `'a second tag of the same person on a photo replaces the box'`: one row, new box.
  - `'a video keeps one tag per moment for the same person'`: two rows at 42 s and 118 s.
  - `'updateTag changes the person and bumps updatedAt'`
  - `'removeTag deletes and tombstones the row'`
  - `'getTagsForMedia shows a profile only its own tags'`: diver A's buddy tag and A's Me tag are invisible with `diverId: 'B'`; B's own tag is visible.
  - `'getTagsForMedia orders Me first, then buddies by name, then moment'`
  - `'getMediaForBuddy returns each tagged item once, newest first'`
  - `'deleteForBuddies tombstones every tag of those buddies'`
- [ ] **Step 2: Run** the file. Expected: FAIL (missing classes).
- [ ] **Step 3: Implement** the entities and repository with the signatures above. Ownership filter: `diver_id = ?` OR `buddy_id IN (SELECT id FROM buddies WHERE diver_id = ?)`; a null `diverId` means no scoping.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): repository for people tags on media`.

### Task 3: Sync registration

**Files:**
- Modify: `sync_data_serializer.dart`, `sync_service.dart`, `sync_repository.dart`, `sync_migrations.dart`
- Test: `test/core/services/sync/sync_media_people_registration_test.dart` (modelled on `sync_media_species_registration_test.dart`)

**Interfaces:**
- Consumes: Task 1 table, Task 2 repository.
- Produces: sync entity type `'mediaPeople'`, table `'media_people'`, JSON key `mediaPeople` on `SyncData`.

- [ ] **Step 1: Write failing tests:** `'upsertRecord and deleteRecord round-trip a remote tag'`; `'SyncData carries mediaPeople through toJson and fromJson'`; `'mediaPeople merges as a child of media and buddies with updatedAt'` (parent refs `mediaId -> media` non-null and `buddyId -> buddies` nullable; `hasUpdatedAt` true); `'a tag written through the repository is stamped with an hlc'`; `'an edited tag lands in the incremental changeset'`.
- [ ] **Step 2: Run** it plus `test/core/services/sync/sync_hlc_target_registration_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Add a `'mediaPeople'` arm at every site `grep -n "'mediaSpecies'\|mediaSpecies:" sync_data_serializer.dart` lists, mirroring that arm with `MediaPeopleData.fromJson`. In `sync_service.dart`: the record-type list entry with `hasUpdatedAt: true`, `'mediaPeople': true` in the updatedAt map, parent refs `[(field: 'mediaId', parent: 'media', nullable: false), (field: 'buddyId', parent: 'buddies', nullable: true)]` with a comment that `diverId` is left to `repairDanglingForeignKeys` like every diver key. Table map and hlc list beside `media_tags`. Merge order after `media`, `buddies`, `divers`.
- [ ] **Step 4: Run** `flutter test test/core/services/sync test/architecture`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(sync): sync people tags on media`.

### Task 4: People facet in the library filter

**Files:**
- Modify: `media_library_filter.dart`, `media_library_repository.dart`
- Test: `test/features/media/domain/entities/media_library_filter_people_test.dart`, `test/features/media/data/repositories/media_library_people_filter_test.dart`

**Interfaces:**
- Produces: `MediaLibraryFilter` fields `final Set<String> buddyIds; final bool includeMe;` (defaults `const {}`, `false`), in `isEmpty`, `copyWith({Set<String>? buddyIds, bool? includeMe})`, `==`, `hashCode`. JSON keys `'buddyIds'` (sorted list, omitted when empty) and `'me': true` (omitted when false). `bool get hasPeople => buddyIds.isNotEmpty || includeMe;`

- [ ] **Step 1: Write failing tests:**
  - Entity: `'an album saved before people decodes to no people facet'`; `'buddyIds and me round-trip, sorted, omitted when empty'`; `'unknown keys survive a repoint'` (via `{...decoded, ...filter.toJson()}`).
  - Repository (`getPage` with a `diverId`): `'buddyIds matches media tagged with any of them, once each'`; `'includeMe matches the viewing diver's Me tags only'`; `'Me for diver A does not match diver B's Me tags'`; `'a filter naming only deleted buddies drops the facet'`; `'watchMediaChanges ticks on a media_people write'`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** the fields, then in `_baseWhere` an `EXISTS` on `media_people` (`media_id = m.id AND (buddy_id IN buddyIds OR (includeMe AND diver_id = diverId))`; with `diverId` null, Me matches any `diver_id IS NOT NULL`), with the tag facet's "drop when nothing selected exists" rule applied to buddies when `includeMe` is false. Add `_db.mediaPeople` to `watchMediaChanges`.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): filter the library by people`.

### Task 5: Housekeeping on delete, restore and merge

**Files:**
- Create: `lib/features/media/data/repositories/media_people_buddy_merge.dart`
- Modify: `media_repository.dart`, `media_row_restore.dart`, `buddy_repository.dart`, `buddy_merge_repository.dart`, `diver_delete_steps.dart`
- Test: `test/features/media/data/repositories/media_people_housekeeping_test.dart`, `test/features/buddies/data/repositories/buddy_merge_media_people_test.dart`

**Interfaces:**
- Consumes: `MediaPeopleRepository.deleteForMedia` / `deleteForBuddies` (Task 2).
- Produces (in `media_people_buddy_merge.dart`):
  - `class MediaPeopleMergeSnapshot { final Map<String, String> originalBuddyIds; final List<MediaPeopleData> removedDuplicates; }`
  - `Future<MediaPeopleMergeSnapshot> repointMediaPeopleForMerge(AppDatabase db, SyncRepository sync, {required List<String> fromBuddyIds, required String toBuddyId, required int now})`: repoints, then on photos removes (and tombstones) a repointed row when the survivor already has one on that media.
  - `Future<void> undoMediaPeopleMerge(AppDatabase db, SyncRepository sync, MediaPeopleMergeSnapshot snapshot, {required int now})`
  - `Future<void> repointSmartAlbumBuddies(AppDatabase db, SyncRepository sync, {required List<String> fromBuddyIds, required String toBuddyId, required int now})`: same shape as `repointSmartAlbumTags`, on `MediaLibraryFilter.buddyIds` (added in Task 4).
- `BuddyMergeSnapshot` gains `final MediaPeopleMergeSnapshot? mediaPeople;`.
- `diverDiveSteps` gains first: `(table: 'media_people', entityType: 'mediaPeople', where: 'diver_id = ?1 OR buddy_id IN (SELECT id FROM buddies WHERE diver_id = ?1)')`.

- [ ] **Step 1: Write failing tests:**
  - `'deleting media tombstones its people tags'` and `'undoing a media delete restores its people tags'` (`readMediaRows` / `restoreMediaRows` carry `people`; a restored row whose buddy is gone is skipped).
  - `'deleting a buddy tombstones their tags'`, and the same for `bulkDeleteBuddies`.
  - `'deleting a diver removes their Me tags and their buddies tags'`
  - `'merging divers moves Me tags to the keeper'` (generic `diver_id` repoint, no code change expected).
  - `'merging buddies moves tags to the survivor'`; `'a photo tagged with both buddies keeps one survivor tag'`; `'undoing the merge restores both tags'`; `'a smart album filtered on the duplicate now names the survivor'`.
- [ ] **Step 2: Run** both files. Expected: FAIL.
- [ ] **Step 3: Implement.** Call `deleteForMedia(targets)` beside `_tagLinks.deleteLinksFor` in both media deletes; add `people` to `MediaRowsSnapshot`, `readMediaRows` and the restore loop (mirror the `mediaTags` block, checking the buddy or diver still exists via `existingRowIds`). Call `deleteForBuddies` inside the `deleteBuddy` and `bulkDeleteBuddies` transactions before the buddy delete. In `mergeBuddies`, call `repointMediaPeopleForMerge` and `repointSmartAlbumBuddies` inside the transaction and store the snapshot; `undoMerge` calls `undoMediaPeopleMerge` after re-creating buddies.
- [ ] **Step 4: Run** both files plus `test/features/buddies`, `test/features/divers`, `test/features/media/data`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): keep people tags through deletes, restores and merges`.

### Task 6: Providers

**Files:**
- Create: `lib/features/media/presentation/providers/media_people_providers.dart`
- Test: `test/features/media/presentation/providers/media_people_providers_test.dart`

**Interfaces:**
- Produces:
  - `mediaPeopleRepositoryProvider` (`Provider<MediaPeopleRepository>`)
  - `mediaPeopleChipsProvider` (`FutureProvider.family<List<MediaPersonChip>, String>` by media id, scoped by `currentDiverIdProvider`, invalidated on `watchTagChanges()` and buddy changes)
  - `mediaForBuddyProvider` (`FutureProvider.family<List<MediaItem>, String>` by buddy id)
  - `personPickerOptionsProvider` (`FutureProvider.family<PersonPickerOptions, String?>` by dive id) with `class PersonPickerOptions { final List<Buddy> onThisDive; final List<Buddy> everyoneElse; }` (everyone else sorted by name, excluding those on the dive; `onThisDive` empty when dive id is null).
- [ ] **Step 1: Failing tests:** chips refresh after `addTag`; picker options split a dive's buddies from the rest and exclude another diver's buddies.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): providers for people tags`.

### Task 7: Viewing tags (chips, boxes, image size)

**Files:**
- Create: `face_box_geometry.dart`, `media_people_chips_row.dart`, `face_box_layer.dart`
- Modify: `media_item_view.dart` (add `final ValueChanged<Size>? onImageSize;`, called once with the decoded image's pixel size), `media_viewer_page.dart` (`_PhotoItem` becomes a `Stack` of `MediaItemView` and `FaceBoxLayer` inside the PhotoView child so boxes zoom with the photo; `MediaPeopleChipsRow` above `MediaSpeciesChipsRow` in `_BottomMetadataOverlay`)
- Test: `test/features/media/presentation/helpers/face_box_geometry_test.dart`, `test/features/media/presentation/widgets/people_tags/media_people_chips_row_test.dart`, `.../face_box_layer_test.dart`

**Interfaces:**
- Produces in `face_box_geometry.dart`:
  - `Rect containedImageRect(Size image, Size box)` (BoxFit.contain, centred)
  - `Offset? normalizedPoint(Offset tap, Size image, Size box)` (null outside the image)
  - `FaceBox boxAround(Offset normalized, {double size = 0.18, required Size image})` (square in screen terms, clamped)
  - `Rect boxRect(FaceBox box, Size image, Size viewBox)`
  - `String formatMoment(Duration d)` ("0:42", "1:02:05")
- `MediaPeopleChipsRow({required String mediaId, ValueChanged<MediaPersonTag>? onMomentTap})`: Me chip opens `/media` library route with `MediaLibraryFilter(includeMe: true)` (use the same navigation helper `media_tag_navigation.dart` uses for tag chips); buddy chip pushes `/buddies/<id>`; moment chips call `onMomentTap`.
- `FaceBoxLayer({required String mediaId, required Size? imageSize, required bool visible, Duration? showAt})`: draws boxes with a name label; on video only the tags at `showAt` (within 500 ms).

- [ ] **Step 1: Failing tests:** geometry (letterboxed portrait image in a landscape box; tap in the bar returns null; clamp at edges; `formatMoment`); chips row (renders nothing when empty; Me first; "Alex · 0:42" label; tapping buddy pushes the route); box layer (hidden when `visible` false; no boxes until `imageSize` known; label text).
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** Boxes follow `_showOverlay` (and the fullscreen controls flag) as `visible`. The viewer passes `onMomentTap`: when the item's controller is initialised and playable it pauses, seeks to `tag.videoPosition` and sets `showAt` for that page; otherwise it does nothing (Task 8 pins the unplayable case).
- [ ] **Step 4: Run** the new tests and `test/features/media/presentation`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): show people tags in the viewer`.

### Task 8: Tag mode

**Files:**
- Create: `people_tag_viewer_mixin.dart`, `people_tag_hint.dart`, `people_tag_editor.dart`, `video_tag_marks.dart`
- Modify: `media_viewer_toolbar.dart` (action `Icons.person_add_alt_1`, label from l10n, `onTagPeople` callback, same pattern as `onTagSpecies`), `media_viewer_page.dart` (mix in, tap layers mirroring the pick-white ones, video pause, marks in `_VideoControlsOverlay`)
- Test: `test/features/media/presentation/widgets/people_tags/people_tag_mode_test.dart`

**Interfaces:**
- Produces `mixin PeopleTagViewerMixin<T extends ConsumerStatefulWidget> on ConsumerState<T>` with `bool taggingPeople`, `PendingFaceTag? pendingTag`, `void togglePeopleTagging(MediaItem item, {VideoPlayerController? controller})` (pauses a video), `Future<void> placeTagAt(MediaItem item, Offset tap, Size box, Size? image, {Duration? at})`, `Future<void> tagWithoutSpot(MediaItem item)`, `Future<void> editTag(MediaItem item, MediaPersonTag tag)`. `class PendingFaceTag { FaceBox box; Duration? at; String? existingTagId; }`.
- `bool canPlaceSpot(MediaItem item, {required VideoPlayerController? controller, required Size? imageSize})`: false for Linux (`!kIsWeb && Platform.isLinux`, injectable for tests via a `bool? linuxOverride` parameter), connector videos, a video whose controller is null or errored, and a photo whose image size is unknown.
- `PeopleTagHint({required bool canPlaceSpot, required VoidCallback onWithoutSpot, required VoidCallback onCancel})`: "Tap a person to tag them" plus "Tag without a spot"; only the latter when `canPlaceSpot` is false.
- `VideoTagMarks({required List<Duration> moments, required Duration duration})`

- [ ] **Step 1: Failing tests:** toolbar shows the people action; tapping it shows the hint; a tap on the photo opens the picker with a pending box; picking saves a tag with that box; tapping an existing box offers change person, resize, remove; on a video tag mode pauses and the saved tag carries the paused position; `canPlaceSpot` false on Linux override, connector video and unknown image size shows only "Tag without a spot"; a moment chip on an unplayable video does not seek.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement.** Corner handles drag in normalised space through `FaceBox.clamped`.
- [ ] **Step 4: Run** the file and `test/features/media/presentation/pages`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): tag people on photos and videos`.

### Task 9: Person picker and the add-to-dive offer

**Files:**
- Create: `person_picker_sheet.dart`, `add_to_dive_offer.dart`
- Test: `test/features/media/presentation/widgets/people_tags/person_picker_sheet_test.dart`, `.../add_to_dive_offer_test.dart`

**Interfaces:**
- Produces:
  - `sealed class PersonChoice` with `MeChoice` and `BuddyChoice(Buddy buddy, {bool isNew})`.
  - `Future<PersonChoice?> showPersonPickerSheet(BuildContext context, {required String? diveId})`: Me, "On this dive" (hidden when empty or no dive), "Everyone else", search over all of the diver's buddies, "New buddy" (name field, creates via `buddyRepositoryProvider` `createBuddy` with the current diver).
  - `Future<void> offerAddToDive(BuildContext context, WidgetRef ref, {required String? diveId, required PersonChoice choice})`: no-op for `MeChoice`, a null dive, or a buddy already on the dive; otherwise a SnackBar "Add {name} to this dive's buddies?" with an Add action calling `addBuddyToDiveWithRoles(diveId, buddyId, const [])` (empty = Buddy role).
- [ ] **Step 1: Failing tests:** section order and headings; dive buddies not repeated under everyone else; search filters; New buddy creates and returns `BuddyChoice(isNew: true)`; offer appears for a buddy not on the dive and not for Me / no dive / already on dive; Add writes one `dive_buddies` row with the buddy role; ignoring it writes none.
- [ ] **Step 2: Run.** Expected: FAIL. **Step 3: Implement**, then call both from the mixin's save path (Task 8). **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): person picker and offer to log a tagged buddy`.

### Task 10: Buddy page Photos section

**Files:**
- Create: `lib/features/buddies/presentation/widgets/buddy_photos_section.dart`
- Modify: `buddy_detail_page.dart` (mount after `BuddySharedDivesSection`)
- Test: `test/features/buddies/presentation/widgets/buddy_photos_section_test.dart`

**Interfaces:** `BuddyPhotosSection({required String buddyId})`, reading `mediaForBuddyProvider`; three-column thumbnail grid like `SpeciesPhotosSection`, newest first, hidden when empty, tap opens `MediaViewerPage` on that list.
- [ ] **Step 1: Failing tests:** hidden with no tags; shows thumbnails newest first; tap opens the viewer at that item.
- [ ] **Step 2 to 4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Commit** `feat(buddies): photos a buddy is tagged in`.

### Task 11: People in the filter sheet and active chips

**Files:**
- Modify: `media_library_filter_sheet.dart`, `media_library_active_filter_chips.dart`
- Test: `test/features/media/presentation/widgets/media_library_people_filter_test.dart`

**Interfaces:** a "People" section listing Me then the diver's buddies as `FilterChip`s writing `buddyIds` / `includeMe`; active chips show "Me" and buddy names with a remove action.
- [ ] **Step 1: Failing tests:** selecting Me and a buddy applies `MediaLibraryFilter(includeMe: true, buddyIds: {'b1'})`; reset clears both; active chips render and remove each.
- [ ] **Step 2 to 4:** Run (FAIL), implement, run (PASS).
- [ ] **Step 5: Commit** `feat(media): pick people in the library filter`.

### Task 12: Translations and final checks

**Files:** `lib/l10n/arb/app_*.arb` (11), generated `app_localizations*.dart`.
- [ ] **Step 1:** Tasks 7 to 11 add their keys to `app_en.arb` under a `media_people_` prefix (feature-grouped, anchored beside the `media_species_` keys) as they go. Here, add real translations of every new key to the 10 other ARBs, in each locale's own group position.
- [ ] **Step 2:** `flutter gen-l10n` (last), then verify `grep -A1 "get media_people_tagModeHint" lib/l10n/arb/app_localizations_de.dart` shows German, and `git diff --numstat lib/l10n/arb/` is even across locales.
- [ ] **Step 3:** `dart format .`, `flutter analyze` (no issues), `flutter test test/architecture test/shared test/core/database test/core/services/sync test/features/media test/features/buddies test/features/divers`. Expected: all pass.
- [ ] **Step 4: Commit** `i18n(media): translate people tagging strings`.
