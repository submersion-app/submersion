# Settings > Data, PR 4: Photos & videos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One Photos & videos page replaces the Photos & Media hub and the Media Storage page.
- Copies in the cloud are set up by choosing an account in the shared account sheet, which replaces Media Storage's own provider chooser and forms.
- A status line says what is true: copied of total, uploading, waiting, paused, or not reachable.
- The store records which account it lives on, so a second device that already holds that account joins with nothing to type.
- Rarely used controls move to an Advanced section, and nothing is lost.

**Architecture:**
- A new nullable synced column, `media_stores.account_id`, records the roster row the attached store lives on. It is written on attach, and null means a store from before this change.
- `MediaStoreService` gains one entry point, `attachThroughAccount(AccountGroup group)`. It turns an account into today's per-kind connect call:
  - S3 and WebDAV use `AccountGroupService.ensureRole(group, AccountRole.media)` to reach the account's media-folder row, then today's `connectS3` / `connectWebDav` with that row's stored config.
  - Dropbox, Google Drive and iCloud use today's managed connects.
- The marker checks, the store marker and the transfer preflight are untouched. Choosing the account a store already lives on finds that store's marker and joins it, which is what makes the second device's attach need no typing.
- The page is assembled from small widgets. The Media Storage page, its WebDAV form and the hub page are deleted.

**Tech Stack:** Flutter, Riverpod 3, Drift (tables in `lib/core/database/tables/`, rungs in `lib/core/database/migrations/`), the phase 2 account model (`AccountGroup`, `showAccountSheet`, `AccountGroupService.ensureRole`), go_router, gen-l10n with 11 ARB files, `flutter_test`.

**Spec:** `docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md`. Sections 3, 4, 7.1-7.4, 8.3, 9, 10, 11 (phase 4) and 12, plus the appendix rows for Photos & Media, Media Storage and Hub. Phases 1-3 shipped as #3485, #3500, #3527 and #3541.

## Global Constraints

- **One migration rung, schema 301 to 302.** It adds one nullable column and runs no backfill. `minimumCompatibleSchemaVersion` stays 300.
- **A stored account id is never erased by an older peer.** An incoming null `accountId` from a peer that predates the column means "unset", and never erases a value this device holds (`_nullMeansUnsetKeys`, as `connected_accounts.location` does).
- **The store model is unchanged.** The marker checks, store marker, preflight, attach generation and transfer queue all behave as today. Nothing deletes bucket contents. "Stop keeping copies on this device" is today's Disconnect.
- **The sheet offers today's photo kinds:** iCloud, Google Drive, Dropbox, S3 and WebDAV, gated exactly as the sheet already gates them. It never offers Git (never a media store) or Lightroom.
- **Words follow the vocabulary in spec section 4.** The device word is "device", as phases 1-3 shipped it.
- **Strings go in all eleven ARB files.** Arabic plurals give the one, two, few, many and other forms (`test/l10n/arabic_plural_categories_test.dart`). A string whose meaning changes gets a new key, and old keys are deleted once nothing reads them.
- **Files stay under 800 lines.** No new file goes over 400.
- **No em dashes, and no tool names or attribution.** Every commit and the PR say `Refs #3482`.
- **Tests restore any global state they replace.** After adding files under `lib/`, run `test/architecture` and `test/shared`. After the migration, run `test/core/database` and `test/core/services/sync`.

## Rulings and deferrals

These are calls the plan makes where the spec leaves a choice or the code forces one. Each is cheap to reverse.

