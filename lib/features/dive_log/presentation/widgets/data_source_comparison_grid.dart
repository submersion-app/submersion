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
  const _SourceComparisonGrid({
    required this.sources,
    required this.units,
    required this.viewedSourceId,
    required this.actionsFor,
    required this.operationReason,
  });
  final List<DiveDataSource> sources;
  final UnitFormatter units;

  /// The source being viewed (tap-to-view), whose column is marked.
  final String? viewedSourceId;

  /// The menu actions and tap-to-view for one source's column.
  final _SourceActions Function(DiveDataSource source) actionsFor;

  /// Why the menu's operations are unavailable, or null when they are.
  final String? operationReason;

  /// The label column hugs the section's leading edge.
  static const _labelPadding = EdgeInsetsDirectional.fromSTEB(0, 6, 6, 6);

  /// A source cell keeps a small inset on both sides, so its text sits
  /// inside the viewed column's tint; with the label's end inset it
  /// leaves the same 12 between columns as before.
  static const _sourcePadding = EdgeInsetsDirectional.all(6);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.bodyMedium;

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

    final actions = {for (final s in sources) s.id: actionsFor(s)};

    // A cell of [s]'s column: tinted while [s] is viewed, and a tap views
    // it, as a tap anywhere on its card did. intrinsicHeight stretches the
    // cell to its row's height, so the tint runs unbroken down the column,
    // while still letting a two-line value set that height (a fill cell
    // would not count towards it and could clip).
    TableCell columnCell(
      DiveDataSource s,
      Widget child, {
      AlignmentGeometry alignment = AlignmentDirectional.centerStart,
      Widget Function(Widget body)? wrap,
    }) {
      final body = Material(
        color: s.id == viewedSourceId
            ? colorScheme.surfaceContainerHighest
            : Colors.transparent,
        child: InkWell(
          onTap: actions[s.id]!.onTap,
          child: Align(
            alignment: alignment,
            widthFactor: 1,
            heightFactor: 1,
            child: child,
          ),
        ),
      );
      // TableCell has to sit directly under the table, so anything that
      // wraps the cell goes inside it.
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
        child: wrap == null ? body : wrap(body),
      );
    }

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
              columnCell(
                s,
                alignment: AlignmentDirectional.topStart,
                // One node per source for screen readers: its name and
                // chips, read as a button that is selected while viewed.
                wrap: (body) => KeyedSubtree(
                  key: DataSourcesSection.cardKey(s.id),
                  child: Semantics(
                    container: true,
                    button: actions[s.id]!.onTap != null,
                    selected: s.id == viewedSourceId,
                    child: body,
                  ),
                ),
                Padding(
                  // A menu button brings its own inset at the end.
                  padding: EdgeInsetsDirectional.fromSTEB(
                    6,
                    2,
                    actions[s.id]!.hasMenuFor(s) ? 0 : 6,
                    6,
                  ),
                  child: sourceCell(
                    _SourceColumnHeader(
                      source: s,
                      isViewing: s.id == viewedSourceId,
                      actions: actions[s.id]!,
                      operationReason: operationReason,
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (final (label, pick) in visibleRows)
          TableRow(
            children: [
              Padding(
                padding: _labelPadding,
                child: Text(label, style: labelStyle),
              ),
              for (final s in sources)
                columnCell(
                  s,
                  Padding(
                    padding: _sourcePadding,
                    child: sourceCell(
                      Text(
                        pick(s) ?? '—',
                        style: valueStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
