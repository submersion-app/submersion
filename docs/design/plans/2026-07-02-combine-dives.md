# Combine Dives (Sequential Merge, #449) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user select 2+ non-time-overlapping dives in the dive list and combine them into one contiguous dive whose profile represents inter-dive gaps as 0-depth surface time, with sources deleted (sync tombstones) and a snackbar Undo that restores them exactly.

**Architecture:** A pure `DiveMergeBuilder` (domain layer, no DB) classifies selections as sequential vs overlapping and computes the merged `Dive` entity, per-source timeline offsets, gap descriptors, and a tank-ID remap table. A thin `DiveMergeService` (modeled on `BulkDiveEditService`) captures a full-fidelity Drift-row snapshot, then in one transaction creates the merged dive via `DiveRepository.createDive`, row-copies the children the create path does not cover, re-points media, and deletes the sources through the tombstone-logging path. A new `CombineDivesDialog` routes sequential selections to a preview/confirm flow and overlapping selections to an explanatory panel (reserved for the future multi-computer combine).

**Tech Stack:** Dart/Flutter, Drift (SQLite ORM, companions), Riverpod, flutter_test, flutter gen-l10n.

**Spec:** `docs/superpowers/specs/2026-07-02-combine-dives-design.md`

## Global Constraints

- **Name-clash rule:** Drift generates row classes `Dive`, `DiveTank`, `DiveWeight`, `Sighting`, `DiveCustomField` that collide with domain entities. In every new/edited data-layer file, import domain entities `as domain` and use Drift row classes unprefixed. Reconstruct companions from Drift rows with `row.toCompanion(false)` (prior NULLs written back, not left absent).
- Sync bookkeeping: every touched row is marked pending via `_sync.markRecordPending(entityType: <camelCaseTable>, recordId: <id>, localUpdatedAt: now)`; every deletion via the repository delete paths that call `logDeletion`. `now` is always `final now = DateTime.now().millisecondsSinceEpoch;` (int).
- `entityType` strings (exact): `'dives'`, `'diveTanks'`, `'diveWeights'`, `'diveEquipment'`, `'diveCustomFields'`, `'diveDiveTypes'`, `'diveTags'`, `'diveBuddies'`, `'sightings'`, `'gasSwitches'`, `'diveProfileEvents'`, `'tideRecords'`, `'media'`.
- `DiveMergeService` owns the transaction boundary (`_db.transaction`). Nested repository calls (`createDive`, `bulkDeleteDives`) fire their own `SyncEventBus.notifyLocalChange()`; that is harmless (the bus debounces) — do not refactor them.
- Junction/child rows are NEVER re-pointed in place (except `media`, whose FK is `setNull` and which has no better identity); they are copied with fresh `_uuid.v4()` IDs (#347 sync lesson). Media re-point happens INSIDE the transaction BEFORE source deletion.
- All carried-over `DiveDataSources` rows get `isPrimary: false` so `reparse_service` can never rewrite the merged profile.
- Repositories use implicit default constructors and resolve the DB via `DatabaseService.instance.database`; tests use `setUpTestDatabase()` / `tearDownTestDatabase()` from `test/helpers/test_database.dart` and construct `DiveRepository()` directly. Service DB tests run `await db.customStatement('PRAGMA foreign_keys = OFF');` in `setUp` so link rows can be seeded without catalog rows.
- Test imports: `import 'package:drift/drift.dart' hide isNull, isNotNull;` and `import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;`.
- New user-facing strings use the `diveLog_combine_*` / `diveLog_selection_*` l10n namespaces, referenced as `context.l10n.<key>`, added to `lib/l10n/arb/app_en.arb` when first used and to all 10 non-English ARB files (`app_ar/de/es/fr/he/hu/it/nl/pt/zh.arb`) in the final localization task, then regenerated with `flutter gen-l10n`.
- Snackbars with an Undo action set `persist: false` AND `showCloseIcon: true` (#406). Model: `dive_edit_page.dart:1428-1444`, NOT the older `_confirmAndDelete` snackbar.
- Run `dart format .` (whole repo) before every commit. Conventional commit prefixes; no `Co-Authored-By` lines. Never push with the worktree pre-push hook (`git push --no-verify` when pushing).
- Time semantics (from spec): runtime = full surface-to-surface span including gaps; bottomTime = sum of source bottom times; avgDepth = time-weighted mean over the segments' original samples only (synthesized gap samples excluded; a real 0-depth sample recorded by a computer inside a segment still counts).

---

## Phase 1 — Pure merge builder (`DiveMergeBuilder`)

All Phase 1 code goes in a new file `lib/features/dive_log/domain/services/dive_merge_builder.dart` with tests in `test/features/dive_log/domain/services/dive_merge_builder_test.dart`. No database anywhere in this phase.

### Task 1: Classification — sequential / overlapping / invalid

**Files:**
- Create: `lib/features/dive_log/domain/services/dive_merge_builder.dart`
- Test: `test/features/dive_log/domain/services/dive_merge_builder_test.dart` (new)

**Interfaces:**
- Consumes: `domain.Dive` (`effectiveEntryTime`, `effectiveRuntime`, `diverId`, `id`).
- Produces: `sealed class DiveMergeClassification` with `MergeInvalid(DiveMergeInvalidReason reason)`, `MergeOverlapping()`, `MergeSequential({List<Dive> sortedDives, List<MergeGap> gaps})`; `class MergeGap({String afterDiveId, String beforeDiveId, int startSeconds, int endSeconds})` with `Duration get duration`; `DiveMergeClassification DiveMergeBuilder.classify(List<Dive> dives)`. Later tasks and the dialog switch on these types.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/domain/services/dive_merge_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_merge_builder.dart';

Dive dive(
  String id, {
  DateTime? entry,
  int runtimeMin = 30,
  String? diverId = 'diver1',
  List<DiveProfilePoint> profile = const [],
}) => Dive(
  id: id,
  diverId: diverId,
  dateTime: entry ?? DateTime.utc(2026, 7, 1, 9),
  entryTime: entry ?? DateTime.utc(2026, 7, 1, 9),
  runtime: Duration(minutes: runtimeMin),
  profile: profile,
);

void main() {
  const builder = DiveMergeBuilder();

  group('classify', () {
    test('fewer than 2 dives is invalid', () {
      final result = builder.classify([dive('a')]);
      expect(result, isA<MergeInvalid>());
      expect(
        (result as MergeInvalid).reason,
        DiveMergeInvalidReason.tooFewDives,
      );
    });

    test('mixed divers is invalid', () {
      final result = builder.classify([
        dive('a', entry: DateTime.utc(2026, 7, 1, 9)),
        dive('b', entry: DateTime.utc(2026, 7, 1, 11), diverId: 'diver2'),
      ]);
      expect(result, isA<MergeInvalid>());
      expect(
        (result as MergeInvalid).reason,
        DiveMergeInvalidReason.mixedDivers,
      );
    });

    test('overlapping dives are classified overlapping', () {
      // a runs 09:00-09:30, b starts 09:15 -> overlap
      final result = builder.classify([
        dive('a', entry: DateTime.utc(2026, 7, 1, 9)),
        dive('b', entry: DateTime.utc(2026, 7, 1, 9, 15)),
      ]);
      expect(result, isA<MergeOverlapping>());
    });

    test('sequential dives sort chronologically and report the gap', () {
      // b: 10:00-10:20, a: 09:00-09:30 -> sorted a,b; gap 09:30-10:00
      final result = builder.classify([
        dive('b', entry: DateTime.utc(2026, 7, 1, 10), runtimeMin: 20),
        dive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 30),
      ]);
      expect(result, isA<MergeSequential>());
      final seq = result as MergeSequential;
      expect(seq.sortedDives.map((d) => d.id), ['a', 'b']);
      expect(seq.gaps, hasLength(1));
      expect(seq.gaps.single.afterDiveId, 'a');
      expect(seq.gaps.single.beforeDiveId, 'b');
      expect(seq.gaps.single.startSeconds, 30 * 60);
      expect(seq.gaps.single.endSeconds, 60 * 60);
      expect(seq.gaps.single.duration, const Duration(minutes: 30));
    });

    test('touching dives (gap == 0) are sequential with a zero gap', () {
      final result = builder.classify([
        dive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 60),
        dive('b', entry: DateTime.utc(2026, 7, 1, 10)),
      ]);
      expect(result, isA<MergeSequential>());
      expect((result as MergeSequential).gaps.single.duration, Duration.zero);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package ... dive_merge_builder.dart` / type not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/dive_log/domain/services/dive_merge_builder.dart
import '../entities/dive.dart';

/// Why a merge was rejected outright (neither sequential nor overlapping).
enum DiveMergeInvalidReason { tooFewDives, mixedDivers }

/// One inter-dive surface gap on the merged timeline.
class MergeGap {
  const MergeGap({
    required this.afterDiveId,
    required this.beforeDiveId,
    required this.startSeconds,
    required this.endSeconds,
  });

  /// The gap follows this source dive.
  final String afterDiveId;

  /// The gap precedes this source dive.
  final String beforeDiveId;

  /// Seconds from the merged dive's start.
  final int startSeconds;
  final int endSeconds;

  Duration get duration => Duration(seconds: endSeconds - startSeconds);
}

sealed class DiveMergeClassification {
  const DiveMergeClassification();
}

class MergeInvalid extends DiveMergeClassification {
  const MergeInvalid(this.reason);
  final DiveMergeInvalidReason reason;
}

/// Any pair of dives overlaps in time — these look like the same dive from
/// multiple computers (future feature), not a sequential combine.
class MergeOverlapping extends DiveMergeClassification {
  const MergeOverlapping();
}

class MergeSequential extends DiveMergeClassification {
  const MergeSequential({required this.sortedDives, required this.gaps});
  final List<Dive> sortedDives;
  final List<MergeGap> gaps;
}

class DiveMergeBuilder {
  const DiveMergeBuilder();

  DiveMergeClassification classify(List<Dive> dives) {
    if (dives.length < 2) {
      return const MergeInvalid(DiveMergeInvalidReason.tooFewDives);
    }
    if (dives.map((d) => d.diverId).toSet().length > 1) {
      return const MergeInvalid(DiveMergeInvalidReason.mixedDivers);
    }
    final sorted = [...dives]
      ..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));
    final mergedStart = sorted.first.effectiveEntryTime;
    final gaps = <MergeGap>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final prev = sorted[i];
      final next = sorted[i + 1];
      final prevEnd = prev.effectiveEntryTime.add(
        prev.effectiveRuntime ?? Duration.zero,
      );
      if (next.effectiveEntryTime.isBefore(prevEnd)) {
        return const MergeOverlapping();
      }
      gaps.add(
        MergeGap(
          afterDiveId: prev.id,
          beforeDiveId: next.id,
          startSeconds: prevEnd.difference(mergedStart).inSeconds,
          endSeconds: next.effectiveEntryTime
              .difference(mergedStart)
              .inSeconds,
        ),
      );
    }
    return MergeSequential(sortedDives: sorted, gaps: gaps);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/domain/services/dive_merge_builder.dart test/features/dive_log/domain/services/dive_merge_builder_test.dart
git commit -m "feat(dive-merge): add DiveMergeBuilder.classify (#449)"
```

### Task 2: `DiveMergeResult` + `build()` timeline core

**Files:**
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart`
- Test: `test/features/dive_log/domain/services/dive_merge_builder_test.dart`

**Interfaces:**
- Consumes: Task 1's `classify`/`MergeSequential`.
- Produces:
  - `class DiveMergeResult({Dive mergedDive, List<Dive> sortedSources, List<MergeGap> gaps, Map<String, int> segmentOffsetsSeconds, Map<String, String> tankIdMap, List<MarineSighting> mergedSightings})`
  - `DiveMergeResult DiveMergeBuilder.build(List<Dive> dives, {Map<String, List<Tag>> tagsByDive = const {}, Map<String, List<MarineSighting>> sightingsByDive = const {}, String Function()? idGenerator})` — throws `ArgumentError` unless classification is `MergeSequential`.
  - Timeline fields on `mergedDive` after this task: `id` (from `idGenerator`), `diverId`, `dateTime`, `entryTime`, `exitTime`, `runtime`.
  - `segmentOffsetsSeconds[sourceDiveId]` = whole seconds to add to that source's profile timestamps.

- [ ] **Step 1: Write the failing test** (append to the existing test file)

```dart
  group('build - timeline', () {
    test('throws for non-sequential input', () {
      expect(
        () => builder.build([dive('a')]),
        throwsArgumentError,
      );
    });

    test('merged dive spans first entry to last exit; offsets are relative', () {
      var n = 0;
      final result = builder.build([
        dive('b', entry: DateTime.utc(2026, 7, 1, 10), runtimeMin: 20),
        dive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 30),
      ], idGenerator: () => 'gen-${n++}');

      final merged = result.mergedDive;
      expect(merged.id, 'gen-0');
      expect(merged.diverId, 'diver1');
      expect(merged.entryTime, DateTime.utc(2026, 7, 1, 9));
      expect(merged.exitTime, DateTime.utc(2026, 7, 1, 10, 20));
      expect(merged.runtime, const Duration(minutes: 80)); // includes the gap
      expect(result.segmentOffsetsSeconds, {'a': 0, 'b': 3600});
      expect(result.sortedSources.map((d) => d.id), ['a', 'b']);
      expect(result.gaps, hasLength(1));
    });

    test('uses explicit exitTime of the last dive when set', () {
      final last = Dive(
        id: 'b',
        diverId: 'diver1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        entryTime: DateTime.utc(2026, 7, 1, 10),
        exitTime: DateTime.utc(2026, 7, 1, 10, 25),
        runtime: const Duration(minutes: 25),
      );
      final result = builder.build([dive('a'), last]);
      expect(result.mergedDive.exitTime, DateTime.utc(2026, 7, 1, 10, 25));
    });
  });
```

Note: the `builder` local and `dive()` helper from Task 1 are reused; add `import 'package:submersion/features/tags/domain/entities/tag.dart';` at the top of the test file (needed by later tasks; harmless now).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: FAIL — `The method 'build' isn't defined for the type 'DiveMergeBuilder'`.

- [ ] **Step 3: Write minimal implementation** (add to `dive_merge_builder.dart`)

```dart
import 'package:uuid/uuid.dart';

import '../../../tags/domain/entities/tag.dart';
import '../entities/dive.dart';

/// Everything the merge service needs to persist a sequential combine.
class DiveMergeResult {
  const DiveMergeResult({
    required this.mergedDive,
    required this.sortedSources,
    required this.gaps,
    required this.segmentOffsetsSeconds,
    required this.tankIdMap,
    required this.mergedSightings,
  });

  final Dive mergedDive;
  final List<Dive> sortedSources;
  final List<MergeGap> gaps;

  /// Source dive id -> seconds to add to that segment's profile timestamps.
  final Map<String, int> segmentOffsetsSeconds;

  /// Old source tank id -> fresh tank id on the merged dive.
  final Map<String, String> tankIdMap;

  /// Union of source sightings (same species merged), with fresh ids.
  final List<MarineSighting> mergedSightings;
}

// Inside DiveMergeBuilder:
  static const _uuid = Uuid();

  DiveMergeResult build(
    List<Dive> dives, {
    Map<String, List<Tag>> tagsByDive = const {},
    Map<String, List<MarineSighting>> sightingsByDive = const {},
    String Function()? idGenerator,
  }) {
    final classification = classify(dives);
    if (classification is! MergeSequential) {
      throw ArgumentError(
        'build() requires a sequential selection; got $classification',
      );
    }
    final idGen = idGenerator ?? _uuid.v4;
    final sorted = classification.sortedDives;
    final first = sorted.first;
    final last = sorted.last;

    final mergedStart = first.effectiveEntryTime;
    final mergedEnd =
        last.exitTime ??
        last.effectiveEntryTime.add(last.effectiveRuntime ?? Duration.zero);

    final offsets = <String, int>{
      for (final d in sorted)
        d.id: d.effectiveEntryTime.difference(mergedStart).inSeconds,
    };

    final mergedDive = Dive(
      id: idGen(),
      diverId: first.diverId,
      dateTime: first.dateTime,
      entryTime: mergedStart,
      exitTime: mergedEnd,
      runtime: mergedEnd.difference(mergedStart),
    );

    return DiveMergeResult(
      mergedDive: mergedDive,
      sortedSources: sorted,
      gaps: classification.gaps,
      segmentOffsetsSeconds: offsets,
      tankIdMap: const {},
      mergedSightings: const [],
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/features/dive_log/domain/services test/features/dive_log/domain/services
git commit -m "feat(dive-merge): DiveMergeResult and merged timeline (#449)"
```

### Task 3: Merged stats — bottomTime, maxDepth, avgDepth (surface-excluded)

**Files:**
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart`
- Test: `test/features/dive_log/domain/services/dive_merge_builder_test.dart`

**Interfaces:**
- Consumes: Task 2's `build()`.
- Produces: `mergedDive.bottomTime`, `mergedDive.maxDepth`, `mergedDive.avgDepth` populated. avgDepth is the time-weighted mean over each segment's own samples (trapezoidal), weighted across segments by sampled span; a source with < 2 samples contributes its stored `avgDepth` weighted by `effectiveRuntime`. Gap time never contributes.

- [ ] **Step 1: Write the failing test** (append)

```dart
  group('build - stats', () {
    List<DiveProfilePoint> flatProfile(int seconds, double depth) => [
      for (var t = 0; t <= seconds; t += 10)
        DiveProfilePoint(timestamp: t, depth: depth),
    ];

    test('bottomTime sums sources; maxDepth is the max', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        bottomTime: const Duration(minutes: 25),
        maxDepth: 18.0,
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        bottomTime: const Duration(minutes: 20),
        maxDepth: 30.5,
      );
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.bottomTime, const Duration(minutes: 45));
      expect(merged.maxDepth, 30.5);
    });

    test('avgDepth is weighted by sampled time and excludes the gap', () {
      // a: 600s at a constant 10m; b: 600s at a constant 20m; 30min gap.
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        runtimeMin: 10,
        profile: flatProfile(600, 10),
      );
      final b = dive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
        runtimeMin: 10,
        profile: flatProfile(600, 20),
      );
      final merged = builder.build([a, b]).mergedDive;
      // Equal sampled spans -> plain mean of 10 and 20; the 30min gap at
      // 0m must NOT drag this down.
      expect(merged.avgDepth, closeTo(15.0, 0.001));
    });

    test('profile-less source falls back to stored avgDepth x runtime', () {
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
        runtimeMin: 10,
        profile: flatProfile(600, 10),
      );
      final b = dive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
        runtimeMin: 30,
      ).copyWith(avgDepth: 20.0);
      final merged = builder.build([a, b]).mergedDive;
      // 600s @ 10m + 1800s @ 20m = (6000 + 36000) / 2400 = 17.5
      expect(merged.avgDepth, closeTo(17.5, 0.001));
    });

    test('stats are null when no source has any data', () {
      final merged = builder
          .build([
            dive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 0),
            dive('b', entry: DateTime.utc(2026, 7, 1, 10), runtimeMin: 0),
          ])
          .mergedDive;
      expect(merged.maxDepth, isNull);
      expect(merged.avgDepth, isNull);
      expect(merged.bottomTime, isNull);
    });
  });
