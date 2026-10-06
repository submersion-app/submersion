# Multilevel-Correct Bottom Time Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the square-profile 85%-of-max-depth bottom time heuristic with a multilevel-correct algorithm (surface departure to start of final ascent) and backfill machine-derived stored values.

**Architecture:** One pure calculator in the dive_log domain layer; the `Dive` entity and the dive computer repository delegate to it. A v146 migration recomputes stored bottom times, using the frozen old 85% heuristic as a fingerprint to distinguish machine-derived values (replaced) from user-typed values (untouched). Both migration algorithms are frozen private copies inside `database.dart` so every device computes identical values regardless of which app version it migrates with (`hlc` untouched, LWW converges without sync traffic).

**Tech Stack:** Flutter/Dart, Drift ORM (raw `customSelect`/`customStatement` in migrations), flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-09-bottom-time-multilevel-design.md`

## Global Constraints

- Schema version: this branch claims **v146**. v145 is reserved by the GPS track mapping branch (PR #908) — do NOT use 145. Before merging to main, re-grep `currentSchemaVersion = ` on current origin/main and renumber above it if main has moved.
- All Dart code must pass `dart format` with no changes (run `dart format lib/ test/` before each commit).
- `flutter analyze` must be clean (infos are fatal in CI).
- No emojis anywhere. No commented-out code.
- Commit after each task. Do NOT add a Co-Authored-By line or session URL to commit messages.
- Run tests per-file (`flutter test <path>`), not the full suite, until the final verification task.
- Depths are meters internally; profile timestamps are seconds from dive start (`int`).

---

### Task 1: BottomTimeCalculator with unit tests

**Files:**
- Create: `lib/features/dive_log/domain/services/bottom_time_calculator.dart`
- Test: `test/features/dive_log/domain/services/bottom_time_calculator_test.dart`

**Interfaces:**
- Consumes: nothing (pure function, no imports beyond core Dart).
- Produces: `BottomTimeCalculator.secondsFromSamples(List<({int timestamp, double depth})> samples, {double absoluteFloorMeters = 6.0, double maxDepthFraction = 0.33, double thresholdCapFraction = 0.85}) -> int?` and the three `static const double` defaults `defaultAbsoluteFloorMeters` / `defaultMaxDepthFraction` / `defaultThresholdCapFraction`. Tasks 2 and 3 call `secondsFromSamples` with only the positional argument.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/services/bottom_time_calculator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';

void main() {
  // Reported bug scenario: 60 min dive, ~10 min at 95 ft (29 m) then a
  // 40 min multilevel tail at 50 ft (15.2 m), safety stop, surface.
  // Threshold = min(max(6, 0.33*29=9.57), 0.85*29=24.65) = 9.57 m.
  // Last sample >= 9.57 m is t=3060 (15.2 m), so bottom time = 3060 s.
  // The old 85% heuristic returned 540 s for this profile.
  const multilevel = [
    (timestamp: 0, depth: 0.0),
    (timestamp: 60, depth: 29.0),
    (timestamp: 600, depth: 29.0),
    (timestamp: 660, depth: 15.2),
    (timestamp: 3060, depth: 15.2),
    (timestamp: 3120, depth: 5.0),
    (timestamp: 3300, depth: 5.0),
    (timestamp: 3600, depth: 0.0),
  ];

  group('BottomTimeCalculator.secondsFromSamples', () {
    test('multilevel dive counts the shallow tail as bottom time', () {
      expect(BottomTimeCalculator.secondsFromSamples(multilevel), 3060);
    });

    test('square profile measures surface departure to ascent start', () {
      // Threshold = min(max(6, 9.9), 25.5) = 9.9 m; last sample >= 9.9 m
      // is t=1200. Includes the descent (starts at t=0), so 1200 s -- the
      // old heuristic gave 1140 s (descent excluded).
      const square = [
        (timestamp: 0, depth: 0.0),
        (timestamp: 60, depth: 30.0),
        (timestamp: 120, depth: 30.0),
        (timestamp: 1200, depth: 30.0),
        (timestamp: 1260, depth: 5.0),
        (timestamp: 1320, depth: 0.0),
      ];
      expect(BottomTimeCalculator.secondsFromSamples(square), 1200);
    });

    test('safety stop at 5 m is excluded via the 6 m absolute floor', () {
      // 18 m dive: threshold = min(max(6, 5.94), 15.3) = 6 m. The 5 m
      // safety stop (t=1860..2160) is below it; bottom ends at t=1800.
      const withStop = [
        (timestamp: 0, depth: 0.0),
        (timestamp: 60, depth: 18.0),
        (timestamp: 1800, depth: 18.0),
        (timestamp: 1860, depth: 5.0),
        (timestamp: 2160, depth: 5.0),
        (timestamp: 2220, depth: 0.0),
      ];
      expect(BottomTimeCalculator.secondsFromSamples(withStop), 1800);
    });

    test('dive shallower than the floor still gets a result (0.85 cap)', () {
      // 4 m dive: max(6, 1.32) = 6 exceeds max depth, so the cap kicks in:
      // threshold = 0.85 * 4 = 3.4 m. Last sample >= 3.4 m is t=600.
      const shallow = [
        (timestamp: 0, depth: 0.0),
        (timestamp: 30, depth: 4.0),
        (timestamp: 600, depth: 4.0),
        (timestamp: 630, depth: 2.0),
        (timestamp: 660, depth: 0.0),
      ];
      expect(BottomTimeCalculator.secondsFromSamples(shallow), 600);
    });

    test('deep stop beyond a third of max depth counts as bottom (known '
        'trade-off, documented in the spec)', () {
      // 45 m dive: threshold = min(max(6, 14.85), 38.25) = 14.85 m. The
      // 21 m deep stop (t=1260..1440) sits above it and is counted; the
      // 6 m stop is not (6 < 14.85). Bottom ends at t=1440.
      const deco = [
        (timestamp: 0, depth: 0.0),
        (timestamp: 120, depth: 45.0),
        (timestamp: 1200, depth: 45.0),
        (timestamp: 1260, depth: 21.0),
        (timestamp: 1440, depth: 21.0),
        (timestamp: 1500, depth: 6.0),
        (timestamp: 1800, depth: 6.0),
        (timestamp: 1860, depth: 0.0),
      ];
      expect(BottomTimeCalculator.secondsFromSamples(deco), 1440);
    });

    test('unsorted input is sorted internally', () {
      final shuffled = [
        multilevel[4],
        multilevel[0],
        multilevel[6],
        multilevel[2],
        multilevel[1],
        multilevel[7],
        multilevel[3],
        multilevel[5],
      ];
      expect(BottomTimeCalculator.secondsFromSamples(shuffled), 3060);
    });

    test('returns null for fewer than 3 samples', () {
      expect(
        BottomTimeCalculator.secondsFromSamples(const [
          (timestamp: 0, depth: 0.0),
          (timestamp: 60, depth: 10.0),
        ]),
        isNull,
      );
    });

    test('returns null when all depths are zero', () {
      expect(
        BottomTimeCalculator.secondsFromSamples(const [
          (timestamp: 0, depth: 0.0),
          (timestamp: 60, depth: 0.0),
          (timestamp: 120, depth: 0.0),
        ]),
        isNull,
      );
    });

    test('returns null when the bottom span is zero', () {
      // Only the first sample reaches the threshold (min(max(6, 9.9),
      // 25.5) = 9.9 m), so ascentStart == first timestamp and span is 0.
      expect(
        BottomTimeCalculator.secondsFromSamples(const [
          (timestamp: 0, depth: 30.0),
          (timestamp: 60, depth: 1.0),
          (timestamp: 120, depth: 0.0),
        ]),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/bottom_time_calculator_test.dart`
