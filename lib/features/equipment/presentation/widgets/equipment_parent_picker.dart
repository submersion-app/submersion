import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Which item types can hold a child of [type]. Empty means the type is
/// not a child type and the edit page hides the parent picker.
Set<EquipmentType> equipmentParentTypesFor(EquipmentType type) =>
    switch (type) {
      EquipmentType.o2Cell => const {EquipmentType.rebreather},
      EquipmentType.battery => const {
        EquipmentType.computer,
        EquipmentType.transmitter,
        EquipmentType.light,
        EquipmentType.dpv,
        EquipmentType.rebreather,
      },
      _ => const {},
    };

/// The edit page's parent-item picker, for the child types only (v202): the
/// active items of [allowedTypes], less the item being edited. A selection
/// the list does not contain (not loaded yet, or no longer valid) shows as
/// "none".
class EquipmentParentPicker extends ConsumerWidget {
  /// The item being edited, which can never be its own parent; null for a
  /// new item.
  final String? equipmentId;

  final Set<EquipmentType> allowedTypes;
  final String? selectedParentId;
  final ValueChanged<String?> onChanged;

  const EquipmentParentPicker({
    super.key,
    required this.equipmentId,
    required this.allowedTypes,
    required this.selectedParentId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates =
        (ref.watch(activeEquipmentProvider).valueOrNull ??
                const <EquipmentItem>[])
            .where((e) => e.id != equipmentId && allowedTypes.contains(e.type))
            .toList();
    final known = candidates.any((e) => e.id == selectedParentId);
    return DropdownButtonFormField<String?>(
      key: const Key('equipment-parent-picker'),
      initialValue: known ? selectedParentId : null,
      decoration: InputDecoration(
        labelText: context.l10n.equipment_edit_parentLabel,
        prefixIcon: const Icon(Icons.account_tree_outlined),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(context.l10n.equipment_edit_parentNone),
        ),
        for (final e in candidates)
          DropdownMenuItem<String?>(
            value: e.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ServiceStatusIndicatorFor(
                  equipmentId: e.id,
                  density: ServiceIndicatorDensity.dot,
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(e.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
