import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/rules/trend_rules.dart';

import '../observation_fixtures.dart';

/// [n] values per period with mean [recent]/[previous] and spread +-[jitter].
List<ObservationValue> rmvSeries({
  required int n,
  required double recent,
  required double previous,
  double jitter = 1,
  int? previousN,
}) => [
  for (var k = 0; k < (previousN ?? n); k++)
    ObservationValue(
      diveId: 'p$k',
      date: daysAgo(400 + k * 30),
      value: previous + (k.isEven ? jitter : -jitter),
    ),
  for (var k = 0; k < n; k++)
    ObservationValue(
      diveId: 'r$k',
      date: daysAgo(10 + k * 30),
      value: recent + (k.isEven ? jitter : -jitter),
    ),
]..sort((a, b) => a.date.compareTo(b.date));

List<ObservationDive> twoPeriods(
  ObservationDive Function(String id, DateTime date, int k) previous,
  ObservationDive Function(String id, DateTime date, int k) recent,
) => [
  for (var k = 0; k < 8; k++) previous('p$k', daysAgo(400 + k * 30), k),
  for (var k = 0; k < 8; k++) recent('r$k', daysAgo(10 + k * 30), k),
]..sort((a, b) => a.date.compareTo(b.date));

void main() {
  group('rmvTrendRule', () {
    test('fires on a clear 25% drop with a stable fingerprint', () {
      final out = rmvTrendRule(
        ObservationInputs(
          now: now,
          rmvPerDive: rmvSeries(n: 8, recent: 15, previous: 20),
        ),
      );
      expect(out, hasLength(1));
      final facts = out.single.facts as TrendFacts;
      expect(facts.direction, TrendDirection.down);
      expect(facts.percentChange, closeTo(-25, 1e-9));
      expect(out.single.fingerprint, 'down:2');
      expect(out.single.target, const InsightsCategoryTarget('gas'));
    });

    test('silent below 8 dives in a period', () {
      final series = rmvSeries(n: 8, previousN: 7, recent: 15, previous: 20);
      expect(
        rmvTrendRule(ObservationInputs(now: now, rmvPerDive: series)),
        isEmpty,
      );
    });

    test('silent below the 8% minimum', () {
      // 18.7 against 20 is 6.5% lower.
      final series = rmvSeries(n: 8, recent: 18.7, previous: 20, jitter: 0.1);
      expect(
        rmvTrendRule(ObservationInputs(now: now, rmvPerDive: series)),
        isEmpty,
      );
    });

    test('silent when noise swamps the change (effect size < 0.5)', () {
      // A 10% change with a spread of 10 gives d of about 0.2.
      final series = rmvSeries(n: 8, recent: 18, previous: 20, jitter: 10);
      expect(
        rmvTrendRule(ObservationInputs(now: now, rmvPerDive: series)),
        isEmpty,
      );
    });

    test('future-dated values are not in the last 12 months', () {
      final series = rmvSeries(n: 8, recent: 15, previous: 20)
        ..removeWhere((v) => v.diveId == 'r0');
      final withFuture = [
        ...series,
        ObservationValue(
          diveId: 'future',
          date: now.add(const Duration(days: 3)),
          value: 1,
        ),
      ];
      // Seven real recent values plus one future one: under the minimum.
      expect(
        rmvTrendRule(ObservationInputs(now: now, rmvPerDive: withFuture)),
        isEmpty,
      );
    });
  });

  test('maxDepthTrendRule: 20% deeper fires, band 2', () {
    final dives = twoPeriods(
      (id, date, k) => dive(id, date, maxDepthM: k.isEven ? 21 : 19),
      (id, date, k) => dive(id, date, maxDepthM: k.isEven ? 25 : 23),
    );
    final out = maxDepthTrendRule(ObservationInputs(now: now, dives: dives));
    expect(out.single.fingerprint, 'up:2');
    expect(out.single.target, const InsightsCategoryTarget('progression'));
  });

  test('diveTimeTrendRule uses runtime minutes and ignores null runtime', () {
    final dives = [
      ...twoPeriods(
        (id, date, k) =>
            dive(id, date, runtimeSeconds: (k.isEven ? 41 : 39) * 60),
        (id, date, k) =>
            dive(id, date, runtimeSeconds: (k.isEven ? 51 : 49) * 60),
      ),
      dive('none', daysAgo(5)),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final out = diveTimeTrendRule(ObservationInputs(now: now, dives: dives));
    final facts = out.single.facts as TrendFacts;
    expect(facts.recent, closeTo(50, 1e-9));
    expect(facts.recentDives, 8);
  });

  test('weightTrendRule needs 1 kg and bands by kilogram', () {
    List<ObservationDive> make(double recent) => twoPeriods(
      (id, date, k) => dive(id, date, weightKg: k.isEven ? 8.1 : 7.9),
      (id, date, k) =>
          dive(id, date, weightKg: recent + (k.isEven ? 0.1 : -0.1)),
    );
    expect(
      weightTrendRule(ObservationInputs(now: now, dives: make(7.2))),
      isEmpty,
    );
    final out = weightTrendRule(ObservationInputs(now: now, dives: make(5.5)));
    expect(out.single.fingerprint, 'down:2');
    expect(out.single.target, const InsightsCategoryTarget('equipment'));
  });

  group('frequencyTrendRule', () {
    List<ObservationDive> log({required int previous, required int recent}) => [
      dive('first', daysAgo(800)),
      ...divesIn(prefix: 'p', count: previous, endDaysAgo: 400),
      ...divesIn(prefix: 'r', count: recent, endDaysAgo: 5),
    ]..sort((a, b) => a.date.compareTo(b.date));

    test('fires on 30% and 6 more dives', () {
      final out = frequencyTrendRule(
        ObservationInputs(now: now, dives: log(previous: 20, recent: 26)),
      );
      expect((out.single.facts as TrendFacts).recentDives, 26);
      expect(out.single.fingerprint, 'up:3');
      expect(out.single.target, const InsightsCategoryTarget('time-patterns'));
    });

    test('silent under 6 dives of change even at 50%', () {
      expect(
        frequencyTrendRule(
          ObservationInputs(now: now, dives: log(previous: 10, recent: 15)),
        ),
        isEmpty,
      );
    });

    test('silent when the log starts inside the previous window', () {
      final dives = [
        ...divesIn(prefix: 'p', count: 4, endDaysAgo: 400, spanDays: 100),
        ...divesIn(prefix: 'r', count: 20, endDaysAgo: 5),
      ]..sort((a, b) => a.date.compareTo(b.date));
      expect(
        frequencyTrendRule(ObservationInputs(now: now, dives: dives)),
        isEmpty,
      );
    });
  });
}
