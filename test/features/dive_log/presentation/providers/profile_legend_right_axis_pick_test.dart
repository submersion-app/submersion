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

  test('every metric turns on its own line and no other', () {
    // Each metric's toggle, read off the legend. A metric picked from the
    // axis menu must turn on exactly this one.
    final toggles = <ProfileRightAxisMetric, bool Function(ProfileLegendState)>{
      ProfileRightAxisMetric.temperature: (s) => s.showTemperature,
      ProfileRightAxisMetric.pressure: (s) => s.showPressure,
      ProfileRightAxisMetric.heartRate: (s) => s.showHeartRate,
      ProfileRightAxisMetric.sac: (s) => s.showSac,
      ProfileRightAxisMetric.ascentRate: (s) => s.showAscentRateLine,
      ProfileRightAxisMetric.ndl: (s) => s.showNdl,
      ProfileRightAxisMetric.ppO2: (s) => s.showPpO2,
      ProfileRightAxisMetric.ppN2: (s) => s.showPpN2,
      ProfileRightAxisMetric.ppHe: (s) => s.showPpHe,
      ProfileRightAxisMetric.gasDensity: (s) => s.showDensity,
      ProfileRightAxisMetric.gf: (s) => s.showGf,
      ProfileRightAxisMetric.surfaceGf: (s) => s.showSurfaceGf,
      ProfileRightAxisMetric.meanDepth: (s) => s.showMeanDepth,
      ProfileRightAxisMetric.tts: (s) => s.showTts,
      ProfileRightAxisMetric.cns: (s) => s.showCns,
      ProfileRightAxisMetric.otu: (s) => s.showOtu,
      ProfileRightAxisMetric.o2CellMv: (s) => s.showO2Cells,
      ProfileRightAxisMetric.gtr: (s) => s.showGtr,
      ProfileRightAxisMetric.buoyancy: (s) => s.showBuoyancy,
      ProfileRightAxisMetric.aveloBuoyancy: (s) => s.showAveloBuoyancy,
      ProfileRightAxisMetric.aveloGasRemaining: (s) => s.showAveloGasRemaining,
      ProfileRightAxisMetric.computerRmv: (s) => s.showComputerRmv,
      ProfileRightAxisMetric.trim: (s) => s.showTrim,
    };
    expect(toggles.keys, unorderedEquals(ProfileRightAxisMetric.values));

    // Every line off, so each pick's effect shows alone.
    const allOff = AppSettings(
      defaultShowTemperature: false,
      defaultShowPressure: false,
      defaultShowHeartRate: false,
      defaultShowSac: false,
      defaultShowAscentRateLine: false,
      showNdlOnProfile: false,
      defaultShowPpO2: false,
      defaultShowPpN2: false,
      defaultShowPpHe: false,
      defaultShowGasDensity: false,
      defaultShowGf: false,
      defaultShowSurfaceGf: false,
      defaultShowMeanDepth: false,
      defaultShowTts: false,
      defaultShowCns: false,
      defaultShowOtu: false,
      defaultShowO2CellMv: false,
      defaultShowGtr: false,
      defaultShowBuoyancy: false,
      defaultShowAveloBuoyancy: false,
      defaultShowAveloGasRemaining: false,
      defaultShowComputerRmv: false,
    );

    for (final picked in ProfileRightAxisMetric.values) {
      final legend = _legend(allOff);
      legend.setRightAxisMetric(picked);
      for (final MapEntry(key: metric, value: isOn) in toggles.entries) {
        expect(
          isOn(legend.state),
          metric == picked,
          reason: 'picking ${picked.name}, ${metric.name}',
        );
      }
    }
  });

  test('clearing the pick leaves the lines as they were', () {
    final legend = _legend(const AppSettings(defaultShowSac: false));

    legend.setRightAxisMetric(null);

    expect(legend.state.showSac, isFalse);
  });
}
