# Settings > Data, PR 2: Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make an account the one thing a diver signs in to: roster rows grouped into accounts, one account sheet used by every picker, an account detail view with Sign in again, one "My own server" form, and the Sync between devices page reshaped around a Using row, with the provider tiles and gear icons gone and shared libraries picking their server through the same sheet.

**Architecture:** The roster stays exactly as it is (one row per role, deterministic ids). A new nullable synced column `connected_accounts.location` carries a secret-free description of where an S3 or WebDAV row points, including the row's own folder. A pure function groups rows into `AccountGroup`s by kind plus server; a small service signs a group in (credentials written to every row), adds a role row on a server, and signs out or removes a group. UI callers (Connected accounts, the Sync page, shared libraries) open one `showAccountSheet`, which lists groups and the kinds that can be added. The sync engine is untouched: choosing an S3 or WebDAV account for sync writes that row's config into the existing legacy store and runs today's provider selection.

**Tech Stack:** Flutter, Riverpod 3 (provider style in `lib/features/settings/presentation/providers/`), Drift (tables in `lib/core/database/tables/`, rungs in `lib/core/database/migrations/`), go_router, gen-l10n with 11 ARB files, `flutter_test`.

**Spec:** `docs/design/specs/2026-10-17-settings-data-setup-and-accounts-design.md`, sections 3, 4, 7, 8.1, 8.4, 9, 10, 11 (phase 2), 13 and the appendix rows for Cloud Sync, Connected Accounts and Shared libraries. Phase 1 shipped as #3485 and #3500.

## Global Constraints

- The account id namespace, `accountIdFor`, `s3NaturalKey` and `webdavNaturalKey` are frozen (`lib/core/services/accounts/account_identity.dart`). Nothing in this plan changes an id or a natural key.
- `location` holds no secret: no S3 access key id or secret key, no WebDAV password. The WebDAV user name is allowed (it is already in the synced roster label).
- One migration rung (schema 292 to 293), nullable and additive, no backfill. `minimumCompatibleSchemaVersion` stays 280.
- Platform and build gating of kinds is exactly today's: iCloud only where `isApplePlatformProvider` is true and `iCloudAvailabilityProvider` is not `unsupported`; Google Drive only where `googleDriveAvailableProvider` is true; Dropbox only where `dropboxConfiguredProvider` is true; S3 and WebDAV everywhere.
- Vocabulary (spec section 4), sentence case. The device word is "device", matching the strings phase 1 shipped ("Only on this device"); the phone or laptop word waits for a later phase.
- Every new string in all eleven ARB files; a string whose meaning changes gets a new key and the old key is deleted once nothing reads it. Run `flutter gen-l10n` after ARB edits and commit the generated files with them.
- Files under 800 lines. `cloud_sync_page.dart` (1,527 lines) must end this PR under 800; `connected_accounts_page.dart` must not grow past 400.
- No em dashes. No tool names or attribution in commits or on GitHub. Every commit and the PR say `Refs #3482`.
- Tests restore global state they replace. After adding files under `lib/`, run `test/architecture` and `test/shared`.
- Screenshots per `docs/contributing/pull-requests.md` for the Connected accounts page, the account detail view, the sheet, the Sync page and the library connect page; the maintainer decides at PR time whether to attach them.

## Rulings and deferrals

Calls this plan makes where the spec leaves a choice or the code forces one; each costs little to reverse.

- `location` also carries the row's own folder (S3 prefix, WebDAV folder) and the WebDAV user name. The spec lists only the server fields, but a second device cannot rebuild a row's config, or prove it hashes back to the row's id, without the folder; the user name is already in the synced label.
- One JSON column, versioned (`"v":1`), rather than typed columns: one rung, and a later field needs no schema change.
- Rows with no `location` group by this device's stored config, and otherwise stand alone. Nothing writes `location` from a read; it is written on save and on sign-in only (spec 7.3).
- "Used for ... on {device}" (spec 7.6) is left out: account usage is device-local today and no synced data says which device uses an account. It needs its own design.
- "Sign in to {account} again" as the sync health reason (spec 9) moves to phase 6, with the card that reads it.
- Per-feature folder names (spec 7.5): this PR keeps today's editable sync folder (on the sync account's detail view); the media folder stays on Media storage until phase 4.
- "Stop syncing on this device" keeps today's cloud backup switch-off and warning until phase 3 adds the pinned copy destination.
- The media storage page's own S3 form stays until phase 4 merges that page; every other S3 and WebDAV form becomes `OwnServerForm` here.
- Size: twelve tasks. Tasks 1 to 8 (accounts) and Tasks 9 to 12 (the Sync page and shared libraries) can ship as one PR or as two in that order; the maintainer chooses before execution.

## Review Focus

