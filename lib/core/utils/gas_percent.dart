import 'package:submersion/core/utils/number_display.dart';

/// An analysed gas fraction as the diver logged it: a whole number stays
/// whole ("32%"), anything else keeps one decimal with the locale's
/// decimal separator ("40.4%", or "40,4%" under de), so a reading just over
/// a threshold is never shown as the threshold itself.
String formatGasPercent(double value) => '${formatGasPercentValue(value)}%';

/// [fraction] of a gas as the percentage a gas column stores, without the
/// float noise of a bare multiplication (0.29 * 100 is 28.999999999999996).
double gasPercentOfFraction(double fraction) => (fraction * 1e6).round() / 1e4;

/// [formatGasPercent] without the sign, for a mix whose two gases share
/// one ("18.5/45%"). A non-finite value renders as text rather than
/// throwing: `round()` cannot convert infinity to an int.
String formatGasPercentValue(double value) =>
    value.isFinite && value == value.roundToDouble()
    ? '${value.round()}'
    : formatFixedForDisplay(value, 1);
