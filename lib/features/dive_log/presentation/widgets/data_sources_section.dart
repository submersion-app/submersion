import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';

/// A collapsible section showing data source provenance for a dive.
///
/// Handles four scenarios:
/// - **No sources:** Shows a "Manual Entry" card with pen icon and creation date.
/// - **Single source:** Shows the source card with device info, details grid,
///   and original filename.
/// - **Manual + consolidated:** Two cards, each with its own metrics row.
/// - **Multi-source (N):** Cards stack vertically with primary/secondary badges.
///
/// Always visible -- unlike the old [DiveComputersSection], there is no
/// `length < 2` guard.
class DataSourcesSection extends StatefulWidget {
  final List<DiveDataSource> dataSources;
  final DateTime diveCreatedAt;
  final String diveId;
  final UnitFormatter units;

  /// Currently viewed source ID (tap-to-view interaction).
  final String? viewedSourceId;

  /// Called with the reading ID when the user confirms "Set as primary".
  final void Function(String readingId)? onSetPrimary;

  /// Called with the reading ID when the user confirms "Unlink".
  final void Function(String readingId)? onUnlink;

  /// Called when the user taps a source card to temporarily view it.
  final void Function(String sourceId)? onTapSource;

  const DataSourcesSection({
    super.key,
    required this.dataSources,
    required this.diveCreatedAt,
    required this.diveId,
    required this.units,
    this.viewedSourceId,
    this.onSetPrimary,
    this.onUnlink,
    this.onTapSource,
  });

  @override
  State<DataSourcesSection> createState() => _DataSourcesSectionState();
}

class _DataSourcesSectionState extends State<DataSourcesSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final count = widget.dataSources.length;
    final isMultiSource = count >= 2;
    final title = isMultiSource ? 'Data Sources' : 'Data Source';

    return CollapsibleSection(
      title: title,
      icon: Icons.storage,
      isExpanded: _isExpanded,
      onToggle: (expanded) => setState(() => _isExpanded = expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildCards(isMultiSource),
      ),
    );
  }

  List<Widget> _buildCards(bool isMultiSource) {
    if (widget.dataSources.isEmpty) {
      return [
        _ManualEntryCard(
          diveCreatedAt: widget.diveCreatedAt,
          units: widget.units,
        ),
      ];
    }

    final children = <Widget>[];
    for (var i = 0; i < widget.dataSources.length; i++) {
      final source = widget.dataSources[i];
      final isViewing = widget.viewedSourceId == source.id;
      if (i > 0) {
        children.add(const Divider(height: 1));
      }
      children.add(
        _DataSourceCard(
          source: source,
          units: widget.units,
          showBadges: isMultiSource,
          isViewing: isViewing,
          onSetPrimary: widget.onSetPrimary != null
              ? () => widget.onSetPrimary!(source.id)
              : null,
          onUnlink: widget.onUnlink != null
              ? () => widget.onUnlink!(source.id)
              : null,
          onTap: widget.onTapSource != null
              ? () => widget.onTapSource!(source.id)
              : null,
        ),
      );
    }

    return children;
  }
}

// ---------------------------------------------------------------------------
// Manual Entry Card
// ---------------------------------------------------------------------------

/// Card shown when a dive has no imported data sources (manual entry).
class _ManualEntryCard extends StatelessWidget {
  final DateTime diveCreatedAt;
  final UnitFormatter units;

