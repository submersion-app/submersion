import 'package:drift/drift.dart';

/// The offset from UTC in force at an instant, given as a UTC epoch in
/// milliseconds. Tests pass a fixed zone; the default is the device's.
typedef UtcOffsetAt = Duration Function(int epochMs);

Duration _deviceOffsetAt(int epochMs) =>
    DateTime.fromMillisecondsSinceEpoch(epochMs).timeZoneOffset;

/// Converts a true local epoch to the wall-clock-as-UTC convention: the
/// same clock reading, stored as if it were UTC.
///
///   UTC+8: local 8:42 = 0:42 UTC epoch.  +8 h = 8:42 UTC.
///   UTC-4: local 8:42 = 12:42 UTC epoch. -4 h = 8:42 UTC.
///
/// The offset is the one in force at that instant, not today's, so in a
/// daylight saving zone a dive from the other half of the year keeps its
/// clock reading instead of moving by an hour (issue #3656).
int localEpochToWallClockUtc(
  int localEpochMs, {
  UtcOffsetAt offsetAt = _deviceOffsetAt,
}) => localEpochMs + offsetAt(localEpochMs).inMilliseconds;

/// v49: moves every dive without an import version (manual and wearable
/// dives, which stored a true local epoch) to the wall-clock-as-UTC
/// convention, and marks it with import version 1. Each of a dive's
/// timestamps is shifted by the offset at its own instant, so this runs row
/// by row rather than as one UPDATE. Returns how many dives changed.
Future<int> shiftLocalDiveTimesToWallClockUtc(
  DatabaseConnectionUser db, {
  UtcOffsetAt offsetAt = _deviceOffsetAt,
}) async {
  final rows = await db
      .customSelect(
        'SELECT id, dive_date_time, entry_time, exit_time FROM dives '
        'WHERE import_version IS NULL',
      )
      .get();
  int? shift(int? epochMs) => epochMs == null
      ? null
      : localEpochToWallClockUtc(epochMs, offsetAt: offsetAt);
  for (final row in rows) {
    await db.customStatement(
      'UPDATE dives SET dive_date_time = ?, entry_time = ?, exit_time = ?, '
      'import_version = 1 WHERE id = ?',
      [
        // Nullable like the others: a damaged row must not fail the upgrade.
        shift(row.readNullable<int>('dive_date_time')),
        shift(row.readNullable<int>('entry_time')),
        shift(row.readNullable<int>('exit_time')),
        row.read<String>('id'),
      ],
    );
  }
  return rows.length;
}
