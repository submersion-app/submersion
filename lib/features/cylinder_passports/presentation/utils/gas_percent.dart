import 'package:submersion/core/utils/number_display.dart';

/// An analysed gas fraction as the diver logged it: a whole number stays
/// whole ("32%"), anything else keeps one decimal in the locale's
/// convention ("40.4%", "40,4 %" style separators), so a reading just over a
/// threshold is never shown as the threshold itself.
String formatGasPercent(double value) => '${formatGasPercentValue(value)}%';

/// [formatGasPercent] without the sign, for a mix whose two gases share
/// one ("18.5/45%").
String formatGasPercentValue(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : formatFixedForDisplay(value, 1);