1. **The guided setup icon stays until phase 6.** Spec 8.3 removes the toolbar checklist, but its replacement (the Set up this phone card) arrives in phase 6. Removing it now would leave the checklist unreachable for one release. The pending setup card also stays.
2. **"Set up" on a Not set up Using row opens the account sheet.** The spec says it opens step 4, which is phase 6.
3. **Automatic color correction** (#3520, which merged after the spec) goes in Advanced, next to "Show source badges on thumbnails". Both are display preferences.
4. **Copied of total** counts with the same rule as "Upload everything already attached" (`getBackfillCandidateIds`), shared, so the count and the backfill cannot disagree on what is eligible.
5. **Choosing the account the copies already use** does nothing. Choosing another account first shows the consequence inside the sheet (new string `settings_photos_switchConsequence`), then detaches and attaches.
6. **Old routes redirect.** `/settings/media-storage` goes to `/settings/photos-media`, and `/settings/media-storage/transfers` goes to `/settings/photos-media/uploads`. Pending setup items, the data health route match, the gauge chip and the desktop pane all move to the new paths.
7. **A store row with no account id** shows its display hint on the Using row, exactly as today. Choosing its server in the sheet joins it through the marker.

## Review Focus

These are inputs the spec implies that no task's tests would otherwise exercise. Each test is added to the task that owns the code.

1. **A second device that holds the account.** The library announces a store with an account id, and this device is signed in to that account. Choosing it in the sheet attaches to the announced store (same store id, `createdNewStore` false) with no form shown (Task 2).
2. **An S3 account whose media folder has no row yet.** Choosing it creates the `submersion-media/` row through `ensureRole`, attaches there, and records that row's id as the store's account (Task 2).
3. **Changing the photo account while uploads are queued.** The old store detaches before the new one attaches, and the queue pauses on the preflight's detached check, as today. The new store then takes over; it is never a silent mix of two stores (Task 2).
4. **A store announced by another device that this device cannot reach** (no keys here). The status line says "Finish setting up this device", and Set up opens the sheet with that account offered to sign in (Task 4).
5. **A peer that predates the column sends `accountId: null`.** It never erases the account id this device holds (Task 1).

---

### Task 1: The store's account

**Files:**
- Modify:
  - `lib/core/database/tables/media_tables.dart` (`MediaStores.accountId`)
  - `lib/core/database/database.dart` (version 302 and the `migrationVersions` entry)
  - `lib/core/database/migrations/ladder/rungs_v231_onward.dart`
  - `lib/core/database/migrations/helpers/media_migrations.dart` (a new `_assertMediaStoresAccountColumn` with `_addColumnIfMissing`)
  - `lib/core/database/migrations/before_open.dart` (the backstop call), or its part file if it is at its line guard
  - `lib/core/services/sync/sync_data_serializer.dart` (`_nullMeansUnsetKeys` gains `'mediaStores': {'accountId'}`)
  - `lib/features/media_store/data/media_stores_repository.dart` (`upsertActive` takes `String? accountId`, and `MediaStoreDescriptor` gains `accountId`)
- Test:
  - `test/core/database/migration_v302_media_store_account_test.dart`
  - `test/core/services/sync/sync_media_store_account_test.dart`
  - `test/features/media_store/data/media_stores_repository_test.dart` (extend)

**Interfaces:**
- Produces:
  - `MediaStoreDescriptor.accountId` (`String?`).
  - `upsertActive({required storeId, required providerType, required displayHint, String? accountId})`. A null `accountId` keeps a stored one, so a reattach through a path that does not know the account never clears it.

- [ ] **Step 1: Write the failing tests.**
  - `'a database at 301 gains media_stores.account_id'`: a PRAGMA check on a database stranded at the old version, as the v293 test does.
  - `'migrationVersions lists 302'`.
  - `'an incoming null accountId keeps the local one'`.
  - `'an incoming accountId is applied'`.
  - `'upsertActive records the account and a later null keeps it'`.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.** Then run `dart run build_runner build --delete-conflicting-outputs`, via a scratchpad script.
- [ ] **Step 4: Run the tests, then the suites.** The new tests, then `test/core/database`, `test/core/services/sync` and `test/features/media_store`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): media stores record the account they live on`.

### Task 2: Attach through an account

**Files:**
- Modify:
  - `lib/features/media_store/data/media_store_service.dart`. Every connect passes the account row's id to `upsertActive`, `connectWebDav` gains `{String? accountId}` as `connectS3` has it, and the new method goes in a new part file, `media_store_account_attach.dart`, to keep the service under its current size.
- Create:
  - `lib/features/media_store/data/media_store_account_attach.dart`
- Test:
  - `test/features/media_store/data/media_store_account_attach_test.dart`

**Interfaces:**
- Consumes: `AccountGroupService.ensureRole(group, AccountRole.media)`, today's `connectS3` / `connectWebDav` / `connectDropbox` / `connectGoogleDrive` / `connectICloud`, and `disconnect()`.
- Produces:
  - `Future<MediaStoreConnectResult> attachThroughAccount(AccountGroup group, {required AccountGroupService accounts})`.
    - S3: `ensureRole(group, media)`, then the row's stored `S3Config` (`AccountGroupService.storedS3ForRow`), then `connectS3(config, accountId: row.id)`.
    - WebDAV: the same, through `connectWebDav(config, accountId: row.id)`.
    - Dropbox, Google Drive and iCloud: the managed connect. Its `ensure` already lands on the kind's one row.
    - Throws `MediaStoreException(kind: auth)` when the account holds no usable keys here.
  - `Future<MediaStoreConnectResult> switchToAccount(AccountGroup group, {...})`: `disconnect()`, then `attachThroughAccount`. When the attach fails, the old store stays detached and the error propagates, so the page can say so. It never reattaches the old store silently.

- [ ] **Step 1: Write the failing tests.**
  - One per kind: S3 creates the media row through `ensureRole` and attaches with its id (Review Focus 2); WebDAV the same; each managed kind goes through its managed connect.
  - `'choosing the account the announced store lives on joins that store'`: a fake object store whose marker holds the announced id. Expect `createdNewStore` false and the same store id (Review Focus 1).
  - `'the store row records the account'`.
  - `'switching detaches before it attaches, and a failed attach leaves the old store detached'` (Review Focus 3).
  - `'an account with no keys here throws auth'`.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests and `test/features/media_store`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): attach photo copies through an account`.

