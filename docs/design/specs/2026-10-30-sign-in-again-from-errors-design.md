# Sign in again from sync and backup errors

Issue: #3811. Release: v1.8.4.
Mockup: [assets/2026-10-30-sign-in-again-from-errors-mockup.html](assets/2026-10-30-sign-in-again-from-errors-mockup.html).

## Intent

When a connected cloud account stops working (access never granted, a grant
revoked, a key changed), sync and backup show an error with no way to act on
it. The diver has to find the account in Settings, and a ScubaBoard reporter
got out of it only by deleting the connection and adding it back. This feature
puts a **Sign in again** action on the error, which runs the existing sign-in
and then retries.

This is rare: roughly once per affected diver. It matters because sync stays
stuck until the diver finds the way out. The design therefore reuses what
exists and adds as little as it can.

## What the code does today

The issue is out of date in three places. The design follows the code.

- **Sync hides these failures.** `SyncService` turns every
  `CloudStorageException` into `SyncResultStatus.networkError`
  (`sync_service.dart:1071`), so a Drive 403 or a Dropbox "authorization
  expired" is recorded as `SyncFailureKind.network`. A network failure never
  shows as failing, and shows at all only a week after the last good sync.
- **Backup discards the reason.** `_copyToCloud` catches the upload error and
  logs it. `_getOrCreateCloudBackupFolder`, usually the first request, swallows
  it too. Only `lastCloudCopyMissing` survives.
- **There is no Sync Now snackbar.** A failed sync shows only in the Cloud Sync
  status card.

`signInToGroup` (`account_sign_in.dart:42`) already runs the right flow for
Google, Dropbox, own servers and Git.

## Goals

1. A refused sign-in or refused access is told apart from every other cloud
   failure, for sync and for the backup's cloud copy.
2. Sync shows it at once as failing, not as being offline.
3. Sign in again appears on the error itself, and a success retries the work.
4. One sign-in clears the problem everywhere that account is used by sync and
   the backup copy.
5. Reconnecting with a different account never syncs into that account.

## Non-goals

- Shared libraries and the media store. They have their own error paths and
  reconnect flows.
- The Home sync chip, which shows no sync errors today and still shows none.
- A new snackbar. The status card is where a failed Sync Now is reported.
- Telling a diver which Google scope is missing. #3753 already words that at
  sign-in time.
- Changing what counts as a network failure, beyond taking refusals out of it.
- Letting a device hold two Google or two Dropbox accounts.
- Making a scheduled backup's Google Drive copy work. It has no session in that
  isolate today, and still has none.
- Guarding the account page's own Sign in again. It stays as it is, and is the
  deliberate way to change accounts.

## Anti-goals

- Signing a diver out because of an outage. A 5xx, a timeout or a quota error
  must never read as a sign-in problem.
- Matching on message text. `S3MediaObjectStore._map` already classifies by
  substring, and the S3 client keeps provider words out of its messages for
  that reason.
- A one-tap action that moves a library into the wrong account.

## Classifying a refusal

`CloudStorageException` gains a typed signal, `accessRefused`, false by
default. `WebDavException` and `GitException` already subclass it with their
own codes, so it is a property subclasses can override rather than a new
subclass.

| Provider | Refused | Not refused |
| --- | --- | --- |
| Google Drive | A sign-in that expired and found no grant to refresh from; a 403 whose reason is `insufficientPermissions`, `insufficientFilePermissions`, `ACCESS_TOKEN_SCOPE_INSUFFICIENT` or `authError` | `_requireApi`'s not-authenticated error, a refresh that threw (an outage looks like this), `storageQuotaExceeded`, rate-limit reasons, any other 403 |
| Dropbox | The second 401; a 400 or 401 refusing the refresh token (`dropbox_auth_manager.dart:205`) | Not connected, 429, insufficient space, could not reach |
| S3 | 403, except `RequestTimeTooSkewed` | `AuthorizationHeaderMalformed`, 404, 5xx |
| WebDAV | `unauthorized`, `forbidden` | Everything else |
| Git | `unauthorized`, `forbidden` | `rateLimited` (a 403 with Retry-After), everything else |
| iCloud | Never | Its Apple ID is managed by the system |

The Google list is an allowlist: a 403 reason it does not name keeps today's
behaviour.

**A refusal means a server refused.** Having no session here is a different
thing. Google Drive has none in the scheduled-backup isolate
(`headless_cloud_provider.dart`), and `_requireApi` would throw on every
scheduled backup for a healthy account, so it must not count. A device that
really is signed out is already known from `isAuthenticated`, which sync checks
first and which the account's status reflects.

