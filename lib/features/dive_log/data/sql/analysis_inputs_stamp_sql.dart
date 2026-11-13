import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/sql/multi_cylinder_sac_sql.dart';

/// The terms a cache built from a dive's profile analysis adds to
/// `diveSourceStampSql`, as one SQL expression over the dive alias [dive]:
/// the dive's effective water type (issue #3958), its gas switches, and its
/// primary computer (issue #2930). None of a site's water, a synced switch
/// or a synced source flag re-stamps the dive, so a cache keyed on the
/// source stamp alone keeps a result built from the old inputs current.
///
/// The primary term is the source row's local rowid, which differs for each
/// source of a dive. Like the source stamp it is a version token, not a
/// time: compare it only for equality. Shared by the Explore derived metrics
/// and the computed deco verdicts (issue #4461), the two caches that read
/// these inputs.
String diveAnalysisInputsStampSql(String dive) {
  final whens = [
    for (final type in WaterType.values)
      "WHEN '${type.name}' THEN ${type.index + 1}",
  ].join(' ');
  return '((CASE ${diveEffectiveWaterTypeSql(dive)} $whens ELSE 0 END) + '
      'COALESCE((SELECT COUNT(*) + SUM(stamp_g.timestamp) + '
      'SUM(COALESCE(CAST(substr(stamp_g.hlc, 1, 15) AS INTEGER), 0)) '
      'FROM gas_switches stamp_g WHERE stamp_g.dive_id = $dive.id), 0) + '
      'COALESCE((SELECT SUM(stamp_s.rowid) FROM dive_data_sources stamp_s '
      'WHERE stamp_s.dive_id = $dive.id AND stamp_s.is_primary = 1), 0))';
}

/// The tables [diveAnalysisInputsStampSql] reads, for `readsFrom` and ticks.
Set<ResultSetImplementation<dynamic, dynamic>> diveAnalysisInputsStampTables(
  AppDatabase db,
) => {db.diveSites, db.gasSwitches, db.diveDataSources};

/// The computer events of the dive at [dive] as a version token: their count,
/// times and clocks. The dive analysis reads them (computer CNS, gas
/// switches, stops) and a synced event never re-stamps its dive. Kept apart
/// from [diveAnalysisInputsStampSql] because the derived metrics do not read
/// events, and folding them in would re-sweep every dive that has any.
String diveProfileEventsStampSql(String dive) =>
    'COALESCE((SELECT COUNT(*) + SUM(stamp_e.timestamp) + '
    'SUM(COALESCE(CAST(substr(stamp_e.hlc, 1, 15) AS INTEGER), 0)) + '
    'SUM(stamp_e.created_at) '
    'FROM dive_profile_events stamp_e WHERE stamp_e.dive_id = $dive.id), 0)';
