import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// The version of a dive a device-local cache was built from, as one SQL
/// expression over the dive alias [dive]: the dive's own `updated_at`, plus
/// the `updated_at` of every one of its profile and tank-pressure series,
/// plus the clock of every one of its tanks.
///
/// The series and the tanks are synced child rows that never re-stamp their
/// dive (#1769), so a change to them arriving by sync leaves
/// `dives.updated_at` alone. A cache keyed on the dive's stamp alone would
/// keep calling a row built from the old children current.
///
/// A sum, not the latest of them: a child change that arrives by sync can
/// carry a time older than the dive's own (the profile rewritten on one
/// device, the dive's buddy edited later on another, then a sync), and the
/// latest would not move. The sum moves on any write that moves one of its
/// terms, and on adding or removing a child. It is a version token, not a
/// time: compare it only for equality.
///
/// `dive_tanks` has no `updated_at`, so a tank counts through its `hlc`
/// (see `Hlc.toString`: a 15-digit physical time, a colon, a 6-digit
/// counter, the node). Staging a tank for sync stamps a new one, and a
/// synced copy brings its own, so a tank row that arrives alone still moves
/// the stamp. A writer that changes a tank without staging it must re-stamp
/// the dive instead (the dive editor and the bulk tank edits do), or the
/// stamp does not move. The physical times and the counters are
/// summed apart: packed into one number a tank's clock is near 2e18, and a
/// few of them would overflow SQLite's 64-bit integers. A tank with no clock
/// adds nothing.
///
/// Every writer and reader of one cache must use this same expression: a row
/// written with it and compared against the bare `updated_at` reads as stale
/// for good. The sensor summaries and the Explore derived metrics both do.
String diveSourceStampSql([String dive = 'd']) =>
    '($dive.updated_at + '
    'COALESCE((SELECT SUM(stamp_p.updated_at) '
    'FROM dive_profile_series stamp_p WHERE stamp_p.dive_id = $dive.id), 0) + '
    'COALESCE((SELECT SUM(stamp_t.updated_at) '
    'FROM tank_pressure_series stamp_t WHERE stamp_t.dive_id = $dive.id), 0) + '
    'COALESCE((SELECT SUM(CAST(substr(stamp_k.hlc, 1, 15) AS INTEGER)) + '
    'SUM(CAST(substr(stamp_k.hlc, 17, 6) AS INTEGER)) '
    'FROM dive_tanks stamp_k WHERE stamp_k.dive_id = $dive.id), 0))';

/// The tables [diveSourceStampSql] reads besides the cache's own, for a
/// query's `readsFrom`.
Set<ResultSetImplementation<dynamic, dynamic>> diveSourceStampTables(
  AppDatabase db,
) => {db.dives, db.diveProfileSeries, db.tankPressureSeries, db.diveTanks};

/// [diveSourceStampSql] for one dive, or null when [diveId] does not exist.
Future<int?> readDiveSourceStamp(AppDatabase db, String diveId) async {
  final row = await db
      .customSelect(
        'SELECT ${diveSourceStampSql()} AS stamp FROM dives d WHERE d.id = ?',
        variables: [Variable.withString(diveId)],
        readsFrom: diveSourceStampTables(db),
      )
      .getSingleOrNull();
  return row?.read<int>('stamp');
}
