import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// How close another row on the same cylinder must sit to a start to claim
/// it, in seconds. A computer-logged switch usually lands a few seconds from
/// the first breath, and one moment needs no second switch.
const int kGasSwitchClaimSeconds = 60;

/// The most times a row offers, so a long sidemount rotation does not push
/// the rest of the form down.
const int kGasSwitchMaxSuggestions = 3;

/// Whether a falling pressure on [tank] means it was breathed. A cylinder that
/// feeds a rebreather loop falls with the loop's demand, whatever the diver is
/// breathing, so its pressure says nothing about a switch.
bool hasBreathingStarts(DiveTank? tank) =>
    tank != null &&
    tank.role != TankRole.diluent &&
    tank.role != TankRole.oxygenSupply;

/// The times [row] offers as one-tap fills, in time order, from the [starts]
/// of its cylinder [tank] (issue #4089).
///
/// Left out: the second the row already holds, a start another row in
/// [switches] claims, the second any other row sits on, since two switches
/// cannot share one, and a start past [maxTimestamp], which a series that
/// outlasts the profile can give. When more than [kGasSwitchMaxSuggestions]
/// remain, the nearest the row's time stay.
List<int> gasSwitchTimeSuggestions({
  required GasSwitch row,
  required DiveTank? tank,
  required List<int> starts,
  required List<GasSwitch> switches,
  required int? maxTimestamp,
}) {
  if (!hasBreathingStarts(tank)) return const [];
  final others = [
    for (final s in switches)
      if (s.id != row.id) s,
  ];
  final claimedBy = [
    for (final s in others)
      if (s.tankId == row.tankId) s.timestamp,
  ];
  final open = [
    for (final start in starts)
      if (start != row.timestamp &&
          !others.any((s) => s.timestamp == start) &&
          (maxTimestamp == null || start <= maxTimestamp) &&
          !claimedBy.any((t) => (t - start).abs() <= kGasSwitchClaimSeconds))
        start,
  ];
  if (open.length <= kGasSwitchMaxSuggestions) return open;
  final nearest = [...open]
    ..sort(
      (a, b) => (a - row.timestamp).abs().compareTo((b - row.timestamp).abs()),
    );
  return nearest.take(kGasSwitchMaxSuggestions).toList()..sort();
}
