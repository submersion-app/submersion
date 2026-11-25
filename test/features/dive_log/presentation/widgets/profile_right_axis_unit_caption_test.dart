import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_metric_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The profile chart's right caption names only the right axis's unit, which
/// is all the narrow caption above the tick column has room for (#5013).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      pressureUnit: PressureUnit.psi,
      temperatureUnit: TemperatureUnit.fahrenheit,
    ),
  );

  String caption(ProfileRightAxisMetric m, UnitFormatter units) =>
      rightAxisUnitCaption(m, units, l10n);

  test('metric units give the bare symbol', () {
    expect(caption(ProfileRightAxisMetric.temperature, metric), '°C');
    expect(caption(ProfileRightAxisMetric.pressure, metric), 'bar');
    expect(caption(ProfileRightAxisMetric.meanDepth, metric), 'm');
    expect(caption(ProfileRightAxisMetric.sac, metric), 'bar/min');
    expect(caption(ProfileRightAxisMetric.ascentRate, metric), 'm/min');
    expect(caption(ProfileRightAxisMetric.heartRate, metric), 'bpm');
    expect(caption(ProfileRightAxisMetric.cns, metric), '%');
  });

  test('imperial units follow the diver settings', () {
    expect(caption(ProfileRightAxisMetric.pressure, imperial), 'psi');
    expect(caption(ProfileRightAxisMetric.meanDepth, imperial), 'ft');
    expect(caption(ProfileRightAxisMetric.temperature, imperial), '°F');
    expect(caption(ProfileRightAxisMetric.ascentRate, imperial), 'ft/min');
  });

  test('a metric without a unit falls back to its short name', () {
    expect(caption(ProfileRightAxisMetric.otu, metric), 'OTU');
    expect(caption(ProfileRightAxisMetric.o2CellMv, metric), 'Cells');
  });
}
