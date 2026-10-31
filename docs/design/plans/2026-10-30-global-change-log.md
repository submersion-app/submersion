# Global Change Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An always-on, per-device log of every change to user data, with old and new values, a feed, per-record history, and revert of fields, entries and whole bulk actions, including restoring deleted records.

**Architecture:** Generated SQLite triggers write raw events and per-column values into local-only tables. A shared context row tells triggers the current operation and whether recording is suppressed. A Dart settling step folds raw events into diver-visible operations. Revert is a new edit: it never restores an old clock.

**Tech Stack:** Flutter, Drift 2.34, SQLite/SQLCipher, Riverpod, go_router, SharedPreferences.

**Spec:** [docs/design/specs/2026-10-30-global-change-log-design.md](../specs/2026-10-30-global-change-log-design.md)

**Issue:** #3922. Release v1.8.4. One PR.

## Global Constraints

- Logging must never fail a save or stop the app opening.
- Every table in `allTables` is classified in `ChangeLogPolicy`.
- `currentSchemaVersion` moves from 327 to the next free version; recheck open PRs before pushing.
- Log tables have no `hlc` column and are not registered with sync.
- Excluded columns: `conflictBookkeepingColumns` less `id`, the `SyncFactGroups.mediaUpload`-style media device facts and their clocks, device-local columns, and credentials (`signing_private_key`, `credentials_ref`, `credentials_host_id`, `instance_token`).
- Retention choices: 3, 6, 12 months or forever. Default 12.
- `kChangeLogManualGroupWindow` is 5 seconds.
- A revert never writes a logged `hlc`; it uses `markRecordPending`, and a restored root row gets `updated_at = now`.
- Anything displaying units uses the active diver's unit settings. All strings go through ARB files, in every locale file the repo keeps.
- No table or rung in `database.dart`. New `beforeOpen` code goes in a part file. No em-dashes anywhere, no emojis, no tool attribution.
- Paths in tests use `p.join` and `Directory.systemTemp`. Tests restore any global state they change.
- `dart format .` and `flutter analyze` before each commit. `test/architecture/` and `test/shared/` after adding files under `lib/`.

## Review Focus

1. Records with no plain `id`: `settings` (key), `dive_equipment` and other composite keys, whose id must match `syncRecordId`. A wrong id makes revert silently touch nothing.
2. A device clock moved backwards between edits: the feed must order by event id within a day, and grouping must not merge or split on a negative gap.
3. Very long or binary values (notes, `raw_dive_data`): the feed clips text and shows a blob as a size, never raw bytes, and never lays out a huge string.
4. Switching diver with the log open, and an entry whose owner diver has been deleted or whose record was shared then unshared: the feed reloads and never shows another diver's entry.
5. A revert while a sync is running: revert goes through `SyncCoordinator.run`, so it cannot interleave with a merge.

---

## File Map

| File | Responsibility |
| --- | --- |
| `lib/core/database/tables/change_log_tables.dart` | The four tables |
| `lib/core/database/migrations/helpers/change_log_migrations.dart` | Rung helper |
| `lib/core/database/migrations/before_open_change_log.dart` | Table assert, pragma, trigger install |
| `lib/core/database/change_log/change_log_policy.dart` | Table classes, ignored columns, parent map |
| `lib/core/database/change_log/change_log_trigger_sql.dart` | Pure SQL generation |
| `lib/core/database/change_log/change_log_rewrites.dart` | Columns rewritten by later rungs |
| `lib/core/services/change_log/change_log_scope.dart` | Source context and suppression |
| `lib/features/change_log/domain/entities/` | `ChangeLogOperation`, `ChangeLogEvent`, `ChangeLogFieldChange`, `ChangeLogFilter`, `ChangeLogRevertPlan` |
| `lib/features/change_log/data/services/change_log_settler.dart` | Raw events to operations |
| `lib/features/change_log/data/services/change_log_dependencies.dart` | Foreign key index, in-use and missing-parent checks |
| `lib/features/change_log/data/services/change_log_revert_service.dart` | Revert planning and execution |
| `lib/features/change_log/data/services/change_log_maintenance.dart` | Pruning |
| `lib/features/change_log/data/repositories/change_log_repository.dart` | Feed, detail, clear |
| `lib/features/change_log/data/repositories/change_log_preferences.dart` | Retention preference |
| `lib/features/change_log/presentation/` | Providers, feed, detail, revert dialogs, history menu item, settings tile |

---

