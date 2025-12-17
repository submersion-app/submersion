import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/dive.dart';

/// Interactive dive profile chart showing depth over time with zoom/pan support
class DiveProfileChart extends ConsumerStatefulWidget {
  final List<DiveProfilePoint> profile;
  final Duration? diveDuration;
  final double? maxDepth;
  final bool showTemperature;
  final bool showPressure;

  const DiveProfileChart({
    super.key,
    required this.profile,
    this.diveDuration,
    this.maxDepth,
    this.showTemperature = true,
    this.showPressure = false,
  });

  @override
  ConsumerState<DiveProfileChart> createState() => _DiveProfileChartState();
}

class _DiveProfileChartState extends ConsumerState<DiveProfileChart> {
  bool _showTemperature = true;

  // Zoom/pan state
  double _zoomLevel = 1.0;
  double _panOffsetX = 0.0; // Normalized offset (0-1 range based on total data)
  double _panOffsetY = 0.0;

  // For gesture handling
  double _previousZoom = 1.0;
  Offset _previousPan = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  // Zoom limits
  static const double _minZoom = 1.0;
  static const double _maxZoom = 10.0;

  @override
  void initState() {
    super.initState();
    _showTemperature = widget.showTemperature;
  }

  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
      _panOffsetX = 0.0;
      _panOffsetY = 0.0;
    });
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel * 1.5).clamp(_minZoom, _maxZoom);
      _clampPanOffsets();
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel / 1.5).clamp(_minZoom, _maxZoom);
      _clampPanOffsets();
    });
  }

  void _clampPanOffsets() {
    // Calculate maximum allowed pan based on zoom level
    final maxPan = 1.0 - (1.0 / _zoomLevel);
    _panOffsetX = _panOffsetX.clamp(0.0, maxPan);
    _panOffsetY = _panOffsetY.clamp(0.0, maxPan);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.isEmpty) {
      return _buildEmptyState(context);
    }

    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final hasTemperatureData = widget.profile.any((p) => p.temperature != null);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart header with toggles and zoom controls
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // Legend items
              _buildLegendItem(
                context,
                color: colorScheme.primary,
                label: 'Depth',
              ),
              if (hasTemperatureData) ...[
                const SizedBox(width: 16),
                InkWell(
                  onTap: () => setState(() => _showTemperature = !_showTemperature),
                  child: Row(
                    children: [
                      Icon(
                        _showTemperature ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 18,
                        color: colorScheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      _buildLegendItem(
                        context,
                        color: colorScheme.tertiary,
                        label: 'Temperature',
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Zoom controls
              _buildZoomControls(context),
            ],
          ),
        ),

        // The chart with gesture handling
        SizedBox(
          height: 200,
          child: _buildInteractiveChart(context, hasTemperatureData, units),
        ),

        // Zoom hint
        if (_zoomLevel > 1.0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Zoom: ${_zoomLevel.toStringAsFixed(1)}x • Pinch or scroll to zoom, drag to pan',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }

  Widget _buildZoomControls(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isZoomed = _zoomLevel > 1.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom out button
        IconButton(
          onPressed: _zoomLevel > _minZoom ? _zoomOut : null,
          icon: const Icon(Icons.remove),
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Zoom out',
        ),
        // Zoom level indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${_zoomLevel.toStringAsFixed(1)}x',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isZoomed ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        // Zoom in button
        IconButton(
          onPressed: _zoomLevel < _maxZoom ? _zoomIn : null,
          icon: const Icon(Icons.add),
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Zoom in',
        ),
        // Reset button (only show when zoomed)
        if (isZoomed) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: _resetZoom,
            icon: const Icon(Icons.fit_screen),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Reset zoom',
          ),
        ],
      ],
    );
  }

  Widget _buildInteractiveChart(BuildContext context, bool hasTemperatureData, UnitFormatter units) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onScaleStart: (details) {
            _previousZoom = _zoomLevel;
            _previousPan = Offset(_panOffsetX, _panOffsetY);
            _startFocalPoint = details.localFocalPoint;
          },
          onScaleUpdate: (details) {
            setState(() {
              // Handle zoom
              final newZoom = (_previousZoom * details.scale).clamp(_minZoom, _maxZoom);

              // Handle pan
              final panDelta = details.localFocalPoint - _startFocalPoint;

              // Convert pixel delta to normalized offset based on chart size
              final chartWidth = constraints.maxWidth;
              final chartHeight = constraints.maxHeight;

              // Only apply pan if zoomed in
              if (newZoom > 1.0) {
                final normalizedDeltaX = -panDelta.dx / chartWidth / newZoom;
                final normalizedDeltaY = -panDelta.dy / chartHeight / newZoom;

                _panOffsetX = (_previousPan.dx + normalizedDeltaX).clamp(0.0, 1.0 - (1.0 / newZoom));
                _panOffsetY = (_previousPan.dy + normalizedDeltaY).clamp(0.0, 1.0 - (1.0 / newZoom));
              } else {
                _panOffsetX = 0.0;
                _panOffsetY = 0.0;
              }

              _zoomLevel = newZoom;
            });
          },
          onDoubleTap: () {
            if (_zoomLevel > 1.0) {
              _resetZoom();
            } else {
              setState(() {
                _zoomLevel = 2.0;
              });
            }
          },
          child: Listener(
            onPointerSignal: (event) {
              // Handle mouse scroll wheel for zoom
              if (event is PointerScrollEvent) {
                setState(() {
                  final scrollDelta = event.scrollDelta.dy;
                  if (scrollDelta < 0) {
                    // Scroll up = zoom in
                    _zoomLevel = (_zoomLevel * 1.1).clamp(_minZoom, _maxZoom);
                  } else {
                    // Scroll down = zoom out
                    _zoomLevel = (_zoomLevel / 1.1).clamp(_minZoom, _maxZoom);
                  }
                  _clampPanOffsets();
                });
              }
            },
            child: _buildChart(context, hasTemperatureData, units),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No dive profile data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, {required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, bool hasTemperatureData, UnitFormatter units) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate full data bounds (all values stored in meters, convert for display)
    final totalMaxTime = widget.profile.map((p) => p.timestamp).reduce(math.max).toDouble();
    final maxDepthValueMeters = widget.profile.map((p) => p.depth).reduce(math.max);
    // Convert to user's preferred depth unit for chart calculations
    final maxDepthValueDisplay = units.convertDepth(widget.maxDepth ?? maxDepthValueMeters);
    final totalMaxDepth = maxDepthValueDisplay * 1.1; // Add 10% padding

    // Apply zoom and pan to calculate visible bounds
    final visibleRangeX = totalMaxTime / _zoomLevel;
    final visibleRangeY = totalMaxDepth / _zoomLevel;

    final visibleMinX = _panOffsetX * totalMaxTime;
    final visibleMaxX = visibleMinX + visibleRangeX;

    final visibleMinDepth = _panOffsetY * totalMaxDepth;
    final visibleMaxDepth = visibleMinDepth + visibleRangeY;

    // Temperature bounds (if showing) - convert to user's preferred unit
    double? minTemp, maxTemp;
    if (_showTemperature && hasTemperatureData) {
      final temps = widget.profile.where((p) => p.temperature != null).map((p) => units.convertTemperature(p.temperature!));
      if (temps.isNotEmpty) {
        minTemp = temps.reduce(math.min) - 1;
        maxTemp = temps.reduce(math.max) + 1;
      }
    }

    return LineChart(
      LineChartData(
        minX: visibleMinX,
        maxX: visibleMaxX,
        minY: -visibleMaxDepth, // Inverted: negative depth at bottom
        maxY: -visibleMinDepth, // Surface area at top (inverted)
        clipData: const FlClipData.all(), // Clip data points outside visible area
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: _calculateDepthInterval(visibleRangeY),
          verticalInterval: _calculateTimeInterval(visibleRangeX),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              'Depth (${units.depthSymbol})',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _calculateDepthInterval(visibleRangeY),
              getTitlesWidget: (value, meta) {
                // Show positive depth values (negate the negative axis values)
                return Text(
                  '${(-value).toInt()}',
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              'Time (min)',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _calculateTimeInterval(visibleRangeX),
              getTitlesWidget: (value, meta) {
                final minutes = (value / 60).round();
                return Text(
                  '$minutes',
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: _showTemperature && hasTemperatureData && minTemp != null,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (minTemp == null || maxTemp == null) return const SizedBox();
                // Map from inverted depth axis to temperature (already in user's preferred unit)
                final temp = _mapDepthToTemp(-value, totalMaxDepth, minTemp, maxTemp);
                if (temp < minTemp || temp > maxTemp) return const SizedBox();
                return Text(
                  '${temp.toStringAsFixed(0)}${units.temperatureSymbol}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.tertiary,
                      ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        lineBarsData: [
          // Depth line (convert to user's preferred unit)
          _buildDepthLine(colorScheme, units),

          // Temperature line (if showing)
          if (_showTemperature && hasTemperatureData && minTemp != null && maxTemp != null)
            _buildTemperatureLine(colorScheme, totalMaxDepth, minTemp, maxTemp, units),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => colorScheme.inverseSurface,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isDepth = spot.barIndex == 0;
                final point = widget.profile[spot.spotIndex];

                if (isDepth) {
                  final minutes = point.timestamp ~/ 60;
                  final seconds = point.timestamp % 60;
                  // Convert depth from stored meters to user's preferred unit
                  final depthDisplay = units.formatDepth(point.depth);
                  return LineTooltipItem(
                    '$depthDisplay\n$minutes:${seconds.toString().padLeft(2, '0')}',
                    TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                } else {
                  // Convert temperature from stored Celsius to user's preferred unit
                  final tempDisplay = units.formatTemperature(point.temperature);
                  return LineTooltipItem(
                    tempDisplay,
                    TextStyle(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildDepthLine(ColorScheme colorScheme, UnitFormatter units) {
    return LineChartBarData(
      spots: widget.profile
          .map((p) => FlSpot(
            p.timestamp.toDouble(),
            -units.convertDepth(p.depth), // Convert to user's unit and negate for inverted axis
          ))
          .toList(),
      isCurved: true,
      curveSmoothness: 0.2,
      color: colorScheme.primary,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withValues(alpha: 0.05),
            colorScheme.primary.withValues(alpha: 0.3),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildTemperatureLine(
    ColorScheme colorScheme,
    double chartMaxDepth,
    double minTemp,
    double maxTemp,
    UnitFormatter units,
  ) {
    return LineChartBarData(
      spots: widget.profile
          .where((p) => p.temperature != null)
          .map((p) => FlSpot(
                p.timestamp.toDouble(),
                // Convert temp to user's unit, then map to depth axis
                -_mapTempToDepth(units.convertTemperature(p.temperature!), chartMaxDepth, minTemp, maxTemp),
              ))
          .toList(),
      isCurved: true,
      curveSmoothness: 0.2,
      color: colorScheme.tertiary,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [5, 3],
    );
  }

  // Map temperature value to depth axis for overlay
  double _mapTempToDepth(double temp, double maxDepth, double minTemp, double maxTemp) {
    final normalized = (temp - minTemp) / (maxTemp - minTemp);
    return maxDepth * (1 - normalized); // Higher temp maps to shallower depth
  }

  // Map depth axis value back to temperature for right axis labels
  double _mapDepthToTemp(double depthAxisValue, double maxDepth, double minTemp, double maxTemp) {
    final normalized = 1 - (depthAxisValue / maxDepth);
    return minTemp + (normalized * (maxTemp - minTemp));
  }

  double _calculateDepthInterval(double maxDepth) {
    if (maxDepth <= 10) return 2;
    if (maxDepth <= 20) return 5;
    if (maxDepth <= 50) return 10;
    return 20;
  }

  double _calculateTimeInterval(double maxTime) {
    final minutes = maxTime / 60;
    if (minutes <= 10) return 60; // 1 min intervals
    if (minutes <= 30) return 300; // 5 min intervals
    if (minutes <= 60) return 600; // 10 min intervals
    return 900; // 15 min intervals
  }
}

/// Compact version of the dive profile chart for list previews
class DiveProfileMiniChart extends StatelessWidget {
  final List<DiveProfilePoint> profile;
  final double height;
  final Color? color;

  const DiveProfileMiniChart({
    super.key,
    required this.profile,
    this.height = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.isEmpty) {
      return SizedBox(height: height);
    }

    final chartColor = color ?? Theme.of(context).colorScheme.primary;
    final maxDepth = profile.map((p) => p.depth).reduce(math.max) * 1.1;
    final maxTime = profile.map((p) => p.timestamp).reduce(math.max).toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxTime,
          minY: -maxDepth, // Inverted: negative depth at bottom
          maxY: 0, // Surface (0m) at top
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: profile
                  .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth)) // Negate for inverted axis
                  .toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              color: chartColor,
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: chartColor.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
