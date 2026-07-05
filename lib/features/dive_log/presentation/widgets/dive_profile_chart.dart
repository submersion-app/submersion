import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_series_cache.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_timeline_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_overlay.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_chart_viewport.dart';
import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';

/// Structured row emitted via [DiveProfileChart.onTooltipData] so callers
/// can render the tooltip externally (e.g., below the chart).
class TooltipRow {
  final String label;
  final String value;
  final Color bulletColor;

  const TooltipRow({
    required this.label,
    required this.value,
    required this.bulletColor,
  });
}

/// Interactive dive profile chart showing depth over time with zoom/pan support
/// One overlay source drawn for comparison alongside the active source.
/// The overlay renders its own color-coded rendition of each enabled line
/// type (depth, temperature, computer-reported ceiling/NDL); its events and
/// tank pressures render through the shared per-computer gating.
class ChartSourceOverlay {
  const ChartSourceOverlay({
    required this.sourceId,
    required this.name,
    required this.color,
    required this.computerId,
    required this.points,
  });

  final String sourceId;
  final String name;
  final Color color;
  final String? computerId;
  final List<DiveProfilePoint> points;
}

class DiveProfileChart extends ConsumerStatefulWidget {
  final List<DiveProfilePoint> profile;
  final Duration? diveDuration;
  final double? maxDepth;
  final bool showTemperature;
  final bool showPressure;
  final void Function(int? index)? onPointSelected;

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

  /// Photos positioned on the profile via their import-time enrichment.
  /// Rendered as a tappable overlay when the legend toggle is on.
  final List<PhotoChartMarker>? photoMarkers;

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

  /// Gas-usage segments rendered as a horizontal strip directly between the
  /// plot area and the X-axis tick labels. When non-empty, the chart
  /// reserves [gasTimelineHeight] of extra space at the bottom and the
  /// hover/playback cursor lines extend through the strip so the active
  /// time can be read off both the depth profile and the gas in use.
  final List<GasUsageSegment>? gasSegments;

  /// Total dive duration in seconds. Required when [gasSegments] is set —
  /// the strip uses it to map segment timestamps to horizontal pixels.
  final int? diveDurationSeconds;

  /// Height of the integrated gas timeline strip in logical pixels.
  /// Kept slim so the bar reads as a thin band beneath the plot; the floor is
  /// the label's line box (`labelSmall` ~16px), below which the centered gas
  /// name would start to clip.
  static const double gasTimelineHeight = 18.0;

  /// fl_chart default axisNameSize used for left and right axes.
  static const double _leftRightAxisNameSize = 16.0;

  /// axisNameSize for the bottom (time) axis.
  static const double _bottomAxisNameSize = 14.0;

  /// reservedSize for the bottom sideTitles tick-label area (no gas strip).
  static const double _bottomTickReservedSize = 22.0;

  /// Optional key for exporting the chart as an image.
  /// When provided, wraps the chart in a RepaintBoundary for screenshot capture.
  final GlobalKey? exportKey;

  /// Optional playback cursor timestamp in seconds.
  /// When provided, renders a vertical line at this position for step-through playback.
  final int? playbackTimestamp;

  /// Optional highlighted timestamp in seconds (e.g. from heat map hover).
  /// Renders a subtle vertical line at this position.
  final int? highlightedTimestamp;

  // Advanced decompression/gas curves
  /// ppO2 curve in bar
  final List<double>? ppO2Curve;

  /// Individual CCR O2 cell readings (bar). Outer list indexed by cell
  /// (Sensor 1, Sensor 2, ...), inner list per sample (null where no reading).
  /// Shown in the tooltip alongside the resolved ppO2.
  final List<List<double?>>? o2SensorCurves;

  /// True when [ppO2Curve] is a cell average (no computer-supplied ppO2),
  /// used to label the tooltip "ppO2 (avg)".
  final bool ppO2FromSensorAverage;

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

  /// Cumulative CNS% curve (includes residual from prior dives)
  final List<double>? cnsCurve;

  /// Cumulative OTU curve
  final List<double>? otuCurve;

  // Multi-source rendering parameters
  /// Overlay sources drawn for comparison alongside the active source
  /// ([profile]). Each overlay renders dashed, in its own color.
  final List<ChartSourceOverlay>? overlays;

  /// The active source's computer id. Per-computer data (events, tank
  /// pressures) attributed to this id — or to no computer at all — belongs
  /// to the active source and always draws; other computers draw only while
  /// overlaid.
  final String? activeComputerId;

  /// Map of computerId -> display name (e.g. "Perdix 2"), used to label
  /// tank-pressure tooltip rows with their source computer when 2+
  /// computers contribute pressure curves to the same chart.
  final Map<String, String>? computerNames;

  /// When true, the built-in tooltip is suppressed and tooltip data is
  /// emitted via [onTooltipData] so callers can render it externally
  /// (e.g., below the chart in the profile panel).
  final bool tooltipBelow;

  /// Called with structured tooltip row data when a point is touched
  /// and [tooltipBelow] is true. Null clears the tooltip.
  final void Function(List<TooltipRow>? rows)? onTooltipData;

  /// Optional widget rendered at the start of the legend row (e.g. a close
  /// button and title in the fullscreen view).
  final Widget? legendLeading;

  /// Returns responsive left axis reserved size based on available chart width.
  /// Tick labels are plain numbers (e.g. "30", "60") so don't need much space.
  static double leftAxisSize(double availableWidth) =>
      availableWidth < 350 ? 28.0 : 32.0;

  /// Returns responsive right axis reserved size based on available chart width.
  /// Needs extra room for 4-digit values like PSI pressure (e.g. "3000").
  static double rightAxisSize(double availableWidth) =>
      availableWidth < 350 ? 32.0 : 38.0;

  /// Builds the label for a tank's pressure row in the profile tooltip,
  /// appending the gas type when the tank is known, e.g. "Tank 1 (EAN32)".
  ///
  /// [fallbackLabel] is used when the tank has no custom name; callers pass a
  /// localized default (e.g. "Tank 1") so labeling stays translatable.
  @visibleForTesting
  static String tankTooltipLabel(DiveTank? tank, String fallbackLabel) {
    final base = tank?.name ?? fallbackLabel;
    if (tank == null) return base;
    return '$base (${tank.gasMix.name})';
  }

  /// Formats one tooltip row into aligned monospace label/value columns.
  ///
  /// The label is padded to [labelWidth] but never truncated; when it already
  /// fills (or overruns) the column a single separating space is kept so a long
  /// label such as "Tank 1 (EAN32)" never abuts the value. The value is clamped
  /// only if it would overflow [valueWidth]. Also used by the fullscreen
  /// readout card so both readouts share one row format.
  static String tooltipRowText(
    String label,
    String value,
    int labelWidth,
    int valueWidth,
  ) {
    final labelText = label.length >= labelWidth
        ? '$label '
        : label.padRight(labelWidth);
    final valueText = value.length > valueWidth
        ? value.substring(0, valueWidth)
        : value.padRight(valueWidth);
    return (labelText + valueText).trimRight();
  }

  /// Symmetric m/min range for the ascent-rate line and the right axis so both
  /// share one scale. Returns null when there is no ascent-rate data. The floor
  /// keeps the scale meaningful for gentle dives.
  @visibleForTesting
  static ({double min, double max})? ascentRateAxisRange(
    List<AscentRatePoint>? rates,
  ) {
    if (rates == null || rates.isEmpty) return null;
    var maxAbs = 0.0;
    for (final r in rates) {
      final a = r.rateMetersPerMin.abs();
      if (a > maxAbs) maxAbs = a;
    }
    // Floor the scale a little above the danger threshold so the warning/danger
    // bands are always on-axis; derived from the calculator's threshold so the
    // two cannot drift apart.
    const floorSpan = AscentRateCalculator.defaultCriticalThreshold * 1.25;
    final span = math.max(maxAbs, floorSpan);
    return (min: -span, max: span);
  }

  /// Contiguous velocity-band runs over the depth profile, in draw order.
  ///
  /// Adjacent samples in the same band merge into one run covering profile
  /// points `[start, end)` (end exclusive). The ascent-rate at index i describes
  /// the segment that *ends* at i (index 0 is a zero placeholder), so the first
  /// drawable run starts at sample 1 and reaches back to point 0. Neighbouring
  /// runs share their boundary sample, so a run's `start` is the previous run's
  /// last point.
  ///
  /// This is the single source of truth for both velocity colouring
  /// ([_DiveProfileChartState._buildVelocityColoredDepthLines]) and mapping a
  /// touched depth spot back to its global profile index: a spot on bar `b` at
  /// local `spotIndex` addresses profile point `runs[b].start + spotIndex`.
  @visibleForTesting
  static List<({int start, int end, AscentRateCategory category})>
  velocityBandRuns(int profileLength, List<AscentRatePoint> ascentRates) {
    // The loop indexes ascentRates up to profileLength - 1, so it needs at
    // least one rate sample per profile point. All internal callers validate
    // this; the assert turns a would-be RangeError into a clear message if the
    // exposed helper is ever mis-called.
    assert(
      ascentRates.length >= profileLength,
      'velocityBandRuns needs one ascent-rate sample per profile point '
      '(got ${ascentRates.length} for $profileLength points)',
    );
    final runs = <({int start, int end, AscentRateCategory category})>[];
    var segStart = 1; // first drawable segment connects points 0 and 1
    while (segStart < profileLength) {
      var segEnd = segStart;
      while (segEnd + 1 < profileLength &&
          ascentRates[segEnd + 1].category == ascentRates[segStart].category) {
        segEnd++;
      }
      runs.add((
        start: segStart - 1,
        end: segEnd + 1,
        category: ascentRates[segStart].category,
      ));
      segStart = segEnd + 1;
    }
    return runs;
  }

  /// Depth-band touched spots whose built-in focus indicator should be hidden.
  ///
  /// Velocity colouring splits the depth line into one [LineChartBarData] per
  /// ascent-rate band ([velocityBandRuns]). fl_chart's built-in touch handling
  /// then paints a focus dot on *every* band whose nearest sample falls within
  /// the touch threshold, so hovering an abrupt (warning/danger) stretch
  /// clusters several depth dots around the cursor. Keep the dot on the band
  /// the tooltip resolves to -- the first touched depth bar, matching the
  /// onPointSelected mapping -- and return the other touched depth-band spots
  /// so the caller can suppress their indicators.
  ///
  /// Returns an empty list when the depth line is a single bar
  /// ([depthBandCount] <= 1: velocity colouring off, or multi-computer
  /// rendering) or only one band sits under the cursor, leaving fl_chart's
  /// default behaviour untouched. A dropped band that shares the kept band's
  /// exact sample (adjacent bands join on their boundary point) is left in
  /// place so the two indicators overlap into one dot instead of cancelling.
  @visibleForTesting
  static List<({double x, double y})> velocityIndicatorSuppression(
    List<({int barIndex, double x, double y})> touchedSpots,
    int depthBandCount,
  ) {
    if (depthBandCount <= 1) return const [];
    final depthSpots = touchedSpots
        .where((s) => s.barIndex < depthBandCount)
        .toList();
    if (depthSpots.length <= 1) return const [];
    final kept = depthSpots.first;
    return depthSpots
        .skip(1)
        .where((s) => s.x != kept.x || s.y != kept.y)
        .map((s) => (x: s.x, y: s.y))
        .toList();
  }