### Task 1: Tables and schema rung

**Files:**
- Create: `lib/core/database/tables/change_log_tables.dart`, `lib/core/database/migrations/helpers/change_log_migrations.dart`, `lib/core/database/migrations/before_open_change_log.dart`
- Modify: `lib/core/database/database.dart` (imports, table list, `currentSchemaVersion`), `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, `lib/core/database/migrations/app_database_migrations.dart` (part line), `lib/core/database/migrations/before_open.dart` (one call at the end)
- Test: `test/core/database/change_log_tables_test.dart`

**Interfaces:**
- Produces: drift tables `ChangeLogContext` (`change_log_context`), `ChangeLogOperations`, `ChangeLogEvents`, `ChangeLogFields`.

Columns:

- `change_log_context`: `id` int primary key (always 1), `operation_id` text nullable, `scope_expires_at` int nullable, `suppressed_until` int nullable, `trigger_hash` text nullable. One row is seeded by the rung and the backstop.
- `change_log_operations`: `id` text pk, `source` text, `label` text nullable, `device_id` text nullable, `diver_id` text nullable, `root_table` text nullable, `root_id` text nullable, `root_label` text nullable, `root_ordinal` int nullable, `started_at` int, `ended_at` int, `last_event_id` int nullable, `event_count` int default 0, `summary_count` int nullable, `closed` bool default false, `revert_of_id` text nullable, `reverted_by_id` text nullable. Indexes: `(diver_id, last_event_id)`, `(root_table, root_id, last_event_id)`. `last_event_id` orders the feed, because event ids only rise while the device clock can move backwards. A summary operation takes the current highest event id.
- `change_log_events`: `id` int autoincrement, `operation_id` text nullable, `table_name` text, `record_id` text, `action` text (`I`, `U`, `D`), `changed_at` int, `schema_version` int, `settled` bool default false, `root_table` text nullable, `root_id` text nullable. Indexes: `(settled, id)`, `(operation_id)`, `(table_name, record_id, id)`.
- `change_log_fields`: `event_id` int, `column_name` text, `old_value` blob nullable, `new_value` blob nullable, primary key `(event_id, column_name)`, `WITHOUT ROWID`.

`old_value` and `new_value` are declared `blob()` because SQLite's BLOB declared type has no affinity and stores every value unchanged. A drift `any` column declares `ANY`, which has numeric affinity outside `STRICT` tables and would turn the text `'028'` into `28`. They are read through `customSelect` and `row.data`, never the generated row class.

- [ ] **Step 1: Write failing tests** `change_log_fields keep every SQLite type` (insert text `'028'`, int 28, real 1.5, null and a blob; read each back with its type), `a fresh database has one context row`, `a v327 database upgrades to the new tables`, `a restored database missing the tables gets them on open`.
- [ ] **Step 2: Run** `flutter test test/core/database/change_log_tables_test.dart`. Expected: compile failure.
- [ ] **Step 3: Implement** the tables, rung, `_assertChangeLogTables()` in the part file, and register the tables. Run codegen through `bash scripts/setup.sh`.
- [ ] **Step 4: Run** the test file, `test/core/database/` and `test/core/services/sync/sync_hlc_target_registration_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): add change log tables`.

### Task 2: Policy and trigger SQL

**Files:**
- Create: `lib/core/database/change_log/change_log_policy.dart`, `lib/core/database/change_log/change_log_trigger_sql.dart`
- Test: `test/core/database/change_log/change_log_policy_test.dart`, `test/core/database/change_log/change_log_trigger_sql_test.dart`

**Interfaces:**
- Produces:
  - `enum ChangeLogClass { tracked, deleteCopyOnly, excluded }`
  - `const Map<String, ChangeLogClass> changeLogTables`
  - `Set<String> changeLogIgnoredColumns(String table)`
  - `const Map<String, ChangeLogParent> changeLogParents`, with `ChangeLogParent({String rootTable, String column})`
  - `class ChangeLogTableSpec { String table; List<String> keyColumns; List<String> columns; }`
  - `List<ChangeLogTableSpec> changeLogSpecsFor(GeneratedDatabase db)`, from `allTables`, `$columns` and `$primaryKey`
  - `String changeLogRecordIdSql(String prefix, List<String> keyColumns)`: single key `OLD."id"`, composite `OLD."a" || '|' || OLD."b"`
  - `List<String> buildChangeLogTriggers(ChangeLogTableSpec spec, ChangeLogClass cls, {required int schemaVersion})`
  - `const kChangeLogTriggerPrefix = 'change_log_trg_'`, `String changeLogTriggersHash(List<String> statements)`

Classification, by SQL name. Everything not listed is `tracked`.

- `deleteCopyOnly`: `dive_profile_series`, `dive_profile_series_history`, `tank_pressure_series`, `media_enrichment`, `dive_safety_findings`, `dive_safety_reviews`, `tide_records`.
- `excluded`: `cached_regions`, `change_log_context`, `change_log_events`, `change_log_fields`, `change_log_operations`, `connected_accounts`, `deletion_log`, `dive_derived_metrics`, `dive_sensor_summaries`, `equipment_condition_reviews`, `equipment_findings`, `equipment_service_status`, `gps_track_points_local`, `local_publish_states`, `media_fetch_diagnostics`, `media_repair_log`, `media_subscription_state`, `nearby_peers`, `network_credential_hosts`, `pending_photo_suggestions`, `quality_findings`, `rule_run_changes`, `rule_runs`, `scheduled_notifications`, `shared_libraries`, `shared_library_backups`, `shared_library_members`, `shared_site_states`, `shared_site_suggestions`, `sync_metadata`, `sync_peer_cursors`, `sync_records`.

Parents: any table with a `dive_id` foreign key to `dives` roots at `dives`; the same for `site_id` to `dive_sites`, `equipment_id` to `equipment`, `trip_id` to `trips`, `plan_id` to `dive_plans`, `set_id` to `equipment_sets`, `course_id` to `courses`, `certification_id` to `certifications`, `document_id` to `documents`, `media_id` to `media`, `template_id` to the two checklist template tables, `session_id` to `pre_dive_sessions`, `preset_id` to `weight_presets`, `config_id` to `cylinder_configs`. Tables with a `diver_id` of their own and no such parent are roots.

Trigger shape, all guarded with `WHEN COALESCE((SELECT suppressed_until FROM change_log_context WHERE id = 1), 0) <= <now>`. `<now>` is `CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)`, since `unixepoch('subsec')` is not on every SQLCipher build we ship.

- Update: `AFTER UPDATE`, extra guard `OLD.a IS NOT NEW.a OR ...` over tracked columns, then the event insert, then `INSERT INTO change_log_fields SELECT last_insert_rowid(), c, o, n FROM (SELECT 'a' c, OLD."a" o, NEW."a" n UNION ALL ...) WHERE o IS NOT n`.
- Delete: event, then one row per non-null column of the whole table except `hlc`, with `new_value` null, so the row can be rebuilt. Ignored columns are kept here, because a restore needs them. Credentials are the exception.
- Insert: event only.
- The event's `operation_id` is `(SELECT CASE WHEN scope_expires_at > <now> THEN operation_id END FROM change_log_context WHERE id = 1)`.

- [ ] **Step 1: Write failing tests:**
  - `every table in allTables is classified` lists any table missing from `changeLogTables`, and any key that is not a real table.
  - `every child parent column exists on that table`.
  - `a composite key joins with a pipe, matching syncRecordId` compares against `syncRecordId('diveEquipment', ...)`.
  - `no credential column appears in any generated trigger`.
  - `generated triggers are stable across runs`.
- [ ] **Step 2: Run** the two files. Expected: compile failure.
- [ ] **Step 3: Implement** both files.
- [ ] **Step 4: Run** the two files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): classify tables and generate triggers`.

