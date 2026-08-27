# SSRF Slice C.3 — UDDF Event Parity (Design)

**Date:** 2026-04-17
**Status:** Draft
**Relates to:** Issue #155 (follow-up). Closes the UDDF-vs-SSRF event-key asymmetry documented in Slice C's `_importDives` block comment. Complements Slice C (PR #243) and Slice C.2 (PR #244).

## Purpose

Fix the long-standing key mismatch that silently drops profile events during Submersion-authored UDDF round-trips, and preserve the richer shape (severity + depth) UDDF emits. No schema work. No new event types. Single-slice closure of the "UDDF events get parsed but never persisted" bug that Slice C surfaced.

## Context

- **UDDF parser** at `lib/core/services/export/uddf/uddf_full_import_service.dart:872` writes parsed events to `diveData['profileEvents']`.
- **SSRF parser** (Slice C) writes to `diveData['events']`.
- **`_importDives` consumer** (Slice C) reads `diveData['events']`.
- **Net effect today**: UDDF events are parsed, never persisted. Submersion→UDDF→Submersion round-trip drops all profile events on the import side.
- **Third-party UDDF files don't have `<profileevents>`** — that element is Submersion-specific, written by our own exporter in `uddf_export_builders.dart:745`. Slice C.3's user impact is bounded to our own round-trip fidelity, not to broader third-party import coverage.

## Scope

