# Shared Library Details and Connection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show and change where a connected shared site library lives on this device, and let an owner edit the library's name and a new description.

**Architecture:** Two small new services beside the existing shared library services: `LibraryConnectionService` checks a candidate account and folder against a connected library and repoints the device's row; `LibraryDetailsService` writes `name` and `description` to the library folder's `info.json`. The sync and probe learn to read `description`. The library page gains an About section and a Connection section as their own widgets, and a new Change connection page reuses location fields extracted from the connect page.

**Tech Stack:** Flutter, Riverpod, Drift, go_router, ARB localization.

**Spec:** `docs/design/specs/2026-10-17-shared-library-details-and-connection-design.md`

## Global Constraints

- No file over 800 lines. `shared_library_store.dart` (822), `shared_library_models.dart` (842) and `shared_library_service.dart` (796) are already at or over: add only the few lines each task names to them; new logic goes in new files.
- Schema: `description` is a new nullable TEXT column on `shared_libraries`, shipped as rung v291 (v289 shipped in v1.8.2, so a new rung is needed; no open PR claims 291 as of 2026-10-17; re-check before pushing).
- `info.json` writes are read-modify-write and keep unknown keys. No manifest format version bump.
- Name: required, trimmed, 1 to 80 characters. Description: optional, trimmed, up to 500 characters; empty clears it.
- Only owners edit name and description (checked in the service as well as the UI). Any member may change the connection.
- A failed check or save leaves the library row, memberships and member cards untouched.
- All new strings go in `app_en.arb` and all ten locale ARBs, translated; run `flutter gen-l10n` last (after translations).
- No em dashes anywhere. TDD. `dart format .` before every commit.

## Review Focus

1. The folder is changed in storage between Check and Save (another library appears there): Save re-checks and refuses. Test in Task 4.
2. An encrypted library re-keyed at the new location, wrong passphrase typed: `WrongPassphraseError` surfaces as text, nothing saved. Test in Task 4.
3. The library's current account was deleted from this device: the Connection section still renders and Change connection still works. Test in Task 7.
4. A sync already running for the library when Save starts: the repoint waits behind `SyncCoordinator.run`, so no sync writes the old location after the row changes. Test in Task 4.
5. A reader (read-only storage keys) or offline owner saving details: the write fails, the error shows, and the local name and description are unchanged. Test in Task 3.

---

### Task 1: `description` column, model field and store plumbing

**Files:**
- Modify: `lib/core/database/tables/shared_library_tables.dart` (`SharedLibraries`: `TextColumn get description => text().nullable()();`)
- Modify: `lib/core/database/migrations/helpers/shared_library_migrations.dart` (add `'description': 'TEXT'` to the `shared_libraries` map)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung `if (from < 291) { await _assertSharedLibrarySchema(); }` plus `reportProgress`, with a comment naming issue #3389)
- Modify: `lib/core/database/database.dart:277` (`currentSchemaVersion = 291`)
- Modify: `lib/core/services/shared_library/shared_library_models.dart` (`SharedLibrary.description`, `String?`; constructor, `copyWith(description:, clearDescription:)`, `props`)
- Modify: `lib/core/services/shared_library/shared_library_store.dart` (`upsertLibrary`, `_libraryFromRow`, `setLibraryStatus(description:, clearDescription:)`)
- Test: `test/core/services/shared_library/shared_library_store_test.dart`, and whichever migration test under `test/core/database/` asserts the shared library columns

**Interfaces:**
- Produces: `SharedLibrary.description` (`String?`); `SharedLibraryStore.setLibraryStatus(id, {..., String? description, bool clearDescription = false})`.