### Task 3: Trigger lifecycle and capture

**Files:**
- Modify: `lib/core/database/migrations/before_open_change_log.dart`, `lib/core/database/migrations/migration_strategy.dart`
- Test: `test/core/database/change_log/change_log_capture_test.dart`, `test/core/database/change_log/change_log_lifecycle_test.dart`, `test/core/database/change_log/change_log_every_table_test.dart`

**Interfaces:**
- Produces: `Future<void> dropChangeLogTriggers(GeneratedDatabase db)`, and `AppDatabase._assertChangeLogTriggers()`, which is the last call in `_beforeOpen`.

`_beforeOpen` sets `PRAGMA recursive_triggers = ON` in the same part file, because test databases and the plain opener bypass `applyConnectionBasics`. `_onUpgrade` calls `dropChangeLogTriggers` before the ladder. `_assertChangeLogTriggers` compares the hash and replaces the triggers in one transaction when it differs; a failure is logged through `developer.log` and never rethrown.

- [ ] **Step 1: Write failing tests:**
  - `a field edit logs one event and only that field`.
  - `a write that changes only hlc or updated_at logs nothing`.
  - `a delete keeps every non-null column`, and `deleting a dive logs its cascaded children`.
  - `INSERT OR REPLACE logs a delete and an insert`.
  - `a suppressed window logs nothing`.
  - `opening twice does not rewrite triggers` (hash unchanged, `sqlite_master` rowids unchanged).
  - `a stale hash rewrites triggers`.
  - `an upgrade with old triggers can drop a column`.
  - `a failing trigger install does not stop open`.
  - `change_log_every_table_test`: for every tracked table, insert, update each column and delete a row built from column types, with foreign keys off, and expect no error. This is the test that protects saves.
