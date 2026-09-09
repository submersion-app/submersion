import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
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
    final arrangement = ref.watch(equipmentArrangementProvider);

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.sort),
                    tooltip: context.l10n.equipment_arrange_tooltip,
                    onPressed: () => showEquipmentArrangeSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.common_action_close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
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

              // Filtering happens before arranging, so a type whose every
              // item is already on the dive contributes no empty heading.
              final rows = <Widget>[
                for (final group in arrangeEquipment(
                  available,
                  arrangement,
                  typeLabel: (type) => type.localizedName(context.l10n),
                )) ...[
                  if (group.type != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: EquipmentGroupHeader(type: group.type!),
                    ),
                  ...group.items.map((equipment) {
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
                      subtitle: group.type == null
                          ? Text(equipment.type.localizedName(context.l10n))
                          : null,
                      onTap: () => onEquipmentSelected(equipment),
                    );
                  }),
                ],
              ];

              return ListView.builder(
                controller: scrollController,
                itemCount: rows.length,
                itemBuilder: (context, index) => rows[index],
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
