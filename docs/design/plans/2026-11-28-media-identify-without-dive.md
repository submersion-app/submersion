# Identify species in media not on a dive: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task (the maintainer chose inline execution).
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver identify species in photos and videos that are on no
dive: from files or the camera without keeping anything, and by keeping media
with no place, on a site, or on a dive.

**Architecture:** Data rules first: site as location, sweep and cascades
sparing retained rows, tags relinking on a move, and a "no place" import
target. Then the sync hold-back, using a device-local `held_media` table and
an export filter modelled on the shared-library site filter (#2567). Then the
scratch Identify viewer: a nested `ProviderScope` overriding the
identification, tag and species stores with in-memory ones. A Keep service
copies results into the real stores. Last, the camera screen with a pure-Dart
live naming controller.

**Tech Stack:** Flutter, Riverpod 3.4, Drift, HLC changeset sync, the
`camera` plugin (new), `gal`, the existing `VisionEngine` and `nameCrops`.

**Spec:** `docs/design/specs/2026-11-28-media-identify-without-dive-design.md`

## Global Constraints

- Every new user-facing string goes in `app_en.arb` and is translated into all
  11 other ARBs (ar, de, es, fr, he, hu, it, ja, nl, pt, zh), with
  `flutter gen-l10n` run **last**. ARBs are grouped by feature: insert next to
  a neighbouring key of the same group.
- No em-dashes anywhere. No emojis. Comments and docs name no AI tool.
- Paths are built with `p.join`; temporary space comes from
  `Directory.systemTemp` or the OS cache dir, never a literal `/tmp`.
- A test that replaces process-wide state restores it in `addTearDown`.
- Run only the test files you wrote or changed, by path. Never a folder or the
  suite. Run `dart format .` and `flutter analyze` before each commit.
- Tables go in `lib/core/database/tables/`, rungs in
  `lib/core/database/migrations/`. Nothing is added to `database.dart` beyond
  registration lines.
- Media is linked, never stored by the app: a kept camera capture is saved to
  the photo library first and linked as a gallery asset.
- `heldMediaSchemaVersion` = the schema version this PR ships (390 unless main
  has moved; re-number on merge if so).
- Live naming samples a frame every 250 ms and pauses when
  `VisionMemory.availableBytes` is below `liveNamingMemoryMarginBytes =
  512 * 1024 * 1024` or `VisionMemory.lowMemory == true`.

## Review Focus

1. **A scratch action reaching the real database.** For example: hand
   tagging, accepting a suggestion, rejecting, the crop sheet, or the tag
   chips' reconcile. Expected: nothing is written. Pinned by Task 10's
   "no database writes" test, which runs every action against a
   database-spy.
2. **A held media row reaching another device through a path not covered by
   the filter.** For example: base compaction, nearby full or delta, the
   rejoin snapshot, or a reused nearby full copy. Expected: no held row or
   held child in any payload. Pinned by Task 8's per-path tests.
3. **Keep run twice, or Keep on a file deleted from disk.** Expected: one row
   per Keep, and the failure names the file while the rest go ahead. Pinned
   by Task 12.
4. **Moving media whose tag already points at the new dive's sighting**
   (a no-op), or a move onto the dive the media is already on. Expected: no
   duplicate sighting. Pinned by Task 4.
5. **Camera permission denied, or memory low from the start.** Expected: the
   screen still opens and says why, and the file picker still works. Pinned
   by Tasks 14 and 15.

---

## Phase A: data rules

### Task 1: The media row's own site as the last location fallback

**Files:**
- Modify: `lib/features/media/domain/services/media_location.dart`
- Modify callers: `lib/features/media/presentation/pages/media_viewer_actions.dart:103`, `lib/features/species_id/presentation/providers/species_review_providers.dart:102`, `lib/features/species_id/data/services/dive_species_run.dart:216`, `lib/features/species_id/presentation/providers/recorded_nearby_providers.dart:22`
- Test: `test/features/media/domain/services/media_location_test.dart`

**Interfaces:**
- Produces: `GeoPoint? mediaLocation(MediaItem item, {GeoPoint? siteLocation, GeoPoint? entryLocation, GeoPoint? ownSiteLocation})`. Order: own lat/lon, `siteLocation`, `entryLocation`, `ownSiteLocation`.
- Callers resolve `ownSiteLocation` from `item.siteId` with `siteProvider(id)` (UI) or `SiteRepository.getSiteById` (services), reading `DiveSite.location`.

- [ ] **Step 1: Failing tests:** `own site is used when no GPS and no dive` (item with siteId, no lat/lon; `ownSiteLocation: GeoPoint(1, 2)` gives `GeoPoint(1, 2)`); `dive site wins over own site`; `own GPS wins over own site`.
- [ ] **Step 2:** Run `flutter test test/features/media/domain/services/media_location_test.dart`. Expect a FAIL (unknown named parameter).
- [ ] **Step 3:** Add the parameter. Update the four callers to pass the media row's own site location, and add a test to each caller's existing test file for a site-only item with no GPS.
- [ ] **Step 4:** Run the touched test files and expect them to pass.
- [ ] **Step 5:** Commit `feat(media): use the media row's own site as its identification location`.

### Task 2: The launch sweep spares retained rows

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart:2772` (`getSweepableOrphanIds`)
- Test: `test/features/media_store/media_orphan_backlog_sweep_test.dart`

- [ ] **Step 1: Failing test:** `a retained unlinked row older than 24 h is not swept`. Insert with `MediaItem(retainInLibrary: true)` and no links, `createdAt` 48 h ago; `run()` returns 0 and the row exists. Also confirm that a non-retained twin is still swept.
- [ ] **Step 2:** Run it and expect a FAIL.
- [ ] **Step 3:** Add `& _db.media.retainInLibrary.equals(false)` to the where clause. Update the class doc of `MediaOrphanBacklogSweep`: the "every row carries a link" rule now excepts kept rows.
- [ ] **Step 4:** Run it and expect a PASS.
- [ ] **Step 5:** Commit `feat(media): keep media the diver kept with no place through the launch sweep`.

### Task 3: Delete cascades keep retained rows, with no place

**Files:**
- Modify: `lib/features/media/data/repositories/media_parent_cascade.dart:113` (`mediaRowLivesOn`)
- Modify: `media_repository.dart` partitions at :2177 (dive), :2270 (site) and :2325 (equipment). A retained row goes to `unlinkIds`, never to `doomed`.
- Modify: correct the stale doc at `media_repository.dart:2296-2301`.
- Tests: `test/features/media/data/media_parent_cascade_test.dart`, `media_repository_cascade_test.dart`, `media_repository_site_cascade_test.dart`, `equipment_media_attachment_test.dart`

**Interfaces:**
- Produces: `mediaRowLivesOn(row, parents)` returns true when `row.retainInLibrary`.

- [ ] **Step 1: Failing tests, one per path:**
  - `retained row survives its dive's deletion with no place`
  - `... its site's deletion`
  - `... its gear's deletion`
  - `... a diver deletion (planMediaCascade)`

  Each asserts that the row exists afterwards with `diveId`, `siteId` and `equipmentId` all null and `retainInLibrary` true.
- [ ] **Step 2:** Run the four files and expect FAILs.
- [ ] **Step 3:** Implement. In each partition, check `row.retainInLibrary` next to the existing "any surviving link" check.
- [ ] **Step 4:** Run the files and expect them to pass.
- [ ] **Step 5:** Commit `feat(media): retained media outlives its dive, site or gear`.

### Task 4: Tags relink when media moves onto a dive

**Files:**
- Modify: `lib/features/media/data/repositories/media_species_repository.dart`. Add `Future<void> setTagSighting({required String mediaId, required String speciesId, required String? sightingId})`, writing `MediaSpeciesCompanion(sightingId: Value(...))` plus `markRecordPending('mediaSpecies')` in the `confirmTag` write pattern.
- Modify: `lib/features/media/data/services/species_tagging_service.dart`. Add `Future<void> moveMediaToDive(List<String> mediaIds, String diveId)`.
- Modify callers: `lib/features/media/presentation/helpers/media_move_to_dive.dart:75` and `lib/features/agent_access/data/writes/families/media_writes.dart:261` call `speciesTaggingService.moveMediaToDive` instead of `reassignMediaToDive`. Update `test/architecture/agent_write_coverage_covered.dart:710` if it names the call.
- Tests: `test/features/media/data/services/species_tagging_service_move_test.dart` (new), plus the existing move helper and agent write tests.

**Interfaces:**
- `moveMediaToDive` runs `ChangeLogScope.bulk(label: ChangeLogLabels.moveMedia)` around `MediaRepository.reassignMediaToDive` (which joins the running scope), then relinks each tag:
  - A confirmed or hand tag gets `_sightingIdFor(diveId, speciesId)`.
  - An unconfirmed tag gets `_existingSightingId(diveId, speciesId)`, which may be null and clears the link.
  - Sightings on the old dive are never deleted.

- [ ] **Step 1: Failing tests:**
  - `hand tag on unplaced media gets the dive's sighting, created`
  - `confirmed tag reuses an existing sighting on the new dive`
  - `unconfirmed app tag pointing at the old dive's sighting is cleared when the new dive has none`
  - `unconfirmed app tag links to a sighting the diver logged on the new dive`
  - `old dive's sighting is kept`
  - `moving onto the same dive creates no duplicate sighting`
  - `one History entry labelled as a move`
- [ ] **Step 2:** Run the new file and expect FAILs.
- [ ] **Step 3:** Implement. Make `_sightingIdFor` and `_existingSightingId` usable from the new method; they are already in the same class.
- [ ] **Step 4:** Run the new file and the touched caller tests, and expect them to pass.
- [ ] **Step 5:** Commit `feat(media): moving media onto a dive gives its tags that dive's sightings`.

### Task 5: A "no place" import target

**Files:**
- Modify: `lib/features/media/domain/value_objects/media_attach_target.dart`. Add `final class UnplacedAttachTarget extends MediaAttachTarget` (const, `props => []`), and make `ownsEveryFile` true for it.
- Modify: every exhaustive switch the analyzer flags.
- Modify: `lib/features/media/data/services/media_import_service.dart`. Add `Future<...> importPhotosUnplaced({required List<AssetInfo> selectedAssets})` through `_importOwned` with `link: (m) => m.copyWith(retainInLibrary: true)`, mirroring `importPhotosForSite` (:415).
- Modify: `media_import_view.dart` `importResolved` (:70) to route `UnplacedAttachTarget` groups.
- Tests: `test/features/media/data/services/media_import_service_test.dart` and `test/features/media/presentation/media_import_view_test.dart`

- [ ] **Step 1: Failing tests:**
  - `importPhotosUnplaced inserts rows with no dive, no site and retainInLibrary true`
  - `importResolved sends UnplacedAttachTarget assets to importPhotosUnplaced and counts them as linked`
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement. Where an exhaustive switch needs a decision for the new target, choose the behaviour of a site target (owned, no date matching).
- [ ] **Step 4:** Run and expect them to pass.
- [ ] **Step 5:** Commit `feat(media): import can keep media with no place`.

### Task 6: Import review and Files tab actions

**Files:**
- Modify: `lib/features/media/presentation/pages/media_import_review_page.dart`:
  - Popup menu (:207-226): add the value `'unplaced'` with label `media_import_review_keepUnplaced`, which sets `_overrides[id] = const UnplacedAttachTarget()`.
  - Above the unmatched rows: a bar with `media_import_review_allOnSite` (site picker, then a `SiteAttachTarget` for every row whose `_targetFor` is null) and `media_import_review_allUnplaced`. Show the bar only when at least one row has no target.
  - `_subtitle` (:120) shows `media_import_review_unplacedSubtitle` for the new target.
- Modify: `lib/features/media/presentation/providers/files_tab_providers.dart`. Change `commit` to `commit({MediaAttachTarget? target, MediaAttachTarget? unmatchedTarget})`. With a dive or null target, unmatched files are persisted with `unmatchedTarget` when it is a site or unplaced target, through `_persistOne(..., siteId:)` or a retained unplaced `_itemFor`. Relax the "exactly one owner" assert in `_itemFor` (:400) for the unplaced case.
- Modify: `lib/features/media/presentation/widgets/file_review_pane.dart:117-158`. Give the Unmatched tile two actions, `media_photoPicker_files_allOnSite` and `media_photoPicker_files_allUnplaced`, beside the existing add-all-to-dive. Thread the choice to `files_tab.dart:311`.
- Tests: `test/features/media/presentation/media_import_review_test.dart`, `test/features/media/presentation/widgets/file_review_pane_test.dart`, `test/features/media/presentation/providers/files_tab_providers_test.dart`

- [ ] **Step 1: Failing tests:**
  - `Keep without a place targets the row as unplaced and enables the button`
  - `Put all on a site assigns only rows with no target`
  - `Keep all without a place leaves matched rows alone`
  - `commit with unmatchedTarget unplaced persists unmatched files retained with no links`
  - `commit with unmatchedTarget site persists them on the site`
  - `the bar is hidden when every row has a target`
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement. Add the English strings to `app_en.arb` now; translations come in Task 17.
- [ ] **Step 4:** Run and expect them to pass.
- [ ] **Step 5:** Commit `feat(media): keep or place every unmatched file at once in the import review`.

## Phase B: holding kept media back from older devices

### Task 7: Schema 390 with a device-local `held_media` table

**Files:**
- Create: `lib/core/database/tables/held_media_tables.dart`. `class HeldMedia extends Table` with `mediaId` (text, PK) and `heldAt` (int). It has **no `hlc` column**, after `NearbyPeers` in `nearby_tables.dart:18`.
- Modify: `lib/core/database/database.dart`:
  - Register the table in `@DriftDatabase(tables:)`, with an import/export line.
  - Set `currentSchemaVersion = 390`.
  - Append 390 to `migrationVersions`.
  - Add `static const int heldMediaSchemaVersion = 390;`.
  - Leave `minimumCompatibleSchemaVersion` at 386.
- Create: `lib/core/database/migrations/helpers/held_media_migrations.dart` with `extension HeldMediaMigrations on AppDatabase { Future<void> _assertHeldMediaSchema() }`, which creates the table if missing. Register its `part` in `app_database_migrations.dart`.
- Modify: `migrations/ladder/rungs_v340_onward.dart`. Add a 390 rung after 387 (:357-358). Add a backstop in `before_open_table_backstops.dart` as nearby does (:134).
- Modify: `lib/core/database/change_log/change_log_policy.dart:181`, adding `'held_media': ChangeLogClass.excluded`.
- Modify: `tool/demo_data/src/checks/coverage_check.dart:15`, adding `held_media`.
- Create: `lib/features/media/data/repositories/held_media_repository.dart`, `class HeldMediaRepository({AppDatabase? database})`, with:
  - `Future<Set<String>> heldIds()`
  - `Future<void> hold(Iterable<String> mediaIds, {required DateTime at})` (insert or ignore)
  - `Future<void> release(Iterable<String> mediaIds)`
  - `Future<bool> isHeld(String mediaId)`
- Run codegen (`dart run build_runner build --delete-conflicting-outputs`, never `--build-filter`) in the background.
- Tests: `test/core/database/migration_v390_held_media_test.dart` (new, after `migration_v387_ccr_setpoint_switch_test.dart`), `test/features/media/data/held_media_repository_test.dart` (new). Then run each guard file named in the sync recon: `database_table_libraries_test.dart`, `change_log_every_table_test.dart`, `change_log_policy_test.dart`, `sync_hlc_target_registration_test.dart`, `fresh_schema_declared_columns_test.dart`, `test/tool/demo_data/coverage_check_test.dart`, `test/web/database/web_database_install_test.dart`.

- [ ] **Step 1: Failing tests:**
  - `v387 database upgrades to 390 with an empty held_media table`
  - `hold is idempotent`
  - `release removes ids`
  - `held_media never appears in SyncData exports`
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement and run codegen.
- [ ] **Step 4:** Run the new tests and every guard file, and expect them to pass.
- [ ] **Step 5:** Commit `feat(sync): a device-local held_media table, schema 390`.

### Task 8: The export filter

**Files:**
- Create: `lib/core/services/sync/media_hold_policy.dart`:
  - `class MediaHoldPolicy` with `bool holding` (default **true**, the safe value when peers are unknown).
  - `static bool olderPeersPresent(Iterable<SyncManifest> peers, Set<String> fencedPeerIds)`, true when any non-fenced peer has `(writerSchemaVersion ?? schemaVersion) < AppDatabase.heldMediaSchemaVersion`.
- Modify: `lib/core/services/sync/sync_data_serializer.dart`:
  - Give the serializer a `MediaHoldPolicy holdPolicy` and a `HeldMediaRepository`.
  - Add `Future<Set<String>> heldMediaIds()`, memoised per export like `librarySiteIds()` (:10738-10760, reset in a `finally`). When `holdPolicy.holding`, it returns the ids of media with `retainInLibrary` and no dive, site or equipment, and records them with `HeldMediaRepository.hold`. Otherwise it returns `{}`.
  - Add `static const Set<String> heldMediaChildEntities = {'mediaEnrichment','mediaTags','mediaSpecies','mediaPeople','mediaIdentificationRuns','mediaIdentifications','mediaIdentificationCrops'}`, all keyed by `mediaId`.
  - Filter `_exportMedia` (:10918) by `id`. Filter each child export, and `_withPendingChildren` (:2567), by `mediaId`.
  - In the base `emit` (:1913), skip a `media` row in the held set and a child row whose `mediaId` is in it.
  - Wrap `_buildSyncData` (:2591) in the new memo as it wraps the library one.
- Modify: `lib/core/services/sync/sync_service.dart`. After the pull (:776) and retirement sweep (:842), set `holdPolicy.holding = MediaHoldPolicy.olderPeersPresent(pullResult.peerManifests, fencedPeerIds)` before `publish` (:905). The library-replace publish (:5202) and rejoin (:5308) keep the current value (default true).
- Modify: `lib/core/services/nearby/nearby_sync_protocol.dart` `_prepare` (:482). Set `holding` from `_channel.peer.schemaVersion < heldMediaSchemaVersion` before `exportFull`/`exportDelta`. Skip `_files.reusableFull(_peerId)` (:497) when the cached copy was made under a different holding value: key the reuse on it.
- Tests: `test/core/services/sync/held_media_export_test.dart` (new, modelled on `shared_library_row_guard_test.dart`), `test/core/services/sync/media_hold_policy_test.dart` (new), and the nearby protocol test file for `_prepare`.

- [ ] **Step 1: Failing tests:**
  - `held row and every child kind are absent from an incremental export while holding`
  - `... absent from the base export`
  - `... present when not holding`
  - `a retained row with a site is never held`
  - `olderPeersPresent ignores fenced peers and peers at 390`
  - `nearby export to a 387 peer holds; to a 390 peer it does not`
  - `a reusable nearby full copy made while holding is not reused for a 390 peer`
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run and expect them to pass.
- [ ] **Step 5:** Commit `feat(sync): hold media kept with no place back from older devices`.

### Task 9: Release, and remote deletes while held

**Files:**
- Create: `lib/core/services/sync/held_media_releaser.dart`, `class HeldMediaReleaser({required HeldMediaRepository held, required SyncRepository sync, required AppDatabase db})`, with `Future<int> release({required bool holding})`. For each held id:
  - If the row is gone, release the id.
  - If `!holding`, or the row now has a dive, site or equipment: call `markRecordPending(entityType: 'media', recordId: id, localUpdatedAt: now, alsoStamp: <every media fact group>)`, then `markRecordPending` for each child row of each `heldMediaChildEntities` kind (by its own id, or `mediaId` for runs), then release the id.
  - Returns the count released.
- Modify: `sync_service.dart`. Call `release(holding: holdPolicy.holding)` after setting `holding` and **before** `publish`, so the new HLCs are above the watermark.
- Modify: `sync_service.dart` `_applyRemoteDeletions` (:2955). Next to the library-site skip (:2994-3007), skip a `media` deletion whose id `isHeld`, and a child deletion whose local row's `mediaId` is held. Log nothing to the tombstone log for skipped ones, as the library skip does.
- Tests: `test/core/services/sync/held_media_release_test.dart` (new), and an addition to `held_media_export_test.dart`.

- [ ] **Step 1: Failing tests:**
  - `after the last 387 peer updates, the next incremental export carries the held row and its children`
  - `placing a held row on a site releases it with its children on the next export`
  - `a deleted held row is forgotten`
  - `a remote media tombstone for a held row is not applied`
  - `a remote mediaSpecies tombstone for a held row's tag is not applied`
  - `a remote tombstone for a released row is applied`
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run and expect them to pass.
- [ ] **Step 5:** Commit `feat(sync): release held media once every device can keep it`.

## Phase C: the scratch Identify viewer

### Task 10: Scratch stores and scope

**Files:**
- Create: `lib/features/species_id/data/scratch/scratch_identification_repository.dart`. `class ScratchIdentificationRepository extends MediaIdentificationRepository` is constructed with `currentDatabase: () => throw StateError('scratch')`, so any method it does not override throws. It overrides, in memory, every method the service and overlay providers call:
  - `storeRun`, `storeRunAfterReading`, `runFor`, `forMedia`, `forMediaWithRun`, `identificationsAtLevel`, `taggedSpecies`, `updateDecisions`, `updateNames`, `claim`, `fillNamingBars`, `deleteLeftovers`, `deleteForMedia`
  - `watchChanges` and `watchTagChanges`, as broadcast controllers
- Create: `scratch_embedding_repository.dart` (`IdentificationEmbeddingRepository` with `put`, `get` and `delete` over a map), `scratch_crop_repository.dart` (`IdentificationCropRepository` in memory), and the crop store, built as `IdentificationCropStore(supportPath: () => tempDir, table: scratchCrops)`.
- Create: `lib/features/media/data/scratch/scratch_media_species_repository.dart`, extending `MediaSpeciesRepository` with in-memory tags (`addTag`, `findTag`, `confirmTag`, `removeTag`, `getTagsForMedia`, `getTagChipsForMedia`, `watchTagChanges`, `tagsForSighting` returning `[]`).
- Create: `lib/features/marine_life/data/scratch/scratch_species_repository.dart`, extending `SpeciesRepository`. Reads pass through to the real repository. `createSpecies` holds the new species in memory under a fresh id and returns it. Reads merge held species in. `heldSpecies()` returns them. Sighting writes throw.
- Create: `lib/features/media/data/scratch/scratch_species_tagging_service.dart`, extending `SpeciesTaggingService` over the scratch repos. `tagPhoto`, `confirmTag`, `rejectTag` and `applyAppTag` act on scratch tags only, with no media lookup and no sightings.
- Create: `lib/features/species_id/presentation/scratch/scratch_scope.dart`:
  - `class ScratchSession` owns the stores, the temp dir and a `Map<String, MediaItem> items`, plus `Future<void> dispose()`, which deletes the temp dir.
  - `List<Override> scratchOverrides(ScratchSession s, MediaIdentificationService service)` overrides `mediaIdentificationRepositoryProvider`, `identificationEmbeddingRepositoryProvider`, `identificationCropRepositoryProvider`, `identificationCropStoreProvider`, `mediaIdentificationServiceProvider`, `mediaSpeciesRepositoryProvider`, `speciesRepositoryProvider` and `speciesTaggingServiceProvider`.
  - `MediaIdentificationService buildScratchService(Ref root, ScratchSession s)` uses the root's `visionEngineProvider`, pack loader, level providers and memory readout. Its `onItemSettled` is a no-op. `resolveImage` reads `item.localPath` bytes or the platform asset.
- Modify: add `dependencies:` to every provider that reads an overridden one, so the scoped overrides reach it (Riverpod 3 scoping):
  - `photoDetectionsProvider`, `videoTracksProvider`, `mediaAnalysisStatusProvider`, `mediaTagChipsProvider`, `allSpeciesProvider`, `speciesProvider`
  - `mediaSuggestionsProvider`, `identificationCropProvider`, `presentCropIdsProvider`, `suggestionAcceptorProvider`
  - `mediaIdentificationBusyProvider`, `mediaIdentificationProgressProvider`
  - any provider in between that the analyzer or a runtime assert names

  Step 1's first test proves whether this is needed. If Riverpod 3 reaches them without `dependencies`, drop this step.
- Tests: `test/features/species_id/presentation/scratch/scratch_scope_test.dart` (new), and `scratch_*_repository_test.dart` for each store.

- [ ] **Step 1: Failing tests:**
  - `photoDetectionsProvider in a scratch scope reads the scratch repository`
  - `mediaTagChipsProvider in a scratch scope shows a scratch tag and a held new species by name`
  - `no database writes`: build the scope over a test database. Run a request, accept a suggestion for an uncatalogued species, hand tag, confirm, reject and open a crop. Then assert that the change log, `media`, `media_species`, `species`, `sightings` and every identification table are unchanged.
  - `dispose deletes the temp folder`
  - each scratch store's round trip
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run and expect them to pass. Then run the existing tests of every provider given `dependencies:`.
- [ ] **Step 5:** Commit `feat(species-id): in-memory identification stores for media that is not kept`.

### Task 11: The viewer's scratch mode

**Files:**
- Modify: `lib/features/media/presentation/pages/media_viewer_page.dart`:
  - Add `final ScratchSession? scratch` to the constructor.
  - When it is set, `_hydrate` (:273) returns the passed item.
  - `_photoLocation` uses only the item's own GPS. Camera captures carry none.
  - The page wraps itself in `ProviderScope(overrides: scratchOverrides(...))`.
  - `dispose` calls `scratch.dispose()`.
- Modify: `media_viewer_chrome.dart`. In scratch mode, pass null for:
  - `onReupload`, `onWriteMetadata`, `onTagPeople`, `onAdjustColor`, `onUnlock`, `editBar`, `onGoToDive`, `onTogglePerdix`, `onOpenInLightroom`
  - the mini profile and the site name in `_bottomPanel`

  Keep `onShowInfo`, `onShare`, `onTagSpecies` and `onMarineLifeLabels`. `onTagSpecies` must open the species sheet without a database photo sitting. Give `showMediaSpeciesSheet` a scratch path that needs no `photoSitting`; check `media_species_sheet.dart:101` and `photo_sitting_shown.dart:44` for what the sitting supplies, and supply it from the scratch scope.
- Create: `lib/features/media/presentation/widgets/scratch_banner.dart`, a `ScratchBanner({required VoidCallback onKeep})` with the text `media_identify_notKeptBanner` and the button `media_identify_keep`.
- Modify: wrap the route with a `PopScope`. Leaving with unkept items the diver decided on (a scratch tag, or a confirmed or rejected identification) asks `media_identify_leaveTitle` / `media_identify_leaveBody`.
- Tests: `test/features/media/presentation/pages/media_viewer_scratch_test.dart` (new)

- [ ] **Step 1: Failing tests:**
  - `scratch mode shows the banner and no dive, site or edit actions`
  - `a rowless local video plays`
  - `the species sheet opens without a sitting`
  - `leaving after a decision asks; leaving without one does not`
  - `a kept item loses the banner` (driven by Task 12's callback; stub it here)
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run and expect them to pass. Also run `test/features/media/presentation/pages/` files that cover `MediaViewerPage`, by path.
- [ ] **Step 5:** Commit `feat(media): a scratch mode of the media viewer`.

### Task 12: Keep

**Files:**
- Create: `lib/features/media/data/services/scratch_keeper.dart`:
  - `class ScratchKeeper({required MediaImportService importer, required MediaIdentificationRepository identifications, required IdentificationEmbeddingRepository embeddings, required IdentificationCropStore crops, required SpeciesRepository species, required SpeciesTaggingService tagging, required AutoApplier autoApplier, required Future<String?> Function(MediaItem capture) saveCaptureToLibrary})`
  - `Future<KeepResult> keep(ScratchSession s, List<String> scratchIds, MediaAttachTarget target)`.
  - `class KeepResult { Map<String, String> keptIds; Map<String, String> failures; }`
- Per item, in order:
  1. A camera capture goes to the photo library through `saveCaptureToLibrary`, which wraps `gal`. It returns the asset id. If that fails, the item fails.
  2. Check that the file exists. If not, the item fails with `media_identify_keepGone`.
  3. Insert through the importer for the target (`DiveAttachTarget`, `SiteAttachTarget` or `UnplacedAttachTarget`).
  4. Create the held new species the item's tags use (`createSpecies`), and map old ids to new ones.
  5. Copy the run, identifications (with decisions), embeddings and crops to the new media id. Re-key `mediaId`; keep identification ids.
  6. Write tags: confirmed and hand tags through `tagging.tagPhoto`; unconfirmed app tags through `applyAppTag` with the diver's `SightingTiming`.
  7. Call `autoApplier.applyInScope(newId, isVideo:, generation:)`.
  8. Remove the item from the session.
- Create: `lib/features/media/presentation/widgets/keep_sheet.dart`, `showKeepSheet(context, {required int unkeptCount})`, which returns `({MediaAttachTarget target, bool all})?`.
  - Choices: `media_identify_keepOnDive` (dive picker, with the capture-time match first, using the import's matcher), `media_identify_keepOnSite` (`showSitePicker`) and `media_identify_keepUnplaced`.
  - When `unkeptCount > 1`, add `media_identify_keepThis` / `media_identify_keepAll(count)`.
- Tests: `test/features/media/data/services/scratch_keeper_test.dart` (new), `test/features/media/presentation/widgets/keep_sheet_test.dart` (new)

- [ ] **Step 1: Failing tests:**
  - `keep unplaced inserts a retained row and copies the run and crops`
  - `keep on a dive turns a confirmed tag into a sighting`
  - `a held new species is created only on keep and keeps its name`
  - `keep twice makes one row`: the second call finds the item gone from the session and does nothing
  - `a file deleted from disk fails alone`
  - `a capture is saved to the library and linked by asset id`
  - `the keep sheet offers this file or all only with more than one unkept file`
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement and wire Keep into the viewer from Task 11.
- [ ] **Step 4:** Run and expect them to pass.
- [ ] **Step 5:** Commit `feat(media): keep a file identified in the scratch viewer`.

### Task 13: The Identify button

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_console_scaffold.dart`:
  - Add `identify` to `MediaConsoleAction` (:27) after `importMedia`.
  - `mediaConsoleActionsFor` (:31) includes it only when the device is not web and marine life ID is enabled. Pass the flag in.
  - `_actionButton` (:142) uses icon `Icons.travel_explore` and tooltip `media_console_identify`.
- Modify: `lib/features/media/presentation/pages/media_section_page.dart` `_runAction` (:120):
  - With no installed pack, show the species download prompt.
  - On a phone or tablet, push `IdentifyCameraPage` (Task 14).
  - On desktop, pick files with the import's picker (`MediaImportView`'s pick seam, reused through a new `pickForIdentify` that returns the candidates), build scratch items with ids `scratch:<uuid>`, and push `MediaViewerPage(scratch: ScratchSession(...))`.
- Create: `lib/features/media/presentation/helpers/scratch_items.dart`, `List<MediaItem> scratchItemsFrom(List<ImportCandidate> picked)`.
- Tests: `test/features/media/presentation/media_console_scaffold_test.dart`, `test/features/media/presentation/media_section_page_test.dart`, `test/features/media/presentation/helpers/scratch_items_test.dart` (new)

- [ ] **Step 1: Failing tests:**
  - `Identify shows only with marine life ID enabled and not on web`
  - `with no pack it shows the download prompt`
  - `on desktop picked files open the viewer in scratch mode`
  - `scratch ids never collide with uuids from createMedia`
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run and expect them to pass.
- [ ] **Step 5:** Commit `feat(media): an Identify button in the Media section`.

## Phase D: the camera

### Task 14: The camera screen and capture

**Files:**
- Modify: `pubspec.yaml`. Add the `camera` plugin (`flutter pub add camera`). Check that iOS `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` exist, adding the microphone one for video if missing. Android `CAMERA` is declared; add `RECORD_AUDIO` if absent.
- Create: `lib/features/media/presentation/pages/identify_camera_page.dart`, `IdentifyCameraPage`. It has:
  - the preview
  - a photo and video switch (`media_identify_photo` / `media_identify_video`)
  - a shutter / record button
  - a thumbnail of the session's captures, which opens the scratch viewer
  - a pick-files button, which runs the Task 13 desktop flow
  - a "Names on" switch (`media_identify_namesOn`)
  - the no-location line (`media_identify_noLocation`)
- Captures go into the OS cache dir under the session's temp folder, become scratch items, and are kept in a `ScratchSession` shared with the viewer.
- Permission denied: show `media_identify_cameraDenied` and keep the pick-files button working.
- Create: `lib/features/media/presentation/camera/camera_seam.dart`, an `abstract class IdentifyCamera` (`initialize`, `previewWidget`, `takePhoto`, `startRecording`, `stopRecording`, `frames` as `Stream<LiveFrame>`, `dispose`). `CameraPluginCamera` implements it over `camera`. Tests use a fake.
- Tests: `test/features/media/presentation/pages/identify_camera_page_test.dart` (new)

- [ ] **Step 1: Failing tests:**
  - `a photo capture joins the session and the thumbnail opens the scratch viewer`
  - `a recorded clip joins the session as a video`
  - `permission denied shows the message and the pick-files button`
  - `names off draws no labels`
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run and expect them to pass.
- [ ] **Step 5:** Commit `feat(media): an Identify camera that captures into the scratch viewer`.

### Task 15: Live naming

**Files:**
- Create: `lib/features/species_id/domain/services/live_naming_controller.dart`, a pure Dart `class LiveNamingController`. Constructor arguments:
  - `required Future<VisionAnalysis> Function(Uint8List jpeg) analyze`
  - `required Future<List<NamingResult>> Function(NamingCrops crops) name` (`nameCrops` with `cell: null`)
  - `required Future<VisionMemory> Function() memory`
  - `Duration interval = const Duration(milliseconds: 250)`
  - `int memoryMarginBytes = liveNamingMemoryMarginBytes`
  - `DateTime Function() now`

  It exposes `Stream<LiveLabels> labels` and `void offer(LiveFrame frame)`. It accepts a frame only when at least `interval` has passed since the last one and none is in flight; otherwise the frame is dropped. Before each frame it checks memory, emitting `LiveLabels.paused(LivePause.memory)` and skipping while short, then resumes. Boxes match the previous frame's at IoU >= 0.3 to keep a label's identity. Reuse the video tracker's IoU helper if public, or move it to a shared file.
- Create: `lib/features/species_id/domain/entities/live_labels.dart` (`LiveLabels`, `LiveBox` with box, suggestion name, track id, and `LivePause`).
- Create: `lib/features/media/presentation/camera/live_label_overlay.dart`, which draws `LiveBox`es over the preview with suggestion names (`?` suffix style as the viewer labels use), and the pause line `media_identify_namesPaused`.
- Frames: `CameraPluginCamera.frames` converts each `CameraImage` (YUV420 on Android, BGRA on iOS) to JPEG in an isolate before `offer`. Convert only frames the controller will accept: it exposes `bool get wantsFrame`.
- Tests: `test/features/species_id/domain/services/live_naming_controller_test.dart` (new), and an overlay widget test.

- [ ] **Step 1: Failing tests:**
  - `frames inside 250 ms are dropped`
  - `a frame offered while one is in flight is dropped, not queued`
  - `low available memory pauses, recovery resumes`
  - `lowMemory true pauses from the first frame`
  - `a box moving less than the IoU bar keeps its track id and name`
  - `names off stops offering frames`
  - `the pack unloaded or identification turned off stops naming and the camera stays open`
- [ ] **Step 2:** Run and expect FAILs.
- [ ] **Step 3:** Implement and wire the controller into `IdentifyCameraPage`.
- [ ] **Step 4:** Run and expect them to pass.
- [ ] **Step 5:** Commit `feat(species-id): live suggestions over the Identify camera`.

### Task 16: Device measurements (with the maintainer)

**Files:**
- Create: `docs/design/findings/2026-11-28-identify-camera-live-naming.md`

- [ ] **Step 1:** Install a release build on an iPhone and an 8 GB Android phone (the maintainer's devices). Record frames named per second, time to first label, and memory over 2 minutes of live naming, then while recording.
- [ ] **Step 2:** Write the findings. If a device cannot hold live naming without pausing, record it and ask the maintainer before changing the margin.
- [ ] **Step 3:** Commit `docs(species-id): measured live naming on phones`.

## Phase E: finishing

### Task 17: Translations

- [ ] **Step 1:** Translate every new key into the 11 non-English ARBs, next to a neighbouring key of the same group. Every Arabic plural (`media_identify_keepAll`) needs zero, one, two, few, many and other.
- [ ] **Step 2:** Run `flutter gen-l10n` last. Check with `grep -A1 "get media_identify_keep" lib/l10n/arb/app_localizations_de.dart`, and check that `git diff --numstat lib/l10n/arb/` changes every locale evenly.
- [ ] **Step 3:** Run the l10n guard test files the hook names, by path.
- [ ] **Step 4:** Commit `i18n(media): translate identify and keep strings`.

### Task 18: Docs

- [ ] **Step 1:** Update the user docs page for the Media section (find it with `grep -rl "Import" docs/user` or the site docs) with Identify, the camera and keeping with no place.
- [ ] **Step 2:** Commit `docs(media): identify species in media that is not on a dive`.
