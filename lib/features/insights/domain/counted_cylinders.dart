import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/features/dive_log/domain/services/multi_cylinder_consumption.dart';

/// The O2 share from which a cylinder is a deco gas rather than a bottom
/// gas, as the download path infers roles (parsed_tank_resolver's
/// _decoMinO2Percent).
const double _decoMinO2Percent = 41.0;

/// The roles of the gas a diver starts the dive on.
const Set<TankRole> _bottomGasRoles = {...backmountRoles, ...sidemountRoles};

/// The ids of [tanks] the Insights figures count on one dive, so a dive
/// consolidated from two computers counts each cylinder once.
///
/// Every cylinder of the primary recording counts. Consolidation merges
/// another computer's cylinder into a primary one when they match and drops
/// its row, so another recording's row that is left is either a cylinder
/// only that computer logged, or a copy it did not merge (issue #2661).
/// Such a row counts unless it is a copy (issue #4420: a stage only the
/// second computer logged left the dive out of the Stages count). It is a
/// copy when a cylinder already counted from another recording:
///
/// 1. holds the same gas, within [sameGasTolerancePct]; or
/// 2. fills the same one-of-a-kind slot: a bottom gas (a backup computer
///    left on air beside a primary on 32% logged one cylinder on a stale
///    mix), a diluent or an oxygen supply.
///
/// A recording is the tank's computer, and a tank that names no computer
/// belongs to its source. The primary's are those [primaryComputerId] uses
/// (its own and the ones consolidation shared with it) and those of
/// [primarySourceId] or of no source. With no primary source, every
/// cylinder counts. Rows are taken in [tanks] order, so of two other
/// computers' copies of one cylinder the first counts.
Set<String> countedCylinderIds(
  List<DiveTank> tanks, {
  required String? primarySourceId,
  required String? primaryComputerId,
}) {
  if (primarySourceId == null) return {for (final t in tanks) t.id};

  const primary = '';
  String recordingOf(DiveTank tank) {
    final computerId = tank.computerId;
    if (computerId == null) {
      final sourceId = tank.sourceId;
      return sourceId == null || sourceId == primarySourceId
          ? primary
          : 'source:$sourceId';
    }
    return primaryComputerId != null && tank.isUsedBy(primaryComputerId)
        ? primary
        : 'computer:$computerId';
  }

  final recordings = {for (final t in tanks) t.id: recordingOf(t)};
  final fromPrimary = [
    for (final t in tanks)
      if (recordings[t.id] == primary) t,
  ];
  return tanks
      .where((t) => recordings[t.id] != primary)
      .fold<List<DiveTank>>(fromPrimary, (counted, tank) {
        final others = counted.where(
          (c) => recordings[c.id] != recordings[tank.id],
        );
        final slot = _slotOf(tank);
        final copy = others.any(
          (c) => _sameGas(c, tank) || (slot != null && _slotOf(c) == slot),
        );
        return copy ? counted : [...counted, tank];
      })
      .map((t) => t.id)
      .toSet();
}

bool _sameGas(DiveTank a, DiveTank b) =>
    (a.gasMix.o2 - b.gasMix.o2).abs() <= sameGasTolerancePct &&
    (a.gasMix.he - b.gasMix.he).abs() <= sameGasTolerancePct;

/// The slot a diver carries one of, or null. Back gas and sidemount rows at
/// deco strength are not bottom gas: an import without roles labels every
/// cylinder back gas.
TankRole? _slotOf(DiveTank tank) => switch (tank.role) {
  TankRole.diluent || TankRole.oxygenSupply => tank.role,
  final role
      when _bottomGasRoles.contains(role) &&
          tank.gasMix.o2 < _decoMinO2Percent =>
    TankRole.backGas,
  _ => null,
};