- [ ] **Step 2: Run** the three files. Expected: FAIL.
- [ ] **Step 3: Implement** the lifecycle.
- [ ] **Step 4: Run** the three files, `test/core/database/`, `test/core/services/sync/` and `test/architecture/`. Expected: PASS. Investigate any row-count or `sqlite_master` assertion that fails rather than loosening it.
- [ ] **Step 5: Commit** `feat(change-log): install capture triggers`.

### Task 4: Scope and suppression

**Files:**
- Create: `lib/core/services/change_log/change_log_scope.dart`
- Test: `test/core/services/change_log/change_log_scope_test.dart`

**Interfaces:**
- Produces:
  - `enum ChangeLogSource { manual, import, download, rule, sync, automatic, revert, system }`
  - `abstract final class ChangeLogScope`
  - `static Future<T> run<T>(AppDatabase db, {required ChangeLogSource source, String? label, String? deviceId, String? revertOfId, required Future<T> Function() body})`, which returns the body's result and creates one `change_log_operations` row
  - `static Future<T> suppressed<T>(AppDatabase db, {required String label, required ChangeLogSource source, int? summaryCount, required Future<T> Function() body})`
- `kChangeLogLease` is 5 minutes, renewed every minute by a timer cancelled in `finally`.

`run` remembers the previous `operation_id`, writes its own, runs the body, closes the operation, and restores the previous id only if the context still holds its own. A context failure is logged and the body still runs, since logging must never block work.

- [ ] **Step 1: Write failing tests** `events inside a scope carry its operation`, `a nested scope restores the outer one`, `an expired scope stops labelling`, `an expired suppression lets recording resume`, `the body still runs when the context write fails`, `a throwing body closes the operation and rethrows`, `an open during a scope leaves it alone`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement** `ChangeLogScope`.
- [ ] **Step 4: Run** the file. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): add source scopes and suppression`.

### Task 5: Settling

**Files:**
- Create: `lib/features/change_log/domain/entities/change_log_operation.dart`, `lib/features/change_log/data/services/change_log_settler.dart`
- Test: `test/features/change_log/data/services/change_log_settler_test.dart`

**Interfaces:**
- Produces: `class ChangeLogSettler { Future<int> settle({int batch = 500}); }`, returning events settled. `ChangeLogOperation` with `source`, `label`, `deviceId`, `diverId`, `rootTable`, `rootId`, `rootLabel`, `rootOrdinal`, `startedAt`, `endedAt`, `eventCount`, `summaryCount`, `revertOfId`, `revertedById`.

Rules:

- Root is `changeLogParents[table]`, walked until none remains, using the row or the delete copy.
- Events with an `operation_id` join it. A null id joins the latest open manual operation with the same root when `0 <= gap <= kChangeLogManualGroupWindow`; otherwise a new manual operation.
- `D` then `I` of one record in one operation becomes `U`: the insert's values are read from the live row, and only differing columns remain. An `I` then `D` of one record in one operation cancels out.
- A closed operation with no events is deleted.
- Owner comes from the root's `diver_id`, or the delete copy. A root without one stays null.
- `root_label` comes from the root's name column or a dive's site name; `root_ordinal` is `dive_number`. Labels are stored as written, not localized.

- [ ] **Step 1: Write failing tests** `two saves within five seconds on one dive are one operation`, `a save six seconds later is a new operation`, `a backwards clock starts a new operation`, `tank and dive edits share the dive as root`, `replace folds into an update`, `an insert then delete in one operation vanishes`, `an empty scope leaves no operation`, `owner survives the root being deleted`, `labels survive the root being deleted`, `a settings key record settles`, `settling is resumable after a batch limit`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement** the settler.
- [ ] **Step 4: Run** the file. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): settle raw events into operations`.

