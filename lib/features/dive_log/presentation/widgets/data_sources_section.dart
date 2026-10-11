import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

part 'data_source_comparison_grid.dart';

/// Localized fallback labels for [resolveSourceName], shared by the
/// comparison grid header and the source card title.
SourceNameLabels _labelsOf(BuildContext context) {
  final l10n = context.l10n;
  return SourceNameLabels(
    unknownComputer: l10n.diveLog_sources_unknownComputer,
    manualEntry: l10n.diveLog_sources_manualEntry,
    importedFile: l10n.diveLog_sources_importedFile,
    editedSuffix: l10n.diveLog_sources_editedSuffix,
  );
}

/// CNS as a whole percentage, or null when the source did not report one.
/// One formatter for the comparison grid and the single-source metrics row,
/// so a value never reads "18%" in one place and "18.4%" in the other.
String? _cnsText(DiveDataSource s) =>
    s.cns != null ? '${s.cns!.toStringAsFixed(0)}%' : null;

/// A collapsible section showing data source provenance for a dive.
///
/// Handles three scenarios:
/// - **No sources:** Shows a "Manual Entry" card with pen icon and creation date.
/// - **Single source:** Shows the source card with device info, a provenance
///   list and one metrics row.
/// - **Multi-source (N):** A comparison table carries every per-source
///   number; the cards beneath it carry identity and provenance only, so no
///   value is printed twice (issue #3247).
///
/// Section-wide actions (Compare in 3D, Separate combined dives) live in a
/// menu in the section header, reachable whether or not the section is
/// expanded.
class DataSourcesSection extends StatefulWidget {
  /// The header menu button. Absent when no section-wide action applies.
  static const sectionMenuKey = Key('data-sources-section-menu');

  /// The multi-source comparison table.
  static const comparisonGridKey = Key('data-sources-comparison-grid');

  /// The card for one source.
  static Key cardKey(String sourceId) => Key('data-source-card-$sourceId');

  final List<DiveDataSource> dataSources;
  final DateTime diveCreatedAt;
  final String diveId;
  final UnitFormatter units;

  /// Currently viewed source ID (tap-to-view interaction).
  final String? viewedSourceId;

  /// Called with the reading ID when the user confirms "Set as primary".
  final void Function(String readingId)? onSetPrimary;

  /// Called with the reading ID when the user chooses "Split into
  /// separate dive" (confirmation happens in the caller).
  final void Function(String readingId)? onSplit;

  /// Called when the user chooses "Separate combined dives" (confirmation
  /// happens in the caller). Null hides the action.
  ///
  /// A dive-level action rather than a per-source one: it is the inverse of
  /// Combine, and a Combine's segments do not line up with the display
  /// sources. Two file imports collapse to one card (issue #1451), and a
  /// dive consolidated before it was combined has one card per computer,
  /// each straddling both halves.
  final VoidCallback? onSeparate;

  /// Called when the user taps a source card to temporarily view it.
  final void Function(String sourceId)? onTapSource;

  /// Called when the user picks "Compare in 3D" (offered only for
  /// multi-source dives). Null hides the action.
  final VoidCallback? onCompareIn3d;

