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

/// What the gas-use expressions read beyond the dive row and the
/// [measuredRuntimeTables], by SQL name: a query or tick over a whole-dive
/// rate follows these too.
const Set<String> gasUseTables = {'dive_derived_metrics'};

String _cached(String dive, String column) =>
    '(SELECT gu.$column FROM dive_derived_metrics gu '
    'WHERE gu.dive_id = $dive.id)';

/// Seconds a whole-dive rate of the `dives` row aliased [dive] divides by:
/// the stored window, never longer than the measured runtime (a runtime
/// already shortened by hand is not cut twice), else the measured runtime.
/// NULL exactly when the measured runtime is, since a multi-argument `MIN`
/// is NULL when any argument is. Mirrors `Dive._consumptionBasis`.
String gasUseSecondsSql(String dive) {
  final measured = measuredRuntimeSecondsSql(dive);
  return 'MIN(COALESCE(${_cached(dive, 'gas_use_s')}, $measured), $measured)';
}

/// The depth in metres a whole-dive rate of the `dives` row aliased [dive]
/// takes its ambient pressure at: the stored window's mean depth, else the
/// recorded average depth.
String gasUseAvgDepthSql(String dive) =>
    'COALESCE(${_cached(dive, 'gas_use_avg_depth_m')}, $dive.avg_depth)';