### Task 6: Repository and providers

**Files:**
- Create: `lib/features/change_log/domain/entities/change_log_event.dart`, `lib/features/change_log/domain/entities/change_log_filter.dart`, `lib/features/change_log/data/repositories/change_log_repository.dart`, `lib/features/change_log/presentation/providers/change_log_providers.dart`
- Test: `test/features/change_log/data/repositories/change_log_repository_test.dart`, add a case to `test/architecture/repository_tick_stream_test.dart`

**Interfaces:**
- Produces:
  - `class ChangeLogFilter { Set<String> rootTables; Set<ChangeLogSource> sources; String? rootTable; String? rootId; }`
  - `class ChangeLogPageCursor { int lastEventId; }`
  - `Future<List<ChangeLogOperation>> getFeed({required String diverId, required ChangeLogFilter filter, ChangeLogPageCursor? after, int limit = 50})`
  - `Future<ChangeLogOperation?> getOperation(String id)`
  - `Future<List<ChangeLogEvent>> getEvents(String operationId)`, with `ChangeLogEvent.fields` as `List<ChangeLogFieldChange>` (`column`, `oldValue`, `newValue`)
  - `Future<Map<String, List<ChangeLogFieldChange>>> getPreviewFields(List<String> operationIds, {int perOperation = 2})`
  - `Future<int> clearForDiver(String diverId)`
  - `Stream<void> watchChanges()`, on `change_log_operations`
  - providers `changeLogFeedProvider` (family by filter, paged notifier), `changeLogOperationProvider`, `changeLogEventsProvider`

Scope: `diver_id = ? OR diver_id IS NULL OR` the root id is shared with the diver through `site_shares`, `equipment_shares` or `trip_shares`. Order: `last_event_id DESC`, with the day grouping done in the page from `ended_at`. Opening the feed runs `settle()` first. A debounced `settle()` also runs after `SyncEventBus` local changes.

- [ ] **Step 1: Write failing tests** `feed shows only the active diver`, `a shared site's change shows for the diver it is shared with`, `an unshared record stops showing`, `a null owner shows for every diver`, `filter by record type and by source`, `record filter returns one root`, `paging returns no duplicates across equal timestamps`, `a backwards clock keeps the newest change first`, `clear removes one diver's entries and their fields`, plus the tick case.
- [ ] **Step 2: Run** the files. Expected: compile failure.
- [ ] **Step 3: Implement** the repository and providers.
- [ ] **Step 4: Run** the files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): read the feed and entry detail`.

### Task 7: Wrap sources

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart` (`_applyRemotePayload`, `_applyRemoteBaseFile`), `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart` (`performImport`), `lib/features/dive_computer/data/services/dive_import_service.dart`, `lib/features/rules/data/services/rule_engine.dart` (`run`), `lib/features/dive_log/data/services/dive_merge_service.dart`, `lib/features/dive_log/data/services/dive_consolidation_service.dart`, `lib/features/buddies/data/repositories/buddy_merge_repository.dart`, `lib/features/divers/data/repositories/diver_merge_repository.dart`, `lib/features/data_quality/data/services/quality_repair_executor.dart`, and the bulk methods of the dive, site and equipment repositories and notifiers. Also the restore and replace-and-join paths, and demo mode entry and exit if they write the live database (check `lib/features/demo_mode/` first; a separate file needs no scope).
- Test: `test/core/services/sync/change_log_sync_scope_test.dart`, one scope assertion added to each area's existing test.

**Interfaces:**
- Consumes: `ChangeLogScope.run`, `ChangeLogScope.suppressed`.

`_applyRemotePayload` runs in a `sync` scope with the payload's device id. `_applyRemoteBaseFile` is suppressed with one summary operation when `lastSync == null`, and otherwise runs in a `sync` scope. Scopes are outside the existing transactions, so a failure in the scope cannot discard a cursor update.

- [ ] **Step 1: Write failing tests** `a pulled edit logs under sync with the peer's device id`, `first adoption logs one summary and no rows`, `a lapped base logs its real differences as sync`, `a lapped base that changes nothing logs nothing`, `an import is one operation`, `a rule run is one operation`, `a merge is one operation`.
- [ ] **Step 2: Run** the test files. Expected: FAIL.
- [ ] **Step 3: Wrap** each entry point.
- [ ] **Step 4: Run** the test files, `test/core/services/sync/` and `test/features/rules/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): label changes by source`.

