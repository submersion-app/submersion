# GPS Track Logging - Design

**Date:** 2026-07-06
**Source:** GitHub discussion #289 (MacDive-style GPS logger)
**Status:** Approved design, pending implementation plan

## Problem

Most dive computers have no GPS. Divers want dive entry positions and automatic
dive-site matching without buying GPS hardware. The phone sits on the boat all
day anyway: let it record a timestamped GPS track, then match dive timestamps
from the dive computer against the track to determine where each dive happened.

## Requirements (validated with user)

1. **Recording:** manual start/stop session, background-capable. Diver taps
   Start at the dock; the phone records with the screen locked and the app
   backgrounded until Stop. No automatic/geofenced start (deferred).
2. **Cross-device:** tracks sync via the existing HLC changeset sync, so a
   dive imported on the Mac matches against a track recorded on the phone.
3. **Match application:** entry/exit GPS is stamped automatically from the
   track (objective timestamp lookup; never overwrites GPS the computer or
   user already provided). Site linking flows through the existing
   match-sites review page. No new review UI.
4. **Triggers:** matching runs at import time, when a track arrives (local
   stop or sync), and via a manual "Match dives to GPS logs" action.
5. **Engine:** geolocator streaming (approach A) - no new plugin or paid
   dependency. Accepts the rare force-kill gap, mitigated by checkpointing
   and buffer recovery.

## Data model

### New synced table: `gps_tracks` (one row per recording session)

| Column | Type | Notes |
| --- | --- | --- |
| `id` | text PK | UUID |
| `startTime` | int | Wall-clock-as-UTC epoch, same convention as `dives.entryTime` |
| `endTime` | int nullable | Null while recording |
| `tzOffsetMinutes` | int | Device UTC offset at recording start (reconstructs true UTC for future GPX export) |
| `deviceName` | text nullable | Recording device label |
| `pointCount` | int | List display without decoding the blob |
| `points` | blob | Gzipped JSON array of `[wallClockEpochSeconds, lat, lon, accuracyMeters]` |
| `hlc` | text | Standard sync version column |

Rationale for blob-per-session: matching always reads a whole track and never
queries individual points; sync cost drops from thousands of HLC rows per boat
day to one row (tens of KB gzipped). The sync serializer's table descriptors
already support blob tables.

Sync integration (all three points required):

- Add to `_hlcTables` in `database.dart`.
- Tombstones via `DeletionLog` on delete.
- Descriptor plus per-table export/import/merge cases in
  `sync_data_serializer.dart` (copy the checklists-table precedent).

### New local-only table: `gps_track_points_local` (not synced, no HLC)

Append-only buffer of points during recording: `trackId`, `timestamp`, `lat`,
`lon`, `accuracy`. On Stop, points are encoded into the blob, the `gps_tracks`
row is finalized, and the buffer is cleared. Crash safety: on app startup,
orphaned buffer rows are finalized into their track automatically and a notice
is surfaced ("recording was interrupted - track saved through HH:MM"). While
recording, the `gps_tracks` row is checkpointed (blob rewritten) every ~10
minutes so the synced copy is never more than 10 minutes stale, without
per-point HLC churn.

### Timestamp convention (load-bearing)

Dives store local-wall-clock-reinterpreted-as-UTC epochs (`diveDateTime`,
`entryTime`, `exitTime` in `database.dart:339-345`). geolocator returns real
UTC. Each point's timestamp is converted at capture time using the device's
current timezone: the phone on the boat is in the same timezone the dive
computer's wall clock is set to, matching the app-wide assumption. Points
therefore compare directly against `dive.entryTime` with no conversion at
match time, on any device.

### Dives table: no changes

Matching only fills null `entryLatitude` / `entryLongitude` / `exitLatitude` /
`exitLongitude` (`database.dart:472-475`). Computer-provided or manually set
GPS is never overwritten, so no provenance column is needed.

Schema migration: next version after current (`currentSchemaVersion` is 100 at
design time; use the next free version at implementation). Create both tables
with idempotent `CREATE TABLE IF NOT EXISTS` per the migration pattern.

## Recording service

`GpsTrackRecorder` singleton in `lib/features/gps_log/` owning the session
lifecycle:

- **Start:** verify location services and permission (reuse
  `LocationService.checkPermission` / `requestPermission`), insert the
  `gps_tracks` row with null `endTime`, subscribe to
  `Geolocator.getPositionStream`.
- **While recording:** each position passes an accuracy gate (drop fixes worse
  than 100 m), is converted to wall-clock-as-UTC, and is appended to the local
  buffer. A keepalive timer records a point every 5 minutes even when
  stationary so track coverage is continuous and the UI can show "last fix
  N min ago".
- **Stop:** encode blob, finalize row, clear buffer, then run the matching
  sweep over the new track.
- **Recovery:** on startup, finalize orphaned buffer rows and surface a
  notice.

