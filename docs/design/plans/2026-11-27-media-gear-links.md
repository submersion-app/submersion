# Link photos to gear Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver link photos and videos to gear items, from the photo
viewer, a Library multi-selection and the gear page, stored in a new synced
`media_equipment` table.

**Architecture:** A junction table shaped like `media_tags` (surrogate uuid,
parent-gated child of `media` for sync, reconciled on its unique pair like
`equipment_shares`). One repository, `MediaGearRepository`, owns every read
and write. The photo side holds edits in the photo sitting as
`MediaGearEdits`; the gear side holds them in the gear item's sitting through
a `SittingList`; the Library bulk action writes at once with Undo, like bulk
Edit tags.

**Tech Stack:** Flutter, Drift, Riverpod, go_router, the record editing
sittings of issue #4527.

**Spec:** `docs/design/specs/2026-11-27-media-gear-links-design.md`

## Global Constraints

- Never write `media.equipment_id`; a linked photo never becomes a gear photo.
- Linkable media: `!item.isDocument && !item.isSignature && !item.isGearPhoto`.
- A link is shown only where the active diver sees both ends (media through
  the Library's `_diverScope`, gear through the equipment providers);
  hidden links are never deleted by an edit (edits are deltas, merged).
- Schema version 388 (bump to the next free number if main moved on); do
  not raise `minimumCompatibleSchemaVersion`.
- No table or rung code in `database.dart` beyond the tables list and the
  `migrationVersions` entry.
- Every new string in all 12 ARB files with a real translation, inserted
  next to a key of the same feature group; plurals with `one` and `other`
  (Arabic: zero, one, two, few, many, other).
- No em-dashes anywhere. `dart format .` before each commit.
- Local test runs: only the test files this plan writes or changes, by path.

## Review Focus

1. A gear item shared with another diver (#2046): its "In dive photos" card
   lists only the active diver's visible photos, and saving the card keeps
   the other diver's links. Pinned in Task 3 (`linkedMediaFor` scope test)
   and Task 8 (merge keeps hidden link test).
2. A link made on another device while a sitting is open survives Save.
   Pinned in Task 5 (`applyTo keeps a stored link the edits never name`).
3. Unlink then relink the same pair, then sync: no unique-index clash with
   the tombstone. Pinned in Task 2 (relink round trip test).
4. Deleting a gear item, then undoing a photo delete that referenced it:
   the restore skips links to gear that is gone. Pinned in Task 4.
5. A Library selection of only documents and gear photos: no Link to gear
   action. Pinned in Task 7.

---

### Task 1: The `media_equipment` table and its rung

**Files:**
- Create: `lib/core/database/tables/media_equipment_tables.dart`
- Create: `lib/core/database/migrations/helpers/media_equipment_migrations.dart`
- Modify: `lib/core/database/database.dart` (import/export beside `media_people_tables.dart`:27/69; tables list after `MediaPeople,` :140; `currentSchemaVersion` :341 to 388; `migrationVersions` append 388 with a comment)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (`part` line beside :119)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (after the v387 block)
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart` (after `_assertSpeciesRevampSchema()`, :179-181)
- Test: `test/core/database/migration_v388_media_equipment_test.dart` (copy the shape of `migration_v326_media_people_test.dart`)

**Interfaces:**
- Produces: Drift table class `MediaEquipment` (SQL `media_equipment`,
  accessor `db.mediaEquipment`, row class `MediaEquipmentData`) with `id`,
  `mediaId` (FK media, cascade), `equipmentId` (FK equipment, cascade),
  `createdAt` (int), `hlc` (nullable); `primaryKey {id}`;
  `uniqueKeys [{mediaId, equipmentId}]`.
- Produces: `extension MediaEquipmentMigrations on AppDatabase { Future<void> _assertMediaEquipmentSchema() }`:
  return early when `media` or `equipment` is missing (partial fixtures),
  create the table when missing, then
  `CREATE INDEX IF NOT EXISTS idx_media_equipment_equipment ON media_equipment (equipment_id)`.

- [ ] **Step 1: Write the failing migration test** with these cases:
  `388 is in migrationVersions and the floor is unchanged`;
  `upgrading a v387 database creates media_equipment with its unique pair and equipment index`
  (assert `PRAGMA index_list` names `idx_media_equipment_equipment` and a unique index over `media_id, equipment_id`);
  `the backstop recreates a dropped media_equipment`;
  `a fresh database matches an upgraded one` (same columns and indexes);
  `inserting the same pair twice fails on the unique key`.
- [ ] **Step 2: Run it, expect FAIL** (no table):
  `flutter test test/core/database/migration_v388_media_equipment_test.dart`
- [ ] **Step 3: Add the table, helper, rung (`if (from < 388) await _assertMediaEquipmentSchema(); if (from < 388) await reportProgress();`), backstop call and database.dart entries.** Run `dart run build_runner build --delete-conflicting-outputs` in the background (never `--build-filter`).
- [ ] **Step 4: Run the test, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): media_equipment table for photo gear links`.

### Task 2: Change log and sync wiring

**Files:**
- Modify: `lib/core/database/change_log/change_log_policy.dart` (`'media_equipment': ChangeLogClass.tracked` near :109; `'media_equipment': ChangeLogParent(rootTable: 'media', column: 'media_id')` near :382)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets`: `'mediaEquipment': (table: 'media_equipment', pk: 'id')`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart`: every `mediaTags` site in the explorer table (field, constructor default, toJson, fromJson, `_baseTables`, export through `_withPendingChildren`, `fetchRecord`, `upsertRecord`, `upsertRecords`, `recordIdsFor`, `_syncTableFor`, `_deleteRecordApply`), plus `parentGatedChildEntities` and `parentGatedTables`. Apply copies `_applyEquipmentShareRecord` (:5849) and its batch twin (:8168): `_reconcileJunctionIds('media_equipment', parentColumn: 'media_id', childColumn: 'equipment_id', ...)`, `_lowestIdPerPair`, insert with `DoNothing`.
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` entry `(type: 'mediaEquipment', records: data.mediaEquipment, hasUpdatedAt: false)` after both media and equipment; `entityHasUpdatedAt['mediaEquipment'] = false`; `parentRefs['mediaEquipment']`: `mediaId -> media` and `equipmentId -> equipment`, both `nullable: false`)
- Modify tests: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables`), `test/features/agent_access/data/records/record_catalog_guard_test.dart` (`_linkTables`)
- Test: `test/core/services/sync/media_equipment_sync_test.dart` (copy `media_document_tags_sync_test.dart`)

**Interfaces:**
- Produces: sync entity type `'mediaEquipment'`, `SyncData.mediaEquipment: List<Map<String, dynamic>>`.

- [ ] **Step 1: Write the failing sync test** with:
  `a pending link exports and applies on a peer`;
  `a deleted link applies as a delete on the peer`;
  `unlink then relink the same pair syncs as one live row` (two rows with
  different ids for one pair on apply: the lowest id survives, no unique
  error);
  `a link whose media or equipment is missing on the peer is held, not dropped`
  (match what `media_document_tags_sync_test.dart` asserts for tags).
- [ ] **Step 2: Run it plus the two guard tests, expect FAIL.**
  `flutter test test/core/services/sync/media_equipment_sync_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/features/agent_access/data/records/record_catalog_guard_test.dart`
- [ ] **Step 3: Wire every site listed above.**
- [ ] **Step 4: Run the same three files plus** `test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/child_hlc_test.dart test/core/services/sync/media_clock_guard_test.dart test/core/database/change_log/change_log_policy_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(sync): sync photo gear links`.

### Task 3: `MediaGearRepository`, providers and an item's dive ids

**Files:**
- Create: `lib/features/media/data/repositories/media_gear_repository.dart`
- Create: `lib/features/media/presentation/providers/media_gear_providers.dart`
- Modify: `lib/features/equipment/domain/repositories/equipment_repository.dart` and `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (beside `getDiveCountForEquipment`, :1248)
- Modify: `test/architecture/agent_write_coverage_exempt.dart` (each new public write method, reason: "photo gear links are not an agent write family yet (#5046)")
- Test: `test/features/media/data/repositories/media_gear_repository_test.dart`, `test/features/equipment/data/repositories/equipment_dive_ids_test.dart`

**Interfaces (Produces):**
```dart
class MediaGearRepository {
  MediaGearRepository({AppDatabase? db, SyncRepository? syncRepository});
  Stream<void> watchChanges();
  Future<List<String>> gearIdsFor(String mediaId);            // every link, unscoped
  Future<Map<String, Set<String>>> gearIdsByMedia(List<String> mediaIds);
  Future<Map<String, int>> gearCountsFor(List<String> mediaIds); // equipmentId -> linked media count
  Future<void> replaceGear(String mediaId, List<String> equipmentIds, {bool notify = true});
  Future<void> addGear(List<String> mediaIds, List<String> equipmentIds, {bool notify = true});
  Future<void> removeGear(List<String> mediaIds, List<String> equipmentIds, {bool notify = true});
  Future<List<MediaItem>> linkedMediaFor(String equipmentId, {required String? diverId}); // linkable, diver-scoped, newest first
  Future<List<String>> mediaIdsFor(String equipmentId);       // every link, unscoped
  Future<void> replaceMedia(String equipmentId, List<String> mediaIds, {bool notify = true});
  Future<List<MediaItem>> linkableMediaOnDives(List<String> diveIds); // grouped by caller, newest first
  Future<Set<String>> gearOnDive(String diveId);              // via gearUsageForDives
  Future<void> deleteForMedia(List<String> mediaIds);         // caller's txn, logs deletions
  Future<void> deleteForEquipment(String equipmentId);        // caller's txn, logs deletions
}
// EquipmentRepository
Future<List<String>> getDiveIdsForEquipment(String equipmentId, {String? diverId});
```
Writes follow `TagLinkRepository` (`_insert` with `ON CONFLICT DO NOTHING`,
`markRecordPending` on insert, `logDeletion` per deleted row, notify after
the transaction). `getDiveIdsForEquipment` is `SELECT d.id FROM dives d WHERE $_diveOnItemSql`, newest first.

Providers: `mediaGearRepositoryProvider`; `gearIdsForMediaProvider`
(family by media id); `linkedMediaForEquipmentProvider` (family by
equipment id, reads `validatedCurrentDiverIdProvider`); `gearOnDiveProvider`
(family by dive id); `equipmentDiveIdsProvider` (family, scoped like
`equipmentDiveCountProvider`). Each invalidates itself on
`watchChanges()` (and the dive tables where it reads them).

- [ ] **Step 1: Write the failing repository tests:**
  `replaceGear adds and removes links and stamps hlc on new rows`;
  `replaceGear twice with the same ids writes nothing`;
  `removing a link logs a deletion`;
  `addGear skips pairs already linked`;
  `linkedMediaFor hides another diver's dive photos and shows dive-less photos`;
  `linkedMediaFor leaves out documents and gear photos`;
  `gearOnDive includes a cylinder linked through dive_tanks`;
  and `getDiveIdsForEquipment matches getDiveCountForEquipment` (same
  fixture, `ids.length == count`, planned dives and other divers' dives
  left out).
- [ ] **Step 2: Run both files, expect FAIL.**
- [ ] **Step 3: Implement the repository, the equipment method and the providers.**
- [ ] **Step 4: Run both files plus `test/architecture/agent_write_coverage_test.dart`, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): repository for photo gear links`.

### Task 4: Deletes, undo and folds

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart` (`deleteMedia` :572, `deleteMultipleMedia` :607-636: call `deleteForMedia` beside `_people.deleteForMedia`)
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`_deleteEquipmentInner` beside :812: `deleteForEquipment(id)`)
- Modify: `lib/features/divers/data/repositories/diver_delete_steps.dart` (delete links of the diver's media and of the diver's gear, logged, like `media_people` :82-87 and `equipment_tags` :241-244)
- Modify: `lib/features/equipment/data/services/equipment_item_fold.dart` (`_idChildren`: `media_equipment` with `unique: ['media_id']`)
- Modify: `lib/features/media/data/repositories/media_row_restore.dart` (`MediaRowsSnapshot.gearLinks`, read in `readMediaRows`, restore like tags :196-215, skipping gear that no longer exists via `existingRowIds(db, db.equipment, ...)`)
- Modify: `lib/features/agent_access/data/writes/families/media_writes.dart` (`deleteReach` :228-246: `'media_equipment': 'media_id'`)
- Test: `test/features/media/data/repositories/media_gear_delete_test.dart`