Expected: FAIL — the calculator file does not exist yet (compile error).

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_log/domain/services/bottom_time_calculator.dart`:

```dart
/// Pure bottom-time computation shared by the Dive entity and the dive
/// computer repository.
///
/// Bottom time is defined as surface departure to the start of the final
/// ascent (US Navy / dive-table convention): the descent counts; safety
/// and deco stops during the final ascent do not. The start of the final
/// ascent is approximated as the last profile sample at or below a depth
/// threshold, which makes multilevel dives (a deep excursion followed by a
/// long shallower tail) measure correctly -- the retired heuristic (time
/// at/above 85% of max depth) collapsed them to the deep segment only.
class BottomTimeCalculator {
  BottomTimeCalculator._();

  /// Depth (meters) below which a sample never marks the end of bottom
  /// time; keeps shallow safety stops (3-5 m) out of the bottom phase.
  static const double defaultAbsoluteFloorMeters = 6.0;

  /// Fraction of max depth used for the ascent threshold on deeper dives,
  /// so mid-depth multilevel tails still count as bottom.
  static const double defaultMaxDepthFraction = 0.33;

  /// Cap on the threshold as a fraction of max depth. Guarantees the
  /// deepest sample always qualifies; without it, dives shallower than the
  /// absolute floor could never produce a result.
  static const double defaultThresholdCapFraction = 0.85;

