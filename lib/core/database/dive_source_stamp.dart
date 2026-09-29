import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// The version of a dive a device-local cache was built from, as one SQL
/// expression over the dive alias [dive]: the later of the dive's own
/// `updated_at` and the newest `updated_at` among its profile and
/// tank-pressure series.
///
/// The series are synced child rows that never re-stamp their dive (#1769),
/// so a profile or pressure change arriving by sync leaves `dives.updated_at`
/// alone. A cache keyed on the dive's stamp alone would keep calling a row
/// built from the old series current. A row matches only its exact stamp, so
/// removing the newest series moves the stamp back down, which is a change
/// too. Removing an older series leaves the maximum where it was and is not
/// seen: a series delete that arrives by sync with no newer write to the dive
/// or its other series keeps the row current until something else moves.
///
/// Every writer and reader of one cache must use this same expression: a row
/// written with it and compared against the bare `updated_at` reads as stale
/// for good. The sensor summaries and the Explore derived metrics both do.
String diveSourceStampSql([String dive = 'd']) =>
    'MAX($dive.updated_at, '
    'COALESCE((SELECT MAX(stamp_p.updated_at) '
    'FROM dive_profile_series stamp_p WHERE stamp_p.dive_id = $dive.id), 0), '
    'COALESCE((SELECT MAX(stamp_t.updated_at) '
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
