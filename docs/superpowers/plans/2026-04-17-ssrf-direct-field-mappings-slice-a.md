# SSRF Direct Field Mappings (Slice A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close three concrete SSRF-import gaps in the Subsurface XML parser — sample `setpoint` parsing (direct attribute + `SP change` events with forward-fill), partial cylinder preservation (stop dropping gas-only cylinders), and correction of the import-gap tracker's UDDF rows.

**Architecture:** Pure parser-layer work in `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`. One new private generic helper `_applyEventFillOntoSamples<T>` that forward-fills a field onto samples from timestamped events. Tests use inline XML strings (the established pattern in the test file) rather than new fixture files. **No schema migration. No UDDF code changes. No `database.dart` changes.**

**Tech Stack:** Dart 3 + Flutter 3 + `package:xml` for XML parsing + `flutter_test` for assertions.

**Spec reference:** `docs/superpowers/specs/2026-04-17-ssrf-direct-field-mappings-slice-a-design.md`

---

## Pre-implementation Notes

**Plan-phase verification result (done):** No existing `.ssrf` fixture in the repo exposes `<extradata key='Setpoint'>`. The only fixture file, `test/features/universal_import/data/parsers/fixtures/dual-cylinder.ssrf`, has extradata keys `Logversion`, `Serial`, `FW Version`, `Deco model`, `Battery type`, `Battery at end` — no `Setpoint`. Per the spec's escape clause, **strategy (iv) fixed-CCR fallback is deferred to Slice B** and not implemented in this plan. If the user later provides a real-world SSRF file that exposes a fixed-CCR setpoint via extradata (or any other mechanism), it becomes a Slice B requirement and the gap tracker should flag it then.

**Output shape recap (relevant to tests):**
- `parser.parse(xmlBytes)` -> `ImportPayload`.
- `payload.entitiesOf(ImportEntityType.dives)` -> `List<Map<String, dynamic>>`.
- Each dive map has `'profile'` (list of sample maps) and `'tanks'` (list of tank maps).
- Each sample map has `'timestamp'` (int seconds) and `'depth'` (double meters). Our new fields go alongside those.

**Inline XML test skeleton (use verbatim):**

```dart
final result = await parser.parse(
  xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='30.0 m' mean='15.0 m' />
  <!-- events and samples here -->
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
);
```

**Git hook reminder:** This repo configures pre-push hooks that run `dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test`. Every commit step below should succeed with those hooks enabled. If `dart format` complains, the fix is `dart format lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` before re-committing.

**Commit preference:** The user prefers to control commit timing manually. Each task below includes a concrete `git commit` command so the intent is explicit, but the executor should confirm with the user before running commits if there's any doubt. Commits are written as separate steps so any given task can be split or batched at the user's discretion.

---

## Task 1: Add shared event-forward-fill helper with coverage via setpoint events

Introduces the shared `_applyEventFillOntoSamples<T>` helper and its first consumer: `SP change` event parsing for sample `setpoint`. TDD — the failing test drives both the helper and its call site into existence.

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` (add helper, add setpoint-event parser, call in `_parseProfile`)
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` (add new test group)

- [ ] **Step 1.1: Write the failing test for setpoint forward-fill from SP-change events**

Add the following group to `subsurface_xml_parser_test.dart` after the existing groups but before the closing `}` of `main()`. Place it near the end of the file to avoid disturbing existing groups.

