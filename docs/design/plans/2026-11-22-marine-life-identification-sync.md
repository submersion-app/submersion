# Marine life identification sync: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (native, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Marine life results (runs, identifications, decisions, named crops) sync with the logbook, so a device that cannot analyse shows what another device found.

**Architecture:** The two identification tables and a new crops table join sync as clock-guarded entities. Decisions travel in a sync fact group with their own clock. Runs record who made them and a stable run id; a trust rule keeps capable devices from redoing each other's work. Showing labels is split from running the analysis.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, the app's HLC changeset sync (`lib/core/services/sync/`).

**Spec:** `docs/design/specs/2026-11-22-marine-life-identification-sync-design.md` (issue #4876). Read it first; this plan does not repeat its reasoning.

## Global Constraints

- Schema version 381 for every change in this plan (one rung); `minimumCompatibleSchemaVersion` = 381.
- New columns are nullable (or defaulted); no column is dropped, renamed or retyped.
- Entity types: `mediaIdentificationRuns` (table `media_identification_runs`, pk `media_id`), `mediaIdentifications` (table `media_identifications`, pk `id`), `mediaIdentificationCrops` (table `media_identification_crops`, pk `id`, holding the identification's id, so the sync pagers that key by `id` stream crops by size).
- Fact group: `identificationDecision`, clock key `decisionHlc`, clock column `decision_hlc`, columns `decision`, `decidedSpeciesId`, `decidedAt`, `claimedSpeciesId`, `nullClockIsUnset: true` (a renamed but never-decided row must not borrow its newer row clock and undo a decision).
- "Named" = `specific || suggestable || decision != undecided || claimedSpeciesId != null`.
- No FK from any of the three tables to `media` or to each other (undo keeps decisions).
- Change-log class `excluded` for all three tables.
- Files stay under 800 lines; `media_identification_repository.dart` (657 now) gets its sync calls in a new file.
- Tests: run only the test files you wrote or changed, by path; never a folder or the suite (the pre-push hook and CI do that).
- Never add attribution to commits; never use em-dashes.
- After any table change: `dart run build_runner build --delete-conflicting-outputs` (never `--build-filter`), in the background.

## Review Focus

1. A capable device receiving a run made elsewhere with no crops and no embeddings must do nothing on opening (no ping-pong). Pinned in Task 6.
2. A video scanned in several chunks must show every track (one `run_id` across chunks), not only the last chunk's. Pinned in Task 5.
3. A diver's accept on one device racing a rename on another must end as the accept on both. Pinned in Task 3.
4. Identification rows that arrive before their media must survive the launch orphan sweep. Pinned in Task 10.
5. A phone with no pack at the Eager level shows the same pills as the laptop that named them. Pinned in Task 7.

---

### Task 1: Schema rung v381

**Files:**
- Modify: `lib/core/database/tables/identification_tables.dart` (new columns; new `MediaIdentificationCrops` table; class docs no longer say "Never synced")
- Modify: `lib/core/database/database.dart` (register table, `currentSchemaVersion` 381, `minimumCompatibleSchemaVersion` 381 with a floor comment naming #4876, append 381 to `migrationVersions`)
- Modify: `lib/core/database/migrations/helpers/identification_migrations.dart` (`_assertIdentificationSyncSchema()`)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (v381 block)
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart` (v381 backstop)
- Modify: `lib/core/database/change_log/change_log_policy.dart` (crops table `excluded`), `lib/features/agent_access/data/sql/sql_denied_set.dart` (as its test requires), `tool/demo_data/src/checks/coverage_check.dart` and `test/architecture/agent_write_coverage_exempt.dart` if their guard tests require the new table
- Test: `test/core/database/migration_v381_identification_sync_test.dart`

**Interfaces:**
- Produces columns: runs `hlc TEXT`, `analysed_by TEXT`, `run_id TEXT`, `naming_bars TEXT`; identifications `hlc TEXT`, `run_id TEXT`, `decision_hlc TEXT`; table `media_identification_crops(id TEXT PK, media_id TEXT NOT NULL, jpeg BLOB NOT NULL, hlc TEXT)` with index on `media_id`.
- Drift getters: `MediaIdentificationRuns.hlc/analysedBy/runId/namingBars`, `MediaIdentifications.hlc/runId/decisionHlc`, `MediaIdentificationCrops` (`@DataClassName('MediaIdentificationCropRow')`).

- [ ] **Step 1: Write the failing migration test** `migration_v381_identification_sync_test.dart`: a v380 database with two runs and three identifications migrates to 381; every new column exists; the crops table exists; each run has a non-null `run_id` and its identifications carry that same `run_id`; two runs get different ids; `analysed_by`, `naming_bars`, `hlc` and `decision_hlc` stay null; running the helper twice changes nothing. Follow the setup of `test/core/database/migration_v378_*` (nearest precedent).
- [ ] **Step 2: Run it**: `flutter test test/core/database/migration_v381_identification_sync_test.dart`. Expected: FAIL (columns missing).
- [ ] **Step 3: Implement** the table columns, the helper (`_addColumnIfMissing` for each column, `createTable` for crops plus `CREATE INDEX IF NOT EXISTS idx_media_identification_crops_media`, then the `run_id` fill: `UPDATE media_identification_runs SET run_id = lower(hex(randomblob(16))) WHERE run_id IS NULL` and `UPDATE media_identifications SET run_id = (SELECT r.run_id FROM media_identification_runs r WHERE r.media_id = media_identifications.media_id) WHERE run_id IS NULL`), the rung, the backstop, the database registration and floor. Run build_runner.
- [ ] **Step 4: Run** the migration test plus `test/core/database/change_log/change_log_every_table_test.dart`, `test/features/agent_access/data/sql/sql_denied_set_test.dart` and any schema-version pin test that fails `flutter analyze`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): schema v381 for syncing identifications and crops`.

### Task 2: Entities carry origin, run id and naming bars

**Files:**
- Create: `lib/features/species_id/domain/entities/naming_bars.dart`
- Modify: `lib/features/species_id/domain/entities/media_identification.dart`
- Modify: `lib/features/species_id/data/repositories/media_identification_repository.dart` (row mapping only)
- Modify: `lib/features/species_id/domain/services/naming_levels.dart`
- Test: `test/features/species_id/domain/entities/naming_bars_test.dart`, `test/features/species_id/domain/services/naming_levels_test.dart` (extend), `test/features/species_id/data/repositories/media_identification_repository_test.dart` (extend)

**Interfaces:**
- Produces: `class NamingBars extends Equatable { int minCropSide; double minOpenScore; double suggestScore; double suggestScoreNoLocation; List<MeasuredNamingLevel> levels; factory NamingBars.fromNaming(NamingConfig naming); String toJson(); static NamingBars? fromJson(String? json); }` (bad JSON reads as null).
- Produces on `MediaIdentificationRun`: `String? analysedBy`, `String? runId`, `NamingBars? namingBars`, and `copyWith` for them. On `MediaIdentification`: `String? runId` (in `copyWith` and props).
- Produces: `LevelInForce? levelFromBars(NamingBars? bars, NamingLevel chosen, {required String packVersion})`, the same rule as `levelInForce` but from stored bars; `levelInForce(manifest, chosen)` becomes `levelFromBars(NamingBars.fromNaming(manifest.naming), chosen, packVersion: manifest.packVersion)` for a non-null manifest.

- [ ] **Step 1: Failing tests**: `NamingBars` JSON round trip equals the original; `fromJson('not json')` is null; `levelFromBars` gives the same `LevelInForce` as `levelInForce` for each `NamingLevel` against a test manifest; `levelFromBars(null, ...)` is null; the repository stores and reads back `analysedBy`, `runId`, `namingBars` and an identification's `runId`.
- [ ] **Step 2: Run** those three files. Expected: FAIL.
- [ ] **Step 3: Implement** the value object, entity fields and mapping.
- [ ] **Step 4: Run** the same files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): runs record their maker, run id and naming bars`.

### Task 3: Register the three entities with sync, decisions as a fact group

**Files:**
- Modify: `lib/core/services/sync/sync_fact_groups.dart` (`identificationDecision`, `byEntity`, `tables`)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets` x3; `_hlcBackfillTargets` x3; generalise `_backfillTable` to select the target's pk; before backfilling runs, `UPDATE media_identification_runs SET analysed_by = ? WHERE analysed_by IS NULL` with `getDeviceId()`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (all ten arm sites listed in the spec section 1 for each entity; runs use `_baseTables` `table: null, full: () => _exportMediaIdentificationRuns(null)`; identifications and crops `blob: true`; `_syncBlobSerializer` at every BLOB point; `clockGuardedEntities` += 3; `clockGuardedClearTables`/`clockGuardedClearKeys` for runs `scannedRanges`)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` after `mediaSpecies`, runs then identifications then crops; `entityHasUpdatedAt` false x3; `parentRefs` `mediaId` to `media`, not nullable, x3)
- Modify: `lib/core/services/sync/sync_record_overlay.dart` (`syncRecordId`: runs return `mediaId`)
- Modify: `lib/core/services/sync/conflict_reference.dart` (`decidedSpeciesId`, `claimedSpeciesId` to species)
- Modify: conflict field catalogue (`lib/features/settings/presentation/conflicts/catalogue/media_library_fields.dart` or a new `species_id_fields.dart` beside it) and `lib/l10n/arb/app_en.arb` labels, then `flutter gen-l10n`
- Test: `test/core/services/sync/identification_sync_round_trip_test.dart` (new), plus the guard tests in spec section 1 (`sync_hlc_target_registration_test`, `sync_parent_refs_completeness_test`, `media_clock_guard_test`, `sync_base_streaming_parity_test`, `base_publish_streaming_parity_test`, `sync_data_serializer_batch_coverage_test`, `sync_hlc_backfill_test`, `conflict_field_catalogue_coverage_test`, and the fact-group table pin test that compares `SyncFactGroups.tables` with `hlcTargets`)

**Interfaces:**
- Consumes: Task 1 columns.
- Produces: `SyncFactGroups.identificationDecision`; entity type strings above, used by Task 4.

- [ ] **Step 1: Failing round-trip test** `identification_sync_round_trip_test.dart` (two in-memory databases, the pattern of `cylinder_pairings_sync_round_trip_test.dart`): a run with `scannedRanges`, a track with `trackPath`, and a crop export from A and apply to B byte-for-byte; a base adopt carries them too; a run with null `analysed_by` gets A's device id at backfill and leaves A non-null; **decision race (Review Focus 3)**: B accepts (stamps `decisionHlc`), A then renames the same row (row hlc later), after both directions sync both hold the accept and A's new scores; a later undo on A beats B's earlier accept; a claim cleared on A reaches B as null.
- [ ] **Step 2: Run** it. Expected: FAIL.
- [ ] **Step 3: Implement** the registrations above, then update each guard test's expected sets.
- [ ] **Step 4: Run** the round-trip file and each guard test file by path. Expected: PASS.
- [ ] **Step 5: Commit** `feat(sync): sync marine life runs, identifications and crops`.

### Task 4: Every identification write marks pending; deletes tombstone

**Files:**
- Create: `lib/features/species_id/data/repositories/identification_sync_marks.dart`
- Modify: `lib/features/species_id/data/repositories/media_identification_repository.dart`
- Modify: `lib/features/media/data/repositories/media_row_restore.dart` (undo re-marks identification, run and crop rows of restored media)
- Test: `test/features/species_id/data/repositories/identification_sync_marks_test.dart`, extend `media_identification_repository_test.dart`

**Interfaces:**
- Produces: `class IdentificationSyncMarks { IdentificationSyncMarks({SyncRepository? sync}); Future<void> runsWritten(List<String> mediaIds); Future<void> rowsWritten(List<String> ids); Future<void> decisionsWritten(List<String> ids); Future<void> cropsWritten(List<String> identificationIds); Future<void> deleted({List<String> runMediaIds, List<String> rowIds, List<String> cropIds}); }`. `decisionsWritten` uses `markFactsPending(..., group: SyncFactGroups.identificationDecision)` per row (the group clock only, never the row clock); the others `markRecordsPending`; `deleted` uses `logDeletions` per entity type.
- `MediaIdentificationRepository` gains an optional constructor `IdentificationSyncMarks? marks` and calls: `storeRun`/`storeRunAfterReading` → `runsWritten`, `rowsWritten(insert ids)`, `deleted(rowIds: deleteIds)`, plus `decisionsWritten` for inserted rows that carry a decision or claim (a carried decision); `updateDecisions` and `claim` → `decisionsWritten`; `updateNames` → `rowsWritten` + `runsWritten`; `deleteForMedia` → `deleted` for runs, rows and their crops.

- [ ] **Step 1: Failing tests**: each repository write leaves the right `sync_records` pending rows and `hlc` stamped; `updateDecisions` and `claim` stamp `decision_hlc` and leave a machine-only write's `decision_hlc` unchanged; `deleteForMedia` writes deletion-log entries for runs (record id = media id), rows and crops; an undo restore re-marks the restored media's identification rows.
- [ ] **Step 2: Run** the two test files. Expected: FAIL.
- [ ] **Step 3: Implement.** Marks run after the write transaction commits, as `media_species_repository.dart` does.
- [ ] **Step 4: Run** the files plus the existing `media_row_restore` test file by path. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): identification writes publish to sync`.

### Task 5: Run identity and leftover rows

**Files:**
- Modify: `lib/features/species_id/data/services/media_identification_service.dart` and its parts (`media_identification_video.dart`), `lib/features/species_id/data/services/video_identification_scan.dart`
- Modify: `lib/features/species_id/domain/services/identification_rules.dart`
- Modify: readers: `identificationsAtLevel` (`species_id_providers.dart`), `species_review_repository.dart`, `media_identification_readiness.dart`
- Test: extend `test/features/species_id/domain/services/identification_rules_test.dart`, `test/features/species_id/data/services/media_identification_service_test.dart`, the video scan test file

**Interfaces:**
- Produces: `List<MediaIdentification> visibleRows(MediaIdentificationRun? run, List<MediaIdentification> rows)`: drops undecided, unclaimed rows whose `runId` is non-null and differs from `run.runId`; keeps everything when `run` or `run.runId` is null.
- The service sets on every run it writes `analysedBy: await deviceId()` (new constructor parameter `Future<String> Function()? deviceId`, provider passes `SyncRepository().getDeviceId`), and `runId`: a new `_newId()` when a photo analysis or a video scan from the start begins; a later chunk, resume or rename keeps the stored `runId`. Every inserted identification gets the run's `runId`.
- Analysing writes read rows unfiltered, so `carryDecisions` deletes leftovers (they are undecided) with tombstones via Task 4.

- [ ] **Step 1: Failing tests**: `visibleRows` cases (leftover hidden; decided leftover kept; claimed leftover kept; null run id kept); a photo analysed twice gets two different run ids; **a video scanned in three chunks (Review Focus 2)** stores one run id on the run and on every track from every chunk, and `visibleRows` returns all tracks; a leftover row is deleted by the next analysis of that media.
- [ ] **Step 2: Run** the test files. Expected: FAIL.
- [ ] **Step 3: Implement**, and apply `visibleRows` in the three readers.
- [ ] **Step 4: Run** the files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): runs carry a stable id; rows of a lost run are hidden`.

### Task 6: The trust rule

**Files:**
- Modify: `lib/features/species_id/domain/services/identification_rules.dart` (`decideRefresh`), `lib/features/species_id/domain/services/video_identification_rules.dart` (`decideVideoRefresh`)
- Modify: `media_identification_service.dart`, `media_identification_readiness.dart`, `media_identification_video.dart` (callers); `auto_applier.dart` or the `onItemSettled` wiring (auto-apply only for runs made here)
- Create if none exists: `int comparePackVersions(String a, String b)` in `lib/features/species_id/domain/services/pack_versions.dart`
- Test: `identification_rules_test.dart`, the video rules test, `media_identification_service_test.dart`, the auto-apply test

**Interfaces:**
- `decideRefresh` and `decideVideoRefresh` gain `required bool madeHere`. When `madeHere` is false: return `analyse` only if `comparePackVersions(packVersion, run.packVersion) > 0` and (`run.detectorId != detectorId` or `run.classifierId != classifierId`); otherwise `none`. Crops, embeddings and cell are not consulted. When true: unchanged.
- `madeHere` = `run.analysedBy == await deviceId()`.
- A video run made elsewhere is never resumed by the scan; only a fresh request (Analyse again) scans it, from the start.

- [ ] **Step 1: Failing tests (Review Focus 1)**: made elsewhere, crops and embeddings missing, same pack → `none`; made elsewhere, older pack here → `none`; made elsewhere, later pack, same models → `none`; made elsewhere, later pack, new detector → `analyse`; made elsewhere, different cell → `none`; every existing made-here case passes unchanged; the service does not call the engine when opening such a photo; a fresh request does; a partial video made elsewhere is not resumed on opening; auto-apply does not run for a run made elsewhere.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): trust results made on another device`.

### Task 7: Naming bars travel with the run

**Files:**
- Modify: `media_identification_service.dart` (store `NamingBars.fromNaming(manifest.naming)` on every run it analyses or renames)
- Modify: `species_id_providers.dart` (`identificationsAtLevel` and `levelInForceProvider` callers): with no installed pack, apply the chosen level per media using `levelFromBars(run.namingBars, chosen, packVersion: run.packVersion)`; a run without bars reads the stored flags
- Modify: `species_review_repository.dart` (same rule for its loose-level reading)
- Create: a one-shot fill in the pack controller or service: when the installed pack is read, `UPDATE`-equivalent through the repository writes bars onto runs made here with that `packVersion` and null bars (marks them pending)
- Test: extend `label_providers` / `species_id_providers` tests, the review repository test, the service test

**Interfaces:**
- Consumes: Task 2 `NamingBars`, `levelFromBars`.
- Produces: `MediaIdentificationRepository.fillNamingBars(String packVersion, NamingBars bars, {required String deviceId}) -> Future<int>`.

- [ ] **Step 1: Failing tests (Review Focus 5)**: with no pack installed and level Eager, rows of a run carrying bars show the same pills as with the pack installed; a run without bars shows the stored flags; the review page lists the same suggestions; `fillNamingBars` fills only runs made here of that pack and marks them pending.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): a device with no pack names at the chosen level`.

