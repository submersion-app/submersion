# SSRF Slice C — Profile Events with Source Tagging (Design)

**Date:** 2026-04-17
**Status:** Draft
**Relates to:** Issue #155 (follow-up); completes the SSRF setpoint-parsing story that Slice A deliberately left open after the backout (see `2026-04-17-ssrf-direct-field-mappings-slice-a-design.md`). Complements PR #137's `ProfileGasSegment` pattern.

## Purpose

Close the SSRF `SP change` event gap that was intentionally left open when Slice A's event-forward-fill path was backed out. The approach is "persist events, derive at read" — matching PR #137's pattern for gas switches. Along with the plumbing, introduce **source tagging** on `DiveProfileEvents` so that imported events, computed events, and user-authored events can coexist cleanly now and drive richer merge rules in future slices.

## Scope Summary

**Level 1 + source tagging.** One schema column (`source`), one event type (`setpointChange`) emitted by the SSRF parser, one derivation helper (`SetpointSegment` list, parallel to `ProfileGasSegment`). Existing `DiveProfileEvents` / `ProfileEvent` / `ProfileEventType` infrastructure is already in place and is extended rather than rebuilt.

## In Scope

1. **Schema change** — add a `source` column to `DiveProfileEvents`.
2. **Domain enum** — new `EventSource` enum (`imported`, `computed`, `user`).
3. **Entity update** — `ProfileEvent` gets a `source` field; factory constructors default appropriately.
4. **Mapper update** — read/write the new `source` field. `mergeEvents` logic is unchanged for this slice.
5. **SSRF parser** — emit `setpointChange` events from `<event name='SP change'>` into a new top-level `events` list on each parsed dive (analogous to the existing `gasSwitches` list).
6. **Repository** — add `insertProfileEvents`, `getProfileEventsForDive`, `deleteProfileEventsForDive` methods on the dive repository.
7. **Import pipeline** — persist parsed events with `source: EventSource.imported`.
8. **Derivation helper** — `SetpointSegment` class + `loadSetpointSegments(diveId)` loader + `setpointAt(segments, timestamp)` query, parallel to `ProfileGasSegment`.
9. **Tracker correction** — restore `Sample setpoint` to `[x]` in the combined and SSRF sub-tables with a note that closure is now via persisted events + derivation rather than per-sample forward-fill at import.

## Out of Scope (Deferred)

- **Other SSRF event types** (bookmarks, alarms, ceiling violations, ascent-rate warnings) — Level 2 / 3 scope for a later slice.
- **UDDF parser parity** — separate slice if audit reveals gaps. UDDF importer already references `ProfileEvent`, but depth of wiring is not reviewed in this slice.
- **Merge rule refinement** — `mergeEvents` retains its current `(timestamp, eventType)` dedup with "auto-wins" collision rule. Source tagging is available for future use but does not change merge behavior this slice.
- **Migration of existing consumers of `DiveProfiles.setpoint`** — the setpoint column is still written by the direct `<sample setpoint='...'>` attribute path (preserved after the Slice A backout). No consumer migration in this slice.
- **UI surfacing** of imported events on the profile chart — may already exist via the `mergeEvents` + analysis provider flow; not audited here. If it doesn't, it's a follow-up.
- **Round-trip through `uddf_export_builders.dart`** — ensuring imported events survive UDDF re-export is a separate concern.

## Architecture Changes

**Files touched (code):**
- `lib/core/database/database.dart` — add `source` column to `DiveProfileEvents`; add migration.
- `lib/core/constants/enums.dart` — add `EventSource` enum.
- `lib/features/dive_log/domain/entities/profile_event.dart` — add `source` field and defaults on factories.
- `lib/features/dive_log/domain/services/profile_event_mapper.dart` — read/write `source`.
- `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` — add `_parseProfileEvents` method; emit `events` in parser output.
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — add `insertProfileEvents`, `getProfileEventsForDive`, `deleteProfileEventsForDive`.
- `lib/features/dive_log/domain/services/` — new file `setpoint_segments.dart` (or similar) for `SetpointSegment` and the segment-loader/query helpers.
- The import pipeline layer (wherever SSRF parser output gets converted to domain entities and persisted — to be identified in the plan phase) — wire the new `events` list through to `insertProfileEvents`.