- [ ] **Step 1:** Write failing test `upsertLibrary and setLibraryStatus round-trip the description`: upsert a library with `description: 'Group sites'`, read it back (equals), `setLibraryStatus(id, description: 'New')` reads back `'New'`, `setLibraryStatus(id, clearDescription: true)` reads back `null`, and `setLibraryStatus(id, lastError: 'x')` alone leaves the description as it was.
- [ ] **Step 2:** Add a migration assertion beside the existing v289 shared library column checks: a database opened from 290 has `shared_libraries.description`.
- [ ] **Step 3:** Run `flutter test test/core/services/shared_library/shared_library_store_test.dart`; expect FAIL (no `description`).
- [ ] **Step 4:** Implement the column, rung, version, model field and store plumbing, then `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 5:** Run the store test and `flutter test test/core/database`; expect PASS.
- [ ] **Step 6:** Commit `feat(shared-library): store a library description`.

### Task 2: Read `description` in probe and sync

**Files:**
- Modify: `lib/core/services/shared_library/shared_library_transport.dart` (`Future<String?> readDescription()`, same tolerance as `readName`)
- Modify: `lib/core/services/shared_library/shared_library_membership_errors.dart` (`LibraryProbe.description`, `String?`)
- Modify: `lib/core/services/shared_library/shared_library_membership_service.dart` (`_probeWith` and `unlockProbe` fill `description` when the name is readable)
- Modify: `lib/core/services/shared_library/shared_library_service.dart:217` (pass `description:` / `clearDescription:` to `setLibraryStatus`; when the read name differs from the row's, update every local membership's `libraryName` for the library)
- Test: `test/core/services/shared_library/shared_library_membership_service_test.dart`, `test/core/services/shared_library/shared_library_service_test.dart`

**Interfaces:**
- Consumes: Task 1's `setLibraryStatus(description:, clearDescription:)`.
- Produces: `SharedLibraryTransport.readDescription()`, `LibraryProbe.description`.

- [ ] **Step 1:** Write failing tests: `probe reads the description from info.json` (write `{'name': 'Reef', 'description': 'Group sites'}`, expect `probe.description == 'Group sites'`; a probe of a library whose `info.json` has no description gives null); `sync picks up a renamed library and its description` (after a first sync, rewrite `info.json` as another device would, sync again, expect the row's `name` and `description` and the membership's `libraryName` to follow; then remove `description` and expect it cleared).
- [ ] **Step 2:** Run both files; expect FAIL.
- [ ] **Step 3:** Implement. A `readDescription` that returns an empty string counts as none.
- [ ] **Step 4:** Run both files; expect PASS.
- [ ] **Step 5:** Commit `feat(shared-library): read the library description on probe and sync`.

### Task 3: `LibraryDetailsService` (owner edits name and description)

**Files:**
- Create: `lib/core/services/shared_library/library_details_service.dart`
- Test: `test/core/services/shared_library/library_details_service_test.dart`

**Interfaces:**
- Consumes: `SharedLibraryStore`, a `Future<SharedLibraryTransport> Function(SharedLibrary)` (the same shape as `sharedLibraryTransportFactoryProvider`).
- Produces:
  - `class LibraryDetailsService { LibraryDetailsService({required SharedLibraryStore store, required Future<SharedLibraryTransport> Function(SharedLibrary) transportFor}); Future<void> save({required String libraryId, required String diverId, required String name, String? description}); }`
  - `static const int maxNameLength = 80; static const int maxDescriptionLength = 500;`
  - `class NotLibraryOwnerError extends StateError` (in the same file).

- [ ] **Step 1:** Write failing tests, using the fake cloud and a library created through `SharedLibraryMembershipService.create` as the membership tests do:
  - `owner saves name and description to info.json and the local rows`: `info.json` holds both and keeps an unrelated key written before; the row's `name`/`description` and the membership's `libraryName` match.
  - `empty description removes the key`.
  - `non-owner is refused`: a second profile joined as a reader gets `NotLibraryOwnerError`, `info.json` unchanged.
  - `blank or over-long name is refused` with `ArgumentError`, nothing written.
  - `a refused write changes nothing locally` (Review Focus 5): the fake cloud throws on upload; the row keeps the old name and description.
- [ ] **Step 2:** Run; expect FAIL (no file).
- [ ] **Step 3:** Implement. The role comes from `library.roles.roleOf(membership.memberId)`. Write `info.json` first, then the local row (`setLibraryStatus(name:, description:/clearDescription:)`) and memberships.
- [ ] **Step 4:** Run; expect PASS.
- [ ] **Step 5:** Commit `feat(shared-library): owners edit the library name and description`.

### Task 4: `LibraryConnectionService` (check and repoint)

**Files:**
- Create: `lib/core/services/shared_library/library_connection_service.dart`
- Test: `test/core/services/shared_library/library_connection_service_test.dart`

**Interfaces:**
- Consumes: `SharedLibraryStore`, `LibraryTransportFactory` (from `shared_library_membership_errors.dart`), `SharedLibraryMembershipService` for `transportAt`, `SyncCoordinator`.
- Produces:
  - `enum LibraryLocationVerdict { same, olderCopy, locked, differentLibrary, noLibrary, retired, needsNewerApp }`
  - `class LibraryLocationCheck { const LibraryLocationCheck(this.verdict, {this.foundName}); final LibraryLocationVerdict verdict; final String? foundName; bool get canSave => verdict == LibraryLocationVerdict.same || verdict == LibraryLocationVerdict.olderCopy; }`
  - `class LibraryLocationRejected extends StateError { LibraryLocationRejected(this.check); final LibraryLocationCheck check; }`
  - `class LibraryConnectionService { Future<LibraryLocationCheck> check({required String libraryId, required ConnectedAccount account, required String prefix, String? secret}); Future<SharedLibrary> repoint({required String libraryId, required ConnectedAccount account, required String prefix, String? secret, bool acceptOlder = false}); }`

Check rules, in order: no manifest gives `noLibrary`; retired and needs-newer-app as `LibraryProbe` reports them; a different manifest id gives `differentLibrary` with the name when readable; encrypted with no held key for the manifest's `keyId` and no `secret` gives `locked` (a wrong `secret` throws `WrongPassphraseError`); then `readRolesOrNull()` at the new location, where null, empty, or `version` lower than `library.roles.version` gives `olderCopy`; otherwise `same`.

Repoint, inside `SyncCoordinator.run`: re-run `check`; throw `LibraryLocationRejected` unless `canSave` and (`same` or `acceptOlder`). Then update the row's `connected_account_id` and `prefix` (a direct Drift update, not `upsertLibrary`, so no other column moves), set every local membership's `backendKind` and `locationHint` (`'<account label>: <prefix>'`), keep an opened key as `unlockLibrary` does, write each local member's card at the new location (log and continue on refusal, as `join` does), `clearRemoteStamps(libraryId)`, and clear `lastError`.

- [ ] **Step 1:** Write failing tests (fake cloud; library created at prefix `a`, copies made by copying the fake cloud's files to prefix `b`):
  - `same library at a new folder is same, and repoint moves the row`: after repoint, `prefix == 'b'`, roles, `lastSyncAt`, `encrypted` and `keyId` unchanged, membership `locationHint == 'Survey bucket: b'`, member card present at `b`, site states' `remoteModifiedTime` null.
  - `different library is refused and nothing moves`: `differentLibrary` with its name; `repoint` throws `LibraryLocationRejected`; row still at `a`.
  - `empty folder is noLibrary`; `newer format is needsNewerApp`.
  - `older roles version is olderCopy`: bump the trusted roles at `a` past the copy's; `repoint` throws without `acceptOlder` and succeeds with it.
  - `encrypted copy re-keyed elsewhere is locked until the secret is given`; with a wrong secret, `WrongPassphraseError` and nothing moves (Review Focus 2).
  - `repoint re-checks` (Review Focus 1): check `same`, then overwrite `b` with another library's manifest, `repoint` throws.
  - `repoint waits for a running sync` (Review Focus 4): hold `SyncCoordinator.run` with a `Completer`, start `repoint`, expect the row unchanged until the completer finishes.
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run; expect PASS.
- [ ] **Step 5:** Commit `feat(shared-library): check and change a library's connection`.