### Task 3: Copied of total

**Files:**
- Modify: `lib/features/media/data/repositories/media_repository.dart`. Extract the backfill eligibility expression into `_uploadEligible(...)`, used by `getBackfillCandidateIds` and the new count.
- Create: `lib/features/media_store/presentation/providers/media_upload_progress_provider.dart`
- Test: `test/features/media/data/repositories/media_upload_progress_test.dart`

**Interfaces:**
- Produces:
  - `Future<({int copied, int total})> countUploadProgress()`.
    - `total` counts every row the backfill rule would ever upload: linked to the logbook, this device's own or untagged, and an uploadable source or kind.
    - `copied` counts those with the stamp that completes them: original or compressed for photos, original for videos.
  - `mediaUploadProgressProvider`: `FutureProvider.autoDispose`, refreshed on media changes and on transfer summary changes.

- [ ] **Step 1: Write the failing tests.**
  - A seeded library of a copied photo, an uncopied photo, a compressed-only photo, a copied local video, a connector video (thumb-only, excluded), another device's photo (excluded) and an orphan (excluded). Expect `(copied: 3, total: 5)`.
  - `'backfill candidates are exactly total minus copied'`, which pins the shared rule.
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests and the existing backfill tests.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): count copied photos with the backfill rule`.

### Task 4: The status line model

**Files:**
- Create: `lib/features/media_store/domain/photos_status.dart` (pure)
- Test: `test/features/media_store/domain/photos_status_test.dart`

**Interfaces:**
- Produces `PhotosStatus photosStatus({...})`. Its inputs are `attached`, `announced`, `pendingSetup` (an attach or reconnect item for the store), `reachable` (`bool?`, null while checking), `progress` and `summary` (`MediaTransferSummary?`). It returns a sealed `PhotosStatus`, checked in this order:

  | Case | When |
  | --- | --- |
  | `PhotosNotSetUp` | nothing attached or announced |
  | `PhotosFinishSettingUp` | announced and not attached here, or a pending item |
  | `PhotosChecking` | reachability is null |
  | `PhotosUnreachable(accountLabel)` | attached and the runtime could not open the store |
  | `PhotosPaused(reason)` | the summary holds a `MediaTransferHoldKind` other than offline |
  | `PhotosWaitingConnection` | held offline |
  | `PhotosWaitingRetry(n)` | the summary's waiting count |
  | `PhotosUploading(copied, total, n)` | the summary has transfers or queue entries |
  | `PhotosAllCopied(copied, total)` | otherwise |

- [ ] **Step 1: Write the failing tests.** One per row, plus precedence: paused beats uploading, and finish setting up beats everything once announced (Review Focus 4).
- [ ] **Step 2: Run the tests.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): one status for photo copies`.

