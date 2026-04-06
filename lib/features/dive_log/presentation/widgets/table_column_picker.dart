import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shows the [TableColumnPicker] as a modal bottom sheet.
void showTableColumnPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const TableColumnPicker(),
  );
}

/// Bottom sheet that lets users toggle column visibility and reorder columns.
///
/// Top section: reorderable list of visible columns with pin/remove controls.
/// Bottom section: available fields grouped by [DiveFieldCategory] with add buttons.
class TableColumnPicker extends ConsumerWidget {
  const TableColumnPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tableViewConfigProvider);
    final notifier = ref.read(tableViewConfigProvider.notifier);
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

            // Header: title + Done button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.columnConfig_columns,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.columnConfig_done),
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
                  // -- Visible columns (reorderable) --
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      context.l10n.columnConfig_visibleColumns.toUpperCase(),
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
                    onReorder: notifier.reorderColumn,
                    itemBuilder: (context, index) {
                      final col = config.columns[index];
                      return ListTile(
                        key: ValueKey(col.field),
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
                              onPressed: () => notifier.togglePin(col.field),
                            ),
                            if (!col.isPinned)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove',
                                onPressed: () =>
                                    notifier.toggleColumn(col.field),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  const Divider(height: 1),

                  // -- Available fields (grouped by category) --
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      context.l10n.columnConfig_availableFields.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  for (final category in DiveFieldCategory.values)
                    _AvailableCategorySection(
                      category: category,
                      visibleFields: visibleFields,
                      onAdd: notifier.toggleColumn,
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
class _AvailableCategorySection extends StatelessWidget {
  const _AvailableCategorySection({
    required this.category,
    required this.visibleFields,
    required this.onAdd,
  });

  final DiveFieldCategory category;
  final Set<DiveField> visibleFields;
  final void Function(DiveField field) onAdd;

  @override
  Widget build(BuildContext context) {
    final fields = DiveField.fieldsForCategory(
      category,
    ).where((f) => !visibleFields.contains(f)).toList();
    if (fields.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            category.name.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
        for (final field in fields)
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
