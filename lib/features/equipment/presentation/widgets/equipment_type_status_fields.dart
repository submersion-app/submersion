import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Type and Status dropdowns at the top of the equipment edit form.
/// The page owns both values and decides what a type change clears.
class EquipmentTypeStatusFields extends StatelessWidget {
  final EquipmentType type;
  final EquipmentStatus status;
  final ValueChanged<EquipmentType> onTypeChanged;
  final ValueChanged<EquipmentStatus> onStatusChanged;

  const EquipmentTypeStatusFields({
    super.key,
    required this.type,
    required this.status,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<EquipmentType>(
          initialValue: type,
          decoration: InputDecoration(
            labelText: context.l10n.equipment_edit_typeLabel,
            prefixIcon: const Icon(Icons.category),
          ),
          items: EquipmentType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.localizedName(context.l10n)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onTypeChanged(value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<EquipmentStatus>(
          initialValue: status,
          decoration: InputDecoration(
            labelText: context.l10n.equipment_edit_statusLabel,
            prefixIcon: const Icon(Icons.flag),
          ),
          items: EquipmentStatus.values.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Text(status.localizedName(context.l10n)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onStatusChanged(value);
          },
        ),
      ],
    );
  }
}
