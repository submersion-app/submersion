import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/presentation/formatters/focus_metric_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();
  const metric = AppSettings();
  const imperial = AppSettings(
    depthUnit: DepthUnit.feet,
    volumeUnit: VolumeUnit.cubicFeet,
    temperatureUnit: TemperatureUnit.fahrenheit,
    altitudeUnit: AltitudeUnit.feet,
  );
  FocusMetricUnits units(FocusMetric m, AppSettings s) =>
      FocusMetricUnits(m, UnitFormatter(s));

  test('every metric has a symbol and round-trips through display', () {
    for (final m in FocusMetric.values) {
      for (final s in [metric, imperial]) {
        final u = units(m, s);
        expect(u.symbol(l10n), isNotNull, reason: '$m');
        expect(
          u.toStorage(u.toDisplay(12.5)),
          closeTo(12.5, 1e-6),
          reason: '$m',
        );
        expect(u.format(12.5, l10n), isNotEmpty, reason: '$m');
      }
    }
  });

  test('imperial visibility, altitude and gas used store metric', () {
    expect(
      units(FocusMetric.visibility, imperial).toStorage(100),
      closeTo(30.48, 0.01),
    );
    expect(
      units(FocusMetric.altitude, imperial).toStorage(1000),
      closeTo(304.8, 0.1),
    );
    expect(
      units(FocusMetric.gasUsed, imperial).toStorage(10),
      closeTo(283.17, 0.1),
    );
  });

  test('surface interval formats as hours and minutes', () {
    expect(
      units(FocusMetric.surfaceInterval, metric).format(95, l10n),
      '1h 35m',
    );
    expect(
      units(FocusMetric.surfaceInterval, metric).format(45, l10n),
      '45 min',
    );
  });

  test('cns and otu are unitless percent and count', () {
    expect(units(FocusMetric.cns, metric).format(37.4, l10n), '37%');
    expect(units(FocusMetric.otu, metric).format(120.6, l10n), '121');
  });

  test('only the two temperatures allow a negative threshold', () {
    for (final m in FocusMetric.values) {
      expect(
        units(m, metric).allowsNegative,
        m == FocusMetric.waterTemp || m == FocusMetric.airTemp,
        reason: '$m',
      );
    }
  });

  test('metrics are grouped and gas metrics are lower-is-better', () {
    expect(FocusMetric.gasUsed.group, FocusMetricGroup.gas);
    expect(FocusMetric.surfaceInterval.group, FocusMetricGroup.depthTime);
    expect(FocusMetric.cns.group, FocusMetricGroup.exposure);
    expect(FocusMetric.values.where((m) => m.lowerIsBetter).toList(), [
      FocusMetric.rmv,
      FocusMetric.sac,
      FocusMetric.gasUsed,
    ]);
  });
}
