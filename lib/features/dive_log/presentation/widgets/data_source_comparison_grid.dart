part of 'data_sources_section.dart';

// ---------------------------------------------------------------------------
// Source Comparison Grid
// ---------------------------------------------------------------------------

/// A compact table comparing key metrics across all data sources for a dive,
/// e.g. "Perdix says 30.1 m / Teric says 30.4 m" at a glance.
///
/// Only rendered when there are 2+ sources; rows where every source has a
/// null value are omitted entirely. With two sources the columns flex to the
/// card width so both fit on a phone; with more, the columns take their
/// natural width and the table scrolls sideways.
class _SourceComparisonGrid extends StatelessWidget {
  const _SourceComparisonGrid({required this.sources, required this.units});
  final List<DiveDataSource> sources;
  final UnitFormatter units;

  static const _cellPadding = EdgeInsetsDirectional.fromSTEB(0, 6, 12, 6);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.bodyMedium;
    final headerStyle = textTheme.labelLarge;
    final labels = _labelsOf(context);

    final rows = <(String, String? Function(DiveDataSource))>[
      (
        l10n.diveLog_sources_row_maxDepth,
        (s) => s.maxDepth != null ? units.formatDepth(s.maxDepth!) : null,
      ),
      (
        l10n.diveLog_sources_row_avgDepth,
        (s) => s.avgDepth != null ? units.formatDepth(s.avgDepth!) : null,
      ),
      (
        l10n.diveLog_sources_row_duration,
        (s) => s.duration != null
            ? l10n.diveLog_sources_minutes(s.duration! ~/ 60)
            : null,
      ),
      (
        l10n.diveLog_sources_row_waterTemp,
        (s) => s.waterTemp != null
            ? units.formatTemperature(s.waterTemp!, decimals: 1)
            : null,
      ),
      (l10n.diveLog_sources_row_cns, _cnsText),
      (l10n.diveLog_sources_row_otu, (s) => s.otu?.toStringAsFixed(0)),
      (l10n.diveLog_sources_row_decoAlgorithm, (s) => s.decoAlgorithm),
      (
        l10n.diveLog_sources_row_gf,
        (s) => s.gradientFactorLow != null && s.gradientFactorHigh != null
            ? '${s.gradientFactorLow}/${s.gradientFactorHigh}'
            : null,
      ),
    ];
    final visibleRows = [
      for (final row in rows)
        if (sources.any((s) => row.$2(s) != null)) row,
    ];

    final fitsWidth = sources.length <= 2;
    final table = Table(
      key: DataSourcesSection.comparisonGridKey,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      // The metric column takes its natural width in both modes; the source
      // columns share the rest when they fit, else size to their content.
      columnWidths: {
        0: const IntrinsicColumnWidth(),
        for (var i = 1; i <= sources.length; i++)
          i: fitsWidth ? const FlexColumnWidth() : const IntrinsicColumnWidth(),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: colorScheme.outlineVariant),
      ),
      children: [
        TableRow(
          children: [
            Padding(
              padding: _cellPadding,
              child: Text(l10n.diveLog_sources_row_metric, style: labelStyle),
            ),
            for (final s in sources)
              Padding(
                padding: _cellPadding,
                child: Text(
                  resolveSourceName(s, labels),
                  style: s.isPrimary
                      ? headerStyle?.copyWith(fontWeight: FontWeight.bold)
                      : headerStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        for (final (label, pick) in visibleRows)
          TableRow(
            children: [
              Padding(
                padding: _cellPadding,
                child: Text(label, style: labelStyle),
              ),
              for (final s in sources)
                Padding(
                  padding: _cellPadding,
                  child: Text(pick(s) ?? '—', style: valueStyle),
                ),
            ],
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: fitsWidth
          // Capped so that on a wide pane the two value columns stay close
          // enough to read across; the table hugs the leading edge.
          ? Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: table,
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            ),
    );
  }
}
