import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';

void main() {
  final rmv = [
    for (var i = 0; i < 6; i++)
      TrendDataPoint(
        date: DateTime.utc(2025, 1, i + 1),
        value: 10.0 + i,
        diveId: 'd$i',
      ),
  ];
  final depth = [
    TrendDataPoint(date: DateTime.utc(2025), value: 30, diveId: 'd0'),
  ];
  final rows = [
    for (var i = 0; i < 6; i++)
      FocusFactorRow(
        diveId: 'd$i',
        dateTime: DateTime.utc(2025, 1, i + 1),
        maxDepth: i < 3 ? 10 : 30,
      ),
    FocusFactorRow(diveId: 'noRmv', dateTime: DateTime.utc(2025), maxDepth: 99),
  ];

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        focusMetricSeriesProvider(
          FocusMetric.rmv,
        ).overrideWith((ref) async => rmv),
        focusMetricSeriesProvider(
          FocusMetric.maxDepth,
        ).overrideWith((ref) async => depth),
        focusFactorRowsProvider.overrideWith((ref) async => rows),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the default group is the best ten RMV dives', () async {
    final c = container();
    final group = await c.read(focusGroupProvider.future);
    expect(group.members.first.diveId, 'd0');
    expect(group.members, hasLength(6));
  });

  test('changing the selection re-picks the group', () async {
    final c = container();
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.maxDepth,
      mode: FocusMode.highest,
      count: 1,
    );
    final group = await c.read(focusGroupProvider.future);
    expect(group.members.single.value, 30);
  });

  test('the baseline is only the dives that have the metric', () async {
    final c = container();
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      count: 3,
    );
    final report = await c.read(focusFactorReportProvider.future);
    final depthFactor =
        report.factors.firstWhere((f) => f.id == FocusFactorId.maxDepth)
            as NumericFactor;
    expect(depthFactor.groupMean, 10);
    // Mean of d0..d5 only; the 99 m dive without an RMV is not baseline.
    expect(depthFactor.baselineMean, 20);
  });
}
