# Trend Chart Gap Breaks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse stretches with no dives longer than a diver-chosen threshold into a narrow hatched band on every `DiveTrendChart`, so long breaks in diving stop dominating the trend charts (issue #3251).

**Architecture:** A pure-Dart `TrendTimeScale` maps dates to a piecewise-linear x axis (real time inside each period of diving, a fixed-width band per collapsed gap) and back. `DiveTrendChart`, `DateAxis`, `TrendWindowSeater` and `trendRangeFractions` route every coordinate through it; with the setting Off, or no qualifying gap, the scale is the identity and today's behaviour is unchanged. The threshold is one synced per-diver setting (`diver_settings.trend_gap_collapse_months`, schema v278), edited from Settings > Appearance and from each trend chart's Range menu.

**Tech Stack:** Flutter, fl_chart 1.1.1 (`LineChart`, `FlSpot.nullSpot`), Drift (schema ladder), Riverpod (`settingsProvider`), ARB l10n.

**Spec:** `docs/design/specs/2026-10-11-trend-chart-gap-breaks-design.md`

> **Schema note:** this plan was written against v278. Main shipped v278 (issue #3226), v279 (issue #3106) and v280 (issue #2361) first, so the rung landed as **v281**; read every v278 and 277 below as v281 and 280.

## Global Constraints

- Threshold choices: Off (0), 6 months (6), 1 year (12, the default), 2 years (24). Any other stored or synced value reads as 1 year.
- A gap is two consecutive plotted dates where the later is after the earlier plus N calendar months; exactly N months is not a gap.
- Each band is 3% of the collapsed span (sum of the periods), never narrower than one day of axis.
- Identity scale: `toAxis(d) == d.millisecondsSinceEpoch` exactly, so Off renders exactly as before.
- Schema: `currentSchemaVersion` 277 to 278; additive defaulted column, so `minimumCompatibleSchemaVersion` stays 275.
- New lib/ code goes in new files or the files named here; never add a table or rung to `database.dart` beyond the `migrationVersions` entry and the version constant; `before_open.dart` stays under 800 lines.
- No em dashes or en dashes as punctuation anywhere (code, comments, ARB values, commits).
- Every new user-visible string is in `app_en.arb` and translated into ar, de, es, fr, he, hu, it, nl, pt, zh in the same change.
- `dart format .`, `flutter analyze`, `test/architecture/` and `test/shared/` pass before each commit that adds lib/ files.

## Review Focus

1. **Local (non-UTC) dive dates.** Points carry local `DateTime`s on device; the scale must compare instants (epoch ms) and never mix local and UTC field arithmetic in a way that moves a gap by a day. Test in Task 2: local dates build the same breaks as their UTC instants.
2. **Threshold change while a custom window is showing.** The window must keep its real dates. Test in Task 4.
3. **Tap-to-open after a break in aggregated mode.** Null spots shift fl_chart's spot indices; a tap on a bucket after a break must open that bucket's dive, not its neighbour's. Test in Task 8.
4. **Two dives years apart.** The collapsed span is zero; the band must still have width, nothing divides by zero, and the chart draws. Tests in Tasks 2 and 8.
5. **Secondary series only (condition charts, Focus).** The primary is empty and the data is in `secondarySeries`; the scale must be built from every series. Test in Task 8.

---

### Task 1: `TrendGapThreshold` domain type

**Files:**
- Create: `lib/features/insights/domain/trend_gap_threshold.dart`
- Test: `test/features/insights/domain/trend_gap_threshold_test.dart`

**Interfaces:**
- Produces: `enum TrendGapThreshold { off, months6, year1, years2 }` with `final int months`, `static const defaultValue = TrendGapThreshold.year1`, `static TrendGapThreshold fromMonths(int? months)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';

void main() {
  test('each choice carries its month count', () {
    expect(TrendGapThreshold.off.months, 0);
    expect(TrendGapThreshold.months6.months, 6);
    expect(TrendGapThreshold.year1.months, 12);
    expect(TrendGapThreshold.years2.months, 24);
  });

  test('the default is one year', () {
    expect(TrendGapThreshold.defaultValue, TrendGapThreshold.year1);
  });

  test('fromMonths reads every stored choice back', () {
    for (final t in TrendGapThreshold.values) {
      expect(TrendGapThreshold.fromMonths(t.months), t);
    }
  });

  test('an unknown or missing count reads as the default', () {
    expect(TrendGapThreshold.fromMonths(7), TrendGapThreshold.year1);
    expect(TrendGapThreshold.fromMonths(-1), TrendGapThreshold.year1);
    expect(TrendGapThreshold.fromMonths(null), TrendGapThreshold.year1);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/features/insights/domain/trend_gap_threshold_test.dart`
Expected: compile error, `trend_gap_threshold.dart` not found.

- [ ] **Step 3: Implement**

```dart
/// How long a stretch with no dives must last before a trend chart collapses
/// it into a break (issue #3251). Stored as [months] in
/// `diver_settings.trend_gap_collapse_months`.
enum TrendGapThreshold {
  off(0),
  months6(6),
  year1(12),
  years2(24);

  const TrendGapThreshold(this.months);

  /// Calendar months a gap must exceed; 0 for [off].
  final int months;

  static const defaultValue = TrendGapThreshold.year1;

  /// The choice stored as [months]. Anything else, from an older or newer
  /// peer or a hand-edited database, reads as [defaultValue].
  static TrendGapThreshold fromMonths(int? months) {
    for (final t in values) {
      if (t.months == months) return t;
    }
    return defaultValue;
  }
}
```

- [ ] **Step 4: Run it and see it pass**

Run: `flutter test test/features/insights/domain/trend_gap_threshold_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights/domain/trend_gap_threshold.dart test/features/insights/domain/trend_gap_threshold_test.dart
git commit -m "feat(insights): add the trend gap threshold choices"
```

---

### Task 2: `TrendTimeScale`

**Files:**
- Create: `lib/features/insights/domain/trend_time_scale.dart`
- Test: `test/features/insights/domain/trend_time_scale_test.dart`

**Interfaces:**
- Consumes: `TrendGapThreshold` (Task 1).
- Produces:
  - `class TrendGapBreak { final DateTime start; final DateTime end; final double axisStart; final double axisEnd; }`
  - `class TrendTimeScale` with `static const TrendTimeScale identity`, `factory TrendTimeScale.build(Iterable<DateTime> dates, TrendGapThreshold threshold)`, `List<TrendGapBreak> breaks`, `bool get isIdentity`, `double toAxis(DateTime date)`, `DateTime toDate(double x)` (UTC), `TrendGapBreak? breakAt(double x)`, `int periodOf(DateTime date)`, `static const double bandFraction = 0.03`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';

double ms(DateTime d) => d.millisecondsSinceEpoch.toDouble();
const day = Duration.millisecondsPerDay;

List<DateTime> weekly(DateTime from, DateTime to) => [
  for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 7))) d,
];