### Task 8: Automatic writers

**Files:**
- Modify: each writer found below.
- Test: `test/features/change_log/automatic_sources_test.dart`

Inventory, starting from these and then confirmed by reading what each writes:

`gallery_origin_backfill.dart`, `gallery_cloud_id_backfill.dart`, `media_origin_republish_sweep.dart`, `media_orphan_backlog_sweep.dart`, `media_backfill_service.dart`, `media_verification_sweep.dart`, `media_repair_service.dart`, `site_location_backfill_service.dart`, `tank_role_repair_repository.dart`, `equipment_file_converter.dart`, `equipment_condition_refresher.dart`, `legacy_buddy_conversion_service.dart`, `trip_day_weather_backfill.dart`, `safety_review_sweep.dart`, `SyncRepository.backfillMissingHlc`, and any notification or tide job.

A job that writes only excluded tables needs no scope. List each writer's outcome in the commit message.

- [ ] **Step 1: Write the failing test** `each automatic job logs under automatic` for at least the gallery backfill and the gear file conversion.
- [ ] **Step 2: Run** it. Expected: FAIL.
- [ ] **Step 3: Wrap** every writer that touches a tracked table in `ChangeLogScope.run(source: ChangeLogSource.automatic, label: ...)`.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): label automatic changes`.

### Task 9: Feed page

**Files:**
- Create: `lib/features/change_log/presentation/pages/change_log_page.dart`, `lib/features/change_log/presentation/widgets/change_log_entry_tile.dart`, `lib/features/change_log/presentation/change_log_labels.dart`, `lib/features/change_log/presentation/change_log_value_format.dart`
- Modify: `lib/core/router/app_router.dart`, `lib/features/settings/presentation/pages/data_section_content.dart`, ARB files
- Test: `test/features/change_log/presentation/change_log_page_test.dart`, `test/features/change_log/presentation/change_log_value_format_test.dart`

**Interfaces:**
- Produces: routes `/settings/change-log` (query `rootTable`, `rootId`) and `/settings/change-log/:id`. `String formatChangeLogValue(BuildContext context, {required String table, required String column, required Object? value})`.

`formatChangeLogValue` calls `conflictFieldFor(columnJsonKey(table), columnJsonKey(column))` and `formatConflictValue`, resolves foreign keys through `ConflictReferenceResolver`, clips long text to 200 characters in the feed, and shows a blob as its size. Add a test that `columnJsonKey(table)` equals the entity key for every table in `SyncRepository.hlcTargets`.

The tile goes in the "Your data" group of `data_section_content.dart`, enabled in demo mode. Layout follows option B of the mockup: day headers, source chips, title, source line, first two field changes with the old value struck through, and "+n more" or "View n records".

- [ ] **Step 1: Write failing tests** `feed shows two changed fields and +1 more`, `values use the diver's units` (metres and feet), `old value is struck through`, `a bulk entry shows its count`, `a blob shows its size`, `a 5,000 character note is clipped`, `switching diver reloads the feed`, `an empty log shows the empty state`, `the record filter shows that record's title`.
- [ ] **Step 2: Run** the files. Expected: compile failure.
- [ ] **Step 3: Implement** the page, tile, formatter, route, tile in Settings and ARB strings. Run `flutter gen-l10n`.
- [ ] **Step 4: Run** the files and `test/shared/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): add the change log page`.

### Task 10: Entry detail and record history

**Files:**
- Create: `lib/features/change_log/presentation/pages/change_log_entry_page.dart`, `lib/features/change_log/presentation/widgets/change_log_history_menu_item.dart`
- Modify: detail pages for dive (both menus), site, equipment, equipment set, trip, buddy, certification, course, dive center, document, species, nav track and GPS track
- Test: `test/features/change_log/presentation/change_log_entry_page_test.dart`

**Interfaces:**
- Produces: `void openChangeLogHistory(BuildContext context, {required String rootTable, required String rootId})`.

Read-only at this task, in the first and third mockup states. A record's name links to it only when the row still exists. Pages with no overflow menu get the item in their existing action row.

- [ ] **Step 1: Write failing tests** `detail lists every changed field`, `a bulk entry lists its records`, `a deleted record shows no open link`, `a dive's History item opens the filtered log`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement** the page and the History items.
- [ ] **Step 4: Run** the file and each touched page's tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): show entry detail and record history`.

### Task 11: Revert edits

