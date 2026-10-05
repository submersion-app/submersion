import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    ),
  );
  const metric = UnitFormatter(AppSettings());

  test('an imperial RMV threshold converts to litres per minute', () {
    const u = FocusMetricUnits(FocusMetric.rmv, imperial);
    expect(u.toStorage(0.75), closeTo(21.24, 0.01));
    expect(u.toDisplay(u.toStorage(0.75)), closeTo(0.75, 1e-9));
  });

  test('a Fahrenheit water temp converts to Celsius', () {
    const u = FocusMetricUnits(FocusMetric.waterTemp, imperial);
    expect(u.toStorage(50), closeTo(10, 1e-9));
  });

  test('depth in feet converts to metres', () {
    expect(
      const FocusMetricUnits(FocusMetric.maxDepth, imperial).toStorage(100),
      closeTo(30.48, 1e-6),
    );
  });

  test('bottom time is minutes in every unit system', () {
    expect(
      const FocusMetricUnits(FocusMetric.bottomTime, imperial).toStorage(40),
      40,
    );
    expect(
      const FocusMetricUnits(FocusMetric.bottomTime, metric).toStorage(40),
      40,
    );
  });

  test('only water temp may go below zero', () {
    for (final m in FocusMetric.values) {
      expect(
        FocusMetricUnits(m, metric).allowsNegative,
        m == FocusMetric.waterTemp,
      );
    }
  });
}