void main() {
  final early = weekly(DateTime.utc(2013, 1, 1), DateTime.utc(2013, 12, 31));
  final late = weekly(DateTime.utc(2020, 1, 1), DateTime.utc(2020, 6, 30));

  group('identity', () {
    test('off never collapses anything', () {
      final s = TrendTimeScale.build([...early, ...late], TrendGapThreshold.off);
      expect(s.isIdentity, isTrue);
      expect(s.toAxis(late.first), ms(late.first));
    });

    test('no gap past the threshold is the identity', () {
      final s = TrendTimeScale.build(early, TrendGapThreshold.year1);
      expect(s.isIdentity, isTrue);
      for (final d in early) {
        expect(s.toAxis(d), ms(d));
        expect(s.toDate(ms(d)), d);
      }
    });

    test('one date or none is the identity', () {
      expect(TrendTimeScale.build([], TrendGapThreshold.year1).isIdentity, isTrue);
      expect(
        TrendTimeScale.build([DateTime.utc(2020)], TrendGapThreshold.year1).isIdentity,
        isTrue,
      );
    });
  });

  group('threshold boundary', () {
    test('exactly twelve calendar months is not a gap', () {
      final s = TrendTimeScale.build(
        [DateTime.utc(2020, 1, 1), DateTime.utc(2021, 1, 1)],
        TrendGapThreshold.year1,
      );
      expect(s.isIdentity, isTrue);
    });

    test('a day past twelve months is a gap', () {
      final s = TrendTimeScale.build(
        [DateTime.utc(2020, 1, 1), DateTime.utc(2021, 1, 2)],
        TrendGapThreshold.year1,
      );
      expect(s.breaks, hasLength(1));
    });

    test('six months collapses what a year keeps', () {
      final dates = [DateTime.utc(2020, 1, 1), DateTime.utc(2020, 9, 1)];
      expect(TrendTimeScale.build(dates, TrendGapThreshold.months6).breaks, hasLength(1));
      expect(TrendTimeScale.build(dates, TrendGapThreshold.year1).isIdentity, isTrue);
    });
  });

  group('one break', () {
    final s = TrendTimeScale.build([...late, ...early], TrendGapThreshold.year1);
    final b = s.breaks.single;

    test('the break runs from the last dive before it to the first after', () {
      expect(b.start, early.last);
      expect(b.end, late.first);
    });

    test('the first period is unshifted', () {
      expect(s.toAxis(early.first), ms(early.first));
      expect(b.axisStart, ms(early.last));
    });

    test('the band is three percent of the collapsed span', () {
      final collapsed =
          (ms(early.last) - ms(early.first)) + (ms(late.last) - ms(late.first));
      expect(b.axisEnd - b.axisStart, closeTo(collapsed * 0.03, 1));
      expect(s.toAxis(late.first), closeTo(b.axisEnd, 0.001));
    });

    test('every plotted date round-trips', () {
      for (final d in [...early, ...late]) {
        expect(s.toDate(s.toAxis(d)), d);
      }
    });

    test('a date inside the gap maps proportionally across the band', () {
      final mid = DateTime.fromMillisecondsSinceEpoch(
        ((ms(b.start) + ms(b.end)) / 2).round(),
        isUtc: true,
      );
      expect(s.toAxis(mid), closeTo((b.axisStart + b.axisEnd) / 2, 1));
      expect(s.breakAt(s.toAxis(mid)), same(b));
    });

    test('breakAt is null away from the band', () {
      expect(s.breakAt(s.toAxis(early.first)), isNull);
      expect(s.breakAt(s.toAxis(late.last)), isNull);
    });

    test('periodOf numbers the periods', () {
      expect(s.periodOf(early.first), 0);
      expect(s.periodOf(early.last), 0);
      expect(s.periodOf(late.first), 1);
    });

    test('dates outside the data extrapolate with their period', () {
      final before = DateTime.utc(2012, 6, 1);
      final after = DateTime.utc(2021, 1, 1);
      expect(s.toAxis(before), ms(before));
      expect(s.toDate(s.toAxis(after)), after);
    });
  });

  test('several breaks shift each later period further', () {
    final third = weekly(DateTime.utc(2024, 1, 1), DateTime.utc(2024, 3, 1));
    final s = TrendTimeScale.build([...early, ...late, ...third], TrendGapThreshold.year1);
    expect(s.breaks, hasLength(2));
    expect(s.breaks[1].axisStart, greaterThan(s.breaks[0].axisEnd));
    for (final d in [...early, ...late, ...third]) {
      expect(s.toDate(s.toAxis(d)), d);
    }
    expect(s.periodOf(third.first), 2);
  });

  test('two dives years apart still get a band a day wide', () {
    final a = DateTime.utc(2015, 5, 1);
    final b = DateTime.utc(2019, 5, 1);
    final s = TrendTimeScale.build([a, b], TrendGapThreshold.year1);
    expect(s.toAxis(b) - s.toAxis(a), day.toDouble());
    expect(s.toDate(s.toAxis(b)), b);
  });

  test('order and duplicates do not matter', () {
    final shuffled = [...late.reversed, ...early, ...early];
    final s = TrendTimeScale.build(shuffled, TrendGapThreshold.year1);
    expect(s.breaks.single.start, early.last);
  });

  test('local dates build the same break as their instants', () {
    final local = [DateTime(2013, 3, 1, 10), DateTime(2013, 4, 1, 10), DateTime(2016, 3, 1, 10)];
    final utc = [for (final d in local) d.toUtc()];
    final a = TrendTimeScale.build(local, TrendGapThreshold.year1);
    final b = TrendTimeScale.build(utc, TrendGapThreshold.year1);
    expect(a.breaks.single.axisStart, b.breaks.single.axisStart);
    expect(a.toAxis(local.last), b.toAxis(utc.last));
  });
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/features/insights/domain/trend_time_scale_test.dart`
Expected: compile error, `trend_time_scale.dart` not found.

- [ ] **Step 3: Implement**

```dart
import 'dart:math' as math;

import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';

/// One collapsed stretch with no dives (issue #3251).
class TrendGapBreak {
  const TrendGapBreak({
    required this.start,
    required this.end,
    required this.axisStart,
    required this.axisEnd,
  });

  /// The last plotted date before the gap.
  final DateTime start;

  /// The first plotted date after it.
  final DateTime end;

  /// The band's left and right edges on the chart's x axis.
  final double axisStart;
  final double axisEnd;
}

/// Maps dates to a trend chart's x axis and back, collapsing every stretch
/// with no dives longer than a [TrendGapThreshold] into a narrow band.
///
/// Piecewise linear: inside a period of diving, axis distance is real time
/// in milliseconds; each break is replaced by a band [bandFraction] of the
/// collapsed span wide, across which a date inside the gap maps
/// proportionally. The first period is never shifted, so a scale with no
/// breaks is exactly epoch milliseconds and a chart drawn through it is
/// unchanged.
class TrendTimeScale {
  const TrendTimeScale._(this.breaks, this._shifts);

  /// No breaks: `toAxis(d) == d.millisecondsSinceEpoch`.
  static const identity = TrendTimeScale._(<TrendGapBreak>[], <double>[0]);

  /// Share of the collapsed span (the sum of the periods) each band takes.
  static const double bandFraction = 0.03;

  /// A band is never narrower than this, so two dives years apart with
  /// nothing between them still draw a visible break.
  static const double _minBandMs = Duration.millisecondsPerDay * 1.0;

  /// Breaks in date order.
  final List<TrendGapBreak> breaks;

  /// Milliseconds subtracted from a date in period `i` to reach the axis.
  /// One more entry than [breaks].
  final List<double> _shifts;

  bool get isIdentity => breaks.isEmpty;

  /// Builds the scale for [dates] (any order, duplicates allowed): every
  /// date the chart plots, so no plotted point can fall inside a band.
  factory TrendTimeScale.build(
    Iterable<DateTime> dates,
    TrendGapThreshold threshold,
  ) {
    if (threshold == TrendGapThreshold.off) return identity;
    final ms = dates.map((d) => d.millisecondsSinceEpoch).toSet().toList()
      ..sort();
    if (ms.length < 2) return identity;

    final gaps = <(int, int)>[];
    for (var i = 1; i < ms.length; i++) {
      final limit = _addMonths(ms[i - 1], threshold.months);
      if (ms[i] > limit) gaps.add((ms[i - 1], ms[i]));
    }
    if (gaps.isEmpty) return identity;

    final gapTotal = gaps.fold<int>(0, (sum, g) => sum + g.$2 - g.$1);
    final collapsed = (ms.last - ms.first - gapTotal).toDouble();
    final band = math.max(collapsed * bandFraction, _minBandMs);

    final breaks = <TrendGapBreak>[];
    final shifts = <double>[0];
    var shift = 0.0;
    for (final (start, end) in gaps) {
      final axisStart = start - shift;
      breaks.add(
        TrendGapBreak(
          start: _date(start),
          end: _date(end),
          axisStart: axisStart,
          axisEnd: axisStart + band,
        ),
      );
      shift += (end - start) - band;
      shifts.add(shift);
    }
    return TrendTimeScale._(
      List.unmodifiable(breaks),
      List.unmodifiable(shifts),
    );
  }

  /// [ms] plus [months] calendar months, on the UTC calendar. Instants, not
  /// wall-clock fields, so a local and a UTC date for the same moment agree.
  static int _addMonths(int ms, int months) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    return DateTime.utc(
      d.year,
      d.month + months,
      d.day,
      d.hour,
      d.minute,
      d.second,
      d.millisecond,
    ).millisecondsSinceEpoch;
  }

  static DateTime _date(num ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true);

  /// The x position of [date].
  double toAxis(DateTime date) {
    final ms = date.millisecondsSinceEpoch.toDouble();
    for (var i = 0; i < breaks.length; i++) {
      final b = breaks[i];
      final start = b.start.millisecondsSinceEpoch;
      final end = b.end.millisecondsSinceEpoch;
      if (ms <= start) return ms - _shifts[i];
      if (ms < end) {
        return b.axisStart +
            (ms - start) / (end - start) * (b.axisEnd - b.axisStart);
      }
    }
    return ms - _shifts.last;
  }

  /// The date at x position [x], in UTC. Exact inside a period.
  DateTime toDate(double x) {
    for (var i = 0; i < breaks.length; i++) {
      final b = breaks[i];
      if (x <= b.axisStart) return _date(x + _shifts[i]);
      if (x < b.axisEnd) {
        final start = b.start.millisecondsSinceEpoch;
        final end = b.end.millisecondsSinceEpoch;
        return _date(
          start + (x - b.axisStart) / (b.axisEnd - b.axisStart) * (end - start),
        );
      }
    }
    return _date(x + _shifts.last);
  }

  /// The break whose band contains [x], or null.
  TrendGapBreak? breakAt(double x) {
    for (final b in breaks) {
      if (x > b.axisStart && x < b.axisEnd) return b;
    }
    return null;
  }

  /// Which period [date] belongs to: 0 before the first break, and one more
  /// for each break that ends at or before it.
  int periodOf(DateTime date) {
    final ms = date.millisecondsSinceEpoch;
    var i = 0;
    while (i < breaks.length && breaks[i].end.millisecondsSinceEpoch <= ms) {
      i++;
    }
    return i;
  }
}
```

- [ ] **Step 4: Run them and see them pass**

Run: `flutter test test/features/insights/domain/trend_time_scale_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights/domain/trend_time_scale.dart test/features/insights/domain/trend_time_scale_test.dart
git commit -m "feat(insights): add a gap-collapsing time scale for trend charts"
```

---

### Task 3: Rolling mean restarts at each break

**Files:**
- Modify: `lib/features/insights/domain/trend_aggregation.dart` (`rollingMean`, around line 137)
- Test: `test/features/insights/domain/trend_rolling_mean_breaks_test.dart`

**Interfaces:**
- Produces: `List<TrendDataPoint> rollingMean(List<TrendDataPoint> points, {int window = 21, int Function(DateTime date)? periodOf})`. With `periodOf` null, identical to today.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';

List<TrendDataPoint> run(DateTime from, int n, double value) => [
  for (var i = 0; i < n; i++)
    TrendDataPoint(date: from.add(Duration(days: i * 3)), value: value),
];

void main() {
  final before = run(DateTime.utc(2013, 1, 1), 30, 10);
  final after = run(DateTime.utc(2020, 1, 1), 30, 50);
  int periodOf(DateTime d) => d.year < 2020 ? 0 : 1;

  test('without periods the window mixes both sides of the gap', () {
    final smoothed = rollingMean([...before, ...after]);
    expect(smoothed[29].value, greaterThan(10));
    expect(smoothed[30].value, lessThan(50));
  });

  test('with periods no window reaches across the gap', () {
    final smoothed = rollingMean([...after, ...before], periodOf: periodOf);
    expect(smoothed, hasLength(60));
    for (final p in smoothed) {
      expect(p.value, p.date.year < 2020 ? 10 : 50);
    }
  });

  test('a short period averages only its own dives', () {
    final lone = TrendDataPoint(date: DateTime.utc(2020, 1, 1), value: 99);
    final smoothed = rollingMean([...before, lone], periodOf: periodOf);
    expect(smoothed.last.value, 99);
  });

  test('one period is the same as no periods', () {
    final a = rollingMean(before);
    final b = rollingMean(before, periodOf: (_) => 0);
    expect([for (final p in b) p.value], [for (final p in a) p.value]);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/features/insights/domain/trend_rolling_mean_breaks_test.dart`
Expected: compile error, no named parameter `periodOf`.

- [ ] **Step 3: Implement**

Replace `rollingMean` in `trend_aggregation.dart` with:

```dart
/// Centred mean over [window] neighbouring dives, ordered by date.
///
/// The window counts dives rather than calendar days on purpose. A time-based
/// window would compute some points from a liveaboard's forty dives and others
/// from none, so the line would be least stable exactly where the diving was
/// densest. At the ends the window truncates rather than padding.
///
/// [periodOf] numbers the periods between collapsed gaps (issue #3251); the
/// window never reaches into another period, so dives either side of a long
/// break are never averaged together. Null treats the series as one period.
///
/// Returns an empty list below [kMinTrendFitPoints].
List<TrendDataPoint> rollingMean(
  List<TrendDataPoint> points, {
  int window = 21,
  int Function(DateTime date)? periodOf,
}) {
  if (points.length < kMinTrendFitPoints) return const [];

  final ordered = [...points]..sort((a, b) => a.date.compareTo(b.date));
  final half = window ~/ 2;
  final period = periodOf == null
      ? null
      : [for (final p in ordered) periodOf(p.date)];

  return List<TrendDataPoint>.generate(ordered.length, (i) {
    var lo = (i - half) < 0 ? 0 : i - half;
    var hi = (i + half + 1) > ordered.length ? ordered.length : i + half + 1;
    if (period != null) {
      while (period[lo] != period[i]) {
        lo++;
      }
      while (period[hi - 1] != period[i]) {
        hi--;
      }
    }
    var sum = 0.0;
    for (var j = lo; j < hi; j++) {
      sum += ordered[j].value;
    }
    return TrendDataPoint(date: ordered[i].date, value: sum / (hi - lo));
  }, growable: false);
}
```

- [ ] **Step 4: Run it and the existing aggregation tests**

Run: `flutter test test/features/insights/domain/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights/domain/trend_aggregation.dart test/features/insights/domain/trend_rolling_mean_breaks_test.dart
git commit -m "feat(insights): restart the rolling average at each collapsed gap"
```

---

### Task 4: Range fractions and the window seater through the scale

**Files:**
- Modify: `lib/features/insights/domain/trend_range.dart` (`trendRangeFractions`)
- Modify: `lib/features/insights/presentation/widgets/trend_window_seater.dart`
- Test: `test/features/insights/domain/trend_range_scale_test.dart`
- Test: `test/features/insights/presentation/widgets/trend_window_seater_scale_test.dart`

**Interfaces:**
- Consumes: `TrendTimeScale` (Task 2).
- Produces:
  - `trendRangeFractions(TrendRange range, DateTime dataStart, DateTime dataEnd, {double Function(DateTime date)? toAxis})`
  - `TrendWindowSeater.seat(TrendRange range, ChartViewport current, double fullMin, double fullMax, {TrendTimeScale scale = TrendTimeScale.identity})`; `fullMin`/`fullMax` are axis positions. `report` turns positions back into dates with the scale last seated.

- [ ] **Step 1: Write the failing tests**

