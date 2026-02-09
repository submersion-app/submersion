import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/theme/app_colors.dart';
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

  // Advanced decompression/gas curves
  /// ppO2 curve in bar
  final List<double>? ppO2Curve;

  /// ppN2 curve in bar
  final List<double>? ppN2Curve;

  /// ppHe curve in bar (for trimix)
  final List<double>? ppHeCurve;

  /// MOD curve in meters
  final List<double>? modCurve;

  /// Gas density curve in g/L
  final List<double>? densityCurve;

  /// Gradient Factor % curve (0-100+)
  final List<double>? gfCurve;

  /// Surface GF% curve (0-100+)
  final List<double>? surfaceGfCurve;

  /// Mean depth curve in meters
  final List<double>? meanDepthCurve;

  /// TTS (Time To Surface) curve in seconds
  final List<int>? ttsCurve;

  /// Returns responsive left axis reserved size based on available chart width.
  /// Tick labels are plain numbers (e.g. "30", "60") so don't need much space.
  static double leftAxisSize(double availableWidth) =>
      availableWidth < 350 ? 28.0 : 32.0;

  /// Returns responsive right axis reserved size based on available chart width.
  /// Tick labels are plain numbers (units moved to axis name label).
  static double rightAxisSize(double availableWidth) =>
      availableWidth < 350 ? 28.0 : 32.0;

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
    this.ppO2Curve,
    this.ppN2Curve,
    this.ppHeCurve,
    this.modCurve,
    this.densityCurve,
    this.gfCurve,
    this.surfaceGfCurve,
    this.meanDepthCurve,
    this.ttsCurve,
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

  // Advanced decompression/gas toggles
  bool _showNdl = false;
  bool _showPpO2 = false;
  bool _showPpN2 = false;
  bool _showPpHe = false;
  bool _showMod = false;
  bool _showDensity = false;
  bool _showGf = false;
  bool _showSurfaceGf = false;
  bool _showMeanDepth = false;
  bool _showTts = false;

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
    // Sync advanced deco/gas toggles
    _showNdl = legendState.showNdl;
    _showPpO2 = legendState.showPpO2;
    _showPpN2 = legendState.showPpN2;
    _showPpHe = legendState.showPpHe;
    _showMod = legendState.showMod;
    _showDensity = legendState.showDensity;
    _showGf = legendState.showGf;
    _showSurfaceGf = legendState.showSurfaceGf;
    _showMeanDepth = legendState.showMeanDepth;
    _showTts = legendState.showTts;
    // Sync per-tank pressure visibility
    for (final entry in legendState.showTankPressure.entries) {
      _showTankPressure[entry.key] = entry.value;
    }

    // Check data availability for advanced curves
    final hasNdlData = widget.ndlCurve != null && widget.ndlCurve!.isNotEmpty;
    final hasPpO2Data =
        widget.ppO2Curve != null && widget.ppO2Curve!.isNotEmpty;
    final hasPpN2Data =
        widget.ppN2Curve != null && widget.ppN2Curve!.isNotEmpty;
    final hasPpHeData =
        widget.ppHeCurve != null && widget.ppHeCurve!.any((v) => v > 0.001);
    final hasModData = widget.modCurve != null && widget.modCurve!.isNotEmpty;
    final hasDensityData =
        widget.densityCurve != null && widget.densityCurve!.isNotEmpty;
    final hasGfData = widget.gfCurve != null && widget.gfCurve!.isNotEmpty;
    final hasSurfaceGfData =
        widget.surfaceGfCurve != null && widget.surfaceGfCurve!.isNotEmpty;
    final hasMeanDepthData =
        widget.meanDepthCurve != null && widget.meanDepthCurve!.isNotEmpty;
    final hasTtsData = widget.ttsCurve != null && widget.ttsCurve!.isNotEmpty;

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
      hasNdlData: hasNdlData,
      hasPpO2Data: hasPpO2Data,
      hasPpN2Data: hasPpN2Data,
      hasPpHeData: hasPpHeData,
      hasModData: hasModData,
      hasDensityData: hasDensityData,
      hasGfData: hasGfData,
      hasSurfaceGfData: hasSurfaceGfData,
      hasMeanDepthData: hasMeanDepthData,
      hasTtsData: hasTtsData,
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
              availableWidth: constraints.maxWidth,
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
    required double availableWidth,
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

    // Determine effective right axis metric using settings default and fallback chain
    final legendNotifier = ref.read(profileLegendProvider.notifier);
    final preferredMetric = legendNotifier.getEffectiveRightAxisMetric();
    final effectiveRightAxisMetric = _getEffectiveRightAxisMetric(
      preferredMetric,
    );
    final rightAxisRange = effectiveRightAxisMetric != null
        ? _getMetricRange(effectiveRightAxisMetric, units)
        : null;

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
                  reservedSize: DiveProfileChart.leftAxisSize(availableWidth),
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
                axisNameWidget:
                    effectiveRightAxisMetric != null && rightAxisRange != null
                    ? Text(
                        _rightAxisLabel(effectiveRightAxisMetric, units),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: effectiveRightAxisMetric.getColor(colorScheme),
                        ),
                      )
                    : null,
                sideTitles: SideTitles(
                  showTitles:
                      effectiveRightAxisMetric != null &&
                      rightAxisRange != null,
                  reservedSize: DiveProfileChart.rightAxisSize(availableWidth),
                  getTitlesWidget: (value, meta) {
                    if (effectiveRightAxisMetric == null ||
                        rightAxisRange == null) {
                      return const SizedBox();
                    }
                    // Map from inverted depth axis to the metric value
                    final metricValue = _mapDepthToMetricValue(
                      -value,
                      totalMaxDepth,
                      rightAxisRange.min,
                      rightAxisRange.max,
                    );
                    if (metricValue < rightAxisRange.min ||
                        metricValue > rightAxisRange.max) {
                      return const SizedBox();
                    }
                    final metricColor = effectiveRightAxisMetric.getColor(
                      colorScheme,
                    );
                    return Text(
                      _formatRightAxisValue(
                        effectiveRightAxisMetric,
                        metricValue,
                        units,
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: metricColor),
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

              // NDL line (if showing)
              if (_showNdl && widget.ndlCurve != null)
                _buildNdlLine(totalMaxDepth),

              // ppO2 line (if showing)
              if (_showPpO2 && widget.ppO2Curve != null)
                _buildPpO2Line(totalMaxDepth),

              // ppN2 line (if showing)
              if (_showPpN2 && widget.ppN2Curve != null)
                _buildPpN2Line(totalMaxDepth),

              // ppHe line (if showing and has helium data)
              if (_showPpHe &&
                  widget.ppHeCurve != null &&
                  widget.ppHeCurve!.any((v) => v > 0.001))
                _buildPpHeLine(totalMaxDepth),

              // MOD line (if showing)
              if (_showMod && widget.modCurve != null) _buildModLine(units),

              // Gas density line (if showing)
              if (_showDensity && widget.densityCurve != null)
                _buildDensityLine(totalMaxDepth),

              // GF% line (if showing)
              if (_showGf && widget.gfCurve != null)
                _buildGfLine(totalMaxDepth),

              // Surface GF line (if showing)
              if (_showSurfaceGf && widget.surfaceGfCurve != null)
                _buildSurfaceGfLine(totalMaxDepth),

              // Mean depth line (if showing)
              if (_showMeanDepth && widget.meanDepthCurve != null)
                _buildMeanDepthLine(units),

              // TTS line (if showing)
              if (_showTts && widget.ttsCurve != null)
                _buildTtsLine(totalMaxDepth),

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

                    // Depth (always shown) - use same color as depth line
                    addRow(
                      'Depth',
                      units.formatDepth(point.depth),
                      AppColors.chartDepth,
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
                      addRow('Ceiling', ceilingValue, const Color(0xFFD32F2F));
                    }

                    // Ascent rate (if enabled - always show row with fixed format)
                    // Uses distinct colors that don't conflict with gas colors:
                    // - Descent: cyan (distinct from air blue)
                    // - Safe ascent: lime green (distinct from nitrox green)
                    // - Warning/danger: orange/red (already distinct)
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
                          // Use lime for safe ascent (distinct from nitrox green)
                          rateColor =
                              ascentRate.category == AscentRateCategory.safe
                              ? Colors.lime
                              : _getAscentRateColor(ascentRate.category);
                        } else if (rate < -0.5) {
                          arrow = '↓';
                          // Use cyan for descent (distinct from air blue)
                          rateColor = Colors.cyan;
                        }
                      }
                      final rateNum = convertedRate
                          .toStringAsFixed(1)
                          .padLeft(5);
                      final rateValue =
                          '$arrow$rateNum ${units.depthSymbol}/min';
                      addRow('Rate', rateValue, rateColor);
                    }

                    // NDL (if enabled)
                    if (_showNdl) {
                      String ndlValue = '—';
                      if (widget.ndlCurve != null &&
                          spot.spotIndex < widget.ndlCurve!.length) {
                        final ndl = widget.ndlCurve![spot.spotIndex];
                        if (ndl < 0) {
                          ndlValue = 'DECO';
                        } else if (ndl < 3600) {
                          final min = ndl ~/ 60;
                          final sec = ndl % 60;
                          ndlValue = '$min:${sec.toString().padLeft(2, '0')}';
                        } else {
                          ndlValue = '>60 min';
                        }
                      }
                      addRow('NDL', ndlValue, Colors.lightGreen.shade700);
                    }

                    // ppO2 (if enabled)
                    if (_showPpO2) {
                      String ppO2Value = '—';
                      if (widget.ppO2Curve != null &&
                          spot.spotIndex < widget.ppO2Curve!.length) {
                        final ppO2 = widget.ppO2Curve![spot.spotIndex];
                        ppO2Value = '${ppO2.toStringAsFixed(2)} bar';
                      }
                      addRow('ppO2', ppO2Value, const Color(0xFF00ACC1));
                    }

                    // ppN2 (if enabled)
                    if (_showPpN2) {
                      String ppN2Value = '—';
                      if (widget.ppN2Curve != null &&
                          spot.spotIndex < widget.ppN2Curve!.length) {
                        final ppN2 = widget.ppN2Curve![spot.spotIndex];
                        ppN2Value = '${ppN2.toStringAsFixed(2)} bar';
                      }
                      addRow('ppN2', ppN2Value, Colors.indigo);
                    }

                    // ppHe (if enabled)
                    if (_showPpHe) {
                      String ppHeValue = '—';
                      if (widget.ppHeCurve != null &&
                          spot.spotIndex < widget.ppHeCurve!.length) {
                        final ppHe = widget.ppHeCurve![spot.spotIndex];
                        if (ppHe > 0.001) {
                          ppHeValue = '${ppHe.toStringAsFixed(2)} bar';
                        }
                      }
                      addRow('ppHe', ppHeValue, Colors.pink.shade300);
                    }

                    // MOD (if enabled)
                    if (_showMod) {
                      String modValue = '—';
                      if (widget.modCurve != null &&
                          spot.spotIndex < widget.modCurve!.length) {
                        final mod = widget.modCurve![spot.spotIndex];
                        if (mod > 0 && mod < 200) {
                          modValue = units.formatDepth(mod);
                        }
                      }
                      addRow('MOD', modValue, Colors.deepOrange);
                    }

                    // Gas density (if enabled)
                    if (_showDensity) {
                      String densityValue = '—';
                      if (widget.densityCurve != null &&
                          spot.spotIndex < widget.densityCurve!.length) {
                        final density = widget.densityCurve![spot.spotIndex];
                        densityValue = '${density.toStringAsFixed(2)} g/L';
                      }
                      addRow('Density', densityValue, Colors.brown);
                    }

                    // GF% (if enabled)
                    if (_showGf) {
                      String gfValue = '—';
                      if (widget.gfCurve != null &&
                          spot.spotIndex < widget.gfCurve!.length) {
                        final gf = widget.gfCurve![spot.spotIndex];
                        gfValue = '${gf.toStringAsFixed(0)}%';
                      }
                      addRow('GF%', gfValue, Colors.deepPurple);
                    }

                    // Surface GF (if enabled)
                    if (_showSurfaceGf) {
                      String surfaceGfValue = '—';
                      if (widget.surfaceGfCurve != null &&
                          spot.spotIndex < widget.surfaceGfCurve!.length) {
                        final surfaceGf =
                            widget.surfaceGfCurve![spot.spotIndex];
                        surfaceGfValue = '${surfaceGf.toStringAsFixed(0)}%';
                      }
                      addRow('SrfGF', surfaceGfValue, Colors.purple.shade300);
                    }

                    // Mean depth (if enabled)
                    if (_showMeanDepth) {
                      String meanDepthValue = '—';
                      if (widget.meanDepthCurve != null &&
                          spot.spotIndex < widget.meanDepthCurve!.length) {
                        final meanDepth =
                            widget.meanDepthCurve![spot.spotIndex];
                        meanDepthValue = units.formatDepth(meanDepth);
                      }
                      addRow('Mean', meanDepthValue, Colors.blueGrey);
                    }

                    // TTS (if enabled)
                    if (_showTts) {
                      String ttsValue = '—';
                      if (widget.ttsCurve != null &&
                          spot.spotIndex < widget.ttsCurve!.length) {
                        final tts = widget.ttsCurve![spot.spotIndex];
                        if (tts > 0) {
                          final min = (tts / 60).ceil();
                          ttsValue = '$min min';
                        } else {
                          ttsValue = '0 min';
                        }
                      }
                      addRow('TTS', ttsValue, const Color(0xFFAD1457));
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
        // Right axis tap overlay for metric selection
        if (effectiveRightAxisMetric != null)
          Positioned(
            right: 0,
            top: 0,
            bottom: 30, // Leave space for bottom axis
            width: 50, // Match reservedSize of right axis
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _showRightAxisMetricSelector(
                context,
                colorScheme,
                effectiveRightAxisMetric,
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
      ],
    );
  }

  /// Show popup menu for selecting right axis metric
  void _showRightAxisMetricSelector(
    BuildContext context,
    ColorScheme colorScheme,
    ProfileRightAxisMetric currentMetric,
  ) {
    final legendNotifier = ref.read(profileLegendProvider.notifier);

    // Build list of metrics grouped by category
    final menuItems = <PopupMenuEntry<ProfileRightAxisMetric?>>[];

    // Add "None" option to hide the axis
    menuItems.add(
      PopupMenuItem<ProfileRightAxisMetric?>(
        value: null,
        child: Row(
          children: [
            Icon(
              Icons.visibility_off,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            const Text('None'),
          ],
        ),
      ),
    );
    menuItems.add(const PopupMenuDivider());

    // Group metrics by category
    for (final category in ProfileMetricCategory.values) {
      final metricsInCategory = category.metrics;
      final availableMetrics = metricsInCategory
          .where((m) => _hasDataForMetric(m))
          .toList();

      if (availableMetrics.isEmpty) continue;

      // Add divider before category (except first)
      if (menuItems.length > 2) {
        menuItems.add(const PopupMenuDivider());
      }

      // Add category header
      menuItems.add(
        PopupMenuItem<ProfileRightAxisMetric?>(
          enabled: false,
          height: 32,
          child: Text(
            category.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      // Add metrics in this category
      for (final metric in availableMetrics) {
        final isSelected = metric == currentMetric;
        final metricColor = metric.getColor(colorScheme);

        menuItems.add(
          PopupMenuItem<ProfileRightAxisMetric?>(
            value: metric,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check : Icons.show_chart,
                  size: 16,
                  color: isSelected
                      ? metricColor
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: metricColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  metric.displayName,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Show the popup menu
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    showMenu<ProfileRightAxisMetric?>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + renderBox.size.width - 200,
        offset.dy,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      items: menuItems,
    ).then((selectedMetric) {
      // Handle "None" selection (null value means user wants to hide)
      // For now, we don't have a "hide axis" option in state, so selecting
      // an actual metric or canceling
      if (selectedMetric != null) {
        legendNotifier.setRightAxisMetric(selectedMetric);
      }
    });
  }

  /// Build depth line segments - always uses consistent blue color.
  /// Gas switches are indicated by separate gas switch markers, not depth line color.
  List<LineChartBarData> _buildGasColoredDepthLines(
    ColorScheme colorScheme,
    UnitFormatter units,
  ) {
    const depthColor = AppColors.chartDepth;
    return [
      _buildSingleDepthSegment(
        depthColor,
        units,
        0,
        widget.profile.length,
        showFill: true,
      ),
    ];
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
    const ceilingColor = Color(
      0xFFD32F2F,
    ); // Red 700 - distinct from pressure orange

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

  /// Build NDL (No Decompression Limit) line
  /// NDL values are in seconds; shows time remaining before deco obligation
  LineChartBarData _buildNdlLine(double chartMaxDepth) {
    final ndlData = widget.ndlCurve!;
    final ndlColor = Colors.lightGreen.shade700;

    // Map NDL to chart: max NDL (~60 min) at top, 0 at bottom
    const maxNdlSeconds = 3600.0; // 60 minutes as max display

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < ndlData.length; i++) {
      final ndl = ndlData[i];
      // Skip negative values (in deco) and very large values
      if (ndl >= 0 && ndl < maxNdlSeconds) {
        final normalized = ndl / maxNdlSeconds;
        final yValue = chartMaxDepth * (1 - normalized);
        spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
      }
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: ndlColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [6, 3],
    );
  }

  /// Build ppO2 (partial pressure of oxygen) line
  /// Values typically range from 0.21 (surface air) to 1.6+ (critical)
  LineChartBarData _buildPpO2Line(double chartMaxDepth) {
    final ppO2Data = widget.ppO2Curve!;
    const ppO2Color = Color(0xFF00ACC1); // Cyan 600 - distinct from depth blue

    // Map ppO2 to chart: 0 at top, 2.0 bar at bottom
    const minPpO2 = 0.0;
    const maxPpO2 = 2.0;

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < ppO2Data.length; i++) {
      final ppO2 = ppO2Data[i].clamp(minPpO2, maxPpO2);
      final yValue = _mapValueToDepth(ppO2, chartMaxDepth, minPpO2, maxPpO2);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: ppO2Color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [5, 3],
    );
  }

  /// Build ppN2 (partial pressure of nitrogen) line
  LineChartBarData _buildPpN2Line(double chartMaxDepth) {
    final ppN2Data = widget.ppN2Curve!;
    const ppN2Color = Colors.indigo;

    // Map ppN2 to chart: 0 at top, ~5 bar at bottom (deep dive)
    const minPpN2 = 0.0;
    const maxPpN2 = 5.0;

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < ppN2Data.length; i++) {
      final ppN2 = ppN2Data[i].clamp(minPpN2, maxPpN2);
      final yValue = _mapValueToDepth(ppN2, chartMaxDepth, minPpN2, maxPpN2);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: ppN2Color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [4, 2],
    );
  }

  /// Build ppHe (partial pressure of helium) line for trimix dives
  LineChartBarData _buildPpHeLine(double chartMaxDepth) {
    final ppHeData = widget.ppHeCurve!;
    final ppHeColor = Colors.pink.shade300;

    // Map ppHe to chart: 0 at top, ~3 bar at bottom
    const minPpHe = 0.0;
    const maxPpHe = 3.0;

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < ppHeData.length; i++) {
      final ppHe = ppHeData[i];
      if (ppHe > 0.001) {
        final clamped = ppHe.clamp(minPpHe, maxPpHe);
        final yValue = _mapValueToDepth(
          clamped,
          chartMaxDepth,
          minPpHe,
          maxPpHe,
        );
        spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
      }
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: ppHeColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [3, 3],
    );
  }

  /// Build MOD (Maximum Operating Depth) line
  /// Shows the MOD limit as a horizontal reference line
  LineChartBarData _buildModLine(UnitFormatter units) {
    final modData = widget.modCurve!;
    const modColor = Colors.deepOrange;

    // MOD is typically constant for a given gas
    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < modData.length; i++) {
      final mod = modData[i];
      if (mod > 0 && mod < 200) {
        spots.add(
          FlSpot(
            widget.profile[i].timestamp.toDouble(),
            -units.convertDepth(mod),
          ),
        );
      }
    }

    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: modColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [8, 4],
    );
  }

  /// Build gas density line (g/L)
  /// High density (>5.7 g/L) increases work of breathing
  LineChartBarData _buildDensityLine(double chartMaxDepth) {
    final densityData = widget.densityCurve!;
    const densityColor = Colors.brown;

    // Map density to chart: 0 at top, 8 g/L at bottom
    const minDensity = 0.0;
    const maxDensity = 8.0;

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < densityData.length; i++) {
      final density = densityData[i].clamp(minDensity, maxDensity);
      final yValue = _mapValueToDepth(
        density,
        chartMaxDepth,
        minDensity,
        maxDensity,
      );
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: densityColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [5, 2],
    );
  }

  /// Build GF% (Gradient Factor percentage) line at current depth
  /// Shows how close tissues are to M-value limit
  LineChartBarData _buildGfLine(double chartMaxDepth) {
    final gfData = widget.gfCurve!;
    const gfColor = Colors.deepPurple;

    // Map GF% to chart: 0% at top, 120% at bottom
    const minGf = 0.0;
    const maxGf = 120.0;

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < gfData.length; i++) {
      final gf = gfData[i].clamp(minGf, maxGf);
      final yValue = _mapValueToDepth(gf, chartMaxDepth, minGf, maxGf);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: gfColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [4, 3],
    );
  }

  /// Build Surface GF% line (what GF would be if surfaced now)
  /// Values >100% indicate deco obligation
  LineChartBarData _buildSurfaceGfLine(double chartMaxDepth) {
    final surfaceGfData = widget.surfaceGfCurve!;
    final surfaceGfColor = Colors.purple.shade300;

    // Map Surface GF% to chart: 0% at top, 150% at bottom
    const minGf = 0.0;
    const maxGf = 150.0;

    final spots = <FlSpot>[];
    for (
      int i = 0;
      i < widget.profile.length && i < surfaceGfData.length;
      i++
    ) {
      final gf = surfaceGfData[i].clamp(minGf, maxGf);
      final yValue = _mapValueToDepth(gf, chartMaxDepth, minGf, maxGf);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: surfaceGfColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [6, 2],
    );
  }

  /// Build mean depth line (running average from start)
  LineChartBarData _buildMeanDepthLine(UnitFormatter units) {
    final meanDepthData = widget.meanDepthCurve!;
    const meanDepthColor = Colors.blueGrey;

    final spots = <FlSpot>[];
    for (
      int i = 0;
      i < widget.profile.length && i < meanDepthData.length;
      i++
    ) {
      spots.add(
        FlSpot(
          widget.profile[i].timestamp.toDouble(),
          -units.convertDepth(meanDepthData[i]),
        ),
      );
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: meanDepthColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [3, 4],
    );
  }

  /// Build TTS (Time To Surface) line
  /// Shows total time including deco stops to reach surface
  LineChartBarData _buildTtsLine(double chartMaxDepth) {
    final ttsData = widget.ttsCurve!;
    const ttsColor = Color(
      0xFFAD1457,
    ); // Pink 800 - distinct from pressure orange

    // Map TTS to chart: 0 at top, 60 min at bottom
    const maxTtsSeconds = 3600.0;

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < ttsData.length; i++) {
      final tts = ttsData[i].toDouble().clamp(0, maxTtsSeconds);
      final normalized = tts / maxTtsSeconds;
      final yValue = chartMaxDepth * (1 - normalized);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: ttsColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [5, 4],
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

  /// Check if a specific metric has data available in this dive profile
  bool _hasDataForMetric(ProfileRightAxisMetric metric) {
    switch (metric) {
      case ProfileRightAxisMetric.temperature:
        return widget.profile.any((p) => p.temperature != null);
      case ProfileRightAxisMetric.pressure:
        return widget.profile.any((p) => p.pressure != null);
      case ProfileRightAxisMetric.heartRate:
        return widget.profile.any((p) => p.heartRate != null);
      case ProfileRightAxisMetric.sac:
        return widget.sacCurve != null && widget.sacCurve!.any((s) => s > 0);
      case ProfileRightAxisMetric.ndl:
        return widget.ndlCurve != null && widget.ndlCurve!.isNotEmpty;
      case ProfileRightAxisMetric.ppO2:
        return widget.ppO2Curve != null && widget.ppO2Curve!.isNotEmpty;
      case ProfileRightAxisMetric.ppN2:
        return widget.ppN2Curve != null && widget.ppN2Curve!.isNotEmpty;
      case ProfileRightAxisMetric.ppHe:
        return widget.ppHeCurve != null &&
            widget.ppHeCurve!.any((v) => v > 0.001);
      case ProfileRightAxisMetric.gasDensity:
        return widget.densityCurve != null && widget.densityCurve!.isNotEmpty;
      case ProfileRightAxisMetric.gf:
        return widget.gfCurve != null && widget.gfCurve!.isNotEmpty;
      case ProfileRightAxisMetric.surfaceGf:
        return widget.surfaceGfCurve != null &&
            widget.surfaceGfCurve!.isNotEmpty;
      case ProfileRightAxisMetric.meanDepth:
        return widget.meanDepthCurve != null &&
            widget.meanDepthCurve!.isNotEmpty;
      case ProfileRightAxisMetric.tts:
        return widget.ttsCurve != null && widget.ttsCurve!.isNotEmpty;
    }
  }

  /// Get the effective right axis metric using the fallback chain
  ProfileRightAxisMetric? _getEffectiveRightAxisMetric(
    ProfileRightAxisMetric preferred,
  ) {
    // First, check if the preferred metric has data
    if (_hasDataForMetric(preferred)) {
      return preferred;
    }

    // Fall back through the priority chain
    for (final fallback in ProfileRightAxisMetric.fallbackPriority) {
      if (_hasDataForMetric(fallback)) {
        return fallback;
      }
    }

    // No metric has data
    return null;
  }

  /// Get the min/max value range for a metric
  ({double min, double max})? _getMetricRange(
    ProfileRightAxisMetric metric,
    UnitFormatter units,
  ) {
    switch (metric) {
      case ProfileRightAxisMetric.temperature:
        final temps = widget.profile
            .where((p) => p.temperature != null)
            .map((p) => units.convertTemperature(p.temperature!));
        if (temps.isEmpty) return null;
        return (
          min: temps.reduce(math.min) - 1,
          max: temps.reduce(math.max) + 1,
        );

      case ProfileRightAxisMetric.pressure:
        final pressures = widget.profile
            .where((p) => p.pressure != null)
            .map((p) => p.pressure!);
        if (pressures.isEmpty) return null;
        return (
          min: pressures.reduce(math.min) - 10,
          max: pressures.reduce(math.max) + 10,
        );

      case ProfileRightAxisMetric.heartRate:
        final hrs = widget.profile
            .where((p) => p.heartRate != null)
            .map((p) => p.heartRate!.toDouble());
        if (hrs.isEmpty) return null;
        return (min: hrs.reduce(math.min) - 5, max: hrs.reduce(math.max) + 5);

      case ProfileRightAxisMetric.sac:
        if (widget.sacCurve == null) return null;
        final sacs = widget.sacCurve!.where((s) => s > 0);
        if (sacs.isEmpty) return null;
        return (min: 0.0, max: sacs.reduce(math.max) * 1.2);

      case ProfileRightAxisMetric.ndl:
        return (min: 0.0, max: 3600.0); // 0-60 minutes

      case ProfileRightAxisMetric.ppO2:
        return (min: 0.0, max: 2.0); // 0-2.0 bar

      case ProfileRightAxisMetric.ppN2:
        return (min: 0.0, max: 5.0); // 0-5.0 bar

      case ProfileRightAxisMetric.ppHe:
        return (min: 0.0, max: 3.0); // 0-3.0 bar

      case ProfileRightAxisMetric.gasDensity:
        return (min: 0.0, max: 8.0); // 0-8 g/L

      case ProfileRightAxisMetric.gf:
        return (min: 0.0, max: 120.0); // 0-120%

      case ProfileRightAxisMetric.surfaceGf:
        return (min: 0.0, max: 150.0); // 0-150%

      case ProfileRightAxisMetric.meanDepth:
        if (widget.meanDepthCurve == null) return null;
        final depths = widget.meanDepthCurve!;
        if (depths.isEmpty) return null;
        return (min: 0.0, max: depths.reduce(math.max) * 1.1);

      case ProfileRightAxisMetric.tts:
        return (min: 0.0, max: 3600.0); // 0-60 minutes
    }
  }

  /// Format right axis tick values as plain numbers (units shown in axis label).
  ///
  /// Values from [_getMetricRange] are in storage units (bar, meters, etc.).
  /// Temperature is pre-converted in [_getMetricRange]; all others are
  /// converted here at display time to match the user's unit preferences.
  String _formatRightAxisValue(
    ProfileRightAxisMetric metric,
    double value,
    UnitFormatter units,
  ) {
    switch (metric) {
      // Temperature range is already in user units (converted in _getMetricRange)
      case ProfileRightAxisMetric.temperature:
        return value.toStringAsFixed(0);
      // Pressure stored in bar -> convert to user unit
      case ProfileRightAxisMetric.pressure:
        return units.convertPressure(value).toStringAsFixed(0);
      // SAC stored in bar/min -> convert pressure component to user unit
      case ProfileRightAxisMetric.sac:
        return units.convertPressure(value).toStringAsFixed(1);
      // Mean depth stored in meters -> convert to user unit
      case ProfileRightAxisMetric.meanDepth:
        return units.convertDepth(value).toStringAsFixed(0);
      // Universal units - no conversion needed
      case ProfileRightAxisMetric.heartRate:
      case ProfileRightAxisMetric.gf:
      case ProfileRightAxisMetric.surfaceGf:
        return value.toStringAsFixed(0);
      case ProfileRightAxisMetric.ppO2:
      case ProfileRightAxisMetric.ppN2:
      case ProfileRightAxisMetric.ppHe:
      case ProfileRightAxisMetric.gasDensity:
        return value.toStringAsFixed(1);
      case ProfileRightAxisMetric.ndl:
      case ProfileRightAxisMetric.tts:
        return (value / 60).round().toString();
    }
  }

  /// Build axis label text for the right axis (e.g. "Temp (°C)").
  String _rightAxisLabel(ProfileRightAxisMetric metric, UnitFormatter units) {
    final name = metric.shortName;
    switch (metric) {
      case ProfileRightAxisMetric.temperature:
        return '$name (${units.temperatureSymbol})';
      case ProfileRightAxisMetric.pressure:
        return '$name (${units.pressureSymbol})';
      case ProfileRightAxisMetric.meanDepth:
        return '$name (${units.depthSymbol})';
      case ProfileRightAxisMetric.sac:
        return '$name (${units.pressureSymbol}/min)';
      default:
        final suffix = metric.unitSuffix;
        if (suffix != null) return '$name ($suffix)';
        return name;
    }
  }

  /// Map a depth axis value back to the metric value for axis labels
  double _mapDepthToMetricValue(
    double depthAxisValue,
    double maxDepth,
    double minValue,
    double maxValue,
  ) {
    final normalized = 1 - (depthAxisValue / maxDepth);
    return minValue + (normalized * (maxValue - minValue));
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
