import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// What applying [t]'s setup would write to cylinder [row], or null when it
/// would change nothing. One function for the apply and its preview, so the
/// counts the diver confirms are the rows written (issue #4347).
///
/// Empty size, working pressure, material, preset, gear link and name are
/// filled. The role is replaced while it is still the uninformed backGas
/// default, and always while it is the computer's guess from the
/// transmitter's name (issue #2595), which also drops that source: the entry
/// is the diver's own configuration. A role the diver set is never replaced.
DiveTanksCompanion? transmitterFillFor(DiveTank row, Transmitter t) {
  final hasVolume = row.volume != null && row.volume! > 0;
  final nameDerived = isNameDerivedRole(row);
  final companion = DiveTanksCompanion(
    volume: !hasVolume && t.volumeL != null
        ? Value(t.volumeL)
        : const Value.absent(),
    workingPressure: row.workingPressure == null && t.workingPressureBar != null
        ? Value(t.workingPressureBar)
        : const Value.absent(),
    tankMaterial: row.tankMaterial == null && t.material != null
        ? Value(t.material!.name)
        : const Value.absent(),
    presetName: row.presetName == null && t.presetName != null
        ? Value(t.presetName)
        : const Value.absent(),
    equipmentId: row.equipmentId == null && t.equipmentId != null
        ? Value(t.equipmentId)
        : const Value.absent(),
    tankName:
        (row.tankName == null || row.tankName!.isEmpty) && t.label.isNotEmpty
        ? Value(t.label)
        : const Value.absent(),
    tankRole:
        nameDerived ||
            (row.tankRole == TankRole.backGas.name &&
                t.role != TankRole.backGas)
        ? Value(t.role.name)
        : const Value.absent(),
    roleSource: nameDerived ? const Value(null) : const Value.absent(),
  );
  // Every field absent means nothing to write for this row.
  return companion == const DiveTanksCompanion() ? null : companion;
}

/// Whether [row]'s role is the computer's guess from the transmitter's name.
bool isNameDerivedRole(DiveTank row) =>
    TankRoleSource.fromName(row.roleSource) == TankRoleSource.transmitterName;
