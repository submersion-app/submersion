import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/dive_log/presentation/widgets/computer_tissue_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The tissue state the dive computer itself reported for a dive, shown
/// under the app's own tissue loading. Renders nothing without a snapshot.
///
/// Where the computer reported a value the app also computes (end-of-dive
/// GF99, surface GF, CNS) the computer's number takes the row and the
/// calculated one follows as a secondary line, so the diver sees what the
/// computer said first and the app's opinion second.
class ComputerTissueSection extends ConsumerWidget {
  const ComputerTissueSection({
    super.key,
    required this.snapshot,
    this.calculatedGf99Percent,
    this.calculatedSurfaceGfPercent,
    this.calculatedCnsPercent,
  });

  final ComputerTissueSnapshot? snapshot;

  /// End-of-dive values from the app's Buhlmann recompute, shown as the
  /// secondary line under the computer's own where both exist.
  final double? calculatedGf99Percent;
  final double? calculatedSurfaceGfPercent;
  final double? calculatedCnsPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = this.snapshot;
    if (snapshot == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final end = snapshot.end;
    final rows = aggregateRows(snapshot);
    final rgbm = _rgbmRows(snapshot, l10n);

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = textTheme.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 6),
        Text(
          l10n.diveLog_computerTissue_title,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (snapshot.algorithm != null) ...[
          const SizedBox(height: 4),
          _LabelValueRow(
            label: l10n.diveLog_computerTissue_algorithm,
            value: snapshot.algorithm!,
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        ],
        if (end?.loadPercent != null) ...[
          const SizedBox(height: 6),
          Text(l10n.diveLog_computerTissue_endLoading, style: labelStyle),
          const SizedBox(height: 4),
          for (var i = 0; i < end!.loadPercent!.length; i++)
            ComputerTissueLoadBar(
              label: l10n.diveLog_computerTissue_compartment(i + 1),
              percent: end.loadPercent![i],
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          _compartmentCount(
            l10n,
            snapshot,
            end.loadPercent!.length,
            labelStyle,
          ),
        ] else if (end?.n2Bar != null) ...[
          const SizedBox(height: 6),
          Text(l10n.diveLog_computerTissue_endTensions, style: labelStyle),
          const SizedBox(height: 4),
          for (var i = 0; i < end!.n2Bar!.length; i++)
            _TensionRow(
              label: l10n.diveLog_computerTissue_compartment(i + 1),
              n2: formatTissueTension(units, end.n2Bar![i]),
              he: end.heBar != null && i < end.heBar!.length
                  ? formatTissueTension(units, end.heBar![i])
                  : null,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          _compartmentCount(l10n, snapshot, end.n2Bar!.length, labelStyle),
        ],
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 6),
          _AggregateTable(
            rows: rows,
            calculated: {
              ComputerTissueMetric.gf99: calculatedGf99Percent,
              ComputerTissueMetric.surfaceGf: calculatedSurfaceGfPercent,
              ComputerTissueMetric.cns: calculatedCnsPercent,
            },
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        ],
        for (final (label, value) in rgbm) ...[
          const SizedBox(height: 4),
          _LabelValueRow(
            label: label,
            value: value,
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        ],
      ],
    );
  }

  Widget _compartmentCount(
    AppLocalizations l10n,
    ComputerTissueSnapshot snapshot,
    int count,
    TextStyle? style,
  ) {
    final algorithm = snapshot.algorithm;
    final text = algorithm == null
        ? l10n.diveLog_computerTissue_compartments(count)
        : l10n.diveLog_computerTissue_compartmentsWithAlgorithm(
            count,
            algorithm,
          );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: style),
    );
  }

  List<(String, String)> _rgbmRows(
    ComputerTissueSnapshot snapshot,
    AppLocalizations l10n,
  ) {
    // The factors are a property of the whole dive; the end state carries
    // them, falling back to the start for a source that only filled that.
    final state = snapshot.end ?? snapshot.start;
    final n2 = state?.rgbmNitrogen ?? snapshot.start?.rgbmNitrogen;
    final he = state?.rgbmHelium ?? snapshot.start?.rgbmHelium;
    return [
      if (n2 != null)
        (l10n.diveLog_computerTissue_rgbmNitrogen, formatRgbmFactor(n2)),
      if (he != null)
        (l10n.diveLog_computerTissue_rgbmHelium, formatRgbmFactor(he)),
    ];
  }
}