`test/features/insights/domain/trend_range_scale_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';

void main() {
  final first = DateTime.utc(2013, 1, 1);
  final gapStart = DateTime.utc(2014, 1, 1);
  final gapEnd = DateTime.utc(2020, 1, 1);
  final last = DateTime.utc(2021, 1, 1);
  final scale = TrendTimeScale.build(
    [first, DateTime.utc(2013, 7, 1), gapStart, gapEnd, DateTime.utc(2020, 7, 1), last],
    TrendGapThreshold.year1,
  );

  test('without toAxis the fractions are unchanged', () {
    final a = trendRangeFractions(const TrendRange.preset(TrendRangePreset.year1), first, last);
    final b = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.year1),
      first,
      last,
      toAxis: TrendTimeScale.identity.toAxis,
    );
    expect(b, a);
  });

  test('last year of a collapsed axis is about half of it', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.year1),
      first,
      last,
      toAxis: scale.toAxis,
    );
    // Two one-year periods and a 3% band: the last year starts just past the
    // middle, not at 7/8 as it would on the real-time axis.
    expect(f.start, closeTo(0.5, 0.03));
    expect(f.end, 1.0);
  });

  test('a preset that starts inside the gap opens inside the band', () {
    final f = trendRangeFractions(
      const TrendRange.preset(TrendRangePreset.years2),
      first,
      last,
      toAxis: scale.toAxis,
    );
    final b = scale.breaks.single;
    final full = scale.toAxis(last) - scale.toAxis(first);
    final startX = scale.toAxis(first) + f.start * full;
    expect(startX, greaterThan(b.axisStart));
    expect(startX, lessThan(b.axisEnd));
  });
}
```

`test/features/insights/presentation/widgets/trend_window_seater_scale_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_window_seater.dart';

void main() {
  final dates = [
    DateTime.utc(2013, 1, 1),
    DateTime.utc(2013, 7, 1),
    DateTime.utc(2014, 1, 1),
    DateTime.utc(2020, 1, 1),
    DateTime.utc(2020, 7, 1),
    DateTime.utc(2021, 1, 1),
  ];
  final collapsed = TrendTimeScale.build(dates, TrendGapThreshold.year1);
  const identity = TrendTimeScale.identity;

  ChartViewport seat(TrendWindowSeater s, TrendRange r, TrendTimeScale scale) =>
      s.seat(
        r,
        ChartViewport.reset,
        scale.toAxis(dates.first),
        scale.toAxis(dates.last),
        scale: scale,
      );

  test('a custom range reports back the same dates through a scale', () {
    final seater = TrendWindowSeater();
    final range = TrendRange.custom(DateTime.utc(2020, 2, 1), DateTime.utc(2020, 10, 1));
    final vp = seat(seater, range, collapsed);
    final moved = vp.pannedBy(0.0001, 0);
    final reported = seater.report(moved)!;
    expect(
      reported.start!.difference(range.start!).inDays.abs(),
      lessThanOrEqualTo(1),
    );
  });

  test('changing the threshold keeps a custom window on its dates', () {
    final seater = TrendWindowSeater();
    final range = TrendRange.custom(DateTime.utc(2020, 2, 1), DateTime.utc(2020, 10, 1));
    seat(seater, range, identity);
    final vp = seat(seater, range, collapsed);
    final full = collapsed.toAxis(dates.last) - collapsed.toAxis(dates.first);
    final shownStart = collapsed.toDate(
      collapsed.toAxis(dates.first) + vp.windowStart * full,
    );
    expect(shownStart.difference(range.start!).inHours.abs(), lessThan(24));
  });

  test('an identity scale seats exactly as before', () {
    final a = TrendWindowSeater().seat(
      const TrendRange.preset(TrendRangePreset.year1),
      ChartViewport.reset,
      identity.toAxis(dates.first),
      identity.toAxis(dates.last),
    );
    final b = seat(TrendWindowSeater(), const TrendRange.preset(TrendRangePreset.year1), identity);
    expect(b.sameWindowAs(a), isTrue);
  });
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/features/insights/domain/trend_range_scale_test.dart test/features/insights/presentation/widgets/trend_window_seater_scale_test.dart`
Expected: compile errors, no named parameters `toAxis` and `scale`.

- [ ] **Step 3: Implement**

In `trend_range.dart`, change `trendRangeFractions`:

```dart
/// The fraction window (0..1 of [dataStart]..[dataEnd]) that [range] shows.
///
/// A preset ends at [dataEnd]. A window that would start before the data
/// starts at the data, and a window with no overlap at all shows everything.
///
/// [toAxis] places a date on the chart's x axis; null is epoch milliseconds.
/// A chart that collapses long gaps (issue #3251) passes its scale's, so the
/// presets stay calendar-true while the fractions follow the drawn axis.
({double start, double end}) trendRangeFractions(
  TrendRange range,
  DateTime dataStart,
  DateTime dataEnd, {
  double Function(DateTime date)? toAxis,
}) {
  const everything = (start: 0.0, end: 1.0);
  final axis = toAxis ?? (DateTime d) => d.millisecondsSinceEpoch.toDouble();
  final origin = axis(dataStart);
  final full = axis(dataEnd) - origin;
  if (full <= 0) return everything;

  final DateTime from;
  final DateTime to;
  switch (range.preset) {
    case TrendRangePreset.all:
      return everything;
    case TrendRangePreset.custom:
      from = range.start!;
      to = range.end!;
    case TrendRangePreset.years5:
    case TrendRangePreset.years2:
    case TrendRangePreset.year1:
    case TrendRangePreset.months6:
    case TrendRangePreset.months3:
      to = dataEnd;
      from = _presetStart(range.preset, dataEnd);
  }

  double fraction(DateTime d) => ((axis(d) - origin) / full).clamp(0.0, 1.0);
  final start = fraction(from);
  final end = fraction(to);
  return end <= start ? everything : (start: start, end: end);
}
```

In `trend_window_seater.dart`:

1. Add `import 'package:submersion/features/insights/domain/trend_time_scale.dart';`.
2. Add a field below `_fullX`:

```dart
  /// The scale of the last [seat], for turning axis positions into dates.
  TrendTimeScale _scale = TrendTimeScale.identity;
```

3. Change `seat`'s signature and its window computation:

```dart
  /// The viewport to draw for [range] over data spanning [fullMin]..[fullMax]
  /// (axis positions under [scale]), given the [current] one.
  ///
  /// A new window only when the range or the data's span changed since the
  /// last seat; otherwise [current], with its zoom limit matched to the span.
  /// A threshold change that moves the collapsed span counts as a span
  /// change, so a custom window is re-seated on its own dates.
  ChartViewport seat(
    TrendRange range,
    ChartViewport current,
    double fullMin,
    double fullMax, {
    TrendTimeScale scale = TrendTimeScale.identity,
  }) {
```

and, after `_fullX = (min: fullMin, span: span);`, add `_scale = scale;`, then replace
`final window = trendRangeFractions(range, _date(fullMin), _date(fullMax));` with:

```dart
    final window = trendRangeFractions(
      range,
      scale.toDate(fullMin),
      scale.toDate(fullMax),
      toAxis: scale.toAxis,
    );
```

4. In `report`, replace the two `_date(...)` calls with `_scale.toDate(...)`:

```dart
    final next = viewport.isZoomed
        ? TrendRange.custom(
            _scale.toDate(full.min + viewport.windowStart * full.span),
            _scale.toDate(full.min + viewport.windowEnd * full.span),
          )
        : TrendRange.all;
```

5. Delete the now-unused `_date` helper if nothing else uses it (`flutter analyze` flags it).

- [ ] **Step 4: Run them and the existing range and seater tests**

Run: `flutter test test/features/insights/domain/ test/features/insights/presentation/widgets/trend_window_seater_scale_test.dart test/features/insights/presentation/widgets/dive_trend_chart_range_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights/domain/trend_range.dart lib/features/insights/presentation/widgets/trend_window_seater.dart test/features/insights/domain/trend_range_scale_test.dart test/features/insights/presentation/widgets/trend_window_seater_scale_test.dart
git commit -m "feat(insights): seat trend chart windows through the time scale"
```

---

### Task 5: `DateAxis` over a collapsed, width-aware axis

**Files:**
- Modify: `lib/features/insights/presentation/widgets/date_axis.dart`
- Test: `test/features/insights/presentation/widgets/date_axis_scale_test.dart`

**Interfaces:**
- Consumes: `TrendTimeScale` (Task 2).
- Produces:
  - `DateAxis.forAxisRange(double min, double max, {TrendTimeScale scale = TrendTimeScale.identity, double? plotWidth, DateFormatPreference dateFormat})`; `forRange(DateTime, DateTime, {dateFormat})` delegates to it with the identity scale and no width.
  - New fields `TrendTimeScale scale`, `double? axisPerPixel`.
  - `static const double breakLabelClearancePx = 36`.
  - `labelFor` returns null inside a band and within the clearance of one.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';
import 'package:submersion/features/insights/presentation/widgets/date_axis.dart';

double ms(DateTime d) => d.millisecondsSinceEpoch.toDouble();

