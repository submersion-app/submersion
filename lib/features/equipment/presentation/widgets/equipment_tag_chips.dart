import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/equipment_tag_navigation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// An equipment item's tags as colored chips, under the name in the detail
/// page header (issue #1942). Tapping one opens the equipment list filtered
/// to that tag, as a dive's tag chip opens the dive list. Renders nothing
/// for an item without tags, so the header keeps its height.
class EquipmentTagChips extends ConsumerWidget {
  const EquipmentTagChips({super.key, required this.equipmentId, this.tags});

  final String equipmentId;

  /// The tags to show in place of the stored ones: those an unlocked page's
  /// sitting holds (issue #4527, phase 3).
  final List<Tag>? tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(tagsForEquipmentProvider(equipmentId)).value;
    final tags = this.tags ?? stored ?? const <Tag>[];
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in tags)
            TagChip(
              tag: tag,
              tooltip: context.l10n.equipment_detail_showEquipmentWith(
                tag.name,
              ),
              onTap: () => openEquipmentWithTag(context, ref, tag.id),
            ),
        ],
      ),
    );
  }
}
