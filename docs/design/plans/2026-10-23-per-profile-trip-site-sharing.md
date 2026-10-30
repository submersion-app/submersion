# Per-Profile Trip and Site Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The owner of a trip or dive site shares it with Everyone or with chosen profiles, from the item's page, the list selection or Settings; wording and user docs explain how sharing, ownership and hiding work (issue #2151).

**Architecture:** "Everyone" stays the existing `is_shared` flag; "chosen profiles" are rows in two new synced tables, `trip_shares` and `site_shares` (schema v309), shaped like `trip_hides`. `VisibilityFilter` (the one choke point for trip and site visibility, Drift and raw SQL) adds "or a share row names the viewer". A new `ItemSharesRepository` is the only non-sync writer of the share rows and enforces owner-only changes; one dialog, one detail-page row and one bulk action serve trips and sites alike.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), the app's HLC sync (`SyncDataSerializer` / `SyncService` / `SyncRepository`), gen-l10n ARB files in 11 locales.

**Spec:** `docs/design/specs/2026-10-23-per-profile-trip-site-sharing-design.md`. The wiring pattern for a per-profile child table of trips and sites is the one #2594 used for the hides; its plan, `docs/design/plans/2026-09-30-shared-trip-site-ownership.md` (Tasks 2 to 5), shows each touch point in full.

## Global Constraints

