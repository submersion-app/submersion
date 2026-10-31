# Sign in again from errors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tell refused access apart from other cloud failures for sync and the backup copy, and put a Sign in again action on those errors that retries the work.

**Architecture:** A typed `accessRefused` signal on `CloudStorageException` carries the reason out of each provider. Sync records it as `SyncFailureKind.auth`, which Data health reads as `syncSignedOut`; backup stores a flag that gives `backupCloudSignIn`. One shared action wraps `signInToGroup`, passing the expected account down so the wrong account is refused before anything of it is kept.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, googleapis, google_sign_in, gen-l10n.

**Spec:** `docs/design/specs/2026-10-30-sign-in-again-from-errors-design.md`

## Global Constraints

- A refusal means a server refused. No session here is not a refusal.
- Never classify by message text.
- An outage (5xx, timeout, quota, rate limit) never reads as a sign-in problem.
- The account page's Sign in again and the set-up flows keep today's behaviour.
- Every string is translated in all 10 non-English ARBs. `flutter gen-l10n` runs after the translations are in.
- Paths built with `p.join`. A test that replaces process-wide state restores it.
- No em dashes. No mention of the tool in commits or the PR.
- Before each commit: `dart format` on touched files, `flutter analyze`, the affected tests. Run `test/architecture/` after adding a file under `lib/`.

## Review Focus

1. A Google account with a healthy session whose scheduled backup fails with no session: no Sign in again appears. Pinned in Task 3.
2. A Drive 403 for a reason not on the allowlist: keeps today's network classification. Pinned in Task 1.
3. A sign-in finishing after the button's line has gone: the retry still runs. Pinned in Task 7.
4. A double tap: one sign-in only. Pinned in Task 6.
5. A diver who backs up by hand, with automatic backups off: still sees the action. Pinned in Task 3.

---

### Task 1: The refusal signal, for every provider

**Files:**
- Modify: `lib/core/services/cloud_storage/cloud_storage_provider.dart`
- Modify: `lib/core/services/cloud_storage/google_drive_storage_provider.dart:254-288`
- Modify: `lib/core/services/cloud_storage/dropbox/dropbox_api_client.dart:334`
- Modify: `lib/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart:205-213`
- Modify: `lib/core/services/cloud_storage/s3/s3_api_client.dart:777-790`
- Modify: `lib/core/services/cloud_storage/webdav/webdav_errors.dart`
- Modify: `lib/core/services/cloud_storage/git/git_errors.dart`
- Test: `test/core/services/cloud_storage/cloud_storage_provider_test.dart`, `google_drive_storage_provider_test.dart`, `dropbox/dropbox_api_client_test.dart`, `dropbox/dropbox_auth_manager_test.dart`, `s3/` client test, `webdav/` errors test, `git/` errors test

**Interfaces:**
- Produces, in `cloud_storage_provider.dart`:
  - `bool get accessRefused => false` on `CloudStorageException`
  - `class CloudAccessRefusedException extends CloudStorageException` with `const CloudAccessRefusedException(super.message, [super.cause, super.stackTrace])`, overriding `accessRefused` to true

Dart forbids optional positional and named parameters together, so the base constructor cannot take a flag.

- [ ] **Step 1: Write the failing tests**

One test per row of the spec's table, both columns:
- `refused`: Drive 403 for each of `insufficientPermissions`, `insufficientFilePermissions`, `ACCESS_TOKEN_SCOPE_INSUFFICIENT`, `authError`; `_signInExpired` after a rejected retry; Dropbox second 401; Dropbox token endpoint 400; S3 403 `AccessDenied`; WebDAV 401 and 403; Git 401 and 403.
- `not refused`: Drive 403 `storageQuotaExceeded`, `rateLimitExceeded`, and an unknown reason; Dropbox 429 and token endpoint 500; S3 403 `RequestTimeTooSkewed` and `AuthorizationHeaderMalformed`, and 500; WebDAV 404; Git 403 with Retry-After.

