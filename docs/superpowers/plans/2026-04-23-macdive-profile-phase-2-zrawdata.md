# MacDive Profile Decoding — Phase 2 (ZRAWDATA via libdivecomputer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce decoded profile samples for every dive imported from a MacDive SQLite database that has a non-null `ZDIVE.ZRAWDATA` column. Route the raw bytes through the existing `libdivecomputer_plugin.parseRawDiveData()` API and project the result into the unified `ImportPayload` format. Dives without `ZRAWDATA` (older imports, non-Shearwater computers, manual entries) continue to import without a profile, with an `ImportWarning` flagging why.

**Architecture:** Extends `MacDiveDiveMapper` (already on `main` from PR #256) by adapting the ZRAWDATA handling pattern already proven in `ShearwaterDiveMapper.mergeWithParsedDive()`. No new service layer, no new typed model — we consume the plugin's `ProfileSample` directly and project it to the `ImportPayload` profile map using the same 10-line helper pattern as `MacDiveXmlParser`.

**Tech Stack:** Flutter, Dart 3, `libdivecomputer_plugin` (local package at `packages/libdivecomputer_plugin/`), Riverpod, `flutter_test`.

**Dependencies:**
- PR #256 (MacDive SQLite import, `feature/macdive-sqlite`) is merged to `main` as of 2026-04-23.
- Phase 1 spike PR (#260) should merge before this work so `docs/import-formats/macdive-zsamples.md` is available on `main` for reference. (Not strictly required — this plan doesn't touch those files — but it makes the history coherent.)
- The `libdivecomputer` git submodule must be initialized in the worktree.

**Spec:** `docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md` (as updated with the Phase 1 NO-GO on ZSAMPLES + pivot to ZRAWDATA).

**Investigation foundation:** `docs/import-formats/macdive-zsamples.md` explains why `ZSAMPLES` was ruled out (per-dive AES encryption). This plan targets `ZRAWDATA` instead — 100% of Shearwater dives (267/267 in the sample DB) have it, and `libdivecomputer` parses Shearwater's native format natively.

---

## Pattern to copy

The entire plan is effectively "do what `ShearwaterDiveMapper.mergeWithParsedDive()` does, but inside `MacDiveDiveMapper`."

Key existing code to reuse:

| Reference | File | Purpose |
|---|---|---|
| `DiveComputerHostApi().parseRawDiveData(vendor, product, 0, bytes)` | `packages/libdivecomputer_plugin/lib/src/generated/dive_computer_api.g.dart` | Plugin's bytes-in → `ParsedDive` API |
| `ShearwaterDiveMapper._parseWithFfi(...)` (~line 328) | `lib/features/universal_import/data/services/shearwater_dive_mapper.dart` | How to call `parseRawDiveData` with error handling |
| `ShearwaterDiveMapper.mergeWithParsedDive(map, parsed, warnings)` (~line 341) | same file | How to fold `ParsedDive.samples` into an ImportPayload map |
| `MacDiveXmlParser._buildProfile(...)` lines 279–291 | `lib/features/universal_import/data/parsers/macdive_xml_parser.dart` | Existing `ProfileSample`-shaped → payload-map projection reference |

---

## File Structure

| File | Role | New / Modified |
|---|---|---|
| `lib/features/universal_import/data/services/macdive_dive_mapper.dart` | Replace `profile: const []` at line ~334 with a ZRAWDATA-decode + sample-projection block adapted from `ShearwaterDiveMapper`. | Modified |
| `lib/features/universal_import/data/services/macdive_raw_types.dart` | No structural change — `MacDiveRawDive` already has `rawDataBlob: Uint8List?` and `computerName: String?` from PR #256. Verify at plan start. | Reference |
| `lib/features/universal_import/data/models/import_warning.dart` (or wherever `ImportWarning` lives — `grep -r 'class ImportWarning' lib/` at plan start) | Add `ImportWarning.sampleDecodeFailed({diveUuid, reason})`. If a compatible variant already exists, reuse it. | Modified |
| `test/features/universal_import/data/services/macdive_dive_mapper_test.dart` | Extend the existing test for MacDiveDiveMapper (added in PR #256) with two new tests: one for successful ZRAWDATA decode → populated `profile`, one for missing/unparseable ZRAWDATA → `profile: []` + warning. Use a stubbed plugin API. | Modified |
| `test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart` | Gated real-sample test: import the full sample SQLite, confirm Shearwater dives get non-empty profiles, cross-check against UDDF per UUID. Mirrors `macdive_xml_real_sample_test.dart` structure. | Created |

**Notably NOT created** (compared to the original skeleton plan):
- ~~`MacDiveSqliteSample` typed model~~ — use `pigeon.ProfileSample` directly from the plugin.
- ~~`MacDiveSamplesDecoder` service~~ — `parseRawDiveData` IS the decoder.
- ~~`test/fixtures/macdive_sqlite/zrawdata_golden/`~~ — the plugin owns parser-level golden tests; the mapper layer only needs unit tests with stubbed plugin calls + the gated real-sample regression.

---

## Task 1: Worktree setup and baseline verification

**Files:** No files created.

- [ ] **Step 1: Create the Phase 2 worktree from `main`**

```bash
git fetch origin
git worktree add -b feature/macdive-profile-zrawdata \
  .worktrees/macdive-profile-zrawdata \
  origin/main
```

- [ ] **Step 2: Initialize submodules and Flutter deps in the worktree**

```bash
cd .worktrees/macdive-profile-zrawdata
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Symlink sample data into the worktree (gitignored, same as Phase 1)**

```bash
ln -s /Users/ericgriffin/repos/submersion-app/submersion/scripts/sample_data \
      scripts/sample_data
```

- [ ] **Step 4: Confirm the expected files exist and the baseline tests pass**

```bash
ls lib/features/universal_import/data/services/macdive_dive_mapper.dart
ls lib/features/universal_import/data/services/macdive_raw_types.dart
ls lib/features/universal_import/data/services/shearwater_dive_mapper.dart
grep -n "profile.*const.*\[\]" lib/features/universal_import/data/services/macdive_dive_mapper.dart
flutter test test/features/universal_import/data/services/macdive_dive_mapper_test.dart
```

Expected:
- All three files listed.
- `grep` finds the `profile: const []` line (record its line number — it's the integration point).
- Existing mapper tests pass before any changes.

- [ ] **Step 5: Locate `ImportWarning` and confirm whether `sampleDecodeFailed` (or a compatible variant) already exists**

```bash
grep -rn "class ImportWarning" lib/
grep -rn "sampleDecodeFailed\|SampleDecodeFailed\|profile.*decode.*failed" lib/
```

Record:
- The file where `ImportWarning` is defined.
- Whether a matching variant exists (if yes, reuse; if no, add in Task 4).

- [ ] **Step 6: Read `ShearwaterDiveMapper._parseWithFfi` and `mergeWithParsedDive` carefully**

```bash
sed -n '80,150p' lib/features/universal_import/data/services/shearwater_dive_mapper.dart
sed -n '320,430p' lib/features/universal_import/data/services/shearwater_dive_mapper.dart
```

These are the reference implementations for all subsequent tasks. If they differ materially from what this plan assumes (e.g. different method names, different signatures), stop and report — the plan needs an update before proceeding.

- [ ] **Step 7: No commit** (setup/read-only).

---

## Task 2: Failing tests for ZRAWDATA decode in `MacDiveDiveMapper`

**Files:**
- Modify: `test/features/universal_import/data/services/macdive_dive_mapper_test.dart`

This task adds failing tests first (TDD). The tests assume a stubbed `parseRawDiveData` returning a minimal `ParsedDive`; they verify the mapper projects samples correctly into the payload.

- [ ] **Step 1: Add two new tests to the existing test file**

Append to `test/features/universal_import/data/services/macdive_dive_mapper_test.dart` (exact code; adapt imports if the existing file uses different aliases):

```dart
import 'dart:typed_data';
import 'package:libdivecomputer_plugin/src/generated/dive_computer_api.g.dart' as pigeon;

// ... existing imports

group('MacDiveDiveMapper.profile from ZRAWDATA', () {
  test('populates profile when ZRAWDATA decode succeeds', () async {
    // A minimal ParsedDive the stub will return.
    final parsed = pigeon.ParsedDive(
      fingerprint: 'test',
      dateTimeYear: 2026, dateTimeMonth: 3, dateTimeDay: 11,
      dateTimeHour: 10, dateTimeMinute: 0, dateTimeSecond: 0,
      maxDepthMeters: 10.0, avgDepthMeters: 6.0, durationSeconds: 600,
      samples: [
        pigeon.ProfileSample(timeSeconds: 0,  depthMeters: 0.0,  temperatureCelsius: 25.0),
        pigeon.ProfileSample(timeSeconds: 10, depthMeters: 5.0,  temperatureCelsius: 24.5),
        pigeon.ProfileSample(timeSeconds: 20, depthMeters: 10.0, temperatureCelsius: 24.0),
      ],
      tanks: const [], gasMixes: const [], events: const [],
    );

    final rawDive = _macDiveRawDiveFixture(
      uuid: 'dive-1',
      computerName: 'Shearwater Teric',
      rawDataBlob: Uint8List.fromList(List.filled(32, 0x41)),  // stub bytes; parser is mocked
    );

    final mapper = MacDiveDiveMapper(
      parseRawDiveData: (vendor, product, model, bytes) async => parsed,
    );

    final logbook = _logbookWith([rawDive]);
    final payload = await mapper.toPayload(logbook);
    final dive = payload.entities[ImportEntityType.dives]!.first;

    final profile = dive['profile'] as List<Map<String, dynamic>>;
    expect(profile, hasLength(3));
    expect(profile[0]['timestamp'], 0);
    expect(profile[0]['depth'], 0.0);
    expect(profile[0]['temperature'], 25.0);
    expect(profile[2]['timestamp'], 20);
    expect(profile[2]['depth'], 10.0);
  });

  test('emits sampleDecodeFailed warning and profile:[] when decode throws', () async {
    final rawDive = _macDiveRawDiveFixture(
      uuid: 'dive-2',
      computerName: 'Shearwater Teric',
      rawDataBlob: Uint8List.fromList(List.filled(32, 0x42)),
    );

    final mapper = MacDiveDiveMapper(
      parseRawDiveData: (vendor, product, model, bytes) async =>
          throw pigeon.PigeonError(code: 'PARSE_ERROR', message: 'corrupt', details: null),
    );

    final payload = await mapper.toPayload(_logbookWith([rawDive]));
    final dive = payload.entities[ImportEntityType.dives]!.first;

    expect(dive['profile'], isEmpty);
    expect(payload.warnings.any((w) => w.toString().contains('dive-2')), isTrue);
  });

  test('returns profile:[] for dives with null ZRAWDATA (no warning)', () async {
    final rawDive = _macDiveRawDiveFixture(
      uuid: 'dive-3', computerName: 'Manual', rawDataBlob: null,
    );

    final mapper = MacDiveDiveMapper(
      parseRawDiveData: (vendor, product, model, bytes) async =>
          throw StateError('should not be called'),
    );

    final payload = await mapper.toPayload(_logbookWith([rawDive]));
    final dive = payload.entities[ImportEntityType.dives]!.first;

    expect(dive['profile'], isEmpty);
    expect(payload.warnings, isEmpty);
  });
});

// Helper: adjust to match the actual `MacDiveRawDive` constructor signature that
// landed in PR #256. Look at `macdive_raw_types.dart` to see required fields.
MacDiveRawDive _macDiveRawDiveFixture({
  required String uuid,
  required String? computerName,
  required Uint8List? rawDataBlob,
}) {
  // Fill in the remaining required fields with reasonable defaults. Use the
  // existing synthetic-DB builder helpers if one exists (check test/fixtures/macdive_sqlite/).
  throw UnimplementedError('Fill from macdive_raw_types.dart signature');
}

MacDiveRawLogbook _logbookWith(List<MacDiveRawDive> dives) {
  // Fill from macdive_raw_types.dart. Other fields likely default to empty maps/lists.
  throw UnimplementedError();
}
```

Note on the helper stubs: fill them in by reading `macdive_raw_types.dart` during this step. The point is for the test to compile — this is why Step 1 of Task 1 said "verify baseline tests pass" and read the raw types file. Use whatever defaults make the existing tests compile.

- [ ] **Step 2: Run the new tests and confirm they fail**

```bash
flutter test test/features/universal_import/data/services/macdive_dive_mapper_test.dart --plain-name "ZRAWDATA"
```

Expected: FAIL. The current `MacDiveDiveMapper` ignores `rawDataBlob` and always emits `profile: const []`. The three tests should specifically fail on:
- Test 1: `expect(profile, hasLength(3))` → gets `0` because current code emits `[]`.
- Test 2: `expect(payload.warnings.any(...))` → empty warnings list.
- Test 3: should already pass (null blob path is current behavior) — note it as "accidentally passing today," do NOT mark green.

- [ ] **Step 3: Commit (red-phase commit)**

```bash
git add test/features/universal_import/data/services/macdive_dive_mapper_test.dart
git commit -m "test(macdive): failing tests for ZRAWDATA profile decode (red phase)"
```

---

## Task 3: `MacDiveDiveMapper` decodes `ZRAWDATA` and projects samples

**Files:**
- Modify: `lib/features/universal_import/data/services/macdive_dive_mapper.dart`

This is the core implementation task. Follows the exact pattern of `ShearwaterDiveMapper._parseWithFfi` + `mergeWithParsedDive`.

- [ ] **Step 1: Add a `parseRawDiveData` constructor parameter for testability**

Adapt the existing `MacDiveDiveMapper` constructor:

```dart
typedef ParseRawDiveDataFn = Future<pigeon.ParsedDive> Function(
  String vendor, String product, int model, Uint8List data,
);

class MacDiveDiveMapper {
  MacDiveDiveMapper({ParseRawDiveDataFn? parseRawDiveData})
      : _parseRawDiveData = parseRawDiveData ?? _defaultParse;

  final ParseRawDiveDataFn _parseRawDiveData;

  static Future<pigeon.ParsedDive> _defaultParse(
    String vendor, String product, int model, Uint8List data,
  ) => pigeon.DiveComputerHostApi().parseRawDiveData(vendor, product, model, data);

  // ... existing members
}
```

Import at the top of the file:
```dart
import 'dart:typed_data';
import 'package:libdivecomputer_plugin/src/generated/dive_computer_api.g.dart' as pigeon;
```

- [ ] **Step 2: Add a helper that maps `ZCOMPUTER` strings to libdivecomputer (vendor, product)**

Near the bottom of the file:

```dart
/// Maps MacDive's ZCOMPUTER string to the (vendor, product) pair
/// libdivecomputer expects. Returns null for computers not supported by the
/// plugin; callers should emit a warning and skip decoding.
(String vendor, String product)? _vendorProductFromZComputer(String? zComputer) {
  if (zComputer == null) return null;
  switch (zComputer) {
    case 'Shearwater Teric':   return ('Shearwater', 'Teric');
    case 'Shearwater Tern':    return ('Shearwater', 'Tern');
    case 'Shearwater Petrel':  return ('Shearwater', 'Petrel');
    case 'Shearwater Perdix':  return ('Shearwater', 'Perdix');
    case 'Shearwater Nerd':    return ('Shearwater', 'Nerd');
    // Extend as other ZCOMPUTER values are observed in the sample data.
    default: return null;
  }
}
```

Rationale: libdivecomputer expects strings that match its internal device descriptor table. For Shearwater, the vendor is always `"Shearwater"` and the product is the model name without the vendor prefix. See `DiveComputerService.getDeviceDescriptors()` output in the plugin's test file for the exact spelling the plugin returns.

- [ ] **Step 3: Replace the `profile: const []` line with the decode+project block**

Locate the line identified in Task 1 Step 4 (grep output). Replace that single statement with:

```dart
final profile = <Map<String, dynamic>>[];
final vendorProduct = _vendorProductFromZComputer(dive.computerName);
final rawData = dive.rawDataBlob;

if (rawData != null && vendorProduct != null) {
  try {
    final parsed = await _parseRawDiveData(
      vendorProduct.$1, vendorProduct.$2, 0, rawData,
    );
    for (final s in parsed.samples) {
      final point = <String, dynamic>{'timestamp': s.timeSeconds};
      if (s.depthMeters != 0 || s.timeSeconds == 0) {
        point['depth'] = s.depthMeters;  // always emit depth; 0.0 is valid
      } else {
        point['depth'] = s.depthMeters;
      }
      if (s.temperatureCelsius != null) point['temperature'] = s.temperatureCelsius;
      if (s.pressureBar != null) point['pressure'] = s.pressureBar;
      if (s.ppo2 != null) point['ppO2'] = s.ppo2;
      if (s.decoTime != null) point['ndl'] = s.decoTime;
      if (s.heartRate != null) point['heartRate'] = s.heartRate;
      if (s.setpoint != null) point['setpoint'] = s.setpoint;
      if (s.cns != null) point['cns'] = s.cns;
      if (s.rbt != null) point['rbt'] = s.rbt;
      if (s.decoType != null) point['decoType'] = s.decoType;
      if (s.tts != null) point['tts'] = s.tts;
      if (s.decoDepth != null) point['ceiling'] = s.decoDepth;
      profile.add(point);
    }
  } catch (e) {
    warnings.add(ImportWarning.sampleDecodeFailed(
      diveUuid: dive.uuid,
      reason: e.toString(),
    ));
  }
}

map['profile'] = profile;
```

Simplify the depth emission to just `point['depth'] = s.depthMeters;` — the conditional above was a thinko leftover. The clean version:

```dart
final profile = <Map<String, dynamic>>[];
final vendorProduct = _vendorProductFromZComputer(dive.computerName);
final rawData = dive.rawDataBlob;

if (rawData != null && vendorProduct != null) {
  try {
    final parsed = await _parseRawDiveData(
      vendorProduct.$1, vendorProduct.$2, 0, rawData,
    );
    for (final s in parsed.samples) {
      final point = <String, dynamic>{
        'timestamp': s.timeSeconds,
        'depth': s.depthMeters,
      };
      if (s.temperatureCelsius != null) point['temperature'] = s.temperatureCelsius;
      if (s.pressureBar != null)        point['pressure']    = s.pressureBar;
      if (s.ppo2 != null)               point['ppO2']        = s.ppo2;
      if (s.decoTime != null)           point['ndl']         = s.decoTime;
      if (s.heartRate != null)          point['heartRate']   = s.heartRate;
      if (s.setpoint != null)           point['setpoint']    = s.setpoint;
      if (s.cns != null)                point['cns']         = s.cns;
      if (s.rbt != null)                point['rbt']         = s.rbt;
      if (s.decoType != null)           point['decoType']    = s.decoType;
      if (s.tts != null)                point['tts']         = s.tts;
      if (s.decoDepth != null)          point['ceiling']     = s.decoDepth;
      profile.add(point);
    }
  } catch (e) {
    warnings.add(ImportWarning.sampleDecodeFailed(
      diveUuid: dive.uuid,
      reason: e.toString(),
    ));
  }
}

map['profile'] = profile;
```

- [ ] **Step 4: If `toPayload`'s method signature isn't `async`, make it `async`**

`parseRawDiveData` returns a `Future`. The mapper's `toPayload` method likely needs to become `async`. If this causes cascading signature changes (e.g. in `MacDiveSqliteParser.parse`), propagate them — they're all one-line edits. The parser is already `async` per `ImportParser` interface.

- [ ] **Step 5: Run the tests added in Task 2**

```bash
flutter test test/features/universal_import/data/services/macdive_dive_mapper_test.dart --plain-name "ZRAWDATA"
```

Expected: all three tests PASS.

- [ ] **Step 6: Run the full `MacDiveDiveMapper` test file to confirm no regressions**

```bash
flutter test test/features/universal_import/data/services/macdive_dive_mapper_test.dart
```

Expected: all tests PASS (pre-existing + 3 new).

- [ ] **Step 7: Run `flutter analyze` and `dart format`**

```bash
flutter analyze lib/features/universal_import/data/services/macdive_dive_mapper.dart
dart format lib/features/universal_import/data/services/macdive_dive_mapper.dart
```

Expected: no analyzer issues; formatter makes no changes (or auto-fixes whitespace only).

- [ ] **Step 8: Commit**

```bash
git add lib/features/universal_import/data/services/macdive_dive_mapper.dart \
        test/features/universal_import/data/services/macdive_dive_mapper_test.dart
git commit -m "feat(macdive): decode ZRAWDATA profiles via libdivecomputer_plugin"
```

---

## Task 4: Add `ImportWarning.sampleDecodeFailed` variant (if it doesn't already exist)

**Files:**
- Modify: the file identified in Task 1 Step 5 (wherever `class ImportWarning` lives).
- Test: add or extend a unit test asserting the variant constructs and renders.

Skip this entire task if Task 1 Step 5 found an existing compatible variant.

- [ ] **Step 1: Write a failing test for the new variant**

Add to the `ImportWarning` test file:

```dart
test('ImportWarning.sampleDecodeFailed carries diveUuid and reason', () {
  final w = ImportWarning.sampleDecodeFailed(
    diveUuid: 'abc-123',
    reason: 'corrupt header',
  );
  expect(w.toString(), contains('abc-123'));
  expect(w.toString(), contains('corrupt header'));
});
```

- [ ] **Step 2: Add the variant following existing `ImportWarning` patterns**

Consult the existing variants in the class. Add:

```dart
factory ImportWarning.sampleDecodeFailed({
  required String diveUuid,
  required String reason,
}) {
  return ImportWarning(
    type: ImportWarningType.sampleDecodeFailed,
    message: 'Profile decode failed for dive $diveUuid: $reason',
    diveUuid: diveUuid,
  );
}
```

If the `ImportWarning` class uses a sealed-class / sum-type pattern (rather than a single class with a `type` enum), match that pattern instead. Read surrounding variants before writing this one.

- [ ] **Step 3: Test passes.**

- [ ] **Step 4: Commit.**

```bash
git commit -am "feat(import): ImportWarning.sampleDecodeFailed variant"
```

---

## Task 5: Gated real-sample regression test

**Files:**
- Create: `test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart`

Mirrors the structure of `test/features/universal_import/data/parsers/macdive_xml_real_sample_test.dart` (see the existing file for the exact tag, environment-variable, and skip-reason conventions used by the codebase).

- [ ] **Step 1: Write the test file**

File contents:

```dart
@Tags(['real-data'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

void main() {
  const sqlitePath = String.fromEnvironment('MACDIVE_SQLITE_SAMPLE');
  const uddfPath = String.fromEnvironment('MACDIVE_UDDF_SAMPLE');

  test(
    'ZRAWDATA decode agrees with UDDF profile per-UUID for Shearwater dives',
    skip: sqlitePath.isEmpty ? 'Set --dart-define=MACDIVE_SQLITE_SAMPLE' : null,
    () async {
      final sqliteBytes = File(sqlitePath).readAsBytesSync();
      final uddfBytes = uddfPath.isEmpty
          ? null
          : File(uddfPath).readAsBytesSync();

      final sqlitePayload = await const MacDiveSqliteParser().parse(sqliteBytes);
      final sqliteDives = sqlitePayload.entities[ImportEntityType.dives] ?? const [];

      // Count coverage: Shearwater dives should all have non-empty profiles.
      int shearwaterDives = 0;
      int shearwaterDecoded = 0;
      for (final dive in sqliteDives) {
        final computer = (dive['computer'] as String?) ?? '';
        if (!computer.startsWith('Shearwater')) continue;
        shearwaterDives++;
        if ((dive['profile'] as List).isNotEmpty) shearwaterDecoded++;
      }
      expect(shearwaterDives, greaterThan(200), reason: 'sample DB has ~267 Shearwater dives');
      expect(shearwaterDecoded / shearwaterDives, greaterThan(0.95),
          reason: 'at least 95% of Shearwater dives should decode cleanly');

      // Cross-validate against UDDF per-UUID if UDDF path provided.
      if (uddfBytes != null) {
        final uddfPayload = await UddfImportParser().parse(uddfBytes);
        final uddfByUuid = <String, Map<String, dynamic>>{
          for (final d in (uddfPayload.entities[ImportEntityType.dives] ?? const []))
            (d['source_uuid'] as String? ?? d['id'] as String? ?? ''): d,
        };

        int compared = 0;
        int withinTolerance = 0;
        for (final sqliteDive in sqliteDives) {
          final uuid = sqliteDive['source_uuid'] as String?;
          if (uuid == null) continue;
          final uddfDive = uddfByUuid[uuid];
          if (uddfDive == null) continue;

          final sqliteProfile = (sqliteDive['profile'] as List?) ?? const [];
          final uddfProfile = (uddfDive['profile'] as List?) ?? const [];
          if (sqliteProfile.isEmpty || uddfProfile.isEmpty) continue;

          compared++;
          // Sample count should be within ±5% (libdivecomputer may decimate
          // or MacDive may have added manual samples to UDDF).
          final ratio = sqliteProfile.length / uddfProfile.length;
          if (ratio >= 0.95 && ratio <= 1.05) withinTolerance++;

          // First sample: timestamp should be 0, depth should match within 0.1m.
          final s0 = sqliteProfile.first as Map;
          final u0 = uddfProfile.first as Map;
          expect(s0['timestamp'], 0);
          expect(
            (s0['depth'] as num).toDouble() - (u0['depth'] as num).toDouble(),
            inInclusiveRange(-0.1, 0.1),
            reason: 'dive $uuid first-sample depth mismatch',
          );
        }

        expect(compared, greaterThan(200),
            reason: 'should compare against at least 200 UUID-matched dives');
        expect(withinTolerance / compared, greaterThan(0.90),
            reason: '≥90% of compared dives should have sample counts within 5%');
      }

      // Bounded warnings: <5% of the Shearwater-dive set.
      expect(sqlitePayload.warnings.length, lessThan(shearwaterDives ~/ 20));
    },
  );
}
```

- [ ] **Step 2: Run it locally**

```bash
flutter test \
  --dart-define=MACDIVE_SQLITE_SAMPLE=$(pwd)/scripts/sample_data/MacDive.sqlite \
  --dart-define=MACDIVE_UDDF_SAMPLE="$(pwd)/scripts/sample_data/Apr 4 no iPad sync.uddf" \
  --run-skipped --tags=real-data \
  test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart
```

Expected: test passes. Roughly 267 Shearwater dives decoded. ≥90% have profile sample counts within 5% of the UDDF counterpart. First-sample depth matches UDDF within 0.1m.

If the test fails: inspect the failure mode. Common causes and fixes:
- Vendor/product mapping is incomplete → add the missing `ZCOMPUTER` string to `_vendorProductFromZComputer` in Task 3's code.
- `libdivecomputer_plugin` isn't loaded in the test environment → tests that invoke the plugin require the native build; run via `flutter test` (which boots a Flutter engine), not `dart test`.
- UDDF file doesn't contain `source_uuid` in the same shape as SQLite — the cross-check would skip those dives rather than failing, so the `compared > 200` assertion catches this.

- [ ] **Step 3: Commit**

```bash
git add test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart
git commit -m "test(macdive): gated real-sample test cross-validates ZRAWDATA vs UDDF"
```

---

## Task 6: Open the PR

- [ ] **Step 1: Push branch**

```bash
git push -u origin feature/macdive-profile-zrawdata
```

(If `flutter analyze` pre-push hook fails with stale generated code, run `dart run build_runner build --delete-conflicting-outputs` and retry — same issue we hit in Phase 1.)

- [ ] **Step 2: Open PR against `main`**

```bash
gh pr create --base main \
  --title "MacDive: decode ZRAWDATA profiles via libdivecomputer" \
  --body "$(cat <<'EOF'
## Summary

Closes the profile-decoding gap from #256 (which landed metadata-only MacDive SQLite import) using the pivot documented in the Phase 1 spike (#260).

- Decodes `ZDIVE.ZRAWDATA` via the already-integrated `libdivecomputer_plugin.parseRawDiveData()` API.
- Produces full profile samples (depth, temp, tank pressure, ppO2, NDL, deco state) for **100% of Shearwater dives** in the sample DB (267/267).
- Dives without `ZRAWDATA` (older imports, non-Shearwater computers, manual entries) continue to import metadata-only with an `ImportWarning` flagging why.

## Why not `ZSAMPLES`

See `docs/import-formats/macdive-zsamples.md` (landed in #260) — MacDive's proprietary `ZSAMPLES` column is per-dive AES-encrypted and was ruled NO-GO in the Phase 1 spike. `ZRAWDATA` is the raw dive-computer sensor dump, which libdivecomputer already parses natively.

## Changes

- `MacDiveDiveMapper`: replace the hard-coded `profile: const []` with a ZRAWDATA decode + sample projection, following the `ShearwaterDiveMapper.mergeWithParsedDive` pattern already used for Shearwater Cloud import.
- `_vendorProductFromZComputer` helper: maps `ZCOMPUTER` strings (`Shearwater Teric`, `Shearwater Tern`, etc.) to the `(vendor, product)` pair `libdivecomputer` expects.
- `ImportWarning.sampleDecodeFailed`: new variant.
- Tests: three unit tests for the mapper (success, decode failure, null ZRAWDATA) + one gated real-sample regression test that cross-validates against UDDF per-UUID.

## Test plan

- [x] `flutter test test/features/universal_import/data/services/macdive_dive_mapper_test.dart` — unit tests pass.
- [x] `flutter analyze` — clean.
- [x] `dart format` — clean.
- [ ] Manual: import the sample MacDive SQLite via the wizard, open a Shearwater dive, confirm the depth-over-time chart renders.
- [ ] Gated real-sample test passes locally with the full 6.7MB sample DB + UDDF export.

Prior work: #256 (metadata import, merged) → #260 (Phase 1 spike, merged or open) → this PR.
EOF
)"
```

- [ ] **Step 3: Return the PR URL.**

---

## Self-Review Checklist

- [ ] Spec requirement "decode SQLite profiles into same payload shape as UDDF" → Task 3's projection builds the same map shape (`timestamp`, `depth`, `temperature`, `pressure`, `ppO2`, `ndl`, etc.) the UDDF path emits.
- [ ] Spec requirement "per-dive warnings on decode failure" → Task 3's catch block + Task 4's `ImportWarning.sampleDecodeFailed` variant.
- [ ] Spec requirement "unit tests + gated real-sample test" → Task 2 (3 unit tests) + Task 5 (real-sample test).
- [ ] Spec requirement "no domain model or Drift schema changes" → verified: `DiveProfilePoint` and `dive_profiles` table unchanged. `ProfileSample` from the plugin is consumed directly; the importer converts to the Drift companion elsewhere (existing path).
- [ ] Spec requirement "no new service, no new typed model (simpler than original skeleton plan)" → verified: `MacDiveSqliteSample` and `MacDiveSamplesDecoder` are NOT created. Plugin types + mapper change only.
- [ ] No scope creep: does not touch XML path, does not touch Oceanic / Suunto dives, does not modify the duplicate checker or import wizard UI.

## Notes for the executor

- **The mapping table in Task 3 Step 2 is the single biggest correctness risk.** If a `ZCOMPUTER` string in the sample data doesn't match any switch case, that dive's decoder returns null and the profile ends up empty with NO warning (because we only warn when we TRIED and failed). Before shipping, extend the switch to cover every distinct `ZCOMPUTER` value you see: `sqlite3 scripts/sample_data/MacDive.sqlite 'SELECT DISTINCT ZCOMPUTER FROM ZDIVE WHERE ZRAWDATA IS NOT NULL;'` and verify each one is either in the switch or known-unsupported-by-libdivecomputer.
- Non-Shearwater dive computers (Oceanic Matrix Master, etc.) have no `ZRAWDATA` in the sample DB, so mapping for them isn't needed for this plan. If a future user provides a DB with Oceanic ZRAWDATA, the mapper emits `profile: []` (no warning — because vendor/product lookup returns null); that's the correct behavior and matches the "best-effort" scope of this PR.
- The 83 "ZSAMPLES-only, no ZRAWDATA" dives (~15% of dives with any sample data) will continue to emit `profile: []`. This is documented, expected, and matches the Phase 1 spike's explicit non-goal. Users can export UDDF from MacDive for those specific dives if they need profiles.
- Mapper projection intentionally **duplicates** (does not share) the XML parser's projection logic. Two simple functions beat one shared abstraction across parsers that evolve independently.
- If `libdivecomputer_plugin` is missing a model the sample DB references (e.g. a very new Shearwater firmware not in the bundled `libdivecomputer` submodule), `parseRawDiveData` will throw a `PigeonError` with a vendor-specific code. That falls into the catch-and-warn path; no special handling needed.
