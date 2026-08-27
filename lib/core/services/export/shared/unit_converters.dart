import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';

/// Format a date according to the user's preferred format.
///
/// Reads the pattern off the enum rather than restating it: a switch here
/// drifted out of step with [DateFormatPreference.pattern] the moment a
/// seventh preference was considered.
String formatDateForExport(DateTime date, DateFormatPreference format) =>
    DateFormat(format.pattern).format(date);

/// Convert a depth from meters to the target unit, returning a formatted string.
String convertDepth(double? depthMeters, DepthUnit targetUnit) {
  if (depthMeters == null) return '';
  final converted = DepthUnit.meters.convert(depthMeters, targetUnit);
  return converted.toStringAsFixed(1);
}

/// Convert a temperature from Celsius to the target unit, returning a formatted string.
String convertTemperature(double? tempCelsius, TemperatureUnit targetUnit) {
  if (tempCelsius == null) return '';
  final converted = TemperatureUnit.celsius.convert(tempCelsius, targetUnit);
  return converted.toStringAsFixed(0);
}

/// Convert a pressure from bar to the target unit, returning a formatted string.
String convertPressure(double? pressureBar, PressureUnit targetUnit) {
  if (pressureBar == null) return '';
  final converted = PressureUnit.bar.convert(pressureBar, targetUnit);
  return converted.toStringAsFixed(0);
}

/// Convert a volume from liters to the target unit, returning a formatted string.
String convertVolume(double? volumeLiters, VolumeUnit targetUnit) {
  if (volumeLiters == null) return '';
  final converted = VolumeUnit.liters.convert(volumeLiters, targetUnit);
  return converted.toStringAsFixed(1);
}
