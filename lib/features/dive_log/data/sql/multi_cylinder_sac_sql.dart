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
/// the reference cylinder's drop (the first back gas with a drop, else the
/// first cylinder with a drop when the dive has no back gas) plus every
/// other breathed cylinder's drop converted to the reference by volume, or
/// one to one between two unsized sidemount cylinders. A rebreather dive
/// reads the reference alone. NULL with no reference drop; the caller
/// guards the runtime and average depth. Mirrors `Dive.sac`.
String diveSacPressureSql(String dive) {
  final volume = consumptionVolumeSql('sac_t');
  final referenceVolume = consumptionVolumeSql('sac_ref');
  return '((SELECT SUM((sac_t.start_pressure - sac_t.end_pressure) * CASE '
      'WHEN sac_t.id = sac_ref.id THEN 1.0 '
      'WHEN $volume > 0 AND $referenceVolume > 0 '
      'THEN $volume / $referenceVolume '
      'WHEN sac_t.tank_role IN $_sidemountRolesSql '
      'AND sac_ref.tank_role IN $_sidemountRolesSql THEN 1.0 '
      'ELSE 0.0 END) '
      'FROM dive_tanks sac_ref '
      'JOIN dive_tanks sac_t ON sac_t.dive_id = sac_ref.dive_id '
      'WHERE sac_ref.id = ('
      'SELECT t2.id FROM dive_tanks t2 '
      'WHERE t2.dive_id = $dive.id '
      'AND t2.start_pressure > t2.end_pressure '
      "AND (t2.tank_role = 'backGas' OR NOT EXISTS ("
      'SELECT 1 FROM dive_tanks t3 WHERE t3.dive_id = $dive.id '
      "AND t3.tank_role = 'backGas')) "
      'ORDER BY t2.tank_order, t2.rowid LIMIT 1) '
      'AND sac_t.start_pressure > sac_t.end_pressure '
      'AND (sac_t.id = sac_ref.id '
      "OR COALESCE($dive.dive_mode, 'oc') NOT IN ('ccr', 'scr'))) "
      '/ (COALESCE($dive.runtime, $dive.bottom_time) / 60.0) '
      '/ (($dive.avg_depth / 10.0) + 1))';
}
