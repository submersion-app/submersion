import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';

/// Format a date according to the user's preferred format.
String formatDateForExport(DateTime date, DateFormatPreference format) {
  switch (format) {
    case DateFormatPreference.mmddyyyy:
      return DateFormat('MM/dd/yyyy').format(date);
    case DateFormatPreference.ddmmyyyy:
      return DateFormat('dd/MM/yyyy').format(date);
    case DateFormatPreference.yyyymmdd:
      return DateFormat('yyyy-MM-dd').format(date);
    case DateFormatPreference.mmmDYYYY:
      return DateFormat('MMM d, yyyy').format(date);
    case DateFormatPreference.dMMMYYYY:
      return DateFormat('d MMM yyyy').format(date);
  }
}

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