  const _ManualEntryCard({required this.diveCreatedAt, required this.units});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + "Manual Entry" + badge
          Row(
            children: [
              Icon(Icons.edit, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Manual Entry',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _Badge(
                      label: 'Manual',
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Creation date
          Text(
            'Created ${_formatDate(diveCreatedAt)}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}

// ---------------------------------------------------------------------------
// Data Source Card
// ---------------------------------------------------------------------------

/// Card for a single [DiveDataSource] with device info, details, and metrics.
class _DataSourceCard extends StatelessWidget {
  final DiveDataSource source;
  final UnitFormatter units;
  final bool showBadges;
  final bool isViewing;
  final VoidCallback? onSetPrimary;
  final VoidCallback? onUnlink;
  final VoidCallback? onTap;

  const _DataSourceCard({
    required this.source,
    required this.units,
    required this.showBadges,
    required this.isViewing,
    this.onSetPrimary,
    this.onUnlink,
    this.onTap,
  });

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--';
    final minutes = seconds ~/ 60;
    return '$minutes min';
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat('h:mm a').format(dateTime);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final labelStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.bodyMedium;

    // Primary card gets a green-tinted left border when in multi-source mode.
    // Viewing card gets a blue highlight.
    BoxDecoration? cardDecoration;
    if (showBadges && source.isPrimary) {
      cardDecoration = BoxDecoration(
        border: Border(left: BorderSide(color: colorScheme.primary, width: 3)),
      );
    }
    if (isViewing) {
      cardDecoration = BoxDecoration(
        border: Border(left: BorderSide(color: colorScheme.tertiary, width: 3)),
      );
    }

    final hasOverflowMenu = onSetPrimary != null || onUnlink != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: cardDecoration,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: icon + model name + badges + overflow menu
              Row(
                children: [
                  Icon(Icons.watch, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            source.displayName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showBadges) ...[
                          const SizedBox(width: 6),
                          if (isViewing)
                            _Badge(
                              label: 'Viewing',
                              color: colorScheme.tertiaryContainer,
                            )
                          else if (source.isPrimary)
                            _Badge(
                              label: 'Primary',
                              color: colorScheme.primaryContainer,
                            )
                          else
                            _Badge(
                              label: 'Secondary',
                              color: colorScheme.surfaceContainerHighest,
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (hasOverflowMenu)
                    PopupMenuButton<_SourceMenuAction>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      iconSize: 20,
                      onSelected: (action) {
                        switch (action) {
                          case _SourceMenuAction.setPrimary:
                            onSetPrimary?.call();
                          case _SourceMenuAction.unlink:
                            onUnlink?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        if (!source.isPrimary && onSetPrimary != null)
                          const PopupMenuItem(
                            value: _SourceMenuAction.setPrimary,
                            child: ListTile(
                              leading: Icon(Icons.star_outline),
                              title: Text('Set as primary'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        if (onUnlink != null)
                          const PopupMenuItem(
                            value: _SourceMenuAction.unlink,
                            child: ListTile(
                              leading: Icon(Icons.link_off),
                              title: Text('Unlink'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Details grid: serial, format, entry/exit times, import date
              _DetailsGrid(
                source: source,
                labelStyle: labelStyle,
                valueStyle: valueStyle,
                formatTime: _formatTime,
                formatDate: _formatDate,
              ),
              const SizedBox(height: 8),
              // Metrics row: max depth, duration, temp, CNS
              Row(
                children: [
                  Expanded(
                    child: _MetricCell(
                      label: 'Max depth',
                      value: units.formatDepth(source.maxDepth),
                      labelStyle: labelStyle,
                      valueStyle: valueStyle,
                    ),
                  ),
                  Expanded(
                    child: _MetricCell(
                      label: 'Duration',
                      value: _formatDuration(source.duration),
                      labelStyle: labelStyle,
                      valueStyle: valueStyle,
                    ),
                  ),
                  Expanded(
                    child: _MetricCell(
                      label: 'Water temp',
                      value: units.formatTemperature(source.waterTemp),
                      labelStyle: labelStyle,
                      valueStyle: valueStyle,
                    ),
                  ),
                  Expanded(
                    child: _MetricCell(
                      label: 'CNS%',
                      value: source.cns != null
                          ? '${source.cns!.toStringAsFixed(1)}%'
                          : '--',
                      labelStyle: labelStyle,
                      valueStyle: valueStyle,
                    ),
                  ),
                ],
              ),
              // Filename at bottom
              if (source.sourceFileName != null) ...[
                const SizedBox(height: 8),
                Text(
                  source.sourceFileName!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------

// Details Grid
// ---------------------------------------------------------------------------

/// Displays serial, format, entry/exit times, and import date in a compact grid.
class _DetailsGrid extends StatelessWidget {
  final DiveDataSource source;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final String Function(DateTime?) formatTime;
  final String Function(DateTime) formatDate;

  const _DetailsGrid({
    required this.source,
    this.labelStyle,
    this.valueStyle,
    required this.formatTime,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (source.computerSerial != null) {
      items.add(
        _MetricCell(
          label: 'Serial',
          value: source.computerSerial!,
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      );
    }

    if (source.sourceFormat != null) {
      items.add(
        _MetricCell(
          label: 'Format',
          value: source.sourceFormat!,
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      );
    }

    if (source.entryTime != null) {
      items.add(
        _MetricCell(
          label: 'Entry',
          value: formatTime(source.entryTime),
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      );
    }

    if (source.exitTime != null) {
      items.add(
        _MetricCell(
          label: 'Exit',
          value: formatTime(source.exitTime),
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      );
    }

    items.add(
      _MetricCell(
        label: 'Imported',
        value: formatDate(source.importedAt),
        labelStyle: labelStyle,
        valueStyle: valueStyle,
      ),
    );

    if (items.isEmpty) return const SizedBox.shrink();

    // Layout in rows of 3
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 3) {
      final end = (i + 3 > items.length) ? items.length : i + 3;
      final rowItems = items.sublist(i, end);
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 3 < items.length ? 4 : 0),
          child: Row(
            children: [
              for (final item in rowItems) Expanded(child: item),
              // Fill remaining space if row is incomplete
              for (var j = rowItems.length; j < 3; j++)
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

enum _SourceMenuAction { setPrimary, unlink }

/// A small badge chip with customizable background color.
class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A label + value cell used in the metrics and details rows.
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
