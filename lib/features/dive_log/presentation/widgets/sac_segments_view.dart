import 'package:flutter/material.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_axis.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_display.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_segment_groups.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_table.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segments_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_share_bar.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_time_columns.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The body of the Gas consumption by segment card: the dive's average, peak
/// and gas used over time, phase and gas breakdowns of the same dive.
///
/// On a wide card the time chart and the breakdowns sit side by side, so the
/// chart does not stretch across the whole window.
///
/// One position in the dive ties the three together. It comes from a column
/// the diver hovers or tapped, else from the profile chart's cursor, and it
/// marks the column, phase row and gas row it falls in. A section with no data
/// is left out rather than filled from another, which would put one
/// breakdown's numbers under another's heading.
///
/// Color ties them together as well: a column takes the color of the phase it
/// mostly falls in, and the phase rows below are its legend.
class SacSegmentsView extends StatefulWidget {
  final List<SacSegment> timeSegments;
  final List<SacSegment> phaseSegments;
  final List<SacSegment> gasSegments;
  final SacRateDisplay rates;

  /// The profile chart cursor, in seconds from dive start.
  final int? selectedTimestamp;

  /// The time under the pointer on the time chart, in seconds, or null when
  /// it leaves; the host moves the profile cursor there (#4423).
  final ValueChanged<int?>? onCursorSeconds;

  /// Sits on the Time heading's line, so choosing a lane costs no extra row.
  final Widget? laneSelector;

  const SacSegmentsView({
    super.key,
    required this.timeSegments,
    required this.phaseSegments,
    required this.gasSegments,
    required this.rates,
    required this.selectedTimestamp,
    this.onCursorSeconds,
    this.laneSelector,
  });

  @override
  State<SacSegmentsView> createState() => _SacSegmentsViewState();
}

class _SacSegmentsViewState extends State<SacSegmentsView> {
  /// From this width the chart and the breakdowns sit side by side.
  static const double _sideBySideWidth = 720;
  static const double _columnGap = 24;

  int? _pinnedIndex;
  int? _hoveredIndex;

  /// Whether the cursor is this chart's own, reported from a hover or drag
  /// still on it. Its moves are then this chart's pointer, not something
  /// pointed at elsewhere, so they leave the pinned column alone.
  bool _drivingCursor = false;

  @override
  void didUpdateWidget(SacSegmentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The newest thing the diver pointed at wins.
    if (!_drivingCursor &&
        widget.selectedTimestamp != null &&
        widget.selectedTimestamp != oldWidget.selectedTimestamp) {
      _pinnedIndex = null;
    }
  }

  void _reportCursor(int? seconds) {
    _drivingCursor = seconds != null;
    widget.onCursorSeconds?.call(seconds);
  }

  void _setHovered(int? index) {
    if (index != _hoveredIndex) setState(() => _hoveredIndex = index);
  }

  void _setPinned(int? index) {
    if (index != _pinnedIndex) setState(() => _pinnedIndex = index);
  }

  String _timeRange(SacSegment segment) =>
      context.l10n.diveLog_detail_sacSegments_timeRange(
        '${segment.startTimestamp ~/ 60}',
        '${segment.endTimestamp ~/ 60}',
      );

  String _depth(double meters) =>
      widget.rates.units.formatDepth(meters, decimals: 0);

  /// The average depth with the shallowest and deepest, such as `27m (18-30m)`,
  /// or the average alone where the two read the same.
  String _depthWithRange(SacSegment segment) {
    final units = widget.rates.units;
    final shallowest = formatFixedForDisplay(
      units.convertDepth(segment.minDepth),
      0,
    );
    final deepest = formatFixedForDisplay(
      units.convertDepth(segment.maxDepth),
      0,
    );
    if (shallowest == deepest) return _depth(segment.avgDepth);
    return context.l10n.diveLog_detail_sacSegments_depthWithRange(
      _depth(segment.avgDepth),
      shallowest,
      _depth(segment.maxDepth),
    );
  }

  String _share(double share) =>
      context.l10n.diveLog_detail_sacSegments_share('${(share * 100).round()}');

  String _phaseLabel(DivePhase phase) {
    final l10n = context.l10n;
    return switch (phase) {
      DivePhase.descent => l10n.diveLog_detail_sacSegments_phaseDescent,
      DivePhase.bottom => l10n.diveLog_detail_sacSegments_phaseBottom,
      DivePhase.ascent => l10n.diveLog_detail_sacSegments_phaseAscent,
      DivePhase.safetyStop => l10n.diveLog_detail_sacSegments_phaseSafetyStop,
      DivePhase.deco => l10n.diveLog_detail_sacSegments_phaseDeco,
    };
  }

  static String _duration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  /// The column a hover or tap points at, if any is still in range.
  int? get _pickedIndex {
    final index = _hoveredIndex ?? _pinnedIndex;
    return index != null && index < widget.timeSegments.length ? index : null;
  }

