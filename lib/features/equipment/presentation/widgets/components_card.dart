import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_role_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Components card on the equipment detail page (issue #1487): the parts
/// this item is assembled from, each with its role, its own service dot,
/// inline edit and remove actions, and drag-to-reorder.
///
/// Lives on the detail page, not the edit form, like every other cross-item
/// edge (service clocks, documents, unit configurations): a new item has no
/// id until it is saved.
class ComponentsCard extends ConsumerWidget {
  final String equipmentId;

  const ComponentsCard({super.key, required this.equipmentId});

  Color _dotColor(BuildContext context, ServiceClockSeverity? severity) {
    final scheme = Theme.of(context).colorScheme;
    return switch (severity) {
      ServiceClockSeverity.overdue => scheme.error,
      ServiceClockSeverity.dueSoon => scheme.tertiary,
      _ => scheme.surfaceContainerHighest,
    };
  }

  Future<void> _editRole(
    BuildContext context,
    WidgetRef ref,
    EquipmentComponent part,
  ) async {
    final repository = ref.read(equipmentComponentRepositoryProvider);
    final suggestions = await repository.distinctRoles();
    if (!context.mounted) return;
    final role = await showComponentRoleDialog(
      context,
      initial: part.role,
      suggestions: suggestions.where((r) => r != part.role).toList(),
    );
    if (role == null || role == part.role) return;
    await repository.updateRole(part.id, role);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final partsAsync = ref.watch(equipmentComponentsProvider(equipmentId));
    final worstClocks =
        ref.watch(equipmentWorstClockProvider).value ?? const {};
    final repository = ref.read(equipmentComponentRepositoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.equipment_components_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      showComponentPicker(context, parentId: equipmentId),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.equipment_components_add),
                ),
              ],
            ),
            const Divider(),
            partsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  Padding(padding: const EdgeInsets.all(8), child: Text('$e')),
              data: (parts) {
                if (parts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.equipment_components_empty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    final ids = parts.map((p) => p.id).toList();
                    if (newIndex > oldIndex) newIndex -= 1;
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    repository.reorder(equipmentId, ids);
                  },
                  children: [
                    for (final (index, part) in parts.indexed)
                      _PartTile(
                        key: ValueKey(part.id),
                        index: index,
                        part: part,
                        dotColor: _dotColor(
                          context,
                          worstClocks[part.componentEquipmentId]
                              ?.status
                              .severity,
                        ),
                        onEditRole: () => _editRole(context, ref, part),
                        onRemove: () => repository.removeComponent(part.id),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PartTile extends StatelessWidget {
  final int index;
  final EquipmentComponent part;
  final Color dotColor;
  final VoidCallback onEditRole;
  final VoidCallback onRemove;

  const _PartTile({
    super.key,
    required this.index,
    required this.part,
    required this.dotColor,
    required this.onEditRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = part.component;
    final name = item?.name ?? part.componentEquipmentId;
    final type = item?.type ?? EquipmentType.other;
    final retired =
        item != null &&
        (item.status == EquipmentStatus.retired || !item.isActive);
    final subtitle = part.role.isNotEmpty
        ? part.role
        : type.localizedName(l10n);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Icon(equipmentTypeIcon(type)),
          Icon(Icons.circle, size: 10, color: dotColor),
        ],
      ),
      title: Text(name),
      subtitle: Row(
        children: [
          Flexible(child: Text(subtitle, overflow: TextOverflow.ellipsis)),
          if (retired) ...[
            const SizedBox(width: 8),
            Text(
              EquipmentStatus.retired.localizedName(l10n),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push('/equipment/${part.componentEquipmentId}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.equipment_components_editRole,
            onPressed: onEditRole,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.equipment_components_remove,
            onPressed: onRemove,
          ),
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: l10n.equipment_components_reorder,
              child: const Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}