Inputs the spec implies that no task's tests would otherwise exercise. Each test is added to the owning task.

1. A legacy S3 row with no `location`, on a device that holds no credentials for it: it must show as its own account, never merged into another server's group and never hidden, and Sign in again must ask for the full server details (Task 3 grouping table, Task 6 sign-in test).
2. Two rows on one server whose folders differ (sync `submersion-sync/`, library `submersion-sites/reef-team/`): one account in the list; signing in writes each row its own folder, and a row whose rebuilt config does not hash back to its own id is skipped, never overwritten (Task 4).
3. Choosing, on the Sync page, the account sync already uses: no "Switch sync backend?" step and no departure recorded (Task 9).
4. Connecting a shared library through an account that is not signed in on this device: the sheet signs in first, then the library row is created with the library folder, and its id equals `accountIdFor(kind: s3, naturalKey: s3NaturalKey(server with that folder))` (Task 11).
5. iCloud on Android, Windows or Linux: never offered under Add an account; an iCloud roster row synced from an Apple device reads "Unavailable on this device" and offers neither Sign in again nor Sign out (Tasks 5 and 7).

---

### Task 1: The location value

**Files:**
- Create: `lib/core/services/accounts/account_location.dart`
- Test: `test/core/services/accounts/account_location_test.dart`

**Interfaces:**
- Produces:
  - `sealed class AccountLocation` with `String get serverKey`, `String toJsonString()`, `static AccountLocation? tryParse(String? json)`.
  - `final class S3AccountLocation extends AccountLocation` with fields `displayHost, endpoint, bucket, region, prefix` (String) and `pathStyle` (bool); `factory S3AccountLocation.fromConfig(S3Config c)`; `S3Config toConfig({required String accessKeyId, required String secretAccessKey})`; `serverKey => 's3|$displayHost|$bucket'`.
  - `final class WebDavAccountLocation extends AccountLocation` with fields `serverUrl, username, folder`; `factory WebDavAccountLocation.fromConfig(WebDavConfig c)`; `WebDavConfig toConfig({required String password, String? pinnedCertSha256})`; `serverKey => 'webdav|${davRoot}'` where `davRoot` is computed the same way as `WebDavConfig.davRoot`.
  - JSON shape: `{"v":1,"kind":"s3",...}` or `{"v":1,"kind":"webdav",...}`. `tryParse` returns null for null, malformed JSON, an unknown `kind` or a `v` above 1.

- [ ] **Step 1: Write the failing tests**

```dart
test('an S3 location never carries a secret', () {
  final json = S3AccountLocation.fromConfig(s3('AKIA1', 'shh')).toJsonString();
  expect(json, isNot(contains('AKIA1')));
  expect(json, isNot(contains('shh')));
});
test('a WebDAV location never carries the password', () { /* same, password */ });
test('round-trips and rebuilds a config that hashes to the same id', () {
  final cfg = s3('AKIA1', 'shh', prefix: 'submersion-sites/reef-team/');
  final loc = AccountLocation.tryParse(S3AccountLocation.fromConfig(cfg).toJsonString())! as S3AccountLocation;
  final rebuilt = loc.toConfig(accessKeyId: 'AKIA1', secretAccessKey: 'shh');
  expect(accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(rebuilt)),
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(cfg)));
});
test('rows on one server share a server key across folders', () {
  expect(S3AccountLocation.fromConfig(s3(prefix: 'submersion-sync/')).serverKey,
      S3AccountLocation.fromConfig(s3(prefix: 'submersion-sites/reef-team/')).serverKey);
});
test('tryParse rejects null, junk, unknown kinds and newer versions', () {
  for (final j in [null, '', '{', '{"v":1,"kind":"ftp"}', '{"v":2,"kind":"s3"}']) {
    expect(AccountLocation.tryParse(j), isNull, reason: '$j');
  }
});
```

The WebDAV round-trip test mirrors the S3 one with `webdavNaturalKey`.

- [ ] **Step 2: Run them, expect a compile failure** (`flutter test test/core/services/accounts/account_location_test.dart`)
- [ ] **Step 3: Implement `account_location.dart`**
- [ ] **Step 4: Run them, expect PASS**
- [ ] **Step 5: Commit** `feat(accounts): a secret-free account location value`

### Task 2: The `connected_accounts.location` column

