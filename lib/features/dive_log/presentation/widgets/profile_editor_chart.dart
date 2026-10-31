import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/theme/backdrop_color.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Simplified dive profile chart for the editor page.
///
/// Shows depth vs time only, with overlays for original/edited profiles,
/// outlier markers, waypoint markers, and range selection shading.
class ProfileEditorChart extends ConsumerStatefulWidget {
  final List<DiveProfilePoint> originalProfile;
  final List<DiveProfilePoint> editedProfile;
  final List<OutlierResult>? outliers;
  final List<ProfileWaypoint>? waypoints;
  final ({int start, int end})? selectedRange;
  final EditorMode mode;

  /// Called on a draw mode tap with [depth] in meters, whatever unit the chart
  /// is displaying.
  final void Function(int timestamp, double depth)? onTap;
  final void Function(int waypointIndex, int timestamp, double depth)?
  onWaypointDrag;

  /// A drag across the chart in Select or Smooth mode selected this range.
  final void Function(int startTimestamp, int endTimestamp)? onRangeChanged;

  /// A tap on the chart in Select or Smooth mode dropped the selection.
  final VoidCallback? onRangeCleared;

  const ProfileEditorChart({
    super.key,
    required this.originalProfile,
    required this.editedProfile,
    this.outliers,
    this.waypoints,
    this.selectedRange,
    this.mode = EditorMode.select,
    this.onTap,
    this.onWaypointDrag,
    this.onRangeChanged,
    this.onRangeCleared,
  });

  @override
  ConsumerState<ProfileEditorChart> createState() => _ProfileEditorChartState();
}

class _ProfileEditorChartState extends ConsumerState<ProfileEditorChart> {
  double _minX = 0;
  double _maxX = 1;
  double _maxDepthDisplay = 1;

  /// Chart time where the current drag began, the end of the range it holds
  /// still.
  double? _rangeDragAnchor;

  bool get _selectsRange =>
      widget.mode == EditorMode.select || widget.mode == EditorMode.smooth;

  @override
  void initState() {
    super.initState();
    _calculateBounds();
  }