**Files touched (docs):**
- `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md` — flip `Sample setpoint` rows to closed with a derivation note.

**Files touched (tests):**
- `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` — add test group for `events` emission.
- `test/features/dive_log/data/repositories/dive_repository_impl_test.dart` (or equivalent) — round-trip tests for the new repo methods.
- `test/features/dive_log/domain/services/` — new test file for `SetpointSegment` + derivation helpers.
- `test/features/dive_log/domain/entities/profile_event_test.dart` (or equivalent) — source-field defaults on factories.
- Mapper test — updated for source round-trip.

## Detailed Changes

### 1. Schema — `source` column on `DiveProfileEvents`

```dart
class DiveProfileEvents extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get timestamp => integer()();
  TextColumn get eventType => text()();
  TextColumn get severity =>
      text().withDefault(const Constant('info'))();
  TextColumn get description => text().nullable()();
  RealColumn get depth => real().nullable()();
  RealColumn get value => real().nullable()();
  TextColumn get tankId => text().nullable()();
  // NEW in Slice C
  TextColumn get source =>
      text().withDefault(const Constant('imported'))(); // EventSource.name
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Migration: add a new schema version bump. The `ALTER TABLE` adds the column with a default of `'imported'`. Rationale: any rows that predate this slice were written by import flows (the only paths that existed). Defaulting to `imported` on the existing rows is correct retroactively, and defaulting on future inserts that omit the field is a forgiving contract for callers.

### 2. `EventSource` enum (new)

Add to `lib/core/constants/enums.dart`:

```dart
enum EventSource {
  /// Came from outside the app: file import (SSRF, UDDF) or native DC download.
  imported,
  /// Auto-detected by in-app analysis (ascent rate, CNS, ppO2 thresholds, etc.).
  computed,
  /// User-authored in the app (bookmarks, notes).
  user,
}
```

### 3. `ProfileEvent` entity updates

Add a required `source` field with sensible factory defaults:

```dart
class ProfileEvent extends Equatable {
  // ... existing fields ...
  final EventSource source;

