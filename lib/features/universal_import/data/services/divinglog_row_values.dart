import 'package:sqlite3/sqlite3.dart';

/// Reads one value out of a Diving Log row.
///
/// Every SELECT aliases the file's own spelling to our canonical column
/// name, so callers ask by the canonical name. A column the file lacks was
/// never selected, and reading it throws rather than returning null, which
/// is why every accessor goes through [rowCell]: a missing column and a
/// null value mean the same thing to a caller.
Object? rowCell(Row row, String column) {
  try {
    return row[column];
  } catch (_) {
    return null;
  }
}

String? rowString(Row row, String column) {
  final v = rowCell(row, column);
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// SQLite is dynamically typed, so a column declared INTEGER can hold a
/// string; parsing the text form is the fallback, not an error path.
int? rowInt(Row row, String column) {
  final v = rowCell(row, column);
  if (v is int) return v;
  if (v is num) return v.toInt();
  return v == null ? null : int.tryParse(v.toString().trim());
}

double? rowDouble(Row row, String column) {
  final v = rowCell(row, column);
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return v == null ? null : double.tryParse(v.toString().trim());
}

/// Reads a `YYYY-MM-DD` date column as a wall clock, per the house
/// convention that stored dive times carry no zone.
///
/// The components are round-tripped because `DateTime.utc` normalises
/// rather than rejects: 30 February would otherwise become 1 March and the
/// record would carry a date the logbook never held.
DateTime? rowDate(Row row, String column) {
  final raw = rowString(row, column);
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 8) return null;
  final year = int.tryParse(digits.substring(0, 4));
  final month = int.tryParse(digits.substring(4, 6));
  final day = int.tryParse(digits.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

/// Reads a Diving Log coordinate column.
///
/// The real export stores these as TEXT in degrees, minutes and seconds
/// with a hemisphere letter, for example `16°27'59.74"S`, not as a decimal
/// number. Reading them as a double returns null and every site silently
/// loses its position, so the DMS form is parsed here and the hemisphere
/// decides the sign. A plain decimal is accepted too, since other versions
/// may store one.
///
/// Returns null beyond plus or minus 180. The caller does not say whether
/// this is a latitude or a longitude, so that is the only bound that can be
/// applied without discarding valid longitudes.
double? parseDivingLogCoordinate(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;

  final dms = RegExp(
    r'''^\s*(\d+(?:\.\d+)?)\s*[°d]\s*(\d+(?:\.\d+)?)\s*['m]?\s*'''
    r'''(?:(\d+(?:\.\d+)?)\s*["s]?)?\s*([NSEW])\s*$''',
    caseSensitive: false,
  ).firstMatch(text);
  if (dms != null) {
    final degrees = double.tryParse(dms.group(1)!);
    final minutes = double.tryParse(dms.group(2)!);
    final seconds = double.tryParse(dms.group(3) ?? '0') ?? 0;
    if (degrees == null || minutes == null) return null;
    // A minute or second at 60 or above is not a coordinate. The outer
    // range check cannot catch it: 19 deg 99' folds into a perfectly
    // plausible 20.65 that would be stored as a real position.
    if (minutes >= 60 || seconds >= 60) return null;
    final magnitude = degrees + minutes / 60 + seconds / 3600;
    final hemisphere = dms.group(4)!.toUpperCase();
    final signed = (hemisphere == 'S' || hemisphere == 'W')
        ? -magnitude
        : magnitude;
    if (!signed.isFinite) return null;
    return signed.abs() > 180 ? null : signed;
  }

  final decimal = double.tryParse(text);
  if (decimal == null) return null;
  // double.tryParse accepts NaN and Infinity, and the range check below
  // cannot reject NaN because every comparison against it is false. A NaN
  // latitude would reach the payload and then evade downstream validation
  // for exactly the same reason, so it is rejected here.
  if (!decimal.isFinite) return null;
  return decimal.abs() > 180 ? null : decimal;
}

/// [parseDivingLogCoordinate] applied to a column.
double? rowCoordinate(Row row, String column) =>
    parseDivingLogCoordinate(rowString(row, column));

/// [value] when it is a real measurement, or null when it is absent or the
/// zero this format uses to mean "not recorded".
///
/// Diving Log writes 0 into optional numeric columns it never filled in, so
/// passing one through states something false: a cylinder that weighs
/// nothing, a site whose maximum depth is the surface. The packed profile
/// columns needed the same rule, where reading their zeros as measurements
/// gave 402 open-circuit dives an oxygen sensor.
double? positiveOrNull(double? value) =>
    value == null || value <= 0 ? null : value;
