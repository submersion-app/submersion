# Share a backup from the history

Issue: #3650. Release: v1.8.4.

## Why

The backup history (Settings > Backups) lets a diver restore, pin or delete a
backup, but not send one anywhere. Today the only way to get a backup off the
device is "Save a backup file", which makes a brand-new backup. The diver who
asked wants to move a backup they already have: texting it to one of their
own other devices, and now and then emailing it to themselves as an extra
copy. So this is about moving a backup the diver owns to places the diver
owns; sending to someone else is possible but not the main case.

## Goals

- Every row in the backup history gets a menu item that opens a small sheet
  offering **Save to folder** and **Share**, the same two choices the
  existing "Save a backup file" sheet offers.
- Works whether the backup is on this device (a plain path or an Android SAF
  `content://` document) or only in the cloud.
- An encrypted backup (`.sbe`) goes out exactly as it is, with no password
  prompt. Decryption happens only when it is restored.
- A cloud-only backup is downloaded to a temporary copy for the action and
  never becomes a history entry or a new backup.

## Non-goals

- No new backup is made. Nothing is added to or changed in the history.
- No size warning for email limits. If a mail app refuses a large file, its
  own error is what the diver sees.
- No editing of the backup's note.
- Making protected pre-update copies portable (bundling their key file, or
  re-encrypting them as `.sbe`) is out of scope.

## Anti-goals

- A shared or saved file that is not byte-for-byte the backup in the history
  (no decryption, no re-encryption, no note re-stamping).
- A temporary download that shows up anywhere in the logbook or history.
- Deleting a share's temp copy before the receiving app has read it (see
  Cleanup).

## The menu item

- Added to the row's popup menu in `BackupHistoryTile`, between Restore and
  Delete.
- On iOS, macOS and Android it is labelled **Share** (share icon). On Windows
  and Linux, which have no share sheet, it is labelled **Save a copy**
  (save icon), and the sheet it opens shows only Save to folder. This mirrors
  how `ExportBottomSheet.show` already hides Share on those platforms.
- Disabled while a backup operation is in progress
  (`backupOperationProvider.status == inProgress`), as Back up now is, so two
  full-size file jobs never overlap.

## The sheet

The existing `ExportBottomSheet` is the model: drag handle, title, then the
Save to folder and Share list tiles with their current icons and subtitles.
For an existing backup:

- **No note field.** The backup already carries its note, and an encrypted
  file cannot be changed without its password.
- **Title** names the backup by its date and time, formatted with the diver's
  date/time settings (as the history row does).
- **Protected safety copy line.** When the record is a raw copy of the live
  database (`BackupType.preMigration` or `BackupType.preDowngrade`) and its
  file is in the SQLCipher-encrypted form, one line under the title says the
  copy was taken from the protected database and can only be restored on
  this device. Share and Save stay available. Detection, in order:
  1. The file is an `.sbe` (`BackupCrypto.isEncryptedBackup`): "Encrypt
     existing backups" can wrap a safety copy, and what is inside cannot be
     seen without the backup password, which this flow never asks for. The
     line is shown when database protection is on now (my call: the best
     available guess, and the combination is rare).
  2. Otherwise the file's header (`isEncryptedDatabaseFile` in
     `database_security_sidecar.dart`), not the current protection setting:
     the diver may have turned protection on or off since the copy was made.
     A header that is not plain SQLite means either protected or corrupt;
     either way it will not restore elsewhere, so the line is honest in both
     cases.
  When the file is not reachable without a download (cloud-only), the line
  is not shown; safety copies are local in practice.

Background, for the builder: database protection wraps a random master key in
a sidecar file next to the live database (password and recovery-code slots),
and derives the SQLCipher key from it. A pre-update copy is a raw byte copy of
the database file and never includes that sidecar
(`backup_service.dart`, `validateBackupFile`), and Restore from file rejects
SQLCipher-encrypted files (the rejection is in
`BackupOperationNotifier.restoreFromFilePath`, which calls
`validateBackupFile` without `allowLiveDatabaseEncryption`;
`BackupService.restoreFromFile` itself did no validation before this change).
So on another device neither the password nor the recovery code can open
it.

