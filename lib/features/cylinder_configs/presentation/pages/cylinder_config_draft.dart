import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/cylinder_config_item_editor.dart';

/// One cylinder of the configuration editor as the diver sees it (issue
/// #4527, phase 4): its numbers as their fields show them, so a size typed
/// in cubic feet or psi and typed back reads as unchanged, and a cylinder
/// left alone never reads as changed.
typedef CylinderRowDraft = ({
  String id,
  String label,
  TankRole role,
  String volume,
  String pressure,
  String o2,
  String he,
  String mod,
  TankMaterial? material,
});

/// The configuration editor's form as shown: its name as typed, its unit,
/// and its cylinders in order. Two drafts are equal when the diver would
/// see the same form.
@immutable
class CylinderConfigDraft {
  const CylinderConfigDraft({
    required this.name,
    this.equipmentId,
    required this.rows,
  });

  final String name;
  final String? equipmentId;
  final List<CylinderRowDraft> rows;

  @override
  bool operator ==(Object other) =>
      other is CylinderConfigDraft &&
      other.name == name &&
      other.equipmentId == equipmentId &&
      listEquals(other.rows, rows);

  @override
  int get hashCode => Object.hash(name, equipmentId, Object.hashAll(rows));
}

/// [item] as the item editor shows it to a diver with [units]. The MOD is
/// the one set by hand, as its field fills its text; blank for the default.
CylinderRowDraft cylinderRowDraft(
  CylinderConfigItem item,
  UnitFormatter units,
) => (
  id: item.id,
  label: item.label ?? '',
  role: item.tankRole,
  volume: cylinderVolumeText(units, item.volumeL, item.workingPressureBar),
  pressure: cylinderPressureText(units, item.workingPressureBar),
  o2: cylinderShareText(item.o2Percent),
  he: cylinderShareText(item.hePercent),
  mod: switch (item.decoSwitchDepth) {
    final meters? => formatRoundedForInput(units.convertDepth(meters), 1),
    null => '',
  },
  material: item.tankMaterial,
);
