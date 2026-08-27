# SSRF Slice D — Dive-Level Metadata + Provenance Fill-Out Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parse three categories of dive-level metadata from SSRF (dive computer identity, deco algorithm + gradient factors, surface pressure) and wire them into the existing Dives + DiveDataSources columns that are already waiting.

**Architecture:** All work in `subsurface_xml_parser.dart` (new `_parseDiveComputerMetadata` + `_parseDecoModel` helpers) and minor extensions to `uddf_entity_importer.dart`'s companion construction. No schema changes — every target column exists. Importer discovery revealed most keys are already consumed; only `decoAlgorithm` on Dives and three GF/algo mirror fields on DiveDataSources are missing.

**Tech Stack:** Dart 3 + Flutter 3 + `package:xml` + `flutter_test` + Drift (all unchanged).

**Spec reference:** `docs/superpowers/specs/2026-04-17-ssrf-slice-d-dive-level-metadata-design.md`

**Branch:** `feat/ssrf-slice-d` (already created off `feat/ssrf-slice-c3`).

---

## Pre-implementation Findings (verified before writing plan)

**Importer currently reads (no change needed)**:
- `diveData['surfacePressure']` → `DivesCompanion.surfacePressure` (line 1128)
- `diveData['gradientFactorLow']` → `DivesCompanion.gradientFactorLow` (line 1130)
- `diveData['gradientFactorHigh']` → `DivesCompanion.gradientFactorHigh` (line 1131)
- `diveData['diveComputerModel']` → `DivesCompanion.diveComputerModel` (line 1132)
- `diveData['diveComputerSerial']` → `DivesCompanion.diveComputerSerial` (line 1133)
- `diveData['diveComputerFirmware']` → `DivesCompanion.diveComputerFirmware` (line 1134)
- `diveData['diveComputerModel']` → `DiveDataSourcesCompanion.computerModel` (line 1466)
- `diveData['diveComputerSerial']` → `DiveDataSourcesCompanion.computerSerial` (line 1467)

**Importer currently MISSING (must be added)**:
- `decoAlgorithm` on `DivesCompanion`
- `decoAlgorithm` / `gradientFactorLow` / `gradientFactorHigh` on `DiveDataSourcesCompanion`

**Parser currently emits**: none of these keys. Entire parser-side work is new.

**Fixture content for end-to-end test** (`test/features/universal_import/data/parsers/fixtures/dual-cylinder.ssrf`):
- `<divecomputer model='Shearwater Peregrine' deviceid='23d341cc' diveid='804e0df5'>`
- `<extradata key='Serial' value='98d09a47' />`
- `<extradata key='FW Version' value='86' />`
- `<extradata key='Deco model' value='GF 40/85' />`
- `<surface pressure='1.012 bar' />`

**Commit authorization**: per-task commits authorized per memory's plan-approved-autonomous-execution exception.

**Pre-push hook note**: repo pre-push runs `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`. Handle format drift with `dart format` if needed.

---

## Task 1: Discovery verification

Pure investigation. Confirms pre-findings, writes a brief note, and commits it.

**Files:**
- Create: `docs/superpowers/plans/2026-04-17-ssrf-slice-d-discovery.md`

