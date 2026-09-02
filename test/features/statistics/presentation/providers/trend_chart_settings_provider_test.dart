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
        .state = const TrendChartSettings(
      aggregation: TrendAggregation.monthly,
    );

    expect(
      container
          .read(trendChartSettingsProvider(TrendChartIds.depth))
          .aggregation,
      TrendAggregation.monthly,
    );
    expect(
      container
          .read(trendChartSettingsProvider(TrendChartIds.weight))
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
