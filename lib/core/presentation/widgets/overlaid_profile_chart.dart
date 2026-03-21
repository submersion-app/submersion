import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Renders two dive profiles overlaid on a single chart for comparison.
///
/// The existing dive profile is drawn as a solid line and the incoming
/// profile as a dashed line.  Both share the same axes so shape
/// differences are immediately visible.
///
/// If only one profile is present, renders a single-line chart.
/// If both are empty, shows a "No profile data" placeholder.
class OverlaidProfileChart extends StatelessWidget {
  final List<DiveProfilePoint> existingProfile;
  final List<DiveProfilePoint> incomingProfile;
  final String? existingLabel;
  final String? incomingLabel;
  final double height;

  const OverlaidProfileChart({
    super.key,
    this.existingProfile = const [],
    this.incomingProfile = const [],
    this.existingLabel,
    this.incomingLabel,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (existingProfile.isEmpty && incomingProfile.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No profile data',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Compute shared axis bounds across both profiles.
    final allDepths = [
      ...existingProfile.map((p) => p.depth),
      ...incomingProfile.map((p) => p.depth),
    ];
    final allTimes = [
      ...existingProfile.map((p) => p.timestamp),
      ...incomingProfile.map((p) => p.timestamp),
    ];
    final maxDepth = allDepths.reduce(math.max) * 1.1;
    final maxTime = allTimes.reduce(math.max).toDouble();

    final existingColor = colorScheme.primary;
    final incomingColor = colorScheme.secondary;

    final bars = <LineChartBarData>[];

    if (existingProfile.isNotEmpty) {
      bars.add(
        LineChartBarData(
          spots: existingProfile
              .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth))
              .toList(),
          isCurved: true,
          curveSmoothness: 0.3,
          color: existingColor,
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: existingColor.withValues(alpha: 0.15),
          ),
        ),
      );
    }

    if (incomingProfile.isNotEmpty) {
      bars.add(
        LineChartBarData(
          spots: incomingProfile
              .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth))
              .toList(),
          isCurved: true,
          curveSmoothness: 0.3,
          color: incomingColor,
          barWidth: 1.5,
          isStrokeCapRound: true,
          dashArray: [4, 2],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: incomingColor.withValues(alpha: 0.08),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxTime,
              minY: -maxDepth,
              maxY: 0,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: bars,
            ),
          ),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (existingProfile.isNotEmpty) ...[
                _LegendDot(color: existingColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    existingLabel ?? 'Existing',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (existingProfile.isNotEmpty && incomingProfile.isNotEmpty)
                const SizedBox(width: 16),
              if (incomingProfile.isNotEmpty) ...[
                _LegendDot(color: incomingColor, dashed: true),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    incomingLabel ?? 'Incoming',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final bool dashed;

  const _LegendDot({required this.color, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 3,
      decoration: BoxDecoration(
        color: dashed ? null : color,
        borderRadius: BorderRadius.circular(1.5),
        border: dashed ? Border.all(color: color, width: 1) : null,
      ),
    );
  }
}
