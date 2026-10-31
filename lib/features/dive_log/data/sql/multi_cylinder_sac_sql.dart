/// SQL forms of the multi-cylinder consumption rules in
/// `domain/services/multi_cylinder_consumption.dart` (issue #3109), so the
/// statistics, the query language and the dive overview agree on one dive.
library;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

const String _sidemountRolesSql = "('sidemountLeft', 'sidemountRight')";

/// The consumption volume of the `dive_tanks` row aliased [tank], in
/// liters: its own volume, else the volume of the first other cylinder of
/// the dive that forms a matched pair with it (both sidemount, or both
/// back gas on the same gas). NULL when neither is known. Mirrors
/// `consumptionVolume`.
String consumptionVolumeSql(String tank) {
  final partner = '${tank}_partner';
  return '(CASE WHEN $tank.volume > 0 THEN $tank.volume ELSE ('
      'SELECT $partner.volume FROM dive_tanks $partner '
      'WHERE $partner.dive_id = $tank.dive_id AND $partner.id <> $tank.id '
      'AND $partner.volume > 0 '
      'AND (($tank.tank_role IN $_sidemountRolesSql '
      'AND $partner.tank_role IN $_sidemountRolesSql) '
      "OR ($tank.tank_role = 'backGas' "
      "AND $partner.tank_role = 'backGas' "
      'AND ABS($partner.o2_percent - $tank.o2_percent) '
      '<= $sameGasTolerancePct '
      'AND ABS($partner.he_percent - $tank.he_percent) '
      '<= $sameGasTolerancePct)) '
      'ORDER BY $partner.tank_order, $partner.rowid LIMIT 1) END)';
}

/// The effective water type of the `dives` row aliased [dive]: its own, else
/// its site's, an empty string meaning none was recorded. The SQL twin of
/// `Dive.effectiveWaterType`.
String diveEffectiveWaterTypeSql(String dive) =>
    "COALESCE(NULLIF($dive.water_type, ''), "
    "(SELECT NULLIF(dws.water_type, '') FROM dive_sites dws "
    'WHERE dws.id = $dive.site_id))';

/// The absolute pressure in bar at [depth] meters in the water of the `dives`
/// row aliased [dive], as `Dive.environment` reads it. [depth] is a SQL
/// expression.
String diveAmbientBarSql(String dive, String depth) =>
    '$kDiveAmbientBarFunction($depth, $dive.altitude, $dive.surface_pressure, '
    '${diveEffectiveWaterTypeSql(dive)})';

/// SAC in bar per minute at the surface of the `dives` row aliased [dive]:
/// the reference cylinder's drop (the first back gas, else the first
/// cylinder, as `Dive.sacReferenceTank` picks it) plus every other breathed
/// cylinder's drop converted to the reference by volume, or one to one
/// when a size is missing and the two are a matched pair (both sidemount,
/// or both back gas on the same gas). A reference that did not fall adds
/// zero, since only breathed cylinders are summed (#3974). NULL on a
/// rebreather dive, whose cylinders do not drain with the diver's breathing
/// (issue #3673), when the reference has no pressures logged, since it must
/// join, and when nothing adds up to a drop; the caller guards the runtime
/// and average depth. Mirrors `Dive.sac`.
String diveSacPressureSql(String dive) {
  // The cylinders matching [where] once each, with their consumption volume
  // computed once.
  String cylinders(String where) =>
      '(SELECT sac_t.id, '
      'sac_t.start_pressure - sac_t.end_pressure AS pressure_drop, '
      '${consumptionVolumeSql('sac_t')} AS volume, '
      'sac_t.tank_role IN $_sidemountRolesSql AS sidemount, '
      "sac_t.tank_role = 'backGas' AS back_gas, "
      'sac_t.o2_percent AS o2, sac_t.he_percent AS he '
      'FROM dive_tanks sac_t WHERE sac_t.dive_id = $dive.id AND $where)';
  final breathed = cylinders('sac_t.start_pressure > sac_t.end_pressure');
  final measured = cylinders(
    'sac_t.start_pressure IS NOT NULL AND sac_t.end_pressure IS NOT NULL',
  );
  return "(CASE WHEN COALESCE($dive.dive_mode, 'oc') "
      'IN ${DiveStatsScope.rebreatherModesSql} '
      'THEN NULL ELSE '
      '((SELECT NULLIF(SUM(sac_c.pressure_drop * CASE '
      'WHEN sac_c.id = sac_r.id THEN 1.0 '
      'WHEN sac_c.volume > 0 AND sac_r.volume > 0 '
      'THEN sac_c.volume / sac_r.volume '
      'WHEN sac_c.sidemount AND sac_r.sidemount THEN 1.0 '
      'WHEN sac_c.back_gas AND sac_r.back_gas '
      'AND ABS(sac_c.o2 - sac_r.o2) <= $sameGasTolerancePct '
      'AND ABS(sac_c.he - sac_r.he) <= $sameGasTolerancePct THEN 1.0 '
      'ELSE 0.0 END), 0) '
      'FROM $breathed sac_c JOIN $measured sac_r '
      'ON sac_r.id = ('
      'SELECT t2.id FROM dive_tanks t2 '
      'WHERE t2.dive_id = $dive.id '
      "AND (t2.tank_role = 'backGas' OR NOT EXISTS ("
      'SELECT 1 FROM dive_tanks t3 WHERE t3.dive_id = $dive.id '
      "AND t3.tank_role = 'backGas')) "
      'ORDER BY t2.tank_order, t2.rowid LIMIT 1)) '
      '/ (COALESCE($dive.runtime, $dive.bottom_time) / 60.0) '
      '/ ${diveAmbientBarSql(dive, '$dive.avg_depth')}) END)';
}
