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

/// [stored], the cylinder as stored now, with the diver's changes on it:
/// each field whose row draft differs from [start] is taken from [edited],
/// the form's copy, and every other field, those the editor does not show
/// among them (the default start pressure), stays as stored, so a value a
/// sync wrote meanwhile is not put back (issue #4527, phase 4). In cubic
/// feet a size is a capacity at the working pressure, so a new pressure
/// brings the litres the form worked out with it.
CylinderConfigItem mergeCylinderEdits({
  required CylinderConfigItem stored,
  required CylinderConfigItem edited,
  required CylinderRowDraft start,
  required CylinderRowDraft draft,
  required bool inCuft,
}) {
  final labelChanged = draft.label != start.label;
  final pressureChanged = draft.pressure != start.pressure;
  final volumeChanged =
      draft.volume != start.volume || (inCuft && pressureChanged);
  final mixChanged = draft.o2 != start.o2 || draft.he != start.he;
  final modChanged = draft.mod != start.mod;
  final materialChanged = draft.material != start.material;
  return stored.copyWith(
    label: labelChanged ? edited.label : null,
    clearLabel: labelChanged && edited.label == null,
    tankRole: draft.role != start.role ? edited.tankRole : null,
    volumeL: volumeChanged ? edited.volumeL : null,
    clearVolumeL: volumeChanged && edited.volumeL == null,
    workingPressureBar: pressureChanged ? edited.workingPressureBar : null,
    clearWorkingPressureBar:
        pressureChanged && edited.workingPressureBar == null,
    o2Percent: mixChanged ? edited.o2Percent : null,
    hePercent: mixChanged ? edited.hePercent : null,
    decoSwitchDepth: modChanged ? edited.decoSwitchDepth : null,
    clearDecoSwitchDepth: modChanged && edited.decoSwitchDepth == null,
    tankMaterial: materialChanged ? edited.tankMaterial : null,
    clearTankMaterial: materialChanged && edited.tankMaterial == null,
  );
}