**Files:**
- Modify: `lib/core/database/tables/media_tables.dart` (`ConnectedAccounts`, add `TextColumn get location => text().nullable()();`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion` 292 to 293, append 293 to `migrationVersions` with a one-line comment)
- Modify: `lib/core/database/migrations/helpers/media_migrations.dart` (`_assertConnectedAccountsSchema`: add `location TEXT` to the CREATE, then `await _addColumnIfMissing('connected_accounts', 'location', 'TEXT');`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (rung 293 calls `_assertConnectedAccountsSchema()`, then `reportProgress`)
- Modify: `lib/core/services/accounts/connected_account.dart` (field `final AccountLocation? location;`, in `copyWith`)
- Modify: `lib/core/data/repositories/connected_accounts_repository.dart`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/media_library_fields.dart` (override `'connectedAccounts.location'`, `FieldKind.opaque`, label key `settings_conflict_field_accountLocation` "Account location")
- Test: `test/core/database/migration_v293_connected_account_location_test.dart`, `test/core/data/repositories/connected_accounts_repository_location_test.dart`, the existing sync round-trip and conflict catalogue suites

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `ConnectedAccount.location` (`AccountLocation?`, parsed by `_toDomain` with `AccountLocation.tryParse`).
  - `Future<void> ConnectedAccountsRepository.setLocation(String id, AccountLocation location)`: writes the column, bumps `updatedAt`, marks the row pending exactly as `updateLabels` does, and does nothing when the stored JSON is identical.
  - `ensure({..., AccountLocation? location})`: when given, writes it through `setLocation` after the insert or label refresh.

- [ ] **Step 1: Write the failing migration test** in the v285 test's style: open a v292 database, run the migration, assert `PRAGMA table_info(connected_accounts)` lists `location`, and that a database whose table was dropped and recreated by the beforeOpen backstop also has it.
- [ ] **Step 2: Write the failing repository tests**: `setLocation` round-trips through `getById`; a second identical `setLocation` does not mark the row pending again; `ensure(location: ...)` on an existing row writes the location; a row whose stored location is junk reads `location == null` and still loads.
- [ ] **Step 3: Write the failing sync test** in `test/core/services/sync/` (follow `sync_nav_tracks_test.dart`): an exported row carries `location`, and importing it on a second database stores it.
- [ ] **Step 4: Run them, expect FAIL**
- [ ] **Step 5: Implement the column, rung, backstop, domain field and repository methods; run `dart run build_runner build --delete-conflicting-outputs`** (write the command into a scratchpad script: a bare build word in a Bash command is refused here)
- [ ] **Step 6: Run the three new tests plus `test/features/settings/presentation/conflicts/`, `test/core/services/sync/cross_version_roundtrip_test.dart`, `test/core/services/sync/omitted_column_keeps_local_test.dart`, `test/architecture/repository_tick_stream_test.dart`; expect PASS**
- [ ] **Step 7: Commit** `feat(accounts): a synced location column on connected accounts`

### Task 3: Account groups

**Files:**
- Create: `lib/core/services/accounts/account_group.dart`
- Test: `test/core/services/accounts/account_group_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 2, `AccountStatus`, `AccountUsage` (`account_usage_service.dart`).
- Produces:
  - `class AccountGroup { final String key; final AccountKind kind; final String label; final String? identifier; final List<ConnectedAccount> rows; final AccountStatus status; final List<AccountUsage> usages; bool get isOwnServer; ConnectedAccount? rowFor(AccountRole role); }`
  - `enum AccountRole { sync, media, library }` (sync: S3 prefix `submersion-sync/` or WebDAV folder `kDefaultWebDavSyncFolder`; media: `submersion-media/` or `Submersion Media`; library: anything under `submersion-sites/`).
  - `List<AccountGroup> groupAccounts({required List<ConnectedAccount> rows, required Map<String, AccountStatus> statusById, required Map<String, AccountLocation> localLocationById, required List<AccountUsage> Function(ConnectedAccount) usagesOf})`.

Rules, in the order the tests pin them:
- Key: OAuth kinds and Lightroom `'${kind.name}|${row.id}'` (one row each); S3 and WebDAV `(row.location ?? localLocationById[row.id])?.serverKey`, and `'row|${row.id}'` when neither is known, so an unknown row stands alone.
- Status: `needsSignIn` if any row needs sign-in; else `unavailable` if every row is unavailable; else `signedIn`.
- Usages: the union of the rows' usages, deduplicated by kind and library name.
- Label: S3 `'$bucket @ $displayHost'`, WebDAV `'$username @ $host'` when a location is known; otherwise the first row's label with a trailing `' (...)'` folder note removed.
- Order: iCloud, Google Drive, Dropbox, S3 and WebDAV together, Lightroom; then label.

- [ ] **Step 1: Write the table test** `groups rows the way the spec says`, one case per rule: sync and media rows on one minio bucket give one group with both usages; the same bucket on two hosts gives two groups; a legacy row with no location and no local config is alone (Review Focus 1); a row known only from `localLocationById` joins its server's group; one row needing sign-in makes the group need sign-in; an all-unavailable iCloud group is unavailable; the label drops `(submersion-sites/reef-team)`.
- [ ] **Step 2: Run, expect a compile failure**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(accounts): group roster rows into accounts`

### Task 4: The account group service, and writing `location` everywhere a row is saved

**Files:**
- Create: `lib/core/services/accounts/account_group_service.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`ensureAccountForProviderType`, about line 351: pass `location:` for S3 and WebDAV)
- Modify: `lib/features/media_store/data/media_store_service.dart` (`connectWebDav` about 255, `connectS3` about 302: pass `location:`)
- Modify: `lib/core/services/shared_library/library_account_setup.dart` (`saveS3`, `saveWebDav`: pass `location:`)
- Modify: `lib/core/providers/account_providers.dart` (`accountGroupServiceProvider`)
- Test: `test/core/services/accounts/account_group_service_test.dart`, plus one assertion each in the existing tests for the three writers

**Interfaces:**
- Consumes: Tasks 1 to 3, `AccountCredentialsStore`, `ConnectedAccountsRepository`, `AccountProviderRegistry`, `S3AccountAdapter.loadConfig`, `WebDavAccountAdapter.loadConfig`.
- Produces (`AccountGroupService`):
  - `Future<int> storeServerSecret(AccountGroup group, ServerSecret secret)`: for each row, rebuild its config from `row.location` (or this device's stored config with the secret replaced), skip the row unless `accountIdFor(kind, naturalKey(config)) == row.id`, write the credentials blob, write `location`; returns how many rows were signed in.
  - `sealed class ServerSecret` with `S3Secret(accessKeyId, secretAccessKey)` and `WebDavSecret(password, {pinnedCertSha256})`.
  - `Future<ConnectedAccount> ensureRole(AccountGroup group, AccountRole role, {String? libraryFolder})`: takes the server from any signed-in row's stored config, swaps in the role's folder (`libraryFolder` for `library`), `ensure`s the row with label and location, writes the credentials. Throws `StateError('not signed in')` when no row of the group has credentials here.
  - `Future<void> signOut(AccountGroup group)`: `disconnect` on every row's adapter.
  - `Future<void> remove(AccountGroup group)`: `disconnect` then `delete` on every row.
  - `Future<ConnectedAccount> saveOwnServer({S3Config? s3, WebDavConfig? webdav})`: the first row of a new server is the sync-role row (default sync folder, spec section 7.2), with credentials and location.

- [ ] **Step 1: Write the failing tests**: `signing in writes each row its own folder` (Review Focus 2); `a row whose rebuilt config hashes elsewhere is skipped`; `adding a library role reuses the group's credentials and folds into the group`; `ensureRole without credentials here throws`; `saveOwnServer creates the sync-role row with its default folder and a location`; `remove deletes every row of the group`. In each writer's existing test, assert the saved row now has a location.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement the service and the three writer changes**
- [ ] **Step 4: Run the new test and the three writers' suites (`test/features/settings/presentation/providers/sync_providers*`, `test/features/media_store/`, `test/core/services/shared_library/`), expect PASS**
- [ ] **Step 5: Commit** `feat(accounts): sign in, add a role, sign out and remove by account`

### Task 5: Group providers, offerable kinds, and sign-in reminders only for needed accounts

**Files:**
- Create: `lib/features/settings/presentation/providers/account_group_providers.dart`
- Modify: `lib/core/services/accounts/pending_setup_service.dart` (the sign-in loop, lines 137 to 160)
- Modify: `lib/features/settings/presentation/pages/connected_accounts_page.dart` (move `connectedAccountsWithStatusProvider` and `connectedAccountUsageProvider` into the new providers file; the page imports them)
- Test: `test/features/settings/presentation/providers/account_group_providers_test.dart`, `test/core/services/accounts/pending_setup_service_test.dart`

**Interfaces:**
- Produces:
  - `accountGroupsProvider = FutureProvider.autoDispose<List<AccountGroup>>`: roster (tick on `watchAccountsChanges`), statuses (as `connectedAccountsWithStatusProvider` probes today), `localLocationById` from each S3 and WebDAV row's stored config, usages from `AccountUsageService`. Registered in `test/architecture/provider_tick_build_smoke_test.dart`. Never read by the Data page (it probes).
  - `enum AccountKindOffer { icloud, googleDrive, dropbox, ownServer }` and `offerableAccountKindsProvider = Provider.autoDispose<List<AccountKindOffer>>` in that order, gated exactly as Global Constraints say.
  - Pending setup: an `accountSignIn` item is raised only for a row with at least one usage on this device (`usage.usagesOf(account).isNotEmpty`). The announced-but-unattached store keeps its `mediaStoreAttach` item and gets no sign-in item (phase 4 adds the store's account).

- [ ] **Step 1: Write the failing tests**: `an unused roster row raises no sign-in item` (the leftover Lightroom row from the inventory); `the sync account needing sign-in raises one`; `a library account needing sign-in raises one`; `offerable kinds follow the platform gates` (iCloud absent off Apple and when unsupported, Drive absent when unavailable, Dropbox absent without a key, own server always last); `groups combine roster, status, local config and usage`. Update the existing pending-setup tests that create unused accounts and expect a sign-in item: give those accounts a usage.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run these tests, `test/features/settings`, and `test/architecture`; expect PASS**
- [ ] **Step 5: Commit** `feat(accounts): account groups, offerable kinds, reminders only where needed`

### Task 6: The My own server form and signing in by kind

**Files:**
- Create: `lib/features/settings/presentation/widgets/accounts/own_server_form.dart`
- Create: `lib/features/settings/presentation/widgets/accounts/account_sign_in.dart`
- Test: `test/features/settings/presentation/widgets/accounts/own_server_form_test.dart`, `test/features/settings/presentation/widgets/accounts/account_sign_in_test.dart`

**Interfaces:**
- Consumes: Tasks 4 and 5, `S3ServerFields`/`S3FormController`, `WebDavServerFields`/`WebDavFormController`, `runWithCertificateTrust`, `authenticateWithBrowserWait`, `DropboxConnectDialog`, `AccountCredentialsStore.rekeyFromLegacy`.
- Produces:
  - `OwnServerForm({AccountGroup? existing, Set<AccountKind> kinds = const {AccountKind.s3, AccountKind.webdav}, bool showSyncFolder = false, required ValueChanged<AccountGroup> onSaved})`: a `SegmentedButton` S3-compatible or WebDAV (hidden when `existing` fixes the kind or `kinds` has one entry), today's fields with folders hidden (`showPrefix: false`, `showFolder: false`) unless `showSyncFolder`, the plain-HTTP warning, the untrusted certificate dialog, Forget certificate, "Check connection" and "Save". With `existing`, fields are pre-filled from the group's location and the secret fields start empty.
  - `Future<AccountGroup?> showOwnServerPage(BuildContext, {AccountGroup? existing, Set<AccountKind>? kinds})` (a pushed page holding the form).
  - `Future<bool> signInToGroup(BuildContext, WidgetRef, AccountGroup)`: Google Drive runs `authenticateWithBrowserWait`; Dropbox opens `DropboxConnectDialog` and rekeys the blob onto the row (`overwrite: true`); own server opens `showOwnServerPage(existing:)` and saves through `storeServerSecret`; iCloud returns false and does nothing. Invalidates `accountGroupsProvider` and `pendingSetupItemsProvider` after a success.
  - `Future<AccountGroup?> addAccount(BuildContext, WidgetRef, AccountKindOffer)`: OAuth kinds sign in, then `ensure(kind, naturalKey: naturalKeyForKind(kind)!, label: <today's provider name>)`; own server opens `showOwnServerPage()`.
- Strings: `settings_accounts_ownServer_title` "My own server", `settings_accounts_ownServer_s3` "S3-compatible", `settings_accounts_ownServer_webdav` "WebDAV", `settings_accounts_checkConnection` "Check connection", `settings_accounts_save` "Save". Reuse today's S3 and WebDAV field, warning and error strings.

- [ ] **Step 1: Write the failing tests**: `saving a new server creates its sync-role account`; `editing an account pre-fills everything but the secret` (Review Focus 1 when the location is null: every field is empty and required); `a plain-http address shows the warning`; `an untrusted certificate asks before trusting`; `iCloud has no sign in`; `a cancelled Google sign-in changes nothing`.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(accounts): one My own server form and sign-in by kind`

### Task 7: The account sheet

**Files:**
- Create: `lib/features/settings/presentation/widgets/accounts/account_sheet.dart`
- Create: `lib/features/settings/presentation/widgets/accounts/account_group_tile.dart` (shared with Task 8)
- Test: `test/features/settings/presentation/widgets/accounts/account_sheet_test.dart`

**Interfaces:**
- Consumes: Tasks 5 and 6.
- Produces:
  - `Future<AccountGroup?> showAccountSheet(BuildContext, {Set<AccountKind>? allowedKinds, String? currentKey, bool addOnly = false, String? Function(AccountGroup choice)? consequenceOf})`, using `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` with a `DraggableScrollableSheet` as `storage_setup_sheet.dart` does.
  - Section "Your accounts" (omitted when `addOnly`): `AccountGroupTile`s filtered by `allowedKinds`, the `currentKey` one marked. A group not signed in here reads "Sign in to use it here"; choosing it runs `signInToGroup` first and returns only on success. Unavailable groups are listed disabled.
  - Section "Add an account": `offerableAccountKindsProvider` filtered by `allowedKinds` (own server needs S3 or WebDAV allowed), minus OAuth kinds that already have a group. Choosing runs `addAccount`.
  - When `consequenceOf(choice)` returns text, the sheet shows that text with Cancel and Continue before returning.
  - `AccountGroupTile({required AccountGroup group, bool selected = false, VoidCallback? onTap})`: kind icon (move today's per-kind icon switch here), label, identifier, sign-in state, and "Used for ..." from the group's usages.
- Strings: `settings_accounts_sheet_yours` "Your accounts", `settings_accounts_sheet_add` "Add an account", `settings_accounts_signInHere` "Sign in to use it here", `settings_accounts_state_signedIn` "Signed in", `settings_accounts_state_notSignedIn` "Not signed in on this device", `settings_accounts_state_unavailable` "Unavailable on this device", `settings_accounts_continue` "Continue". The three state strings replace `settings_connectedAccounts_status_*` once Task 8 lands.

- [ ] **Step 1: Write the failing tests**: `lists accounts, then the kinds that can be added, in the spec order`; `an existing Google account is not offered again`; `restricted to S3 and WebDAV only own servers show`; `choosing a signed-out account signs in first`; `a consequence is shown before returning, and Cancel returns nothing`; `iCloud is not offered off Apple devices` (Review Focus 5).
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `feat(accounts): one account sheet for every picker`

### Task 8: Connected accounts page and the account detail view

**Files:**
- Modify: `lib/features/settings/presentation/pages/connected_accounts_page.dart` (list of `AccountGroupTile`s; "Add account" in the app bar opens `showAccountSheet(addOnly: true)`; empty state keeps "No accounts connected yet" and gains an "Add account" button; overflow menus go)
- Create: `lib/features/settings/presentation/pages/account_detail_page.dart`
- Create: `lib/features/settings/presentation/widgets/accounts/account_confirm_dialog.dart` (today's `_confirm` and its texts, moved)
- Modify: `lib/core/router/app_router.dart` (child route `connected-accounts/account`, query parameter `key`), `lib/features/settings/presentation/pages/data_settings_pane.dart` (`['connected-accounts', 'account']`)
- Test: `test/features/settings/presentation/pages/connected_accounts_page_test.dart` (rework), `test/features/settings/presentation/pages/account_detail_page_test.dart`, `test/core/router/app_router_test.dart` (pane and router parity list)

**Interfaces:**
- Consumes: Tasks 4 to 7.
- Produces: `AccountDetailPage({required String groupKey})`, showing in order: sign-in state; "Used on this device for ..."; "Sign in again" (not for iCloud); for own servers the `OwnServerForm(existing:, showSyncFolder: <group is the sync account>)` with Check connection, Save and Forget certificate, then "Folders" listing each row's role and folder; "Sign out on this device" and "Remove from all devices" (group-wide, through `AccountGroupService`, with today's confirmations listing affected features). iCloud shows "Managed by your Apple ID in device settings" in place of sign-in and sign-out. Saving a changed sync folder on the sync account switches sync to that row as today's S3 and WebDAV config pages do.
- Strings: `settings_accounts_add` "Add account", `settings_accounts_signInAgain` "Sign in again", `settings_accounts_usedHere` "Used on this device for {features}", `settings_accounts_folders` "Folders", `settings_accounts_signOutHere` "Sign out on this device", `settings_accounts_removeEverywhere` "Remove from all devices", `settings_accounts_icloudManaged` "Managed by your Apple ID in device settings". Delete `settings_connectedAccounts_disconnectDevice` and `settings_connectedAccounts_removeFromLibrary` once unread.

- [ ] **Step 1: Write the failing tests**: `two rows on one server show as one account`; `tapping an account opens its detail`; `Add account opens the add sheet`; `Sign out on this device signs out every row of the account`; `Remove from all devices names the features it affects`; `iCloud says it is managed by the Apple ID and offers no sign-out` (Review Focus 5); `the detail page builds in the desktop pane`. Keep the #3388 usage tests, now on the group tile. Keep the sign-out refresh test from #3500 (it must still invalidate `pendingSetupItemsProvider`).
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run the page tests, `test/core/router/app_router_test.dart`, and `test/architecture`; expect PASS**
- [ ] **Step 5: Commit** `feat(settings): Connected accounts lists accounts with a detail view`

### Task 9: Choosing the sync account through the sheet

**Files:**
- Create: `lib/features/settings/presentation/widgets/sync/sync_account_switch.dart` (today's `_selectProvider`, `_confirmBackendSwitch`, `_connectionErrorMessage` and `_providerDisplayName`, moved out of `cloud_sync_page.dart` and made top-level)
- Test: `test/features/settings/presentation/widgets/sync/sync_account_switch_test.dart`, and the moved tests from `cloud_sync_page_test.dart` groups 'provider selection', 'Google Drive desktop browser-wait dialog' and the two backend-switch tests

**Interfaces:**
- Consumes: Tasks 4, 6, 7.
- Produces:
  - `Future<void> useAccountForSync(BuildContext, WidgetRef, AccountGroup group)`: for S3 or WebDAV, `ensureRole(group, AccountRole.sync)` when the group has no sync-role row, then save that row's stored config through `s3StorageProviderInstanceProvider.saveConfig` or the WebDAV equivalent; then run the moved `selectProvider(context, ref, type)` (which keeps today's backend-switch confirmation, departure record, authentication, `saveProvider` and `refreshState`).
  - `String? syncSwitchConsequence(WidgetRef, AccountGroup choice)`: today's "Switch sync backend?" body when sync has history and the choice is not the current sync account; null otherwise (Review Focus 3). Passed to `showAccountSheet(consequenceOf:)`, so the confirmation shows inside the sheet.
  - `Future<void> selectProvider(BuildContext, WidgetRef, CloudProviderType type, {bool alreadyConfirmed = false})`: the moved `_selectProvider`; with `alreadyConfirmed` it skips the switch dialog but still records the departure.

- [ ] **Step 1: Write the failing tests**: `choosing a server with only a library row adds its sync row and syncs there`; `choosing the current account asks nothing and records no departure`; `choosing another account with history shows the switch text first`; `a cancelled Google sign-in leaves sync on the old account`.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run, expect PASS**
- [ ] **Step 5: Commit** `refactor(settings): sync picks its account through the account sheet`

### Task 10: The Sync between devices page reshaped

**Files:**
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart` (end under 800 lines)
- Create: `lib/features/settings/presentation/widgets/sync/sync_using_row.dart`
- Create: `lib/features/settings/presentation/widgets/sync/sync_advanced_section.dart`
- Create: `lib/features/settings/presentation/pages/sync_encryption_page.dart` (hosts the existing `EncryptionSettingsSection`)
- Create: `lib/features/settings/presentation/widgets/sync/sync_banners.dart` (custom folder, duplicate divers, moved and cleanup banners, moved verbatim)
- Delete: `lib/features/settings/presentation/pages/s3_config_page.dart`, `lib/features/settings/presentation/pages/webdav_config_page.dart`, `lib/features/settings/presentation/widgets/webdav_provider_tile.dart`, their routes (`app_router.dart` about 1552 to 1568) and pane entries (`data_settings_pane.dart` 66 to 68), after `grep -rn "s3-config\|webdav-config\|S3ConfigPage\|WebDavConfigPage\|WebDavProviderTile" lib test` finds only these
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart` (`SyncNotifier.stopSyncing()`)
- Test: `test/features/settings/presentation/pages/cloud_sync_page_test.dart` (rework), `test/features/settings/presentation/widgets/sync/sync_using_row_test.dart`, `test/features/settings/presentation/widgets/sync/sync_advanced_section_test.dart`; move the server-form assertions of `s3_config_page_test.dart` and `webdav_config_page_test.dart` into Task 6 and Task 8 tests, then delete those two files

**Interfaces:**
- Consumes: Tasks 7 and 9.
- Produces:
  - Page order: banners; Using row; status card (unchanged); sync actions and their banners (unchanged); "Keep devices in step automatically"; conflicts row; "Advanced".
  - `SyncUsingRow`: "Using: {account}" with its sign-in state and "Change" (opens `showAccountSheet(allowedKinds: sync kinds, currentKey:, consequenceOf: syncSwitchConsequence)` then `useAccountForSync`); "Not set up" with "Set up" (the same sheet) when no account; "Off while the database is in a custom folder" with a link to Database storage in custom folder mode (spec 8.5).
  - `SyncAdvancedSection`: "Also sync at launch" and "Also sync when the app returns" (disabled while automatic sync is off); "Encryption" (pushes `SyncEncryptionPage`); "Devices using this library" (pushes `SyncDevicesPage`); "Troubleshoot"; "Replace the library with this device's copy" (today's flow); "Stop syncing on this device".
  - `Future<void> SyncNotifier.stopSyncing()`: today's S3 and WebDAV branch of `signOut()` for every provider (no `_syncService.signOut()`, no Dropbox token clear), then the shared tail. The page keeps today's confirmation, `disableCloudBackup()` and backup warning; phase 3 replaces that with the pinned copy destination (spec 8.1).
  - The cleanup banner's "Delete old data" gains a confirmation (spec 8.1).
- Strings: `settings_sync_using` "Using: {account}", `settings_sync_change` "Change", `settings_sync_notSetUp` "Not set up", `settings_sync_offCustomFolder` "Off while the database is in a custom folder", `settings_sync_keepInStep` "Keep devices in step automatically", `settings_sync_alsoAtLaunch` "Also sync at launch", `settings_sync_alsoOnReturn` "Also sync when the app returns", `settings_sync_encryption` "Encryption", `settings_sync_devices` "Devices using this library", `settings_sync_troubleshoot` "Troubleshoot", `settings_sync_replaceLibrary` "Replace the library with this device's copy", `settings_sync_stop` "Stop syncing on this device", `settings_sync_cleanup_confirm` (title and body for the new confirmation). Delete the provider tile, header, sign-out and behavior keys once unread.

- [ ] **Step 1: Write the failing tests**: `shows the account in use with Change`; `with no account it says Not set up and offers Set up`; `custom folder mode says sync is off and links to Database storage`; `no provider tiles or gear icons remain`; `the launch and return switches are disabled while automatic sync is off`; `Stop syncing keeps the account signed in` (the account's credentials blob survives and `syncAccountId` is cleared); `Delete old data asks first`; `Encryption and Devices open their pages`.
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement; delete the tile groups and S3 and Dropbox tile groups from `cloud_sync_page_test.dart`, keep every other group passing unchanged**
- [ ] **Step 4: Run `test/features/settings`, `test/core/router`, `test/features/setup_wizard`, `test/architecture`, `test/shared`; expect PASS; `wc -l lib/features/settings/presentation/pages/cloud_sync_page.dart` under 800**
- [ ] **Step 5: Commit** `feat(settings): Sync between devices opens with the account it uses`

### Task 11: Shared libraries pick their server through the sheet

**Files:**
- Modify: `lib/features/shared_library/presentation/widgets/library_location_fields.dart` (the dropdown, the "Add storage account" button and `_accountForm` go; a Using row shows the chosen server account with "Change")
- Modify: `lib/features/shared_library/presentation/pages/connect_shared_library_page.dart`, `change_library_connection_page.dart`
- Test: `test/features/shared_library/presentation/pages/connect_shared_library_page_test.dart`, `change_library_connection_page_test.dart`, `connect_restore_from_backup_test.dart`

**Interfaces:**
- Consumes: Tasks 4 and 7.
- Produces:
  - `LibraryLocationController` holds `AccountGroup? server` in place of `selectedAccountId` and `addingAccount`, and `Future<ConnectedAccount> resolveLibraryAccount(AccountGroupService)` calling `ensureRole(server, AccountRole.library, libraryFolder: prefix)`. The pages call it before probe, join, create, restore and repoint, so `account` stays a `ConnectedAccount` for every service call.
  - Change opens `showAccountSheet(allowedKinds: {AccountKind.s3, AccountKind.webdav}, currentKey:)`. The change page seeds `server` with the group holding `library.connectedAccountId`; when none does, today's `sharedLibrary_connection_accountMissing` text shows.
  - The connect page's "Check" becomes "Check location", reusing `sharedLibrary_connection_check`.
- Strings: delete `sharedLibrary_connect_addAccount`, `sharedLibrary_connect_saveAccount`, `sharedLibrary_connect_account_label`, `sharedLibrary_connect_probe_action` once unread; `sharedLibrary_connect_onlyS3Webdav` stays as the empty state text with an "Add account" button that opens the restricted sheet.

- [ ] **Step 1: Rework the failing tests**: replace the dropdown and add-card cases with `choosing a server makes the library account with the library folder` (Review Focus 4 id assertion); `a signed-out server signs in before the library is checked`; `the connect page says Check location`; `the change page shows the library's server`; `a long server label fits a phone width` (kept from today).
- [ ] **Step 2: Run, expect FAIL**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run `test/features/shared_library`, `test/core/services/shared_library`; expect PASS**
- [ ] **Step 5: Commit** `feat(shared-library): pick the library's server through the account sheet`

### Task 12: Docs and the final sweep

**Files:**
- Modify: the `docs/user/` pages that describe Connected accounts, database sync and shared libraries (find them with `grep -rln "Connected accounts\|Sync between devices\|S3\|WebDAV" docs/user`)
- Modify: release notes per the repo's conventions

- [ ] **Step 1: Update the user docs to the new pages and words; no screenshots of removed tiles remain**
- [ ] **Step 2: Remove every ARB key this PR made unread** (`grep -rn "<key>" lib --include='*.dart' | grep -v lib/l10n/arb` finds nothing), then `flutter gen-l10n`
- [ ] **Step 3: Run `dart format .`, `flutter analyze`, and the full suite (`flutter test`), logging to the scratchpad; expect PASS**
- [ ] **Step 4: Commit** `docs(settings): accounts and the Sync page in the user guide`
