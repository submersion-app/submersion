import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Equipment picker bottom sheet
class EquipmentPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final Set<String> selectedEquipmentIds;
  final void Function(EquipmentItem) onEquipmentSelected;

  const EquipmentPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedEquipmentIds,
    required this.onEquipmentSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only active gear belongs in the dive-edit picker; retired items are
    // reachable from the Equipment page's Retired filter (#636).
    final equipmentAsync = ref.watch(activeEquipmentProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_equipmentPicker_title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.l10n.common_action_close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: equipmentAsync.when(
            data: (equipmentList) {
              // Filter out already selected equipment
              final available = equipmentList
                  .where((e) => !selectedEquipmentIds.contains(e.id))
                  .toList();

              if (available.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        equipmentList.isEmpty
                            ? context.l10n.diveLog_equipmentPicker_noEquipment
                            : context.l10n.diveLog_equipmentPicker_allSelected,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        equipmentList.isEmpty
                            ? context.l10n.diveLog_equipmentPicker_addFromTab
                            : context.l10n.diveLog_equipmentPicker_removeToAdd,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: available.length,
                itemBuilder: (context, index) {
                  final equipment = available[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        equipmentTypeIcon(equipment.type),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(equipment.name),
                    subtitle: Text(equipment.type.displayName),
                    onTap: () => onEquipmentSelected(equipment),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                context.l10n.diveLog_equipmentPicker_errorLoading(
                  error.toString(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