void main() {
  setUpAll(() => Intl.defaultLocale = 'en');
  tearDownAll(() => Intl.defaultLocale = null);

  test('forRange is forAxisRange with the identity scale', () {
    final a = DateAxis.forRange(DateTime.utc(2013), DateTime.utc(2026));
    final b = DateAxis.forAxisRange(ms(DateTime.utc(2013)), ms(DateTime.utc(2026)));
    expect(b.min, a.min);
    expect(b.max, a.max);
    expect(b.labelInterval, a.labelInterval);
    expect(b.granularity, a.granularity);
  });

  test('a phone-width thirteen-year axis spaces labels at least 44px apart', () {
    final axis = DateAxis.forAxisRange(
      ms(DateTime.utc(2013)),
      ms(DateTime.utc(2026)),
      plotWidth: 300,
    );
    final px = axis.labelInterval / (axis.max - axis.min) * 300;
    expect(px, greaterThanOrEqualTo(44));
  });

  test('a wide axis keeps the tick-derived interval', () {
    final narrow = DateAxis.forAxisRange(ms(DateTime.utc(2013)), ms(DateTime.utc(2026)));
    final wide = DateAxis.forAxisRange(
      ms(DateTime.utc(2013)),
      ms(DateTime.utc(2026)),
      plotWidth: 4000,
    );
    expect(wide.labelInterval, narrow.labelInterval);
  });

  group('with a collapsed gap', () {
    final dates = [
      for (var m = 0; m < 18; m++) DateTime.utc(2013, 1 + m, 1),
      for (var m = 0; m < 6; m++) DateTime.utc(2021, 1 + m, 1),
    ];
    final scale = TrendTimeScale.build(dates, TrendGapThreshold.year1);
    final axis = DateAxis.forAxisRange(
      scale.toAxis(dates.first),
      scale.toAxis(dates.last),
      scale: scale,
      plotWidth: 600,
    );
    final b = scale.breaks.single;

    test('granularity follows the collapsed span, not the real one', () {
      // About two years of diving over eight calendar years.
      expect(axis.granularity, DateAxisGranularity.quarter);
    });

    test('no tick falls inside the gap', () {
      for (final t in axis.ticks) {
        expect(scale.breakAt(scale.toAxis(t)), isNull);
      }
    });

    test('no label inside the band or crowding it', () {
      final mid = (b.axisStart + b.axisEnd) / 2;
      expect(axis.labelFor(mid), isNull);
      final perPx = (axis.max - axis.min) / 600;
      expect(axis.labelFor(b.axisEnd + 10 * perPx), isNull);
      expect(axis.labelFor(b.axisStart - 10 * perPx), isNull);
    });

    test('a label after the gap reads its real date', () {
      final x = scale.toAxis(DateTime.utc(2021, 4, 1));
      expect(axis.labelFor(x), "Apr '21");
    });
  });
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/features/insights/presentation/widgets/date_axis_scale_test.dart`
Expected: compile error, no `forAxisRange`.

- [ ] **Step 3: Implement**

In `date_axis.dart`:

1. Add `import 'package:submersion/features/insights/domain/trend_time_scale.dart';`.
2. Add constructor params and fields:

```dart
  const DateAxis({
    required this.min,
    required this.max,
    required this.ticks,
    required this.granularity,
    required this.labelInterval,
    this.dateFormat = DateFormatPreference.mmmDYYYY,
    this.scale = TrendTimeScale.identity,
    this.axisPerPixel,
  });

  /// Maps axis positions back to dates; collapses long gaps (issue #3251).
  final TrendTimeScale scale;

  /// Axis units per pixel of plot, when the plot width is known. Lets a
  /// label keep clear of a break band by a pixel distance.
  final double? axisPerPixel;

  /// Pixels a date label keeps from a band, leaving room for the band's own
  /// length label under the axis.
  static const double breakLabelClearancePx = 36;

  /// Narrowest spacing, in pixels, between two labels of each granularity at
  /// the chart's bodySmall size: "2014" and "Mar '25" plus a gap.
  static const Map<DateAxisGranularity, double> _minLabelSpacingPx = {
    DateAxisGranularity.year: 44,
    DateAxisGranularity.quarter: 60,
    DateAxisGranularity.month: 60,
    DateAxisGranularity.day: 64,
  };
```

3. In `labelFor`, make the first line:

```dart
    if (!showsLabelAt(value) || _crowdsBreak(value)) return null;
```

and add:

```dart
  bool _crowdsBreak(double value) {
    final reach = (axisPerPixel ?? 0) * breakLabelClearancePx;
    for (final b in scale.breaks) {
      if (value > b.axisStart - reach && value < b.axisEnd + reach) {
        return true;
      }
    }
    return false;
  }
```

4. Replace `_dateOf` uses with `scale.toDate(value)` (make `_dateOf` an instance method: `DateTime _dateOf(double v) => scale.toDate(v);`).
5. Replace the `forRange` factory with:

```dart
  /// Chooses a granularity from the span, then walks ticks across it.
  ///
  /// A degenerate range (one dive, or several on one day) is widened to a day
  /// so fl_chart has a non-zero axis to draw.
  factory DateAxis.forRange(
    DateTime first,
    DateTime last, {
    DateFormatPreference dateFormat = DateFormatPreference.mmmDYYYY,
  }) => DateAxis.forAxisRange(
    first.millisecondsSinceEpoch.toDouble(),
    last.millisecondsSinceEpoch.toDouble(),
    dateFormat: dateFormat,
  );

  /// An axis over positions [min]..[max] under [scale].
  ///
  /// Granularity comes from the axis span, which for a collapsed scale is
  /// the time with dives in it, not the calendar span. With [plotWidth] the
  /// label step is widened until neighbouring labels cannot touch.
  factory DateAxis.forAxisRange(
    double min,
    double max, {
    TrendTimeScale scale = TrendTimeScale.identity,
    double? plotWidth,
    DateFormatPreference dateFormat = DateFormatPreference.mmmDYYYY,
  }) {
    final lo = min;
    final hi = max > min ? max : min + Duration.millisecondsPerDay;

    final days = (hi - lo) / Duration.millisecondsPerDay;
    final granularity = days > 1095
        ? DateAxisGranularity.year
        : days > 365
        ? DateAxisGranularity.quarter
        : days > 60
        ? DateAxisGranularity.month
        : DateAxisGranularity.day;

    final start = scale.toDate(lo);
    final end = scale.toDate(hi);
    var ticks = [
      for (final t in _ticksFor(start, end, granularity))
        if (scale.breakAt(scale.toAxis(t)) == null) t,
    ];
    if (ticks.isEmpty) ticks = [start];

    final steps = ticks.length > 1 ? ticks.length - 1 : 1;
    var interval = (hi - lo) / steps;
    final width = plotWidth;
    if (width != null && width > 0) {
      final minInterval = (hi - lo) * _minLabelSpacingPx[granularity]! / width;
      if (minInterval > interval) interval = minInterval;
    }

    return DateAxis(
      min: lo,
      max: hi,
      ticks: List.unmodifiable(ticks),
      granularity: granularity,
      labelInterval: interval,
      dateFormat: dateFormat,
      scale: scale,
      axisPerPixel: width != null && width > 0 ? (hi - lo) / width : null,
    );
  }
```

Note `days` is now fractional; the old code used `inDays` (whole days). Boundaries are `> 1095`, `> 365`, `> 60`, so a span of 365.5 days now reads quarter where it read month. Keep the existing tests green; if one asserts a span just over a boundary, compare `days.floor()` instead (`final days = ((hi - lo) / Duration.millisecondsPerDay).floor();`).

- [ ] **Step 4: Run the new and existing axis tests**

Run: `flutter test test/features/insights/presentation/widgets/date_axis_scale_test.dart test/features/insights/presentation/widgets/date_axis_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights/presentation/widgets/date_axis.dart test/features/insights/presentation/widgets/date_axis_scale_test.dart
git commit -m "feat(insights): thin date labels by width and keep them off gap bands"
```

---

### Task 6: Strings and label formatters

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart` (`flutter gen-l10n`)
- Create: `lib/features/insights/presentation/formatters/trend_gap_label.dart`
- Test: `test/features/insights/presentation/formatters/trend_gap_label_test.dart`

**Interfaces:**
- Consumes: `TrendGapThreshold` (Task 1).
- Produces:
  - l10n getters `insights_trend_gaps_menuHeader`, `insights_trend_gaps_off`, `insights_trend_gaps_months6`, `insights_trend_gaps_year1`, `insights_trend_gaps_years2`, `settings_appearance_trendGaps`, `settings_appearance_trendGaps_subtitle`, `settings_conflict_field_trendGapCollapseMonths`; methods `insights_trend_gap_years(int years)`, `insights_trend_gap_months(int months)`, `insights_trend_gap_yearsMonths(int years, int months)`, `insights_trend_gap_noDives(String start, String end)`.
  - `String trendGapThresholdLabel(TrendGapThreshold t, AppLocalizations l10n)`
  - `int calendarMonthsBetween(DateTime start, DateTime end)`
  - `String trendGapLengthLabel(DateTime start, DateTime end, AppLocalizations l10n)`

- [ ] **Step 1: Add the strings**

English values (placeholder maps list `years` before `months`, which fixes the generated argument order):

```json
  "insights_trend_gaps_menuHeader": "Collapse gaps",
  "insights_trend_gaps_off": "Off",
  "insights_trend_gaps_months6": "6 months",
  "insights_trend_gaps_year1": "1 year",
  "insights_trend_gaps_years2": "2 years",
  "insights_trend_gap_years": "{years}y",
  "@insights_trend_gap_years": {
    "description": "Length of a collapsed break in diving on a trend chart axis, whole years only",
    "placeholders": {"years": {"type": "int"}}
  },
  "insights_trend_gap_months": "{months}m",
  "@insights_trend_gap_months": {
    "description": "Length of a collapsed break in diving, under a year",
    "placeholders": {"months": {"type": "int"}}
  },
  "insights_trend_gap_yearsMonths": "{years}y {months}m",
  "@insights_trend_gap_yearsMonths": {
    "description": "Length of a collapsed break in diving, years and months",
    "placeholders": {"years": {"type": "int"}, "months": {"type": "int"}}
  },
  "insights_trend_gap_noDives": "No dives: {start} to {end}",
  "@insights_trend_gap_noDives": {
    "description": "Chart readout when hovering a collapsed break; start and end are formatted dates",
    "placeholders": {"start": {"type": "String"}, "end": {"type": "String"}}
  },
  "settings_appearance_trendGaps": "Collapse gaps in trend charts",
  "settings_appearance_trendGaps_subtitle": "Show long breaks in diving as a narrow hatched band",
  "settings_conflict_field_trendGapCollapseMonths": "Collapse gaps in trend charts",
```

Translations, in key order menuHeader, off, months6, year1, years2, years, months, yearsMonths, noDives, settings title, settings subtitle (the conflict label repeats the settings title):

| Locale | Values |
| --- | --- |
| de | Lücken zusammenfassen; Aus; 6 Monate; 1 Jahr; 2 Jahre; `{years} J`; `{months} M`; `{years} J {months} M`; `Keine Tauchgänge: {start} bis {end}`; Lücken in Trenddiagrammen zusammenfassen; Lange Tauchpausen als schmales schraffiertes Band anzeigen |
| es | Contraer pausas; Desactivado; 6 meses; 1 año; 2 años; `{years} a`; `{months} m`; `{years} a {months} m`; `Sin inmersiones: {start} a {end}`; Contraer pausas en los gráficos de tendencia; Mostrar las pausas largas sin bucear como una banda rayada estrecha |
| fr | Réduire les pauses; Désactivé; 6 mois; 1 an; 2 ans; `{years} a`; `{months} m`; `{years} a {months} m`; `Aucune plongée : du {start} au {end}`; Réduire les pauses dans les graphiques de tendance; Afficher les longues pauses sans plongée comme une bande hachurée étroite |
| it | Comprimi le pause; Disattivato; 6 mesi; 1 anno; 2 anni; `{years} a`; `{months} m`; `{years} a {months} m`; `Nessuna immersione: dal {start} al {end}`; Comprimi le pause nei grafici di tendenza; Mostra le lunghe pause senza immersioni come una banda tratteggiata stretta |
| nl | Pauzes inkorten; Uit; 6 maanden; 1 jaar; 2 jaar; `{years} j`; `{months} m`; `{years} j {months} m`; `Geen duiken: {start} tot {end}`; Pauzes in trendgrafieken inkorten; Lange duikpauzes tonen als een smalle gearceerde band |
| pt | Recolher pausas; Desativado; 6 meses; 1 ano; 2 anos; `{years} a`; `{months} m`; `{years} a {months} m`; `Sem mergulhos: {start} a {end}`; Recolher pausas nos gráficos de tendência; Mostrar longas pausas sem mergulho como uma faixa tracejada estreita |
| hu | Szünetek összevonása; Ki; 6 hónap; 1 év; 2 év; `{years} év`; `{months} hó`; `{years} év {months} hó`; `Nincs merülés {start} és {end} között`; Szünetek összevonása a trenddiagramokon; A hosszú merülési szüneteket keskeny, sraffozott sávként mutatja |
| ar | طي الفجوات; إيقاف; 6 أشهر; سنة واحدة; سنتان; `{years} س`; `{months} ش`; `{years} س {months} ش`; `لا غطسات: من {start} إلى {end}`; طي الفجوات في مخططات الاتجاه; عرض فترات الانقطاع الطويلة عن الغوص كشريط مخطط ضيق |
| he | כיווץ פערים; כבוי; 6 חודשים; שנה; שנתיים; `{years} ש׳`; `{months} ח׳`; `{years} ש׳ {months} ח׳`; `אין צלילות: {start} עד {end}`; כיווץ פערים בתרשימי מגמה; הצגת הפסקות ארוכות בצלילה כרצועה מקווקוות צרה |
| zh | 折叠间隔; 关闭; 6 个月; 1 年; 2 年; `{years}年`; `{months}个月`; `{years}年{months}个月`; `无潜水：{start} 至 {end}`; 在趋势图中折叠间隔; 将长时间未潜水的时段显示为窄的斜线带 |

Insert with a python3.14 script, never by hand, because the ARBs are feature-grouped and several are CRLF. For each file: insert the `insights_trend_gap*` keys before the line holding `"insights_trend_legend_rate"`, the two `settings_appearance_trendGaps*` keys before `"settings_appearance_mapStyle"`, and the conflict key before `"settings_conflict_field_tripServiceLeadDays"`, matching that line's indentation and line ending. The `@` metadata blocks go in `app_en.arb` only. Write the script to the scratchpad and run it with the ARB directory as its argument. Afterwards check `git diff --numstat lib/l10n/arb/*.arb` shows only additions.

- [ ] **Step 2: Regenerate and check**

Run: `flutter gen-l10n && flutter analyze lib/l10n`
Expected: no issues.

- [ ] **Step 3: Write the failing formatter test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/presentation/formatters/trend_gap_label.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';

void main() {
  final en = AppLocalizationsEn();

  test('names every threshold', () {
    expect(trendGapThresholdLabel(TrendGapThreshold.off, en), 'Off');
    expect(trendGapThresholdLabel(TrendGapThreshold.months6, en), '6 months');
    expect(trendGapThresholdLabel(TrendGapThreshold.year1, en), '1 year');
    expect(trendGapThresholdLabel(TrendGapThreshold.years2, en), '2 years');
  });

  test('counts whole calendar months', () {
    expect(calendarMonthsBetween(DateTime.utc(2018, 6, 10), DateTime.utc(2025, 3, 20)), 81);
    expect(calendarMonthsBetween(DateTime.utc(2018, 6, 20), DateTime.utc(2025, 3, 10)), 80);
    expect(calendarMonthsBetween(DateTime.utc(2020, 1, 1), DateTime.utc(2020, 1, 1)), 0);
  });

  test('years and months render in that order', () {
    expect(trendGapLengthLabel(DateTime.utc(2018, 6, 1), DateTime.utc(2025, 3, 1), en), '6y 9m');
    expect(
      trendGapLengthLabel(DateTime.utc(2018, 6, 1), DateTime.utc(2025, 3, 1), AppLocalizationsDe()),
      '6 J 9 M',
    );
  });

  test('whole years and short gaps drop the empty part', () {
    expect(trendGapLengthLabel(DateTime.utc(2018, 6, 1), DateTime.utc(2021, 6, 1), en), '3y');
    expect(trendGapLengthLabel(DateTime.utc(2020, 1, 1), DateTime.utc(2020, 8, 1), en), '7m');
  });
}
```

- [ ] **Step 4: Run it and see it fail**

Run: `flutter test test/features/insights/presentation/formatters/trend_gap_label_test.dart`
Expected: compile error, `trend_gap_label.dart` not found.

- [ ] **Step 5: Implement**

```dart
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The threshold's name in the Range menu and the Settings picker.
String trendGapThresholdLabel(TrendGapThreshold t, AppLocalizations l10n) =>
    switch (t) {
      TrendGapThreshold.off => l10n.insights_trend_gaps_off,
      TrendGapThreshold.months6 => l10n.insights_trend_gaps_months6,
      TrendGapThreshold.year1 => l10n.insights_trend_gaps_year1,
      TrendGapThreshold.years2 => l10n.insights_trend_gaps_years2,
    };

/// Whole calendar months from [start] to [end], ignoring time of day.
int calendarMonthsBetween(DateTime start, DateTime end) {
  var months = (end.year - start.year) * 12 + end.month - start.month;
  if (end.day < start.day) months--;
  return months < 0 ? 0 : months;
}

/// A collapsed break's length for the label under its band: "6y 9m", or
/// "3y" or "7m" when one part is zero.
String trendGapLengthLabel(
  DateTime start,
  DateTime end,
  AppLocalizations l10n,
) {
  final total = calendarMonthsBetween(start, end);
  final years = total ~/ 12;
  final months = total % 12;
  if (years == 0) return l10n.insights_trend_gap_months(months);
  if (months == 0) return l10n.insights_trend_gap_years(years);
  return l10n.insights_trend_gap_yearsMonths(years, months);
}
```

If the generated `insights_trend_gap_yearsMonths` takes `(months, years)`, the placeholder map order in `app_en.arb` is wrong: fix the map, not the call, and re-run gen-l10n.

- [ ] **Step 6: Run it and the l10n tests**

Run: `flutter test test/features/insights/presentation/formatters/trend_gap_label_test.dart test/l10n/`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/arb lib/features/insights/presentation/formatters/trend_gap_label.dart test/features/insights/presentation/formatters/trend_gap_label_test.dart
git commit -m "feat(insights): add strings for collapsed gaps in trend charts"
```

---

### Task 7: The synced setting

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (after `tripServiceLeadDays`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion`, `migrationVersions`)
- Modify: `lib/core/database/migrations/helpers/diver_migrations.dart` (new helper at the end)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v277 block)
- Modify: `lib/core/database/migrations/before_open.dart` (after the v276 backstop)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (diver settings defaults, after `'tripServiceLeadDays': 14,`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (three sites beside `tripServiceLeadDays`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`
- Modify: `lib/features/settings/presentation/conflicts/conflict_enum_labels_settings.dart`
- Modify: every `implements SettingsNotifier` test double that `flutter analyze` flags (at least `test/helpers/mock_providers.dart`)
- Test: `test/core/database/migration_v278_trend_gap_collapse_test.dart`
- Test: `test/core/services/sync/sync_diver_settings_trend_gap_test.dart`
- Test: `test/features/settings/data/repositories/diver_settings_repository_trend_gap_test.dart`

**Interfaces:**
- Consumes: `TrendGapThreshold` (Task 1), `trendGapThresholdLabel` (Task 6).
- Produces: column `trend_gap_collapse_months` (Drift field `trendGapCollapseMonths`), `AppSettings.trendGapThreshold` (`TrendGapThreshold`, default `year1`), `SettingsNotifier.setTrendGapThreshold(TrendGapThreshold value)`, `final trendGapThresholdProvider = Provider<TrendGapThreshold>(...)`, `final ConflictEnumLabeler trendGapThresholdLabeler`.

- [ ] **Step 1: Write the failing tests**

`test/core/database/migration_v278_trend_gap_collapse_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v278: diver_settings.trend_gap_collapse_months (issue #3251).
void main() {
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 277');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v278 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(278));
    expect(AppDatabase.migrationVersions, contains(278));
    expect(
      AppDatabase.migrationStepCount(277),
      AppDatabase.migrationStepCount(278) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(278));
  });

  test('upgrading from v277 gives every diver a one-year threshold', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final rows = await db
        .customSelect(
          'SELECT trend_gap_collapse_months AS v FROM diver_settings',
        )
        .get();
    expect(rows.single.read<int>('v'), 12);
  });
}
```

`test/core/services/sync/sync_diver_settings_trend_gap_test.dart`: copy `sync_diver_settings_late_gas_switch_test.dart` with ids `ds-tg` / `diver-tg`, the key `trendGapCollapseMonths`, the exported value `12`, and the final assertion `expect(row.trendGapCollapseMonths, 12);`. Name the test `applies a pre-v278 payload missing the trend gap threshold`.

`test/features/settings/data/repositories/diver_settings_repository_trend_gap_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('the threshold defaults to a year and copyWith carries it', () {
    const settings = AppSettings();
    expect(settings.trendGapThreshold, TrendGapThreshold.year1);
    expect(
      settings.copyWith(trendGapThreshold: TrendGapThreshold.off).trendGapThreshold,
      TrendGapThreshold.off,
    );
  });

  group('DiverSettingsRepository trend gap persistence', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: 'd1', name: 'Test Diver', createdAt: now, updatedAt: now),
      );
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('new settings start at one year', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.trendGapThreshold, TrendGapThreshold.year1);
    });

    test('every choice round-trips', () async {
      await repository.createSettingsForDiver('d1');
      for (final t in TrendGapThreshold.values) {
        await repository.updateSettingsForDiver('d1', AppSettings(trendGapThreshold: t));
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.trendGapThreshold, t);
      }
    });

    test('an out-of-range stored value reads as one year', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        "UPDATE diver_settings SET trend_gap_collapse_months = 7 WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.trendGapThreshold, TrendGapThreshold.year1);
    });
  });
}
```

Add to the same repository test file a conflict-labeler test:

```dart
  test('the conflict labeler names a stored month count', () {
    final en = AppLocalizationsEn();
    expect(trendGapThresholdLabeler(en, '24'), '2 years');
    expect(trendGapThresholdLabeler(en, '7'), isNull);
  });
```

(imports: `package:submersion/l10n/arb/app_localizations_en.dart` and `package:submersion/features/settings/presentation/conflicts/conflict_enum_labels_settings.dart`).

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/core/database/migration_v278_trend_gap_collapse_test.dart test/features/settings/data/repositories/diver_settings_repository_trend_gap_test.dart`
Expected: compile errors (`trendGapThreshold` undefined) and the migration expectations fail.

- [ ] **Step 3: Implement the column and the rung**

`diver_tables.dart`, directly after the `tripServiceLeadDays` column:

```dart
  // v278: calendar months a stretch with no dives must exceed before the
  // trend charts collapse it into a break (issue #3251); 0 is off. Any
  // other value reads as 12. Codegen input, never executed.
  // coverage:ignore-start
  IntColumn get trendGapCollapseMonths =>
      integer().withDefault(const Constant(12))();
  // coverage:ignore-end
```

`database.dart`: `static const int currentSchemaVersion = 278;` and, after the `277,` entry of `migrationVersions`:

```dart
    // v278: diver_settings.trend_gap_collapse_months (issue #3251). Additive
    // defaulted column, so the floor stays.
    278,
```

`diver_migrations.dart`, appended inside the extension:

```dart

  /// v278: diver_settings.trend_gap_collapse_months (issue #3251). Column
  /// only, defaulting to a year; re-asserted in beforeOpen. No CHECK: a peer
  /// value outside 0, 6, 12, 24 reads as 12 rather than failing the upsert.
  Future<void> _assertTrendGapCollapseColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('trend_gap_collapse_months')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN trend_gap_collapse_months '
        'INTEGER NOT NULL DEFAULT 12',
      );
    }
  }
