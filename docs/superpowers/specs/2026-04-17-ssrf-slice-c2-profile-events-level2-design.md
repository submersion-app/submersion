# SSRF Slice C.2 — Profile Events Level 2 (Design)

**Date:** 2026-04-17
**Status:** Draft
**Relates to:** Issue #155 (follow-up). Extends Slice C (PR #243). Complements PR #137's gas-aware analysis.

## Purpose

Extend Slice C's `_parseProfileEvents` + persistence pipeline to cover the common Subsurface XML event types beyond `setpointChange`. Same "persist events, derive at read" architecture. Flat one-to-one mapping from SSRF `name=` attribute to `ProfileEventType` enum values; no numeric-driven variant branching; no new enum values.

## Scope

**In scope:**
- Six new SSRF event types wired into the parser (`bookmark`, `safety stop`, `deco stop`, `ceiling`, `violation`, `ascent`, `po2`). Total with `setpointChange`: 7 event types.
- Three new factory constructors on `ProfileEvent` for ergonomic call-site use: `decoStop`, `decoViolation`, `ppO2High`.
- Switch extension in `uddf_entity_importer.dart:_importDives` with one `case` per new event type.
- Synthetic fixture `profile-events-variety.ssrf` exercising all 7 event types in one dive.
- Tests at parser and importer level verifying wiring.
- Import-gap tracker updated to reflect expanded SSRF event coverage.

**Explicitly out of scope (deferred):**
- UDDF parity — that is Slice C.3.
- Variant branching on event `value` is avoided in general, **except** for
  `po2` which is threshold-split between `ppO2High` (>= 1.4) and `ppO2Low`
  (<= 0.18). Other potential threshold-split types (`ascentRateCritical` at
  extreme ascent rates) remain deferred to future enrichment slices.
- DC-internal alarm names that don't map to user-visible dive concepts: `low battery`, `heading`, `rbt`, `model version`, `workload`. These are skipped with a `developer.log` line.
- Real-world SSRF fixture validation. We are using synthetic fixtures per an explicit brainstorming decision. Mapping correctness is based on Subsurface's documented event vocabulary, not verified against real exports.
- New `ProfileEventType` enum values. The existing 18 cover the mapping.
- UI rendering of events. Persistence only; any consumer (chart overlay, dive summary panel) is a separate downstream slice.

## Event Type Mapping

| SSRF `name=` | `ProfileEventType` | Factory | Severity |
|---|---|---|---|
| `bookmark` | `bookmark` | `ProfileEvent.bookmark(...)` | info |
| `safety stop` | `safetyStopStart` | `ProfileEvent.safetyStop(isStart: true)` | info |
| `deco stop` | `decoStopStart` | `ProfileEvent.decoStop(isStart: true)` (new) | info |
| `ceiling` | `decoViolation` | `ProfileEvent.decoViolation(...)` (new) | alert |
| `violation` | `decoViolation` | `ProfileEvent.decoViolation(...)` (new) | alert |
| `ascent` | `ascentRateWarning` | `ProfileEvent.ascentRateWarning(...)` | warning |
| `po2` (value >= 1.4) | `ppO2High` | `ProfileEvent.ppO2High(...)` (new) | warning |
| `po2` (value <= 0.18) | `ppO2Low` | `ProfileEvent.ppO2Low(...)` (new) | warning |
| `po2` (mid-range) | `ppO2High` (default) | `ProfileEvent.ppO2High(...)` | warning |
| `SP change` | `setpointChange` | `ProfileEvent.setpointChange(...)` | info | *(from Slice C, unchanged)* |

**Name matching**: case-insensitive, trimmed, matching existing `_parseProfileEvents` convention.

**Value payload rules per type**:
- `bookmark`, `safety stop`, `deco stop`: no `value` captured. Event `description` may be populated from optional `description` attribute if present in the XML.
- `ceiling`, `violation`: if `value` attribute present, interpret as ceiling depth (meters) and store on the `ProfileEvent.value` field. Optional.
- `ascent`: `value` interpreted as ascent rate (m/min), stored on `value`. Optional.
- `po2`: `value` interpreted as ppO2 reading (bar). No unit normalization — Subsurface emits these in bar natively. Optional.

**Source tagging**: all events parsed from SSRF land with `source: EventSource.imported`. For event types whose factory default is something else (notably `bookmark` which defaults to `user`), the importer passes an explicit override at the call site.

## Architecture Changes

**Files modified (code):**
- `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` — extend `_parseProfileEvents` with six new `if` blocks.
- `lib/features/dive_log/domain/entities/profile_event.dart` — add three new factory constructors: `decoStop`, `decoViolation`, `ppO2High`.
- `lib/features/dive_import/data/services/uddf_entity_importer.dart` — extend the `switch (eventTypeStr)` in `_importDives` with six new cases.