- [ ] **Step 1: Write the failing tests:**
  `deleting a photo deletes its links and logs each deletion`;
  `deleting a gear item deletes its links and logs each deletion`;
  `undoing a photo delete restores its links`;
  `undoing a photo delete skips a link to gear deleted meanwhile`;
  `folding a duplicate gear item moves its links without duplicating a pair`;
  `deleting a diver removes links on their media and their gear`.
- [ ] **Step 2: Run, expect FAIL. Step 3: Implement. Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): delete and restore photo gear links with their parents`.

### Task 5: Gear links in the photo sitting

**Files:**
- Modify: `lib/features/media/domain/entities/photo_record.dart` (`final List<String> gearIds` default `const []`, in `copyWith` and `props`)
- Modify: `lib/features/media/domain/value_objects/photo_tag_edits.dart` (add `MediaGearEdits`, copying `MediaTagEdits` :257-315 with `Set<String> added`, `Set<String> removed`, `none`, `isEmpty`, `between(List<String> stored, List<String> chosen)`, `applyTo(List<String> stored)`, `prunedTo(List<String> stored)`)
- Modify: `lib/features/media/presentation/editing/photo_edit_fields.dart` (`const photoGearCardId = 'gear'`; `photoGearField = EditField<PhotoRecord, MediaGearEdits>(id: 'photoGear', ...)`; pass `gearIds` in `photoDiveShiftField.write`)
- Modify: `lib/features/media/presentation/editing/photo_viewer_editing.dart` (`_pruneMootEdits`: prune `photoGearField` against `stored.gearIds`)
- Modify: `lib/features/media/data/services/photo_record_reader.dart` (dep `MediaGearRepository gear`; `gearIds: await _gear.gearIdsFor(mediaId)`)
- Modify: `lib/features/media/data/services/photo_edit_save_service.dart` (dep `gear`; in `_write`, when the id sets differ, `replaceGear(id, after.gearIds, notify: false)`)
- Modify: `lib/features/media/presentation/providers/photo_editing_providers.dart` (deps, and `invalidateSelfWhen(gear.watchChanges())` in `photoRecordProvider`)
- Modify: `lib/features/change_log/presentation/change_log_labels.dart` (`photoGearCardId => l.media_info_gear`)
- Test: `test/features/media/domain/value_objects/media_gear_edits_test.dart`, `test/features/media/data/services/photo_edit_save_service_gear_test.dart`

- [ ] **Step 1: Write the failing tests:**
  `between gives added and removed ids`;
  `applyTo keeps a stored link the edits never name`;
  `prunedTo drops an add already stored and a remove already gone`;
  `saving a sitting with gear edits replaces the links`;
  `saving a sitting with no gear edits writes no link`.
- [ ] **Step 2: Run, expect FAIL. Step 3: Implement. Step 4: Run, expect PASS** (also re-run the existing tests of files changed here: `photo_record_reader` and `photo_edit_save_service` tests by path).
- [ ] **Step 5: Commit** `feat(media): hold photo gear links in the photo sitting`.

### Task 6: Viewer Gear card and gear picker

**Files:**
- Create: `lib/features/media/presentation/widgets/media_info_gear_section.dart`
- Create: `lib/features/media/presentation/widgets/media_gear_sheet.dart`
- Modify: `lib/features/media/presentation/widgets/media_info_panel.dart` (after `MediaInfoTagsSection`, :137, only for linkable media)
- Modify: all 12 `lib/l10n/arb/app_*.arb` (keys `media_info_gear`, `media_info_noGear`, `media_info_editGear`, `media_gearSheet_title`, `media_gearSheet_onThisDive`, `media_gearSheet_yourGear`, `media_gearSheet_search`), then `flutter gen-l10n`
- Test: `test/features/media/presentation/widgets/media_info_gear_section_test.dart`, `test/features/media/presentation/widgets/media_gear_sheet_test.dart`

**Interfaces:**
- `MediaInfoGearSection({required MediaItem item, bool readOnly = false, EditSession<PhotoRecord>? sitting})`, built like `MediaInfoTagsSection`: ids from `held.working.gearIds` or `gearIdsForMediaProvider`, resolved against `allEquipmentProvider` (ids not visible are not drawn), chips `ActionChip(avatar: Icon(equipmentItemIcon(item)), label: name)` in name order, tap closes routes above the router page (`closeRoutesAboveRouterPage`) then `push('/equipment/<id>')`. Edit gear button key `media_info_editGear`.
- `Future<void> showMediaGearSheet(BuildContext context, MediaItem item, {required EditSession<PhotoRecord> sitting})`: search field; "On this dive" from `gearOnDiveProvider(item.diveId)` (omitted when none); "Your gear" from `allEquipmentProvider` minus those, grouped by type with `sortedByLocalizedName`, `CheckboxListTile` rows with `equipmentItemIcon`; each toggle calls `sitting.set(photoGearField, MediaGearEdits.between(sitting.stored.gearIds, chosen))`, guarded by `isDisposed || isFrozen` like `MediaTagSheet._hold`.

- [ ] **Step 1: Write the failing widget tests:**
  `shows No gear linked and no Edit gear while locked`;
  `shows linked gear chips in name order`;
  `hides a chip for gear the diver cannot see`;
  `is absent for a document and for a gear photo` (panel test);
  `tapping a chip navigates to /equipment/<id>`;
  `the sheet lists the dive's gear under On this dive first`;
  `checking an item holds an add in the sitting, unchecking it a remove`;
  `search narrows both sections`;
  `ten linked items wrap without overflow at 360 px wide`.