  @override
  void didUpdateWidget(ProfileEditorChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editedProfile != widget.editedProfile ||
        oldWidget.originalProfile != widget.originalProfile) {
      _calculateBounds();
    }
  }

  void _calculateBounds() {
    final allPoints = [...widget.originalProfile, ...widget.editedProfile];
    if (allPoints.isEmpty) return;

    _minX = allPoints.map((p) => p.timestamp.toDouble()).reduce(math.min);
    _maxX = allPoints.map((p) => p.timestamp.toDouble()).reduce(math.max);

    // Bounds are recalculated in build() after unit conversion,
    // but we store the raw time bounds here for consistency.
    final xPad = (_maxX - _minX) * 0.05;
    _minX -= xPad;
    _maxX += xPad;
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);

    final colorScheme = Theme.of(context).colorScheme;

    // Calculate max depth in display units
    final allPoints = [...widget.originalProfile, ...widget.editedProfile];
    if (allPoints.isEmpty) {
      return const SizedBox(height: 300);
    }

    final maxDepthMeters = allPoints.map((p) => p.depth).reduce(math.max);
    _maxDepthDisplay = units.convertDepth(maxDepthMeters) * 1.1;
    if (_maxDepthDisplay < 1) _maxDepthDisplay = 1;

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 8),
        child: LineChart(
          LineChartData(
            minX: _minX,
            maxX: _maxX,
            minY: -_maxDepthDisplay,
            maxY: 0,
            lineBarsData: [
              _buildOriginalLine(colorScheme, units),
              _buildEditedLine(colorScheme, units),
            ],
            titlesData: _buildTitles(units),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: _maxDepthDisplay > 20 ? 10 : 5,
              getDrawingHorizontalLine: (value) => FlLine(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                strokeWidth: 0.5,
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              // Not just the tooltip: a disabled chart takes no pointers.
              enabled: widget.mode == EditorMode.draw || _selectsRange,
              handleBuiltInTouches: widget.mode == EditorMode.draw,
              touchCallback: _handleTouch,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
              ),
            ),
            rangeAnnotations: _buildRangeAnnotations(colorScheme),
            extraLinesData: const ExtraLinesData(
              horizontalLines: [],
              verticalLines: [],
            ),
          ),
          // Editing rebuilds the chart data (waypoints shift marker indices,
          // range shading tracks the selection). The default 150ms implicit
          // animation lerps old data to new by list index, sliding markers
          // between unrelated positions; render every edit immediately.
          duration: Duration.zero,
        ),
      ),
    );
  }

  LineChartBarData _buildOriginalLine(
    ColorScheme colorScheme,
    UnitFormatter units,
  ) {
    return LineChartBarData(
      spots: widget.originalProfile
          .map(
            (p) => FlSpot(p.timestamp.toDouble(), -units.convertDepth(p.depth)),
          )
          .toList(),
      isCurved: false,
      color: colorScheme.outline.withValues(alpha: 0.3),
      barWidth: 1,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [4, 4],
    );
  }

  LineChartBarData _buildEditedLine(
    ColorScheme colorScheme,
    UnitFormatter units,
  ) {
    // Read once here: fl_chart calls getDotPainter during paint, per frame.
    final ring = backdropColorOf(context);
    return LineChartBarData(
      spots: widget.editedProfile
          .map(
            (p) => FlSpot(p.timestamp.toDouble(), -units.convertDepth(p.depth)),
          )
          .toList(),
      isCurved: false,
      color: colorScheme.primary,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          if (widget.mode == EditorMode.outlier && widget.outliers != null) {
            final isOutlier = widget.outliers!.any(
              (o) => o.timestamp == spot.x.toInt(),
            );
            if (isOutlier) {
              return FlDotCirclePainter(
                radius: 5,
                color: colorScheme.error,
                strokeWidth: 1.5,
                strokeColor: colorScheme.onError,
              );
            }
          }
          if (widget.mode == EditorMode.draw && widget.waypoints != null) {
            final isWaypoint = widget.waypoints!.any(
              (w) => w.timestamp == spot.x.toInt(),
            );
            if (isWaypoint) {
              return FlDotCirclePainter(
                radius: 6,
                color: Colors.blue,
                strokeWidth: 2,
                strokeColor: ring,
              );
            }
          }
          return FlDotCirclePainter(
            radius: 0,
            color: Colors.transparent,
            strokeWidth: 0,
            strokeColor: Colors.transparent,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: colorScheme.primary.withValues(alpha: 0.08),
      ),
    );
  }

  FlTitlesData _buildTitles(UnitFormatter units) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final seconds = value.toInt();
            final minutes = seconds ~/ 60;
            final secs = seconds % 60;
            return SideTitleWidget(
              meta: meta,
              child: Text(
                '$minutes:${secs.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 10, color: textColor),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            // Chart Y is negated; convert back to positive depth
            final depthDisplay = -value;
            if (depthDisplay < 0) return const SizedBox.shrink();
            return SideTitleWidget(
              meta: meta,
              child: Text(
                '${depthDisplay.round()}',
                style: TextStyle(fontSize: 10, color: textColor),
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  RangeAnnotations _buildRangeAnnotations(ColorScheme colorScheme) {
    if (widget.selectedRange == null) return const RangeAnnotations();

    final range = widget.selectedRange!;
    return RangeAnnotations(
      verticalRangeAnnotations: [
        VerticalRangeAnnotation(
          x1: range.start.toDouble(),
          x2: range.end.toDouble(),
          color: colorScheme.primary.withValues(alpha: 0.15),
        ),
      ],
    );
  }

  void _handleTouch(FlTouchEvent event, LineTouchResponse? response) {
    if (_selectsRange) {
      _handleRangeTouch(event, response?.touchChartCoordinate.dx);
      return;
    }
    if (widget.mode != EditorMode.draw) return;
    if (event is! FlTapUpEvent) return;

    final spots = response?.lineBarSpots;
    if (spots == null || spots.isEmpty) return;

    final touchedSpot = spots.first;
    final timestamp = touchedSpot.x.toInt();
    // Chart Y is negated and in display units; convert back to stored meters
    final units = UnitFormatter(ref.read(settingsProvider));
    final depth = units.depthToMeters(-touchedSpot.y);
    widget.onTap?.call(timestamp, depth);
  }

  void _handleRangeTouch(FlTouchEvent event, double? time) {
    switch (event) {
      // Holding still before dragging turns the gesture into a long press.
      case FlPanDownEvent() || FlLongPressStart():
        _rangeDragAnchor = time;
      case FlPanStartEvent() || FlPanUpdateEvent() || FlLongPressMoveUpdate():
        final anchor = _rangeDragAnchor;
        if (anchor == null || time == null) return;
        final range = _rangeBetween(anchor, time);
        if (range == null || range == widget.selectedRange) return;
        widget.onRangeChanged?.call(range.start, range.end);
      case FlTapUpEvent():
        widget.onRangeCleared?.call();
      default:
        break;
    }
  }

  /// The samples between chart times [a] and [b], reaching out to a sample at
  /// each end: a drag between two sparse samples still holds some, the shading
  /// shows exactly which, and a time shift's overlap check measures from real
  /// samples. Null when no two samples qualify, as for a drag past the dive.
  ({int start, int end})? _rangeBetween(double a, double b) {
    final profile = widget.editedProfile;
    if (profile.isEmpty) return null;

    final low = math.min(a, b);
    final high = math.max(a, b);
    final times = profile.map((p) => p.timestamp);
    final start = times.lastWhere((t) => t <= low, orElse: () => times.first);
    final end = times.firstWhere((t) => t >= high, orElse: () => times.last);
    return start < end ? (start: start, end: end) : null;
  }
}
