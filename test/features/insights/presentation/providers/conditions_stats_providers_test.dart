import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #3118: the condition statistics re-bin on a unit change without
/// re-running the query behind them.
void main() {
  test('air temperature trend has its own chart id', () {
    expect(TrendChartIds.airTemp, 'air-temp');
  });

  test('a unit change re-bins without re-running the query', () async {
    var queries = 0;
    final settings = MockSettingsNotifier();
    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides(settingsNotifier: settings)).cast(),
        conditionsRowsProvider.overrideWith((ref) async {
          queries++;
          return [
            ConditionsRow(
              diveId: 'a',
              dateTime: DateTime.utc(2026, 1, 1),
              airTemp: 22, // 20-25 C; 71.6 F is 70-80 F
            ),
          ];
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(conditionsStatsProvider, (_, _) {});

    final celsius = await container.read(conditionsStatsProvider.future);
    expect(celsius.airTemp.bands.first.upper, 10);

    await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
    final fahrenheit = await container.read(conditionsStatsProvider.future);

    expect(fahrenheit.airTemp.bands.first.upper, 50);
    expect(fahrenheit.airTemp.bands.map((b) => b.count), [0, 0, 1, 0, 0]);
    expect(queries, 1);
  });

  test('depth unit switches wind and swell to imperial', () async {
    final settings = MockSettingsNotifier();
    final container = ProviderContainer(
      overrides: [
        ...(await getBaseOverrides(settingsNotifier: settings)).cast(),
        conditionsRowsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    container.listen(conditionsUnitsProvider, (_, _) {});

    expect(container.read(conditionsUnitsProvider).isMetric, isTrue);
    await settings.setDepthUnit(DepthUnit.feet);
    expect(container.read(conditionsUnitsProvider).isMetric, isFalse);
  });
}