  /// Bottom time in seconds from (timestamp, depth) samples, or null when
  /// the profile is too small or degenerate. Samples need not be sorted;
  /// timestamps are seconds from dive start, depths are meters.
  static int? secondsFromSamples(
    List<({int timestamp, double depth})> samples, {
    double absoluteFloorMeters = defaultAbsoluteFloorMeters,
    double maxDepthFraction = defaultMaxDepthFraction,
    double thresholdCapFraction = defaultThresholdCapFraction,
  }) {
    if (samples.length < 3) return null;

    final sorted = [...samples]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    var maxDepth = 0.0;
    for (final sample in sorted) {
      if (sample.depth > maxDepth) maxDepth = sample.depth;
    }
    if (maxDepth <= 0) return null;

    var threshold = maxDepth * maxDepthFraction;
    if (threshold < absoluteFloorMeters) threshold = absoluteFloorMeters;
    final cap = maxDepth * thresholdCapFraction;
    if (threshold > cap) threshold = cap;

    int? ascentStart;
    for (var i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i].depth >= threshold) {
        ascentStart = sorted[i].timestamp;
        break;
      }
    }
    if (ascentStart == null) return null;

    final bottomSeconds = ascentStart - sorted.first.timestamp;
    return bottomSeconds > 0 ? bottomSeconds : null;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/services/bottom_time_calculator_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/domain/services/bottom_time_calculator.dart test/features/dive_log/domain/services/bottom_time_calculator_test.dart
git commit -m "Add multilevel-correct BottomTimeCalculator"
```

---

### Task 2: Delegate Dive.calculateBottomTimeFromProfile

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (method at ~line 438; add import at top)
- Test: `test/features/dive_log/domain/entities/dive_bottom_time_test.dart` (create)
- Modify: `test/features/dive_import/data/services/uddf_entity_importer_test.dart` (~lines 1044-1050)

**Interfaces:**
- Consumes: `BottomTimeCalculator.secondsFromSamples` from Task 1.
- Produces: `Duration? calculateBottomTimeFromProfile()` on `Dive` — same name as today but WITHOUT the old `depthThresholdPercent` parameter (no caller passes it; verify with the grep in Step 1). Call sites in `uddf_entity_importer.dart`, `imported_dive_converter.dart`, `dive_merge_builder.dart`, `dive_edit_page.dart`, and `test/integration/uddf_test_importer.dart` compile unchanged.

- [ ] **Step 1: Verify no caller passes the parameter being removed**

Run: `grep -rn "calculateBottomTimeFromProfile(" lib/ test/ | grep -v "calculateBottomTimeFromProfile()"`
Expected: only the definition in `dive.dart` (and doc-comment references). If any call site passes `depthThresholdPercent`, stop and report — the plan assumed none do.

- [ ] **Step 2: Write the failing entity test**

Create `test/features/dive_log/domain/entities/dive_bottom_time_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive.calculateBottomTimeFromProfile', () {
    test('multilevel dive counts the shallow tail as bottom time', () {
      // 29 m for ~10 min, then a 40 min tail at 15.2 m: the old 85%
      // heuristic returned 540 s; the multilevel-correct value is 3060 s
      // (surface departure at t=0 to the start of the final ascent).
      final dive = Dive(
        id: 'bt-multilevel',
        dateTime: DateTime(2024, 1, 1),
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 0.0),
          DiveProfilePoint(timestamp: 60, depth: 29.0),
          DiveProfilePoint(timestamp: 600, depth: 29.0),
          DiveProfilePoint(timestamp: 660, depth: 15.2),
          DiveProfilePoint(timestamp: 3060, depth: 15.2),
          DiveProfilePoint(timestamp: 3120, depth: 5.0),
          DiveProfilePoint(timestamp: 3300, depth: 5.0),
          DiveProfilePoint(timestamp: 3600, depth: 0.0),
        ],
      );
      expect(
        dive.calculateBottomTimeFromProfile(),
        const Duration(seconds: 3060),
      );
    });

    test('returns null without profile data', () {
      final dive = Dive(id: 'bt-empty', dateTime: DateTime(2024, 1, 1));
      expect(dive.calculateBottomTimeFromProfile(), isNull);
    });
  });
}
```

Note: if the `Dive` constructor requires `profile` to be non-const or has a different parameter shape, match the constructor as defined in `dive.dart` — the entity stores `profile` as a `List<DiveProfilePoint>` defaulting to empty.

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_bottom_time_test.dart`
Expected: FAIL — the multilevel case returns `Duration(seconds: 540)` from the old heuristic.

