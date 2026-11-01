import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_axis.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_rate_display.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_segment_groups.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_table.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_time_columns.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The body of the Gas consumption by segment card: time, phase and gas
/// breakdowns of the same dive, shown together.
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

  /// Sits on the Time heading's line, so choosing a lane costs no extra row.
  final Widget? laneSelector;

  const SacSegmentsView({
    super.key,
    required this.timeSegments,
    required this.phaseSegments,
    required this.gasSegments,
    required this.rates,
    required this.selectedTimestamp,
    this.laneSelector,
  });

  @override
  State<SacSegmentsView> createState() => _SacSegmentsViewState();
}

class _SacSegmentsViewState extends State<SacSegmentsView> {
  int? _pinnedIndex;
  int? _hoveredIndex;

  @override
  void didUpdateWidget(SacSegmentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The newest thing the diver pointed at wins.
    if (widget.selectedTimestamp != null &&
        widget.selectedTimestamp != oldWidget.selectedTimestamp) {
      _pinnedIndex = null;
    }
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

  static IconData _phaseIcon(DivePhase phase) => switch (phase) {
    DivePhase.descent => Icons.south,
    DivePhase.bottom => Icons.horizontal_rule,
    DivePhase.ascent => Icons.north,
    DivePhase.safetyStop => Icons.pause,
    DivePhase.deco => Icons.hourglass_bottom,
  };

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

  /// A cylinder's row wears its gas, in the colors it has across the app.
  static Color? _gasColor(SacSegmentGroup group) {
    final mix = group.segments.first.gasMix;
    return mix == null ? null : GasColors.forGasMix(mix);
  }

  Widget _timeSection(int? activeIndex) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rates = widget.rates;
    final segments = widget.timeSegments;
    final tankIds = segments.map((s) => s.tankId);
    double comparable(SacSegment s) =>
        rates.comparable(s.sacRate, tankId: s.tankId, among: tankIds);
    final peak = segments.reduce(
      (best, s) => comparable(s) > comparable(best) ? s : best,
    );
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
      return phase == null
          ? null
          : SacSegmentColors.forPhase(phase, theme.colorScheme.brightness);
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
        ),
        const SizedBox(height: 6),
        Text(
          active != null
              ? [
                  _timeRange(active),
                  rates.format(active.sacRate, tankId: active.tankId),
                  _depth(active.avgDepth),
                ].join(' · ')
              : l10n.diveLog_detail_sacSegments_peak(
                  rates.format(peak.sacRate, tankId: peak.tankId),
                  _timeRange(peak),
                ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget? _tableSection(int? focusTimestamp) {
    final l10n = context.l10n;
    final rates = widget.rates;
    final phases = groupSegmentsByPhase(widget.phaseSegments);
    final gases = gasSectionRows(widget.gasSegments);
    if (phases.isEmpty && gases.isEmpty) return null;

    // Phase and gas bars share a scale, so a row compares across sections.
    final groups = [...phases, ...gases];
    final tankIds = [
      for (final group in groups) ...group.segments.map((s) => s.tankId),
    ];
    final headingUnit = rates.unit(tankIds);
    double comparable(SacSegmentGroup g) =>
        rates.averageRate(g.segments, among: tankIds);
    final peak = groups.map(comparable).reduce(math.max);

    List<SacSegmentTableRow> rows(
      List<SacSegmentGroup> groups, {
      required String Function(SacSegmentGroup) label,
      required Color? Function(SacSegmentGroup) color,
      IconData? Function(SacSegmentGroup)? icon,
    }) {
      final selected = focusTimestamp == null
          ? -1
          : groups.indexWhere((g) => g.containsTimestamp(focusTimestamp));
      return [
        for (final (index, group) in groups.indexed)
          SacSegmentTableRow(
            label: label(group),
            icon: icon?.call(group),
            barFactor: peak > 0 ? comparable(group) / peak : 0,
            color: color(group),
            rate: rates.cell(group.segments, headingUnit: headingUnit),
            depth: _depth(group.avgDepth),
            duration: _duration(group.durationSeconds),
            selected: index == selected,
            semanticLabel: [
              label(group),
              rates.formatAverage(group.segments),
              _depth(group.avgDepth),
              _duration(group.durationSeconds),
            ].join(', '),
          ),
      ];
    }

    return SacSegmentTable(
      rateHeading: headingUnit,
      depthHeading: l10n.diveLog_detail_sacSegments_depth,
      durationHeading: l10n.diveLog_detail_sacSegments_time,
      sections: [
        if (phases.isNotEmpty)
          SacSegmentTableSection(
            title: l10n.diveLog_detail_sacSegments_phase,
            rows: rows(
              phases,
              label: (g) => _phaseLabel(g.phase!),
              color: (g) => SacSegmentColors.forPhase(
                g.phase!,
                Theme.of(context).colorScheme.brightness,
              ),
              icon: (g) => _phaseIcon(g.phase!),
            ),
          ),
        if (gases.isNotEmpty)
          SacSegmentTableSection(
            title: l10n.diveLog_detail_sacSegments_gas,
            rows: rows(gases, label: (g) => g.label, color: _gasColor),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (segments.isNotEmpty) _timeSection(activeIndex),
        if (table != null) ...[const SizedBox(height: 8), table],
      ],
    );
  }
}