  /// The lines of [axis]. The top one also carries the unit, as the last label
  /// on the time axis does.
  List<SacRateTick> _rateTicks(SacRateAxis axis, String unit) => [
    for (final value in axis.ticks)
      SacRateTick(
        factor: value / axis.top,
        label: [
          formatFixedForDisplay(value, axis.decimals),
          if (value == axis.top) unit,
        ].join(' '),
      ),
  ];

  Color _phaseColor(DivePhase phase) =>
      SacSegmentColors.forPhase(phase, Theme.of(context).brightness);

  /// A cylinder's row wears its gas, in the colors it has across the app.
  static Color? _gasColor(SacSegmentGroup group) {
    final mix = group.segments.first.gasMix;
    return mix == null ? null : GasColors.forGasMix(mix);
  }

  /// The time segment with the highest rate, on the scale the chart draws.
  SacSegment _findPeak() {
    final tankIds = [for (final s in widget.timeSegments) s.tankId];
    double comparable(SacSegment s) =>
        widget.rates.comparable(s.sacRate, tankId: s.tankId, among: tankIds);
    return widget.timeSegments.reduce(
      (best, s) => comparable(s) > comparable(best) ? s : best,
    );
  }

  /// The gas the whole dive used, or null where its cylinders' gas can't be
  /// added up.
  ///
  /// The time segments follow the reference cylinder's pressure alone, so a
  /// dive on several cylinders totals its per-cylinder stretches instead.
  String? _totalGasUsed() {
    final rates = widget.rates;
    final cylinders = gasSectionRows(widget.gasSegments);
    if (cylinders.isEmpty) return rates.formatGasUsed(widget.timeSegments);
    final stretches = [for (final g in cylinders) ...g.segments];
    return rates.canShare(stretches.map((s) => s.tankId))
        ? rates.formatGasUsed(stretches)
        : null;
  }

  Widget _summary(SacSegment peak) {
    final l10n = context.l10n;
    final rates = widget.rates;
    final segments = widget.timeSegments;
    final used = _totalGasUsed();
    return SacSegmentsSummary(
      figures: [
        SacSummaryFigure(
          label: l10n.diveLog_detail_sacSegments_summaryAverage,
          value: rates.formatAverage(segments),
        ),
        SacSummaryFigure(
          label: l10n.diveLog_detail_sacSegments_summaryPeak,
          value: rates.format(peak.sacRate, tankId: peak.tankId),
        ),
        if (used != null)
          SacSummaryFigure(
            label: l10n.diveLog_detail_sacSegments_summaryUsed,
            value: used,
          ),
      ],
    );
  }

  Widget _timeSection(int? activeIndex, SacSegment peak) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rates = widget.rates;
    final segments = widget.timeSegments;
    final tankIds = [for (final s in segments) s.tankId];
    double comparable(SacSegment s) =>
        rates.comparable(s.sacRate, tankId: s.tankId, among: tankIds);
    final axis = SacRateAxis.forPeak(
      rates.displayComparable(comparable(peak), among: tankIds),
    );
    double share(double value) => axis.top > 0
        ? rates.displayComparable(value, among: tankIds) / axis.top
        : 0;

    Color? columnColor(SacSegment segment) {
      final phase = dominantPhase(
        segment.startTimestamp,
        segment.endTimestamp,
        widget.phaseSegments,
      );
      return phase == null ? null : _phaseColor(phase);
    }