  const DataSourcesSection({
    super.key,
    required this.dataSources,
    required this.diveCreatedAt,
    required this.diveId,
    required this.units,
    this.viewedSourceId,
    this.onSetPrimary,
    this.onSplit,
    this.onSeparate,
    this.onTapSource,
    this.onCompareIn3d,
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
    final title = context.l10n.diveLog_sources_sectionTitle(count);

    // A lone source has nothing to compare, so the 3D entry is withheld;
    // Separate depends only on the dive having been combined.
    final onCompare = isMultiSource ? widget.onCompareIn3d : null;
    final hasSectionMenu = onCompare != null || widget.onSeparate != null;

    return CollapsibleSection(
      title: title,
      icon: Icons.storage,
      isExpanded: _isExpanded,
      onToggle: (expanded) => setState(() => _isExpanded = expanded),
      headerActions: hasSectionMenu
          ? _SectionMenu(
              key: DataSourcesSection.sectionMenuKey,
              onCompareIn3d: onCompare,
              onSeparate: widget.onSeparate,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildChildren(isMultiSource),
      ),
    );
  }

  List<Widget> _buildChildren(bool isMultiSource) {
    if (widget.dataSources.isEmpty) {
      return [
        _ManualEntryCard(
          diveCreatedAt: widget.diveCreatedAt,
          units: widget.units,
        ),
      ];
    }

    final children = <Widget>[];
    if (isMultiSource) {
      children.add(
        _SourceComparisonGrid(sources: widget.dataSources, units: widget.units),
      );
      children.add(const Divider(height: 1));
    }
    for (var i = 0; i < widget.dataSources.length; i++) {
      final source = widget.dataSources[i];
      if (i > 0) {
        children.add(const Divider(height: 1));
      }
      children.add(
        _DataSourceCard(
          source: source,
          units: widget.units,
          showBadges: isMultiSource,
          isViewing: widget.viewedSourceId == source.id,
          onSetPrimary: widget.onSetPrimary != null
              ? () => widget.onSetPrimary!(source.id)
              : null,
          onSplit: widget.onSplit != null && isMultiSource
              ? () => widget.onSplit!(source.id)
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
// Section Menu
// ---------------------------------------------------------------------------

enum _SectionMenuAction { compareIn3d, separate }

/// One entry of the section or card menu: a leading icon and a label with
/// the tile's own padding removed, since the popup supplies its own.
PopupMenuItem<T> _menuItem<T>(T value, IconData icon, String label) {
  return PopupMenuItem<T>(
    value: value,
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      contentPadding: EdgeInsets.zero,
    ),
  );
}

/// The header menu holding the section-wide actions. Built only when at
/// least one applies, so it never opens onto an empty menu.
class _SectionMenu extends StatelessWidget {
  const _SectionMenu({super.key, this.onCompareIn3d, this.onSeparate});

  final VoidCallback? onCompareIn3d;
  final VoidCallback? onSeparate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<_SectionMenuAction>(
      tooltip: l10n.diveLog_sources_sectionMenuTooltip,
      icon: const Icon(Icons.more_vert, size: 20),
      // Compact so the header keeps its usual height; the padding shrink in
      // CollapsibleSection assumes a 40px button.
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
      onSelected: (action) {
        switch (action) {
          case _SectionMenuAction.compareIn3d:
            onCompareIn3d?.call();
          case _SectionMenuAction.separate:
            onSeparate?.call();
        }
      },
      itemBuilder: (context) => [
        if (onCompareIn3d != null)
          _menuItem(
            _SectionMenuAction.compareIn3d,
            Icons.view_in_ar,
            l10n.diveLog_sources_compareIn3d,
          ),
        if (onSeparate != null)
          _menuItem(
            _SectionMenuAction.separate,
            Icons.call_split,
            l10n.diveLog_sources_menu_separate,
          ),
      ],
    );
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.diveLog_sources_manualEntry,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              _Badge(
                label: context.l10n.diveLog_sources_badge_manual,
                color: colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.diveLog_sources_created(
              units.formatDate(diveCreatedAt),
            ),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data Source Card
// ---------------------------------------------------------------------------

enum _SourceMenuAction { setPrimary, split }

/// Card for a single [DiveDataSource]: identity, status chips, the per-source
/// menu and a provenance list. On a single-source dive it also carries the
/// metrics row that the comparison grid shows for multi-source dives.
class _DataSourceCard extends StatelessWidget {
  final DiveDataSource source;
  final UnitFormatter units;
  final bool showBadges;
  final bool isViewing;
  final VoidCallback? onSetPrimary;
  final VoidCallback? onSplit;
  final VoidCallback? onTap;

  const _DataSourceCard({
    required this.source,
    required this.units,
    required this.showBadges,
    required this.isViewing,
    this.onSetPrimary,
    this.onSplit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // When the header shows the computer's friendly name, surface the model
    // beneath it -- but only when it adds information (i.e. the friendly name
    // was customized away from the model). Un-renamed computers, whose name
    // defaults to the model, get no redundant subtitle.
    final modelSubtitle =
        source.computerName != null &&
            source.computerModel != null &&
            source.computerModel != source.computerName
        ? source.computerModel
        : null;

    // The icon shows only when the menu would have an entry: a lone
    // primary source has none, and an icon over an empty menu opens
    // nothing (#2974).
    final canSetPrimary = !source.isPrimary && onSetPrimary != null;
    final canSplit = onSplit != null;
    final hasOverflowMenu = canSetPrimary || canSplit;

    final chips = <Widget>[
      if (showBadges && source.isPrimary)
        _Badge(
          label: context.l10n.diveLog_computerSource_badge_primary,
          color: colorScheme.primaryContainer,
        ),
      if (showBadges && isViewing)
        _Badge(
          label: context.l10n.diveLog_sources_badge_viewing,
          color: colorScheme.tertiaryContainer,
        ),
    ];

    return KeyedSubtree(
      key: DataSourcesSection.cardKey(source.id),
      child: Material(
        // The viewed card is tinted with an opaque theme role rather than a
        // translucent overlay, so it reads the same on every preset.
        // Gated like the Viewing chip: a stale viewed id on a dive that has
        // dropped to one source would otherwise tint a card with no chip to
        // say why.
        color: showBadges && isViewing
            ? colorScheme.surfaceContainerHighest
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              16,
              12,
              hasOverflowMenu ? 4 : 16,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.watch, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  resolveSourceName(source, _labelsOf(context)),
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              for (final chip in chips) ...[
                                const SizedBox(width: 6),
                                chip,
                              ],
                            ],
                          ),
                          if (modelSubtitle != null)
                            Text(
                              modelSubtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                            case _SourceMenuAction.split:
                              onSplit?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          if (canSetPrimary)
                            _menuItem(
                              _SourceMenuAction.setPrimary,
                              Icons.star_outline,
                              context.l10n.diveLog_sources_menu_setPrimary,
                            ),
                          if (canSplit)
                            _menuItem(
                              _SourceMenuAction.split,
                              Icons.call_split,
                              context.l10n.diveLog_sources_menu_split,
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  // The header trims its end inset to seat the menu button;
                  // the body below it keeps the full 16.
                  padding: EdgeInsetsDirectional.only(
                    end: hasOverflowMenu ? 12 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProvenanceList(source: source, units: units),
                      if (!showBadges) ...[
                        const SizedBox(height: 12),
                        _MetricsRow(source: source, units: units),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provenance List
// ---------------------------------------------------------------------------

/// Serial, format, times, import date and file name as one aligned
/// label/value list. The label column takes the width of its widest label,
/// so it lines up in every locale; rows without a value are left out.
class _ProvenanceList extends StatelessWidget {
  final DiveDataSource source;
  final UnitFormatter units;

  const _ProvenanceList({required this.source, required this.units});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.bodyMedium;

    final rows = <(String, String)>[
      if (source.computerSerial != null)
        (l10n.diveLog_sources_detail_serial, source.computerSerial!),
      if (source.sourceFormat != null)
        (l10n.diveLog_sources_detail_format, source.sourceFormat!),
      ..._timeRows(l10n),
      (
        l10n.diveLog_sources_detail_imported,
        units.formatDate(source.importedAt),
      ),
      if (source.sourceFileName != null)
        (l10n.diveLog_sources_detail_file, source.sourceFileName!),
    ];

    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (final (label, value) in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16, bottom: 4),
                child: Text(label, style: labelStyle),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  value,
                  style: valueStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Entry and exit merged into one Times row when both are known; a lone
  /// time keeps its own Entry or Exit label so it is not mistaken for a span.
  List<(String, String)> _timeRows(AppLocalizations l10n) {
    final entry = source.entryTime;
    final exit = source.exitTime;
    if (entry != null && exit != null) {
      return [
        (
          l10n.diveLog_sources_detail_times,
          l10n.diveLog_sources_timeRange(
            units.formatTime(entry),
            units.formatTime(exit),
          ),
        ),
      ];
    }
    if (entry != null) {
      return [(l10n.diveLog_edit_row_entry, units.formatTime(entry))];
    }
    if (exit != null) {
      return [(l10n.diveLog_edit_row_exit, units.formatTime(exit))];
    }
    return const [];
  }
}

// ---------------------------------------------------------------------------
// Metrics Row (single source)
// ---------------------------------------------------------------------------

/// Max depth, duration, water temperature and CNS for a single-source dive,
/// formatted the same way the comparison grid formats them.
class _MetricsRow extends StatelessWidget {
  final DiveDataSource source;
  final UnitFormatter units;

  const _MetricsRow({required this.source, required this.units});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.bodyMedium;

    final cells = <(String, String)>[
      (l10n.diveLog_sources_row_maxDepth, units.formatDepth(source.maxDepth)),
      (
        l10n.diveLog_sources_row_duration,
        source.duration != null
            ? l10n.diveLog_sources_minutes(source.duration! ~/ 60)
            : '--',
      ),
      (
        l10n.diveLog_sources_row_waterTemp,
        units.formatTemperature(source.waterTemp, decimals: 1),
      ),
      (l10n.diveLog_sources_row_cns, _cnsText(source) ?? '--'),
    ];

    return Row(
      children: [
        for (final (label, value) in cells)
          Expanded(
            child: _MetricCell(
              label: label,
              value: value,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

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

/// A label + value cell used in the metrics row.
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