## Restore from file accepts a protected safety copy on this device

Without this, the line above would be untrue: today Restore from file rejects
any SQLCipher-encrypted file, so a saved or emailed protected safety copy
could not be restored anywhere, this device included. The diver chose to fix
that rather than only firm up the wording.

- `BackupOperationNotifier.restoreFromFilePath` validates with
  `allowLiveDatabaseEncryption: true`. A file with a plain SQLite header is
  validated exactly as today. A file with an encrypted header is opened with
  the live database key: it passes when that key opens it (a safety copy
  from this install's protected database), and fails otherwise.
- A failure of that kind gets a clear message rather than the generic
  "File is not a valid database": the copy came from a protected database
  this install has no key for (another device, or protection turned off and
  on again since), or the file is corrupt. Builder's wording, in the spirit of
  the existing message in `validateBackupFile` for a missing key.
- An `.sbe` whose plaintext turns out to be SQLCipher ciphertext (a safety
  copy wrapped by "Encrypt existing backups") must get the same treatment
  after decryption: `restoreFromFile` today runs no deep check on the
  materialized copy, so the builder adds one that allows the live key, as
  `_restoreFromSource` does for history rows.
- The swap itself needs no change: `DatabaseService.restore` already detects
  an encrypted source and skips re-encrypting it.
- Validation and any failure still happen before the pre-restore backup and
  before any swap, so a refused file has no side effects.

This is the same rule the history row already uses for its own safety
copies, extended to the same file picked from outside.

## Getting the file

Resolution order, matching `BackupService.restoreFromBackup`:

1. `localPath` is a SAF `content://` ref: stream it to a temp file with
   `BackupSafPort.readBackup`. If the document is gone, or its folder grant
   was revoked, fall through to the cloud copy below, as a missing plain
   local file does (one resolver now serves restore, Save and Share).
2. `localPath` is a plain path that exists: use it in place, no copy.
3. The cloud copy is reachable with the current account (`_cloudCopyHere`):
   download it with `downloadToFile` into the temp folder.
4. The cloud copy belongs to another account: throw
   `BackupCopyInOtherAccountException`, shown with the same message Restore
   uses.
5. Otherwise: the existing "Backup file not found locally or in cloud" error.

The download or SAF stream starts only after the diver picks Save or Share,
not when the sheet opens. While it runs, the backup operation state is
`inProgress` with a "preparing" message, as the current share export does. A
failure shows an error and leaves no partial file (the providers already
delete a partial download; a failed SAF stream is cleaned up as restore does).

A temp copy made for **Share** keeps the record's original filename, so the
receiving device sees which backup it is (`submersion_backup_<date>...db|sbe`,
or a pre-update copy's `<yyyyMMdd>-<HHmmssSSS>-v<n>-v<m>.db`). A temp copy
made for **Save to folder** is named with the existing `restore-<uuid>-`
prefix, so it can never overwrite (and then delete) a Share copy of the same
backup that is still waiting to be read; the original name is used only at
the destination. All these shapes already match `RestoreTempSweep`'s pattern
for bare files in the temp root (the builder should confirm the
pre-downgrade copy's name does too, and widen the pattern if not).

Demo mode: blocked with the same gate as exporting a backup
(`DemoModeGate.ensureNotDemo(DemoSealedFeature.backup)`).

## Save to folder

Same folder pick as "Save a backup file" today:

- Android: `SubmersionSaf.pickFolder()`, then write the file into the tree
  with `BackupSafPort.writeBackup`.
- Other platforms: `FilePicker.getDirectoryPath`, then copy the file to
  `<folder>/<original filename>`.

A file of the same name already in the folder is never overwritten:

- Android: the native `writeBackup` in
  `packages/submersion_saf/android/.../SubmersionSafPlugin.kt` deletes a
  same-name document before writing (so scheduled-backup retries do not pile
  up). That is dangerous here: if the diver picks the folder that already
  holds this SAF backup, the original document would be deleted and the
  history row's `content://` link would point at nothing. So `writeBackup`
  gains a replace flag (default: today's replace behaviour, unchanged for
  scheduled backups); Save to folder passes "do not replace", and the
  document provider's own collision renaming (`name (1).db`) applies. This
  is a native plugin change and is in scope.
- Other platforms: a numbered suffix before the extension.

## Share

`SharePlus.instance.share` with the file and the share anchor captured from
the tile before the sheet closes (iPad popover), as `saveBackupFile` does.

## Cleanup

- A temp copy made for **Save to folder** is deleted as soon as the copy
  finishes or fails.
- A temp copy made for **Share** is left in the app temp folder, and
  `RestoreTempSweep` deletes it once it is a day old. This is how the existing
  share export already works, and it is deliberate: some receiving apps
  (Gmail on Android, for one) read the attachment only when the diver finally
  presses Send, so deleting it when the share sheet closes can break the
  attachment.
- A backup used in place (a plain local path) is never touched.

## Strings

New strings go in `app_en.arb` with translations in every other ARB
(`ar de es fr he hu it nl pt zh`): the Share and Save a copy menu labels, the
sheet title, and the protected pre-update line. Existing strings are reused
for Save to folder, Share, their subtitles, and the error messages.

## Testing

TDD per the repo guide. At least:

- Service: resolving each source (local path in place, SAF stream, cloud
  download, other account, missing), and that nothing is added to the
  history.
- Service: an `.sbe` is returned byte-for-byte, with no password asked.
- Temp cleanup after Save to folder, success and failure.
- Widget: the menu item and its label per platform, disabled while busy; the
  sheet without a note field, its title, and the protected line shown only
  for an encrypted-header safety copy (and for an `.sbe` safety copy only
  while protection is on).
- Restore from file: a SQLCipher file the live key opens is accepted; one it
  does not open, or with no live key, is refused with the clear message and
  no pre-restore backup; plain files behave as before; an `.sbe` wrapping
  SQLCipher is deep-checked after decryption.
- SAF plugin: `writeBackup` with replace off leaves a same-name document in
  place (Kotlin side covered as far as the plugin's tests allow; the Dart
  channel call is unit-tested).

## Decided by the diver

- A small sheet with Save to folder and Share, not straight to the share
  sheet.
- Encrypted backups are shared as they are, no password prompt (from the
  issue).
- Cloud-only backups are downloaded to a temp copy that never appears in the
  logbook (from the issue).
- Protected pre-update copies are still shareable, with a line saying they
  restore only on this device.
- Restore from file is fixed to accept such a copy on this device when the
  live key opens it, so the line is true and an emailed copy restores here.

## Calls made in design (not raised by the diver)

- No note field on the sheet; the title carries the backup's date instead.
- Windows and Linux: "Save a copy", Save to folder only.
- Download starts after the choice, not when the sheet opens.
- Share temp copies are left for the day-old sweep; Save temp copies are
  deleted at once.
- The shared file keeps its original name.
- The protected line keys off the file header, not the current setting; for
  an `.sbe` safety copy it falls back to the current setting.
- The protected line covers pre-downgrade copies too, which are the same raw
  copy of the live database.
- Save to folder never overwrites a same-name file; on Android this needs a
  replace flag on the SAF plugin's `writeBackup`.
- Save's temp copy uses the `restore-<uuid>-` prefix so it cannot clobber a
  pending Share copy.
- Disabled while a backup operation runs; blocked in demo mode.
- No email size warning.

## Left to the builder

- Where the "get a shareable file for this record" logic lives (a new
  `BackupService` method in a part or sibling file is expected, since
  `backup_service.dart` is already 1924 lines, well past the repo's 800-line
  guidance, and should not grow further).
- Whether the sheet is a new widget or `ExportBottomSheet` gains options.
- The exact wording of new strings, within the meaning above.
- How a same-name file in the chosen folder is avoided.
