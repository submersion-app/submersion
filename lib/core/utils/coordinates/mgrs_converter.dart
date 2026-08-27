import 'package:submersion/core/utils/coordinates/utm_converter.dart';

/// Column letters for the 100 km squares, cycling every three zones. I and O
/// are omitted throughout MGRS to avoid confusion with 1 and 0.
const String _columnLetters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

/// Row letters, cycling every 2000 km of northing.
const String _rowLetters = 'ABCDEFGHJKLMNPQRSTUV';

/// Valid latitude band letters.
const String _bandLetters = 'CDEFGHJKLMNPQRSTUVWX';

/// Formats a coordinate as an MGRS grid reference at 1 m precision.
///
/// Returns the grouped form (`16Q DH 96898 51535`), which is how a reference
/// is read aloud. Null outside the UTM latitude band.
String? latLngToMgrs(double latitude, double longitude) {
  final utm = latLngToUtm(latitude, longitude);
  if (utm == null) return null;

  final columnIndex = ((utm.zone - 1) % 3) * 8 + (utm.easting ~/ 100000) - 1;
  final column = _columnLetters[columnIndex];

  var rowIndex = (utm.northing ~/ 100000) % 20;
  // Even-numbered zones start their row lettering half an alphabet along, so
  // adjacent zones never present the same letter pair at the same latitude.
  if (utm.zone.isEven) rowIndex = (rowIndex + 5) % 20;
  final row = _rowLetters[rowIndex];

  // A grid reference names a square and is identified by its south-west
  // corner, so the residual metres truncate. Rounding would name the wrong
  // square for any coordinate in the upper half of one.
  final eastingDigits = (utm.easting % 100000).floor().toString().padLeft(
    5,
    '0',
  );
  final northingDigits = (utm.northing % 100000).floor().toString().padLeft(
    5,
    '0',
  );

  return '${utm.zone}${utm.band} $column$row $eastingDigits $northingDigits';
}

final RegExp _mgrsPattern = RegExp(
  r'^(\d{1,2})([C-HJ-NP-X])([A-HJ-NP-Z])([A-HJ-NP-V])(\d+)$',
  caseSensitive: false,
);

/// Parses an MGRS grid reference back to WGS84 degrees.
///
/// Accepts grouped or run-together input in any case. Returns the square's
/// south-west corner rather than its centre, matching the reference's own
/// definition, so a format-then-parse round trip lands within one square of
/// the original.
({double latitude, double longitude})? mgrsToLatLng(String reference) {
  final cleaned = reference.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  final match = _mgrsPattern.firstMatch(cleaned);
  if (match == null) return null;

  final zone = int.parse(match.group(1)!);
  if (zone < 1 || zone > 60) return null;
  final band = match.group(2)!;
  if (!_bandLetters.contains(band)) return null;
  final column = match.group(3)!;
  final row = match.group(4)!;
  final digits = match.group(5)!;
  // A reference carries the same number of easting and northing digits.
  if (digits.isEmpty || digits.length.isOdd || digits.length > 10) return null;

  final half = digits.length ~/ 2;
  final precision = 100000 ~/ _pow10(half);
  final eastingRemainder = int.parse(digits.substring(0, half)) * precision;
  final northingRemainder = int.parse(digits.substring(half)) * precision;

  final columnIndex = _columnLetters.indexOf(column);
  if (columnIndex < 0) return null;
  var rowIndex = _rowLetters.indexOf(row);
  if (rowIndex < 0) return null;
  if (zone.isEven) rowIndex = rowIndex - 5;
  if (rowIndex < 0) rowIndex += 20;

  final easting =
      ((columnIndex - ((zone - 1) % 3) * 8 + 1) * 100000).toDouble() +
      eastingRemainder;

  // The row letters repeat every 2000 km, so the band's own latitude range
  // decides which repetition is meant.
  final bandMinNorthing = _minimumNorthingForBand(band);
  var northing = rowIndex * 100000.0 + northingRemainder;
  while (northing < bandMinNorthing) {
    northing += 2000000.0;
  }

  return utmToLatLng(zone, band, easting, northing);
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}

/// The smallest northing that can occur in a latitude band, used to resolve
/// which 2000 km repetition of the row letters a reference means.
double _minimumNorthingForBand(String band) {
  final index = _bandLetters.indexOf(band);
  // Bands are 8 degrees tall starting at 80S; X is 12 degrees but its lower
  // edge follows the same rule.
  final southEdge = -80.0 + index * 8.0;
  final utm = latLngToUtm(southEdge, 0);
  if (utm == null) return 0;
  // Round down to a whole 100 km square so the comparison is conservative.
  return (utm.northing / 100000).floor() * 100000.0;
}