- [ ] **Step 2: Run, expect FAIL. Step 3: Implement. Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): Gear card and gear picker in the photo viewer`.

### Task 7: Library bulk Link to gear

**Files:**
- Create: `lib/features/media/data/services/bulk_gear_link_service.dart` (copy `BulkTagService`: `ChangeLogScope.bulk`, one transaction, snapshot with `gearIdsByMedia`, `addGear`/`removeGear` with `notify: false`, `SyncEventBus.notifyLocalChange()`; `undo(prior)` with `replaceGear` per surviving media)
- Create: `lib/features/media/presentation/widgets/bulk_gear_sheet.dart` (`BulkMembershipEditor`, members from `allEquipmentProvider` with `equipmentItemIcon`, counts from `gearCountsFor`, `absentStartsChecked: false`; SnackBar with Undo, as `bulk_tag_sheet.dart`)
- Modify: `lib/features/media/presentation/widgets/media_selection_bar.dart` (action id `link_gear` after `edit_tags`, key `selection_menu_link_gear`, only when `canWrite` and at least one selected item is linkable; only linkable ids are passed)
- Modify: 12 ARB files (`media_library_linkToGear`, plus confirm/empty strings mirroring the tag sheet's)
- Test: `test/features/media/data/services/bulk_gear_link_service_test.dart`, `test/features/media/presentation/widgets/media_selection_bar_gear_test.dart`

- [ ] **Step 1: Write the failing tests:**
  `apply adds to every selected photo and removes from every selected photo`;
  `undo restores each photo's prior links`;
  `Link to gear sits after Edit tags and opens the bulk gear sheet`;
  `Link to gear is absent when the selection is only documents and gear photos`;
  `documents in a mixed selection are not linked`.