/// One compartment's loading as a labelled horizontal bar. Public so tests
/// can count compartments by widget type.
class ComputerTissueLoadBar extends StatelessWidget {
  const ComputerTissueLoadBar({
    super.key,
    required this.label,
    required this.percent,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final double percent;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = (percent / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text(label, style: labelStyle)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: colorScheme.surfaceContainerHighest),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(color: _loadColor(percent)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              formatTissuePercent(percent),
              style: valueStyle,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  static Color _loadColor(double percent) {
    if (percent >= 100) return Colors.red;
    if (percent >= 80) return Colors.orange;
    if (percent >= 60) return Colors.amber;
    return Colors.green;
  }
}

class _TensionRow extends StatelessWidget {
  const _TensionRow({
    required this.label,
    required this.n2,
    required this.he,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String n2;
  final String? he;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text(label, style: labelStyle)),
          Text(l10n.diveLog_tissue_legend_n2, style: labelStyle),
          const SizedBox(width: 4),
          Text(n2, style: valueStyle),
          if (he != null) ...[
            const SizedBox(width: 10),
            Text(l10n.diveLog_tissue_legend_he, style: labelStyle),
            const SizedBox(width: 4),
            Text(he!, style: valueStyle),
          ],
        ],
      ),
    );
  }
}

class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        Text(value, style: valueStyle),
      ],
    );
  }
}

/// Start vs end mini table. The computer's numbers fill the cells; where the
/// app computed the same end-of-dive metric its value follows on a
/// secondary line beneath the computer's.
class _AggregateTable extends StatelessWidget {
  const _AggregateTable({
    required this.rows,
    required this.calculated,
    this.labelStyle,
    this.valueStyle,
  });

  final List<ComputerTissueAggregateRow> rows;
  final Map<ComputerTissueMetric, double?> calculated;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondaryStyle = labelStyle?.copyWith(fontSize: 10);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            Text(
              l10n.diveLog_computerTissue_columnStart,
              style: labelStyle,
              textAlign: TextAlign.end,
            ),
            Text(
              l10n.diveLog_computerTissue_columnEnd,
              style: labelStyle,
              textAlign: TextAlign.end,
            ),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(_metricLabel(l10n, row.metric), style: labelStyle),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  row.start ?? computerTissueMissing,
                  style: valueStyle,
                  textAlign: TextAlign.end,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      row.end ?? computerTissueMissing,
                      style: valueStyle,
                      textAlign: TextAlign.end,
                    ),
                    if (row.end != null && calculated[row.metric] != null)
                      Text(
                        l10n.diveLog_computerTissue_calculated(
                          formatTissuePercent(calculated[row.metric]!),
                        ),
                        style: secondaryStyle,
                        textAlign: TextAlign.end,
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  static String _metricLabel(AppLocalizations l10n, ComputerTissueMetric m) =>
      switch (m) {
        ComputerTissueMetric.n2Load => l10n.diveLog_computerTissue_rowN2Load,
        ComputerTissueMetric.gf99 => l10n.diveLog_deco_label_gf99,
        ComputerTissueMetric.surfaceGf => l10n.diveLog_deco_label_surfGf,
        ComputerTissueMetric.cns => l10n.diveLog_computerTissue_rowCns,
        ComputerTissueMetric.otu => l10n.diveLog_computerTissue_rowOtu,
      };
}
