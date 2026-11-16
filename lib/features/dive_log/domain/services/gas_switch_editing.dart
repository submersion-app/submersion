import 'package:submersion/core/constants/enums.dart' show DiveMode;
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/breathing_gas_switches.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

/// Whether a dive has gas switches to edit, as the dive editor shows them:
/// with one breathing cylinder there is nothing to switch to, a gauge dive
/// logs no gas, and a planned dive's switches belong to the plan. A suit
/// inflation bottle is not breathed, so [breathingTankCount] leaves it out
/// (issue #4243).
bool gasSwitchesEditable({
  required int breathingTankCount,
  required DiveMode mode,
  required bool isPlanned,
}) => breathingTankCount >= 2 && mode != DiveMode.gauge && !isPlanned;

/// [switches] in time order, ties broken by id, so two rows on one second
/// (a time being typed over another) never swap between builds. A new list.
List<GasSwitch> gasSwitchesInTimeOrder(Iterable<GasSwitch> switches) =>
    [...switches]..sort(
      (a, b) => a.timestamp != b.timestamp
          ? a.timestamp.compareTo(b.timestamp)
          : a.id.compareTo(b.id),
    );

/// The cylinder a new switch at [timestamp] goes to: the first breathing
/// cylinder not breathed then, else the first breathing cylinder; null when
/// [tanks] holds none.
///
/// The cylinder breathed then is the one the last of [switches] at or before
/// [timestamp] names, else [startingTankId]. A switch to a suit inflation
/// bottle counts against the breathing cylinder on its mix and is passed
/// over when none holds it (issue #4243), as every breathing gas reading
/// takes it, so a new switch never goes to the gas already in use.
DiveTank? newGasSwitchTank({
  required List<DiveTank> tanks,
  required List<GasSwitch> switches,
  required int timestamp,
  required String? startingTankId,
}) {
  final breathing = breathingTanks(tanks);
  if (breathing.isEmpty) return null;
  GasSwitch? active;
  for (final s in breathingRawGasSwitches(switches, tanks)) {
    if (s.timestamp <= timestamp &&
        (active == null || s.timestamp >= active.timestamp)) {
      active = s;
    }
  }
  final inUse = active?.tankId ?? startingTankId;
  return breathing.firstWhere(
    (t) => t.id != inUse,
    orElse: () => breathing.first,
  );
}