Each asserts `expect(error.accessRefused, isTrue)` or `isFalse`, and that the error is still a `CloudStorageException`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/core/services/cloud_storage/`
Expected: FAIL with `accessRefused` undefined.

- [ ] **Step 3: Implement**

- `_signInExpired` returns `CloudAccessRefusedException`.
- `_mapDriveError` gains an allowlist `_refusedReasons`, checked after the `storageQuotaExceeded` branch: `e.status == 403 && e.errors.any((d) => _refusedReasons.contains(d.reason))`.
- Dropbox client's second 401 and the auth manager's 4xx branch throw the new class; its 5xx branch stays `CloudStorageException`.
- S3 `_throwFor`'s final 403 throw uses the new class, keeping the message and cause. `S3MediaObjectStore._map` reads the message, which does not change.
- `WebDavException` and `GitException` override `accessRefused` from `code`: `unauthorized` or `forbidden`.

- [ ] **Step 4: Run them to see them pass**

Run: `flutter test test/core/services/cloud_storage/ test/core/services/media_store/`
Expected: PASS.

- [ ] **Step 5: Commit**

`feat(cloud-storage): mark refused access with a typed signal`

### Task 2: Sync records a refusal as a sign-in problem

**Files:**
- Modify: `lib/core/services/sync/sync_service.dart:1071`
- Modify: `lib/core/services/sync/changeset_log/changeset_reader.dart:389`
- Modify: `lib/features/settings/domain/data_health/sync_health.dart`
- Modify: `lib/features/settings/presentation/providers/sync_providers.dart:1787-1806`
- Test: `test/core/services/sync/sync_service_epoch_test.dart` (or a new `sync_service_refused_access_test.dart`), `test/core/services/sync/changeset_log/changeset_reader_test.dart`, `test/features/settings/domain/data_health/sync_health_test.dart`, `test/features/settings/presentation/providers/sync_failure_recording_test.dart`

**Interfaces:**
- Consumes: `CloudStorageException.accessRefused`.
- Produces: `enum SyncFailureKind { network, auth, other }`.

- [ ] **Step 1: Write the failing tests**

- `a refused provider call returns authError with its message`
- `an ordinary CloudStorageException still returns networkError`
- `a refused peer read stops the pull` and `an ordinary peer read failure is still isolated`
- `evaluateSyncHealth`: a current `auth` failure gives failing `syncSignedOut`; a later `lastSyncAt` clears it; `network` behaviour is unchanged.
- Recording: `authError` records `SyncFailureKind.auth`; a refused exception reaching the outer catch records `auth`; `error` still records `other`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/core/services/sync/changeset_log/changeset_reader_test.dart test/features/settings/domain/data_health/sync_health_test.dart test/features/settings/presentation/providers/sync_failure_recording_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- `sync_service.dart`: in the `on CloudStorageException` handler, return `SyncResultStatus.authError` with `e.message` when `e.accessRefused`, before the `networkError` return.
- `changeset_reader.dart`: an `on CloudStorageException catch (e) { if (e.accessRefused) rethrow; ... }` ahead of the existing catch, sharing its body.
- `sync_health.dart`: a current failure of kind `auth` joins `!i.authenticated` in the `syncSignedOut` candidate.
- `_runSyncOnce`: `authError` maps to `auth`; the outer catch uses `auth` when `e is CloudStorageException && e.accessRefused`.

- [ ] **Step 4: Run them to see them pass**

Run: the Step 2 command, plus `flutter test test/core/services/sync/sync_service_epoch_test.dart`.
Expected: PASS.

- [ ] **Step 5: Commit**

`feat(sync): report refused access as a sign-in problem`

### Task 3: Backup keeps the reason

**Files:**
- Modify: `lib/features/backup/domain/entities/backup_settings.dart`
- Modify: `lib/features/backup/data/repositories/backup_preferences.dart`
- Modify: `lib/features/backup/data/services/backup_service.dart:250,340,1730,1856`
- Modify: `lib/features/backup/data/services/backup_service_cloud_copy.dart`
- Modify: `lib/features/settings/domain/data_health/feature_health.dart`
- Modify: `lib/features/settings/domain/data_health/backup_health.dart`
- Modify: `lib/features/settings/presentation/widgets/data_health/health_text.dart`
- Modify: `lib/features/settings/presentation/providers/data_health_providers.dart:35-50`
- Modify: `lib/features/backup/presentation/providers/backup_copy_providers.dart`
- Test: `test/features/backup/data/repositories/backup_preferences_test.dart`, `test/features/backup/data/services/backup_copy_destination_test.dart`, `test/features/settings/domain/data_health/backup_health_test.dart`, `test/features/settings/presentation/widgets/data_health/health_text_test.dart`, `test/core/services/background_service_backup_test.dart`

**Interfaces:**
- Consumes: `accessRefused`.
- Produces:
  - `BackupSettings.lastCloudCopyNeedsSignIn` (bool, default false), in `copyWith` and `props`
  - `BackupPreferences.setLastCloudCopyNeedsSignIn(bool)`, key `backup_last_cloud_copy_needs_sign_in`
  - `HealthReason.backupCloudSignIn`
  - `BackupHealthInputs.lastCloudCopyNeedsSignIn` and `.copyAccountNeedsSignIn`
  - `AccountGroup? backupCopyGroupOf(BackupCopyTarget?)` in `backup_copy_providers.dart`: the group of `CopyFollowsSync` or `CopyToAccount`, otherwise null

- [ ] **Step 1: Write the failing tests**

- Preferences: defaults false and round-trips.
- Service: `a refused upload sets the flag`; `a refused folder lookup sets the flag`; `an outage leaves it false`; `the next good backup clears it`.
- Background: a Google provider with no session (`CloudStorageException('Not authenticated with Google Drive')`) leaves `lastCloudCopyNeedsSignIn` false while `lastCloudCopyMissing` is true.
- Health: `backupCloudSignIn` from the flag; from `copyAccountNeedsSignIn`; it beats `backupAutoOff`, `backupOverdue` and `backupNever`; `backupFailed` beats it; without a missing copy, neither input matters.
- Text: `healthReasonText` for `backupCloudSignIn` is `dataHealth_backup_cloudCopyMissing`'s text.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/backup/data/repositories/backup_preferences_test.dart test/features/backup/data/services/backup_copy_destination_test.dart test/features/settings/domain/data_health/backup_health_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- `_copyToCloud` returns `({String? fileId, String? accountId, bool needsSignIn})`; the catch sets `needsSignIn` from `e is CloudStorageException && e.accessRefused`. Update the `copy` default in `_performBackupInto`.
- `_getOrCreateCloudBackupFolder({bool rethrowRefused = false})`: rethrows a refusal when asked. `_uploadToCloud` passes true. Line 565's caller is inside a per-record catch, so a throw fails that record as a null did.
- Write `setLastCloudCopyNeedsSignIn(copy.needsSignIn)` beside `setLastCloudCopyMissing`.
- `evaluateBackupHealth`: `copySignIn = i.cloudBackupEnabled && i.lastCloudCopyMissing && (i.lastCloudCopyNeedsSignIn || i.copyAccountNeedsSignIn)`. Check it before the `autoEnabled` return. In the candidate list, put it right after `backupFailed`, ahead of `backupNever` and `backupOverdue`, and skip `backupCloudCopyMissing` when it holds.
- `backupHealthProvider`: read `backupCopyTargetProvider` **only** while the copy is missing, so nothing else pays for it: `settings.lastCloudCopyMissing && settings.cloudBackupEnabled ? backupCopyGroupOf(ref.watch(backupCopyTargetProvider).value)?.status == AccountStatus.needsSignIn : false`.

- [ ] **Step 4: Run them to see them pass**

Run: the Step 2 command, plus `flutter test test/core/services/background_service_backup_test.dart test/features/settings/presentation/providers/data_health_providers_test.dart test/features/settings/presentation/widgets/data_health/health_text_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