### Task 8: Named crops live in the synced table

**Files:**
- Create: `lib/features/species_id/data/repositories/identification_crop_repository.dart`
- Create: `lib/features/species_id/data/services/named_crop_backfill.dart`
- Modify: `lib/features/species_id/data/services/identification_crop_store.dart` (fronts file and table)
- Modify: `media_identification_service.dart` (analysis write: named crops to the table, others to files; a row becoming named on rename moves its file into the table)
- Modify: `media_identification_readiness.dart` (`_cropsPresent` counts table crops)
- Modify: `species_id_providers.dart` (`identificationCropFileProvider` becomes `identificationCropProvider` returning `IdentificationCropImage?`; launch hook runs the backfill)
- Modify: `suggested_species_section.dart` (`IdentificationCrop` draws `Image.memory` or `Image.file`)
- Test: `identification_crop_repository_test.dart`, `named_crop_backfill_test.dart`, extend the crop store and service tests

**Interfaces:**
- Produces: `bool isNamed(MediaIdentification i)` in `identification_rules.dart`.
- Produces: `class IdentificationCropRepository { Future<Uint8List?> bytesFor(String identificationId); Future<Set<String>> presentAmong(List<String> identificationIds); Future<void> put(String identificationId, String mediaId, Uint8List jpeg); Future<void> deleteForIdentifications(List<String> ids); }` (writes mark pending / tombstone through Task 4's `IdentificationSyncMarks`).
- Produces: `sealed class IdentificationCropImage` with `CropFile(File file)` and `CropBytes(Uint8List bytes)`; `IdentificationCropStore.read(String mediaId, String identificationId) -> Future<IdentificationCropImage?>` (file first, then table); `allPresent` counts either.
- Produces: `class NamedCropBackfill { Future<int> run({int batch = 50}); }`: for named rows of runs made here whose crop file exists and table row does not, put the bytes and delete the file; repeatable; never throws.

- [ ] **Step 1: Failing tests**: a named crop written by analysis lands in the table, not as a file; an unnamed one is a file; `read` finds either; `_cropsPresent` true with table crops only; the backfill moves 3 named files of 5, is a no-op on a second run, and skips rows whose crop is missing; deleting an identification tombstones its crop row; the crop widget shows bytes from the table.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): named crops sync with the logbook`.

### Task 9: Labels show on every platform; analysis only where it runs

**Files:**
- Modify: `lib/core/constants/feature_flags.dart` (add `bool get marineLifeLabelsShown => _marineLifeIdOverride ?? _marineLifeIdDefine;` and a test override path consistent with `resetMarineLifeIdEnabled`)
- Modify, switching to `marineLifeLabelsShown`: `photo_identification_layer.dart`, `video_identification_layer.dart` and its `media_viewer_video_item.dart` mount, `video_analysed_stretches.dart`, `label_providers.dart`, `species_review_providers.dart`, `media_species_chips_row.dart`, `labels_menu.dart` (modes always; Analyse and Analyse again only when `marineLifeIdEnabled`; the action applies to video where a player exists, `visionVideoRuns` no longer gates showing), the suggestion section
- Keep on `marineLifeIdEnabled`: `identification_trigger.dart`, `video_playhead_reporter.dart`, `dive_find_species_panel.dart`, `species_download_prompt_providers.dart`, `auto_applier.dart`, `photos_videos_page.dart`, `media_store_providers.dart`, `storage_inventory.dart`, the pack page
- Dropped while building: the outlined thumbnail fallback. Every crop drawn belongs to a named identification, whose crop syncs; see the spec, section 4.
- Test: extend the labels menu, photo layer, review provider and crop widget tests

**Interfaces:**
- Produces: `marineLifeLabelsShown`.

- [ ] **Step 1: Failing tests**: with labels shown and analysis off (override engine off), the photo layer draws stored pills, the labels menu lists the three modes and no Analyse item, the review provider returns suggestions, the trigger requests nothing.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** and audit every remaining `marineLifeIdEnabled` read against the two lists.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): show synced labels where the models cannot run`.

