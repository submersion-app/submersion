import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';

/// An equipment item's tags as colored chips, under the name in the detail
/// page header (issue #1942), styled like the tag chips on dive and site
/// detail. Renders nothing for an item without tags, so the header keeps
/// its height.
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
            Chip(
              label: Text(tag.name),
              backgroundColor: tag.color.withValues(alpha: 0.2),
              side: BorderSide(color: tag.color),
              labelStyle: TextStyle(color: tag.color),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