**Files modified (tests):**
- `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` — rename existing `profile events - setpointChange` group to `profile events` to accommodate broader scope; add six new parser-level tests (one per new event type).
- `test/features/dive_import/data/services/uddf_entity_importer_test.dart` — add two tests: one verifying all 7 event types persist end-to-end, one verifying the `bookmark` source override (`imported`, not `user`).
- `test/features/dive_log/domain/entities/profile_event_test.dart` — add three new factory-default tests for the new factories.

**Files created (fixtures):**
- `test/features/universal_import/data/parsers/fixtures/profile-events-variety.ssrf` — single dive with 7 events demonstrating each mapped type.

**Files modified (docs):**
- `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md` — update combined + SSRF sub-table rows for "Profile events / markers" to reflect expanded coverage. Add Slice C.2 bullet to Notes.

**No schema migration. No new enum values. No DB-level changes.**

## Detailed Changes

### 1. SSRF parser — extend `_parseProfileEvents`

Current state: the method has one `if (name == 'sp change')` block. Extend with six parallel blocks. Pattern:

```dart
static List<Map<String, dynamic>> _parseProfileEvents(
  XmlElement divecomputer,
) {
  final events = <Map<String, dynamic>>[];
  for (final event in divecomputer.findElements('event')) {
    final name = event.getAttribute('name')?.trim().toLowerCase();

    if (name == 'sp change') {
      // ... existing setpointChange block (unchanged) ...
    } else if (name == 'bookmark') {
      final timestamp = _parseDurationSeconds(event.getAttribute('time'));
      if (timestamp == null) continue;
      events.add({
        'eventType': 'bookmark',
        'timestamp': timestamp,
        // description: pulled from optional attribute if present
        if (event.getAttribute('description') != null)
          'description': event.getAttribute('description'),
      });
    } else if (name == 'safety stop') {
      final timestamp = _parseDurationSeconds(event.getAttribute('time'));
      if (timestamp == null) continue;
      events.add({
        'eventType': 'safetyStopStart',
        'timestamp': timestamp,
      });
    } else if (name == 'deco stop') {
      final timestamp = _parseDurationSeconds(event.getAttribute('time'));
      if (timestamp == null) continue;
      events.add({
        'eventType': 'decoStopStart',
        'timestamp': timestamp,
      });
    } else if (name == 'ceiling' || name == 'violation') {
      final timestamp = _parseDurationSeconds(event.getAttribute('time'));
      if (timestamp == null) continue;
      final value = _parseDouble(event.getAttribute('value'));
      events.add({
        'eventType': 'decoViolation',
        'timestamp': timestamp,
        if (value != null) 'value': value,
      });
    } else if (name == 'ascent') {
      final timestamp = _parseDurationSeconds(event.getAttribute('time'));
      if (timestamp == null) continue;
      final value = _parseDouble(event.getAttribute('value'));
      events.add({
        'eventType': 'ascentRateWarning',
        'timestamp': timestamp,
        if (value != null) 'value': value,
      });
    } else if (name == 'po2') {
      final timestamp = _parseDurationSeconds(event.getAttribute('time'));
      if (timestamp == null) continue;
      final value = _parseDouble(event.getAttribute('value'));
      if (value == null || value <= 0) continue; // same guard as SP change
      events.add({
        'eventType': 'ppO2High',
        'timestamp': timestamp,
        'value': value,
      });
    }
  }
  return events;
}
```

Each block is independent. Shared `_parseDurationSeconds` / `_parseDouble` helpers already exist. Unknown names fall through without emitting.

### 2. `ProfileEvent` — three new factory constructors

Add alongside existing factories:

```dart
factory ProfileEvent.decoStop({
  required String id,
  required String diveId,
  required int timestamp,
  required double depth,
  required DateTime createdAt,
  bool isStart = true,
  EventSource source = EventSource.imported,
}) {
  return ProfileEvent(
    id: id,
    diveId: diveId,
    timestamp: timestamp,
    eventType: isStart
        ? ProfileEventType.decoStopStart
        : ProfileEventType.decoStopEnd,
    depth: depth,
    createdAt: createdAt,
    source: source,
  );
}

factory ProfileEvent.decoViolation({
  required String id,
  required String diveId,
  required int timestamp,
  double? depth,
  double? value,
  String? description,
  required DateTime createdAt,
  EventSource source = EventSource.imported,
}) {
  return ProfileEvent(
    id: id,
    diveId: diveId,
    timestamp: timestamp,
    eventType: ProfileEventType.decoViolation,
    severity: EventSeverity.alert,
    depth: depth,
    value: value,
    description: description,
    createdAt: createdAt,
    source: source,
  );
}

factory ProfileEvent.ppO2High({
  required String id,
  required String diveId,
  required int timestamp,
  required double value,
  double? depth,
  required DateTime createdAt,
  EventSource source = EventSource.imported,
}) {
  return ProfileEvent(
    id: id,
    diveId: diveId,
    timestamp: timestamp,
    eventType: ProfileEventType.ppO2High,
    severity: EventSeverity.warning,
    value: value,
    depth: depth,
    createdAt: createdAt,
    source: source,
  );
}
```