```

Note: `Dive.copyWith` cannot clear fields (`x ?? this.x`), which is fine here — we only set them.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: FAIL — merged stats are null / wrong values.

- [ ] **Step 3: Write minimal implementation** (add private helpers + wire into `build()`)

```dart
  /// Trapezoidal time-weighted mean depth over one segment's samples.
  /// Returns (weightedAreaMeterSeconds, spanSeconds) or null if < 2 samples.
  (double, int)? _profileDepthArea(List<DiveProfilePoint> profile) {
    if (profile.length < 2) return null;
    final sorted = [...profile]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    var area = 0.0;
    var span = 0;
    for (var i = 0; i < sorted.length - 1; i++) {
      final dt = sorted[i + 1].timestamp - sorted[i].timestamp;
      if (dt <= 0) continue;
      area += dt * (sorted[i].depth + sorted[i + 1].depth) / 2;
      span += dt;
    }
    return span > 0 ? (area, span) : null;
  }

  Duration? _mergedBottomTime(List<Dive> sorted) {
    var total = Duration.zero;
    var any = false;
    for (final d in sorted) {
      final bt =
          d.bottomTime ??
          d.calculateBottomTimeFromProfile() ??
          d.effectiveRuntime;
      if (bt != null && bt > Duration.zero) {
        total += bt;
        any = true;
      }
    }
    return any ? total : null;
  }

  double? _mergedMaxDepth(List<Dive> sorted) {
    double? max;
    for (final d in sorted) {
      final m = d.maxDepth ?? d.calculateMaxDepthFromProfile();
      if (m != null && (max == null || m > max)) max = m;
    }
    return max;
  }

  double? _mergedAvgDepth(List<Dive> sorted) {
    var area = 0.0;
    var span = 0;
    for (final d in sorted) {
      final fromProfile = _profileDepthArea(d.profile);
      if (fromProfile != null) {
        area += fromProfile.$1;
        span += fromProfile.$2;
      } else if (d.avgDepth != null) {
        final w = (d.effectiveRuntime ?? Duration.zero).inSeconds;
        if (w > 0) {
          area += d.avgDepth! * w;
          span += w;
        }
      }
    }
    return span > 0 ? area / span : null;
  }