**Files:**
- Create: `lib/features/change_log/domain/entities/change_log_revert_plan.dart`, `lib/features/change_log/data/services/change_log_revert_service.dart`, `lib/core/database/change_log/change_log_rewrites.dart`
- Test: `test/features/change_log/data/services/change_log_revert_edit_test.dart`

**Interfaces:**
- Produces:
  - `class ChangeLogRevertItem { ChangeLogEvent event; String? column; Object? logged; Object? current; ChangeLogBlock? block; bool changedSince; }`
  - `enum ChangeLogBlock { recordGone, columnGone, rewritten, parentGone, alreadyRestored, inUse }`
  - `class ChangeLogRevertPlan { List<ChangeLogRevertItem> items; bool get hasChangedSince; }`
  - `class ChangeLogRevertResult { int reverted; int kept; List<ChangeLogRevertItem> keptItems; String? operationId; }`
  - `class ChangeLogRevertService { Future<ChangeLogRevertPlan> planField(int eventId, String column); Future<ChangeLogRevertPlan> planEvent(int eventId); Future<ChangeLogRevertPlan> planOperation(String operationId); Future<ChangeLogRevertResult> execute(ChangeLogRevertPlan plan, {bool includeChangedSince = true}); }`
  - `const Map<String, int> changeLogRewrittenColumns`, empty at this schema, keyed `'table.column'`, value the rung that rewrote it. An event below that version is blocked `rewritten`. The ladder gets a header comment naming this rule.

`execute` runs in `SyncCoordinator.run`, then `ChangeLogScope.run(source: revert, revertOfId: ...)`, then one transaction. Each write is `UPDATE "t" SET "c" = ?, "updated_at" = ?` when the table has `updated_at`, then `SyncRepository.markRecordPending(entityType: columnJsonKey(t), recordId: id, localUpdatedAt: now, alsoStamp: <groups holding c>)`. After commit: `refreshAfterRuleWrites` for affected dive ids, `db.notifyUpdates` for touched tables, `SyncEventBus.notifyLocalChange()`, and set `reverted_by_id` on the original.

- [ ] **Step 1: Write failing tests:**
  - `reverting a field restores it and logs a revert operation`.
  - `a revert stamps a fresh clock, never the logged one`.
  - `changed since is reported with all three values`.
  - `a child revert marks the child, not the parent` (this passes `test/architecture/child_write_restamps_test.dart`).
  - `a fact group column stamps its own clock`.
  - `a composite key record reverts`, `a settings key reverts`.
  - `a dropped column is blocked`, `a rewritten column is blocked`.
  - `a revert can be reverted`.
  - `a failure rolls back every field`.
  - `a revert waits for a running sync`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement** the service.
- [ ] **Step 4: Run** the file and `test/architecture/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): revert edits`.

### Task 12: Restore deletes and undo bulk actions

**Files:**
- Create: `lib/features/change_log/data/services/change_log_dependencies.dart`
- Modify: `lib/features/change_log/data/services/change_log_revert_service.dart`
- Test: `test/features/change_log/data/services/change_log_restore_test.dart`, `test/features/change_log/data/services/change_log_dependencies_test.dart`

**Interfaces:**
- Produces: `class ChangeLogDependencyIndex { static Future<ChangeLogDependencyIndex> load(AppDatabase db); Future<List<ChangeLogReference>> referencesTo(String table, String recordId); Future<List<String>> missingParents(String table, Map<String, Object?> row, Set<String> restoring); }`, built from `PRAGMA foreign_key_list`.

Rules:

- Restore: `INSERT` from the delete copy with only columns that still exist, `updated_at = now` on root rows, `removeDeletion`, `markRecordPending`. Pair junctions restore as rows. Use `PRAGMA defer_foreign_keys = ON` inside the transaction so order cannot fail, after `missingParents` has already blocked what cannot succeed.
- Removing a created record: `referencesTo` outside the operation's own records blocks it `inUse`, whether the foreign key is no-action or cascading. Created dives go through `DiveRepository.bulkDeleteDives`. Others use a delete plus `logDeletion`.
- Operation order: newest event first.
- A created record with a later event is `changedSince`.

- [ ] **Step 1: Write failing tests:**
  - `a deleted dive returns with tanks, gear and profile`.
  - `a restored root row revives on a peer` (updated_at is now and the tombstone is gone).
  - `a restored child with a missing parent is blocked`, `a record already back is blocked`.
  - `undoing an import removes its dives and reverses its edits`.
  - `an imported site used by a later dive is kept and listed` (no-action foreign key).
  - `imported gear on a later dive is kept and that dive is untouched` (cascading foreign key).
  - `an edited created record is reported as changed since`.
  - `includeChangedSince false skips those records`.