  const ProfileEvent({
    // ... existing params ...
    this.source = EventSource.imported,  // safe default
    // ...
  });
}
```

Factory defaults:
- `ProfileEvent.setpointChange(...)` — defaults `source: EventSource.imported`.
- `ProfileEvent.gasSwitch(...)` — defaults `source: EventSource.imported`.
- `ProfileEvent.bookmark(...)` — defaults `source: EventSource.user`.
- `ProfileEvent.ascentStart(...)`, `ProfileEvent.safetyStop(...)`, `ProfileEvent.maxDepth(...)`, `ProfileEvent.ascentRateWarning(...)` — default `source: EventSource.computed` (these are analysis-derived in the current code paths that use them).

Factories that represent events that could legitimately come from either an import or from computation (e.g., `ascentRateWarning` could be imported from a DC or computed by our analysis) should accept an override: `source: EventSource.computed`.

Add `source` to `props` for equality.

### 4. Mapper update

`profile_event_mapper.dart`:
- Extend `mapDiveProfileEventToProfileEvent` to read `dbEvent.source` into the domain entity.
- Add `_parseSource(String)` with fallback to `EventSource.imported` for unknown values (matches the existing pattern used by `_parseEventType` and `_parseSeverity`).
- `mergeEvents` unchanged — no merge-rule changes in this slice.

Add an inverse direction (`mapProfileEventToCompanion` or equivalent) that writes `source.name` into the DB row's `source` column. Look at how existing writes happen for `DiveProfileEvents` today, or follow the pattern used for `GasSwitches` writes in `dive_repository_impl.dart:2985+`.

### 5. SSRF parser — emit events

Add a new private method in `subsurface_xml_parser.dart`:

```dart
/// Parses `<event>` children of a `<divecomputer>` into profile-event maps.
///
/// Currently emits only `SP change` events (setpointChange). Gas-change
/// events remain handled by `_parseGasSwitches` (distinct table / separate
/// pipeline). Future slices may extend this to bookmarks, alarms, etc.
///
/// Setpoint value normalization: Subsurface typically emits `value` in mbar
/// (e.g., 1200 for 1.2 bar) but some third-party exporters use bar (1.2).
/// If the parsed value is greater than 10, divide by 1000.
/// Non-positive values are dropped as implausible.
List<Map<String, dynamic>> _parseProfileEvents(XmlElement divecomputer) {
  final events = <Map<String, dynamic>>[];
  for (final event in divecomputer.findElements('event')) {
    final name = event.getAttribute('name')?.trim().toLowerCase();
    if (name == 'sp change') {
      final timestamp = _parseDurationSeconds(event.getAttribute('time'));
      if (timestamp == null) continue;
      final raw = _parseDouble(event.getAttribute('value'));
      if (raw == null || raw <= 0) continue;
      final bar = raw > 10 ? raw / 1000 : raw;
      events.add({
        'eventType': 'setpointChange',
        'timestamp': timestamp,
        'value': bar,
      });
    }
    // future event types here — one `if` block per name
  }
  return events;
}
```

In `_parseDive`, after the existing gas-switch and profile-point parses:

```dart
final events = divecomputer != null ? _parseProfileEvents(divecomputer) : const <Map<String, dynamic>>[];
if (events.isNotEmpty) result['events'] = events;
```

### 6. Repository methods

In `dive_repository_impl.dart`, follow the pattern already established by `GasSwitches` at line ~2821-3007:

```dart
Future<void> insertProfileEvents(List<ProfileEvent> events) async {
  if (events.isEmpty) return;
  await _db.transaction(() async {
    for (final event in events) {
      final id = event.id.isEmpty ? _uuid.v4() : event.id;
      await _db.into(_db.diveProfileEvents).insert(
        DiveProfileEventsCompanion(
          id: Value(id),
          diveId: Value(event.diveId),
          timestamp: Value(event.timestamp),
          eventType: Value(event.eventType.name),
          severity: Value(event.severity.name),
          description: Value(event.description),
          depth: Value(event.depth),
          value: Value(event.value),
          tankId: Value(event.tankId),
          source: Value(event.source.name),
          createdAt: Value(event.createdAt.millisecondsSinceEpoch),
        ),
      );
    }
    // audit-log hook similar to gas switches
  });
}

