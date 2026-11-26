import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// Formats a CCR setpoint switch depth (meters) in the diver's depth unit.
///
/// The stored value sits on a 0.1 m grid, so a whole number of the display
/// unit shows without a decimal ("10m", "33ft") and anything else with one
/// ("10.5m"), instead of rounding a typed value away in the label.
String formatSwitchDepth(UnitFormatter units, double meters) {
  final shown = units.convertDepth(meters);
  final whole = (shown - shown.roundToDouble()).abs() < 0.05;
  return '${formatFixedForDisplay(shown, whole ? 0 : 1)}${units.depthSymbol}';
}
