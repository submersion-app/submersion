import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// The version of a dive a device-local cache was built from, as one SQL
/// expression over the dive alias [dive]: the dive's own `updated_at` plus
/// the `updated_at` of every one of its profile and tank-pressure series.
///
/// The series are synced child rows that never re-stamp their dive (#1769),
/// so a profile or pressure change arriving by sync leaves `dives.updated_at`
/// alone. A cache keyed on the dive's stamp alone would keep calling a row
/// built from the old series current.
///
/// A sum, not the latest of them: a series change that arrives by sync can
/// carry an `updated_at` older than the dive's own (the profile rewritten on
/// one device, the dive's buddy edited later on another, then a sync), and
/// the latest would not move. The sum moves on any write that moves one of
/// its terms, and on adding or removing a series. It is a version token, not
/// a time: compare it only for equality.
///
/// Every writer and reader of one cache must use this same expression: a row
/// written with it and compared against the bare `updated_at` reads as stale
/// for good. The sensor summaries and the Explore derived metrics both do.
String diveSourceStampSql([String dive = 'd']) =>
    '($dive.updated_at + '
    'COALESCE((SELECT SUM(stamp_p.updated_at) '
    'FROM dive_profile_series stamp_p WHERE stamp_p.dive_id = $dive.id), 0) + '
    'COALESCE((SELECT SUM(stamp_t.updated_at) '
    'FROM tank_pressure_series stamp_t WHERE stamp_t.dive_id = $dive.id), 0))';

/// [diveSourceStampSql] for one dive, or null when [diveId] does not exist.
Future<int?> readDiveSourceStamp(AppDatabase db, String diveId) async {
  final row = await db
      .customSelect(
        'SELECT ${diveSourceStampSql()} AS stamp FROM dives d WHERE d.id = ?',
        variables: [Variable.withString(diveId)],
        readsFrom: {db.dives, db.diveProfileSeries, db.tankPressureSeries},
      )
      .getSingleOrNull();
  return row?.read<int>('stamp');
}