```dart
group('sample setpoint', () {
  test('forward-fills setpoint from SP change events', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='30.0 m' mean='15.0 m' />
  <event time='0:00 min' name='SP change' value='700' />
  <event time='25:00 min' name='SP change' value='1300' />
  <sample time='0:10 min' depth='5.0 m' />
  <sample time='10:00 min' depth='20.0 m' />
  <sample time='24:59 min' depth='20.0 m' />
  <sample time='25:00 min' depth='20.0 m' />
  <sample time='26:00 min' depth='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final profile = dive['profile'] as List<Map<String, dynamic>>;
    expect(profile[0]['setpoint'], 0.7, reason: 'sample at 0:10 after t=0 event');
    expect(profile[1]['setpoint'], 0.7, reason: 'sample at 10:00 after t=0 event');
    expect(profile[2]['setpoint'], 0.7, reason: 'sample at 24:59 still below 25:00 event');
    expect(profile[3]['setpoint'], 1.3, reason: 'sample at 25:00 at/after 25:00 event');
    expect(profile[4]['setpoint'], 1.3, reason: 'sample at 26:00 after 25:00 event');
  });
});
```

- [ ] **Step 1.2: Run the test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "forward-fills setpoint from SP change events"`

Expected: FAIL. All five `expect(... , 0.7)` / `expect(... , 1.3)` assertions fail because `setpoint` is absent from every sample.

- [ ] **Step 1.3: Implement the helper and the setpoint event parser**

First, add the helper as a `static` private method inside `SubsurfaceXmlParser` (place it immediately after the existing `_fillSparseField` definition near `subsurface_xml_parser.dart:512`). Exact code:

```dart
  /// Forward-fills a field on each sample from timestamped events.
  ///
  /// For each sample, finds the last event with timestamp <= sample.timestamp
  /// and sets sample[sampleField] = event.value. If the sample already has a
  /// non-null value at sampleField, it is preserved so direct sample
  /// attributes take precedence over event-derived values.
  static void _applyEventFillOntoSamples<T>({
    required List<Map<String, dynamic>> samples,
    required List<({int timestamp, T value})> events,
    required String sampleField,
  }) {
    if (events.isEmpty || samples.isEmpty) return;
    final sortedEvents = [...events]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    var eventIdx = 0;
    T? current;
    for (final sample in samples) {
      final sampleTime = sample['timestamp'] as int;
      while (eventIdx < sortedEvents.length &&
          sortedEvents[eventIdx].timestamp <= sampleTime) {
        current = sortedEvents[eventIdx].value;
        eventIdx++;
      }
      if (current != null && sample[sampleField] == null) {
        sample[sampleField] = current;
      }
    }
  }
```

Second, add a new private method `_parseSetpointEvents` anywhere in the file (suggest placing it immediately after `_parseGasSwitches` near line 657). Exact code:

```dart
  /// Parses `SP change` events from a `<divecomputer>` into
  /// timestamped setpoint values in bar.
  ///
  /// Subsurface typically emits `value` in mbar (e.g., 1200), but third-party
  /// exporters sometimes use bar (e.g., 1.2). Normalization: if the parsed
  /// value is greater than 10, divide by 1000. Implausible values (non-
  /// positive) are dropped.
  List<({int timestamp, double value})> _parseSetpointEvents(
    XmlElement divecomputer,
  ) {
    final events = <({int timestamp, double value})>[];
    for (final event in divecomputer.findElements('event')) {
      final name = event.getAttribute('name')?.trim().toLowerCase();
      if (name != 'sp change') continue;
      final timestamp = _parseDurationSeconds(event.getAttribute('time'));
      if (timestamp == null) continue;
      final raw = _parseDouble(event.getAttribute('value'));
      if (raw == null || raw <= 0) continue;
      final bar = raw > 10 ? raw / 1000 : raw;
      events.add((timestamp: timestamp, value: bar));
    }
    return events;
  }
```

Third, call the helper from `_parseProfile` by appending the following block **after** the existing "Convert per-tank pressure fields into allTankPressures arrays" loop ends (immediately before `return points;` near `subsurface_xml_parser.dart:502`). Exact code:

```dart
    _applyEventFillOntoSamples<double>(
      samples: points,
      events: _parseSetpointEvents(divecomputer),
      sampleField: 'setpoint',
    );
```

- [ ] **Step 1.4: Run the test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "forward-fills setpoint from SP change events"`