### Task 10: Orphan sweep and clear all

**Files:**
- Modify: `lib/features/species_id/data/repositories/media_identification_repository.dart` (`orphanMediaIds` returns only media ids with a `media` tombstone in `deletion_log`)
- Modify: `lib/features/species_id/data/services/identification_cleanup.dart` (`clearAll` tombstones through `deleteForMedia`; crops and embeddings as today)
- Modify: `lib/l10n/arb/app_en.arb` `settings_speciesId_clearConfirmBody` to say the clear applies on every device that syncs this logbook; `flutter gen-l10n`
- Test: extend `identification_cleanup_test.dart` and the repository test

- [ ] **Step 1: Failing tests (Review Focus 4)**: rows whose media id has no media row and no tombstone survive `sweepOrphans`; rows of a tombstoned media are purged; `clearAll` writes deletion-log entries for every run, row and crop.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(species-id): sweep only deleted media; clear all clears everywhere`.

### Task 11: Developer docs and final checks

**Files:**
- Modify: `docs/developer/species-identification.md` (a section on sync: what syncs, the trust rule, the decision fact group, named crops)
- Modify: the v375 to v377 comments in `database.dart` that say the tables are local

- [ ] **Step 1:** Update the docs.
- [ ] **Step 2:** `dart format .`, `flutter analyze` (whole repo, no issues), and every test file changed in this plan by path.
- [ ] **Step 3: Commit** `docs(species-id): how marine life results sync`.