### Task 5: Providers and account details

**Files:**
- Modify: `lib/features/shared_library/presentation/providers/shared_library_providers.dart` (two service providers, one details provider)
- Modify: `lib/core/services/shared_library/library_account_setup.dart` (`Future<String?> webdavServer(String accountId)`, mirroring `s3Bucket`, returning `WebDavConfig.serverUrl`)
- Test: `test/core/services/shared_library/library_account_setup_test.dart`

**Interfaces:**
- Produces:
  - `libraryDetailsServiceProvider` (`Provider<LibraryDetailsService>`), `libraryConnectionServiceProvider` (`Provider<LibraryConnectionService>`).
  - `libraryConnectionDetailsProvider` (`FutureProvider.family<LibraryConnectionDetails, String>` by library id) where `class LibraryConnectionDetails { final ConnectedAccount? account; final String? bucket; final String? server; final String prefix; }`; `account` null when it is no longer on the device. It invalidates itself on `watchAccountsChanges()` and rebuilds when the library row changes.

- [ ] **Step 1:** Failing test `webdavServer reads the stored server url` (and returns null for missing or broken settings).
- [ ] **Step 2:** Run; expect FAIL. **Step 3:** Implement all three providers and the helper. **Step 4:** Run; expect PASS.
- [ ] **Step 5:** Commit `feat(shared-library): providers for library details and connection`.