```

In `build()`, extend the `Dive(...)` construction:

```dart
    final mergedDive = Dive(
      id: idGen(),
      diverId: first.diverId,
      dateTime: first.dateTime,
      entryTime: mergedStart,
      exitTime: mergedEnd,
      runtime: mergedEnd.difference(mergedStart),
      bottomTime: _mergedBottomTime(sorted),
      maxDepth: _mergedMaxDepth(sorted),
      avgDepth: _mergedAvgDepth(sorted),
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/features/dive_log/domain/services test/features/dive_log/domain/services
git commit -m "feat(dive-merge): merged stats with surface-excluded avgDepth (#449)"
```

### Task 4: Scalar metadata — first-non-empty, notes concat, favorites

**Files:**
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart`
- Test: `test/features/dive_log/domain/services/dive_merge_builder_test.dart`

**Interfaces:**
- Consumes: Tasks 2-3.
- Produces: `mergedDive` scalar fields populated per spec: first-non-empty in chronological order for `site`, `diveCenter`, `trip`/`tripId`, `buddy`, `diveMaster`, `rating`, `visibility`, `waterTemp`, `airTemp`, `currentDirection`, `currentStrength`, `swellHeight`, `entryMethod`, `exitMethod`, `waterType`, `altitude`, `surfacePressure`, `gradientFactorLow/High`, `decoAlgorithm`, `decoConservatism`, `diveComputerModel/Serial/Firmware`, `weightAmount`, `weightType`, CCR/SCR block (`setpointLow/High/Deco`, `scrType`, `scrInjectionRate`, `scrAdditionRatio`, `scrOrificeSize`, `assumedVo2`, `diluentGas`, `loopO2Min/Max/Avg`, `loopVolume`, `scrubber`), `importSource`, `importId`, weather block (`windSpeed`, `windDirection`, `cloudCover`, `precipitation`, `humidity`, `weatherDescription`, `weatherSource`, `weatherFetchedAt`), `entryLocation`. Exceptions: `exitLocation` = LAST non-null (the merged dive exits where the final segment exited); `notes` = all non-empty notes joined with `'\n\n'`; `isFavorite` = OR across sources; `surfaceInterval` = first dive's; `diveNumber` = first dive's; `diveMode` = first dive's; `isPlanned` = first dive's.

- [ ] **Step 1: Write the failing test** (append)

```dart
  group('build - metadata', () {
    test('first non-empty wins in chronological order', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        rating: 4,
        diveNumber: 101,
        surfaceInterval: const Duration(hours: 2),
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        rating: 2,
        waterTemp: 19.5,
        diveComputerModel: 'Perdix 2',
        diveNumber: 102,
      );
      final merged = builder.build([b, a]).mergedDive; // unsorted input
      expect(merged.rating, 4); // a is chronologically first
      expect(merged.waterTemp, 19.5); // a blank -> filled from b
      expect(merged.diveComputerModel, 'Perdix 2');
      expect(merged.diveNumber, 101); // always the first dive's
      expect(merged.surfaceInterval, const Duration(hours: 2));
    });

    test('notes concatenate non-empty in order; favorite is OR', () {
      final a = dive(
        'a',
        entry: DateTime.utc(2026, 7, 1, 9),
      ).copyWith(notes: 'first leg');
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10));
      final c = dive(
        'c',
        entry: DateTime.utc(2026, 7, 1, 11),
      ).copyWith(notes: 'second leg', isFavorite: true);
      final merged = builder.build([a, b, c]).mergedDive;
      expect(merged.notes, 'first leg\n\nsecond leg');
      expect(merged.isFavorite, isTrue);
    });

    test('exitLocation comes from the LAST dive that has one', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        entryLocation: const GeoPoint(latitude: 1, longitude: 1),
        exitLocation: const GeoPoint(latitude: 2, longitude: 2),
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        exitLocation: const GeoPoint(latitude: 3, longitude: 3),
      );
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.entryLocation!.latitude, 1);
      expect(merged.exitLocation!.latitude, 3);
    });
  });
```

Add the import the `GeoPoint` type needs (match whatever `dive.dart` imports for it — check the top of `lib/features/dive_log/domain/entities/dive.dart` and import the same file in the test).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: FAIL — metadata fields null / notes empty.

- [ ] **Step 3: Write minimal implementation**

Add helpers:

```dart
  T? _firstNonNull<T>(List<Dive> sorted, T? Function(Dive) pick) {
    for (final d in sorted) {
      final v = pick(d);
      if (v != null) return v;
    }
    return null;
  }

  T? _lastNonNull<T>(List<Dive> sorted, T? Function(Dive) pick) {
    for (final d in sorted.reversed) {
      final v = pick(d);
      if (v != null) return v;
    }
    return null;
  }

  String _mergedNotes(List<Dive> sorted) => sorted
      .map((d) => d.notes.trim())
      .where((n) => n.isNotEmpty)
      .join('\n\n');
```

Extend the `Dive(...)` construction in `build()` with every field listed in this task's Produces block, following this shape (write ALL of them — the full block is long but mechanical):

```dart
      diveNumber: first.diveNumber,
      surfaceInterval: first.surfaceInterval,
      diveMode: first.diveMode,
      isPlanned: first.isPlanned,
      notes: _mergedNotes(sorted),
      isFavorite: sorted.any((d) => d.isFavorite),
      entryLocation: _firstNonNull(sorted, (d) => d.entryLocation),
      exitLocation: _lastNonNull(sorted, (d) => d.exitLocation),
      site: _firstNonNull(sorted, (d) => d.site),
      diveCenter: _firstNonNull(sorted, (d) => d.diveCenter),
      trip: _firstNonNull(sorted, (d) => d.trip),
      tripId: _firstNonNull(sorted, (d) => d.tripId),
      buddy: _firstNonNull(sorted, (d) => d.buddy),
      diveMaster: _firstNonNull(sorted, (d) => d.diveMaster),
      rating: _firstNonNull(sorted, (d) => d.rating),
      visibility: _firstNonNull(sorted, (d) => d.visibility),
      waterTemp: _firstNonNull(sorted, (d) => d.waterTemp),
      airTemp: _firstNonNull(sorted, (d) => d.airTemp),
      currentDirection: _firstNonNull(sorted, (d) => d.currentDirection),
      currentStrength: _firstNonNull(sorted, (d) => d.currentStrength),
      swellHeight: _firstNonNull(sorted, (d) => d.swellHeight),
      entryMethod: _firstNonNull(sorted, (d) => d.entryMethod),
      exitMethod: _firstNonNull(sorted, (d) => d.exitMethod),
      waterType: _firstNonNull(sorted, (d) => d.waterType),
      altitude: _firstNonNull(sorted, (d) => d.altitude),
      surfacePressure: _firstNonNull(sorted, (d) => d.surfacePressure),
      gradientFactorLow: _firstNonNull(sorted, (d) => d.gradientFactorLow),
      gradientFactorHigh: _firstNonNull(sorted, (d) => d.gradientFactorHigh),
      decoAlgorithm: _firstNonNull(sorted, (d) => d.decoAlgorithm),
      decoConservatism: _firstNonNull(sorted, (d) => d.decoConservatism),
      diveComputerModel: _firstNonNull(sorted, (d) => d.diveComputerModel),
      diveComputerSerial: _firstNonNull(sorted, (d) => d.diveComputerSerial),
      diveComputerFirmware: _firstNonNull(
        sorted,
        (d) => d.diveComputerFirmware,
      ),
      weightAmount: _firstNonNull(sorted, (d) => d.weightAmount),
      weightType: _firstNonNull(sorted, (d) => d.weightType),
      setpointLow: _firstNonNull(sorted, (d) => d.setpointLow),
      setpointHigh: _firstNonNull(sorted, (d) => d.setpointHigh),
      setpointDeco: _firstNonNull(sorted, (d) => d.setpointDeco),
      scrType: _firstNonNull(sorted, (d) => d.scrType),
      scrInjectionRate: _firstNonNull(sorted, (d) => d.scrInjectionRate),
      scrAdditionRatio: _firstNonNull(sorted, (d) => d.scrAdditionRatio),
      scrOrificeSize: _firstNonNull(sorted, (d) => d.scrOrificeSize),
      assumedVo2: _firstNonNull(sorted, (d) => d.assumedVo2),
      diluentGas: _firstNonNull(sorted, (d) => d.diluentGas),
      loopO2Min: _firstNonNull(sorted, (d) => d.loopO2Min),
      loopO2Max: _firstNonNull(sorted, (d) => d.loopO2Max),
      loopO2Avg: _firstNonNull(sorted, (d) => d.loopO2Avg),
      loopVolume: _firstNonNull(sorted, (d) => d.loopVolume),
      scrubber: _firstNonNull(sorted, (d) => d.scrubber),
      importSource: _firstNonNull(sorted, (d) => d.importSource),
      importId: _firstNonNull(sorted, (d) => d.importId),
      windSpeed: _firstNonNull(sorted, (d) => d.windSpeed),
      windDirection: _firstNonNull(sorted, (d) => d.windDirection),
      cloudCover: _firstNonNull(sorted, (d) => d.cloudCover),
      precipitation: _firstNonNull(sorted, (d) => d.precipitation),
      humidity: _firstNonNull(sorted, (d) => d.humidity),
      weatherDescription: _firstNonNull(sorted, (d) => d.weatherDescription),
      weatherSource: _firstNonNull(sorted, (d) => d.weatherSource),
      weatherFetchedAt: _firstNonNull(sorted, (d) => d.weatherFetchedAt),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/features/dive_log/domain/services test/features/dive_log/domain/services
git commit -m "feat(dive-merge): first-non-empty metadata merge (#449)"
```

### Task 5: Entity collections — tanks (+ID map), weights, custom fields, tags, dive types, equipment, sightings

**Files:**
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart`
- Test: `test/features/dive_log/domain/services/dive_merge_builder_test.dart`

**Interfaces:**
- Consumes: Tasks 2-4.
- Produces: `mergedDive.tanks` (all tanks, chronological, fresh ids, `order` re-sequenced from 0), `result.tankIdMap` (old id -> new id), `mergedDive.weights` (first dive's set; else first source with any; fresh ids, `diveId` = merged id), `mergedDive.customFields` (union by `key`, first wins, fresh ids, `sortOrder` re-sequenced), `mergedDive.tags` (union by `tag.id` from `tagsByDive`), `mergedDive.diveTypeIds` (ordered union), `mergedDive.equipment` (union by `EquipmentItem.id`), `result.mergedSightings` (union from `sightingsByDive`; same `speciesId` merged: counts summed, non-empty notes joined with `'; '`; fresh ids). `mergedDive.profile` stays EMPTY (the service copies profile rows directly to preserve per-row `computerId`/`isPrimary`).

- [ ] **Step 1: Write the failing test** (append)

```dart
  group('build - collections', () {
    test('tanks keep chronological order, get fresh ids and an id map', () {
      var n = 0;
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        tanks: [
          const DiveTank(id: 'tA1', volume: 11.1, order: 0),
        ],
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        tanks: [
          const DiveTank(id: 'tB1', volume: 15.0, order: 0),
        ],
      );
      final result = builder.build([b, a], idGenerator: () => 'gen-${n++}');
      final tanks = result.mergedDive.tanks;
      expect(tanks, hasLength(2));
      expect(tanks[0].volume, 11.1); // a's tank first
      expect(tanks[0].order, 0);
      expect(tanks[1].order, 1);
      expect(result.tankIdMap['tA1'], tanks[0].id);
      expect(result.tankIdMap['tB1'], tanks[1].id);
      expect(tanks[0].id, isNot('tA1')); // fresh id
    });

    test('weights come from the first dive that has any', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9));
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        weights: [
          const DiveWeight(
            id: 'w1',
            diveId: 'b',
            weightType: WeightType.belt,
            amountKg: 6,
          ),
        ],
      );
      final result = builder.build([a, b]);
      expect(result.mergedDive.weights, hasLength(1));
      expect(result.mergedDive.weights.single.amountKg, 6);
      expect(result.mergedDive.weights.single.diveId, result.mergedDive.id);
      expect(result.mergedDive.weights.single.id, isNot('w1'));
    });

    test('custom fields union by key (first wins); dive types union', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9)).copyWith(
        customFields: [
          const DiveCustomField(id: 'c1', key: 'boat', value: 'Sea Cat'),
        ],
        diveTypeIds: ['recreational', 'night'],
      );
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10)).copyWith(
        customFields: [
          const DiveCustomField(id: 'c2', key: 'boat', value: 'Other'),
          const DiveCustomField(id: 'c3', key: 'guide', value: 'Maria'),
        ],
        diveTypeIds: ['recreational', 'drift'],
      );
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.customFields, hasLength(2));
      expect(
        merged.customFields.firstWhere((f) => f.key == 'boat').value,
        'Sea Cat',
      );
      expect(merged.diveTypeIds, ['recreational', 'night', 'drift']);
    });

    test('sightings merge same species: counts summed, notes joined', () {
      final a = dive('a', entry: DateTime.utc(2026, 7, 1, 9));
      final b = dive('b', entry: DateTime.utc(2026, 7, 1, 10));
      final result = builder.build(
        [a, b],
        sightingsByDive: {
          'a': [
            const MarineSighting(
              id: 's1',
              speciesId: 'turtle',
              speciesName: 'Green Turtle',
              count: 2,
              notes: 'near reef',
            ),
          ],
          'b': [
            const MarineSighting(
              id: 's2',
              speciesId: 'turtle',
              speciesName: 'Green Turtle',
              count: 1,
            ),
            const MarineSighting(
              id: 's3',
              speciesId: 'ray',
              speciesName: 'Eagle Ray',
            ),
          ],
        },
      );
      expect(result.mergedSightings, hasLength(2));
      final turtle = result.mergedSightings.firstWhere(
        (s) => s.speciesId == 'turtle',
      );
      expect(turtle.count, 3);
      expect(turtle.notes, 'near reef');
      expect(turtle.id, isNot('s1'));
    });
  });
