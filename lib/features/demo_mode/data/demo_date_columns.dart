import 'package:drift/drift.dart';

/// How a date column stores its instant.
enum DemoDateUnit { epochMillis, epochSeconds }

/// A column holding an instant, moved by the same amount as every other one
/// when the sample logbook is prepared.
class DemoDateColumn {
  const DemoDateColumn(this.table, this.column, this.unit);

  final String table;
  final String column;
  final DemoDateUnit unit;
}

/// Columns whose names end in `time` (or `_since`, `_until`, `_on`) that hold
/// an instant. Such names are ambiguous, because a duration can end in
/// `time` too, so each one is listed here or in [demoNotDateColumns].
const demoShiftedTimeColumns = {
  'dives.dive_date_time',
  'dives.entry_time',
  'dives.exit_time',
  'dive_plans.start_date_time',
  'gps_tracks.start_time',
  'gps_tracks.end_time',
  'gps_tracks.trim_start_time',
  'gps_tracks.trim_end_time',
  'nav_tracks.start_time',
  'nav_tracks.end_time',
  'tide_records.high_tide_time',
  'tide_records.low_tide_time',
};

/// Date-like columns that are not instants, with the reason.
const demoNotDateColumns = <String, String>{
  'dives.bottom_time': 'a duration in seconds',
  'dives.runtime': 'a duration in seconds',
  'divers.diving_since': 'a calendar year, not an instant',
  'buddies.card_diving_since': 'a calendar year, not an instant',
  'dive_centers.fill_opens_at': 'minutes after local midnight',
  'dive_centers.fill_closes_at': 'minutes after local midnight',
};

final _instantName = RegExp(r'(_at|date|_due)$');

/// Every column in [db] holding an instant: each `DateTimeColumn` (stored as
/// epoch seconds) and each integer column named like an instant (stored as
/// epoch milliseconds, the app's convention), minus [demoNotDateColumns].
///
/// Read from the live schema, so a new `*_at` or `*_date` column is shifted
/// without anyone having to remember this file.
List<DemoDateColumn> demoDateColumnsOf(GeneratedDatabase db) => [
  for (final t in db.allTables)
    for (final c in t.$columns)
      if (_unitOf(t.actualTableName, c) case final unit?)
        DemoDateColumn(t.actualTableName, c.name, unit),
];

DemoDateUnit? _unitOf(String table, GeneratedColumn<Object> c) {
  final key = '$table.${c.name}';
  if (demoNotDateColumns.containsKey(key)) return null;
  if (c.type == DriftSqlType.dateTime) return DemoDateUnit.epochSeconds;
  if (c.type != DriftSqlType.int) return null;
  if (demoShiftedTimeColumns.contains(key) || _instantName.hasMatch(c.name)) {
    return DemoDateUnit.epochMillis;
  }
  return null;
}

/// How far to move the sample logbook so its latest dive lands 7 to 13
/// calendar days before [now], in whole weeks so every weekday, interval and
/// expiry keeps its relation to the others.
Duration demoShiftFor({required DateTime latestDive, required DateTime now}) {
  final days = DateTime.utc(now.year, now.month, now.day)
      .difference(
        DateTime.utc(latestDive.year, latestDive.month, latestDive.day),
      )
      .inDays;
  final weeks = ((days - 13) / 7).ceil();
  return Duration(days: weeks * 7);
}
