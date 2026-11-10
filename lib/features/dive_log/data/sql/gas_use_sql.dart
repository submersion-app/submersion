/// SQL forms of `Dive.gasUse`: the time and depth a whole-dive SAC or RMV
/// divides by, with surface runs at the ends of the recording left out
/// (issue #2930).
///
/// SQL cannot decode a packed profile, so these read the window the derived
/// metrics sweep stored from the same `gasUseWindowOf` the entity runs. A dive
/// whose row is not built yet, or that had nothing to leave out, reads the
/// measured runtime and recorded average depth, as it did before.
library;

import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';
import 'package:submersion/features/dive_log/data/sql/multi_cylinder_sac_sql.dart';

/// What the gas-use expressions read beyond the dive row and the
/// [measuredRuntimeTables], by SQL name: a query or tick over a whole-dive
/// rate follows these too. `tank_pressure_series` says which cylinders a
/// transmitter logged, whose entered surface minutes do not count.
///
/// The surface minutes term also reads `dive_tanks`, which every whole-dive
/// rate already reads for its pressure drop, so it is not repeated here.
const Set<String> gasUseTables = {
  'dive_derived_metrics',
  'tank_pressure_series',
};

/// Whether the `dive_tanks` row aliased [tank] has no transmitter log: its
/// end pressure was read off the gauge, so it can hold gas breathed after
/// the computer stopped. The SQL form of `!DiveTank.hasPressureSeries`.
String _unloggedSql(String tank) =>
    'NOT EXISTS (SELECT 1 FROM tank_pressure_series gu_s '
    'WHERE gu_s.dive_id = $tank.dive_id AND gu_s.tank_id = $tank.id)';

String _cached(String dive, String column) =>
    '(SELECT gu.$column FROM dive_derived_metrics gu '
    'WHERE gu.dive_id = $dive.id)';

/// The recorded seconds a whole-dive rate of the `dives` row aliased [dive]
/// divides by: the stored window, never longer than the measured runtime (a
/// runtime already shortened by hand is not cut twice), else the measured
/// runtime. NULL exactly when the measured runtime is, since a
/// multi-argument `MIN` is NULL when any argument is.
String _recordedSeconds(String dive) {
  final measured = measuredRuntimeSecondsSql(dive);
  return 'MIN(COALESCE(${_cached(dive, 'gas_use_s')}, $measured), $measured)';
}

/// Which whole-dive rate a gas-use expression is for: the pressure lane
/// (`Dive.sac`, `diveSacPressureSql`) or the volume lane (`Dive.rmvFor`).
/// They sum different cylinders, so they count different surface minutes.
enum GasUseLane { pressure, volume }

/// Whether the `dive_tanks` row aliased [tank] adds gas to [lane] of the
/// `dives` row aliased [dive]: in litres, when it has a consumption volume;
/// in bar of the reference, when it is the reference, both sizes are known,
/// or it pairs with the reference (`referenceBarsPerBar`).
String _contributesSql(String tank, String dive, GasUseLane lane) =>
    switch (lane) {
      GasUseLane.volume => '${consumptionVolumeSql(tank)} IS NOT NULL',
      GasUseLane.pressure =>
        'EXISTS (SELECT 1 FROM dive_tanks gu_r '
            'WHERE gu_r.id = ${sacReferenceIdSql(dive)} '
            'AND ($tank.id = gu_r.id '
            'OR (${consumptionVolumeSql(tank)} IS NOT NULL '
            "AND ${consumptionVolumeSql('gu_r')} IS NOT NULL) "
            "OR ${matchedPairSql(tank, 'gu_r')}))",
    };

/// Seconds the diver entered for breathing at the surface after the computer
/// stopped logging that [lane] counts, 0 when none: the SQL form of
/// `enteredSurfaceSeconds` over the breathing cylinders with a logged drop
/// and no transmitter log. A matched pair's shared time counts once, at its
/// longer entry.
String _surfaceSeconds(String dive, GasUseLane lane) =>
    '(SELECT COALESCE(SUM(gu_t.surface_breathing_duration), 0) '
    'FROM dive_tanks gu_t WHERE gu_t.dive_id = $dive.id '
    'AND gu_t.start_pressure > gu_t.end_pressure '
    "AND ${breathingTankSql('gu_t')} "
    'AND gu_t.surface_breathing_duration > 0 '
    "AND ${_unloggedSql('gu_t')} "
    "AND ${_contributesSql('gu_t', dive, lane)} "
    'AND NOT EXISTS (SELECT 1 FROM dive_tanks gu_p '
    'WHERE gu_p.dive_id = gu_t.dive_id AND gu_p.id <> gu_t.id '
    'AND gu_p.start_pressure > gu_p.end_pressure '
    "AND ${breathingTankSql('gu_p')} "
    "AND ${_unloggedSql('gu_p')} "
    "AND ${matchedPairSql('gu_t', 'gu_p')} "
    'AND (COALESCE(gu_p.surface_breathing_duration, 0) '
    '> gu_t.surface_breathing_duration '
    'OR (gu_p.surface_breathing_duration = gu_t.surface_breathing_duration '
    'AND gu_p.id < gu_t.id))))';

/// Seconds [lane] of the `dives` row aliased [dive] divides by: the recorded
/// time (see [_recordedSeconds]) plus minutes entered for breathing at the
/// surface (issue #2930). NULL exactly when the measured runtime is.
/// Mirrors `Dive._consumptionBasis`.
String gasUseSecondsSql(String dive, {required GasUseLane lane}) =>
    '(${_recordedSeconds(dive)} + ${_surfaceSeconds(dive, lane)})';

/// The depth in metres a whole-dive rate of the `dives` row aliased [dive]
/// takes its ambient pressure at: the stored window's mean depth, else the
/// recorded average depth, with any surface minutes entered counted at 0 m.
String gasUseAvgDepthSql(String dive, {required GasUseLane lane}) {
  final depth =
      'COALESCE(${_cached(dive, 'gas_use_avg_depth_m')}, '
      '$dive.avg_depth)';
  final recorded = _recordedSeconds(dive);
  final surface = _surfaceSeconds(dive, lane);
  return '(CASE WHEN $surface > 0 '
      'THEN $depth * $recorded / ($recorded + $surface) '
      'ELSE $depth END)';
}
