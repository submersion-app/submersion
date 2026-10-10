import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/tank_source_index.dart';

/// Whether a dive computer recorded [tank] (issue #3021). A download stamps
/// its computer and the parsed tank index on every tank it writes; a tank
/// the diver added by hand carries neither.
///
/// The mix of such a tank is the computer's record of what was breathed, so
/// filling the tank from another cylinder (a trip slot, an own cylinder, a
/// scanned tag) takes that cylinder's specs but keeps this mix. The diver
/// can still type a different one.
bool isComputerRecordedTank(DiveTank tank) =>
    tank.computerId != null ||
    (tank.sourceTankIndex != null &&
        tank.sourceTankIndex != kNoSourceTankIndex);

/// The parsed tank index [tank]'s computer-recorded mix comes from, or null
/// when it takes none: a hand-added tank, or the row a series reassignment
/// left behind. A computer row from before v200 has no source index and
/// falls back to its order, as re-parse does.
int? computerTankIndex(DiveTank tank) {
  if (!isComputerRecordedTank(tank)) return null;
  final index = tank.sourceTankIndex;
  if (index == kNoSourceTankIndex) return null;
  return index ?? tank.order;
}
