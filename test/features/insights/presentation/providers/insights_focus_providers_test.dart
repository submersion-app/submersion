import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/focus/focus_factor_row.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<ProviderContainer> container(List<TrendDataPoint> cns) async {
    final c = ProviderContainer(
      overrides: [
        ...await getBaseOverrides(),
        focusMetricSeriesProvider(
          FocusMetric.cns,
        ).overrideWith((ref) async => cns),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the threshold default is the mean of the selected metric', () async {
    final c = await container([
      TrendDataPoint(date: DateTime.utc(2025), value: 10, diveId: 'a'),
      TrendDataPoint(date: DateTime.utc(2025, 2), value: 30, diveId: 'b'),
    ]);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.cns,
      mode: FocusMode.above,
    );
    expect(await c.read(focusThresholdDefaultProvider.future), 20);
  });

  test('an empty series gives no default', () async {
    final c = await container(const []);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.cns,
      mode: FocusMode.above,
    );
    expect(await c.read(focusThresholdDefaultProvider.future), isNull);
  });

  test('every metric has a series provider that resolves', () async {
    final c = ProviderContainer(overrides: await getBaseOverrides());
    addTearDown(c.dispose);
    for (final m in FocusMetric.values) {
      expect(
        await c.read(focusMetricSeriesProvider(m).future),
        isEmpty,
        reason: '$m',
      );
    }
  });

  test('factor rows are keyed by dive id once per load', () async {
    final rows = [
      FocusFactorRow(diveId: 'a', dateTime: DateTime.utc(2025)),
      FocusFactorRow(diveId: 'b', dateTime: DateTime.utc(2025, 2)),
    ];
    final c = ProviderContainer(
      overrides: [
        ...await getBaseOverrides(),
        focusFactorRowsProvider.overrideWith((ref) async => rows),
      ],
    );
    addTearDown(c.dispose);
    await c.read(focusFactorRowsProvider.future);
    final byId = c.read(focusFactorRowsByIdProvider);
    expect(byId.keys, ['a', 'b']);
    expect(byId['b'], same(rows[1]));
    // The same map object comes back until the rows reload.
    expect(c.read(focusFactorRowsByIdProvider), same(byId));
  });
}