### Task 6: About section and details editor

**Files:**
- Create: `lib/features/shared_library/presentation/widgets/library_about_section.dart` (`LibraryAboutSection({required SharedLibrary library, required SharedLibraryRole role, required SharedLibraryMembership? membership})`, plus a private dialog with the name and multi-line description fields, enforcing the Global Constraints limits)
- Modify: `lib/features/shared_library/presentation/pages/shared_library_page.dart` (insert `LibraryAboutSection` after the sync tile's divider)
- Modify: `lib/l10n/arb/app_en.arb` (keys listed below)
- Test: `test/features/shared_library/presentation/widgets/library_about_section_test.dart`

New keys: `sharedLibrary_about_title` "About", `sharedLibrary_about_edit_title` "Edit library details", `sharedLibrary_about_name_label` "Library name", `sharedLibrary_about_description_label` "Description", `sharedLibrary_about_description_help` "What this library holds and who it is for. Every member sees it.", `sharedLibrary_about_nameRequired` "Enter a name".

- [ ] **Step 1:** Failing widget tests: an owner sees name, description and an edit icon, taps it, edits both and saves, and `LibraryDetailsService.save` (a fake) receives the trimmed values; a reader sees the text with no edit icon and tapping does nothing; an empty name blocks Save; a thrown error shows `libraryErrorText` in a snackbar.
- [ ] **Step 2:** Run; expect FAIL. **Step 3:** Implement. **Step 4:** Run, plus `shared_library_page_test.dart`; expect PASS.
- [ ] **Step 5:** Commit `feat(shared-library): about section with owner editing`.

### Task 7: Connection section

**Files:**
- Create: `lib/features/shared_library/presentation/widgets/library_connection_section.dart` (`LibraryConnectionSection({required SharedLibrary library})`)
- Modify: `shared_library_page.dart` (insert before `LibraryOwnershipSection`, after the divider)
- Modify: `app_en.arb`
- Test: `test/features/shared_library/presentation/widgets/library_connection_section_test.dart`

New keys: `sharedLibrary_connection_title` "Connection on this device", `sharedLibrary_connection_s3` "S3 account", `sharedLibrary_connection_s3Bucket` "S3 account, bucket {bucket}", `sharedLibrary_connection_webdav` "WebDAV account", `sharedLibrary_connection_webdavServer` "WebDAV account, {server}", `sharedLibrary_connection_accountMissing` "This account is no longer on this device", `sharedLibrary_connection_folder` "Folder", `sharedLibrary_connection_rootFolder` "The account's top folder", `sharedLibrary_connection_change` "Change connection".

- [ ] **Step 1:** Failing widget tests (override `libraryConnectionDetailsProvider`): S3 account shows its label and "S3 account, bucket group-sites" and the folder; WebDAV shows the server; an empty prefix shows the root wording; a missing account shows the missing line and the button still navigates to `/settings/shared-libraries/L/connection` (Review Focus 3).
- [ ] **Step 2:** Run; expect FAIL. **Step 3:** Implement. **Step 4:** Run; expect PASS.
- [ ] **Step 5:** Commit `feat(shared-library): show a library's connection`.

### Task 8: Shared location fields and the Change connection page

**Files:**
- Create: `lib/features/shared_library/presentation/widgets/library_location_fields.dart` (folder field with validation and setup-guide link, eligible-account dropdown, and the inline add-account form, moved out of `connect_shared_library_page.dart`, with a `LibraryLocationController` holding the prefix controller and selected account id and notifying on change)
- Modify: `lib/features/shared_library/presentation/pages/connect_shared_library_page.dart` (use the extracted widget; behaviour unchanged)
- Create: `lib/features/shared_library/presentation/pages/change_library_connection_page.dart` (`ChangeLibraryConnectionPage({required String libraryId})`)
- Modify: `lib/core/router/app_router.dart` (child route `connection`, name `sharedLibraryConnection`, under `:libraryId`)
- Modify: `app_en.arb`
- Test: `test/features/shared_library/presentation/pages/change_library_connection_page_test.dart`; existing `connect_shared_library_page_test.dart` and `connect_restore_from_backup_test.dart` must stay green unchanged.

New keys: `sharedLibrary_connection_check` "Check location", `sharedLibrary_connection_same` "Found {name} here. This is the same library.", `sharedLibrary_connection_save` "Save connection", `sharedLibrary_connection_olderCopy` "This copy looks older than the one you have been syncing with.", `sharedLibrary_connection_saveAnyway` "Save anyway", `sharedLibrary_connection_different` "This folder holds a different library ({name}). Your connection is unchanged.", `sharedLibrary_connection_differentUnnamed` "This folder holds a different library. Your connection is unchanged.", `sharedLibrary_connection_none` "No library found in this folder. Your connection is unchanged.", `sharedLibrary_connection_saved` "Connection updated". Reuse `sharedLibrary_retired`, `sharedLibrary_connect_needsNewerApp`, `sharedLibrary_encrypted_probe`, `sharedLibrary_encrypted_passphrase`, `sharedLibrary_encrypted_unlock`.

- [ ] **Step 1:** Failing page tests with a fake `LibraryConnectionService`: fields start at the library's account and folder; each verdict shows its message and only `same` shows Save, only `olderCopy` shows Save anyway (which calls `repoint(acceptOlder: true)`); `locked` shows the passphrase field and Unlock re-checks with the secret; editing the folder clears the result; a successful save pops back and starts `syncOne(libraryId)`; a `LibraryLocationRejected` on save shows the matching message and stays.
- [ ] **Step 2:** Run; expect FAIL.
- [ ] **Step 3:** Extract `LibraryLocationFields` first and run the two connect page tests (PASS, unchanged), then build the page and route.
- [ ] **Step 4:** Run the new and connect tests; expect PASS.
- [ ] **Step 5:** Commit `feat(shared-library): change a library's connection`.

### Task 9: Description in the join preview

**Files:**
- Modify: `connect_shared_library_page.dart` (`_result()`: when `probe.exists && probe.description != null`, show it under the join button's library name)
- Test: `connect_shared_library_page_test.dart`

- [ ] **Step 1:** Failing test `join preview shows the library description`. **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(shared-library): show the description before joining`.

### Task 10: Translations and final checks

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb` and the generated `app_localizations*.dart`

- [ ] **Step 1:** Insert every new key into each locale ARB by anchoring on an existing `sharedLibrary_*` neighbour present in all eleven files; real translations, placeholders verbatim; `json.loads` each file; `git diff --numstat -- lib/l10n/arb` shows the same added count and 0 removed per locale.
- [ ] **Step 2:** `flutter gen-l10n`; confirm `grep -A1 "get sharedLibrary_connection_title" lib/l10n/arb/app_localizations_de.dart` is German.
- [ ] **Step 3:** `dart format .`, `flutter analyze` (no issues), `flutter test test/core/services/shared_library test/features/shared_library test/core/database test/architecture test/shared test/l10n`; all PASS.
- [ ] **Step 4:** Commit `i18n(shared-library): translate library details and connection strings`.
