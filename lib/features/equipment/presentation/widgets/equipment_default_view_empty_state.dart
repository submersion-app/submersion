import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The empty list when the diver's default view (#2628) hides every item
/// they own: it names the view as the cause and offers All Equipment,
/// rather than inviting them to add gear they already have.
class EquipmentDefaultViewEmptyState extends ConsumerWidget {
  const EquipmentDefaultViewEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.backpack,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.equipment_list_emptyState_defaultView_title,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.equipment_list_emptyState_defaultView_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('equipment_list_showAll'),
            onPressed: () {
              final notifier = ref.read(equipmentFilterProvider.notifier);
              notifier.state = notifier.state.copyWith(allStatuses: true);
            },
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(l10n.equipment_list_emptyState_showAll),
          ),
        ],
      ),
    );
  }
}
