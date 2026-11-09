import 'package:submersion/core/utils/time_weighted_mean.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/breathing_gas_switches.dart';
import 'package:submersion/features/dive_log/domain/services/tank_usage_range.dart';

/// When, for how long and how deep one open-circuit cylinder was breathed.
typedef CylinderUsage = ({
  /// The periods it was breathed, in time order.
  List<TankUsageWindow> windows,

  /// Its breathing time: the windows' total, or a duration the source log
  /// recorded for it.
  int seconds,

  /// Whether [seconds] is a duration the source log recorded rather than the
  /// windows' total: the windows are then the whole dive, which says nothing
  /// about when it was breathed (issue #771).
  bool fromRecordedDuration,

  /// The time-weighted mean depth over [windows], in meters; null when the
  /// profile has no samples in them.
  double? avgDepth,
});

/// How the Cylinders card reads [tank]'s breathing time and depth, so a
/// statistic over many dives gives each cylinder the rate that one dive
/// shows (issue #4315). Null when nothing says when it was breathed.
///
/// Gas switches that name a cylinder of [tanks] before [diveEnd] decide the
/// windows (see [tankUsageWindows]). Without them, a duration the source log
/// recorded for [tank] (issue #1496) is its breathing time, its depth window
/// the whole dive, since a duration says how long but not when.
CylinderUsage? cylinderUsage({
  required DiveTank tank,
  required List<DiveTank> tanks,
  required List<DiveProfilePoint> profile,
  required List<GasSwitchWithTank>? gasSwitches,
  required int diveEnd,
}) {
  // Only a switch that says when a cylinder was breathed overrides a
  // recorded duration: not a stale id (#110), nor one after the dive, nor one
  // to a suit inflation bottle that no breathing cylinder's mix takes over
  // (issue #4243), as [tankUsageWindows] reads them.
  final hasGasSwitches = knownGasSwitches(
    tanks,
    gasSwitches == null ? null : breathingGasSwitches(gasSwitches, tanks),
    before: diveEnd,
  ).isNotEmpty;
  // Gas switches say when, which is more, so they win; without them this is
  // the only thing that tells two same-role tanks apart.
  final recordedSeconds = hasGasSwitches ? null : tank.usageDuration?.inSeconds;
  final hasRecordedUsage = recordedSeconds != null && recordedSeconds > 0;

  final windows = hasRecordedUsage
      ? [(start: 0, end: diveEnd > 0 ? diveEnd : recordedSeconds)]
      : tankUsageWindows(
          tank: tank,
          gasSwitches: gasSwitches,
          diveStart: 0,
          diveEnd: diveEnd,
          tanks: tanks,
        );
  if (windows.isEmpty) return null;

  return (
    windows: windows,
    seconds: hasRecordedUsage ? recordedSeconds : windows.breathedSeconds,
    fromRecordedDuration: hasRecordedUsage,
    avgDepth: timeWeightedMeanAcross(
      profile,
      windows: windows,
      time: (p) => p.timestamp,
      value: (p) => p.depth,
    ),
  );
}
