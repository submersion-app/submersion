import 'package:submersion/core/utils/number_display.dart';

/// An analysed gas fraction as the diver logged it: a whole number stays
/// whole ("32%"), anything else keeps one decimal with the locale's
/// decimal separator ("40.4%", or "40,4%" under de), so a reading just over
/// a threshold is never shown as the threshold itself.
String formatGasPercent(double value) => '${formatGasPercentValue(value)}%';

/// [formatGasPercent] without the sign, for a mix whose two gases share
/// one ("18.5/45%"). A non-finite value renders as text rather than
/// throwing: `round()` cannot convert infinity to an int.
String formatGasPercentValue(double value) =>
    value.isFinite && value == value.roundToDouble()
    ? '${value.round()}'
    : formatFixedForDisplay(value, 1);