### Task 5: The Photos & videos page

**Files:**
- Create, under `lib/features/media_store/presentation/`:
  - `pages/photos_videos_page.dart` (layout only)
  - `widgets/photos_using_row.dart` (Using row, Change or Set up, and the sheet)
  - `widgets/photos_status_line.dart` (renders `PhotosStatus`)
  - `widgets/photos_upload_settings.dart` (Upload new photos automatically, Use cellular data, Uploads)
  - `widgets/photos_advanced_section.dart`:
    - Upload quality, with today's hints and save
    - Upload everything already attached
    - Verify the copies, with today's result texts
    - Network sources
    - Show source badges on thumbnails
    - Automatic color correction
    - Cache, via today's `MediaCacheSettingsCard`
    - Export media report
    - Stop keeping copies on this device, with today's confirmation reworded
- Modify:
  - `lib/core/router/app_router.dart` (the redirects in Ruling 6, the new `uploads` child, and `network-sources` stays under `media-sources`)
  - `data_settings_pane.dart` (`dataPanePage`)
  - `pending_setup_service.dart` (routes)
  - `data_health_providers.dart` (`countMediaSetupItems` route match)
  - `gauge_strip.dart` and `media_transfer_summary_row.dart` (the Uploads route)
  - `transfers_page.dart` (title "Uploads")
  - the info panel strings in Task 6
- Delete:
  - `lib/features/media_store/presentation/pages/media_storage_page.dart`
  - `lib/features/media_store/presentation/widgets/webdav_media_form.dart`
  - `lib/features/settings/presentation/pages/photos_media_hub_page.dart`
  - their tests, ported first
- Modify: the 11 ARB files and the generated l10n.
- Test:
  - `test/features/media_store/presentation/pages/photos_videos_page_test.dart`
  - `photos_using_row_test.dart`, `photos_status_line_test.dart`, `photos_advanced_section_test.dart`
  - the ported Media Storage and hub tests (quality save, backfill, verify, export, disconnect, policies, transfers entry), with the same assertions

**Interfaces:**
- Consumes: Tasks 1-4, `showAccountSheet` (`allowedKinds: {icloud, googledrive, dropbox, s3, webdav}`, `consequenceOf`), `PendingSetupCard`, the hold notice strings, and today's policy, quality and verify providers.
- **Order, top to bottom:**
  1. The pending setup card
  2. "Copies in the cloud": the Using row, then the status line
  3. Upload new photos automatically
  4. Use cellular data
  5. Uploads
  6. "Where photos come from": Photo library and files
  7. Advanced
  8. The guided setup icon in the app bar (Ruling 1)
- **The Using row:**
  - It reads "Copies in {account}", or the store's display hint for a store with no account id. Change opens the sheet with the current account's group selected.
  - With nothing set up it reads "Not set up", with Set up.
  - Choosing a different account shows the consequence first, then runs `switchToAccount`, or `attachThroughAccount` when nothing was attached.