Expected: PASS.

- [ ] **Step 1.5: Run the full parser test file to verify no regressions**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

Expected: all existing tests pass plus the one new test. No failures.

- [ ] **Step 1.6: Analyze and format**

Run: `dart analyze lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

Expected: zero issues.

Run: `dart format --set-exit-if-changed lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

Expected: exit code 0 (no changes needed). If it exits non-zero, run without `--set-exit-if-changed` to apply formatting, then re-check.

- [ ] **Step 1.7: Commit**

```bash
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart \
        test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat(ssrf-import): persist sample setpoint from SP change events"
```

---

## Task 2: Direct sample `setpoint` attribute takes precedence over events

Adds direct-attribute parsing in the per-sample loop and verifies the helper's "don't overwrite existing value" rule makes direct attributes win over event-derived values.

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` (add direct setpoint attr read in sample loop)
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` (add new test)

- [ ] **Step 2.1: Write the failing test**

Add the following test inside the existing `group('sample setpoint', ...)` block from Task 1:

```dart
  test('direct sample setpoint attribute wins over later events', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='15:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='20.0 m' mean='10.0 m' />
  <event time='10:00 min' name='SP change' value='700' />
  <sample time='1:00 min' depth='10.0 m' setpoint='1.2' />
  <sample time='10:30 min' depth='15.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final profile = dive['profile'] as List<Map<String, dynamic>>;
    expect(profile[0]['setpoint'], 1.2,
        reason: 'direct sample attribute preserved');
    expect(profile[1]['setpoint'], 0.7,
        reason: 'event fills sample that had no direct attribute');
  });
```

- [ ] **Step 2.2: Run the test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "direct sample setpoint attribute wins over later events"`

Expected: FAIL. The first assertion fails because the sample has no `setpoint` field set (we haven't wired direct-attribute reading yet). The second assertion may already pass from Task 1, but the first will fail regardless.

- [ ] **Step 2.3: Implement the direct-attribute read**

Inside `_parseProfile`, within the per-sample loop, add a line that reads the `setpoint` attribute directly. Insert it immediately after the `ppO2` read at `subsurface_xml_parser.dart:461-462`. Exact code to insert:

```dart
      final setpoint = _parseDouble(sample.getAttribute('setpoint'));
      if (setpoint != null) point['setpoint'] = setpoint;
```

The helper's existing "don't overwrite existing value" rule from Task 1 ensures the event pass won't clobber this.

- [ ] **Step 2.4: Run the test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "direct sample setpoint attribute wins over later events"`

Expected: PASS.

- [ ] **Step 2.5: Run the full parser test file**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

Expected: all tests pass.

- [ ] **Step 2.6: Commit**

```bash
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart \
        test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat(ssrf-import): honor direct sample setpoint attribute over events"
```

---

## Task 3: Setpoint unit normalization covers both mbar and bar values

Task 1's test already exercised the mbar path (`value='700'` -> `0.7`). Add an explicit decimal-bar test to pin the other branch, and an implausible-value guard test.

**Files:**
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` (add tests only — no production changes expected, since Task 1's implementation already handles these cases)

- [ ] **Step 3.1: Write the tests**

Inside `group('sample setpoint', ...)`, add:

```dart
  test('decimal bar value is used as-is (no divide by 1000)', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='10.0 m' mean='5.0 m' />
  <event time='0:00 min' name='SP change' value='1.2' />
  <sample time='0:30 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final profile = dive['profile'] as List<Map<String, dynamic>>;
    expect(profile[0]['setpoint'], 1.2);
  });

  test('implausible setpoint values are dropped', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test' dctype='CCR'>
  <depth max='10.0 m' mean='5.0 m' />
  <event time='0:00 min' name='SP change' value='0' />
  <event time='1:00 min' name='SP change' value='-100' />
  <sample time='2:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final profile = dive['profile'] as List<Map<String, dynamic>>;
    expect(profile[0].containsKey('setpoint'), isFalse,
        reason: 'both events dropped as implausible');
  });
