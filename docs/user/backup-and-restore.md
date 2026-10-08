# Backup and Restore

A backup is a point-in-time snapshot of your whole dive logbook in a single
file. Keep the file wherever you like, share it, or use it to roll back to an
earlier state of your data.

> [!NOTE]
> **Where to find it:** **Settings > Data > Backup & Restore**.

<!-- screenshot: images/backup-and-restore/backup.png: backup and restore page -->

## What a backup contains

A backup is a copy of Submersion's database. It includes every dive, site, trip,
buddy, piece of equipment, sighting, diver profile and everything else the app
stores in its log. Device settings such as cloud-sync credentials are not stored
in the database and are not included.

A plain backup is a `.db` file named with the date, such as `submersion_backup_YYYY-MM-DD.db` for an exported one (automatic backups add the time); an encrypted one
ends in `.sbe` (see [Backup encryption](#backup-encryption)).

## Creating a backup

Tap **Export Backup**. A sheet offers two options:

- **Save to File:** choose where to save the backup, such as a folder, a cloud
  drive, or a connected disk.
- **Share:** send the file through the system share sheet (AirDrop, email, other
  apps). Not available on Windows and Linux, which have no share sheet.

When the export finishes, a message confirms it with the file's size.

**Backup Now**, in the **Automatic Backups** section, makes a backup straight
away into your backup location.

## Restoring from a backup

Tap **Restore from File** and pick a backup (`.db`, `.sqlite` or `.sbe`).
Submersion checks that the file is a Submersion database before going any
further. An encrypted backup asks you to **Unlock encrypted backup** with its
password or recovery code.

A confirmation shows the backup's date, its dive and site counts, and its size.
If the backup came from a different version of the app, the dialog says so.
Before the restore runs, Submersion saves a safety backup of your current data
so you can go back if something goes wrong. When the restore is done, tap
**Continue** to reload the app with the restored log.

<!-- screenshot: images/backup-and-restore/restore.png: restore with the replace option -->

### Merge or replace (when sync is on)

With [Multi-Device Sync](multi-device-sync.md) set up, the confirmation asks how
the restored log should treat the shared cloud library:

| Choice | What happens |
|--------|--------------|
| **Merge on next sync** (default) | The backup is restored on this device, and the next sync merges it with the cloud library like any other change. Use this to roll back a mistake but keep changes made on other devices. |
| **Replace everywhere** | The restored backup becomes the library on every device. Submersion replaces the cloud library with it, and every other device is asked to adopt the replacement before its next sync. |

**Replace everywhere** turns the button into **Restore and Replace Everywhere**
and asks a second time (**Replace Library Everywhere?**), because it affects
every device that shares your library.

Without sync, the backup is simply restored and the choice is not shown.

## History

**History** lists your backups, each with its date, dive and site counts, and
size. From the list you can restore or delete a backup, and **Pin backup** keeps
one from being removed automatically. Unpinned backups are cleaned up according
to your **Keep backups** setting.

## Automatic Backups

Turn on **Automatic backups** under **Automatic Backups**:

| Setting | Choices | Default |
|---------|---------|---------|
| **Frequency** | **Daily**, **Weekly** or **Monthly** | Weekly |
| **Keep backups** | 5, 10, 15, 20 or 30 | 10 |
| **Backup Location** | **Default location**, or a folder you choose with **Change** | Default location |
| **Cloud backup** | Upload backups to your cloud sync storage instead of a local folder (when sync is set up) | Off |

Automatic backups are off until you turn them on. The page shows how much space
your backups use.

## Backup encryption

**Encrypt backups** protects every backup with a password of at least 8
characters. You also get a recovery code: keep it safe, because it is the only
way to open your backups if you forget the password. Once it is on, every backup
and export Submersion writes is encrypted, local and cloud alike. The one
exception is the automatic copy saved before an app upgrade (see below), which
stays a plain copy of your database.

- If you already have backups, Submersion offers to **Re-encrypt now**.
- **Change password**, **Regenerate recovery code** and **Turn off encryption**
  manage it later. Turning it off leaves existing encrypted backups as they are:
  they still need the password to restore.

Backup encryption is separate from [end-to-end encryption](encrypted-sync.md) of
your synced library and from the database encryption in **App Security**.

## Automatic backup before app upgrades

When an app update upgrades Submersion's database, a backup of your database is
saved first. It appears in the history marked with the database versions it
spans (for example, `v63 → v64`). Three of these are kept: the one from the
oldest database version, so you can always go back to before the first upgrade,
and the two newest. Pinned ones are never deleted.

If an upgrade causes a problem, these backups let you go back to exactly where
your database was before it.

## Resetting the database

**Settings > Data > Database Storage** has a **Danger Zone** with
**Reset Database**, which deletes all data on this device and starts fresh. You type
"Delete" to confirm, and a backup is made first.

> [!WARNING]
> Resetting cannot be undone except by restoring a backup. If this device syncs,
> the reset disconnects it from cloud sync first, so the deleted data is not
> pulled straight back down; the cloud library itself is left untouched. The
> reset also turns off App Lock and database encryption.

When the reset completes, the app starts again from a clean state.

## How this differs from Multi-Device Sync

| | Backup | [Multi-Device Sync](multi-device-sync.md) |
|--|--------|---------------------------------------|
| **What it is** | A snapshot file, on demand or on a schedule | A continuously shared library across devices |
| **Storage** | Any location you choose, or your cloud sync storage | A cloud backend you set up: iCloud, Google Drive, Dropbox or S3-compatible storage |
| **Trigger** | Manual, or automatic on a schedule | Automatic when data changes, at launch, or on demand |
| **Purpose** | Point-in-time recovery | Keeping devices in step |

Backups and sync work together. Sync keeps your devices in step; backups let you
recover from accidental changes or data loss, whether or not you use sync.

## See also

- [Multi-Device Sync](multi-device-sync.md): keep your logbook in step across devices
- [Encrypted Sync](encrypted-sync.md): end-to-end encryption for the synced library
- [Import & Export](import-export.md): exchange data with other dive-logging apps
- [Settings](settings.md): every settings page
- [Debug Mode](debug-mode.md): diagnostics when something goes wrong
