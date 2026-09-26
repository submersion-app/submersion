# Explore Phase 2 (Profile-Derived Predicates) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make "SAC increased after 20 minutes" and "the final stop was unstable" answerable in SQL, by deriving a small set of per-dive scalars and per-bucket SAC values from the profile blob once per dive version, and exposing them (plus the five safety findings already stored) as Explore query fields.

**Architecture:** A pure `DerivedMetricsService` computes the metrics from already-decoded samples and tank pressure series. A top-level worker function runs it on a background isolate from undecoded blobs, exactly as `computeSensorSummaryFromBlobs` does. Two device-local, engine-versioned tables in the main database hold the results, refreshed per dive by a single-flight scheduler copied from `SensorSummaryScheduler` and by a stale sweep at startup. The new filter axes are SQL-only: `DiveFilterState.apply` skips them and callers intersect an id set, the way `decoOnly` already works.

**Tech Stack:** Dart (pure domain code), Drift (main database, new tables and one migration rung), `compute()` for the worker isolate, Riverpod providers, `flutter_test` for unit, database and widget tests.

**Spec:** `docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md` (section "Phase 2: profile-derived predicates").

**Phase 1 plan, for the seams this builds on:** `docs/superpowers/plans/2026-09-19-explore-phase1-core-dives.md`.

## Global Constraints

- No em-dashes, en-dashes as punctuation, or double hyphens anywhere: code, comments, ARB strings, commit messages.
- No mention of Claude, Claude Code or Anthropic in any commit, file, PR body, PR comment or review reply. This holds even when an automated reviewer asks for an "Addressed by" line.
- No emojis in code, comments or docs.
- Every new ARB key goes into all 11 files: `app_ar, de, en, es, fr, he, hu, it, nl, pt, zh`. `app_en.arb` is alphabetical; the others are feature-grouped, so anchor inserts on a neighbouring key. A key with more than one placeholder needs an `@key` metadata block in `app_en.arb` or `gen-l10n` orders the parameters alphabetically. In `fr` and `pt`, a plural's `=1` branch must interpolate its own argument (`=1{{count} plongée}`), never a literal `1`; `ar` and `he` keep word forms. `test/l10n/arb_parity_test.dart`, `plural_singular_interpolates_argument_test.dart` and `plural_zero_count_test.dart` enforce this.
- A new `DiveFilterState` axis must land in THREE places: `buildFilteredDiveIdSubquery` (`lib/features/statistics/data/dive_filter_sql.dart`), `DiveRepositoryImpl._buildFilterWhereClauses` plus its count, and `DiveFilterState.apply`. An axis the entity cannot answer is SQL-only: `apply` skips it and `filteredDivesProvider` intersects an id set. Every axis needs a parity test.
- A provider that reads a table must self-invalidate on that table's change tick (`test/architecture/provider_change_tick_test.dart`). Use `ref.invalidateSelfWhen(stream)`. A provider whose value is a function, not data, carries `// no-tick: <reason>` on the line ABOVE the declaration.
- A new aggregate over `dives` must apply `DiveStatsScope` or carry a `// stats-scope-exempt: <reason>` marker (`test/core/database/dive_stats_scope_census_test.dart`).
- Storage units are metric. SAC is stored in bar per minute at surface pressure, matching `ProfileAnalysis.sacCurve`. Depths are metres, durations seconds.
- Never hydrate profiles for a whole library. Read undecoded blobs through `ProfileSeriesRepository.getPrimaryRowsForDives`, chunk them, and decode on the worker isolate.
- `currentSchemaVersion` was **221** when this plan was written. Main moves fast: re-grep `lib/core/database/database.dart` for `static const int currentSchemaVersion` before claiming a rung number, and expect to renumber at merge.
- The Drift generated files (`*.g.dart`) are gitignored in this repository. Run codegen, but do not commit them. Codegen is `dart run build_runner build --delete-conflicting-outputs`; the bare word `build` in a Bash command is refused by a deny rule, so run it from a script file.
- `TMPDIR` on the maintainer's machine may point at a mounted volume, which crashes the test harness during shutdown and still exits 0. Run `TMPDIR=/tmp flutter test ...` and prefix `git push` the same way.
- Run `dart format .` before every commit and `flutter analyze` (clean, infos are fatal) before the final one. Run tests per file or directory; run the full suite once at the end, unpiped so the exit code is real.
- Work in the phase 1 worktree on its branch. Stage explicit paths, never `git add -A`. Commit after every task.
- This phase's PR references the program issue with `Refs #2195` (phase 3 closes it).

---

## File Structure

New files:

| File | Responsibility |
| --- | --- |
| `lib/features/dive_log/domain/entities/derived_metrics.dart` | `DiveDerivedMetrics`, `SacBucket`, `FinalStopKind`, `UnsupportedReason`, `SacTrend`. Pure value types. |
| `lib/features/dive_log/domain/services/derived_metrics_service.dart` | `DerivedMetricsService`: `static const int version`, `isCurrent`, and `compute(...)` over decoded samples and tank series. Pure, no I/O, no Flutter. |
| `lib/features/dive_log/data/services/derived_metrics_worker.dart` | `DerivedMetricsWorkInput`, `TankPressureBlob`, and the top-level `computeDerivedMetricsFromBlobs` that `compute()` sends to an isolate. |
| `lib/features/dive_log/data/repositories/derived_metrics_repository.dart` | `DerivedMetricsRepository`: `ensureCurrent`, `staleDiveIds`, `getMetrics`, `saveMetrics`, `watchChanges`. Owns the runner indirection tests override. |
| `lib/features/dive_log/data/services/derived_metrics_scheduler.dart` | `DerivedMetricsScheduler`: singleton, single-flight tail, burst merging, `enabled` flag. |
| `lib/features/dive_log/presentation/providers/derived_metrics_providers.dart` | `derivedMetricsRepositoryProvider`, `diveDerivedMetricsProvider` (compute-through-cache), `derivedFilteredDiveIdsProvider`. |
| `lib/features/explore/domain/derived_predicates.dart` | `DerivedPredicate` sealed types and `DerivedConditionsKey` (value-equal family key). |

Modified files:

| File | Change |
| --- | --- |
| `lib/core/database/database.dart` | Two new tables, registration, schema rung, `_assertDerivedMetricsSchema` helper called from the rung and `beforeOpen`. |
| `lib/features/dive_log/domain/models/dive_filter_state.dart` | New SQL-only axes plus `readsDerivedMetrics`. |
| `lib/features/statistics/data/dive_filter_sql.dart` | `derivedPredicateCondition(...)`, the one SQL builder all three paths share. |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | The axes in `_buildFilterWhereClauses`, `getDiveIdsMatchingDerived`, `watchDerivedMetricsFilterChanges`. |
| `lib/features/dive_log/presentation/providers/dive_providers.dart` | Id-set intersection in `filteredDivesProvider`, tick in `orderedDiveIdsProvider`, paginator tick follower. |
| `lib/features/explore/domain/dive_field_catalog.dart` | The new fields, and `kQuerySchemaVersion` bumped to 2. |
| `lib/features/explore/domain/query_compiler.dart` | Lowering for the new fields. |
| `lib/features/explore/presentation/chip_labeler.dart` | Labels for the new fields. |
| `lib/features/explore/domain/nl_engine.dart` | Prompt lines for the new fields; the vocabulary follows the catalog automatically. |
| `packages/submersion_nl/darwin/Classes/SubmersionNlPlugin.swift` | Nothing: the schema is built from the vocabulary Dart ships. |
| `packages/submersion_nl/android/.../SubmersionNlPlugin.kt` | Nothing: prompt-only. |
| `lib/app.dart`, import adapters, dive edit, consolidation, reparse, repair | `scheduleDerivedMetricsRefresh` beside the existing sensor-summary calls. |
| `test/flutter_test_config.dart` | `DerivedMetricsScheduler.enabled = false;`. |
| 11 ARB files | Labels for the new fields and chips. |

---

### Task 1: Derived metric value types

**Files:**
- Create: `lib/features/dive_log/domain/entities/derived_metrics.dart`
- Test: `test/features/dive_log/domain/entities/derived_metrics_test.dart`

**Interfaces:**
- Produces:
  - `enum FinalStopKind { safety, deco, none }`
  - `enum UnsupportedReason { noProfile, gaugeMode, noPressureSeries, tooShort }`
  - `enum SacTrend { rising, falling, flat }`
  - `class SacBucket { final int index; final double sacBarPerMin; const SacBucket({required this.index, required this.sacBarPerMin}); }`
  - `class DiveDerivedMetrics { final String diveId; final int engineVersion; final int sourceUpdatedAt; final int computedAt; final FinalStopKind finalStopKind; final int? finalStopStartSeconds; final int? finalStopDurationSeconds; final double? finalStopDepthStdDevMeters; final double? finalStopMaxExcursionMeters; final double? sacMeanBarPerMin; final double? sacSlopeBarPerMinPerMin; final int? runtimeSeconds; final UnsupportedReason? unsupportedReason; final List<SacBucket> sacBuckets; }` with `const` constructor, `bool get hasSac`, `bool get hasFinalStop`, and `SacTrend? trend({double flatBand = 0.02})`.
  - `const int kSacBucketSeconds = 300;`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/domain/entities/derived_metrics_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';

