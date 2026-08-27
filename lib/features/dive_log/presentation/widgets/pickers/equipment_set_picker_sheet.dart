import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Equipment set picker bottom sheet
class EquipmentSetPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final void Function(EquipmentSet set, List<EquipmentItem> items)
  onSetSelected;

  const EquipmentSetPickerSheet({
    super.key,
    required this.scrollController,
    required this.onSetSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(equipmentSetsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_equipmentSetPicker_title,
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
          child: setsAsync.when(
            data: (sets) {
              if (sets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_special_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.diveLog_equipmentSetPicker_noSets,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.diveLog_equipmentSetPicker_createHint,
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
                itemCount: sets.length,
                itemBuilder: (context, index) {
                  final set = sets[index];
                  return _EquipmentSetTile(
                    set: set,
                    onTap: (items) => onSetSelected(set, items),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                context.l10n.diveLog_equipmentSetPicker_errorLoading(
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

/// Individual equipment set tile that loads its items
class _EquipmentSetTile extends ConsumerWidget {
  final EquipmentSet set;
  final void Function(List<EquipmentItem> items) onTap;

  const _EquipmentSetTile({required this.set, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setWithItemsAsync = ref.watch(equipmentSetWithItemsProvider(set.id));

    return setWithItemsAsync.when(
      data: (setWithItems) {
        if (setWithItems == null) {
          return const SizedBox.shrink();
        }
        final items = setWithItems.items ?? [];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.folder_special,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(set.name),
          subtitle: Text(
            items.isEmpty
                ? context.l10n.diveLog_equipmentSetPicker_emptySet
                : context.l10n.diveLog_equipmentSetPicker_itemsSummary(
                    items.length,
                    items.map((e) => e.name).join(', '),
                  ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: items.isEmpty ? null : () => onTap(items),
        );
      },
      loading: () => ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: Text(set.name),
        subtitle: Text(context.l10n.diveLog_equipmentSetPicker_loading),
      ),
      error: (_, _) => ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          child: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        title: Text(set.name),
        subtitle: Text(context.l10n.diveLog_equipmentSetPicker_errorItems),
      ),
    );
  }
}
