import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/units.dart';
import '../../../../core/deco/ascent_rate_calculator.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/dive.dart';
import '../../domain/entities/profile_event.dart';

/// Interactive dive profile chart showing depth over time with zoom/pan support
class DiveProfileChart extends ConsumerStatefulWidget {
  final List<DiveProfilePoint> profile;
  final Duration? diveDuration;
  final double? maxDepth;
  final bool showTemperature;
  final bool showPressure;
  final void Function(DiveProfilePoint? point)? onPointSelected;

  // Decompression visualization data (optional)
  /// Ceiling curve in meters, same length as profile
  final List<double>? ceilingCurve;

  /// Ascent rate data for each profile point
  final List<AscentRatePoint>? ascentRates;

  /// Profile events to display as markers
  final List<ProfileEvent>? events;

  /// NDL values in seconds for each point (-1 = in deco)
  final List<int>? ndlCurve;

  /// SAC rate curve (bar/min at surface) - smoothed for visualization
  final List<double>? sacCurve;

  /// Tank volume in liters (for L/min SAC conversion)
  final double? tankVolume;

  /// Normalization factor to align profile SAC with tank-based SAC
  final double sacNormalizationFactor;

  /// Whether to show ceiling by default
  final bool showCeiling;

  /// Whether to color depth line by ascent rate
  final bool showAscentRateColors;

  /// Whether to show event markers
  final bool showEvents;

  /// Whether to show SAC curve by default
  final bool showSac;

  const DiveProfileChart({
    super.key,
    required this.profile,
    this.diveDuration,
    this.maxDepth,
    this.showTemperature = true,
    this.showPressure = false,
    this.onPointSelected,
    this.ceilingCurve,
    this.ascentRates,
    this.events,
    this.ndlCurve,
    this.sacCurve,
    this.tankVolume,
    this.sacNormalizationFactor = 1.0,
    this.showCeiling = true,
    this.showAscentRateColors = true,
    this.showEvents = true,
    this.showSac = false,
  });

  @override
  ConsumerState<DiveProfileChart> createState() => _DiveProfileChartState();
}

class _DiveProfileChartState extends ConsumerState<DiveProfileChart> {
  bool _showTemperature = true;
  bool _showPressure = false;
  bool _showHeartRate = false;
  bool _showSac = false;

  // Decompression visualization toggles
  bool _showCeiling = true;
  bool _showAscentRateColors = true;
  bool _showEvents = true;

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
    _showPressure = widget.showPressure;
    _showSac = widget.showSac;
    _showCeiling = widget.showCeiling;
    _showAscentRateColors = widget.showAscentRateColors;
    _showEvents = widget.showEvents;
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
    final hasPressureData = widget.profile.any((p) => p.pressure != null);
    final hasHeartRateData = widget.profile.any((p) => p.heartRate != null);
    final colorScheme = Theme.of(context).colorScheme;

