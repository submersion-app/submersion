import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/gas_switch_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  const late = GasSwitchWindow(
    kind: GasSwitchWindowKind.late,
    fO2: 0.5,
    fHe: 0,
    idealTimestamp: 1630,
    idealDepth: 21,
    switchTimestamp: 1830,
    switchDepth: 12,
    endTimestamp: 1830,
    delaySeconds: 200,
    depthDelayMeters: 9,
    extraDecoSeconds: 250,
  );

  test('minutes and seconds', () {
    expect(formatMinSec(0), '0:00');
    expect(formatMinSec(200), '3:20');
    expect(formatMinSec(3725), '62:05');
  });

  test('gas labels reuse GasMix names', () {
    expect(gasSwitchGasLabel(0.5, 0), 'EAN50');
    expect(gasSwitchGasLabel(1.0, 0), 'O2');
    expect(gasSwitchGasLabel(0.21, 0.35), 'Tx 21/35');
  });

  test('late tooltip rows in metric and imperial', () {
    const metric = UnitFormatter(AppSettings());
    expect(lateSwitchTooltipLabel(late, l10n), 'Late switch');
    expect(lateSwitchTooltipValue(late), 'EAN50');
    expect(
      lateSwitchDelayValue(late, metric),
      '3:20 / ${metric.formatDepth(9, decimals: 0)}',
    );
    expect(lateSwitchExtraDecoValue(late), '+4:10');
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
    expect(lateSwitchDelayValue(late, imperial), contains('ft'));
  });

  test('a switch late by time only shows no depth delay', () {
    final timeOnly = late.copyWith(delaySeconds: 130, depthDelayMeters: 0.2);
    const metric = UnitFormatter(AppSettings());
    expect(lateSwitchDelayValue(timeOnly, metric), '2:10');
  });

  test('a missed switch has no delay row', () {
    final missed = late.copyWith(kind: GasSwitchWindowKind.missed);
    const metric = UnitFormatter(AppSettings());
    expect(lateSwitchTooltipLabel(missed, l10n), 'Missed switch');
    expect(lateSwitchTooltipValue(missed), 'EAN50');
    expect(lateSwitchDelayValue(missed, metric), isNull);
    expect(lateSwitchExtraDecoValue(missed), '+4:10');
  });

  test('every tooltip value fits the half-width a row value gets', () {
    // The profile tooltip caps rows at 320 px and splits label and value
    // evenly; about 18 monospace characters is what a value can show.
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));
    final worst = late.copyWith(
      fO2: 0.18,
      fHe: 0.45,
      delaySeconds: 3599,
      depthDelayMeters: 30,
      extraDecoSeconds: 3599,
    );
    for (final value in [
      lateSwitchTooltipValue(worst),
      lateSwitchDelayValue(worst, imperial)!,
      lateSwitchExtraDecoValue(worst),
    ]) {
      expect(value.length, lessThanOrEqualTo(18), reason: value);
    }
  });
}