```

- [ ] **Step 3.2: Run both tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "decimal bar value is used as-is"`

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "implausible setpoint values are dropped"`

Expected: both PASS. Task 1's implementation already handled these branches (the `raw > 10 ? raw / 1000 : raw` line for unit normalization and the `raw <= 0` guard for implausible values).

**If either fails,** the implementation in `_parseSetpointEvents` from Task 1 needs review. Expected code at that point:

```dart
      if (raw == null || raw <= 0) continue;
      final bar = raw > 10 ? raw / 1000 : raw;
```

- [ ] **Step 3.3: Commit**

```bash
git add test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "test(ssrf-import): pin setpoint unit normalization and implausible-value guard"
```

---

## Task 4: Preserve partial cylinders (gas-only, no size/description)

Relax the empty-cylinder skip predicate so a cylinder with only a gas mix (or only a `use` role, etc.) is emitted. This closes the "partial cylinders" gap from the spec.

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` (relax skip predicate at `_parseCylinders`)
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` (add test)

- [ ] **Step 4.1: Write the failing test**

Add the following group **after** the existing `group('sample setpoint', ...)` group added in Task 1:

```dart
group('cylinder partial preservation', () {
  test('preserves a cylinder with only a gas mix and role', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='30:00 min'>
  <cylinder size='11.1 l' workpressure='207.0 bar' description='AL80' o2='21.0%' start='200.0 bar' end='100.0 bar' />
  <cylinder o2='98.0%' use='oxygen' />
  <divecomputer model='Test'>
  <depth max='30.0 m' mean='15.0 m' />
  <sample time='0:10 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final tanks = dive['tanks'] as List<Map<String, dynamic>>;
    expect(tanks.length, 2, reason: 'gas-only cylinder is preserved');

    final gasOnly = tanks[1];
    final gasMix = gasOnly['gasMix'];
    expect((gasMix as dynamic).o2, 98.0);
    expect(gasOnly['role'], TankRole.oxygenSupply);
    expect(gasOnly.containsKey('volume'), isFalse,
        reason: 'no size attribute, so no volume');
    expect(gasOnly.containsKey('startPressure'), isFalse);
    expect(gasOnly.containsKey('endPressure'), isFalse);
  });
});
```

**Import note:** `TankRole` comes from `package:submersion/core/constants/enums.dart`. That import is already at line 6 of the test file, so no new import is needed.

**Type note:** `gasMix` is a `GasMix` instance from the parser. Casting to `dynamic` to access `.o2` avoids having to add a `GasMix` import just for a test. If the existing test file already imports `GasMix`, use the proper type cast instead. Grep: `grep -n "GasMix" test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` — if a matching import exists, replace `(gasMix as dynamic).o2` with the proper cast.

- [ ] **Step 4.2: Run the test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "preserves a cylinder with only a gas mix and role"`

Expected: FAIL. `tanks.length` is `1` because the gas-only cylinder is currently dropped by the skip predicate at `subsurface_xml_parser.dart:577-581`.

- [ ] **Step 4.3: Relax the skip predicate**

In `_parseCylinders` at `subsurface_xml_parser.dart:566-629`, replace the existing skip block with a version that skips only fully-empty elements. Locate this block (around lines 573-581):

```dart
    for (final cyl in dive.findElements('cylinder')) {
      final size = cyl.getAttribute('size');
      final description = cyl.getAttribute('description');
      // Skip empty cylinder elements
      if ((size == null || size.isEmpty) &&
          (description == null || description.isEmpty)) {
        cylinderIndex++;
        continue;
      }
```

Replace the `// Skip empty cylinder elements` comment and condition (the `if` + its body) with:

