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
      final s = TrendTimeScale.build([
        ...early,
        ...late,
      ], TrendGapThreshold.off);
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
      expect(
        TrendTimeScale.build([], TrendGapThreshold.year1).isIdentity,
        isTrue,
      );
      expect(
        TrendTimeScale.build([
          DateTime.utc(2020),
        ], TrendGapThreshold.year1).isIdentity,
        isTrue,
      );
    });
  });

  group('threshold boundary', () {
    test('exactly twelve calendar months is not a gap', () {
      final s = TrendTimeScale.build([
        DateTime.utc(2020, 1, 1),
        DateTime.utc(2021, 1, 1),
      ], TrendGapThreshold.year1);
      expect(s.isIdentity, isTrue);
    });

    test('a day past twelve months is a gap', () {
      final s = TrendTimeScale.build([
        DateTime.utc(2020, 1, 1),
        DateTime.utc(2021, 1, 2),
      ], TrendGapThreshold.year1);
      expect(s.breaks, hasLength(1));
    });

    test('six months collapses what a year keeps', () {
      final dates = [DateTime.utc(2020, 1, 1), DateTime.utc(2020, 9, 1)];
      expect(
        TrendTimeScale.build(dates, TrendGapThreshold.months6).breaks,
        hasLength(1),
      );
      expect(
        TrendTimeScale.build(dates, TrendGapThreshold.year1).isIdentity,
        isTrue,
      );
    });
  });

  group('one break', () {
    final s = TrendTimeScale.build([
      ...late,
      ...early,
    ], TrendGapThreshold.year1);
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
    final s = TrendTimeScale.build([
      ...early,
      ...late,
      ...third,
    ], TrendGapThreshold.year1);
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
    final local = [
      DateTime(2013, 3, 1, 10),
      DateTime(2013, 4, 1, 10),
      DateTime(2016, 3, 1, 10),
    ];
    final utc = [for (final d in local) d.toUtc()];
    final a = TrendTimeScale.build(local, TrendGapThreshold.year1);
    final b = TrendTimeScale.build(utc, TrendGapThreshold.year1);
    expect(a.breaks.single.axisStart, b.breaks.single.axisStart);
    expect(a.toAxis(local.last), b.toAxis(utc.last));
  });
}
