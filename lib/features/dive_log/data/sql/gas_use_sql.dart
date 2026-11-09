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
/// rate follows these too.
///
/// The surface minutes term also reads `dive_tanks`, which every whole-dive
/// rate already reads for its pressure drop, so it is not repeated here.
const Set<String> gasUseTables = {'dive_derived_metrics'};

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

/// Seconds the diver entered for breathing the dive's cylinders at the
/// surface after the computer stopped logging, 0 when none: the SQL form of
/// `Dive.surfaceBreathingSeconds`. A suit inflation bottle is not breathed,
/// and a cylinder with no logged drop adds no gas to a rate.
String _surfaceSeconds(String dive) =>
    '(SELECT COALESCE(SUM(gu_t.surface_breathing_duration), 0) '
    'FROM dive_tanks gu_t WHERE gu_t.dive_id = $dive.id '
    'AND gu_t.start_pressure > gu_t.end_pressure '
    "AND ${breathingTankSql('gu_t')})";

/// Seconds a whole-dive rate of the `dives` row aliased [dive] divides by:
/// the recorded time (see [_recordedSeconds]) plus minutes entered for
/// breathing at the surface (issue #2930). NULL exactly when the measured
/// runtime is. Mirrors `Dive._consumptionBasis`.
String gasUseSecondsSql(String dive) =>
    '(${_recordedSeconds(dive)} + ${_surfaceSeconds(dive)})';

/// The depth in metres a whole-dive rate of the `dives` row aliased [dive]
/// takes its ambient pressure at: the stored window's mean depth, else the
/// recorded average depth, with any surface minutes entered counted at 0 m.
String gasUseAvgDepthSql(String dive) {
  final depth =
      'COALESCE(${_cached(dive, 'gas_use_avg_depth_m')}, '
      '$dive.avg_depth)';
  final recorded = _recordedSeconds(dive);
  final surface = _surfaceSeconds(dive);
  return '(CASE WHEN $surface > 0 '
      'THEN $depth * $recorded / ($recorded + $surface) '
      'ELSE $depth END)';
}