```dart
      // Skip only truly-empty cylinder elements (no useful content of any
      // kind). Any single attribute — gas mix, role, pressure, depth, etc. —
      // means this is a real cylinder worth preserving. This matters for CCR
      // files that emit gas-only cylinders (e.g., <cylinder o2='98%' use='oxygen' />).
      final hasAnyContent = (size != null && size.isNotEmpty) ||
          (description != null && description.isNotEmpty) ||
          cyl.getAttribute('o2') != null ||
          cyl.getAttribute('he') != null ||
          cyl.getAttribute('workpressure') != null ||
          cyl.getAttribute('start') != null ||
          cyl.getAttribute('end') != null ||
          cyl.getAttribute('use') != null ||
          cyl.getAttribute('depth') != null;
      if (!hasAnyContent) {
        cylinderIndex++;
        continue;
      }
```

Leave every other line of `_parseCylinders` unchanged — the output-index counter (`index`) and source-index counter (`cylinderIndex`) are already correctly separated in the surrounding code.

- [ ] **Step 4.4: Run the test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "preserves a cylinder with only a gas mix and role"`

Expected: PASS.

- [ ] **Step 4.5: Run the full parser test file**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

Expected: all tests pass, including the existing `dual-cylinder.ssrf`-based tests (regression check).

- [ ] **Step 4.6: Analyze and format**

Run: `dart analyze lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

Expected: zero issues.

Run: `dart format --set-exit-if-changed lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

Expected: exit 0.

- [ ] **Step 4.7: Commit**

```bash
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart \
        test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat(ssrf-import): preserve partial cylinders (gas-only, role-only)"
```

---

## Task 5: Verify cylinder source-indexing still advances past truly-empty slots

Regression-pinning test. When a fully-empty `<cylinder />` sits between two populated cylinders, the SSRF source-index for `pressureN` attributes on samples must still match the second real cylinder's position.

**Files:**
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` (add test only — no production changes expected)

- [ ] **Step 5.1: Write the test**

Add inside `group('cylinder partial preservation', ...)` (created in Task 4):

```dart
  test('truly-empty cylinder still advances the source index for pressureN', () async {
    final result = await parser.parse(
      xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='10:00 min'>
  <cylinder size='11.1 l' workpressure='207.0 bar' description='AL80' o2='21.0%' />
  <cylinder />
  <cylinder size='11.1 l' workpressure='207.0 bar' description='DECO50' o2='50.0%' />
  <divecomputer model='Test'>
  <depth max='20.0 m' mean='10.0 m' />
  <sample time='0:10 min' depth='5.0 m' pressure0='200.0 bar' pressure2='150.0 bar' />
  <sample time='5:00 min' depth='20.0 m' pressure0='150.0 bar' pressure2='120.0 bar' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
    );
    final dive = result.entitiesOf(ImportEntityType.dives).first;
    final tanks = dive['tanks'] as List<Map<String, dynamic>>;

    // Two emitted tanks (the truly-empty one is skipped).
    expect(tanks.length, 2);

    // The second emitted tank must have derived its start/end pressure from
    // the sample-level pressure2 attributes, which requires the source-index
    // counter to have stepped past the empty cylinder.
    final secondTank = tanks[1];
    expect(secondTank['startPressure'], 150.0,
        reason: 'first pressure2 value becomes startPressure fallback');
    expect(secondTank['endPressure'], 120.0,
        reason: 'last pressure2 value becomes endPressure fallback');
  });
```