All three default `source: EventSource.imported` because these are typically wiring from an import path (dive computer or file). Explicit override at call sites where needed.

### 3. Import pipeline — extend `_importDives` switch

The switch in `uddf_entity_importer.dart` currently handles `setpointChange` and a `default:` for unknowns. Add six new cases.

```dart
switch (eventTypeStr) {
  case 'setpointChange':
    // ... existing ...
    break;

  case 'bookmark':
    events.add(ProfileEvent.bookmark(
      id: _uuid.v4(),
      diveId: diveId,
      timestamp: timestamp,
      depth: m['depth'] as double?,
      note: m['description'] as String?,
      createdAt: now,
      source: EventSource.imported,  // override the factory default of `user`
    ));
    break;

  case 'safetyStopStart':
    events.add(ProfileEvent.safetyStop(
      id: _uuid.v4(),
      diveId: diveId,
      timestamp: timestamp,
      depth: (m['depth'] as double?) ?? 0.0,
      createdAt: now,
      isStart: true,
      // source default = computed — override to imported
      // NOTE: safetyStop factory does not currently accept source parameter.
      // This needs the same parameter addition as the new decoStop factory.
      // Include this in the plan: add `source: EventSource.imported` to safetyStop factory signature.
    ));
    break;

  case 'decoStopStart':
    events.add(ProfileEvent.decoStop(
      id: _uuid.v4(),
      diveId: diveId,
      timestamp: timestamp,
      depth: (m['depth'] as double?) ?? 0.0,
      createdAt: now,
      isStart: true,
    ));
    break;

  case 'decoViolation':
    events.add(ProfileEvent.decoViolation(
      id: _uuid.v4(),
      diveId: diveId,
      timestamp: timestamp,
      value: m['value'] as double?,
      createdAt: now,
    ));
    break;

  case 'ascentRateWarning':
    events.add(ProfileEvent.ascentRateWarning(
      id: _uuid.v4(),
      diveId: diveId,
      timestamp: timestamp,
      depth: (m['depth'] as double?) ?? 0.0,
      rate: (m['value'] as double?) ?? 0.0,
      createdAt: now,
      // NOTE: ascentRateWarning factory does not currently accept source parameter.
      // The Task 3 review noted this factory exists but source parameter is not yet propagated.
      // Plan must include adding `source: EventSource.imported` to ascentRateWarning factory signature.
    ));
    break;

  case 'ppO2High':
    events.add(ProfileEvent.ppO2High(
      id: _uuid.v4(),
      diveId: diveId,
      timestamp: timestamp,
      value: (m['value'] as double?) ?? 0.0,
      createdAt: now,
    ));
    break;

  default:
    _log.warning('Skipping unknown profile event type from parser: $eventTypeStr');
    break;
}
```

**Factory-parameter augmentation required**: `safetyStop` and `ascentRateWarning` factories (shipped in Slice C) currently take `source` as optional parameter. Verify during the plan phase; if not, the plan must add them. `bookmark` factory already accepts `source` per Slice C Task 3.

### 4. Synthetic fixture

New file `test/features/universal_import/data/parsers/fixtures/profile-events-variety.ssrf`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<divelog program='subsurface' version='3'>
  <dives>
    <dive number='1' date='2026-03-15' time='10:00:00' duration='45:00 min'>
      <divecomputer model='Test' dctype='CCR'>
        <depth max='30.0 m' mean='15.0 m' />
        <event time='0:00 min' name='SP change' value='700' />
        <event time='2:00 min' name='bookmark' description='cool fish' />
        <event time='5:00 min' name='ascent' value='12.5' />
        <event time='10:00 min' name='po2' value='1.65' />
        <event time='25:00 min' name='ceiling' value='18.0' />
        <event time='30:00 min' name='violation' />
        <event time='35:00 min' name='deco stop' />
        <event time='40:00 min' name='safety stop' />
        <sample time='0:30 min' depth='5.0 m' />
        <sample time='5:00 min' depth='25.0 m' />
        <sample time='40:00 min' depth='5.0 m' />
        <sample time='45:00 min' depth='0.5 m' />
      </divecomputer>
    </dive>
  </dives>
