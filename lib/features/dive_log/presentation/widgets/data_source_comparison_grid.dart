part of 'data_sources_section.dart';

// ---------------------------------------------------------------------------
// Source Comparison Grid
// ---------------------------------------------------------------------------

/// A compact table comparing every data source of a dive side by side: the
/// key metrics (e.g. "Perdix says 30.1 m / Teric says 30.4 m"), then each
/// source's provenance (serial, format, times, import date and file), so a
/// multi-source dive shows one table rather than a list per card (#3281).
///
/// Only rendered when there are 2+ sources; rows where every source has a
/// null value are omitted entirely. With two sources the columns flex to the
/// card width so both fit on a phone; with more, the columns take their
/// natural width, capped at [DataSourcesSection.maxScrollingCellWidth], and
/// the table scrolls sideways.
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
      (l10n.diveLog_sources_detail_serial, (s) => s.computerSerial),
      (l10n.diveLog_sources_detail_format, (s) => s.sourceFormat),
      ..._timeRows(l10n),
      (
        l10n.diveLog_sources_detail_imported,
        (s) => units.formatDate(s.importedAt),
      ),
      (l10n.diveLog_sources_detail_file, (s) => s.sourceFileName),
    ];
    final visibleRows = [
      for (final row in rows)
        if (sources.any((s) => row.$2(s) != null)) row,
    ];

    final fitsWidth = sources.length <= 2;
    // A sideways-scrolling column sizes to its content, so a cap keeps one
    // long value (a file name) from stretching it; flexed columns are
    // already bounded by the card width.
    Widget sourceCell(Widget child) => fitsWidth
        ? child
        : ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: DataSourcesSection.maxScrollingCellWidth,
            ),
            child: child,
          );

    final table = Table(
      key: DataSourcesSection.comparisonGridKey,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      // The label column takes its natural width in both modes; the source
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
            // The label column holds provenance as well as metrics, so its
            // header is left blank rather than titled "Metric".
            const SizedBox.shrink(),
            for (final s in sources)
              Padding(
                padding: _cellPadding,
                child: sourceCell(
                  Text(
                    resolveSourceName(s, labels),
                    style: s.isPrimary
                        ? headerStyle?.copyWith(fontWeight: FontWeight.bold)
                        : headerStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                  child: sourceCell(
                    Text(
                      pick(s) ?? '—',
                      style: valueStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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

  /// One Times row (entry to exit) when every source knows both ends;
  /// otherwise separate Entry and Exit rows, so a source with a lone time
  /// is not read as a span. The single-source list follows the same rule.
  List<(String, String? Function(DiveDataSource))> _timeRows(
    AppLocalizations l10n,
  ) {
    final allSpans = sources.every(
      (s) => s.entryTime != null && s.exitTime != null,
    );
    if (allSpans) {
      return [
        (
          l10n.diveLog_sources_detail_times,
          (s) => _timeRangeText(l10n, units, s.entryTime!, s.exitTime!),
        ),
      ];
    }
    return [
      (
        l10n.diveLog_edit_row_entry,
        (s) => s.entryTime != null ? units.formatTime(s.entryTime!) : null,
      ),
      (
        l10n.diveLog_edit_row_exit,
        (s) => s.exitTime != null ? units.formatTime(s.exitTime!) : null,
      ),
    ];
  }
}