```

Add test imports as needed: `dive_weight.dart`, `dive_custom_field.dart` (match the entity import paths from section 1's Interfaces; `WeightType` lives with `DiveWeight` — check `lib/features/dive_log/domain/entities/dive_weight.dart`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: FAIL — collections empty on merged dive.

- [ ] **Step 3: Write minimal implementation**

In `build()`, before constructing `mergedDive` (the merged dive id must exist first — hoist it):

```dart
    final mergedId = idGen();

    // Tanks: all kept, chronological, fresh ids, order re-sequenced.
    final tankIdMap = <String, String>{};
    final mergedTanks = <DiveTank>[];
    var tankOrder = 0;
    for (final d in sorted) {
      final tanksInOrder = [...d.tanks]
        ..sort((x, y) => x.order.compareTo(y.order));
      for (final tank in tanksInOrder) {
        final freshId = idGen();
        tankIdMap[tank.id] = freshId;
        mergedTanks.add(tank.copyWith(id: freshId, order: tankOrder++));
      }
    }

    // Weights: first source that has any (avoids double-counting lead).
    final weightSource = sorted.firstWhere(
      (d) => d.weights.isNotEmpty,
      orElse: () => sorted.first,
    );
    final mergedWeights = [
      for (final w in weightSource.weights)
        DiveWeight(
          id: idGen(),
          diveId: mergedId,
          weightType: w.weightType,
          amountKg: w.amountKg,
          notes: w.notes,
        ),
    ];

    // Custom fields: union by key, first-in-order wins.
    final seenKeys = <String>{};
    final mergedCustomFields = <DiveCustomField>[];
    for (final d in sorted) {
      for (final f in d.customFields) {
        if (seenKeys.add(f.key)) {
          mergedCustomFields.add(
            DiveCustomField(
              id: idGen(),
              key: f.key,
              value: f.value,
              sortOrder: mergedCustomFields.length,
            ),
          );
        }
      }
    }

    // Tags: union by id, chronological order.
    final seenTagIds = <String>{};
    final mergedTags = <Tag>[
      for (final d in sorted)
        for (final t in tagsByDive[d.id] ?? const <Tag>[])
          if (seenTagIds.add(t.id)) t,
    ];

    // Dive types: ordered union (first dive's representative type stays first).
    final mergedDiveTypeIds = <String>[];
    for (final d in sorted) {
      for (final t in d.diveTypeIds) {
        if (!mergedDiveTypeIds.contains(t)) mergedDiveTypeIds.add(t);
      }
    }

    // Equipment: union by item id.
    final seenEquipment = <String>{};
    final mergedEquipment = [
      for (final d in sorted)
        for (final e in d.equipment)
          if (seenEquipment.add(e.id)) e,
    ];

    // Sightings: union; same species merged (counts summed, notes joined).
    final bySpecies = <String, MarineSighting>{};
    for (final d in sorted) {
      for (final s in sightingsByDive[d.id] ?? const <MarineSighting>[]) {
        final existing = bySpecies[s.speciesId];
        if (existing == null) {
          bySpecies[s.speciesId] = MarineSighting(
            id: idGen(),
            speciesId: s.speciesId,
            speciesName: s.speciesName,
            count: s.count,
            notes: s.notes,
          );
        } else {
          final notes = [existing.notes, s.notes]
              .where((n) => n.trim().isNotEmpty)
              .join('; ');
          bySpecies[s.speciesId] = MarineSighting(
            id: existing.id,
            speciesId: existing.speciesId,
            speciesName: existing.speciesName,
            count: existing.count + s.count,
            notes: notes,
          );
        }
      }
    }
```

Wire into the `Dive(...)` construction (`id: mergedId` replaces `id: idGen()`) plus `tanks: mergedTanks, weights: mergedWeights, customFields: mergedCustomFields, tags: mergedTags, diveTypeIds: mergedDiveTypeIds, equipment: mergedEquipment`, and return `tankIdMap: tankIdMap, mergedSightings: bySpecies.values.toList()`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: PASS (whole file).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/features/dive_log/domain/services test/features/dive_log/domain/services
git commit -m "feat(dive-merge): collection merging with tank id map (#449)"
```

---

## Phase 2 — Snapshot + transactional service (`DiveMergeService`)

### Task 6: `DiveMergeSnapshot` + snapshot capture

**Files:**
- Create: `lib/features/dive_log/data/services/dive_merge_snapshot.dart`
- Create: `lib/features/dive_log/data/services/dive_merge_service.dart`
- Test: `test/features/dive_log/data/services/dive_merge_service_test.dart` (new)