`feat(backup): keep why a cloud copy failed`

### Task 4: Refuse the wrong account where it first appears

**Files:**
- Modify: `lib/core/services/cloud_storage/cloud_storage_provider.dart`
- Modify: `lib/core/services/cloud_storage/google_drive/google_drive_authenticator.dart`
- Modify: `lib/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart:157-180`
- Modify: `lib/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart:108-161`
- Modify: `lib/core/services/cloud_storage/google_drive/keychain_gated_authenticator.dart:135,184`
- Modify: `lib/core/services/cloud_storage/google_drive_storage_provider.dart:93`
- Modify: `lib/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart:96-139`
- Modify: `lib/core/services/cloud_storage/dropbox_storage_provider.dart:65`
- Test: `test/core/services/cloud_storage/google_drive/desktop_oauth_authenticator_test.dart`, `google_sign_in_authenticator_test.dart`, `keychain_gated_authenticator_test.dart`, `test/core/services/cloud_storage/dropbox/dropbox_auth_manager_test.dart`, `test/core/services/cloud_storage/cloud_storage_provider_test.dart`
- Update fakes: `test/core/services/accounts/adapters/google_drive_account_adapter_test.dart`, `test/core/services/cloud_storage/google_drive_storage_provider_auth_test.dart`, `test/features/media_store/media_store_service_google_drive_test.dart`