  /// Resolve a touched depth spot to an index into [profile].
  ///
  /// fl_chart reports a touched spot as `(barIndex, spotIndex)`, where
  /// [spotIndex] is local to that bar's own spot list, alongside the spot's x
  /// coordinate ([spotX], the sample timestamp in seconds).
  ///
  /// Single-computer rendering -- including the velocity-split bands -- draws
  /// every depth bar from a contiguous slice of [profile], so
  /// `depthBarStarts[barIndex] + spotIndex` addresses the sample directly.
  ///
  /// Multi-computer rendering draws one depth bar per computer from that
  /// computer's OWN point array, which need not align index-for-index with
  /// [profile] (different sample counts, or the [profile]-backing computer
  /// toggled off). The local [spotIndex] is then meaningless against [profile],
  /// so resolve by the spot's actual timestamp: the nearest [profile] sample to
  /// [spotX]. Without this, the hover cursor and tooltip read the wrong sample
  /// and stop tracking the pointer once a second computer is present. Returns
  /// -1 when [profile] is empty.
  @visibleForTesting
  static int depthSpotProfileIndex({
    required List<DiveProfilePoint> profile,
    required List<int> depthBarStarts,
    required int barIndex,
    required int spotIndex,
    required double spotX,
    required bool multiComputer,
  }) {
    if (!multiComputer) {
      return depthBarStarts[barIndex] + spotIndex;
    }
    if (profile.isEmpty) return -1;
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < profile.length; i++) {
      final d = (profile[i].timestamp - spotX).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

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
    this.showAscentRateColors = false,
    this.showEvents = true,
    this.showSac = false,
    this.markers,
    this.photoMarkers,
    this.showMaxDepthMarker = false,
    this.showPressureThresholdMarkers = false,
    this.gasSwitches,
    this.tanks,
    this.tankPressures,
    this.gasSegments,
    this.diveDurationSeconds,
    this.exportKey,
    this.playbackTimestamp,
    this.highlightedTimestamp,
    this.ppO2Curve,
    this.o2SensorCurves,
    this.ppO2FromSensorAverage = false,
    this.ppN2Curve,
    this.ppHeCurve,
    this.modCurve,
    this.densityCurve,
    this.gfCurve,
    this.surfaceGfCurve,
    this.meanDepthCurve,
    this.ttsCurve,
    this.cnsCurve,
    this.otuCurve,
    this.overlays,
    this.activeComputerId,
    this.computerNames,
    this.tooltipBelow = false,
    this.onTooltipData,
    this.legendLeading,
  });

  @override
  ConsumerState<DiveProfileChart> createState() => _DiveProfileChartState();
}

class _DiveProfileChartState extends ConsumerState<DiveProfileChart> {
  bool _showTemperature = true;

  bool _showHeartRate = false;
  bool _showSac = false;

  // Per-tank pressure visibility (keyed by tank ID)
  // Defaults to all visible; populated on first build if multi-tank data exists
  final Map<String, bool> _showTankPressure = {};

  // Decompression visualization toggles
  bool _showCeiling = true;
  bool _showAscentRateColors = false;
  bool _showAscentRateLine = false;
  bool _showEvents = true;

  // Profile marker toggles
  bool _showMaxDepthMarkerLocal = true;
  bool _showPressureMarkersLocal = true;

  // Gas switch visualization toggle
  bool _showGasSwitchMarkers = true;

  // Photo marker visualization toggle
  bool _showPhotoMarkers = true;

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
  bool _showCns = false;
  bool _showOtu = false;

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

  /// Whether per-computer data attributed to [computerId] should be drawn.
  ///
  /// A `null` [computerId] (the null-means-primary convention used by
  /// dive_profiles/dive_profile_events/tank_pressure_profiles rows — see
  /// database.dart) or the active source's own computer always draws.
  /// Other computers draw only while their source is overlaid. When the
  /// caller wired no active computer and no overlays (single-source dive),
  /// everything is visible.
  bool _isComputerVisible(String? computerId) {
    if (computerId == null) return true;
    final overlays = widget.overlays;
    if (widget.activeComputerId == null && (overlays?.isEmpty ?? true)) {
      return true;
    }
    if (computerId == widget.activeComputerId) return true;
    return overlays?.any((o) => o.computerId == computerId) ?? false;
  }