- Schema version becomes `309` (check `origin/main` before pushing; if another PR took 309, renumber everywhere the number appears: `database.dart`, the rung, the helper doc comments, the backstop comment, the migration test). `AppDatabase.minimumCompatibleSchemaVersion` does not change.
- Tables live in `lib/core/database/tables/` (`trip_tables.dart`, `site_tables.dart`), rung in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, helpers in `migrations/helpers/trip_migrations.dart` / `site_migrations.dart`, backstop in `migrations/before_open_table_backstops.dart`. Never a table or rung in `database.dart` itself.
- Sync entity names `tripShares` (table `trip_shares`) and `siteShares` (table `site_shares`). Drift data classes `@DataClassName('TripShareRow')` / `'SiteShareRow'`.
- A share row is never updated in place: a change of diver is delete + tombstone + insert under a new id (peers apply share rows insert-only, #2670).
- Removing an item's share rows when the item itself is deleted goes through `ItemSharesRepository.deleteShares` before the delete: a cascade writes no tombstone.
- Every new or changed ARB string in all 11 locales (ar, de, en, es, fr, he, hu, it, nl, pt, zh); plurals `one{...}` / `other{...}` with `{count}` inside the text.
- No em-dash, and no en-dash as prose punctuation, anywhere. No tool or model attribution anywhere.
- Files 200 to 400 lines typical, 800 max: new logic goes in new files; the big pages and repositories get call sites only.
- After each task: `dart format` on touched files, `flutter analyze` with zero issues, the task's tests. After adding files under `lib/`: `flutter test test/architecture test/shared`.
- Codegen: the Bash tool refuses a bare `build` token, so put `dart run build_runner build --delete-conflicting-outputs` in a scratchpad script and run it with `bash`.
- Commit per task with a conventional message ending `Refs #2151`, staging explicit paths.

## Review Focus

1. **Owner unticks the profile that is looking at the trip right now.** The trip leaves that profile's lists live, but its dive pages still open the trip by id without "Shared by" or "Remove from my profile". Test in Task 6 (`SharedByBanner` renders nothing once the share row is gone).
2. **A trip shared with the son and later shared with Everyone, then back to only the daughter.** Expected: Everyone clears the share rows, choosing the daughter writes only hers, the son loses sight of it, his hide (if any) stays. Test in Task 3 (`setSharing transitions`).
3. **Bulk share over a mixed selection** (own private, own Everyone, own shared with someone, another profile's). Expected: private and partially shared items gain the ticked profiles, Everyone items are untouched, another profile's item is skipped and counted. Test in Task 3 (`addSharing`).
4. **Parent profile deleted while a trip is shared with two children.** Expected: the child whose share is oldest owns it, the other child keeps a share row, both children's dives stay linked, no tombstone for the trip. Test in Task 5.
5. **Sync race leaves a trip with `is_shared = 1` and share rows.** Expected: treated as Everyone everywhere (the dialog opens on Everyone, the row says "Everyone"), and the next owner save clears the rows. Test in Task 3 (`sharingOf prefers Everyone`).

---

## File Structure

Create:
- `lib/core/data/visibility/item_sharing.dart`: `ItemSharing` value type.
- `lib/features/divers/data/repositories/item_shares_repository.dart`: `ItemSharesRepository`, `ItemShareResult`, `ItemShare` (a removed row, for undo).
- `lib/features/divers/presentation/providers/item_shares_providers.dart`: `itemSharesRepositoryProvider`, `itemSharingProvider`.
- `lib/shared/widgets/shared_items/share_target_dialog.dart`: `showShareTargetDialog`, `sharingSummary`.
- `lib/shared/widgets/shared_items/item_sharing_row.dart`: `ItemSharingRow` (detail pages) and `ItemSharingField` (edit pages).
- `lib/shared/widgets/shared_items/item_bulk_share.dart`: `shareItemsWithProfiles`.
- `lib/features/divers/data/repositories/diver_share_handover.dart`: `handOverSharedItems` (profile delete step).
- Tests per task.

Modify: `trip_tables.dart`, `site_tables.dart`, `database.dart`, `trip_migrations.dart`, `site_migrations.dart`, `rungs_v231_onward.dart`, `before_open_table_backstops.dart`, `sync_repository.dart`, `sync_data_serializer.dart`, `sync_service.dart`, `visibility_filter.dart`, `shared_item_policy.dart`, `profile_hides_repository.dart`, `name_index_loader.dart`, `trip_repository.dart`, `site_repository_impl.dart`, `diver_repository.dart`, `diver_delete_steps.dart`, `diver_merge_repository.dart`, `shared_by_banner.dart`, the trip and site detail and edit pages, both list contents, `settings_page.dart`, 11 ARB files, four `docs/user/` pages.

---

### Task 1: Schema v309, `trip_shares` and `site_shares`

**Files:**
- Modify: `lib/core/database/tables/trip_tables.dart`, `lib/core/database/tables/site_tables.dart`, `lib/core/database/database.dart` (table list, `currentSchemaVersion`, version history list), `migrations/helpers/trip_migrations.dart`, `migrations/helpers/site_migrations.dart`, `migrations/ladder/rungs_v231_onward.dart`, `migrations/before_open_table_backstops.dart`
- Test: `test/core/database/migration_v309_item_shares_test.dart` (model on `migration_v250_profile_hides_test.dart`)

**Interfaces:**
- Produces: Drift tables `TripShares` (`id`, `tripId` cascade, `diverId` cascade, `createdAt`, `hlc`, unique `{diverId, tripId}`), `SiteShares` (same with `siteId`), accessors `db.tripShares`, `db.siteShares`, row classes `TripShareRow`, `SiteShareRow`; helpers `_assertTripSharesSchema()`, `_assertSiteSharesSchema()`.

- [ ] **Step 1: Write the failing test**: `upgrading from 308 creates trip_shares and site_shares` (open a v308 fixture as the v250 test does; assert both tables exist with the five columns; inserting a duplicate `(diver_id, trip_id)` throws; deleting the trip deletes its share row), and `beforeOpen recreates a missing trip_shares` (drop the table, reopen, assert it is back).
- [ ] **Step 2: Run it**: `flutter test test/core/database/migration_v309_item_shares_test.dart`; expected FAIL (no such table).
- [ ] **Step 3: Implement** the two tables next to `TripHides` / `SiteHides`, list them in `database.dart`, bump `currentSchemaVersion` to 309, add the `309` entry with a comment to the version history (additive tables, floor unchanged), the rung `if (from < 309) { await _assertTripSharesSchema(); await _assertSiteSharesSchema(); }` plus `reportProgress`, and the backstop calls. Run codegen.
- [ ] **Step 4: Run it again**: same command; expected PASS. Also `flutter test test/core/database`.
- [ ] **Step 5: Commit** `feat(sharing): add trip_shares and site_shares tables (v309)`.

### Task 2: Sync the share rows as parent-gated children

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (entity map, beside `tripHides` at line ~219), `lib/core/services/sync/sync_data_serializer.dart` (every place `tripHides` / `siteHides` appears: payload fields, constructor, toJson, fromJson, table list ~1386, entity list ~1841, table-name map ~2071, export ~2729, fetch ~3404, apply record ~4739, ~5318, ~6767, ~7502, ~8006, ~8585, export helpers ~10402), `lib/core/services/sync/sync_service.dart` (~1822, ~2824, ~3262)
- Test: `test/core/services/sync/item_shares_sync_test.dart` (model on `profile_hides_sync_test.dart`); the existing guards `sync_parent_refs_completeness_test.dart`, `sync_data_serializer_batch_coverage_test.dart`, `sync_serializer_fetch_record_test.dart` must pass with the new entities listed.

**Interfaces:**
- Consumes: Task 1 tables.
- Produces: entity types `tripShares`, `siteShares`, exported and applied like the hides (insert-only, `DoNothing` on conflict, parent-gated, `hasUpdatedAt: false`). `siteShares` is not in `librarySiteChildEntities`.

- [ ] **Step 1: Write the failing tests**: `a trip share round-trips through export and apply`, `a site share whose site is missing is held back by the parent gate`, `a deleted share's tombstone removes it on the peer`.
- [ ] **Step 2: Run them**: `flutter test test/core/services/sync/item_shares_sync_test.dart`; expected FAIL.
- [ ] **Step 3: Implement** by mirroring each `tripHides` / `siteHides` occurrence listed above with `tripShares` / `siteShares`.
- [ ] **Step 4: Run** the new test and `flutter test test/core/services/sync`; expected PASS.
- [ ] **Step 5: Commit** `feat(sync): sync trip and site shares`.

### Task 3: `ItemSharing` and `ItemSharesRepository`

**Files:**
- Create: `lib/core/data/visibility/item_sharing.dart`, `lib/features/divers/data/repositories/item_shares_repository.dart`, `lib/features/divers/presentation/providers/item_shares_providers.dart`
- Test: `test/core/data/visibility/item_sharing_test.dart`, `test/features/divers/data/repositories/item_shares_repository_test.dart`

**Interfaces:**
- Produces:
  - `class ItemSharing { const ItemSharing({this.everyone = false, this.profileIds = const {}}); static const none; final bool everyone; final Set<String> profileIds; bool get isShared; bool reaches(String diverId); bool narrows(ItemSharing next); ItemSharing without(String? diverId); }`. `everyone` wins: an `ItemSharing(everyone: true, profileIds: {...})` compares equal to `ItemSharing(everyone: true)`. `narrows(next)` is true when some profile reached by `this` is not reached by `next` (Everyone to anything less, or a removed id).
  - `class ItemShareResult { final int itemsChanged; final int skippedNotOwned; }`
  - `typedef ItemShare = ({String id, String itemId, String diverId, int createdAt});`
  - `ItemSharesRepository`:
    - `Stream<void> watchChanges()` (trip_shares, site_shares, trips, dive_sites)
    - `Future<ItemSharing> sharingOf(SharedItemKind kind, String id)`
    - `Future<Map<String, ItemSharing>> sharingOfAll(SharedItemKind kind, List<String> ids)`
    - `Future<bool> setSharing(SharedItemKind kind, String id, ItemSharing sharing, {required String? actingDiverId})`: false, writing nothing, when the item is missing or `canDestroySharedItem` refuses; otherwise writes `is_shared = sharing.everyone` (stamp `updated_at`, mark the parent pending only if the flag changed), deletes and tombstones rows no longer wanted (all of them for Everyone), inserts missing ones; ids equal to the owner are dropped.
    - `Future<ItemShareResult> addSharing(SharedItemKind kind, List<String> ids, ItemSharing add, {required String actingDiverId})`: add-only, per the spec's bulk rule.
    - `Future<List<ItemShare>> deleteShares(SharedItemKind kind, List<String> ids, {String? diverId})`: inside the caller's transaction, tombstones, returns the rows.
    - `Future<void> restoreShares(SharedItemKind kind, List<ItemShare> shares)`: re-inserts with their ids and clears their tombstones (as `ProfileHidesRepository.restoreHides`).
  - Providers: `itemSharesRepositoryProvider` (`// no-tick:` comment as the guard requires for a service provider), `itemSharingProvider = FutureProvider.family<ItemSharing, (SharedItemKind, String)>` invalidated by `watchChanges()`.

- [ ] **Step 1: Write the failing tests**:
  - `item_sharing_test.dart`: `everyone wins over profile ids`, `narrows is true for Everyone to a profile and for a removed id, false for an added id`, `without drops the owner`.
  - repository: `setSharing by a non-owner writes nothing and returns false`; `setSharing transitions` (none to {son}: one row, flag 0; {son} to Everyone: flag 1, son's row deleted and tombstoned; Everyone to {daughter}: flag 0, one row; {daughter} to none: no rows, flag 0); `setSharing keeps a profile's hide when it is unticked`; `setSharing drops the owner's own id`; `sharingOf prefers Everyone` (flag 1 plus a stale row reads as Everyone); `addSharing` over the Review Focus 3 selection: `itemsChanged == 2`, `skippedNotOwned == 1`, the Everyone item has no new row; `addSharing with nobody changes nothing`; `deleteShares then restoreShares round-trips ids and clears tombstones`.
- [ ] **Step 2: Run them**; expected FAIL.
- [ ] **Step 3: Implement**, following `ProfileHidesRepository` for raw-SQL writes, `markRecordPending` / `logDeletions`, and `SyncEventBus.notifyLocalChange()` after a committed change.
- [ ] **Step 4: Run them**; expected PASS.
- [ ] **Step 5: Commit** `feat(sharing): item shares repository`.

### Task 4: Visibility follows share rows

**Files:**
- Modify: `lib/core/data/visibility/visibility_filter.dart` (`applyToTrips`, `applyToDiveSites`, `ownerOrSharedSql`, `ownerOrSharedOrLibrarySql`, `sqlFragment` variables), `lib/core/data/visibility/shared_item_policy.dart` (doc of `canHideSharedItem.isShared`: "shared with the active profile, with Everyone or by a share row"), `lib/features/divers/data/repositories/profile_hides_repository.dart` (`hideAll` reads `is_shared OR EXISTS (share row for diverId)`), `lib/features/query/data/name_index_loader.dart` (watched tables list and the inline predicates at ~97-101, ~158, ~167), `lib/features/trips/data/repositories/trip_repository.dart` and `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (`watch...Changes` also on the share tables), `trip_list_content.dart` and `site_list_content.dart` (`splitForBulkDelete(isSharedOf: (_) => true)` with a comment: a listed item another profile owns reaches this one only by sharing)
- Test: extend `test/core/data/visibility/visibility_filter_test.dart`, `test/features/divers/data/repositories/profile_hides_repository_test.dart`, `test/features/query/data/name_index_loader_test.dart`

**Interfaces:**
- Consumes: Task 1 tables, Task 3 repository for seeding.
- Produces: `ownerOrSharedSql(alias, viewer)` = `(alias.diver_id = V OR alias.is_shared = 1 OR alias.id IN (SELECT trip_id FROM trip_shares WHERE diver_id = V))`; `ownerOrSharedOrLibrarySql` gains the `site_shares` clause. `sqlFragment` supplies one variable per `?`.

- [ ] **Step 1: Write the failing tests**: `a trip shared with the son is listed for the son and not the daughter` (Drift and `sqlFragment` paths); same for a site; `the son can hide a trip shared with him`; `hiddenItems lists a hidden trip shared with the profile specifically`; `the name index includes a site shared with the profile`; `watchTripsChanges emits on a trip_shares write`.
- [ ] **Step 2: Run them**; expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them plus `flutter test test/features/trips test/features/dive_sites test/features/query test/core/data`; expected PASS.
- [ ] **Step 5: Commit** `feat(sharing): lists show items shared with the profile`.

### Task 5: Deletes, profile delete, profile merge and site merge keep shares right

**Files:**
- Create: `lib/features/divers/data/repositories/diver_share_handover.dart`
- Modify: `trip_repository.dart` and `site_repository_impl.dart` (every owner delete path that calls `deleteHides` first also calls `deleteShares`; site bulk delete's undo snapshot also restores shares), `diver_repository.dart` (`deleteDiverWithReassignment` step 0 calls `handOverSharedItems`, counts the handed-over items in `reassignedTrips` / `reassignedSites`, and removes the heir's own share rows of the Everyone items it receives), `diver_delete_steps.dart` (tombstone the deleted profile's `trip_shares` / `site_shares` rows beside its hides), `diver_merge_repository.dart` (generalise `_dropCollidingShares` / `_recreateDuplicateShares` over `equipment_shares`, `trip_shares`, `site_shares` with each table's item table and column; exclude all three from the generic repoint; snapshot and undo cover them), `site_repository_impl.dart` `mergeSites` / `undoMerge` (carry duplicates' share rows onto the survivor unless it is Everyone, as new rows; `MergeSnapshot` gains `deletedShares` and `createdShareIds`)
- Test: `test/features/divers/data/repositories/diver_share_handover_test.dart`, extend `diver_merge_repository` tests, `trip_ownership_test.dart`, a site merge test beside the existing ones

**Interfaces:**
- Consumes: Task 3 `deleteShares`, `restoreShares`.
- Produces: `Future<({List<String> tripIds, List<String> siteIds})> handOverSharedItems(AppDatabase db, SyncRepository sync, {required String fromDiverId, required int now})`: for every item `fromDiverId` owns with `is_shared = 0` and share rows, the heir is the share row with the smallest `(created_at, id)`; delete and tombstone that row, set `diver_id` to the heir, stamp and mark the item pending, delete the heir's hides of it.

- [ ] **Step 1: Write the failing tests**: Review Focus 4 (`a trip shared with two children goes to the earlier share and the other child keeps access`); `the heir of an Everyone trip loses its stale share row`; `a private trip with no shares is still deleted`; `deleting a profile tombstones its share rows`; `merging two profiles turns the duplicate's trip share into the keeper's and drops a share of the keeper's own trip`, and its undo; `deleting a shared trip tombstones its share rows`; `site bulk delete undo restores share rows`; `merging sites carries a duplicate's share onto the survivor` and `does not add rows to an Everyone survivor`, and undo restores both.
- [ ] **Step 2: Run them**; expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them plus `flutter test test/features/divers test/features/trips test/features/dive_sites`; expected PASS.
- [ ] **Step 5: Commit** `feat(sharing): keep trip and site shares through deletes and merges`.

### Task 6: Strings, the share dialog and the detail-page row

**Files:**
- Create: `lib/shared/widgets/shared_items/share_target_dialog.dart`, `lib/shared/widgets/shared_items/item_sharing_row.dart` (`ItemSharingRow` only in this task)
- Modify: 11 ARB files; `shared_by_banner.dart` (watch `itemSharingProvider` and show only when the active profile is reached, replacing the `isShared` parameter), `trip_detail_page.dart` and `site_detail_page.dart` (place `ItemSharingRow` under the banner; the delete dialog's "shared delete" test uses `sharingOf(...).isShared`)
- Test: `test/shared/widgets/shared_items/share_target_dialog_test.dart`, `item_sharing_row_test.dart`, extend `shared_by_banner` test

**Interfaces:**
- Produces:
  - `Future<ItemSharing?> showShareTargetDialog(BuildContext context, {required String title, required String body, required List<Diver> profiles, required ItemSharing initial, required String confirmLabel, bool allowEmpty = true})`: an Everyone tile, then one checkbox per profile (reuse `ProfileAvatar` as `profile_checklist_dialog.dart` does); ticking Everyone clears the boxes, ticking a box clears Everyone.
  - `String sharingSummary(ItemSharing sharing, Map<String, String> namesById, AppLocalizations l10n)`: "Not shared", "Everyone", or the names joined with ", ".
  - `ItemSharingRow({required SharedItemKind kind, required String itemId, required String? ownerId, bool isLibrarySite = false})`: nothing unless two or more profiles, a known active profile, the active profile is the owner, not a library site, and the sharing is loaded. Taps open the dialog; a narrowing choice shows the kind's unshare confirmation first; then `setSharing`; a failure shows `common_error_tryAgain`.
- New strings (keys and English): `sharedItems_sharedWith_label` "Shared with", `sharedItems_sharedWith_none` "Not shared", `sharedItems_sharedWith_everyone` "Everyone", `sharedItems_shareDialog_title` "Share with", `sharedItems_shareDialog_everyoneSubtitle` "Every dive profile, including ones added later", `sharedItems_shareDialog_tripBody` "Profiles you choose see this trip and can add their own dives to it. Only you can delete it or change who it is shared with.", `sharedItems_shareDialog_siteBody` "Profiles you choose see this site and can log their own dives at it. Only you can delete it or change who it is shared with.". Changed: `trips_unshareConfirm_body` / `sites_unshareConfirm_body` "Profiles you take off will no longer see '{name}'. Their dives stay linked to it, and you can share it with them again later.".

- [ ] **Step 1: Write the failing tests**: dialog `ticking Everyone clears the profiles`, `ticking a profile clears Everyone`, `cancel returns null`; row `owner sees Not shared and a chevron`, `non-owner sees nothing`, `choosing the son calls setSharing with {son}`, `taking the son off asks to confirm first`; banner `shows for a profile reached by a share row`, `renders nothing once the share row is gone` (Review Focus 1).
- [ ] **Step 2: Run them**; expected FAIL.
- [ ] **Step 3: Implement**, strings in all 11 locales.
- [ ] **Step 4: Run** them plus `flutter test test/shared test/features/trips/presentation test/features/dive_sites/presentation`; expected PASS.
- [ ] **Step 5: Commit** `feat(sharing): share a trip or site with chosen profiles from its page`.

### Task 7: Edit pages choose sharing with the same picker

**Files:**
- Modify: `item_sharing_row.dart` (add `ItemSharingField`), `trip_edit_page.dart` (replace the "Share with all dive profiles" switch and `_isShared` with an `ItemSharing _sharing`; new trip starts at Everyone when "Share new sites and trips by default" is on, else none; an existing trip loads `sharingOf` before the field is enabled; the save writes `isShared: _sharing.everyone`, then calls `setSharing` when the owner changed it), `site_edit_page.dart` and the section widget it passes `isShared` / `shareLocked` to (same change)
- Test: extend the trip and site edit page tests

**Interfaces:**
- Produces: `ItemSharingField({required SharedItemKind kind, required ItemSharing value, required ValueChanged<ItemSharing> onChanged, required bool locked, ItemSharing? original, String? itemName})`: shows "Shared with" and `sharingSummary`; opens `showShareTargetDialog`; confirms with the unshare dialog when the pick narrows `original`.

- [ ] **Step 1: Write the failing tests**: `a new trip shared with the son saves one share row`, `a non-owner sees the field locked`, `saving without touching the field writes no share change`, the site equivalents.
- [ ] **Step 2: Run them**; expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them; expected PASS.
- [ ] **Step 5: Commit** `feat(sharing): edit pages pick who a trip or site is shared with`.

### Task 8: Bulk share from the lists and from Settings

**Files:**
- Create: `lib/shared/widgets/shared_items/item_bulk_share.dart`
- Modify: `trip_list_content.dart` (the empty `actions` list gets a `share` `BulkAction`, enabled when every checked trip is the active profile's own, shown with two or more profiles), `site_list_content.dart` `_bulkActions` (same, not for library sites), `settings_page.dart` (`_confirmAndBulkShareTrips` / `_confirmAndBulkShareSites` call `shareItemsWithProfiles` with every id the profile owns and the share-all body; keep the "Nothing to share." path for no owned items), 11 ARB files
- Test: `test/shared/widgets/shared_items/item_bulk_share_test.dart`, extend the settings shared-data test

**Interfaces:**
- Produces: `Future<BulkActionOutcome> shareItemsWithProfiles(BuildContext context, WidgetRef ref, {required SharedItemKind kind, required List<String> ids, required String? activeDiverId, String? body})`: dialog with `initial: ItemSharing.none`, `allowEmpty: false`, confirm label `common_action_share`; then `addSharing`; snackbar with the result.
- Strings: new `sharedItems_bulkShare_action` "Share with...", `sharedItems_bulkShare_done` "{count, plural, one{Shared {count} item} other{Shared {count} items}}", `sharedItems_bulkShare_doneSkipped` "{count, plural, one{Shared {count} item} other{Shared {count} items}}, skipped {skipped} you do not own". Changed: `settings_shareAllTrips_title` "Share all my trips...", `settings_shareAllSites_title` "Share all my sites...", `settings_shareAllTrips_confirm` "Choose who sees all {count} of your trips. To change one trip later, open it and tap Shared with.", `settings_shareAllSites_confirm` the same for sites.

- [ ] **Step 1: Write the failing tests**: `bulk share adds the son to each owned trip and reports skipped ones`, `cancel changes nothing`, `Settings share all opens the picker with the share-all text`.
- [ ] **Step 2: Run them**; expected FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** them plus `flutter test test/features/settings test/architecture test/shared`; expected PASS.
- [ ] **Step 5: Commit** `feat(sharing): share many trips or sites at once`.

### Task 9: User docs

**Files:**
- Modify: `docs/user/trips.md`, `docs/user/dive-sites.md`, `docs/user/diver-profile.md`, `docs/user/settings.md`

- [ ] **Step 1: Write** per the spec's "User docs" section: Everyone or chosen profiles; who owns a shared item and what others may do; "Remove from my profile" and Settings > Shared data > Hidden from this profile; how to stop sharing (open it, tap Shared with); the family example in `diver-profile.md`; the "Share all..." pickers in `settings.md`.
- [ ] **Step 2: Verify**: `python3.14 scripts/check_docs_links.py` passes; no U+2014 character in any of the four files (`grep -c $'\xe2\x80\x94'` prints 0).
- [ ] **Step 3: Commit** `docs(user): explain sharing trips and sites with chosen profiles`.

### Task 10: Whole-branch verification

- [ ] `dart format .` leaves no change; `flutter analyze` reports no issues.
- [ ] `flutter test test/architecture test/shared test/core test/features/trips test/features/dive_sites test/features/divers test/features/settings test/features/query`; all pass.
- [ ] Re-check the schema number against `origin/main` (Global Constraints).
