import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';
import 'package:submersion/features/insights/presentation/widgets/date_axis.dart';

double ms(DateTime d) => d.millisecondsSinceEpoch.toDouble();

void main() {
  // Pinned and restored as in date_axis_test.dart: labels resolve against the
  // process-wide Intl.defaultLocale.
  late String? previousLocale;
  setUpAll(() => initializeDateFormatting('en'));
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  test('forRange is forAxisRange with the identity scale', () {
    final a = DateAxis.forRange(DateTime.utc(2013), DateTime.utc(2026));
    final b = DateAxis.forAxisRange(
      ms(DateTime.utc(2013)),
      ms(DateTime.utc(2026)),
    );
    expect(b.min, a.min);
    expect(b.max, a.max);
    expect(b.labelInterval, a.labelInterval);
    expect(b.granularity, a.granularity);
  });

  test('a phone-width thirteen-year axis spaces labels 44px apart', () {
    final axis = DateAxis.forAxisRange(
      ms(DateTime.utc(2013)),
      ms(DateTime.utc(2026)),
      plotWidth: 300,
    );
    final px = axis.labelInterval / (axis.max - axis.min) * 300;
    expect(px, greaterThanOrEqualTo(44));
  });

  test('a wide axis keeps the tick-derived interval', () {
    final narrow = DateAxis.forAxisRange(
      ms(DateTime.utc(2013)),
      ms(DateTime.utc(2026)),
    );
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
      final x = scale.toAxis(DateTime.utc(2021, 3, 1));
      expect(axis.labelFor(x), "Mar '21");
    });
  });

  group('a short collapsed axis', () {
    // Two ten-day trips a year and a half apart: about a month of diving.
    final dates = [
      for (var d = 0; d < 10; d++) DateTime.utc(2019, 3, 1 + d),
      for (var d = 0; d < 10; d++) DateTime.utc(2020, 9, 1 + d),
    ];
    final scale = TrendTimeScale.build(dates, TrendGapThreshold.year1);
    final axis = DateAxis.forAxisRange(
      scale.toAxis(dates.first),
      scale.toAxis(dates.last),
      scale: scale,
      plotWidth: 600,
    );

    test('day ticks step through the collapsed span, not the real one', () {
      expect(axis.granularity, DateAxisGranularity.day);
      expect(axis.labelInterval, lessThan((axis.max - axis.min) / 3));
      for (final t in axis.ticks) {
        expect(scale.inGap(scale.toAxis(t)), isFalse);
      }
    });

    test('labels land on both trips', () {
      final labels = <String>[];
      for (var x = axis.min; x <= axis.max; x += axis.labelInterval) {
        final l = axis.labelFor(x, step: axis.labelInterval);
        if (l != null) labels.add(l);
      }
      expect(labels.where((l) => l.endsWith("'19")), isNotEmpty);
      expect(labels.where((l) => l.endsWith("'20")), isNotEmpty);
    });
  });

  test('no label anywhere in a gap region, margins included', () {
    final dates = [
      for (var m = 0; m < 18; m++) DateTime.utc(2013, 1 + m, 1),
      for (var m = 0; m < 6; m++) DateTime.utc(2021, 1 + m, 1),
    ];
    final scale = TrendTimeScale.build(dates, TrendGapThreshold.year1);
    final axis = DateAxis.forAxisRange(
      scale.toAxis(dates.first),
      scale.toAxis(dates.last),
      scale: scale,
    );
    final gapStart = scale.toAxis(DateTime.utc(2014, 6, 1));
    final gapEnd = scale.toAxis(DateTime.utc(2021, 1, 1));
    final b = scale.breaks.single;
    // Just inside each margin, outside the hatched band.
    expect(axis.labelFor(gapStart + (b.axisStart - gapStart) * 0.9), isNull);
    expect(axis.labelFor(b.axisEnd + (gapEnd - b.axisEnd) * 0.1), isNull);
  });

  test('the period after a gap keeps its labels where fl_chart puts them', () {
    // Five years of diving, a six-year break, a year and a half more, on a
    // desktop-width plot; seeded so the label slots land where the
    // screenshot that showed the bug had them. fl_chart draws labels at
    // min, at multiples of the interval, and at max.
    final rnd = math.Random(7);
    final dates = <DateTime>[];
    for (
      var d = DateTime.utc(2013, 3, 1);
      d.isBefore(DateTime.utc(2018, 9, 1));
      d = d.add(Duration(days: 2 + rnd.nextInt(d.year < 2016 ? 6 : 30)))
    ) {
      rnd.nextDouble();
      dates.add(d);
    }
    for (
      var d = DateTime.utc(2025, 3, 20);
      d.isBefore(DateTime.utc(2026, 9, 30));
      d = d.add(Duration(days: 2 + rnd.nextInt(14)))
    ) {
      rnd.nextDouble();
      dates.add(d);
    }
    final scale = TrendTimeScale.build(dates, TrendGapThreshold.year1);
    final lo = scale.toAxis(dates.first);
    final hi = scale.toAxis(dates.last);
    final axis = DateAxis.forAxisRange(lo, hi, scale: scale, plotWidth: 794);
    final step = axis.labelInterval;
    final slots = [
      lo,
      for (var k = (lo / step).ceil(); k * step < hi; k++)
        if (k * step > lo) k * step,
      hi,
    ];
    final after = [
      for (final x in slots)
        if (x > scale.breaks.single.axisEnd) axis.labelFor(x, step: step),
    ].whereType<String>();
    expect(after, isNotEmpty);
  });
}