- [ ] **Step 4: Replace the entity method**

In `lib/features/dive_log/domain/entities/dive.dart`, add to the import block (keep alphabetical grouping with the other `package:submersion/features/dive_log/` imports):

```dart
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
```

Replace the whole `calculateBottomTimeFromProfile` method (doc comment through closing brace, currently lines 430-488) with:

```dart
  /// Calculate bottom time from dive profile data.
  ///
  /// Bottom time runs from surface departure to the start of the final
  /// ascent (US Navy convention): the descent counts; safety and deco
  /// stops during the final ascent do not. See [BottomTimeCalculator]
  /// for the threshold rule.
  ///
  /// Returns null if profile data is insufficient for calculation.
  Duration? calculateBottomTimeFromProfile() {
    final seconds = BottomTimeCalculator.secondsFromSamples([
      for (final point in profile)
        (timestamp: point.timestamp, depth: point.depth),
    ]);
    return seconds == null ? null : Duration(seconds: seconds);
  }
```

- [ ] **Step 5: Run the entity test to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/dive_bottom_time_test.dart`
Expected: PASS.

- [ ] **Step 6: Update the importer test pinned to the old heuristic**

In `test/features/dive_import/data/services/uddf_entity_importer_test.dart` (~lines 1046-1049), the Subsurface-style square profile now derives 1200 s (threshold min(max(6, 9.9), 25.5) = 9.9 m; last sample >= 9.9 m at t=1200; surface departure t=0), not 1140 s. Replace:

```dart
        // Bottom threshold is 85% of 30 m = 25.5 m; the diver is at/above it from
        // t=60 to t=1200, so bottom time is 1140 s, not the 1320 s runtime.
        expect(dive.runtime, const Duration(seconds: 1320));
        expect(dive.bottomTime, const Duration(seconds: 1140));
```

with:

```dart
        // Ascent threshold is min(max(6 m, 33% of 30 m), 85% of 30 m) =
        // 9.9 m; the last sample at/deeper is t=1200 and bottom time runs
        // from surface departure (t=0), so 1200 s, not the 1320 s runtime.
        expect(dive.runtime, const Duration(seconds: 1320));
        expect(dive.bottomTime, const Duration(seconds: 1200));
```

- [ ] **Step 7: Run the affected suites**

Run: `flutter test test/features/dive_import/data/services/uddf_entity_importer_test.dart test/features/dive_log/domain/`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format lib/ test/
git add -A lib/features/dive_log/domain test/features/dive_log/domain test/features/dive_import
git commit -m "Fix Dive bottom time calculation for multilevel profiles"
```

---

### Task 3: Delegate the dive computer repository copy

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`_calculateBottomTimeFromPoints`, ~lines 1732-1783; add import at top)

**Interfaces:**
- Consumes: `BottomTimeCalculator.secondsFromSamples` from Task 1; `ProfilePointData` (same file, has `int timestamp` and `double depth`).
- Produces: `int? _calculateBottomTimeFromPoints(List<ProfilePointData> points)` — private, same name, `depthThresholdPercent` parameter dropped.

- [ ] **Step 1: Verify the private method's callers**