Future<List<ProfileEvent>> getProfileEventsForDive(String diveId) async {
  final rows = await (_db.select(_db.diveProfileEvents)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
      .get();
  return rows.map(mapDiveProfileEventToProfileEvent).toList();
}

Future<void> deleteProfileEventsForDive(String diveId) async {
  await (_db.delete(_db.diveProfileEvents)
        ..where((t) => t.diveId.equals(diveId)))
      .go();
}
```

The exact shape should follow whatever conventions are in `dive_repository_impl.dart` (audit log, sync tracking, etc.) — match the `GasSwitches` block.

### 7. Import pipeline wiring

Wherever the SSRF parser output is consumed and converted to domain entities (to be identified in the plan — likely in a pipeline service in `lib/features/universal_import/` or similar), the new `events` list must be:
- Mapped from parser-output maps to `ProfileEvent` domain entities with appropriate factories
- Persisted via `insertProfileEvents` with `source: EventSource.imported`
- Associated to the correct `diveId` (assigned during the persistence transaction)

This integration point needs a short discovery step in the plan phase — the Slice A work did not touch the pipeline-to-persistence layer.

### 8. Derivation helper — `SetpointSegment` (Option B, chosen)

New file `lib/features/dive_log/domain/services/setpoint_segments.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/core/constants/enums.dart';

/// A contiguous time range during which a single CCR setpoint was active.
///
/// Built from a stream of `setpointChange` events. `endTimestamp` is
/// exclusive — equal to the next segment's `startTimestamp`, or
/// `null` for the final (open-ended) segment.
class SetpointSegment extends Equatable {
  final int startTimestamp; // seconds from dive start
  final int? endTimestamp;  // exclusive; null = until end of dive
  final double setpoint;    // bar

  const SetpointSegment({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.setpoint,
  });

  bool containsTimestamp(int t) =>
      t >= startTimestamp && (endTimestamp == null || t < endTimestamp!);

  @override
  List<Object?> get props => [startTimestamp, endTimestamp, setpoint];
}

/// Builds a list of setpoint segments from `setpointChange` events.
///
/// Events should already be sorted by timestamp; this function will sort
/// defensively if they are not. Consecutive events with the same setpoint
/// value are coalesced (they describe the same segment).
///
/// Returns an empty list when no setpointChange events exist; callers must
/// handle "no CCR events" as a legitimate no-segment state.
List<SetpointSegment> buildSetpointSegments(List<ProfileEvent> events) {
  final setpointEvents = events
      .where((e) => e.eventType == ProfileEventType.setpointChange && e.value != null)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  if (setpointEvents.isEmpty) return const [];

  final segments = <SetpointSegment>[];
  for (var i = 0; i < setpointEvents.length; i++) {
    final e = setpointEvents[i];
    final nextTs = i + 1 < setpointEvents.length
        ? setpointEvents[i + 1].timestamp
        : null;
    // Skip zero-length segments when consecutive events share a timestamp
    if (nextTs != null && nextTs == e.timestamp) continue;
    // Coalesce consecutive equal setpoints
    if (segments.isNotEmpty &&
        segments.last.setpoint == e.value &&
        segments.last.endTimestamp == e.timestamp) {
      final prev = segments.removeLast();
      segments.add(SetpointSegment(
        startTimestamp: prev.startTimestamp,
        endTimestamp: nextTs,
        setpoint: e.value!,
      ));
    } else {
      segments.add(SetpointSegment(
        startTimestamp: e.timestamp,
        endTimestamp: nextTs,
        setpoint: e.value!,
      ));
    }
  }
  return segments;
}

/// Returns the active setpoint at [timestamp], or null if no segment
/// covers that time (i.e., [timestamp] is before the first setpointChange).
double? setpointAt(List<SetpointSegment> segments, int timestamp) {
  for (final s in segments) {
    if (s.containsTimestamp(timestamp)) return s.setpoint;
  }
  return null;
}
```

Usage at the read/analysis layer:

```dart
final events = await diveRepository.getProfileEventsForDive(diveId);
final segments = buildSetpointSegments(events);
final setpoint = setpointAt(segments, sampleTimestamp);
```

This parallels PR #137's `ProfileGasSegment` pattern: load the event stream once per dive, build segment list once, query many times.

### 9. Tracker updates

In `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md`:

- **Combined table `Sample setpoint` row** — `Fixed [ ]` → `[x]`, SSRF Support `Partial` → `Yes`:
  ```markdown
  | Sample `setpoint` | [x] | Medium | Yes | Yes | Yes |
  ```

- **SSRF sub-table `Sample \`setpoint\`` row** — update the Why cell to describe the new architecture:
  ```markdown
  | Sample `setpoint` | [x] | Medium | Direct `<sample setpoint=...>` attribute is parsed into `DiveProfiles.setpoint`. `SP change` events are persisted in `DiveProfileEvents` with `source='imported'`, and `SetpointSegment` + `setpointAt(...)` derives per-sample setpoint on read, matching PR #137's `ProfileGasSegment` pattern |
  ```

- **Combined table `Profile events / markers` row** — change Fixed from `[ ]` to `Partial` (or introduce a stronger rating) since one event type is now end-to-end:
  ```markdown
  | Profile events / markers | [ ] | Medium | Yes | Partial | Partial |
  ```
  (Partial on both UDDF and SSRF reflects: SSRF has setpointChange but no other event types; UDDF's depth of wiring is unaudited in this slice.)

- **SSRF sub-table `Profile events / markers` row** — update:
  ```markdown
  | Profile events / markers | [ ] | Medium | `setpointChange` events are persisted via `DiveProfileEvents`; bookmarks, alarms, ceiling violations, and other event types remain unmapped. A future slice should extend `_parseProfileEvents` to cover these |
  ```

- **Notes section** — add a new bullet:
  ```markdown
  - Slice C (2026-04-17) adds source tagging to `DiveProfileEvents` (new `source` column) and closes SSRF `SP change` event persistence via a `setpointChange` event type, consumed by a `SetpointSegment` derivation helper parallel to PR #137's `ProfileGasSegment`. Further SSRF event types (bookmarks, alarms) remain open. See `docs/superpowers/specs/2026-04-17-ssrf-slice-c-profile-events-design.md`.
  ```

## Data Flow

```
Subsurface XML
     |
     v
SubsurfaceXmlParser._parseDive
     |
     +--- existing: _parseProfile, _parseCylinders, _parseGasSwitches
     +--- NEW: _parseProfileEvents -> result['events'] = [...]
     |
     v
[import pipeline maps result['events'] to ProfileEvent entities
 with source: EventSource.imported and appropriate diveId]
     |
     v
DiveRepository.insertProfileEvents(List<ProfileEvent>)
     |
     v
DiveProfileEvents table (persisted with source='imported')
     |
     v
[Analysis / UI layer, on read:]
     |
     +--- DiveRepository.getProfileEventsForDive(diveId)
     +--- buildSetpointSegments(events)
     +--- setpointAt(segments, sampleTimestamp)
     v
[Per-sample setpoint, derived at read time]
```

## Testing Strategy

### SSRF parser tests
New test group `profile events` in `subsurface_xml_parser_test.dart`:

- `emits setpointChange event from SP change with mbar value` — value=`'1200'` yields an event with setpoint=`1.2`.
- `emits setpointChange event from SP change with bar value` — value=`'1.2'` yields an event with setpoint=`1.2`.
- `drops SP change events with non-positive value` — value=`'0'` and `'-100'` produce no events.
- `drops SP change events with missing timestamp` — malformed `time` attribute yields no event.
- `emits events in timestamp order` — multiple SP change events produce a sorted list.
- `no events emitted when no SP change present` — `result.containsKey('events')` is false for a non-CCR dive.

### Mapper tests
- Round-trip: `ProfileEvent` with `source: EventSource.imported` → DB → loaded back with same source.
- Unknown source string in DB → defaults to `EventSource.imported`.

### Repository tests
- `insertProfileEvents` writes all events with correct diveId, timestamp, source.
- `getProfileEventsForDive` returns events in timestamp order.
- `deleteProfileEventsForDive` removes only that dive's events.

### Derivation helper tests
- `buildSetpointSegments` with one event at t=0 → one segment from 0 to null-end.
- `buildSetpointSegments` with two events at t=0 and t=1500 → two segments, first ending at 1500.
- `buildSetpointSegments` coalesces consecutive events with the same setpoint.
- `setpointAt` at time before first segment → null.
- `setpointAt` at time exactly at segment start → that segment's setpoint.
- `setpointAt` at time in middle of a segment → that segment's setpoint.
- `setpointAt` after the last segment's start (when endTimestamp is null) → last segment's setpoint.

### End-to-end integration test
- Parse an SSRF CCR fixture with SP change events.
- Persist via the pipeline.
- Load events via `getProfileEventsForDive`.
- Build segments and query `setpointAt` at several sample timestamps — values must match expected.

### Regression
- All 39 existing parser tests must continue to pass.
- Existing `GasSwitches` round-trip tests must continue to pass.

## Migration Plan

The schema change is a single `ALTER TABLE` adding the `source` column with a default. Drift's migration system should handle this cleanly. The plan phase will identify the exact migration version number and fit it into the existing migration ladder in `database.dart`.

Rollback: if the slice is reverted, the `source` column stays (columns can't be dropped cleanly in SQLite without table-rebuild, which is more disruptive than a leftover column). The migration is forward-compatible with Slice C being backed out — old code just ignores the column.

## Required Plan-Phase Discovery

The plan must begin with a discovery task that answers three questions before any implementation starts:

1. **Where is the SSRF parser → persistence bridge?** The parser output (maps including `events`, `tanks`, `profile`, etc.) is consumed by an import pipeline service. Locate the file(s) that (a) receive the parser payload, (b) map its keys to domain entities, and (c) call repository methods to persist. This is the integration point for piping `result['events']` through to `insertProfileEvents`.

2. **What does `DiveProfileEvents` currently get written from?** Existing references (grep found `sync_data_serializer.dart`, `uddf_full_import_service.dart`, `uddf_export_builders.dart`, `reparse_service.dart`, `dive_computer_repository_impl.dart`) need to be audited to:
   - Confirm whether they currently write to `DiveProfileEvents` or only to `GasSwitches`.
   - Identify each write site that must be updated to set the new `source` field.
   - Flag any site where the source is ambiguous (e.g., sync-serialized events from another device may be `imported` or `computed` depending on their origin).

3. **What's the current Drift migration version, and which version should this slice add?** The plan must pin the migration number and the exact `ALTER TABLE` SQL, and verify the migration ladder in `database.dart` still chains correctly.

These findings drive the rest of the plan. The plan's first task should be "Discovery" and subsequent tasks should reference the discovered file paths and version numbers by name.

## Risks

- **`DiveProfileEvents` write sites missing source** — any existing code that writes to the table without setting `source` will rely on the column's `DEFAULT 'imported'`. This is acceptable only if every current write is in fact an import. If `dive_computer_repository_impl.dart` (for BLE/USB native downloads) writes `DiveProfileEvents` today, its events are "imported from DC" and `imported` is correct. But if any site writes a computed event (e.g., a real-time analysis hook), the default would mis-tag it. The discovery step must verify.
- **`DiveProfileEvents` may already have some writes in code I haven't seen** — the search found `DiveProfileEvent` references in `sync_data_serializer.dart`, `uddf_full_import_service.dart`, `uddf_export_builders.dart`, `reparse_service.dart`, and `dive_computer_repository_impl.dart`. The plan phase must audit these to ensure the new `source` field is set appropriately where they write events.
- **`mergeEvents` unchanged but `source` field now present** — any consumer that pattern-matches on `ProfileEvent` exhaustively (e.g., a switch statement without default) will need updating. Low risk but worth verifying during implementation.

## Follow-Up Slices

- **Slice C.2** — extend SSRF `_parseProfileEvents` to cover bookmarks, alarms, ceiling violations, ascent rate warnings, deco violations. Level 2.
- **Slice C.3** — UDDF parity audit; extend UDDF importer to emit the same event types.
- **Slice C.4** — refine `mergeEvents` rules to be source-aware (e.g., keep both imported-analysis and computed-analysis events at the same timestamp rather than collapsing).
- **Slice C.5** — migrate downstream consumers of `DiveProfiles.setpoint` for event-derived values to use `setpointAt` + `SetpointSegment`, deprecating the per-sample column if it becomes unused.
- **Future** — UI pass to display imported events distinctly from computed events (color, icon, or legend). Not a "slice" per se but a UX follow-up.

## Why "Persist Events, Derive at Read"

This slice deliberately chooses the same architectural stance as PR #137:

- The event stream is the **source of truth**. It's what the dive computer (or importing tool) captured.
- Per-sample projections (`DiveProfiles.setpoint`, per-sample `activeTankIndex`) are **derived views**. They should be computable from the events at read time, not stored redundantly at import time.
- Storing derived views at import time creates denormalization: two representations of the same truth, each of which can drift out of sync.
- The cost of derivation is small (a list of segments per dive) and cached by any reasonable consumer pattern.

This stance was the explicit rationale for backing out Slice A's event-forward-fill path: we chose to wait until Slice C could provide persistence + derivation properly rather than ship a stopgap. Slice C fulfills that commitment.
