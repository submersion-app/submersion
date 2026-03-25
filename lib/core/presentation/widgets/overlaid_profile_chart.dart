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
class OverlaidProfileChart extends StatefulWidget {
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
  State<OverlaidProfileChart> createState() => _OverlaidProfileChartState();
}

class _OverlaidProfileChartState extends State<OverlaidProfileChart> {
  final Set<String> _hidden = {};

  static const _existingKey = 'existing';
  static const _incomingKey = 'incoming';

  void _toggleSeries(String key) {
    setState(() {
      if (_hidden.contains(key)) {
        _hidden.remove(key);
      } else {
        // Don't allow hiding both series.
        final otherKey = key == _existingKey ? _incomingKey : _existingKey;
        final otherHasData = key == _existingKey
            ? widget.incomingProfile.isNotEmpty
            : widget.existingProfile.isNotEmpty;
        if (!_hidden.contains(otherKey) || !otherHasData) {
          _hidden.add(key);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.existingProfile.isEmpty && widget.incomingProfile.isEmpty) {
      return SizedBox(
        height: widget.height,
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

    final showExisting =
        widget.existingProfile.isNotEmpty && !_hidden.contains(_existingKey);
    final showIncoming =
        widget.incomingProfile.isNotEmpty && !_hidden.contains(_incomingKey);

    // Compute shared axis bounds across both profiles (always use both for
    // consistent axes regardless of visibility).
    final allDepths = [
      ...widget.existingProfile.map((p) => p.depth),
      ...widget.incomingProfile.map((p) => p.depth),
    ];
    final allTimes = [
      ...widget.existingProfile.map((p) => p.timestamp),
      ...widget.incomingProfile.map((p) => p.timestamp),
    ];
    final maxDepth = allDepths.reduce(math.max) * 1.1;
    final maxTime = allTimes.reduce(math.max).toDouble();

    final existingColor = colorScheme.primary;
    final incomingColor = Colors.teal.shade400;

    final bars = <LineChartBarData>[];

    if (showExisting) {
      bars.add(
        LineChartBarData(
          spots: widget.existingProfile
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

    if (showIncoming) {
      bars.add(
        LineChartBarData(
          spots: widget.incomingProfile
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

    final existingHidden = _hidden.contains(_existingKey);
    final incomingHidden = _hidden.contains(_incomingKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
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
              if (widget.existingProfile.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _toggleSeries(_existingKey),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendDot(
                        color: existingHidden
                            ? existingColor.withValues(alpha: 0.3)
                            : existingColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.existingLabel ?? 'Existing',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: existingHidden
                              ? colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                )
                              : colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.existingProfile.isNotEmpty &&
                  widget.incomingProfile.isNotEmpty)
                const SizedBox(width: 16),
              if (widget.incomingProfile.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _toggleSeries(_incomingKey),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendDot(
                        color: incomingHidden
                            ? incomingColor.withValues(alpha: 0.3)
                            : incomingColor,
                        dashed: true,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.incomingLabel ?? 'Incoming',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: incomingHidden
                              ? colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                )
                              : colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
