import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';

/// Shows the [TableColumnPicker] as a modal bottom sheet.
void showTableColumnPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const TableColumnPicker(),
  );
}

/// Bottom sheet that lets users toggle column visibility in the table view.
///
/// Fields are grouped by [DiveFieldCategory]. Pinned columns have their
/// checkbox disabled to prevent accidental removal.
class TableColumnPicker extends ConsumerWidget {
  const TableColumnPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tableViewConfigProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
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

            // Scrollable field list grouped by category
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  for (final category in DiveFieldCategory.values)
                    _CategorySection(
                      category: category,
                      config: config,
                      onToggle: (field) => ref
                          .read(tableViewConfigProvider.notifier)
                          .toggleColumn(field),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders a category header followed by a [CheckboxListTile] for each field
/// in that category. Skipped entirely when the category has no fields.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.config,
    required this.onToggle,
  });

  final DiveFieldCategory category;
  final TableViewConfig config;
  final void Function(DiveField field) onToggle;

  @override
  Widget build(BuildContext context) {
    final fields = DiveField.fieldsForCategory(category);
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
          _FieldTile(field: field, config: config, onToggle: onToggle),
      ],
    );
  }
}

/// A single [CheckboxListTile] row for one [DiveField].
class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.field,
    required this.config,
    required this.onToggle,
  });

  final DiveField field;
  final TableViewConfig config;
  final void Function(DiveField field) onToggle;

  @override
  Widget build(BuildContext context) {
    final existing = config.columns.where((c) => c.field == field).firstOrNull;
    final isVisible = existing != null;
    final isPinned = existing?.isPinned ?? false;

    return CheckboxListTile(
      value: isVisible,
      onChanged: isPinned ? null : (_) => onToggle(field),
      title: Text(field.shortLabel),
      secondary: field.icon != null ? Icon(field.icon, size: 18) : null,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }
}
