import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/insights/presentation/widgets/chart_selection_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const depthBucketColors = [
  Color(0xFF81D4FA), // lightBlue.shade200 (0-10m)
  Color(0xFF4FC3F7), // lightBlue.shade300 (10-20m)
  Color(0xFF29B6F6), // lightBlue.shade400 (20-30m)
  Color(0xFF03A9F4), // lightBlue (30-40m)
  Color(0xFF039BE5), // lightBlue.shade600 (40-50m)
  Color(0xFF0288D1), // lightBlue.shade700 (50-60m)
  Color(0xFF1E88E5), // blue.shade600 (60-70m)
  Color(0xFF1976D2), // blue.shade700 (70-80m)
  Color(0xFF1565C0), // blue.shade800 (80-90m)
  Color(0xFF3949AB), // indigo.shade600 (90-100m)
  Color(0xFF303F9F), // indigo.shade700 (100-110m)
  Color(0xFF283593), // indigo.shade800 (110-120m)
  Color(0xFF1A237E), // indigo.shade900 (120-130m)
  Color(0xFF4A148C), // purple.shade900 (130m+)
];

/// Shared with the pie card's own legend so both agree on how a bucket is
/// worded in the diver's active unit.
String depthBucketLabel(
  DepthRangeStat data,
  UnitFormatter fmt,
  AppLocalizations l10n,
) {
  final minDisplay = fmt.convertDepth(data.minDepth.toDouble()).round();
  final maxDisplay = fmt.convertDepth(data.maxDepth.toDouble()).round();
  return data.openEnded
      ? l10n.insights_summary_depthBucket_over('$minDisplay', fmt.depthSymbol)
      : l10n.insights_summary_depthBucket_range(
          '$minDisplay',
          '$maxDisplay',
          fmt.depthSymbol,
        );
}

/// The depth distribution's pie and short legend (issue #641). A slice marks
/// first, showing its count, and a legend row opens at once (issue #3805).
class DepthPieCard extends StatefulWidget {
  final List<DepthRangeStat> depthDistribution;
  final UnitFormatter fmt;

  /// Opens the dives behind a bucket, by its index in [depthDistribution].
  final Future<void> Function(int bucket)? onOpenBucket;

  const DepthPieCard({
    super.key,
    required this.depthDistribution,
    required this.fmt,
    this.onOpenBucket,
  });

  @override
  State<DepthPieCard> createState() => _DepthPieCardState();
}

class _DepthPieCardState extends State<DepthPieCard> {
  /// An index into the whole distribution, not into the slices: empty
  /// buckets draw no slice, so the two differ.
  int? _marked;

  @override
  void didUpdateWidget(DepthPieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(_counts(oldWidget), _counts(widget))) _marked = null;
  }

  List<int> _counts(DepthPieCard card) => [
    for (final range in card.depthDistribution) range.count,
  ];

  void _onTouch(
    FlTouchEvent event,
    PieTouchResponse? response,
    List<int> buckets,
  ) {
    if (event is! FlTapUpEvent) return;
    final slice = response?.touchedSection?.touchedSectionIndex;
    if (slice == null || slice < 0 || slice >= buckets.length) return;
    final bucket = buckets[slice];
    setState(() => _marked = _marked == bucket ? null : bucket);
  }

  @override
  Widget build(BuildContext context) {
    final depthDistribution = widget.depthDistribution;
    final fmt = widget.fmt;
    final onOpenBucket = widget.onOpenBucket;
    final l10n = context.l10n;
    final buckets = [
      for (var i = 0; i < depthDistribution.length; i++)
        if (depthDistribution[i].count > 0) i,
    ];
    final hasData = buckets.isNotEmpty;
    final marked = _marked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.insights_summary_depthDistribution_title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: hasData
              ? Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Semantics(
                        label: context
                            .l10n
                            .insights_summary_depthDistribution_semanticLabel,
                        child: PieChart(
                          PieChartData(
                            pieTouchData: onOpenBucket == null
                                ? null
                                : PieTouchData(
                                    touchCallback: (event, response) =>
                                        _onTouch(event, response, buckets),
                                    mouseCursorResolver: (_, _) =>
                                        SystemMouseCursors.click,
                                  ),
                            sectionsSpace: 2,
                            centerSpaceRadius: 24,
                            sections: [
                              for (final index in buckets)
                                _section(index, marked),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        // Caps the inline legend at 6 rows so a diver with
                        // many occupied depth buckets can't push the legend
                        // below the fixed-height chart box. The full,
                        // uncapped breakdown with count and time is listed
                        // underneath the pie chart.
                        children: [
                          for (final index in buckets.take(6))
                            _legendRow(context, index),
                        ],
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    Icons.pie_chart_outline,
                    size: 40,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
        ),
        if (onOpenBucket != null && marked != null)
          ChartSelectionStrip(
            label: depthBucketLabel(depthDistribution[marked], fmt, l10n),
            countText: l10n.insights_filterBar_diveCount(
              depthDistribution[marked].count,
            ),
            onOpen: () => onOpenBucket(marked),
          ),
      ],
    );
  }

  PieChartSectionData _section(int index, int? marked) {
    final data = widget.depthDistribution[index];
    final color = depthBucketColors[index % depthBucketColors.length];
    return PieChartSectionData(
      value: data.count.toDouble(),
      title: '${data.count}',
      color: marked == null || marked == index
          ? color
          : color.withValues(alpha: 0.35),
      radius: marked == index ? 56 : 50,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    );
  }

  Widget _legendRow(BuildContext context, int index) {
    final open = widget.onOpenBucket;
    final data = widget.depthDistribution[index];
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: depthBucketColors[index % depthBucketColors.length],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              depthBucketLabel(data, widget.fmt, context.l10n),
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (open != null) const Icon(Icons.chevron_right, size: 14),
        ],
      ),
    );
    if (open == null) return row;
    return Semantics(
      button: true,
      child: InkWell(onTap: () => open(index), child: row),
    );
  }
}
