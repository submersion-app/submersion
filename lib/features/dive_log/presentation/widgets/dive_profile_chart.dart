import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';

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

  /// Profile markers to display (max depth, pressure thresholds)
  final List<ProfileMarker>? markers;

  /// Whether to show max depth marker (from settings)
  final bool showMaxDepthMarker;

  /// Whether to show pressure threshold markers (from settings)
  final bool showPressureThresholdMarkers;

  /// Gas switches for coloring profile segments by active gas
  final List<GasSwitchWithTank>? gasSwitches;

  /// Tanks for determining initial gas color (before first switch)
  final List<DiveTank>? tanks;

  /// Per-tank time-series pressure data (keyed by tank ID)
  /// Used for multi-tank pressure visualization
  final Map<String, List<TankPressurePoint>>? tankPressures;

  /// Optional key for exporting the chart as an image.
  /// When provided, wraps the chart in a RepaintBoundary for screenshot capture.
  final GlobalKey? exportKey;

  /// Optional playback cursor timestamp in seconds.
  /// When provided, renders a vertical line at this position for step-through playback.
  final int? playbackTimestamp;

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
    this.markers,
    this.showMaxDepthMarker = false,
    this.showPressureThresholdMarkers = false,
    this.gasSwitches,
    this.tanks,
    this.tankPressures,
    this.exportKey,
    this.playbackTimestamp,
  });

  @override
  ConsumerState<DiveProfileChart> createState() => _DiveProfileChartState();
}

class _DiveProfileChartState extends ConsumerState<DiveProfileChart> {
  bool _showTemperature = true;
  bool _showPressure = false;
  bool _showHeartRate = false;
  bool _showSac = false;

  // Per-tank pressure visibility (keyed by tank ID)
  // Defaults to all visible; populated on first build if multi-tank data exists
  final Map<String, bool> _showTankPressure = {};

  // Decompression visualization toggles
  bool _showCeiling = true;
  bool _showAscentRateColors = true;
  bool _showEvents = true;

  // Profile marker toggles
  bool _showMaxDepthMarkerLocal = true;
  bool _showPressureMarkersLocal = true;

  // Gas switch visualization toggle
  bool _showGasSwitchMarkers = true;

  // Helper getters for marker availability
  bool get _hasMaxDepthMarker =>
      widget.markers?.any((m) => m.type == ProfileMarkerType.maxDepth) ?? false;

  bool get _hasPressureMarkers =>
      widget.markers?.any((m) => m.type != ProfileMarkerType.maxDepth) ?? false;

  /// Whether multi-tank pressure data is available
  bool get _hasMultiTankPressure =>
      widget.tankPressures != null && widget.tankPressures!.isNotEmpty;

  /// Get tank by ID for display purposes
  DiveTank? _getTankById(String tankId) {
    final tanks = widget.tanks;
    if (tanks == null) return null;
    for (final tank in tanks) {
      if (tank.id == tankId) return tank;
    }
    return null;
  }

