import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/utils/gas_consumption_tooltip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The profile chart has one consumption curve, computed in bar/min. The
/// tooltip shows RMV only when the diver displays that lane alone and a
/// cylinder volume exists to convert with; otherwise the native SAC lane.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  ({String label, String value}) row(
    GasConsumptionDisplay display, {
    double? tankVolume = 12.0,
  }) => gasConsumptionTooltipRow(
    l10n: l10n,
    units: units,
    display: display,
    sacBarPerMin: 1.47,
    tankVolume: tankVolume,
  );

  test('SAC-only shows the pressure lane', () {
    expect(row(GasConsumptionDisplay.sac), (
      label: 'SAC',
      value: '1.5 bar/min',
    ));
  });

  test('both shows the native pressure lane (one curve, one lane)', () {
    expect(row(GasConsumptionDisplay.both), (
      label: 'SAC',
      value: '1.5 bar/min',
    ));
  });

  test('RMV-only converts by the tank volume', () {
    // 1.47 bar/min * 12 L = 17.64 L/min
    expect(row(GasConsumptionDisplay.rmv), (label: 'RMV', value: '17.6 L/min'));
  });

  test('RMV-only without a volume falls back to SAC', () {
    expect(row(GasConsumptionDisplay.rmv, tankVolume: null), (
      label: 'SAC',
      value: '1.5 bar/min',
    ));
  });
}