**In scope:**
1. **Key unification**: UDDF parser writes to `diveData['events']` instead of `diveData['profileEvents']`.
2. **Rich shape preservation**: `_importDives` reads `severity` and `depth` from UDDF event maps (SSRF maps don't emit these; the code handles the absence gracefully).
3. **Severity override**: when UDDF provides a `severity` string, override the factory's default severity via `ProfileEvent.copyWith(severity: parsed)`. Factory defaults continue to apply when severity is absent (SSRF path).
4. **Depth passthrough**: replace `depth: 0.0` placeholders in the switch cases with `depth: depth ?? 0.0` (required-depth factories) or `depth: depth` (optional-depth factories).
5. **Round-trip test**: in-memory Submersion export → parse → import, verifying end-to-end event preservation.
6. **Tracker update**: combined table `Profile events / markers` row UDDF Support `Partial` → `Yes` (with qualifier note).

**Explicitly out of scope:**
- Third-party UDDF event parsing (Diviac, Shearwater Cloud, etc. — would require vendor-specific parsing paths; separate slice).
- `uddf_export_builders.dart` changes — the exporter already writes the format the parser reads. No two-way change here.
- New event types beyond the 8 Slice C + C.2 shipped.
- Schema migration.
- `ProfileEvent` factory signature changes (severity handled via `copyWith`, not added to factories).
- UI for displaying events (still deferred).

## Shape Analysis

**SSRF parser output (per event map):**
```
{
  'eventType': String,     // required
  'timestamp': int,        // required
  'value': double,         // optional
  'description': String,   // optional (bookmark only)
}
```

**UDDF parser output (per event map):**
```
{
  'eventType': String,     // required
  'timestamp': int,        // required (from <time>)
  'severity': String,      // optional — UDDF-specific
  'depth': double,         // optional — UDDF-specific
  'value': double,         // optional
  'description': String,   // optional
  'tankRef': String,       // optional — UDDF-specific, unused by _importDives today
}
```

**Observation**: UDDF is a strict superset of SSRF. Adding UDDF support to `_importDives` is non-breaking for SSRF — the SSRF code path continues to read `value`/`description` as before and simply ignores the absent UDDF-specific keys. `tankRef` is ignored by `_importDives` in this slice (gas-switch-specific; we don't currently have a factory that wires tankRef into a non-gas-switch event type).

## Architecture Changes

**Files modified (code):**
- `lib/core/services/export/uddf/uddf_full_import_service.dart` — one-line key rename (`profileEvents` → `events`).
- `lib/features/dive_import/data/services/uddf_entity_importer.dart` — extend the events-persistence block in `_importDives`: extract `severity` and `depth` from the event map before the switch, use UDDF's `depth` when present in factory calls, wrap each factory call with a `copyWith(severity: ...)` override for UDDF-sourced events.

**Files modified (tests):**
- `test/features/dive_import/data/services/uddf_entity_importer_test.dart` — add a round-trip test: construct `ProfileEvent` entities → export UDDF via `UddfExportBuilder` → parse via `UddfFullImportService` → feed back through `_importDives` → verify all 8 event types preserved with correct severity and depth.

**Files modified (docs):**
- `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md` — combined table + UDDF sub-table rows for `Profile events / markers`, plus Slice C.3 note bullet.

**No schema migration. No new enum values. No new factories. No `ProfileEvent` API changes.**

## Detailed Changes

### 1. UDDF parser key rename

`uddf_full_import_service.dart:872`:

```dart
// Before:
diveData['profileEvents'] = eventsList;

// After:
diveData['events'] = eventsList;
```

That's the entire fix for key unification. All other fields on each event map are already extracted correctly by the UDDF parser (lines 833-869).

### 2. `_importDives` rich-shape extraction

In `uddf_entity_importer.dart` events-persistence block (around line 1232 after Slice C.2), update the per-event extractions above the switch:

```dart
final timestamp = m['timestamp'] as int?;
if (timestamp == null) continue;
final value = m['value'] as double?;
final description = m['description'] as String?;
// NEW (Slice C.3): UDDF provides severity and depth; SSRF does not.
final severity = m['severity'] as String?;
final depth = m['depth'] as double?;
```

Add a `_parseSeverity(String) → EventSeverity?` helper on the class (or extract the one from `profile_event_mapper.dart` into a shared place). Pattern:

```dart
EventSeverity? _parseSeverity(String? raw) {
  if (raw == null) return null;
  for (final value in EventSeverity.values) {
    if (value.name == raw) return value;
  }
  return null;
}
```

Returns null on unknown/absent → caller treats null as "no override."

Introduce a local closure `applyOverrides` in the events-persistence block, just above the switch:

```dart
ProfileEvent applyOverrides(ProfileEvent event) {
  final severityOverride = _parseSeverity(severity);
  if (severityOverride != null) {
    return event.copyWith(severity: severityOverride);
  }
  return event;
}
```

Each switch case now wraps its factory call:

```dart
case 'decoViolation':
  events.add(applyOverrides(ProfileEvent.decoViolation(
    id: _uuid.v4(),
    diveId: diveId,
    timestamp: timestamp,
    depth: depth, // NEW: was absent; now UDDF-provided when available
    value: value,
    createdAt: now,
  )));
  break;
```

For factories where `depth` is required (`safetyStop`, `decoStop`, `ascentRateWarning`):

```dart
case 'safetyStopStart':
  events.add(applyOverrides(ProfileEvent.safetyStop(
    id: _uuid.v4(),
    diveId: diveId,
    timestamp: timestamp,
    depth: depth ?? 0.0, // UDDF may provide; SSRF falls back to 0.0 placeholder
    createdAt: now,
    isStart: true,
    source: EventSource.imported,
  )));
  break;
```

All 8 switch cases get the `applyOverrides(...)` wrapper.

### 3. Round-trip test

New test in `test/features/dive_import/data/services/uddf_entity_importer_test.dart`, in the Profile events persistence group:

```dart
test('UDDF round-trip preserves all 8 event types with severity and depth',
    () async {
  // 1. Build a list of ProfileEvents covering each of the 8 types.
  //    Each carries a distinctive (timestamp, eventType, severity, value, depth)
  //    tuple so we can verify individual preservation.
  final sourceEvents = [
    ProfileEvent.setpointChange(
      id: 'e1', diveId: 'd1', timestamp: 0, setpoint: 0.7, createdAt: now),
    ProfileEvent.bookmark(
      id: 'e2', diveId: 'd1', timestamp: 120, depth: 5.0,
      note: 'cool fish', createdAt: now),
    ProfileEvent.ascentRateWarning(
      id: 'e3', diveId: 'd1', timestamp: 300, depth: 10.0,
      rate: 12.5, createdAt: now),
    ProfileEvent.ppO2High(
      id: 'e4', diveId: 'd1', timestamp: 600, value: 1.65, createdAt: now),
    ProfileEvent.ppO2Low(
      id: 'e5', diveId: 'd1', timestamp: 700, value: 0.15, createdAt: now),
    ProfileEvent.decoViolation(
      id: 'e6', diveId: 'd1', timestamp: 1500, value: 18.0, createdAt: now),
    ProfileEvent.decoStop(
      id: 'e7', diveId: 'd1', timestamp: 2100, depth: 6.0, createdAt: now),
    ProfileEvent.safetyStop(
      id: 'e8', diveId: 'd1', timestamp: 2400, depth: 5.0, createdAt: now),
  ];

  // 2. Construct a minimal dive with these events and export to UDDF XML
  //    via UddfExportBuilder. (Exact call signature depends on exporter API —
  //    the plan phase should discover the right entry point.)
  final uddfXml = await buildUddfForDive(dive, sourceEvents);

  // 3. Parse the UDDF XML back via UddfFullImportService.
  final importResult = await uddfImportService.parse(uddfXml);
  final diveData = importResult.dives.first;
  final parsedEvents = diveData['events'] as List<Map<String, dynamic>>;

  // 4. Feed through _importDives via importer.import(...) with the full
  //    mock harness (mirror the Slice C.2 test setup).
  // 5. Verify insertProfileEvents was called with 8 ProfileEvents,
  //    correct types in same order, severities preserved where exporter
  //    wrote them, depths preserved where exporter wrote them.
});
```

Concrete test code must match the existing test harness style in the file. The plan phase will identify the exact exporter API (whether a single `buildUddfForDive` call exists or we need to assemble from lower-level builders).

### 4. Tracker update

In `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md`:

**Combined table `Profile events / markers` row**: change `UDDF Support` from `Partial` to `Yes`. Keep `Fixed` as `[ ]` because third-party UDDF imports still don't have `<profileevents>` and that's not what this slice fixes.

```markdown
| Profile events / markers | [ ] | Medium | Yes | Yes | Yes |
```

Add a footnote if table width allows, or update the SSRF/UDDF sub-table rows to carry the nuance.

**UDDF sub-table `Profile events / markers` row**: update Why cell:

```markdown
| Profile events / markers | [x] | Medium | Submersion-authored UDDF round-trip preserves all 8 event types via the `<profileevents>` element. `diveData['events']` key unified with SSRF path (Slice C.3). Third-party UDDF parsers that don't emit `<profileevents>` remain out of scope |
```

**Slice C.3 bullet in Notes**:

```markdown
- Slice C.3 (2026-04-17) fixes the UDDF-vs-SSRF event-key mismatch (UDDF parser now writes `diveData['events']` instead of `diveData['profileEvents']`). Extends `_importDives` to consume UDDF's richer event shape (severity, depth) via post-construction `copyWith` overrides. Round-trip test confirms Submersion-authored UDDF exports preserve all 8 event types end-to-end. See `docs/superpowers/specs/2026-04-17-ssrf-slice-c3-uddf-event-parity-design.md`.
```

## Testing Strategy

**Primary test** — the round-trip test described above. Exercises the full chain:
1. ProfileEvent entities → UDDF XML (exporter-side)
2. UDDF XML → parser output with `events` key
3. Parser output → `_importDives` switch → ProfileEvent entities with preserved metadata

**No new unit tests for the UDDF parser** — its output shape doesn't change except for the key name, and the round-trip test indirectly verifies the key rename works (if the rename were missed, `diveData['events']` would be empty and the test would fail).

**No new unit tests for individual switch cases** — the rich-shape additions to each case (depth passthrough, severity override) are exercised via the round-trip test's type-by-type assertions.

**Regression coverage**:
- All Slice C and Slice C.2 parser and importer tests continue to pass. The SSRF path's event maps don't include `severity` or `depth`, so the new extractions in `_importDives` simply produce null — no behavior change on the SSRF path.
- The existing UDDF import flow (without events) continues unaffected.

## Risks

- **`copyWith` re-allocation**: every UDDF event that carries a severity now allocates a second `ProfileEvent` (factory result, then copyWith result). Trivial per-event cost; negligible at dive-scale (dozens of events typical, thousands at worst).
- **Shared helper location**: `_parseSeverity` exists in `profile_event_mapper.dart` as a private helper. Duplicating it in `uddf_entity_importer.dart` is pragmatic for this slice; extracting to a shared utility is scope creep. The plan phase should default to duplication unless a clean extraction opportunity emerges.
- **Test setup complexity for round-trip**: building UDDF XML through the exporter requires constructing a full `Dive` entity plus its dependencies (DiveTanks, etc.). The plan phase must identify the minimal construction recipe and whether a helper exists in the test infrastructure.
- **Hidden assumptions in the exporter**: the round-trip test assumes `uddf_export_builders.dart` writes every event field (`severity`, `depth`, `value`, `description`) that the parser reads. If the exporter omits any field, the round-trip would silently lose it. Plan-phase discovery should verify the exporter writes everything the parser expects.

## Follow-Up Slices

- **Third-party UDDF event parsing** — parse vendor-specific event vocabularies (Diviac, Shearwater Cloud) if those formats are added to the universal-import path. Separate slice, different parsers.
- **Severity on factories** — if a future slice wants to avoid `copyWith` for severity, adding a `severity` parameter to each factory is a one-shot cleanup. Not needed for C.3.
- **UI consumption** — profile chart overlays, dive-summary event lists, etc. Presentation-layer work orthogonal to persistence.
- **`tankRef` consumption** — UDDF carries `tankRef` on events. We don't use it today for non-gas-switch events. If a future feature wants to associate a bookmark or violation with a specific tank, this is the hook.

## Why This Is a Single-Slice Fix

Slice C.3 is intentionally narrow. It could be subdivided:
- A: key unification only
- B: rich shape extraction and override
- C: round-trip test

But A without B means UDDF events land with wrong severity/depth on import. A+B without C means we have no regression safety net for exporter/parser drift. The three together are cohesive: "UDDF events are now imported correctly and stay correct under round-trip." The design spec for each of A/B/C in isolation would be smaller than the overhead of splitting them up.
