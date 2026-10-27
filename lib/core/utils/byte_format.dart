import 'package:submersion/core/utils/locale_number_symbols.dart';

/// Formats a byte count for display.
///
/// Bytes are not a diver-facing unit, so this deliberately ignores the active
/// diver's unit settings: a megabyte is a megabyte in metric and imperial
/// alike. Sizes are a floor, since a source that reports no size counts zero.
String formatBytes(int bytes) {
  final (number, unit) = _byteParts(bytes);
  return '$number $unit';
}

/// [formatBytes] for a size placed inside a translated sentence. The decimal
/// mark follows the active locale (`12,5` in French), and [label] joins the
/// number to the unit key (`B`, `KB`, `MB`, `GB` or `TB`) in the language's
/// own words, as `AppLocalizations.common_byteSize` does (`12,5 Mo`).
String formatBytesLocalized(
  int bytes,
  String Function(String number, String unit) label,
) {
  final (number, unit) = _byteParts(bytes);
  return label(localiseNumberSeparators(number), unit);
}

/// The number, rounded and with Dart's '.' decimal point, and its unit key.
(String, String) _byteParts(int bytes) {
  if (bytes <= 0) return ('0', 'B');
  if (bytes < 1024) return ('$bytes', 'B');
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return (value.toStringAsFixed(value >= 10 ? 0 : 1), units[unit]);
}