Run: `grep -n "_calculateBottomTimeFromPoints" lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
Expected: the definition plus call sites that pass only `points`. If a caller passes `depthThresholdPercent`, stop and report.

- [ ] **Step 2: Replace the method**

Add to the `package:submersion/` import block:

```dart
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
```

Replace the whole `_calculateBottomTimeFromPoints` method (doc comment through closing brace) with:

```dart
  /// Calculate bottom time (seconds) from profile points.
  ///
  /// Delegates to [BottomTimeCalculator]: bottom time runs from surface
  /// departure to the start of the final ascent, so multilevel dives
  /// count their shallower segments.
  ///
  /// Returns null if profile data is insufficient for calculation.
  int? _calculateBottomTimeFromPoints(List<ProfilePointData> points) {
    return BottomTimeCalculator.secondsFromSamples([
      for (final point in points)
        (timestamp: point.timestamp, depth: point.depth),
    ]);
  }
```

- [ ] **Step 3: Analyze and run the repository suites**

Run: `flutter analyze lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
Expected: clean.
Run: `flutter test test/features/dive_log/data/repositories/`
Expected: PASS (these tests seed `bottomTime` directly; none pin the heuristic).

- [ ] **Step 4: Format and commit**

```bash
dart format lib/ test/
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart
git commit -m "Route dive computer bottom time through BottomTimeCalculator"
```

---

### Task 4: v146 migration backfill with fingerprint

**Files:**
- Modify: `lib/core/database/database.dart` — `currentSchemaVersion` (line ~2962), `migrationVersions` list (ends at 144), onUpgrade ladder (after the `from < 144` block, ~line 7453), new helpers next to `_backfillBottomTimeFromProfile` (~line 3395)
- Test: `test/core/database/migration_v146_bottom_time_multilevel_test.dart` (create)
- Modify: `test/core/database/migration_v132_bottom_time_backfill_test.dart` (expectations change because its fixtures now also run the v146 step)

