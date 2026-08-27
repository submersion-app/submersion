# SSRF Slice C.2 — Profile Events Level 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend Slice C's SSRF event pipeline to persist 6 additional event types (`bookmark`, `safety stop`, `deco stop`, `ceiling`, `violation`, `ascent`, `po2`) on top of the existing `setpointChange` support, with three new `ProfileEvent` factory constructors and a compound synthetic fixture.

**Architecture:** Flat one-to-one `name=` → `ProfileEventType` mapping inside `_parseProfileEvents`. New factory constructors (`decoStop`, `decoViolation`, `ppO2High`) for call-site ergonomics in the `_importDives` switch. No schema migration; no new `ProfileEventType` enum values. All imported events land with `source: EventSource.imported`.

**Tech Stack:** Dart 3 + Flutter 3 + `package:xml` + `flutter_test` + Drift (unchanged from Slice C).

**Spec reference:** `docs/superpowers/specs/2026-04-17-ssrf-slice-c2-profile-events-level2-design.md`

**Branch:** `feat/ssrf-slice-c2` (already created off `feat/ssrf-slice-c` which is in PR #243).

---

## Pre-implementation Findings (verified before writing plan)

- **All three factories already accept `source` parameter** (per Slice C Task 3):
  - `bookmark` — `source: EventSource.user` default
  - `safetyStop` — `source: EventSource.computed` default
  - `ascentRateWarning` — `source: EventSource.computed` default
  - No signature augmentation needed.
- **SSRF fixtures currently contain only `gaschange` events.** This slice adds one synthetic fixture exercising all 7 event types (existing `setpointChange` + 6 new) for end-to-end smoke coverage.
- **Parser's `_parseProfileEvents` has one `if (name == 'sp change')` block today** (Slice C). Extension adds 6 parallel `else if` blocks.
- **Importer's `_importDives` switch has one `case 'setpointChange':` + `default:` today** (Slice C). Extension adds 6 new cases before `default:`.

**Commit preference:** User authorized per-task commits for Slice C.2 (per Slice A/C precedent).

**Pre-push hook note:** `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` run on push. If `dart format` complains, run `dart format` without the flag and re-commit.

---

## Task 1: Three new factory constructors on `ProfileEvent`

Adds `decoStop`, `decoViolation`, `ppO2High` factories. TDD-driven.

**Files:**
- Modify: `lib/features/dive_log/domain/entities/profile_event.dart`
- Modify: `test/features/dive_log/domain/entities/profile_event_test.dart`

- [ ] **Step 1.1: Write failing factory tests**

Append to `test/features/dive_log/domain/entities/profile_event_test.dart` inside `main()`, after existing group(s):

```dart
  group('ProfileEvent new factories (Slice C.2)', () {
    final now = DateTime.utc(2026, 1, 1);

    test('decoStop defaults to decoStopStart with source=imported', () {
      final e = ProfileEvent.decoStop(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        depth: 6.0,
        createdAt: now,
      );
      expect(e.eventType, ProfileEventType.decoStopStart);
      expect(e.source, EventSource.imported);
      expect(e.depth, 6.0);
    });

    test('decoStop isStart=false produces decoStopEnd', () {
      final e = ProfileEvent.decoStop(
        id: 'e1',
        diveId: 'd1',
        timestamp: 500,
        depth: 3.0,
        createdAt: now,
        isStart: false,
      );
      expect(e.eventType, ProfileEventType.decoStopEnd);
    });

    test('decoViolation defaults to alert severity + source=imported', () {
      final e = ProfileEvent.decoViolation(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        value: 18.0,
        createdAt: now,
      );
      expect(e.eventType, ProfileEventType.decoViolation);
      expect(e.severity, EventSeverity.alert);
      expect(e.source, EventSource.imported);
      expect(e.value, 18.0);
    });

    test('ppO2High defaults to warning severity + source=imported', () {
      final e = ProfileEvent.ppO2High(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        value: 1.65,
        createdAt: now,
      );
      expect(e.eventType, ProfileEventType.ppO2High);
      expect(e.severity, EventSeverity.warning);
      expect(e.source, EventSource.imported);
      expect(e.value, 1.65);
    });

    test('explicit source overrides factory default on new factories', () {
      final dv = ProfileEvent.decoViolation(
        id: 'e1',
        diveId: 'd1',
        timestamp: 100,
        createdAt: now,
        source: EventSource.computed,
      );
      expect(dv.source, EventSource.computed);
    });
  });
```

- [ ] **Step 1.2: Run tests to verify they fail**

```
flutter test test/features/dive_log/domain/entities/profile_event_test.dart --plain-name "ProfileEvent new factories"
```

Expected: FAIL — `decoStop`, `decoViolation`, `ppO2High` don't exist.

- [ ] **Step 1.3: Add the three factories**

In `lib/features/dive_log/domain/entities/profile_event.dart`, add these three factories alongside existing ones. Suggested placement: after `setpointChange` (current last factory, around line 243-260). Exact code:

```dart
  /// Create a deco stop event (CCR/technical dives).
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

  /// Create a deco violation event (ceiling exceeded, generic violation).
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

  /// Create a high ppO2 warning event.
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

- [ ] **Step 1.4: Run tests to verify they pass**

```
flutter test test/features/dive_log/domain/entities/profile_event_test.dart
```

Expected: all tests pass (existing + 5 new).

- [ ] **Step 1.5: Analyze and format**

```
dart analyze lib/features/dive_log/domain/entities/profile_event.dart test/features/dive_log/domain/entities/profile_event_test.dart
dart format --set-exit-if-changed lib/features/dive_log/domain/entities/profile_event.dart test/features/dive_log/domain/entities/profile_event_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 1.6: Commit**

```bash
git add lib/features/dive_log/domain/entities/profile_event.dart \
        test/features/dive_log/domain/entities/profile_event_test.dart
git commit -m "feat(profile-event): add decoStop, decoViolation, ppO2High factories"
```

**Do NOT include** untracked `docs/superpowers/` 2026-04-17 files.

---

## Task 2: Extend `_parseProfileEvents` with 6 new event types

TDD — add 6 new tests in the existing `profile events - setpointChange` group (renamed to `profile events`), then extend the parser.

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 2.1: Rename existing test group**

In `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`, find:
```dart
group('profile events - setpointChange', () {
```

Rename to:
```dart
group('profile events', () {
```

This is pure renaming — no test content changes.

- [ ] **Step 2.2: Write failing tests for 6 new event types**

Append inside the renamed `group('profile events', () { ... })` block, after existing setpointChange tests:

```dart
  test('emits bookmark event', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test'>
  <depth max='10.0 m' mean='5.0 m' />
  <event time='2:00 min' name='bookmark' description='cool fish' />
  <sample time='2:30 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 1);
    expect(events[0]['eventType'], 'bookmark');
    expect(events[0]['timestamp'], 120);
    expect(events[0]['description'], 'cool fish');
  });

  test('emits safetyStopStart event from safety stop', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='45:00 min'>
  <divecomputer model='Test'>
  <depth max='30.0 m' mean='15.0 m' />
  <event time='40:00 min' name='safety stop' />
  <sample time='40:30 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 1);
    expect(events[0]['eventType'], 'safetyStopStart');
    expect(events[0]['timestamp'], 2400);
  });

  test('emits decoStopStart event from deco stop', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='45:00 min'>
  <divecomputer model='Test'>
  <depth max='60.0 m' mean='30.0 m' />
  <event time='35:00 min' name='deco stop' />
  <sample time='35:30 min' depth='9.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 1);
    expect(events[0]['eventType'], 'decoStopStart');
    expect(events[0]['timestamp'], 2100);
  });

  test('emits decoViolation from ceiling event with value', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='40.0 m' mean='20.0 m' />
  <event time='25:00 min' name='ceiling' value='18.0' />
  <sample time='25:30 min' depth='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 1);
    expect(events[0]['eventType'], 'decoViolation');
    expect(events[0]['timestamp'], 1500);
    expect(events[0]['value'], 18.0);
  });

  test('emits decoViolation from generic violation event', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='40.0 m' mean='20.0 m' />
  <event time='30:00 min' name='violation' />
  <sample time='30:30 min' depth='10.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 1);
    expect(events[0]['eventType'], 'decoViolation');
    expect(events[0]['timestamp'], 1800);
    expect(events[0].containsKey('value'), isFalse,
        reason: 'no value attribute → no value field');
  });

  test('emits ascentRateWarning from ascent event with rate value', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test'>
  <depth max='30.0 m' mean='15.0 m' />
  <event time='5:00 min' name='ascent' value='12.5' />
  <sample time='5:30 min' depth='20.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 1);
    expect(events[0]['eventType'], 'ascentRateWarning');
    expect(events[0]['timestamp'], 300);
    expect(events[0]['value'], 12.5);
  });

  test('emits ppO2High from po2 event with value', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='10:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='50.0 m' mean='30.0 m' />
  <event time='10:00 min' name='po2' value='1.65' />
  <sample time='10:30 min' depth='45.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final events = dive['events'] as List<Map<String, dynamic>>;
    expect(events.length, 1);
    expect(events[0]['eventType'], 'ppO2High');
    expect(events[0]['timestamp'], 600);
    expect(events[0]['value'], 1.65);
  });

  test('drops po2 event with non-positive value', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='10:00 min'>
  <divecomputer model='Test'>
  <depth max='10.0 m' mean='5.0 m' />
  <event time='5:00 min' name='po2' value='0' />
  <sample time='5:30 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    expect(dive.containsKey('events'), isFalse,
        reason: 'po2=0 is implausible → dropped; no other events → no events key');
  });
```

- [ ] **Step 2.3: Run tests to verify they fail**

```
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "profile events"
```

Expected: 8 new tests fail (parser doesn't emit these yet).

- [ ] **Step 2.4: Extend `_parseProfileEvents`**

In `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`, find `_parseProfileEvents`. Replace the current body with the extended version below. The structure uses `else if` chains to make the mutually-exclusive name matching explicit:

```dart
  static List<Map<String, dynamic>> _parseProfileEvents(
    XmlElement divecomputer,
  ) {
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
      } else if (name == 'bookmark') {
        final timestamp = _parseDurationSeconds(event.getAttribute('time'));
        if (timestamp == null) continue;
        final description = event.getAttribute('description');
        events.add({
          'eventType': 'bookmark',
          'timestamp': timestamp,
          if (description != null) 'description': description,
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
        if (value == null || value <= 0) continue;
        events.add({
          'eventType': 'ppO2High',
          'timestamp': timestamp,
          'value': value,
        });
      }
      // Unrecognized names (e.g., `gaschange` which has a separate pipeline,
      // DC metadata like `low battery`, `heading`) fall through silently.
      // The `_importDives` switch's `default:` case logs truly unknown event
      // types at that layer.
    }
    return events;
  }
```

Also update the method's doc comment to reflect the expanded scope (remove "Currently emits only `SP change` events" language):

```dart
  /// Parses `<event>` children of a `<divecomputer>` into typed profile-event
  /// maps.
  ///
  /// Currently emits: `setpointChange` (from `SP change`), `bookmark`,
  /// `safetyStopStart` (from `safety stop`), `decoStopStart` (from `deco stop`),
  /// `decoViolation` (from `ceiling` or `violation`), `ascentRateWarning`
  /// (from `ascent`), and `ppO2High` (from `po2`).
  ///
  /// Gas-change events remain handled by `_parseGasSwitches` (persisted via
  /// the distinct `GasSwitches` table). Future slices may extend this method
  /// to cover additional types.
  ///
  /// Setpoint value normalization: Subsurface typically emits `value` in mbar
  /// (e.g., 1200 for 1.2 bar) but some third-party exporters use bar (1.2).
  /// The `> 10` threshold is exclusive: realistic setpoints are 0.2-1.6 bar
  /// (200-1600 mbar), so 10 is unreachable in either unit.
  ///
  /// Implausible values (non-positive) and unparseable timestamps are dropped.
```

- [ ] **Step 2.5: Run tests to verify they pass**

```
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "profile events"
```

Expected: all pass (pre-existing setpointChange tests + 8 new).

- [ ] **Step 2.6: Run full parser test file for regressions**

```
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
```

Expected: all pass.

- [ ] **Step 2.7: Analyze and format**

```
dart analyze lib/ test/
dart format --set-exit-if-changed lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 2.8: Commit**

```bash
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart \
        test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat(ssrf-import): parse bookmark, stops, violations, ascent, po2 events"
```

---

## Task 3: Create synthetic compound fixture

Covers all 7 event types in a single realistic dive. Used by Task 4's integration test.

**Files:**
- Create: `test/features/universal_import/data/parsers/fixtures/profile-events-variety.ssrf`

- [ ] **Step 3.1: Create the fixture**

Create `test/features/universal_import/data/parsers/fixtures/profile-events-variety.ssrf` with the exact content:

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

- [ ] **Step 3.2: Commit**

```bash
git add test/features/universal_import/data/parsers/fixtures/profile-events-variety.ssrf
git commit -m "test(ssrf-import): add profile-events-variety.ssrf fixture"
```

---

## Task 4: Extend `_importDives` switch + integration tests

Wires parser output to `insertProfileEvents` via the right factory for each event type. Bookmark source override is the critical bit.

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart`
- Modify: `test/features/dive_import/data/services/uddf_entity_importer_test.dart`

- [ ] **Step 4.1: Write the failing integration tests**

Append to `uddf_entity_importer_test.dart` in an appropriate location (near the existing Slice C events tests):

```dart
  test('persists 7 event types from profile-events-variety fixture', () async {
    // Build diveData with all 7 event types as parsed from the fixture
    final diveData = <String, dynamic>{
      'uddfId': 'test-dive-c2',
      'dateTime': DateTime.utc(2026, 3, 15, 10, 0, 0),
      'duration': const Duration(minutes: 45),
      'maxDepth': 30.0,
      'avgDepth': 15.0,
      'profile': <Map<String, dynamic>>[
        {'timestamp': 30, 'depth': 5.0},
        {'timestamp': 300, 'depth': 25.0},
      ],
      'events': <Map<String, dynamic>>[
        {'eventType': 'setpointChange', 'timestamp': 0, 'value': 0.7},
        {'eventType': 'bookmark', 'timestamp': 120, 'description': 'cool fish'},
        {'eventType': 'ascentRateWarning', 'timestamp': 300, 'value': 12.5},
        {'eventType': 'ppO2High', 'timestamp': 600, 'value': 1.65},
        {'eventType': 'decoViolation', 'timestamp': 1500, 'value': 18.0},
        {'eventType': 'decoViolation', 'timestamp': 1800},
        {'eventType': 'decoStopStart', 'timestamp': 2100},
        {'eventType': 'safetyStopStart', 'timestamp': 2400},
      ],
    };

    // Run _importDives (or whatever public method the existing Slice C
    // event-persistence test uses; inspect the test file and match its pattern).
    // The test should verify that insertProfileEvents was called once with
    // a list containing 8 ProfileEvents of the correct types and source=imported.

    // Expected assertions (adapt to the mock/test harness used by sibling tests):
    // - `verify(mockDiveRepository.insertProfileEvents(captureAny)).captured.single`
    //   returns a List<ProfileEvent> of length 8
    // - event types in order: setpointChange, bookmark, ascentRateWarning,
    //   ppO2High, decoViolation, decoViolation, decoStopStart, safetyStopStart
    // - every event has source == EventSource.imported
    // - the bookmark event's description == 'cool fish'
  });

  test('bookmark event from import uses source=imported, not user', () async {
    // Build minimal diveData with a single bookmark event.
    final diveData = <String, dynamic>{
      'uddfId': 'test-dive-bookmark',
      'dateTime': DateTime.utc(2026, 3, 15, 10, 0, 0),
      'duration': const Duration(minutes: 10),
      'maxDepth': 10.0,
      'avgDepth': 5.0,
      'profile': <Map<String, dynamic>>[],
      'events': <Map<String, dynamic>>[
        {'eventType': 'bookmark', 'timestamp': 120, 'description': 'cool fish'},
      ],
    };

    // Run import. Assert:
    // - insertProfileEvents called once with list of length 1
    // - events[0].eventType == ProfileEventType.bookmark
    // - events[0].source == EventSource.imported  // NOT EventSource.user
    // - events[0].description == 'cool fish'
  });
```

**Note on test harness pattern**: Inspect the existing Slice C events-persistence test in the same file to understand the mock setup, import invocation, and `captureAny`/`captured.single` conventions. Match that pattern. The tests above are pseudocode for the assertions; concrete test code must follow the sibling-test style exactly.

- [ ] **Step 4.2: Run tests to verify they fail**

```
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart --plain-name "profile-events-variety\|bookmark event from import"
```

Expected: fail — `default:` case in switch logs and skips the new event types (nothing gets inserted).

- [ ] **Step 4.3: Extend the `_importDives` switch**

In `lib/features/dive_import/data/services/uddf_entity_importer.dart`, find the events-persistence block inside `_importDives`. Locate the `switch (eventTypeStr)` statement. Between `case 'setpointChange':` and `default:`, add six new cases:

```dart
        switch (eventTypeStr) {
          case 'setpointChange':
            // ... existing setpointChange case (unchanged) ...
            break;

          case 'bookmark':
            final description = m['description'] as String?;
            events.add(ProfileEvent.bookmark(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              note: description,
              createdAt: now,
              source: EventSource.imported, // override the `user` factory default
            ));
            break;

          case 'safetyStopStart':
            events.add(ProfileEvent.safetyStop(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              depth: 0.0, // depth not in event map; could be inferred from samples later
              createdAt: now,
              isStart: true,
              source: EventSource.imported,
            ));
            break;

          case 'decoStopStart':
            events.add(ProfileEvent.decoStop(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              depth: 0.0,
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
              depth: 0.0,
              rate: (m['value'] as double?) ?? 0.0,
              createdAt: now,
              source: EventSource.imported, // override `computed` factory default
            ));
            break;

          case 'ppO2High':
            if (value == null) {
              // Ignore malformed events missing required value
              break;
            }
            events.add(ProfileEvent.ppO2High(
              id: _uuid.v4(),
              diveId: diveId,
              timestamp: timestamp,
              value: value,
              createdAt: now,
            ));
            break;

          default:
            _log.warning('Skipping unknown profile event type from parser: $eventTypeStr');
            break;
        }
```

**Variable name note**: if `value` is not already extracted as a local in the enclosing loop, extract it once before the switch:

```dart
      final timestamp = m['timestamp'] as int?;
      if (timestamp == null) continue;
      final value = m['value'] as double?;
      // then switch on eventTypeStr...
```

Match the style of surrounding code. The existing Slice C block already extracts `timestamp` defensively; add `value` extraction in the same place if not present.

- [ ] **Step 4.4: Run tests to verify they pass**

```
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart --plain-name "profile-events-variety\|bookmark event from import"
```

Expected: both new tests pass.

- [ ] **Step 4.5: Run full importer test file**

```
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: all pass, no regressions from Slice C's tests.

- [ ] **Step 4.6: Analyze and format**

```
dart analyze lib/features/dive_import/data/services/uddf_entity_importer.dart test/features/dive_import/data/services/uddf_entity_importer_test.dart
dart format --set-exit-if-changed lib/features/dive_import/data/services/uddf_entity_importer.dart test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 4.7: Commit**

```bash
git add lib/features/dive_import/data/services/uddf_entity_importer.dart \
        test/features/dive_import/data/services/uddf_entity_importer_test.dart
git commit -m "feat(ssrf-import): persist 6 new event types with source=imported"
```

---

## Task 5: Tracker doc update

**Files:**
- Modify: `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md`

- [ ] **Step 5.1: Update SSRF sub-table `Profile events / markers` row**

Find the row (around line 109) that currently reads:
```
| Profile events / markers | [ ] | Medium | `setpointChange` events are persisted via `DiveProfileEvents` (Slice C). Bookmarks, alarms, ceiling violations, and other SSRF event types remain unmapped. A future slice should extend `_parseProfileEvents` to cover these |
```

Replace with:
```
| Profile events / markers | [ ] | Medium | `setpointChange`, `bookmark`, `safetyStopStart`, `decoStopStart`, `decoViolation` (from `ceiling` / `violation`), `ascentRateWarning` (from `ascent`), and `ppO2High` (from `po2`) are now persisted via `DiveProfileEvents` (Slice C + C.2). DC-internal alarms (`low battery`, `heading`, `rbt`) remain intentionally unmapped. UDDF parity is Slice C.3. |
```

Leave the `[ ]` Fixed column as-is (still open because UDDF parity isn't done and mapping is synthetic-fixture-verified, not real-data-verified).

- [ ] **Step 5.2: Add a Slice C.2 bullet to the Notes section**

Find the `## Notes` section. Add a bullet at the end of the list, just before the `[^1]` footnote:

```
- Slice C.2 (2026-04-17) extends SSRF `_parseProfileEvents` with 6 additional event types (`bookmark`, `safety stop`, `deco stop`, `ceiling`, `violation`, `ascent`, `po2`), flat one-to-one mapping to existing `ProfileEventType` values. Three new factory constructors on `ProfileEvent` (`decoStop`, `decoViolation`, `ppO2High`). One synthetic fixture `profile-events-variety.ssrf`. No schema change. Mapping is based on Subsurface's documented event vocabulary — not verified against real-world exports; future enrichment slices may correct mapping as real data surfaces. See `docs/superpowers/specs/2026-04-17-ssrf-slice-c2-profile-events-level2-design.md`.
```

- [ ] **Step 5.3: Commit**

```bash
git add docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md
git commit -m "docs(tracker): record Slice C.2 expanded SSRF event coverage"
```

---

## Task 6: Final verification

- [ ] **Step 6.1: Run scoped tests**

```
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter test test/features/dive_log/domain/entities/profile_event_test.dart
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Report per-file pass count. All must pass.

- [ ] **Step 6.2: Broader tree smoke tests**

```
flutter test test/features/dive_log/ 2>&1 | tail -5
flutter test test/features/dive_import/ 2>&1 | tail -5
flutter test test/features/universal_import/ 2>&1 | tail -5
```

All pass.

- [ ] **Step 6.3: Full analyzer**

```
dart analyze lib/ test/ 2>&1 | tail -5
```

Expected: zero issues.

- [ ] **Step 6.4: Format check on touched files**

```
dart format --set-exit-if-changed \
  lib/features/dive_log/domain/entities/profile_event.dart \
  lib/features/universal_import/data/parsers/subsurface_xml_parser.dart \
  lib/features/dive_import/data/services/uddf_entity_importer.dart
```

Expected: exit 0.

- [ ] **Step 6.5: Working tree and log**

```
git status --short
git log --oneline origin/main..HEAD
```

Expected: working tree has only the 4+ untracked `docs/superpowers/` 2026-04-17 files (including the new Slice C.2 spec and this plan). Commit log shows the Slice C.2 commits plus the Slice C commits they're built on.

- [ ] **Step 6.6: Spot-check file state**

Read and confirm:
- `lib/features/dive_log/domain/entities/profile_event.dart` has 10 factories: ascentStart, safetyStop, maxDepth, ascentRateWarning, gasSwitch, bookmark, setpointChange, decoStop, decoViolation, ppO2High.
- `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart:_parseProfileEvents` has 7 `if/else if` branches.
- `lib/features/dive_import/data/services/uddf_entity_importer.dart:_importDives` switch has 7 cases + default.

---

## Summary of Commits

Expected Slice C.2 commit sequence:

1. `feat(profile-event): add decoStop, decoViolation, ppO2High factories`
2. `feat(ssrf-import): parse bookmark, stops, violations, ascent, po2 events`
3. `test(ssrf-import): add profile-events-variety.ssrf fixture`
4. `feat(ssrf-import): persist 6 new event types with source=imported`
5. `docs(tracker): record Slice C.2 expanded SSRF event coverage`

Plus any fix-ups from review loops.

## Out of Scope Reminders

- UDDF parity — Slice C.3.
- Numeric-driven variant branching (ascentRateCritical vs. Warning) — future enrichment slice.
- Chart overlay rendering of events — presentation-layer follow-up.
- Real-world SSRF fixture validation — opportunistic; update mapping when real files with these event types surface.
