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
