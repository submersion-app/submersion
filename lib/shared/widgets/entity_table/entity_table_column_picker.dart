import 'package:flutter/material.dart';

import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';

/// Shows the [EntityTableColumnPicker] as a modal bottom sheet.
void showEntityTableColumnPicker<F extends EntityField>(
  BuildContext context, {
  required EntityTableViewConfig<F> config,
  required EntityFieldAdapter<dynamic, F> adapter,
  required void Function(F field) onToggleColumn,
  required void Function(int oldIndex, int newIndex) onReorderColumn,
  required void Function(F field) onTogglePin,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => EntityTableColumnPicker<F>(
      config: config,
      adapter: adapter,
      onToggleColumn: onToggleColumn,
      onReorderColumn: onReorderColumn,
      onTogglePin: onTogglePin,
    ),
  );
}

/// Generic bottom sheet that lets users toggle column visibility and reorder
/// columns for any entity table.
///
/// Top section: reorderable list of visible columns with pin/remove controls.
/// Bottom section: available fields grouped by category with add buttons.
class EntityTableColumnPicker<F extends EntityField> extends StatelessWidget {
  final EntityTableViewConfig<F> config;
  final EntityFieldAdapter<dynamic, F> adapter;
  final void Function(F field) onToggleColumn;
  final void Function(int oldIndex, int newIndex) onReorderColumn;
  final void Function(F field) onTogglePin;

  const EntityTableColumnPicker({
    super.key,
    required this.config,
    required this.adapter,
    required this.onToggleColumn,
    required this.onReorderColumn,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleFields = config.columns.map((c) => c.field).toSet();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Columns', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // Visible columns (reorderable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'VISIBLE COLUMNS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: config.columns.length,
                    onReorder: onReorderColumn,
                    itemBuilder: (context, index) {
                      final col = config.columns[index];
                      return ListTile(
                        key: ValueKey(col.field.name),
                        dense: true,
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(col.field.displayName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                col.isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 18,
                              ),
                              visualDensity: VisualDensity.compact,
                              tooltip: col.isPinned ? 'Unpin' : 'Pin',
                              onPressed: () => onTogglePin(col.field),
                            ),
                            if (!col.isPinned)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove',
                                onPressed: () => onToggleColumn(col.field),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  const Divider(height: 1),

                  // Available fields (grouped by category)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'AVAILABLE FIELDS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  for (final entry in adapter.fieldsByCategory.entries)
                    _AvailableCategorySection<F>(
                      categoryName: entry.key,
                      fields: entry.value,
                      visibleFields: visibleFields,
                      onAdd: onToggleColumn,
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders a category header followed by add-buttons for each hidden field
/// in that category. Skipped entirely when all fields are already visible.
class _AvailableCategorySection<F extends EntityField> extends StatelessWidget {
  const _AvailableCategorySection({
    required this.categoryName,
    required this.fields,
    required this.visibleFields,
    required this.onAdd,
  });

  final String categoryName;
  final List<F> fields;
  final Set<EntityField> visibleFields;
  final void Function(F field) onAdd;

  @override
  Widget build(BuildContext context) {
    final hiddenFields = fields
        .where((f) => !visibleFields.contains(f))
        .toList();
    if (hiddenFields.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            categoryName.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
        for (final field in hiddenFields)
          ListTile(
            dense: true,
            leading: field.icon != null ? Icon(field.icon, size: 18) : null,
            title: Text(field.displayName),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Add',
              onPressed: () => onAdd(field),
            ),
          ),
      ],
    );
  }
}