**Interfaces:**
- Consumes: existing frozen `_bottomTimeSecondsFromProfileRows(List<QueryRow>)` (the old 85% heuristic — do NOT modify it; it is the fingerprint) and the v132 helper's structure as a template.
- Produces: `Future<void> _recomputeMultilevelBottomTimes()` and `int? _multilevelBottomTimeSecondsFromProfileRows(List<QueryRow> points)`, both private to `AppDatabase`. `AppDatabase.currentSchemaVersion == 146`; `migrationVersions` contains 146 (not 145).

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v146_bottom_time_multilevel_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v146 backfill: the retired bottom-time heuristic (time at/above 85% of
/// max depth) collapsed multilevel dives to their deepest segment. For any
/// dive whose stored bottom_time exactly reproduces that old heuristic's
/// output for its primary profile (i.e. it was machine-derived, not
/// user-typed), the migration recomputes it with the multilevel-correct
/// rule (surface departure to the last sample at/deeper than
/// min(max(6 m, 33% of max), 85% of max)).
void main() {
  // Stamped at 145 so ONLY the v146 step runs (the v132 backfill and every
  // earlier step are skipped), isolating what this test asserts.
  NativeDatabase setupDb(void Function(dynamic rawDb) seed) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 145');
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            bottom_time INTEGER,
            runtime INTEGER,
            hlc TEXT
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL
          )
        ''');
        seed(rawDb);
      },
    );
  }

  void insertDive(
    dynamic rawDb,
    String id, {
    int? bottomTime,
    int? runtime,
    String? hlc,
  }) {
    rawDb.execute(
      'INSERT INTO dives (id, bottom_time, runtime, hlc) VALUES (?, ?, ?, ?)',
      [id, bottomTime, runtime, hlc],
    );
  }

  // Multilevel profile: 29 m until t=600, a 15.2 m tail until t=3060, then
  // safety stop and surface. Old heuristic: threshold 24.65 m, window
  // t=60..600 -> 540 s (the fingerprint). New rule: threshold 9.57 m, last
  // sample at/deeper t=3060, surface departure t=0 -> 3060 s.
  void insertMultilevelProfile(
    dynamic rawDb,
    String diveId, {
    required bool isPrimary,
    String prefix = 'p',
  }) {
    const points = [
      [0, 0.0],
      [60, 29.0],
      [600, 29.0],
      [660, 15.2],
      [3060, 15.2],
      [3120, 5.0],
      [3300, 5.0],
      [3600, 0.0],
    ];
    for (var i = 0; i < points.length; i++) {
      rawDb.execute(
        'INSERT INTO dive_profiles (id, dive_id, is_primary, timestamp, depth) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          '$prefix-$diveId-$i',
          diveId,
          isPrimary ? 1 : 0,
          points[i][0],
          points[i][1],
        ],
      );
    }
  }

  Future<int?> bottomTimeOf(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          'SELECT bottom_time FROM dives WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingle();
    return row.data['bottom_time'] as int?;
  }

  test('recomputes a bottom time that matches the old heuristic', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertDive(rawDb, 'd1', bottomTime: 540, runtime: 3600);
        insertMultilevelProfile(rawDb, 'd1', isPrimary: true);
      }),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd1'), 3060);
  });

  test('leaves a user-typed bottom time untouched', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        // 2000 s does not match the old heuristic's 540 s for this
        // profile, so it was not machine-derived and must not change.
        insertDive(rawDb, 'd2', bottomTime: 2000, runtime: 3600);
        insertMultilevelProfile(rawDb, 'd2', isPrimary: true);
      }),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd2'), 2000);
  });

  test('leaves a profile-less dive untouched', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertDive(rawDb, 'd3', bottomTime: 1000, runtime: 1200);
      }),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd3'), 1000);
  });

  test('ignores secondary computer rows (primary profile only)', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertDive(rawDb, 'd4', bottomTime: 540, runtime: 3600);
        insertMultilevelProfile(rawDb, 'd4', isPrimary: false);
      }),
    );
    addTearDown(db.close);

    // No primary rows: the fingerprint cannot be computed, so no change.
    expect(await bottomTimeOf(db, 'd4'), 540);
  });

  test('does not bump hlc (deterministic local correction)', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        insertDive(rawDb, 'd5', bottomTime: 540, runtime: 3600, hlc: 'H1');
        insertMultilevelProfile(rawDb, 'd5', isPrimary: true);
      }),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd5'), 3060);
    final row = await db
        .customSelect(
          'SELECT hlc FROM dives WHERE id = ?',
          variables: [const Variable<String>('d5')],
        )
        .getSingle();
    expect(row.data['hlc'], 'H1');
  });

  test('no-ops safely when dive_profiles lacks a dive_id column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 145');
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY,
              bottom_time INTEGER,
              runtime INTEGER,
              hlc TEXT
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dive_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              is_primary INTEGER NOT NULL DEFAULT 1,
              timestamp INTEGER NOT NULL,
              depth REAL NOT NULL
            )
          ''');
          rawDb.execute(
            'INSERT INTO dives (id, bottom_time, runtime) VALUES (?, ?, ?)',
            ['d6', 540, 3600],
          );
        },
      ),
    );
    addTearDown(db.close);

    expect(await bottomTimeOf(db, 'd6'), 540);
  });

  test('schema version is at least 146 and the migration list includes it', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(146));
    expect(AppDatabase.migrationVersions, contains(146));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v146_bottom_time_multilevel_test.dart`
Expected: FAIL — schema version is 144 and no v146 step exists (the fingerprinted dives stay at 540).

- [ ] **Step 3: Implement the migration**

In `lib/core/database/database.dart`:

(a) Bump the version constant (line ~2962):

```dart
  static const int currentSchemaVersion = 146;
```

(b) Append to `migrationVersions` (list currently ends `..., 144,`):

```dart
    144,
    // v145 is reserved by the GPS track mapping branch (PR #908).
    146,
