import 'package:flutter/material.dart';

import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/csv_unit_mode_selector.dart';

/// The type of CSV data to export.
enum CsvExportType {
  dives,
  sites,
  equipment,
  observations;

  String localizedDisplayName(BuildContext context) {
    switch (this) {
      case CsvExportType.dives:
        return context.l10n.transfer_csvExport_typeDives;
      case CsvExportType.sites:
        return context.l10n.transfer_csvExport_typeSites;
      case CsvExportType.equipment:
        return context.l10n.transfer_csvExport_typeEquipment;
      case CsvExportType.observations:
        return context.l10n.transfer_csvExport_typeObservations;
    }
  }

  String localizedDescription(BuildContext context) {
    switch (this) {
      case CsvExportType.dives:
        return context.l10n.transfer_csvExport_descriptionDives;
      case CsvExportType.sites:
        return context.l10n.transfer_csvExport_descriptionSites;
      case CsvExportType.equipment:
        return context.l10n.transfer_csvExport_descriptionEquipment;
      case CsvExportType.observations:
        return context.l10n.transfer_csvExport_descriptionObservations;
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
      case CsvExportType.observations:
        return Icons.fact_check;
    }
  }

  /// Whether this export has unit-bearing columns. Gear check-ins do not.
  bool get hasUnits => this != CsvExportType.observations;
}

/// What the CSV dialog returns: the data type and the unit mode.
typedef CsvExportRequest = ({CsvExportType type, CsvUnitMode unitMode});

/// Dialog for selecting which data type to export as CSV, and in which
/// units.
class CsvExportDialog extends StatefulWidget {
  const CsvExportDialog({
    super.key,
    this.initialUnitMode = CsvUnitMode.myUnits,
  });

  /// The remembered unit choice the dialog opens on.
  final CsvUnitMode initialUnitMode;

  /// Show the dialog and return the chosen type and units, or null if
  /// cancelled.
  static Future<CsvExportRequest?> show(
    BuildContext context, {
    CsvUnitMode initialUnitMode = CsvUnitMode.myUnits,
  }) {
    return showModalBottomSheet<CsvExportRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CsvExportDialog(initialUnitMode: initialUnitMode),
    );
  }

  @override
  State<CsvExportDialog> createState() => _CsvExportDialogState();
}

class _CsvExportDialogState extends State<CsvExportDialog> {
  CsvExportType _selected = CsvExportType.dives;
  late CsvUnitMode _unitMode = widget.initialUnitMode;

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
            ExcludeSemantics(
              child: Center(
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
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.table_chart, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.transfer_csvExport_dialogTitle,
                    style: theme.textTheme.titleLarge,
                  ),
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
                      context.l10n.transfer_csvExport_dataTypeHeader,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...CsvExportType.values.map(
                      (type) => _buildTypeOption(type, theme),
                    ),
                    if (_selected.hasUnits) ...[
                      const SizedBox(height: 8),
                      CsvUnitModeSelector(
                        value: _unitMode,
                        onChanged: (mode) => setState(() => _unitMode = mode),
                      ),
                    ],
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
                      child: Text(context.l10n.transfer_csvExport_cancelButton),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop((type: _selected, unitMode: _unitMode)),
                      icon: const Icon(Icons.download),
                      label: Text(context.l10n.transfer_csvExport_exportButton),
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
      child: Semantics(
        button: true,
        label: context.l10n.transfer_csvExport_semanticLabel(
          type.localizedDisplayName(context),
        ),
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
                        type.localizedDisplayName(context),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? colorScheme.primary : null,
                        ),
                      ),
                      Text(
                        type.localizedDescription(context),
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
      ),
    );
  }
}
