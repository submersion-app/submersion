import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The new equipment form's optional place. Saving the item writes its
/// first move here; an existing item changes place only through Move, so
/// every change lands in its history.
class EquipmentLocationField extends ConsumerWidget {
  const EquipmentLocationField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final EquipmentLocation? value;
  final ValueChanged<EquipmentLocation?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return InkWell(
      key: const ValueKey('equipment_location_field'),
      onTap: () async {
        final picked = await showEquipmentLocationPickerSheet(context, ref);
        if (picked == null) return;
        onChanged(switch (picked) {
          PlacePick(:final location) => location,
          NoLocationPick() => null,
        });
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.equipment_edit_locationLabel,
          prefixIcon: Icon(value?.kind.icon ?? Icons.place_outlined),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(value?.name ?? l10n.equipment_edit_locationNone),
      ),
    );
  }
}