- [ ] **Step 5.2: Run the test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "truly-empty cylinder still advances the source index for pressureN"`

Expected: PASS. Task 4's implementation kept `cylinderIndex++` inside the skip path, so the source-index stays aligned with the XML cylinder positions.

**If this fails,** the fix is to re-verify that the revised skip block in `_parseCylinders` still does `cylinderIndex++` before `continue` (it should — this is the same behavior as before Task 4).

- [ ] **Step 5.3: Commit**

```bash
git add test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "test(ssrf-import): pin cylinder source-index behavior for pressureN alignment"
```

---

## Task 6: Correct the import-gap tracker

Fix the factual error about UDDF tank role/material being unsupported (they are in fact supported — see `uddf_full_import_service.dart:1315-1329` and `uddf_entity_importer.dart:1290-1318`). Update the rows affected by this slice's parser changes.

**Files:**
- Modify: `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md`

- [ ] **Step 6.1: Update the combined table row for "Sample `setpoint`"**

In the combined table (around line 62), locate:

```markdown
| Sample `setpoint` | [ ] | Medium | Yes | Yes | No |
```

Replace with:

```markdown
| Sample `setpoint` | [x] | Medium | Yes | Yes | Yes |
```

- [ ] **Step 6.2: Update the combined table row for "Tank role / material metadata"**

In the combined table (around line 56), locate:

```markdown
| Tank role / material metadata | [ ] | High | Yes | No | No |
```

Replace with:

```markdown
| Tank role / material metadata | [ ] | High | Yes | Yes[^1] | No |
```

Then add the following footnote at the end of the file (just above the final line or at the very bottom of the "Notes" section):

```markdown
[^1]: UDDF already supports both tank role and tank material end-to-end via `<tankrole>` -> `TankRole` and `<tankmaterial>` -> `TankMaterial` mappings in the UDDF importer. The unchecked `Fixed` column reflects only the SSRF-side material gap, which is intentionally not closed by description-based inference.
```

- [ ] **Step 6.3: Update the combined table row for "Multi-tank definitions"**

In the combined table (around line 64), locate:

```markdown
| Multi-tank definitions | [ ] | Medium | Yes | Yes | No |
```

Replace with:

```markdown
| Multi-tank definitions | [ ] | Medium | Yes | Yes | Partial |
```

- [ ] **Step 6.4: Update the UDDF sub-table row for "Tank role / material metadata"**

In the "Most Valuable UDDF Fixes" table (around line 81), locate:

```markdown
| Tank role / material metadata | [ ] | High | Backend supports richer tank semantics and UDDF already carries some of it |
```

Replace with:

```markdown
| Tank role / material metadata | [x] | High | Already supported end-to-end — role via `<tankrole>` to `TankRole`, material via `<tankmaterial>` to `TankMaterial` |
```

- [ ] **Step 6.5: Update the SSRF sub-table row for "Sample `setpoint`"**

In the "Most Valuable SSRF Fixes" table (around line 106), locate:

```markdown
| Sample `setpoint` | [ ] | Medium | Real SSRF exports can imply it indirectly, but the parser does not currently map sample setpoint directly |
```

Replace with:

```markdown
| Sample `setpoint` | [x] | Medium | Direct sample `setpoint` attribute and `SP change` events (mbar or bar) now map to profile sample setpoint |
```

- [ ] **Step 6.6: Update the SSRF sub-table row for "Tank role / material metadata"**

In the "Most Valuable SSRF Fixes" table (around line 103), locate:

```markdown
| Tank role / material metadata | [x] | High | Real `.ssrf` has `use='diluent'`; direct role mapping is now preserved, while richer material metadata remains open |
```

Replace with:

```markdown
| Tank role / material metadata | [x] | High | Tank role mapping via `use` is preserved. SSRF cylinder elements expose no direct material field; description-based inference (e.g., `AL80 -> aluminum`) is intentionally deferred as a separate preset-matcher feature |
```

- [ ] **Step 6.7: Update the SSRF sub-table row for "Multi-tank definitions"**

In the "Most Valuable SSRF Fixes" table (around line 111), locate:

```markdown
| Multi-tank definitions | [ ] | Medium | Multi-cylinder and `pressureN` are present, but richer semantics are incomplete |
```

Replace with:

```markdown
| Multi-tank definitions | [ ] | Medium | Partial cylinders (gas-only / role-only) are now preserved. Active-tank-per-sample is deferred to Slice A.2 because it requires a new `DiveProfiles` column |
```

- [ ] **Step 6.8: Add a note about Slice A + A.2 to the Notes section**

In the "Notes" section at the bottom of the tracker (just before the final bullet or at the end of the bullet list), add:

```markdown
- Slice A (2026-04-17) closes sample `setpoint` and partial cylinder preservation for SSRF, and corrects the UDDF tank role/material entries to reflect existing end-to-end support. Active-tank-per-sample, which requires a new `DiveProfiles` column, is split out as Slice A.2. See `docs/superpowers/specs/2026-04-17-ssrf-direct-field-mappings-slice-a-design.md`.
```

- [ ] **Step 6.9: Verify the tracker still renders cleanly**

Open the file and visually scan the tables for alignment. Column counts must match between header and body rows. The combined table has 6 columns, the sub-tables have 4 columns.

- [ ] **Step 6.10: Commit**

```bash
git add docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md
git commit -m "docs: update import-gap tracker for slice A changes and UDDF correction"
```

---

## Task 7: Final verification

Run all the repo-level checks the pre-push hook would run, plus a final read of the changed parser file to confirm the three additions are coherent.

- [ ] **Step 7.1: Run parser tests**

Run: `flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