    // Define colors for each metric
    const pressureColor = Colors.orange;
    const heartRateColor = Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart header with toggles and zoom controls
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Depth legend (always shown)
              _buildLegendItem(
                context,
                color: colorScheme.primary,
                label: 'Depth',
              ),
              // Temperature toggle
              if (hasTemperatureData)
                _buildMetricToggle(
                  context,
                  color: colorScheme.tertiary,
                  label: 'Temp',
                  isEnabled: _showTemperature,
                  onTap: () =>
                      setState(() => _showTemperature = !_showTemperature),
                ),
              // Pressure toggle
              if (hasPressureData)
                _buildMetricToggle(
                  context,
                  color: pressureColor,
                  label: 'Pressure',
                  isEnabled: _showPressure,
                  onTap: () => setState(() => _showPressure = !_showPressure),
                ),
              // Heart rate toggle
              if (hasHeartRateData)
                _buildMetricToggle(
                  context,
                  color: heartRateColor,
                  label: 'HR',
                  isEnabled: _showHeartRate,
                  onTap: () => setState(() => _showHeartRate = !_showHeartRate),
                ),
              // SAC curve toggle (if data available)
              if (widget.sacCurve != null && widget.sacCurve!.isNotEmpty)
                _buildMetricToggle(
                  context,
                  color: Colors.teal,
                  label: 'SAC',
                  isEnabled: _showSac,
                  onTap: () => setState(() => _showSac = !_showSac),
                ),
              // Ceiling toggle (if data available)
              if (widget.ceilingCurve != null)
                _buildMetricToggle(
                  context,
                  color: Colors.amber.shade700,
                  label: 'Ceiling',
                  isEnabled: _showCeiling,
                  onTap: () => setState(() => _showCeiling = !_showCeiling),
                ),
              // Ascent rate coloring toggle (if data available)
              if (widget.ascentRates != null)
                _buildMetricToggle(
                  context,
                  color: Colors.green,
                  label: 'Rate',
                  isEnabled: _showAscentRateColors,
                  onTap: () => setState(
                    () => _showAscentRateColors = !_showAscentRateColors,
                  ),
                ),
              // Events toggle (if data available)
              if (widget.events != null && widget.events!.isNotEmpty)
                _buildMetricToggle(
                  context,
                  color: Colors.purple,
                  label: 'Events',
                  isEnabled: _showEvents,
                  onTap: () => setState(() => _showEvents = !_showEvents),
                ),
              // Zoom controls (pushed to end)
              _buildZoomControls(context),
            ],
          ),
        ),

        // The chart with gesture handling
        SizedBox(
          height: 200,
          child: _buildInteractiveChart(
            context,
            units,
            hasTemperatureData: hasTemperatureData,
            hasPressureData: hasPressureData,
            hasHeartRateData: hasHeartRateData,
          ),
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
                  color: isZoomed
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
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

  Widget _buildInteractiveChart(
    BuildContext context,
    UnitFormatter units, {
    required bool hasTemperatureData,
    required bool hasPressureData,
    required bool hasHeartRateData,
  }) {
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
              final newZoom =
                  (_previousZoom * details.scale).clamp(_minZoom, _maxZoom);

              // Handle pan
              final panDelta = details.localFocalPoint - _startFocalPoint;

              // Convert pixel delta to normalized offset based on chart size
              final chartWidth = constraints.maxWidth;
              final chartHeight = constraints.maxHeight;

              // Only apply pan if zoomed in
              if (newZoom > 1.0) {
                final normalizedDeltaX = -panDelta.dx / chartWidth / newZoom;
                final normalizedDeltaY = -panDelta.dy / chartHeight / newZoom;

                _panOffsetX = (_previousPan.dx + normalizedDeltaX)
                    .clamp(0.0, 1.0 - (1.0 / newZoom));
                _panOffsetY = (_previousPan.dy + normalizedDeltaY)
                    .clamp(0.0, 1.0 - (1.0 / newZoom));
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
            child: _buildChart(
              context,
              units,
              hasTemperatureData: hasTemperatureData,
              hasPressureData: hasPressureData,
              hasHeartRateData: hasHeartRateData,
            ),
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
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

  Widget _buildLegendItem(
    BuildContext context, {
    required Color color,
    required String label,
  }) {
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

  Widget _buildMetricToggle(
    BuildContext context, {
    required Color color,
    required String label,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: isEnabled
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                color: isEnabled ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isEnabled
                        ? null
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    UnitFormatter units, {
    required bool hasTemperatureData,
    required bool hasPressureData,
    required bool hasHeartRateData,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    const pressureColor = Colors.orange;
    const heartRateColor = Colors.red;

    // Calculate full data bounds (all values stored in meters, convert for display)
    final totalMaxTime =
        widget.profile.map((p) => p.timestamp).reduce(math.max).toDouble();
    final maxDepthValueMeters =
        widget.profile.map((p) => p.depth).reduce(math.max);
    // Convert to user's preferred depth unit for chart calculations
    final maxDepthValueDisplay =
        units.convertDepth(widget.maxDepth ?? maxDepthValueMeters);
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
      final temps = widget.profile
          .where((p) => p.temperature != null)
          .map((p) => units.convertTemperature(p.temperature!));
      if (temps.isNotEmpty) {
        minTemp = temps.reduce(math.min) - 1;
        maxTemp = temps.reduce(math.max) + 1;
      }
    }

    // Pressure bounds (if showing)
    double? minPressure, maxPressure;
    if (_showPressure && hasPressureData) {
      final pressures = widget.profile
          .where((p) => p.pressure != null)
          .map((p) => p.pressure!);
      if (pressures.isNotEmpty) {
        minPressure = pressures.reduce(math.min) - 10;
        maxPressure = pressures.reduce(math.max) + 10;
      }
    }

    // Heart rate bounds (if showing)
    double? minHR, maxHR;
    if (_showHeartRate && hasHeartRateData) {
      final hrs = widget.profile
          .where((p) => p.heartRate != null)
          .map((p) => p.heartRate!.toDouble());
      if (hrs.isNotEmpty) {
        minHR = hrs.reduce(math.min) - 5;
        maxHR = hrs.reduce(math.max) + 5;
      }
    }

    // SAC bounds (if showing)
    double? minSac, maxSac;
    final hasSacData = widget.sacCurve != null && widget.sacCurve!.isNotEmpty;
    if (_showSac && hasSacData) {
      final sacs = widget.sacCurve!.where((s) => s > 0);
      if (sacs.isNotEmpty) {
        minSac = 0; // Always start from 0 for SAC
        maxSac = sacs.reduce(math.max) * 1.2; // Add 20% headroom
      }
    }

    return LineChart(
      LineChartData(
        minX: visibleMinX,
        maxX: visibleMaxX,
        minY: -visibleMaxDepth, // Inverted: negative depth at bottom
        maxY: -visibleMinDepth, // Surface area at top (inverted)
        clipData:
            const FlClipData.all(), // Clip data points outside visible area
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
              showTitles:
                  _showTemperature && hasTemperatureData && minTemp != null,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (minTemp == null || maxTemp == null) return const SizedBox();
                // Map from inverted depth axis to temperature (already in user's preferred unit)
                final temp =
                    _mapDepthToTemp(-value, totalMaxDepth, minTemp, maxTemp);
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
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        lineBarsData: [
          // Depth line (convert to user's preferred unit)
          _buildDepthLine(colorScheme, units),

          // Temperature line (if showing)
          if (_showTemperature &&
              hasTemperatureData &&
              minTemp != null &&
              maxTemp != null)
            _buildTemperatureLine(
              colorScheme,
              totalMaxDepth,
              minTemp,
              maxTemp,
              units,
            ),

          // Pressure line (if showing)
          if (_showPressure &&
              hasPressureData &&
              minPressure != null &&
              maxPressure != null)
            _buildPressureLine(
              pressureColor,
              totalMaxDepth,
              minPressure,
              maxPressure,
            ),

          // Heart rate line (if showing)
          if (_showHeartRate &&
              hasHeartRateData &&
              minHR != null &&
              maxHR != null)
            _buildHeartRateLine(heartRateColor, totalMaxDepth, minHR, maxHR),

          // SAC curve line (if showing)
          if (_showSac && hasSacData && minSac != null && maxSac != null)
            _buildSacLine(totalMaxDepth, minSac, maxSac),

          // Ceiling line (if showing and data available)
          if (_showCeiling && widget.ceilingCurve != null)
            _buildCeilingLine(units),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: _showEvents && widget.events != null
              ? _buildEventLines(colorScheme)
              : [],
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (widget.onPointSelected != null) {
              if (response?.lineBarSpots != null &&
                  response!.lineBarSpots!.isNotEmpty) {
                final spot = response.lineBarSpots!.first;
                if (spot.barIndex == 0 &&
                    spot.spotIndex < widget.profile.length) {
                  widget.onPointSelected!(widget.profile[spot.spotIndex]);
                }
              } else if (event is FlPointerExitEvent ||
                  event is FlLongPressEnd) {
                widget.onPointSelected!(null);
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => colorScheme.inverseSurface,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              // Build tooltip showing all enabled metrics for the touched point
              // Only process the depth line (barIndex 0) and build combined tooltip
              return touchedSpots.map((spot) {
                final isDepth = spot.barIndex == 0;
                if (!isDepth) {
                  return null;
                }

                final point = widget.profile[spot.spotIndex];
                final minutes = point.timestamp ~/ 60;
                final seconds = point.timestamp % 60;

                // Build tooltip with all enabled metrics
                final lines = <TextSpan>[];

                // Time (always shown)
                lines.add(
                  TextSpan(
                    text: '$minutes:${seconds.toString().padLeft(2, '0')}\n',
                    style: TextStyle(
                      color:
                          colorScheme.onInverseSurface.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                );

                // Depth (always shown) with color marker
                final depthDisplay = units.formatDepth(point.depth);
                lines.add(
                  TextSpan(
                    text: '● ',
                    style: TextStyle(color: colorScheme.primary, fontSize: 10),
                  ),
                );
                lines.add(
                  TextSpan(
                    text: '$depthDisplay\n',
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );

                // Temperature (if enabled and available)
                if (_showTemperature && point.temperature != null) {
                  final tempDisplay =
                      units.formatTemperature(point.temperature);
                  lines.add(
                    TextSpan(
                      text: '● ',
                      style:
                          TextStyle(color: colorScheme.tertiary, fontSize: 10),
                    ),
                  );
                  lines.add(
                    TextSpan(
                      text: '$tempDisplay\n',
                      style: TextStyle(
                        color: colorScheme.onInverseSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                // Pressure (if enabled and available)
                if (_showPressure && point.pressure != null) {
                  lines.add(
                    const TextSpan(
                      text: '● ',
                      style: TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                  );
                  lines.add(
                    TextSpan(
                      text: '${units.formatPressure(point.pressure)}\n',
                      style: TextStyle(
                        color: colorScheme.onInverseSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                // Heart rate (if enabled and available)
                if (_showHeartRate && point.heartRate != null) {
                  lines.add(
                    const TextSpan(
                      text: '● ',
                      style: TextStyle(color: Colors.red, fontSize: 10),
                    ),
                  );
                  lines.add(
                    TextSpan(
                      text: '${point.heartRate!} bpm\n',
                      style: TextStyle(
                        color: colorScheme.onInverseSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                // SAC (if enabled and available)
                if (_showSac &&
                    widget.sacCurve != null &&
                    spot.spotIndex < widget.sacCurve!.length) {
                  final sacBarPerMin = widget.sacCurve![spot.spotIndex];
                  if (sacBarPerMin > 0) {
                    // Apply normalization to align with tank-based SAC
                    final normalizedSac =
                        sacBarPerMin * widget.sacNormalizationFactor;
                    final sacUnit = ref.read(sacUnitProvider);
                    String sacText;
                    if (sacUnit == SacUnit.litersPerMin &&
                        widget.tankVolume != null) {
                      // Convert to L/min
                      final sacLPerMin = normalizedSac * widget.tankVolume!;
                      sacText =
                          '${units.convertVolume(sacLPerMin).toStringAsFixed(1)} ${units.volumeSymbol}/min\n';
                    } else {
                      // Use pressure units
                      sacText =
                          '${units.convertPressure(normalizedSac).toStringAsFixed(1)} ${units.pressureSymbol}/min\n';
                    }
                    lines.add(
                      const TextSpan(
                        text: '● ',
                        style: TextStyle(color: Colors.teal, fontSize: 10),
                      ),
                    );
                    lines.add(
                      TextSpan(
                        text: sacText,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                }

                return LineTooltipItem(
                  '', // Empty base text, using children instead
                  TextStyle(color: colorScheme.onInverseSurface),
                  children: lines,
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  LineChartBarData _buildDepthLine(
    ColorScheme colorScheme,
    UnitFormatter units,
  ) {
    return LineChartBarData(
      spots: widget.profile
          .map(
            (p) => FlSpot(
              p.timestamp.toDouble(),
              -units.convertDepth(
                p.depth,
              ), // Convert to user's unit and negate for inverted axis
            ),
          )
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
          .map(
            (p) => FlSpot(
              p.timestamp.toDouble(),
              // Convert temp to user's unit, then map to depth axis
              -_mapTempToDepth(
                units.convertTemperature(p.temperature!),
                chartMaxDepth,
                minTemp,
                maxTemp,
              ),
            ),
          )
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

  LineChartBarData _buildPressureLine(
    Color color,
    double chartMaxDepth,
    double minPressure,
    double maxPressure,
  ) {
    return LineChartBarData(
      spots: widget.profile
          .where((p) => p.pressure != null)
          .map(
            (p) => FlSpot(
              p.timestamp.toDouble(),
              -_mapValueToDepth(
                p.pressure!,
                chartMaxDepth,
                minPressure,
                maxPressure,
              ),
            ),
          )
          .toList(),
      isCurved: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [8, 4],
    );
  }

  LineChartBarData _buildHeartRateLine(
    Color color,
    double chartMaxDepth,
    double minHR,
    double maxHR,
  ) {
    return LineChartBarData(
      spots: widget.profile
          .where((p) => p.heartRate != null)
          .map(
            (p) => FlSpot(
              p.timestamp.toDouble(),
              -_mapValueToDepth(
                p.heartRate!.toDouble(),
                chartMaxDepth,
                minHR,
                maxHR,
              ),
            ),
          )
          .toList(),
      isCurved: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [3, 2],
    );
  }

  /// Build SAC (Surface Air Consumption) curve line
  LineChartBarData _buildSacLine(
    double chartMaxDepth,
    double minSac,
    double maxSac,
  ) {
    const sacColor = Colors.teal;
    final sacCurve = widget.sacCurve!;

    // Build spots for each profile point that has SAC data
    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < sacCurve.length; i++) {
      final sac = sacCurve[i];
      if (sac > 0) {
        spots.add(
          FlSpot(
            widget.profile[i].timestamp.toDouble(),
            -_mapValueToDepth(sac, chartMaxDepth, minSac, maxSac),
          ),
        );
      }
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: sacColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [6, 3], // Distinctive dash pattern for SAC
    );
  }

  // Map temperature value to depth axis for overlay
  double _mapTempToDepth(
    double temp,
    double maxDepth,
    double minTemp,
    double maxTemp,
  ) {
    final normalized = (temp - minTemp) / (maxTemp - minTemp);
    return maxDepth * (1 - normalized); // Higher temp maps to shallower depth
  }

  // Generic value to depth axis mapping
  double _mapValueToDepth(
    double value,
    double maxDepth,
    double minValue,
    double maxValue,
  ) {
    final normalized = (value - minValue) / (maxValue - minValue);
    return maxDepth * (1 - normalized);
  }

  // Map depth axis value back to temperature for right axis labels
  double _mapDepthToTemp(
    double depthAxisValue,
    double maxDepth,
    double minTemp,
    double maxTemp,
  ) {
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

  /// Build the ceiling line (decompression ceiling)
  LineChartBarData _buildCeilingLine(UnitFormatter units) {
    final ceilingData = widget.ceilingCurve!;
    final ceilingColor = Colors.amber.shade700;

    // Build spots only where ceiling > 0
    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < ceilingData.length; i++) {
      final ceiling = ceilingData[i];
      if (ceiling > 0) {
        spots.add(
          FlSpot(
            widget.profile[i].timestamp.toDouble(),
            -units
                .convertDepth(ceiling), // Convert and negate for inverted axis
          ),
        );
      }
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: ceilingColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [4, 4],
      belowBarData: BarAreaData(
        show: true,
        color: ceilingColor.withValues(alpha: 0.15),
        cutOffY: 0, // Fill to surface
        applyCutOffY: true,
      ),
    );
  }

  /// Build vertical lines for events
  List<HorizontalLine> _buildEventLines(ColorScheme colorScheme) {
    // We use vertical lines at event timestamps, but fl_chart's extraLinesData
    // uses HorizontalLine/VerticalLine. Since we want vertical markers at
    // specific times, we'd need VerticalLine. However, the current fl_chart API
    // might not support this well in lineBarsData context.
    // For now, return empty - events will be shown differently
    return [];
  }

  /// Get color for ascent rate category
  Color _getAscentRateColor(AscentRateCategory category) {
    switch (category) {
      case AscentRateCategory.safe:
        return Colors.green;
      case AscentRateCategory.warning:
        return Colors.orange;
      case AscentRateCategory.danger:
        return Colors.red;
    }
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
                  .map(
                    (p) => FlSpot(
                      p.timestamp.toDouble(),
                      -p.depth,
                    ),
                  ) // Negate for inverted axis
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
