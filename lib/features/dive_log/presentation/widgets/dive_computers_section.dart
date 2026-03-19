import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer_reading.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';

/// A collapsible section showing per-computer readings for a multi-computer dive.
///
/// Only rendered when [readings] contains 2 or more entries.  Each reading gets
/// its own card that shows depth, duration, temperature, CNS%, and GF settings
/// when available. The primary reading shows a "(primary)" chip; secondary
/// readings offer a "Set as primary" action. All cards have an overflow menu
/// with an "Unlink computer" option.
class DiveComputersSection extends StatefulWidget {
  final List<DiveComputerReading> readings;
  final String diveId;
  final UnitFormatter units;

  /// Called with the reading ID when the user confirms "Set as primary".
  final void Function(String readingId)? onSetPrimary;

  /// Called with the reading ID when the user confirms "Unlink computer".
  final void Function(String readingId)? onUnlink;

  const DiveComputersSection({
    super.key,
    required this.readings,
    required this.diveId,
    required this.units,
    this.onSetPrimary,
    this.onUnlink,
  });

  @override
  State<DiveComputersSection> createState() => _DiveComputersSectionState();
}

class _DiveComputersSectionState extends State<DiveComputersSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    // Only show when there are 2+ readings.
    if (widget.readings.length < 2) return const SizedBox.shrink();

    final count = widget.readings.length;
    final title = 'Computers ($count)';

    return CollapsibleSection(
      title: title,
      icon: Icons.watch,
      isExpanded: _isExpanded,
      onToggle: (expanded) => setState(() => _isExpanded = expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.readings.map((reading) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ComputerReadingCard(
              reading: reading,
              units: widget.units,
              onSetPrimary: widget.onSetPrimary != null
                  ? () => widget.onSetPrimary!(reading.id)
                  : null,
              onUnlink: widget.onUnlink != null
                  ? () => widget.onUnlink!(reading.id)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Internal card for a single [DiveComputerReading].
class _ComputerReadingCard extends StatelessWidget {
  final DiveComputerReading reading;
  final UnitFormatter units;
  final VoidCallback? onSetPrimary;
  final VoidCallback? onUnlink;

  const _ComputerReadingCard({
    required this.reading,
    required this.units,
    this.onSetPrimary,
    this.onUnlink,
  });

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--';
    final minutes = seconds ~/ 60;
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final labelStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.bodyMedium;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + primary badge + overflow menu
            Row(
              children: [
                Icon(Icons.watch, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          reading.displayName,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (reading.isPrimary) ...[
                        const SizedBox(width: 6),
                        _PrimaryBadge(),
                      ],
                    ],
                  ),
                ),
                // Overflow menu
                PopupMenuButton<_ReadingMenuAction>(
                  iconSize: 20,
                  onSelected: (action) {
                    switch (action) {
                      case _ReadingMenuAction.setPrimary:
                        onSetPrimary?.call();
                      case _ReadingMenuAction.unlink:
                        onUnlink?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    if (!reading.isPrimary && onSetPrimary != null)
                      const PopupMenuItem(
                        value: _ReadingMenuAction.setPrimary,
                        child: ListTile(
                          leading: Icon(Icons.star_outline),
                          title: Text('Set as primary'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onUnlink != null)
                      const PopupMenuItem(
                        value: _ReadingMenuAction.unlink,
                        child: ListTile(
                          leading: Icon(Icons.link_off),
                          title: Text('Unlink computer'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Depth / duration row
            Row(
              children: [
                Expanded(
                  child: _MetricCell(
                    label: 'Max depth',
                    value: units.formatDepth(reading.maxDepth),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'Avg depth',
                    value: units.formatDepth(reading.avgDepth),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'Duration',
                    value: _formatDuration(reading.duration),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                ),
              ],
            ),
            // Optional second row: water temp, CNS%, GF
            if (reading.waterTemp != null ||
                reading.cns != null ||
                (reading.gradientFactorLow != null &&
                    reading.gradientFactorHigh != null)) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (reading.waterTemp != null)
                    Expanded(
                      child: _MetricCell(
                        label: 'Water temp',
                        value: units.formatTemperature(reading.waterTemp),
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                    ),
                  if (reading.cns != null)
                    Expanded(
                      child: _MetricCell(
                        label: 'CNS%',
                        value: '${reading.cns!.toStringAsFixed(1)}%',
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                    ),
                  if (reading.gradientFactorLow != null &&
                      reading.gradientFactorHigh != null)
                    Expanded(
                      child: _MetricCell(
                        label: 'GF',
                        value:
                            '${reading.gradientFactorLow}/${reading.gradientFactorHigh}',
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ReadingMenuAction { setPrimary, unlink }

/// Small "(primary)" badge chip.
class _PrimaryBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'primary',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A label + value cell used in the metrics rows.
class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _MetricCell({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}
