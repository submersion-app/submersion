import 'package:flutter/material.dart';

import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "My units" / "Metric" for a CSV export, with a line saying what the
/// selected mode writes. Shared by the Transfer CSV dialog and the export
/// destination sheet so both read the same.
class CsvUnitModeSelector extends StatelessWidget {
  const CsvUnitModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CsvUnitMode value;
  final ValueChanged<CsvUnitMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.transfer_csvExport_unitsHeader,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<CsvUnitMode>(
          key: const ValueKey('csv-unit-mode-selector'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: CsvUnitMode.myUnits,
              label: Text(l10n.transfer_csvExport_unitsMine),
            ),
            ButtonSegment(
              value: CsvUnitMode.metric,
              label: Text(l10n.transfer_csvExport_unitsMetric),
            ),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        const SizedBox(height: 4),
        Text(
          value == CsvUnitMode.myUnits
              ? l10n.transfer_csvExport_unitsMineDescription
              : l10n.transfer_csvExport_unitsMetricDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
