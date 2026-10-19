# Removing Members from a Shared Site Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Owners can remove any approved member other than themselves; the person's past contributions keep counting, the removal sticks, and an owner can allow them back.

**Architecture:** Removal rewrites `roles.json` with existing fields only (move to reader, retire an editing key, drop the approval) and writes an owner-signed `members/removed-<id>.json` record that v1.8.2 never lists. Sync verifies and caches the records; a removed device holds its writes and stops rewriting its card, and owners' devices accept the removed person's pre-removal suggestions.

**Tech Stack:** Flutter, Riverpod 3, Drift, the shared-library transport and signing code under `lib/core/services/shared_library/`.

**Spec:** [docs/design/specs/2026-10-18-shared-library-remove-member-design.md](../specs/2026-10-18-shared-library-remove-member-design.md) (issue #3481)

## Global Constraints

- No new field in `roles.json` (`SharedLibraryRoles.unsignedJson`): v1.8.2 re-serializes roles to verify them.
- Removal record file name `removed-<memberId>.json` in `SharedLibraryLayout.membersDir`; signature message prefix `ssl-removal:v1\n<libraryId>\n`.
- A reader's key is never retired; only `changeRole`'s existing rule (editor or owner with an approved key) retires.
- A valid removal record wins over an approved key.
- Never the word "club" in strings, identifiers, comments, tests or docs.
- New strings in all ten ARB locales, translated; dates through the diver's preferred format (`libraryDateLabel`).
- `shared_library_models.dart`, `shared_library_transport.dart`, `shared_library_store.dart` and `shared_library_service.dart` are at or over 800 lines: new code goes in new files or `part` files; net growth in those four stays minimal.
- A schema rung for the cache column: v292, following the v291 pattern (#3452).

## Review Focus

1. A removed editor's site edits from before the removal must survive a full sync on a device that never saw them before (test in Task 4).
2. Removing a member while offline must leave no half state: roles write fails, so no record is written and the card stays (test in Task 3).
3. A removal record signed by someone who is not an owner (an editor with write access) must be ignored everywhere (test in Task 1, and in Task 4 through sync).
4. Allow back followed by the person's next sync must bring them back as pending, not approved (test in Task 4).
5. Backup member counts and passphrase rewrites must not miss or miscount removal records (tests in Task 2).

---

### Task 1: Removal record and roles helper

**Files:**
- Create: `lib/core/services/shared_library/member_removal.dart`
- Test: `test/core/services/shared_library/member_removal_test.dart`

**Interfaces:**
- Produces:
  - `class MemberRemoval extends Equatable` with `memberId`, `displayName`, `String? publicKey`, `DateTime removedAt` (UTC), `String removedBy`, `String? signature`.
  - `static Future<MemberRemoval> signed({required String libraryId, required String memberId, required String displayName, String? publicKey, required DateTime removedAt, required String removedBy, required LibrarySigningKey key})`
  - `Map<String, dynamic> toJson()` (keys `memberId`, `displayName`, `publicKey?`, `removedAt` ms, `removedBy`, `signature?`); `static MemberRemoval? fromJson(Object? raw)` (null for a malformed record).
  - `Future<bool> verify(String libraryId, SharedLibraryRoles roles)`: true only when `roles.owners` contains `removedBy` and the signature verifies under `roles.approvedKeys[removedBy]`.
  - `extension MemberRemovalRoles on SharedLibraryRoles { SharedLibraryRoles removing(String memberId, {required DateTime at}); }` = `changeRole(memberId, reader, at: at)` with `memberId` dropped from `approvedKeys`.
  - `Future<List<MemberRemoval>> validRemovals(Iterable<MemberRemoval> records, String libraryId, SharedLibraryRoles roles)`.

- [ ] **Step 1: Write the failing tests** (`member_removal_test.dart`, keys from `test/helpers/shared_library_test_keys.dart`):
  - `a record signed by an owner verifies`: roles `owners: {'ann'}`, `approvedKeys: {'ann': annKey.publicKey}`; `verify('L', roles)` is true.
  - `a record signed by an editor does not verify`: same record but `removedBy: 'ed'` with `ed` an editor holding an approved key, false.
  - `a tampered field or another library does not verify`: change `displayName` after signing, false; verify with `'M'`, false.
  - `round-trips through json`: `fromJson(toJson())` equals the original; `fromJson({'memberId': 1})` is null.
  - `removing an editor retires the key at the cut-off and drops the approval`: editor `bo` with key K, `removing('bo', at: T)` gives `roleOf('bo') == reader`, `approvedKeys` lacks `bo`, `retired['bo']` holds `(key: K, untilMs: T.ms)`.
  - `removing a reader retires nothing`: reader `rd` with an approved key; `retired` has no `rd` entry and `approvedKeys` lacks `rd`.
- [ ] **Step 2: Run** `flutter test test/core/services/shared_library/member_removal_test.dart`; expected: compile failure (no `member_removal.dart`).
- [ ] **Step 3: Implement** `member_removal.dart`. Signed message: `utf8.encode('ssl-removal:v1\n$libraryId\n${canonicalJson(unsigned json)}')`, the unsigned json being `toJson()` without `signature`; sign and verify with `LibrarySigner`.
- [ ] **Step 4: Run** the test file; expected: all pass.
- [ ] **Step 5: Commit** `feat(shared-library): signed member removal records`

### Task 2: Storage, cache, backup and restore

**Files:**
- Create: `lib/core/services/shared_library/shared_library_transport_removals.dart` (`part of 'shared_library_transport.dart'`)
- Create: `lib/core/services/shared_library/shared_library_store_removals.dart` (`part of 'shared_library_store.dart'`)
- Modify: `lib/core/services/shared_library/shared_library_transport.dart` (part directive; `sealableFiles` adds the members folder's `removed-` files)
- Modify: `lib/core/services/shared_library/shared_library_store.dart` (part directive)
- Modify: `lib/core/database/tables/shared_library_tables.dart` (`TextColumn get removalsJson => text().nullable()();` on `SharedLibraries`)
- Modify: `lib/core/database/migrations/helpers/shared_library_migrations.dart` (`'removals_json': 'TEXT'`), `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung 292), `lib/core/database/database.dart` (`currentSchemaVersion = 292`, 292 in the rung list, floor unchanged)
- Modify: `lib/core/services/shared_library/backup/library_backup_service.dart` (`memberCount` counts `member-` files only)
- Modify: `lib/core/services/shared_library/backup/library_restore_service.dart` (`_restoreOthers` deletes removal records the backup lacks)
- Test: `test/core/services/shared_library/shared_library_transport_test.dart`, `shared_library_store_test.dart`, `test/core/database/shared_library_schema_test.dart`, the existing backup and restore tests under `test/core/services/shared_library/backup/`

**Interfaces:**
- Consumes: `MemberRemoval` (Task 1).
- Produces:
  - `extension SharedLibraryTransportRemovals on SharedLibraryTransport`: `Future<List<MemberRemoval>> listRemovals()` (unreadable or malformed files skipped with a warning, as cards are), `Future<void> writeRemoval(MemberRemoval r)`, `Future<void> deleteRemoval(String memberId)`, `static String removalFileName(String memberId)`.
  - `extension SharedLibraryStoreRemovals on SharedLibraryStore`: `Future<List<MemberRemoval>> removals(String libraryId)` (empty when null or unparsable), `Future<void> setRemovals(String libraryId, List<MemberRemoval> removals)` (updates only `removals_json`, so `watchLibraries` fires).

- [ ] **Step 1: Write the failing tests:**
  - transport: `removal records round-trip and are not member cards` (write one, `listRemovals` returns it, `listMembers` does not); `deleteRemoval removes it`; `sealableFiles lists removal records`; an encrypted library reads a sealed record back.
  - store: `removals are cached per library and survive upsertLibrary` (set, then `upsertLibrary` of the same library, then `removals` still returns them).
  - schema: the v292 column exists after migrating from 291, as the v291 test does for `description`.
  - backup: `member count ignores removal records`.
  - restore: `restoring a backup from before a removal drops the newer record`.
- [ ] **Step 2: Run** each file alone; expected: failures for the missing API and column.
- [ ] **Step 3: Implement** the parts, column, rung and the two backup changes. Run `dart run build_runner build --delete-conflicting-outputs` after the table change.
- [ ] **Step 4: Run** the five test files plus `test/core/database`; expected: pass.
- [ ] **Step 5: Commit** `feat(shared-library): store, cache and back up member removals`

### Task 3: Remove and Allow back in the membership service

**Files:**
- Modify: `lib/core/services/shared_library/shared_library_membership_ownership.dart`
- Test: `test/core/services/shared_library/member_removal_service_test.dart` (harness as in `shared_library_membership_service_test.dart`: test database, `FakeCloudStorageProvider`, `ownerAndJoiner`-style setup)

**Interfaces:**
- Consumes: Tasks 1 and 2; existing `_asOwner`, `writeSignedRoles`, `_keyOfMember`.
- Produces:
  - `Future<void> removeMember({required String libraryId, required String memberId, required String actingMemberId})`
  - `Future<void> allowBack({required String libraryId, required String memberId, required String actingMemberId})`

- [ ] **Step 1: Write the failing tests:**
  - `removing an approved editor`: after approve and setRole editor, `removeMember`; folder roles show reader, no approval, `retired[bo]` set; `listMembers` lacks bo; `listRemovals` has one record with bo's display name and key that verifies; `store.removals` has it.
  - `an owner cannot remove themselves`: `throwsStateError`.
  - `only an owner removes`: acting as bo, `throwsStateError`.
  - `a refused roles write leaves no record and the card`: make the fake cloud fail uploads of `roles.json` (as existing offline tests do), expect a throw, then `listRemovals` empty and bo's card still listed.
  - `allow back deletes the record`: `listRemovals` and `store.removals` empty, roles unchanged.
- [ ] **Step 2: Run** the file; expected: methods not defined.
- [ ] **Step 3: Implement** both in `SyncCoordinator.run`, in the spec's write order (roles, record, card delete, then `replaceMembers` and `setRemovals` from the folder). `removedBy` is `actingMemberId`, signed with `_keyOfMember(libraryId, actingMemberId)`; `displayName` and `publicKey` from the person's card (empty name and the approved key when the card is gone). Self-removal throws `StateError`.
- [ ] **Step 4: Run** the file and `shared_library_membership_service_test.dart`; expected: pass.
- [ ] **Step 5: Commit** `feat(shared-library): owners remove members and allow them back`

### Task 4: Sync honours removals

**Files:**
- Create: `lib/core/services/shared_library/shared_library_sync_removals.dart` (`part of 'shared_library_service.dart'`)
- Modify: `lib/core/services/shared_library/shared_library_service.dart` (read and cache removals after `listMembers`; `holdWrites` also when this member is removed; skip the card rewrite when removed; pending keys exclude removed members)
- Modify: `lib/core/services/shared_library/shared_library_sync_parts.dart` (`_pullSuggestions` takes `removals`)
- Test: `test/core/services/shared_library/member_removal_sync_test.dart` (harness as in `retired_keys_test.dart`)

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces: `extension _RemovalSync on SharedLibraryService` with `Future<List<MemberRemoval>> _readRemovals(SharedLibraryTransport t, String libraryId, SharedLibraryRoles roles)` (lists, verifies, caches) and `Map<String, String> _pendingKeysOf(List<SharedLibraryMember> members, SharedLibraryRoles roles, Set<String> removed)` (the existing pending-key rule, minus removed ids; moved out of the service to keep it under 800 lines).

- [ ] **Step 1: Write the failing tests:**
  - `a removed editor's earlier edits survive on a fresh device`: bo (editor) edits a site and syncs; ann removes bo; a third profile joins and syncs; the site carries bo's edit.
  - `the removed device stops writing`: after removal, bo edits locally and syncs: result status `readOnly`, no upload of the site, and `listMembers` still lacks bo's card.
  - `a forged record changes nothing`: an editor writes a record removing a reader, signed with the editor's own key; ann's sync caches no removal, and the reader's device still uploads.
  - `allow back brings them back as pending`: after `allowBack`, bo syncs: bo's card is back, `approvedKeys` lacks bo.
  - `an undecided suggestion from before the removal stays`: bo (reader) suggests, ann removes bo before her device pulls it, ann syncs: the suggestion is in ann's inbox as pending. A suggestion with `createdAt` after `removedAt` is not taken in.
- [ ] **Step 2: Run** the file; expected: failures.
- [ ] **Step 3: Implement.** Suggestion fallback: when neither the approved key nor the card key verifies, a removal for the author with a `publicKey` that verifies the suggestion and `createdAt <= removedAt` makes it pending.
- [ ] **Step 4: Run** the file plus `shared_library_service_test.dart`, `retired_keys_test.dart`, `held_edits_test.dart`, `suggestion_service_test.dart`; expected: pass.
- [ ] **Step 5: Commit** `feat(shared-library): sync honours member removals`

### Task 5: Members page: Remove, confirmation, Removed section

**Files:**
- Modify: `lib/features/shared_library/presentation/providers/shared_library_providers.dart` (`libraryRemovalsProvider`)
- Modify: `lib/features/shared_library/presentation/pages/shared_library_members_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` (English only here; Task 7 translates)
- Test: `test/features/shared_library/presentation/pages/shared_library_members_page_test.dart`

**Interfaces:**
- Consumes: `removeMember`, `allowBack` (Task 3); `SharedLibraryStoreRemovals.removals` (Task 2).
- Produces: `final libraryRemovalsProvider = FutureProvider.family<List<MemberRemoval>, String>` (watches `sharedLibrariesProvider`, reads the store). ARB keys and English copy:
  - `sharedLibrary_members_remove`: "Remove from library"
  - `sharedLibrary_members_removeTitle`: "Remove {name}?"
  - `sharedLibrary_members_removeBody`: "{name} will no longer be able to edit sites or suggest changes. Sites and edits they already contributed stay in the library.\n\nThey can still read the library until you change its storage keys, and its passphrase if it is encrypted."
  - `sharedLibrary_members_removeConfirm`: "Remove"
  - `sharedLibrary_members_removedHeader`: "Removed"
  - `sharedLibrary_members_removedOn`: "Removed {date}"
  - `sharedLibrary_members_allowBack`: "Allow back"

- [ ] **Step 1: Write the failing widget tests** (extend `_RecordingMembershipService` with `removals` and `allowedBack` lists; override `libraryRemovalsProvider`):
  - `owners can remove another approved member`: open Bob's menu, tap "Remove from library", the dialog reads "Remove Bob?", tap "Remove": `removals == ['ed']`.
  - `cancel removes nobody`.
  - `no Remove on the owner's own row`: open Ann's menu; "Remove from library" absent.
  - `readers see no Remove`.
  - `removed people are listed under Removed with Allow back`: a removal for `pd` named "Pat" with a pending card for `pd`: "Removed" header shown, Pat appears once (not under Pending), tapping "Allow back" records `pd`.
  - `a refused removal shows a snack bar` (service throws `CloudStorageException`).
- [ ] **Step 2: Run** the file; expected: failures.
- [ ] **Step 3: Implement.** Menu value type is the builder's call (the role menu gains a divider and the Remove item, only when the row is not the viewer's own). No buttons in `ListTile.trailing` (the `list_tile_trailing_width` guard): Allow back goes in the subtitle, as Remove role does for the Left section. `flutter gen-l10n` after the ARB edit.
- [ ] **Step 4: Run** the file and `test/architecture/`; expected: pass.
- [ ] **Step 5: Commit** `feat(shared-library): remove members from the members page`

### Task 6: Library page notice for a removed person

**Files:**
- Modify: `lib/features/shared_library/presentation/pages/shared_library_page.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/shared_library/presentation/pages/shared_library_page_test.dart`

**Interfaces:**
- Consumes: `libraryRemovalsProvider` (Task 5), `currentMembershipProvider`.
- Produces: `sharedLibrary_library_removedBanner`: "An owner removed you from this library. Its sites stay on this device, but you can no longer change them. Leaving the library keeps personal copies of the sites you dived."

- [ ] **Step 1: Write the failing tests:** `a removed member sees the removal notice` (a removal for the viewer's member id); `others do not` (a removal for someone else).
- [ ] **Step 2: Run**; expected: fail.
- [ ] **Step 3: Implement** with the page's existing `_Banner` (icon `Icons.person_remove_outlined`, not an error).
- [ ] **Step 4: Run** the file; expected: pass.
- [ ] **Step 5: Commit** `feat(shared-library): tell a removed member they were removed`

### Task 7: Translations and docs

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Modify: the user-facing Shared Site Libraries doc under `docs/` if one describes members (find with `grep -ril "shared site librar" docs --include=*.md`)

- [ ] **Step 1:** Translate the eight new keys into each locale, keeping `{name}` and `{date}` placeholders.
- [ ] **Step 2:** `flutter gen-l10n`, then run the l10n staleness and ARB checks the pre-push hook runs (`test/l10n/` if present).
- [ ] **Step 3:** Add a short "Removing someone" paragraph to the user doc, if there is one.
- [ ] **Step 4: Commit** `i18n(shared-library): translate member removal strings`

### Task 8: Whole-branch check

- [ ] `dart format .`, `flutter analyze`, `test/architecture/`, `test/shared/`, `test/core/services/shared_library/`, `test/core/database/`, `test/features/shared_library/`; expected: all pass.
- [ ] After screenshots with the throwaway golden harness (members page with the Removed section, the menu with Remove, the confirmation dialog, the library page notice), plus dark mode of the dialog.
