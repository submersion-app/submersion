# Backup retention: Keep all, custom count, and pin on Back up now

Issue: #4535. Release: v1.8.5. Size: a small change.

## Intent

A diver taking daily backups wants to keep more than 30 of them: while
importing old dives a mistake may surface weeks later, and a long trip can
push early backups out of a 30-backup window. They asked to turn automatic
removal off or to type a number such as 365 or 999. A backup they make by
hand should never be removed.

## Today

- Retention is a count (`BackupSettings.retentionCount`, default 10), picked
  in Settings > Data > Advanced from 5, 10, 15, 20, 30.
- `pruneOldBackups` runs after every backup and removes the oldest unpinned
  `BackupType.manual` records past the count. Scheduled and hand-made backups
  share the count. Pinned records are exempt from every prune, including the
  cross-device rule (#3503).

## Goals

- "Keep all": no automatic removal at all.
- A custom count, typed, from 1 to 9999.
- A hand-made backup can be kept forever as it is made.

## Non-goals

- Age-based (days) retention. With daily backups a count gives the same
  result, and the cross-device rule is built on counts.
- Exempting every hand-made backup from pruning automatically (approach B
  below, declined).

## Anti-goals

- Any stored form of "keep all" that an older build reads as a small count.
  `0` would make an older build delete every unpinned backup.

## Approaches

Protecting hand-made backups:

- **A. Pin, as today, made easier to reach (chosen).** A "Keep this backup"
  switch in the Back up now dialog pins the backup as it is made. Reuses the
  one exemption every prune already honours; existing behaviour unchanged.
- B. Hand-made backups never count. Nothing to do per backup, but they pile up
  without limit and existing users who rely on them being pruned see a change.

The count picker:

- 1. A longer fixed list up to 365 plus Keep all. No typing, but no 999 and a
  long dialog.
- **2. Today's short list plus Keep all and Custom number (chosen).** Covers
  365 and 999 and keeps the list short.
- 3. Age-based days. A second rule beside the count, and a rework of the
  cross-device rule.

## Design

### Storage

- "Keep all" is stored in the existing `backup_retention_count` key as a large
  sentinel, `BackupSettings.keepAllRetentionCount` (`1 << 30`). An older build
  reads it as "keep a billion", which keeps everything.
- `BackupSettings.keepsAll` is true for any count above the custom maximum
  (9999), so a stored value is never shown as a raw number.
- `pruneOldBackups` needs no change: with the sentinel no record is past the
  count. The cross-device plan likewise removes nothing.

### Keep backups dialog

```
Keep backups
  5
  10
  15
  20
  30
  Keep all
  Custom number…        (shows "Custom: 365" and the check when current)
```

- Custom number opens a dialog with a number field (digits only), prefilled
  with the current count, accepting 1 to 9999, with an inline error otherwise.
  Save is disabled while the value is invalid. A value that matches a list
  entry is simply saved.
- Lowering the count while "Count backups from all devices" is on still goes
  through the existing confirm-then-prune flow (`changeRetentionCount`).
  Switching from Keep all to a number counts as lowering.

### Wording

- Tile title: "Keep all backups" when keeping all, else today's
  "Keep the last {count} backups".
- Tile subtitle: "Backups are never removed automatically" when keeping all,
  else today's "Older backups are automatically removed". The footprint line
  stays.
- Cross-device switch, on, with Keep all: "Keep all is on, so this device
  removes no backups from the cloud folder. Pinned backups are kept." (my
  call; the switch stays visible so it is not lost when a count is chosen
  again).
- Set-up step: "{frequency}. Every backup is kept here." and the desktop
  variant, when keeping all.

All new strings are added to every ARB file.

### Back up now dialog

- A `SwitchListTile` "Keep this backup" with subtitle "Pinned backups are
  never removed automatically", under the note field, off by default.
- `BackupNoteResult` gains `pin`. The caller pins the new record through the
  same path the history tile's pin button uses, so a cloud copy gets its pin
  marker (#3503).
- The pin is applied after the backup is made; the prune that runs inside
  `performBackup` only removes records past the count, and the newest record
  is never past it, so the new backup cannot be pruned before it is pinned.

## Left to the builder

- Where the custom-number dialog lives (a small widget beside
  `backup_choice_dialog.dart`).
- Exact keys and test layout.