**Interfaces:**
- Produces, in `cloud_storage_provider.dart`:
  - `class CloudAccountMismatchException extends CloudStorageException` with `final String signedInAs`, and `accessRefused` left false
  - `bool isSameAccount(String? expected, String? actual)`: true when either side is null or blank, otherwise a trimmed, case-insensitive comparison
- Produces:
  - `GoogleDriveAuthenticator.authenticate({String? expectedAccount})`
  - `GoogleDriveStorageProvider.authenticateAs(String? expectedAccount)`; `authenticate()` calls it with null
  - `DropboxAuthManager.completeAuthorization(String code, {String? expectedAccount})` and the same on `DropboxStorageProvider`

- [ ] **Step 1: Write the failing tests**

- `isSameAccount`: `Diver@Example.com ` matches `diver@example.com`; null or blank on either side is true; two different addresses are false.
- Desktop, a consent for another email: throws `CloudAccountMismatchException` with that `signedInAs`; `_tokenStore.save` not called; `authClient` unchanged. With no id-token email, signs in normally. With no `expectedAccount`, signs in as today.
- Mobile, `authenticateResult` for another email: throws the mismatch (not a wrapped `Google Sign-In failed`); `signOutCalls == 1`; `authClient` unchanged; a `signOut` that throws does not change the exception.
- Dropbox: another email or display name throws before `_store.save`; the stored auth is unchanged; an account fetch failure (no labels) still connects.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/core/services/cloud_storage/google_drive/ test/core/services/cloud_storage/dropbox/dropbox_auth_manager_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- Desktop: after `_grantsDrive`, compare `_emailFromIdToken(credentials.idToken)`. The existing `on CloudStorageException { rethrow; }` lets it through.
- Mobile: after `_googleSignIn.authenticate`, before `authorizeScopes`, compare `account.email`; on a mismatch call `_googleSignIn.signOut()` in its own try (log a failure) and throw. **Add `on CloudStorageException { rethrow; }` ahead of the `catch` at line 158**, which would otherwise rewrap it as `Google Sign-In failed`.
- Keychain gated: forward `expectedAccount`; `_UnconfiguredDesktopAuthenticator` accepts and ignores it.
- Dropbox: compare `email ?? displayName` before `_store.save`, clear `_pendingVerifier`, and throw.
- Update each test fake's `authenticate` to the new signature.

- [ ] **Step 4: Run them to see them pass**

Run: `flutter test test/core/services/cloud_storage/ test/core/services/accounts/ test/features/media_store/media_store_service_google_drive_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

`feat(cloud-storage): refuse a sign-in to a different account`

### Task 5: Strings

**Files:**
- Modify: `lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces:
  - `settings_cloudSync_status_signInNeeded`: "Sign-in needed"
  - `settings_cloudSync_signInNeeded_message(account)`: "{account} needs you to sign in again."
  - `settings_accounts_differentAccount_title`: "That's a different account"
  - `settings_accounts_differentAccount_body(expected, signedIn)`: "Submersion uses {expected}, but you signed in as {signedIn}."
  - `settings_accounts_differentAccount_nothingSynced(signedIn)`: "Nothing was synced, and {signedIn} was not connected."
- Reuses: `settings_accounts_signInAgain`, `settings_setUpDevice_notNow`.

"Submersion uses" replaces the mockup's "Sync uses", since the account may be the backup copy's alone.

- [ ] **Step 1: Insert the keys in every ARB**

The ARBs are feature-grouped, so anchor on a neighbour: the status key after `settings_cloudSync_status_syncError`, the rest after `settings_accounts_signInAgain`. Script it in python3.14 with a UTF-8 locale. Metadata with placeholders goes in `app_en.arb`. Real translations in all 10 locales.

- [ ] **Step 2: Regenerate and verify**

