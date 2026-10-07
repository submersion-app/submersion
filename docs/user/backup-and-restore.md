# Backup and Restore

A backup is a single point-in-time snapshot of your entire dive logbook saved to a portable file. You can keep that file wherever you like, share it, or use it to roll back to an earlier state of your data.

> [!NOTE]
> **Where to find it:** Settings → Data → Backup / Restore

<!-- screenshot: images/backup-and-restore/backup.png — create backup -->

## What a backup contains

A backup is a raw copy of Submersion's SQLite database (`submersion.db`). It includes every dive, dive site, trip, buddy, equipment record, species log, diver profile, and all other data the app stores locally. App settings such as cloud-sync credentials are not stored in the database and are not included.

Backup files use the `.db` extension. The default filename when you export is `submersion_backup_YYYY-MM-DD.db`.

## Creating a backup

Open **Settings → Data → Backup / Restore** and tap **Export Backup**. A sheet appears with two options:

- **Save to file** — opens a system file picker so you can choose where to write the backup. Use this to save to a folder, attach to a cloud drive, or copy to a connected computer.
- **Share** — creates a temporary copy and opens the system share sheet, so you can send the file to another app, AirDrop it, email it, and so on. Not available on Windows and Linux, which do not have a share sheet.

After a successful export a confirmation message shows the path where the file was saved.

You can also trigger an immediate backup at any time from the auto-backup section of the same page using the **Backup Now** button.

## Restoring from a backup

Tap **Restore from File**, then pick any `.db` backup file. Submersion verifies the file is a valid Submersion database before proceeding, and rejects files that do not contain the expected tables.

A confirmation dialog shows the backup's timestamp, dive and site counts, and file size. Before the restore runs, Submersion automatically saves a safety backup of your current data so you can recover if something goes wrong.

<!-- screenshot: images/backup-and-restore/restore.png — restore with replace mode -->

### Merge versus replace (when sync is active)

If you have [Multi-Device Sync](multi-device-sync.md) configured, the confirmation dialog offers a choice of how the restored data interacts with the shared cloud library:

| Mode | What happens |
|------|--------------|
| **Merge** (default) | The backup is restored locally. On the next sync the restored data is merged with the cloud library, the same as any other sync. Use this when you want to roll back a mistake but keep changes from other devices. |
| **Replace** | The restored backup becomes the authoritative library everywhere. Submersion writes a new library marker to the cloud, clears the existing sync files, and re-uploads your restored data. Every other synced device will be prompted to adopt the replacement before its next sync. Use this when you want the backup to completely replace the library on all devices. |

Replace mode requires a second confirmation because it affects every device sharing your library.

If sync is not configured, only the merge path is available and the choice is not shown.

## Backup history

The **Backup history** section of the page lists all recorded backups. Each entry shows the timestamp, dive and site counts (where available), file size, and whether it is stored locally, in the cloud, or both. From the history you can restore any entry or delete it.

You can pin any backup so it is excluded from automatic pruning. Unpinned backups are cleaned up according to the retention settings you configure.

## Automatic backups

Automatic backups can be turned on in **Settings → Data → Backup / Restore** under the auto-backup section. Options include:

| Setting | Choices |
|---------|---------|
| **Frequency** | Daily, weekly, or monthly |
| **Keep** | 5 to 30 backups |
| **Backup location** | A folder you choose, or the app default (`Submersion/Backups` in the app documents directory) |
| **Cloud backup** | Upload each auto-backup to your cloud sync storage (visible when sync is configured) |

If you have turned on [end-to-end encryption](encrypted-sync.md), cloud backups are
encrypted with your passphrase before upload, and each one is self-contained &mdash;
you can restore it on a new device by entering the passphrase, even before sync is
set up there. Backups saved to a local folder or the share sheet stay unencrypted.

## Automatic backup before app upgrades

When Submersion upgrades its internal database schema — something that happens automatically when you update the app — it saves a backup of your database before the upgrade runs. This safety copy appears in the backup history with a migration badge showing the schema versions it spans (for example, `v63 → v64`). Up to three of these pre-migration backups are kept automatically; pinned ones are never deleted.

If a migration causes a problem, these backups let you roll back to the exact state your database was in before the upgrade.

> [!TIP]
> Pre-migration backups are restored in merge mode only. If you need to restore one to an older version of the app, install that app version first, then restore; the app will rerun the same upgrade on the restored data if you restore to a current version.

## Resetting the database

**Settings → Data → Database Storage** has a **Danger Zone** section with a **Reset Database** option. This permanently deletes all your data and creates a fresh empty database. A backup is made automatically before the reset, and you must type `Delete` in the confirmation dialog to proceed.

> [!WARNING]
> Resetting the database cannot be undone except by restoring a backup. If you have Multi-Device Sync enabled, the reset only affects the local device — the shared library in the cloud is untouched until you sync again, which will pull data back down. To erase the library everywhere, disable sync or clear the cloud storage separately.

After the reset completes, the app restarts from a clean state.

## How this differs from Multi-Device Sync

| | Backup | [Multi-Device Sync](multi-device-sync.md) |
|--|--------|---------------------------------------|
| **What it is** | A snapshot file you export on demand | A continuous shared library across devices |
| **Storage** | Any location you choose (local folder, cloud drive, share sheet) | A cloud storage backend you configure (iCloud or S3-compatible) |
| **Trigger** | Manual, or automatically on a schedule | Automatic whenever data changes, on launch, or on demand |
| **Purpose** | Point-in-time recovery | Real-time library sharing |

Backups and sync are complementary. Sync keeps your devices in step; backups let you recover from accidental changes or data loss, regardless of whether sync is in use.

## See also

- [Multi-Device Sync](multi-device-sync.md) — keep your logbook in sync across devices
- [Import / Export](import-export.md) — exchange data with other dive-logging apps
- [Settings](settings.md) — overview of all settings pages
- [Debug Mode](debug-mode.md) — advanced diagnostics when something goes wrong
