# SSRF Slice C.3 — UDDF Event Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify the UDDF-vs-SSRF event map key (`profileEvents` → `events`), extend `_importDives` to consume UDDF's richer event shape (severity, depth), and pin the round-trip via an export-then-import test that verifies Submersion's UDDF exporter and importer stay aligned.

**Architecture:** One-line parser key rename + switch-case augmentation in `_importDives`. Severity preserved via post-construction `ProfileEvent.copyWith(severity: parsed)` rather than expanding factory signatures. Depth passthrough replaces the `depth: 0.0` placeholders from Slice C.2 with UDDF-provided depth when available. No schema work; no new factories; no `ProfileEvent` API changes.

**Tech Stack:** Dart 3 + Flutter 3 + `package:xml` + `flutter_test` + Drift (all unchanged from Slice C).

**Spec reference:** `docs/superpowers/specs/2026-04-17-ssrf-slice-c3-uddf-event-parity-design.md`

**Branch:** `feat/ssrf-slice-c3` (already created off `feat/ssrf-slice-c2`, which is PR #244 stacked on #243).

---

## Pre-implementation Findings (verified before writing plan)

- **UDDF parser key** is at `lib/core/services/export/uddf/uddf_full_import_service.dart:872`: currently `diveData['profileEvents'] = eventsList;`. Single line to change.
- **UDDF exporter writes all fields the parser reads** (audit of `uddf_export_builders.dart:742-786`):
  - `time` → `timestamp`
  - `eventtype` → `eventType` (uses `ProfileEventType.name`)
  - `severity` → `severity` (uses `EventSeverity.name`, always written)
  - `depth` → `depth` (conditional)
  - `value` → `value` (conditional)
  - `description` → `description` (conditional)
  - `tankref` → `tankRef` (conditional, from `event.tankId`)
  - **No silent drop risk** on round-trip.
- **Exporter entry point for the round-trip test**: `UddfExportBuilders.buildDiveElement(builder, dive, ..., profileEvents: events, ...)`. Static method that writes the `<dive>` element to an `XmlBuilder`; callers wrap it in a `<divelog><dives>...</dives></divelog>` root.
- **`_importDives` events-persistence block** after Slice C.2 extracts `value` and `description` before the switch. Slice C.3 adds `severity` and `depth` extractions alongside.
- **Slice C.2 switch cases** pass `depth: 0.0` placeholder for `safetyStopStart`, `decoStopStart`, `ascentRateWarning`. Slice C.3 changes these to `depth: depth ?? 0.0` where `depth` is the UDDF-extracted variable.

**Commit authorization**: user approved per-task commits for autonomous plan execution (Slice A/C/C.2 precedent).

---

## Task 1: Discovery — confirm pre-findings, log exporter entry-point details

Pure investigation. Produces a discovery note. No code changes beyond the note itself.

**Files:**
- Create: `docs/superpowers/plans/2026-04-17-ssrf-slice-c3-discovery.md`

- [ ] **Step 1.1: Confirm exporter field coverage**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
grep -n "builder.element" lib/core/services/export/uddf/uddf_export_builders.dart | grep -A 1 -B 1 "profileevents\|eventtype\|severity"
```

Expected: confirms the exporter writes `time`, `eventtype`, `severity`, `depth` (conditional), `value` (conditional), `description` (conditional), `tankref` (conditional). Record findings in the discovery note.

- [ ] **Step 1.2: Locate `buildDiveElement` signature**

Run:
```bash
grep -n "static.*buildDiveElement\|buildDiveElement(" lib/core/services/export/uddf/uddf_export_builders.dart | head -5
```

Open the method and record its exact signature (parameter names, required vs. optional, ordering). The round-trip test in Task 4 calls this method — Task 4's code must match the real signature.

- [ ] **Step 1.3: Check whether `profileEvents` is a parameter**

Specifically verify that `buildDiveElement` accepts a `profileEvents` list parameter (it should, given line 743 `if (profileEvents.isNotEmpty)`). Record its exact name and type.

- [ ] **Step 1.4: Identify the UddfImportService parse method**

```bash
grep -n "class UddfFullImportService\|Future.*parse\|parseString" lib/core/services/export/uddf/uddf_full_import_service.dart | head -10
```

Find the public method that accepts XML bytes or a string and returns import results. Record the method signature for Task 4.

- [ ] **Step 1.5: Write the discovery note**

Create `docs/superpowers/plans/2026-04-17-ssrf-slice-c3-discovery.md` with sections:
- **Exporter field coverage**: confirmed list of fields written to each `<event>` element with line numbers.
- **`buildDiveElement` signature**: exact Dart signature. Which params are required, which have defaults, which accept profileEvents.
- **Import service public API**: the method Task 4's round-trip test will call.
- **Any surprises**: anything that doesn't match the plan's pre-findings (e.g., if `buildDiveElement` doesn't take profileEvents directly — then Task 4 needs to use a higher-level service).

Keep it brief — one page. Working doc, not polished.

- [ ] **Step 1.6: Commit**

```bash
git add docs/superpowers/plans/2026-04-17-ssrf-slice-c3-discovery.md
git commit -m "docs(slice-c.3): discovery findings for UDDF event parity"
```

**Do NOT include** the untracked `2026-04-17-*` spec/plan files in any commit.

**If any finding contradicts the plan's pre-findings, STOP and report NEEDS_CONTEXT** — subsequent tasks assume the pre-findings are correct.

---

## Task 2: UDDF parser key rename

One-line change. TDD-driven via an existing-consumer verification.

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart` (line 872)
- Modify or create: a targeted test verifying the key landed correctly

- [ ] **Step 2.1: Inspect and rename the key**

Open `lib/core/services/export/uddf/uddf_full_import_service.dart`. Navigate to line 872:

```dart
if (eventsList.isNotEmpty) {
  diveData['profileEvents'] = eventsList;
}
```

Change to:

```dart
if (eventsList.isNotEmpty) {
  diveData['events'] = eventsList;
}
```

- [ ] **Step 2.2: Scan for any other reader of `profileEvents`**

```bash
grep -rn "'profileEvents'\|\"profileEvents\"\|\['profileEvents'\]" lib/ test/ --include="*.dart"
```

Expected: zero matches in `lib/` after the rename. If any remain (e.g., another consumer reading from that key), they need the same rename. Report any matches before proceeding.

- [ ] **Step 2.3: Run any existing UDDF import tests**

```bash
flutter test test/features/dive_import/ 2>&1 | tail -10
flutter test test/core/services/export/uddf/ 2>&1 | tail -10
```

Expected: all pass. No existing test should break from this rename because no existing consumer reads `profileEvents` (Slice C's `_importDives` reads `events`). If any test breaks, inspect — it might reveal another consumer that needs updating.

- [ ] **Step 2.4: Analyze and format**

```bash
dart analyze lib/core/services/export/uddf/uddf_full_import_service.dart
dart format --set-exit-if-changed lib/core/services/export/uddf/uddf_full_import_service.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 2.5: Commit**

```bash
git add lib/core/services/export/uddf/uddf_full_import_service.dart
git commit -m "fix(uddf-import): rename diveData['profileEvents'] to 'events' for consumer parity"
```

---

## Task 3: Extend `_importDives` for rich UDDF shape

Adds severity + depth extraction, applies severity override via `copyWith`, passes UDDF depth to factories. TDD-driven with unit tests that feed synthetic maps through the events-persistence block.

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart`
- Modify: `test/features/dive_import/data/services/uddf_entity_importer_test.dart`

- [ ] **Step 3.1: Write failing tests for the rich-shape behavior**

Add to the Profile events persistence group in the importer test file, after existing Slice C.2 tests:

```dart
    test('UDDF severity overrides factory default via copyWith', () async {
      // Build a synthetic parsed-events list with UDDF-shape maps. Severity
      // is provided; factories' defaults should be overridden.
      final diveData = <String, dynamic>{
        'uddfId': 'test-dive-severity',
        'dateTime': DateTime.utc(2026, 3, 15, 10, 0, 0),
        'duration': const Duration(minutes: 10),
        'maxDepth': 20.0,
        'avgDepth': 10.0,
        'profile': <Map<String, dynamic>>[],
        'events': <Map<String, dynamic>>[
          {
            // ascentRateWarning factory default severity: warning
            // UDDF says: alert (the DC treated this as critical)
            'eventType': 'ascentRateWarning',
            'timestamp': 300,
            'value': 25.0,
            'depth': 15.0,
            'severity': 'alert',
          },
          {
            // decoViolation factory default severity: alert
            // UDDF says: warning (the user acknowledged it wasn't critical)
            'eventType': 'decoViolation',
            'timestamp': 600,
            'value': 18.0,
            'depth': 12.0,
            'severity': 'warning',
          },
        ],
      };

      // Invoke importer with the usual mock harness (match Slice C.2 test style).
      // Assert: insertProfileEvents called with 2 events where:
      //   events[0].severity == EventSeverity.alert  (overridden)
      //   events[0].depth == 15.0                    (from UDDF shape)
      //   events[1].severity == EventSeverity.warning (overridden)
      //   events[1].depth == 12.0
      //   both events[x].source == EventSource.imported
    });

    test('SSRF path continues to use factory default severity (no regression)', () async {
      // SSRF-shape event maps don't include `severity`; factory defaults apply.
      final diveData = <String, dynamic>{
        'uddfId': 'test-dive-ssrf-no-severity',
        'dateTime': DateTime.utc(2026, 3, 15, 10, 0, 0),
        'duration': const Duration(minutes: 10),
        'maxDepth': 20.0,
        'avgDepth': 10.0,
        'profile': <Map<String, dynamic>>[],
        'events': <Map<String, dynamic>>[
          {
            // SSRF-shape: no severity, no depth
            'eventType': 'decoViolation',
            'timestamp': 600,
            'value': 18.0,
          },
        ],
      };

      // Assert: events[0].severity == EventSeverity.alert (factory default preserved);
      // events[0].depth is null or unset (factory received no depth).
    });

    test('unknown severity string falls through to factory default', () async {
      // UDDF event with a malformed severity string — _parseSeverity returns null,
      // no override applied, factory default wins.
      final diveData = <String, dynamic>{
        'uddfId': 'test-dive-bad-severity',
        // ... minimal setup ...
        'events': <Map<String, dynamic>>[
          {
            'eventType': 'ppO2High',
            'timestamp': 600,
            'value': 1.65,
            'severity': 'catastrophic',  // not in EventSeverity.values
          },
        ],
      };

      // Assert: events[0].severity == EventSeverity.warning (factory default, not overridden)
    });
```

**Match the existing mock harness exactly.** Inspect the Slice C.2 Profile events persistence tests in the same file for the `importer.import(...)` invocation pattern and `verify(mockDiveRepo.insertProfileEvents(captureAny)).captured.single` pattern. Use identical setUp / mocks.

- [ ] **Step 3.2: Run tests to verify they fail**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart --plain-name "UDDF severity\|SSRF path continues\|unknown severity"
```

Expected: three tests fail — severity is ignored today, depth is hardcoded to 0.0, no override logic exists.

- [ ] **Step 3.3: Add `_parseSeverity` helper**

In `lib/features/dive_import/data/services/uddf_entity_importer.dart`, add a private top-level helper (or a static method on the class — match the file's existing private-helper pattern):

```dart
/// Parse an [EventSeverity] from its string name.
///
/// Returns null for unknown/absent values so callers can fall back to the
/// factory-default severity. Mirrors the pattern used by
/// `profile_event_mapper._parseSeverity` — duplicated here rather than
/// extracted to a shared location to keep Slice C.3's scope bounded.
EventSeverity? _parseSeverity(String? raw) {
  if (raw == null) return null;
  for (final value in EventSeverity.values) {
    if (value.name == raw) return value;
  }
  return null;
}
```

Place alongside other private top-level helpers in the file. If there are none at that level, place it immediately above the `UddfEntityImporter` class declaration.

Required imports (add if not already present):
- `import 'package:submersion/core/constants/enums.dart';` (for `EventSeverity`)

- [ ] **Step 3.4: Extract `severity` and `depth` from event map**

In `_importDives`, find the events-persistence block. Above the `switch (eventTypeStr)`, locate the existing extractions:

```dart
        final timestamp = m['timestamp'] as int?;
        if (timestamp == null) continue;
        final value = m['value'] as double?;
        final description = m['description'] as String?;
```

Add two more lines:

```dart
        final severity = m['severity'] as String?;
        final depth = m['depth'] as double?;
```

- [ ] **Step 3.5: Introduce the `applyOverrides` local closure**

Inside the events-persistence block, just above the `switch`, add:

```dart
        // Apply UDDF-provided overrides. When UDDF supplies a severity,
        // override the factory default via copyWith. SSRF-shape events
        // don't supply severity, so the closure is a pass-through for them.
        ProfileEvent applyOverrides(ProfileEvent event) {
          final severityOverride = _parseSeverity(severity);
          if (severityOverride != null) {
            return event.copyWith(severity: severityOverride);
          }
          return event;
        }
```

- [ ] **Step 3.6: Update each factory call site to use `applyOverrides` + UDDF depth**

The switch currently has 8 cases (setpointChange, bookmark, safetyStopStart, decoStopStart, decoViolation, ascentRateWarning, ppO2High, ppO2Low). Each case currently calls a factory and `events.add(factoryResult)`. Wrap each in `applyOverrides`:

**setpointChange** — currently: no depth passed. Add depth:
```dart
          case 'setpointChange':
            if (value == null) {
              _log.warning('Skipping setpointChange event with missing value');
              continue;
            }
            events.add(applyOverrides(ProfileEvent.setpointChange(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              setpoint: value,
              depth: depth, // NEW: was absent
              createdAt: now,
            )));
            break;
```

**bookmark** — currently passes depth from map explicitly:
```dart
          case 'bookmark':
            events.add(applyOverrides(ProfileEvent.bookmark(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              note: description,
              depth: depth, // may be null for SSRF; UDDF provides when present
              createdAt: now,
              source: EventSource.imported,
            )));
            break;
```

**safetyStopStart** — replace `depth: 0.0` with `depth: depth ?? 0.0`:
```dart
          case 'safetyStopStart':
            events.add(applyOverrides(ProfileEvent.safetyStop(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              depth: depth ?? 0.0, // parser does not emit depth on SSRF event
                                     // elements; UDDF may provide; placeholder
                                     // used across safety/deco/ascent cases.
              createdAt: now,
              isStart: true,
              source: EventSource.imported,
            )));
            break;
```

**decoStopStart** — same pattern:
```dart
          case 'decoStopStart':
            events.add(applyOverrides(ProfileEvent.decoStop(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              depth: depth ?? 0.0,
              createdAt: now,
              isStart: true,
              // factory default is already `imported`; no override needed
            )));
            break;
```

**decoViolation** — factory takes optional depth:
```dart
          case 'decoViolation':
            events.add(applyOverrides(ProfileEvent.decoViolation(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              depth: depth, // optional on factory
              value: value,
              createdAt: now,
              // factory default is already `imported`; no override needed
            )));
            break;
```

**ascentRateWarning** — replace `depth: 0.0` with `depth: depth ?? 0.0`:
```dart
          case 'ascentRateWarning':
            events.add(applyOverrides(ProfileEvent.ascentRateWarning(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              depth: depth ?? 0.0,
              rate: value ?? 0.0,
              createdAt: now,
              source: EventSource.imported, // override `computed` factory default
            )));
            break;
```

**ppO2High** and **ppO2Low** — factory takes optional depth:
```dart
          case 'ppO2High':
            if (value == null) {
              _log.warning('Skipping ppO2High event with missing value');
              continue;
            }
            events.add(applyOverrides(ProfileEvent.ppO2High(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              value: value,
              depth: depth, // optional
              createdAt: now,
            )));
            break;

          case 'ppO2Low':
            if (value == null) {
              _log.warning('Skipping ppO2Low event with missing value');
              continue;
            }
            events.add(applyOverrides(ProfileEvent.ppO2Low(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              value: value,
              depth: depth,
              createdAt: now,
            )));
            break;
```

- [ ] **Step 3.7: Run tests to verify they pass**

```bash
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart --plain-name "UDDF severity\|SSRF path continues\|unknown severity"
```

Expected: all three new tests pass.

- [ ] **Step 3.8: Run full importer test file**

```bash
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: all pass. Slice C.2 tests should continue to pass — the SSRF-path events have `severity = null` (not in map), so `_parseSeverity(null)` returns null and the closure returns the factory result unchanged.

- [ ] **Step 3.9: Analyze and format**

```bash
dart analyze lib/features/dive_import/data/services/uddf_entity_importer.dart test/features/dive_import/data/services/uddf_entity_importer_test.dart
dart format --set-exit-if-changed lib/features/dive_import/data/services/uddf_entity_importer.dart test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 3.10: Commit**

```bash
git add lib/features/dive_import/data/services/uddf_entity_importer.dart \
        test/features/dive_import/data/services/uddf_entity_importer_test.dart
git commit -m "feat(uddf-import): preserve severity and depth from UDDF event shape"
```

---

## Task 4: Round-trip test — UDDF export → parse → import

Adds a single end-to-end test that constructs `ProfileEvent` entities, exports via `UddfExportBuilders.buildDiveElement`, parses back via `UddfFullImportService`, and verifies the importer persists everything correctly.

**Files:**
- Modify: `test/features/dive_import/data/services/uddf_entity_importer_test.dart` (add one new test)

- [ ] **Step 4.1: Write the round-trip test**

Add to the Profile events persistence group:

```dart
    test('UDDF round-trip preserves all 8 event types with severity and depth',
        () async {
      final now = DateTime.utc(2026, 3, 15, 10, 0, 0);
      final diveId = 'roundtrip-dive';

      // 1. Build source events covering all 8 types. Each has a unique timestamp
      //    and carries severity/depth/value/description where applicable.
      final sourceEvents = <ProfileEvent>[
        ProfileEvent.setpointChange(
          id: 'e1', diveId: diveId, timestamp: 0, setpoint: 0.7,
          depth: 0.0, createdAt: now),
        ProfileEvent.bookmark(
          id: 'e2', diveId: diveId, timestamp: 120, depth: 5.0,
          note: 'cool fish', createdAt: now, source: EventSource.imported),
        ProfileEvent.ascentRateWarning(
          id: 'e3', diveId: diveId, timestamp: 300, depth: 10.0,
          rate: 12.5, createdAt: now),
        ProfileEvent.ppO2High(
          id: 'e4', diveId: diveId, timestamp: 600, value: 1.65,
          depth: 20.0, createdAt: now),
        ProfileEvent.ppO2Low(
          id: 'e5', diveId: diveId, timestamp: 700, value: 0.15,
          depth: 25.0, createdAt: now),
        ProfileEvent.decoViolation(
          id: 'e6', diveId: diveId, timestamp: 1500, value: 18.0,
          depth: 15.0, createdAt: now),
        ProfileEvent.decoStop(
          id: 'e7', diveId: diveId, timestamp: 2100, depth: 6.0,
          createdAt: now),
        ProfileEvent.safetyStop(
          id: 'e8', diveId: diveId, timestamp: 2400, depth: 5.0,
          createdAt: now),
      ];

      // 2. Build minimal UDDF XML wrapping a dive that carries these events.
      //    The exact builder API depends on Task 1 Discovery findings — use
      //    whatever signature of UddfExportBuilders.buildDiveElement was
      //    discovered, or the higher-level UddfExportService if buildDiveElement
      //    requires extra infrastructure.
      //
      //    Typical shape:
      //      final builder = XmlBuilder();
      //      builder.processing('xml', 'version="1.0"');
      //      builder.element('uddf', nest: () {
      //        builder.element('profiledata', nest: () {
      //          builder.element('repetitiongroup', nest: () {
      //            UddfExportBuilders.buildDiveElement(
      //              builder,
      //              dive: ..., // minimal Dive entity
      //              profileEvents: sourceEvents,
      //              // other required params: populate per Task 1 findings
      //            );
      //          });
      //        });
      //      });
      //      final uddfXml = builder.buildDocument().toXmlString();

      // 3. Parse via UddfFullImportService.
      //    final importResult = await uddfImportService.parse(utf8.encode(uddfXml));
      //    final parsedDiveData = importResult.entitiesOf(ImportEntityType.dives).first;
      //    final parsedEvents = parsedDiveData['events'] as List<Map<String, dynamic>>;

      // 4. Feed through the full importer using the same mock harness as
      //    other Profile events persistence tests. Verify:
      //    - insertProfileEvents called once
      //    - captured list has length 8
      //    - event order matches source order
      //    - for each event: eventType matches, timestamp matches, severity
      //      matches (UDDF round-trips the severity explicitly), depth matches
      //      (within floating-point tolerance for asymmetric representations),
      //      value and description match where applicable
      //    - all events have source == EventSource.imported
    });
```

**Key implementation notes** (work out against Discovery findings):
- The precise builder API and minimum `Dive` construction may require test-harness helpers. If sibling tests construct a `Dive` via a test utility, reuse it. If not, build minimally and fill only the required fields.
- If `UddfExportBuilders.buildDiveElement` requires additional entities (tanks, gasmixes, etc.) as required parameters, pass empty lists where possible; the event-path exercise doesn't need a fully-populated dive.
- Match the floating-point comparison style used by other tests in the file — prefer `expect(a.depth, b.depth)` for exact representation if UDDF preserves the exact value; use `closeTo(expected, 0.001)` if floating-point drift is a concern.

- [ ] **Step 4.2: Run the test to verify it passes**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart --plain-name "UDDF round-trip preserves all 8 event types"
```

Expected: PASS. Task 2's key rename and Task 3's rich-shape handling together make this test pass without any further implementation code — the exporter was already writing all the fields, and the importer now reads them.

If this test fails, the most likely causes are:
1. UDDF exporter drops a field the parser reads (Task 1 Discovery should have caught this).
2. Builder API signature doesn't match Task 1 findings.
3. Severity name mismatch (e.g., `EventSeverity.alert` vs `'alert'` serialization — verify `.name` matches both sides).

- [ ] **Step 4.3: Full importer test file**

```bash
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: all pass.

- [ ] **Step 4.4: Analyze and format**

```bash
dart analyze test/features/dive_import/data/services/uddf_entity_importer_test.dart
dart format --set-exit-if-changed test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 4.5: Commit**

```bash
git add test/features/dive_import/data/services/uddf_entity_importer_test.dart
git commit -m "test(uddf-import): round-trip test pins Submersion UDDF export/import event fidelity"
```

---

## Task 5: Tracker doc update

**Files:**
- Modify: `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md`

- [ ] **Step 5.1: Update combined table `Profile events / markers` row**

Find the row (last updated by Slice C.2 Task 5). Currently reads something like:

```markdown
| Profile events / markers | [ ] | Medium | Yes | Partial | Partial |
```

Change UDDF Support column to `Yes`; keep SSRF Support and Fixed as-is (SSRF stayed `Partial` after C.2 because real-world validation wasn't done; UDDF is now `Yes` because Submersion round-trip is fully covered by C.3):

```markdown
| Profile events / markers | [ ] | Medium | Yes | Yes | Partial |
```

- [ ] **Step 5.2: Update UDDF sub-table `Profile events / markers` row**

Find the row in the UDDF sub-table. Update Fixed to `[x]` and the Why cell:

```markdown
| Profile events / markers | [x] | Medium | Submersion-authored UDDF round-trip preserves all 8 event types via the `<profileevents>` element. `diveData['events']` key unified with SSRF path (Slice C.3). Third-party UDDF parsers that don't emit `<profileevents>` remain out of scope |
```

- [ ] **Step 5.3: Add Slice C.3 bullet to Notes section**

At the end of the Notes bullet list, before any footnote definitions:

```markdown
- Slice C.3 (2026-04-17) fixes the UDDF-vs-SSRF event-key mismatch — the UDDF parser now writes `diveData['events']` instead of `diveData['profileEvents']`. Extends `_importDives` to consume UDDF's richer event shape (severity, depth) via post-construction `copyWith` overrides, while keeping the SSRF path unchanged. Round-trip test confirms Submersion-authored UDDF exports preserve all 8 event types end-to-end. Third-party UDDF event parsing remains a separate future slice. See `docs/superpowers/specs/2026-04-17-ssrf-slice-c3-uddf-event-parity-design.md`.
```

- [ ] **Step 5.4: Visual sanity check**

Column counts should remain 6 (combined) and 4 (sub-tables). `[^1]` footnote still appears twice.

- [ ] **Step 5.5: Commit**

```bash
git add docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md
git commit -m "docs(tracker): record Slice C.3 UDDF event parity"
```

---

## Task 6: Final verification

- [ ] **Step 6.1: Scoped tests**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart 2>&1 | tail -3
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart 2>&1 | tail -3
flutter test test/features/dive_log/domain/entities/profile_event_test.dart 2>&1 | tail -3
```

All pass.

- [ ] **Step 6.2: Broader tree**

```bash
flutter test test/features/dive_import/ 2>&1 | tail -5
flutter test test/features/dive_log/ 2>&1 | tail -5
flutter test test/features/universal_import/ 2>&1 | tail -5
flutter test test/core/services/export/ 2>&1 | tail -5
```

All pass. No regressions.

- [ ] **Step 6.3: Full analyzer**

```bash
dart analyze lib/ test/ 2>&1 | tail -5
```

Expected: zero issues.

- [ ] **Step 6.4: Format**

```bash
dart format --set-exit-if-changed \
  lib/core/services/export/uddf/uddf_full_import_service.dart \
  lib/features/dive_import/data/services/uddf_entity_importer.dart \
  test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: exit 0.

- [ ] **Step 6.5: Git state**

```bash
git status --short
git log --oneline origin/main..HEAD
```

Working tree has only the untracked spec/plan docs in `docs/superpowers/`. Commit log shows Slice C.3 commits layered on top of Slice C + C.2.

- [ ] **Step 6.6: Spot-check files**

Read and confirm:
- `lib/core/services/export/uddf/uddf_full_import_service.dart:872` writes to `'events'`, not `'profileEvents'`.
- `lib/features/dive_import/data/services/uddf_entity_importer.dart` has `_parseSeverity` helper and `applyOverrides` closure; all 8 switch cases wrap their factory calls with `applyOverrides(...)` and pass `depth ?? 0.0` (required-depth factories) or `depth` (optional) from the extracted `depth` variable.
- `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md` combined row UDDF Support is now `Yes`; UDDF sub-table row has `[x]` Fixed; Notes section has Slice C.3 bullet.

---

## Summary of Commits

Expected commit sequence:

1. `docs(slice-c.3): discovery findings for UDDF event parity`
2. `fix(uddf-import): rename diveData['profileEvents'] to 'events' for consumer parity`
3. `feat(uddf-import): preserve severity and depth from UDDF event shape`
4. `test(uddf-import): round-trip test pins Submersion UDDF export/import event fidelity`
5. `docs(tracker): record Slice C.3 UDDF event parity`

Plus fix-up commits from review loops.

## Out of Scope Reminders

- Third-party UDDF event parsing (Diviac, Shearwater Cloud) — separate slice.
- UI rendering of events — presentation-layer follow-up.
- `tankRef` consumption for non-gas-switch events — no current use case.
- Severity as a factory parameter — deliberately deferred in favor of the `copyWith` pattern.
