import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// Formats a CCR setpoint switch depth (meters) in the diver's depth unit.
///
/// A whole number of the display unit shows without a decimal ("10m",
/// "30ft") and anything else with one ("10.5m"), instead of rounding a
/// typed value away in the label.
String formatSwitchDepth(UnitFormatter units, double meters) {
  final shown = units.convertDepth(meters);
  // Decided on the one-decimal value that would be shown, so 9.95 reads as
  // "10" and never as "10.0".
  final whole = (shown * 10).round() % 10 == 0;
  return '${formatFixedForDisplay(shown, whole ? 0 : 1)}${units.depthSymbol}';
}
