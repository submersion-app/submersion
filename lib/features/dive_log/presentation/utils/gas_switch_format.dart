import 'dart:ui';

import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Legend chip colour for the late gas switch overlay. The bands themselves
/// take the colour of the gas that should have been breathed.
const Color lateSwitchLegendColor = Color(0xFFFF8F00);

/// `m:ss`, the profile tooltip's own time format.
String formatMinSec(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

String gasSwitchGasLabel(double fO2, double fHe) =>
    GasMix(o2: fO2 * 100, he: fHe * 100).name;

String lateSwitchTooltipLabel(GasSwitchWindow window, AppLocalizations l10n) =>
    window.isMissed
    ? l10n.diveLog_tooltip_missedSwitch
    : l10n.diveLog_tooltip_lateSwitch;

String lateSwitchTooltipValue(
  GasSwitchWindow window,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  final gas = gasSwitchGasLabel(window.fO2, window.fHe);
  final extra = formatMinSec(window.extraDecoSeconds);
  if (window.isMissed) {
    return l10n.diveLog_tooltip_missedSwitchValue(gas, extra);
  }
  return l10n.diveLog_tooltip_lateSwitchValue(
    gas,
    formatMinSec(window.delaySeconds),
    units.formatDepth(window.depthDelayMeters, decimals: 0),
    extra,
  );
}