## Sync

- `SyncService.performSync`: a `CloudStorageException` with `accessRefused`
  returns `SyncResultStatus.authError` with its message, ahead of the existing
  `networkError` mapping.
- `ChangesetReader`: a refusal rethrows out of the per-peer catch
  (`changeset_reader.dart:389`). Otherwise it is filed as one bad peer and the
  sync reports a clean finish. Cursors already written stay written.
- `SyncFailureKind` gains `auth`. `_runSyncOnce` records it for a refused
  `authError` and for a refused exception reaching its outer catch. An
  `authError` that only means no session here is recorded as `network`: being
  signed out is read live from `isAuthenticated`, and a stored `auth` would
  outlive an offline cold launch.
- `evaluateSyncHealth`: a current `auth` failure gives
  `HealthReason.syncSignedOut`, failing, the same as `!authenticated`. One
  reason means one line, one button, and no new Data health text.
- Dropbox and S3 answer `isAuthenticated` from stored credentials, so `auth`
  is what makes a refusal visible for them.
- A record with an unknown kind already reads as no failure
  (`sync_failure_store.dart`), so a downgrade is safe.

## Backup

- A failed copy records why, in a new `lastCloudCopyNeedsSignIn` preference
  written beside `lastCloudCopyMissing`. Every backup overwrites both.
- It is set only when the upload failed with `accessRefused`, and cleared by a
  sign-in to the copy's account from anywhere, as well as by the next backup.
- `_getOrCreateCloudBackupFolder` must let the reason out for the upload path.
  Its other callers keep their behaviour.
- `HealthReason` gains `backupCloudSignIn`, level attention. It applies while
  the last copy is missing and either the flag is set, or the copy's account
  reads `AccountStatus.needsSignIn` here. The second case is read when the
  screen is built, in the foreground, so it needs no stored state and is
  untouched by the scheduled-backup isolate.
- Its text is the existing `dataHealth_backup_cloudCopyMissing`, since the
  button says the rest.
- It outranks `backupAutoOff`, `backupOverdue` and `backupNever`, which means
  checking it before the early return in `evaluateBackupHealth` and listing it
  first among the attention candidates. `pickHealth` keeps the first candidate
  at the top severity. Without this, a diver who backs up by hand never sees
  the action. `backupFailed` still outranks it.

## The Sign in again action

One shared action, offered when:

- the feature's account group resolves (sync: `groups.syncing`; backup:
  `CopyFollowsSync.group` or `CopyToAccount.group` from
  `backupCopyTargetProvider`), and
- its kind has a sign-in here (not iCloud or Lightroom), and
- `canSignInOnThisBuild` allows it, and
- sync is not running.

Otherwise the error reads as it does today, and tapping it opens its page.

What it does:

1. Runs the account's sign-in, as `signInToGroup` does. For Google and Dropbox
   the row's `accountIdentifier` goes with it as the expected account (see
   below).
2. On success, clears the current `auth` failure for that provider.
3. Retries **everything this account is failing**: a sync through
   `runSyncNow` when it is the sync account (so the replaced-library and
   first-contact gates still apply), and a backup through
   `BackupOperationNotifier.performBackup` when it is the copy's account and
   `lastCloudCopyMissing` is set.

One tap therefore clears both lines when sync and the copy share an account.

Outcomes:

| Outcome | What the diver sees |
| --- | --- |
| Signed in | Sync runs and the error clears |
| Cancelled | Nothing changes |
| Sign-in fails | The existing red snackbar from `signInToGroup` |
| Different account | The dialog below |

The action must not depend on the widget that started it. Signing in removes
the attention line, so a `BuildContext` or `WidgetRef` held by that line is dead
by the time the retry runs. It must also ignore a second tap while it runs:
two OAuth flows would race.

## Different account

Applies to Google Drive and Dropbox, whose rows are keyed by provider, so a
device holds exactly one of each (`account_identity.dart:44`).

`firstSyncMergeInfo` returns early for an established provider
(`sync_providers.dart:1138`), and the provider id says nothing about the
account. A device that has synced would go straight into the other account's
Drive with no prompt.

**The wrong account is refused before anything of it is kept.** Comparing after
sign-in and then signing out would leave a window: the wrong client is live
during the sign-out, returning from the browser fires `_maybeSyncOnResume`
(`app.dart:358`), and a failed sign-out would leave it installed. So the check
runs where the account first becomes known, before any session is stored:

- **Desktop Google:** in `DesktopOAuthAuthenticator.authenticate`, beside the
  `_grantsDrive` check, from the id token, before `_tokenStore.save` and
  `_installClient`. Because it lives here, a flow the diver cancelled in the app
  but finished later in the browser is checked as well.
- **Mobile and macOS Google:** in `GoogleSignInAuthenticator.authenticate`, from
  `account.email`, before `authorizeScopes` and `_installClient`. The SDK has
  already switched its own current user by then, so it calls
  `_googleSignIn.signOut()` before refusing. Otherwise the next cold launch's
  lightweight sign-in could return the wrong account. A failure of that call is
  logged and does not change the outcome. The refused account was never
  authorized, so it has no Drive client to reach.
- **Dropbox:** in `DropboxAuthManager.completeAuthorization`, comparing
  `email ?? displayName`, before `_store.save`. The dialog that hosts it returns
  the mismatch rather than showing it as a connect failure. The refused token is
  revoked, best effort. Google's is not: its revoke ends the account's whole
  grant, which would sign out another device using that account on purpose.

Rules:

- Compare trimmed and ignoring case. If either side is missing or empty,
  there is nothing to compare, so carry on.
- A mismatch throws a typed exception carrying the account that signed in. It
  is a `CloudStorageException` subclass, so the existing handlers stay safe.
- The diver's row and identity are untouched, and so is the session held in the
  running app, so the error and its button stay in place and no automatic sync
  can reach the other account. On mobile and macOS Google the session does not
  outlive a restart: the SDK has already switched user and has no way back, and
  signing it out means the expected account signs in again rather than the next
  cold launch returning the wrong one.
- The expected account is passed per call, so the account page's Sign in again
  and the set-up flows behave as they do today.

Dialog: title "That's a different account"; body naming both accounts and
saying nothing was synced and the other account was not connected. Buttons:
**Not now** (close) and **Sign in again** (run the action again).

There is no "use this account" button. It would be the same silent move into
another Drive.

## Surfaces

1. **Settings > Data, attention lines.** Sync and backup lines get a trailing
   text button. The rest of the line still opens the feature's page. The strip
   is hidden in demo mode, so demo mode needs nothing further.
2. **Cloud Sync status card.** When sync health is `syncSignedOut` and sync is
   not running: title "Sign-in needed", message "{account} needs you to sign in
   again.", and a filled Sign in again button when the action is offered. It
   reads the health provider rather than `SyncStatus`, so it also shows after a
   restart, when the status starts as idle. The rest of the card opens
   Troubleshoot Sync, as an error does today.
3. **Backups page status line.** For `backupCloudSignIn` it shows the health
   text with the same button.

The Data page's Sync and Backups rows do not get their own button. The
attention line sits directly above them, so a second button would repeat it.

## Strings

- New: the card title and message, the dialog title and body, and "Not now" if
  no suitable key exists.
- Reused: `settings_accounts_signInAgain`, `dataHealth_sync_signedOut`,
  `dataHealth_backup_cloudCopyMissing`.
- All in every locale, following the repo's ARB conventions.

## Tests

- Each row of the classification table, including the "not refused" column:
  this is the safety net against signing divers out over an outage.
- `SyncService` maps a refusal to `authError`; `ChangesetReader` rethrows one
  and still isolates an ordinary peer failure.
- Health: `auth` gives `syncSignedOut`; a later good sync clears it; `network`
  is unchanged.
- Backup: the flag is set for a refusal and for signed-out, not for an outage,
  and the next good backup clears it.
- The action: each outcome; one tap retries both when the account is shared;
  neither runs twice on a double tap; the retry still runs after the button is
  gone.
- Different account, for each authenticator: nothing is stored or installed,
  the existing session survives, the row's identity is unchanged, and no sync
  runs. Mobile also signs the SDK out. No expected account keeps today's
  behaviour.
- A health check that a scheduled backup's "no session" failure does not set the
  sign-in flag, and that the reason outranks auto-off, overdue and never.
- Widgets: the three surfaces, with and without the action offered.

## Left to the builder

- The exact name and shape of the `accessRefused` signal.
- How the action outlives its widget (root navigator context, a notifier, or
  another way).
- Whether the shared logic returns a sealed outcome type alongside
  `signInToGroup`, or extends it.
- How the expected account reaches the authenticators. `CloudStorageProvider`
  is shared by every provider, so it need not grow a parameter for two of them.
- How `_getOrCreateCloudBackupFolder` lets the reason out.
