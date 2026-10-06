# Statistics Trend Charts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the monthly-averaged progression charts with per-dive values on a real date axis, scoped by the existing statistics filter, with optional per-chart smoothing and fitted trend overlays.

**Architecture:** Five repository methods drop their `GROUP BY` and their hardcoded five-year cutoff and return one point per dive. Bucketing and curve fitting move into a pure Dart domain module with no Flutter or database imports. A new `DiveTrendChart` widget plots those points against a date-valued x axis, layering an optional mean/min-max band, a rolling mean, and a linear fit. A `TrendControlStrip` beneath each chart drives per-chart state held in a Riverpod family.

**Tech Stack:** Flutter, Riverpod 3, Drift (raw `customSelect`), fl_chart 1.2.0, `flutter_localizations` with 11 ARB locales.

**Spec:** `docs/superpowers/specs/2026-08-27-statistics-trend-charts-design.md`

## Global Constraints

- **No em-dashes** anywhere: not in code, comments, commit messages, or ARB strings. En-dashes as prose punctuation and spaced hyphens are equally forbidden.
- **No emojis** in code, comments, or documentation.
- **TDD**: write the failing test first, watch it fail, then implement.
- **Immutability**: never mutate objects or lists in place.
- **Run `dart format .`** after completing any task, before committing.
- **File size**: 200-400 lines typical, 800 maximum.
- **Import grouping**: dart, flutter, packages, local (relative), in that order.
- **Units**: anything displaying a value must respect the active diver's unit settings via `UnitFormatter(ref.watch(settingsProvider))`.
- **`dive_date_time` is epoch milliseconds holding a UTC-flagged wall clock.** Always construct with `DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)` and always build bucket boundaries with `DateTime.utc(...)`, never the bare `DateTime(...)` constructor. CI runs in UTC and is blind to this class of bug.
- **New ARB keys go into all 11 locales**: `app_ar`, `app_de`, `app_en`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`. `arb_parity_test` fails on a key present in English and missing elsewhere.
- **Test command**: `flutter test --exclude-tags performance <path>` (matches `hooks/pre-push:298`).
- **Commit only what the task touches.** Never `git add -A` or `git add -u` in this repo: sibling worktrees share the checkout and a stale submodule pointer gets re-staged. Stage explicit paths.

## File Structure

**Create:**

| Path | Responsibility |
| --- | --- |
| `lib/features/statistics/domain/trend_aggregation.dart` | `TrendDataPoint`, `TrendAggregation`, `TrendBucket`, `LinearFit`, and the three pure functions `aggregate`, `rollingMean`, `linearFit`. No Flutter, no Drift. |
| `lib/features/statistics/presentation/widgets/date_axis.dart` | `DateAxis` and `DateAxisGranularity`: tick selection for a date-valued x axis. Pure, no Flutter widgets. |
| `lib/features/statistics/presentation/widgets/dive_trend_chart.dart` | `DiveTrendChart`: fl_chart `LineChart` rendering points, band, rolling mean and linear fit on a date axis. |
| `lib/features/statistics/presentation/widgets/trend_control_strip.dart` | `TrendControlStrip`: aggregation dropdown plus two tappable legend toggles. |
| `lib/features/statistics/presentation/providers/trend_chart_settings_provider.dart` | `TrendChartSettings` plus a `StateProvider.family` keyed by chart id. |

**Modify:**

| Path | Change |
| --- | --- |
| `lib/features/statistics/data/repositories/statistics_repository.dart` | Remove the `TrendDataPoint` declaration and re-export it; rewrite five trend methods as per-dive; add `getWaterTempPerDive`. |
| `lib/features/statistics/presentation/providers/statistics_providers.dart` | Point providers at the renamed methods; add `waterTempTrendProvider`. |
| `lib/features/statistics/presentation/pages/statistics_progression_page.dart` | Depth and bottom time move to `DiveTrendChart`. |
| `lib/features/statistics/presentation/pages/statistics_gas_page.dart` | SAC trend moves to `DiveTrendChart`. |
| `lib/features/statistics/presentation/pages/statistics_equipment_page.dart` | Weight trend moves to `DiveTrendChart`. |
| `lib/features/statistics/presentation/pages/statistics_conditions_page.dart` | Add a water temperature trend card; retitle the seasonal chart. |
| `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` | Add "Last 5 Years" and "Last 10 Years" date presets. |
| `lib/l10n/arb/app_*.arb` (11 files) | New keys; rewrite four stale subtitles. |

**Unchanged on purpose:** `stat_charts.dart` (`TrendLineChart` still serves Cumulative Dive Count; `MultiTrendLineChart` still serves the seasonal temperature chart), `chart_axis.dart`, `getTemperatureByMonth`.

---

## Task 1: Domain module, bucketing

**Files:**
- Create: `lib/features/statistics/domain/trend_aggregation.dart`
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart:31-42` (remove class, add export)
- Test: `test/features/statistics/domain/trend_aggregation_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class TrendDataPoint { final DateTime date; final double value; final String label; TrendDataPoint({required this.date, required this.value, this.label = ''}); }`
  - `enum TrendAggregation { none, weekly, monthly }`
  - `class TrendBucket { final DateTime date; final double mean; final double min; final double max; final int count; }`
  - `List<TrendBucket> aggregate(List<TrendDataPoint> points, TrendAggregation mode)`

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/domain/trend_aggregation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';

TrendDataPoint p(int y, int m, int d, double v) =>
    TrendDataPoint(date: DateTime.utc(y, m, d), value: v);

