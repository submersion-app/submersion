import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/equipment_tag_navigation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// An equipment item's tags as colored chips, under the name in the detail
/// page header (issue #1942). Tapping one opens the equipment list filtered
/// to that tag, as a dive's tag chip opens the dive list. Renders nothing
/// for an item without tags, so the header keeps its height.
class EquipmentTagChips extends ConsumerWidget {
  const EquipmentTagChips({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags =
        ref.watch(tagsForEquipmentProvider(equipmentId)).value ?? const [];
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in tags)
            ActionChip(
              label: Text(tag.name),
              tooltip: context.l10n.equipment_detail_showEquipmentWith(
                tag.name,
              ),
              backgroundColor: tag.color.withValues(alpha: 0.2),
              side: BorderSide(color: tag.color),
              labelStyle: TextStyle(color: tag.color),
              visualDensity: VisualDensity.compact,
              onPressed: () => openEquipmentWithTag(context, ref, tag.id),
            ),
        ],
      ),
    );
  }
}