```

`rungs_v231_onward.dart`, after `if (from < 277) await reportProgress();`:

```dart
    // v278: diver_settings.trend_gap_collapse_months (issue #3251). Column
    // only, defaulting to a year; re-asserted in beforeOpen.
    if (from < 278) {
      await _assertTrendGapCollapseColumn();
    }
    if (from < 278) await reportProgress();
```

`before_open.dart`, after `await _assertIcdWarningsColumn();`:

```dart
    // v278 backstop: diver_settings.trend_gap_collapse_months.
    await _assertTrendGapCollapseColumn();
```

Then: `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Implement sync, repository, settings, conflicts**

`sync_data_serializer.dart`, after `'tripServiceLeadDays': 14,`:

```dart
      // v278: seed it so payloads predating the column hydrate instead of
      // throwing in DiverSetting.fromJson (issue #3251).
      'trendGapCollapseMonths': 12,
```

`diver_settings_repository.dart`: at each of the two companion sites beside `tripServiceLeadDays`, add `trendGapCollapseMonths: Value(s.trendGapThreshold.months),` (the first site's variable is `s`, the second's is `settings`); at the row-mapping site add `trendGapThreshold: TrendGapThreshold.fromMonths(row.trendGapCollapseMonths),`. Import `package:submersion/features/insights/domain/trend_gap_threshold.dart`.

`settings_providers.dart` (import the threshold type):
- field, beside `insightsMutedObservationRules`:

```dart
  /// Stretches with no dives longer than this collapse into a break on the
  /// trend charts (issue #3251).
  final TrendGapThreshold trendGapThreshold;
```

- constructor default `this.trendGapThreshold = TrendGapThreshold.year1,`
- `copyWith` param `TrendGapThreshold? trendGapThreshold,` and `trendGapThreshold: trendGapThreshold ?? this.trendGapThreshold,`
- notifier setter, beside `setIcdWarningsEnabled`:

```dart
  Future<void> setTrendGapThreshold(TrendGapThreshold value) async {
    state = state.copyWith(trendGapThreshold: value);
    await _saveSettings();
  }
```

- provider, beside `defaultShowLateGasSwitchesProvider`:

```dart
/// The active diver's gap threshold for every `DiveTrendChart`.
final trendGapThresholdProvider = Provider<TrendGapThreshold>((ref) {
  return ref.watch(settingsProvider.select((s) => s.trendGapThreshold));
});
```

`conflict_enum_labels_settings.dart` (import the threshold type and `trend_gap_label.dart`):

```dart
final ConflictEnumLabeler trendGapThresholdLabeler = enumLabeler(
  TrendGapThreshold.values,
  (l, v) => trendGapThresholdLabel(v, l),
  storedAs: (v) => '${v.months}',
);
```