Expected: all tests pass. Count should be the previous count plus the five new tests added in Tasks 1, 2, 3, 4, and 5.

- [ ] **Step 7.2: Run broader analyzer**

Run: `flutter analyze lib/features/universal_import/data/parsers/ test/features/universal_import/data/parsers/`

Expected: zero issues in the subsurface parser or its test file.

- [ ] **Step 7.3: Format check**

Run: `dart format --set-exit-if-changed lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

Expected: exit 0.

- [ ] **Step 7.4: Confirm no unintended files changed**

Run: `git status`

Expected: clean working tree after the commits from Tasks 1, 2, 3, 4, and 6. (Task 3 committed only a test change; Task 5 committed only a test change; Tasks 1 and 2 and 4 committed production + test changes; Task 6 committed only the tracker doc.)

Run: `git log --oneline -10`

Expected: the five commits from this plan appear in order. No other unexpected commits.

- [ ] **Step 7.5: Optional — import a real SSRF file and smoke-test**

If the user has a CCR `.ssrf` file on hand that exposes `SP change` events or gas-only cylinders, import it via the app and confirm (a) profile sample setpoint values are no longer uniformly null for CCR dives, and (b) diluent/oxygen cylinders with only gas specs now appear in the dive's tank list. If no such file is available, skip this step — the unit tests above provide the primary verification.

---

## Summary of Commits

After all tasks complete, the branch should have these commits in order:

1. `feat(ssrf-import): persist sample setpoint from SP change events`
2. `feat(ssrf-import): honor direct sample setpoint attribute over events`
3. `test(ssrf-import): pin setpoint unit normalization and implausible-value guard`
4. `feat(ssrf-import): preserve partial cylinders (gas-only, role-only)`
5. `test(ssrf-import): pin cylinder source-index behavior for pressureN alignment`
6. `docs: update import-gap tracker for slice A changes and UDDF correction`

(The user may choose to squash or batch some of these. The separation above matches one task = one commit for clean history.)

## What this plan does NOT do (for clarity)

- Does not add an `activeTankIndex` column to `DiveProfiles` (deferred to Slice A.2).
- Does not modify UDDF code — UDDF tank role and material are already mapped end-to-end.
- Does not parse rebreather dive fields (setpoint low/high/deco, SCR config, diluent gas, loop O2, scrubber, loop volume) — Slice B.
- Does not parse bookmark/alarm events beyond gas-change — Slice C.
- Does not implement a fixed-CCR extradata fallback — the plan-phase verification found no fixture that exercises it, so per the spec's escape clause it is deferred to Slice B.
- Does not infer SSRF tank material from `description` presets (`"AL80" -> aluminum`) — out of scope for direct field mapping.
