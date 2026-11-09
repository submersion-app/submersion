# Back up to several cloud accounts at once (issue #3782)

## Why

A diver with Google Drive and Git both connected can send the backup copy to
one of them only. Backups are insurance; a second copy in a different service
covers the day the first service loses the file, locks the account, or is
signed out on this device. Sync from several backends stays out of scope: the
maintainer ruled it out because merging several sources is a different and
much harder problem. This is about backups only.

The design questions were skipped at the maintainer's request, so every
decision below is the builder's call unless the issue states it.

## Goals

- A backup can be copied to any number of connected accounts at once.
- Today's copy keeps working exactly as before. Divers who never add a second
  account see no change.
- A failed copy to one account never fails the backup, the other copies, or
  the local file.
- Old backups leave every account they were copied to, not just the first.
- A backup can be restored, saved or shared from any account it reached.

## Non-goals

- Syncing from several accounts.
- Listing the backups of every account in history. History, pin markers,
  cross-device retention and the orphan scan keep working on the main copy's
  folder only.
- A per-account retention count. Every account keeps what this device keeps.
- Changing the device setup wizard. It still offers the one copy.

## The model (builder's call)

The existing copy stays the **main copy**: `BackupSettings.copyAccountId` /
`copyAccountKind`, null to follow sync, or pinned to a roster row, with all its
rules. Added beside it:

- `BackupSettings.extraCopyAccounts`: an ordered list of `(accountId, kind)`
  roster rows, the **extra copies**. Stored in SharedPreferences
  (`backup_extra_copy_accounts`, a JSON list), device-local like the main
  copy's pin.
- Extra copies run only while the main copy is on (`cloudBackupEnabled`).
  Turning the copy off keeps the list but sends nothing; the Backups page hides
  the extra rows while the copy is off.
- An extra account that is also where the main copy goes (chosen as the main
  copy later, or the sync account the main copy follows) is skipped, so one
  account never receives the same backup twice. Choosing an extra account as
  the main copy removes it from the list.

## Writing a backup

After the main copy, the same stored bytes (the plaintext export, or the
`.sbe` when backup encryption is on) are uploaded to each extra account's
`Submersion Backups` folder in list order, with the same rules as the main
copy: sync encryption frames the upload and fails closed when this device is
locked, and a refused account is noted as needing sign-in. Each upload is
isolated: its failure is logged and the next one runs.

`BackupRecord` gains `extraCloudCopies`, a list of `(accountId, fileId)` for
the uploads that returned a file id. `location` keeps describing the local
file and the main copy only.

`BackupSettings` gains `lastExtraCopyMissingIds`: the extra accounts the most
recent backup did not reach, rewritten by every backup.

The service is handed its extra destinations when it is built, as
`(accountId, CloudStorageProvider?)` pairs, fixed for its lifetime like the
main copy's provider. A null provider (a row the roster no longer has, or no
adapter for the kind) means that account is missed. The foreground builds each
provider the way `backupCopyProviderProvider` builds a pinned one; the
scheduled backup builds each the way `resolveHeadlessBackupCopyProvider`
builds a pinned one.

## Removing old backups

When a record is removed, by pruning or by Delete, each of its extra copies
whose account is still an extra destination with a provider, or is now where
the main copy goes, is deleted there (and pushed, on a backend that defers
deletes). The destinations are built while the copy is off too, so pruning
then still deletes old copies. A copy whose account is no
longer reachable is left where it is and forgotten, with a log line: the app
cannot reach it, and keeping the record would keep a local file the diver
asked to prune. Extra copies never count toward retention.

A record kept cloud-only because the main folder could not be listed keeps its
extra copies until it is finally removed.

## Restore, Save and Share

The resolution order becomes: local file (or SAF document), main copy, then
the first extra copy whose account is reachable. The "copy is in another
account" error is raised only when no copy can be reached.

## Encryption changes

- Re-encrypting existing backups re-uploads each extra copy whose account is
  reachable, deletes the old object when the id changed, and resets history on
  backends that keep it. An extra copy that cannot be reached, or whose old
  object cannot be deleted, counts the record as failed (a residual plaintext
  copy is disclosed, never hidden).
- Deleting plaintext cloud backups when encryption is turned on clears each
  extra account's folder as well as the main one.

## Telling the diver

- **Backups page:** below "Copy to {account}", while the main copy names an
  account, one row per extra account: "Also copy to {account}", its sign-in
  state as the subtitle (or "The last backup did not reach this account" when
  it is in `lastExtraCopyMissingIds`, or "The copy's account was removed" when
  the roster lacks it), and a Remove action. Below them, "Copy to another
  account too" opens the account sheet, offering the sync-capable accounts that
  are not already a destination. Google Drive and iCloud sign in once per
  device, so a second destination of either kind is not offered.
- **Settings > Data health:** when the main copy arrived but an extra one did
  not, attention: "Last backup did not reach every account". A missing main
  copy keeps its existing, stronger message.
- **Scheduled backup notification:** a missed extra copy counts as a missing
  copy.
- **Account detail page:** an account that receives extra copies lists the
  backup copy among its uses. Signing out of or removing it drops it from the
  extra list.

## Left to the builder

File layout (the service is far past the size guideline, so the extra-copy
logic goes in its own part file), naming, and test layout.