- [ ] **Step 1.1: Confirm importer-side key coverage**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
grep -n "diveComputerModel\|diveComputerSerial\|diveComputerFirmware\|surfacePressure\|gradientFactor\|decoAlgorithm" lib/features/dive_import/data/services/uddf_entity_importer.dart
```

Expected: matches for `surfacePressure`, `gradientFactorLow`, `gradientFactorHigh`, `diveComputerModel`, `diveComputerSerial`, `diveComputerFirmware`. Zero matches for `decoAlgorithm`. Record line numbers.

- [ ] **Step 1.2: Confirm parser has no existing metadata extractions**

```bash
grep -n "diveComputerModel\|diveComputerSerial\|diveComputerFirmware\|surfacePressure\|gradientFactor\|decoAlgorithm\|Deco model\|Serial\|FW Version" lib/features/universal_import/data/parsers/subsurface_xml_parser.dart
```

Expected: zero matches. If any exist, they need to be harmonized with Slice D's new work — flag them.

- [ ] **Step 1.3: Read the dual-cylinder.ssrf fixture's `<divecomputer>` block**

```bash
sed -n '7,30p' test/features/universal_import/data/parsers/fixtures/dual-cylinder.ssrf
```

Verify:
- `<divecomputer model='Shearwater Peregrine' ...>`
- `<extradata key='Serial' value='98d09a47' />`
- `<extradata key='FW Version' value='86' />`
- `<extradata key='Deco model' value='GF 40/85' />`
- `<surface pressure='1.012 bar' />`

If any value differs, update Task 5's end-to-end test assertions to match.

- [ ] **Step 1.4: Confirm importer's DiveDataSourcesCompanion doesn't yet set decoAlgorithm / GFs**

Open `lib/features/dive_import/data/services/uddf_entity_importer.dart` around lines 1462-1480 (the DiveDataSourcesCompanion construction). Confirm no `decoAlgorithm:`, `gradientFactorLow:`, or `gradientFactorHigh:` lines exist there. These three keys are Task 4's additions.

- [ ] **Step 1.5: Write discovery note**

Create `docs/superpowers/plans/2026-04-17-ssrf-slice-d-discovery.md` with:

```markdown
# Slice D Discovery

## Date
2026-04-17

## Importer key inventory
- Already consumed (no change needed): [list the 6 found in Step 1.1]
- Missing, Task 4 adds: `decoAlgorithm` on DivesCompanion; `decoAlgorithm`, `gradientFactorLow`, `gradientFactorHigh` on DiveDataSourcesCompanion

## Parser current state
- Zero existing references to Slice D's metadata keys (Step 1.2 confirmed)

## Fixture content for end-to-end test
[Record the five verbatim XML excerpts from Step 1.3]

