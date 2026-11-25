/// Issue #5012: the right axis only shows a metric whose line is drawn, so
/// picking a metric from the axis menu turns its line on as well.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/o2_cell_unit.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A live legend seeded from [settings], kept alive as a mounted chart would.
ProfileLegend _legend(AppSettings settings) {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) => _StubSettingsNotifier(settings)),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(profileLegendProvider, (_, _) {});
  addTearDown(sub.close);
  return container.read(profileLegendProvider.notifier);
}

void main() {
  test('picking heart rate turns its line on', () {
    final legend = _legend(const AppSettings(defaultShowHeartRate: false));

    legend.setRightAxisMetric(ProfileRightAxisMetric.heartRate);

    expect(legend.state.showHeartRate, isTrue);
    expect(legend.state.rightAxisMetric, ProfileRightAxisMetric.heartRate);
  });

  test('picking temperature turns its line on', () {
    final legend = _legend(const AppSettings(defaultShowTemperature: false));

    legend.setRightAxisMetric(ProfileRightAxisMetric.temperature);

    expect(legend.state.showTemperature, isTrue);
  });

  test('picking pressure shows every tank the diver had hidden', () {
    final legend = _legend(const AppSettings(defaultShowPressure: false));
    legend.toggleTankPressure('tank-1', visibleByDefault: true);
    legend.toggleTankPressure('tank-2', visibleByDefault: false);
    expect(legend.state.showTankPressure['tank-1'], isFalse);

    legend.setRightAxisMetric(ProfileRightAxisMetric.pressure);

    expect(legend.state.showPressure, isTrue);
    expect(legend.state.showTankPressure['tank-1'] ?? true, isTrue);
    expect(legend.state.showTankPressure['tank-2'] ?? true, isTrue);
  });

  test('picking O2 cells draws them in millivolts, the axis unit', () {
    final legend = _legend(
      const AppSettings(
        defaultShowO2CellMv: false,
        o2CellUnit: O2CellUnit.ppO2,
      ),
    );

    legend.setRightAxisMetric(ProfileRightAxisMetric.o2CellMv);

    expect(legend.state.showO2Cells, isTrue);
    expect(legend.state.o2CellUnit, O2CellUnit.millivolts);
  });

  test('picking an Avelo line turns that line on', () {
    final legend = _legend(
      const AppSettings(defaultShowAveloGasRemaining: false),
    );

    legend.setRightAxisMetric(ProfileRightAxisMetric.aveloGasRemaining);

    expect(legend.state.showAveloGasRemaining, isTrue);
  });

  test('clearing the pick leaves the lines as they were', () {
    final legend = _legend(const AppSettings(defaultShowSac: false));

    legend.setRightAxisMetric(null);

    expect(legend.state.showSac, isFalse);
  });
}