```

(c) Add the two helpers directly after `_bottomTimeSecondsFromProfileRows` (~line 3432). Do NOT modify `_bottomTimeSecondsFromProfileRows` or `_backfillBottomTimeFromProfile` — the old heuristic is the fingerprint and the v132 step's behavior must stay frozen.

```dart
  /// v146 data fix: the retired bottom-time heuristic (time at/above 85% of
  /// max depth -- kept frozen above in [_bottomTimeSecondsFromProfileRows])
  /// collapsed multilevel dives to their deepest segment: 10 min at 29 m
  /// followed by 40 min at 15 m reported ~9 min of bottom time. For any dive
  /// whose stored bottom_time exactly reproduces the old heuristic's output
  /// for its primary profile (i.e. it was machine-derived by an import,
  /// download, or the v132 backfill -- user-typed values will not match),
  /// recompute it with the multilevel-correct rule in
  /// [_multilevelBottomTimeSecondsFromProfileRows].
  ///
  /// Both algorithms are frozen private copies so every device computes
  /// identical values no matter which app version it migrates with; `hlc`
  /// is left untouched (deterministic local recompute, no sync traffic
  /// needed to converge, exactly like v132). onUpgrade only.
  Future<void> _recomputeMultilevelBottomTimes() async {
    final diveCols = await customSelect("PRAGMA table_info('dives')").get();
    final diveColNames = diveCols.map((c) => c.read<String>('name')).toSet();
    if (!diveColNames.contains('bottom_time')) {
      return;
    }
    final profileCols = await customSelect(
      "PRAGMA table_info('dive_profiles')",
    ).get();
    final profileColNames = profileCols
        .map((c) => c.read<String>('name'))
        .toSet();
    if (!profileColNames.contains('dive_id') ||
        !profileColNames.contains('is_primary') ||
        !profileColNames.contains('timestamp') ||
        !profileColNames.contains('depth')) {
      return;
    }

    final candidates = await customSelect(
      'SELECT id, bottom_time FROM dives WHERE bottom_time IS NOT NULL',
    ).get();

    var processed = 0;
    for (final candidate in candidates) {
      // Same event-loop yield as the v132 backfill: during a migration the
      // executor completes drift awaits in microtasks, so an unbroken loop
      // would freeze the migration progress spinner.
      if (processed++ % 25 == 24) {
        await Future<void>.delayed(Duration.zero);
      }
      final diveId = candidate.read<String>('id');
      final storedSeconds = candidate.read<int>('bottom_time');

      final points = await customSelect(
        'SELECT timestamp, depth FROM dive_profiles '
        'WHERE dive_id = ? AND is_primary = 1 '
        'ORDER BY timestamp ASC',
        variables: [Variable<String>(diveId)],
      ).get();

      // Fingerprint check: only values the old heuristic produced are
      // machine-written; anything else is user data and stays.
      final oldSeconds = _bottomTimeSecondsFromProfileRows(points);
      if (oldSeconds == null || oldSeconds != storedSeconds) continue;

      final newSeconds = _multilevelBottomTimeSecondsFromProfileRows(points);
      if (newSeconds != null && newSeconds != storedSeconds) {
        await customStatement('UPDATE dives SET bottom_time = ? WHERE id = ?', [
          newSeconds,
          diveId,
        ]);
      }
    }
  }

  /// Multilevel-correct bottom time in seconds from timestamp-ordered
  /// profile rows: surface departure (first sample) to the last sample
  /// at/deeper than min(max(6 m, 33% of max depth), 85% of max depth).
  /// Frozen copy of the v146-era BottomTimeCalculator so the migration is
  /// deterministic across app versions; do not sync with later changes to
  /// the domain calculator.
  int? _multilevelBottomTimeSecondsFromProfileRows(List<QueryRow> points) {
    if (points.length < 3) return null;

    var maxDepth = 0.0;
    for (final point in points) {
      final depth = point.read<double>('depth');
      if (depth > maxDepth) maxDepth = depth;
    }
    if (maxDepth <= 0) return null;

    var threshold = maxDepth * 0.33;
    if (threshold < 6.0) threshold = 6.0;
    final cap = maxDepth * 0.85;
    if (threshold > cap) threshold = cap;

    int? ascentStart;
    for (var i = points.length - 1; i >= 0; i--) {
      if (points[i].read<double>('depth') >= threshold) {
        ascentStart = points[i].read<int>('timestamp');
        break;
      }
    }
    if (ascentStart == null) return null;

    final firstTimestamp = points.first.read<int>('timestamp');
    final bottomSeconds = ascentStart - firstTimestamp;
    return bottomSeconds > 0 ? bottomSeconds : null;
  }
```

(d) Register the step in the onUpgrade ladder, directly after `if (from < 144) await reportProgress();` (~line 7453):

```dart
        // v145 is reserved by the GPS track mapping branch (PR #908).
        // v146: recompute bottom times the retired square-profile heuristic
        // derived too short on multilevel dives. Fingerprinted -- only
        // stored values that exactly reproduce the old heuristic are
        // machine-written and get replaced; user-typed values never match
        // and are left alone. onUpgrade only, hlc untouched (v132 pattern).
        if (from < 146) {
          await _recomputeMultilevelBottomTimes();
        }
        if (from < 146) await reportProgress();