`diver_settings_fields.dart`, in key order (after `'tripServiceLeadDays'`):

```dart
  'trendGapCollapseMonths': ConflictField(
    (l) => l.settings_conflict_field_trendGapCollapseMonths,
    FieldKind.enumValue,
    enumLabel: trendGapThresholdLabeler,
  ),
```

- [ ] **Step 5: Fix the test doubles**

Run: `flutter analyze`
For each `implements SettingsNotifier` double reported as missing `setTrendGapThreshold`, add:

```dart
  @override
  Future<void> setTrendGapThreshold(TrendGapThreshold value) async =>
      state = state.copyWith(trendGapThreshold: value);
```

with the threshold import. Re-run until analyze is clean.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/core/database/migration_v278_trend_gap_collapse_test.dart test/core/services/sync/sync_diver_settings_trend_gap_test.dart test/features/settings/data/repositories/diver_settings_repository_trend_gap_test.dart test/core/database/ test/features/settings/presentation/conflicts/`
Expected: all pass. A catalogue-completeness test in `test/features/settings/presentation/conflicts/` failing on the new column means Step 4's catalogue entry is missing or misnamed.

- [ ] **Step 7: Commit**

```bash
git add lib/core lib/features/settings test/core test/features/settings test/helpers
git commit -m "feat(settings): persist and sync the trend chart gap threshold"
```

Check `git show --stat HEAD` lists the generated `.g.dart` changes for the new column.

---

### Task 8: `DiveTrendChart` plots through the scale

**Files:**
- Modify: `lib/features/insights/presentation/widgets/dive_trend_chart.dart`
- Create: `lib/features/insights/presentation/widgets/trend_break_spots.dart` (the null-spot helpers, keeping the chart file under 800 lines)
- Test: `test/features/insights/presentation/widgets/dive_trend_chart_gaps_test.dart`

**Interfaces:**
- Consumes: `TrendTimeScale` (Task 2), `rollingMean(periodOf:)` (Task 3), `seat(scale:)` (Task 4), `DateAxis.forAxisRange` (Task 5), `trendGapLengthLabel`, `insights_trend_gap_noDives` (Task 6), `TrendGapThreshold` (Task 1).
- Produces: `DiveTrendChart({..., TrendGapThreshold gapThreshold = TrendGapThreshold.off})`; in `trend_break_spots.dart`:
  - `({List<FlSpot> spots, List<int?> source}) spotsAcrossBreaks<T>(List<T> items, DateTime Function(T) dateOf, double Function(T) valueOf, TrendTimeScale scale)`: one spot per item at `scale.toAxis`, with an `FlSpot.nullSpot` between consecutive items in different periods; `source[i]` is the item index behind spot `i`, null for a null spot.
  - `List<FlSpot> fitAcrossBreaks(LinearFit fit, List<DateTime> dates, TrendTimeScale scale)`: for each period, a segment from its first to its last date, segments separated by `FlSpot.nullSpot`.

- [ ] **Step 1: Write the failing widget tests**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 600, child: child)),
);

LineChartData readData(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

List<TrendDataPoint> run(DateTime from, int n, String prefix) => [
  for (var i = 0; i < n; i++)
    TrendDataPoint(
      date: from.add(Duration(days: i * 9)),
      value: 10.0 + i % 5,
      diveId: '$prefix$i',
    ),
];

void main() {
  final before = run(DateTime.utc(2013, 1, 1), 40, 'a');
  final after = run(DateTime.utc(2020, 1, 1), 20, 'b');
  final points = [...before, ...after];

  testWidgets('Off plots epoch milliseconds exactly as before', (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(points: points)));
    final spots = readData(tester).lineBarsData.first.spots;
    expect(spots.last.x, after.last.date.millisecondsSinceEpoch.toDouble());
  });

  testWidgets('a year threshold pulls the later dives left', (tester) async {
    await tester.pumpWidget(
      host(DiveTrendChart(points: points, gapThreshold: TrendGapThreshold.year1)),
    );
    final data = readData(tester);
    final real = after.last.date.millisecondsSinceEpoch.toDouble();
    expect(data.maxX, lessThan(real));
    // The first dive after the break sits a band (3%) past the last before.
    final firstAfter = data.lineBarsData.first.spots
        .firstWhere((s) => !s.isNull() && s.y >= 0 && s.x > before.last.date.millisecondsSinceEpoch);
    expect(firstAfter.x - before.last.date.millisecondsSinceEpoch, lessThan(Duration.millisecondsPerDay * 30));
  });

  testWidgets('the rolling average breaks at the gap', (tester) async {
    await tester.pumpWidget(
      host(DiveTrendChart(
        points: points,
        showRollingMean: true,
        gapThreshold: TrendGapThreshold.year1,
      )),
    );
    final rolling = readData(tester).lineBarsData[1].spots;
    expect(rolling.where((s) => s.isNull()), hasLength(1));
  });

  testWidgets('the fit is drawn in one piece per period', (tester) async {
    await tester.pumpWidget(
      host(DiveTrendChart(
        points: points,
        showLinearFit: true,
        gapThreshold: TrendGapThreshold.year1,
      )),
    );
    final fit = readData(tester).lineBarsData[1].spots;
    expect(fit, hasLength(5)); // two segments and the null between
    expect(fit[2].isNull(), isTrue);
  });

  testWidgets('aggregated buckets after a break open their own dive', (tester) async {
    final opened = <String>[];
    // One dive per month either side of the gap: each monthly bucket holds
    // exactly one dive, so each is openable.
    final monthly = [
      for (var m = 0; m < 6; m++)
        TrendDataPoint(date: DateTime.utc(2013, 1 + m, 15), value: 10, diveId: 'a$m'),
      for (var m = 0; m < 6; m++)
        TrendDataPoint(date: DateTime.utc(2020, 1 + m, 15), value: 20, diveId: 'b$m'),
    ];
    await tester.pumpWidget(
      host(DiveTrendChart(
        points: monthly,
        aggregation: TrendAggregation.monthly,
        gapThreshold: TrendGapThreshold.year1,
        onDiveSelected: opened.add,
      )),
    );
    final bar = readData(tester).lineBarsData.first;
    final nullAt = bar.spots.indexWhere((s) => s.isNull());
    expect(nullAt, 6);
    final state = tester.state(find.byType(DiveTrendChart)) as dynamic;
    expect(state.debugDiveIdForSpot(0, 7), 'b0');
    expect(state.debugDiveIdForSpot(0, 6), isNull);
  });

  testWidgets('two dives years apart still draw', (tester) async {
    await tester.pumpWidget(
      host(DiveTrendChart(
        points: [
          TrendDataPoint(date: DateTime.utc(2015, 5, 1), value: 10),
          TrendDataPoint(date: DateTime.utc(2019, 5, 1), value: 20),
        ],
        gapThreshold: TrendGapThreshold.year1,
      )),
    );
    final data = readData(tester);
    expect(data.maxX - data.minX, Duration.millisecondsPerDay.toDouble());
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chart drawn only from secondary series collapses their gap', (tester) async {
    await tester.pumpWidget(
      host(DiveTrendChart(
        points: const [],
        secondarySeries: [
          TrendSeries(label: 'A', points: before, color: Colors.red),
          TrendSeries(label: 'B', points: after, color: Colors.blue),
        ],
        gapThreshold: TrendGapThreshold.year1,
      )),
    );
    final data = readData(tester);
    expect(data.maxX, lessThan(after.last.date.millisecondsSinceEpoch.toDouble()));
  });
}
```

`debugDiveIdForSpot(int barIndex, int spotIndex)` is a `@visibleForTesting` method on the chart state that runs the same lookup the tap handler uses; adding it keeps the tap test free of pixel-hunting.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/features/insights/presentation/widgets/dive_trend_chart_gaps_test.dart`
Expected: compile error, no named parameter `gapThreshold`.

- [ ] **Step 3: Implement the helpers**

`trend_break_spots.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';

import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';

/// One spot per item, placed through [scale], with a null spot wherever two
/// neighbours sit in different periods so fl_chart lifts the pen across the
/// gap (issue #3251). [items] must be in date order.
///
/// `source[i]` is the index into [items] behind spot `i`, null for a null
/// spot, so a tap's spot index can be mapped back to its item.
({List<FlSpot> spots, List<int?> source}) spotsAcrossBreaks<T>(
  List<T> items,
  DateTime Function(T item) dateOf,
  double Function(T item) valueOf,
  TrendTimeScale scale,
) {
  final spots = <FlSpot>[];
  final source = <int?>[];
  int? lastPeriod;
  for (var i = 0; i < items.length; i++) {
    final date = dateOf(items[i]);
    final period = scale.isIdentity ? 0 : scale.periodOf(date);
    if (lastPeriod != null && period != lastPeriod) {
      spots.add(FlSpot.nullSpot);
      source.add(null);
    }
    lastPeriod = period;
    spots.add(FlSpot(scale.toAxis(date), valueOf(items[i])));
    source.add(i);
  }
  return (
    spots: List.unmodifiable(spots),
    source: List.unmodifiable(source),
  );
}

/// The fitted line drawn only across the periods with dives: one segment per
/// period, from its first to its last date in [dates] (date order), each
/// evaluated on the one fit so the rate is unchanged.
List<FlSpot> fitAcrossBreaks(
  LinearFit fit,
  List<DateTime> dates,
  TrendTimeScale scale,
) {
  if (dates.isEmpty) return const [];
  final spots = <FlSpot>[];
  var segmentStart = dates.first;
  var previous = dates.first;
  void close() {
    if (spots.isNotEmpty) spots.add(FlSpot.nullSpot);
    spots
      ..add(FlSpot(scale.toAxis(segmentStart), fit.valueAt(segmentStart)))
      ..add(FlSpot(scale.toAxis(previous), fit.valueAt(previous)));
  }

  for (final d in dates.skip(1)) {
    if (scale.periodOf(d) != scale.periodOf(previous)) {
      close();
      segmentStart = d;
    }
    previous = d;
  }
  close();
  return spots;
}
```

- [ ] **Step 4: Wire the chart**

In `dive_trend_chart.dart`:

1. Imports: `trend_gap_threshold.dart`, `trend_time_scale.dart`, `trend_break_spots.dart`, `trend_gap_label.dart`.
2. Constructor param `this.gapThreshold = TrendGapThreshold.off,` and field:

```dart
  /// Stretches with no dives longer than this collapse into a hatched band
  /// (issue #3251). Callers pass the diver's `trendGapThresholdProvider`.
  final TrendGapThreshold gapThreshold;
```

3. State fields:

```dart
  /// The x scale as last built, and what it was built from.
  TrendTimeScale _scale = TrendTimeScale.identity;
  Object? _scaleKey;

  /// Bucket index behind each drawn spot of the primary and each secondary
  /// data bar; null at a break's null spot.
  List<int?> _drawnSource = const [];
  List<List<int?>> _drawnSecondarySource = const [];

  /// Axis position of the pointer over the plot, from the touch callback,
  /// so the readout can tell a hover over a band from one over the data.
  double? _pointerAxisX;
```

4. Remove `static double _x(DateTime date)`; replace every `_x(...)` with `_scale.toAxis(...)`.
5. In `_buildChart`, right after `allBuckets` is built and before `firstDate`:

```dart
    final scaleKey = (
      points,
      widget.secondarySeries,
      aggregation,
      widget.gapThreshold,
    );
    if (scaleKey != _scaleKey) {
      _scaleKey = scaleKey;
      _scale = TrendTimeScale.build([
        for (final b in allBuckets) b.date,
        for (final p in points) p.date,
        for (final s in widget.secondarySeries)
          for (final p in s.points) p.date,
      ], widget.gapThreshold);
    }