  /// Nearest sample of [overlay] strictly within 10 seconds of [timestamp];
  /// null when the overlay has no sample near that time (e.g. the overlaid
  /// computer surfaced earlier). Overlay points are time-ordered, so a
  /// binary-search lower bound finds the window start and only its
  /// immediate neighborhood is scanned (tooltips rebuild on every hover
  /// move, so this must not be O(n) in profile length).
  DiveProfilePoint? _overlayPointAt(ChartSourceOverlay overlay, int timestamp) {
    final points = overlay.points;
    if (points.isEmpty) return null;

    // Lower bound: first index with points[i].timestamp >= timestamp - 10.
    final windowStart = timestamp - 10;
    var lo = 0;
    var hi = points.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (points[mid].timestamp < windowStart) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    DiveProfilePoint? best;
    var bestDelta = 11;
    for (var i = lo; i < points.length; i++) {
      final p = points[i];
      if (p.timestamp > timestamp + 10) break;
      final delta = (p.timestamp - timestamp).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = p;
      }
    }
    return best;
  }

  /// Map of tankId -> owning computerId, derived from [widget.tanks].
  /// Tanks without attribution (single-source dives, manually entered
  /// tanks) map to null and are always treated as visible.
  Map<String, String?> _tankComputerIds() => {
    for (final t in widget.tanks ?? const <DiveTank>[]) t.id: t.computerId,
  };

  /// Distinct, currently-visible computer IDs attributed to any of
  /// [tankIds]'s owning tanks. Used to decide whether tank-pressure tooltip
  /// rows need a source-computer suffix (only when 2+ computers actually
  /// contribute pressure data at once — a single contributor is unambiguous).
  Set<String> _contributingTankComputerIds(
    Iterable<String> tankIds,
    Map<String, String?> tankComputerIds,
  ) {
    final ids = <String>{};
    for (final tankId in tankIds) {
      final computerId = tankComputerIds[tankId];
      if (computerId != null && _isComputerVisible(computerId)) {
        ids.add(computerId);
      }
    }
    return ids;
  }

  /// Suffix identifying a tank's source computer in a tooltip label, e.g.
  /// " · Perdix 2". Empty when there's nothing to disambiguate: fewer than
  /// 2 contributing computers, an unattributed tank, or no display name
  /// available for the tank's computer.
  String _tankSourceSuffix(
    String tankId,
    Map<String, String?> tankComputerIds,
    Set<String> contributingComputerIds,
  ) {
    if (contributingComputerIds.length < 2) return '';
    final computerId = tankComputerIds[tankId];
    if (computerId == null) return '';
    final name = widget.computerNames?[computerId];
    if (name == null) return '';
    return ' · $name';
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

  /// Colour for a velocity-coloured depth-line band. The safe/baseline band
  /// keeps the normal depth blue so the line looks unchanged where the ascent
  /// is within limits; only the elevated warning/danger bands are recoloured.
  Color _velocityDepthColor(AscentRateCategory category) =>
      category == AscentRateCategory.safe
      ? AppColors.chartDepth
      : _getAscentRateColor(category);

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

  // Zoom/pan state — see profile_chart_viewport.dart.
  ProfileChartViewport _viewport = ProfileChartViewport.reset;

  // Snapshot of the viewport at the start of a continuous gesture; continuous
  // gestures report cumulative scale/pan, so we apply them against this.
  ProfileChartViewport _gestureStartViewport = ProfileChartViewport.reset;
  Offset _startFocalPoint = Offset.zero;

  // Local position of the most recent (double-)tap, for tap-anchored zoom.
  Offset _lastTapDownLocal = Offset.zero;

  // Active pointer kind, corrected on the first real pointer event. Chooses
  // pan-vs-scrub for single-pointer drags and is set by trackpad gestures.
  PointerDeviceKind _activePointerKind =
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)
      ? PointerDeviceKind.touch
      : PointerDeviceKind.mouse;

  // Cursor position at the start of a trackpad pan/zoom gesture.

  // True between a double-tap-down and the finger lifting; lets a held-finger
  // drag pan instead of scrub.
  bool _doubleTapHold = false;

  // Index of the last sample reported via hover, to de-dupe onPointSelected.
  int? _lastHoverIndex;

  // Last raw pointer position during a drag; used to compute per-move deltas
  // in the Listener.onPointerMove mouse-pan path (bypasses gesture arena).
  Offset? _lastPointerLocal;

  // Number of pointers currently down. onPointerMove only pans for a genuine
  // single-pointer drag, so a multi-finger touch never leaks into the pan path
  // (this is what keeps Task 7's double-tap-hold pan single-finger-only).
  int _activePointerCount = 0;

  // Tooltip memoization
  int? _lastTooltipSpotIndex;
  List<LineTooltipItem?> _lastTooltipItems = [];

  // Depth-band touched spots whose built-in focus indicator is hidden, so
  // velocity colouring shows a single depth dot instead of one per band.
  // Set from the touch response in the LineTouchData touchCallback and read by
  // getTouchedSpotIndicator during paint. See [velocityIndicatorSuppression].
  List<({double x, double y})> _suppressedDepthIndicatorSpots = const [];

  // Memoized lineBarsData. The chart's series builders are pure w.r.t.
  // interaction state, so the assembled bars are reused across playback / hover
  // / zoom rebuilds and only reconstructed when the underlying data, units,
  // visibility, or theme change (see [_barsSignature]).
  final ChartSeriesCache<LineChartBarData> _barsCache =
      ChartSeriesCache<LineChartBarData>();

  /// Identity of everything the assembled bars depend on. Excludes playback,
  /// viewport, highlight, and tooltip state -- those drive separate overlays and
  /// never change the bars. [legendState] is taken as [Object] since only its
  /// identity (changed on any visibility toggle) matters here. [colorScheme] is
  /// hashed by value (not just its [Brightness]) so switching between two
  /// presets of the same brightness -- which recolours series such as the
  /// tertiary temperature line -- still invalidates the cached bars.
  String _barsSignature(
    UnitFormatter units,
    Object legendState,
    ColorScheme colorScheme,
  ) => [
    identityHashCode(widget.profile),
    identityHashCode(widget.ascentRates),
    identityHashCode(widget.ceilingCurve),
    identityHashCode(widget.ndlCurve),
    identityHashCode(widget.sacCurve),
    identityHashCode(widget.ppO2Curve),
    identityHashCode(widget.ppN2Curve),
    identityHashCode(widget.ppHeCurve),
    identityHashCode(widget.modCurve),
    identityHashCode(widget.densityCurve),
    identityHashCode(widget.gfCurve),
    identityHashCode(widget.surfaceGfCurve),
    identityHashCode(widget.meanDepthCurve),
    identityHashCode(widget.ttsCurve),
    identityHashCode(widget.cnsCurve),
    identityHashCode(widget.otuCurve),
    identityHashCode(widget.tankPressures),
    identityHashCode(widget.overlays),
    identityHashCode(widget.gasSwitches),
    identityHashCode(widget.tanks),
    identityHashCode(widget.markers),
    identityHashCode(legendState),
    units.depthSymbol,
    units.temperatureSymbol,
    units.pressureSymbol,
    units.sacSymbol,
    colorScheme.hashCode,
  ].join('|');

  @override
  void initState() {
    super.initState();
    _showTemperature = widget.showTemperature;
    _showSac = widget.showSac;
    _showCeiling = widget.showCeiling;
    _showAscentRateColors = widget.showAscentRateColors;
    _showEvents = widget.showEvents;
    _scheduleTankPressureVisibilityInitialization();
  }

  @override
  void didUpdateWidget(covariant DiveProfileChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _lastTooltipSpotIndex = null;
      _lastTooltipItems = [];
    }
    if (oldWidget.tankPressures != widget.tankPressures) {
      _scheduleTankPressureVisibilityInitialization();
    }
  }

  void _scheduleTankPressureVisibilityInitialization() {
    if (!_hasMultiTankPressure) return;
    final tankIds = widget.tankPressures!.keys.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tankIds.isEmpty) return;
      ref.read(profileLegendProvider.notifier).initializeTankPressures(tankIds);
    });
  }

  void _resetZoom() {
    setState(() => _viewport = ProfileChartViewport.reset);
  }

  /// Build and emit [TooltipRow] data for external rendering when
  /// [DiveProfileChart.tooltipBelow] is true.
  void _emitExternalTooltip(
    List<LineBarSpot> touchedSpots,
    UnitFormatter units,
    ColorScheme colorScheme,
  ) {
    if (widget.onTooltipData == null) return;

    // The depth line may be split into per-band bars (velocity colouring), so a
    // touched spot's spotIndex is local to its segment. Resolve it to the global
    // profile index, then shadow `spot` with that index so every row below reads
    // the right sample without further changes.
    final starts = _depthBarStartIndices();
    final touched = touchedSpots
        .where((s) => s.barIndex < starts.length)
        .firstOrNull;
    final index = touched == null
        ? -1
        : starts[touched.barIndex] + touched.spotIndex;
    if (touched == null || index < 0 || index >= widget.profile.length) {
      widget.onTooltipData!(null);
      return;
    }
    final spot = (spotIndex: index);

    final point = widget.profile[spot.spotIndex];
    final rows = <TooltipRow>[];
    final onSurface = colorScheme.onInverseSurface;

    // Time
    final minutes = point.timestamp ~/ 60;
    final seconds = point.timestamp % 60;
    rows.add(
      TooltipRow(
        label: 'Time',
        value: '$minutes:${seconds.toString().padLeft(2, '0')}',
        bulletColor: onSurface.withValues(alpha: 0.5),
      ),
    );

    // Depth
    rows.add(
      TooltipRow(
        label: 'Depth',
        value: units.formatDepth(point.depth),
        bulletColor: AppColors.chartDepth,
      ),
    );

    // Overlaid sources' depth at this time, labeled with the metric so
    // the value is unambiguous.
    for (final overlay in widget.overlays ?? const <ChartSourceOverlay>[]) {
      final overlayPoint = _overlayPointAt(overlay, point.timestamp);
      if (overlayPoint == null) continue;
      rows.add(
        TooltipRow(
          label: 'Depth · ${overlay.name}',
          value: units.formatDepth(overlayPoint.depth),
          bulletColor: overlay.color,
        ),
      );
    }

    // Temperature
    if (_showTemperature) {
      rows.add(
        TooltipRow(
          label: 'Temp',
          value: point.temperature != null
              ? units.formatTemperature(point.temperature)
              : '-',
          bulletColor: colorScheme.tertiary,
        ),
      );
      for (final overlay in widget.overlays ?? const <ChartSourceOverlay>[]) {
        final overlayTemp = _overlayPointAt(
          overlay,
          point.timestamp,
        )?.temperature;
        if (overlayTemp == null) continue;
        rows.add(
          TooltipRow(
            label: 'Temp · ${overlay.name}',
            value: units.formatTemperature(overlayTemp),
            bulletColor: overlay.color.withValues(alpha: 0.6),
          ),
        );
      }
    }

    // Ceiling
    if (_showCeiling &&
        widget.ceilingCurve != null &&
        spot.spotIndex < widget.ceilingCurve!.length) {
      final ceiling = widget.ceilingCurve![spot.spotIndex];
      rows.add(
        TooltipRow(
          label: 'Ceiling',
          value: ceiling > 0 ? units.formatDepth(ceiling) : '-',
          bulletColor: const Color(0xFFD32F2F),
        ),
      );
    }

    // Ascent rate
    if ((_showAscentRateColors || _showAscentRateLine) &&
        widget.ascentRates != null &&
        spot.spotIndex < widget.ascentRates!.length) {
      final ascentRate = widget.ascentRates![spot.spotIndex];
      final rate = ascentRate.rateMetersPerMin;
      final convertedRate = units.convertDepth(rate.abs());
      String arrow = '-';
      Color rateColor = Colors.grey;
      if (rate > 0.5) {
        arrow = '\u2191';
        rateColor = ascentRate.category == AscentRateCategory.safe
            ? Colors.lime
            : _getAscentRateColor(ascentRate.category);
      } else if (rate < -0.5) {
        arrow = '\u2193';
        rateColor = Colors.cyan;
      }
      rows.add(
        TooltipRow(
          label: 'Rate',
          value:
              '$arrow ${convertedRate.toStringAsFixed(1)} ${units.depthSymbol}/min',
          bulletColor: rateColor,
        ),
      );
    }

    // Heart rate
    if (_showHeartRate) {
      rows.add(
        TooltipRow(
          label: 'HR',
          value: point.heartRate != null ? '${point.heartRate} bpm' : '-',
          bulletColor: Colors.red,
        ),
      );
    }

    // SAC
    if (_showSac &&
        widget.sacCurve != null &&
        spot.spotIndex < widget.sacCurve!.length) {
      final sacBarPerMin = widget.sacCurve![spot.spotIndex];
      String sacValue = '-';
      if (sacBarPerMin > 0) {
        final normalizedSac = sacBarPerMin * widget.sacNormalizationFactor;
        final sacUnit = ref.read(settingsProvider).sacUnit;
        if (sacUnit == SacUnit.litersPerMin && widget.tankVolume != null) {
          final sacLPerMin = normalizedSac * widget.tankVolume!;
          sacValue =
              '${units.convertVolume(sacLPerMin).toStringAsFixed(1)} ${units.volumeSymbol}/min';
        } else {
          sacValue =
              '${units.convertPressure(normalizedSac).toStringAsFixed(1)} ${units.pressureSymbol}/min';
        }
      }
      rows.add(
        TooltipRow(label: 'SAC', value: sacValue, bulletColor: Colors.teal),
      );
    }

    // NDL
    if (_showNdl &&
        widget.ndlCurve != null &&
        spot.spotIndex < widget.ndlCurve!.length) {
      final ndl = widget.ndlCurve![spot.spotIndex];
      String ndlValue;
      if (ndl < 0) {
        ndlValue = 'DECO';
      } else if (ndl < 3600) {
        final min = ndl ~/ 60;
        final sec = ndl % 60;
        ndlValue = '$min:${sec.toString().padLeft(2, '0')}';
      } else {
        ndlValue = '>60 min';
      }
      rows.add(
        TooltipRow(
          label: 'NDL',
          value: ndlValue,
          bulletColor: Colors.yellow.shade700,
        ),
      );
    }

    // ppO2 (computer-supplied value or O2 cell average) plus each sensor cell.
    if (_showPpO2 &&
        widget.ppO2Curve != null &&
        spot.spotIndex < widget.ppO2Curve!.length) {
      rows.add(
        TooltipRow(
          label: widget.ppO2FromSensorAverage
              ? '${context.l10n.diveLog_tooltip_ppO2} ${context.l10n.diveLog_tooltip_avgCalculated}'
              : context.l10n.diveLog_tooltip_ppO2,
          value: '${widget.ppO2Curve![spot.spotIndex].toStringAsFixed(2)} bar',
          bulletColor: const Color(0xFF00ACC1),
        ),
      );
      final sensorCurves = widget.o2SensorCurves;
      if (sensorCurves != null) {
        for (var cell = 0; cell < sensorCurves.length; cell++) {
          final readings = sensorCurves[cell];
          if (spot.spotIndex >= readings.length) continue;
          final reading = readings[spot.spotIndex];
          if (reading == null) continue;
          rows.add(
            TooltipRow(
              label: '${context.l10n.diveLog_tooltip_sensor} ${cell + 1}',
              value: '${reading.toStringAsFixed(2)} bar',
              bulletColor: const Color(0xFF80DEEA),
            ),
          );
        }
      }
    }

    // ppN2
    if (_showPpN2 &&
        widget.ppN2Curve != null &&
        spot.spotIndex < widget.ppN2Curve!.length) {
      rows.add(
        TooltipRow(
          label: 'ppN2',
          value: '${widget.ppN2Curve![spot.spotIndex].toStringAsFixed(2)} bar',
          bulletColor: Colors.indigo,
        ),
      );
    }

    // ppHe
    if (_showPpHe &&
        widget.ppHeCurve != null &&
        spot.spotIndex < widget.ppHeCurve!.length) {
      final ppHe = widget.ppHeCurve![spot.spotIndex];
      if (ppHe > 0.001) {
        rows.add(
          TooltipRow(
            label: 'ppHe',
            value: '${ppHe.toStringAsFixed(2)} bar',
            bulletColor: Colors.pink.shade300,
          ),
        );
      }
    }

    // MOD
    if (_showMod &&
        widget.modCurve != null &&
        spot.spotIndex < widget.modCurve!.length) {
      final mod = widget.modCurve![spot.spotIndex];
      if (mod > 0 && mod < 200) {
        rows.add(
          TooltipRow(
            label: 'MOD',
            value: units.formatDepth(mod),
            bulletColor: Colors.deepOrange,
          ),
        );
      }
    }

    // Gas density
    if (_showDensity &&
        widget.densityCurve != null &&
        spot.spotIndex < widget.densityCurve!.length) {
      rows.add(
        TooltipRow(
          label: 'Density',
          value:
              '${widget.densityCurve![spot.spotIndex].toStringAsFixed(2)} g/L',
          bulletColor: Colors.brown,
        ),
      );
    }

    // GF%
    if (_showGf &&
        widget.gfCurve != null &&
        spot.spotIndex < widget.gfCurve!.length) {
      rows.add(
        TooltipRow(
          label: 'GF',
          value: '${widget.gfCurve![spot.spotIndex].toStringAsFixed(0)}%',
          bulletColor: Colors.deepPurple,
        ),
      );
    }

    // Surface GF
    if (_showSurfaceGf &&
        widget.surfaceGfCurve != null &&
        spot.spotIndex < widget.surfaceGfCurve!.length) {
      rows.add(
        TooltipRow(
          label: 'Srf GF',
          value:
              '${widget.surfaceGfCurve![spot.spotIndex].toStringAsFixed(0)}%',
          bulletColor: Colors.purple.shade300,
        ),
      );
    }

    // Mean depth
    if (_showMeanDepth &&
        widget.meanDepthCurve != null &&
        spot.spotIndex < widget.meanDepthCurve!.length) {
      rows.add(
        TooltipRow(
          label: 'Mean',
          value: units.formatDepth(widget.meanDepthCurve![spot.spotIndex]),
          bulletColor: Colors.blueGrey,
        ),
      );
    }

    // TTS
    if (_showTts &&
        widget.ttsCurve != null &&
        spot.spotIndex < widget.ttsCurve!.length) {
      final tts = widget.ttsCurve![spot.spotIndex];
      rows.add(
        TooltipRow(
          label: 'TTS',
          value: tts > 0 ? '${(tts / 60).ceil()} min' : '0 min',
          bulletColor: const Color(0xFFAD1457),
        ),
      );
    }

    // CNS%
    if (_showCns &&
        widget.cnsCurve != null &&
        spot.spotIndex < widget.cnsCurve!.length) {
      rows.add(
        TooltipRow(
          label: 'CNS',
          value: '${widget.cnsCurve![spot.spotIndex].toStringAsFixed(1)}%',
          bulletColor: const Color(0xFFE65100),
        ),
      );
    }

    // OTU
    if (_showOtu &&
        widget.otuCurve != null &&
        spot.spotIndex < widget.otuCurve!.length) {
      rows.add(
        TooltipRow(
          label: 'OTU',
          value: widget.otuCurve![spot.spotIndex].toStringAsFixed(0),
          bulletColor: const Color(0xFF6D4C41),
        ),
      );
    }

    // Per-tank pressure
    if (widget.tankPressures != null) {
      final timestamp = point.timestamp;
      final sortedTankIds = _sortedTankIds(widget.tankPressures!.keys);
      final tankComputerIds = _tankComputerIds();
      final contributingComputerIds = _contributingTankComputerIds(
        sortedTankIds,
        tankComputerIds,
      );
      for (var i = 0; i < sortedTankIds.length; i++) {
        final tankId = sortedTankIds[i];
        if (!(_showTankPressure[tankId] ?? true)) continue;
        if (!_isComputerVisible(tankComputerIds[tankId])) continue;
        final pressurePoints = widget.tankPressures![tankId];
        if (pressurePoints == null || pressurePoints.isEmpty) continue;
        final pressure = _interpolateTankPressure(pressurePoints, timestamp);
        final tank = _getTankById(tankId);
        final color = tank != null
            ? GasColors.forGasMix(tank.gasMix)
            : _getTankColor(i);
        final tankLabel =
            DiveProfileChart.tankTooltipLabel(tank, 'Tank ${i + 1}') +
            _tankSourceSuffix(tankId, tankComputerIds, contributingComputerIds);
        rows.add(
          TooltipRow(
            label: tankLabel,
            value: pressure != null ? units.formatPressure(pressure) : '-',
            bulletColor: color,
          ),
        );
      }
    }

    // Marker info (if touching near a marker)
    if (widget.markers != null && widget.markers!.isNotEmpty) {
      final timestamp = point.timestamp;
      const timestampThreshold = 3;
      for (final marker in widget.markers!) {
        if (marker.type == ProfileMarkerType.maxDepth) {
          if (!widget.showMaxDepthMarker || !_showMaxDepthMarkerLocal) continue;
        } else {
          if (!widget.showPressureThresholdMarkers ||
              !_showPressureMarkersLocal) {
            continue;
          }
        }
        if ((marker.timestamp - timestamp).abs() <= timestampThreshold) {
          rows.add(
            TooltipRow(
              label: 'Marker',
              value: marker.chartLabel,
              bulletColor: marker.getColor(),
            ),
          );
        }
      }
    }

    widget.onTooltipData!(rows);
  }

  /// The plot-rect insets (reserved axis gutters) for the current build, so a
  /// gesture's local position can be mapped to a plot-area fraction. Mirrors
  /// the axis reservations used for the gas-strip overlay (left/right at
  /// :2265-2270, bottom at :1379-1382). Top has no titles, so its inset is 0.
  ({double left, double top, double right, double bottom}) _plotInsets(
    double availableWidth,
    UnitFormatter units,
  ) {
    final legendNotifier = ref.read(profileLegendProvider.notifier);
    final preferredMetric = legendNotifier.getEffectiveRightAxisMetric();
    final effectiveRightAxisMetric = preferredMetric != null
        ? _getEffectiveRightAxisMetric(preferredMetric)
        : null;
    final rightAxisRange = effectiveRightAxisMetric != null
        ? _getMetricRange(effectiveRightAxisMetric, units)
        : null;
    final hasRightAxisName =
        effectiveRightAxisMetric != null && rightAxisRange != null;
    // ref.read (NOT _hasGasStrip's ref.watch): _plotInsets runs from gesture
    // callbacks, outside build, where ref.watch must not be used.
    final hasGasStrip = _gasStripVisible(
      ref.read(profileLegendProvider).showGas,
    );

    return (
      left:
          DiveProfileChart._leftRightAxisNameSize +
          DiveProfileChart.leftAxisSize(availableWidth),
      top: 0,
      right:
          (hasRightAxisName ? DiveProfileChart._leftRightAxisNameSize : 0) +
          DiveProfileChart.rightAxisSize(availableWidth),
      bottom:
          DiveProfileChart._bottomAxisNameSize +
          (hasGasStrip
              ? DiveProfileChart._bottomTickReservedSize +
                    DiveProfileChart.gasTimelineHeight
              : DiveProfileChart._bottomTickReservedSize),
    );
  }

  /// Nearest profile sample index under a hover at [localPos], or null if the
  /// profile is empty. Maps the cursor X through the current viewport to a
  /// timestamp, then finds the closest sample.
  int? _hoverIndex(
    Offset localPos,
    Size box,
    ({double left, double top, double right, double bottom}) insets,
  ) {
    if (widget.profile.isEmpty) return null;
    final focal = chartFocalFraction(
      localPos,
      box,
      left: insets.left,
      right: insets.right,
      top: insets.top,
      bottom: insets.bottom,
    );
    final totalMaxTime = widget.profile
        .map((p) => p.timestamp)
        .reduce(math.max)
        .toDouble();
    final t =
        (_viewport.offsetX + focal.fx * _viewport.visibleWidth) * totalMaxTime;
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < widget.profile.length; i++) {
      final d = (widget.profile[i].timestamp - t).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  // Buttons have no cursor, so they zoom about the visible center.
  void _zoomIn() {
    setState(() => _viewport = _viewport.zoomedAt(0.5, 0.5, 1.5));
  }

  void _zoomOut() {
    setState(() => _viewport = _viewport.zoomedAt(0.5, 0.5, 1 / 1.5));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.isEmpty) {
      return _buildEmptyState(context);
    }

    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    // Temperature data from the active source or any overlaid source should
    // surface the temperature toggle.
    final overlaySources = widget.overlays ?? const <ChartSourceOverlay>[];
    final hasTemperatureData =
        widget.profile.any((p) => p.temperature != null) ||
        overlaySources.any((o) => o.points.any((p) => p.temperature != null));
    final hasPressureData = _hasMultiTankPressure;
    final hasHeartRateData = widget.profile.any((p) => p.heartRate != null);
    final colorScheme = Theme.of(context).colorScheme;

    // Watch legend state from provider
    final legendState = ref.watch(profileLegendProvider);

    // Sync local state with provider for backward compatibility
    // This allows the chart rendering logic to continue using local state
    _showTemperature = legendState.showTemperature;
    _showHeartRate = legendState.showHeartRate;
    _showSac = legendState.showSac;
    _showCeiling = legendState.showCeiling;
    _showAscentRateColors = legendState.showAscentRateColors;
    _showAscentRateLine = legendState.showAscentRateLine;
    _showEvents = legendState.showEvents;
    _showMaxDepthMarkerLocal = legendState.showMaxDepthMarker;
    _showPressureMarkersLocal = legendState.showPressureMarkers;
    _showGasSwitchMarkers = legendState.showGasSwitchMarkers;
    _showPhotoMarkers = legendState.showPhotoMarkers;
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
    _showCns = legendState.showCns;
    _showOtu = legendState.showOtu;
    // Sync per-tank pressure visibility
    for (final entry in legendState.showTankPressure.entries) {
      _showTankPressure[entry.key] = entry.value;
    }

    // Drop the memoized bars only when their inputs change; playback / hover /
    // zoom rebuilds keep the same signature and reuse the assembled series.
    _barsCache.invalidate(_barsSignature(units, legendState, colorScheme));

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
    final hasCnsData = widget.cnsCurve != null && widget.cnsCurve!.isNotEmpty;
    final hasOtuData = widget.otuCurve != null && widget.otuCurve!.isNotEmpty;

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
      hasPhotoMarkers:
          widget.photoMarkers != null && widget.photoMarkers!.isNotEmpty,
      hasMultiTankPressure: _hasMultiTankPressure,
      hasGasData:
          (widget.gasSegments?.isNotEmpty ?? false) &&
          (widget.diveDurationSeconds != null &&
              widget.diveDurationSeconds! > 0),
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
      hasCnsData: hasCnsData,
      hasOtuData: hasOtuData,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Left axis offset = axisNameSize + sideTitles reservedSize
        final legendLeftPadding =
            DiveProfileChart._leftRightAxisNameSize +
            DiveProfileChart.leftAxisSize(constraints.maxWidth);

        // The chart with gesture handling
        // Wrapped in RepaintBoundary for PNG export when exportKey is provided
        final plot = RepaintBoundary(
          key: widget.exportKey,
          child: _buildInteractiveChart(
            context,
            units,
            hasTemperatureData: hasTemperatureData,
            hasPressureData: hasPressureData,
            hasHeartRateData: hasHeartRateData,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart header with legend and zoom controls (decluttered)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.legendLeading != null) widget.legendLeading!,
                Expanded(
                  child: DiveProfileLegend(
                    config: legendConfig,
                    zoomLevel: _viewport.zoom,
                    minZoom: ProfileChartViewport.minZoom,
                    maxZoom: ProfileChartViewport.maxZoom,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    onResetZoom: _resetZoom,
                    leftPadding: widget.legendLeading == null
                        ? legendLeftPadding
                        : 0,
                  ),
                ),
              ],
            ),

            // Fill bounded parents (e.g. fullscreen); keep the 200px default
            // in unbounded contexts such as inline scroll views.
            if (constraints.hasBoundedHeight)
              Expanded(child: plot)
            else
              SizedBox(height: 200, child: plot),
            // Zoom hint
            if (_viewport.isZoomed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.l10n.diveLog_profile_zoomHint(
                    _viewport.zoom.toStringAsFixed(1),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      },
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
        // Trackpad two-finger scroll/pinch zoom, cursor-anchored. Driven by an
        // arena-winning recognizer so it does not also scroll an enclosing page
        // (the chart lives inside a SingleChildScrollView) and is not fought by
        // fl_chart's own recognizers.
        void zoomAt(Offset localPosition, double zoomDelta) {
          if (zoomDelta == 0) return;
          setState(() {
            _activePointerKind = PointerDeviceKind.trackpad;
            final box = constraints.biggest;
            final insets = _plotInsets(constraints.maxWidth, units);
            final focal = chartFocalFraction(
              localPosition,
              box,
              left: insets.left,
              right: insets.right,
              top: insets.top,
              bottom: insets.bottom,
            );
            _viewport = _viewport.zoomedAt(
              focal.fx,
              focal.fy,
              math.pow(2, zoomDelta).toDouble(),
            );
          });
        }

        return Semantics(
          label: context.l10n.diveLog_profile_semantics_chart,
          child: RawGestureDetector(
            gestures: {
              TrackpadZoomGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    TrackpadZoomGestureRecognizer
                  >(
                    () => TrackpadZoomGestureRecognizer(debugOwner: this),
                    (recognizer) => recognizer.onZoom = zoomAt,
                  ),
            },
            child: GestureDetector(
              onScaleStart: (details) {
                _gestureStartViewport = _viewport;
                _startFocalPoint = details.localFocalPoint;
              },
              onScaleUpdate: (details) {
                // Single-pointer drags are handled by Listener.onPointerMove
                // (mouse pan) and fl_chart's own recognizer (touch scrub); they
                // never reach onScaleUpdate, which only ever fires for a pinch.
                if (details.pointerCount < 2) return;

                // Trackpad pinch/scroll is handled by the
                // TrackpadZoomGestureRecognizer (reliable cursor anchor); touch
                // focal points are correct, so touch pinch is handled here.
                if (_activePointerKind != PointerDeviceKind.touch) return;

                setState(() {
                  final box = constraints.biggest;
                  final insets = _plotInsets(constraints.maxWidth, units);
                  final plotW = (box.width - insets.left - insets.right).clamp(
                    1.0,
                    double.infinity,
                  );
                  final plotH = (box.height - insets.top - insets.bottom).clamp(
                    1.0,
                    double.infinity,
                  );
                  final focal = chartFocalFraction(
                    _startFocalPoint,
                    box,
                    left: insets.left,
                    right: insets.right,
                    top: insets.top,
                    bottom: insets.bottom,
                  );
                  // scale is cumulative from gesture start -> apply to snapshot.
                  var vp = _gestureStartViewport.zoomedAt(
                    focal.fx,
                    focal.fy,
                    details.scale,
                  );
                  final panPx = details.localFocalPoint - _startFocalPoint;
                  vp = vp.pannedBy(
                    -panPx.dx / plotW / vp.zoom,
                    -panPx.dy / plotH / vp.zoom,
                  );
                  _viewport = vp;
                });
              },
              onDoubleTapDown: (details) {
                _lastTapDownLocal = details.localPosition;
                _doubleTapHold = true;
              },
              onDoubleTap: () {
                _doubleTapHold = false;
                setState(() {
                  if (_viewport.isZoomed) {
                    _viewport = ProfileChartViewport.reset;
                  } else {
                    final box = constraints.biggest;
                    final insets = _plotInsets(constraints.maxWidth, units);
                    final focal = chartFocalFraction(
                      _lastTapDownLocal,
                      box,
                      left: insets.left,
                      right: insets.right,
                      top: insets.top,
                      bottom: insets.bottom,
                    );
                    _viewport = _viewport.zoomedAt(focal.fx, focal.fy, 2.0);
                  }
                });
              },
              child: Listener(
                onPointerDown: (event) {
                  _activePointerCount++;
                  _activePointerKind = event.kind;
                  _lastPointerLocal = event.localPosition;
                },
                onPointerMove: (event) {
                  final prev = _lastPointerLocal;
                  _lastPointerLocal = event.localPosition;
                  if (prev == null) return;
                  final intent = chartDragIntent(
                    kind: _activePointerKind,
                    pointerCount: _activePointerCount,
                    doubleTapHold: _doubleTapHold,
                  );
                  if (intent != ChartDragIntent.pan) return;
                  setState(() {
                    final box = constraints.biggest;
                    final insets = _plotInsets(constraints.maxWidth, units);
                    final plotW = (box.width - insets.left - insets.right)
                        .clamp(1.0, double.infinity);
                    final plotH = (box.height - insets.top - insets.bottom)
                        .clamp(1.0, double.infinity);
                    final d = event.localPosition - prev;
                    _viewport = _viewport.pannedBy(
                      -d.dx / plotW / _viewport.zoom,
                      -d.dy / plotH / _viewport.zoom,
                    );
                  });
                },
                onPointerUp: (event) {
                  if (_activePointerCount > 0) _activePointerCount--;
                  _lastPointerLocal = null;
                  _doubleTapHold = false;
                },
                onPointerCancel: (event) {
                  if (_activePointerCount > 0) _activePointerCount--;
                  _lastPointerLocal = null;
                  _doubleTapHold = false;
                },
                // Trackpad two-finger scroll/pinch is handled by the
                // TrackpadZoomGestureRecognizer above (it wins the gesture arena so
                // it cannot also scroll the enclosing page).
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    setState(() {
                      final box = constraints.biggest;
                      final insets = _plotInsets(constraints.maxWidth, units);
                      final focal = chartFocalFraction(
                        event.localPosition,
                        box,
                        left: insets.left,
                        right: insets.right,
                        top: insets.top,
                        bottom: insets.bottom,
                      );
                      final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
                      _viewport = _viewport.zoomedAt(
                        focal.fx,
                        focal.fy,
                        factor,
                      );
                    });
                  }
                },
                onPointerHover: (event) {
                  _activePointerKind = PointerDeviceKind.mouse;
                  final idx = _hoverIndex(
                    event.localPosition,
                    constraints.biggest,
                    _plotInsets(constraints.maxWidth, units),
                  );
                  if (idx != _lastHoverIndex) {
                    _lastHoverIndex = idx;
                    widget.onPointSelected?.call(idx);
                  }
                },
                child: MouseRegion(
                  onExit: (_) {
                    if (_lastHoverIndex != null) {
                      _lastHoverIndex = null;
                      widget.onPointSelected?.call(null);
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
              ),
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
            ExcludeSemantics(
              child: Icon(
                Icons.show_chart,
                size: 48,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveLog_profile_emptyState,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether the integrated gas timeline strip should be rendered for the
  /// current dive. True iff segments and a positive dive duration were
  /// supplied AND the user has not hidden the strip via the chart options
  /// menu — keeps the chart self-contained and lets us cheaply branch in
  /// the layout code without nullable bookkeeping at every call site.
  bool _gasStripVisible(bool showGas) =>
      (widget.gasSegments?.isNotEmpty ?? false) &&
      (widget.diveDurationSeconds != null && widget.diveDurationSeconds! > 0) &&
      showGas;

  // ref.watch is correct here: _hasGasStrip is only read from build().
  // Gesture paths must use _gasStripVisible with ref.read (see _plotInsets).
  bool get _hasGasStrip => _gasStripVisible(
    ref.watch(profileLegendProvider.select((s) => s.showGas)),
  );

  Widget _buildChart(
    BuildContext context,
    UnitFormatter units, {
    required double availableWidth,
    required bool hasTemperatureData,
    required bool hasPressureData,
    required bool hasHeartRateData,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final sacUnit = ref.read(sacUnitProvider);
    const heartRateColor = Colors.red;

    // Calculate full data bounds (all values stored in meters, convert for
    // display). Overlaid sources widen the extents so a deeper or longer
    // overlay trace is never clipped.
    final overlayPoints = (widget.overlays ?? const <ChartSourceOverlay>[])
        .expand((o) => o.points);
    final totalMaxTime = [
      widget.profile.map((p) => p.timestamp).reduce(math.max),
      ...overlayPoints.map((p) => p.timestamp),
    ].reduce(math.max).toDouble();
    final maxDepthValueMeters = [
      widget.profile.map((p) => p.depth).reduce(math.max),
      ...overlayPoints.map((p) => p.depth),
    ].reduce(math.max);
    // Convert to user's preferred depth unit for chart calculations
    final maxDepthValueDisplay = units.convertDepth(
      widget.maxDepth ?? maxDepthValueMeters,
    );
    final totalMaxDepth = maxDepthValueDisplay * 1.1; // Add 10% padding

    // Apply zoom and pan to calculate visible bounds (see ProfileChartViewport).
    final visibleRangeX = totalMaxTime * _viewport.visibleWidth;
    final visibleRangeY = totalMaxDepth * _viewport.visibleHeight;

    final visibleMinX = _viewport.offsetX * totalMaxTime;
    final visibleMaxX = visibleMinX + visibleRangeX;

    final visibleMinDepth = _viewport.offsetY * totalMaxDepth;
    final visibleMaxDepth = visibleMinDepth + visibleRangeY;

    // Temperature bounds (if showing) - convert to user's preferred unit.
    // Pool the active source's and every overlaid source's readings so both
    // curves share one temperature scale and the axis range doesn't jump as
    // overlays are toggled.
    double? minTemp, maxTemp;
    if (_showTemperature && hasTemperatureData) {
      final tempSource = widget.profile.followedBy(
        (widget.overlays ?? const <ChartSourceOverlay>[]).expand(
          (o) => o.points,
        ),
      );
      final temps = tempSource
          .where((p) => p.temperature != null)
          .map((p) => units.convertTemperature(p.temperature!));
      if (temps.isNotEmpty) {
        minTemp = temps.reduce(math.min) - 1;
        maxTemp = temps.reduce(math.max) + 1;
      }
    }

    // Determine effective right axis metric using settings default and fallback chain.
    // getEffectiveRightAxisMetric() returns null when the user chose "None".
    final legendNotifier = ref.read(profileLegendProvider.notifier);
    final preferredMetric = legendNotifier.getEffectiveRightAxisMetric();
    final effectiveRightAxisMetric = preferredMetric != null
        ? _getEffectiveRightAxisMetric(preferredMetric)
        : null;
    final rightAxisRange = effectiveRightAxisMetric != null
        ? _getMetricRange(effectiveRightAxisMetric, units)
        : null;

    // Pressure bounds from multi-tank pressure data
    double? minPressure, maxPressure;
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
                  context.l10n.diveLog_profile_axisDepth(units.depthSymbol),
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: DiveProfileChart.leftAxisSize(availableWidth),
                  interval: _calculateDepthInterval(visibleRangeY),
                  getTitlesWidget: (value, meta) {
                    // Suppress interval ticks too close to the min boundary
                    // (min is the most-negative value = deepest depth).
                    final interval = _calculateDepthInterval(visibleRangeY);
                    final distToMin = (value - meta.min).abs();
                    if (distToMin > 0 && distToMin < interval * 0.4) {
                      return const SizedBox.shrink();
                    }
                    // Show positive depth values (negate the negative axis values)
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        '${(-value).toInt()}',
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: Text(
                  context.l10n.diveLog_profile_axisTime,
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                axisNameSize: DiveProfileChart._bottomAxisNameSize,
                sideTitles: SideTitles(
                  showTitles: true,
                  // When the gas strip is rendered, reserve extra room and
                  // push the tick labels down by the strip's height so the
                  // strip can be Positioned in the resulting gap, directly
                  // between the plot area and the time labels.
                  reservedSize: _hasGasStrip
                      ? DiveProfileChart._bottomTickReservedSize +
                            DiveProfileChart.gasTimelineHeight
                      : DiveProfileChart._bottomTickReservedSize,
                  interval: _calculateTimeInterval(visibleRangeX),
                  getTitlesWidget: (value, meta) {
                    // Suppress interval ticks that are too close to the max
                    // boundary to prevent overlapping labels.
                    final interval = _calculateTimeInterval(visibleRangeX);
                    final distToMax = (meta.max - value).abs();
                    if (distToMax > 0 && distToMax < interval * 0.4) {
                      return const SizedBox.shrink();
                    }
                    final minutes = (value / 60).round();
                    return SideTitleWidget(
                      meta: meta,
                      space: _hasGasStrip
                          ? 8 + DiveProfileChart.gasTimelineHeight
                          : 8,
                      child: Text(
                        '$minutes',
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                      ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    // Suppress interval ticks too close to the min boundary
                    final interval = _calculateDepthInterval(visibleRangeY);
                    final distToMin = (value - meta.min).abs();
                    if (distToMin > 0 && distToMin < interval * 0.4) {
                      return const SizedBox.shrink();
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
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        _formatRightAxisValue(
                          effectiveRightAxisMetric,
                          metricValue,
                          units,
                        ),
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: metricColor),
                        maxLines: 1,
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
            lineBarsData: _barsCache.series(
              'main',
              () => [
                // Depth line segments (colored by active gas if gas switches exist)
                ..._buildGasColoredDepthLines(colorScheme, units),

                // Gas switch markers (if showing and data available)
                if (_showGasSwitchMarkers) ..._buildGasSwitchMarkers(units),

                // Temperature line(s) (if showing) — one per visible computer
                // when multi-computer profiles are present, else a single
                // curve from the primary profile.
                if (_showTemperature &&
                    hasTemperatureData &&
                    minTemp != null &&
                    maxTemp != null)
                  ..._buildTemperatureLines(
                    colorScheme,
                    totalMaxDepth,
                    minTemp,
                    maxTemp,
                    units,
                  ),

                // Multi-tank pressure lines (per-tank visibility controlled
                // inside _buildMultiTankPressureLines via _showTankPressure)
                if (_hasMultiTankPressure)
                  ..._buildMultiTankPressureLines(totalMaxDepth),

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

                // Ascent-rate magnitude line (separate overlay; signed m/min)
                if (_showAscentRateLine && widget.ascentRates != null)
                  _buildAscentRateLine(totalMaxDepth),

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

                // CNS% curve (if showing)
                if (_showCns && widget.cnsCurve != null)
                  _buildCnsLine(totalMaxDepth),

                // OTU curve (if showing)
                if (_showOtu && widget.otuCurve != null)
                  _buildOtuLine(totalMaxDepth),

                // Profile markers (max depth, pressure thresholds)
                ..._buildMarkerLines(
                  units,
                  totalMaxDepth,
                  minPressure: minPressure,
                  maxPressure: maxPressure,
                ),

                // Overlaid comparison sources — LAST, so depth bars keep
                // occupying the leading barIndex range (see _depthBarCount).
                ..._buildOverlayLines(units, totalMaxDepth, minTemp, maxTemp),
              ],
            ),
            extraLinesData: ExtraLinesData(
              verticalLines: [
                ..._buildPlaybackCursor(colorScheme),
                ..._buildHighlightCursor(colorScheme),
                if (_showEvents && widget.events != null)
                  ..._buildEventVerticalLines(colorScheme),
              ],
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchSpotThreshold: 20,
              handleBuiltInTouches: true,
              getTouchedSpotIndicator: (barData, spotIndexes) {
                final suppressed = _suppressedDepthIndicatorSpots;
                if (suppressed.isEmpty) {
                  return defaultTouchedIndicators(barData, spotIndexes);
                }
                // Hide the built-in focus dot on the extra velocity bands so a
                // single depth dot remains; every other line keeps its default
                // indicator. See [velocityIndicatorSuppression].
                return [
                  for (final index in spotIndexes)
                    if (_isSuppressedIndicatorSpot(barData, index, suppressed))
                      null
                    else
                      defaultTouchedIndicators(barData, [index]).first,
                ];
              },
              touchCallback: (event, response) {
                final isTouchEnd =
                    event is FlPointerExitEvent ||
                    event is FlLongPressEnd ||
                    event is FlTapUpEvent ||
                    event is FlPanEndEvent;
                final spots =
                    response?.lineBarSpots ?? const <TouchLineBarSpot>[];
                final active = !isTouchEnd && spots.isNotEmpty;
                // Depth-line bar layout: a single bar normally, one per velocity
                // band when the ascent-rate overlay splits the line. Shared by
                // the indicator-suppression list and the spot -> global-index
                // mapping below.
                final starts = active
                    ? _depthBarStartIndices()
                    : const <int>[0];

                // Collapse velocity colouring's per-band focus dots to a single
                // depth dot, independently of the external selection/tooltip
                // callbacks below (so the built-in indicator is de-cluttered
                // even when neither callback is wired).
                _suppressedDepthIndicatorSpots = active
                    ? DiveProfileChart.velocityIndicatorSuppression([
                        for (final s in spots)
                          (barIndex: s.barIndex, x: s.x, y: s.y),
                      ], starts.length)
                    : const [];

                if (widget.onPointSelected != null ||
                    widget.onTooltipData != null) {
                  if (isTouchEnd) {
                    widget.onPointSelected?.call(null);
                    if (widget.tooltipBelow) {
                      widget.onTooltipData?.call(null);
                    }
                  } else if (active) {
                    // The depth line can be split into multiple bars (per
                    // velocity band); find the touched depth spot on any of
                    // them and map it back to the global profile index.
                    final depthBarCount = starts.length;
                    final depthSpot = spots
                        .where((s) => s.barIndex < depthBarCount)
                        .firstOrNull;
                    final index = depthSpot == null
                        ? -1
                        : DiveProfileChart.depthSpotProfileIndex(
                            profile: widget.profile,
                            depthBarStarts: starts,
                            barIndex: depthSpot.barIndex,
                            spotIndex: depthSpot.spotIndex,
                            spotX: depthSpot.x,
                            multiComputer: false,
                          );
                    if (depthSpot != null &&
                        index >= 0 &&
                        index < widget.profile.length) {
                      widget.onPointSelected?.call(index);
                      if (widget.tooltipBelow) {
                        final settings = ref.read(settingsProvider);
                        final units = UnitFormatter(settings);
                        _emitExternalTooltip(
                          spots,
                          units,
                          Theme.of(context).colorScheme,
                        );
                      }
                    }
                  }
                }
              },
              touchTooltipData: LineTouchTooltipData(
                // Wide enough for a tank row carrying the gas type, e.g.
                // "Tank 1 (EAN32) 2064 psi", without wrapping. Narrower
                // tooltips still size to their content (this is only a cap).
                maxContentWidth: 320,
                fitInsideHorizontally: true,
                fitInsideVertically: false,
                showOnTopOfTheChartBoxArea: true,
                tooltipMargin: 0,
                getTooltipColor: widget.tooltipBelow
                    ? (_) => Colors.transparent
                    : (spot) => colorScheme.inverseSurface,
                getTooltipItems: (touchedSpots) {
                  // When tooltipBelow, suppress the visual bubble.
                  // Tooltip data is emitted via touchCallback instead.
                  if (widget.tooltipBelow) {
                    return touchedSpots.map((_) => null).toList();
                  }
                  // Resolve the touched depth spot to a global profile index.
                  // Velocity colouring splits the depth line into per-band bars,
                  // so the depth spot can land on any bar in [0, starts.length)
                  // and its spotIndex is local to that bar.
                  final depthBarStarts = _depthBarStartIndices();
                  final depthBarCount = depthBarStarts.length;
                  final depthSpot = touchedSpots
                      .where((s) => s.barIndex < depthBarCount)
                      .firstOrNull;
                  final depthIndex = depthSpot == null
                      ? -1
                      : DiveProfileChart.depthSpotProfileIndex(
                          profile: widget.profile,
                          depthBarStarts: depthBarStarts,
                          barIndex: depthSpot.barIndex,
                          spotIndex: depthSpot.spotIndex,
                          spotX: depthSpot.x,
                          multiComputer: false,
                        );
                  final hasDepth =
                      depthSpot != null &&
                      depthIndex >= 0 &&
                      depthIndex < widget.profile.length;

                  // Return cached result if the same sample is touched again.
                  // The cache is keyed on the resolved depth index, but the
                  // cached list length equals the number of touched bars when it
                  // was built. fl_chart requires the returned list to match
                  // touchedSpots.length, so the cache is only valid while the bar
                  // count is unchanged -- the set of rendered lines can change
                  // under a parked cursor (a metric toggled, or a data provider
                  // refreshing), and a stale-length cached list throws
                  // 'tooltipItems and touchedSpots size should be same'.
                  if (hasDepth &&
                      depthIndex == _lastTooltipSpotIndex &&
                      _lastTooltipItems.length == touchedSpots.length) {
                    return _lastTooltipItems;
                  }

                  // Build the combined tooltip from the resolved depth spot; all
                  // other touched bars contribute a null entry so the returned
                  // list still matches touchedSpots.length. `spot` is shadowed
                  // with the global index so every metric row reads the right
                  // sample.
                  final result = touchedSpots.map((touched) {
                    if (!hasDepth || !identical(touched, depthSpot)) {
                      return null;
                    }
                    final spot = (spotIndex: depthIndex);

                    final point = widget.profile[spot.spotIndex];
                    final minutes = point.timestamp ~/ 60;
                    final seconds = point.timestamp % 60;

                    // Build tooltip with all enabled metrics
                    // Text style constants for consistent column layout
                    final onSurface = colorScheme.onInverseSurface;
                    final rowStyle = TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 14,
                      color: onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    );

                    // fl_chart tooltips are a single TextSpan tree, so columns
                    // are aligned with monospace padding rather than layout
                    // widgets. A fixed label column keeps the common rows
                    // compact and within the tooltip's max content width; a
                    // long label (e.g. "Tank 1 (EAN32)") overflows its own row
                    // instead of widening every row.
                    const labelWidth = 8;
                    const valueWidth = 16;

                    final tooltipRows =
                        <
                          ({
                            String label,
                            String value,
                            Color bulletColor,
                            String bullet,
                            double bulletSize,
                          })
                        >[];

                    void addRow(
                      String label,
                      String value,
                      Color bulletColor, {
                      String bullet = '●',
                      double bulletSize = 12,
                    }) {
                      tooltipRows.add((
                        label: label,
                        value: value,
                        bulletColor: bulletColor,
                        bullet: bullet,
                        bulletSize: bulletSize,
                      ));
                    }

                    // Time (always shown)
                    final timeValue =
                        '$minutes:${seconds.toString().padLeft(2, '0')}';
                    addRow(
                      context.l10n.diveLog_tooltip_time,
                      timeValue,
                      onSurface.withValues(alpha: 0.5),
                    );

                    // Depth (always shown) - use same color as depth line
                    addRow(
                      context.l10n.diveLog_tooltip_depth,
                      units.formatDepth(point.depth),
                      AppColors.chartDepth,
                    );

                    // Overlaid sources' depth at this time, labeled with
                    // the metric so the value is unambiguous.
                    for (final overlay
                        in widget.overlays ?? const <ChartSourceOverlay>[]) {
                      final overlayPoint = _overlayPointAt(
                        overlay,
                        point.timestamp,
                      );
                      if (overlayPoint == null) continue;
                      addRow(
                        '${context.l10n.diveLog_tooltip_depth}'
                        ' · ${overlay.name}',
                        units.formatDepth(overlayPoint.depth),
                        overlay.color,
                      );
                    }

                    // Temperature (if enabled - always show row)
                    if (_showTemperature) {
                      final tempValue = point.temperature != null
                          ? units.formatTemperature(point.temperature)
                          : '—';
                      addRow(
                        context.l10n.diveLog_tooltip_temp,
                        tempValue,
                        colorScheme.tertiary,
                      );
                      for (final overlay
                          in widget.overlays ?? const <ChartSourceOverlay>[]) {
                        final overlayTemp = _overlayPointAt(
                          overlay,
                          point.timestamp,
                        )?.temperature;
                        if (overlayTemp == null) continue;
                        addRow(
                          '${context.l10n.diveLog_tooltip_temp}'
                          ' · ${overlay.name}',
                          units.formatTemperature(overlayTemp),
                          overlay.color.withValues(alpha: 0.6),
                        );
                      }
                    }

                    // Heart rate (if enabled - always show row)
                    if (_showHeartRate) {
                      final hrValue = point.heartRate != null
                          ? '${point.heartRate} bpm'
                          : '—';
                      addRow(
                        context.l10n.diveLog_tooltip_hr,
                        hrValue,
                        Colors.red,
                      );
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
                      addRow(
                        context.l10n.diveLog_tooltip_sac,
                        sacValue,
                        Colors.teal,
                      );
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
                        context.l10n.diveLog_tooltip_ceiling,
                        ceilingValue,
                        const Color(0xFFD32F2F),
                      );
                    }

                    // Ascent rate (if enabled - always show row with fixed format)
                    // Uses distinct colors that don't conflict with gas colors:
                    // - Descent: cyan (distinct from air blue)
                    // - Safe ascent: lime green (distinct from nitrox green)
                    // - Warning/danger: orange/red (already distinct)
                    if (_showAscentRateColors || _showAscentRateLine) {
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
                      addRow(
                        context.l10n.diveLog_tooltip_rate,
                        rateValue,
                        rateColor,
                      );
                    }

                    // NDL (if enabled)
                    if (_showNdl) {
                      String ndlValue = '—';
                      if (widget.ndlCurve != null &&
                          spot.spotIndex < widget.ndlCurve!.length) {
                        final ndl = widget.ndlCurve![spot.spotIndex];
                        if (ndl < 0) {
                          ndlValue = context.l10n.diveLog_playbackStats_deco;
                        } else if (ndl < 3600) {
                          final min = ndl ~/ 60;
                          final sec = ndl % 60;
                          ndlValue = '$min:${sec.toString().padLeft(2, '0')}';
                        } else {
                          ndlValue = '>60 min';
                        }
                      }
                      addRow(
                        context.l10n.diveLog_tooltip_ndl,
                        ndlValue,
                        Colors.yellow.shade700,
                      );
                    }

                    // ppO2 (computer value or O2 cell average) plus each sensor
                    if (_showPpO2) {
                      String ppO2Value = '—';
                      if (widget.ppO2Curve != null &&
                          spot.spotIndex < widget.ppO2Curve!.length) {
                        final ppO2 = widget.ppO2Curve![spot.spotIndex];
                        ppO2Value = '${ppO2.toStringAsFixed(2)} bar';
                      }
                      addRow(
                        widget.ppO2FromSensorAverage
                            ? '${context.l10n.diveLog_tooltip_ppO2} ${context.l10n.diveLog_tooltip_avgCalculated}'
                            : context.l10n.diveLog_tooltip_ppO2,
                        ppO2Value,
                        const Color(0xFF00ACC1),
                      );
                      final sensorCurves = widget.o2SensorCurves;
                      if (sensorCurves != null) {
                        for (var cell = 0; cell < sensorCurves.length; cell++) {
                          final readings = sensorCurves[cell];
                          if (spot.spotIndex >= readings.length) continue;
                          final reading = readings[spot.spotIndex];
                          if (reading == null) continue;
                          addRow(
                            '${context.l10n.diveLog_tooltip_sensor} ${cell + 1}',
                            '${reading.toStringAsFixed(2)} bar',
                            const Color(0xFF80DEEA),
                          );
                        }
                      }
                    }

                    // ppN2 (if enabled)
                    if (_showPpN2) {
                      String ppN2Value = '—';
                      if (widget.ppN2Curve != null &&
                          spot.spotIndex < widget.ppN2Curve!.length) {
                        final ppN2 = widget.ppN2Curve![spot.spotIndex];
                        ppN2Value = '${ppN2.toStringAsFixed(2)} bar';
                      }
                      addRow(
                        context.l10n.diveLog_tooltip_ppN2,
                        ppN2Value,
                        Colors.indigo,
                      );
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
                      addRow(
                        context.l10n.diveLog_tooltip_ppHe,
                        ppHeValue,
                        Colors.pink.shade300,
                      );
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
                      addRow(
                        context.l10n.diveLog_tooltip_mod,
                        modValue,
                        Colors.deepOrange,
                      );
                    }

                    // Gas density (if enabled)
                    if (_showDensity) {
                      String densityValue = '—';
                      if (widget.densityCurve != null &&
                          spot.spotIndex < widget.densityCurve!.length) {
                        final density = widget.densityCurve![spot.spotIndex];
                        densityValue = '${density.toStringAsFixed(2)} g/L';
                      }
                      addRow(
                        context.l10n.diveLog_tooltip_density,
                        densityValue,
                        Colors.brown,
                      );
                    }

                    // GF% (if enabled)
                    if (_showGf) {
                      String gfValue = '—';
                      if (widget.gfCurve != null &&
                          spot.spotIndex < widget.gfCurve!.length) {
                        final gf = widget.gfCurve![spot.spotIndex];
                        gfValue = '${gf.toStringAsFixed(0)}%';
                      }
                      addRow(
                        context.l10n.diveLog_tooltip_gfPercent,
                        gfValue,
                        Colors.deepPurple,
                      );
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
                      addRow(
                        context.l10n.diveLog_tooltip_srfGf,
                        surfaceGfValue,
                        Colors.purple.shade300,
                      );
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
                      addRow(
                        context.l10n.diveLog_tooltip_mean,
                        meanDepthValue,
                        Colors.blueGrey,
                      );
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
                      addRow(
                        context.l10n.diveLog_tooltip_tts,
                        ttsValue,
                        const Color(0xFFAD1457),
                      );
                    }

                    // CNS% (if enabled)
                    if (_showCns) {
                      String cnsValue = '\u2014';
                      if (widget.cnsCurve != null &&
                          spot.spotIndex < widget.cnsCurve!.length) {
                        final cns = widget.cnsCurve![spot.spotIndex];
                        cnsValue = '${cns.toStringAsFixed(1)}%';
                      }
                      addRow(
                        context.l10n.diveLog_tooltip_cns,
                        cnsValue,
                        const Color(0xFFE65100),
                      );
                    }

                    // OTU (if enabled)
                    if (_showOtu) {
                      String otuValue = '\u2014';
                      if (widget.otuCurve != null &&
                          spot.spotIndex < widget.otuCurve!.length) {
                        final otu = widget.otuCurve![spot.spotIndex];
                        otuValue = otu.toStringAsFixed(0);
                      }
                      addRow(
                        context.l10n.diveLog_tooltip_otu,
                        otuValue,
                        const Color(0xFF6D4C41),
                      );
                    }

                    // Per-tank pressure (if any tanks are enabled)
                    if (widget.tankPressures != null) {
                      final timestamp = point.timestamp;
                      final sortedTankIds = _sortedTankIds(
                        widget.tankPressures!.keys,
                      );
                      final tankComputerIds = _tankComputerIds();
                      final contributingComputerIds =
                          _contributingTankComputerIds(
                            sortedTankIds,
                            tankComputerIds,
                          );

                      for (var i = 0; i < sortedTankIds.length; i++) {
                        final tankId = sortedTankIds[i];
                        if (!(_showTankPressure[tankId] ?? true)) continue;
                        if (!_isComputerVisible(tankComputerIds[tankId])) {
                          continue;
                        }

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
                        final tankLabel =
                            DiveProfileChart.tankTooltipLabel(
                              tank,
                              context.l10n.diveLog_tank_title(i + 1),
                            ) +
                            _tankSourceSuffix(
                              tankId,
                              tankComputerIds,
                              contributingComputerIds,
                            );
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
                            context.l10n.diveLog_tooltip_marker,
                            marker.chartLabel,
                            markerColor,
                            bullet: '◆',
                            bulletSize: 10,
                          );
                        }
                      }
                    }

                    const rowWidth = labelWidth + valueWidth;
                    final rowFiller = List.filled(rowWidth, '0').join();
                    final lines = <TextSpan>[];
                    for (final row in tooltipRows) {
                      if (lines.isNotEmpty) {
                        lines.add(const TextSpan(text: '\n'));
                      }
                      lines.add(
                        TextSpan(
                          text: '${row.bullet} ',
                          style: TextStyle(
                            color: row.bulletColor,
                            fontSize: row.bulletSize,
                          ),
                        ),
                      );
                      final rowText = DiveProfileChart.tooltipRowText(
                        row.label,
                        row.value,
                        labelWidth,
                        valueWidth,
                      );
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

                    return LineTooltipItem(
                      '', // Empty base text, using children instead
                      TextStyle(color: onSurface),
                      children: lines,
                      textAlign: TextAlign.start,
                    );
                  }).toList();

                  // Cache the result for next frame, keyed on the resolved
                  // global depth index (see the resolution above).
                  if (hasDepth) {
                    _lastTooltipSpotIndex = depthIndex;
                    _lastTooltipItems = result;
                  }

                  return result;
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
            child: Semantics(
              button: true,
              label: context.l10n.diveLog_profile_semantics_changeRightAxis,
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
          ),
        // Gas-usage timeline strip rendered between the plot area and the
        // X-axis tick labels. Sized to exactly the chart's plot width by
        // mirroring the chart's left/right axis reservations, and offset
        // from the bottom so it lands in the gap reserved above by
        // `_hasGasStrip` (_bottomAxisNameSize + _bottomTickReservedSize).
        //
        // Plot bounds = _leftRightAxisNameSize + sideTitles reservedSize
        // on each side that has an axisNameWidget. Left axis always renders
        // its name; the right axis only does so when a metric is selected.
        if (_hasGasStrip)
          Positioned(
            left:
                DiveProfileChart._leftRightAxisNameSize +
                DiveProfileChart.leftAxisSize(availableWidth),
            right:
                (effectiveRightAxisMetric != null && rightAxisRange != null
                    ? DiveProfileChart._leftRightAxisNameSize
                    : 0) +
                DiveProfileChart.rightAxisSize(availableWidth),
            bottom:
                DiveProfileChart._bottomAxisNameSize +
                DiveProfileChart._bottomTickReservedSize,
            height: DiveProfileChart.gasTimelineHeight,
            child: GasTimelineStrip(
              segments: widget.gasSegments!,
              diveDurationSeconds: widget.diveDurationSeconds!,
              height: DiveProfileChart.gasTimelineHeight,
              leftPadding: 0,
              rightPadding: 0,
              visibleMinSeconds: visibleMinX,
              visibleMaxSeconds: visibleMaxX,
            ),
          ),
        // Extension of the hover/playback cursor line into the gas strip.
        // fl_chart's vertical lines are clipped to the plot area, so the
        // strip would otherwise miss the cursor; we draw a 1-px line at
        // the same horizontal position to bridge the gap visually.
        if (_hasGasStrip)
          ..._buildGasStripCursorExtensions(
            availableWidth: availableWidth,
            visibleMinX: visibleMinX,
            visibleMaxX: visibleMaxX,
            hasRightAxisName:
                effectiveRightAxisMetric != null && rightAxisRange != null,
          ),
        // Photo markers: tappable camera chips at each photo's (time, depth).
        // A widget layer (not an fl_chart element) so its taps never enter
        // the chart's gesture arena; insets mirror the plot-rect math used
        // by the gas strip above.
        if (_showPhotoMarkers &&
            widget.photoMarkers != null &&
            widget.photoMarkers!.isNotEmpty)
          Positioned.fill(
            child: PhotoMarkerOverlay(
              markers: widget.photoMarkers!,
              visibleMinSeconds: visibleMinX,
              visibleMaxSeconds: visibleMaxX,
              visibleMinDepth: visibleMinDepth,
              visibleMaxDepth: visibleMaxDepth,
              insets: _plotInsets(availableWidth, units),
              units: units,
            ),
          ),
      ],
    );
  }

  /// Builds vertical line extensions over the gas timeline strip for any
  /// active cursors (hover highlight + step-through playback) so the line
  /// visually continues past the chart's plot area.
  List<Widget> _buildGasStripCursorExtensions({
    required double availableWidth,
    required double visibleMinX,
    required double visibleMaxX,
    required bool hasRightAxisName,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final cursors = <(int timestamp, Color color, double width)>[
      if (widget.highlightedTimestamp != null)
        (
          widget.highlightedTimestamp!,
          colorScheme.onSurface.withValues(alpha: 0.5),
          1.0,
        ),
      if (widget.playbackTimestamp != null)
        (widget.playbackTimestamp!, colorScheme.primary, 2.0),
    ];
    if (cursors.isEmpty) return const [];

    final left =
        DiveProfileChart._leftRightAxisNameSize +
        DiveProfileChart.leftAxisSize(availableWidth);
    final right =
        (hasRightAxisName ? DiveProfileChart._leftRightAxisNameSize : 0) +
        DiveProfileChart.rightAxisSize(availableWidth);
    final stripWidth = (availableWidth - left - right).clamp(
      0.0,
      double.infinity,
    );
    final visibleRangeX = visibleMaxX - visibleMinX;
    if (visibleRangeX <= 0 || stripWidth <= 0) return const [];

    return [
      for (final (timestamp, color, width) in cursors)
        if (timestamp >= visibleMinX && timestamp <= visibleMaxX)
          Positioned(
            left:
                left +
                ((timestamp - visibleMinX) / visibleRangeX) * stripWidth -
                width / 2,
            bottom:
                DiveProfileChart._bottomAxisNameSize +
                DiveProfileChart._bottomTickReservedSize,
            height: DiveProfileChart.gasTimelineHeight,
            width: width,
            child: IgnorePointer(child: ColoredBox(color: color)),
          ),
    ];
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

    // Add "None" option to hide the axis.
    // Use onTap instead of relying on the menu return value, because
    // showMenu returns null both for "None" (value: null) and for
    // dismissing the menu — we can't distinguish them otherwise.
    menuItems.add(
      PopupMenuItem<ProfileRightAxisMetric?>(
        value: null,
        onTap: () => legendNotifier.hideRightAxis(),
        child: Row(
          children: [
            Icon(
              Icons.visibility_off,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(context.l10n.diveLog_profile_rightAxis_none),
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
      // "None" is handled via onTap on its PopupMenuItem.
      // Here we only handle actual metric selections (non-null).
      if (selectedMetric != null) {
        legendNotifier.setRightAxisMetric(selectedMetric);
      }
    });
  }

  /// Build depth line segments for the active source ([widget.profile]).
  List<LineChartBarData> _buildGasColoredDepthLines(
    ColorScheme colorScheme,
    UnitFormatter units,
  ) {
    // When the ascent-rate overlay is on, colour the depth line by velocity
    // band; otherwise draw a single solid depth-coloured segment.
    final ascentRates = widget.ascentRates;
    if (_showAscentRateColors &&
        ascentRates != null &&
        ascentRates.length == widget.profile.length &&
        widget.profile.length >= 2) {
      return _buildVelocityColoredDepthLines(units, ascentRates);
    }
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

  /// Build depth-line segments coloured by ascent-rate band ("velocity
  /// coloring", green/orange/red).
  ///
  /// Each line segment between samples i-1 and i is coloured by the velocity
  /// recorded at point i ([AscentRateCalculator] stores the rate for the
  /// segment that *ends* at i; index 0 is a zero placeholder). Consecutive
  /// same-band segments are merged into one polyline, so every bar spans at
  /// least two points (the final sample never collapses to a 1-point dot) and
  /// every run keeps the gradient fill so the plot reads as a continuous depth
  /// area.
  List<LineChartBarData> _buildVelocityColoredDepthLines(
    UnitFormatter units,
    List<AscentRatePoint> ascentRates,
  ) {
    // One coloured bar per band. [DiveProfileChart.velocityBandRuns] is the
    // shared source of truth so the tooltip's spot-to-sample mapping and this
    // rendering never disagree on where a segment starts.
    return DiveProfileChart.velocityBandRuns(widget.profile.length, ascentRates)
        .map(
          (run) => _buildSingleDepthSegment(
            _velocityDepthColor(run.category),
            units,
            run.start,
            run.end,
            showFill: true,
          ),
        )
        .toList();
  }

  /// Global profile start index of each depth-line bar, in bar order.
  ///
  /// Depth bars always occupy `barIndex` `[0, length)`. A touched spot on bar
  /// `b` at local `spotIndex` addresses profile point `result[b] + spotIndex`.
  /// The depth line is a single full-span bar in the common case; velocity
  /// colouring splits it into one bar per band. Mirrors the branching in
  /// [_buildGasColoredDepthLines].
  List<int> _depthBarStartIndices() {
    final ascentRates = widget.ascentRates;
    if (_showAscentRateColors &&
        ascentRates != null &&
        ascentRates.length == widget.profile.length &&
        widget.profile.length >= 2) {
      return DiveProfileChart.velocityBandRuns(
        widget.profile.length,
        ascentRates,
      ).map((run) => run.start).toList();
    }
    return const [0];
  }

  /// Whether the built-in focus indicator for [barData]'s spot at [index]
  /// should be hidden because velocity colouring already shows the depth dot on
  /// another band (see [velocityIndicatorSuppression]). Matches on the spot
  /// coordinate because fl_chart hands the indicator callback a copied bar
  /// without its position in the bar list.
  bool _isSuppressedIndicatorSpot(
    LineChartBarData barData,
    int index,
    List<({double x, double y})> suppressed,
  ) {
    if (index < 0 || index >= barData.spots.length) return false;
    final spot = barData.spots[index];
    const epsilon = 1e-6;
    for (final s in suppressed) {
      if ((s.x - spot.x).abs() < epsilon && (s.y - spot.y).abs() < epsilon) {
        return true;
      }
    }
    return false;
  }

  /// Build every overlaid source's lines: dashed depth, dimmed temperature
  /// (when the temperature metric is enabled), and computer-reported
  /// ceiling/NDL (when those metrics are enabled), all in the overlay's
  /// color. Appended AFTER every other bar so the depth-bar indexing
  /// contract (depth bars occupy `barIndex` `[0, _depthBarCount())`) stays
  /// valid for the tooltip's spot-to-sample mapping.
  List<LineChartBarData> _buildOverlayLines(
    UnitFormatter units,
    double chartMaxDepth,
    double? minTemp,
    double? maxTemp,
  ) {
    final overlays = widget.overlays;
    if (overlays == null || overlays.isEmpty) return const [];

    final lines = <LineChartBarData>[];
    for (final overlay in overlays) {
      if (overlay.points.isEmpty) continue;

      // Depth: dashed, no fill.
      lines.add(
        LineChartBarData(
          spots: [
            for (final p in overlay.points)
              FlSpot(p.timestamp.toDouble(), -units.convertDepth(p.depth)),
          ],
          isCurved: true,
          curveSmoothness: 0.2,
          color: overlay.color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: const [6, 4],
          belowBarData: BarAreaData(show: false),
        ),
      );

      // Temperature: dimmed dashed, on the shared temperature scale.
      if (_showTemperature && minTemp != null && maxTemp != null) {
        final tempPoints = overlay.points
            .where((p) => p.temperature != null)
            .toList();
        if (tempPoints.isNotEmpty) {
          lines.add(
            LineChartBarData(
              spots: [
                for (final p in tempPoints)
                  FlSpot(
                    p.timestamp.toDouble(),
                    -_mapTempToDepth(
                      units.convertTemperature(p.temperature!),
                      chartMaxDepth,
                      minTemp,
                      maxTemp,
                    ),
                  ),
              ],
              isCurved: true,
              curveSmoothness: 0.2,
              color: overlay.color.withValues(alpha: 0.6),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: const [5, 3],
            ),
          );
        }
      }

      // Computer-reported ceiling, mapped like the active ceiling line.
      if (_showCeiling) {
        final ceilingSpots = [
          for (final p in overlay.points)
            if (p.ceiling != null && p.ceiling! > 0)
              FlSpot(p.timestamp.toDouble(), -units.convertDepth(p.ceiling!)),
        ];
        if (ceilingSpots.isNotEmpty) {
          lines.add(
            LineChartBarData(
              spots: ceilingSpots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: overlay.color.withValues(alpha: 0.45),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: const [4, 4],
            ),
          );
        }
      }

      // Computer-reported NDL, on the same normalized scale as the active
      // NDL line (see _buildNdlLine).
      if (_showNdl) {
        const maxNdlSeconds = 3600.0;
        final ndlSpots = <FlSpot>[];
        for (final p in overlay.points) {
          final ndl = p.ndl;
          if (ndl == null) continue;
          final clamped = ndl.clamp(0, maxNdlSeconds.toInt()).toDouble();
          ndlSpots.add(
            FlSpot(
              p.timestamp.toDouble(),
              -(chartMaxDepth * (1 - clamped / maxNdlSeconds)),
            ),
          );
        }
        if (ndlSpots.isNotEmpty) {
          lines.add(
            LineChartBarData(
              spots: ndlSpots,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: overlay.color.withValues(alpha: 0.45),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: const [6, 3],
            ),
          );
        }
      }
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

  /// Build the active source's temperature curve. Overlaid sources' curves
  /// render through [_buildOverlayLines] on the same shared scale.
  List<LineChartBarData> _buildTemperatureLines(
    ColorScheme colorScheme,
    double chartMaxDepth,
    double minTemp,
    double maxTemp,
    UnitFormatter units,
  ) {
    return [
      _buildTemperatureLine(
        colorScheme,
        chartMaxDepth,
        minTemp,
        maxTemp,
        units,
      ),
    ];
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
    final tankComputerIds = _tankComputerIds();

    // Build a line for each visible tank
    for (var i = 0; i < sortedTankIds.length; i++) {
      final tankId = sortedTankIds[i];

      // Skip if tank is hidden
      if (_showTankPressure[tankId] == false) continue;

      // Skip tanks attributed to a computer that's been toggled off.
      if (!_isComputerVisible(tankComputerIds[tankId])) continue;

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

  /// Build the separate ascent-rate magnitude line: signed rate (m/min) mapped
  /// into the depth plot area so ascents rise above and descents dip below the
  /// vertical mid-plot. Self-scaled via [DiveProfileChart.ascentRateAxisRange]
  /// so the line and the optional right-axis labels share one scale.
  LineChartBarData _buildAscentRateLine(double chartMaxDepth) {
    final ascentRates = widget.ascentRates!;
    final range = DiveProfileChart.ascentRateAxisRange(ascentRates)!;
    final spots = <FlSpot>[];
    for (var i = 0; i < widget.profile.length && i < ascentRates.length; i++) {
      // Normalisation is unit-invariant, so map the stored m/min value
      // directly; the right axis converts to the user's unit at label time.
      spots.add(
        FlSpot(
          widget.profile[i].timestamp.toDouble(),
          -_mapValueToDepth(
            ascentRates[i].rateMetersPerMin,
            chartMaxDepth,
            range.min,
            range.max,
          ),
        ),
      );
    }
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: Colors.lime,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: const [5, 3],
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
    final ndlColor = Colors.yellow.shade700;

    // Map NDL to chart: max NDL (~60 min) at top, 0 at bottom
    const maxNdlSeconds = 3600.0; // 60 minutes as max display

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < ndlData.length; i++) {
      // Clamp NDL to display range to avoid gaps that cause Bezier artifacts.
      // Negative values (in deco) clamp to 0; values > 60 min clamp to 60 min.
      final ndl = ndlData[i].clamp(0, maxNdlSeconds.toInt()).toDouble();
      final normalized = ndl / maxNdlSeconds;
      final yValue = chartMaxDepth * (1 - normalized);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      preventCurveOverShooting: true,
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

  /// Compute dynamic max scale for CNS curve based on actual data.
  double _getCnsMaxScale() {
    if (widget.cnsCurve == null || widget.cnsCurve!.isEmpty) return 100.0;
    final actualMax = widget.cnsCurve!.reduce(math.max);
    return math.max(actualMax * 1.25, 10.0); // 25% headroom, min 10%
  }

  /// Compute dynamic max scale for OTU curve based on actual data.
  double _getOtuMaxScale() {
    if (widget.otuCurve == null || widget.otuCurve!.isEmpty) return 100.0;
    final actualMax = widget.otuCurve!.reduce(math.max);
    return math.max(actualMax * 1.25, 20.0); // 25% headroom, min 20 OTU
  }

  /// Build cumulative CNS% line
  LineChartBarData _buildCnsLine(double chartMaxDepth) {
    final cnsData = widget.cnsCurve!;
    const cnsColor = Color(0xFFE65100); // Orange 900

    const minCns = 0.0;
    final maxCns = _getCnsMaxScale();

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < cnsData.length; i++) {
      final cns = cnsData[i].clamp(minCns, maxCns);
      final yValue = _mapValueToDepth(cns, chartMaxDepth, minCns, maxCns);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: cnsColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [6, 3],
    );
  }

  /// Build cumulative OTU line
  LineChartBarData _buildOtuLine(double chartMaxDepth) {
    final otuData = widget.otuCurve!;
    const otuColor = Color(0xFF6D4C41); // Brown 600

    const minOtu = 0.0;
    final maxOtu = _getOtuMaxScale();

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.profile.length && i < otuData.length; i++) {
      final otu = otuData[i].clamp(minOtu, maxOtu);
      final yValue = _mapValueToDepth(otu, chartMaxDepth, minOtu, maxOtu);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: otuColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [4, 4],
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

  /// Build vertical line for external highlight (e.g. heat map hover)
  List<VerticalLine> _buildHighlightCursor(ColorScheme colorScheme) {
    final timestamp = widget.highlightedTimestamp;
    if (timestamp == null) {
      return [];
    }

    return [
      VerticalLine(
        x: timestamp.toDouble(),
        color: colorScheme.onSurface.withValues(alpha: 0.5),
        strokeWidth: 1,
        dashArray: [3, 3],
      ),
    ];
  }

  /// Build vertical lines for event markers on the dive profile.
  ///
  /// Groups events by timestamp and shows only the most severe event at each
  /// timestamp to avoid overlapping labels. Lines are colored by severity:
  /// info = primary, warning = orange, alert = red.
  List<VerticalLine> _buildEventVerticalLines(ColorScheme colorScheme) {
    final events = widget.events;
    if (events == null || events.isEmpty) return [];

    // Drop events attributed to a computer that's been toggled off. A null
    // computerId is treated as belonging to the primary computer (see
    // _isComputerVisible).
    final visibleEvents = events
        .where((e) => _isComputerVisible(e.computerId))
        .toList();
    if (visibleEvents.isEmpty) return [];

    // Group events by timestamp, keeping only the most severe at each time
    final byTimestamp = <int, ProfileEvent>{};
    for (final event in visibleEvents) {
      final existing = byTimestamp[event.timestamp];
      if (existing == null || event.severity.index > existing.severity.index) {
        byTimestamp[event.timestamp] = event;
      }
    }

    return byTimestamp.values.map((event) {
      final color = _eventSeverityColor(event.severity, colorScheme);
      return VerticalLine(
        x: event.timestamp.toDouble(),
        color: color,
        strokeWidth: 1,
        dashArray: [3, 3],
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(bottom: 2),
          style: TextStyle(
            color: color,
            fontSize: 9,
            backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
          ),
          labelResolver: (line) => event.displayName,
        ),
      );
    }).toList();
  }

  /// Returns the color for an event based on its severity level.
  Color _eventSeverityColor(EventSeverity severity, ColorScheme colorScheme) {
    switch (severity) {
      case EventSeverity.info:
        return colorScheme.primary.withValues(alpha: 0.5);
      case EventSeverity.warning:
        return Colors.orange;
      case EventSeverity.alert:
        return Colors.red;
    }
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
        return _hasMultiTankPressure;
      case ProfileRightAxisMetric.heartRate:
        return widget.profile.any((p) => p.heartRate != null);
      case ProfileRightAxisMetric.sac:
        return widget.sacCurve != null && widget.sacCurve!.any((s) => s > 0);
      case ProfileRightAxisMetric.ascentRate:
        return widget.ascentRates != null && widget.ascentRates!.isNotEmpty;
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
      case ProfileRightAxisMetric.cns:
        return widget.cnsCurve != null && widget.cnsCurve!.isNotEmpty;
      case ProfileRightAxisMetric.otu:
        return widget.otuCurve != null && widget.otuCurve!.isNotEmpty;
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
        if (!_hasMultiTankPressure || widget.tankPressures == null) return null;
        double? pMin, pMax;
        for (final points in widget.tankPressures!.values) {
          for (final pt in points) {
            if (pMin == null || pt.pressure < pMin) pMin = pt.pressure;
            if (pMax == null || pt.pressure > pMax) pMax = pt.pressure;
          }
        }
        if (pMin == null || pMax == null) return null;
        return (min: pMin - 10, max: pMax + 10);

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

      case ProfileRightAxisMetric.ascentRate:
        return DiveProfileChart.ascentRateAxisRange(widget.ascentRates);

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

      case ProfileRightAxisMetric.cns:
        if (widget.cnsCurve == null || widget.cnsCurve!.isEmpty) return null;
        return (min: 0.0, max: _getCnsMaxScale());

      case ProfileRightAxisMetric.otu:
        if (widget.otuCurve == null || widget.otuCurve!.isEmpty) return null;
        return (min: 0.0, max: _getOtuMaxScale());
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
      // Ascent rate stored in m/min -> convert depth component to user unit
      case ProfileRightAxisMetric.ascentRate:
        return units.convertDepth(value).toStringAsFixed(0);
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
      case ProfileRightAxisMetric.cns:
      case ProfileRightAxisMetric.otu:
        return value.toStringAsFixed(0);
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
      case ProfileRightAxisMetric.ascentRate:
        return '$name (${units.depthSymbol}/min)';
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
              // Straight segments preserve the actual sample-to-sample shape
              // (safety stops, multilevel ledges, abrupt descents). Catmull-
              // Rom smoothing flattens those short features into rounded
              // arcs, producing a less informative "blob" silhouette.
              isCurved: false,
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