**Interfaces:**
- Consumes: Drift row classes from `package:submersion/core/database/database.dart`; `DiveRepository` from `dive_repository_impl.dart`.
- Produces:
  - `class DiveMergeSnapshot` — plain data: `String mergedDiveId` plus captured Drift rows: `List<Dive> diveRows`, `List<DiveProfile> profileRows`, `List<DiveTank> tankRows`, `List<DiveWeight> weightRows`, `List<DiveCustomField> customFieldRows`, `List<DiveEquipmentData> equipmentRows`, `List<DiveDiveType> diveTypeRows`, `List<DiveTag> tagRows`, `List<DiveBuddy> buddyRows`, `List<Sighting> sightingRows`, `List<DiveProfileEvent> eventRows`, `List<GasSwitch> gasSwitchRows`, `List<TankPressureProfile> tankPressureRows`, `List<DiveDataSource> dataSourceRows`, `List<TideRecord> tideRows`, `Map<String, String> mediaDiveIds` (media id -> original dive id). NOTE: confirm each generated row-class name against `lib/core/database/database.g.dart` (Drift derives them from the table class; tables whose names don't end in `s`, like `DiveEquipment` and `Media`, get suffixed names such as `DiveEquipmentData`/`MediaData`).
  - `class DiveMergeService { DiveMergeService(this._diveRepo); Future<DiveMergeSnapshot> captureSnapshot(List<String> diveIds, String mergedDiveId); }` — pure reads, no mutation.
- Test seeding helper `seedDive(...)` produced here is reused by Tasks 7-8.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/data/services/dive_merge_service_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveMergeService service;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    service = DiveMergeService(diveRepo);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Seeds a dive with one tank, a 3-sample profile, and link rows in the
  /// tables createDive does not cover (buddy, sighting, event, gas switch,
  /// tank pressure, data source, media).
  Future<void> seedDive(
    String id, {
    required DateTime entry,
    int runtimeMin = 30,
    double depth = 10,
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: Duration(minutes: runtimeMin),
        maxDepth: depth,
        tanks: [domain.DiveTank(id: 'tank-$id', volume: 11.1)],
        profile: [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: runtimeMin * 30, depth: depth),
          domain.DiveProfilePoint(timestamp: runtimeMin * 60, depth: 0),
        ],
      ),
    );
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion.insert(
            id: 'buddy-$id',
            diveId: id,
            buddyId: 'buddy-cat-1',
            createdAt: 0,
          ),
        );
    await db
        .into(db.sightings)
        .insert(
          SightingsCompanion.insert(
            id: 'sight-$id',
            diveId: id,
            speciesId: 'turtle',
          ),
        );
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion.insert(
            id: 'event-$id',
            diveId: id,
            timestamp: 60,
            eventType: 'gaschange',
            createdAt: 0,
          ),
        );
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion.insert(
            id: 'switch-$id',
            diveId: id,
            timestamp: 60,
            tankId: 'tank-$id',
            createdAt: 0,
          ),
        );
    await db
        .into(db.tankPressureProfiles)
        .insert(
          TankPressureProfilesCompanion.insert(
            id: 'tp-$id',
            diveId: id,
            tankId: 'tank-$id',
            timestamp: 60,
            pressure: 180,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            importedAt: DateTime.utc(2026, 7, 1),
            createdAt: DateTime.utc(2026, 7, 1),
          ).copyWith(isPrimary: const Value(true)),
        );
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            id: 'media-$id',
            filePath: '/photos/$id.jpg',
            createdAt: 0,
            updatedAt: 0,
          ).copyWith(diveId: Value(id)),
        );
  }

  group('captureSnapshot', () {
    test('captures every child table and media pointers', () async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
      await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10));

      final snap = await service.captureSnapshot(['a', 'b'], 'merged-1');

      expect(snap.mergedDiveId, 'merged-1');
      expect(snap.diveRows, hasLength(2));
      expect(snap.profileRows, hasLength(6));
      expect(snap.tankRows, hasLength(2));
      expect(snap.buddyRows, hasLength(2));
      expect(snap.sightingRows, hasLength(2));
      expect(snap.eventRows, hasLength(2));
      expect(snap.gasSwitchRows, hasLength(2));
      expect(snap.tankPressureRows, hasLength(2));
      expect(snap.dataSourceRows, hasLength(2));
      expect(snap.mediaDiveIds, {'media-a': 'a', 'media-b': 'b'});
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/dive_merge_service_test.dart`
Expected: FAIL — `dive_merge_service.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

`dive_merge_snapshot.dart` — the data class exactly as in Interfaces (constructor with all required named fields, all `final`). Then the service:

```dart
// lib/features/dive_log/data/services/dive_merge_service.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../domain/services/dive_merge_builder.dart';
import '../repositories/dive_repository_impl.dart';
import 'dive_merge_snapshot.dart';

/// Applies and undoes sequential dive combines (#449).
/// Mirrors the BulkDiveEditService shape: snapshot -> one transaction ->
/// one SyncEventBus notify.
class DiveMergeService {
  DiveMergeService(this._diveRepo);

  final DiveRepository _diveRepo;
  final _uuid = const Uuid();
  final _builder = const DiveMergeBuilder();

  AppDatabase get _db => DatabaseService.instance.database;

  Future<DiveMergeSnapshot> captureSnapshot(
    List<String> diveIds,
    String mergedDiveId,
  ) async {
    Future<List<T>> byDive<T>(
      ResultSetImplementation<dynamic, T> table,
      Expression<String> Function(dynamic) diveId,
    ) => (_db.select(table)..where((t) => diveId(t).isIn(diveIds))).get();

    final mediaRows = await (_db.select(
      _db.media,
    )..where((t) => t.diveId.isIn(diveIds))).get();

    return DiveMergeSnapshot(
      mergedDiveId: mergedDiveId,
      diveRows: await (_db.select(
        _db.dives,
      )..where((t) => t.id.isIn(diveIds))).get(),
      profileRows: await byDive(_db.diveProfiles, (t) => t.diveId),
      tankRows: await byDive(_db.diveTanks, (t) => t.diveId),
      weightRows: await byDive(_db.diveWeights, (t) => t.diveId),
      customFieldRows: await byDive(_db.diveCustomFields, (t) => t.diveId),
      equipmentRows: await byDive(_db.diveEquipment, (t) => t.diveId),
      diveTypeRows: await byDive(_db.diveDiveTypes, (t) => t.diveId),
      tagRows: await byDive(_db.diveTags, (t) => t.diveId),
      buddyRows: await byDive(_db.diveBuddies, (t) => t.diveId),
      sightingRows: await byDive(_db.sightings, (t) => t.diveId),
      eventRows: await byDive(_db.diveProfileEvents, (t) => t.diveId),
      gasSwitchRows: await byDive(_db.gasSwitches, (t) => t.diveId),
      tankPressureRows: await byDive(_db.tankPressureProfiles, (t) => t.diveId),
      dataSourceRows: await byDive(_db.diveDataSources, (t) => t.diveId),
      tideRows: await byDive(_db.tideRecords, (t) => t.diveId),
      mediaDiveIds: {for (final m in mediaRows) m.id: m.diveId!},
    );
  }
}
```

If the generic `byDive` helper fights Drift's type system, unroll it into per-table `(_db.select(_db.<table>)..where((t) => t.diveId.isIn(diveIds))).get()` calls — 15 straightforward lines beat clever generics.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/services/dive_merge_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/data/services test/features/dive_log/data/services/dive_merge_service_test.dart
git commit -m "feat(dive-merge): DiveMergeSnapshot capture (#449)"
```

### Task 7: `DiveMergeService.apply` — transactional merge

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_merge_service.dart`
- Test: `test/features/dive_log/data/services/dive_merge_service_test.dart`

**Interfaces:**
- Consumes: `DiveMergeBuilder.build` (Task 5), `captureSnapshot` (Task 6), `DiveRepository.getDivesByIds/createDive/bulkDeleteDives`, `TagRepository.getTagsForDives`, `SyncRepository.markRecordPending`, `SyncEventBus.notifyLocalChange`.
- Produces: `class DiveMergeOutcome { final domain.Dive mergedDive; final DiveMergeSnapshot snapshot; }` and `Future<DiveMergeOutcome> apply(List<String> diveIds)`. Throws `ArgumentError` for non-sequential selections. Guarantees on success: merged dive + all children persisted; sources deleted with `deletion_log` tombstones; media re-pointed; carried data sources `isPrimary = false`; gap represented by 0-depth profile rows and `'surface'` events.

- [ ] **Step 1: Write the failing tests** (append; reuse `seedDive`)

```dart
  group('apply', () {
    test('creates merged dive, copies children, deletes sources', () async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9), depth: 10);
      await seedDive(
        'b',
        entry: DateTime.utc(2026, 7, 1, 10),
        depth: 20,
        runtimeMin: 20,
      );

      final outcome = await service.apply(['a', 'b']);
      final mergedId = outcome.mergedDive.id;

      // Sources gone, tombstones logged.
      final remaining = await db.select(db.dives).get();
      expect(remaining.map((r) => r.id), [mergedId]);
      final tombstones = await (db.select(
        db.deletionLog,
      )..where((t) => t.entityType.equals('dives'))).get();
      expect(tombstones.map((t) => t.recordId).toSet(), {'a', 'b'});

      // Profile: 3 samples per source, re-based, plus 2 gap samples.
      final profile =
          await (db.select(db.diveProfiles)
                ..where((t) => t.diveId.equals(mergedId))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();
      expect(profile, hasLength(8));
      // Dive a ends at 1800s; dive b starts at 3600s; gap samples inside.
      final gapSamples = profile.where(
        (p) => p.timestamp > 1800 && p.timestamp < 3600,
      );
      expect(gapSamples, hasLength(2));
      expect(gapSamples.every((p) => p.depth == 0), isTrue);
      // b's first sample re-based to 3600.
      expect(profile.where((p) => p.timestamp == 3600), isNotEmpty);

      // Surface events at the gap boundaries.
      final events = await (db.select(db.diveProfileEvents)
            ..where((t) => t.diveId.equals(mergedId)))
          .get();
      expect(
        events.where((e) => e.eventType == 'surface').map((e) => e.timestamp),
        containsAll([1800, 3600]),
      );

      // Gas switch re-pointed to a NEW tank id belonging to the merged dive.
      final mergedTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(mergedTanks, hasLength(2));
      final switches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(switches, hasLength(2));
      expect(
        mergedTanks.map((t) => t.id).toSet().containsAll(
          switches.map((s) => s.tankId),
        ),
        isTrue,
      );

      // Tank pressures re-based and re-pointed.
      final pressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(pressures.map((p) => p.timestamp).toSet(), {60, 3660});

      // Buddies and sightings carried; same-species sightings merged.
      final buddies = await (db.select(
        db.diveBuddies,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(buddies.map((b) => b.buddyId).toSet(), {'buddy-cat-1'});
      final sightings = await (db.select(
        db.sightings,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(sightings, hasLength(1));
      expect(sightings.single.count, 2);

      // Data sources carried, all non-primary.
      final sources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(mergedId))).get();
      expect(sources, hasLength(2));
      expect(sources.every((s) => !s.isPrimary), isTrue);

      // Media re-pointed, not orphaned.
      final media = await db.select(db.media).get();
      expect(media.every((m) => m.diveId == mergedId), isTrue);

      // Merged stats.
      final mergedRow = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(mergedId))).getSingle();
      expect(mergedRow.maxDepth, 20);
      expect(mergedRow.runtime, 80 * 60); // if stored in seconds
    });

    test('rejects overlapping selections', () async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9), runtimeMin: 90);
      await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10));
      expect(() => service.apply(['a', 'b']), throwsArgumentError);
      expect(await db.select(db.dives).get(), hasLength(2)); // untouched
    });

    test('rejects when a selected dive no longer exists; DB untouched',
        () async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
      // 'ghost' was never created -> only 1 dive loads -> tooFewDives.
      expect(() => service.apply(['a', 'ghost']), throwsArgumentError);
      expect(await db.select(db.dives).get(), hasLength(1));
      expect(await db.select(db.deletionLog).get(), isEmpty);
    });
  });
```

NOTE for the `runtime` assertion: check how `createDive` persists `runtime` (seconds int vs millis) in `dive_repository_impl.dart` around line 708 and assert accordingly.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/dive_merge_service_test.dart`
Expected: FAIL — `The method 'apply' isn't defined`.

- [ ] **Step 3: Write the implementation**

Add to `DiveMergeService` (new imports: `dart:math` not needed; add `../../../tags/data/repositories/tag_repository.dart`, `../../../../core/data/repositories/sync_repository.dart`, `../../../../core/services/sync/sync_event_bus.dart`, `../../domain/entities/dive.dart` as `domain`):

```dart
class DiveMergeOutcome {
  const DiveMergeOutcome({required this.mergedDive, required this.snapshot});
  final domain.Dive mergedDive;
  final DiveMergeSnapshot snapshot;
}

  final _sync = SyncRepository();
  final _tagRepository = TagRepository();

  Future<DiveMergeOutcome> apply(List<String> diveIds) async {
    final sources = await _diveRepo.getDivesByIds(diveIds);
    final tagsByDive = await _tagRepository.getTagsForDives(diveIds);

    // Sightings from rows (speciesName not needed for persistence).
    final sightingRows = await (_db.select(
      _db.sightings,
    )..where((t) => t.diveId.isIn(diveIds))).get();
    final sightingsByDive = <String, List<domain.MarineSighting>>{};
    for (final row in sightingRows) {
      sightingsByDive.putIfAbsent(row.diveId, () => []).add(
        domain.MarineSighting(
          id: row.id,
          speciesId: row.speciesId,
          speciesName: '',
          count: row.count,
          notes: row.notes,
        ),
      );
    }

    final result = _builder.build(
      sources,
      tagsByDive: tagsByDive,
      sightingsByDive: sightingsByDive,
      idGenerator: _uuid.v4,
    );
    final mergedId = result.mergedDive.id;
    final snapshot = await captureSnapshot(diveIds, mergedId);
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // 1. Merged dive + entity-carried children (tanks, weights, custom
      //    fields, profile=[], equipment, tags, dive types).
      await _diveRepo.createDive(result.mergedDive);

      // 2. Profile rows copied directly (preserves computerId/isPrimary/
      //    temperature/sensor columns), re-based onto the merged timeline.
      await _db.batch((batch) {
        for (final row in snapshot.profileRows) {
          final offset = result.segmentOffsetsSeconds[row.diveId] ?? 0;
          batch.insert(
            _db.diveProfiles,
            row
                .toCompanion(false)
                .copyWith(
                  id: Value(_uuid.v4()),
                  diveId: Value(mergedId),
                  timestamp: Value(row.timestamp + offset),
                ),
          );
        }
        // 3. Synthesized 0-depth samples at gap boundaries (skip tiny gaps).
        for (final gap in result.gaps) {
          if (gap.endSeconds - gap.startSeconds < 2) continue;
          for (final ts in [gap.startSeconds + 1, gap.endSeconds - 1]) {
            batch.insert(
              _db.diveProfiles,
              DiveProfilesCompanion.insert(
                id: _uuid.v4(),
                diveId: mergedId,
                timestamp: ts,
                depth: 0,
              ),
            );
          }
        }
      });

      // 4. Surface events at each gap boundary.
      for (final gap in result.gaps) {
        for (final ts in [gap.startSeconds, gap.endSeconds]) {
          final eventId = _uuid.v4();
          await _db
              .into(_db.diveProfileEvents)
              .insert(
                DiveProfileEventsCompanion.insert(
                  id: eventId,
                  diveId: mergedId,
                  timestamp: ts,
                  eventType: 'surface',
                ).copyWith(
                  severity: const Value('info'),
                  depth: const Value(0),
                  source: const Value('app'),
                  createdAt: Value(now),
                ),
              );
          await _sync.markRecordPending(
            entityType: 'diveProfileEvents',
            recordId: eventId,
            localUpdatedAt: now,
          );
        }
      }

      // 5. Existing profile events, re-based, tank text-refs remapped.
      for (final row in snapshot.eventRows) {
        final offset = result.segmentOffsetsSeconds[row.diveId] ?? 0;
        final eventId = _uuid.v4();
        await _db
            .into(_db.diveProfileEvents)
            .insert(
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(eventId),
                    diveId: Value(mergedId),
                    timestamp: Value(row.timestamp + offset),
                    tankId: Value(
                      row.tankId == null
                          ? null
                          : result.tankIdMap[row.tankId] ?? row.tankId,
                    ),
                  ),
            );
        await _sync.markRecordPending(
          entityType: 'diveProfileEvents',
          recordId: eventId,
          localUpdatedAt: now,
        );
      }

      // 6. Gas switches, re-based + tank FK remapped (drop unmappable).
      for (final row in snapshot.gasSwitchRows) {
        final newTankId = result.tankIdMap[row.tankId];
        if (newTankId == null) continue;
        final offset = result.segmentOffsetsSeconds[row.diveId] ?? 0;
        final switchId = _uuid.v4();
        await _db
            .into(_db.gasSwitches)
            .insert(
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(switchId),
                    diveId: Value(mergedId),
                    tankId: Value(newTankId),
                    timestamp: Value(row.timestamp + offset),
                  ),
            );
        await _sync.markRecordPending(
          entityType: 'gasSwitches',
          recordId: switchId,
          localUpdatedAt: now,
        );
      }

      // 7. Tank pressure series, re-based + remapped (parent-dive sync
      //    pattern: no per-row pending).
      await _db.batch((batch) {
        for (final row in snapshot.tankPressureRows) {
          final newTankId = result.tankIdMap[row.tankId];
          if (newTankId == null) continue;
          final offset = result.segmentOffsetsSeconds[row.diveId] ?? 0;
          batch.insert(
            _db.tankPressureProfiles,
            row
                .toCompanion(false)
                .copyWith(
                  id: Value(_uuid.v4()),
                  diveId: Value(mergedId),
                  tankId: Value(newTankId),
                  timestamp: Value(row.timestamp + offset),
                ),
          );
        }
      });

      // 8. Buddies: union by buddyId, chronological (sortedSources order).
      final seenBuddies = <String>{};
      for (final source in result.sortedSources) {
        for (final row in snapshot.buddyRows.where(
          (r) => r.diveId == source.id,
        )) {
          if (!seenBuddies.add(row.buddyId)) continue;
          final buddyRowId = _uuid.v4();
          await _db
              .into(_db.diveBuddies)
              .insert(
                row
                    .toCompanion(false)
                    .copyWith(
                      id: Value(buddyRowId),
                      diveId: Value(mergedId),
                      createdAt: Value(now),
                    ),
              );
          await _sync.markRecordPending(
            entityType: 'diveBuddies',
            recordId: buddyRowId,
            localUpdatedAt: now,
          );
        }
      }

      // 9. Merged sightings (already unioned by the builder).
      for (final s in result.mergedSightings) {
        await _db
            .into(_db.sightings)
            .insert(
              SightingsCompanion.insert(
                id: s.id,
                diveId: mergedId,
                speciesId: s.speciesId,
              ).copyWith(count: Value(s.count), notes: Value(s.notes)),
            );
        await _sync.markRecordPending(
          entityType: 'sightings',
          recordId: s.id,
          localUpdatedAt: now,
        );
      }

      // 10. Data sources carried as provenance; NEVER primary (a merged
      //     profile is user-authored — reparse must not rewrite it).
      for (final row in snapshot.dataSourceRows) {
        await _db
            .into(_db.diveDataSources)
            .insert(
              row
                  .toCompanion(false)
                  .copyWith(
                    id: Value(_uuid.v4()),
                    diveId: Value(mergedId),
                    isPrimary: const Value(false),
                  ),
            );
      }
      // Match saveComputerReading's sync handling for data sources — read
      // dive_repository_impl.dart:4437 and mirror any markRecordPending it
      // performs (it may rely on the parent-dive pending record only).

      // 11. Tide record: first dive's only.
      final firstTide = snapshot.tideRows
          .where((r) => r.diveId == result.sortedSources.first.id)
          .toList();
      if (firstTide.isNotEmpty) {
        final tideId = _uuid.v4();
        await _db
            .into(_db.tideRecords)
            .insert(
              firstTide.first
                  .toCompanion(false)
                  .copyWith(id: Value(tideId), diveId: Value(mergedId)),
            );
        await _sync.markRecordPending(
          entityType: 'tideRecords',
          recordId: tideId,
          localUpdatedAt: now,
        );
      }

      // 12. Re-point media BEFORE deleting sources (FK is setNull).
      for (final mediaId in snapshot.mediaDiveIds.keys) {
        await (_db.update(_db.media)..where((t) => t.id.equals(mediaId)))
            .write(
              MediaCompanion(
                diveId: Value(mergedId),
                updatedAt: Value(now),
              ),
            );
        await _sync.markRecordPending(
          entityType: 'media',
          recordId: mediaId,
          localUpdatedAt: now,
        );
      }

      // 13. Delete sources through the tombstone-logging path.
      await _diveRepo.bulkDeleteDives(diveIds);
    });

    SyncEventBus.notifyLocalChange();
    return DiveMergeOutcome(mergedDive: result.mergedDive, snapshot: snapshot);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/services/dive_merge_service_test.dart`
Expected: PASS. If the `runtime` column assertion fails, fix the expected unit (seconds vs millis) per `createDive`, not the implementation.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/features/dive_log/data/services test/features/dive_log/data/services
git commit -m "feat(dive-merge): transactional apply with gap synthesis (#449)"
```

### Task 8: `DiveMergeService.undo`

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_merge_service.dart`
- Test: `test/features/dive_log/data/services/dive_merge_service_test.dart`

**Interfaces:**
- Consumes: Task 7's `apply` outcome.
- Produces: `Future<void> undo(DiveMergeSnapshot snapshot)` — deletes the merged dive (tombstone), re-inserts every captured row verbatim with ORIGINAL ids (`row.toCompanion(false)`), restores media `diveId` pointers, marks restored dives + child rows pending, one notify. Safe under HLC: re-inserts carry newer HLC than the merge's tombstones.

- [ ] **Step 1: Write the failing test** (append)

```dart
  group('undo', () {
    test('restores sources byte-for-byte and removes the merged dive',
        () async {
      await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
      await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10));
      final before = await (db.select(
        db.dives,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

      final outcome = await service.apply(['a', 'b']);
      await service.undo(outcome.snapshot);

      final after = await (db.select(
        db.dives,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(after.map((r) => r.id), ['a', 'b']);
      // Every column identical except updatedAt (bumped for sync LWW).
      // Drift ROW classes have value equality + copyWith; companions do not.
      for (var i = 0; i < before.length; i++) {
        expect(
          after[i].copyWith(updatedAt: 0),
          before[i].copyWith(updatedAt: 0),
        );
      }

      // Children restored with original ids.
      final tanks = await db.select(db.diveTanks).get();
      expect(tanks.map((t) => t.id).toSet(), {'tank-a', 'tank-b'});
      final buddies = await db.select(db.diveBuddies).get();
      expect(buddies.map((b) => b.id).toSet(), {'buddy-a', 'buddy-b'});
      final events = await db.select(db.diveProfileEvents).get();
      expect(events.map((e) => e.id).toSet(), {'event-a', 'event-b'});
      final sources = await db.select(db.diveDataSources).get();
      expect(sources.every((s) => s.isPrimary), isTrue); // original flag back

      // Media pointers restored.
      final media = await (db.select(
        db.media,
      )..where((t) => t.id.equals('media-a'))).getSingle();
      expect(media.diveId, 'a');

      // Merged dive tombstoned.
      final tombstones = await (db.select(
        db.deletionLog,
      )..where((t) => t.recordId.equals(outcome.mergedDive.id))).get();
      expect(tombstones, isNotEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/dive_merge_service_test.dart`
Expected: FAIL — `The method 'undo' isn't defined`.

- [ ] **Step 3: Write the implementation**

```dart
  /// Restores the source dives exactly and removes the merged dive.
  Future<void> undo(DiveMergeSnapshot snapshot) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Remove the merged dive (children cascade; tombstone logged so the
      // merge's remote copies are deleted too).
      await _diveRepo.deleteDive(snapshot.mergedDiveId);

      // Re-insert dives with ORIGINAL ids; newer HLC beats the tombstones.
      for (final row in snapshot.diveRows) {
        await _db
            .into(_db.dives)
            .insert(row.toCompanion(false).copyWith(updatedAt: Value(now)));
        await _sync.markRecordPending(
          entityType: 'dives',
          recordId: row.id,
          localUpdatedAt: now,
        );
      }

      // Child rows verbatim (original ids never collide: merged children
      // all had fresh ids).
      await _db.batch((batch) {
        for (final r in snapshot.profileRows) {
          batch.insert(_db.diveProfiles, r.toCompanion(false));
        }
        for (final r in snapshot.tankPressureRows) {
          batch.insert(_db.tankPressureProfiles, r.toCompanion(false));
        }
        for (final r in snapshot.dataSourceRows) {
          batch.insert(_db.diveDataSources, r.toCompanion(false));
        }
        for (final r in snapshot.tideRows) {
          batch.insert(_db.tideRecords, r.toCompanion(false));
        }
        for (final r in snapshot.equipmentRows) {
          batch.insert(_db.diveEquipment, r.toCompanion(false));
        }
      });
      for (final r in snapshot.tankRows) {
        await _db.into(_db.diveTanks).insert(r.toCompanion(false));
        await _sync.markRecordPending(
          entityType: 'diveTanks',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.weightRows) {
        await _db.into(_db.diveWeights).insert(r.toCompanion(false));
        await _sync.markRecordPending(
          entityType: 'diveWeights',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.customFieldRows) {
        await _db.into(_db.diveCustomFields).insert(r.toCompanion(false));
        await _sync.markRecordPending(
          entityType: 'diveCustomFields',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.diveTypeRows) {
        await _db.into(_db.diveDiveTypes).insert(r.toCompanion(false));
        await _sync.markRecordPending(
          entityType: 'diveDiveTypes',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.tagRows) {
        await _db.into(_db.diveTags).insert(r.toCompanion(false));
        await _sync.markRecordPending(
          entityType: 'diveTags',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.buddyRows) {
        await _db.into(_db.diveBuddies).insert(r.toCompanion(false));
        await _sync.markRecordPending(
          entityType: 'diveBuddies',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.sightingRows) {
        await _db.into(_db.sightings).insert(r.toCompanion(false));
        await _sync.markRecordPending(
          entityType: 'sightings',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.eventRows) {
        await _db.into(_db.diveProfileEvents).insert(r.toCompanion(false));
        await _sync.markRecordPending(
          entityType: 'diveProfileEvents',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }
      for (final r in snapshot.gasSwitchRows) {
        await _db.into(_db.gasSwitches).insert(r.toCompanion(false));
        await _sync.markRecordPending(
          entityType: 'gasSwitches',
          recordId: r.id,
          localUpdatedAt: now,
        );
      }

      // Restore media pointers.
      for (final entry in snapshot.mediaDiveIds.entries) {
        await (_db.update(_db.media)..where((t) => t.id.equals(entry.key)))
            .write(
              MediaCompanion(
                diveId: Value(entry.value),
                updatedAt: Value(now),
              ),
            );
        await _sync.markRecordPending(
          entityType: 'media',
          recordId: entry.key,
          localUpdatedAt: now,
        );
      }
    });

    SyncEventBus.notifyLocalChange();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/services/dive_merge_service_test.dart`
Expected: PASS (whole file).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/features/dive_log/data/services test/features/dive_log/data/services
git commit -m "feat(dive-merge): full-fidelity undo (#449)"
```

---

## Phase 3 — UI

### Task 9: `CombineDivesDialog` + provider + English strings

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/combine_dives_dialog.dart`
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (add `diveMergeServiceProvider` next to the other service providers)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart` (new)

**Interfaces:**
- Consumes: `DiveMergeBuilder.classify` (Task 1), `DiveMergeService.apply` (Task 7), `diveRepositoryProvider`, `UnitFormatter` (`lib/core/utils/unit_formatter.dart`), `settingsProvider`.
- Produces:
  - `final diveMergeServiceProvider = Provider<DiveMergeService>((ref) => DiveMergeService(ref.watch(diveRepositoryProvider)));`
  - `Future<DiveMergeOutcome?> showCombineDivesDialog({required BuildContext context, required List<String> diveIds})` — returns the outcome on success, `null` on cancel/close. The dialog loads dives via `getDivesByIds`, classifies, and renders: sequential -> preview list (dive number/time/duration per dive, gap durations between, merged totals line, data-handling note, Cancel + Combine buttons); overlapping -> explanation panel (+ hint pointing at the per-dive "Merge with another dive" action when exactly 2 dives are selected) with a Close button; invalid (mixed divers) -> error panel with Close.
  - English l10n keys (exact) added to `app_en.arb`:

```json
"diveLog_selection_tooltip_combine": "Combine",
"diveLog_combine_title": "Combine dives",
"diveLog_combine_previewIntro": "These {count} dives will be combined into one continuous dive. Gaps between them become surface time.",
"@diveLog_combine_previewIntro": {"placeholders": {"count": {"type": "int"}}},
"diveLog_combine_gapLabel": "Surface interval: {duration}",
"@diveLog_combine_gapLabel": {"placeholders": {"duration": {"type": "String"}}},
"diveLog_combine_resultSummary": "Result: {runtime} total, max depth {maxDepth}",
"@diveLog_combine_resultSummary": {"placeholders": {"runtime": {"type": "String"}, "maxDepth": {"type": "String"}}},
"diveLog_combine_dataNote": "Details come from the earliest dive, with blanks filled from later dives. Notes are combined. Tanks, gear, buddies, tags, and sightings are all kept.",
"diveLog_combine_confirm": "Combine into one dive",
"diveLog_combine_overlapTitle": "These dives overlap in time",
"diveLog_combine_overlapBody": "Overlapping dives look like the same dive recorded by multiple dive computers. Combining those into a single entry that shows every computer's data is coming in a future release.",
"diveLog_combine_overlapHintTwoDives": "To merge two records of the same dive now, open one of them and use \"Merge with another dive\".",
"diveLog_combine_mixedDivers": "The selected dives belong to different divers and can't be combined.",
"diveLog_combine_snackbar": "Combined {count} {count, plural, =1{dive} other{dives}}",
"@diveLog_combine_snackbar": {"placeholders": {"count": {"type": "int"}}},
"diveLog_combine_undone": "Combine undone"
```

- [ ] **Step 1: Write the failing widget test**

Model the harness on `test/features/dive_log/presentation/widgets/merge_dive_dialog_test.dart` (window sizing, `ProviderScope` overrides, capturing a `BuildContext` via `Builder`), but add l10n wiring since this dialog IS localized:

```dart
// test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart
// Harness: copy the window-size + ProviderScope + Builder-context pattern
// from merge_dive_dialog_test.dart. MaterialApp must set:
//   localizationsDelegates: AppLocalizations.localizationsDelegates,
//   supportedLocales: AppLocalizations.supportedLocales,
// Override diveRepositoryProvider with a fake whose getDivesByIds returns
// canned domain dives, and settingsProvider with the fake settings notifier
// (same fake as merge_dive_dialog_test).

void main() {
  testWidgets('sequential selection shows preview and confirm button',
      (tester) async {
    await pumpCombineDialog(tester, dives: [
      diveAt('a', DateTime.utc(2026, 7, 1, 9)),
      diveAt('b', DateTime.utc(2026, 7, 1, 10)),
    ]);
    expect(find.text('Combine dives'), findsOneWidget);
    expect(find.textContaining('Surface interval'), findsOneWidget);
    expect(find.text('Combine into one dive'), findsOneWidget);
  });

  testWidgets('overlapping selection shows the explanation panel',
      (tester) async {
    await pumpCombineDialog(tester, dives: [
      diveAt('a', DateTime.utc(2026, 7, 1, 9), runtimeMin: 90),
      diveAt('b', DateTime.utc(2026, 7, 1, 10)),
    ]);
    expect(find.text('These dives overlap in time'), findsOneWidget);
    expect(find.text('Combine into one dive'), findsNothing);
    // 2 dives selected -> hint at the existing per-dive merge action.
    expect(find.textContaining('Merge with another dive'), findsOneWidget);
  });
}
```

Write `pumpCombineDialog`/`diveAt` helpers concretely in the test file (they wrap the harness above; `diveAt` mirrors the `dive()` helper from the builder test).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart`
Expected: FAIL — dialog file does not exist.

- [ ] **Step 3: Implement**

1. Add the l10n keys above to `lib/l10n/arb/app_en.arb`, then run `flutter gen-l10n` (English-only for now; the translation task fills the other locales).
2. Add `diveMergeServiceProvider` to `dive_providers.dart` exactly as in Interfaces.
3. Build the dialog. Structural skeleton (follow `merge_dive_dialog.dart` conventions — `Dialog` + `ConstrainedBox(maxWidth: 520, maxHeight: 600)`, 24px padding, header icon + `headlineSmall` title, right-aligned `TextButton`/`FilledButton` row):

```dart
class CombineDivesDialog extends ConsumerStatefulWidget {
  const CombineDivesDialog({super.key, required this.diveIds});
  final List<String> diveIds;
  @override
  ConsumerState<CombineDivesDialog> createState() =>
      _CombineDivesDialogState();
}

class _CombineDivesDialogState extends ConsumerState<CombineDivesDialog> {
  List<domain.Dive>? _dives;
  DiveMergeClassification? _classification;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dives = await ref
        .read(diveRepositoryProvider)
        .getDivesByIds(widget.diveIds);
    if (!mounted) return;
    setState(() {
      _dives = dives;
      _classification = const DiveMergeBuilder().classify(dives);
    });
  }

  Future<void> _confirm() async {
    setState(() => _working = true);
    try {
      final outcome = await ref
          .read(diveMergeServiceProvider)
          .apply(widget.diveIds);
      if (mounted) Navigator.of(context).pop(outcome);
    } catch (_) {
      if (mounted) {
        setState(() => _working = false);
        Navigator.of(context).pop(null);
      }
      rethrow;
    }
  }
  // build(): switch on _classification —
  //   null -> centered CircularProgressIndicator
  //   MergeSequential -> _buildPreview(...)  (list of _dives rows: dive
  //     number + formatted entry time + duration; between rows a gap line
  //     context.l10n.diveLog_combine_gapLabel(_formatDuration(gap.duration));
  //     then diveLog_combine_resultSummary using UnitFormatter(settings)
  //     .formatDepth for maxDepth and _formatDuration for runtime; then
  //     diveLog_combine_dataNote in bodySmall; Cancel + confirm FilledButton
  //     wired to _confirm, disabled while _working)
  //   MergeOverlapping -> _buildOverlapPanel(...) (warning icon, overlapTitle,
  //     overlapBody, + overlapHintTwoDives when widget.diveIds.length == 2;
  //     single Close TextButton)
  //   MergeInvalid -> error panel with diveLog_combine_mixedDivers + Close.
}

Future<DiveMergeOutcome?> showCombineDivesDialog({
  required BuildContext context,
  required List<String> diveIds,
}) => showDialog<DiveMergeOutcome>(
  context: context,
  builder: (_) => CombineDivesDialog(diveIds: diveIds),
);
```

Write the three `_build*` methods in full (the comment block above defines their required content); reuse the merge dialog's `_formatDuration` shape (`{h}h {m}min` / `{m}min`) as a private helper.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/features/dive_log/presentation lib/l10n test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart
git commit -m "feat(dive-merge): CombineDivesDialog with overlap routing (#449)"
```

### Task 10: Combine action in the selection UI + undo snackbar

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (both `_buildSelectionAppBar` ~line 859 and the master-detail `_buildSelectionBar`)
- Test: `test/features/dive_log/presentation/widgets/dive_list_selection_test.dart` (extend the existing selection harness)

**Interfaces:**
- Consumes: `showCombineDivesDialog` + `DiveMergeOutcome` (Task 9), `diveMergeServiceProvider` (undo), existing selection state (`_selectedIds`, `_exitSelectionMode`), providers to refresh: `paginatedDiveListProvider`, `diveListNotifierProvider`, `diveStatisticsProvider`, `diveNumberingInfoProvider`.
- Produces: a Combine `IconButton` (`Icons.call_merge`, tooltip `diveLog_selection_tooltip_combine`) shown when `_selectedIds.length >= 2`, placed before the Export action in both selection bars; `_combineSelected()` handler.

- [ ] **Step 1: Write the failing test** (extend `dive_list_selection_test.dart` using its existing harness)

```dart
    testWidgets('Combine action appears only with 2+ selected', (tester) async {
      // Pump the list and enter selection mode exactly the way the existing
      // tests in this file do (reuse their pump helper and long-press /
      // tap-to-select steps verbatim). Then:

      // With exactly one dive selected:
      expect(find.byTooltip('Combine'), findsNothing);

      // After selecting a second dive:
      expect(find.byTooltip('Combine'), findsOneWidget);
    });
```

The selection mechanics (pump helper, how a tile is long-pressed and toggled) already exist in this test file — reuse them unchanged; the only new assertions are the two `byTooltip` expectations above. If the harness runs without full l10n, match the tooltip lookup style the file already uses for the existing Export/Delete tooltips.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: New test FAILS (`findsNothing` for the tooltip with 2 selected).

- [ ] **Step 3: Implement**

Add to BOTH selection bars, immediately before the Export button:

```dart
        if (_selectedIds.length >= 2)
          IconButton(
            icon: const Icon(Icons.call_merge),
            tooltip: context.l10n.diveLog_selection_tooltip_combine,
            onPressed: _combineSelected,
          ),
```

Handler (mirrors `_confirmAndDelete`'s messenger/undo shape, but #406-complete):

```dart
  DiveMergeOutcome? _lastMergeOutcome;

  Future<void> _combineSelected() async {
    final ids = _selectedIds.toList();
    if (ids.length < 2) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final outcome = await showCombineDivesDialog(
      context: context,
      diveIds: ids,
    );
    if (outcome == null || !mounted) return;

    // The merged dive replaced the sources; clear a stale detail selection.
    if (widget.selectedId != null && ids.contains(widget.selectedId)) {
      widget.onItemSelected?.call(null);
    }
    _exitSelectionMode();
    _lastMergeOutcome = outcome;
    _refreshAfterMerge();

    scaffoldMessenger.clearSnackBars();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.diveLog_combine_snackbar(ids.length)),
        duration: const Duration(seconds: 5),
        // #406: an action defaults to persist: true; force auto-dismiss and
        // allow closing without triggering Undo.
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(
          label: context.l10n.diveLog_bulkDelete_undo,
          onPressed: () async {
            final toUndo = _lastMergeOutcome;
            if (toUndo == null) return;
            _lastMergeOutcome = null;
            await ref.read(diveMergeServiceProvider).undo(toUndo.snapshot);
            _refreshAfterMerge();
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(context.l10n.diveLog_combine_undone),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _refreshAfterMerge() {
    ref.invalidate(paginatedDiveListProvider);
    ref.invalidate(diveListNotifierProvider);
    ref.invalidate(diveStatisticsProvider);
    ref.invalidate(diveNumberingInfoProvider);
  }
```

If any of those four providers is not already imported/visible in this file, check how `_confirmAndDelete`'s notifier path refreshes and reuse the same set.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart test/features/dive_log/presentation/widgets/dive_list_content_test.dart`
Expected: PASS (new + pre-existing).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A lib/features/dive_log/presentation test/features/dive_log/presentation
git commit -m "feat(dive-merge): Combine action with undo snackbar (#449)"
```

---

## Phase 4 — Localization + final verification

### Task 11: Translate the new strings into all 10 locales

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`

**Interfaces:**
- Consumes: the 14 English keys from Task 9.
- Produces: the same 14 keys translated in every non-English ARB (translate naturally per locale — dive-log terms like "surface interval" have established translations elsewhere in each file; match them), then regenerated localizations.

- [ ] **Step 1: Add the 14 keys to each of the 10 ARB files** — translated values, identical `@`-metadata/placeholders as English. Search each file for existing terms (`diveLog_bulkDelete_undo`, "surface", "dive") to keep terminology consistent within that locale.

- [ ] **Step 2: Regenerate and verify**

Run: `flutter gen-l10n && flutter analyze lib/l10n`
Expected: no missing-translation warnings for the new keys; analyze clean.

- [ ] **Step 3: Format and commit**

```bash
dart format .
git add lib/l10n
git commit -m "l10n: translate combine-dives strings into 10 locales (#449)"
```

### Task 12: Whole-project verification sweep

**Files:** none new.

- [ ] **Step 1: Format check**

Run: `dart format . && git diff --stat`
Expected: no formatting churn (empty diff).

- [ ] **Step 2: Whole-project analyze** (never pipe through `tail`/`head` in a way that masks the exit code)

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run the feature's test files + the neighboring suites the changes touch**

Run: `flutter test test/features/dive_log/domain/services/dive_merge_builder_test.dart test/features/dive_log/data/services/dive_merge_service_test.dart test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart test/features/dive_log/presentation/widgets/dive_list_selection_test.dart test/features/dive_log/presentation/widgets/dive_list_content_test.dart test/features/dive_log/presentation/widgets/merge_dive_dialog_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`
Expected: all pass.

- [ ] **Step 4: Commit any straggler fixes**

```bash
git add -A
git commit -m "test(dive-merge): verification sweep fixes (#449)"
```

(Skip the commit if the tree is clean.)

---

## Deliberately out of scope (from the spec)

- Overlapping-dives (multi-computer) combine — the dialog's overlapping panel is the reserved slot.
- Heuristic collapsing of "same physical tank continued across segments".
- Re-splitting a merged dive after the undo snackbar is gone.
- Import-dedup protection against re-downloading later segments (known limitation; carried `DiveDataSources` fingerprints mitigate).