```

6. The seat call becomes `_seater.seat(widget.range, _viewport, fullMin, fullMax, scale: _scale);`.
7. The date axis becomes:

```dart
    final dateAxis = DateAxis.forAxisRange(
      visibleMin,
      visibleMax,
      scale: _scale,
      plotWidth: plotWidth,
      dateFormat: widget.dateFormat,
    );
```

where `plotWidth` is a new `_buildChart(BuildContext context, double plotWidth)` parameter, passed from `_interactiveChart` as `box.width - trendChartPlotInsets.left - _yAxisNameSize - trendChartPlotInsets.right`.
8. Rolling mean: `rollingMean(points, periodOf: _scale.isIdentity ? null : _scale.periodOf)`.
9. In `_bars`: the data bar, min and max bars, the rolling bar and secondary bars build their spots with `spotsAcrossBreaks` (buckets with `(b) => b.date`, values `b.mean` / `b.min` / `b.max`; rolling with `(p) => p.date`, `(p) => p.value`), recording `_drawnSource` for the primary data bar and `_drawnSecondarySource[i]` for each secondary. The fit bar's spots become `fitAcrossBreaks(fit, [for (final b in buckets) b.date], _scale)`.
10. Tap mapping: extract the lookup from `touchCallback` into

```dart
  /// The dive behind spot [spotIndex] of bar [barIndex], or null for a
  /// null spot, an overlay bar or a bucket of several dives.
  @visibleForTesting
  String? debugDiveIdForSpot(int barIndex, int spotIndex) =>
      _diveIdForSpot(barIndex, spotIndex);

  String? _diveIdForSpot(int barIndex, int spotIndex) {
    final List<TrendBucket> drawn;
    final List<int?> source;
    if (barIndex == 0) {
      drawn = _drawnBuckets;
      source = _drawnSource;
    } else if (_secondaryBarStart >= 0 &&
        barIndex >= _secondaryBarStart &&
        barIndex - _secondaryBarStart < _drawnSecondary.length) {
      drawn = _drawnSecondary[barIndex - _secondaryBarStart];
      source = _drawnSecondarySource[barIndex - _secondaryBarStart];
    } else {
      return null;
    }
    if (spotIndex < 0 || spotIndex >= source.length) return null;
    final bucket = source[spotIndex];
    return bucket == null ? null : drawn[bucket].diveId;
  }
```

and make `touchCallback` record the pointer and call it:

```dart
      touchCallback: (event, response) {
        _pointerAxisX = response?.touchChartCoordinate.dx;
        if (event is! FlTapUpEvent) return;
        final onDiveSelected = widget.onDiveSelected;
        if (onDiveSelected == null) return;
        if (_pointerAxisX != null && _scale.breakAt(_pointerAxisX!) != null) {
          return;
        }
        final spot = nearestTouchedDataSpot(/* unchanged */);
        if (spot == null) return;
        final diveId = _diveIdForSpot(spot.barIndex, spot.spotIndex);
        if (diveId != null) onDiveSelected(diveId);
      },
```

11. Readout: at the top of `getTooltipItems`, after the empty check:

```dart
          final pointer = _pointerAxisX;
          final gap = pointer == null ? null : _scale.breakAt(pointer);
          if (gap != null) {
            final format = DateFormat(widget.dateFormat.pattern);
            return [
              for (var i = 0; i < touchedSpots.length; i++)
                i == 0
                    ? LineTooltipItem(
                        context.l10n.insights_trend_gap_noDives(
                          format.format(gap.start),
                          format.format(gap.end),
                        ),
                        style,
                      )
                    : null,
            ];
          }
```

and in the normal path build the date with `_scale.toDate(touchedSpots.first.x)`. In `getTouchedSpotIndicator`, return all-null indicators while the pointer is in a band.

12. The overview strip and the highlight band read `_scale.toAxis`; nothing else changes.

- [ ] **Step 5: Run the new and every existing chart test**

Run: `flutter test test/features/insights/presentation/widgets/`
Expected: all pass. The existing tests construct no threshold, so they run the identity path and must be unchanged.

- [ ] **Step 6: Add the readout test, then run it**

Append to `dive_trend_chart_gaps_test.dart`:

```dart
  testWidgets('hovering the band reads No dives with both dates', (tester) async {
    await tester.pumpWidget(
      host(DiveTrendChart(points: points, gapThreshold: TrendGapThreshold.year1)),
    );
    final chart = tester.getRect(find.byType(LineChart));
    final data = readData(tester);
    final state = tester.state(find.byType(DiveTrendChart)) as dynamic;
    final b = state.debugScale.breaks.single;
    final fx = ((b.axisStart + b.axisEnd) / 2 - data.minX) / (data.maxX - data.minX);
    // Plot spans the chart minus the 50px left titles and 30px bottom titles.
    final x = chart.left + 50 + fx * (chart.width - 50);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset(x, chart.top + 40));
    await gesture.moveTo(Offset(x, chart.top + 41));
    await tester.pump();
    expect(find.textContaining('No dives:'), findsOneWidget);
  });
```

with a `@visibleForTesting TrendTimeScale get debugScale => _scale;` getter on the state and `import 'package:flutter/gestures.dart';`. fl_chart paints the tooltip on the canvas, not as a `Text` widget: if `find.textContaining` cannot see it, assert instead on the `LineTooltipItem` list by calling `readData(tester).lineTouchData.touchTooltipData.getTooltipItems` with one `LineBarSpot` after setting `state.debugPointerAxisX = mid` (add that `@visibleForTesting` setter).

Run: `flutter test test/features/insights/presentation/widgets/dive_trend_chart_gaps_test.dart`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/insights/presentation/widgets/dive_trend_chart.dart lib/features/insights/presentation/widgets/trend_break_spots.dart test/features/insights/presentation/widgets/dive_trend_chart_gaps_test.dart
git commit -m "feat(insights): plot trend charts through the gap-collapsing scale"
```

---

### Task 9: The hatched break band

**Files:**
- Create: `lib/features/insights/presentation/widgets/trend_break_band_painter.dart`
- Modify: `lib/features/insights/presentation/widgets/dive_trend_chart.dart` (stack the painter over the `LineChart`)
- Test: `test/features/insights/presentation/widgets/trend_break_band_painter_test.dart`

**Interfaces:**
- Consumes: `TrendGapBreak` (Task 2), `trendGapLengthLabel` (Task 6).
- Produces: `class TrendBreakBandPainter extends CustomPainter` with `TrendBreakBandPainter({required List<({double left, double right, String label})> bands, required Rect plot, required Color hatch, required Color fill, required TextStyle labelStyle, required TextDirection textDirection})` and `static List<({double left, double right, String label})> layout({required List<TrendGapBreak> breaks, required double visibleMin, required double visibleMax, required Rect plot, required String Function(TrendGapBreak) labelOf})`, which converts each break to pixels and drops those wholly outside the visible window.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_break_band_painter.dart';

void main() {
  final b = TrendGapBreak(
    start: DateTime.utc(2018),
    end: DateTime.utc(2025),
    axisStart: 400,
    axisEnd: 430,
  );
  const plot = Rect.fromLTWH(50, 0, 500, 170);

  test('a visible break is placed in plot pixels', () {
    final bands = TrendBreakBandPainter.layout(
      breaks: [b],
      visibleMin: 0,
      visibleMax: 1000,
      plot: plot,
      labelOf: (_) => '7y',
    );
    expect(bands.single.left, 50 + 0.4 * 500);
    expect(bands.single.right, 50 + 0.43 * 500);
    expect(bands.single.label, '7y');
  });

  test('a break outside the window is dropped', () {
    expect(
      TrendBreakBandPainter.layout(
        breaks: [b],
        visibleMin: 500,
        visibleMax: 1000,
        plot: plot,
        labelOf: (_) => '7y',
      ),
      isEmpty,
    );
  });

  test('a break half in view is clipped to the plot', () {
    final bands = TrendBreakBandPainter.layout(
      breaks: [b],
      visibleMin: 410,
      visibleMax: 1000,
      plot: plot,
      labelOf: (_) => '7y',
    );
    expect(bands.single.left, plot.left);
  });
}
```

Plus a widget test in `dive_trend_chart_gaps_test.dart`:

```dart
  testWidgets('the band painter is present only when a gap collapses', (tester) async {
    await tester.pumpWidget(host(DiveTrendChart(points: points)));
    expect(find.byKey(const ValueKey('trend-break-bands')), findsNothing);
    await tester.pumpWidget(
      host(DiveTrendChart(points: points, gapThreshold: TrendGapThreshold.year1)),
    );
    expect(find.byKey(const ValueKey('trend-break-bands')), findsOneWidget);
  });
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/features/insights/presentation/widgets/trend_break_band_painter_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement the painter**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/insights/domain/trend_time_scale.dart';

typedef TrendBreakBand = ({double left, double right, String label});

/// Draws each collapsed gap as a diagonal-hatched band the full height of
/// the plot, with its length centred under the x axis (issue #3251).
class TrendBreakBandPainter extends CustomPainter {
  TrendBreakBandPainter({
    required this.bands,
    required this.plot,
    required this.hatch,
    required this.fill,
    required this.labelStyle,
    required this.textDirection,
  });

  final List<TrendBreakBand> bands;
  final Rect plot;
  final Color hatch;
  final Color fill;
  final TextStyle labelStyle;
  final TextDirection textDirection;

  /// Gap between hatch lines, in pixels.
  static const double _spacing = 6;

