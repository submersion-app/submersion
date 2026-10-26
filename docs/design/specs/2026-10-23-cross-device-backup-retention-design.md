# Cross-device backup retention

Issue: [#3503](https://github.com/submersion-app/submersion/issues/3503).
Mockup: [assets/2026-10-23-cross-device-backup-retention-mockup.html](assets/2026-10-23-cross-device-backup-retention-mockup.html)
(the confirmation the maintainer chose is option B, "Full list").

## Why

"Keep the last N backups" is applied per device. `BackupService.pruneOldBackups`
only prunes the device's own SharedPreferences ledger, and backups that other
devices (or earlier installs of this one) put in the same cloud folder are
listed in history (`mergeCloudBackups`) but never pruned. That is deliberate
today: pruning what a listing found could delete another device's backups.

With several devices backing up into one folder, the folder grows far past the
limit. The reported case: 44 backups (4.8 GB) with the limit at 30. Cloud
storage is often a small quota or a free tier, so the cost is real space, and
the diver wants a hard ceiling on what the shared folder holds.

## Goals

- An opt-in switch, **off by default**, that makes the "Keep" number a ceiling
  on the whole cloud backup folder, counting every device's backups.
- Turning it on shows exactly which backups will be removed, and removes them
  right away when confirmed.
- Pins made on any device are respected.
- Pre-migration and pre-downgrade backups stay exempt.

## Non-goals

- Sharing one "Keep" number across devices. The number stays a per-device
  setting (see "Smallest number wins").
- Touching anything stored on a device itself. Only cloud copies are deleted
  by the cross-device rule.
- Locking or coordination between devices (see "Concurrent pruning").
- Changing behaviour for anyone who leaves the switch off.

## Anti-goals

- Deleting a pinned backup, from any device, because of this rule (apart
  from the accepted marker-arrival window under "Pins across devices").
- Deleting one of the newest N backups in the folder because two devices
  pruned at the same moment.
- Deleting anything the confirmation did not list.

## Behaviour

### The switch

- New per-device setting, stored in `BackupPreferences` beside
  `backup_retention_count`, exposed on `BackupSettings`, default `false`.
  Being a fresh setting with a false default, it needs no migration.
- Shown in Settings, Backups, Advanced, directly under "Keep the last N
  backups", only when backups go to a cloud folder (cloud backup enabled and a
  provider connected). Without a shared folder there is nothing to count.
- Title "Count backups from all devices". Subtitle when off: this device
  removes only the backups it made. Subtitle when on: the cloud folder keeps
  the last N backups from every device; pinned backups are kept; if other
  devices use this too, the smallest number wins; update the app on every
  device first so their pins are seen. Exact wording is the builder's, in that
  spirit, and goes through the ARB files for every locale.
- When on, the retention footprint line under "Keep the last N backups"
  describes the cloud folder (count and size of its backups) rather than this
  device's history, as in the mockup.

### Smallest number wins

Each device with the switch on applies its own "Keep" number to the whole
folder. The folder therefore settles at the smallest number among those
devices. This is intended (it is the safe direction for space; the lowest
choice offered is 5) and the subtitle says so.

### The cross-device rule

Runs wherever `pruneOldBackups` runs today (after every backup, including the
safety snapshot a restore takes), and when the switch is confirmed on. It runs
**in addition to** today's per-device pruning, which is unchanged.

1. List the cloud backup folder (the listing `getCloudBackups` already makes).
2. The candidates are the backup files in it (prefix `submersion_backup_`,
   extension `.db` or `.sbe`), minus any that are pinned (see "Pins across
   devices"), minus any this device's history records as pinned.
3. Sort the candidates newest first and keep the newest N, where N is this
   device's "Keep" number, after first reserving a slot for each device's
   newest backup (see "Each device's newest backup"). Order by the timestamp
   in the name, falling back to
   the file's modified time, as `backupRecordFromCloudFile` already does,
   with the name breaking a tie so listing order never decides.
   Every device must sort the same way for the concurrency argument below to
   hold, and a server's modified time is not available everywhere (iCloud
   reports a local file stat), so the name is the key.
4. Never delete a backup less than 24 hours old, whatever its rank. Names
   carry the writing device's local time, so two devices in different time
   zones can mis-order recent backups by up to 14 hours; the grace period
   means that skew can only ever keep a backup, never delete one. The folder
   may briefly hold more than N because of it.
