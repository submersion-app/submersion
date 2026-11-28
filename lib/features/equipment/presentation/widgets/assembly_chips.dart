import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "3 components" on an assembly and "Part of Cold water reg" on a part
/// (issue #1487). Reads the shared adjacency index by id, the same way the
/// service badge reads the worst-clock map, so a list of a thousand items
/// costs no per-row query. Renders nothing for an item that is neither.
///
/// In the Equipment list's assembly view (issue #5071) the list hands in
/// [partCount], the parts listed under the row by either link, in place of
/// the component count, and [hideParentId], the assembly the row sits
/// under, whose "Part of" chip would repeat the row above.
class AssemblyChips extends ConsumerWidget {
  final String itemId;
  final int? partCount;
  final String? hideParentId;

  const AssemblyChips({
    super.key,
    required this.itemId,
    this.partCount,
    this.hideParentId,
  });

  /// Whether [AssemblyChips] would draw anything for [itemId], so a tile
  /// leaves out an empty subtitle line.
  static bool showsAny(
    ComponentsIndex index,
    String itemId, {
    int? partCount,
    String? hideParentId,
  }) =>
      (partCount ?? index.componentCount(itemId)) > 0 ||
      _parentsShown(index, itemId, hideParentId).isNotEmpty;

  static List<String> _parentsShown(
    ComponentsIndex index,
    String itemId,
    String? hideParentId,
  ) => [
    for (final parent in index.parentIdsOf(itemId))
      if (parent != hideParentId) parent,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(equipmentComponentsIndexProvider).value;
    if (index == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final labels = <String>[];

    // The assembly view's count spans components and installed parts, so
    // it says "parts" rather than "components".
    final parts = partCount;
    if (parts != null) {
      if (parts > 0) labels.add(l10n.equipment_list_partCount(parts));
    } else {
      final count = index.componentCount(itemId);
      if (count > 0) labels.add(l10n.equipment_components_count(count));
    }

    final shownParents = _parentsShown(index, itemId, hideParentId);
    if (shownParents.length == 1) {
      // Active gear is what the list already holds; a retired parent falls
      // back to the count form rather than costing a query.
      final active = ref.watch(activeEquipmentProvider).value ?? const [];
      String? name;
      for (final item in active) {
        if (item.id == shownParents.single) {
          name = item.name;
          break;
        }
      }
      labels.add(
        name != null
            ? l10n.equipment_components_partOf(name)
            : l10n.equipment_components_partOfCount(1),
      );
    } else if (shownParents.length > 1) {
      labels.add(l10n.equipment_components_partOfCount(shownParents.length));
    }

    if (labels.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
      ],
    );
  }
}
