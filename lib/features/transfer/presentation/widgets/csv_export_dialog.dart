import 'package:flutter/material.dart';

/// The type of CSV data to export.
enum CsvExportType {
  dives,
  sites,
  equipment;

  String get displayName {
    switch (this) {
      case CsvExportType.dives:
        return 'Dives';
      case CsvExportType.sites:
        return 'Sites';
      case CsvExportType.equipment:
        return 'Equipment';
    }
  }

  String get description {
    switch (this) {
      case CsvExportType.dives:
        return 'Export all dive logs as a spreadsheet';
      case CsvExportType.sites:
        return 'Export dive site locations and details';
      case CsvExportType.equipment:
        return 'Export equipment inventory and service info';
    }
  }

  IconData get icon {
    switch (this) {
      case CsvExportType.dives:
        return Icons.table_chart;
      case CsvExportType.sites:
        return Icons.location_on;
      case CsvExportType.equipment:
        return Icons.build;
    }
  }
}

/// Dialog for selecting which data type to export as CSV.
class CsvExportDialog extends StatefulWidget {
  const CsvExportDialog({super.key});

  /// Show the dialog and return the selected type, or null if cancelled.
  static Future<CsvExportType?> show(BuildContext context) {
    return showModalBottomSheet<CsvExportType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CsvExportDialog(),
    );
  }

  @override
  State<CsvExportDialog> createState() => _CsvExportDialogState();
}

class _CsvExportDialogState extends State<CsvExportDialog> {
  CsvExportType _selected = CsvExportType.dives;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('Export CSV', style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            const Divider(height: 1),
            // Options
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Type',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...CsvExportType.values.map(
                      (type) => _buildTypeOption(type, theme),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(_selected),
                      icon: const Icon(Icons.download),
                      label: const Text('Export CSV'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(CsvExportType type, ThemeData theme) {
    final isSelected = _selected == type;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selected = type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  type.icon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                    ),
                    Text(
                      type.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