## Risks / surprises
[Anything that diverges from the plan's pre-findings]
```

- [ ] **Step 1.6: Commit**

```bash
git add docs/superpowers/plans/2026-04-17-ssrf-slice-d-discovery.md
git commit -m "docs(slice-d): discovery findings for SSRF dive-level metadata parsing"
```

Do NOT include any `2026-04-17-*` spec/plan files (they stay untracked per repo convention).

---

## Task 2: Add `_parseDecoModel` helper with unit tests

TDD cycle for the regex parser that splits `'GF X/Y'` strings.

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart`

- [ ] **Step 2.1: Write failing tests**

Because `_parseDecoModel` is a private function, the test exercises it indirectly via `_parseDiveComputerMetadata` (Task 3) or via a visible-for-testing annotation. For Slice D, the simplest path is to test it indirectly through the parser's public output — but since the parser output requires a full `<divecomputer>` element, Task 3's tests cover that. This Task 2 is implementation-only; unit tests for `_parseDecoModel` live in Task 3's group.

Skip this step — move to Step 2.2.

- [ ] **Step 2.2: Add `_parseDecoModel` helper**

In `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`, add a static private helper method on the `SubsurfaceXmlParser` class. Place it near the other static private helpers (after `_fillSparseField` or `_applyEventFillOntoSamples` — match existing style):

```dart
  /// Parses a Subsurface `Deco model` extradata value into algorithm + gradient
  /// factors. Subsurface emits strings like `'GF 40/85'` for Bühlmann with
  /// gradient factors. Non-GF formats (e.g., `'VPM-B +2'`) are preserved as
  /// the raw lowercased algorithm string with no gradient-factor extraction.
  ///
  /// Returns a map with optional keys:
  ///   - `'decoAlgorithm'`: String
  ///   - `'gradientFactorLow'`: int
  ///   - `'gradientFactorHigh'`: int
  ///
  /// Returns an empty map when the input is null or empty.
  static Map<String, dynamic> _parseDecoModel(String? value) {
    if (value == null || value.trim().isEmpty) return const {};
    final trimmed = value.trim();
    final gfMatch = RegExp(r'^GF\s+(\d+)\s*/\s*(\d+)$').firstMatch(trimmed);
    if (gfMatch != null) {
      return {
        'decoAlgorithm': 'buhlmann',
        'gradientFactorLow': int.parse(gfMatch.group(1)!),
        'gradientFactorHigh': int.parse(gfMatch.group(2)!),
      };
    }
    return {'decoAlgorithm': trimmed.toLowerCase()};
  }
```

- [ ] **Step 2.3: Analyze**

```bash
dart analyze lib/features/universal_import/data/parsers/subsurface_xml_parser.dart
```

Expected: zero issues.

- [ ] **Step 2.4: No commit yet**

The helper is unused by any caller — committing in isolation would leave it dangling. Continue to Task 3, which adds the caller, and commit the two together.

---

## Task 3: Add `_parseDiveComputerMetadata` method + parser tests

Adds the main extraction method, wires it into `_parseDive`, and introduces the `dive-level metadata` test group.

**Files:**
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` (add method + call site)
- Modify: `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` (new test group)

- [ ] **Step 3.1: Write failing tests**

Append to the test file at the end of `main()`, after existing groups but before the closing `}` of `main()`:

```dart
  group('dive-level metadata', () {
    test('parses divecomputer model attribute', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Shearwater Peregrine'>
  <depth max='10.0 m' mean='5.0 m' />
  <sample time='1:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['diveComputerModel'], 'Shearwater Peregrine');
    });

    test('parses Serial extradata into diveComputerSerial', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test'>
  <depth max='10.0 m' mean='5.0 m' />
  <extradata key='Serial' value='98d09a47' />
  <sample time='1:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['diveComputerSerial'], '98d09a47');
    });

    test('parses FW Version extradata into diveComputerFirmware', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test'>
  <depth max='10.0 m' mean='5.0 m' />
  <extradata key='FW Version' value='86' />
  <sample time='1:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['diveComputerFirmware'], '86');
    });

    test('parses Deco model "GF 40/85" into buhlmann + gradient factors', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test'>
  <depth max='10.0 m' mean='5.0 m' />
  <extradata key='Deco model' value='GF 40/85' />
  <sample time='1:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['decoAlgorithm'], 'buhlmann');
      expect(dive['gradientFactorLow'], 40);
      expect(dive['gradientFactorHigh'], 85);
    });

    test('parses Deco model non-GF format as lowercased algo string without GFs', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test'>
  <depth max='10.0 m' mean='5.0 m' />
  <extradata key='Deco model' value='VPM-B +2' />
  <sample time='1:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['decoAlgorithm'], 'vpm-b +2');
      expect(dive.containsKey('gradientFactorLow'), isFalse);
      expect(dive.containsKey('gradientFactorHigh'), isFalse);
    });

    test('parses surface pressure attribute', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test'>
  <depth max='10.0 m' mean='5.0 m' />
  <surface pressure='1.012 bar' />
  <sample time='1:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive['surfacePressure'], 1.012);
    });

    test('ignores unrelated extradata keys', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer model='Test'>
  <depth max='10.0 m' mean='5.0 m' />
  <extradata key='Logversion' value='13(PNF)' />
  <extradata key='Battery type' value='3.7V Li-Ion' />
  <extradata key='Battery at end' value='4.0 V' />
  <sample time='1:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      // None of the Slice D keys should be set from unrelated extradata
      expect(dive.containsKey('diveComputerSerial'), isFalse);
      expect(dive.containsKey('diveComputerFirmware'), isFalse);
      expect(dive.containsKey('decoAlgorithm'), isFalse);
      expect(dive.containsKey('gradientFactorLow'), isFalse);
    });

    test('no metadata present yields no metadata keys', () async {
      final result = await parser.parse(
        xmlBytes('''
<divelog program='subsurface' version='3'>
<dives>
<dive number='1' date='2025-01-15' time='10:00:00' duration='5:00 min'>
  <divecomputer>
  <depth max='10.0 m' mean='5.0 m' />
  <sample time='1:00 min' depth='5.0 m' />
  </divecomputer>
</dive>
</dives>
</divelog>
'''),
      );
      final dive = result.entitiesOf(ImportEntityType.dives).first;
      expect(dive.containsKey('diveComputerModel'), isFalse);
      expect(dive.containsKey('diveComputerSerial'), isFalse);
      expect(dive.containsKey('diveComputerFirmware'), isFalse);
      expect(dive.containsKey('decoAlgorithm'), isFalse);
      expect(dive.containsKey('surfacePressure'), isFalse);
    });
  });