  /// Sort tank IDs by tank order
  List<String> _sortedTankIds(Iterable<String> tankIds) {
    final ids = tankIds.toList();
    ids.sort((a, b) {
      final orderA = _getTankById(a)?.order ?? 999;
      final orderB = _getTankById(b)?.order ?? 999;
      return orderA.compareTo(orderB);
    });
    return ids;
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

  /// Interpolate tank pressure at a given timestamp
  double? _interpolateTankPressure(
    List<TankPressurePoint> points,
    int timestamp,
  ) {
    if (points.isEmpty) return null;

    // Find surrounding points
    TankPressurePoint? before;
    TankPressurePoint? after;

    for (final point in points) {
      if (point.timestamp <= timestamp) {
        before = point;
      } else {
        after = point;
        break;
      }
    }

    // Exact match or only before point
    if (before != null && (after == null || before.timestamp == timestamp)) {
      return before.pressure;
    }

    // Only after point (timestamp before first data point)
    if (before == null && after != null) {
      return after.pressure;
    }

    // Interpolate between before and after
    if (before != null && after != null) {
      final t =
          (timestamp - before.timestamp) / (after.timestamp - before.timestamp);
      return before.pressure + (after.pressure - before.pressure) * t;
    }

    return null;
  }

  /// Get color for tank by index (fallback when no gas mix info)
  Color _getTankColor(int index) {
    const colors = [
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.cyan,
      Colors.purple,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  /// Get dash pattern for tank by index
  List<int>? _getTankDashPattern(int index) {
    switch (index) {
      case 0:
        return [8, 4]; // Primary: long dash
      case 1:
        return [4, 4]; // Secondary: medium dash
      case 2:
        return [2, 2]; // Tertiary: short dash
      case 3:
        return [8, 2, 2, 2]; // Fourth: dash-dot
      default:
        return [4, 2];
    }
  }

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

    // Watch legend state from provider
    final legendState = ref.watch(profileLegendProvider);

    // Sync local state with provider for backward compatibility
    // This allows the chart rendering logic to continue using local state
    _showTemperature = legendState.showTemperature;
    _showPressure = legendState.showPressure;
    _showHeartRate = legendState.showHeartRate;
    _showSac = legendState.showSac;
    _showCeiling = legendState.showCeiling;
    _showAscentRateColors = legendState.showAscentRateColors;
    _showEvents = legendState.showEvents;
    _showMaxDepthMarkerLocal = legendState.showMaxDepthMarker;
    _showPressureMarkersLocal = legendState.showPressureMarkers;
    _showGasSwitchMarkers = legendState.showGasSwitchMarkers;
    // Sync per-tank pressure visibility
    for (final entry in legendState.showTankPressure.entries) {
      _showTankPressure[entry.key] = entry.value;
    }

    // Build legend config based on available data
    final legendConfig = ProfileLegendConfig(
      hasTemperatureData: hasTemperatureData,
      hasPressureData: hasPressureData,
      hasHeartRateData: hasHeartRateData,
      hasSacCurve: widget.sacCurve != null && widget.sacCurve!.isNotEmpty,
      hasCeilingCurve: widget.ceilingCurve != null,
      hasAscentRates: widget.ascentRates != null,
      hasEvents: widget.events != null && widget.events!.isNotEmpty,
      hasMaxDepthMarker: widget.showMaxDepthMarker && _hasMaxDepthMarker,
      hasPressureMarkers:
          widget.showPressureThresholdMarkers && _hasPressureMarkers,
      hasGasSwitches:
          widget.gasSwitches != null && widget.gasSwitches!.isNotEmpty,
      hasMultiTankPressure: _hasMultiTankPressure,
      tanks: widget.tanks,
      tankPressures: widget.tankPressures,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart header with legend and zoom controls (decluttered)
        DiveProfileLegend(
          config: legendConfig,
          zoomLevel: _zoomLevel,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onResetZoom: _resetZoom,
        ),

        // The chart with gesture handling
        // Wrapped in RepaintBoundary for PNG export when exportKey is provided
        RepaintBoundary(
          key: widget.exportKey,
          child: SizedBox(
            height: 200,
            child: _buildInteractiveChart(
              context,
              units,
              hasTemperatureData: hasTemperatureData,
              hasPressureData: hasPressureData,
              hasHeartRateData: hasHeartRateData,
            ),
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
              final newZoom = (_previousZoom * details.scale).clamp(
                _minZoom,
                _maxZoom,
              );

              // Handle pan
              final panDelta = details.localFocalPoint - _startFocalPoint;

              // Convert pixel delta to normalized offset based on chart size
              final chartWidth = constraints.maxWidth;
              final chartHeight = constraints.maxHeight;

              // Only apply pan if zoomed in
              if (newZoom > 1.0) {
                final normalizedDeltaX = -panDelta.dx / chartWidth / newZoom;
                final normalizedDeltaY = -panDelta.dy / chartHeight / newZoom;

                _panOffsetX = (_previousPan.dx + normalizedDeltaX).clamp(
                  0.0,
                  1.0 - (1.0 / newZoom),
                );
                _panOffsetY = (_previousPan.dy + normalizedDeltaY).clamp(
                  0.0,
                  1.0 - (1.0 / newZoom),
                );
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
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
    final totalMaxTime = widget.profile
        .map((p) => p.timestamp)
        .reduce(math.max)
        .toDouble();
    final maxDepthValueMeters = widget.profile
        .map((p) => p.depth)
        .reduce(math.max);
    // Convert to user's preferred depth unit for chart calculations
    final maxDepthValueDisplay = units.convertDepth(
      widget.maxDepth ?? maxDepthValueMeters,
    );
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

    // Pressure bounds (if showing) - includes both legacy single pressure and multi-tank
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
    // Also calculate from multi-tank pressure data if available
    if (_hasMultiTankPressure && widget.tankPressures != null) {
      for (final pressurePoints in widget.tankPressures!.values) {
        for (final point in pressurePoints) {
          if (minPressure == null || point.pressure < minPressure) {
            minPressure = point.pressure - 10;
          }
          if (maxPressure == null || point.pressure > maxPressure) {
            maxPressure = point.pressure + 10;
          }
        }
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

    return Stack(
      children: [
        LineChart(
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
                    if (minTemp == null || maxTemp == null) {
                      return const SizedBox();
                    }
                    // Map from inverted depth axis to temperature (already in user's preferred unit)
                    final temp = _mapDepthToTemp(
                      -value,
                      totalMaxDepth,
                      minTemp,
                      maxTemp,
                    );
                    if (temp < minTemp || temp > maxTemp) {
                      return const SizedBox();
                    }
                    return Text(
                      '${temp.toStringAsFixed(0)}${units.temperatureSymbol}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.tertiary,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            lineBarsData: [
              // Depth line segments (colored by active gas if gas switches exist)
              ..._buildGasColoredDepthLines(colorScheme, units),

              // Gas switch markers (if showing and data available)
              if (_showGasSwitchMarkers) ..._buildGasSwitchMarkers(units),

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

              // Pressure lines - multi-tank if available, legacy single otherwise
              if (_hasMultiTankPressure)
                ..._buildMultiTankPressureLines(totalMaxDepth)
              else if (_showPressure &&
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
                _buildHeartRateLine(
                  heartRateColor,
                  totalMaxDepth,
                  minHR,
                  maxHR,
                ),

              // SAC curve line (if showing)
              if (_showSac && hasSacData && minSac != null && maxSac != null)
                _buildSacLine(totalMaxDepth, minSac, maxSac),

              // Ceiling line (if showing and data available)
              if (_showCeiling && widget.ceilingCurve != null)
                _buildCeilingLine(units),

              // Profile markers (max depth, pressure thresholds)
              ..._buildMarkerLines(
                units,
                totalMaxDepth,
                minPressure: minPressure,
                maxPressure: maxPressure,
              ),
            ],
            extraLinesData: ExtraLinesData(
              horizontalLines: _showEvents && widget.events != null
                  ? _buildEventLines(colorScheme)
                  : [],
              verticalLines: _buildPlaybackCursor(colorScheme),
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
                maxContentWidth: 220,
                fitInsideHorizontally: true,
                fitInsideVertically: false,
                showOnTopOfTheChartBoxArea: true,
                tooltipMargin: 0,
                getTooltipColor: (spot) => colorScheme.inverseSurface,
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

                    // Text style constants for consistent column layout
                    final onSurface = colorScheme.onInverseSurface;
                    final rowStyle = TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 14,
                      color: onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    );

                    const labelWidth = 8;
                    const valueWidth = 16;
                    const rowWidth = labelWidth + valueWidth;
                    final rowFiller = List.filled(rowWidth, '0').join();

                    String clampText(String text, int maxChars) {
                      if (text.length <= maxChars) {
                        return text;
                      }
                      return text.substring(0, maxChars);
                    }

                    // Helper to add a formatted row with constant width
                    void addRow(
                      String label,
                      String value,
                      Color bulletColor, {
                      String bullet = '●',
                      double bulletSize = 12,
                    }) {
                      if (lines.isNotEmpty) {
                        lines.add(const TextSpan(text: '\n'));
                      }
                      lines.add(
                        TextSpan(
                          text: '$bullet ',
                          style: TextStyle(
                            color: bulletColor,
                            fontSize: bulletSize,
                          ),
                        ),
                      );
                      final labelText = clampText(
                        label,
                        labelWidth,
                      ).padRight(labelWidth);
                      final valueText = clampText(
                        value,
                        valueWidth,
                      ).padRight(valueWidth);
                      final rowText = (labelText + valueText).trimRight();
                      lines.add(TextSpan(text: rowText, style: rowStyle));

                      final fillerCount = rowWidth - rowText.length;
                      if (fillerCount > 0) {
                        lines.add(
                          TextSpan(
                            text: rowFiller.substring(0, fillerCount),
                            style: rowStyle.copyWith(color: Colors.transparent),
                          ),
                        );
                      }
                    }

                    // Time (always shown)
                    final timeValue =
                        '$minutes:${seconds.toString().padLeft(2, '0')}';
                    addRow('Time', timeValue, onSurface.withValues(alpha: 0.5));

                    // Depth (always shown)
                    addRow(
                      'Depth',
                      units.formatDepth(point.depth),
                      colorScheme.primary,
                    );

                    // Temperature (if enabled - always show row)
                    if (_showTemperature) {
                      final tempValue = point.temperature != null
                          ? units.formatTemperature(point.temperature)
                          : '—';
                      addRow('Temp', tempValue, colorScheme.tertiary);
                    }

                    // Pressure (if enabled - always show row)
                    if (_showPressure) {
                      final pressValue = point.pressure != null
                          ? units.formatPressure(point.pressure)
                          : '—';
                      addRow('Press', pressValue, Colors.orange);
                    }

                    // Heart rate (if enabled - always show row)
                    if (_showHeartRate) {
                      final hrValue = point.heartRate != null
                          ? '${point.heartRate} bpm'
                          : '—';
                      addRow('HR', hrValue, Colors.red);
                    }

                    // SAC (if enabled - always show row)
                    if (_showSac) {
                      String sacValue = '—';
                      if (widget.sacCurve != null &&
                          spot.spotIndex < widget.sacCurve!.length) {
                        final sacBarPerMin = widget.sacCurve![spot.spotIndex];
                        if (sacBarPerMin > 0) {
                          final normalizedSac =
                              sacBarPerMin * widget.sacNormalizationFactor;
                          final sacUnit = ref.read(sacUnitProvider);
                          if (sacUnit == SacUnit.litersPerMin &&
                              widget.tankVolume != null) {
                            final sacLPerMin =
                                normalizedSac * widget.tankVolume!;
                            sacValue =
                                '${units.convertVolume(sacLPerMin).toStringAsFixed(1)} ${units.volumeSymbol}/min';
                          } else {
                            sacValue =
                                '${units.convertPressure(normalizedSac).toStringAsFixed(1)} ${units.pressureSymbol}/min';
                          }
                        }
                      }
                      addRow('SAC', sacValue, Colors.teal);
                    }

                    // Ceiling (if enabled - always show row)
                    if (_showCeiling) {
                      String ceilingValue = '—';
                      if (widget.ceilingCurve != null &&
                          spot.spotIndex < widget.ceilingCurve!.length) {
                        final ceiling = widget.ceilingCurve![spot.spotIndex];
                        if (ceiling > 0) {
                          ceilingValue = units.formatDepth(ceiling);
                        }
                      }
                      addRow(
                        'Ceiling',
                        ceilingValue,
                        Colors.red.withValues(alpha: 0.7),
                      );
                    }

                    // Ascent rate (if enabled - always show row with fixed format)
                    if (_showAscentRateColors) {
                      Color rateColor = Colors.grey;
                      String arrow = '—';
                      double convertedRate = 0.0;

                      if (widget.ascentRates != null &&
                          spot.spotIndex < widget.ascentRates!.length) {
                        final ascentRate = widget.ascentRates![spot.spotIndex];
                        final rate = ascentRate.rateMetersPerMin;
                        convertedRate = units.convertDepth(rate.abs());
                        if (rate > 0.5) {
                          arrow = '↑';
                          rateColor = _getAscentRateColor(ascentRate.category);
                        } else if (rate < -0.5) {
                          arrow = '↓';
                          rateColor = Colors.blue;
                        }
                      }
                      final rateNum = convertedRate
                          .toStringAsFixed(1)
                          .padLeft(5);
                      final rateValue =
                          '$arrow$rateNum ${units.depthSymbol}/min';
                      addRow('Rate', rateValue, rateColor);
                    }

                    // Per-tank pressure (if any tanks are enabled)
                    if (widget.tankPressures != null) {
                      final timestamp = point.timestamp;
                      final sortedTankIds = _sortedTankIds(
                        widget.tankPressures!.keys,
                      );

                      for (var i = 0; i < sortedTankIds.length; i++) {
                        final tankId = sortedTankIds[i];
                        if (!(_showTankPressure[tankId] ?? true)) continue;

                        final pressurePoints = widget.tankPressures![tankId];
                        if (pressurePoints == null || pressurePoints.isEmpty) {
                          continue;
                        }

                        final pressure = _interpolateTankPressure(
                          pressurePoints,
                          timestamp,
                        );
                        final tank = _getTankById(tankId);
                        final color = tank != null
                            ? GasColors.forGasMix(tank.gasMix)
                            : _getTankColor(i);
                        final tankLabel = tank?.name ?? 'Tank ${i + 1}';
                        final pressValue = pressure != null
                            ? units.formatPressure(pressure)
                            : '—';
                        addRow(tankLabel, pressValue, color);
                      }
                    }

                    // Marker info (if touching near a marker)
                    final markers = widget.markers;
                    if (markers != null && markers.isNotEmpty) {
                      final timestamp = point.timestamp;
                      const timestampThreshold = 3;

                      for (final marker in markers) {
                        if (marker.type == ProfileMarkerType.maxDepth) {
                          if (!widget.showMaxDepthMarker ||
                              !_showMaxDepthMarkerLocal) {
                            continue;
                          }
                        } else {
                          if (!widget.showPressureThresholdMarkers ||
                              !_showPressureMarkersLocal) {
                            continue;
                          }
                        }

                        if ((marker.timestamp - timestamp).abs() <=
                            timestampThreshold) {
                          final markerColor = marker.getColor();
                          addRow(
                            'Marker',
                            marker.chartLabel,
                            markerColor,
                            bullet: '◆',
                            bulletSize: 10,
                          );
                        }
                      }
                    }

                    return LineTooltipItem(
                      '', // Empty base text, using children instead
                      TextStyle(color: onSurface),
                      children: lines,
                      textAlign: TextAlign.left,
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
        // Marker labels removed - marker info now shown in tooltip when tapping near markers
      ],
    );
  }

  /// Build depth line segments colored by active gas
  /// Returns multiple line segments, each colored based on the active gas at that time
  List<LineChartBarData> _buildGasColoredDepthLines(
    ColorScheme colorScheme,
    UnitFormatter units,
  ) {
    final gasSwitches = widget.gasSwitches;
    final tanks = widget.tanks;

    // If no gas switches, use initial tank color or theme primary
    if (gasSwitches == null || gasSwitches.isEmpty) {
      final gasColor = (tanks != null && tanks.isNotEmpty)
          ? GasColors.forGasMix(tanks.first.gasMix)
          : colorScheme.primary;
      return [
        _buildSingleDepthSegment(
          gasColor,
          units,
          0,
          widget.profile.length,
          showFill: true,
        ),
      ];
    }

    final lines = <LineChartBarData>[];

    // Determine initial gas color from first tank
    Color currentColor = (tanks != null && tanks.isNotEmpty)
        ? GasColors.forGasMix(tanks.first.gasMix)
        : GasColors.air;

    int segmentStart = 0;
    int switchIndex = 0;

    for (int i = 0; i < widget.profile.length; i++) {
      final point = widget.profile[i];

      // Check if we've passed a gas switch
      while (switchIndex < gasSwitches.length &&
          point.timestamp >= gasSwitches[switchIndex].timestamp) {
        // Create segment up to this switch point
        if (i > segmentStart) {
          lines.add(
            _buildSingleDepthSegment(
              currentColor,
              units,
              segmentStart,
              i,
              showFill: segmentStart == 0, // Only show fill for first segment
            ),
          );
        }

        // Update color for new gas
        currentColor = GasColors.forMixFraction(
          gasSwitches[switchIndex].o2Fraction,
          gasSwitches[switchIndex].heFraction,
        );
        segmentStart = i;
        switchIndex++;
      }
    }

    // Add final segment
    if (segmentStart < widget.profile.length) {
      lines.add(
        _buildSingleDepthSegment(
          currentColor,
          units,
          segmentStart,
          widget.profile.length,
          showFill:
              segmentStart == 0, // Only show fill if this is the only segment
        ),
      );
    }

    return lines;
  }

  /// Build a single depth line segment with the given color
  LineChartBarData _buildSingleDepthSegment(
    Color color,
    UnitFormatter units,
    int startIndex,
    int endIndex, {
    bool showFill = false,
  }) {
    return LineChartBarData(
      spots: widget.profile
          .sublist(startIndex, endIndex)
          .map(
            (p) => FlSpot(p.timestamp.toDouble(), -units.convertDepth(p.depth)),
          )
          .toList(),
      isCurved: true,
      curveSmoothness: 0.2,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: showFill
          ? BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: GasColors.gradientColors(color),
              ),
            )
          : BarAreaData(show: false),
    );
  }

  /// Build gas switch marker dots on the profile
  List<LineChartBarData> _buildGasSwitchMarkers(UnitFormatter units) {
    final gasSwitches = widget.gasSwitches;
    if (gasSwitches == null || gasSwitches.isEmpty) {
      return [];
    }

    return gasSwitches.map((gs) {
      final color = GasColors.forMixFraction(gs.o2Fraction, gs.heFraction);

      // Find the depth at this timestamp from profile
      final depth = gs.depth ?? _findDepthAtTimestamp(gs.timestamp);

      return LineChartBarData(
        spots: [FlSpot(gs.timestamp.toDouble(), -units.convertDepth(depth))],
        isCurved: false,
        color: Colors.transparent,
        barWidth: 0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) {
            return FlDotCirclePainter(
              radius: 6,
              color: color,
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          },
        ),
      );
    }).toList();
  }

  /// Find the depth at a given timestamp by interpolating profile data
  double _findDepthAtTimestamp(int timestamp) {
    if (widget.profile.isEmpty) return 0;

    // Find the closest profile point
    for (int i = 0; i < widget.profile.length; i++) {
      if (widget.profile[i].timestamp >= timestamp) {
        if (i == 0) return widget.profile[0].depth;
        // Simple interpolation
        final prev = widget.profile[i - 1];
        final curr = widget.profile[i];
        final ratio =
            (timestamp - prev.timestamp) / (curr.timestamp - prev.timestamp);
        return prev.depth + (curr.depth - prev.depth) * ratio;
      }
    }
    return widget.profile.last.depth;
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

  /// Build multiple pressure lines for multi-tank visualization
  List<LineChartBarData> _buildMultiTankPressureLines(double chartMaxDepth) {
    if (!_hasMultiTankPressure) return [];

    final tankPressures = widget.tankPressures!;
    final lines = <LineChartBarData>[];

    // Calculate global min/max pressure across all tanks for consistent scaling
    double? globalMinPressure;
    double? globalMaxPressure;

    for (final pressurePoints in tankPressures.values) {
      for (final point in pressurePoints) {
        if (globalMinPressure == null || point.pressure < globalMinPressure) {
          globalMinPressure = point.pressure;
        }
        if (globalMaxPressure == null || point.pressure > globalMaxPressure) {
          globalMaxPressure = point.pressure;
        }
      }
    }

    if (globalMinPressure == null || globalMaxPressure == null) return [];

    // Add some padding to the pressure range
    final pressureRange = globalMaxPressure - globalMinPressure;
    final minPressure = globalMinPressure - (pressureRange * 0.05);
    final maxPressure = globalMaxPressure + (pressureRange * 0.05);

    final sortedTankIds = _sortedTankIds(tankPressures.keys);

    // Build a line for each visible tank
    for (var i = 0; i < sortedTankIds.length; i++) {
      final tankId = sortedTankIds[i];

      // Skip if tank is hidden
      if (!(_showTankPressure[tankId] ?? true)) continue;

      final pressurePoints = tankPressures[tankId]!;
      if (pressurePoints.isEmpty) continue;

      // Get tank for color
      final tank = _getTankById(tankId);

      // Use gas color or fallback
      final color = tank != null
          ? GasColors.forGasMix(tank.gasMix)
          : _getTankColor(i);
      final dashPattern = _getTankDashPattern(i);

      lines.add(
        LineChartBarData(
          spots: pressurePoints
              .map(
                (p) => FlSpot(
                  p.timestamp.toDouble(),
                  -_mapValueToDepth(
                    p.pressure,
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
          dashArray: dashPattern,
        ),
      );
    }

    return lines;
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
            -units.convertDepth(
              ceiling,
            ), // Convert and negate for inverted axis
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

  /// Build vertical line for playback cursor
  List<VerticalLine> _buildPlaybackCursor(ColorScheme colorScheme) {
    final timestamp = widget.playbackTimestamp;
    if (timestamp == null) {
      return [];
    }

    // Convert timestamp to x position (seconds)
    final xPosition = timestamp.toDouble();

    return [
      VerticalLine(
        x: xPosition,
        color: colorScheme.primary,
        strokeWidth: 2,
        dashArray: [4, 4],
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(bottom: 4),
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: colorScheme.primaryContainer.withValues(
              alpha: 0.9,
            ),
          ),
          labelResolver: (line) {
            final minutes = timestamp ~/ 60;
            final seconds = timestamp % 60;
            return ' ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} ';
          },
        ),
      ),
    ];
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

  /// Build marker lines for max depth and pressure thresholds
  List<LineChartBarData> _buildMarkerLines(
    UnitFormatter units,
    double chartMaxDepth, {
    double? minPressure,
    double? maxPressure,
  }) {
    final lines = <LineChartBarData>[];
    final markers = widget.markers;

    if (markers == null || markers.isEmpty) return lines;

    for (final marker in markers) {
      // Skip max depth markers if setting is off or locally toggled off
      if (marker.type == ProfileMarkerType.maxDepth) {
        if (!widget.showMaxDepthMarker || !_showMaxDepthMarkerLocal) continue;
      } else {
        // Skip pressure markers if setting is off or locally toggled off
        if (!widget.showPressureThresholdMarkers ||
            !_showPressureMarkersLocal) {
          continue;
        }
      }

      lines.add(
        _buildSingleMarkerLine(
          marker,
          units,
          chartMaxDepth,
          minPressure: minPressure,
          maxPressure: maxPressure,
        ),
      );
    }

    return lines;
  }

  /// Build a single marker as a LineChartBarData with a visible dot
  LineChartBarData _buildSingleMarkerLine(
    ProfileMarker marker,
    UnitFormatter units,
    double chartMaxDepth, {
    double? minPressure,
    double? maxPressure,
  }) {
    final color = marker.getColor();
    final size = marker.markerSize;

    // Calculate Y position based on marker type
    double yPosition;
    if (marker.type == ProfileMarkerType.maxDepth) {
      // Max depth marker: position on depth line
      yPosition = -units.convertDepth(marker.depth);
    } else {
      // Pressure threshold marker: position on pressure line
      // Use the threshold pressure value (marker.value) mapped to the chart's Y axis
      if (minPressure != null && maxPressure != null && marker.value != null) {
        yPosition = -_mapValueToDepth(
          marker.value!,
          chartMaxDepth,
          minPressure,
          maxPressure,
        );
      } else {
        // Fallback to depth position if pressure range not available
        yPosition = -units.convertDepth(marker.depth);
      }
    }

    return LineChartBarData(
      spots: [FlSpot(marker.timestamp.toDouble(), yPosition)],
      isCurved: false,
      color: Colors.transparent,
      barWidth: 0,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          if (marker.type == ProfileMarkerType.maxDepth) {
            // Max depth: red circle with white border
            return FlDotCirclePainter(
              radius: size,
              color: color,
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          } else {
            // Pressure threshold: colored circle with darker border
            return FlDotCirclePainter(
              radius: size,
              color: color.withValues(alpha: 0.9),
              strokeWidth: 1.5,
              strokeColor: color.withValues(alpha: 0.5),
            );
          }
        },
      ),
    );
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
                    (p) => FlSpot(p.timestamp.toDouble(), -p.depth),
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