Stream settings: `distanceFilter: 20` m, high accuracy. A moored boat emits
almost nothing (battery duty-cycles down); a moving boat logs a point every
20 m.

### Platform configuration

| Platform | Changes |
| --- | --- |
| Android | Uncapped `ACCESS_FINE_LOCATION` (current declaration is `maxSdkVersion=30` for BLE only), `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`. Use geolocator `AndroidSettings(foregroundNotificationConfig: ...)` for a persistent notification while recording. |
| iOS | Add `location` to `UIBackgroundModes`; update location usage-description strings to mention track recording; `AppleSettings` with `allowBackgroundLocationUpdates` and `showBackgroundLocationIndicator`. |
| Desktop (macOS/Windows/Linux) | Recording hidden; matching and track management still available since tracks sync. |

No "Always" location permission: the session starts in the foreground, and
both platforms allow a foreground-started stream to continue in the background
under While-In-Use (iOS blue indicator, Android foreground-service
notification).

## Matching

`GpsTrackMatcher`: pure lookup logic, separate from triggers.

- **Candidates:** dives with null entry GPS. Dive start =
  `entryTime ?? diveDateTime`; dive end = `exitTime ?? start + duration`.
- **Lookup:** find a track whose `[startTime - 30 min, endTime + 30 min]`
  window contains the dive start. Entry position = track position at dive
  start, linearly interpolated between bracketing points, or nearest point if
  the dive time falls just outside the track edge within the 30-minute
  tolerance. Exit position likewise at dive end. If the nearest usable point
  is more than 30 minutes away, no match.
- **Write path:** stamp the four GPS columns via the dive repository (nulls
  only), then hand stamped dive IDs to the existing `SiteMatchingService`
  flow (`computeProposals` / `/dives/match-sites` review page).

### Triggers (all funnel into the same matcher)

1. **Import time:** after `DiveImportService.importDives` returns, sweep the
   imported IDs against stored tracks before the import-summary step, so the
   existing "Match sites" button benefits immediately.
2. **Track arrival:** when a track finalizes locally (Stop) or lands via
   sync, sweep GPS-less dives against it. Closes the "Mac imported before the
   phone synced" race.
3. **Manual:** "Match dives to GPS logs" action on the GPS Logger page.

After an automatic sweep stamps dives, a snackbar/banner offers "N dives
positioned - review site matches" linking to `/dives/match-sites`.

### Reparse guard

`reparse_service.dart` rewrites GPS columns from parsed data. It must write
`Value.absent()` when the parser has no GPS so a reparse cannot clobber
log-stamped positions.

## UI

"GPS Logger" card on the Tools page routed to `/tools/gps-logger`:

- Start/stop control with live status while recording (elapsed time, point
  count, last-fix accuracy and age).
- List of stored tracks (date, duration, point count, delete).
- Manual "Match dives to GPS logs" action.
- Desktop shows tracks and the match action but no record button.
- All distances/coordinates respect the active diver's unit settings.

## Error handling

- Permission denied: explanatory dialog with a path to system settings.
- Location services off: prompt before starting.
- Mid-session permission revocation or provider loss: keepalive timer notices
  no fresh fix, marks the session interrupted, finalizes what exists.
- Crash: buffer recovery on next launch.
- Poor fixes: accuracy-gated points dropped silently; live UI shows fix
  quality.

## Testing

- Unit tests for the pure parts: blob encode/decode round-trip, wall-clock
  conversion, interpolation and tolerance lookup, never-overwrite rule.
  Fixtures computed, not recalled.
- Recorder lifecycle tests with a fake `Stream<Position>`, including
  crash-recovery from the buffer.
- Sync serializer round-trip tests for `gps_tracks` (export, import, merge,
  tombstone delete).
- Widget tests for the logger page states (idle, recording, interrupted,
  desktop).
- FK-ON round-trip test per project convention.

## Out of scope (deferred)

- Automatic/geofenced recording start.
- Track visualization on a map and GPX export.
- Force re-match that overwrites existing GPS.
- Track retention/auto-pruning policies.

## Key integration points

| Concern | Location |
| --- | --- |
| One-shot location + permissions | `lib/core/services/location_service.dart` |
| Dive GPS columns | `lib/core/database/database.dart:472-475` |
| Dive timestamps | `lib/core/database/database.dart:339-345` |
| Site matcher orchestration | `lib/features/dive_sites/data/services/site_matching_service.dart` |
| Import pipeline hook | `lib/features/dive_computer/data/services/dive_import_service.dart` |
| Reparse GPS mirror | `lib/features/dive_computer/data/services/reparse_service.dart` |
| Post-import matcher UI | `lib/features/import_wizard/presentation/widgets/import_summary_step.dart` |
| Sync serializer | `lib/core/services/sync/sync_data_serializer.dart` |
| Tools page | `lib/features/tools/presentation/pages/tools_page.dart` |