    final active = activeIndex == null ? null : segments[activeIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.diveLog_detail_sacSegments_time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ?widget.laneSelector,
          ],
        ),
        const SizedBox(height: 6),
        SacTimeColumns(
          columns: [
            for (final segment in segments)
              SacTimeColumn(
                startSeconds: segment.startTimestamp,
                durationSeconds: segment.durationSeconds,
                heightFactor: share(comparable(segment)),
                color: columnColor(segment),
                semanticLabel: [
                  _timeRange(segment),
                  rates.format(segment.sacRate, tankId: segment.tankId),
                  _depth(segment.avgDepth),
                ].join(', '),
              ),
          ],
          averageFactor: share(rates.averageRate(segments)),
          rateTicks: _rateTicks(axis, rates.comparableUnit(tankIds)),
          activeIndex: activeIndex,
          endLabel: (minutes) =>
              l10n.diveLog_detail_sacSegments_axisMinutes('$minutes'),
          onTap: (index) => _setPinned(_pinnedIndex == index ? null : index),
          onScrub: _setPinned,
          onHover: _setHovered,
          onCursorSeconds: widget.onCursorSeconds == null
              ? null
              : _reportCursor,
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              active != null
                  ? [
                      _timeRange(active),
                      rates.format(active.sacRate, tankId: active.tankId),
                      _depthWithRange(active),
                      l10n.diveLog_detail_sacSegments_usedAmount(
                        rates.formatGasUsed([active]),
                      ),
                    ].join(' · ')
                  : l10n.diveLog_detail_sacSegments_peak(
                      rates.format(peak.sacRate, tankId: peak.tankId),
                      _timeRange(peak),
                    ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  SacSegmentTableRow _row(
    SacSegmentGroup group, {
    required String label,
    required Color? color,
    required String rate,
    required String? share,
    required bool selected,
  }) {
    final rates = widget.rates;
    final used = rates.formatGasUsed(group.segments);
    final depth = _depth(group.avgDepth);
    final duration = _duration(group.durationSeconds);
    return SacSegmentTableRow(
      label: label,
      color: color,
      rate: rate,
      used: used,
      share: share,
      depth: depth,
      duration: duration,
      selected: selected,
      semanticLabel: [
        label,
        rates.formatAverage(group.segments),
        context.l10n.diveLog_detail_sacSegments_usedAmount(used),
        ?share,
        depth,
        duration,
      ].join(', '),
    );
  }

  /// The share bar and the phase and gas table, or null with neither.
  Widget? _tableSection(int? focusTimestamp) {
    final l10n = context.l10n;
    final rates = widget.rates;
    final phases = groupSegmentsByPhase(widget.phaseSegments);
    final gases = gasSectionRows(widget.gasSegments);
    if (phases.isEmpty && gases.isEmpty) return null;

    // Rates in one section share a heading unit across both.
    final tankIds = [
      for (final group in [...phases, ...gases])
        ...group.segments.map((s) => s.tankId),
    ];
    final headingUnit = rates.unit(tankIds);

    /// Each group's share of the gas its section used, or null where the
    /// section's gas can't be added up or adds up to nothing.
    List<double>? shares(List<SacSegmentGroup> groups) {
      final among = [
        for (final group in groups) ...group.segments.map((s) => s.tankId),
      ];
      if (!rates.canShare(among)) return null;
      final used = [
        for (final group in groups) rates.gasUsed(group.segments, among: among),
      ];
      final total = used.fold(0.0, (sum, u) => sum + u);
      return total > 0 ? [for (final u in used) u / total] : null;
    }

    List<SacSegmentTableRow> rows(
      List<SacSegmentGroup> groups, {
      required String Function(SacSegmentGroup) label,
      required Color? Function(SacSegmentGroup) color,
      required List<double>? shares,
    }) {
      final selected = focusTimestamp == null
          ? -1
          : groups.indexWhere((g) => g.containsTimestamp(focusTimestamp));
      return [
        for (final (index, group) in groups.indexed)
          _row(
            group,
            label: label(group),
            color: color(group),
            rate: rates.cell(group.segments, headingUnit: headingUnit),
            share: shares == null ? null : _share(shares[index]),
            selected: index == selected,
          ),
      ];
    }

    String phaseLabel(SacSegmentGroup g) => _phaseLabel(g.phase!);
    Color phaseColor(SacSegmentGroup g) => _phaseColor(g.phase!);
    final phaseShares = shares(phases);
    final gasShares = shares(gases);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phaseShares != null) ...[
          SacShareBar(
            title: l10n.diveLog_detail_sacSegments_shareByPhase,
            parts: [
              for (final (index, group) in phases.indexed)
                SacSharePart(
                  label: phaseLabel(group),
                  share: phaseShares[index],
                  shareText: _share(phaseShares[index]),
                  color: phaseColor(group),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        SacSegmentTable(
          rateHeading: headingUnit,
          usedHeading: l10n.diveLog_detail_sacSegments_used,
          depthHeading: l10n.diveLog_detail_sacSegments_depth,
          durationHeading: l10n.diveLog_detail_sacSegments_time,
          sections: [
            if (phases.isNotEmpty)
              SacSegmentTableSection(
                title: l10n.diveLog_detail_sacSegments_phase,
                rows: rows(
                  phases,
                  label: phaseLabel,
                  color: phaseColor,
                  shares: phaseShares,
                ),
              ),
            if (gases.isNotEmpty)
              SacSegmentTableSection(
                title: l10n.diveLog_detail_sacSegments_gas,
                rows: rows(
                  gases,
                  label: (g) => g.label,
                  color: _gasColor,
                  shares: gasShares,
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final segments = widget.timeSegments;
    final picked = _pickedIndex;
    final cursor = widget.selectedTimestamp;
    final cursorIndex = cursor == null
        ? -1
        : segments.indexWhere(
            (s) => cursor >= s.startTimestamp && cursor <= s.endTimestamp,
          );
    final activeIndex = picked ?? (cursorIndex >= 0 ? cursorIndex : null);
    final focusTimestamp = picked != null
        ? segments[picked].midTimestamp
        : cursor;
    final table = _tableSection(focusTimestamp);
    final peak = segments.isEmpty ? null : _findPeak();
    final chart = peak == null ? null : _timeSection(activeIndex, peak);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= _sideBySideWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (peak != null) ...[_summary(peak), const SizedBox(height: 12)],
            if (sideBySide)
              // A missing side keeps its half, so the chart stays half wide.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: chart ?? const SizedBox.shrink()),
                  const SizedBox(width: _columnGap),
                  Expanded(child: table ?? const SizedBox.shrink()),
                ],
              )
            else ...[
              ?chart,
              if (chart != null && table != null) const SizedBox(height: 16),
              ?table,
            ],
          ],
        );
      },
    );
  }
}
