import 'package:submersion/core/utils/coordinates/mgrs_converter.dart';
import 'package:submersion/core/utils/coordinates/utm_converter.dart';

/// An MGRS reference: zone, band, two square letters, then an even run of
/// digits. Checked before UTM because both begin with a zone and a band.
final RegExp _mgrsShape = RegExp(
  r'^\d{1,2}[C-HJ-NP-X][A-HJ-NP-Z][A-HJ-NP-V]\d+$',
  caseSensitive: false,
);

/// A UTM reference: zone, band, easting, northing, with optional E/N marks.
final RegExp _utmShape = RegExp(
  r'^(\d{1,2})\s*([C-HJ-NP-X])\s+(\d+(?:\.\d+)?)\s*E?[\s,]+(\d+(?:\.\d+)?)\s*N?$',
  caseSensitive: false,
);

/// Any run of digits with an optional decimal part.
final RegExp _number = RegExp(r'\d+(?:\.\d+)?');

/// Parses a coordinate pair from free text in any supported notation.
///
/// Deliberately independent of the diver's display preference: text arrives
/// from dive guides, messages, and chartplotter screens in whatever notation
/// its author used, and rejecting a valid coordinate because it is not the
/// currently selected format would be hostile.
///
/// Returns null rather than throwing; partially typed input is a normal
/// state while editing, not an error.
({double latitude, double longitude})? parseCoordinates(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (_mgrsShape.hasMatch(trimmed.replaceAll(RegExp(r'\s+'), ''))) {
    return mgrsToLatLng(trimmed);
  }

  final utmMatch = _utmShape.firstMatch(trimmed);
  if (utmMatch != null) {
    final zone = int.parse(utmMatch.group(1)!);
    final band = utmMatch.group(2)!.toUpperCase();
    if (zone < 1 || zone > 60) return null;
    final result = utmToLatLng(
      zone,
      band,
      double.parse(utmMatch.group(3)!),
      double.parse(utmMatch.group(4)!),
    );
    if (!_inRange(result.latitude, result.longitude)) return null;
    return result;
  }

  return _parseDegreeFamily(trimmed);
}

/// Parses a single axis, used by the per-axis sub-fields of the input widget.
double? parseSingleAxis(String input, {required bool isLatitude}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final value = _parseAxisText(trimmed, isLatitude: isLatitude);
  if (value == null) return null;
  final limit = isLatitude ? 90.0 : 180.0;
  if (value.abs() > limit) return null;
  return value;
}

/// Splits free text into a latitude half and a longitude half, then parses
/// each as degrees, degrees-minutes, or degrees-minutes-seconds.
({double latitude, double longitude})? _parseDegreeFamily(String input) {
  final normalized = input
      .replaceAll('′', "'") // prime
      .replaceAll('″', '"') // double prime
      .replaceAll('´', "'")
      .replaceAll('’', "'");

  final halves = _splitHalves(normalized);
  if (halves == null) return null;

  final latitude = _parseAxisText(halves.$1, isLatitude: true);
  final longitude = _parseAxisText(halves.$2, isLatitude: false);
  if (latitude == null || longitude == null) return null;
  if (!_inRange(latitude, longitude)) return null;
  return (latitude: latitude, longitude: longitude);
}

(String, String)? _splitHalves(String input) {
  final commaIndex = input.indexOf(',');
  if (commaIndex > 0) {
    final first = input.substring(0, commaIndex);
    final second = input.substring(commaIndex + 1);
    if (_number.hasMatch(first) && _number.hasMatch(second)) {
      return (first, second);
    }
  }

  final numbers = _number.allMatches(input).toList();
  if (numbers.length < 2 || numbers.length.isOdd) return null;

  // A trailing N or S ends the latitude half -- but only once a number has
  // been seen. In 'N20.36 W87.02' the leading N introduces the latitude
  // rather than terminating it, and splitting there would leave a half with
  // no number in it at all.
  final firstNumberEnd = numbers.first.end;
  for (final match in RegExp(r'[NSns]\s*(?=[\d\-+EWew])').allMatches(input)) {
    if (match.start < firstNumberEnd) continue;
    return (input.substring(0, match.end), input.substring(match.end));
  }

  // Otherwise split evenly on the numbers present.
  var splitAt = numbers[numbers.length ~/ 2].start;
  // Carry any sign or hemisphere letter that immediately precedes the second
  // half into that half. Both qualify the number that follows them, so
  // leaving them behind corrupts the first half instead: '20.36 -87.02'
  // would read as a negative latitude, and 'N20.36 W87.02' would put a W in
  // the latitude.
  const carried = {'-', '+', 'N', 'S', 'E', 'W', 'n', 's', 'e', 'w'};
  while (splitAt > 0 && carried.contains(input[splitAt - 1])) {
    splitAt -= 1;
  }
  return (input.substring(0, splitAt), input.substring(splitAt));
}

/// Parses one axis expressed as degrees, degrees and minutes, or degrees,
/// minutes and seconds, with the sign taken from a hemisphere letter or a
/// leading minus.
double? _parseAxisText(String text, {required bool isLatitude}) {
  final upper = text.toUpperCase();
  final negative =
      upper.contains(isLatitude ? 'S' : 'W') || upper.contains('-');
  if (isLatitude && (upper.contains('E') || upper.contains('W'))) return null;
  if (!isLatitude && (upper.contains('N') || upper.contains('S'))) return null;

  final parts = _number
      .allMatches(text)
      .map((m) => double.parse(m.group(0)!))
      .toList();
  if (parts.isEmpty || parts.length > 3) return null;

  final degrees = parts[0];
  final minutes = parts.length > 1 ? parts[1] : 0.0;
  final seconds = parts.length > 2 ? parts[2] : 0.0;
  // 60 minutes or 60 seconds is a misread, not a coordinate.
  if (minutes >= 60 || seconds >= 60) return null;
  if (parts.length > 1 && degrees != degrees.floorToDouble()) return null;

  final magnitude = degrees + minutes / 60 + seconds / 3600;
  return negative ? -magnitude : magnitude;
}

bool _inRange(double latitude, double longitude) =>
    latitude.abs() <= 90 && longitude.abs() <= 180;
