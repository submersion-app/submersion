import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The cylinders a tank can be filled from: tank gear in [gear], spares
/// left out as in every gear picker (#1803). Gear another diver shared is
/// included, since shared gear is usable on a dive (#2046); the picker marks
/// it with its owner. The same narrowing [showOwnCylinderPicker] applies.
List<EquipmentItem> ownCylinders(List<EquipmentItem> gear) => [
  for (final item in gear)
    if (item.type == EquipmentType.tank && item.status != EquipmentStatus.spare)
      item,
];

/// The [cylinders] that record a size or a material, so choosing one fills
/// something. The tank preset dropdown offers only these (issue #163): a
/// cylinder with no spec would fill nothing there, yet still join the dive's
/// gear. The "My cylinders" picker, which says what picking does, offers all.
List<EquipmentItem> cylindersWithSpec(List<EquipmentItem> cylinders) => [
  for (final item in cylinders)
    if (item.volumeL != null ||
        item.workingPressureBar != null ||
        item.tankMaterial != null)
      item,
];

/// Lets the diver choose one of their cylinders to fill a dive tank from
/// (issue #2599): the gear picker narrowed to cylinders, saying what picking
/// does. Resolves to the chosen cylinder, or null when dismissed.
Future<EquipmentItem?> showOwnCylinderPicker(BuildContext context) {
  return showModalBottomSheet<EquipmentItem>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => EquipmentPickerSheet(
        scrollController: scrollController,
        // Nothing is left out for being on the dive already: a cylinder
        // listed under Equipment is exactly the one a tank should copy.
        selectedEquipmentIds: const {},
        typeFilter: EquipmentType.tank,
        hideSpare: true,
        title: context.l10n.diveLog_tank_ownCylinderTitle,
        hint: context.l10n.diveLog_tank_ownCylinderHint,
        onEquipmentSelected: (item) => Navigator.of(context).pop(item),
      ),
    ),
  );
}