  /// Places [breaks] in pixels over [plot] for the window
  /// [visibleMin]..[visibleMax], clipping to the plot and dropping any
  /// wholly out of view.
  static List<TrendBreakBand> layout({
    required List<TrendGapBreak> breaks,
    required double visibleMin,
    required double visibleMax,
    required Rect plot,
    required String Function(TrendGapBreak) labelOf,
  }) {
    final span = visibleMax - visibleMin;
    if (span <= 0) return const [];
    double px(double x) => plot.left + (x - visibleMin) / span * plot.width;
    return [
      for (final b in breaks)
        if (b.axisEnd > visibleMin && b.axisStart < visibleMax)
          (
            left: math.max(px(b.axisStart), plot.left),
            right: math.min(px(b.axisEnd), plot.right),
            label: labelOf(b),
          ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = hatch
      ..strokeWidth = 1;
    final fillPaint = Paint()..color = fill;
    for (final band in bands) {
      final rect = Rect.fromLTRB(band.left, plot.top, band.right, plot.bottom);
      canvas
        ..save()
        ..clipRect(rect)
        ..drawRect(rect, fillPaint);
      for (var x = rect.left - rect.height; x < rect.right; x += _spacing) {
        canvas.drawLine(
          Offset(x, rect.bottom),
          Offset(x + rect.height, rect.top),
          linePaint,
        );
      }
      canvas.restore();

      final text = TextPainter(
        text: TextSpan(text: band.label, style: labelStyle),
        textDirection: textDirection,
      )..layout();
      final centre = (band.left + band.right) / 2;
      text.paint(canvas, Offset(centre - text.width / 2, plot.bottom + 8));
    }
  }

  @override
  bool shouldRepaint(TrendBreakBandPainter old) =>
      old.bands != bands ||
      old.plot != plot ||
      old.hatch != hatch ||
      old.fill != fill ||
      old.labelStyle != labelStyle;
}
```

- [ ] **Step 4: Stack it over the chart**

In `_buildChart`, wrap the `LineChart` (inside the existing `SizedBox(height: height)`) in a `Stack`:

```dart
        child: Stack(
          children: [
            LineChart(/* unchanged */),
            if (!_scale.isIdentity)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('trend-break-bands'),
                    painter: TrendBreakBandPainter(
                      bands: TrendBreakBandPainter.layout(
                        breaks: _scale.breaks,
                        visibleMin: visibleMin,
                        visibleMax: visibleMax,
                        plot: Rect.fromLTWH(
                          trendChartPlotInsets.left + _yAxisNameSize,
                          0,
                          plotWidth,
                          height - trendChartPlotInsets.bottom,
                        ),
                        labelOf: (b) =>
                            trendGapLengthLabel(b.start, b.end, context.l10n),
                      ),
                      plot: Rect.fromLTWH(
                        trendChartPlotInsets.left + _yAxisNameSize,
                        0,
                        plotWidth,
                        height - trendChartPlotInsets.bottom,
                      ),
                      hatch: theme.colorScheme.outline.withValues(alpha: 0.6),
                      fill: theme.colorScheme.surfaceContainerHighest,
                      labelStyle: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
```

Compute the plot `Rect` once in a local. `surfaceContainerHighest` is an opaque theme colour, so the band hides any dot drawn under it and reads the same on every card surface.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/insights/presentation/widgets/`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/insights/presentation/widgets/trend_break_band_painter.dart lib/features/insights/presentation/widgets/dive_trend_chart.dart test/features/insights/presentation/widgets/trend_break_band_painter_test.dart test/features/insights/presentation/widgets/dive_trend_chart_gaps_test.dart
git commit -m "feat(insights): draw collapsed gaps as hatched bands with their length"
```

---

### Task 10: Callers and the Range menu

**Files:**
- Modify: `lib/features/insights/presentation/widgets/trend_chart_section.dart`
- Modify: `lib/features/insights/presentation/widgets/trend_control_strip.dart`
- Modify: `lib/features/insights/presentation/pages/insights_progression_page.dart` (cumulative chart)
- Modify: `lib/features/insights/presentation/widgets/focus/focus_results.dart`
- Modify: `lib/features/equipment/presentation/widgets/condition_trend_card.dart`
- Test: `test/features/insights/presentation/widgets/trend_control_strip_gaps_test.dart`
- Test: `test/features/insights/presentation/widgets/trend_chart_section_gaps_test.dart`

**Interfaces:**
- Consumes: `trendGapThresholdProvider`, `setTrendGapThreshold` (Task 7), `trendGapThresholdLabel` (Task 6), `DiveTrendChart.gapThreshold` (Task 8).
- Produces: `TrendControlStrip` params `TrendGapThreshold gapThreshold = TrendGapThreshold.off` and `ValueChanged<TrendGapThreshold>? onGapThresholdSelected`; menu keys `trend-gaps-<chartId>-<threshold.name>`.

- [ ] **Step 1: Write the failing tests**

`trend_control_strip_gaps_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_range.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_control_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ValueChanged<TrendGapThreshold> onGap,
    required ValueChanged<TrendRangePreset> onRange,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TrendControlStrip(
          chartId: 'depth',
          aggregation: TrendAggregation.none,
          onAggregationChanged: (_) {},
          showRollingMean: true,
          onToggleRollingMean: () {},
          showLinearFit: false,
          onToggleLinearFit: () {},
          seriesColor: Colors.indigo,
          rollingColor: Colors.amber,
          rateColor: Colors.grey,
          range: TrendRange.all,
          onRangePresetSelected: onRange,
          gapThreshold: TrendGapThreshold.year1,
          onGapThresholdSelected: onGap,
        ),
      ),
    ),
  );

  testWidgets('the Range menu lists the gap choices and checks the current', (tester) async {
    await pump(tester, onGap: (_) {}, onRange: (_) {});
    await tester.tap(find.byKey(const ValueKey('trend-range-depth')));
    await tester.pumpAndSettle();
    expect(find.text('Collapse gaps'), findsOneWidget);
    final year = tester.widget<CheckedPopupMenuItem<Object>>(
      find.byKey(const ValueKey('trend-gaps-depth-year1')),
    );
    expect(year.checked, isTrue);
  });

  testWidgets('picking a gap choice reports it and not a range', (tester) async {
    TrendGapThreshold? gap;
    TrendRangePreset? range;
    await pump(tester, onGap: (t) => gap = t, onRange: (p) => range = p);
    await tester.tap(find.byKey(const ValueKey('trend-range-depth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trend-gaps-depth-years2')));
    await tester.pumpAndSettle();
    expect(gap, TrendGapThreshold.years2);
    expect(range, isNull);
  });

  testWidgets('a range preset still reports as a range', (tester) async {
    TrendRangePreset? range;
    await pump(tester, onGap: (_) {}, onRange: (p) => range = p);
    await tester.tap(find.byKey(const ValueKey('trend-range-depth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trend-range-depth-year1')));
    await tester.pumpAndSettle();
    expect(range, TrendRangePreset.year1);
  });
}
```

`trend_chart_section_gaps_test.dart`: pump `TrendChartSection` (as in `trend_chart_section_test.dart`'s `host`) inside a `ProviderScope` overriding `settingsProvider` with `MockSettingsNotifier(const AppSettings(trendGapThreshold: TrendGapThreshold.years2))` from `test/helpers/mock_providers.dart`; assert `tester.widget<DiveTrendChart>(find.byType(DiveTrendChart)).gapThreshold == TrendGapThreshold.years2`; open the Range menu, tap `trend-gaps-depth-off`, and assert the container's `settingsProvider` now holds `TrendGapThreshold.off`.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/features/insights/presentation/widgets/trend_control_strip_gaps_test.dart test/features/insights/presentation/widgets/trend_chart_section_gaps_test.dart`
Expected: compile errors, no `gapThreshold` parameter.

- [ ] **Step 3: Implement the menu**

In `trend_control_strip.dart` (imports: `trend_gap_threshold.dart`, `trend_gap_label.dart`):

```dart
  /// The diver's gap threshold, checked in the Range menu's "Collapse gaps"
  /// section (issue #3251).
  final TrendGapThreshold gapThreshold;

  /// Called with a picked gap threshold. Null leaves the section out.
  final ValueChanged<TrendGapThreshold>? onGapThresholdSelected;
```

Change the Range `PopupMenuButton<TrendRangePreset>` to `PopupMenuButton<Object>`:

```dart
            PopupMenuButton<Object>(
              key: ValueKey('trend-range-$chartId'),
              tooltip: context.l10n.insights_trend_range_tooltip,
              initialValue: range.preset,
              onSelected: (value) {
                if (value is TrendRangePreset) {
                  onRangePresetSelected!(value);
                } else if (value is TrendGapThreshold) {
                  onGapThresholdSelected?.call(value);
                }
              },
              itemBuilder: (context) => [
                for (final preset in TrendRangePreset.values)
                  PopupMenuItem<Object>(
                    key: ValueKey('trend-range-$chartId-${preset.name}'),
                    value: preset,
                    child: Text(
                      trendRangeLabel(preset, context.l10n, menuItem: true),
                    ),
                  ),
                if (onGapThresholdSelected != null) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem<Object>(
                    enabled: false,
                    height: 32,
                    child: Text(
                      context.l10n.insights_trend_gaps_menuHeader,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  for (final t in TrendGapThreshold.values)
                    CheckedPopupMenuItem<Object>(
                      key: ValueKey('trend-gaps-$chartId-${t.name}'),
                      value: t,
                      checked: t == gapThreshold,
                      child: Text(trendGapThresholdLabel(t, context.l10n)),
                    ),
                ],
              ],
              child: /* unchanged */,
            ),
```

- [ ] **Step 4: Wire the callers**

`trend_chart_section.dart`: read `final gapThreshold = ref.watch(trendGapThresholdProvider);`, pass `gapThreshold: gapThreshold` to `DiveTrendChart`, and to `TrendControlStrip` pass `gapThreshold: gapThreshold` and `onGapThresholdSelected: (t) => ref.read(settingsProvider.notifier).setTrendGapThreshold(t)`.

`insights_progression_page.dart` (cumulative chart), `focus_results.dart` and `condition_trend_card.dart`: add `gapThreshold: ref.watch(trendGapThresholdProvider),` to each `DiveTrendChart(...)`, importing `settings_providers.dart` where it is not already imported.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/insights/ test/features/equipment/presentation/widgets/`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/insights lib/features/equipment/presentation/widgets/condition_trend_card.dart test/features/insights
git commit -m "feat(insights): collapse gaps on every trend chart and pick the threshold from Range"
```

---

### Task 11: Settings > Appearance tile

**Files:**
- Modify: `lib/features/settings/presentation/widgets/appearance_settings_tiles.dart` (`AppearanceGeneralTiles`, after the Map style tile)
- Test: `test/features/settings/presentation/widgets/appearance_trend_gaps_tile_test.dart`

**Interfaces:**
- Consumes: `trendGapThresholdLabel` (Task 6), `AppSettings.trendGapThreshold`, `setTrendGapThreshold` (Task 7).
- Produces: a `ListTile` keyed `settings-trend-gaps` with a `DropdownButton<TrendGapThreshold>` trailing, the same picker the Map style tile beside it uses.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/appearance_settings_tiles.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('the tile shows the threshold and saves a new pick', (tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppearanceGeneralTiles(onLanguageTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('settings-trend-gaps'));
    await tester.scrollUntilVisible(tile, 100);
    expect(find.text('Collapse gaps in trend charts'), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('1 year')), findsOneWidget);

    await tester.tap(find.descendant(of: tile, matching: find.text('1 year')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 years').last);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).trendGapThreshold, TrendGapThreshold.years2);
  });
}
```

If `AppearanceGeneralTiles` needs other overrides to build (theme registry, nav customization), copy them from the nearest existing `appearance_settings_tiles` test.

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/features/settings/presentation/widgets/appearance_trend_gaps_tile_test.dart`
Expected: FAIL, no widget with key `settings-trend-gaps`.

- [ ] **Step 3: Implement**

After the Map style `ListTile` in `AppearanceGeneralTiles` (imports: `trend_gap_threshold.dart`, `trend_gap_label.dart`):

```dart
        ListTile(
          key: const ValueKey('settings-trend-gaps'),
          leading: const FeatureAccentIcon(
            Icons.insights_outlined,
            featureId: 'settings-appearance',
            surface: AccentSurface.list,
          ),
          title: Text(l10n.settings_appearance_trendGaps),
          subtitle: Text(l10n.settings_appearance_trendGaps_subtitle),
          trailing: DropdownButton<TrendGapThreshold>(
            value: settings.trendGapThreshold,
            underline: const SizedBox.shrink(),
            onChanged: (t) {
              if (t != null) {
                ref.read(settingsProvider.notifier).setTrendGapThreshold(t);
              }
            },
            items: [
              for (final t in TrendGapThreshold.values)
                DropdownMenuItem(
                  value: t,
                  child: Text(trendGapThresholdLabel(t, l10n)),
                ),
            ],
          ),
        ),
```

- [ ] **Step 4: Run it and the settings widget tests**

Run: `flutter test test/features/settings/presentation/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/widgets/appearance_settings_tiles.dart test/features/settings/presentation/widgets/appearance_trend_gaps_tile_test.dart
git commit -m "feat(settings): choose the trend chart gap threshold under Appearance"
```

---

### Task 12: Verification and screenshots

**Files:** none new (the throwaway harness `test/tmp_shots/` is deleted at the end).

- [ ] **Step 1: Whole-repo checks**

```bash
dart format .
flutter analyze
flutter test test/architecture/ test/shared/
flutter test test/features/insights/ test/features/settings/ test/features/equipment/ test/core/database/ test/core/services/sync/ test/l10n/
```

Expected: format leaves no diff, analyze reports no issues, every test passes.

- [ ] **Step 2: After screenshots**

Add `gapThreshold` to nothing in the harness: `TrendChartSection` now reads the setting, whose default is a year. Re-run `flutter test test/tmp_shots/gap_shots_test.dart --update-goldens`, copy the four PNGs to the scratchpad as `01-progression-depth-after[-dark][-phone].png`, then add a harness case that opens the Range menu (`02-range-menu-after.png`) and one that pumps `AppearanceGeneralTiles` (`03-settings-trend-gaps-after.png`). Look at each image before using it.

- [ ] **Step 3: Remove the harness**

```bash
rm -r test/tmp_shots
git status --short
```

Expected: nothing under `test/tmp_shots` remains.
