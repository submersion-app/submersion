import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "3 components" on an assembly and "Part of Cold water reg" on a part
/// (issue #1487). Reads the shared adjacency index by id, the same way the
/// service badge reads the worst-clock map, so a list of a thousand items
/// costs no per-row query. Renders nothing for an item that is neither.
class AssemblyChips extends ConsumerWidget {
  final String itemId;

  const AssemblyChips({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(equipmentComponentsIndexProvider).value;
    if (index == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final labels = <String>[];

    final count = index.componentCount(itemId);
    if (count > 0) labels.add(l10n.equipment_components_count(count));

    final parents = index.parentIdsOf(itemId);
    if (parents.length == 1) {
      // Active gear is what the list already holds; a retired parent falls
      // back to the count form rather than costing a query.
      final active = ref.watch(activeEquipmentProvider).value ?? const [];
      String? name;
      for (final item in active) {
        if (item.id == parents.single) {
          name = item.name;
          break;
        }
      }
      labels.add(
        name != null
            ? l10n.equipment_components_partOf(name)
            : l10n.equipment_components_partOfCount(1),
      );
    } else if (parents.length > 1) {
      labels.add(l10n.equipment_components_partOfCount(parents.length));
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
