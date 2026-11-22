import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The status an inactive item's header chip names, or null for gear in the
/// kit. Sold, Lost and Wanted (#2025) keep their own label; any other
/// inactive row is a legacy retirement (#636) and reads as Retired. Wanted
/// is named even on a row whose isActive was left true (an import).
EquipmentStatus? headerStatusOf(EquipmentItem item) {
  if (item.isWanted) return EquipmentStatus.wanted;
  if (item.isActive) return null;
  return switch (item.status) {
    EquipmentStatus.sold || EquipmentStatus.lost => item.status,
    _ => EquipmentStatus.retired,
  };
}

/// The detail header's status line: a chip naming why the item is out of
/// the kit. Wishlist gear is bought in the header block's editor (issue
/// #4527, phase 3), written with the sitting.
class EquipmentHeaderStatus extends StatelessWidget {
  const EquipmentHeaderStatus({super.key, required this.item});

  final EquipmentItem item;

  @override
  Widget build(BuildContext context) {
    final status = headerStatusOf(item);
    if (status == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text(
            status == EquipmentStatus.retired
                ? l10n.equipment_detail_retiredChip
                : status.localizedName(l10n),
          ),
          backgroundColor: scheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
