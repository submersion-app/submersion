# Change Log

Submersion keeps a record of what changes in your logbook. If something looks wrong, you can see what happened, when, and on which device, and put it back without restoring a whole backup.

> [!NOTE]
> **Where to find it:** **Settings > Data > Change log**. To see one record's history, open that dive, site, piece of gear or other record and choose **History** from its menu.

## What is recorded

The log records changes to your data, with the old and new value of each field:

- Your own edits, additions and deletions
- Imports and dive computer downloads
- Logbook rule runs
- Changes that arrive from your other devices
- The app's own background jobs, labelled **Automatic**

A bulk action, such as an import, is one entry you can open to see every record it touched. Several quick saves to the same record are grouped into one entry.

## What is not recorded

- Dive profile samples. The profile editor keeps its own revision history; a deleted dive's profile is kept so the dive can come back whole.
- Information the app can work out again, such as derived metrics, data quality findings and caches.
- How you arrange lists and tables, such as sort order and visible columns.
- Settings that belong to one device, such as the app theme and navigation layout.
- Passwords, keys and other credentials. These are never written to the log.

The log starts empty when you first update to a version that includes it, so it holds no history from before that.

## Reverting a change

Open an entry to see what changed.

- **Revert** beside a field puts that one field back.
- **Revert all** puts back every field in the entry.
- **Restore** brings back a deleted record with everything that belonged to it, such as a dive's tanks, gear and profile. Photos and videos come back as links, because Submersion never stores the files themselves.
- **Undo this import** removes what the import added and reverses its other changes.

If a value has changed since the entry, Submersion shows you the value in the entry, the value now and the value after the revert, and asks before going ahead. For a bulk action it tells you how many records have changed since, and offers to revert the rest or revert all of them.

Undoing an import keeps any record that later data still uses, such as a site one of your other dives is at, and lists what it kept and why.

A revert is a new change. It appears in the log, it reaches your other devices like any other edit, and it can be reverted too.

Some changes cannot be reverted, and the entry says why: the record has gone, the record it belonged to has gone, or an app update changed how that value is stored.

## Devices and profiles

Each device keeps its own log. Logs do not sync, so a change made on your phone appears in your laptop's log as a synced change once it arrives, and each device can revert it. The log is included in that device's backups.

The log shows the active diver's records and anything shared with them. Deleting a diver deletes their entries.

## How long entries are kept

Entries are kept for 12 months. To change that, open the menu on the Change log page and choose **Log settings**, where you can pick 3, 6 or 12 months, or forever.

**Clear log** removes the active diver's entries from this device. You cannot revert those changes afterwards.

The log takes up space in your database. The **Storage usage** page shows how much, under the database's own size.