```

- [ ] **Step 3.2: Run tests to verify they fail**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "dive-level metadata"
```

Expected: 8 tests fail (the key emissions don't exist yet in parser output).

- [ ] **Step 3.3: Add `_parseDiveComputerMetadata` method**

In `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart`, add an instance method (or static if matching existing style — check `_parseDecoModel`'s scope from Task 2 and match). Place it near the other `_parseXxx` methods. Exact code:

```dart
  /// Extracts dive-level metadata from a `<divecomputer>` element:
  /// model attribute, serial/firmware from extradata, deco algorithm and
  /// gradient factors parsed from the `Deco model` extradata string, and
  /// surface pressure from the `<surface>` child element.
  ///
  /// Returns a map with only the keys that had values. Absent fields are
  /// omitted (no null-value noise).
  Map<String, dynamic> _parseDiveComputerMetadata(XmlElement divecomputer) {
    final result = <String, dynamic>{};

    final model = divecomputer.getAttribute('model');
    if (model != null && model.isNotEmpty) {
      result['diveComputerModel'] = model;
    }

    final surface = divecomputer.findElements('surface').firstOrNull;
    if (surface != null) {
      final pressure = _parseDouble(surface.getAttribute('pressure'));
      if (pressure != null) result['surfacePressure'] = pressure;
    }

    final extradata = <String, String>{};
    for (final ed in divecomputer.findElements('extradata')) {
      final key = ed.getAttribute('key');
      final value = ed.getAttribute('value');
      if (key != null && value != null) extradata[key] = value;
    }

    final serial = extradata['Serial'];
    if (serial != null && serial.isNotEmpty) {
      result['diveComputerSerial'] = serial;
    }

    final fwVersion = extradata['FW Version'];
    if (fwVersion != null && fwVersion.isNotEmpty) {
      result['diveComputerFirmware'] = fwVersion;
    }

    final decoModel = extradata['Deco model'];
    if (decoModel != null) {
      result.addAll(_parseDecoModel(decoModel));
    }

    return result;
  }
```

- [ ] **Step 3.4: Wire into `_parseDive`**

Find `_parseDive` in the same file. After the existing `<divecomputer>`-element resolution (wherever `divecomputer` local is assigned), and before the return of the result map, merge the metadata:

```dart
    if (divecomputer != null) {
      result.addAll(_parseDiveComputerMetadata(divecomputer));
    }
```

Exact placement: pick a natural spot next to similar merges (e.g., after the `gasSwitches` merge from Slice C or the `events` merge from Slice C.2). If uncertain, place at the end of `_parseDive` just before `return result;`.

- [ ] **Step 3.5: Run tests to verify they pass**

```bash
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart --plain-name "dive-level metadata"
```

Expected: all 8 pass.

- [ ] **Step 3.6: Run full parser test file**

```bash
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
```

Expected: all tests pass (no regressions from Slice A/C/C.2/C.3).

- [ ] **Step 3.7: Analyze and format**

```bash
dart analyze lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
dart format --set-exit-if-changed lib/features/universal_import/data/parsers/subsurface_xml_parser.dart test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 3.8: Commit**

```bash
git add lib/features/universal_import/data/parsers/subsurface_xml_parser.dart \
        test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
git commit -m "feat(ssrf-import): parse dive-computer model/serial/firmware, deco model, surface pressure"
```

---

## Task 4: Extend importer with missing Dives + DiveDataSources fields

Adds `decoAlgorithm` to `DivesCompanion` and three mirror fields to `DiveDataSourcesCompanion`.

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart`

- [ ] **Step 4.1: Add `decoAlgorithm` to DivesCompanion**

Open `lib/features/dive_import/data/services/uddf_entity_importer.dart`. Navigate to the `DivesCompanion(...)` construction that consumes dive-level metadata (around lines 1120-1140 per Discovery findings). The block currently looks like:

```dart
        surfacePressure: asDoubleOrNull(diveData['surfacePressure']),
        ...
        gradientFactorLow: diveData['gradientFactorLow'] as int?,
        gradientFactorHigh: diveData['gradientFactorHigh'] as int?,
        diveComputerModel: diveData['diveComputerModel'] as String?,
        diveComputerSerial: diveData['diveComputerSerial'] as String?,
        diveComputerFirmware: diveData['diveComputerFirmware'] as String?,
```

Add a `decoAlgorithm` line adjacent to the existing deco-related fields. Suggested placement: immediately before `gradientFactorLow`:

```dart
        surfacePressure: asDoubleOrNull(diveData['surfacePressure']),
        ...
        decoAlgorithm: diveData['decoAlgorithm'] as String?,
        gradientFactorLow: diveData['gradientFactorLow'] as int?,
        gradientFactorHigh: diveData['gradientFactorHigh'] as int?,
        diveComputerModel: diveData['diveComputerModel'] as String?,
        ...
```

Preserve exact indentation and surrounding lines.

- [ ] **Step 4.2: Add three mirror fields to DiveDataSourcesCompanion**

Around line 1462-1480, the existing `DiveDataSourcesCompanion(...)` currently reads `diveComputerModel` and `diveComputerSerial` via the `diveData` map. Add three more fields — the exact column names are `decoAlgorithm`, `gradientFactorLow`, `gradientFactorHigh` per the Drift schema (see `lib/core/database/database.dart:977-979`):

```dart
        DiveDataSourcesCompanion(
          id: Value(_uuid.v4()),
          diveId: Value(diveId),
          isPrimary: const Value(true),
          computerModel: Value(diveData['diveComputerModel'] as String?),
          computerSerial: Value(diveData['diveComputerSerial'] as String?),
          sourceFileName: Value(sourceFileName),
          sourceFileFormat: const Value('uddf'),
          maxDepth: Value(asDoubleOrNull(diveData['maxDepth'])),
          avgDepth: Value(asDoubleOrNull(diveData['avgDepth'])),
          duration: Value(dive.bottomTime?.inSeconds),
          waterTemp: Value(asDoubleOrNull(diveData['waterTemp'])),
          entryTime: Value(dive.entryTime),
          exitTime: Value(dive.exitTime),
          cns: Value(asDoubleOrNull(diveData['cnsEnd'])),
          otu: Value(asDoubleOrNull(diveData['otu'])),
          decoAlgorithm: Value(diveData['decoAlgorithm'] as String?),
          gradientFactorLow: Value(diveData['gradientFactorLow'] as int?),
          gradientFactorHigh: Value(diveData['gradientFactorHigh'] as int?),
          importedAt: Value(now),
          createdAt: Value(now),
        ),
```

Place the three new lines next to `otu` so related fields group together, before `importedAt`.

- [ ] **Step 4.3: Verify compilation**

```bash
dart analyze lib/features/dive_import/data/services/uddf_entity_importer.dart
```

Expected: zero issues. If the field names differ from the Drift schema (e.g., Drift might generate `gradientFactorLow` as a different identifier in the Companion), the analyzer will catch it.

- [ ] **Step 4.4: Run importer tests for regression**

```bash
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: all tests pass. No tests should break because we're only ADDING fields, not modifying existing ones.

- [ ] **Step 4.5: Format**

```bash
dart format --set-exit-if-changed lib/features/dive_import/data/services/uddf_entity_importer.dart
```

Expected: exit 0.

- [ ] **Step 4.6: Commit**

```bash
git add lib/features/dive_import/data/services/uddf_entity_importer.dart
git commit -m "feat(ssrf-import): persist decoAlgorithm on Dives + mirror deco fields on DiveDataSources"
```

---

## Task 5: End-to-end fixture test

Uses `dual-cylinder.ssrf` (existing fixture) to verify the full Slice D chain: parse → import → DB row population.

**Files:**
- Modify: `test/features/dive_import/data/services/uddf_entity_importer_test.dart`

- [ ] **Step 5.1: Inspect sibling fixture-based tests**

```bash
grep -n "dual-cylinder\|fixtures/" test/features/dive_import/data/services/uddf_entity_importer_test.dart | head -10
```

If there's already a fixture-loading pattern in this file, reuse it. If not, check:

```bash
grep -n "fixtures/" test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart | head -5
```

for the existing pattern (File('test/features/.../fixtures/dual-cylinder.ssrf').readAsBytesSync() or similar).

- [ ] **Step 5.2: Write the end-to-end test**

Add a new group at the end of `uddf_entity_importer_test.dart`, or append to an existing `Profile events persistence`-style group if logically adjacent. The test shape:

```dart
  group('dive-level metadata persistence (Slice D)', () {
    test('dual-cylinder.ssrf populates Dives + DiveDataSources metadata fields',
        () async {
      // Load the fixture. Use File path or the reusable pattern from
      // test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart
      // if it has a fixture loader helper.
      final bytes = await File(
        'test/features/universal_import/data/parsers/fixtures/dual-cylinder.ssrf',
      ).readAsBytes();

      // Parse via SubsurfaceXmlParser to get an ImportPayload with the
      // dive-level metadata keys populated.
      final parsePayload = await SubsurfaceXmlParser().parse(bytes);
      final diveDataList = parsePayload.entitiesOf(ImportEntityType.dives);
      expect(diveDataList.length, 1);
      final diveData = diveDataList.first;

      // Parser-level assertions — verify the expected keys are populated:
      expect(diveData['diveComputerModel'], 'Shearwater Peregrine');
      expect(diveData['diveComputerSerial'], '98d09a47');
      expect(diveData['diveComputerFirmware'], '86');
      expect(diveData['decoAlgorithm'], 'buhlmann');
      expect(diveData['gradientFactorLow'], 40);
      expect(diveData['gradientFactorHigh'], 85);
      expect(diveData['surfacePressure'], 1.012);

      // Importer-level: build a UddfImportResult, run through importer.import(...),
      // and verify the captured DivesCompanion and DiveDataSourcesCompanion
      // carry the expected values. Use the mock harness pattern from sibling
      // tests in this file (e.g., Profile events persistence tests).
      //
      // Assertions on the captured DivesCompanion insert:
      //   .diveComputerModel.value == 'Shearwater Peregrine'
      //   .diveComputerSerial.value == '98d09a47'
      //   .diveComputerFirmware.value == '86'
      //   .decoAlgorithm.value == 'buhlmann'
      //   .gradientFactorLow.value == 40
      //   .gradientFactorHigh.value == 85
      //   .surfacePressure.value == 1.012
      //
      // Assertions on the captured DiveDataSourcesCompanion insert:
      //   .computerModel.value == 'Shearwater Peregrine'
      //   .computerSerial.value == '98d09a47'
      //   .decoAlgorithm.value == 'buhlmann'
      //   .gradientFactorLow.value == 40
      //   .gradientFactorHigh.value == 85
    });
  });
```

**CRITICAL**: inspect the sibling tests' mock harness pattern before writing. The existing `Profile events persistence` group (from Slices C/C.2/C.3) uses `verify(mockDiveRepo.insertDive(captureAny)).captured` and `verify(mockDiveRepo.saveComputerReading(captureAny)).captured` or similar — use the same pattern for consistent mock captures. If the existing tests use `insertDive` for Dives or a different method, match it exactly.

- [ ] **Step 5.3: Run the test**

```bash
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart --plain-name "dual-cylinder.ssrf populates Dives"
```

Expected: PASS. If it fails on the parser-level assertions, Task 3 is incomplete. If it fails on the importer-level assertions, Task 4 missed a field.

- [ ] **Step 5.4: Run full importer file**

```bash
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: all tests pass.

- [ ] **Step 5.5: Analyze and format**

```bash
dart analyze test/features/dive_import/data/services/uddf_entity_importer_test.dart
dart format --set-exit-if-changed test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: zero issues; format exit 0.

- [ ] **Step 5.6: Commit**

```bash
git add test/features/dive_import/data/services/uddf_entity_importer_test.dart
git commit -m "test(ssrf-import): end-to-end dive-level metadata fixture test"
```

---

## Task 6: Tracker doc update

**Files:**
- Modify: `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md`

- [ ] **Step 6.1: Update combined table `Dive-level deco metadata` row**

Find the row (around combined table). Currently:
```
| Dive-level deco metadata (`decoAlgorithm`, `GF low/high`, conservatism) | [ ] | Medium | Yes | No | No |
```

Replace with (SSRF → Partial since conservatism is deferred; UDDF unchanged):
```
| Dive-level deco metadata (`decoAlgorithm`, `GF low/high`, conservatism) | [ ] | Medium | Yes | No | Partial |
```

- [ ] **Step 6.2: Update combined table `Surface pressure / altitude / surface interval` row**

Find:
```
| Surface pressure / altitude / surface interval | [ ] | Medium | Yes | No | No |
```

Replace with (surface pressure covered; altitude + surface interval deferred):
```
| Surface pressure / altitude / surface interval | [ ] | Medium | Yes | No | Partial |
```

- [ ] **Step 6.3: Update combined table `Source provenance snapshot (DiveDataSources)` row**

Find:
```
| Source provenance snapshot (`DiveDataSources`) | [ ] | Medium | Yes | No | No |
```

Replace with (SSRF now fills model, serial, algo, GFs — comprehensive enough to mark Yes; UDDF unchanged):
```
| Source provenance snapshot (`DiveDataSources`) | [ ] | Medium | Yes | No | Yes |
```

- [ ] **Step 6.4: Update SSRF sub-table rows**

Find the three SSRF sub-table rows and rewrite the Why cells:

**`Dive-level deco metadata`**:
```
| Dive-level deco metadata (`decoAlgorithm`, `GF low/high`, conservatism) | [ ] | Medium | Slice D parses `<extradata key='Deco model' value='GF X/Y'/>` into `Dives.decoAlgorithm='buhlmann'` + `gradientFactorLow` + `gradientFactorHigh`; mirrors to `DiveDataSources`. Non-GF algo strings stored as raw lowercased value. `decoConservatism` remains null (Subsurface doesn't commonly emit this). |
```

**`Surface pressure / altitude / surface interval`**:
```
| Surface pressure / altitude / surface interval | [ ] | Medium | Slice D parses `<surface pressure='X bar'/>` into `Dives.surfacePressure`. Altitude (derivation from barometric pressure) and surface interval (cross-dive computation) remain deferred to separate slices. |
```

**`Source provenance snapshot (DiveDataSources)`**:
```
| Source provenance snapshot (`DiveDataSources`) | [x] | Medium | Slice D parses `<divecomputer model>`, `<extradata key='Serial'>`, `<extradata key='FW Version'>`, `<extradata key='Deco model'>` into `Dives.diveComputerModel/Serial/Firmware` and mirrors model/serial/algo/GFs into `DiveDataSources`. Library-descriptor fields (`descriptorVendor`, `descriptorProduct`, `libdivecomputerVersion`) remain populated only for native DC downloads. |
```

- [ ] **Step 6.5: Add Slice D bullet to Notes section**

Add at the end of the bullet list, before any footnote definitions:

```
- Slice D (2026-04-17) adds dive-level metadata parsing from SSRF: dive computer identity (model, serial, firmware from `<divecomputer model>` attribute + `Serial` / `FW Version` extradata), deco metadata (algo + gradient factors parsed from `Deco model` extradata via regex), and surface pressure (from `<surface pressure>` child). Populates matching columns on both `Dives` and `DiveDataSources`. No schema work — all target columns exist. Altitude (barometric derivation) and surface interval (cross-dive computation) remain deferred as separate work. See `docs/superpowers/specs/2026-04-17-ssrf-slice-d-dive-level-metadata-design.md`.
```

- [ ] **Step 6.6: Visual sanity check**

Verify column counts preserved (combined: 6 cols / 7 pipes; sub-tables: 4 cols / 5 pipes).

- [ ] **Step 6.7: Commit**

```bash
git add docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md
git commit -m "docs(tracker): record Slice D dive-level metadata coverage"
```

---

## Task 7: Final verification

- [ ] **Step 7.1: Scoped tests**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
flutter test test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart 2>&1 | tail -3
flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart 2>&1 | tail -3
```

All pass.

- [ ] **Step 7.2: Broader tree**

```bash
flutter test test/features/dive_import/ 2>&1 | tail -5
flutter test test/features/universal_import/ 2>&1 | tail -5
flutter test test/features/dive_log/ 2>&1 | tail -5
```

All pass; no regressions.

- [ ] **Step 7.3: Analyzer**

```bash
dart analyze lib/ test/ 2>&1 | tail -5
```

Expected: No issues found.

- [ ] **Step 7.4: Format check**

```bash
dart format --set-exit-if-changed \
  lib/features/universal_import/data/parsers/subsurface_xml_parser.dart \
  lib/features/dive_import/data/services/uddf_entity_importer.dart \
  test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart \
  test/features/dive_import/data/services/uddf_entity_importer_test.dart
```

Expected: exit 0.

- [ ] **Step 7.5: Git state**

```bash
git status --short
git log --oneline origin/main..HEAD | head -15
```

Working tree shows only untracked `docs/superpowers/` 2026-04-17 files. Commit log shows Slice D commits layered on top of Slice A + C + C.2 + C.3.

- [ ] **Step 7.6: Spot-check**

```bash
grep -n "_parseDiveComputerMetadata\|_parseDecoModel" lib/features/universal_import/data/parsers/subsurface_xml_parser.dart | head -5
grep -n "decoAlgorithm:\|gradientFactorLow:\|gradientFactorHigh:" lib/features/dive_import/data/services/uddf_entity_importer.dart | head -10
```

Expected:
- Parser has `_parseDiveComputerMetadata` declaration + `_parseDecoModel` declaration + one call site.
- Importer has `decoAlgorithm:` on both `DivesCompanion` (added Task 4 Step 4.1) and `DiveDataSourcesCompanion` (added Task 4 Step 4.2); `gradientFactorLow/High:` exist on DiveDataSourcesCompanion (added Task 4 Step 4.2) plus the pre-existing lines on DivesCompanion.

---

## Summary of Commits

1. `docs(slice-d): discovery findings for SSRF dive-level metadata parsing`
2. `feat(ssrf-import): parse dive-computer model/serial/firmware, deco model, surface pressure`
3. `feat(ssrf-import): persist decoAlgorithm on Dives + mirror deco fields on DiveDataSources`
4. `test(ssrf-import): end-to-end dive-level metadata fixture test`
5. `docs(tracker): record Slice D dive-level metadata coverage`

Plus fix-ups from review loops.

## Out of Scope Reminders

- Altitude from barometric pressure — separate slice.
- Surface interval computation across consecutive dives — separate slice.
- UDDF parity for these metadata fields — separate slice.
- `decoConservatism` — deferred (Subsurface doesn't commonly emit this).
- Battery / Logversion extradata — no user-facing target column.
- Non-GF deco algo normalization (e.g., `'vpm-b +2'` → canonical `'vpm'`) — raw-string preservation chosen to keep scope tight.
