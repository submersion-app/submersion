import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_analyzer.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';

FocusFactorRow row(
  String id, {
  double? maxDepth,
  String? entry,
  int month = 3,
  int hour = 9,
  String? siteId,
  String? siteName,
}) => FocusFactorRow(
  diveId: id,
  dateTime: DateTime.utc(2025, month, 1, hour),
  maxDepth: maxDepth,
  entryMethod: entry,
  siteId: siteId,
  siteName: siteName,
);

T factor<T extends FocusFactor>(FocusFactorReport r, FocusFactorId id) =>
    r.factors.firstWhere((f) => f.id == id) as T;

void main() {
  final baseline = [
    for (var i = 0; i < 10; i++)
      row('b$i', maxDepth: 10.0 + i * 2, entry: i < 4 ? 'boat' : 'shore'),
  ];

  test('fewer than three dives is too few', () {
    final report = FocusFactorAnalyzer.analyze(
      group: baseline.take(2).toList(),
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    expect(report.tooFewDives, isTrue);
    expect(report.factors, isEmpty);
  });

  test('a numeric factor compares means and flags half a deviation', () {
    final group = baseline.take(3).toList(); // depths 10, 12, 14
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    final depth = factor<NumericFactor>(report, FocusFactorId.maxDepth);
    expect(depth.groupMean, 12);
    expect(depth.baselineMean, 19);
    expect(depth.difference, -7);
    // Baseline sd of 10..28 step 2 is about 5.74; 7 > 2.87.
    expect(depth.standsOut, isTrue);
    expect(report.standouts, contains(depth));
  });

  test('a small numeric difference does not stand out', () {
    final group = [baseline[4], baseline[5], baseline[6]]; // 18, 20, 22
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    expect(
      factor<NumericFactor>(report, FocusFactorId.maxDepth).standsOut,
      isFalse,
    );
  });

  test('a categorical factor reports shares and flags a 20 point lead', () {
    final group = baseline.take(3).toList(); // all boat
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    final entry = factor<CategoricalFactor>(report, FocusFactorId.entryMethod);
    final boat = entry.top.first;
    expect(boat.key, 'boat');
    expect(boat.groupShare, 1.0);
    expect(boat.baselineShare, 0.4);
    expect(boat.groupCount, 3);
    expect(boat.standsOut, isTrue);
  });

  test('coverage counts only the group dives that recorded a factor', () {
    final group = [row('x', maxDepth: 10), row('y'), row('z', maxDepth: 12)];
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: [...group, ...baseline],
      metric: FocusMetric.rmv,
    );
    final depth = factor<NumericFactor>(report, FocusFactorId.maxDepth);
    expect(depth.groupCovered, 2);
    expect(depth.groupSize, 3);
  });

  test('a factor nobody in the group recorded has no mean', () {
    final report = FocusFactorAnalyzer.analyze(
      group: baseline.take(3).toList(),
      baseline: baseline,
      metric: FocusMetric.rmv,
    );
    final temp = factor<NumericFactor>(report, FocusFactorId.waterTemp);
    expect(temp.groupCovered, 0);
    expect(temp.groupMean, isNull);
    expect(temp.standsOut, isFalse);
  });

  test('the ranking metric own factor is left out', () {
    FocusFactorReport run(FocusMetric m) => FocusFactorAnalyzer.analyze(
      group: baseline.take(3).toList(),
      baseline: baseline,
      metric: m,
    );
    Set<FocusFactorId> ids(FocusMetric m) =>
        run(m).factors.map((f) => f.id).toSet();
    expect(ids(FocusMetric.maxDepth), isNot(contains(FocusFactorId.maxDepth)));
    expect(
      ids(FocusMetric.bottomTime),
      isNot(contains(FocusFactorId.duration)),
    );
    expect(ids(FocusMetric.weight), isNot(contains(FocusFactorId.weight)));
    expect(
      ids(FocusMetric.waterTemp),
      isNot(contains(FocusFactorId.waterTemp)),
    );
    expect(ids(FocusMetric.rmv), hasLength(FocusFactorId.values.length));
  });

  test('months and time of day come from the date', () {
    final group = [
      row('a', month: 7, hour: 5),
      row('b', month: 7, hour: 7),
      row('c', month: 7, hour: 20),
    ];
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: group,
      metric: FocusMetric.rmv,
    );
    expect(
      factor<CategoricalFactor>(report, FocusFactorId.month).top.single.key,
      '7',
    );
    expect(
      factor<CategoricalFactor>(
        report,
        FocusFactorId.timeOfDay,
      ).top.map((s) => s.key),
      containsAll(['Night', 'Morning', 'Evening']),
    );
  });

  test('a site share carries the site name as its label', () {
    final group = [
      for (var i = 0; i < 3; i++)
        row('s$i', siteId: 'reef', siteName: 'House Reef'),
    ];
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: group,
      metric: FocusMetric.rmv,
    );
    final site = factor<CategoricalFactor>(report, FocusFactorId.site);
    expect(site.top.single.label, 'House Reef');
  });

  test('time of day uses the Time patterns buckets', () {
    expect(
      FocusFactorAnalyzer.timeOfDayKey(DateTime.utc(2025, 1, 1, 5)),
      'Night',
    );
    expect(
      FocusFactorAnalyzer.timeOfDayKey(DateTime.utc(2025, 1, 1, 6)),
      'Morning',
    );
    expect(
      FocusFactorAnalyzer.timeOfDayKey(DateTime.utc(2025, 1, 1, 12)),
      'Afternoon',
    );
    expect(
      FocusFactorAnalyzer.timeOfDayKey(DateTime.utc(2025, 1, 1, 18)),
      'Evening',
    );
  });

  test('a dive with several types counts once under each of them', () {
    FocusFactorRow typed(String id, List<String> types) => FocusFactorRow(
      diveId: id,
      dateTime: DateTime.utc(2025, 3, 1),
      diveTypes: types,
    );
    final group = [
      typed('a', ['reef', 'night']),
      typed('b', ['reef']),
      typed('c', ['reef']),
    ];
    final report = FocusFactorAnalyzer.analyze(
      group: group,
      baseline: group,
      metric: FocusMetric.rmv,
    );
    final types = factor<CategoricalFactor>(report, FocusFactorId.diveType);
    expect(types.groupCovered, 3);
    final byKey = {for (final s in types.top) s.key: s};
    // Shares are of dives, not of type links: every dive is a reef dive.
    expect(byKey['reef']!.groupShare, 1.0);
    expect(byKey['night']!.groupShare, closeTo(1 / 3, 1e-9));
  });
}
