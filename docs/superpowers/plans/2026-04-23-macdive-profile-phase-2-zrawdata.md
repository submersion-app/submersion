# MacDive Profile Decoding — Phase 2 (ZRAWDATA via libdivecomputer) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce decoded profile samples for every Shearwater dive imported from a MacDive SQLite database, by decoding the `ZDIVE.ZRAWDATA` column via the already-integrated `libdivecomputer_plugin`. Dives without `ZRAWDATA` (older imports, non-Shearwater computers, manual entries) continue to import without a profile, with an `ImportWarning` flagging why.

**Architecture:** Follows the design spec's original shape (`MacDiveSamplesDecoder` + `MacDiveSqliteSample` under `lib/features/universal_import/data/services/`) but the decoder body is a thin adapter over `libdivecomputer_plugin` rather than a custom binary parser. The reader/mapper integration points are unchanged from the spec.

**Tech Stack:** Flutter, Dart 3, `libdivecomputer_plugin` (local package at `packages/libdivecomputer_plugin/`), Riverpod, `flutter_test`.

**Dependencies:**
- PR #256 (MacDive SQLite import, `feature/macdive-sqlite`) is **merged** to `main` as of 2026-04-23. All reader/mapper files this plan modifies already live on `main`.
- The Phase 1 spike PR (#260, `feature/macdive-zsamples-phase-1`) should merge before this work starts, so `docs/import-formats/macdive-zsamples.md` and the retained tooling are on `main`. Alternatively, this work can stack on top of `feature/macdive-zsamples-phase-1` — either target works.
- The `libdivecomputer` git submodule must be initialized in the worktree.

**Spec:** `docs/superpowers/specs/2026-04-23-macdive-sqlite-profile-decoding-design.md` (as updated with the Phase 1 outcome).

**Investigation foundation:** `docs/import-formats/macdive-zsamples.md` documents why `ZSAMPLES` decoding was deferred. This plan targets the alternative column with `libdivecomputer` support.

---

## Pre-work: libdivecomputer API exploration

Before implementation, verify the `libdivecomputer_plugin` exposes what this plan needs. This is a **controller-level investigation task** — inspect the plugin's public Dart API, not a subagent dispatch.

- [ ] **Discover the plugin's API surface**

Run:
```bash
find packages/libdivecomputer_plugin/lib -name "*.dart" | head
cat packages/libdivecomputer_plugin/lib/*.dart | head -200
```

Record:
- Is there a function that takes raw bytes + a vendor/model hint and returns parsed samples? Or does the plugin expect to own the download flow end-to-end (i.e. connect to a BLE device, not parse arbitrary bytes)?
- What's the sample-point data model? Does it match `DiveProfilePoint` fields (timestamp, depth, temperature, ppO2, ndl, etc.)?
- Does the plugin need `family` (e.g. Shearwater Petrel) and `model` (e.g. Teric) parameters, or does it auto-detect from the bytes?

**Exit criterion:** If the plugin does NOT expose a bytes-in / samples-out entry point, this plan is blocked; add a Task 0 to contribute such an entry point to the plugin (or open an upstream issue). Report and stop before proceeding.

If the API is workable, the rest of this plan applies.

---

## File Structure

| File | Role | New / Modified |
|---|---|---|
| `lib/features/universal_import/data/services/macdive_samples/macdive_sqlite_sample.dart` | `MacDiveSqliteSample` typed model (fields match `MacDiveXmlSample`). | Created |
| `lib/features/universal_import/data/services/macdive_samples/macdive_samples_decoder.dart` | Public `MacDiveSamplesDecoder` with `decode(blob, units, converter)`. Delegates to libdivecomputer. | Created |
| `lib/features/universal_import/data/services/macdive_raw_types.dart` | Add `samples: List<MacDiveSqliteSample>` field to `MacDiveRawDive` (default empty). | Modified |
| `lib/features/universal_import/data/services/macdive_db_reader.dart` | Call the decoder on each dive's `ZRAWDATA`. Record per-dive warnings on decode failure. | Modified |
| `lib/features/universal_import/data/services/macdive_dive_mapper.dart` | Replace the `profile: const []` line (~334) with a projection of `dive.samples` into payload maps. | Modified |
| `lib/features/universal_import/data/models/import_warning.dart` (or wherever the sum type lives) | Add `ImportWarning.sampleDecodeFailed` variant. | Modified |
| `test/features/universal_import/data/services/macdive_samples_decoder_test.dart` | Unit tests against committed golden ZRAWDATA fixtures. | Created |
| `test/fixtures/macdive_sqlite/zrawdata_golden/` | Small (≤1KB) redacted ZRAWDATA fixtures, one per observed Shearwater variant. | Created |
| `test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart` | Gated real-sample test: decode every dive's ZRAWDATA, cross-check against UDDF profile by UUID. | Created |

---

## Task 1: Worktree setup

**Files:** No files created.

- [ ] **Step 1: Create the Phase 2 worktree**

After the Phase 1 PR (#260) merges to `main`, base off `main`:
```bash
git fetch origin
git worktree add -b feature/macdive-profile-zrawdata \
  .worktrees/macdive-profile-zrawdata \
  origin/main
```

If Phase 1 PR is still open and you want to stack (and later rebase once #260 merges), base off its branch instead:
```bash
git worktree add -b feature/macdive-profile-zrawdata \
  .worktrees/macdive-profile-zrawdata \
  origin/feature/macdive-zsamples-phase-1
```

- [ ] **Step 2: Initialize submodules (libdivecomputer is required) and pub deps**

```bash
cd .worktrees/macdive-profile-zrawdata
git submodule update --init --recursive
flutter pub get
```

- [ ] **Step 3: Symlink sample data (per Phase 1 setup pattern)**

```bash
ln -s $(pwd)/../../scripts/sample_data scripts/sample_data
```

- [ ] **Step 4: No commit**

---

## Task 2: `MacDiveSqliteSample` typed model

**Files:**
- Create: `lib/features/universal_import/data/services/macdive_samples/macdive_sqlite_sample.dart`
- Test: `test/features/universal_import/data/services/macdive_sqlite_sample_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/macdive_samples/macdive_sqlite_sample.dart';

void main() {
  test('MacDiveSqliteSample stores SI units', () {
    final sample = MacDiveSqliteSample(
      time: const Duration(seconds: 30),
      depthMeters: 10.5,
      temperatureCelsius: 24.0,
      pressureBar: 180.0,
      ppO2: 1.4,
      ndlSeconds: 1200,
    );
    expect(sample.time.inSeconds, 30);
    expect(sample.depthMeters, 10.5);
  });

  test('fields are nullable except time', () {
    final sample = MacDiveSqliteSample(time: Duration.zero);
    expect(sample.depthMeters, isNull);
    expect(sample.temperatureCelsius, isNull);
  });
}
```

- [ ] **Step 2: Run the test — ModuleNotFoundError**

```bash
flutter test test/features/universal_import/data/services/macdive_sqlite_sample_test.dart
```

- [ ] **Step 3: Implement the model**

```dart
/// One sample from a MacDive SQLite dive profile, in SI canonical units.
///
/// Shape intentionally matches `MacDiveXmlSample` so downstream payload
/// projection logic does not branch on source format.
class MacDiveSqliteSample {
  const MacDiveSqliteSample({
    required this.time,
    this.depthMeters,
    this.pressureBar,
    this.temperatureCelsius,
    this.ppO2,
    this.ndlSeconds,
  });

  final Duration time;
  final double? depthMeters;
  final double? pressureBar;
  final double? temperatureCelsius;
  final double? ppO2;
  final int? ndlSeconds;
}
```

- [ ] **Step 4: Test passes.**

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/services/macdive_samples/macdive_sqlite_sample.dart \
        test/features/universal_import/data/services/macdive_sqlite_sample_test.dart
git commit -m "feat(macdive): MacDiveSqliteSample typed model"
```

---

## Task 3: Decoder — delegates to libdivecomputer_plugin

**Files:**
- Create: `lib/features/universal_import/data/services/macdive_samples/macdive_samples_decoder.dart`
- Test: `test/features/universal_import/data/services/macdive_samples_decoder_test.dart`
- Test fixtures: `test/fixtures/macdive_sqlite/zrawdata_golden/*.bin` (added as they become available — see Step 1 guidance)

The exact implementation depends on the libdivecomputer_plugin API surface discovered in Pre-work. Two expected shapes:

**Shape A — Plugin exposes `parseBytes(Uint8List, {required vendor, required model})`.** The decoder looks up vendor/model from `ZDIVE.ZCOMPUTER` (e.g. "Shearwater Teric" → `Vendor.shearwater, Model.teric`), calls the plugin, maps the plugin's sample type to `MacDiveSqliteSample`.

**Shape B — Plugin requires a device/download flow.** Not workable for offline file import. The pre-work exit criterion covers this case.

- [ ] **Step 1: Create at least one golden fixture**

Extract a small `ZRAWDATA` blob from the sample SQLite:
```bash
sqlite3 scripts/sample_data/MacDive.sqlite \
  "SELECT writefile('test/fixtures/macdive_sqlite/zrawdata_golden/shearwater_teric_short.bin', ZRAWDATA) FROM ZDIVE WHERE ZRAWDATA IS NOT NULL AND LENGTH(ZRAWDATA) < 10000 ORDER BY LENGTH(ZRAWDATA) ASC LIMIT 1"
```

Redact any serial numbers or user-identifying bytes (if present — inspect with `xxd`) before committing. Target fixture size < 10KB.

- [ ] **Step 2: Write failing decoder test using the fixture**

```dart
test('decode produces MacDiveSqliteSample sequence for Teric fixture', () {
  final bytes = File('test/fixtures/macdive_sqlite/zrawdata_golden/shearwater_teric_short.bin').readAsBytesSync();
  final decoder = const MacDiveSamplesDecoder();
  final samples = decoder.decode(
    bytes,
    computerName: 'Shearwater Teric',
    units: MacDiveUnitSystem.metric,
    converter: MacDiveUnitConverter(...),
  );
  expect(samples, isNotEmpty);
  expect(samples.first.time.inSeconds, 0);
  expect(samples.first.depthMeters, greaterThanOrEqualTo(0));
  // Sample times are monotonic.
  for (int i = 1; i < samples.length; i++) {
    expect(samples[i].time >= samples[i - 1].time, isTrue);
  }
});
```

- [ ] **Step 3: Implement the decoder**

Exact API depends on Pre-work findings. Skeleton:

```dart
import 'dart:typed_data';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart';
import 'macdive_sqlite_sample.dart';

class MacDiveSamplesDecoder {
  const MacDiveSamplesDecoder({this.plugin});

  final LibdivecomputerPlugin? plugin;

  List<MacDiveSqliteSample> decode(
    Uint8List blob, {
    required String? computerName,
    required MacDiveUnitSystem units,
    required MacDiveUnitConverter converter,
  }) {
    final (vendor, model) = _identifyVendorAndModel(computerName);
    final result = (plugin ?? LibdivecomputerPlugin.instance)
        .parseBytes(blob, vendor: vendor, model: model);
    return result.samples.map(_toSqliteSample).toList();
  }

  MacDiveSqliteSample _toSqliteSample(DiveComputerSample s) =>
      MacDiveSqliteSample(
        time: Duration(seconds: s.timeSeconds),
        depthMeters: s.depthMeters,
        temperatureCelsius: s.temperatureCelsius,
        pressureBar: s.pressureBar,
        ppO2: s.ppO2Bar,
        ndlSeconds: s.ndlSeconds,
      );

  (Vendor, Model) _identifyVendorAndModel(String? computerName) {
    switch (computerName) {
      case 'Shearwater Teric': return (Vendor.shearwater, Model.teric);
      case 'Shearwater Tern':  return (Vendor.shearwater, Model.tern);
      // Extend as the real plugin's enum reveals.
      default:
        throw MacDiveSamplesDecodeError('Unknown computer: $computerName');
    }
  }
}

class MacDiveSamplesDecodeError implements Exception {
  const MacDiveSamplesDecodeError(this.reason);
  final String reason;
  @override
  String toString() => 'MacDiveSamplesDecodeError($reason)';
}
```

- [ ] **Step 4: Test passes.**

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/services/macdive_samples/macdive_samples_decoder.dart \
        test/features/universal_import/data/services/macdive_samples_decoder_test.dart \
        test/fixtures/macdive_sqlite/zrawdata_golden/
git commit -m "feat(macdive): MacDiveSamplesDecoder via libdivecomputer_plugin"
```

---

## Task 4: Wire decoder into `MacDiveDbReader`

**Files:**
- Modify: `lib/features/universal_import/data/services/macdive_raw_types.dart`
- Modify: `lib/features/universal_import/data/services/macdive_db_reader.dart`
- Test: update `test/features/universal_import/data/services/macdive_db_reader_test.dart`

- [ ] **Step 1: Add `samples` field to `MacDiveRawDive`**

```dart
class MacDiveRawDive {
  // ... existing fields
  final List<MacDiveSqliteSample> samples;
  MacDiveRawDive({
    // ... existing,
    this.samples = const [],
  });
}
```

- [ ] **Step 2: Write failing test — reader populates `samples` from ZRAWDATA**

Extend the synthetic-DB test: build a dive row with a known ZRAWDATA blob (use a committed fixture), instantiate reader with the decoder stubbed to return `[MacDiveSqliteSample(time: Duration.zero)]`, assert `logbook.dives.first.samples.length == 1`.

- [ ] **Step 3: Call decoder in reader's per-dive loop**

```dart
// In MacDiveDbReader, per-dive processing:
List<MacDiveSqliteSample> samples = const [];
if (row.rawDataBlob != null) {
  try {
    samples = decoder.decode(
      row.rawDataBlob!,
      computerName: row.computerName,
      units: unitsPreference,
      converter: converter,
    );
  } on MacDiveSamplesDecodeError catch (e) {
    warnings.add(ImportWarning.sampleDecodeFailed(
      diveUuid: row.uuid,
      reason: e.reason,
    ));
  }
}
dive = dive.copyWith(samples: samples);
```

- [ ] **Step 4: Test passes.**

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/services/macdive_raw_types.dart \
        lib/features/universal_import/data/services/macdive_db_reader.dart \
        test/features/universal_import/data/services/macdive_db_reader_test.dart
git commit -m "feat(macdive): reader decodes ZRAWDATA to MacDiveSqliteSample list"
```

---

## Task 5: Mapper projects samples into ImportPayload

**Files:**
- Modify: `lib/features/universal_import/data/services/macdive_dive_mapper.dart`
- Test: update `test/features/universal_import/data/services/macdive_dive_mapper_test.dart`

- [ ] **Step 1: Write failing test** — mapper emits non-empty `profile` for a dive with decoded samples.

- [ ] **Step 2: Replace `profile: const []` at the hard-coded line (~334) with the projection**

```dart
// In MacDiveDiveMapper._buildDiveMap:
final profile = <Map<String, dynamic>>[];
for (final s in dive.samples) {
  final point = <String, dynamic>{'timestamp': s.time.inSeconds};
  if (s.depthMeters != null) point['depth'] = s.depthMeters;
  if (s.pressureBar != null) point['pressure'] = s.pressureBar;
  if (s.temperatureCelsius != null) point['temperature'] = s.temperatureCelsius;
  if (s.ppO2 != null) point['ppO2'] = s.ppO2;
  if (s.ndlSeconds != null) point['ndl'] = s.ndlSeconds;
  profile.add(point);
}
map['profile'] = profile;
```

- [ ] **Step 3: Test passes.**

- [ ] **Step 4: Commit**

```bash
git add lib/features/universal_import/data/services/macdive_dive_mapper.dart \
        test/features/universal_import/data/services/macdive_dive_mapper_test.dart
git commit -m "feat(macdive): mapper projects decoded samples into ImportPayload profile"
```

---

## Task 6: Add `ImportWarning.sampleDecodeFailed` variant

**Files:**
- Modify: whatever file holds the `ImportWarning` sum type (locate via `grep -r 'class ImportWarning' lib/`).
- Test: add a single test that constructs and renders the new variant.

- [ ] **Step 1: Write failing test.**
- [ ] **Step 2: Add the variant.**
- [ ] **Step 3: Test passes.**
- [ ] **Step 4: Commit.**

```bash
git commit -m "feat(import): ImportWarning.sampleDecodeFailed variant"
```

---

## Task 7: Gated real-sample regression test

**Files:**
- Create: `test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart`

Mirrors the existing `macdive_xml_real_sample_test.dart` pattern.

- [ ] **Step 1: Write the test, skipped by default**

```dart
@Tags(['real-data'])
library;

import 'package:flutter_test/flutter_test.dart';
// ... imports

void main() {
  const sqlitePath = String.fromEnvironment('MACDIVE_SQLITE_SAMPLE');
  const uddfPath = String.fromEnvironment('MACDIVE_UDDF_SAMPLE');

  test(
    'ZRAWDATA decode agrees with UDDF profile per-UUID',
    skip: sqlitePath.isEmpty ? 'Set --dart-define=MACDIVE_SQLITE_SAMPLE' : false,
    () async {
      final sqliteBytes = File(sqlitePath).readAsBytesSync();
      final uddfBytes = File(uddfPath).readAsBytesSync();
      // Parse both.
      final sqliteProfiles = await MacDiveSqliteParser().parse(sqliteBytes);
      final uddfProfiles = await UddfImportParser().parse(uddfBytes);

      // Cross-check: for every dive UUID present in both, samples align within tolerance.
      int checked = 0;
      int warnings = 0;
      for (final sqliteDive in sqliteProfiles.entities[ImportEntityType.dives] ?? []) {
        final uuid = sqliteDive['source_uuid'];
        final uddfDive = uddfProfiles.entities[ImportEntityType.dives]?.firstWhereOrNull((d) => d['source_uuid'] == uuid);
        if (uddfDive == null) continue;
        final sqliteProfile = sqliteDive['profile'] as List? ?? [];
        final uddfProfile = uddfDive['profile'] as List? ?? [];
        if (sqliteProfile.isEmpty && uddfProfile.isEmpty) continue;
        if (sqliteProfile.isEmpty) {
          warnings++;
          continue;
        }
        // Both present. Compare.
        expect(sqliteProfile.length, greaterThanOrEqualTo((uddfProfile.length * 0.95).floor()));
        // Spot-check first sample.
        expect((sqliteProfile[0]['timestamp'] as int), 0);
        expect((sqliteProfile[0]['depth'] as double), closeTo(uddfProfile[0]['depth'] as double, 0.1));
        checked++;
      }
      expect(checked, greaterThan(200));  // should cover most Shearwater dives
      // Bounded warnings: <5% of checked dives should emit a decode failure.
      expect(warnings, lessThan(checked ~/ 20));
    },
  );
}
```

- [ ] **Step 2: Run locally**

```bash
flutter test \
  --dart-define=MACDIVE_SQLITE_SAMPLE=/path/to/sample.sqlite \
  --dart-define=MACDIVE_UDDF_SAMPLE=/path/to/sample.uddf \
  --run-skipped --tags=real-data \
  test/features/universal_import/data/parsers/macdive_sqlite_real_sample_test.dart
```

Expected: passes with ~267 dives checked, warnings < 14.

- [ ] **Step 3: Commit.**

```bash
git commit -m "test(macdive): gated real-sample test cross-validates ZRAWDATA vs UDDF profiles"
```

---

## Task 8: Open the PR

- [ ] **Step 1: Push branch**

```bash
git push -u origin feature/macdive-profile-zrawdata
```

- [ ] **Step 2: Open PR**

If Phase 1 PR (#260) has merged: target `main`.
If Phase 1 PR is still open and you want to stack: target `feature/macdive-zsamples-phase-1`.

```bash
gh pr create --base main \
  --title "MacDive profile decoding (Phase 2: ZRAWDATA via libdivecomputer)" \
  --body "$(cat <<'EOF'
## Summary

Closes the ZSAMPLES profile gap from PR #256 via the pivot documented
in the Phase 1 spike (see `docs/import-formats/macdive-zsamples.md`).
Decodes `ZDIVE.ZRAWDATA` through the already-integrated
`libdivecomputer_plugin` for 100% of Shearwater dives in the sample DB
(267/267).

## Changes

- New `MacDiveSqliteSample` typed model (mirrors `MacDiveXmlSample`).
- New `MacDiveSamplesDecoder` wrapping `libdivecomputer_plugin`.
- Reader decodes `ZRAWDATA` per-dive; failures become `ImportWarning`.
- Mapper projects decoded samples into the `ImportPayload` `profile` key.
- Gated real-sample test cross-validates against user's UDDF export.

## Test plan

- [ ] `flutter test` — unit tests pass.
- [ ] `flutter analyze` — clean.
- [ ] `dart format` — clean.
- [ ] Manual: import the sample SQLite; open a Shearwater dive;
      confirm the depth-over-time chart renders.
- [ ] Gated real-sample test passes locally with the user's 6.7MB DB.

Prior work: #256 (metadata import, merged) → #260 (Phase 1 spike, open) → this PR.
EOF
)"
```

- [ ] **Step 3: Return the PR URL.**

---

## Self-Review Checklist

- [ ] Spec requirement "decode SQLite profiles into same payload shape as UDDF" → Tasks 2–5.
- [ ] Spec requirement "per-dive warnings on decode failure" → Tasks 4 + 6.
- [ ] Spec requirement "unit tests + golden fixtures + gated real-sample test" → Tasks 2, 3, 7.
- [ ] Spec requirement "no domain model or Drift schema changes" → verified: `DiveProfilePoint` and `dive_profiles` table unchanged.
- [ ] No scope creep: does not touch XML path, does not touch Oceanic dives (outside current scope), does not modify duplicate checker or import wizard UI.
- [ ] Pre-work note at top of plan will surface libdivecomputer API gaps before code is written.

## Notes for the executor

- If the `libdivecomputer_plugin` API requires a full device-download flow and does NOT expose a bytes-in / samples-out entry point, STOP at Pre-work. Report the gap; that's a new, larger plan (contribute the entry point upstream) that needs its own brainstorming cycle.
- The 83 "ZSAMPLES-only, no ZRAWDATA" dives (~15% of dives with any sample data) will continue to emit `profile: []`. That's acceptable for this milestone; users can export those via MacDive UDDF if they need profile data.
- Mapper projection intentionally duplicates (not shares) the XML parser's 10-line projection logic. Two simple functions beat one shared abstraction across parsers that evolve independently.