</divelog>
```

One fixture covering all 7 event types exercised per dive. Easy to extend when future slices add more types.

### 5. Tests

**Parser-level** (`subsurface_xml_parser_test.dart`):
- Rename group `profile events - setpointChange` → `profile events`.
- Add 6 new tests, one per new event type, each constructing minimal inline XML and asserting the parser emits the expected `{eventType, timestamp, value?, description?}` shape.

**Importer-level** (`uddf_entity_importer_test.dart`):
- Add test: importing `profile-events-variety.ssrf` via the full pipeline calls `insertProfileEvents` once with 7 events of the correct types, in the correct order, with `source: EventSource.imported` on all.
- Add test: bookmark event specifically has `source: EventSource.imported` (not `user`) — pin the factory-default override.

**Entity-level** (`profile_event_test.dart`):
- 3 new tests for new factory defaults. All three new factories default to `source: EventSource.imported`.

**Factory default rationale**: `decoStop`, `decoViolation`, `ppO2High` default to `source: EventSource.imported` even though they could also be generated by in-app analysis (e.g., a local deco-violation detector). The rule we follow across factories is "pick the default that matches the call site with the most traffic, and let less-common callers pass an explicit override." For these three, the primary consumer is the SSRF import pipeline, hence `imported`. This is asymmetric with `ascentRateWarning` (defaults to `computed` because its primary caller today is analysis) — the asymmetry reflects current call-site distribution, not a principled semantic claim.

**Tracker doc**:
- Combined table: `Profile events / markers` → `| [ ] | Medium | Yes | Partial | Partial |` (unchanged — still Partial because UDDF parity is Slice C.3 and DC-internal alarms remain unsupported).
- SSRF sub-table: update Why cell to enumerate the 7 covered types and note what remains.
- New bullet in Notes section summarizing Slice C.2's contribution.

## Testing Strategy

Pinning tests cover:
1. Each parser `if` block against a minimal inline XML fixture with just that one event type (6 tests).
2. The compound `profile-events-variety.ssrf` fixture for end-to-end smoke coverage (1 parser test, 1 importer test).
3. Source-override rule on `bookmark` (1 importer test).
4. New factory defaults (3 entity tests).
5. Unknown event names still log-and-skip (existing Slice C test covers this; no new test needed).

Total new test count: ~11 tests.

## Migration Plan

None. No schema change. Existing `DiveProfileEvents` rows are unaffected.

## Risks

- **Synthetic fixture matches our mapping by construction**: the fixture was written to match the proposed mapping table, so tests passing proves wiring correctness but not real-world correctness. This is an accepted trade-off per the brainstorming Option A decision.
- **Factory parameter augmentation for `safetyStop` / `ascentRateWarning`**: the plan phase must verify whether these factories already accept `source` (they should per Slice C Task 3 review, but this spec was written without re-reading the final post-fix-up factory state). If they don't, the plan must include adding the parameter.
- **Switch statement growth in `_importDives`**: the switch now has 8 cases (7 types + default). Still readable. If C.2's successor (C.2.1, etc.) adds more, at ~12+ cases we should consider extracting an `_eventMaps` registry or mapper table. Not needed this slice.

## Follow-Ups

- **Slice C.3**: UDDF event parity. Unifies the `'events'` vs. `'profileEvents'` parser-output key mismatch and mirrors this mapping for UDDF event parsing.
- **Future enrichment slice**: variant branching on event `value` (e.g., `ascentRateCritical` at rate > 18 m/min, `ppO2Low` at value < 0.16 bar). Decoupled from C.2.
- **UI chart overlay**: render persisted events on the profile chart. Separate presentation-layer work.
- **Real-fixture validation**: once real SSRF files with diverse events are available, audit our synthetic mapping against real event names; correct any mismatches.

## Why Slice C.2 Extends, Doesn't Replace, Slice C's Approach

Slice C established the contract:
1. Parser emits typed event maps into `diveData['events']`.
2. Importer's `_importDives` switch constructs a `ProfileEvent` via the appropriate factory.
3. `insertProfileEvents` persists with `source: EventSource.imported`.
4. Downstream consumers (eventually) derive display/analysis data from persisted events.

Slice C.2 extends the contract at two ends — parser recognizes more event names, importer switch handles more types — without altering the shape in the middle. This is why no schema migration is required and why the test strategy mirrors Slice C's exactly.
