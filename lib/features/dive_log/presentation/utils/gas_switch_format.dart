import 'dart:ui';

import 'package:submersion/core/deco/gas_switch/gas_switch_efficiency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Legend chip colour for the late gas switch overlay. The bands themselves
/// take the colour of the gas that should have been breathed.
const Color lateSwitchLegendColor = Color(0xFFFF8F00);

/// A depth delay below this is noise, not a fact worth showing: a switch
/// flagged late by time alone happens at (or within a reading of) the
/// ideal depth.
const double minShownDepthDelayMeters = 0.5;

/// Whether [window] was late by depth as well as by time.
bool hasDepthDelay(GasSwitchWindow window) =>
    (window.depthDelayMeters ?? 0) >= minShownDepthDelayMeters;

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

/// The switch row's value: the gas that should have been breathed. The
/// delay and the extra deco get rows of their own, because a row value only
/// gets half the profile tooltip's capped width.
String lateSwitchTooltipValue(GasSwitchWindow window) =>
    gasSwitchGasLabel(window.fO2, window.fHe);

/// The delay row's value (`m:ss`, plus the depth delay when there is one), or
/// null for a missed switch, which has no switch to be late by.
String? lateSwitchDelayValue(GasSwitchWindow window, UnitFormatter units) {
  if (window.isMissed) return null;
  final delay = formatMinSec(window.delaySeconds);
  if (!hasDepthDelay(window)) return delay;
  return '$delay / ${units.formatDepth(window.depthDelayMeters, decimals: 0)}';
}

/// The extra deco row's value.
String lateSwitchExtraDecoValue(GasSwitchWindow window) =>
    '+${formatMinSec(window.extraDecoSeconds)}';