Run: `flutter gen-l10n && git diff --stat lib/l10n/arb/`
Expected: every `app_localizations_XX.dart` changed, and none holds the English text. Check with `grep -c "Sign-in needed" lib/l10n/arb/app_localizations_de.dart`, which must print 0.

- [ ] **Step 3: Commit**

`i18n(settings): strings for sign in again`

### Task 6: The shared action

**Files:**
- Modify: `lib/features/settings/presentation/widgets/accounts/account_sign_in.dart`
- Modify: `lib/features/settings/presentation/widgets/cloud_provider_authenticate.dart`
- Modify: `lib/features/settings/presentation/widgets/dropbox_connect_dialog.dart`
- Modify: `lib/features/settings/domain/data_health/feature_health.dart`
- Create: `lib/features/settings/presentation/providers/sign_in_again_providers.dart`
- Create: `lib/features/settings/presentation/widgets/accounts/sign_in_again.dart`
- Create: `lib/features/settings/presentation/widgets/accounts/sign_in_again_button.dart`
- Test: `test/features/settings/presentation/widgets/accounts/sign_in_again_test.dart`, `test/features/settings/presentation/widgets/accounts/account_sign_in_test.dart` (extend or create), `test/features/settings/presentation/widgets/dropbox_connect_dialog_test.dart`

**Interfaces:**
- Consumes: `authenticateAs`, `CloudAccountMismatchException`, `completeAuthorization(expectedAccount:)`, `backupCopyGroupOf`.
- Produces:
  - `signInToGroup(context, ref, group, {webdavCheck, String? expectedAccount, ValueChanged<String>? onDifferentAccount})`
  - `authenticateWithBrowserWait(..., {Future<void> Function()? signIn, debugForceBrowserWait})`, defaulting to `cloudProvider.authenticate`
  - `DropboxConnectDialog({provider, openUri, expectedAccount, onDifferentAccount})`
  - `bool offersSignInAgain(FeatureHealth)`: reason is `syncSignedOut` or `backupCloudSignIn`
  - `signInAgainGroupProvider`: `FutureProvider.autoDispose.family<AccountGroup?, DataFeature>`. Sync reads `accountGroupsProvider`'s `.syncing`; backup reads `backupCopyGroupOf(backupCopyTargetProvider)`. Null when the kind has no sign-in: `icloud`/`adobeLightroom`, Google without `googleDriveAvailableProvider`, Dropbox without `dropboxConfiguredProvider`.
  - `Future<void> signInAgain(BuildContext context, WidgetRef ref, AccountGroup group)`
  - `SignInAgainButton({required DataFeature feature, required ValueChanged<AccountGroup> onPressed, bool filled = false})`: a `ConsumerWidget` that renders nothing while the group is null or sync is running

- [ ] **Step 1: Write the failing tests**

With a fake sign-in, a fake sync notifier and a fake backup notifier:
- `same account signs in, clears the auth failure and syncs`
- `one account used by sync and the backup copy retries both, sync first`
- `a backup-only account does not sync`
- `cancelled changes nothing`; `a failed sign-in does not retry`
- `a different account shows the dialog, names both, and does not sync or back up`
- `Not now closes it; Sign in again runs the sign-in again`
- `a second tap while running starts no second sign-in`
- Group provider: each kind that returns null; Google with and without availability.
- Button: renders for a group; nothing while syncing; nothing for null.
- Dropbox dialog: a mismatch calls `onDifferentAccount` and pops false, showing no connect error.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/settings/presentation/widgets/accounts/`
Expected: FAIL.

- [ ] **Step 3: Implement `sign_in_again.dart`**

```dart
Future<void> signInAgain(BuildContext context, WidgetRef ref, AccountGroup group)
```

In order:
1. Return if a library-private `_running` is set; set it and clear it in `finally`.
2. Before signing in, read which retries apply: `retrySync` when `(await ref.read(accountGroupsProvider.future)).syncing?.key == group.key`; `retryBackup` when `backupCopyGroupOf(await ref.read(backupCopyTargetProvider.future))?.key == group.key` and `backupSettingsProvider`'s `lastCloudCopyMissing` is set.
3. `signInToGroup` with `expectedAccount: group.rows.first.accountIdentifier` and `onDifferentAccount` capturing the other account.
4. On a captured account, show `_showDifferentAccountDialog`; on **Sign in again** repeat from step 3.
5. On `false`, or `!context.mounted`, return.
6. `syncStateProvider.notifier.refreshState()`, then `syncFailureProvider.notifier.clearFor(providerId)`.
7. `await runSyncNow(context, ref)` when `retrySync`, then `backupOperationProvider.notifier.performBackup()` when `retryBackup`.

`_signInGoogle` passes `signIn: provider is GoogleDriveStorageProvider ? () => provider.authenticateAs(expectedAccount) : null` to `authenticateWithBrowserWait`. It uses `is` rather than a cast because tests override that provider family with fakes. It catches `CloudAccountMismatchException` ahead of its generic catch, calling `onDifferentAccount` and returning false. `_signInDropbox` passes both through to the dialog. The dialog catches the mismatch ahead of `on CloudStorageException`, calls `onDifferentAccount` and pops false. `_recordIdentity` runs only on a true result, as it does today.

- [ ] **Step 4: Run them to see them pass**

Run: `flutter test test/features/settings/presentation/widgets/accounts/ test/features/settings/presentation/widgets/dropbox_connect_dialog_test.dart test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

