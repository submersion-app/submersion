import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_metric_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The profile chart's right caption names the right axis's unit, which is
/// all the caption above the tick column needs, and adds the metric's short
/// name only when that unit alone would not tell the axis apart (#5013).
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

  test('a unit no other axis uses stands alone', () {
    expect(caption(ProfileRightAxisMetric.temperature, metric), '°C');
    expect(caption(ProfileRightAxisMetric.sac, metric), 'bar/min');
    expect(caption(ProfileRightAxisMetric.ascentRate, metric), 'm/min');
    expect(caption(ProfileRightAxisMetric.heartRate, metric), 'bpm');
    expect(caption(ProfileRightAxisMetric.temperature, imperial), '°F');
    expect(caption(ProfileRightAxisMetric.ascentRate, imperial), 'ft/min');
  });

  test('a unit shared with another right-axis metric gains the name', () {
    // Tank pressure and the partial pressures all read in bar.
    expect(caption(ProfileRightAxisMetric.pressure, metric), 'Press bar');
    expect(caption(ProfileRightAxisMetric.ppO2, metric), 'ppO2 bar');
    expect(caption(ProfileRightAxisMetric.ppN2, metric), 'ppN2 bar');
    // NDL, TTS and GTR all read in minutes; CNS and the gas left in percent.
    expect(caption(ProfileRightAxisMetric.ndl, metric), 'NDL min');
    expect(caption(ProfileRightAxisMetric.gtr, metric), 'GTR min');
    expect(caption(ProfileRightAxisMetric.cns, metric), 'CNS %');
  });

  test('a unit shared with the depth axis gains the name', () {
    expect(caption(ProfileRightAxisMetric.meanDepth, metric), 'Mean m');
    expect(caption(ProfileRightAxisMetric.meanDepth, imperial), 'Mean ft');
  });

  test('sharing follows the diver units', () {
    // In psi, tank pressure no longer shares its unit with ppO2 (bar).
    expect(caption(ProfileRightAxisMetric.pressure, imperial), 'psi');
    expect(caption(ProfileRightAxisMetric.ppO2, imperial), 'ppO2 bar');
  });

  test('a short name that already carries the unit is not doubled', () {
    expect(caption(ProfileRightAxisMetric.gf, metric), 'GF%');
  });

  test('a metric without a unit falls back to its short name', () {
    expect(caption(ProfileRightAxisMetric.otu, metric), 'OTU');
    expect(caption(ProfileRightAxisMetric.o2CellMv, metric), 'Cells');
  });
}