- **New strings** (11 locales):
  - Headers and rows:
    - `settings_photos_cloudHeader` "Copies in the cloud"
    - `settings_photos_copiesIn` "Copies in {account}"
    - `settings_photos_autoUpload` "Upload new photos automatically"
    - `settings_photos_cellular` "Use cellular data"
    - `settings_photos_uploads` "Uploads"
    - `settings_photos_sourcesHeader` "Where photos come from"
    - `settings_photos_library` "Photo library and files"
  - Advanced:
    - `settings_photos_quality` "Upload quality"
    - `settings_photos_uploadAll` "Upload everything already attached"
    - `settings_photos_verify` "Verify the copies"
    - `settings_photos_stopKeeping` "Stop keeping copies on this device"
    - `settings_photos_stopKeepingBody` "This device stops uploading and fetching copies. Nothing in the account is deleted."
  - The sheet: `settings_photos_switchConsequence` "This device stops using the copies in {current} and starts or joins copies in {choice}. Nothing is deleted."
  - Status (plurals with Arabic forms):
    - `settings_photos_status_copied` "{copied} of {total} copied"
    - `settings_photos_status_uploading` "{copied} of {total} copied, {count} uploading"
    - `settings_photos_status_waitingConnection` "Waiting for a connection"
    - `settings_photos_status_waitingRetry` "{count} waiting to retry"
    - `settings_photos_status_paused` "Uploads paused: {reason}"
    - `settings_photos_status_finishSetup` "Finish setting up this device"
    - `settings_photos_status_unreachable` "Could not reach {account}"
- **Deleted keys** once nothing reads them: the Media Storage page's provider chooser, form, connect and status strings, and the hub's section and entry strings. Before deleting, check every key against `lib` and `test`.

- [ ] **Step 1: Before screenshots** of the hub and Media Storage (light, dark, phone, desktop), where the harness can launch the app. Otherwise list them for the maintainer, as in phases 2 and 3.
- [ ] **Step 2: Port today's Media Storage and hub tests to the new widgets, and write the new ones.**
  - The order test.
  - One Using-row test per state.
  - `'choosing the account in use changes nothing'`.
  - `'choosing another account explains, then switches'`.
  - `'Set up attaches through the chosen account'`.
  - `'an announced store not attached here reads Finish setting up'`.
  - `'Stop keeping copies asks first and detaches'`.
  - `'the old media-storage route lands on Photos & videos'`.
- [ ] **Step 3: Run the tests.** Expected: FAIL.
- [ ] **Step 4: Implement.** Add the strings, run `flutter gen-l10n`, and delete the old pages last.
- [ ] **Step 5: Run the checks.** `dart format .`, `flutter analyze`, then `test/features/media_store`, `test/features/media`, `test/features/settings`, `test/architecture`, `test/shared` and `test/l10n`. Expected: PASS.
- [ ] **Step 6: After screenshots.**
- [ ] **Step 7: Commit** `feat(media): one Photos & videos page`.

### Task 6: The info panel's copies section

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_info_panel.dart` (`_BackupSection`, `_BackUpButton`), and the ARB files.
- Test: the existing info panel test file (extend)

**Interfaces:**
- New keys:
  - `media_info_copiesSection` "Copies in the cloud", replacing `media_info_backupSection`
  - `media_info_actionCopyNow` "Copy now", replacing `media_info_actionBackUpNow`
- The re-upload menu is unchanged.

- [ ] **Step 1: Write the failing test** `'the panel's copies section uses the new words'`.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement,** and delete the replaced keys.
- [ ] **Step 4: Run the test and `test/features/media`.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(media): the info panel says Copies in the cloud`.

### Task 7: User guides

**Files:** `docs/user/media-sync.md` (behind already, per the inventory), and any guide that names Media Storage, the hub or the provider chooser (find them by grep). Run `python3.14 scripts/check_docs_links.py`.

- [ ] **Step 1: Update the guides** to the new page, the account sheet, the status line and Stop keeping copies.
- [ ] **Step 2: Run the docs link check.** Expected: ok.
- [ ] **Step 3: Commit** `docs(media): describe the Photos & videos page`.

## Done when

- One Photos & videos page holds every control from the hub and Media Storage, plus the guided setup icon until phase 6.
- Copies are set up and changed through the account sheet.
- A second device holding the account joins the library's store with nothing to type.
- The status line says what is true.
- Every appendix row for Photos & Media, Media Storage and Hub is reachable.
- The suite is green and files are within their limits.