- [ ] **Step 2: Run, expect FAIL. Step 3: Implement. Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(media): Link to gear for a Library selection`.

### Task 8: Gear page "In dive photos" card and photo picker

**Files:**
- Modify: `lib/features/equipment/presentation/editing/gear_item_card_ids.dart` (`divePhotos` with its title; never renamed later)
- Modify: `lib/features/equipment/presentation/editing/gear_item_edit_cards.dart` (`EditCard` for `divePhotos`, `isEmpty: (_) => false`, editor `EquipmentDivePhotosSection(equipment: session.working, editing: session)`)
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (`_framed(GearItemCardId.divePhotos, EquipmentDivePhotosSection(equipment: equipment, shown: _session))` right after the Photos card, :445-448)
- Modify: `lib/features/equipment/presentation/editing/gear_item_sitting_host.dart` (`gearItemDivePhotosList.load(session)` in `loadGearItemSitting`)
- Create: `lib/features/equipment/presentation/editing/gear_item_dive_photos_list.dart`: `gearItemDivePhotosList = SittingList<EquipmentItem, MediaItem>(key: 'equipment.divePhotos', cardId: GearItemCardId.divePhotos.name, read: linked media scoped to the active diver, write: mergedIds(stored: mediaIdsFor, loaded, current) then replaceMedia(notify: false), same: by id)`. The read needs the active diver id: capture it when the list is loaded (pass a reader closure from `loadGearItemSitting`, which has the container).
- Create: `lib/features/equipment/presentation/widgets/equipment_dive_photos_section.dart`: header (icon, title with count, `RecordCardPencil`), up to two rows of `MediaThumbnailTile` (4 columns), Show all when more, empty invitation; while `editing`, Link photos and selection plus Unlink, both through `gearItemDivePhotosList.set`.
- Create: `lib/features/equipment/presentation/widgets/gear_photo_link_sheet.dart`: `Future<List<MediaItem>?> showGearPhotoLinkSheet(BuildContext context, {required EquipmentItem item, required List<MediaItem> linked})`; `SegmentedButton` Dives with this gear (from `equipmentDiveIdsProvider` then `linkableMediaOnDives`, grouped by dive, newest first) / All photos (`MediaLibraryRepository.getPage(grouping: MediaLibraryGrouping.dive)`, paged at 60, filtered to linkable); opens on All photos when the item has no dives; checked = linked; confirm button names the count of changes.
- Create: `lib/features/equipment/presentation/pages/equipment_dive_photos_page.dart`: read-only full grid, pushed with `Navigator.push`.
- Modify: 12 ARB files (card title, count, empty text, Link photos, Show all, sheet title with the item name, the two segments, confirm with a plural count, Unlink)
- Test: `test/features/equipment/presentation/widgets/equipment_dive_photos_section_test.dart`, `test/features/equipment/presentation/widgets/gear_photo_link_sheet_test.dart`, `test/features/equipment/presentation/editing/gear_item_dive_photos_list_test.dart`

- [ ] **Step 1: Write the failing tests:**
  `card shows the empty invitation with no links`;
  `card shows at most eight tiles and Show all past that`;
  `Link photos and Unlink are offered only while the card is open`;
  `linking in the sitting shows the photo before Save and writes it on Save`;
  `cancel drops held links`;
  `saving keeps another diver's link the card never showed` (merge);
  `the sheet opens on Dives with this gear grouped by dive`;
  `the sheet opens on All photos for an item with no dives`;
  `unchecking a linked photo removes it`;
  `the Show all page lists every linked photo`.
- [ ] **Step 2: Run, expect FAIL. Step 3: Implement. Step 4: Run, expect PASS** (also re-run the existing equipment detail page tests by path, since the page gained a card and providers: `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`, `equipment_detail_page_unlock_more_test.dart`).
- [ ] **Step 5: Commit** `feat(equipment): In dive photos card with a photo picker`.

### Task 9: Checks and after screenshots

- [ ] **Step 1:** `dart format .`, `flutter analyze` (whole repo), then every test file this plan touched, by path.
- [ ] **Step 2:** Re-run `test/_pr_shots/gear_links_shots_test.dart` with `--dart-define=STAGE=after`, after filling `gear_links_shots_extras.dart` with the overrides for a photo linked to two items, and adding shots of the gear picker, the bulk sheet and the photo picker. Check range: a photo with ten items, an item with 40 links.
- [ ] **Step 3:** Copy the after PNGs to the scratchpad shots folder, then delete `test/_pr_shots/`.