`feat(settings): one Sign in again action for sync and backup errors`

### Task 7: The three surfaces

**Files:**
- Modify: `lib/features/settings/presentation/widgets/data_health/data_health_strip.dart`
- Modify: `lib/features/settings/presentation/pages/cloud_sync_page.dart:120-217`
- Modify: `lib/features/backup/presentation/widgets/backup_status_line.dart`
- Test: `test/features/settings/presentation/widgets/data_health/data_health_strip_test.dart`, `test/features/settings/presentation/pages/cloud_sync_page_test.dart`, `test/features/backup/presentation/widgets/backup_status_line_test.dart` (new)

**Interfaces:**
- Consumes: `offersSignInAgain`, `SignInAgainButton`, `signInAgain`, `syncHealthProvider`, `backupHealthProvider`, the Task 5 strings.

- [ ] **Step 1: Write the failing tests**

- Strip: `a syncSignedOut line shows Sign in again`; `the rest of the line still opens the page`; `a backupFailed line shows no button`; `no button when the group is null`.
- Strip: `the retry runs after the attention line has gone`: `signInAgain` driven from the strip's `ref` and `context`, with the health flipping to healthy while the fake sign-in is awaited, still reaches `runSyncNow`.
- Card: `shows Sign-in needed with the account's name and the button`, for `SyncStatus.error` and for `idle` after a restart; `shows neither while syncing`; `an iCloud account keeps its title and shows no button`; `the rest of the card opens Troubleshoot Sync`.
- Backups line: `backupCloudSignIn` shows the health text and the button; every other reason renders as today.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/settings/presentation/widgets/data_health/data_health_strip_test.dart test/features/settings/presentation/pages/cloud_sync_page_test.dart test/features/backup/presentation/widgets/backup_status_line_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

The action must outlive its button, because signing in removes the attention line. So it runs from a widget that stays: `DataHealthStrip` passes `onPressed: (group) => signInAgain(context, ref, group)` from its own `context` and `ref` into `_AttentionLine`. `_CloudSyncPageState` does the same. `BackupStatusLine` stays mounted, so it can use its own.

- `_AttentionLine`: when `offersSignInAgain(health)`, add a `SignInAgainButton(feature: health.feature, onPressed: ...)` after the `Expanded` text.
- Card: `needsSignIn = ref.watch(syncHealthProvider).reason == HealthReason.syncSignedOut && syncState.status != SyncStatus.syncing`. Then the title is `settings_cloudSync_status_signInNeeded`; the message is `settings_cloudSync_signInNeeded_message(group.label)` when `signInAgainGroupProvider(DataFeature.sync)` has a group, otherwise `syncState.message`; `onTap` and the chevron apply as for an error; and `SignInAgainButton(filled: true)` sits below the title row.
- `BackupStatusLine`: for `backupCloudSignIn`, `title` is `healthReasonText(...)` and `trailing` is the button.

- [ ] **Step 4: Run them to see them pass**

Run: the Step 2 command, plus `flutter test test/features/settings/ test/features/backup/presentation/ test/shared/ test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

`feat(settings): offer Sign in again on sync and backup errors`