void main() {
  group('aggregate none', () {
    test('returns one bucket per point, mean equal to min and max', () {
      final buckets = aggregate([p(2024, 3, 1, 10), p(2024, 3, 2, 20)],
          TrendAggregation.none);

      expect(buckets, hasLength(2));
      expect(buckets[0].date, DateTime.utc(2024, 3, 1));
      expect(buckets[0].mean, 10);
      expect(buckets[0].min, 10);
      expect(buckets[0].max, 10);
      expect(buckets[0].count, 1);
    });

    test('returns an empty list for no points', () {
      expect(aggregate(const [], TrendAggregation.none), isEmpty);
    });
  });

  group('aggregate monthly', () {
    test('collapses a month into mean, min, max and count', () {
      final buckets = aggregate([
        p(2024, 3, 1, 10),
        p(2024, 3, 20, 30),
        p(2024, 4, 2, 50),
      ], TrendAggregation.monthly);

      expect(buckets, hasLength(2));
      expect(buckets[0].date, DateTime.utc(2024, 3, 1));
      expect(buckets[0].mean, 20);
      expect(buckets[0].min, 10);
      expect(buckets[0].max, 30);
      expect(buckets[0].count, 2);
      expect(buckets[1].date, DateTime.utc(2024, 4, 1));
      expect(buckets[1].count, 1);
    });

    test('orders buckets by date regardless of input order', () {
      final buckets = aggregate([
        p(2024, 5, 1, 1),
        p(2023, 1, 1, 2),
      ], TrendAggregation.monthly);

      expect(buckets.map((b) => b.date), [
        DateTime.utc(2023, 1, 1),
        DateTime.utc(2024, 5, 1),
      ]);
    });
  });

  group('aggregate weekly', () {
    test('buckets to the Monday of the point week', () {
      // 2024-03-07 is a Thursday; its Monday is 2024-03-04.
      final buckets =
          aggregate([p(2024, 3, 7, 10)], TrendAggregation.weekly);

      expect(buckets.single.date, DateTime.utc(2024, 3, 4));
    });

    test('a Monday point stays on its own Monday', () {
      final buckets =
          aggregate([p(2024, 3, 4, 10)], TrendAggregation.weekly);

      expect(buckets.single.date, DateTime.utc(2024, 3, 4));
    });

    test('a Sunday point falls into the week that started six days earlier',
        () {
      // 2024-03-10 is a Sunday.
      final buckets =
          aggregate([p(2024, 3, 10, 10)], TrendAggregation.weekly);

      expect(buckets.single.date, DateTime.utc(2024, 3, 4));
    });

    test('splits points across two adjacent weeks', () {
      final buckets = aggregate([
        p(2024, 3, 10, 10), // Sunday, week of Mar 4
        p(2024, 3, 11, 20), // Monday, week of Mar 11
      ], TrendAggregation.weekly);

      expect(buckets, hasLength(2));
      expect(buckets[0].date, DateTime.utc(2024, 3, 4));
      expect(buckets[1].date, DateTime.utc(2024, 3, 11));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/domain/trend_aggregation_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:submersion/features/statistics/domain/trend_aggregation.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/features/statistics/domain/trend_aggregation.dart`:

```dart
/// Pure trend maths for the statistics charts: bucketing a per-dive series and
/// fitting curves through it. No I/O and no Flutter, so the statistical
/// behaviour is unit-testable in isolation (issue #299).
///
/// Every date here is a UTC-flagged wall clock, matching how `dive_date_time`
/// is stored and read. Bucket boundaries are built with `DateTime.utc` so the
/// machine's local offset can never shift a dive into a neighbouring bucket.
library;

/// Data point for line chart trends.
///
/// [label] is only used by the older index-axis `TrendLineChart`; per-dive
/// series leave it empty and format their axis from [date].
class TrendDataPoint {
  final DateTime date;
  final double value;
  final String label;

  TrendDataPoint({required this.date, required this.value, this.label = ''});
}

/// How a per-dive series is folded before drawing. [none] is the default: one
/// drawn point per dive.
enum TrendAggregation { none, weekly, monthly }

/// One drawn point: a single dive under [TrendAggregation.none], or the dives
/// sharing a week or month otherwise.
class TrendBucket {
  const TrendBucket({
    required this.date,
    required this.mean,
    required this.min,
    required this.max,
    required this.count,
  });

  /// Start of the bucket, or the dive's own timestamp when not aggregating.
  final DateTime date;
  final double mean;
  final double min;
  final double max;
  final int count;
}

/// Folds [points] according to [mode], always returning buckets ordered by
/// date. Input order does not matter.
List<TrendBucket> aggregate(
  List<TrendDataPoint> points,
  TrendAggregation mode,
) {
  if (points.isEmpty) return const [];

  if (mode == TrendAggregation.none) {
    final ordered = [...points]..sort((a, b) => a.date.compareTo(b.date));
    return ordered
        .map(
          (p) => TrendBucket(
            date: p.date,
            mean: p.value,
            min: p.value,
            max: p.value,
            count: 1,
          ),
        )
        .toList(growable: false);
  }

  final grouped = <DateTime, List<double>>{};
  for (final point in points) {
    final key = _bucketStart(point.date, mode);
    grouped.putIfAbsent(key, () => <double>[]).add(point.value);
  }

  final keys = grouped.keys.toList()..sort();
  return keys.map((key) {
    final values = grouped[key]!;
    var sum = 0.0;
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      sum += v;
      if (v < min) min = v;
      if (v > max) max = v;
    }
    return TrendBucket(
      date: key,
      mean: sum / values.length,
      min: min,
      max: max,
      count: values.length,
    );
  }).toList(growable: false);
}

DateTime _bucketStart(DateTime date, TrendAggregation mode) {
  switch (mode) {
    case TrendAggregation.monthly:
      return DateTime.utc(date.year, date.month);
    case TrendAggregation.weekly:
      final midnight = DateTime.utc(date.year, date.month, date.day);
      // DateTime.weekday is 1 for Monday through 7 for Sunday.
      return midnight.subtract(Duration(days: midnight.weekday - 1));
    case TrendAggregation.none:
      return date;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/domain/trend_aggregation_test.dart`
Expected: PASS, 8 tests

- [ ] **Step 5: Move `TrendDataPoint` out of the repository**

In `lib/features/statistics/data/repositories/statistics_repository.dart`, delete lines 31-42 (the `/// Data point for line chart trends` comment and the whole `TrendDataPoint` class) and add this immediately after the import block (after line 14):

```dart
export 'package:submersion/features/statistics/domain/trend_aggregation.dart'
    show TrendDataPoint;
```

Then add to the import block, in local-import alphabetical order (after line 13):

```dart
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
```

The re-export keeps every existing `import '.../statistics_repository.dart'` that uses `TrendDataPoint` compiling unchanged, including `stat_charts.dart:4` and `statistics_conditions_page.dart:7`.

- [ ] **Step 6: Verify the whole project still analyzes and the statistics tests still pass**

Run: `flutter analyze 2>&1 | tail -20`
Expected: "No issues found!"

Run: `flutter test --exclude-tags performance test/features/statistics/`
Expected: PASS, no failures

Note: `flutter analyze` must be run without piping to `grep`; a pipe masks the exit code. Infos are fatal in CI.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/statistics/domain/trend_aggregation.dart \
        lib/features/statistics/data/repositories/statistics_repository.dart \
        test/features/statistics/domain/trend_aggregation_test.dart
git commit -m "feat(stats): add pure trend bucketing domain module

Moves TrendDataPoint into the statistics domain layer and adds
TrendAggregation, TrendBucket and aggregate(). Bucket boundaries are built
with DateTime.utc so the local offset cannot shift a dive between buckets.

Refs #299"
```

---

## Task 2: Domain module, rolling mean and linear fit

**Files:**
- Modify: `lib/features/statistics/domain/trend_aggregation.dart`
- Test: `test/features/statistics/domain/trend_aggregation_test.dart`

**Interfaces:**
- Consumes: `TrendDataPoint` from Task 1.
- Produces:
  - `const int kMinTrendFitPoints = 5;`
  - `List<TrendDataPoint> rollingMean(List<TrendDataPoint> points, {int window = 21})`
  - `class LinearFit { final DateTime origin; final double slopePerDay; final double intercept; double get perYear; double valueAt(DateTime date); }`
  - `LinearFit? linearFit(List<TrendDataPoint> points)`

- [ ] **Step 1: Write the failing test**

Append to `test/features/statistics/domain/trend_aggregation_test.dart`, inside `main()`:

```dart
  group('rollingMean', () {
    test('returns an empty list below the minimum point count', () {
      final points = List.generate(4, (i) => p(2024, 1, i + 1, 10));
      expect(rollingMean(points), isEmpty);
    });

    test('leaves a flat series flat', () {
      final points = List.generate(10, (i) => p(2024, 1, i + 1, 7));
      final smoothed = rollingMean(points, window: 3);

      expect(smoothed, hasLength(10));
      for (final s in smoothed) {
        expect(s.value, closeTo(7, 1e-9));
      }
    });

    test('averages the centred window', () {
      // Values 0..9, window 3: interior point i averages i-1, i, i+1.
      final points =
          List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final smoothed = rollingMean(points, window: 3);

      expect(smoothed[5].value, closeTo(5, 1e-9));
      expect(smoothed[1].value, closeTo(1, 1e-9));
    });

    test('truncates the window at both ends rather than padding', () {
      final points =
          List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final smoothed = rollingMean(points, window: 5);

      // First point sees indices 0,1,2 only: mean 1.
      expect(smoothed.first.value, closeTo(1, 1e-9));
      // Last point sees indices 7,8,9 only: mean 8.
      expect(smoothed.last.value, closeTo(8, 1e-9));
    });

    test('keeps each smoothed point on its own date', () {
      final points =
          List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final smoothed = rollingMean(points, window: 3);

      expect(smoothed[3].date, points[3].date);
    });

    test('counts dives rather than calendar time', () {
      // Two clusters far apart. A time-based window would average across the
      // gap; a count-based window of 3 must not.
      final points = <TrendDataPoint>[
        p(2024, 1, 1, 10),
        p(2024, 1, 2, 10),
        p(2024, 1, 3, 10),
        p(2026, 1, 1, 50),
        p(2026, 1, 2, 50),
        p(2026, 1, 3, 50),
      ];
      final smoothed = rollingMean(points, window: 3);

      expect(smoothed.first.value, closeTo(10, 1e-9));
      expect(smoothed.last.value, closeTo(50, 1e-9));
    });
  });

  group('linearFit', () {
    test('returns null below the minimum point count', () {
      final points = List.generate(4, (i) => p(2024, 1, i + 1, 10));
      expect(linearFit(points), isNull);
    });

    test('recovers a known slope of one unit per day', () {
      final points =
          List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final fit = linearFit(points)!;

      expect(fit.slopePerDay, closeTo(1.0, 1e-9));
      expect(fit.perYear, closeTo(365.25, 1e-6));
    });

    test('reports a zero slope for a flat series', () {
      final points = List.generate(10, (i) => p(2024, 1, i + 1, 7));
      final fit = linearFit(points)!;

      expect(fit.slopePerDay, closeTo(0, 1e-9));
    });

    test('valueAt reproduces the fitted line at the origin and beyond', () {
      final points =
          List.generate(10, (i) => p(2024, 1, i + 1, i.toDouble()));
      final fit = linearFit(points)!;

      expect(fit.valueAt(DateTime.utc(2024, 1, 1)), closeTo(0, 1e-9));
      expect(fit.valueAt(DateTime.utc(2024, 1, 11)), closeTo(10, 1e-9));
    });

    test('returns null when every point shares one date', () {
      final points = List.generate(10, (i) => p(2024, 1, 1, i.toDouble()));
      expect(linearFit(points), isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/domain/trend_aggregation_test.dart`
Expected: FAIL, "The function 'rollingMean' isn't defined"

- [ ] **Step 3: Write the implementation**

Append to `lib/features/statistics/domain/trend_aggregation.dart`:

```dart
/// Fewer points than this and neither fit is drawn: a confident line through
/// four dives says more than the data supports.
const int kMinTrendFitPoints = 5;

/// Centred mean over [window] neighbouring dives, ordered by date.
///
/// The window counts dives rather than calendar days on purpose. A time-based
/// window would compute some points from a liveaboard's forty dives and others
/// from none, so the line would be least stable exactly where the diving was
/// densest. At the ends the window truncates rather than padding.
///
/// Returns an empty list below [kMinTrendFitPoints].
List<TrendDataPoint> rollingMean(
  List<TrendDataPoint> points, {
  int window = 21,
}) {
  if (points.length < kMinTrendFitPoints) return const [];

  final ordered = [...points]..sort((a, b) => a.date.compareTo(b.date));
  final half = window ~/ 2;

  return List<TrendDataPoint>.generate(ordered.length, (i) {
    final lo = (i - half) < 0 ? 0 : i - half;
    final hi = (i + half + 1) > ordered.length ? ordered.length : i + half + 1;
    var sum = 0.0;
    for (var j = lo; j < hi; j++) {
      sum += ordered[j].value;
    }
    return TrendDataPoint(
      date: ordered[i].date,
      value: sum / (hi - lo),
    );
  }, growable: false);
}

/// A least-squares line through a per-dive series, expressed against a fixed
/// [origin] so it can be evaluated at any date.
class LinearFit {
  const LinearFit({
    required this.origin,
    required this.slopePerDay,
    required this.intercept,
  });

  /// Date the fit is anchored to. [intercept] is the fitted value here.
  final DateTime origin;
  final double slopePerDay;
  final double intercept;

  /// The rate a diver can actually state, for example "+4.4 m per year".
  double get perYear => slopePerDay * 365.25;

  double valueAt(DateTime date) =>
      intercept +
      slopePerDay * (date.difference(origin).inSeconds / Duration.secondsPerDay);
}

/// Ordinary least squares over [points], with x measured in days since the
/// earliest point.
///
/// Returns null below [kMinTrendFitPoints], and null when every point shares a
/// single date (the slope would be undefined).
LinearFit? linearFit(List<TrendDataPoint> points) {
  if (points.length < kMinTrendFitPoints) return null;

  final ordered = [...points]..sort((a, b) => a.date.compareTo(b.date));
  final origin = ordered.first.date;

  final xs = ordered
      .map(
        (p) => p.date.difference(origin).inSeconds / Duration.secondsPerDay,
      )
      .toList(growable: false);
  final ys = ordered.map((p) => p.value).toList(growable: false);

  final n = xs.length;
  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;

  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - meanX;
    numerator += dx * (ys[i] - meanY);
    denominator += dx * dx;
  }
  if (denominator == 0) return null;

  final slope = numerator / denominator;
  return LinearFit(
    origin: origin,
    slopePerDay: slope,
    intercept: meanY - slope * meanX,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/domain/trend_aggregation_test.dart`
Expected: PASS, 19 tests

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/statistics/domain/trend_aggregation.dart \
        test/features/statistics/domain/trend_aggregation_test.dart
git commit -m "feat(stats): add rolling mean and linear fit to the trend domain

The rolling window counts dives rather than calendar days so trip clustering
does not destabilise the line. Both fits return nothing below five points.

Refs #299"
```

---

## Task 3: Repository, depth and bottom time per dive

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart:839-931`
- Modify: `test/features/statistics/data/repositories/statistics_repository_error_test.dart`
- Test: `test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart` (create)

**Interfaces:**
- Consumes: `TrendDataPoint` from Task 1.
- Produces:
  - `Future<List<TrendDataPoint>> getDepthPerDive({String? diverId, DiveFilterState filter = const DiveFilterState()})`
  - `Future<List<TrendDataPoint>> getBottomTimePerDive({String? diverId, DiveFilterState filter = const DiveFilterState()})`

  Both return one point per dive, ordered by `dive_date_time`, with `value` in metres and minutes respectively, and `label` left empty.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late StatisticsRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = StatisticsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive({
    required String id,
    required DateTime at,
    double? maxDepth,
    int? bottomTimeSeconds,
    double? waterTemp,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(at.millisecondsSinceEpoch),
            maxDepth: Value(maxDepth),
            bottomTime: Value(bottomTimeSeconds),
            waterTemp: Value(waterTemp),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  group('getDepthPerDive', () {
    test('returns one point per dive, ordered by date', () async {
      await insertDive(
          id: 'b', at: DateTime.utc(2024, 5, 20), maxDepth: 30.0);
      await insertDive(
          id: 'a', at: DateTime.utc(2024, 5, 10), maxDepth: 18.0);

      final points = await repository.getDepthPerDive();

      expect(points, hasLength(2));
      expect(points[0].value, 18.0);
      expect(points[1].value, 30.0);
      expect(points[0].date.isBefore(points[1].date), isTrue);
    });

    test('does not collapse two dives in the same month', () async {
      await insertDive(
          id: 'a', at: DateTime.utc(2024, 5, 10), maxDepth: 18.0);
      await insertDive(
          id: 'b', at: DateTime.utc(2024, 5, 11), maxDepth: 30.0);

      expect(await repository.getDepthPerDive(), hasLength(2));
    });

    test('includes a dive far older than five years', () async {
      // The regression that matters: the old code hardcoded a five-year
      // cutoff, so "lifetime" was unreachable no matter what filter was set.
      final longAgo = DateTime.now().toUtc().subtract(
            const Duration(days: 365 * 8),
          );
      await insertDive(id: 'ancient', at: longAgo, maxDepth: 12.0);

      final points = await repository.getDepthPerDive();

      expect(points, hasLength(1));
      expect(points.single.value, 12.0);
    });

    test('skips dives with no recorded max depth', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));

      expect(await repository.getDepthPerDive(), isEmpty);
    });

    test('honours a date filter', () async {
      await insertDive(
          id: 'a', at: DateTime.utc(2020, 5, 10), maxDepth: 18.0);
      await insertDive(
          id: 'b', at: DateTime.utc(2024, 5, 10), maxDepth: 30.0);

      final points = await repository.getDepthPerDive(
        filter: DiveFilterState(startDate: DateTime.utc(2023, 1, 1)),
      );

      expect(points, hasLength(1));
      expect(points.single.value, 30.0);
    });
  });

  group('getBottomTimePerDive', () {
    test('returns minutes, one point per dive', () async {
      await insertDive(
          id: 'a', at: DateTime.utc(2024, 5, 10), bottomTimeSeconds: 45 * 60);
      await insertDive(
          id: 'b', at: DateTime.utc(2024, 5, 11), bottomTimeSeconds: 60 * 60);

      final points = await repository.getBottomTimePerDive();

      expect(points, hasLength(2));
      expect(points[0].value, closeTo(45, 1e-9));
      expect(points[1].value, closeTo(60, 1e-9));
    });

    test('includes a dive far older than five years', () async {
      final longAgo = DateTime.now().toUtc().subtract(
            const Duration(days: 365 * 8),
          );
      await insertDive(
          id: 'ancient', at: longAgo, bottomTimeSeconds: 30 * 60);

      expect(await repository.getBottomTimePerDive(), hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart`
Expected: FAIL, "The method 'getDepthPerDive' isn't defined for the type 'StatisticsRepository'"

- [ ] **Step 3: Replace `getDepthProgressionTrend`**

In `statistics_repository.dart`, replace lines 839-884 in full with:

```dart
  /// Maximum depth of every dive in scope, ordered by date.
  ///
  /// One point per dive. Scope comes entirely from [filter]; there is
  /// deliberately no built-in window, because a hardcoded five-year cutoff
  /// used to make "lifetime" unreachable (issue #299).
  Future<List<TrendDataPoint>> getDepthPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null
          ? [diverId, ...df.params]
          : [...df.params];

      final results = await _db.customSelect('''
        SELECT dive_date_time, max_depth
        FROM dives
        WHERE max_depth IS NOT NULL $diverFilter ${df.clause}
        ORDER BY dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return TrendDataPoint(
          date: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          value: row.read<double>('max_depth'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive max depth',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
```

- [ ] **Step 4: Replace `getBottomTimeTrend`**

Replace the following block (originally lines 886-931) in full with:

```dart
  /// Bottom time in minutes for every dive in scope, ordered by date.
  Future<List<TrendDataPoint>> getBottomTimePerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null
          ? [diverId, ...df.params]
          : [...df.params];

      final results = await _db.customSelect('''
        SELECT dive_date_time, bottom_time / 60.0 AS minutes
        FROM dives
        WHERE bottom_time IS NOT NULL $diverFilter ${df.clause}
        ORDER BY dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return TrendDataPoint(
          date: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          value: row.read<double>('minutes'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive bottom time',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
```

- [ ] **Step 5: Update the error test's method names**

In `test/features/statistics/data/repositories/statistics_repository_error_test.dart`, rename the two calls:
- `repository.getDepthProgressionTrend()` becomes `repository.getDepthPerDive()`
- `repository.getBottomTimeTrend()` becomes `repository.getBottomTimePerDive()`

- [ ] **Step 6: Run the tests**

Run: `flutter test --exclude-tags performance test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart test/features/statistics/data/repositories/statistics_repository_error_test.dart`
Expected: PASS

The two provider call sites still reference the old names, so `flutter analyze` will report errors until Task 6. That is expected; do not fix them here.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/statistics/data/repositories/statistics_repository.dart \
        test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart \
        test/features/statistics/data/repositories/statistics_repository_error_test.dart
git commit -m "feat(stats): return per-dive depth and bottom time

Drops the monthly GROUP BY and the hardcoded five-year cutoff from both
methods, so the statistics filter is now the only thing that scopes them and
a lifetime range is reachable.

Refs #299"
```

---

## Task 4: Repository, weight and water temperature per dive

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (`getWeightTrend`, originally L2111-2157)
- Modify: `test/features/statistics/data/repositories/statistics_repository_error_test.dart`
- Test: `test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart`

**Interfaces:**
- Consumes: `TrendDataPoint` from Task 1.
- Produces:
  - `Future<List<TrendDataPoint>> getWeightPerDive({String? diverId, DiveFilterState filter = const DiveFilterState()})` returning **total** kilograms per dive.
  - `Future<List<TrendDataPoint>> getWaterTempPerDive({String? diverId, DiveFilterState filter = const DiveFilterState()})` returning degrees Celsius per dive.

- [ ] **Step 1: Write the failing test**

Append to `test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart`, inside `main()`:

```dart
  Future<void> insertWeight({
    required String diveId,
    required String id,
    required double amountKg,
  }) async {
    await db
        .into(db.diveWeights)
        .insert(
          DiveWeightsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            amountKg: Value(amountKg),
          ),
        );
  }

  group('getWeightPerDive', () {
    test('sums every weight row on a dive into one point', () async {
      // The old monthly query averaged across weight ROWS, so a diver with a
      // 4 kg belt plus 2 kg of trim weights was recorded as 3 kg rather than
      // the 6 kg actually carried.
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));
      await insertWeight(diveId: 'a', id: 'w1', amountKg: 4.0);
      await insertWeight(diveId: 'a', id: 'w2', amountKg: 2.0);

      final points = await repository.getWeightPerDive();

      expect(points, hasLength(1));
      expect(points.single.value, closeTo(6.0, 1e-9));
    });

    test('returns one point per dive, ordered by date', () async {
      await insertDive(id: 'b', at: DateTime.utc(2024, 5, 20));
      await insertWeight(diveId: 'b', id: 'w2', amountKg: 5.0);
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));
      await insertWeight(diveId: 'a', id: 'w1', amountKg: 7.0);

      final points = await repository.getWeightPerDive();

      expect(points.map((p) => p.value), [7.0, 5.0]);
    });

    test('skips dives with no weight rows', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));

      expect(await repository.getWeightPerDive(), isEmpty);
    });

    test('includes a dive far older than five years', () async {
      final longAgo = DateTime.now().toUtc().subtract(
            const Duration(days: 365 * 8),
          );
      await insertDive(id: 'ancient', at: longAgo);
      await insertWeight(diveId: 'ancient', id: 'w1', amountKg: 6.0);

      expect(await repository.getWeightPerDive(), hasLength(1));
    });
  });

  group('getWaterTempPerDive', () {
    test('returns one point per dive with a recorded temperature', () async {
      await insertDive(
          id: 'a', at: DateTime.utc(2024, 5, 10), waterTemp: 12.5);
      await insertDive(
          id: 'b', at: DateTime.utc(2024, 8, 10), waterTemp: 28.0);

      final points = await repository.getWaterTempPerDive();

      expect(points.map((p) => p.value), [12.5, 28.0]);
    });

    test('skips dives with no recorded temperature', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));

      expect(await repository.getWaterTempPerDive(), isEmpty);
    });

    test('does not collapse different years into one calendar month', () async {
      // The seasonal chart deliberately does collapse years; this one must not.
      await insertDive(
          id: 'a', at: DateTime.utc(2023, 7, 10), waterTemp: 10.0);
      await insertDive(
          id: 'b', at: DateTime.utc(2024, 7, 10), waterTemp: 29.0);

      final points = await repository.getWaterTempPerDive();

      expect(points, hasLength(2));
      expect(points.map((p) => p.value), [10.0, 29.0]);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart`
Expected: FAIL, "The method 'getWeightPerDive' isn't defined"

- [ ] **Step 3: Replace `getWeightTrend`**

Replace the `getWeightTrend` method (originally L2111-2157) in full with:

```dart
  /// Total lead carried on every dive in scope, in kilograms, ordered by date.
  ///
  /// Sums the dive's weight rows. The monthly version this replaced averaged
  /// across rows, so a 4 kg belt plus 2 kg of trim weights was reported as
  /// 3 kg rather than the 6 kg actually carried.
  Future<List<TrendDataPoint>> getWeightPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params]
          : [...df.params];

      final results = await _db.customSelect('''
        SELECT d.dive_date_time AS dive_date_time,
               SUM(dw.amount_kg) AS total_kg
        FROM dives d
        JOIN dive_weights dw ON dw.dive_id = d.id
        WHERE 1 = 1 $diverFilter ${df.clause}
        GROUP BY d.id
        HAVING total_kg IS NOT NULL
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return TrendDataPoint(
          date: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          value: row.read<double>('total_kg'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive weight',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Water temperature of every dive in scope, in Celsius, ordered by date.
  ///
  /// Distinct from [getTemperatureByMonth], which collapses all years into
  /// twelve calendar buckets to show a season. This one is a time series.
  Future<List<TrendDataPoint>> getWaterTempPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = diverId != null
          ? [diverId, ...df.params]
          : [...df.params];

      final results = await _db.customSelect('''
        SELECT dive_date_time, water_temp
        FROM dives
        WHERE water_temp IS NOT NULL $diverFilter ${df.clause}
        ORDER BY dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return TrendDataPoint(
          date: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          value: row.read<double>('water_temp'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive water temperature',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
```

- [ ] **Step 4: Update the error test**

In `statistics_repository_error_test.dart`, rename `repository.getWeightTrend()` to `repository.getWeightPerDive()`, and add an assertion in the same style for `getWaterTempPerDive` returning `[]` on a database failure.

- [ ] **Step 5: Run the tests**

Run: `flutter test --exclude-tags performance test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart test/features/statistics/data/repositories/statistics_repository_error_test.dart`
Expected: PASS

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/statistics/data/repositories/statistics_repository.dart \
        test/features/statistics/data/repositories/statistics_repository_per_dive_test.dart \
        test/features/statistics/data/repositories/statistics_repository_error_test.dart
git commit -m "feat(stats): return per-dive weight and water temperature

Weight now SUMs a dive's weight rows instead of averaging across them, so a
belt plus trim weights reports the total lead actually carried. Adds
getWaterTempPerDive for the new temperature trend chart.

Refs #299"
```

---

## Task 5: Repository, SAC per dive

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (`getSacVolumeTrend` originally L203-334, `getSacPressureTrend` originally L336-401)
- Modify: `test/features/statistics/data/repositories/statistics_repository_sac_test.dart`
- Modify: `test/features/statistics/data/repositories/statistics_repository_error_test.dart`

**Interfaces:**
- Consumes: `TrendDataPoint` from Task 1.
- Produces:
  - `Future<List<TrendDataPoint>> getSacVolumePerDive({String? diverId, DiveFilterState filter = const DiveFilterState()})` in litres per minute.
  - `Future<List<TrendDataPoint>> getSacPressurePerDive({String? diverId, DiveFilterState filter = const DiveFilterState()})` in bar per minute.

- [ ] **Step 1: Write the failing test**

Append to `test/features/statistics/data/repositories/statistics_repository_sac_test.dart`, inside `main()`:

```dart
  group('getSacVolumePerDive', () {
    test('returns one point per dive rather than one per month', () async {
      await insertDiveWithTank(
        id: 'dive-1',
        bottomTimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        volume: 11.1,
        diveDateTimeMs: DateTime.utc(2024, 5, 10).millisecondsSinceEpoch,
      );
      await insertDiveWithTank(
        id: 'dive-2',
        bottomTimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 100,
        volume: 11.1,
        diveDateTimeMs: DateTime.utc(2024, 5, 11).millisecondsSinceEpoch,
      );

      final points = await repository.getSacVolumePerDive();

      expect(points, hasLength(2));
      // Ordered by date, and the second dive used less gas.
      expect(points[0].date.isBefore(points[1].date), isTrue);
      expect(points[1].value, lessThan(points[0].value));
    });

    test('sums every tank on a dive into that dive single SAC', () async {
      final diveId = await insertDiveWithTank(
        id: 'dive-twin',
        bottomTimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 100,
        volume: 11.1,
      );
      await insertTank(
        diveId: diveId,
        startPressure: 200,
        endPressure: 100,
        volume: 11.1,
      );

      final points = await repository.getSacVolumePerDive();

      expect(points, hasLength(1));
    });

    test('includes a dive far older than five years', () async {
      final longAgo = DateTime.now().toUtc().subtract(
            const Duration(days: 365 * 8),
          );
      await insertDiveWithTank(
        id: 'ancient',
        bottomTimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        volume: 11.1,
        diveDateTimeMs: longAgo.millisecondsSinceEpoch,
      );

      expect(await repository.getSacVolumePerDive(), hasLength(1));
    });
  });

  group('getSacPressurePerDive', () {
    test('returns one point per dive rather than one per month', () async {
      await insertDiveWithTank(
        id: 'dive-1',
        bottomTimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        diveDateTimeMs: DateTime.utc(2024, 5, 10).millisecondsSinceEpoch,
      );
      await insertDiveWithTank(
        id: 'dive-2',
        bottomTimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 100,
        diveDateTimeMs: DateTime.utc(2024, 5, 11).millisecondsSinceEpoch,
      );

      final points = await repository.getSacPressurePerDive();

      expect(points, hasLength(2));
      // (200-50) / 40 / 3.0 = 1.25 bar/min
      expect(points[0].value, closeTo(1.25, 1e-6));
      // (200-100) / 40 / 3.0 = 0.8333 bar/min
      expect(points[1].value, closeTo(0.8333, 1e-3));
    });

    test('includes a dive far older than five years', () async {
      final longAgo = DateTime.now().toUtc().subtract(
            const Duration(days: 365 * 8),
          );
      await insertDiveWithTank(
        id: 'ancient',
        bottomTimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        diveDateTimeMs: longAgo.millisecondsSinceEpoch,
      );

      expect(await repository.getSacPressurePerDive(), hasLength(1));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/data/repositories/statistics_repository_sac_test.dart`
Expected: FAIL, "The method 'getSacVolumePerDive' isn't defined"

- [ ] **Step 3: Replace `getSacVolumeTrend`**

Replace the whole method (originally L203-334). The gas-summing loop is kept verbatim; only the cutoff and the final monthly bucketing change.

```dart
  /// SAC rate of every dive in scope, in L/min at surface pressure, ordered by
  /// date. Requires tank volume data.
  ///
  /// Gas used is summed across a dive's tanks first, so a twinset or a stage
  /// dive yields one SAC value rather than one per cylinder.
  Future<List<TrendDataPoint>> getSacVolumePerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params]
          : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          d.id AS dive_id,
          d.dive_date_time,
          d.avg_depth,
          COALESCE(d.runtime, d.bottom_time) AS duration_sec,
          t.start_pressure,
          t.end_pressure,
          t.volume,
          t.o2_percent,
          t.he_percent
        FROM dives d
        JOIN dive_tanks t ON t.dive_id = d.id
        WHERE d.dive_mode <> 'gauge' $diverFilter ${df.clause}
          AND COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
          AND t.start_pressure > t.end_pressure
          AND t.volume > 0
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      // Sum gas across each dive's tanks before dividing, so a twinset is one
      // SAC value and not two.
      final Map<
        String,
        ({double gas, DateTime dateTime, int durationSec, double avgDepth})
      >
      diveSacs = {};

      for (final row in results) {
        final diveId = row.read<String>('dive_id');
        final startP = row.read<double>('start_pressure');
        final endP = row.read<double>('end_pressure');
        final vol = row.read<double>('volume');
        final o2 = row.read<double>('o2_percent');
        final he = row.read<double>('he_percent');
        final dateTimeMs = row.read<int>('dive_date_time');

        final gasUsed =
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: startP,
              o2Percent: o2,
              hePercent: he,
              model: gasModel,
            ) -
            gasVolume(
              tankSizeLiters: vol,
              pressureBar: endP,
              o2Percent: o2,
              hePercent: he,
              model: gasModel,
            );
        if (gasUsed <= 0) continue;

        final existing = diveSacs[diveId];
        if (existing == null) {
          diveSacs[diveId] = (
            gas: gasUsed,
            dateTime: DateTime.fromMillisecondsSinceEpoch(
              dateTimeMs,
              isUtc: true,
            ),
            durationSec: row.read<int>('duration_sec'),
            avgDepth: row.read<double>('avg_depth'),
          );
        } else {
          diveSacs[diveId] = (
            gas: existing.gas + gasUsed,
            dateTime: existing.dateTime,
            durationSec: existing.durationSec,
            avgDepth: existing.avgDepth,
          );
        }
      }

      final points = <TrendDataPoint>[];
      for (final entry in diveSacs.entries) {
        final d = entry.value;
        final sac =
            d.gas / (d.durationSec / 60.0) / ((d.avgDepth / 10.0) + 1.0);
        if (sac <= 0) continue;
        points.add(TrendDataPoint(date: d.dateTime, value: sac));
      }
      points.sort((a, b) => a.date.compareTo(b.date));
      return points;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive SAC volume',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
```

- [ ] **Step 4: Replace `getSacPressureTrend`**

Replace the whole method (originally L336-401). The single-back-gas-tank picker subquery is kept verbatim; the `AVG(...)`, `GROUP BY`, `HAVING` and cutoff go.

```dart
  /// SAC rate of every dive in scope, in pressure per minute, ordered by date.
  ///
  /// Does not require tank volume: uses the pressure drop of the dive's single
  /// back-gas tank normalised to surface pressure.
  Future<List<TrendDataPoint>> getSacPressurePerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null
          ? [diverId, ...df.params]
          : [...df.params];

      final results = await _db.customSelect('''
        SELECT
          d.dive_date_time AS dive_date_time,
          (t.start_pressure - t.end_pressure) / (COALESCE(d.runtime, d.bottom_time) / 60.0) / ((d.avg_depth / 10.0) + 1) AS sac
        FROM dives d
        JOIN dive_tanks t ON t.id = (
          SELECT t2.id FROM dive_tanks t2
          WHERE t2.dive_id = d.id
            AND t2.start_pressure > t2.end_pressure
            AND (
              t2.tank_role = 'backGas'
              OR NOT EXISTS (
                SELECT 1 FROM dive_tanks t3
                WHERE t3.dive_id = d.id AND t3.tank_role = 'backGas'
              )
            )
          ORDER BY t2.tank_order, t2.rowid
          LIMIT 1
        )
        WHERE d.dive_mode <> 'gauge' $diverFilter ${df.clause}
          AND COALESCE(d.runtime, d.bottom_time) > 0
          AND d.avg_depth > 0
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results
          .map(
            (row) => TrendDataPoint(
              date: DateTime.fromMillisecondsSinceEpoch(
                row.read<int>('dive_date_time'),
                isUtc: true,
              ),
              value: row.read<double>('sac'),
            ),
          )
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive SAC pressure',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
```

- [ ] **Step 5: Update the existing SAC tests and the error test**

In `statistics_repository_sac_test.dart`, rename every `getSacVolumeTrend()` call to `getSacVolumePerDive()` and every `getSacPressureTrend()` call to `getSacPressurePerDive()`. Rename the `group('getSacVolumeTrend')` and `group('getSacPressureTrend')` headings to match. Also rename `group('getBottomTimeTrend')` calls to `getBottomTimePerDive()`.

Existing assertions that expect `hasLength(1)` for a single dive still hold, because one dive produced one monthly bucket. Any assertion that relies on **two dives in the same month collapsing to one point** must be changed to expect two points; that behaviour change is the point of this task.

In `statistics_repository_error_test.dart`, rename `getSacVolumeTrend` to `getSacVolumePerDive` and `getSacPressureTrend` to `getSacPressurePerDive`.

- [ ] **Step 6: Run the tests**

Run: `flutter test --exclude-tags performance test/features/statistics/data/repositories/`
Expected: PASS

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/statistics/data/repositories/statistics_repository.dart \
        test/features/statistics/data/repositories/statistics_repository_sac_test.dart \
        test/features/statistics/data/repositories/statistics_repository_error_test.dart
git commit -m "feat(stats): return per-dive SAC for both the volume and pressure lanes

The volume lane already computed a per-dive value before bucketing it; it now
stops there. The pressure lane drops its AVG and GROUP BY while keeping the
single-back-gas-tank picker unchanged.

Refs #299"
```

---

## Task 6: Providers

**Files:**
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart:82-100, 179-200, 485-491`
- Create: `lib/features/statistics/presentation/providers/trend_chart_settings_provider.dart`
- Modify: `test/features/statistics/presentation/providers/statistics_providers_all_test.dart`
- Test: `test/features/statistics/presentation/providers/trend_chart_settings_provider_test.dart` (create)

**Interfaces:**
- Consumes: the six per-dive repository methods from Tasks 3-5; `TrendAggregation` from Task 1.
- Produces:
  - `final waterTempTrendProvider = FutureProvider<List<TrendDataPoint>>(...)`
  - `class TrendChartSettings { final TrendAggregation aggregation; final bool showRollingMean; final bool showLinearFit; const TrendChartSettings({this.aggregation = TrendAggregation.none, this.showRollingMean = true, this.showLinearFit = false}); TrendChartSettings copyWith({TrendAggregation? aggregation, bool? showRollingMean, bool? showLinearFit}); }`
  - `final trendChartSettingsProvider = StateProvider.family<TrendChartSettings, String>(...)`
  - `abstract final class TrendChartIds { static const depth = 'depth'; static const bottomTime = 'bottom-time'; static const sac = 'sac'; static const weight = 'weight'; static const waterTemp = 'water-temp'; }`
- Provider names `depthProgressionTrendProvider`, `bottomTimeTrendProvider`, `sacTrendProvider`, `weightTrendProvider` are **kept** so no consumer outside this feature breaks.

- [ ] **Step 1: Write the failing test for the settings provider**

Create `test/features/statistics/presentation/providers/trend_chart_settings_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';

void main() {
  test('defaults to raw per-dive with the rolling mean on', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = container.read(
      trendChartSettingsProvider(TrendChartIds.depth),
    );

    expect(settings.aggregation, TrendAggregation.none);
    expect(settings.showRollingMean, isTrue);
    expect(settings.showLinearFit, isFalse);
  });

  test('each chart id holds its own independent settings', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
            .read(trendChartSettingsProvider(TrendChartIds.depth).notifier)
            .state =
        const TrendChartSettings(aggregation: TrendAggregation.monthly);

    expect(
      container.read(trendChartSettingsProvider(TrendChartIds.depth))
          .aggregation,
      TrendAggregation.monthly,
    );
    expect(
      container.read(trendChartSettingsProvider(TrendChartIds.weight))
          .aggregation,
      TrendAggregation.none,
    );
  });

  test('copyWith replaces only the named field', () {
    const base = TrendChartSettings();
    final updated = base.copyWith(showLinearFit: true);

    expect(updated.showLinearFit, isTrue);
    expect(updated.showRollingMean, isTrue);
    expect(updated.aggregation, TrendAggregation.none);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/providers/trend_chart_settings_provider_test.dart`
Expected: FAIL, `Target of URI doesn't exist`

- [ ] **Step 3: Create the settings provider**

Create `lib/features/statistics/presentation/providers/trend_chart_settings_provider.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';

/// Stable ids for the charts that carry a [TrendControlStrip]. Used as the
/// family key so each chart keeps its own aggregation and overlay choices.
abstract final class TrendChartIds {
  static const depth = 'depth';
  static const bottomTime = 'bottom-time';
  static const sac = 'sac';
  static const weight = 'weight';
  static const waterTemp = 'water-temp';
}

/// How one trend chart is drawn. Raw per-dive by default: the whole point of
/// issue #299 is that an average is opt-in, not the starting position.
class TrendChartSettings {
  const TrendChartSettings({
    this.aggregation = TrendAggregation.none,
    this.showRollingMean = true,
    this.showLinearFit = false,
  });

  final TrendAggregation aggregation;
  final bool showRollingMean;
  final bool showLinearFit;

  TrendChartSettings copyWith({
    TrendAggregation? aggregation,
    bool? showRollingMean,
    bool? showLinearFit,
  }) {
    return TrendChartSettings(
      aggregation: aggregation ?? this.aggregation,
      showRollingMean: showRollingMean ?? this.showRollingMean,
      showLinearFit: showLinearFit ?? this.showLinearFit,
    );
  }
}

/// Per-chart drawing settings, keyed by [TrendChartIds].
///
/// Deliberately in-memory for the session only, matching
/// `statisticsFilterProvider`, which is likewise an unpersisted StateProvider.
final trendChartSettingsProvider =
    StateProvider.family<TrendChartSettings, String>(
      (ref, chartId) => const TrendChartSettings(),
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/providers/trend_chart_settings_provider_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 5: Repoint the existing providers**

In `statistics_providers.dart`:

Replace the body of `sacTrendProvider` (L89-99) so the two branches call the renamed methods:

```dart
  if (lane == GasConsumptionLane.rmv) {
    return repository.getSacVolumePerDive(
      diverId: currentDiverId,
      filter: filter,
    );
  } else {
    return repository.getSacPressurePerDive(
      diverId: currentDiverId,
      filter: filter,
    );
  }
```

In `depthProgressionTrendProvider` (L186-189) replace the call with:

```dart
  return repository.getDepthPerDive(diverId: currentDiverId, filter: filter);
```

In `bottomTimeTrendProvider` (L199) replace the call with:

```dart
  return repository.getBottomTimePerDive(diverId: currentDiverId, filter: filter);
```

In `weightTrendProvider` (L490) replace the call with:

```dart
  return repository.getWeightPerDive(diverId: currentDiverId, filter: filter);
```

- [ ] **Step 6: Add `waterTempTrendProvider`**

Insert immediately after `temperatureByMonthProvider` (which ends at L295):

```dart
/// Water temperature as a per-dive time series.
///
/// Sibling of [temperatureByMonthProvider], which stays a twelve-bucket
/// seasonal climatology. A travelling diver needs the series; a diver with one
/// home region gets real value from the season (issue #299).
final waterTempTrendProvider = FutureProvider<List<TrendDataPoint>>((
  ref,
) async {
  _keepAliveWithExpiry(ref);
  final repository = ref.watch(statisticsRepositoryProvider);
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(statisticsFilterProvider);
  return repository.getWaterTempPerDive(
    diverId: currentDiverId,
    filter: filter,
  );
});
```

- [ ] **Step 7: Add the new provider to the all-providers smoke test**

In `test/features/statistics/presentation/providers/statistics_providers_all_test.dart`, add after the `temperatureByMonthProvider` line (L72):

```dart
    expect(await container.read(waterTempTrendProvider.future), isEmpty);
```

- [ ] **Step 8: Confirm no consumer outside the Statistics tab is affected**

Run:

```bash
grep -rn "depthProgressionTrendProvider\|bottomTimeTrendProvider\|sacTrendProvider\|weightTrendProvider\|waterTempTrendProvider" lib/ | grep -v "features/statistics/"
```

Expected: no output. If any consumer outside `features/statistics/` appears, stop and report it: making a shared provider filter-aware silently rescoped the marine-life species page once before (issue #453), and the same trap applies to renaming what one returns.

- [ ] **Step 9: Run the tests and analyze**

Run: `flutter test --exclude-tags performance test/features/statistics/`
Expected: PASS

Run: `flutter analyze 2>&1 | tail -20`
Expected: "No issues found!" (the repository renames from Tasks 3-5 now have matching call sites)

- [ ] **Step 10: Format and commit**

```bash
dart format .
git add lib/features/statistics/presentation/providers/statistics_providers.dart \
        lib/features/statistics/presentation/providers/trend_chart_settings_provider.dart \
        test/features/statistics/presentation/providers/trend_chart_settings_provider_test.dart \
        test/features/statistics/presentation/providers/statistics_providers_all_test.dart
git commit -m "feat(stats): point trend providers at the per-dive queries

Adds waterTempTrendProvider and a per-chart settings family keyed by chart id,
defaulting to raw per-dive with the rolling mean on. Provider names are
unchanged so no consumer outside the Statistics tab is disturbed.

Refs #299"
```

---

## Task 7: Date axis helper

**Files:**
- Create: `lib/features/statistics/presentation/widgets/date_axis.dart`
- Test: `test/features/statistics/presentation/widgets/date_axis_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum DateAxisGranularity { day, month, quarter, year }`
  - `class DateAxis { final double min; final double max; final List<DateTime> ticks; final DateAxisGranularity granularity; factory DateAxis.forRange(DateTime first, DateTime last); }`

  `min` and `max` are `millisecondsSinceEpoch` as doubles, ready to feed fl_chart's `minX` and `maxX`. Tick labels are **not** produced here: formatting is the widget's job so this file stays pure and locale-free.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/presentation/widgets/date_axis_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/presentation/widgets/date_axis.dart';

void main() {
  test('bounds are the range endpoints as epoch milliseconds', () {
    final first = DateTime.utc(2024, 1, 1);
    final last = DateTime.utc(2024, 12, 31);

    final axis = DateAxis.forRange(first, last);

    expect(axis.min, first.millisecondsSinceEpoch.toDouble());
    expect(axis.max, last.millisecondsSinceEpoch.toDouble());
  });

  test('a multi-year range ticks by year', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2020, 3, 5),
      DateTime.utc(2026, 8, 20),
    );

    expect(axis.granularity, DateAxisGranularity.year);
    expect(axis.ticks.every((t) => t.month == 1 && t.day == 1), isTrue);
    expect(axis.ticks.first.year, greaterThanOrEqualTo(2020));
    expect(axis.ticks.last.year, lessThanOrEqualTo(2026));
  });

  test('a range of about two years ticks by quarter', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2024, 1, 1),
      DateTime.utc(2025, 12, 31),
    );

    expect(axis.granularity, DateAxisGranularity.quarter);
    expect(axis.ticks.every((t) => t.month % 3 == 1 && t.day == 1), isTrue);
  });

  test('a range of a few months ticks by month', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2024, 1, 1),
      DateTime.utc(2024, 5, 31),
    );

    expect(axis.granularity, DateAxisGranularity.month);
    expect(axis.ticks.every((t) => t.day == 1), isTrue);
  });

  test('a range of a few weeks ticks by day', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2024, 1, 1),
      DateTime.utc(2024, 1, 20),
    );

    expect(axis.granularity, DateAxisGranularity.day);
    expect(axis.ticks, isNotEmpty);
  });

  test('every tick lies inside the bounds', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2020, 3, 5),
      DateTime.utc(2026, 8, 20),
    );

    for (final tick in axis.ticks) {
      final ms = tick.millisecondsSinceEpoch.toDouble();
      expect(ms, greaterThanOrEqualTo(axis.min));
      expect(ms, lessThanOrEqualTo(axis.max));
    }
  });

  test('a single-instant range still yields a drawable axis', () {
    final only = DateTime.utc(2024, 6, 1);

    final axis = DateAxis.forRange(only, only);

    expect(axis.max, greaterThan(axis.min));
    expect(axis.ticks, isNotEmpty);
  });

  test('ticks are strictly increasing', () {
    final axis = DateAxis.forRange(
      DateTime.utc(2021, 6, 1),
      DateTime.utc(2026, 6, 1),
    );

    for (var i = 1; i < axis.ticks.length; i++) {
      expect(axis.ticks[i].isAfter(axis.ticks[i - 1]), isTrue);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/date_axis_test.dart`
Expected: FAIL, `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/features/statistics/presentation/widgets/date_axis.dart`:

```dart
/// Tick selection for a date-valued chart x axis.
///
/// The older `TrendLineChart` plots `FlSpot(index, value)`, so a three-month
/// gap and a three-week gap render identically. Per-dive series cannot do that
/// and stay honest, so they plot real timestamps and need ticks chosen from the
/// span rather than from the point count (issue #299).
///
/// Deliberately free of Flutter and of locale: labels are formatted by the
/// widget, which has a BuildContext. This file only decides where ticks go.
enum DateAxisGranularity { day, month, quarter, year }

class DateAxis {
  const DateAxis({
    required this.min,
    required this.max,
    required this.ticks,
    required this.granularity,
  });

  /// Lower bound, as `millisecondsSinceEpoch`, for fl_chart's `minX`.
  final double min;

  /// Upper bound, as `millisecondsSinceEpoch`, for fl_chart's `maxX`.
  final double max;

  /// Tick positions, strictly increasing and always inside the bounds.
  final List<DateTime> ticks;

  final DateAxisGranularity granularity;

  /// Chooses a granularity from the span, then walks ticks across it.
  ///
  /// A degenerate range (one dive, or several on one day) is widened to a day
  /// so fl_chart has a non-zero axis to draw.
  factory DateAxis.forRange(DateTime first, DateTime last) {
    var start = first;
    var end = last;
    if (!end.isAfter(start)) {
      end = start.add(const Duration(days: 1));
    }

    final days = end.difference(start).inDays;
    final granularity = days > 1095
        ? DateAxisGranularity.year
        : days > 365
        ? DateAxisGranularity.quarter
        : days > 60
        ? DateAxisGranularity.month
        : DateAxisGranularity.day;

    return DateAxis(
      min: start.millisecondsSinceEpoch.toDouble(),
      max: end.millisecondsSinceEpoch.toDouble(),
      ticks: _ticksFor(start, end, granularity),
      granularity: granularity,
    );
  }

  static List<DateTime> _ticksFor(
    DateTime start,
    DateTime end,
    DateAxisGranularity granularity,
  ) {
    final ticks = <DateTime>[];

    switch (granularity) {
      case DateAxisGranularity.year:
        for (var y = start.year; y <= end.year; y++) {
          final tick = DateTime.utc(y);
          if (!tick.isBefore(start) && !tick.isAfter(end)) ticks.add(tick);
        }
      case DateAxisGranularity.quarter:
        var cursor = DateTime.utc(start.year, ((start.month - 1) ~/ 3) * 3 + 1);
        while (!cursor.isAfter(end)) {
          if (!cursor.isBefore(start)) ticks.add(cursor);
          cursor = DateTime.utc(cursor.year, cursor.month + 3);
        }
      case DateAxisGranularity.month:
        var cursor = DateTime.utc(start.year, start.month);
        while (!cursor.isAfter(end)) {
          if (!cursor.isBefore(start)) ticks.add(cursor);
          cursor = DateTime.utc(cursor.year, cursor.month + 1);
        }
      case DateAxisGranularity.day:
        // Aim for about five labels rather than one per day.
        final span = end.difference(start).inDays;
        final step = span <= 5 ? 1 : (span / 5).ceil();
        var cursor = DateTime.utc(start.year, start.month, start.day);
        if (cursor.isBefore(start)) cursor = cursor.add(const Duration(days: 1));
        while (!cursor.isAfter(end)) {
          ticks.add(cursor);
          cursor = cursor.add(Duration(days: step));
        }
    }

    // A range narrower than one tick step would otherwise draw a bare axis.
    if (ticks.isEmpty) ticks.add(start);
    return List.unmodifiable(ticks);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/date_axis_test.dart`
Expected: PASS, 8 tests

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/statistics/presentation/widgets/date_axis.dart \
        test/features/statistics/presentation/widgets/date_axis_test.dart
git commit -m "feat(stats): add a date-valued chart axis helper

Chooses year, quarter, month or day ticks from the span rather than from the
point count, so gaps between dives render at their real width.

Refs #299"
```

---

## Task 8: Localization keys for the control strip

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the other 10 locale ARB files
- Test: existing `test/l10n/arb_parity_test.dart` (do not edit; it must pass)

**Interfaces:**
- Consumes: nothing.
- Produces these `context.l10n` getters, available to Tasks 9 onward:
  - `statistics_trend_aggregation_perDive`, `_weekly`, `_monthly`
  - `statistics_trend_aggregation_tooltip`
  - `statistics_trend_legend_rollingAverage`
  - `statistics_trend_legend_rate`
  - `statistics_trend_rate_perYear(String value)`
  - `statistics_trend_band_semanticLabel`

- [ ] **Step 1: Add the English keys**

Insert into `lib/l10n/arb/app_en.arb`, keeping the file's alphabetical key order (these sort just after `statistics_timePatterns_*` and before `statistics_progression_*` depending on your collation; place them so the file stays sorted):

```json
  "statistics_trend_aggregation_monthly": "Monthly",
  "statistics_trend_aggregation_perDive": "Per dive",
  "statistics_trend_aggregation_tooltip": "Group dives",
  "statistics_trend_aggregation_weekly": "Weekly",
  "statistics_trend_band_semanticLabel": "Shaded band spans the lowest and highest value in each group",
  "statistics_trend_legend_rate": "Rate",
  "statistics_trend_legend_rollingAverage": "Rolling avg",
  "statistics_trend_rate_perYear": "{value}/yr",
  "@statistics_trend_rate_perYear": {
    "description": "Linear trend rate shown beside the rate legend entry. The value already carries its unit symbol, for example '+4.4 m'.",
    "placeholders": {
      "value": {
        "type": "String"
      }
    }
  },
```

- [ ] **Step 2: Verify the parity test fails**

Run: `flutter test --exclude-tags performance test/l10n/arb_parity_test.dart`
Expected: FAIL, reporting 8 keys missing from each of the other 10 locales

- [ ] **Step 3: Translate into all 10 remaining locales**

Add the same 8 keys, translated, to `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`. Keep each file's existing key ordering.

Only `app_en.arb` carries the `@statistics_trend_rate_perYear` metadata block; the other locales carry the plain key. Preserve the `{value}` placeholder verbatim in every translation.

German, for example:

```json
  "statistics_trend_aggregation_monthly": "Monatlich",
  "statistics_trend_aggregation_perDive": "Pro Tauchgang",
  "statistics_trend_aggregation_tooltip": "Tauchgänge gruppieren",
  "statistics_trend_aggregation_weekly": "Wöchentlich",
  "statistics_trend_band_semanticLabel": "Der schattierte Bereich umfasst den niedrigsten und höchsten Wert jeder Gruppe",
  "statistics_trend_legend_rate": "Rate",
  "statistics_trend_legend_rollingAverage": "Gleitender Durchschnitt",
  "statistics_trend_rate_perYear": "{value}/Jahr",
```

- [ ] **Step 4: Regenerate and verify**

Run: `flutter gen-l10n`
Then: `flutter test --exclude-tags performance test/l10n/`
Expected: PASS

CI regenerates l10n but never verifies it, so a stale generated file will not be caught downstream. Regenerate here.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/l10n/arb/
git commit -m "i18n: add trend chart control strip strings

Aggregation mode names, the two overlay legend labels, the per-year rate
format and a band semantic label, across all 11 locales.

Refs #299"
```

---

## Task 9: TrendControlStrip

**Files:**
- Create: `lib/features/statistics/presentation/widgets/trend_control_strip.dart`
- Test: `test/features/statistics/presentation/widgets/trend_control_strip_test.dart`

**Interfaces:**
- Consumes: `TrendAggregation` (Task 1), the l10n keys from Task 8.
- Produces:

```dart
class TrendControlStrip extends StatelessWidget {
  const TrendControlStrip({
    super.key,
    required this.chartId,
    required this.aggregation,
    required this.onAggregationChanged,
    required this.showRollingMean,
    required this.onToggleRollingMean,
    required this.showLinearFit,
    required this.onToggleLinearFit,
    required this.rollingColor,
    required this.rateColor,
    this.rateLabel,
  });

  final String chartId;
  final TrendAggregation aggregation;
  final ValueChanged<TrendAggregation> onAggregationChanged;
  final bool showRollingMean;
  final VoidCallback onToggleRollingMean;
  final bool showLinearFit;
  final VoidCallback onToggleLinearFit;
  final Color rollingColor;
  final Color rateColor;
  final String? rateLabel;
}
```

Test keys, following the `gps_track_date_filter_action.dart` convention: `'trend-aggregation-$chartId'`, `'trend-legend-rolling-$chartId'`, `'trend-legend-rate-$chartId'`.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/presentation/widgets/trend_control_strip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_control_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host({
    TrendAggregation aggregation = TrendAggregation.none,
    bool showRollingMean = true,
    bool showLinearFit = false,
    String? rateLabel,
    ValueChanged<TrendAggregation>? onAggregationChanged,
    VoidCallback? onToggleRollingMean,
    VoidCallback? onToggleLinearFit,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TrendControlStrip(
          chartId: 'depth',
          aggregation: aggregation,
          onAggregationChanged: onAggregationChanged ?? (_) {},
          showRollingMean: showRollingMean,
          onToggleRollingMean: onToggleRollingMean ?? () {},
          showLinearFit: showLinearFit,
          onToggleLinearFit: onToggleLinearFit ?? () {},
          rollingColor: Colors.blue,
          rateColor: Colors.orange,
          rateLabel: rateLabel,
        ),
      ),
    );
  }

  testWidgets('shows the active aggregation mode', (tester) async {
    await tester.pumpWidget(host(aggregation: TrendAggregation.monthly));

    expect(find.text('Monthly'), findsOneWidget);
  });

  testWidgets('opening the dropdown and choosing weekly reports the change',
      (tester) async {
    TrendAggregation? chosen;
    await tester.pumpWidget(host(onAggregationChanged: (m) => chosen = m));

    await tester.tap(find.byKey(const ValueKey('trend-aggregation-depth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();

    expect(chosen, TrendAggregation.weekly);
  });

  testWidgets('tapping the rolling legend entry toggles it', (tester) async {
    var toggled = false;
    await tester.pumpWidget(host(onToggleRollingMean: () => toggled = true));

    await tester.tap(find.byKey(const ValueKey('trend-legend-rolling-depth')));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('tapping the rate legend entry toggles it', (tester) async {
    var toggled = false;
    await tester.pumpWidget(host(onToggleLinearFit: () => toggled = true));

    await tester.tap(find.byKey(const ValueKey('trend-legend-rate-depth')));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('shows the rate value when the fit is on and a label is given',
      (tester) async {
    await tester
        .pumpWidget(host(showLinearFit: true, rateLabel: '+4.4 m'));

    expect(find.text('+4.4 m/yr'), findsOneWidget);
  });

  testWidgets('shows the plain rate label when the fit is off',
      (tester) async {
    await tester.pumpWidget(host(rateLabel: '+4.4 m'));

    expect(find.text('Rate'), findsOneWidget);
    expect(find.text('+4.4 m/yr'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/trend_control_strip_test.dart`
Expected: FAIL, `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/features/statistics/presentation/widgets/trend_control_strip.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The control row beneath a [DiveTrendChart]: how dives are grouped, and
/// which fitted overlays are drawn.
///
/// Everything lives on one row so a card costs exactly one extra line however
/// many controls it carries. The overlay toggles double as the colour key, so
/// a diver can see what the second line is without tapping anything.
///
/// A `PopupMenuButton` rather than Material 3's `DropdownMenu`: the latter is a
/// text-field-shaped widget far too heavy for a chart footer. Same compact
/// pattern as `gps_track_date_filter_action.dart`.
class TrendControlStrip extends StatelessWidget {
  const TrendControlStrip({
    super.key,
    required this.chartId,
    required this.aggregation,
    required this.onAggregationChanged,
    required this.showRollingMean,
    required this.onToggleRollingMean,
    required this.showLinearFit,
    required this.onToggleLinearFit,
    required this.rollingColor,
    required this.rateColor,
    this.rateLabel,
  });

  /// Stable id from `TrendChartIds`, used to build unique widget keys.
  final String chartId;

  final TrendAggregation aggregation;
  final ValueChanged<TrendAggregation> onAggregationChanged;
  final bool showRollingMean;
  final VoidCallback onToggleRollingMean;
  final bool showLinearFit;
  final VoidCallback onToggleLinearFit;
  final Color rollingColor;
  final Color rateColor;

  /// The fitted rate with its unit symbol, for example "+4.4 m". Null when
  /// there are too few dives to fit. Only shown while [showLinearFit] is true.
  final String? rateLabel;

  String _modeLabel(BuildContext context, TrendAggregation mode) {
    switch (mode) {
      case TrendAggregation.none:
        return context.l10n.statistics_trend_aggregation_perDive;
      case TrendAggregation.weekly:
        return context.l10n.statistics_trend_aggregation_weekly;
      case TrendAggregation.monthly:
        return context.l10n.statistics_trend_aggregation_monthly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rate = rateLabel;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<TrendAggregation>(
            key: ValueKey('trend-aggregation-$chartId'),
            tooltip: context.l10n.statistics_trend_aggregation_tooltip,
            initialValue: aggregation,
            onSelected: onAggregationChanged,
            itemBuilder: (context) => TrendAggregation.values
                .map(
                  (mode) => PopupMenuItem<TrendAggregation>(
                    value: mode,
                    child: Text(_modeLabel(context, mode)),
                  ),
                )
                .toList(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _modeLabel(context, aggregation),
                  style: theme.textTheme.bodySmall,
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
          _LegendToggle(
            toggleKey: ValueKey('trend-legend-rolling-$chartId'),
            color: rollingColor,
            label: context.l10n.statistics_trend_legend_rollingAverage,
            enabled: showRollingMean,
            onTap: onToggleRollingMean,
          ),
          _LegendToggle(
            toggleKey: ValueKey('trend-legend-rate-$chartId'),
            color: rateColor,
            label: showLinearFit && rate != null
                ? context.l10n.statistics_trend_rate_perYear(rate)
                : context.l10n.statistics_trend_legend_rate,
            enabled: showLinearFit,
            onTap: onToggleLinearFit,
          ),
        ],
      ),
    );
  }
}

/// One tappable legend entry: a colour swatch plus a label, dimmed when its
/// overlay is off.
class _LegendToggle extends StatelessWidget {
  const _LegendToggle({
    required this.toggleKey,
    required this.color,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final Key toggleKey;
  final Color color;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: toggleKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
```

Note the swatch plus label markup mirrors `MultiTrendLineChart`'s legend at `stat_charts.dart:735-752`, so the two read the same.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/trend_control_strip_test.dart`
Expected: PASS, 6 tests

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/statistics/presentation/widgets/trend_control_strip.dart \
        test/features/statistics/presentation/widgets/trend_control_strip_test.dart
git commit -m "feat(stats): add the trend chart control strip

One row beneath the chart: a compact aggregation dropdown plus two tappable
legend entries that toggle their overlay and act as the colour key.

Refs #299"
```

---

## Task 10: DiveTrendChart, raw points on a date axis

**Files:**
- Create: `lib/features/statistics/presentation/widgets/dive_trend_chart.dart`
- Test: `test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`

**Interfaces:**
- Consumes: `TrendDataPoint`, `TrendAggregation`, `aggregate` (Task 1); `DateAxis` (Task 7); `ChartAxis` from `chart_axis.dart`.
- Produces:

```dart
class DiveTrendChart extends StatelessWidget {
  const DiveTrendChart({
    super.key,
    required this.points,
    this.aggregation = TrendAggregation.none,
    this.showRollingMean = false,
    this.showLinearFit = false,
    this.pointColor,
    this.rollingColor,
    this.rateColor,
    this.yAxisLabel,
    this.height = 200,
    this.valueFormatter,
    this.yAxisFormatter,
  });

  final List<TrendDataPoint> points;
  final TrendAggregation aggregation;
  final bool showRollingMean;
  final bool showLinearFit;
  final Color? pointColor;
  final Color? rollingColor;
  final Color? rateColor;
  final String? yAxisLabel;
  final double height;
  final String Function(double)? valueFormatter;
  final String Function(double)? yAxisFormatter;
}
```

This task implements raw mode only: `showRollingMean` and `showLinearFit` are accepted but ignored until Task 12, and aggregation renders a plain mean line without the band until Task 11.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> series(int n) => List.generate(
      n,
      (i) => TrendDataPoint(
        date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
        value: 10.0 + i,
      ),
    );

Widget host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

LineChartData readData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

void main() {
  testWidgets('plots x as epoch milliseconds, not the array index',
      (tester) async {
    final points = series(6);
    await tester.pumpWidget(host(DiveTrendChart(points: points)));

    final data = readData(tester);
    final spots = data.lineBarsData.first.spots;

    expect(spots, hasLength(6));
    expect(spots.first.x, points.first.date.millisecondsSinceEpoch.toDouble());
    expect(spots.last.x, points.last.date.millisecondsSinceEpoch.toDouble());
  });

  testWidgets('the x bounds span the first and last dive', (tester) async {
    final points = series(6);
    await tester.pumpWidget(host(DiveTrendChart(points: points)));

    final data = readData(tester);

    expect(data.minX, points.first.date.millisecondsSinceEpoch.toDouble());
    expect(data.maxX, points.last.date.millisecondsSinceEpoch.toDouble());
  });

  testWidgets('draws dots with no connecting stroke in raw mode',
      (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(points: series(6))));

    final bar = readData(tester).lineBarsData.first;

    expect(bar.barWidth, 0);
    expect(bar.dotData.show, isTrue);
  });

  testWidgets('a gap between dives is preserved in the x spacing',
      (tester) async {
    final points = <TrendDataPoint>[
      TrendDataPoint(date: DateTime.utc(2024, 1, 1), value: 10),
      TrendDataPoint(date: DateTime.utc(2024, 1, 2), value: 12),
      TrendDataPoint(date: DateTime.utc(2026, 1, 1), value: 40),
    ];
    await tester.pumpWidget(host(DiveTrendChart(points: points)));

    final spots = readData(tester).lineBarsData.first.spots;
    final firstGap = spots[1].x - spots[0].x;
    final secondGap = spots[2].x - spots[1].x;

    expect(secondGap, greaterThan(firstGap * 100));
  });

  testWidgets('monthly aggregation collapses to one point per month',
      (tester) async {
    final points = <TrendDataPoint>[
      TrendDataPoint(date: DateTime.utc(2024, 1, 5), value: 10),
      TrendDataPoint(date: DateTime.utc(2024, 1, 20), value: 20),
      TrendDataPoint(date: DateTime.utc(2024, 2, 5), value: 30),
    ];
    await tester.pumpWidget(
      host(
        DiveTrendChart(
          points: points,
          aggregation: TrendAggregation.monthly,
        ),
      ),
    );

    final spots = readData(tester).lineBarsData.first.spots;

    expect(spots, hasLength(2));
    expect(spots.first.y, 15); // mean of 10 and 20
  });

  testWidgets('renders the empty state rather than a chart for no dives',
      (tester) async {
    await tester.pumpWidget(host(const DiveTrendChart(points: [])));

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No trend data available'), findsOneWidget);
  });

  testWidgets('a single dive still renders a chart', (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(points: series(1))));

    final data = readData(tester);

    expect(data.maxX, greaterThan(data.minX));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`
Expected: FAIL, `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/features/statistics/presentation/widgets/dive_trend_chart.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/widgets/chart_axis.dart';
import 'package:submersion/features/statistics/presentation/widgets/date_axis.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A per-dive trend chart on a real date axis.
///
/// Distinct from `TrendLineChart`, which plots `FlSpot(index, value)` and so
/// draws a three-month gap and a three-week gap identically. That is fine for
/// a dense monthly series; it is not fine for individual dives, which cluster
/// hard around trips (issue #299).
///
/// Layers, all sharing one set of axes:
///  - the data, as dots when raw or a mean line when aggregated
///  - a rolling mean, optional
///  - a linear fit, optional
///
/// fl_chart's ScatterChart is deliberately not used: it cannot carry the
/// overlay line series alongside the points.
class DiveTrendChart extends StatelessWidget {
  const DiveTrendChart({
    super.key,
    required this.points,
    this.aggregation = TrendAggregation.none,
    this.showRollingMean = false,
    this.showLinearFit = false,
    this.pointColor,
    this.rollingColor,
    this.rateColor,
    this.yAxisLabel,
    this.height = 200,
    this.valueFormatter,
    this.yAxisFormatter,
  });

  /// Raw per-dive points, in any order. Never pre-aggregated by the caller.
  final List<TrendDataPoint> points;

  final TrendAggregation aggregation;
  final bool showRollingMean;
  final bool showLinearFit;
  final Color? pointColor;
  final Color? rollingColor;
  final Color? rateColor;
  final String? yAxisLabel;
  final double height;
  final String Function(double)? valueFormatter;
  final String Function(double)? yAxisFormatter;

  static double _x(DateTime date) =>
      date.millisecondsSinceEpoch.toDouble();

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _EmptyChart(height: height);
    }

    final theme = Theme.of(context);
    final color = pointColor ?? theme.colorScheme.primary;

    final buckets = aggregate(points, aggregation);
    final dateAxis = DateAxis.forRange(
      buckets.first.date,
      buckets.last.date,
    );
    final yAxis = ChartAxis.forTrend(
      buckets.expand((b) => [b.min, b.max]),
    );

    final isRaw = aggregation == TrendAggregation.none;

    return Semantics(
      label: yAxisLabel != null
          ? context.l10n.statistics_chart_trendSemanticLabelWithAxis(
              points.length,
              yAxisLabel!,
            )
          : context.l10n.statistics_chart_trendSemanticLabel(points.length),
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            minX: dateAxis.min,
            maxX: dateAxis.max,
            minY: yAxis.min,
            maxY: yAxis.max,
            lineTouchData: _touchData(context, buckets),
            titlesData: _titles(context, dateAxis, yAxis),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yAxis.interval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outlineVariant,
                strokeWidth: 1,
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: buckets
                    .map((b) => FlSpot(_x(b.date), b.mean))
                    .toList(growable: false),
                isCurved: false,
                color: color,
                // Raw mode draws dots only: a stroke between two dives eight
                // months apart would assert something happened in between.
                barWidth: isRaw ? 0 : 2,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: isRaw,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 2.2,
                        color: color.withValues(alpha: 0.7),
                        strokeWidth: 0,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LineTouchData _touchData(BuildContext context, List<TrendBucket> buckets) {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final date = DateTime.fromMillisecondsSinceEpoch(
              spot.x.toInt(),
              isUtc: true,
            );
            final value =
                valueFormatter?.call(spot.y) ?? spot.y.toStringAsFixed(1);
            return LineTooltipItem(
              '${DateFormat.yMMMd().format(date)}\n$value',
              TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList();
        },
      ),
    );
  }

  FlTitlesData _titles(
    BuildContext context,
    DateAxis dateAxis,
    ChartAxis yAxis,
  ) {
    final tickMs = dateAxis.ticks
        .map((t) => t.millisecondsSinceEpoch)
        .toSet();

    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) {
            if (!tickMs.contains(value.toInt())) return const Text('');
            final date = DateTime.fromMillisecondsSinceEpoch(
              value.toInt(),
              isUtc: true,
            );
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _formatTick(date, dateAxis.granularity),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: yAxisLabel != null
            ? Text(
                yAxisLabel!,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
        axisNameSize: yAxisLabel != null ? 20 : 0,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          interval: yAxis.interval,
          getTitlesWidget: (value, meta) {
            final formatter = yAxisFormatter ?? valueFormatter;
            return Text(
              formatter?.call(value) ?? value.toStringAsFixed(0),
              style: Theme.of(context).textTheme.bodySmall,
            );
          },
        ),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    );
  }

  String _formatTick(DateTime date, DateAxisGranularity granularity) {
    switch (granularity) {
      case DateAxisGranularity.year:
        return DateFormat.y().format(date);
      case DateAxisGranularity.quarter:
      case DateAxisGranularity.month:
        return DateFormat.MMM().format(date);
      case DateAxisGranularity.day:
        return DateFormat.Md().format(date);
    }
  }
}

/// Same empty state as `TrendLineChart`, so a chart with no dives reads the
/// same wherever it appears.
class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.statistics_chart_noTrendData,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`
Expected: PASS, 7 tests

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/statistics/presentation/widgets/dive_trend_chart.dart \
        test/features/statistics/presentation/widgets/dive_trend_chart_test.dart
git commit -m "feat(stats): add DiveTrendChart with a date-valued x axis

Plots one dot per dive at its real timestamp, so trip clusters read as
clusters and quiet years read as gaps. Raw mode draws no connecting stroke,
because a segment between two dives months apart asserts something that did
not happen.

Refs #299"
```

---

## Task 11: DiveTrendChart, min/max band when aggregated

**Files:**
- Modify: `lib/features/statistics/presentation/widgets/dive_trend_chart.dart`
- Test: `test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`

**Interfaces:**
- Consumes: `TrendBucket` (Task 1), the chart from Task 10.
- Produces: no new public API. When `aggregation != TrendAggregation.none`, `LineChartData.lineBarsData` gains two invisible series (bucket min at index 1, bucket max at index 2) and `LineChartData.betweenBarsData` gains one `BetweenBarsData(fromIndex: 1, toIndex: 2)`.

Smoothing must not re-hide the spread that this whole issue is about, so an aggregated bucket shows its range as well as its mean.

- [ ] **Step 1: Write the failing test**

Append to `test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`, inside `main()`:

```dart
  group('min/max band', () {
    final spread = <TrendDataPoint>[
      TrendDataPoint(date: DateTime.utc(2024, 1, 5), value: 10),
      TrendDataPoint(date: DateTime.utc(2024, 1, 20), value: 30),
      TrendDataPoint(date: DateTime.utc(2024, 2, 5), value: 40),
      TrendDataPoint(date: DateTime.utc(2024, 2, 25), value: 60),
    ];

    testWidgets('draws no band in raw mode', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: spread)));

      expect(readData(tester).betweenBarsData, isEmpty);
    });

    testWidgets('draws one band between the min and max series when monthly',
        (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: spread,
            aggregation: TrendAggregation.monthly,
          ),
        ),
      );

      final data = readData(tester);

      expect(data.betweenBarsData, hasLength(1));
      expect(data.betweenBarsData.first.fromIndex, 1);
      expect(data.betweenBarsData.first.toIndex, 2);
    });

    testWidgets('the band series carry the bucket min and max', (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: spread,
            aggregation: TrendAggregation.monthly,
          ),
        ),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars[1].spots.map((s) => s.y), [10, 40]);
      expect(bars[2].spots.map((s) => s.y), [30, 60]);
    });

    testWidgets('the band series are not stroked or dotted', (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: spread,
            aggregation: TrendAggregation.monthly,
          ),
        ),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars[1].barWidth, 0);
      expect(bars[1].dotData.show, isFalse);
      expect(bars[2].barWidth, 0);
      expect(bars[2].dotData.show, isFalse);
    });

    testWidgets('a bucket holding one dive yields a zero-height band',
        (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: [
              TrendDataPoint(date: DateTime.utc(2024, 1, 5), value: 10),
              TrendDataPoint(date: DateTime.utc(2024, 2, 5), value: 40),
            ],
            aggregation: TrendAggregation.monthly,
          ),
        ),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars[1].spots.map((s) => s.y), bars[2].spots.map((s) => s.y));
    });

    testWidgets('the y bounds cover the band, not just the means',
        (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: spread,
            aggregation: TrendAggregation.monthly,
          ),
        ),
      );

      final data = readData(tester);

      expect(data.minY, lessThanOrEqualTo(10));
      expect(data.maxY, greaterThanOrEqualTo(60));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`
Expected: FAIL, "Expected: an object with length of <1> Actual: [] Which: is empty"

- [ ] **Step 3: Extract the bar list into a helper**

In `dive_trend_chart.dart`, replace the inline `lineBarsData: [ ... ]` argument with `lineBarsData: _bars(context, buckets, color, isRaw),` and add `betweenBarsData: _bands(context, isRaw),` immediately after it.

Then add these two methods to the class:

```dart
  /// Index 0 is always the data series. When aggregating, indices 1 and 2 are
  /// the invisible bucket min and max that [_bands] fills between.
  List<LineChartBarData> _bars(
    BuildContext context,
    List<TrendBucket> buckets,
    Color color,
    bool isRaw,
  ) {
    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: buckets
            .map((b) => FlSpot(_x(b.date), b.mean))
            .toList(growable: false),
        isCurved: false,
        color: color,
        barWidth: isRaw ? 0 : 2,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: isRaw,
          getDotPainter: (spot, percent, barData, index) =>
              FlDotCirclePainter(
                radius: 2.2,
                color: color.withValues(alpha: 0.7),
                strokeWidth: 0,
              ),
        ),
      ),
    ];

    if (!isRaw) {
      for (final selector in <double Function(TrendBucket)>[
        (b) => b.min,
        (b) => b.max,
      ]) {
        bars.add(
          LineChartBarData(
            spots: buckets
                .map((b) => FlSpot(_x(b.date), selector(b)))
                .toList(growable: false),
            isCurved: false,
            barWidth: 0,
            color: Colors.transparent,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    return bars;
  }

  /// Fills between the min and max series so an aggregated chart still shows
  /// the spread. Smoothing must not put back the hiding this issue is about.
  List<BetweenBarsData> _bands(BuildContext context, bool isRaw) {
    if (isRaw) return const [];
    final color = pointColor ?? Theme.of(context).colorScheme.primary;
    return [
      BetweenBarsData(
        fromIndex: 1,
        toIndex: 2,
        color: color.withValues(alpha: 0.15),
      ),
    ];
  }
```

The y-axis already reads `buckets.expand((b) => [b.min, b.max])` from Task 10, so the band is inside the bounds with no further change.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`
Expected: PASS, 13 tests

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/statistics/presentation/widgets/dive_trend_chart.dart \
        test/features/statistics/presentation/widgets/dive_trend_chart_test.dart
git commit -m "feat(stats): shade the min/max range behind an aggregated trend

An aggregated bucket draws its mean over a band spanning the lowest and
highest dive in it, so opting into smoothing does not re-hide the spread.

Refs #299"
```

---

## Task 12: DiveTrendChart, rolling mean and linear fit overlays

**Files:**
- Modify: `lib/features/statistics/presentation/widgets/dive_trend_chart.dart`
- Test: `test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`

**Interfaces:**
- Consumes: `rollingMean`, `linearFit`, `LinearFit`, `kMinTrendFitPoints` (Task 2).
- Produces: `showRollingMean` and `showLinearFit` become live. Both fits are computed from the **raw** `points`, never from the buckets, in every aggregation mode.

- [ ] **Step 1: Write the failing test**

Append to `test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`, inside `main()`:

```dart
  group('overlays', () {
    testWidgets('draws neither overlay by default', (tester) async {
      await tester.pumpWidget(host(DiveTrendChart(points: series(20))));

      expect(readData(tester).lineBarsData, hasLength(1));
    });

    testWidgets('draws a rolling mean series when asked', (tester) async {
      await tester.pumpWidget(
        host(DiveTrendChart(points: series(20), showRollingMean: true)),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars, hasLength(2));
      expect(bars.last.spots, hasLength(20));
      expect(bars.last.barWidth, greaterThan(0));
    });

    testWidgets('draws the linear fit as exactly two endpoints',
        (tester) async {
      await tester.pumpWidget(
        host(DiveTrendChart(points: series(20), showLinearFit: true)),
      );

      final bars = readData(tester).lineBarsData;

      expect(bars, hasLength(2));
      expect(bars.last.spots, hasLength(2));
    });

    testWidgets('draws both overlays together', (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: series(20),
            showRollingMean: true,
            showLinearFit: true,
          ),
        ),
      );

      expect(readData(tester).lineBarsData, hasLength(3));
    });

    testWidgets('draws no overlay below the minimum point count',
        (tester) async {
      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: series(4),
            showRollingMean: true,
            showLinearFit: true,
          ),
        ),
      );

      expect(readData(tester).lineBarsData, hasLength(1));
    });

    testWidgets('the rolling mean is unchanged by the aggregation mode',
        (tester) async {
      // Both fits read the raw dives. If they read the buckets instead,
      // changing the dropdown would move the trend line and wrongly imply the
      // underlying trend had changed.
      await tester.pumpWidget(
        host(DiveTrendChart(points: series(20), showRollingMean: true)),
      );
      final raw = readData(tester).lineBarsData.last.spots.map((s) => s.y)
          .toList();

      await tester.pumpWidget(
        host(
          DiveTrendChart(
            points: series(20),
            showRollingMean: true,
            aggregation: TrendAggregation.monthly,
          ),
        ),
      );
      final aggregated = readData(tester)
          .lineBarsData
          .where((b) => b.barWidth > 0)
          .last
          .spots
          .map((s) => s.y)
          .toList();

      expect(aggregated, raw);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`
Expected: FAIL, "Expected: an object with length of <2> Actual: [...] Which: has length of <1>"

- [ ] **Step 3: Implement the overlays**

In `_bars`, append the two overlay series just before `return bars;`:

```dart
    // Both fits read the RAW dives, never the buckets. Fitting over monthly
    // means would smooth twice, and the line would visibly move when the
    // dropdown changed, implying the underlying trend had changed when only
    // the drawing did.
    if (showRollingMean) {
      final smoothed = rollingMean(points);
      if (smoothed.isNotEmpty) {
        bars.add(
          LineChartBarData(
            spots: smoothed
                .map((p) => FlSpot(_x(p.date), p.value))
                .toList(growable: false),
            isCurved: false,
            color: rollingColor ?? Theme.of(context).colorScheme.primary,
            barWidth: 2.2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    if (showLinearFit) {
      final fit = linearFit(points);
      if (fit != null) {
        final first = buckets.first.date;
        final last = buckets.last.date;
        bars.add(
          LineChartBarData(
            spots: [
              FlSpot(_x(first), fit.valueAt(first)),
              FlSpot(_x(last), fit.valueAt(last)),
            ],
            isCurved: false,
            color: rateColor ?? Theme.of(context).colorScheme.tertiary,
            barWidth: 1.8,
            dashArray: const [6, 4],
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }
```

Because `_bands` addresses the band series by fixed indices 1 and 2, the overlays must be appended **after** the band series, which the ordering above already does.

The y axis must now also cover the fit, which can run outside the bucket range. In `build`, replace the `yAxis` assignment with:

```dart
    final smoothed = showRollingMean ? rollingMean(points) : const <TrendDataPoint>[];
    final fit = showLinearFit ? linearFit(points) : null;
    final yValues = <double>[
      ...buckets.expand((b) => [b.min, b.max]),
      ...smoothed.map((p) => p.value),
      if (fit != null) ...[
        fit.valueAt(buckets.first.date),
        fit.valueAt(buckets.last.date),
      ],
    ];
    final yAxis = ChartAxis.forTrend(yValues);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/dive_trend_chart_test.dart`
Expected: PASS, 19 tests

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/statistics/presentation/widgets/dive_trend_chart.dart \
        test/features/statistics/presentation/widgets/dive_trend_chart_test.dart
git commit -m "feat(stats): add rolling mean and linear fit overlays

Both fits read the raw per-dive points in every aggregation mode, so changing
how the data is grouped never moves the trend line. Neither is drawn below
five dives.

Refs #299"
```

---

## Task 13: TrendChartSection, the shared card

**Files:**
- Create: `lib/features/statistics/presentation/widgets/trend_chart_section.dart`
- Test: `test/features/statistics/presentation/widgets/trend_chart_section_test.dart`

**Interfaces:**
- Consumes: `DiveTrendChart` (Tasks 10-12), `TrendControlStrip` (Task 9), `trendChartSettingsProvider` and `TrendChartIds` (Task 6), `linearFit` (Task 2), `StatSectionCard`.
- Produces:

```dart
class TrendChartSection extends ConsumerWidget {
  const TrendChartSection({
    super.key,
    required this.chartId,
    required this.title,
    required this.subtitle,
    required this.pointsAsync,
    required this.errorMessage,
    required this.lineColor,
    this.yAxisLabel,
    this.valueFormatter,
    this.yAxisFormatter,
    this.rateFormatter,
  });

  final String chartId;
  final String title;
  final String subtitle;
  final AsyncValue<List<TrendDataPoint>> pointsAsync;
  final String errorMessage;
  final Color lineColor;
  final String? yAxisLabel;
  final String Function(double)? valueFormatter;
  final String Function(double)? yAxisFormatter;
  /// Formats the fitted per-year rate with its unit symbol, for example
  /// `(v) => units.formatDepth(v)`. Null hides the rate value.
  final String Function(double)? rateFormatter;
}
```

Four pages need the identical card, chart, strip and settings wiring. Putting it in one widget means the page tasks that follow are a handful of lines each, and there is one place to fix a layout bug rather than four.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/presentation/widgets/trend_chart_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_control_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

List<TrendDataPoint> series(int n) => List.generate(
      n,
      (i) => TrendDataPoint(
        date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
        value: 10.0 + i,
      ),
    );

Widget host(AsyncValue<List<TrendDataPoint>> value) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrendChartSection(
            chartId: TrendChartIds.depth,
            title: 'Maximum Depth Progression',
            subtitle: 'Every dive',
            pointsAsync: value,
            errorMessage: 'Failed to load depth progression',
            lineColor: Colors.indigo,
            valueFormatter: (v) => '${v.toStringAsFixed(1)}m',
            rateFormatter: (v) => '${v.toStringAsFixed(1)}m',
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the title, the chart and the control strip',
      (tester) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    expect(find.text('Maximum Depth Progression'), findsOneWidget);
    expect(find.byType(DiveTrendChart), findsOneWidget);
    expect(find.byType(TrendControlStrip), findsOneWidget);
  });

  testWidgets('starts in per-dive mode with the rolling mean on',
      (tester) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    expect(find.text('Per dive'), findsOneWidget);
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.aggregation, TrendAggregation.none);
    expect(chart.showRollingMean, isTrue);
    expect(chart.showLinearFit, isFalse);
  });

  testWidgets('choosing monthly re-renders the chart aggregated',
      (tester) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('trend-aggregation-${TrendChartIds.depth}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.aggregation, TrendAggregation.monthly);
  });

  testWidgets('tapping the rate legend turns the linear fit on',
      (tester) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('trend-legend-rate-${TrendChartIds.depth}')),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.showLinearFit, isTrue);
  });

  testWidgets('shows the fitted rate once the fit is on', (tester) async {
    await tester.pumpWidget(host(AsyncValue.data(series(20))));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('trend-legend-rate-${TrendChartIds.depth}')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('/yr'), findsOneWidget);
  });

  testWidgets('shows the error message on failure', (tester) async {
    await tester.pumpWidget(
      host(AsyncValue.error('boom', StackTrace.empty)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load depth progression'), findsOneWidget);
  });

  testWidgets('hides the control strip while loading', (tester) async {
    await tester.pumpWidget(host(const AsyncValue.loading()));
    await tester.pump();

    expect(find.byType(TrendControlStrip), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/trend_chart_section_test.dart`
Expected: FAIL, `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/features/statistics/presentation/widgets/trend_chart_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_control_strip.dart';

/// One per-dive trend chart, its card and its controls.
///
/// Four pages need exactly this combination, so it lives in one widget: the
/// pages stay short and a layout fix lands once rather than four times.
class TrendChartSection extends ConsumerWidget {
  const TrendChartSection({
    super.key,
    required this.chartId,
    required this.title,
    required this.subtitle,
    required this.pointsAsync,
    required this.errorMessage,
    required this.lineColor,
    this.yAxisLabel,
    this.valueFormatter,
    this.yAxisFormatter,
    this.rateFormatter,
  });

  /// Key into [trendChartSettingsProvider]. Use a `TrendChartIds` constant.
  final String chartId;

  final String title;
  final String subtitle;
  final AsyncValue<List<TrendDataPoint>> pointsAsync;
  final String errorMessage;
  final Color lineColor;
  final String? yAxisLabel;
  final String Function(double)? valueFormatter;
  final String Function(double)? yAxisFormatter;

  /// Formats the fitted per-year rate with its unit symbol. Null hides the
  /// numeric rate and leaves the legend entry as a plain toggle.
  final String Function(double)? rateFormatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(trendChartSettingsProvider(chartId));
    final theme = Theme.of(context);
    final rateColor = theme.colorScheme.tertiary;

    return StatSectionCard(
      title: title,
      subtitle: subtitle,
      child: pointsAsync.when(
        data: (points) {
          final fit = settings.showLinearFit ? linearFit(points) : null;
          final rate = (fit != null && rateFormatter != null)
              ? rateFormatter!(fit.perYear)
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiveTrendChart(
                points: points,
                aggregation: settings.aggregation,
                showRollingMean: settings.showRollingMean,
                showLinearFit: settings.showLinearFit,
                pointColor: lineColor,
                rollingColor: lineColor,
                rateColor: rateColor,
                yAxisLabel: yAxisLabel,
                valueFormatter: valueFormatter,
                yAxisFormatter: yAxisFormatter,
              ),
              TrendControlStrip(
                chartId: chartId,
                aggregation: settings.aggregation,
                onAggregationChanged: (mode) => _update(
                  ref,
                  settings.copyWith(aggregation: mode),
                ),
                showRollingMean: settings.showRollingMean,
                onToggleRollingMean: () => _update(
                  ref,
                  settings.copyWith(
                    showRollingMean: !settings.showRollingMean,
                  ),
                ),
                showLinearFit: settings.showLinearFit,
                onToggleLinearFit: () => _update(
                  ref,
                  settings.copyWith(showLinearFit: !settings.showLinearFit),
                ),
                rollingColor: lineColor,
                rateColor: rateColor,
                rateLabel: rate,
              ),
            ],
          );
        },
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: errorMessage,
        ),
      ),
    );
  }

  void _update(WidgetRef ref, TrendChartSettings next) {
    ref.read(trendChartSettingsProvider(chartId).notifier).state = next;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/trend_chart_section_test.dart`
Expected: PASS, 7 tests

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/statistics/presentation/widgets/trend_chart_section.dart \
        test/features/statistics/presentation/widgets/trend_chart_section_test.dart
git commit -m "feat(stats): add the shared per-dive trend chart section

Combines the card, chart, control strip and per-chart settings so the four
consuming pages stay short and a layout fix lands in one place.

Refs #299"
```

---

## Task 14: Wire the Progression page

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_progression_page.dart:51-102`
- Modify: `lib/l10n/arb/app_*.arb` (2 subtitles, 11 files)
- Test: `test/features/statistics/presentation/pages/statistics_progression_page_test.dart` (create)

**Interfaces:**
- Consumes: `TrendChartSection`, `TrendChartIds`, `depthProgressionTrendProvider`, `bottomTimeTrendProvider`.
- Produces: nothing new.

- [ ] **Step 1: Rewrite the two stale subtitles**

The current English strings assert a window that no longer exists. In `lib/l10n/arb/app_en.arb`:

```json
  "statistics_progression_depthProgression_subtitle": "Every dive in range",
  "statistics_progression_bottomTime_subtitle": "Every dive in range",
```

Update the same two keys in the other 10 locales with the equivalent translation. No new keys, so the parity test cannot catch a miss here: check each of the 11 files by hand.

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/features/statistics/presentation/pages/statistics_progression_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_progression_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_control_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

List<TrendDataPoint> series(int n) => List.generate(
      n,
      (i) => TrendDataPoint(
        date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
        value: 10.0 + i,
      ),
    );

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          depthProgressionTrendProvider.overrideWith(
            (ref) async => series(20),
          ),
          bottomTimeTrendProvider.overrideWith((ref) async => series(20)),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StatisticsProgressionPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a per-dive chart for depth and for bottom time',
      (tester) async {
    await pumpPage(tester);

    expect(find.byType(DiveTrendChart), findsNWidgets(2));
    expect(find.byType(TrendControlStrip), findsNWidgets(2));
  });

  testWidgets('both charts start in per-dive mode', (tester) async {
    await pumpPage(tester);

    final charts = tester
        .widgetList<DiveTrendChart>(find.byType(DiveTrendChart))
        .toList();

    for (final chart in charts) {
      expect(chart.aggregation, TrendAggregation.none);
    }
  });

  testWidgets('the two charts hold independent aggregation settings',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('trend-aggregation-depth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();

    final charts = tester
        .widgetList<DiveTrendChart>(find.byType(DiveTrendChart))
        .toList();

    expect(charts[0].aggregation, TrendAggregation.monthly);
    expect(charts[1].aggregation, TrendAggregation.none);
  });

  testWidgets('the cumulative and per-year charts are untouched',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Cumulative Dive Count'), findsOneWidget);
    expect(find.text('Dives Per Year'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/pages/statistics_progression_page_test.dart`
Expected: FAIL, "Expected: exactly 2 matching candidates Actual: _TypeWidgetFinder:<zero widgets>"

- [ ] **Step 4: Replace the two section builders**

In `statistics_progression_page.dart`, add the imports:

```dart
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_chart_section.dart';
```

Replace `_buildDepthProgressionSection` (L51-77) in full with:

```dart
  Widget _buildDepthProgressionSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    return TrendChartSection(
      chartId: TrendChartIds.depth,
      title: context.l10n.statistics_progression_depthProgression_title,
      subtitle: context.l10n.statistics_progression_depthProgression_subtitle,
      pointsAsync: ref.watch(depthProgressionTrendProvider),
      errorMessage:
          context.l10n.statistics_progression_depthProgression_error,
      lineColor: Colors.indigo,
      valueFormatter: (value) => units.formatDepth(value),
      rateFormatter: (value) => units.formatDepth(value),
    );
  }
```

Replace `_buildBottomTimeSection` (L79-102) in full with:

```dart
  Widget _buildBottomTimeSection(BuildContext context, WidgetRef ref) {
    String minutes(double value) => context.l10n
        .surfaceInterval_format_minutes(value.toStringAsFixed(0));

    return TrendChartSection(
      chartId: TrendChartIds.bottomTime,
      title: context.l10n.statistics_progression_bottomTime_title,
      subtitle: context.l10n.statistics_progression_bottomTime_subtitle,
      pointsAsync: ref.watch(bottomTimeTrendProvider),
      errorMessage: context.l10n.statistics_progression_bottomTime_error,
      lineColor: Colors.teal,
      valueFormatter: minutes,
      rateFormatter: minutes,
    );
  }
```

If `stat_charts.dart` is no longer referenced by this file, remove its import; `flutter analyze` will flag it as unused otherwise, and unused imports are fatal in CI.

- [ ] **Step 5: Run the test**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/pages/statistics_progression_page_test.dart`
Expected: PASS, 4 tests

- [ ] **Step 6: Format, analyze and commit**

```bash
dart format .
flutter analyze 2>&1 | tail -20
git add lib/features/statistics/presentation/pages/statistics_progression_page.dart \
        lib/l10n/arb/ \
        test/features/statistics/presentation/pages/statistics_progression_page_test.dart
git commit -m "feat(stats): plot max depth and bottom time per dive

Both charts move to TrendChartSection and gain their own aggregation and
overlay controls. Their subtitles no longer claim a five-year window that no
longer exists.

Refs #299"
```

---

## Task 15: Wire the Gas page

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_gas_page.dart:84-124`
- Modify: `lib/l10n/arb/app_*.arb` (1 subtitle, 11 files)
- Modify: `test/features/statistics/presentation/pages/statistics_gas_page_test.dart`

**Interfaces:**
- Consumes: `TrendChartSection`, `TrendChartIds.sac`, `sacTrendProvider`, `statisticsGasLaneProvider`.
- Produces: nothing new.

- [ ] **Step 1: Rewrite the stale subtitle**

In `lib/l10n/arb/app_en.arb`, replace:

```json
  "statistics_gas_sacTrend_subtitle": "Every dive in range",
```

Update the same key in the other 10 locales. The current value, "Monthly average over 5 years", is false on both counts once this task lands.

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Append to `test/features/statistics/presentation/pages/statistics_gas_page_test.dart`, inside `main()`:

```dart
  testWidgets('the consumption trend renders as a per-dive chart',
      (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          sacTrendProvider.overrideWith(
            (ref) async => List.generate(
              20,
              (i) => TrendDataPoint(
                date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
                value: 15.0 + i,
              ),
            ),
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StatisticsGasPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DiveTrendChart), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trend-aggregation-sac')),
      findsOneWidget,
    );
  });
```

Add the imports this test needs at the top of the file:

```dart
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/pages/statistics_gas_page_test.dart`
Expected: FAIL, "Expected: exactly one matching candidate Actual: zero widgets"

- [ ] **Step 4: Replace `_buildSacTrendSection`**

Add the imports:

```dart
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_chart_section.dart';
```

Replace `_buildSacTrendSection` (L84-124) in full with:

```dart
  Widget _buildSacTrendSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final lane = ref.watch(statisticsGasLaneProvider);
    final isRmv = lane == GasConsumptionLane.rmv;
    final unitSymbol = isRmv ? units.rmvSymbol : units.sacSymbol;
    String format(double v) => isRmv ? units.formatRmv(v) : units.formatSac(v);
    double convert(double v) =>
        isRmv ? units.convertRmv(v) : units.convertSac(v);
    // The axis draws the bare number, so it has to round the way the
    // tooltip's labelled value does or the two disagree (an imperial RMV
    // tick read 0.5 where its tooltip said 0.53).
    final decimals = isRmv ? units.rmvDecimals : units.sacDecimals;

    return TrendChartSection(
      chartId: TrendChartIds.sac,
      title: context.l10n.statistics_gas_sacTrend_title,
      subtitle: context.l10n.statistics_gas_sacTrend_subtitle,
      pointsAsync: ref.watch(sacTrendProvider),
      errorMessage: context.l10n.statistics_gas_sacTrend_error,
      lineColor: Colors.blue,
      yAxisLabel: unitSymbol,
      valueFormatter: format,
      yAxisFormatter: (value) => convert(value).toStringAsFixed(decimals),
      rateFormatter: format,
    );
  }
```

Both lanes share `TrendChartIds.sac`, so switching between SAC and RMV keeps the diver's chosen aggregation rather than resetting it.

- [ ] **Step 5: Run the test**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/pages/statistics_gas_page_test.dart`
Expected: PASS

- [ ] **Step 6: Format, analyze and commit**

```bash
dart format .
flutter analyze 2>&1 | tail -20
git add lib/features/statistics/presentation/pages/statistics_gas_page.dart \
        lib/l10n/arb/ \
        test/features/statistics/presentation/pages/statistics_gas_page_test.dart
git commit -m "feat(stats): plot the gas consumption trend per dive

Both the SAC and RMV lanes share one chart id, so switching lane keeps the
diver's chosen grouping rather than resetting it.

Refs #299"
```

---

## Task 16: Wire the Equipment page

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_equipment_page.dart:72-98`
- Modify: `lib/l10n/arb/app_*.arb` (1 subtitle, 11 files)
- Test: `test/features/statistics/presentation/pages/statistics_equipment_page_test.dart` (create)

**Interfaces:**
- Consumes: `TrendChartSection`, `TrendChartIds.weight`, `weightTrendProvider`.
- Produces: nothing new.

- [ ] **Step 1: Rewrite the subtitle**

In `lib/l10n/arb/app_en.arb`:

```json
  "statistics_equipment_weightTrend_subtitle": "Total lead carried per dive",
```

Update the same key in the other 10 locales. This is not only a window correction: the value itself changed from a monthly average across weight rows to the total lead on each dive, so the old "Average weight over time" describes neither the axis nor the quantity.

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/features/statistics/presentation/pages/statistics_equipment_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_equipment_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          weightTrendProvider.overrideWith(
            (ref) async => List.generate(
              20,
              (i) => TrendDataPoint(
                date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
                value: 6.0 + (i % 3),
              ),
            ),
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StatisticsEquipmentPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the weight trend as a per-dive chart', (tester) async {
    await pumpPage(tester);

    expect(find.byType(DiveTrendChart), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trend-aggregation-weight')),
      findsOneWidget,
    );
  });

  testWidgets('starts in per-dive mode', (tester) async {
    await pumpPage(tester);

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.aggregation, TrendAggregation.none);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/pages/statistics_equipment_page_test.dart`
Expected: FAIL, "Expected: exactly one matching candidate Actual: zero widgets"

- [ ] **Step 4: Replace `_buildWeightTrendSection`**

Add the imports:

```dart
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_chart_section.dart';
```

Replace `_buildWeightTrendSection` (L72-98) in full with:

```dart
  Widget _buildWeightTrendSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    return TrendChartSection(
      chartId: TrendChartIds.weight,
      title: context.l10n.statistics_equipment_weightTrend_title,
      subtitle: context.l10n.statistics_equipment_weightTrend_subtitle,
      pointsAsync: ref.watch(weightTrendProvider),
      errorMessage: context.l10n.statistics_equipment_weightTrend_error,
      lineColor: Colors.purple,
      valueFormatter: (value) => units.formatWeight(value),
      rateFormatter: (value) => units.formatWeight(value),
    );
  }
```

- [ ] **Step 5: Run the test**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/pages/statistics_equipment_page_test.dart`
Expected: PASS, 2 tests

- [ ] **Step 6: Format, analyze and commit**

```bash
dart format .
flutter analyze 2>&1 | tail -20
git add lib/features/statistics/presentation/pages/statistics_equipment_page.dart \
        lib/l10n/arb/ \
        test/features/statistics/presentation/pages/statistics_equipment_page_test.dart
git commit -m "feat(stats): plot total lead carried per dive

The subtitle now names the quantity the chart actually shows, which changed
from a monthly average across weight rows to each dive's total lead.

Refs #299"
```

---

## Task 17: Wire the Conditions page

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_conditions_page.dart` (build list plus `_buildTemperatureSection` L193-262)
- Modify: `lib/l10n/arb/app_*.arb` (2 changed values, 4 new keys, 11 files)
- Test: `test/features/statistics/presentation/pages/statistics_conditions_temperature_test.dart` (create)

**Interfaces:**
- Consumes: `TrendChartSection`, `TrendChartIds.waterTemp`, `waterTempTrendProvider` (Task 6), the existing `temperatureByMonthProvider`.
- Produces: nothing new.

The seasonal chart is kept, not replaced. It genuinely shows real variation for a diver with one home region; it just needs to stop pretending to be a progression.

- [ ] **Step 1: Add and rewrite the localization**

In `lib/l10n/arb/app_en.arb`, change these two values:

```json
  "statistics_conditions_temperature_title": "Seasonal Water Temperature",
  "statistics_conditions_temperature_subtitle": "Min, average and max by calendar month, across every year",
```

And add these four new keys:

```json
  "statistics_conditions_tempTrend_empty": "No temperature data available",
  "statistics_conditions_tempTrend_error": "Failed to load temperature trend",
  "statistics_conditions_tempTrend_subtitle": "Every dive in range",
  "statistics_conditions_tempTrend_title": "Water Temperature Trend",
```

Apply the two changed values and the four new keys to the other 10 locales.

- [ ] **Step 2: Verify parity, then regenerate**

Run: `flutter test --exclude-tags performance test/l10n/arb_parity_test.dart`
Expected: PASS once all 11 files carry the four new keys

Run: `flutter gen-l10n`

- [ ] **Step 3: Write the failing test**

Create `test/features/statistics/presentation/pages/statistics_conditions_temperature_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_conditions_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          waterTempTrendProvider.overrideWith(
            (ref) async => List.generate(
              20,
              (i) => TrendDataPoint(
                date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
                value: 10.0 + i,
              ),
            ),
          ),
          temperatureByMonthProvider.overrideWith(
            (ref) async => [
              (month: 1, minTemp: 8.0, avgTemp: 10.0, maxTemp: 12.0),
              (month: 7, minTemp: 24.0, avgTemp: 27.0, maxTemp: 29.0),
            ],
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StatisticsConditionsPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a per-dive temperature trend', (tester) async {
    await pumpPage(tester);

    expect(find.text('Water Temperature Trend'), findsOneWidget);
    expect(find.byType(DiveTrendChart), findsOneWidget);
  });

  testWidgets('keeps the seasonal chart, retitled', (tester) async {
    await pumpPage(tester);

    expect(find.text('Seasonal Water Temperature'), findsOneWidget);
    expect(find.byType(MultiTrendLineChart), findsOneWidget);
  });

  testWidgets('the trend chart starts in per-dive mode', (tester) async {
    await pumpPage(tester);

    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.aggregation, TrendAggregation.none);
  });

  testWidgets('the seasonal subtitle says it collapses years',
      (tester) async {
    await pumpPage(tester);

    expect(find.textContaining('across every year'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/pages/statistics_conditions_temperature_test.dart`
Expected: FAIL, "Expected: exactly one matching candidate Actual: zero widgets" for 'Water Temperature Trend'

- [ ] **Step 5: Add the trend section and keep the seasonal one**

Add the imports:

```dart
import 'package:submersion/features/statistics/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/trend_chart_section.dart';
```

Add this new method beside `_buildTemperatureSection`:

```dart
  /// Water temperature as a time series, one point per dive.
  ///
  /// The sibling seasonal chart collapses every year into twelve calendar
  /// buckets, which is meaningful for a diver with one home region and
  /// meaningless for one who travels between cold and warm water (issue #299).
  /// Both are kept because both readings are legitimate.
  Widget _buildTemperatureTrendSection(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    return TrendChartSection(
      chartId: TrendChartIds.waterTemp,
      title: context.l10n.statistics_conditions_tempTrend_title,
      subtitle: context.l10n.statistics_conditions_tempTrend_subtitle,
      pointsAsync: ref.watch(waterTempTrendProvider),
      errorMessage: context.l10n.statistics_conditions_tempTrend_error,
      lineColor: Colors.teal,
      valueFormatter: (value) => units.formatTemperature(value),
      rateFormatter: (value) => units.formatTemperature(value),
    );
  }
```

Leave `_buildTemperatureSection` itself unchanged: it already reads its title and subtitle from the two keys whose values Step 1 rewrote.

In the page's `build` list, insert the new section immediately before the existing temperature section, with the usual `const SizedBox(height: 16)` between them, so the time series is read first and the seasonal view sits below it as context.

- [ ] **Step 6: Run the test**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/pages/`
Expected: PASS

- [ ] **Step 7: Format, analyze and commit**

```bash
dart format .
flutter analyze 2>&1 | tail -20
git add lib/features/statistics/presentation/pages/statistics_conditions_page.dart \
        lib/l10n/arb/ \
        test/features/statistics/presentation/pages/statistics_conditions_temperature_test.dart
git commit -m "feat(stats): add a per-dive water temperature trend

The twelve-bucket calendar chart is kept and retitled Seasonal Water
Temperature, with a subtitle stating that it collapses every year. A
travelling diver now gets the honest series; a diver with one home region
keeps the seasonal read.

Refs #299"
```

---

## Task 18: Last 5 Years and Last 10 Years date presets

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart:274-285` (insert after the "Last Year" chip)
- Modify: `lib/l10n/arb/app_*.arb` (2 new keys, 11 files)
- Test: `test/features/dive_log/presentation/widgets/dive_filter_sheet_presets_test.dart` (create)

**Interfaces:**
- Consumes: the existing `_datePresetChip` helper at L1116-1127.
- Produces: two new l10n keys, `diveLog_filter_presetLast5Years` and `diveLog_filter_presetLast10Years`.

The sheet is shared with the dive list filter, so these presets appear there too. That is a deliberate, accepted side effect outside the Statistics tab.

- [ ] **Step 1: Add the localization**

In `lib/l10n/arb/app_en.arb`:

```json
  "diveLog_filter_presetLast10Years": "Last 10 Years",
  "diveLog_filter_presetLast5Years": "Last 5 Years",
```

Add translations of both keys to the other 10 locales.

Run: `flutter test --exclude-tags performance test/l10n/arb_parity_test.dart`
Expected: PASS

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_filter_sheet_presets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    final container = ProviderContainer(overrides: overrides.cast());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: SingleChildScrollView(
                child: DiveFilterSheet(
                  ref: ref,
                  filterProvider: statisticsFilterProvider,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('offers the two new long-range presets', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Last 5 Years'), findsOneWidget);
    expect(find.text('Last 10 Years'), findsOneWidget);
  });

  testWidgets('Last 5 Years sets a start date about five years back',
      (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Last 5 Years'));
    await tester.pumpAndSettle();

    // The chip sets local state; the sheet's apply button commits it. Read
    // the rendered start-date button label rather than the provider.
    final now = DateTime.now();
    expect(find.textContaining('${now.year - 5}'), findsWidgets);
  });

  testWidgets('All Time still clears both dates', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Last 5 Years'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Time'));
    await tester.pumpAndSettle();

    expect(find.text('Start Date'), findsOneWidget);
    expect(find.text('End Date'), findsOneWidget);
  });
}
```

If the sheet's start/end button placeholder text differs from `Start Date` / `End Date`, read the current values of `diveLog_filter_startDate` and `diveLog_filter_endDate` in `app_en.arb` and use those exact strings.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/dive_log/presentation/widgets/dive_filter_sheet_presets_test.dart`
Expected: FAIL, "Expected: exactly one matching candidate Actual: zero widgets" for 'Last 5 Years'

- [ ] **Step 4: Add the two chips**

In `dive_filter_sheet.dart`, inside the `Wrap` at L227-286, insert immediately after the "Last Year" chip (which ends at L284) and before the closing `],`:

```dart
                            _datePresetChip(
                              context,
                              context.l10n.diveLog_filter_presetLast5Years,
                              () {
                                final now = DateTime.now();
                                setState(() {
                                  _startDate = DateTime(
                                    now.year - 5,
                                    now.month,
                                    now.day,
                                  );
                                  _endDate = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  );
                                });
                              },
                            ),
                            _datePresetChip(
                              context,
                              context.l10n.diveLog_filter_presetLast10Years,
                              () {
                                final now = DateTime.now();
                                setState(() {
                                  _startDate = DateTime(
                                    now.year - 10,
                                    now.month,
                                    now.day,
                                  );
                                  _endDate = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  );
                                });
                              },
                            ),
```

"Lifetime" needs no chip: the existing "All Time" preset already nulls both dates, and with the five-year cutoffs gone from Task 3 onward that now genuinely means every dive.

- [ ] **Step 5: Run the test**

Run: `flutter test --exclude-tags performance test/features/dive_log/presentation/widgets/dive_filter_sheet_presets_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 6: Format, analyze and commit**

```bash
dart format .
flutter analyze 2>&1 | tail -20
git add lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart \
        lib/l10n/arb/ \
        test/features/dive_log/presentation/widgets/dive_filter_sheet_presets_test.dart
git commit -m "feat(filter): add Last 5 Years and Last 10 Years date presets

Completes the preset list issue #299 asked for. Lifetime needs no chip: All
Time already nulls both dates, and that now reaches every dive.

Refs #299"
```

---

## Task 19: Filter affordance on the statistics detail pages

**Files:**
- Create: `lib/features/statistics/presentation/widgets/statistics_filter_action.dart`
- Modify: `lib/features/statistics/presentation/pages/statistics_progression_page.dart`, `statistics_gas_page.dart`, `statistics_equipment_page.dart`, `statistics_conditions_page.dart` (each `Scaffold`/`AppBar`)
- Test: `test/features/statistics/presentation/widgets/statistics_filter_action_test.dart` (create)

**Interfaces:**
- Consumes: `statisticsFilterProvider`, `DiveFilterSheet`, `StatisticsFilterBar`.
- Produces: `class StatisticsFilterAction extends ConsumerWidget { const StatisticsFilterAction({super.key}); }`

Today none of these pages has a filter control. On mobile you must set the span on `/statistics` and then drill in, which makes the span the whole feature depends on unreachable from the chart it governs.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/presentation/widgets/statistics_filter_action_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_action.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpAction(
    WidgetTester tester, {
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          statisticsFilterProvider.overrideWith((ref) => filter),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(actions: const [StatisticsFilterAction()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders an unbadged filter icon when no filter is active',
      (tester) async {
    await pumpAction(tester);

    expect(find.byKey(const ValueKey('statistics-filter-action')),
        findsOneWidget);
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('badges the icon when a filter is active', (tester) async {
    await pumpAction(
      tester,
      filter: DiveFilterState(startDate: DateTime.utc(2024, 1, 1)),
    );

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('tapping it opens the filter sheet', (tester) async {
    await pumpAction(tester);

    await tester.tap(find.byKey(const ValueKey('statistics-filter-action')));
    await tester.pumpAndSettle();

    expect(find.byType(DiveFilterSheet), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/statistics_filter_action_test.dart`
Expected: FAIL, `Target of URI doesn't exist`

- [ ] **Step 3: Write the implementation**

Create `lib/features/statistics/presentation/widgets/statistics_filter_action.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// AppBar action opening the statistics filter, badged while a filter is set.
///
/// Extracted from the three places that had hand-rolled the same block. The
/// statistics detail pages had no filter affordance at all, so on a phone the
/// span governing a chart could only be changed from the tab root and then
/// drilled back into (issue #299).
class StatisticsFilterAction extends ConsumerWidget {
  const StatisticsFilterAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const ValueKey('statistics-filter-action'),
      icon: Badge(
        isLabelVisible: ref.watch(statisticsFilterProvider).hasActiveFilters,
        child: const Icon(Icons.filter_list),
      ),
      tooltip: context.l10n.statistics_tooltip_filter,
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DiveFilterSheet(
          ref: ref,
          filterProvider: statisticsFilterProvider,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --exclude-tags performance test/features/statistics/presentation/widgets/statistics_filter_action_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 5: Mount it on the four detail pages**

In each of `statistics_progression_page.dart`, `statistics_gas_page.dart`, `statistics_equipment_page.dart` and `statistics_conditions_page.dart`, add the imports:

```dart
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_action.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_bar.dart';
```

Then replace each page's non-embedded return. For the conditions page, for example, replace:

```dart
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_conditions_appBar_title),
      ),
      body: content,
    );
```

with:

```dart
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statistics_conditions_appBar_title),
        actions: const [StatisticsFilterAction()],
      ),
      body: Column(
        children: [
          const StatisticsFilterBar(),
          Expanded(child: content),
        ],
      ),
    );
```

Apply the same shape to the other three pages, substituting their own AppBar title key. The `embedded` branch is left untouched: in the master-detail layout the list pane already owns the filter icon and the bar, so a second copy would be redundant.

`Expanded(child: content)` is required because `content` is a `SingleChildScrollView`; without it the Column gives the scroll view unbounded height and the page throws a layout error.

- [ ] **Step 6: Replace the three existing duplicated blocks**

Now that the widget exists, replace the hand-rolled filter `IconButton` in each of `statistics_page.dart:102-118`, `statistics_list_content.dart:167-181` and `statistics_list_content.dart:221-235` with `const StatisticsFilterAction()`. Remove any imports those files no longer need.

This duplication was recorded as a follow-up when the filter shipped; adding a fourth copy without collapsing them would make it worse.

- [ ] **Step 7: Run the affected tests**

Run: `flutter test --exclude-tags performance test/features/statistics/`
Expected: PASS

Run: `flutter analyze 2>&1 | tail -20`
Expected: "No issues found!"

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/features/statistics/presentation/widgets/statistics_filter_action.dart \
        lib/features/statistics/presentation/pages/ \
        lib/features/statistics/presentation/widgets/statistics_list_content.dart \
        test/features/statistics/presentation/widgets/statistics_filter_action_test.dart
git commit -m "feat(stats): put the filter on the statistics detail pages

Extracts the filter action that three call sites had duplicated and mounts it
on the four chart pages, which previously had no filter affordance at all: on
a phone the span governing a chart could only be set from the tab root.

Refs #299"
```

---

## Task 20: Whole-suite verification

**Files:** none changed unless a failure requires it.

**Interfaces:**
- Consumes: everything.
- Produces: a branch ready for a pull request.

- [ ] **Step 1: Confirm no hardcoded window survives**

Run:

```bash
grep -rn "365 \* 5\|365\*5" lib/features/statistics/
```

Expected: no output. Any hit is a cutoff that survived, and "lifetime" is still unreachable through it.

- [ ] **Step 2: Confirm no per-dive query aggregates by month**

Run:

```bash
grep -n "GROUP BY year, month" lib/features/statistics/data/repositories/statistics_repository.dart
```

Expected: only `getCumulativeDiveCount`, which is deliberately still monthly and out of scope.

- [ ] **Step 3: Confirm no provider leaked outside the feature**

Run:

```bash
grep -rn "waterTempTrendProvider\|trendChartSettingsProvider\|DiveTrendChart\|TrendChartSection" lib/ | grep -v "features/statistics/"
```

Expected: no output.

- [ ] **Step 4: Format the whole project**

Run: `dart format .`
Expected: files reformatted or already formatted; commit any change.

- [ ] **Step 5: Analyze the whole project**

Run: `flutter analyze 2>&1 | tail -20`
Expected: "No issues found!"

Do not pipe this into `grep`: a pipe returns grep's exit status and masks a failure. Infos are fatal in CI, so treat any output as a failure.

- [ ] **Step 6: Run the full test suite once**

Run: `flutter test --exclude-tags performance`
Expected: all tests pass

Run it once, and do not run a second suite concurrently in another worktree: overlapping runs on this machine produce spurious single-file failures through shared temp directories. If exactly one unfamiliar test fails, rerun that file alone before investigating.

- [ ] **Step 7: Verify the generated localizations are current**

Run: `flutter gen-l10n && git status --short lib/l10n/`
Expected: no modified generated files. CI regenerates l10n but never verifies it, so a stale generated file would not be caught downstream.

- [ ] **Step 8: Commit anything the previous steps changed**

```bash
git add lib/ test/
git commit -m "chore(stats): formatting and generated localizations

Refs #299"
```

- [ ] **Step 9: Manual smoke check**

Launch the app on macOS and confirm, on a real logbook:

1. Statistics > Progression shows individual dive dots, not a monthly line.
2. The aggregation dropdown switches to Weekly and Monthly, and the shaded band appears.
3. Tapping the rate legend draws the dashed fit and shows a per-year figure in the diver's depth unit.
4. The filter icon is present on the Progression, Gas, Equipment and Conditions pages.
5. Setting "All Time" reveals dives older than five years.
6. Conditions shows both Water Temperature Trend and Seasonal Water Temperature.
7. Switching the diver's units from metric to imperial changes the chart axis, the tooltip and the rate figure together.

Note that `open_application` launches the installed app, not this worktree's build; build and run from this worktree explicitly.

---

## Self-review notes

Checked against the spec, 2026-08-27:

- **Spec coverage.** Every spec section maps to a task: domain module (1, 2), repository rewrite (3, 4, 5), providers (6), date axis and chart (7, 10, 11, 12), control strip (9), pages (14, 15, 16, 17), span control (18), filter affordance (19), localization (8 plus per-page steps), testing (throughout), verification (20). The spec's "no schema change" needs no task.
- **One deliberate addition.** The spec did not name `TrendChartSection`; it emerged from the four pages needing identical wiring. Task 13 carries it. Without it, Tasks 14 through 17 would each repeat forty lines of the same code.
- **One deliberate correction.** The spec said `getWeightPerDive` returns weight per dive without saying which statistic. Task 4 uses `SUM` over a dive's weight rows and says why the old `AVG` was wrong. The subtitle rewrite in Task 16 follows from it.
- **Type consistency.** `TrendDataPoint` is defined once in Task 1 and re-exported; `TrendAggregation`, `TrendBucket` and `LinearFit` are used with the same names and members throughout. `TrendChartIds` constants (`depth`, `bottomTime`, `sac`, `weight`, `waterTemp`) match the widget keys asserted in Tasks 14 through 17.
- **Ordering constraint.** Task 12 appends the overlay series after the band series because Task 11's `_bands` addresses indices 1 and 2 by position. Both tasks state this.