- [ ] **Step 2: Run** the files. Expected: compile failure.
- [ ] **Step 3: Implement** the index and restore.
- [ ] **Step 4: Run** the files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): restore deletes and undo bulk actions`.

### Task 13: Revert UI

**Files:**
- Create: `lib/features/change_log/presentation/widgets/change_log_revert_sheet.dart`
- Modify: `lib/features/change_log/presentation/pages/change_log_entry_page.dart`, `lib/features/change_log/presentation/widgets/change_log_entry_tile.dart`, ARB files
- Test: `test/features/change_log/presentation/change_log_revert_ui_test.dart`

Per-field Revert, Revert all, and Undo this import, following the mockup. The bulk dialog offers Revert the rest, Revert all and Cancel. The result lists kept records and each reason. A blocked item shows its reason in place of the button. Reverted entries show a badge.

- [ ] **Step 1: Write failing tests** `Revert all applies with no prompt when nothing changed since`, `the three-value warning shows when a value changed since`, `bulk undo offers the three choices`, `kept records are listed after a bulk undo`, `a blocked field explains why`, `a reverted entry shows its badge`.
- [ ] **Step 2: Run** the file. Expected: compile failure.
- [ ] **Step 3: Implement** the UI and ARB strings.
- [ ] **Step 4: Run** the file. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): add revert controls`.

### Task 14: Retention, clearing and storage

**Files:**
- Create: `lib/features/change_log/data/repositories/change_log_preferences.dart`, `lib/features/change_log/data/services/change_log_maintenance.dart`, `lib/features/change_log/presentation/pages/change_log_settings_page.dart`
- Modify: `lib/app.dart`, `lib/features/divers/data/repositories/diver_delete_steps.dart`, the app wipe path, `lib/features/settings/presentation/pages/storage_usage_page.dart` and its provider, ARB files
- Test: `test/features/change_log/data/services/change_log_maintenance_test.dart`, `test/features/change_log/presentation/change_log_settings_page_test.dart`

**Interfaces:**
- Produces: `class ChangeLogPreferences { int get retentionMonths; Future<void> setRetentionMonths(int months); }`, key `change_log_retention_months`, 0 meaning forever, default 12. `class ChangeLogMaintenance { Future<int> prune({int batch = 200}); Future<int> pruneIfDue(); }`, at most daily, key `change_log_last_pruned_at`.

Pruning deletes operations older than the cutoff with their events and fields in batches, yielding between them, from `app.dart` after startup, in the same place as the other post-start jobs. The menu on the feed opens the settings page and Clear log.

- [ ] **Step 1: Write failing tests** `twelve months is the default`, `older operations go with their fields`, `forever prunes nothing`, `pruneIfDue runs at most daily`, `pruning leaves unsettled events alone`, `deleting a diver deletes their entries`, `wiping the app clears the log`, `the retention picker saves`, `Clear log confirms first`, `Storage usage shows a Change log line`.
- [ ] **Step 2: Run** the files. Expected: compile failure.
- [ ] **Step 3: Implement** each part.
- [ ] **Step 4: Run** the files. Expected: PASS.
- [ ] **Step 5: Commit** `feat(change-log): add retention and clearing`.

### Task 15: End to end

**Files:**
- Create: `test/features/change_log/change_log_two_device_test.dart`, `docs/user/change-log.md`
- Modify: `docs/user/multi-device-sync.md`

- [ ] **Step 1: Write the tests** `a revert reaches the peer` for a root row, a clockless child, a pair junction and a fact-group column, and `a restored dive reaches the peer`, using the two-database setup of `test/core/services/sync/cross_version_roundtrip_test.dart`.
- [ ] **Step 2: Run** them. Expected: PASS, or fix the revert service until they do.
- [ ] **Step 3: Measure** opening a populated SQLCipher database with and without triggers on macOS, and record the numbers for the PR description.
- [ ] **Step 4: Write** the user docs: what is recorded, what is not, per-device behaviour and retention.
- [ ] **Step 5: Run** `dart format .`, `flutter analyze`, `test/architecture/`, `test/shared/`, `test/core/` and `test/features/change_log/`. Expected: no issues and all PASS.
- [ ] **Step 6: Commit** `feat(change-log): cover sync end to end and document the log`.