void main() {
  DiveDerivedMetrics metrics({
    double? slope,
    double? mean,
    FinalStopKind kind = FinalStopKind.none,
    double? excursion,
    UnsupportedReason? reason,
    List<SacBucket> buckets = const [],
  }) => DiveDerivedMetrics(
    diveId: 'd1',
    engineVersion: 1,
    sourceUpdatedAt: 100,
    computedAt: 200,
    finalStopKind: kind,
    finalStopMaxExcursionMeters: excursion,
    sacMeanBarPerMin: mean,
    sacSlopeBarPerMinPerMin: slope,
    unsupportedReason: reason,
    sacBuckets: buckets,
  );

  test('a bucket is five minutes wide', () {
    expect(kSacBucketSeconds, 300);
  });

  test('the trend reads the slope against a flat band', () {
    expect(metrics(slope: 0.05).trend(), SacTrend.rising);
    expect(metrics(slope: -0.05).trend(), SacTrend.falling);
    expect(metrics(slope: 0.01).trend(), SacTrend.flat);
    expect(metrics(slope: -0.01).trend(), SacTrend.flat);
    // Exactly on the band edge is still flat: the band is inclusive, so a
    // dive cannot be called rising on a difference the engine cannot
    // distinguish from noise.
    expect(metrics(slope: 0.02).trend(), SacTrend.flat);
  });

  test('a dive with no slope has no trend', () {
    expect(metrics().trend(), isNull);
  });

  test('hasSac and hasFinalStop report what was computable', () {
    expect(metrics(mean: 0.6, buckets: const [SacBucket(index: 0, sacBarPerMin: 0.6)]).hasSac, isTrue);
    expect(metrics(reason: UnsupportedReason.noPressureSeries).hasSac, isFalse);
    expect(metrics(kind: FinalStopKind.safety).hasFinalStop, isTrue);
    expect(metrics(kind: FinalStopKind.none).hasFinalStop, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/domain/entities/derived_metrics_test.dart`
Expected: FAIL, `Error when reading 'lib/features/dive_log/domain/entities/derived_metrics.dart': No such file or directory`.

- [ ] **Step 3: Write the value types**

```dart
// lib/features/dive_log/domain/entities/derived_metrics.dart
/// What only a profile decode can answer about a dive, computed once per
/// dive version so the Explore filter can ask about it in SQL.
///
/// Pure value types: no Flutter, no database, no analysis engine, so the
/// worker isolate can build them and the filter can read them.
library;

/// The width of one SAC bucket. Five minutes is coarse enough that a single
/// breath does not move a bucket and fine enough that "after 20 minutes"
/// lands on a bucket boundary.
const int kSacBucketSeconds = 300;

enum FinalStopKind { safety, deco, none }

/// Why a metric could not be derived. A row always exists for a dive the
/// sweep has visited, so a predicate simply does not match rather than the
/// sweep revisiting the dive forever.
enum UnsupportedReason { noProfile, gaugeMode, noPressureSeries, tooShort }

enum SacTrend { rising, falling, flat }

class SacBucket {
  /// Zero-based, so bucket n covers [n * kSacBucketSeconds, (n+1) * ...).
  final int index;

  /// Bar per minute at surface pressure, matching ProfileAnalysis.sacCurve.
  final double sacBarPerMin;

  const SacBucket({required this.index, required this.sacBarPerMin});

  @override
  bool operator ==(Object other) =>
      other is SacBucket &&
      other.index == index &&
      other.sacBarPerMin == sacBarPerMin;

  @override
  int get hashCode => Object.hash(index, sacBarPerMin);

  @override
  String toString() => 'SacBucket($index, $sacBarPerMin)';
}

class DiveDerivedMetrics {
  final String diveId;
  final int engineVersion;

  /// The dive's `updated_at` this was built from. A mismatch means stale.
  final int sourceUpdatedAt;
  final int computedAt;

  final FinalStopKind finalStopKind;
  final int? finalStopStartSeconds;
  final int? finalStopDurationSeconds;
  final double? finalStopDepthStdDevMeters;
  final double? finalStopMaxExcursionMeters;

  final double? sacMeanBarPerMin;

  /// Least-squares slope of SAC against time, in bar per minute per minute.
  final double? sacSlopeBarPerMinPerMin;

  final int? runtimeSeconds;
  final UnsupportedReason? unsupportedReason;
  final List<SacBucket> sacBuckets;

  const DiveDerivedMetrics({
    required this.diveId,
    required this.engineVersion,
    required this.sourceUpdatedAt,
    required this.computedAt,
    this.finalStopKind = FinalStopKind.none,
    this.finalStopStartSeconds,
    this.finalStopDurationSeconds,
    this.finalStopDepthStdDevMeters,
    this.finalStopMaxExcursionMeters,
    this.sacMeanBarPerMin,
    this.sacSlopeBarPerMinPerMin,
    this.runtimeSeconds,
    this.unsupportedReason,
    this.sacBuckets = const [],
  });

  bool get hasSac => sacMeanBarPerMin != null && sacBuckets.isNotEmpty;

  bool get hasFinalStop => finalStopKind != FinalStopKind.none;

  /// Rising, falling or flat, judged against a band the engine treats as
  /// noise. Null when no slope could be computed.
  SacTrend? trend({double flatBand = 0.02}) {
    final slope = sacSlopeBarPerMinPerMin;
    if (slope == null) return null;
    if (slope > flatBand) return SacTrend.rising;
    if (slope < -flatBand) return SacTrend.falling;
    return SacTrend.flat;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/domain/entities/derived_metrics_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/domain/entities/derived_metrics.dart test/features/dive_log/domain/entities/derived_metrics_test.dart
git add lib/features/dive_log/domain/entities/derived_metrics.dart test/features/dive_log/domain/entities/derived_metrics_test.dart
git commit -m "feat(dive-log): value types for the per-dive derived metrics"
```

---
### Task 2: The derived metrics engine

**Files:**
- Create: `lib/features/dive_log/domain/services/derived_metrics_service.dart`
- Test: `test/features/dive_log/domain/services/derived_metrics_service_test.dart`

**Interfaces:**
- Consumes: `DiveDerivedMetrics`, `SacBucket`, `FinalStopKind`, `UnsupportedReason`, `kSacBucketSeconds` (Task 1); `ProfileSample` (`lib/features/dive_log/domain/codecs/profile_sample.dart`, fields `timestamp` seconds and `depth` metres); `DiveMode` (`lib/core/constants/enums.dart`).
- Produces:
  - `class TankPressureSeries { final String tankId; final double? volumeLiters; final List<({int timestamp, double bar})> points; const TankPressureSeries({required this.tankId, this.volumeLiters, required this.points}); }`
  - `abstract final class DerivedMetricsService { static const int version = 1; static bool isCurrent(DiveDerivedMetrics m, int diveUpdatedAt); static DiveDerivedMetrics compute({required String diveId, required List<ProfileSample> samples, required List<TankPressureSeries> tanks, required DiveMode diveMode, required int sourceUpdatedAt, required int computedAtMs}); }`

Rules the engine applies, all pinned by the tests below:

- **Gauge mode** or **fewer than two samples** yields `unsupportedReason` and no metrics: `gaugeMode` wins over `tooShort`.
- **Final stop**: the last level run shallower than `7.0 m` lasting at least `60 s`, where "level" means consecutive samples whose depth stays inside a `1.5 m` window of the run's median. Its kind is `deco` when any sample in the run carries `decoType == 2`, else `safety`. `finalStopDepthStdDevMeters` is the population standard deviation of the run's depths; `finalStopMaxExcursionMeters` is the largest absolute deviation from the run's median.
- **SAC**: from the tank with the largest total pressure drop that has at least two points and a volume. For each bucket, the pressure drop across the bucket divided by its minutes, divided by the mean ambient pressure in ata (`1 + meanDepth / 10`). A bucket with a non-negative drop (a tank change or a sensor glitch) is skipped rather than recorded as zero. No usable tank yields `noPressureSeries`.
- **Slope**: least-squares fit of bucket SAC against bucket mid-time in minutes. Fewer than two buckets yields a null slope, not zero.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/domain/services/derived_metrics_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

void main() {
  /// A square profile: descend, hold [bottomDepth] to [bottomEnd], ascend to
  /// [stopDepth] and hold it until [end], one sample every 10 s.
  List<ProfileSample> squareProfile({
    double bottomDepth = 30,
    int bottomEnd = 1800,
    double stopDepth = 5,
    int end = 2100,
    int? decoTypeAtStop,
  }) {
    final out = <ProfileSample>[];
    for (var t = 0; t <= end; t += 10) {
      double depth;
      if (t < 60) {
        depth = bottomDepth * (t / 60);
      } else if (t <= bottomEnd) {
        depth = bottomDepth;
      } else if (t <= bottomEnd + 120) {
        final f = (t - bottomEnd) / 120;
        depth = bottomDepth + (stopDepth - bottomDepth) * f;
      } else {
        depth = stopDepth;
      }
      out.add(
        ProfileSample(
          timestamp: t,
          depth: depth,
          decoType: t > bottomEnd + 120 ? decoTypeAtStop : null,
        ),
      );
    }
    return out;
  }

  /// A tank draining at a constant [barPerMin] of stored pressure.
  TankPressureSeries steadyTank({
    double start = 200,
    double barPerMin = 2,
    int end = 2100,
    double volume = 12,
  }) => TankPressureSeries(
    tankId: 't1',
    volumeLiters: volume,
    points: [
      for (var t = 0; t <= end; t += 10)
        (timestamp: t, bar: start - barPerMin * (t / 60)),
    ],
  );

  DiveDerivedMetrics run({
    List<ProfileSample>? samples,
    List<TankPressureSeries> tanks = const [],
    DiveMode mode = DiveMode.oc,
  }) => DerivedMetricsService.compute(
    diveId: 'd1',
    samples: samples ?? squareProfile(),
    tanks: tanks,
    diveMode: mode,
    sourceUpdatedAt: 111,
    computedAtMs: 222,
  );

  group('unsupported dives', () {
    test('a gauge dive derives nothing', () {
      final m = run(tanks: [steadyTank()], mode: DiveMode.gauge);
      expect(m.unsupportedReason, UnsupportedReason.gaugeMode);
      expect(m.hasSac, isFalse);
      expect(m.hasFinalStop, isFalse);
      expect(m.engineVersion, DerivedMetricsService.version);
      expect(m.sourceUpdatedAt, 111);
    });

    test('a profile with under two samples is too short', () {
      final m = run(samples: [const ProfileSample(timestamp: 0, depth: 0)]);
      expect(m.unsupportedReason, UnsupportedReason.tooShort);
    });

    test('gauge mode wins over a short profile', () {
      final m = run(
        samples: [const ProfileSample(timestamp: 0, depth: 0)],
        mode: DiveMode.gauge,
      );
      expect(m.unsupportedReason, UnsupportedReason.gaugeMode);
    });

    test('no usable tank means no SAC, but the final stop still lands', () {
      final m = run();
      expect(m.unsupportedReason, UnsupportedReason.noPressureSeries);
      expect(m.hasSac, isFalse);
      expect(m.finalStopKind, FinalStopKind.safety);
    });

    test('a tank with no volume is not usable', () {
      final m = run(tanks: [
        TankPressureSeries(
          tankId: 't1',
          points: const [(timestamp: 0, bar: 200), (timestamp: 600, bar: 180)],
        ),
      ]);
      expect(m.unsupportedReason, UnsupportedReason.noPressureSeries);
    });
  });

  group('final stop', () {
    test('a steady safety stop is stable', () {
      final m = run(tanks: [steadyTank()]);
      expect(m.finalStopKind, FinalStopKind.safety);
      expect(m.finalStopDurationSeconds, greaterThanOrEqualTo(120));
      expect(m.finalStopDepthStdDevMeters, closeTo(0, 0.01));
      expect(m.finalStopMaxExcursionMeters, closeTo(0, 0.01));
    });

    test('a deco-flagged stop is reported as deco', () {
      final m = run(
        samples: squareProfile(decoTypeAtStop: 2),
        tanks: [steadyTank()],
      );
      expect(m.finalStopKind, FinalStopKind.deco);
    });

    test('a wandering stop reports its excursion', () {
      // The diver porpoises between 3.5 m and 6.5 m around a 5 m median.
      final samples = squareProfile();
      final wandering = [
        for (final s in samples)
          if (s.timestamp <= 1920)
            s
          else
            ProfileSample(
              timestamp: s.timestamp,
              depth: 5 + ((s.timestamp ~/ 10) % 2 == 0 ? 1.5 : -1.5),
            ),
      ];
      final m = run(samples: wandering, tanks: [steadyTank()]);
      expect(m.finalStopKind, FinalStopKind.safety);
      expect(m.finalStopMaxExcursionMeters, closeTo(1.5, 0.2));
      expect(m.finalStopDepthStdDevMeters, greaterThan(1.0));
    });

    test('a dive that surfaces straight from depth has no final stop', () {
      final straight = [
        for (var t = 0; t <= 600; t += 10)
          ProfileSample(timestamp: t, depth: t < 540 ? 30 : 30 - (t - 540) / 2),
      ];
      final m = run(samples: straight, tanks: [steadyTank(end: 600)]);
      expect(m.finalStopKind, FinalStopKind.none);
      expect(m.finalStopDurationSeconds, isNull);
    });

    test('a stop shorter than a minute does not count', () {
      final brief = [
        for (var t = 0; t <= 640; t += 10)
          ProfileSample(
            timestamp: t,
            depth: t < 560 ? 30 : (t < 600 ? 30 - (t - 560) / 1.6 : 5),
          ),
      ];
      final m = run(samples: brief, tanks: [steadyTank(end: 640)]);
      expect(m.finalStopKind, FinalStopKind.none);
    });
  });

  group('SAC', () {
    test('a steady tank on a square profile gives flat buckets', () {
      final m = run(tanks: [steadyTank()]);
      expect(m.hasSac, isTrue);
      expect(m.unsupportedReason, isNull);
      expect(m.sacBuckets.length, greaterThanOrEqualTo(6));
      expect(m.sacBuckets.first.index, 0);
      // Bottom buckets sit at 30 m (4 ata): 2 bar/min of stored pressure is
      // 0.5 bar/min at surface.
      expect(m.sacBuckets[2].sacBarPerMin, closeTo(0.5, 0.05));
      expect(m.sacMeanBarPerMin, greaterThan(0));
      // Shallower buckets consume more surface-equivalent gas at the same
      // stored drop, so the fit is not flat; assert only the sign is sane.
      expect(m.sacSlopeBarPerMinPerMin, isNotNull);
    });

    test('a rising consumption gives a positive slope', () {
      // Drop accelerates: 1 bar/min for the first half, 4 for the second.
      final points = <({int timestamp, double bar})>[];
      var bar = 220.0;
      for (var t = 0; t <= 1800; t += 10) {
        points.add((timestamp: t, bar: bar));
        bar -= (t < 900 ? 1.0 : 4.0) / 6;
      }
      final m = run(
        samples: squareProfile(bottomEnd: 1500, end: 1800),
        tanks: [
          TankPressureSeries(tankId: 't1', volumeLiters: 12, points: points),
        ],
      );
      expect(m.trend(), SacTrend.rising);
      expect(m.sacSlopeBarPerMinPerMin, greaterThan(0));
    });

    test('the tank with the largest drop wins', () {
      final m = run(tanks: [
        TankPressureSeries(
          tankId: 'stage',
          volumeLiters: 11,
          points: const [(timestamp: 0, bar: 200), (timestamp: 1800, bar: 195)],
        ),
        steadyTank(),
      ]);
      expect(m.hasSac, isTrue);
      // The steady tank drops 60 bar over the dive and is the reference.
      expect(m.sacMeanBarPerMin, greaterThan(0.2));
    });

    test('a bucket where pressure rises is skipped, not recorded as zero', () {
      final points = <({int timestamp, double bar})>[
        for (var t = 0; t <= 600; t += 10) (timestamp: t, bar: 200 - t / 60),
        // A tank swap puts the pressure back up.
        for (var t = 610; t <= 1200; t += 10) (timestamp: t, bar: 230 - t / 60),
      ];
      final m = run(
        samples: squareProfile(bottomEnd: 900, end: 1200),
        tanks: [
          TankPressureSeries(tankId: 't1', volumeLiters: 12, points: points),
        ],
      );
      expect(m.sacBuckets.every((b) => b.sacBarPerMin > 0), isTrue);
      expect(m.sacBuckets.map((b) => b.index), isNot(contains(2)));
    });

    test('a single bucket yields a mean but no slope', () {
      final m = run(
        samples: squareProfile(bottomEnd: 120, end: 240),
        tanks: [steadyTank(end: 240)],
      );
      expect(m.sacMeanBarPerMin, isNotNull);
      expect(m.sacSlopeBarPerMinPerMin, isNull);
    });
  });

  test('isCurrent compares the engine version and the dive stamp', () {
    final m = run(tanks: [steadyTank()]);
    expect(DerivedMetricsService.isCurrent(m, 111), isTrue);
    expect(DerivedMetricsService.isCurrent(m, 112), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/domain/services/derived_metrics_service_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the engine**

```dart
// lib/features/dive_log/domain/services/derived_metrics_service.dart
import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';

/// One tank's pressure over time, already decoded, with the volume needed to
/// turn a pressure drop into gas.
class TankPressureSeries {
  final String tankId;
  final double? volumeLiters;
  final List<({int timestamp, double bar})> points;

  const TankPressureSeries({
    required this.tankId,
    this.volumeLiters,
    required this.points,
  });
}

/// Derives the handful of per-dive numbers that only a profile decode can
/// answer, so the Explore filter can ask about them in SQL.
///
/// Pure: no database, no Flutter, no analysis engine. That is what lets the
/// worker isolate run it and the tests pin it with synthetic profiles.
abstract final class DerivedMetricsService {
  /// Bump whenever a rule below changes; every stored row with a lower
  /// version is rebuilt by the sweep.
  static const int version = 1;

  /// Depth under which a level run counts as a final stop.
  static const double finalStopMaxDepthMeters = 7.0;

  /// A level run must last this long to be a stop rather than a pause.
  static const int finalStopMinSeconds = 60;

  /// How far a sample may sit from a run's median and still be "level".
  static const double levelWindowMeters = 1.5;

  static bool isCurrent(DiveDerivedMetrics m, int diveUpdatedAt) =>
      m.engineVersion >= version && m.sourceUpdatedAt == diveUpdatedAt;

  static DiveDerivedMetrics compute({
    required String diveId,
    required List<ProfileSample> samples,
    required List<TankPressureSeries> tanks,
    required DiveMode diveMode,
    required int sourceUpdatedAt,
    required int computedAtMs,
  }) {
    DiveDerivedMetrics bare(UnsupportedReason reason) => DiveDerivedMetrics(
      diveId: diveId,
      engineVersion: version,
      sourceUpdatedAt: sourceUpdatedAt,
      computedAt: computedAtMs,
      unsupportedReason: reason,
      runtimeSeconds: samples.isEmpty ? null : samples.last.timestamp,
    );

    // Gauge dives carry no usable gas data and their depth track is not a
    // decompression profile, so neither metric means anything.
    if (diveMode == DiveMode.gauge) return bare(UnsupportedReason.gaugeMode);
    if (samples.length < 2) return bare(UnsupportedReason.tooShort);

    final ordered = [...samples]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final stop = _finalStop(ordered);
    final sac = _sac(ordered, tanks);

    return DiveDerivedMetrics(
      diveId: diveId,
      engineVersion: version,
      sourceUpdatedAt: sourceUpdatedAt,
      computedAt: computedAtMs,
      finalStopKind: stop?.kind ?? FinalStopKind.none,
      finalStopStartSeconds: stop?.startSeconds,
      finalStopDurationSeconds: stop?.durationSeconds,
      finalStopDepthStdDevMeters: stop?.stdDev,
      finalStopMaxExcursionMeters: stop?.maxExcursion,
      sacMeanBarPerMin: sac?.mean,
      sacSlopeBarPerMinPerMin: sac?.slope,
      runtimeSeconds: ordered.last.timestamp,
      unsupportedReason: sac == null ? UnsupportedReason.noPressureSeries : null,
      sacBuckets: sac?.buckets ?? const [],
    );
  }

  static ({
    FinalStopKind kind,
    int startSeconds,
    int durationSeconds,
    double stdDev,
    double maxExcursion,
  })? _finalStop(List<ProfileSample> samples) {
    // Walk backwards from the last sample that is shallower than the stop
    // ceiling, collecting while the depth stays inside the level window of
    // the run's running median.
    var end = samples.length - 1;
    while (end >= 0 && samples[end].depth > finalStopMaxDepthMeters) {
      end--;
    }
    if (end < 1) return null;

    final run = <ProfileSample>[samples[end]];
    for (var i = end - 1; i >= 0; i--) {
      final candidate = samples[i];
      if (candidate.depth > finalStopMaxDepthMeters) break;
      final median = _median([...run.map((s) => s.depth), candidate.depth]);
      final within = [...run, candidate]
          .every((s) => (s.depth - median).abs() <= levelWindowMeters);
      if (!within) break;
      run.insert(0, candidate);
    }
    if (run.length < 2) return null;

    final duration = run.last.timestamp - run.first.timestamp;
    if (duration < finalStopMinSeconds) return null;

    final depths = run.map((s) => s.depth).toList();
    final median = _median(depths);
    final mean = depths.reduce((a, b) => a + b) / depths.length;
    final variance =
        depths.map((d) => (d - mean) * (d - mean)).reduce((a, b) => a + b) /
        depths.length;
    final excursion = depths
        .map((d) => (d - median).abs())
        .reduce((a, b) => a > b ? a : b);
    // decoType 2 is a mandatory deco stop; anything else at this depth is a
    // safety stop the diver chose.
    final isDeco = run.any((s) => s.decoType == 2);

    return (
      kind: isDeco ? FinalStopKind.deco : FinalStopKind.safety,
      startSeconds: run.first.timestamp,
      durationSeconds: duration,
      stdDev: math.sqrt(variance),
      maxExcursion: excursion,
    );
  }

  static ({List<SacBucket> buckets, double mean, double? slope})? _sac(
    List<ProfileSample> samples,
    List<TankPressureSeries> tanks,
  ) {
    final tank = _referenceTank(tanks);
    if (tank == null) return null;

    final lastTime = samples.last.timestamp;
    final buckets = <SacBucket>[];
    final midMinutes = <double>[];

    for (var index = 0; index * kSacBucketSeconds <= lastTime; index++) {
      final from = index * kSacBucketSeconds;
      final to = from + kSacBucketSeconds;
      final startBar = _pressureAt(tank, from);
      final endBar = _pressureAt(tank, math.min(to, lastTime));
      if (startBar == null || endBar == null) continue;
      final drop = startBar - endBar;
      // A non-negative drop is a tank change or a sensor glitch, not a
      // breath: recording it as zero would drag the mean and the slope.
      if (drop <= 0) continue;
      final minutes = (math.min(to, lastTime) - from) / 60.0;
      if (minutes <= 0) continue;
      final ata = 1 + _meanDepth(samples, from, to) / 10.0;
      if (ata <= 0) continue;
      buckets.add(
        SacBucket(index: index, sacBarPerMin: drop / minutes / ata),
      );
      midMinutes.add((from + math.min(to, lastTime)) / 2 / 60.0);
    }

    if (buckets.isEmpty) return null;
    final values = buckets.map((b) => b.sacBarPerMin).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    return (buckets: buckets, mean: mean, slope: _slope(midMinutes, values));
  }

  /// The tank that did the most work, which is the one the diver breathed.
  static TankPressureSeries? _referenceTank(List<TankPressureSeries> tanks) {
    TankPressureSeries? best;
    var bestDrop = 0.0;
    for (final tank in tanks) {
      if (tank.volumeLiters == null || tank.points.length < 2) continue;
      final sorted = [...tank.points]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final drop = sorted.first.bar - sorted.last.bar;
      if (drop > bestDrop) {
        bestDrop = drop;
        best = TankPressureSeries(
          tankId: tank.tankId,
          volumeLiters: tank.volumeLiters,
          points: sorted,
        );
      }
    }
    return best;
  }

  /// Linear interpolation between the bracketing points; null outside them.
  static double? _pressureAt(TankPressureSeries tank, int timestamp) {
    final points = tank.points;
    if (timestamp < points.first.timestamp) return null;
    if (timestamp > points.last.timestamp) return null;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (timestamp <= b.timestamp) {
        final span = b.timestamp - a.timestamp;
        if (span <= 0) return b.bar;
        final f = (timestamp - a.timestamp) / span;
        return a.bar + (b.bar - a.bar) * f;
      }
    }
    return points.last.bar;
  }

  static double _meanDepth(List<ProfileSample> samples, int from, int to) {
    final inWindow = samples
        .where((s) => s.timestamp >= from && s.timestamp < to)
        .map((s) => s.depth)
        .toList();
    if (inWindow.isEmpty) return 0;
    return inWindow.reduce((a, b) => a + b) / inWindow.length;
  }

  /// Least squares. Null under two points: a single bucket has no trend, and
  /// reporting zero would read as "flat" rather than "unknown".
  static double? _slope(List<double> xs, List<double> ys) {
    if (xs.length < 2) return null;
    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    var num = 0.0;
    var den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (xs[i] - meanX) * (ys[i] - meanY);
      den += (xs[i] - meanX) * (xs[i] - meanX);
    }
    if (den == 0) return null;
    return num / den;
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/domain/services/derived_metrics_service_test.dart`
Expected: PASS. If a synthetic-profile expectation is off by a small margin, adjust the TEST's tolerance only after checking by hand that the engine's number is the right one; do not loosen a rule to make a number fit.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/domain/services/derived_metrics_service.dart test/features/dive_log/domain/services/derived_metrics_service_test.dart
git add lib/features/dive_log/domain/services/derived_metrics_service.dart test/features/dive_log/domain/services/derived_metrics_service_test.dart
git commit -m "feat(dive-log): derive final-stop stability and bucketed SAC from a profile"
```

---
### Task 3: The two tables and the migration rung

**Files:**
- Modify: `lib/core/database/database.dart` (table classes next to `DiveSensorSummaries` near line 3520; `@DriftDatabase(tables: [...])` near line 4186; `currentSchemaVersion` near line 4264; a `_assertDerivedMetricsSchema` helper beside `_assertEquipmentConditionSchema` near line 5043; the rung after the current last one near line 12366; the `beforeOpen` re-assert near line 12613)
- Test: `test/core/database/migration_derived_metrics_test.dart`

**Interfaces:**
- Produces: tables `dive_derived_metrics` and `dive_sac_buckets`, Drift classes `DiveDerivedMetricsRows` / `DiveSacBuckets` with data classes `DiveDerivedMetricsRow` / `DiveSacBucketRow`, and `AppDatabase._assertDerivedMetricsSchema()`.

Both tables are device-local by construction: the primary key is the dive id (plus the bucket index), they carry `engine_version` and `source_updated_at` as the staleness fingerprint, and they have **no `hlc` column**, which is what keeps them out of sync. A restore rebuilds them by sweep.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/migration_derived_metrics_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<Set<String>> columns(String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('the derived metrics table has its fingerprint and no hlc', () async {
    final cols = await columns('dive_derived_metrics');
    expect(
      cols,
      containsAll([
        'dive_id',
        'engine_version',
        'source_updated_at',
        'computed_at',
        'final_stop_kind',
        'final_stop_start_s',
        'final_stop_duration_s',
        'final_stop_depth_stddev_m',
        'final_stop_max_excursion_m',
        'sac_mean_bar_min',
        'sac_slope_bar_min_per_min',
        'runtime_s',
        'unsupported_reason',
      ]),
    );
    // Device-local: never synced, so it carries no clock.
    expect(cols, isNot(contains('hlc')));
  });

  test('the bucket table is keyed by dive and index', () async {
    final cols = await columns('dive_sac_buckets');
    expect(cols, containsAll(['dive_id', 'bucket_index', 'sac_bar_min']));
    expect(cols, isNot(contains('hlc')));
  });

  test('deleting a dive cascades to both tables', () async {
    final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;
    await db.into(db.dives).insert(
      DivesCompanion(
        id: const Value('d1'),
        diveDateTime: Value(now),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.into(db.diveDerivedMetricsRows).insert(
      DiveDerivedMetricsRowsCompanion.insert(
        diveId: 'd1',
        engineVersion: 1,
        sourceUpdatedAt: now,
        computedAt: now,
      ),
    );
    await db.into(db.diveSacBuckets).insert(
      DiveSacBucketsCompanion.insert(
        diveId: 'd1',
        bucketIndex: 0,
        sacBarMin: 0.6,
      ),
    );

    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();

    expect(await db.select(db.diveDerivedMetricsRows).get(), isEmpty);
    expect(await db.select(db.diveSacBuckets).get(), isEmpty);
  });

  test('the schema assert is idempotent', () async {
    // It runs from the rung AND from beforeOpen, so a second call on an
    // already-migrated database must not throw.
    await db.assertDerivedMetricsSchemaForTest();
    await db.assertDerivedMetricsSchemaForTest();
    expect(await columns('dive_derived_metrics'), isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/core/database/migration_derived_metrics_test.dart`
Expected: FAIL, `diveDerivedMetricsRows` is not defined on `AppDatabase`.

- [ ] **Step 3: Add the tables**

In `lib/core/database/database.dart`, after the `DiveSensorSummaries` class:

```dart
/// What only a profile decode can answer about a dive, computed once per
/// dive version by [DerivedMetricsService] so the Explore filter can ask
/// about SAC trend and final-stop stability in SQL (phase 2).
///
/// Device-local, never synced: no `hlc` column, and a restore rebuilds it
/// by sweep rather than inheriting another device's numbers. The Drift class
/// is `DiveDerivedMetricsRows` because `DiveDerivedMetrics` is the domain
/// type this row maps to.
@DataClassName('DiveDerivedMetricsRow')
class DiveDerivedMetricsRows extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get engineVersion => integer()();
  IntColumn get sourceUpdatedAt => integer()();
  IntColumn get computedAt => integer()();

  /// `FinalStopKind.name`, defaulting to none so a row always classifies.
  TextColumn get finalStopKind =>
      text().withDefault(const Constant('none'))();
  IntColumn get finalStopStartS => integer().nullable()();
  IntColumn get finalStopDurationS => integer().nullable()();
  RealColumn get finalStopDepthStddevM => real().nullable()();
  RealColumn get finalStopMaxExcursionM => real().nullable()();

  RealColumn get sacMeanBarMin => real().nullable()();
  RealColumn get sacSlopeBarMinPerMin => real().nullable()();
  IntColumn get runtimeS => integer().nullable()();

  /// `UnsupportedReason.name` when a metric could not be derived. A row with
  /// a reason still exists, so the sweep never revisits the dive.
  TextColumn get unsupportedReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {diveId};
}

/// SAC per five-minute bucket, so "SAC increased after 20 minutes" is two
/// averages in SQL for any N rather than a profile decode per dive.
@DataClassName('DiveSacBucketRow')
class DiveSacBuckets extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  IntColumn get bucketIndex => integer()();

  /// Bar per minute at surface pressure.
  RealColumn get sacBarMin => real()();

  @override
  Set<Column> get primaryKey => {diveId, bucketIndex};
}
```

Add `DiveDerivedMetricsRows,` and `DiveSacBuckets,` to the `@DriftDatabase(tables: [...])` list.

Add the idempotent helper beside `_assertEquipmentConditionSchema`, plus a test seam:

```dart
  /// Creates the phase 2 derived-metric tables if they are absent.
  ///
  /// Idempotent by construction (drift emits `CREATE TABLE IF NOT EXISTS`),
  /// because it runs both from the migration rung and from `beforeOpen` as
  /// a ladder-collision self-heal.
  Future<void> _assertDerivedMetricsSchema() async {
    if (!await _tableExists('dives')) return;
    final m = createMigrator();
    await m.createTable(diveDerivedMetricsRows);
    await m.createTable(diveSacBuckets);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sac_buckets_dive '
      'ON dive_sac_buckets (dive_id)',
    );
  }

  @visibleForTesting
  Future<void> assertDerivedMetricsSchemaForTest() =>
      _assertDerivedMetricsSchema();
```

Bump `currentSchemaVersion` by one (re-grep first; it was 221) and add the rung after the current last one, following the neighbouring style exactly:

```dart
      // v222: Explore phase 2 derived metrics (issue #2195). Table-only
      // rung, no backfill: the sweep fills both tables on next launch.
      if (from < 222) {
        await _assertDerivedMetricsSchema();
      }
      if (from < 222) await reportProgress();
```

In `beforeOpen`, beside the other re-asserts:

```dart
        await _assertDerivedMetricsSchema();
```

- [ ] **Step 4: Run codegen**

Write `/tmp/p2codegen.sh` containing `cd <worktree> && dart run build_runner build --delete-conflicting-outputs` and run `bash /tmp/p2codegen.sh`. The bare word in that command is refused inline by a deny rule, which is why it goes in a file.

- [ ] **Step 5: Run test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/core/database/migration_derived_metrics_test.dart test/core/database/schema_version_test.dart`
Expected: PASS. If a test pins the schema version literal, update it to the number you actually used.

- [ ] **Step 6: Commit**

```bash
dart format lib/core/database/database.dart test/core/database/migration_derived_metrics_test.dart
git add lib/core/database/database.dart test/core/database/migration_derived_metrics_test.dart
git commit -m "feat(dive-log): device-local tables for derived metrics and SAC buckets"
```

---

### Task 4: The worker and its input

**Files:**
- Create: `lib/features/dive_log/data/services/derived_metrics_worker.dart`
- Test: `test/features/dive_log/data/services/derived_metrics_worker_test.dart`

**Interfaces:**
- Consumes: `DerivedMetricsService`, `TankPressureSeries` (Task 2); `ProfileSeriesCodec` and `TankPressureCodec` (`lib/features/dive_log/domain/codecs/`); `DiveMode`.
- Produces:
  - `class TankPressureBlob { final String tankId; final double? volumeLiters; final Uint8List samples; const TankPressureBlob({required this.tankId, this.volumeLiters, required this.samples}); }`
  - `class DerivedMetricsWorkInput { final String diveId; final List<Uint8List> primaryBlobs; final List<TankPressureBlob> tankBlobs; final DiveMode diveMode; final int sourceUpdatedAt; final int computedAtMs; }`
  - `DiveDerivedMetrics computeDerivedMetricsFromBlobs(DerivedMetricsWorkInput input)`, top-level, so `compute()` can send it to an isolate.

The blob-handling rules copy `sensor_summary_worker.dart` exactly, because they were learned the hard way: a corrupt blob is swallowed (skip the segment, still write a row, or the sweep revisits it forever), but an `UnknownSeriesVersionException` whose `isForwardVersion` is true is **rethrown**, so a dive written by a newer build stays stale instead of caching a wrong answer a future build would never recompute.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/data/services/derived_metrics_worker_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_worker.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';

void main() {
  const codec = ProfileSeriesCodec();

  Uint8List encodeProfile(List<ProfileSample> samples) =>
      codec.encode(samples).bytes;

  List<ProfileSample> square() => [
    for (var t = 0; t <= 1200; t += 10)
      ProfileSample(timestamp: t, depth: t < 1080 ? 20 : 5),
  ];

  test('decodes the primary blobs and derives metrics', () {
    final out = computeDerivedMetricsFromBlobs(
      DerivedMetricsWorkInput(
        diveId: 'd1',
        primaryBlobs: [encodeProfile(square())],
        tankBlobs: const [],
        diveMode: DiveMode.oc,
        sourceUpdatedAt: 7,
        computedAtMs: 9,
      ),
    );
    expect(out.diveId, 'd1');
    expect(out.sourceUpdatedAt, 7);
    expect(out.computedAt, 9);
    expect(out.runtimeSeconds, 1200);
    // No tank blobs, so SAC is unavailable but the stop still lands.
    expect(out.unsupportedReason, UnsupportedReason.noPressureSeries);
    expect(out.finalStopKind, FinalStopKind.safety);
  });

  test('merges several source blobs in timestamp order', () {
    final first = square().where((s) => s.timestamp <= 600).toList();
    final second = square().where((s) => s.timestamp > 600).toList();
    final out = computeDerivedMetricsFromBlobs(
      DerivedMetricsWorkInput(
        diveId: 'd1',
        // Deliberately out of order: the worker sorts.
        primaryBlobs: [encodeProfile(second), encodeProfile(first)],
        tankBlobs: const [],
        diveMode: DiveMode.oc,
        sourceUpdatedAt: 7,
        computedAtMs: 9,
      ),
    );
    expect(out.runtimeSeconds, 1200);
  });

  test('a corrupt blob is skipped, and a row is still produced', () {
    final out = computeDerivedMetricsFromBlobs(
      DerivedMetricsWorkInput(
        diveId: 'd1',
        primaryBlobs: [
          encodeProfile(square()),
          Uint8List.fromList([0, 1, 2, 3, 4]),
        ],
        tankBlobs: const [],
        diveMode: DiveMode.oc,
        sourceUpdatedAt: 7,
        computedAtMs: 9,
      ),
    );
    expect(out.runtimeSeconds, 1200);
  });

  test('no decodable profile at all is reported as noProfile', () {
    final out = computeDerivedMetricsFromBlobs(
      DerivedMetricsWorkInput(
        diveId: 'd1',
        primaryBlobs: [Uint8List.fromList([9, 9, 9])],
        tankBlobs: const [],
        diveMode: DiveMode.oc,
        sourceUpdatedAt: 7,
        computedAtMs: 9,
      ),
    );
    expect(out.unsupportedReason, UnsupportedReason.noProfile);
  });
}
```

Check `ProfileSeriesCodec.encode`'s return shape before writing `encodeProfile`: at the time of writing it returns a record carrying `bytes`. If it returns a `Uint8List` directly, drop the `.bytes`.

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/data/services/derived_metrics_worker_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the worker**

```dart
// lib/features/dive_log/data/services/derived_metrics_worker.dart
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

/// One tank's undecoded pressure series plus the volume the engine needs.
class TankPressureBlob {
  final String tankId;
  final double? volumeLiters;
  final Uint8List samples;

  const TankPressureBlob({
    required this.tankId,
    this.volumeLiters,
    required this.samples,
  });
}

/// Everything the worker needs, read on the main isolate WITHOUT decoding
/// anything: blobs and scalars only, so nothing heavy crosses the boundary.
/// No DateTime crosses either; [computedAtMs] is an int.
class DerivedMetricsWorkInput {
  final String diveId;
  final List<Uint8List> primaryBlobs;
  final List<TankPressureBlob> tankBlobs;
  final DiveMode diveMode;
  final int sourceUpdatedAt;
  final int computedAtMs;

  const DerivedMetricsWorkInput({
    required this.diveId,
    required this.primaryBlobs,
    required this.tankBlobs,
    required this.diveMode,
    required this.sourceUpdatedAt,
    required this.computedAtMs,
  });
}

/// Top-level so `compute` can send it to a worker isolate.
DiveDerivedMetrics computeDerivedMetricsFromBlobs(
  DerivedMetricsWorkInput input,
) {
  const profileCodec = ProfileSeriesCodec();
  const tankCodec = TankPressureCodec();

  final samples = <ProfileSample>[];
  for (final blob in input.primaryBlobs) {
    final decoded = _decodeOrNull(() => profileCodec.decode(blob));
    if (decoded != null) samples.addAll(decoded);
  }
  if (input.primaryBlobs.isNotEmpty && samples.isEmpty) {
    return DiveDerivedMetrics(
      diveId: input.diveId,
      engineVersion: DerivedMetricsService.version,
      sourceUpdatedAt: input.sourceUpdatedAt,
      computedAt: input.computedAtMs,
      unsupportedReason: UnsupportedReason.noProfile,
    );
  }
  if (input.primaryBlobs.length > 1) {
    mergeSort<ProfileSample>(
      samples,
      compare: (a, b) => a.timestamp.compareTo(b.timestamp),
    );
  }

  final tanks = <TankPressureSeries>[];
  for (final blob in input.tankBlobs) {
    final decoded = _decodeOrNull(() => tankCodec.decode(blob.samples));
    if (decoded == null) continue;
    tanks.add(
      TankPressureSeries(
        tankId: blob.tankId,
        volumeLiters: blob.volumeLiters,
        points: [
          for (final p in decoded) (timestamp: p.timestamp, bar: p.pressure),
        ],
      ),
    );
  }

  return DerivedMetricsService.compute(
    diveId: input.diveId,
    samples: samples,
    tanks: tanks,
    diveMode: input.diveMode,
    sourceUpdatedAt: input.sourceUpdatedAt,
    computedAtMs: input.computedAtMs,
  );
}

/// Swallows a corrupt blob so the sweep does not revisit the dive forever,
/// but rethrows a FORWARD version: a dive written by a newer build must stay
/// stale rather than cache an answer this build cannot produce correctly.
List<T>? _decodeOrNull<T>(List<T> Function() decode) {
  try {
    return decode();
  } on UnknownSeriesVersionException catch (e) {
    if (e.isForwardVersion) rethrow;
    return null;
  } catch (_) {
    return null;
  }
}
```

Read `sensor_summary_worker.dart` lines 111 to 125 and copy its `_decodeOrNull` exactly, including the exception type names and the field the codec exposes for a pressure point. The names above are what that file uses at the time of writing; if `TankPressureCodec.decode` returns points with a different field than `pressure`, use the real one.

- [ ] **Step 4: Run test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/data/services/derived_metrics_worker_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/data/services/derived_metrics_worker.dart test/features/dive_log/data/services/derived_metrics_worker_test.dart
git add lib/features/dive_log/data/services/derived_metrics_worker.dart test/features/dive_log/data/services/derived_metrics_worker_test.dart
git commit -m "feat(dive-log): worker that derives metrics from undecoded profile blobs"
```

---
### Task 5: The repository

**Files:**
- Create: `lib/features/dive_log/data/repositories/derived_metrics_repository.dart`
- Test: `test/features/dive_log/data/repositories/derived_metrics_repository_test.dart`

**Interfaces:**
- Consumes: the tables (Task 3), the worker (Task 4), `DerivedMetricsService.isCurrent` (Task 2), `seriesIdChunks` (`lib/features/dive_log/data/repositories/series_id_chunks.dart`), `ProfileSeriesRepository.getPrimaryRowsForDives`, `DatabaseService.instance.database`.
- Produces:
  - `typedef DerivedMetricsRunner = Future<DiveDerivedMetrics> Function(DerivedMetricsWorkInput input);`
  - `class DerivedMetricsRepository { DerivedMetricsRepository({AppDatabase? db, DerivedMetricsRunner? runner}); Future<DiveDerivedMetrics?> ensureCurrent(String diveId, {bool force = false}); Future<List<String>> staleDiveIds({String? diverId}); Future<DiveDerivedMetrics?> getMetrics(String diveId); Future<void> saveMetrics(DiveDerivedMetrics metrics); Stream<void> watchChanges(); }`

The runner indirection is the point: by default it is `compute(computeDerivedMetricsFromBlobs, input)`, and tests substitute a same-isolate runner so they can count invocations and stay deterministic.

Staleness has three cases, exactly as `DiveSensorSummaryRepository.staleDiveIds` has: no row, an older engine version, or a `source_updated_at` that no longer matches the dive's `updated_at`. `force` exists because a data-quality repair can rewrite a profile without touching `updated_at`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/data/repositories/derived_metrics_repository_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_worker.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  var runs = 0;

  DerivedMetricsRepository repo({DiveDerivedMetrics? result}) {
    runs = 0;
    return DerivedMetricsRepository(
      runner: (input) async {
        runs++;
        return result ??
            DiveDerivedMetrics(
              diveId: input.diveId,
              engineVersion: DerivedMetricsService.version,
              sourceUpdatedAt: input.sourceUpdatedAt,
              computedAt: input.computedAtMs,
              finalStopKind: FinalStopKind.safety,
              finalStopDurationSeconds: 180,
              finalStopMaxExcursionMeters: 0.4,
              sacMeanBarPerMin: 0.6,
              sacSlopeBarPerMinPerMin: 0.05,
              sacBuckets: const [
                SacBucket(index: 0, sacBarPerMin: 0.5),
                SacBucket(index: 1, sacBarPerMin: 0.7),
              ],
            );
      },
    );
  }

  Future<void> insertDive(String id, {int? updatedAt}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(updatedAt ?? now),
        ),
      );

  test('ensureCurrent computes, stores and returns the metrics', () async {
    await insertDive('d1');
    final r = repo();
    final metrics = await r.ensureCurrent('d1');
    expect(metrics, isNotNull);
    expect(runs, 1);
    expect(metrics!.finalStopKind, FinalStopKind.safety);
    expect(metrics.sacBuckets.map((b) => b.index), [0, 1]);

    final stored = await r.getMetrics('d1');
    expect(stored!.sacMeanBarPerMin, 0.6);
    expect(stored.sacBuckets.map((b) => b.sacBarPerMin), [0.5, 0.7]);
  });

  test('a second call reads the stored row without recomputing', () async {
    await insertDive('d1');
    final r = repo();
    await r.ensureCurrent('d1');
    await r.ensureCurrent('d1');
    expect(runs, 1);
  });

  test('force recomputes even when the row is current', () async {
    await insertDive('d1');
    final r = repo();
    await r.ensureCurrent('d1');
    await r.ensureCurrent('d1', force: true);
    expect(runs, 2);
  });

  test('a dive that does not exist yields null and no work', () async {
    final r = repo();
    expect(await r.ensureCurrent('missing'), isNull);
    expect(runs, 0);
  });

  test('rewriting the buckets replaces them rather than appending', () async {
    await insertDive('d1');
    final r = repo();
    await r.ensureCurrent('d1');
    await r.ensureCurrent('d1', force: true);
    final stored = await r.getMetrics('d1');
    expect(stored!.sacBuckets, hasLength(2));
  });

  group('staleDiveIds', () {
    test('lists a dive with no row', () async {
      await insertDive('d1');
      expect(await repo().staleDiveIds(), ['d1']);
    });

    test('lists a dive whose engine version is older', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      await db.customStatement(
        'UPDATE dive_derived_metrics SET engine_version = 0',
      );
      expect(await r.staleDiveIds(), ['d1']);
    });

    test('lists a dive whose source stamp drifted', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      await (db.update(db.dives)..where((t) => t.id.equals('d1'))).write(
        DivesCompanion(updatedAt: Value(now + 1)),
      );
      expect(await r.staleDiveIds(), ['d1']);
    });

    test('omits a dive that is current', () async {
      await insertDive('d1');
      final r = repo();
      await r.ensureCurrent('d1');
      expect(await r.staleDiveIds(), isEmpty);
    });

    test('returns the oldest dive first', () async {
      await db.into(db.dives).insert(
        DivesCompanion(
          id: const Value('new'),
          diveDateTime: Value(now + 1000),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await insertDive('old');
      expect(await repo().staleDiveIds(), ['old', 'new']);
    });
  });

  test('the change tick fires on a metrics write', () async {
    await insertDive('d1');
    final r = repo();
    final ticks = <void>[];
    final sub = r.watchChanges().listen(ticks.add);
    await r.ensureCurrent('d1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(ticks, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/data/repositories/derived_metrics_repository_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the repository**

```dart
// lib/features/dive_log/data/repositories/derived_metrics_repository.dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_worker.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

typedef DerivedMetricsRunner =
    Future<DiveDerivedMetrics> Function(DerivedMetricsWorkInput input);

Future<DiveDerivedMetrics> _computeOnIsolate(DerivedMetricsWorkInput input) =>
    compute(computeDerivedMetricsFromBlobs, input);

/// Reads and writes the phase 2 derived metrics, computing them on a worker
/// isolate when the stored row is missing or stale.
///
/// Tests substitute a same-isolate [DerivedMetricsRunner] so they can count
/// invocations and stay deterministic.
class DerivedMetricsRepository {
  DerivedMetricsRepository({AppDatabase? db, DerivedMetricsRunner? runner})
    : _dbOverride = db,
      _runner = runner ?? _computeOnIsolate;

  final AppDatabase? _dbOverride;
  final DerivedMetricsRunner _runner;

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  ProfileSeriesRepository get _series => ProfileSeriesRepository(db: _dbOverride);

  /// The stored metrics when they describe the dive as it is now, otherwise
  /// freshly computed and stored before they are returned. Null when the
  /// dive does not exist.
  ///
  /// [force] rebuilds a row that looks current, for a data-quality repair
  /// that rewrote a profile without touching the dive's `updated_at`.
  Future<DiveDerivedMetrics?> ensureCurrent(
    String diveId, {
    bool force = false,
  }) async {
    final dive = await (_db.select(
      _db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (dive == null) return null;

    if (!force) {
      final stored = await getMetrics(diveId);
      if (stored != null &&
          DerivedMetricsService.isCurrent(stored, dive.updatedAt)) {
        return stored;
      }
    }

    final seriesRows = await _series.getPrimaryRowsForDives([diveId]);
    final tankRows = await (_db.select(
      _db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get();
    final pressureRows = await (_db.select(
      _db.tankPressureSeries,
    )..where((t) => t.diveId.equals(diveId))).get();

    final byTank = {for (final p in pressureRows) p.tankId: p};
    final metrics = await _runner(
      DerivedMetricsWorkInput(
        diveId: diveId,
        primaryBlobs: [for (final r in seriesRows) r.samples],
        tankBlobs: [
          for (final t in tankRows)
            if (byTank[t.id] case final series?)
              TankPressureBlob(
                tankId: t.id,
                volumeLiters: t.volume,
                samples: series.samples,
              ),
        ],
        diveMode: DiveMode.values.firstWhere(
          (m) => m.name == dive.diveMode,
          orElse: () => DiveMode.oc,
        ),
        sourceUpdatedAt: dive.updatedAt,
        computedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await saveMetrics(metrics);
    return metrics;
  }

  Future<DiveDerivedMetrics?> getMetrics(String diveId) async {
    final row = await (_db.select(
      _db.diveDerivedMetricsRows,
    )..where((t) => t.diveId.equals(diveId))).getSingleOrNull();
    if (row == null) return null;
    final buckets =
        await (_db.select(_db.diveSacBuckets)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.bucketIndex)]))
            .get();
    return DiveDerivedMetrics(
      diveId: row.diveId,
      engineVersion: row.engineVersion,
      sourceUpdatedAt: row.sourceUpdatedAt,
      computedAt: row.computedAt,
      finalStopKind: FinalStopKind.values.firstWhere(
        (k) => k.name == row.finalStopKind,
        orElse: () => FinalStopKind.none,
      ),
      finalStopStartSeconds: row.finalStopStartS,
      finalStopDurationSeconds: row.finalStopDurationS,
      finalStopDepthStdDevMeters: row.finalStopDepthStddevM,
      finalStopMaxExcursionMeters: row.finalStopMaxExcursionM,
      sacMeanBarPerMin: row.sacMeanBarMin,
      sacSlopeBarPerMinPerMin: row.sacSlopeBarMinPerMin,
      runtimeSeconds: row.runtimeS,
      unsupportedReason: row.unsupportedReason == null
          ? null
          : UnsupportedReason.values.firstWhere(
              (r) => r.name == row.unsupportedReason,
              orElse: () => UnsupportedReason.noProfile,
            ),
      sacBuckets: [
        for (final b in buckets)
          SacBucket(index: b.bucketIndex, sacBarPerMin: b.sacBarMin),
      ],
    );
  }

  Future<void> saveMetrics(DiveDerivedMetrics m) async {
    await _db.transaction(() async {
      await _db
          .into(_db.diveDerivedMetricsRows)
          .insertOnConflictUpdate(
            DiveDerivedMetricsRowsCompanion(
              diveId: Value(m.diveId),
              engineVersion: Value(m.engineVersion),
              sourceUpdatedAt: Value(m.sourceUpdatedAt),
              computedAt: Value(m.computedAt),
              finalStopKind: Value(m.finalStopKind.name),
              finalStopStartS: Value(m.finalStopStartSeconds),
              finalStopDurationS: Value(m.finalStopDurationSeconds),
              finalStopDepthStddevM: Value(m.finalStopDepthStdDevMeters),
              finalStopMaxExcursionM: Value(m.finalStopMaxExcursionMeters),
              sacMeanBarMin: Value(m.sacMeanBarPerMin),
              sacSlopeBarMinPerMin: Value(m.sacSlopeBarPerMinPerMin),
              runtimeS: Value(m.runtimeSeconds),
              unsupportedReason: Value(m.unsupportedReason?.name),
            ),
          );
      // Replace rather than merge: a rebuild can produce fewer buckets than
      // the previous run, and a stale tail would skew every later average.
      await (_db.delete(
        _db.diveSacBuckets,
      )..where((t) => t.diveId.equals(m.diveId))).go();
      if (m.sacBuckets.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAll(_db.diveSacBuckets, [
            for (final b in m.sacBuckets)
              DiveSacBucketsCompanion.insert(
                diveId: m.diveId,
                bucketIndex: b.index,
                sacBarMin: b.sacBarPerMin,
              ),
          ]);
        });
      }
    });
  }

  /// Dives whose row is missing, built by an older engine, or built from a
  /// different dive version. Oldest dive first, so a sweep makes the most
  /// recently viewed dives current last.
  // stats-scope-exempt: a work list, not an aggregate; an excluded dive
  // still needs its metrics for the filter to answer about it.
  Future<List<String>> staleDiveIds({String? diverId}) async {
    final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
    final rows = await _db
        .customSelect(
          'SELECT d.id AS id FROM dives d '
          'LEFT JOIN dive_derived_metrics m ON m.dive_id = d.id '
          'WHERE (m.dive_id IS NULL OR m.engine_version < ? '
          'OR m.source_updated_at != d.updated_at) $diverFilter '
          'ORDER BY d.dive_date_time ASC, d.id ASC',
          variables: [
            Variable(DerivedMetricsService.version),
            if (diverId != null) Variable(diverId),
          ],
          readsFrom: {_db.dives, _db.diveDerivedMetricsRows},
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.diveDerivedMetricsRows),
      TableUpdateQuery.onTable(_db.diveSacBuckets),
    ]),
  );
}
```

Check `ProfileSeriesRepository`'s constructor parameter name before using `db:`, and `dive_tanks`'s volume column name (`volume` at the time of writing). The compile error names both if they differ.

- [ ] **Step 4: Run test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/data/repositories/derived_metrics_repository_test.dart test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS. The census passes because `staleDiveIds` carries the exempt marker.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/data/repositories/derived_metrics_repository.dart test/features/dive_log/data/repositories/derived_metrics_repository_test.dart
git add lib/features/dive_log/data/repositories/derived_metrics_repository.dart test/features/dive_log/data/repositories/derived_metrics_repository_test.dart
git commit -m "feat(dive-log): compute-through-cache repository for the derived metrics"
```

---

### Task 6: The scheduler and its hooks

**Files:**
- Create: `lib/features/dive_log/data/services/derived_metrics_scheduler.dart`
- Modify: `test/flutter_test_config.dart` (beside `SensorSummaryScheduler.enabled = false;`)
- Modify: `lib/app.dart` (beside the existing `scheduleStaleSweep()` call in the post-frame callback)
- Modify: every site that already calls `scheduleSensorSummaryRefresh`: `lib/features/dive_computer/data/adapters/dive_computer_adapter.dart`, `lib/features/universal_import/data/adapters/universal_adapter.dart`, `lib/features/health/data/adapters/healthkit_adapter.dart`, the Garmin and Suunto cloud adapters, `dive_edit_page.dart`, `dive_detail_page.dart`, `run_dive_consolidation.dart`, `combine_dives_dialog.dart`, `reparse_service.dart`, `quality_repair_executor.dart`, `data_quality_inbox_page.dart`, `sync_providers.dart`, `backup_providers.dart`
- Test: `test/features/dive_log/data/services/derived_metrics_scheduler_test.dart`

**Interfaces:**
- Consumes: `DerivedMetricsRepository` (Task 5).
- Produces: `class DerivedMetricsScheduler { static final DerivedMetricsScheduler instance; static bool enabled; DerivedMetricsRepository Function() repositoryFactory; void schedule(Set<String> diveIds, {bool force = false}); void scheduleStaleSweep({String? diverId}); Future<void> get idle; }` and the free function `void scheduleDerivedMetricsRefresh(Set<String> diveIds, {bool force = false})`.

Copy `sensor_summary_scheduler.dart` structurally. Two properties it has are not optional:

1. **The queued callback must always complete normally.** An error escaping it leaves the `_tail` future completed with that error, and every later `schedule` chains onto a failed future and silently never runs. Hence an outer try/catch around the drain and an inner one per dive.
2. **The `enabled` guard sits after the test listener fires**, so a widget test can assert which ids a write asked for without the work happening.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/data/services/derived_metrics_scheduler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';

class _RecordingRepo implements DerivedMetricsRepository {
  final List<({String id, bool force})> calls = [];
  final List<String> stale;
  bool throwOnce = false;

  _RecordingRepo({this.stale = const []});

  @override
  Future<DiveDerivedMetrics?> ensureCurrent(
    String diveId, {
    bool force = false,
  }) async {
    calls.add((id: diveId, force: force));
    if (throwOnce) {
      throwOnce = false;
      throw StateError('boom');
    }
    return DiveDerivedMetrics(
      diveId: diveId,
      engineVersion: DerivedMetricsService.version,
      sourceUpdatedAt: 0,
      computedAt: 0,
    );
  }

  @override
  Future<List<String>> staleDiveIds({String? diverId}) async => stale;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingRepo repo;

  setUp(() {
    DerivedMetricsScheduler.enabled = true;
    repo = _RecordingRepo();
    DerivedMetricsScheduler.instance.repositoryFactory = () => repo;
  });

  tearDown(() {
    DerivedMetricsScheduler.enabled = false;
    DerivedMetricsScheduler.instance.repositoryFactory =
        DerivedMetricsRepository.new;
  });

  test('a scheduled dive is refreshed once', () async {
    DerivedMetricsScheduler.instance.schedule({'d1'});
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id), ['d1']);
  });

  test('a burst merges into one drain', () async {
    DerivedMetricsScheduler.instance
      ..schedule({'d1'})
      ..schedule({'d2'})
      ..schedule({'d1'});
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id).toSet(), {'d1', 'd2'});
    expect(repo.calls, hasLength(2));
  });

  test('force is carried through', () async {
    DerivedMetricsScheduler.instance.schedule({'d1'}, force: true);
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.single.force, isTrue);
  });

  test('a failure on one dive does not poison the queue', () async {
    repo.throwOnce = true;
    DerivedMetricsScheduler.instance.schedule({'bad'});
    await DerivedMetricsScheduler.instance.idle;
    DerivedMetricsScheduler.instance.schedule({'good'});
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id), ['bad', 'good']);
  });

  test('the sweep refreshes every stale dive', () async {
    repo = _RecordingRepo(stale: const ['a', 'b']);
    DerivedMetricsScheduler.instance.repositoryFactory = () => repo;
    DerivedMetricsScheduler.instance.scheduleStaleSweep();
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls.map((c) => c.id), ['a', 'b']);
  });

  test('disabled means no work, which is how the suite stays quiet', () async {
    DerivedMetricsScheduler.enabled = false;
    DerivedMetricsScheduler.instance.schedule({'d1'});
    await DerivedMetricsScheduler.instance.idle;
    expect(repo.calls, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/data/services/derived_metrics_scheduler_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the scheduler**

```dart
// lib/features/dive_log/data/services/derived_metrics_scheduler.dart
import 'package:flutter/foundation.dart';

import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';

/// Keeps the phase 2 derived metrics current without blocking a write.
///
/// Modelled on SensorSummaryScheduler: one singleton, one serialised tail,
/// bursts merged into a single drain. Every entry point is fire and forget.
class DerivedMetricsScheduler {
  DerivedMetricsScheduler._();

  static final DerivedMetricsScheduler instance = DerivedMetricsScheduler._();

  /// Flipped off for the whole suite in `test/flutter_test_config.dart`: a
  /// widget test that writes a dive must not start isolate work.
  static bool enabled = true;

  @visibleForTesting
  DerivedMetricsRepository Function() repositoryFactory =
      DerivedMetricsRepository.new;

  /// Fires with the ids a caller asked for, before the [enabled] guard, so a
  /// test can assert the request without the work happening.
  @visibleForTesting
  void Function(Set<String> diveIds, bool force)? requestListener;

  Future<void> _tail = Future.value();
  final Set<String> _pending = {};
  final Set<String> _forced = {};
  bool _sweepPending = false;
  String? _sweepDiverId;

  /// Awaited by tests; resolves when the queue has drained.
  @visibleForTesting
  Future<void> get idle => _tail;

  void schedule(Set<String> diveIds, {bool force = false}) {
    requestListener?.call(diveIds, force);
    if (!enabled || diveIds.isEmpty) return;
    _pending.addAll(diveIds);
    if (force) _forced.addAll(diveIds);
    _enqueue();
  }

  void scheduleStaleSweep({String? diverId}) {
    requestListener?.call(const {}, false);
    if (!enabled) return;
    _sweepPending = true;
    _sweepDiverId = diverId;
    _enqueue();
  }

  void _enqueue() {
    // The callback must ALWAYS complete normally. An error escaping it
    // leaves _tail completed with that error, and every later schedule
    // chains onto a failed future and silently never runs again.
    _tail = _tail.then((_) async {
      try {
        final repo = repositoryFactory();

        if (_sweepPending) {
          _sweepPending = false;
          final diverId = _sweepDiverId;
          _sweepDiverId = null;
          try {
            _pending.addAll(await repo.staleDiveIds(diverId: diverId));
          } catch (_) {
            // A failed sweep must not stop the per-dive refreshes.
          }
        }

        final ids = _pending.toList();
        final forced = {..._forced};
        _pending.clear();
        _forced.clear();

        for (final id in ids) {
          try {
            await repo.ensureCurrent(id, force: forced.contains(id));
          } catch (_) {
            // One unreadable dive must not strand the rest of the batch.
          }
        }
      } catch (_) {
        // Nothing here may escape; see the comment above.
      }
    });
  }
}

/// Free function so call sites do not import the singleton.
void scheduleDerivedMetricsRefresh(
  Set<String> diveIds, {
  bool force = false,
}) => DerivedMetricsScheduler.instance.schedule(diveIds, force: force);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/data/services/derived_metrics_scheduler_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Disable it for the suite and wire the hooks**

In `test/flutter_test_config.dart`, beside the other two:

```dart
  DerivedMetricsScheduler.enabled = false;
```

In `lib/app.dart`, beside the existing sweep call in the post-frame callback:

```dart
      DerivedMetricsScheduler.instance.scheduleStaleSweep();
```

At every site that already calls `scheduleSensorSummaryRefresh(ids)`, add the sibling call with the same ids and the same `force` value. Find them with:

```bash
grep -rn "scheduleSensorSummaryRefresh\|SensorSummaryScheduler.instance.schedule" lib | grep -v "sensor_summary_scheduler.dart"
```

and add `scheduleDerivedMetricsRefresh(<same ids>, force: <same>);` immediately after each. The two schedulers are deliberately separate: their engines version independently, so a bump to one must not rebuild the other's rows.

- [ ] **Step 6: Run the touched suites**

Run: `TMPDIR=/tmp flutter test test/features/dive_log test/features/universal_import test/features/data_quality`
Expected: PASS. A widget test that counts scheduler calls may need the new scheduler disabled explicitly; it already is, suite-wide.

- [ ] **Step 7: Commit**

```bash
dart format lib test/flutter_test_config.dart test/features/dive_log
git add lib/features/dive_log/data/services/derived_metrics_scheduler.dart test/features/dive_log/data/services/derived_metrics_scheduler_test.dart test/flutter_test_config.dart lib/app.dart lib/features
git commit -m "feat(dive-log): single-flight scheduler that keeps the derived metrics current"
```

---
### Task 7: The predicate types and the shared SQL builder

**Files:**
- Create: `lib/features/explore/domain/derived_predicates.dart`
- Modify: `lib/features/statistics/data/dive_filter_sql.dart` (a new `derivedPredicateCondition` beside `decoSignalCondition` near line 360)
- Test: `test/features/explore/domain/derived_predicates_test.dart`

**Interfaces:**
- Consumes: `SacTrend`, `FinalStopKind` (Task 1); `SafetyRuleId` (`lib/features/dive_log/domain/entities/safety_finding.dart`).
- Produces:
  - `sealed class DerivedPredicate` with `const` subclasses `SacTrendIs(SacTrend trend)`, `SacRoseAfter({required int minutes, double ratio = 1.1})`, `FinalStopUnstable({double thresholdMeters = 1.0})`, `FinalStopDuration({int? minSeconds, int? maxSeconds})`, `HasFinding(SafetyRuleId rule)`, each with value equality.
  - `class DerivedConditionsKey { final List<DerivedPredicate> predicates; const DerivedConditionsKey(this.predicates); }` with element-wise `==` and `Object.hashAll`, because a `List` family argument compares by identity and would make a family provider miss its cache on every rebuild.
  - `({String sql, List<Object?> params}) derivedPredicateCondition(DerivedPredicate p, {required String diveIdRef})` in `dive_filter_sql.dart`: the ONLY implementation, shared by the statistics subquery, the paginated list and the id-set query, so the three paths cannot disagree.

SQL per predicate, all correlated `EXISTS` or scalar lookups against `diveIdRef`:

| Predicate | Condition |
| --- | --- |
| `SacTrendIs` | `EXISTS (SELECT 1 FROM dive_derived_metrics m WHERE m.dive_id = <ref> AND m.sac_slope_bar_min_per_min IS NOT NULL AND <band test>)` where rising is `> ?`, falling is `< -?`, flat is `BETWEEN -? AND ?` |
| `SacRoseAfter` | compares two averages over `dive_sac_buckets`: the mean of buckets with `bucket_index >= ?` against the mean of the earlier ones, requiring both to exist and the later to exceed the earlier by the ratio |
| `FinalStopUnstable` | `EXISTS (... AND m.final_stop_kind <> 'none' AND m.final_stop_max_excursion_m > ?)` |
| `FinalStopDuration` | `EXISTS (... AND m.final_stop_duration_s IS NOT NULL AND m.final_stop_duration_s >= ? AND <= ?)` |
| `HasFinding` | `EXISTS (SELECT 1 FROM dive_safety_findings f WHERE f.dive_id = <ref> AND f.rule_id = ? AND f.dismissed_at IS NULL)` |

- [ ] **Step 1: Write the failing test**

```dart
// test/features/explore/domain/derived_predicates_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/explore/domain/derived_predicates.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

void main() {
  test('predicates compare by value, so a family key caches', () {
    expect(
      const SacTrendIs(SacTrend.rising),
      const SacTrendIs(SacTrend.rising),
    );
    expect(
      const SacRoseAfter(minutes: 20),
      const SacRoseAfter(minutes: 20),
    );
    expect(
      const SacRoseAfter(minutes: 20),
      isNot(const SacRoseAfter(minutes: 30)),
    );
    expect(
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]),
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]),
    );
    expect(
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]).hashCode,
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]).hashCode,
    );
    expect(
      const DerivedConditionsKey([SacTrendIs(SacTrend.rising)]),
      isNot(const DerivedConditionsKey([SacTrendIs(SacTrend.falling)])),
    );
  });

  test('every predicate binds its values rather than inlining them', () {
    final predicates = <DerivedPredicate>[
      const SacTrendIs(SacTrend.rising),
      const SacRoseAfter(minutes: 20),
      const FinalStopUnstable(),
      const FinalStopDuration(minSeconds: 120),
      const HasFinding(SafetyRuleId.rapidAscent),
    ];
    for (final p in predicates) {
      final c = derivedPredicateCondition(p, diveIdRef: 'dives.id');
      expect(c.sql, contains('dives.id'), reason: '$p');
      expect(c.sql, contains('?'), reason: '$p');
      expect(c.params, isNotEmpty, reason: '$p');
      // A bound value must never be spliced into the text.
      expect(c.sql, isNot(contains('20')), reason: '$p');
    }
  });

  test('the trend bands are expressed as an explicit range', () {
    final flat = derivedPredicateCondition(
      const SacTrendIs(SacTrend.flat),
      diveIdRef: 'd.id',
    );
    expect(flat.sql, contains('BETWEEN'));
    expect(flat.params, hasLength(2));

    final rising = derivedPredicateCondition(
      const SacTrendIs(SacTrend.rising),
      diveIdRef: 'd.id',
    );
    expect(rising.sql, contains('>'));
  });

  test('a dismissed finding does not count', () {
    final c = derivedPredicateCondition(
      const HasFinding(SafetyRuleId.omittedSafetyStop),
      diveIdRef: 'd.id',
    );
    expect(c.sql, contains('dismissed_at IS NULL'));
    expect(c.params, ['omittedSafetyStop']);
  });

  test('an unbounded duration binds only the bound that is set', () {
    final minOnly = derivedPredicateCondition(
      const FinalStopDuration(minSeconds: 120),
      diveIdRef: 'd.id',
    );
    expect(minOnly.params, [120]);
    final both = derivedPredicateCondition(
      const FinalStopDuration(minSeconds: 120, maxSeconds: 300),
      diveIdRef: 'd.id',
    );
    expect(both.params, [120, 300]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/explore/domain/derived_predicates_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the predicate types**

```dart
// lib/features/explore/domain/derived_predicates.dart
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

/// A question about a dive that only the phase 2 derived tables can answer.
///
/// Every one is SQL-only: `DiveFilterState.apply` cannot evaluate it because
/// the entity carries no profile, so callers intersect an id set instead,
/// exactly as the deco axis works.
sealed class DerivedPredicate {
  const DerivedPredicate();
}

class SacTrendIs extends DerivedPredicate {
  final SacTrend trend;

  /// The band around zero the engine treats as noise, in bar per minute per
  /// minute. Kept here so the SQL and [DiveDerivedMetrics.trend] agree.
  final double flatBand;

  const SacTrendIs(this.trend, {this.flatBand = 0.02});

  @override
  bool operator ==(Object other) =>
      other is SacTrendIs && other.trend == trend && other.flatBand == flatBand;

  @override
  int get hashCode => Object.hash(trend, flatBand);

  @override
  String toString() => 'SacTrendIs(${trend.name})';
}

/// SAC after [minutes] exceeded SAC before it by at least [ratio].
class SacRoseAfter extends DerivedPredicate {
  final int minutes;
  final double ratio;

  const SacRoseAfter({required this.minutes, this.ratio = 1.1});

  @override
  bool operator ==(Object other) =>
      other is SacRoseAfter && other.minutes == minutes && other.ratio == ratio;

  @override
  int get hashCode => Object.hash(minutes, ratio);

  @override
  String toString() => 'SacRoseAfter($minutes, $ratio)';
}

class FinalStopUnstable extends DerivedPredicate {
  /// How far the diver may stray from the stop's median depth before the
  /// stop counts as unstable. The chip shows this number.
  final double thresholdMeters;

  const FinalStopUnstable({this.thresholdMeters = 1.0});

  @override
  bool operator ==(Object other) =>
      other is FinalStopUnstable && other.thresholdMeters == thresholdMeters;

  @override
  int get hashCode => thresholdMeters.hashCode;

  @override
  String toString() => 'FinalStopUnstable($thresholdMeters)';
}

class FinalStopDuration extends DerivedPredicate {
  final int? minSeconds;
  final int? maxSeconds;

  const FinalStopDuration({this.minSeconds, this.maxSeconds});

  @override
  bool operator ==(Object other) =>
      other is FinalStopDuration &&
      other.minSeconds == minSeconds &&
      other.maxSeconds == maxSeconds;

  @override
  int get hashCode => Object.hash(minSeconds, maxSeconds);

  @override
  String toString() => 'FinalStopDuration($minSeconds, $maxSeconds)';
}

class HasFinding extends DerivedPredicate {
  final SafetyRuleId rule;

  const HasFinding(this.rule);

  @override
  bool operator ==(Object other) => other is HasFinding && other.rule == rule;

  @override
  int get hashCode => rule.hashCode;

  @override
  String toString() => 'HasFinding(${rule.name})';
}

/// A value-equal wrapper, because a `List` passed as a family argument
/// compares by IDENTITY: without this the id-set provider would miss its
/// cache on every rebuild and requery on each frame.
class DerivedConditionsKey {
  final List<DerivedPredicate> predicates;

  const DerivedConditionsKey(this.predicates);

  @override
  bool operator ==(Object other) {
    if (other is! DerivedConditionsKey) return false;
    if (other.predicates.length != predicates.length) return false;
    for (var i = 0; i < predicates.length; i++) {
      if (other.predicates[i] != predicates[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(predicates);
}
```

- [ ] **Step 4: Write the SQL builder**

In `lib/features/statistics/data/dive_filter_sql.dart`, beside `decoSignalCondition`:

```dart
/// SQL for one [DerivedPredicate]: a correlated EXISTS against the phase 2
/// derived tables. [diveIdRef] names the outer dive id column (`dives.id` in
/// [buildFilteredDiveIdSubquery], `d.id` in DiveRepository).
///
/// This is the ONLY implementation of the derived axis. It is shared by the
/// statistics subquery, the paginated list and the id-set query, so those
/// three cannot disagree about which dives match.
({String sql, List<Object?> params}) derivedPredicateCondition(
  DerivedPredicate predicate, {
  required String diveIdRef,
}) {
  switch (predicate) {
    case SacTrendIs(:final trend, :final flatBand):
      final band = switch (trend) {
        SacTrend.rising => 'm.sac_slope_bar_min_per_min > ?',
        SacTrend.falling => 'm.sac_slope_bar_min_per_min < ?',
        SacTrend.flat => 'm.sac_slope_bar_min_per_min BETWEEN ? AND ?',
      };
      final params = switch (trend) {
        SacTrend.rising => <Object?>[flatBand],
        SacTrend.falling => <Object?>[-flatBand],
        SacTrend.flat => <Object?>[-flatBand, flatBand],
      };
      return (
        sql:
            'EXISTS (SELECT 1 FROM dive_derived_metrics m '
            'WHERE m.dive_id = $diveIdRef '
            'AND m.sac_slope_bar_min_per_min IS NOT NULL AND $band)',
        params: params,
      );

    case SacRoseAfter(:final minutes, :final ratio):
      // Two averages over the bucket table. Both halves must exist, or a
      // dive that simply ended before the mark would look like a riser.
      final bucket = (minutes * 60) ~/ kSacBucketSeconds;
      return (
        sql:
            '(SELECT AVG(CASE WHEN b.bucket_index >= ? THEN b.sac_bar_min END) '
            '> ? * AVG(CASE WHEN b.bucket_index < ? THEN b.sac_bar_min END) '
            'FROM dive_sac_buckets b WHERE b.dive_id = $diveIdRef)',
        params: <Object?>[bucket, ratio, bucket],
      );

    case FinalStopUnstable(:final thresholdMeters):
      return (
        sql:
            'EXISTS (SELECT 1 FROM dive_derived_metrics m '
            'WHERE m.dive_id = $diveIdRef '
            "AND m.final_stop_kind <> 'none' "
            'AND m.final_stop_max_excursion_m IS NOT NULL '
            'AND m.final_stop_max_excursion_m > ?)',
        params: <Object?>[thresholdMeters],
      );

    case FinalStopDuration(:final minSeconds, :final maxSeconds):
      final clauses = <String>[];
      final params = <Object?>[];
      if (minSeconds != null) {
        clauses.add('m.final_stop_duration_s >= ?');
        params.add(minSeconds);
      }
      if (maxSeconds != null) {
        clauses.add('m.final_stop_duration_s <= ?');
        params.add(maxSeconds);
      }
      final extra = clauses.isEmpty ? '' : 'AND ${clauses.join(' AND ')}';
      return (
        sql:
            'EXISTS (SELECT 1 FROM dive_derived_metrics m '
            'WHERE m.dive_id = $diveIdRef '
            'AND m.final_stop_duration_s IS NOT NULL $extra)',
        params: params,
      );

    case HasFinding(:final rule):
      // A dismissed finding is one the diver has answered, so it must not
      // keep the dive in a filtered list.
      return (
        sql:
            'EXISTS (SELECT 1 FROM dive_safety_findings f '
            'WHERE f.dive_id = $diveIdRef AND f.rule_id = ? '
            'AND f.dismissed_at IS NULL)',
        params: <Object?>[rule.dbValue],
      );
  }
}
```

Add the imports for `DerivedPredicate`, `SacTrend` and `kSacBucketSeconds` at the top of that file.

- [ ] **Step 5: Run test to verify it passes**

Run: `TMPDIR=/tmp flutter test test/features/explore/domain/derived_predicates_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/explore/domain/derived_predicates.dart lib/features/statistics/data/dive_filter_sql.dart test/features/explore/domain/derived_predicates_test.dart
git add lib/features/explore/domain/derived_predicates.dart lib/features/statistics/data/dive_filter_sql.dart test/features/explore/domain/derived_predicates_test.dart
git commit -m "feat(explore): derived predicate types and the one SQL builder all paths share"
```

---

### Task 8: The filter axis through all three paths

**Files:**
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart`
- Modify: `lib/features/statistics/data/dive_filter_sql.dart` (inside `buildFilteredDiveIdSubquery`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`_buildFilterWhereClauses`, a new `getDiveIdsMatchingDerived`, a new `watchDerivedMetricsFilterChanges`)
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (`derivedFilteredDiveIdsProvider`, the intersection in `filteredDivesProvider`, the tick in `orderedDiveIdsProvider`, the paginator's follower)
- Modify: `test/architecture/repository_tick_stream_test.dart` (register the new stream)
- Test: `test/features/dive_log/data/repositories/dive_repository_derived_filter_test.dart`

**Interfaces:**
- Consumes: Task 7.
- Produces: `DiveFilterState.derivedPredicates` (a `List<DerivedPredicate>`, default const []), `bool get readsDerivedMetrics`, the `copyWith` parameter and `clearDerivedPredicates` flag, `DiveRepository.getDiveIdsMatchingDerived(List<DerivedPredicate>, {String? diverId})`, `DiveRepository.watchDerivedMetricsFilterChanges()`, and `derivedFilteredDiveIdsProvider` (a `FutureProvider.family<Set<String>, DerivedConditionsKey>`).

This axis is SQL-only. `apply` must NOT evaluate it: the entity carries no profile, so evaluating it there would silently match nothing. Document that in `apply`'s doc comment beside the existing `decoOnly` note.

- [ ] **Step 1: Write the failing parity test**

```dart
// test/features/dive_log/data/repositories/dive_repository_derived_filter_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/derived_predicates.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../../helpers/test_database.dart';

/// Statistics, the paginated list, its count and the id query must select
/// the same dives for every derived predicate (the three-path rule).
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> dive(String id) => db.into(db.dives).insert(
    DivesCompanion(
      id: Value(id),
      diveDateTime: Value(now),
      createdAt: Value(now),
      updatedAt: Value(now),
    ),
  );

  Future<void> metrics(
    String id, {
    double? slope,
    String stopKind = 'none',
    double? excursion,
    int? stopDuration,
  }) => db.into(db.diveDerivedMetricsRows).insert(
    DiveDerivedMetricsRowsCompanion.insert(
      diveId: id,
      engineVersion: 1,
      sourceUpdatedAt: now,
      computedAt: now,
      finalStopKind: Value(stopKind),
      finalStopMaxExcursionM: Value(excursion),
      finalStopDurationS: Value(stopDuration),
      sacSlopeBarMinPerMin: Value(slope),
    ),
  );

  Future<void> buckets(String id, List<double> values) async {
    for (var i = 0; i < values.length; i++) {
      await db.into(db.diveSacBuckets).insert(
        DiveSacBucketsCompanion.insert(
          diveId: id,
          bucketIndex: i,
          sacBarMin: values[i],
        ),
      );
    }
  }

  Future<void> finding(String id, SafetyRuleId rule, {int? dismissedAt}) =>
      db.into(db.diveSafetyFindings).insert(
        DiveSafetyFindingsCompanion.insert(
          id: '$id-${rule.name}',
          diveId: id,
          ruleId: rule.dbValue,
          severity: 'caution',
          engineVersion: 1,
          createdAt: now,
          dismissedAt: Value(dismissedAt),
        ),
      );

  Future<Set<String>> statsIds(DiveFilterState f) async {
    final q = buildFilteredDiveIdSubquery(f);
    final rows = await db
        .customSelect(
          q.subquery,
          variables: q.params.map((p) => Variable(p)).toList(),
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  Future<void> expectParity(
    List<DerivedPredicate> predicates,
    Set<String> expected,
  ) async {
    final f = DiveFilterState(derivedPredicates: predicates);
    expect(await statsIds(f), expected, reason: 'statistics');
    expect(
      (await repo.getDiveSummaries(filter: f)).map((s) => s.id).toSet(),
      expected,
      reason: 'list',
    );
    expect(await repo.getDiveCount(filter: f), expected.length, reason: 'count');
    expect(
      await repo.getDiveIdsMatchingDerived(predicates),
      expected,
      reason: 'id query',
    );
  }

  test('SAC trend', () async {
    await dive('rising');
    await dive('falling');
    await dive('flat');
    await dive('unknown');
    await metrics('rising', slope: 0.5);
    await metrics('falling', slope: -0.5);
    await metrics('flat', slope: 0.001);
    await metrics('unknown');
    await expectParity([const SacTrendIs(SacTrend.rising)], {'rising'});
    await expectParity([const SacTrendIs(SacTrend.falling)], {'falling'});
    await expectParity([const SacTrendIs(SacTrend.flat)], {'flat'});
  });

  test('SAC rose after a mark', () async {
    await dive('rose');
    await dive('steady');
    await dive('short');
    // Four buckets: 20 minutes is bucket 4, so give each dive six.
    await buckets('rose', [0.4, 0.4, 0.4, 0.4, 0.9, 0.9]);
    await buckets('steady', [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]);
    // Ends before the mark: it must not count as a riser.
    await buckets('short', [0.4, 0.4]);
    await expectParity([const SacRoseAfter(minutes: 20)], {'rose'});
  });

  test('final stop stability and duration', () async {
    await dive('wobbly');
    await dive('steady');
    await dive('nostop');
    await metrics('wobbly', stopKind: 'safety', excursion: 2.4, stopDuration: 200);
    await metrics('steady', stopKind: 'safety', excursion: 0.2, stopDuration: 180);
    await metrics('nostop', excursion: 5.0);
    await expectParity([const FinalStopUnstable()], {'wobbly'});
    await expectParity(
      [const FinalStopDuration(minSeconds: 190)],
      {'wobbly'},
    );
  });

  test('safety findings, ignoring dismissed ones', () async {
    await dive('fast');
    await dive('answered');
    await dive('clean');
    await finding('fast', SafetyRuleId.rapidAscent);
    await finding('answered', SafetyRuleId.rapidAscent, dismissedAt: now);
    await expectParity([const HasFinding(SafetyRuleId.rapidAscent)], {'fast'});
  });

  test('several predicates AND together', () async {
    await dive('both');
    await dive('one');
    await metrics('both', slope: 0.5, stopKind: 'safety', excursion: 2.0);
    await metrics('one', slope: 0.5, stopKind: 'safety', excursion: 0.1);
    await expectParity(
      [const SacTrendIs(SacTrend.rising), const FinalStopUnstable()],
      {'both'},
    );
  });

  test('apply leaves the axis to SQL', () async {
    // The entity carries no profile, so evaluating this in memory would
    // match nothing at all; callers intersect an id set instead.
    const f = DiveFilterState(derivedPredicates: [FinalStopUnstable()]);
    expect(f.readsDerivedMetrics, isTrue);
    expect(f.apply(const []), isEmpty);
  });

  test('the derived tick fires on a metrics write alone', () async {
    await dive('d1');
    final ticks = <void>[];
    final sub = repo.watchDerivedMetricsFilterChanges().listen(ticks.add);
    await metrics('d1', slope: 0.1);
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    await sub.cancel();
    expect(ticks, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/data/repositories/dive_repository_derived_filter_test.dart`
Expected: FAIL, `derivedPredicates` is not a parameter of `DiveFilterState`.

- [ ] **Step 3: Add the axis to the filter**

In `dive_filter_state.dart`, import `derived_predicates.dart`, add the field after `speciesIds`:

```dart
  /// Questions only the phase 2 derived tables can answer, combined with
  /// AND. SQL-only, like [decoOnly]: [apply] skips them and callers
  /// intersect `derivedFilteredDiveIdsProvider`.
  final List<DerivedPredicate> derivedPredicates;
```

add `this.derivedPredicates = const [],` to the constructor, extend `hasActiveFilters` with `|| derivedPredicates.isNotEmpty`, add the `copyWith` parameter and `clearDerivedPredicates` flag following the existing pattern, and add:

```dart
  /// Whether a filter reads the derived-metric tables, which are written by
  /// the sweep without a `dives` write.
  bool get readsDerivedMetrics => derivedPredicates.isNotEmpty;
```

Extend `apply`'s doc comment beside the `decoOnly` paragraph:

```dart
  /// [derivedPredicates]: the derived metrics live in their own tables and
  /// never reach the entity, so only SQL can see them. Callers intersect
  /// this result with `derivedFilteredDiveIdsProvider`.
```

and add NOTHING to `apply`'s body.

- [ ] **Step 4: Add the two SQL paths and the id query**

In `buildFilteredDiveIdSubquery`, beside the equipment-attribute loop:

```dart
  // Derived metrics: one EXISTS per predicate, so they AND.
  for (final predicate in filter.derivedPredicates) {
    final c = derivedPredicateCondition(predicate, diveIdRef: 'dives.id');
    conditions.add(c.sql);
    params.addAll(c.params);
  }
```

In `_buildFilterWhereClauses`, beside its equipment-attribute loop:

```dart
    for (final predicate in filter.derivedPredicates) {
      final c = derivedPredicateCondition(predicate, diveIdRef: 'd.id');
      clauses.add(c.sql);
      args.addAll(c.params.map((p) => Variable<Object>(p)));
    }
```

Add the id query beside `getDiveIdsMatchingEquipmentAttrs`:

```dart
  /// The ids of every dive matching [predicates], for the in-memory paths
  /// that cannot evaluate a derived axis.
  // stats-scope-exempt: a view filter, not an aggregate; the scope is
  // applied alongside this by the callers that need it.
  Future<Set<String>> getDiveIdsMatchingDerived(
    List<DerivedPredicate> predicates, {
    String? diverId,
  }) async {
    if (predicates.isEmpty) return const {};
    final clauses = <String>[];
    final args = <Variable<Object>>[];
    for (final predicate in predicates) {
      final c = derivedPredicateCondition(predicate, diveIdRef: 'd.id');
      clauses.add(c.sql);
      args.addAll(c.params.map((p) => Variable<Object>(p)));
    }
    if (diverId != null) {
      clauses.add('d.diver_id = ?');
      args.add(Variable(diverId));
    }
    final rows = await _db
        .customSelect(
          'SELECT d.id AS id FROM dives d WHERE ${clauses.join(' AND ')}',
          variables: args,
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  /// Change tick for a list filtered by a derived predicate: the sweep
  /// writes those tables without a `dives` write, so the dives tick alone
  /// would leave the list stale.
  Stream<void> watchDerivedMetricsFilterChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.diveDerivedMetricsRows),
          TableUpdateQuery.onTable(_db.diveSacBuckets),
          TableUpdateQuery.onTable(_db.diveSafetyFindings),
        ]),
      )
      .debounce(changeTickDebounce);
```

- [ ] **Step 5: Wire the providers**

In `dive_providers.dart`, beside `equipmentAttrFilteredDiveIdsProvider`:

```dart
/// The ids of every dive matching the derived predicates.
///
/// Keyed on [DerivedConditionsKey], which compares element by element, so a
/// changed predicate set lands on a fresh instance rather than briefly
/// reusing the previous set's ids.
final derivedFilteredDiveIdsProvider =
    FutureProvider.family<Set<String>, DerivedConditionsKey>((ref, key) async {
      final diverId = ref.watch(currentDiverIdProvider);
      final repository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchDerivedMetricsFilterChanges());
      return repository.getDiveIdsMatchingDerived(
        key.predicates,
        diverId: diverId,
      );
    });
```

In `filteredDivesProvider`, add to the `idSets` list:

```dart
    if (filter.derivedPredicates.isNotEmpty)
      ref.watch(
        derivedFilteredDiveIdsProvider(
          DerivedConditionsKey(filter.derivedPredicates),
        ),
      ),
```

In `orderedDiveIdsProvider`, beside the sightings block:

```dart
  if (filter.readsDerivedMetrics) {
    ref.invalidateSelfWhen(repository.watchDerivedMetricsFilterChanges());
  }
```

In `PaginatedDiveListNotifier`, add a follower beside `_sightingsFilterTick`, cancel it in the same `onDispose`, and drive it in `_followFilterTicks` with `_derivedFilterTick.follow(filter.readsDerivedMetrics)`. Subscribing only while the axis is set is deliberate: many test fakes `implements DiveRepository` and would hit `noSuchMethod` on an unconditional subscription.

Register the new stream in `test/architecture/repository_tick_stream_test.dart` beside `watchSightingsFilterChanges`.

- [ ] **Step 6: Run the parity test and the guards**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/data/repositories/dive_repository_derived_filter_test.dart test/features/dive_log/domain/models/dive_filter_state_test.dart test/architecture test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib test/features/dive_log test/architecture
git add lib/features/dive_log/domain/models/dive_filter_state.dart lib/features/statistics/data/dive_filter_sql.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/data/repositories/dive_repository_derived_filter_test.dart test/architecture/repository_tick_stream_test.dart
git commit -m "feat(dive-log): evaluate the derived predicates in all three filter paths"
```

---

### Task 9: The compiler fields, labels and prompt

**Files:**
- Modify: `lib/features/explore/domain/query_model.dart` (`kQuerySchemaVersion` to 2)
- Modify: `lib/features/explore/domain/dive_field_catalog.dart` (five new fields)
- Modify: `lib/features/explore/domain/query_compiler.dart` (lowering)
- Modify: `lib/features/explore/presentation/chip_labeler.dart` (labels)
- Modify: `lib/features/explore/domain/nl_engine.dart` (prompt lines)
- Modify: the 11 ARB files
- Test: `test/features/explore/domain/query_compiler_derived_test.dart`
- Test: `test/l10n/explore_strings_test.dart` (extend)

**Interfaces:**
- Consumes: Tasks 7 and 8.
- Produces: `ExploreDiveField.sacTrend`, `.sacRoseAfter`, `.finalStopUnstable`, `.finalStopDuration`, `.safetyFinding`, each lowering to a `DerivedPredicate`.

Field semantics:

| JSON field | op | value | Lowers to |
| --- | --- | --- | --- |
| `sacTrend` | eq | `rising` / `falling` / `flat` | `SacTrendIs` |
| `sacRoseAfter` | eq / gt / gte | minutes as a number | `SacRoseAfter(minutes: n)` |
| `finalStopUnstable` | eq | true | `FinalStopUnstable()` |
| `finalStopDuration` | lt/lte/gt/gte/between | minutes | `FinalStopDuration` in SECONDS |
| `safetyFinding` | eq / in | rule names | one `HasFinding` per value, ANDed |

Bumping `kQuerySchemaVersion` to 2 is what makes a stale native adapter fail loudly rather than emit fields the compiler does not know: the Dart validator rejects a payload whose version is not 2, and the Swift adapter builds its schema from the vocabulary Dart ships, so it picks the new fields up with no native change.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/explore/domain/query_compiler_derived_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/derived_predicates.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  final now = DateTime(2026, 9, 19);
  const units = (
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
  );

  CompiledQuery compile(List<Map<String, Object?>> clauses) =>
      QueryCompiler.compile(
        ParsedQuery.fromJson({
          'schemaVersion': kQuerySchemaVersion,
          'subject': 'dives',
          'clauses': clauses,
        }),
        CompilerContext(units: units, names: NameIndex.empty, now: now),
      );

  test('the schema version is 2 now that the derived fields exist', () {
    expect(kQuerySchemaVersion, 2);
  });

  test('a SAC trend lowers to a trend predicate', () {
    final c = compile([
      {'field': 'sacTrend', 'op': 'eq', 'value': 'rising', 'text': 'SAC rose'},
    ]);
    expect(c.filter.derivedPredicates, [const SacTrendIs(SacTrend.rising)]);
    expect(c.unplaced, isEmpty);
  });

  test('SAC rising after N minutes lowers with the minutes', () {
    final c = compile([
      {
        'field': 'sacRoseAfter',
        'op': 'eq',
        'value': 20,
        'unit': 'min',
        'text': 'SAC increased after 20 minutes',
      },
    ]);
    expect(c.filter.derivedPredicates, [const SacRoseAfter(minutes: 20)]);
  });

  test('an unstable final stop lowers to the default threshold', () {
    final c = compile([
      {
        'field': 'finalStopUnstable',
        'op': 'eq',
        'value': true,
        'text': 'the final stop was unstable',
      },
    ]);
    expect(c.filter.derivedPredicates, [const FinalStopUnstable()]);
  });

  test('a final stop duration converts minutes to seconds', () {
    final c = compile([
      {
        'field': 'finalStopDuration',
        'op': 'gte',
        'value': 3,
        'unit': 'min',
        'text': 'a stop of at least three minutes',
      },
    ]);
    expect(
      c.filter.derivedPredicates,
      [const FinalStopDuration(minSeconds: 180)],
    );
  });

  test('a list of findings becomes one predicate each', () {
    final c = compile([
      {
        'field': 'safetyFinding',
        'op': 'in',
        'value': ['rapidAscent', 'omittedSafetyStop'],
        'text': 'ascent or safety stop problems',
      },
    ]);
    expect(c.filter.derivedPredicates, [
      const HasFinding(SafetyRuleId.rapidAscent),
      const HasFinding(SafetyRuleId.omittedSafetyStop),
    ]);
  });

  test('an unknown trend or rule is unplaced, not guessed', () {
    final c = compile([
      {'field': 'sacTrend', 'op': 'eq', 'value': 'wobbly', 'text': 'a'},
      {'field': 'safetyFinding', 'op': 'eq', 'value': 'kraken', 'text': 'b'},
    ]);
    expect(c.filter.derivedPredicates, isEmpty);
    expect(c.unplaced.map((u) => u.reason), ['invalid', 'invalid']);
  });

  test('the two sentences from the spec compile end to end', () {
    final c = compile([
      {'field': 'waterTemp', 'op': 'lt', 'value': 15, 'unit': 'c', 'text': 'cold-water'},
      {
        'field': 'sacRoseAfter',
        'op': 'eq',
        'value': 20,
        'unit': 'min',
        'text': 'SAC increased after 20 minutes',
      },
      {
        'field': 'finalStopUnstable',
        'op': 'eq',
        'value': true,
        'text': 'the final stop was unstable',
      },
    ]);
    expect(c.filter.maxWaterTemp, 15);
    expect(c.filter.derivedPredicates, [
      const SacRoseAfter(minutes: 20),
      const FinalStopUnstable(),
    ]);
    expect(c.unplaced, isEmpty);
    expect(c.chips, hasLength(3));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/explore/domain/query_compiler_derived_test.dart`
Expected: FAIL, `kQuerySchemaVersion` is 1 and the fields do not parse.

- [ ] **Step 3: Extend the catalog, compiler, labeler and prompt**

1. `query_model.dart`: `const int kQuerySchemaVersion = 2;`
2. `dive_field_catalog.dart`: add the five enum values with their JSON names, and specs: `sacTrend` is an enum field with `enumValues: ['rising', 'falling', 'flat']` and ops `{eq}`; `sacRoseAfter` is a number field with `FieldDimension.minutes` and ops `{eq, gt, gte}`; `finalStopUnstable` is a flag with ops `{eq}`; `finalStopDuration` is a number field with `FieldDimension.minutes` and the ordering ops; `safetyFinding` is an enum field whose `enumValues` are `SafetyRuleId.values.map((r) => r.name)`, with ops `{eq, inList}`.
3. `query_compiler.dart`: in `_lowerEnum` and `_lowerNumber` and `_lowerFlag`, add the cases that append to `f.derivedPredicates` rather than returning `noAxis`. `finalStopDuration` multiplies the grounded minutes by 60. An unknown enum value already falls out as `invalid` through the existing `allowed.contains` check, so no new branch is needed for that.
4. `chip_labeler.dart`: add the five field names, and render `sacRoseAfter` as `explore_chip_numeric(field, op, '20 min')`, `finalStopUnstable` as the plain field name.
5. `nl_engine.dart`: add one line per field to the fields paragraph, and extend Example 2 so the trilaminate sentence now places the two clauses it previously left unplaced. That example is the clearest signal to the model that these fields exist.

New ARB keys (English; translate all eleven, and remember the fr/pt plural rule does not apply here because none of these are plurals):

```json
"explore_field_sacTrend": "SAC trend",
"explore_field_sacRoseAfter": "SAC rose after",
"explore_field_finalStopUnstable": "Unstable final stop",
"explore_field_finalStopDuration": "Final stop length",
"explore_field_safetyFinding": "Safety finding",
"explore_value_sacTrend_rising": "rising",
"explore_value_sacTrend_falling": "falling",
"explore_value_sacTrend_flat": "flat",
"explore_value_finding_rapidAscent": "rapid ascent",
"explore_value_finding_missedDecoStop": "missed decompression stop",
"explore_value_finding_omittedSafetyStop": "omitted safety stop",
"explore_value_finding_sawtoothProfile": "sawtooth profile",
"explore_value_finding_highSurfaceGf": "high surfacing gradient factor"
```

- [ ] **Step 4: Run the tests**

Run: `TMPDIR=/tmp flutter test test/features/explore test/l10n`
Expected: PASS. The prompt test asserts every catalog field appears in the instructions, so adding a field without a prompt line fails it, which is the point.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/explore test/features/explore test/l10n
git add lib/features/explore lib/l10n/arb test/features/explore test/l10n
git commit -m "feat(explore): schema v2 with the derived predicate fields, labels and prompt"
```

---

### Task 10: The dive detail read path and whole-project verification

**Files:**
- Create: `lib/features/dive_log/presentation/providers/derived_metrics_providers.dart`
- Test: `test/features/dive_log/presentation/providers/derived_metrics_providers_test.dart`
- Modify: `docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md` (deviations)

**Interfaces:**
- Produces: `derivedMetricsRepositoryProvider`, and `diveDerivedMetricsProvider`, a `FutureProvider.family<DiveDerivedMetrics?, String>` compute-through-cache mirroring `diveSensorSummaryProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/presentation/providers/derived_metrics_providers_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/domain/services/derived_metrics_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/derived_metrics_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  test('the provider computes through to a stored row', () async {
    await db.into(db.dives).insert(
      DivesCompanion(
        id: const Value('d1'),
        diveDateTime: Value(now),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(
      overrides: [
        ...overrides,
        derivedMetricsRepositoryProvider.overrideWithValue(
          DerivedMetricsRepository(
            runner: (input) async => DiveDerivedMetrics(
              diveId: input.diveId,
              engineVersion: DerivedMetricsService.version,
              sourceUpdatedAt: input.sourceUpdatedAt,
              computedAt: input.computedAtMs,
              finalStopKind: FinalStopKind.safety,
            ),
          ),
        ),
      ].cast(),
    );
    addTearDown(container.dispose);

    final metrics = await container.read(
      diveDerivedMetricsProvider('d1').future,
    );
    expect(metrics!.finalStopKind, FinalStopKind.safety);
  });

  test('a dive that does not exist resolves to null', () async {
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(overrides: overrides.cast());
    addTearDown(container.dispose);
    expect(
      await container.read(diveDerivedMetricsProvider('missing').future),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/presentation/providers/derived_metrics_providers_test.dart`
Expected: FAIL, missing file.

- [ ] **Step 3: Write the providers**

```dart
// lib/features/dive_log/presentation/providers/derived_metrics_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';

final derivedMetricsRepositoryProvider = Provider<DerivedMetricsRepository>(
  (ref) => DerivedMetricsRepository(),
);

/// Compute-through-cache: the stored metrics when they are current for the
/// dive's version, otherwise fresh ones, stored before they are returned.
/// Null when the dive does not exist. Mirrors `diveSensorSummaryProvider`.
///
/// Self-invalidates on the dive detail-change stream, which includes the
/// derived tables, so a sweep or a restore writing rows directly reaches an
/// open dive page without a restart.
final diveDerivedMetricsProvider =
    FutureProvider.family<DiveDerivedMetrics?, String>((ref, diveId) async {
      final repo = ref.watch(derivedMetricsRepositoryProvider);
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      return repo.ensureCurrent(diveId);
    });
```

If `watchDiveDetailChanges` does not already include the two new tables, add them there so a sweep reaches an open dive page.

- [ ] **Step 4: Run the test and the architecture guards**

Run: `TMPDIR=/tmp flutter test test/features/dive_log/presentation/providers/derived_metrics_providers_test.dart test/architecture`
Expected: PASS.

- [ ] **Step 5: Record the deviations**

Append to the spec's "Deviations recorded during implementation" section any place the engine's rules differ from the spec's sketch, for example the exact level-window and stop-depth constants, and the decision that a rising-pressure bucket is skipped rather than zeroed.

- [ ] **Step 6: Format, analyze and run the full suite once**

```bash
dart format .
flutter analyze
TMPDIR=/tmp flutter test
```

Expected: format reports 0 changed, analyze reports `No issues found!`, and the suite passes. Run the suite unpiped so the exit code is real, and remember that a harness crash can print failures while still exiting 0, so read the summary line as well as the code.

- [ ] **Step 7: Commit and push**

```bash
git add lib/features/dive_log/presentation/providers/derived_metrics_providers.dart test/features/dive_log/presentation/providers/derived_metrics_providers_test.dart docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md
git commit -m "feat(dive-log): compute-through-cache provider for a dive's derived metrics"
TMPDIR=/tmp git push
```

The PR body says `Refs #2195`, lists the new schema rung number, and repeats the owed manual smoke from phase 1. No tool attribution anywhere.

---

## Self-review notes

- **Spec coverage.** The spec's phase 2 section asks for: two device-local engine-versioned tables (Task 3), the engine reusing the analysis rules (Task 2), the worker on an isolate from undecoded blobs with the corrupt-blob and forward-version rules (Task 4), the scheduler copied from the sensor summary one with the same hooks and the test-disable flag (Task 6), the five predicates including the safety findings (Tasks 7 and 8), SQL-only evaluation with id-set intersection (Task 8), and the schema bump to 2 on all three sides (Task 9; the native sides need no change because Swift builds its schema from the vocabulary and Android is prompt-only). The compute-through-cache read path is Task 10.
- **Type consistency.** `DiveDerivedMetrics`, `SacBucket`, `FinalStopKind`, `UnsupportedReason`, `SacTrend`, `kSacBucketSeconds`, `TankPressureSeries`, `TankPressureBlob`, `DerivedMetricsWorkInput`, `computeDerivedMetricsFromBlobs`, `DerivedMetricsRunner`, `DerivedMetricsRepository`, `DerivedMetricsScheduler`, `scheduleDerivedMetricsRefresh`, `DerivedPredicate` and its five subclasses, `DerivedConditionsKey`, `derivedPredicateCondition`, `derivedPredicates`, `readsDerivedMetrics`, `getDiveIdsMatchingDerived`, `watchDerivedMetricsFilterChanges`, `derivedFilteredDiveIdsProvider`, `diveDerivedMetricsProvider` are spelled identically across tasks.
- **Soft spots to verify against the compiler rather than trust.** `ProfileSeriesCodec.encode`'s return shape and `TankPressureCodec`'s point field name (Task 4); `ProfileSeriesRepository`'s constructor parameter (Task 5); the `dive_tanks` volume column name (Task 5); `_FilterTickFollower`'s method name (Task 8); whether `watchDiveDetailChanges` already covers the new tables (Task 10). Each is called out inline where it is used.
- **Known judgement call.** The engine computes SAC itself rather than calling `GasAnalysisService.calculateCylinderSac`, because that method takes a hydrated `Dive` and this must run on a worker isolate from blobs. The spec's phrase "reuses the existing SAC segmentation" is therefore honoured in rule, not in code path; record that in the deviations section.
