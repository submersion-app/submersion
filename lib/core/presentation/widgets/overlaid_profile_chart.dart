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

  // Use very distinct colors: blue for existing, orange for incoming.
  static const _existingColor = Colors.blue;
  static final _incomingColor = Colors.orange.shade700;

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
        if (!_hidden.contains(otherKey) && otherHasData) {
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

    final bars = <LineChartBarData>[];

    if (showExisting) {
      bars.add(
        LineChartBarData(
          spots: widget.existingProfile
              .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth))
              .toList(),
          isCurved: true,
          curveSmoothness: 0.3,
          color: _existingColor,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: _existingColor.withValues(alpha: 0.12),
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
          color: _incomingColor,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: _incomingColor.withValues(alpha: 0.08),
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
        // Legend with checkboxes
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (widget.existingProfile.isNotEmpty)
                _LegendCheckbox(
                  color: _existingColor,
                  label: 'Existing: ${widget.existingLabel ?? "Unknown"}',
                  checked: !existingHidden,
                  onTap: () => _toggleSeries(_existingKey),
                ),
              if (widget.incomingProfile.isNotEmpty)
                _LegendCheckbox(
                  color: _incomingColor,
                  label: 'Incoming: ${widget.incomingLabel ?? "Unknown"}',
                  checked: !incomingHidden,
                  onTap: () => _toggleSeries(_incomingKey),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendCheckbox extends StatelessWidget {
  final Color color;
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _LegendCheckbox({
    required this.color,
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = checked ? color : color.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: checked,
              onChanged: (_) => onTap(),
              activeColor: color,
              side: BorderSide(color: effectiveColor, width: 1.5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: checked
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
