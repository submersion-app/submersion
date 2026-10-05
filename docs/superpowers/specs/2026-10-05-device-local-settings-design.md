# Device-local notification and appearance settings (issue #2947)

## Problem

A diver who uses several devices (discussion #1334) wants most settings to
follow them, but some to stay on each device. Today the split is wrong:

- The notification settings sync. Turning reminders off on a Mac turns them
  off on the phone, although the OS notification permission is per device.
- Theme mode and the nav layout sync, although both depend on the device:
  where it is used (light or dark surroundings) and its screen size.
- Nothing user-facing says which settings sync.

## Decisions (recorded with the maintainer)

| Setting | Storage | Decision |
| --- | --- | --- |
| Notifications enabled, service reminder days, reminder time, trip service lead days | `diver_settings` columns | Per device |
| Theme mode | `diver_settings.theme_mode` | Per device |
| Nav order, phone bottom bar | `settings` key `nav_primary_ids` | Per device |
| Nav order, tablet/desktop rail | `settings` key `nav_rail_ids` | Per device |
| Always hide nav labels | `settings` key `nav_always_hide_labels` | Per device |
| Theme preset and the three accent toggles | `diver_settings` columns | Keeps syncing |
| Map style | `diver_settings.map_style` | Keeps syncing |
| Language | `diver_settings.locale` | Keeps syncing |

Approach: keep the columns and keys where they are and leave them out of sync
(approach A). Moving them to SharedPreferences was rejected: it needs a one-time
adoption step and loses per-diver scope, for no gain.

A save that changes only device-local values does not stamp a sync clock or
queue anything (see Saving).

No Settings screen changes. The split is documented in the sync guide.

## Design

### 1. One list of device-local fields

New file `lib/core/services/sync/device_local_fields.dart` holds both lists,
replacing the serializer's private `_deviceLocalKeys` and
`_deviceLocalSettingsKeys`:

- `deviceLocalSyncColumns`: wire (JSON) keys per entity type.
  - `diveComputers`: `bluetoothAddress` (existing).
  - `diverSettings`: `notificationsEnabled`, `serviceReminderDays`,
    `reminderTime`, `tripServiceLeadDays`, `themeMode`.
- `deviceLocalSettingsKeys`: keys in the `settings` table.
  - `active_diver_id` (existing), `nav_primary_ids`, `nav_rail_ids`,
    `nav_always_hide_labels`.

`AppSettingsRepository` and `DiverSettingsRepository` read the same lists, so
the serializer and the write paths cannot drift apart.

### 2. Sync serializer

- `_withoutDeviceLocalFields` strips every key `deviceLocalSyncColumns` lists
  for the entity type, instead of hard-coding `bluetoothAddress`. Calls without
  an entity type keep their current dive-computer meaning.
- Export: `_exportDiverSettings`, and the single and batch record fetches used
  to publish pending changes and build payloads, strip the `diverSettings`
  columns.
- Import: `upsertRecord` and `upsertRecords` already strip, but stripping
  alone is not enough. `_buildRowKeys` subtracts the device-local columns, so
  `_withLocalForOmitted` never refills them, `_withSchemaDefaults` fills their
  defaults, and the full-row upsert writes those defaults over the local
  values. (This already happens to `bluetoothAddress`, which is nullable and
  so is written back as NULL.) A new step after the strip,
  `_withDeviceLocalFromHere`, refills every device-local column from this
  device: the current local row, else the replace-adopt snapshot (below), else
  nothing, so a row new to this device takes the column defaults. The write
  then stores this device's own values, a no-op for an existing row.
- Replace-adopt: the streaming path clears each synced table and refills it
  from the cloud. Before clearing a table with device-local columns,
  `deleteAllRecords` snapshots those columns by record id; the refill consumes
  the snapshot for a row whose id comes back. The in-memory path upserts while
  the local rows still exist, so the local-row refill covers it. Both paths
  therefore keep this device's values (decision: keep them).
- Merge and conflict detection: a device-local column must never count as a
  difference between the local and remote copies. The local copy is stripped
  the same way wherever the two are compared.
- The new nav keys get the `active_diver_id` treatment: filtered on export,
  skipped on import (single and batch), and kept by the replace-adopt clear.

### 3. Saving

- `DiverSettingsRepository.updateSettingsForDiver` already computes the changed
  columns. When every changed column is device-local, it writes them without
  touching `updated_at`, does not call `markRecordPending`, and does not fire
  `SyncEventBus.notifyLocalChange`. A save that changes any synced column
  behaves as today; the export strips the device-local part.
- `AppSettingsRepository.setRawSetting` and the id-list writer used for the nav
  orders write device-local keys without `markRecordPending` or a sync event.

Reason: `diver_settings` merges as a whole row, last writer wins. Stamping a
clock for a reminder toggle on a device that has not pulled yet would republish
its stale copy of the synced columns and undo a peer's newer change.

### 4. Existing installs and older peers

- No schema change, no migration, no backfill. Each device keeps the values it
  holds today.
- Old changesets and bases still carry these columns and keys. Import ignores
  them.
- Peers on older builds still send them; this build ignores them. This build
  stops sending them; older builds refill omitted columns from their own row
  in the merge (since v1.5.9), and in replace-adopt since v1.8.1. Known limit:
  a device on a build older than v1.8.1 that runs a replace-adopt resets its
  own copies to the defaults. Accepted.

### 5. Documentation

`docs/guide/multi-device-sync.md` gains a section "What syncs and what stays on
each device":

- Stays on each device: notification settings, theme mode, nav layout (order
  and always-hide-labels), the active diver, App Security (app lock, database
  encryption), the Cloud Sync connection and sync options, backup settings,
  display zoom, the home dashboard card order, data quality detector toggles,
  dive computer Bluetooth pairing and clock sync, the database location, and
  sign-ins to connected services.
- Syncs: everything else in Settings, explicitly including units, language,
  theme preset and accents, map style, and decompression and safety settings.

Each label is checked against the Settings screens before it goes in.

## Testing (TDD)

- Serializer, `diverSettings`:
  - export omits the five columns;
  - importing a full payload (as an older peer sends) keeps the local values of
    the five columns and applies the synced ones;
  - a row new to this device gets the column defaults;
  - a replace-adopt (clear, then refill) keeps this device's values;
  - the same import and adopt checks for `diveComputers.bluetoothAddress`;
  - merge and conflict detection see no difference from device-local columns
    alone.
- Serializer, `settings`: the three nav keys are not exported, are skipped on
  import (single and batch), and survive the replace-adopt clear.
- `DiverSettingsRepository`: a device-local-only save writes the value, leaves
  `updated_at` unchanged and queues nothing; a mixed save stamps and queues.
- `AppSettingsRepository`: writing a device-local key queues nothing; writing
  a synced key still does.

## Out of scope

- A per-setting "sync this" toggle (rejected in the issue).
- Any change to which other settings sync.
