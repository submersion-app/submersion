/// SQL forms of the multi-cylinder consumption rules in
/// `domain/services/multi_cylinder_consumption.dart` (issue #3109), so the
/// statistics, the query language and the dive overview agree on one dive.
library;

const String _sidemountRolesSql = "('sidemountLeft', 'sidemountRight')";

/// The consumption volume of the `dive_tanks` row aliased [tank], in
/// liters: its own volume, else for a sidemount cylinder the volume of the
/// first other sidemount cylinder of the dive that has one. NULL when
/// neither is known. Mirrors `consumptionVolume`.
String consumptionVolumeSql(String tank) {
  final partner = '${tank}_partner';
  return '(CASE WHEN $tank.volume > 0 THEN $tank.volume '
      'WHEN $tank.tank_role IN $_sidemountRolesSql THEN ('
      'SELECT $partner.volume FROM dive_tanks $partner '
      'WHERE $partner.dive_id = $tank.dive_id AND $partner.id <> $tank.id '
      'AND $partner.tank_role IN $_sidemountRolesSql '
      'AND $partner.volume > 0 '
      'ORDER BY $partner.tank_order, $partner.rowid LIMIT 1) END)';
}

/// SAC in bar per minute at the surface of the `dives` row aliased [dive]:
/// the reference cylinder's drop (the first back gas, else the first
/// cylinder, as `Dive.sacReferenceTank` picks it) plus every other breathed
/// cylinder's drop converted to the reference by volume, or one to one
/// when a size is missing and the two are a matched pair (both sidemount,
/// or both back gas on the same gas). A rebreather dive reads the
/// reference alone. NULL when the reference has no drop, since only
/// breathed cylinders join; the caller guards the runtime and average
/// depth. Mirrors `Dive.sac`.
String diveSacPressureSql(String dive) {
  // Each breathed cylinder once, with its consumption volume computed once.
  final breathed =
      '(SELECT sac_t.id, '
      'sac_t.start_pressure - sac_t.end_pressure AS pressure_drop, '
      '${consumptionVolumeSql('sac_t')} AS volume, '
      'sac_t.tank_role IN $_sidemountRolesSql AS sidemount, '
      "sac_t.tank_role = 'backGas' AS back_gas, "
      'ROUND(sac_t.o2_percent) AS o2, ROUND(sac_t.he_percent) AS he '
      'FROM dive_tanks sac_t WHERE sac_t.dive_id = $dive.id '
      'AND sac_t.start_pressure > sac_t.end_pressure)';
  return '((SELECT SUM(sac_c.pressure_drop * CASE '
      'WHEN sac_c.id = sac_r.id THEN 1.0 '
      'WHEN sac_c.volume > 0 AND sac_r.volume > 0 '
      'THEN sac_c.volume / sac_r.volume '
      'WHEN sac_c.sidemount AND sac_r.sidemount THEN 1.0 '
      'WHEN sac_c.back_gas AND sac_r.back_gas '
      'AND sac_c.o2 = sac_r.o2 AND sac_c.he = sac_r.he THEN 1.0 '
      'ELSE 0.0 END) '
      'FROM $breathed sac_c JOIN $breathed sac_r '
      'ON sac_r.id = ('
      'SELECT t2.id FROM dive_tanks t2 '
      'WHERE t2.dive_id = $dive.id '
      "AND (t2.tank_role = 'backGas' OR NOT EXISTS ("
      'SELECT 1 FROM dive_tanks t3 WHERE t3.dive_id = $dive.id '
      "AND t3.tank_role = 'backGas')) "
      'ORDER BY t2.tank_order, t2.rowid LIMIT 1) '
      'WHERE sac_c.id = sac_r.id '
      "OR COALESCE($dive.dive_mode, 'oc') NOT IN ('ccr', 'scr')) "
      '/ (COALESCE($dive.runtime, $dive.bottom_time) / 60.0) '
      '/ (($dive.avg_depth / 10.0) + 1))';
}