```

- [ ] **Step 4: Run the new migration test**

Run: `flutter test test/core/database/migration_v146_bottom_time_multilevel_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Update the v132 test (its fixtures now run the v146 step too)**

`test/core/database/migration_v132_bottom_time_backfill_test.dart` stamps `user_version = 130`, so its databases migrate through BOTH steps. Its square profile ([0,0],[60,30],[120,30],[1200,30],[1260,5],[1320,0]) fingerprints at 1140 s (old heuristic) and recomputes to 1200 s (new rule: threshold 9.9 m, last sample at/deeper t=1200, surface departure t=0). Update:

1. Line ~104 (`recomputes bottom time from the primary profile...`): `expect(await bottomTimeOf(db, 'd1'), 1140);` becomes `expect(await bottomTimeOf(db, 'd1'), 1200);`
2. Line ~133 (`leaves an already-correct dive untouched...`): `expect(await bottomTimeOf(db, 'd3'), 1140);` becomes `expect(await bottomTimeOf(db, 'd3'), 1200);` — v132 leaves it (bottom_time != runtime), but its 1140 s matches the old-heuristic fingerprint, so v146 corrects it.
3. Line ~165 (primary-only test): `expect(await bottomTimeOf(db, 'd4'), 1140);` becomes `expect(await bottomTimeOf(db, 'd4'), 1200);`
4. Line ~180 (hlc test): `expect(await bottomTimeOf(db, 'd5'), 1140);` becomes `expect(await bottomTimeOf(db, 'd5'), 1200);` (the `hlc == 'H1'` assertion stays).
5. Update the comment above `insertBottomWindowProfile` (~line 52) to:

```dart
  // A clear bottom window: 85% of 30 m = 25.5 m; the diver is at/above it
  // from t=60 to t=1200, so the v132 backfill writes 1140 s. Fixtures here
  // migrate 130 -> current, so the v146 multilevel correction then runs:
  // 1140 s matches the old-heuristic fingerprint and is recomputed to
  // 1200 s (surface departure t=0 to the last sample at/deeper than 9.9 m
  // at t=1200).
```

6. Extend the file's top doc comment (lines 6-9) with one sentence: `Fixtures stamped at v130 also run the v146 multilevel correction; expected values reflect both steps.`

The profile-less (d2, 1320) and missing-dive_id (d6, 1320) tests are unchanged: 1320 == runtime does not match any profile-derived fingerprint without/with a broken profile table, and both steps guard on the columns.

- [ ] **Step 6: Run both migration tests**

Run: `flutter test test/core/database/migration_v132_bottom_time_backfill_test.dart test/core/database/migration_v146_bottom_time_multilevel_test.dart`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format lib/ test/
git add lib/core/database/database.dart test/core/database/
git commit -m "Add v146 backfill correcting machine-derived multilevel bottom times"
```

---

### Task 5: Full verification

**Files:**
- Modify: `docs/superpowers/specs/2026-08-09-bottom-time-multilevel-design.md` (only if verification reveals a deviation worth recording)

**Interfaces:**
- Consumes: everything above.
- Produces: a green tree ready for review/PR.

- [ ] **Step 1: Format check**

Run: `dart format lib/ test/`
Expected: no files changed (`0 changed`). If files changed, commit the formatting.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: `No issues found!` — do not pipe through anything that could mask the exit code; infos are failures.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all green. Known slow/flaky areas (backup, media upload) are unrelated; a failure there once is a retry, twice is a report. If any OTHER test fails on a bottom-time expectation this plan missed, the fix is to hand-compute the new expected value with the algorithm (threshold = min(max(6, 0.33*max), 0.85*max); last sample at/deeper; minus first sample timestamp) and update the expectation with a comment — never copy a number out of the failure output unverified.

- [ ] **Step 4: Verify no stray references to the old heuristic remain**

Run: `grep -rn "85% of max\|depthThresholdPercent\|0.85" lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
Expected: no matches (the only intentional 85% references live in `database.dart`'s frozen helpers and the calculator's cap constant).

- [ ] **Step 5: Commit any residue and report**

```bash
git status
```

If clean besides intended commits, the branch is ready: report test counts and summarize for review.
