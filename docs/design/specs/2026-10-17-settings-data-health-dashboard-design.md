# Settings > Data: health strip, attention lines and row status marks

Date: 2026-10-17. Release: v1.8.3. Issues: #3390 (dashboard), #3394 (row dots).

## Intent

A diver opening Settings > Data wants to know, at a glance, three things: that
their data is safe and backed up properly, that it is consistent across all of
their devices, and that the recommended configuration for a resilient setup is
turned on. Today the page is a flat list of links (`_DataSectionContent`,
`lib/features/settings/presentation/pages/settings_page.dart`) and answering
those questions means opening four pages in turn.

The page must be very simple to read quickly, and calm: no boxes.

## Goals

- One health model per feature (Backup, Cloud sync, Shared libraries, Photos &
  media) that drives both the dashboard and the row marks, so the two can never
  disagree.
- A status strip at the top of Settings > Data, with a one-line explanation for
  each feature that needs attention.
- The same status shown as a small mark on each of the four menu rows (#3394).
- A quiet facts line: counts and database size.
- Persist the failures the model needs that are not stored today (automatic
  backup failures, the last sync failure).

## Non-goals

- Moving Connected Accounts into Settings > Data (#3388 stays separate).
- Storage-reclaimed figures (#3396) and remote storage used.
- Per-device "in sync" claims. The app can say when it last synced, not whether
  each peer has pulled this device's changes.
- Notifications or badges outside Settings > Data.
- Changing any setting's default.

## Anti-goals

- Nagging a diver about a feature they chose not to use. Shared libraries and
  photos & media that are not set up are neutral, never amber.
- Colour as the only carrier of meaning. Every status has its own symbol and a
  screen-reader label.
- A busy, boxed top section. No cards, shadows or borders on this page.

## The health model

Four levels, ordered by severity:

| Level | Symbol | Colour | Meaning |
| --- | --- | --- | --- |
| failing | cross | red | Configured and broken; data may not be protected. |
| attention | exclamation | amber | Works, but something needs the diver: a recommended setting is off, a copy is overdue, writes are held. |
| healthy | check | green | Configured and working. |
| notSetUp | hollow dash | none (outline) | Not in use, or not available here. Neutral. |

Each feature yields one `FeatureHealth`: its level plus a reason code (an enum
per feature, with any values the text needs, such as a time or a library name).

Evaluation runs in two passes. Rows marked **(gate)** in the tables are checked
first, in order, and the first that matches is the answer: nothing below it is
considered. If no gate matches, every remaining row that applies competes and
the most severe wins; ties go to the row listed first. The evaluator is a pure function of a snapshot of inputs, so
the rules are unit-tested as tables without widgets. Widgets turn reason codes
into localized text.

### Backup

Inputs: `BackupSettings` (enabled, frequency, lastBackupTime,
cloudBackupEnabled), the new persisted last automatic outcome (below), and
whether cloud sync is configured.

| Order | Condition | Level | Reason text (gist) |
| --- | --- | --- | --- |
| 1 (gate) | Automatic backups off | attention | Recommended: turn on automatic backups |
| 2 | Last automatic attempt failed and no backup succeeded after it | failing | Last backup failed, {when} |
| 3 | No backup ever, or the last one older than two frequency periods | attention | Backup overdue, last {when} / never |
| 4 | Cloud backup is on and the most recent backup's cloud copy is missing | attention | Cloud copy failed to upload |
| 5 | Neither cloud backup copy nor cloud sync is on | attention | No copy off this device |
| 6 | Otherwise | healthy | (row subtitle already shows last backup time) |

Two periods, not one, because the OS defers mobile background work and the
desktop timer checks hourly; one period would flicker amber every cycle.

**New persisted state.** `BackupPreferences` gains two things.

- The last scheduled backup failure: time and error message. Written only by
  the two scheduled paths, in their catch blocks: the mobile WorkManager job
  (`runScheduledBackup`, `lib/core/services/background_service.dart`) and the
  desktop timer (`_checkDesktopBackup`,
  `lib/features/backup/presentation/providers/backup_providers.dart`). Not in
  `performBackup`, because the adopt/replace safety backups also pass
  `isAutomatic: true`. A failure counts only while it is newer than
  `lastBackupTime`, so any later success clears it with no extra step. Every
  backup that stamps `lastBackupTime` today counts as a success (manual,
  scheduled, export, safety copies): each is a real copy of the data.
- Whether the most recent backup's cloud copy is missing. Written by
  `BackupService` at the point it stamps `lastBackupTime`: when cloud backup is
  on, missing means the record's location is local only. Every backup
  overwrites it, so a later backup that uploaded clears it. The background isolate writes SharedPreferences from another
isolate, so the foreground reads must reload (`backupSettingsProvider` already
has `refresh()`; the model must see the new fields after a resume).

### Cloud sync

Inputs: `SyncState`, `isCloudSyncDisabledByCustomFolderProvider`,
`selectedCloudProviderTypeProvider`, the auto-sync setting, and the new
persisted last sync failure.

| Order | Condition | Level | Reason |
| --- | --- | --- | --- |
| 1 (gate) | Database is in a custom folder (sync unavailable) | notSetUp | Off: custom database folder |
| 2 (gate) | No provider selected | attention | Recommended: turn on cloud sync |
| 3 | Needs passphrase | failing | Sync paused: enter passphrase |
| 4 | Replaced library awaiting adoption | failing | Sync paused: library was replaced |
| 5 | Not authenticated | failing | Sync paused: sign in |
| 6 | Persisted non-network failure for the current provider, newer than its last success | failing | Last sync failed, {when} |
| 7 | Persisted network failure for the current provider, and no success in the last 7 days | attention | Offline: last synced {when} |
| 8 | Conflicts > 0 | attention | {n} conflicts to resolve |
| 9 | Peers held: newer schema, older schema, epoch-skipped or read-failed | attention | A device needs an app update / attention |
| 10 | Automatic sync off | attention | Recommended: turn on automatic sync |
| 11 | Never synced | attention | Not synced yet |
| 12 | Otherwise | healthy | |

**New persisted state.** `SyncPreferences` (or the existing sync store the
builder finds most fitting) gains the last sync failure: provider id, time,
kind (`network` or `other`) and message. Written only from `performSync`'s
failure results: `SyncResultStatus.networkError` gives `network`;
`error` and `authError` give `other`. Other paths that set
`SyncStatus.error` (state load, adoption, rebuild, replace) report on the
Cloud Sync page as today and do not feed the model. A successful sync on the
same provider clears it. A stored failure for a different provider than the
current one is ignored, so switching backends never carries a stale red. This
keeps a failure visible after a restart, when `SyncState.status` starts as
`idle`. The in-memory `SyncStatus.error` is not an input.

Being offline is normal for divers (liveaboards, travel), so a network failure
alone is never red; it turns amber only once a week passes without a
successful sync.

Device count for the facts and the row subtitle: this device plus the peers in
`peerDeviceNamesProvider`.

### Shared libraries

Input: `sharedLibrariesProvider`.

| Order | Condition | Level | Reason |
| --- | --- | --- | --- |
| 1 (gate) | No library joined | notSetUp | |
| 2 | Any library has `lastError` | failing | {library}: sync failed (or "{n} libraries") |
| 3 | Any library has `rolesRejected`, a `pendingRoles` answer waiting, or `readOnlyDetected` while this member's trusted role allows writing | attention | {library}: your edits are on hold |
| 4 | Otherwise | healthy | |

`writesHeld` is not used as is: a reader whose storage key refuses writes is
set up exactly as the owner intended and must not see amber.

### Photos & media

Inputs: media store attach state (`attachedStoreId`, `hasMarkerMismatch`),
the announced store descriptor, Lightroom connection, `pendingSetupItemsProvider`,
`mediaTransferSummaryProvider`, `mediaTransfersSuspendedProvider`.

| Order | Condition | Level | Reason |
| --- | --- | --- | --- |
| 1 (gate) | No media store attached on this device and no Lightroom account; or a store is announced but its "attach on this device" setup item was dismissed | notSetUp | |
| 2 | A media setup item is pending: store to attach, store to reconnect, or sign-in needed for the store's account or the Lightroom account | attention | Finish setting up this device |
| 3 | Transfers suspended, or waiting with a recorded failure/hold reason | attention | Media transfers paused |
| 4 | Otherwise | healthy | |

Only media items count. A sign-in needed for the sync account belongs to Cloud
sync (rule 5 there), and connector accounts unrelated to media count nowhere.
A dismissed attach is respected as the diver's choice for this device.

Gallery and local-file links do not make the feature "set up": they are links
to files the app never copies, so they say nothing about protection.

## The page

The chosen layout is "B2, status strip" (mockup approved in brainstorming).
Settings > Data loses its cards: plain sections with headers and dividers.

From the top:

1. **Status strip.** Four items in one row, evenly spaced: Backup, Sync,
   Libraries, Media. Each is the status symbol (about 26 dp) above a short
   label. Each item is tappable and opens that feature's page. Screen readers
   hear "Backup: healthy", "Shared libraries: needs attention", and so on.
2. **Attention lines.** One line per feature whose level is failing or
   attention, failing first, each a small symbol plus the reason text, each
   tappable to its page. When every feature is healthy or not set up, this area
   is empty and takes no space.
3. **Facts line.** One muted line: dives, sites, photos, database size, for
   example "412 dives · 97 sites · 1,240 photos · 48 MB". Counts cover the
   whole database, not the active diver: this is about the data, not the
   diver's statistics.
4. **Divider**, then the existing menu, unchanged in order and content, as
   flat sections: Backup & Sync, Storage, Import, Data Tools.

Row marks (#3394): Backup & Restore, Database Cloud Sync, Shared Site Libraries
and Photos & Media each show the same symbol as their strip item, at about
16 dp, beside the title. No mark when the feature is not set up. Each mark has
the same semantics label as the strip item.

The Database Cloud Sync row subtitle shows "Synced {when}" once a sync has
happened, in place of the generic subtitle.

Desktop and tablet widths: the same single-row strip, left-aligned in the
detail pane with a sensible maximum width. No separate layout.

Light and dark: symbol colours come from the theme (a green, amber and red that
meet contrast against the surface in both modes); the not-set-up symbol is an
outline in the outline colour.

## Constraints

- Every string localized through the ARB files; relative times reuse the
  existing `backup_time_*` style helpers or an equivalent shared formatter.
- `settings_page.dart` is far past the 800-line guide. The Data section moves
  out into its own file(s) under `lib/features/settings/presentation/`, and the
  health model lives in its own small files; nothing new is added to
  `settings_page.dart` beyond the call site.
- Health providers must not trigger expensive work on every rebuild: account
  status probes and file-size reads are cached providers, refreshed when the
  page opens.
- Tests restore any global state they replace (CI runs many test files in one
  isolate).
- No schema change: the new state lives in SharedPreferences.

## Calls made by the designer

The diver asked for the designer's recommendation throughout, so these are
recommendations, not things the diver specified:

- Four levels with distinct symbols, and amber for "configured but needs
  attention" on the row marks too (the issue asked for green only).
- Recommended setup is automatic backups, an off-device copy, cloud sync and
  automatic sync. Backup encryption is deliberately not recommended: a lost
  passphrase makes every backup unrecoverable.
- Two backup periods before "overdue"; seven days offline before sync goes
  amber; network failures never red.
- Readers with refusing storage keys are healthy; dismissed media attach is
  not set up.
- Facts count the whole database.
- The whole Data page goes flat, which makes it look different from the other
  Settings sections (the diver asked for no boxes on this page).

## Left to the builder

- File and class names, provider shapes, and how inputs are gathered into
  snapshots.
- Exact theme colour tokens and symbol sizes within the guidance above.
- Exact wording of each reason, kept short (one line on a phone).
- How database size is read (main database file plus WAL is fine).
- Whether the strip and attention lines share a widget with the row marks.
