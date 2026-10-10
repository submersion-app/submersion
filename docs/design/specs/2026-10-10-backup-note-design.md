# Backup notes

Date: 2026-10-10
Release: v1.8.2

## Problem

Every manual backup looks the same in the history list: a timestamp, dive and
site counts, and a size. A diver who backs up before a risky change ("before
merging duplicate sites") or before a trip has no way to tell those snapshots
apart later, and a backup file that has travelled to another device or through
a share sheet carries no description at all.

## Goal

Let the diver attach an optional free-text note when using **Backup Now** or
**Export Backup**, and show that note wherever a backup is chosen for restore.

Success:

- A note typed at backup time appears in the Backup History row, in the
  restore confirmation dialog, and on the Unrecognized backups page.
- The note travels inside the backup file, so a file restored on another
  device or after a reinstall still shows it (plaintext `.db` files).
- Skipping the note costs nothing more than one dialog confirmation.

## Decisions

| Question | Decision |
| --- | --- |
| Where the note lives | On the history record AND inside the backup file |
| How it is entered | A dialog before Backup Now; a field in the Export sheet |
| Editable later | No. Fixed at creation, so record and file never disagree |
| Where it is shown | History rows, restore confirmation dialog, Unrecognized backups page |

## Storage

### In the file: a `backup_info` table

Every backup path produces a plaintext staging copy through
`BackupDatabaseAdapter.backup(path)` (a `VACUUM INTO` or a SQLCipher export)
before any encryption or streaming. The note is stamped into that copy:

- `DROP TABLE IF EXISTS backup_info` always runs, so a table inherited from a
  previously restored backup can never leak into a new one.
- For a non-blank note: `CREATE TABLE backup_info (key TEXT PRIMARY KEY, value
  TEXT NOT NULL)` and insert `('note', <note>)` with a bound parameter.

The table is not part of the Drift schema. Nothing in `lib/` enumerates every
table, and Drift migrations ignore unknown tables, so a restore of a stamped
file is unaffected.

Rejected alternatives: a sidecar file (lost on Share/AirDrop, SAF and cloud
upload, and a new orphan kind) and the filename (length and charset limits,
personal text in shared cloud listings, and `backup_attribution` owns the
name's shape).

### New unit: `lib/features/backup/data/services/backup_note_stamp.dart`

- `String? normalizeBackupNote(String? note)`: trims, returns null when blank,
  caps at `maxBackupNoteLength` (200) characters.
- `void stampBackupNote(String path, String? note)`: opens the plaintext copy
  read-write via `DatabaseService.openRaw`, drops and optionally recreates the
  table. Throws on failure.
- `String? readBackupNote(String path)`: returns null for an encrypted backup
  (`BackupCrypto` magic), a missing, corrupt or table-less file. Opens
  read-only. Never throws.

### On the record

`BackupRecord` gains `String? note` in the constructor, `copyWith`,
`toJson`/`fromJson` (an absent key reads as null, so existing history loads
unchanged) and `props`.

### Threading through the service

- `BackupService.performBackup({bool isAutomatic, String? note})` passes the
  note to `_performBackupInto`, which stamps it via the target (plaintext
  branch) or onto the plaintext temp before `encryptFile` (encrypted branch),
  and stores it on the record.
- `BackupTarget.write(adapter, fileName, {String? note})`: both
  `FilesystemBackupTarget` and `SafBackupTarget` stamp right after
  `adapter.backup(...)`, before measuring size or streaming.
- `exportBackupToPath(path, {String? note})` stamps the destination (plaintext)
  or the plaintext temp (encrypted), and stores the note on the record.
- `exportBackupToTemp({String? note})` stamps the temp copy before encryption.
- Automatic, pre-migration and pre-downgrade backups pass no note. Automatic
  backups still go through the drop.

### Restore hygiene

After a successful swap, `_replaceDatabaseAndRebaselineSync` drops
`backup_info` from the live database (best effort, logged on failure), so a raw
pre-migration byte copy or the next `VACUUM INTO` cannot carry an old note
forward.

### Records per route

Backup Now and the desktop/iOS Export to file save the note on their history
record, as they save a record today. Android SAF export and Share still write
no record; for them the note lives only inside the file.

## UI

### Entering the note

- **Backup Now** opens `BackupNoteDialog`: title "Back up now", one optional
  text field ("Note (optional)", hint "e.g. Before the Cozumel trip", single
  line, sentence capitalization, 200-character limit with counter), Cancel and
  Back Up actions. Enter submits. The dialog's result distinguishes Cancel (no
  backup) from an empty note (backup without a note).
- **Export Backup**: `ExportBottomSheet` becomes stateful with the same note
  field under its title. `onSaveToFile` and `onShare` receive the normalized
  note, and all three export routes (desktop/iOS folder pick, Android SAF
  folder, Share) pass it on.
- `BackupOperationNotifier`: `performBackup({note})`,
  `exportToPath(path, {note})`, `exportToSafTree(..., note)` and
  `exportForSharing({note})` hand it to the service.

### Showing the note (only when non-blank)

- **History rows** (`BackupHistoryTile`): the note on its own line above the
  existing counts and size subtitle, two lines maximum, ellipsized.
- **Restore confirmation dialog**: the note in the details card under the date.
  History restores read it from the record. Import reads it with
  `readBackupNote(filePath)` into the temporary record. An encrypted file shows
  no note.
- **Unrecognized backups page**: `UnrecognizedBackup` gains `note`, filled by
  `OrphanedBackupScan` via `readBackupNote`; the row shows it under the
  filename.

### Strings

New `backup_note_*` keys in `app_en.arb` (dialog title, field label, hint,
confirm action), translated into every locale ARB. Cancel reuses the existing
cancel string.

## Error handling

- Stamping is part of producing the backup: a stamp failure fails the backup
  through the existing error state, and the encrypted branches still delete the
  plaintext temp in their `finally`.
- Reading never fails an operation: `readBackupNote` returns null and the
  caller carries on without a note.
- The live-database drop after restore is best effort and never turns a
  successful restore into an error.
- Notes are stored with a bound parameter only.

## Testing

- `backup_note_stamp_test`: round trip; restamp with null removes the table;
  inherited table replaced; blank and overlong notes normalized; encrypted,
  garbage and missing files read as null.
- `backup_record_test`: JSON round trip keeps the note; old JSON loads as null.
- `backup_service_test`: Backup Now, export to path and export to temp embed
  the note and record it; encryption on keeps it through encrypt and decrypt;
  an automatic backup from a stamped source has no note; restore drops the
  table from the live database.
- `backup_target_test`: filesystem and SAF targets stamp.
- Widget tests: dialog Cancel, empty and note results; export sheet passes the
  note to both callbacks; history tile and restore dialog show and hide the
  note; unrecognized backups row shows it.
- `orphaned_backup_scan_test`: note filled for a plaintext orphan.

## Out of scope

- Editing a note after the backup is made.
- Reading notes from cloud listings before download.
- Reading the note of an encrypted `.sbe` before it is decrypted.