5. Immediately before deleting, list the folder once more and drop any
   candidate that has gained a pin marker since step 1. If that listing
   fails, delete nothing (`getCloudBackups` returns an empty list on error,
   which must not read as "no markers").
6. Delete the remaining files from the cloud folder only. A file already gone
   counts as deleted, not as a failure. On a backend that defers writes (Git),
   push once at the end, as `pruneOldBackups` does.
7. When a deleted file is the cloud copy of a record in this device's history:
   if the record has a local copy, it becomes local-only (location `local`,
   cloud id cleared); otherwise the record is removed.

Pre-migration and pre-downgrade backups are never uploaded and do not use the
`submersion_backup_` prefix, so they are never in the listing and are exempt by
construction. A test should pin that.

A failure in the cross-device rule (offline, listing error, a delete refused)
never fails the backup that triggered it; it is logged and retried on the next
prune, matching today's best-effort pruning.

### Each device's newest backup

Added for issue [#3632](https://github.com/submersion-app/submersion/issues/3632).
Ranking every device's backups together lets a device that backs up rarely
(a laptop used only on dive trips) lose every one of its backups to the
others' newer ones. So the rule never removes a device's own newest backup
while that backup is recent.

- **A device is a tag.** The device tag in the name (`__d<tag>`) identifies
  the device. Unattributed names, written before attribution shipped, have no
  device and get no reserved slot; they compete under the plain rule.
- **Counted inside N.** "Keep" stays a ceiling on the folder. Each tag's
  newest backup (by the timestamp in the name, as in step 3, with the name
  breaking a tie) takes a slot first; the remaining `N - reserved` slots go
  to the newest of the rest of the unpinned candidates. With Keep 10 and three devices, the folder holds each
  device's newest plus the seven newest others.
- **More devices than slots.** When the reserved backups alone reach N, all of
  them are kept and nothing else is: the folder holds more than N rather than
  losing some device's only backup.
- **Stale devices drop out after 180 days.** A reinstall gets a new device id
  and so a new tag, and a retired device keeps its tag forever. A device's
  newest is reserved only while its name's timestamp is less than 180 days
  old. Older, it competes under the plain rule: it is not deleted outright,
  and stays until N newer backups exist. 180 days covers a seasonal diver's
  off-season. The number is fixed, not a setting.
- **Pins and grace are unchanged.** Pinned backups are not candidates, so a
  device whose newest is pinned already has its recovery point and reserves
  nothing more. The 24-hour grace still applies on top of the ranking.
- **The confirmation** gains a line under the pinned one, "K backups are kept
  as a device's newest", shown when K is above zero. K counts reserved
  backups that sit outside the plain newest N, so the line appears only when
  the reservation changed what goes. The switch subtitle says each device's
  newest is kept unless it is over six months old.

Concurrency still holds. A listing that lacks a device's newer backup
reserves an older one of that device instead, which can only keep more.
Two edge cases are accepted: a device's newest deleted by hand while another
device is mid-prune can make that prune reserve one slot too many and remove
one backup the folder would otherwise keep; and a backup right at 180 days
can be reserved on one device and not on another, because each compares
against its own clock, which only returns it to the plain rule early.

### Pins across devices

Pins live in each device's own ledger, invisible to other devices. To make
them visible:

- Pinning a backup that has a cloud copy also uploads an empty **pin marker**
  to the same cloud folder. Markers are **per pinning device**, so two devices
  pinning the same backup never share one file and one unpinning cannot
  remove the other's pin: the marker is the backup's name without its
  extension, then `__p` and the pinning device's tag (`deviceTag`), then
  `.pin`. For `submersion_backup_X__dTAG.sbe` pinned by a device tagged
  `PTAG`, it is `submersion_backup_X__dTAG__pPTAG.pin`. A backup is pinned
  when any marker for it exists. This format is fixed once shipped, like the
  device tag. Markers are written whether or not the switch is on, because
  another device may have it on.
- This device's ledger stays the source of truth for **its own** pins; its
  markers mirror it. Unpinning deletes only this device's marker. A marker
  write that fails (offline) does not fail the pin; the reconciliation below
  repairs it.
- The marker starts with the backup prefix, so the existing listing returns
  it. Every consumer of that listing must ignore `.pin` files as backups
  (`mergeCloudBackups` and the orphan scan already filter by extension; the
  builder audits the rest, including `deletePlaintextCloudBackups` and the
  encrypting provider's exemption rule).
- **Reconciliation:** before every prune (and so on the first backup after
  updating, which covers pins made before this version), each device makes its
  own markers match its ledger: it writes a marker for each pinned record
  whose cloud copy is in the listed folder and lacks this device's marker, and
  deletes this device's markers for backups it no longer has pinned. It runs
  whether or not the switch is on, and it never touches another device's
  markers. A failure is logged and retried next time. A successful pass
  records what it mirrored, so a prune lists the folder for it only when the
  pins have changed since (listing is a round trip, and on iCloud it can
  start downloads). A prune lists the folder at all only when it needs to:
  the switch is on, a pin changed, or a cloud copy of this device's own is
  due to go. When that listing fails, no cloud copy goes that round.
- A cloud row discovered from the listing (not in this device's history) that
  has another device's marker shows as pinned, with "Pinned on another device"
  as its explanation, and offers no unpin here (only the device that pinned it
  can). Pinning a discovered row adopts it as today (`pinRecord`) and writes
  this device's marker.
- A marker (from any device) whose backup no longer exists is deleted by the
  cross-device rule.
- A device still on an older version writes no markers, so its pins are
  invisible to the rule until it updates. The subtitle asks divers to update
  every device first. This was accepted as the trade-off.
- A pin is invisible to other devices until its marker arrives: on any
  backend while the pinning device is offline, and on iCloud for the minutes
  its sync can take. A device pruning in that window can delete the backup.
  The window is narrow (an old backup pinned on one device just as another
  finishes a backup) and was accepted: the switch is offered on every
  backend, iCloud included.

### Turning the switch on

1. List the folder and work out what the rule would delete right now.
2. If nothing would be deleted, the switch turns on with no dialog.
3. Otherwise show the confirmation (mockup option B): title "Remove K
   backups?", a line with the count and total size and how many pinned
   backups are kept, then a scrollable list of every backup that goes, each
   with its date and time, its source and its size. Buttons: Cancel, and a
   destructive "Remove K backups".
4. Confirm: the switch turns on and exactly the listed backups are deleted
   then and there (re-check for new pin markers first, as in step 4 of the
   rule). Cancel: the switch stays off and nothing is deleted.
5. If the listing fails (offline, signed out), say so and leave the switch
   off.

Source labels come from the device tag in the name (`classifyBackupFile`):
"This device", "Another device" (a different tag, which also covers this
device's earlier installs; the name cannot tell those apart), and an
"Unknown device" label for unattributed names written before attribution
shipped. The mockup's "Old install" label is not derivable and is not used.

Turning the switch off just turns it off; nothing is restored or deleted.

### Lowering "Keep" while the switch is on

Choosing a smaller number with the switch on goes through the same
confirmation, worked out for the new number: if anything would be deleted,
the list is shown, and confirming saves the number and deletes exactly the
listed backups right away. Cancel keeps the old number. Raising the number,
or changing it with the switch off, saves it with no dialog, as today.

### The switch belongs to the folder it was confirmed for

The setting stores the cloud account id the diver confirmed it for (or
`provider:<id>` when the account id cannot be read, never an empty key that
two unknown accounts could share). The rule only runs when the folder being pruned is in that
account. When the backup destination changes (a different account or
provider, or cloud backup turned off), the switch reads as off and turning it
on again goes through the confirmation for the new folder. Scheduled
background backups resolve their provider separately
(`resolveHeadlessCloudProvider`); they run the rule only when that provider's
account matches the confirmed one, and otherwise skip it.

### Concurrent pruning

No lock is needed. Every device orders backups by the timestamp in the name,
so all devices agree on the order. Each device deletes only files outside the
newest N in its own view of the folder. The newest N files in the folder are inside every
device's newest N (a listing that lacks some newer file only ranks them
higher), so they survive any interleaving. Deleting a file another device
already deleted is treated as done. The pin re-check in step 4 narrows the
window for a pin made elsewhere to the moment between that listing and the
delete.

### A device with the switch off

Its own pruning is unchanged. Another device may delete its cloud copies; its
local copies are untouched and still restorable. Its history then holds
records whose cloud copy is gone, the same state as when a diver deletes
another device's backup from the history list today; no new handling is
required.

## Left to the builder

- Where the cross-device rule lives (a new service or helper beside
  `cloud_backup_history.dart` is preferred; `backup_service.dart` is already
  2,000 lines).
- Exact strings, icons, and the dialog widget structure.
- When the pin-marker catch-up runs.
- How the history list shows a discovered row that is pinned on another
  device, provided it reads as pinned.
