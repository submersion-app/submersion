import 'dart:collection';
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
import 'package:submersion/features/dive_log/data/services/profile_surface_lead_in.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_series_cache.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_touch_recognizer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_readout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_spread.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_timeline_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_findings_overlay.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_chart_viewport.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_event_labels.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';
import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';

/// Opacity of the shaded region between the ceiling and the surface.
///
/// Deliberately lighter than [decoStopFillAlpha]. The stop depth is the
/// ceiling rounded up, so the ceiling region always sits inside the deco stop
/// band, and for computer-reported profiles the two curves are the same values
/// and the regions coincide exactly. The fills composite, so this has to be
/// read as a pair: 0.10 under the band's 0.18 lands the overlap at 0.26, a
/// perceptible step up from the band rather than the 0.30 that matching the
/// band's own weight would produce.
const double ceilingFillAlpha = 0.10;

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

  /// Deco stop levels in meters, same length as profile. Drawn as a stepped
  /// band from the stop depth up to the surface.
  final List<double>? decoStopCurve;

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

  /// Whether to show the stepped deco stop band by default
  final bool showDecoStops;

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

  /// Tank IDs whose pressure series is a synthesized linear estimate (no AI
  /// data). Rendered as a straight line and labelled "(est.)".
  final Set<String>? estimatedTankIds;

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

  /// Minimum on-screen width of the safety-highlight band, in logical px.
  /// Short and instant findings inflate to this so they stay visible.
  static const double _minHighlightBandPx = 12.0;

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

  /// Optional time range to emphasize (e.g. the selected safety finding).
  /// Renders as a translucent vertical band with edge lines; short and
  /// instant ranges inflate to a minimum on-screen width.
  final ProfileHighlightRange? highlightRange;

  /// Safety findings shown as tappable chips in a lane below the plot.
  /// Pre-filtered by the caller (chartSafetyFindings): non-dismissed,
  /// rule-enabled, start-timestamped, sorted by start time. The lane renders
  /// only when this is non-empty AND [onSafetyFindingTap] is provided.
  final List<SafetyFinding>? safetyFindings;

  /// Id of the finding whose chip shows the selected ring and callout.
  final String? selectedSafetyFindingId;

  /// Toggle request from a chip or the callout's clear button: callers
  /// select the finding, or clear when it is already selected.
  final void Function(SafetyFinding finding)? onSafetyFindingTap;

  /// Callout "Dismiss" action.
  final void Function(SafetyFinding finding)? onSafetyFindingDismiss;

  /// Callout "Details" action (scroll to the safety section). Omit where no
  /// detail surface exists (fullscreen); the callout hides the link.
  final void Function(SafetyFinding finding)? onSafetyFindingDetails;

  /// Height of the safety findings lane in logical pixels.
  static const double safetyLaneHeight = 24.0;

  // Advanced decompression/gas curves
  /// ppO2 curve in bar
  final List<double>? ppO2Curve;

  /// Individual CCR O2 cell readings (bar). Outer list indexed by cell
  /// (Sensor 1, Sensor 2, ...), inner list per sample (null where no reading).
  /// Shown in the tooltip alongside the resolved ppO2.
  final List<List<double?>>? o2SensorCurves;

  /// Raw O2 cell output (mV), one curve per cell. Drawn as its own right-axis
  /// metric and shown in the tooltip beside the per-cell ppO2 (issue #810).
  final List<List<int?>>? o2CellMvCurves;

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
  ///
  /// [_DiveProfileChartState._depthBarStartIndices] applies one further
  /// adjustment on top of these runs: when a surface lead-in vertex is drawn
  /// (see [shouldDrawSurfaceLeadIn]) the first run's start is decremented to
  /// absorb it, so the identity above continues to hold.
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

  /// Whether the depth line should be extended back to the surface at t=0.
  ///
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
      // A surface lead-in vertex makes the first bar's start -1 (see
      // [shouldDrawSurfaceLeadIn]); touching that synthetic vertex resolves to
      // the first real sample rather than a negative index.
      return math.max(0, depthBarStarts[barIndex] + spotIndex);
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
    this.decoStopCurve,
    this.ascentRates,
    this.events,
    this.ndlCurve,
    this.sacCurve,
    this.tankVolume,
    this.sacNormalizationFactor = 1.0,
    this.showCeiling = true,
    this.showDecoStops = true,
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
    this.estimatedTankIds,
    this.gasSegments,
    this.diveDurationSeconds,
    this.exportKey,
    this.playbackTimestamp,
    this.highlightedTimestamp,
    this.highlightRange,
    this.safetyFindings,
    this.selectedSafetyFindingId,
    this.onSafetyFindingTap,
    this.onSafetyFindingDismiss,
    this.onSafetyFindingDetails,
    this.ppO2Curve,
    this.o2SensorCurves,
    this.o2CellMvCurves,
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
  bool _showDecoStops = true;
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

  /// Whether secondary-axis metrics are anchored to the visible depth window
  /// instead of the full depth axis. Mirrors the legend session state; read by
  /// [_metricBand] from both build() and _buildChart().
  bool _metricsFollowViewport = false;
  bool _showPpO2 = false;
  bool _showPpN2 = false;
  bool _showPpHe = false;
  bool _showO2CellMv = false;
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

  /// Localized " (est.)" suffix for a synthesized (estimated) tank; empty for
  /// tanks backed by real air-integrated data.
  String _estimatedSuffix(String tankId) =>
      (widget.estimatedTankIds?.contains(tankId) ?? false)
      ? ' ${context.l10n.diveLog_pressure_estimatedSuffix}'
      : '';

  // Zoom/pan state — see profile_chart_viewport.dart.
  ProfileChartViewport _viewport = ProfileChartViewport.reset;

  // Snapshot of the viewport at the start of a continuous gesture; continuous
  // gestures report cumulative scale/pan, so we apply them against this.
  ProfileChartViewport _gestureStartViewport = ProfileChartViewport.reset;

  // Active pointer kind, corrected on the first real pointer event. Chooses
  // pan-vs-scrub for single-pointer drags and is set by trackpad gestures.
  PointerDeviceKind _activePointerKind =
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)
      ? PointerDeviceKind.touch
      : PointerDeviceKind.mouse;

  // All touch pointers currently down, by pointer id, in chart-local coords.
  // Fed by the passive Listener, which sees every event regardless of who
  // wins the gesture arena; the two-finger pinch math reads from here.
  final Map<int, Offset> _touchPositions = {};

  // True while ChartTouchClaimRecognizer holds the arena for a touch drag.
  // The Listener only pans a touch drag when claimed, so a long-press scrub
  // (which wins the arena before any movement) is never fought by a pan.
  bool _touchDragClaimed = false;

  // The two pointer ids driving the current two-finger gesture, plus its
  // start geometry. Cumulative scale/pan is applied against
  // _gestureStartViewport, never the live viewport (no compounding).
  List<int> _pinchPointers = const [];
  double _pinchStartDistance = 1;
  Offset _pinchStartFocal = Offset.zero;

  // Manual double-tap detection off PointerEvent.timeStamp. Replaces a
  // DoubleTapGestureRecognizer, which held every tap's arena for 300 ms and
  // delayed fl_chart's tap/pan resolution (tooltip lag; fast tap-then-drag
  // misclassified). Timestamps are monotonic on real devices; flutter_test
  // must pass explicit timeStamp values.
  Duration? _lastTapUpStamp;
  Offset _lastTapUpPosition = Offset.zero;
  Offset _tapDownPosition = Offset.zero;
  bool _tapMoved = false;
  bool _doubleTapArmed = false;

  // Whether the right-axis metric selector strip is rendered this build.
  // Set in _buildChart alongside effectiveRightAxisMetric; a double-tap
  // whose second tap lands in the strip must not zoom (the strip's own tap
  // opens the metric menu).
  bool _rightAxisSelectorActive = false;

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

  // Per-group cache signatures, computed once per build in the legend-sync
  // pass and consumed by the chart assembly (see _barsCache).
  String _baseSig = '';
  String _sacSig = '';
  String _ascentSig = '';
  String _analysisSig = '';
  String _markersSig = '';
  String _overlaysSig = '';

  /// Joins signature parts for [_barsCache] group keys. Each group's
  /// signature covers exactly the inputs its series read, so changing one
  /// group's data (analysis curves, overlays) leaves the others cached.
  /// [ColorScheme.hashCode] is by value (not just [Brightness]) so switching
  /// between two presets of the same brightness still invalidates. Playback,
  /// highlight, and tooltip state are deliberately excluded.
  String _sigOf(List<Object?> parts) => parts.join('|');

  /// Fixed point budget per analysis-curve series (WS3, large-DB
  /// performance). Depth/touch series are never decimated: tooltips,
  /// scrubbing, and velocity-band suppression all key off the depth bars at
  /// full resolution.
  static const int _curvePointBudget = 2000;

  /// Decimation bucket for the current viewport. Within one bucket, zoomed
  /// pans/zooms stay pure cache hits (as unzoomed interaction always has
  /// been); crossing a half-octave zoom step or a quarter-window pan
  /// re-decimates the analysis curves over the newly visible window, so
  /// deep zoom converges back to full sample resolution.
  String _viewportDecimationBucket() {
    if (!_viewport.isZoomed) return 'full';
    final zoomBucket = (math.log(_viewport.zoom) / math.ln2 * 2).round();
    final panBucket = (_viewport.offsetX * _viewport.zoom * 4).round();
    return 'z$zoomBucket-p$panBucket';
  }

  /// Memo for [_decimatedCurveIndices], keyed by list identity and scoped by
  /// [_decimationScope] to the inputs the answer actually depends on.
  ///
  /// Which samples a curve draws is a function of the profile and the visible
  /// *X* window only — never of the metric band. But the band is folded into
  /// every bar-cache signature (it has to be: band-mapped spots move with it),
  /// so with viewport-following metrics on, a vertical pan invalidates every
  /// group and would re-run all fourteen analysis curves' O(n) envelope
  /// decimation to arrive at the indices it just discarded. Re-emitting the
  /// spots is unavoidable; re-deciding which ones is not.
  final Map<List<num>, List<int>> _decimatedIndicesCache =
      HashMap<List<num>, List<int>>.identity();

  /// Inputs [_decimatedCurveIndices] reads besides [values]. Exact, not
  /// bucketed: the memo only ever returns an answer it would have recomputed
  /// identically, so it adds no staleness of its own on top of the coarse
  /// [_viewportDecimationBucket] the bar cache already tolerates.
  String _decimationScope = '';

  /// Drops the memo when the profile or the visible X window changes. Called
  /// once per build, before any series builder runs.
  void _syncDecimationScope() {
    final scope = _sigOf([
      identityHashCode(widget.profile),
      _viewport.isZoomed,
      _viewport.offsetX,
      _viewport.visibleWidth,
    ]);
    if (scope == _decimationScope) return;
    _decimationScope = scope;
    _decimatedIndicesCache.clear();
    _decimatedNullableIndicesCache.clear();
  }

  /// Sibling of [_decimatedIndicesCache] for curves with real gaps (a cell
  /// that stopped reporting), which [_decimatedCurveIndices]'s `List<num>`
  /// cannot represent. Cleared alongside it in [_syncDecimationScope].
  final Map<List<int?>, List<int>> _decimatedNullableIndicesCache =
      HashMap<List<int?>, List<int>>.identity();

  /// Indices of [curve] to render: gaps excluded before decimation ever sees
  /// them (envelope decimation has no "this doesn't count" input, so a
  /// present-only view is the only way to keep it from treating a gap as a
  /// value), then decimated to [_curvePointBudget] over the same
  /// visible-window slice [_decimatedCurveIndices] uses.
  List<int> _decimatedNullableCurveIndices(List<int?> curve) =>
      _decimatedNullableIndicesCache.putIfAbsent(
        curve,
        () => _computeDecimatedNullableCurveIndices(curve),
      );

  List<int> _computeDecimatedNullableCurveIndices(List<int?> curve) {
    final n = math.min(widget.profile.length, curve.length);
    if (n == 0) return const [];
    final (start, end) = _viewportSampleWindow(n);

    final presentIndices = <int>[];
    final presentValues = <double>[];
    for (var i = start; i < end; i++) {
      final v = curve[i];
      if (v == null) continue;
      presentIndices.add(i);
      presentValues.add(v.toDouble());
    }
    if (presentValues.isEmpty) return const [];

    final kept = decimateSeriesIndices(
      presentValues,
      targetPoints: _curvePointBudget,
    );
    return [for (final k in kept) presentIndices[k]];
  }

  /// Indices of [values] (parallel to [widget.profile]) to render: clipped
  /// to the visible window expanded by half a window on each side, then
  /// decimated to [_curvePointBudget] preserving the value envelope
  /// (min/max per bucket, global extreme, endpoints).
  List<int> _decimatedCurveIndices(List<num> values) => _decimatedIndicesCache
      .putIfAbsent(values, () => _computeDecimatedCurveIndices(values));

  List<int> _computeDecimatedCurveIndices(List<num> values) {
    final n = math.min(widget.profile.length, values.length);
    if (n == 0) return const [];
    final (start, end) = _viewportSampleWindow(n);
    final kept = decimateSeriesIndices([
      for (var i = start; i < end; i++) values[i].toDouble(),
    ], targetPoints: _curvePointBudget);
    if (start == 0) return kept;
    return [for (final k in kept) k + start];
  }

  /// The visible-window slice of the first [n] samples, expanded by half a
  /// window on each side, or the full `[0, n)` range when not zoomed (or the
  /// window collapses to fewer than 2 samples). Shared by every per-sample
  /// decimation variant so the windowing math lives in exactly one place.
  (int start, int end) _viewportSampleWindow(int n) {
    if (!_viewport.isZoomed) return (0, n);
    final t0 = widget.profile.first.timestamp;
    final span = (widget.profile[n - 1].timestamp - t0).toDouble();
    if (span <= 0) return (0, n);
    final w = _viewport.visibleWidth;
    final loT = t0 + span * (_viewport.offsetX - w / 2);
    final hiT = t0 + span * (_viewport.offsetX + w * 1.5);
    final start = _firstProfileIndexAtOrAfter(loT, n);
    final end = _lastProfileIndexAtOrBefore(hiT, n) + 1;
    if (end - start < 2) return (0, n);
    return (start, end);
  }

  int _firstProfileIndexAtOrAfter(double t, int n) {
    var lo = 0;
    var hi = n - 1;
    var ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (widget.profile[mid].timestamp >= t) {
        ans = mid;
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }
    return ans;
  }

  int _lastProfileIndexAtOrBefore(double t, int n) {
    var lo = 0;
    var hi = n - 1;
    var ans = n - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (widget.profile[mid].timestamp <= t) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  /// Overlay variant of [_decimatedCurveIndices]: indices into [points]
  /// selected by the envelope of [value]. Overlay series are decimated by
  /// budget only (their timestamps live on their own domain).
  List<int> _decimatedOverlayIndices(
    List<DiveProfilePoint> points,
    double Function(DiveProfilePoint) value,
  ) {
    if (points.length <= _curvePointBudget) {
      return List<int>.generate(points.length, (i) => i);
    }
    return decimateSeriesIndices([
      for (final p in points) value(p),
    ], targetPoints: _curvePointBudget);
  }

  @override
  void initState() {
    super.initState();
    _showTemperature = widget.showTemperature;
    _showSac = widget.showSac;
    _showCeiling = widget.showCeiling;
    _showDecoStops = widget.showDecoStops;
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
    // Clamped for the same reason as [DiveProfileChart.depthSpotProfileIndex]:
    // the surface lead-in makes the first bar's start -1, and hovering that
    // synthetic vertex should read the first sample, not suppress the tooltip.
    final index = touched == null
        ? -1
        : math.max(0, starts[touched.barIndex] + touched.spotIndex);
    if (touched == null || index < 0 || index >= widget.profile.length) {
      widget.onTooltipData!(null);
      return;
    }
    final spot = (spotIndex: index);

    // On the lead-in vertex the cursor is before the first sample, so the
    // readout must describe t=0 rather than repeat the first sample's values.
    final onLeadIn =
        touched.spotIndex == 0 &&
        starts[touched.barIndex] < 0 &&
        shouldDrawSurfaceLeadIn(widget.profile);
    final point = onLeadIn
        ? _surfaceReadoutPoint()
        : widget.profile[spot.spotIndex];
    final l10n = context.l10n;
    final rows = <TooltipRow>[];
    final onSurface = colorScheme.onInverseSurface;

    // Time
    final minutes = point.timestamp ~/ 60;
    final seconds = point.timestamp % 60;
    rows.add(
      TooltipRow(
        label: l10n.diveLog_tooltip_time,
        value: '$minutes:${seconds.toString().padLeft(2, '0')}',
        bulletColor: onSurface.withValues(alpha: 0.5),
      ),
    );

    // Depth
    rows.add(
      TooltipRow(
        label: l10n.diveLog_tooltip_depth,
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
          label: '${l10n.diveLog_tooltip_depth} · ${overlay.name}',
          value: units.formatDepth(overlayPoint.depth),
          bulletColor: overlay.color,
        ),
      );
    }

    // Temperature
    if (_showTemperature) {
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_temp,
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
            label: '${l10n.diveLog_tooltip_temp} · ${overlay.name}',
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
          label: l10n.diveLog_tooltip_ceiling,
          value: ceiling > 0 ? units.formatDepth(ceiling) : '-',
          bulletColor: const Color(0xFFD32F2F),
        ),
      );
    }

    // Deco stop. Mirrors the in-chart tooltip row so the panel and fullscreen
    // readouts report the band they are already drawing.
    if (_showDecoStops &&
        widget.decoStopCurve != null &&
        spot.spotIndex < widget.decoStopCurve!.length) {
      final stop = widget.decoStopCurve![spot.spotIndex];
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_decoStop,
          value: stop > 0 ? units.formatDepth(stop) : '-',
          bulletColor: decoStopBandColor,
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
          label: l10n.diveLog_tooltip_rate,
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
          label: l10n.diveLog_tooltip_hr,
          value: point.heartRate != null
              ? '${point.heartRate} ${l10n.units_profileMetric_bpm}'
              : '-',
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
        TooltipRow(
          label: context.l10n.diveLog_tooltip_sac,
          value: sacValue,
          bulletColor: Colors.teal,
        ),
      );
    }

    // NDL
    if (_showNdl &&
        widget.ndlCurve != null &&
        spot.spotIndex < widget.ndlCurve!.length) {
      final ndl = widget.ndlCurve![spot.spotIndex];
      String ndlValue;
      if (ndl < 0) {
        ndlValue = l10n.diveLog_playbackStats_deco;
      } else if (ndl < 3600) {
        final min = ndl ~/ 60;
        final sec = ndl % 60;
        ndlValue = '$min:${sec.toString().padLeft(2, '0')}';
      } else {
        ndlValue = l10n.diveLog_tooltip_ndlOverMax;
      }
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_ndl,
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
          value:
              '${_readoutValue(widget.ppO2Curve![spot.spotIndex], onLeadIn).toStringAsFixed(2)} ${l10n.units_pressure_bar}',
          bulletColor: const Color(0xFF00ACC1),
        ),
      );
    }

    // One row per physical cell, plus the agreement verdict (#810). Gated on
    // the cells' own toggles, not on the ppO2 line: hiding the loop ppO2 must
    // not take the sensor readings with it.
    if (_showPpO2 || _showO2CellMv) {
      rows.addAll(_buildO2CellTooltipRows(spot.spotIndex));
    }

    // ppN2
    if (_showPpN2 &&
        widget.ppN2Curve != null &&
        spot.spotIndex < widget.ppN2Curve!.length) {
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_ppN2,
          value:
              '${_readoutValue(widget.ppN2Curve![spot.spotIndex], onLeadIn).toStringAsFixed(2)} ${l10n.units_pressure_bar}',
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
            label: l10n.diveLog_tooltip_ppHe,
            value:
                '${_readoutValue(ppHe, onLeadIn).toStringAsFixed(2)} ${l10n.units_pressure_bar}',
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
            label: l10n.diveLog_tooltip_mod,
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
          label: l10n.diveLog_tooltip_density,
          value:
              '${_readoutValue(widget.densityCurve![spot.spotIndex], onLeadIn).toStringAsFixed(2)} ${l10n.units_profileMetric_gPerL}',
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
          label: l10n.diveLog_tooltip_gfPercent,
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
          label: l10n.diveLog_tooltip_srfGf,
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
          label: l10n.diveLog_tooltip_mean,
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
          label: l10n.diveLog_tooltip_tts,
          value: tts > 0
              ? '${(tts / 60).ceil()} ${l10n.units_profileMetric_min}'
              : '0 ${l10n.units_profileMetric_min}',
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
          label: l10n.diveLog_tooltip_cns,
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
          label: l10n.diveLog_tooltip_otu,
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
            DiveProfileChart.tankTooltipLabel(
              tank,
              l10n.diveLog_tank_title(i + 1),
            ) +
            _tankSourceSuffix(
              tankId,
              tankComputerIds,
              contributingComputerIds,
            ) +
            _estimatedSuffix(tankId);
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
              label: l10n.diveLog_tooltip_marker,
              value: marker.chartLabel,
              bulletColor: marker.getColor(),
            ),
          );
        }
      }
    }

    widget.onTooltipData!(
      onLeadIn
          ? _markInterpolatedRows(rows, _exactAtSurfaceLabels(context))
          : rows,
    );
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
          DiveProfileChart._bottomTickReservedSize +
          (hasGasStrip ? DiveProfileChart.gasTimelineHeight : 0) +
          (_hasSafetyLane ? DiveProfileChart.safetyLaneHeight : 0),
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
    _showDecoStops = legendState.showDecoStops;
    _showAscentRateColors = legendState.showAscentRateColors;
    _showAscentRateLine = legendState.showAscentRateLine;
    _showEvents = legendState.showEvents;
    _showMaxDepthMarkerLocal = legendState.showMaxDepthMarker;
    _showPressureMarkersLocal = legendState.showPressureMarkers;
    _showGasSwitchMarkers = legendState.showGasSwitchMarkers;
    _showPhotoMarkers = legendState.showPhotoMarkers;
    // Must be synced before _metricBand() is read for the cache signatures
    // below, or a mode flip would key bars on the outgoing band.
    _metricsFollowViewport = legendState.metricsFollowViewport;
    // Sync advanced deco/gas toggles
    _showNdl = legendState.showNdl;
    _showPpO2 = legendState.showPpO2;
    _showPpN2 = legendState.showPpN2;
    _showPpHe = legendState.showPpHe;
    _showO2CellMv = legendState.showO2CellMv;
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

    // Per-group signatures for the memoized bars (see _barsCache): playback /
    // hover / zoom rebuilds inside one decimation bucket reuse every group;
    // an analysis-curve re-emission (e.g. a ceiling-source toggle) rebuilds
    // only the analysis group over decimated points.
    final vpBucket = _viewportDecimationBucket();
    // The one depth scan for this build; handed to _buildChart below so the
    // chart body does not repeat it (see _totalMaxDepth).
    final totalMaxDepth = _totalMaxDepth(units);
    // Every band-mapped bar's Y position moves with the visible depth window,
    // so the band belongs in each signature that covers one — otherwise a zoom
    // or vertical pan is served stale bars from the cache. Every group holds at
    // least one band-mapped series, so this sits in the common part.
    //
    // Rebuilding those bars is unavoidable: their spots genuinely move. What is
    // avoidable is re-deciding *which* samples to draw, which depends on the X
    // window alone — see _syncDecimationScope.
    final metricBandSig = _metricBand(totalMaxDepth).cacheKey;
    _syncDecimationScope();
    final commonSig = _sigOf([
      identityHashCode(widget.profile),
      identityHashCode(legendState),
      units.depthSymbol,
      units.temperatureSymbol,
      units.pressureSymbol,
      units.sacSymbol,
      colorScheme.hashCode,
      metricBandSig,
    ]);
    _baseSig = _sigOf([
      commonSig,
      identityHashCode(widget.ascentRates),
      identityHashCode(widget.gasSwitches),
      identityHashCode(widget.tanks),
      identityHashCode(widget.tankPressures),
    ]);
    _sacSig = _sigOf([commonSig, identityHashCode(widget.sacCurve), vpBucket]);
    _ascentSig = _sigOf([commonSig, identityHashCode(widget.ascentRates)]);
    _analysisSig = _sigOf([
      commonSig,
      identityHashCode(widget.ceilingCurve),
      identityHashCode(widget.decoStopCurve),
      identityHashCode(widget.ndlCurve),
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
      identityHashCode(widget.o2CellMvCurves),
      vpBucket,
    ]);
    _markersSig = _sigOf([
      commonSig,
      identityHashCode(widget.markers),
      identityHashCode(widget.tankPressures),
    ]);
    _overlaysSig = _sigOf([commonSig, identityHashCode(widget.overlays)]);

    // Check data availability for advanced curves
    final hasNdlData = widget.ndlCurve != null && widget.ndlCurve!.isNotEmpty;
    final hasPpO2Data =
        widget.ppO2Curve != null && widget.ppO2Curve!.isNotEmpty;
    final hasPpN2Data =
        widget.ppN2Curve != null && widget.ppN2Curve!.isNotEmpty;
    final hasPpHeData =
        widget.ppHeCurve != null && widget.ppHeCurve!.any((v) => v > 0.001);
    final hasModData = widget.modCurve != null && widget.modCurve!.isNotEmpty;
    final hasO2CellMvData = _hasDataForMetric(ProfileRightAxisMetric.o2CellMv);
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
      hasDecoStopCurve:
          widget.decoStopCurve != null && widget.decoStopCurve!.isNotEmpty,
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
      estimatedTankIds: widget.estimatedTankIds ?? const {},
      hasNdlData: hasNdlData,
      hasPpO2Data: hasPpO2Data,
      hasPpN2Data: hasPpN2Data,
      hasPpHeData: hasPpHeData,
      hasO2CellMvData: hasO2CellMvData,
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
            totalMaxDepth: totalMaxDepth,
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
    required double totalMaxDepth,
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
            child: Listener(
              onPointerDown: (event) {
                _activePointerCount++;
                _activePointerKind = event.kind;
                _lastPointerLocal = event.localPosition;
                if (event.kind == PointerDeviceKind.touch) {
                  _touchPositions[event.pointer] = event.localPosition;
                }
                // Tap bookkeeping is kind-agnostic: a mouse double-click
                // zooms exactly like a touch double-tap.
                if (_activePointerCount == 1) {
                  _tapDownPosition = event.localPosition;
                  _tapMoved = false;
                  final lastUp = _lastTapUpStamp;
                  _doubleTapArmed =
                      lastUp != null &&
                      event.timeStamp - lastUp < kDoubleTapTimeout &&
                      (event.localPosition - _lastTapUpPosition).distance <=
                          kDoubleTapSlop &&
                      !_inRightAxisSelector(
                        event.localPosition,
                        constraints.biggest,
                      );
                } else {
                  _doubleTapArmed = false;
                  _tapMoved = true;
                  if (_touchPositions.length == 2) {
                    _beginPinch();
                  }
                }
              },
              onPointerMove: (event) {
                final prev = _lastPointerLocal;
                _lastPointerLocal = event.localPosition;
                if (event.kind == PointerDeviceKind.touch) {
                  _touchPositions[event.pointer] = event.localPosition;
                }
                if (!_tapMoved &&
                    (event.localPosition - _tapDownPosition).distance >
                        kTouchSlop) {
                  _tapMoved = true;
                  _doubleTapArmed = false;
                }
                if (prev == null) return;
                final intent = chartDragIntent(
                  kind: _activePointerKind,
                  pointerCount: _activePointerCount,
                  isZoomed: _viewport.isZoomed,
                );
                if (intent == ChartDragIntent.zoomPan &&
                    _activePointerKind == PointerDeviceKind.touch) {
                  _updatePinch(constraints, units);
                  return;
                }
                if (intent != ChartDragIntent.pan) return;
                // A touch drag only pans once the claim recognizer has won
                // the arena; a long-press scrub keeps the drag otherwise.
                if (_activePointerKind == PointerDeviceKind.touch &&
                    !_touchDragClaimed) {
                  return;
                }
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
                if (event.kind == PointerDeviceKind.touch) {
                  _touchPositions.remove(event.pointer);
                  if (_pinchPointers.contains(event.pointer)) {
                    _touchPositions.length >= 2
                        ? _beginPinch()
                        : _pinchPointers = const [];
                  }
                }
                if (_activePointerCount == 0 && !_tapMoved) {
                  if (_doubleTapArmed) {
                    _doubleTapArmed = false;
                    _lastTapUpStamp = null;
                    _toggleDoubleTapZoom(_tapDownPosition, constraints, units);
                  } else if (!_inRightAxisSelector(
                    event.localPosition,
                    constraints.biggest,
                  )) {
                    // Selector-strip taps belong to the metric menu; they
                    // neither arm (see onPointerDown) nor seed a double-tap.
                    _lastTapUpStamp = event.timeStamp;
                    _lastTapUpPosition = event.localPosition;
                  }
                }
              },
              onPointerCancel: (event) {
                if (_activePointerCount > 0) _activePointerCount--;
                _lastPointerLocal = null;
                _touchPositions.remove(event.pointer);
                if (_pinchPointers.contains(event.pointer)) {
                  _touchPositions.length >= 2
                      ? _beginPinch()
                      : _pinchPointers = const [];
                }
                _doubleTapArmed = false;
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
                    _viewport = _viewport.zoomedAt(focal.fx, focal.fy, factor);
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
                  availableHeight: constraints.maxHeight,
                  hasTemperatureData: hasTemperatureData,
                  hasPressureData: hasPressureData,
                  hasHeartRateData: hasHeartRateData,
                  totalMaxDepth: totalMaxDepth,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Whether [localPosition] falls inside the right-axis metric selector's
  /// tap strip (mirrors the Positioned overlay in _buildChart: right 50 px,
  /// excluding the bottom 30 px axis band). A second tap there is a
  /// selector interaction, not a chart double-tap.
  bool _inRightAxisSelector(Offset localPosition, Size box) =>
      _rightAxisSelectorActive &&
      localPosition.dx >= box.width - 50 &&
      localPosition.dy <= box.height - 30;

  // Arena outcome callbacks from ChartTouchClaimRecognizer. Only event
  // handlers read the flag, so no rebuild is needed. Claiming also parks the
  // tooltip: fl_chart emits a selection at pointer-down (pan-down/tap
  // deadline) but is rejected mid-gesture once the claim wins, so it never
  // sends the touch-end event that would clear that selection.
  void _onTouchDragClaimed() {
    _touchDragClaimed = true;
    widget.onPointSelected?.call(null);
  }

  void _onTouchDragReleased() => _touchDragClaimed = false;

  /// Snapshots the start of a two-finger gesture: the two driving pointers,
  /// their separation and midpoint, and the viewport the cumulative
  /// scale/pan is applied against. Re-invoked when the driving pair changes
  /// (a third finger replacing a lifted one) so the gesture re-anchors
  /// instead of jumping. Also parks the tooltip: fl_chart may still own the
  /// first pointer's arena and would keep scrubbing under the pinch.
  void _beginPinch() {
    _pinchPointers = _touchPositions.keys.take(2).toList(growable: false);
    final p0 = _touchPositions[_pinchPointers[0]]!;
    final p1 = _touchPositions[_pinchPointers[1]]!;
    _pinchStartDistance = (p0 - p1).distance.clamp(1.0, double.infinity);
    _pinchStartFocal = (p0 + p1) / 2;
    _gestureStartViewport = _viewport;
    widget.onPointSelected?.call(null);
  }

  /// Applies the live two-finger scale/pan against the gesture-start
  /// snapshot: zoom by the separation ratio anchored at the start focal
  /// point, then pan by the focal point's movement.
  void _updatePinch(BoxConstraints constraints, UnitFormatter units) {
    if (_pinchPointers.length < 2) return;
    final p0 = _touchPositions[_pinchPointers[0]];
    final p1 = _touchPositions[_pinchPointers[1]];
    if (p0 == null || p1 == null) return;
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
        _pinchStartFocal,
        box,
        left: insets.left,
        right: insets.right,
        top: insets.top,
        bottom: insets.bottom,
      );
      final scale =
          (p0 - p1).distance.clamp(1.0, double.infinity) / _pinchStartDistance;
      var vp = _gestureStartViewport.zoomedAt(focal.fx, focal.fy, scale);
      final panPx = (p0 + p1) / 2 - _pinchStartFocal;
      vp = vp.pannedBy(
        -panPx.dx / plotW / vp.zoom,
        -panPx.dy / plotH / vp.zoom,
      );
      _viewport = vp;
    });
  }

  /// Double-tap toggle: zoom 2x anchored at the tap, or reset when already
  /// zoomed. Invoked by the manual timestamp-based double-tap detection in
  /// the Listener (see the field comments on _lastTapUpStamp).
  void _toggleDoubleTapZoom(
    Offset localPosition,
    BoxConstraints constraints,
    UnitFormatter units,
  ) {
    setState(() {
      if (_viewport.isZoomed) {
        _viewport = ProfileChartViewport.reset;
      } else {
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
        _viewport = _viewport.zoomedAt(focal.fx, focal.fy, 2.0);
      }
    });
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

  /// Whether the safety findings lane renders. Widget-param based (no
  /// provider read) so it is safe from both build and gesture paths.
  bool get _hasSafetyLane =>
      (widget.safetyFindings?.isNotEmpty ?? false) &&
      widget.onSafetyFindingTap != null;

  // ref.watch is correct here: _hasGasStrip is only read from build().
  // Gesture paths must use _gasStripVisible with ref.read (see _plotInsets).
  bool get _hasGasStrip => _gasStripVisible(
    ref.watch(profileLegendProvider.select((s) => s.showGas)),
  );

  /// Full extent of the depth axis in display units, including the 10% padding.
  /// Overlaid sources widen it so a deeper overlay trace is never clipped.
  ///
  /// Scans the profile and every overlay, so call it ONCE per build: [build]
  /// computes it for the bar-cache signatures and hands the same value to
  /// [_buildChart], which must not recompute it. The chart rebuilds on every
  /// hover and pan frame, where a repeated O(samples) scan is not free.
  double _totalMaxDepth(UnitFormatter units) {
    final maxDepthValueMeters = [
      widget.profile.map((p) => p.depth).reduce(math.max),
      ...(widget.overlays ?? const <ChartSourceOverlay>[]).expand(
        (o) => o.points.map((p) => p.depth),
      ),
    ].reduce(math.max);
    return units.convertDepth(widget.maxDepth ?? maxDepthValueMeters) * 1.1;
  }

  /// The depth slice that secondary-axis metrics are stretched across.
  ///
  /// When [_metricsFollowViewport] is off (the default) this is the whole depth
  /// axis, so metrics magnify and scroll with the depth trace and can leave the
  /// viewport when zoomed. When on, it is the currently visible depth window,
  /// so metrics stay on screen at any zoom. See [MetricBand].
  /// Takes [totalMaxDepth] rather than recomputing it, so one build shares a
  /// single depth scan between the cache signatures and the chart body.
  MetricBand _metricBand(double totalMaxDepth) {
    if (!_metricsFollowViewport) return MetricBand.full(totalMaxDepth);
    return MetricBand(
      top: _viewport.offsetY * totalMaxDepth,
      span: totalMaxDepth * _viewport.visibleHeight,
    );
  }

  Widget _buildChart(
    BuildContext context,
    UnitFormatter units, {
    required double availableWidth,
    required double availableHeight,
    required bool hasTemperatureData,
    required bool hasPressureData,
    required bool hasHeartRateData,
    required double totalMaxDepth,
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

    // Apply zoom and pan to calculate visible bounds (see ProfileChartViewport).
    final visibleRangeX = totalMaxTime * _viewport.visibleWidth;
    final visibleRangeY = totalMaxDepth * _viewport.visibleHeight;

    final visibleMinX = _viewport.offsetX * totalMaxTime;
    final visibleMaxX = visibleMinX + visibleRangeX;

    final visibleMinDepth = _viewport.offsetY * totalMaxDepth;
    final visibleMaxDepth = visibleMinDepth + visibleRangeY;

    // Highlight band, inflated to a 12 px minimum so short/instant findings
    // stay visible (spec: safety-findings-lane). Computed once and shared by
    // the band annotation and its edge lines.
    ({double x1, double x2})? highlightSpan;
    if (widget.highlightRange != null) {
      final plotInsets = _plotInsets(availableWidth, units);
      final plotWidth = (availableWidth - plotInsets.left - plotInsets.right)
          .clamp(1.0, double.infinity);
      highlightSpan = highlightBandSpan(
        widget.highlightRange!,
        visibleMinX: visibleMinX,
        visibleMaxX: visibleMaxX,
        minWidthX:
            DiveProfileChart._minHighlightBandPx *
            (visibleMaxX - visibleMinX) /
            plotWidth,
      );
    }

    // Same helper and same totalMaxDepth build() fed into the bar-cache
    // signatures, so the band the bars are drawn with can never diverge from
    // the band they are keyed on.
    final metricBand = _metricBand(totalMaxDepth);

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
    _rightAxisSelectorActive = effectiveRightAxisMetric != null;

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
                  reservedSize:
                      DiveProfileChart._bottomTickReservedSize +
                      (_hasGasStrip ? DiveProfileChart.gasTimelineHeight : 0) +
                      (_hasSafetyLane ? DiveProfileChart.safetyLaneHeight : 0),
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
                      space:
                          8 +
                          (_hasGasStrip
                              ? DiveProfileChart.gasTimelineHeight
                              : 0) +
                          (_hasSafetyLane
                              ? DiveProfileChart.safetyLaneHeight
                              : 0),
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
                    final metricValue = metricBand.unmap(
                      -value,
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
            // Bar order is invariant: depth bars first (velocity suppression
            // and tooltip resolution key off the leading barIndex range),
            // overlays last (see _depthBarCount). The groups scope cache
            // invalidation; the combined key memoizes the concatenation so a
            // playback-only rebuild returns the identical outer list (fl_chart
            // listEquals short-circuits on identity).
            lineBarsData: _barsCache.series(
              'combined',
              _sigOf([
                _baseSig,
                _sacSig,
                _ascentSig,
                _analysisSig,
                _markersSig,
                _overlaysSig,
              ]),
              () => [
                ..._barsCache.series(
                  'base',
                  _baseSig,
                  () => [
                    // Depth line segments (colored by active gas if present)
                    ..._buildGasColoredDepthLines(colorScheme, units),

                    // Gas switch markers (if showing and data available)
                    if (_showGasSwitchMarkers) ..._buildGasSwitchMarkers(units),

                    // Temperature line(s) (if showing) — one per visible
                    // computer when multi-computer profiles are present, else
                    // a single curve from the primary profile.
                    if (_showTemperature &&
                        hasTemperatureData &&
                        minTemp != null &&
                        maxTemp != null)
                      ..._buildTemperatureLines(
                        colorScheme,
                        metricBand,
                        minTemp,
                        maxTemp,
                        units,
                      ),

                    // Multi-tank pressure lines (per-tank visibility controlled
                    // inside _buildMultiTankPressureLines via _showTankPressure)
                    if (_hasMultiTankPressure)
                      ..._buildMultiTankPressureLines(metricBand),

                    // Heart rate line (if showing)
                    if (_showHeartRate &&
                        hasHeartRateData &&
                        minHR != null &&
                        maxHR != null)
                      _buildHeartRateLine(
                        heartRateColor,
                        metricBand,
                        minHR,
                        maxHR,
                      ),
                  ],
                ),
                ..._barsCache.series(
                  'sac',
                  _sacSig,
                  () => [
                    // SAC curve line (if showing)
                    if (_showSac &&
                        hasSacData &&
                        minSac != null &&
                        maxSac != null)
                      _buildSacLine(metricBand, minSac, maxSac),
                  ],
                ),
                ..._barsCache.series(
                  'ascent',
                  _ascentSig,
                  () => [
                    // Ascent-rate magnitude line (separate overlay; signed
                    // m/min)
                    if (_showAscentRateLine && widget.ascentRates != null)
                      _buildAscentRateLine(metricBand),
                  ],
                ),
                ..._barsCache.series(
                  'analysis',
                  _analysisSig,
                  () => [
                    // Deco stop band, drawn before the ceiling line so the
                    // dashed curve stays legible on top of the fill.
                    if (_showDecoStops && widget.decoStopCurve != null)
                      buildDecoStopBand(
                        decoStopCurve: widget.decoStopCurve!,
                        timestamps: [
                          for (final p in widget.profile) p.timestamp,
                        ],
                        units: units,
                      ),
                    // Ceiling line (if showing and data available)
                    if (_showCeiling && widget.ceilingCurve != null)
                      _buildCeilingLine(units),

                    // NDL line (if showing)
                    if (_showNdl && widget.ndlCurve != null)
                      _buildNdlLine(metricBand),

                    // ppO2 line (if showing)
                    if (_showPpO2 && widget.ppO2Curve != null)
                      _buildPpO2Line(metricBand),

                    // ppN2 line (if showing)
                    if (_showPpN2 && widget.ppN2Curve != null)
                      _buildPpN2Line(metricBand),

                    // ppHe line (if showing and has helium data)
                    if (_showPpHe &&
                        widget.ppHeCurve != null &&
                        widget.ppHeCurve!.any((v) => v > 0.001))
                      _buildPpHeLine(metricBand),

                    // O2 cell agreement rug plus one millivolt line per cell
                    if (_showO2CellMv && widget.o2CellMvCurves != null) ...[
                      ..._buildO2CellRug(metricBand),
                      ..._buildO2CellMvLines(metricBand, units),
                    ],

                    // MOD line (if showing)
                    if (_showMod && widget.modCurve != null)
                      _buildModLine(units),

                    // Gas density line (if showing)
                    if (_showDensity && widget.densityCurve != null)
                      _buildDensityLine(metricBand),

                    // GF% line (if showing)
                    if (_showGf && widget.gfCurve != null)
                      _buildGfLine(metricBand),

                    // Surface GF line (if showing)
                    if (_showSurfaceGf && widget.surfaceGfCurve != null)
                      _buildSurfaceGfLine(metricBand),

                    // Mean depth line (if showing)
                    if (_showMeanDepth && widget.meanDepthCurve != null)
                      _buildMeanDepthLine(units),

                    // TTS line (if showing)
                    if (_showTts && widget.ttsCurve != null)
                      _buildTtsLine(metricBand),

                    // CNS% curve (if showing)
                    if (_showCns && widget.cnsCurve != null)
                      _buildCnsLine(metricBand),

                    // OTU curve (if showing)
                    if (_showOtu && widget.otuCurve != null)
                      _buildOtuLine(metricBand),
                  ],
                ),
                ..._barsCache.series(
                  'markers',
                  _markersSig,
                  () => [
                    // Profile markers (max depth, pressure thresholds)
                    ..._buildMarkerLines(
                      units,
                      metricBand,
                      minPressure: minPressure,
                      maxPressure: maxPressure,
                    ),
                  ],
                ),
                ..._barsCache.series(
                  'overlays',
                  _overlaysSig,
                  () => [
                    // Overlaid comparison sources — LAST, so depth bars keep
                    // occupying the leading barIndex range (_depthBarCount).
                    ..._buildOverlayLines(units, metricBand, minTemp, maxTemp),
                  ],
                ),
              ],
            ),
            rangeAnnotations: RangeAnnotations(
              verticalRangeAnnotations: _buildHighlightRangeAnnotations(
                highlightSpan,
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: _buildO2CellRugTrack(metricBand, colorScheme),
              verticalLines: [
                ..._buildPlaybackCursor(colorScheme),
                ..._buildHighlightCursor(colorScheme),
                ..._buildHighlightRangeLines(highlightSpan),
                if (_showEvents && widget.events != null)
                  ..._buildEventVerticalLines(
                    colorScheme,
                    availableWidth: availableWidth,
                    availableHeight: availableHeight,
                    units: units,
                    visibleMinX: visibleMinX,
                    visibleMaxX: visibleMaxX,
                    visibleMinDepth: visibleMinDepth,
                    visibleMaxDepth: visibleMaxDepth,
                  ),
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
                // During a two-finger gesture fl_chart may still own the
                // first pointer's arena (its pan won before the second
                // finger landed) and would keep scrubbing under the pinch;
                // the pinch owns the interaction, so ignore its events. The
                // same applies while a one-finger pan drag is claimed.
                if (_activePointerCount >= 2 || _touchDragClaimed) return;
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

                  // The cursor is on the lead-in vertex when the resolved bar's
                  // start is negative and the touched spot is its first: the
                  // readout must describe t=0, not repeat the first sample.
                  final onLeadIn =
                      depthSpot != null &&
                      depthSpot.spotIndex == 0 &&
                      depthBarStarts[depthSpot.barIndex] < 0 &&
                      shouldDrawSurfaceLeadIn(widget.profile);

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

                    final point = onLeadIn
                        ? _surfaceReadoutPoint()
                        : widget.profile[spot.spotIndex];
                    final minutes = point.timestamp ~/ 60;
                    final seconds = point.timestamp % 60;

                    // Build tooltip with all enabled metrics
                    // Text style constants for consistent column layout
                    final onSurface = colorScheme.onInverseSurface;
                    final l10n = context.l10n;
                    final bar = l10n.units_pressure_bar;
                    final gPerL = l10n.units_profileMetric_gPerL;
                    final minUnit = l10n.units_profileMetric_min;
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
                      final bpm = l10n.units_profileMetric_bpm;
                      final hrValue = point.heartRate != null
                          ? '${point.heartRate} $bpm'
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

                    // Deco stop (if enabled - always show row)
                    if (_showDecoStops) {
                      String stopValue = '—';
                      if (widget.decoStopCurve != null &&
                          spot.spotIndex < widget.decoStopCurve!.length) {
                        final stop = widget.decoStopCurve![spot.spotIndex];
                        if (stop > 0) {
                          stopValue = units.formatDepth(stop);
                        }
                      }
                      addRow(
                        context.l10n.diveLog_tooltip_decoStop,
                        stopValue,
                        decoStopBandColor,
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
                          ndlValue = l10n.diveLog_tooltip_ndlOverMax;
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
                        final ppO2 = _readoutValue(
                          widget.ppO2Curve![spot.spotIndex],
                          onLeadIn,
                        );
                        ppO2Value = '${ppO2.toStringAsFixed(2)} $bar';
                      }
                      addRow(
                        widget.ppO2FromSensorAverage
                            ? '${context.l10n.diveLog_tooltip_ppO2} ${context.l10n.diveLog_tooltip_avgCalculated}'
                            : context.l10n.diveLog_tooltip_ppO2,
                        ppO2Value,
                        const Color(0xFF00ACC1),
                      );
                    }

                    // Cell rows follow the cells' own toggles, not the ppO2
                    // line: hiding the loop ppO2 must not hide the sensors.
                    if (_showPpO2 || _showO2CellMv) {
                      for (final row in _buildO2CellTooltipRows(
                        spot.spotIndex,
                      )) {
                        addRow(row.label, row.value, row.bulletColor);
                      }
                    }

                    // ppN2 (if enabled)
                    if (_showPpN2) {
                      String ppN2Value = '—';
                      if (widget.ppN2Curve != null &&
                          spot.spotIndex < widget.ppN2Curve!.length) {
                        final ppN2 = _readoutValue(
                          widget.ppN2Curve![spot.spotIndex],
                          onLeadIn,
                        );
                        ppN2Value = '${ppN2.toStringAsFixed(2)} $bar';
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
                          ppHeValue =
                              '${_readoutValue(ppHe, onLeadIn).toStringAsFixed(2)} $bar';
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
                        final density = _readoutValue(
                          widget.densityCurve![spot.spotIndex],
                          onLeadIn,
                        );
                        densityValue = '${density.toStringAsFixed(2)} $gPerL';
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
                          ttsValue = '$min $minUnit';
                        } else {
                          ttsValue = '0 $minUnit';
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
                            ) +
                            _estimatedSuffix(tankId);
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

                    // On the lead-in, mark every carried-over value so a held
                    // reading is never shown as measured. Exact and computed
                    // rows (time, depth, the partial pressures, MOD, density)
                    // are left untouched -- same set as the overlay readout.
                    final displayRows = onLeadIn
                        ? [
                            for (final row in tooltipRows)
                              if (_exactAtSurfaceLabels(
                                    context,
                                  ).contains(row.label) ||
                                  row.label.startsWith(
                                    context.l10n.diveLog_tooltip_depth,
                                  ))
                                row
                              else
                                (
                                  label: row.label,
                                  value: l10n.diveLog_tooltip_interpolated(
                                    row.value,
                                  ),
                                  bulletColor: row.bulletColor,
                                  bullet: row.bullet,
                                  bulletSize: row.bulletSize,
                                ),
                          ]
                        : tooltipRows;

                    const rowWidth = labelWidth + valueWidth;
                    final rowFiller = List.filled(rowWidth, '0').join();
                    final lines = <TextSpan>[];
                    for (final row in displayRows) {
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
          // The chart rebuilds on every hover, pan, and cursor move. The
          // default 150ms implicit animation lerps old data to new, lagging
          // the highlight cursor behind the pointer, sliding event markers
          // (verticalLines lerp by index, and cursor lines shift the
          // indices), and smearing bars while panning. Render immediately.
          duration: Duration.zero,
        ),
        // Touch claim overlay. Stacked directly above the LineChart so it is
        // hit-tested first: its recognizer joins each pointer's arena before
        // fl_chart's internal pan/tap/long-press recognizers and therefore
        // wins ties. Translucent, so fl_chart still receives every pointer
        // (taps, long-press scrubs) that the recognizer does not claim. The
        // interactive overlays stacked above (metric selector, photo
        // markers) keep their priority over this layer.
        Positioned.fill(
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              ChartTouchClaimRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    ChartTouchClaimRecognizer
                  >(
                    () => ChartTouchClaimRecognizer(
                      isZoomed: () => _viewport.isZoomed,
                      debugOwner: this,
                    ),
                    (recognizer) => recognizer
                      ..onClaimed = _onTouchDragClaimed
                      ..onReleased = _onTouchDragReleased,
                  ),
            },
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
                DiveProfileChart._bottomTickReservedSize +
                (_hasSafetyLane ? DiveProfileChart.safetyLaneHeight : 0),
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
        // Safety findings lane + callout: a widget layer like the photo
        // markers, occupying the extra bottom reservation added by
        // _hasSafetyLane, directly between the gas strip (or plot) and the
        // tick labels.
        if (_hasSafetyLane)
          Positioned.fill(
            child: SafetyFindingsOverlay(
              findings: widget.safetyFindings!,
              selectedFindingId: widget.selectedSafetyFindingId,
              visibleMinSeconds: visibleMinX,
              visibleMaxSeconds: visibleMaxX,
              insets: _plotInsets(availableWidth, units),
              laneHeight: DiveProfileChart.safetyLaneHeight,
              laneBottomOffset:
                  DiveProfileChart._bottomAxisNameSize +
                  DiveProfileChart._bottomTickReservedSize,
              units: units,
              onFindingTap: widget.onSafetyFindingTap!,
              onFindingDismiss: widget.onSafetyFindingDismiss ?? (_) {},
              onFindingDetails: widget.onSafetyFindingDetails,
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
                DiveProfileChart._bottomTickReservedSize +
                (_hasSafetyLane ? DiveProfileChart.safetyLaneHeight : 0),
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
            profileMetricCategoryName(context.l10n, category),
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
                  profileMetricName(context.l10n, metric),
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
    // The surface lead-in prepends one synthetic spot to the bar that owns the
    // first sample, shifting that bar's local spotIndex by one. Reporting a
    // start of -1 keeps `start + spotIndex` addressing the right sample.
    final leadIn = shouldDrawSurfaceLeadIn(widget.profile) ? 1 : 0;
    final ascentRates = widget.ascentRates;
    if (_showAscentRateColors &&
        ascentRates != null &&
        ascentRates.length == widget.profile.length &&
        widget.profile.length >= 2) {
      final runs = DiveProfileChart.velocityBandRuns(
        widget.profile.length,
        ascentRates,
      ).map((run) => run.start).toList();
      if (leadIn > 0 && runs.isNotEmpty) runs[0] -= leadIn;
      return runs;
    }
    return [0 - leadIn];
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
    MetricBand band,
    double? minTemp,
    double? maxTemp,
  ) {
    final overlays = widget.overlays;
    if (overlays == null || overlays.isEmpty) return const [];

    final lines = <LineChartBarData>[];
    for (final overlay in overlays) {
      if (overlay.points.isEmpty) continue;

      // Depth: dashed, no fill. Decimated on the depth envelope (WS3).
      final depthKeep = _decimatedOverlayIndices(
        overlay.points,
        (p) => p.depth,
      );
      // Keyed on the overlay's OWN points, not the active profile: an overlaid
      // computer has its own first sample and sampling interval, so the active
      // dive cannot decide whether this trace needs a lead-in. Without that,
      // an overlay starting at t=10 stays gapped whenever the active profile
      // starts at t=0.
      final overlayDepthSpots = [
        for (final i in depthKeep)
          FlSpot(
            overlay.points[i].timestamp.toDouble(),
            -units.convertDepth(overlay.points[i].depth),
          ),
      ];
      lines.add(
        LineChartBarData(
          spots: _withSurfaceLeadIn(
            overlayDepthSpots,
            0,
            owner: overlay.points,
          ),
          isCurved: true,
          curveSmoothness: 0.2,
          preventCurveOverShooting: _seriesGetsLeadIn(
            overlayDepthSpots,
            overlay.points,
          ),
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
          final tempKeep = _decimatedOverlayIndices(
            tempPoints,
            (p) => p.temperature!,
          );
          lines.add(
            LineChartBarData(
              spots: [
                for (final i in tempKeep)
                  FlSpot(
                    tempPoints[i].timestamp.toDouble(),
                    -band.map(
                      units.convertTemperature(tempPoints[i].temperature!),
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
        final ceilingPoints = overlay.points
            .where((p) => p.ceiling != null && p.ceiling! > 0)
            .toList();
        if (ceilingPoints.isNotEmpty) {
          final ceilingKeep = _decimatedOverlayIndices(
            ceilingPoints,
            (p) => p.ceiling!,
          );
          lines.add(
            LineChartBarData(
              spots: [
                for (final i in ceilingKeep)
                  FlSpot(
                    ceilingPoints[i].timestamp.toDouble(),
                    -units.convertDepth(ceilingPoints[i].ceiling!),
                  ),
              ],
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
        final ndlPoints = overlay.points.where((p) => p.ndl != null).toList();
        if (ndlPoints.isNotEmpty) {
          final ndlKeep = _decimatedOverlayIndices(
            ndlPoints,
            (p) => p.ndl!.clamp(0, maxNdlSeconds.toInt()).toDouble(),
          );
          final ndlSpots = <FlSpot>[
            for (final i in ndlKeep)
              FlSpot(
                ndlPoints[i].timestamp.toDouble(),
                -band.mapNormalized(
                  ndlPoints[i].ndl!.clamp(0, maxNdlSeconds.toInt()).toDouble() /
                      maxNdlSeconds,
                ),
              ),
          ];
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

  /// Extend a curve back to the t=0 axis origin with a lead-in vertex at
  /// [surfaceY] (already in chart y-space, i.e. negated/normalised the same way
  /// the curve's own points are).
  ///
  /// Computers do not sample at t=0, so without this every line starts one
  /// sample interval inside the chart and the left edge reads as ragged
  /// (issue #684). No-ops when the profile already starts at zero, when the gap
  /// is too wide to attribute to the sampling rate, or when the curve drew no
  /// points at all.
  /// Whether [spots] is eligible for a lead-in against [owner], the profile the
  /// series was built from.
  ///
  /// [owner] is passed rather than assumed to be [widget.profile]: an overlaid
  /// source has its own samples and its own sampling interval, so keying an
  /// overlay's lead-in off the active profile would test the wrong dive.
  ///
  /// A curve that is only drawn where it has data (the ceiling line skips
  /// ceiling <= 0, a deco bottle's pressure starts when it is first breathed)
  /// may legitimately start mid-dive; only a curve whose own first point is its
  /// profile's first sample is bridged back to t=0.
  bool _seriesGetsLeadIn(List<FlSpot> spots, List<DiveProfilePoint> owner) =>
      spots.isNotEmpty &&
      owner.isNotEmpty &&
      shouldDrawSurfaceLeadIn(owner) &&
      spots.first.x == owner.first.timestamp.toDouble();

  List<FlSpot> _withSurfaceLeadIn(
    List<FlSpot> spots,
    double surfaceY, {
    List<DiveProfilePoint>? owner,
  }) {
    final source = owner ?? widget.profile;
    if (!_seriesGetsLeadIn(spots, source)) return spots;
    return [FlSpot(0, surfaceY), ...spots];
  }

  /// Lead-in for curves that barely change across one sample interval
  /// (temperature, partial pressures, MOD, density, SAC, tank pressure, heart
  /// rate): hold the first reading flat back to t=0.
  /// The sample the readout describes when the cursor sits on the lead-in.
  ///
  /// Time and depth are exact rather than interpolated: the dive begins at
  /// t=0 with the diver at the surface. Temperature carries over from the
  /// first reading and is marked interpolated by [_markInterpolatedRows].
  DiveProfilePoint _surfaceReadoutPoint() => DiveProfilePoint(
    timestamp: 0,
    depth: 0,
    temperature: widget.profile.isEmpty
        ? null
        : widget.profile.first.temperature,
  );

  /// Labels whose value at t=0 is known or calculated rather than carried over
  /// from the first sample, and so must not be marked interpolated.
  ///
  /// Time and depth are exact. The partial pressures and gas density are
  /// computed from the ambient pressure at the surface (see
  /// [surfaceValueAtOneBar]). MOD is a property of the gas, so it does not
  /// change between the surface and the first sample.
  /// Built at the call site because some labels are localized: matching
  /// hardcoded English would silently mark them interpolated in other locales.
  Set<String> _exactAtSurfaceLabels(BuildContext context) => {
    context.l10n.diveLog_tooltip_time,
    context.l10n.diveLog_tooltip_depth,
    context.l10n.diveLog_tooltip_ppN2,
    context.l10n.diveLog_tooltip_ppHe,
    context.l10n.diveLog_tooltip_mod,
    context.l10n.diveLog_tooltip_density,
    context.l10n.diveLog_tooltip_ppO2,
    '${context.l10n.diveLog_tooltip_ppO2} '
        '${context.l10n.diveLog_tooltip_avgCalculated}',
  };

  /// Mark every readout row whose value was carried over from the first sample
  /// rather than known or calculated at t=0, so the lead-in never presents a
  /// held value as if it had been measured there.
  List<TooltipRow> _markInterpolatedRows(
    List<TooltipRow> rows,
    Set<String> exactLabels,
  ) => [
    for (final row in rows)
      if (exactLabels.contains(row.label) ||
          row.label.startsWith(context.l10n.diveLog_tooltip_depth))
        row
      else
        TooltipRow(
          label: row.label,
          value: context.l10n.diveLog_tooltip_interpolated(row.value),
          bulletColor: row.bulletColor,
        ),
  ];

  /// A readout value for a pressure-proportional quantity: computed at the
  /// surface while on the lead-in, otherwise the sampled value as-is.
  double _readoutValue(double sampled, bool onLeadIn) =>
      onLeadIn ? _surfaceValueOf(sampled) : sampled;

  /// [surfaceValueAtOneBar] applied at the dive's first sample.
  double _surfaceValueOf(double valueAtFirstSample) => widget.profile.isEmpty
      ? valueAtFirstSample
      : surfaceValueAtOneBar(valueAtFirstSample, widget.profile.first.depth);

  List<FlSpot> _withFlatSurfaceLeadIn(
    List<FlSpot> spots, {
    List<DiveProfilePoint>? owner,
  }) => spots.isEmpty
      ? spots
      : _withSurfaceLeadIn(spots, spots.first.y, owner: owner);

  /// Build a single depth line segment with the given color
  LineChartBarData _buildSingleDepthSegment(
    Color color,
    UnitFormatter units,
    int startIndex,
    int endIndex, {
    bool showFill = false,
  }) {
    return LineChartBarData(
      spots: [
        // Close the gap between the t=0 axis origin and the first sample by
        // descending from the surface. Only the bar that owns the first sample
        // carries it, so the later velocity-band bars are untouched.
        if (startIndex == 0 && shouldDrawSurfaceLeadIn(widget.profile))
          const FlSpot(0, 0),
        ...widget.profile
            .sublist(startIndex, endIndex)
            .map(
              (p) =>
                  FlSpot(p.timestamp.toDouble(), -units.convertDepth(p.depth)),
            ),
      ],
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting:
          startIndex == 0 && shouldDrawSurfaceLeadIn(widget.profile),
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
    MetricBand band,
    double minTemp,
    double maxTemp,
    UnitFormatter units,
  ) {
    return [_buildTemperatureLine(colorScheme, band, minTemp, maxTemp, units)];
  }

  LineChartBarData _buildTemperatureLine(
    ColorScheme colorScheme,
    MetricBand band,
    double minTemp,
    double maxTemp,
    UnitFormatter units,
  ) {
    // Built first so the smoothing flag below can ask whether this series
    // actually receives a lead-in: samples without a temperature are skipped,
    // so the curve can legitimately start after the dive's first sample.
    final tempSpots = widget.profile
        .where((p) => p.temperature != null)
        .map(
          (p) => FlSpot(
            p.timestamp.toDouble(),
            // Convert temp to user's unit, then map to depth axis
            -band.map(
              units.convertTemperature(p.temperature!),
              minTemp,
              maxTemp,
            ),
          ),
        )
        .toList();
    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(tempSpots),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(tempSpots, widget.profile),
      color: colorScheme.tertiary,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [5, 3],
    );
  }

  /// Build multiple pressure lines for multi-tank visualization
  List<LineChartBarData> _buildMultiTankPressureLines(MetricBand band) {
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

    // A zero span means every sample across every tank is identical -- in
    // practice a computer that logged a pressure channel with no transmitter
    // paired (all zeros). There is no pressure information to plot, and mapping
    // a constant value through a zero-width range yields NaN spot coordinates
    // that crash fl_chart's touch/tooltip painter (Offset NaN). Skip it.
    if (pressureRange <= 0) return [];

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

      // A tank first breathed mid-dive keeps its own start: the lead-in only
      // bridges a series that begins at the dive's first sample. Built first so
      // the smoothing flag below reflects whether THIS tank got one.
      final tankSpots = pressurePoints
          .map(
            (p) => FlSpot(
              p.timestamp.toDouble(),
              -band.map(p.pressure, minPressure, maxPressure),
            ),
          )
          .toList();
      lines.add(
        LineChartBarData(
          spots: _withFlatSurfaceLeadIn(tankSpots),
          // Synthesized estimates are straight (flat-drop-flat); curve
          // smoothing would round their corners. Real AI data stays curved.
          isCurved: !(widget.estimatedTankIds?.contains(tankId) ?? false),
          curveSmoothness: 0.2,
          // The lead-in vertex is a sharp direction change; without this the
          // spline overshoots it and hooks below the curve at the left edge.
          preventCurveOverShooting: _seriesGetsLeadIn(
            tankSpots,
            widget.profile,
          ),
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
    MetricBand band,
    double minHR,
    double maxHR,
  ) {
    return LineChartBarData(
      spots: widget.profile
          .where((p) => p.heartRate != null)
          .map(
            (p) => FlSpot(
              p.timestamp.toDouble(),
              -band.map(p.heartRate!.toDouble(), minHR, maxHR),
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
    MetricBand band,
    double minSac,
    double maxSac,
  ) {
    const sacColor = Colors.teal;
    final sacCurve = widget.sacCurve!;

    // Build spots for each profile point that has SAC data
    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(sacCurve)) {
      final sac = sacCurve[i];
      if (sac > 0) {
        spots.add(
          FlSpot(
            widget.profile[i].timestamp.toDouble(),
            -band.map(sac, minSac, maxSac),
          ),
        );
      }
    }

    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(spots),
      isCurved: true,
      curveSmoothness: 0.3,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
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
  LineChartBarData _buildAscentRateLine(MetricBand band) {
    final ascentRates = widget.ascentRates!;
    final range = DiveProfileChart.ascentRateAxisRange(ascentRates)!;
    final spots = <FlSpot>[];
    for (var i = 0; i < widget.profile.length && i < ascentRates.length; i++) {
      // Normalisation is unit-invariant, so map the stored m/min value
      // directly; the right axis converts to the user's unit at label time.
      spots.add(
        FlSpot(
          widget.profile[i].timestamp.toDouble(),
          -band.map(ascentRates[i].rateMetersPerMin, range.min, range.max),
        ),
      );
    }
    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(spots),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
      color: Colors.lime,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: const [5, 3],
    );
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

    // Build spots only where ceiling > 0, breaking the curve wherever the
    // obligation clears. fl_chart splits a bar on null spots and gives each
    // section its own fill, so without the break a profile that re-enters deco
    // would join its two runs and shade the ceiling-free stretch between them.
    // The break is deferred to the next real spot so no null leads or trails.
    final spots = <FlSpot>[];
    var pendingBreak = false;
    for (final i in _decimatedCurveIndices(ceilingData)) {
      final ceiling = ceilingData[i];
      if (ceiling <= 0) {
        if (spots.isNotEmpty) pendingBreak = true;
        continue;
      }
      if (pendingBreak) {
        spots.add(FlSpot.nullSpot);
        pendingBreak = false;
      }
      spots.add(
        FlSpot(
          widget.profile[i].timestamp.toDouble(),
          -units.convertDepth(ceiling), // Convert and negate for inverted axis
        ),
      );
    }

    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(spots),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
      color: ceilingColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [4, 4],
      // The shaded region runs from the ceiling UP to the surface, so it is an
      // aboveBarData. Negated depths put the surface (y = 0) above the ceiling
      // (y = -4.2), and a below-bar fill cannot express that: fl_chart's
      // painter draws the below-bar area and then erases the entire above-line
      // region to clean up the cut-off overdraw, wiping exactly this fill. Same
      // defect, and same fix, as the deco stop band in deco_stop_band.dart.
      aboveBarData: BarAreaData(
        show: true,
        color: ceilingColor.withValues(alpha: ceilingFillAlpha),
        cutOffY: 0, // Fill to surface
        applyCutOffY: true,
      ),
    );
  }

  /// Build NDL (No Decompression Limit) line
  /// NDL values are in seconds; shows time remaining before deco obligation
  LineChartBarData _buildNdlLine(MetricBand band) {
    final ndlData = widget.ndlCurve!;
    final ndlColor = Colors.yellow.shade700;

    // Map NDL to chart: max NDL (~60 min) at top, 0 at bottom
    const maxNdlSeconds = 3600.0; // 60 minutes as max display

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(ndlData)) {
      // Draw NDL only while there is actually no-deco time left. Once it is
      // spent (zero, or negative in deco) the line simply ends -- a flat line
      // pinned at zero through the deco phase carries no information. A null
      // spot breaks the series so it does not bridge straight across the gap.
      if (ndlData[i] <= 0) {
        if (spots.isNotEmpty && spots.last != FlSpot.nullSpot) {
          spots.add(FlSpot.nullSpot);
        }
        continue;
      }
      // Clamp values > 60 min to the top of the display range.
      final ndl = ndlData[i].clamp(0, maxNdlSeconds.toInt()).toDouble();
      final normalized = ndl / maxNdlSeconds;
      final yValue = band.mapNormalized(normalized);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      // Held flat, not forced to maximum: on a repetitive dive the NDL at the
      // surface is already cut short by residual loading, which the first
      // sample reflects and a synthetic maximum would not.
      spots: _withFlatSurfaceLeadIn(spots),
      // Straight segments: a spline across the null-spot breaks would reach
      // for the gap and overshoot.
      isCurved: false,
      color: ndlColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [6, 3],
    );
  }

  /// Build ppO2 (partial pressure of oxygen) line
  /// Values typically range from 0.21 (surface air) to 1.6+ (critical)
  LineChartBarData _buildPpO2Line(MetricBand band) {
    final ppO2Data = widget.ppO2Curve!;
    const ppO2Color = Color(0xFF00ACC1); // Cyan 600 - distinct from depth blue

    // Map ppO2 to chart: 0 at top, 2.0 bar at bottom
    const minPpO2 = 0.0;
    const maxPpO2 = 2.0;

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(ppO2Data)) {
      final ppO2 = ppO2Data[i].clamp(minPpO2, maxPpO2);
      final yValue = band.map(ppO2, minPpO2, maxPpO2);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      // ppO2 scales with ambient pressure, so its surface value is computed,
      // not held flat: at 1 bar it is simply the oxygen fraction.
      spots: _withSurfaceLeadIn(
        spots,
        -band.map(
          _surfaceValueOf(ppO2Data.first).clamp(minPpO2, maxPpO2),
          minPpO2,
          maxPpO2,
        ),
      ),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
      color: ppO2Color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [5, 3],
    );
  }

  List<List<int?>>? _o2SpreadSource;
  List<double?>? _o2SpreadCached;

  /// Smoothed cell spread (max minus min), memoized on the source identity.
  ///
  /// Both the ribbon and the axis need it, and a rolling median per frame would
  /// be wasteful. Smoothed because millivolts are whole numbers: without it the
  /// ribbon flickers a full millivolt wider and narrower on pure rounding.
  List<double?> _o2CellSpread(List<List<int?>> mvCurves) {
    if (identical(_o2SpreadSource, mvCurves) && _o2SpreadCached != null) {
      return _o2SpreadCached!;
    }
    final window = o2CellSpreadWindowSamples([
      for (final p in widget.profile) p.timestamp,
    ]);
    _o2SpreadSource = mvCurves;
    _o2SpreadCached = smoothO2CellSpread([
      computeO2CellRange(mvCurves),
    ], windowSamples: window).single;
    return _o2SpreadCached!;
  }

  /// Cell spread at one sample, for the tooltip. Null when fewer than two cells
  /// reported there.
  double? _o2CellRangeAt(int sampleIndex) {
    final curves = widget.o2CellMvCurves;
    if (curves == null) return null;
    final spread = _o2CellSpread(curves);
    if (sampleIndex >= spread.length) return null;
    return spread[sampleIndex];
  }

  /// Colour for one agreement level, traffic-light coded so the verdict reads
  /// without decoding a legend. Tight is deliberately quiet despite being
  /// green: a healthy rig is in that state for essentially the whole dive, so
  /// it must read as background, not as a series demanding attention.
  Color _agreementColor(O2CellAgreement level) => switch (level) {
    O2CellAgreement.tight => const Color(0xFF66BB6A).withValues(alpha: 0.55),
    O2CellAgreement.drifting => const Color(0xFFFFCA28),
    O2CellAgreement.wide => const Color(0xFFE57373),
  };

  /// The rug's caption. Held here so the track and the tooltip cannot diverge.
  String get _l10nO2CellSpreadLabel => context.l10n.diveLog_o2CellSpread_label;

  String _agreementWord(O2CellAgreement level) => switch (level) {
    O2CellAgreement.tight => context.l10n.diveLog_tooltip_o2CellsTight,
    O2CellAgreement.drifting => context.l10n.diveLog_tooltip_o2CellsDrifting,
    O2CellAgreement.wide => context.l10n.diveLog_tooltip_o2CellsWide,
  };

  /// "tight (1 mV)" -- a verdict backed by the number, rather than a number the
  /// reader has to know how to judge.
  String? _o2CellAgreementReadout(int sampleIndex) {
    final spread = _o2CellRangeAt(sampleIndex);
    if (spread == null) return null;
    final level = o2CellAgreementFor(spread);
    return '${_agreementWord(level)} (${spread.toStringAsFixed(0)} mV)';
  }

  /// One row per physical cell -- ppO2 when the calibration is trustworthy,
  /// the raw output when it is not, both when both are available -- plus the
  /// agreement verdict row (#810). Shared by both tooltip layouts so they
  /// cannot drift apart; callers must gate this on `_showPpO2 || _showO2CellMv`
  /// themselves, since a mobile-vs-desktop caller may need to skip building an
  /// empty section wrapper when there is nothing to show.
  List<TooltipRow> _buildO2CellTooltipRows(int spotIndex) {
    final l10n = context.l10n;
    final rows = <TooltipRow>[];
    final cellCount = o2CellCount(
      barCurves: widget.o2SensorCurves,
      mvCurves: widget.o2CellMvCurves,
    );
    for (var cell = 0; cell < cellCount; cell++) {
      final readout = formatO2CellReadout(
        bar: valueAtSample(
          curves: widget.o2SensorCurves,
          cell: cell,
          sampleIndex: spotIndex,
        ),
        millivolt: valueAtSample(
          curves: widget.o2CellMvCurves,
          cell: cell,
          sampleIndex: spotIndex,
        ),
        barUnit: l10n.units_pressure_bar,
        millivoltUnit: l10n.units_profileMetric_millivolts,
      );
      if (readout == null) continue;
      rows.add(
        TooltipRow(
          label: '${l10n.diveLog_tooltip_sensor} ${cell + 1}',
          value: readout,
          bulletColor: o2CellColor(cell),
        ),
      );
    }
    final agreement = _o2CellAgreementReadout(spotIndex);
    if (agreement != null) {
      rows.add(
        TooltipRow(
          label: _l10nO2CellSpreadLabel,
          value: agreement,
          bulletColor: _agreementColor(
            o2CellAgreementFor(_o2CellRangeAt(spotIndex)!),
          ),
        ),
      );
    }
    return rows;
  }

  /// Depth, in the band's units, at which the agreement rug sits.
  double _o2CellRugDepth(MetricBand band) => band.top + band.span * 0.985;

  /// A faint full-width groove behind the rug, captioned with what it is.
  ///
  /// Without it the rug is a bare mark: a healthy dive draws one quiet segment
  /// and nothing distinguishes "checked, and the cells agreed" from "this line
  /// is left over from something". The groove shows the readout is present and
  /// the caption says what is being read.
  List<HorizontalLine> _buildO2CellRugTrack(
    MetricBand band,
    ColorScheme colorScheme,
  ) {
    if (!_showO2CellMv) return const [];
    if (widget.o2CellMvCurves == null) return const [];

    return [
      HorizontalLine(
        y: -_o2CellRugDepth(band),
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.18),
        strokeWidth: 3,
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          style: TextStyle(
            fontSize: 9,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          labelResolver: (_) => _l10nO2CellSpreadLabel,
        ),
      ),
    ];
  }

  /// Cell agreement over time, as a strip pinned to the bottom edge of the plot.
  ///
  /// Not an object floating in the chart's vertical space: that space belongs to
  /// depth, so anything drawn in it has no anchor the eye can use and reads as a
  /// slab. A rug on the edge costs no depth range, competes with nothing, and
  /// encodes the whole dive's agreement in a band you read left to right.
  ///
  /// One segment per run rather than per sample, so a steady dive is a single
  /// bar however long it is.
  List<LineChartBarData> _buildO2CellRug(MetricBand band) {
    final mvCurves = widget.o2CellMvCurves;
    if (mvCurves == null) return const [];

    final spread = _o2CellSpread(mvCurves);
    final runs = o2CellAgreementRuns(spread);
    if (runs.isEmpty) return const [];

    final y = -_o2CellRugDepth(band);
    final lastSample = widget.profile.length - 1;

    final bars = <LineChartBarData>[];
    for (final run in runs) {
      if (run.startIndex > lastSample) continue;
      final from = widget.profile[run.startIndex].timestamp.toDouble();
      final to = widget.profile[math.min(run.endIndex, lastSample)].timestamp
          .toDouble();
      bars.add(
        LineChartBarData(
          // A run of one sample would be a zero-length line and draw nothing,
          // so give it the width of one sampling interval.
          spots: [FlSpot(from, y), FlSpot(to > from ? to : from + 1, y)],
          isCurved: false,
          color: _agreementColor(run.level),
          // Exception marking: a wide gap is drawn heavier so it is visible
          // without hunting for a colour change.
          barWidth: run.level == O2CellAgreement.tight ? 3 : 6,
          isStrokeCapRound: false,
          dotData: const FlDotData(show: false),
        ),
      );
    }
    return bars;
  }

  /// Per-cell millivolt lines, drawn alongside the agreement rug: the rug
  /// reads the whole dive at a glance, the lines give the detail behind it.
  /// On an absolute scale the ppO2 swing dominates and the disagreement
  /// between cells is invisible, which is why the rug exists at all.
  List<LineChartBarData> _buildO2CellMvLines(
    MetricBand band,
    UnitFormatter units,
  ) {
    final mvCurves = widget.o2CellMvCurves;
    if (mvCurves == null) return const [];
    final range = _getMetricRange(ProfileRightAxisMetric.o2CellMv, units);
    if (range == null || range.max <= range.min) return const [];

    final lines = <LineChartBarData>[];
    for (var cell = 0; cell < mvCurves.length; cell++) {
      final curve = mvCurves[cell];
      final spots = <FlSpot>[];
      for (final i in _decimatedNullableCurveIndices(curve)) {
        final mv = curve[i]!;
        spots.add(
          FlSpot(
            widget.profile[i].timestamp.toDouble(),
            -band.map(
              mv.toDouble().clamp(range.min, range.max),
              range.min,
              range.max,
            ),
          ),
        );
      }
      if (spots.isEmpty) continue;
      lines.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: o2CellColor(cell),
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      );
    }
    return lines;
  }

  /// Build ppN2 (partial pressure of nitrogen) line
  LineChartBarData _buildPpN2Line(MetricBand band) {
    final ppN2Data = widget.ppN2Curve!;
    const ppN2Color = Colors.indigo;

    // Map ppN2 to chart: 0 at top, ~5 bar at bottom (deep dive)
    const minPpN2 = 0.0;
    const maxPpN2 = 5.0;

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(ppN2Data)) {
      final ppN2 = ppN2Data[i].clamp(minPpN2, maxPpN2);
      final yValue = band.map(ppN2, minPpN2, maxPpN2);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      // Computed, not held flat: at 1 bar ppN2 is the nitrogen fraction.
      spots: _withSurfaceLeadIn(
        spots,
        -band.map(
          _surfaceValueOf(ppN2Data.first).clamp(minPpN2, maxPpN2),
          minPpN2,
          maxPpN2,
        ),
      ),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
      color: ppN2Color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [4, 2],
    );
  }

  /// Build ppHe (partial pressure of helium) line for trimix dives
  LineChartBarData _buildPpHeLine(MetricBand band) {
    final ppHeData = widget.ppHeCurve!;
    final ppHeColor = Colors.pink.shade300;

    // Map ppHe to chart: 0 at top, ~3 bar at bottom
    const minPpHe = 0.0;
    const maxPpHe = 3.0;

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(ppHeData)) {
      final ppHe = ppHeData[i];
      if (ppHe > 0.001) {
        final clamped = ppHe.clamp(minPpHe, maxPpHe);
        final yValue = band.map(clamped, minPpHe, maxPpHe);
        spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
      }
    }

    return LineChartBarData(
      // Computed, not held flat: at 1 bar ppHe is the helium fraction. The
      // ppHe > 0.001 filter above means a non-trimix dive draws nothing at all,
      // and the lead-in is skipped with it.
      spots: _withSurfaceLeadIn(
        spots,
        -band.map(
          _surfaceValueOf(ppHeData.first).clamp(minPpHe, maxPpHe),
          minPpHe,
          maxPpHe,
        ),
      ),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
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
    for (final i in _decimatedCurveIndices(modData)) {
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
      // Held flat, and that is the calculated value: MOD is a property of the
      // gas, not of depth, so it does not change between the surface and the
      // first sample. Only a gas switch moves it.
      spots: _withFlatSurfaceLeadIn(spots),
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
  LineChartBarData _buildDensityLine(MetricBand band) {
    final densityData = widget.densityCurve!;
    const densityColor = Colors.brown;

    // Map density to chart: 0 at top, 8 g/L at bottom
    const minDensity = 0.0;
    const maxDensity = 8.0;

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(densityData)) {
      final density = densityData[i].clamp(minDensity, maxDensity);
      final yValue = band.map(density, minDensity, maxDensity);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      // Gas density scales with ambient pressure, so the surface value is
      // computed rather than held flat.
      spots: _withSurfaceLeadIn(
        spots,
        -band.map(
          _surfaceValueOf(densityData.first).clamp(minDensity, maxDensity),
          minDensity,
          maxDensity,
        ),
      ),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
      color: densityColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [5, 2],
    );
  }

  /// Build GF% (Gradient Factor percentage) line at current depth
  /// Shows how close tissues are to M-value limit
  LineChartBarData _buildGfLine(MetricBand band) {
    final gfData = widget.gfCurve!;
    const gfColor = Colors.deepPurple;

    // Map GF% to chart: 0% at top, 120% at bottom
    const minGf = 0.0;
    const maxGf = 120.0;

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(gfData)) {
      final gf = gfData[i].clamp(minGf, maxGf);
      final yValue = band.map(gf, minGf, maxGf);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(spots),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
      color: gfColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [4, 3],
    );
  }

  /// Build Surface GF% line (what GF would be if surfaced now)
  /// Values >100% indicate deco obligation
  LineChartBarData _buildSurfaceGfLine(MetricBand band) {
    final surfaceGfData = widget.surfaceGfCurve!;
    final surfaceGfColor = Colors.purple.shade300;

    // Map Surface GF% to chart: 0% at top, 150% at bottom
    const minGf = 0.0;
    const maxGf = 150.0;

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(surfaceGfData)) {
      final gf = surfaceGfData[i].clamp(minGf, maxGf);
      final yValue = band.map(gf, minGf, maxGf);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(spots),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
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
    for (final i in _decimatedCurveIndices(meanDepthData)) {
      spots.add(
        FlSpot(
          widget.profile[i].timestamp.toDouble(),
          -units.convertDepth(meanDepthData[i]),
        ),
      );
    }

    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(spots),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
      color: meanDepthColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [3, 4],
    );
  }

  /// Build TTS (Time To Surface) line
  /// Shows total time including deco stops to reach surface
  LineChartBarData _buildTtsLine(MetricBand band) {
    final ttsData = widget.ttsCurve!;
    const ttsColor = Color(
      0xFFAD1457,
    ); // Pink 800 - distinct from pressure orange

    // Map TTS to chart: 0 at top, 60 min at bottom
    const maxTtsSeconds = 3600.0;

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(ttsData)) {
      final tts = ttsData[i].toDouble().clamp(0, maxTtsSeconds);
      final normalized = tts / maxTtsSeconds;
      final yValue = band.mapNormalized(normalized);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(spots),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
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
  LineChartBarData _buildCnsLine(MetricBand band) {
    final cnsData = widget.cnsCurve!;
    const cnsColor = Color(0xFFE65100); // Orange 900

    const minCns = 0.0;
    final maxCns = _getCnsMaxScale();

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(cnsData)) {
      final cns = cnsData[i].clamp(minCns, maxCns);
      final yValue = band.map(cns, minCns, maxCns);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(spots),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
      color: cnsColor,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [6, 3],
    );
  }

  /// Build cumulative OTU line
  LineChartBarData _buildOtuLine(MetricBand band) {
    final otuData = widget.otuCurve!;
    const otuColor = Color(0xFF6D4C41); // Brown 600

    const minOtu = 0.0;
    final maxOtu = _getOtuMaxScale();

    final spots = <FlSpot>[];
    for (final i in _decimatedCurveIndices(otuData)) {
      final otu = otuData[i].clamp(minOtu, maxOtu);
      final yValue = band.map(otu, minOtu, maxOtu);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), -yValue));
    }

    return LineChartBarData(
      spots: _withFlatSurfaceLeadIn(spots),
      isCurved: true,
      curveSmoothness: 0.2,
      // Only while a lead-in is drawn: that vertex is a sharp direction
      // change and the spline would otherwise overshoot it and hook below
      // the curve at the left edge. Dives already starting at t=0 keep
      // their existing smoothing untouched.
      preventCurveOverShooting: _seriesGetsLeadIn(spots, widget.profile),
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

  /// Translucent band for the externally highlighted time range. [span] is
  /// precomputed by [_buildChart] via [highlightBandSpan]: clamped to the
  /// visible window and inflated to the 12 px minimum, so instants and short
  /// ranges render the same visible band as wide ones.
  List<VerticalRangeAnnotation> _buildHighlightRangeAnnotations(
    ({double x1, double x2})? span,
  ) {
    final range = widget.highlightRange;
    if (range == null || span == null) return [];
    return [
      VerticalRangeAnnotation(
        x1: span.x1,
        x2: span.x2,
        color: range.color.withValues(alpha: 0.12),
      ),
    ];
  }

  /// Edge lines at the highlight band's (possibly inflated) edges.
  List<VerticalLine> _buildHighlightRangeLines(({double x1, double x2})? span) {
    final range = widget.highlightRange;
    if (range == null || span == null) return [];
    return [
      for (final x in [span.x1, span.x2])
        VerticalLine(
          x: x,
          color: range.color.withValues(alpha: 0.7),
          strokeWidth: 1,
        ),
    ];
  }

  /// Build vertical lines for event markers on the dive profile.
  ///
  /// Groups events by timestamp and shows only the most severe event at each
  /// timestamp to avoid overlapping labels. Lines are colored by severity:
  /// info = primary, warning = orange, alert = red.
  /// Linearly interpolated profile depth (meters) at [timestamp] seconds.
  /// Binary search keeps this O(log n) per event, cheap enough to run on
  /// every pan/zoom rebuild.
  double _depthAtTimestamp(double timestamp) {
    final profile = widget.profile;
    if (profile.isEmpty) return 0;
    if (timestamp <= profile.first.timestamp) return profile.first.depth;
    if (timestamp >= profile.last.timestamp) return profile.last.depth;
    var lo = 0;
    var hi = profile.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (profile[mid].timestamp <= timestamp) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = profile[lo];
    final b = profile[hi];
    final span = (b.timestamp - a.timestamp).toDouble();
    if (span <= 0) return a.depth;
    final f = (timestamp - a.timestamp) / span;
    return a.depth + (b.depth - a.depth) * f;
  }

  /// Minimum pixel spacing between event lines before the less severe of the
  /// pair is dropped entirely (line and label). At phone plot widths a few
  /// seconds is sub-pixel; drawing both just paints noise.
  static const double _eventMinSpacingPx = 24;

  List<VerticalLine> _buildEventVerticalLines(
    ColorScheme colorScheme, {
    required double availableWidth,
    required double availableHeight,
    required UnitFormatter units,
    required double visibleMinX,
    required double visibleMaxX,
    required double visibleMinDepth,
    required double visibleMaxDepth,
  }) {
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

    // Plot-rect pixel geometry, mirroring the insets fl_chart reserves.
    final insets = _plotInsets(availableWidth, units);
    final plotW = (availableWidth - insets.left - insets.right).clamp(
      1.0,
      double.infinity,
    );
    final plotH = (availableHeight - insets.top - insets.bottom).clamp(
      1.0,
      double.infinity,
    );
    final rangeX = (visibleMaxX - visibleMinX).clamp(1e-9, double.infinity);
    final rangeY = (visibleMaxDepth - visibleMinDepth).clamp(
      1e-9,
      double.infinity,
    );
    double xPx(num t) => (t - visibleMinX) / rangeX * plotW;

    // Pixel-space dedupe: events landing within _eventMinSpacingPx of an
    // already kept neighbour keep only the most severe of the pair.
    final ordered = byTimestamp.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final kept = <ProfileEvent>[];
    for (final event in ordered) {
      if (kept.isNotEmpty &&
          (xPx(event.timestamp) - xPx(kept.last.timestamp)).abs() <
              _eventMinSpacingPx) {
        if (event.severity.index > kept.last.severity.index) {
          kept[kept.length - 1] = event;
        }
      } else {
        kept.add(event);
      }
    }

    // Collision-aware label placement for the events inside the visible
    // window: anchored below the profile depth at the event's time (free
    // water instead of the surface tail), flipped off the plot edges, and
    // hidden when there is genuinely no room (see placeEventLabels).
    const labelStyle = TextStyle(fontSize: 9);
    final inWindow = <int>[];
    final specs = <EventLabelSpec>[];
    for (var i = 0; i < kept.length; i++) {
      final t = kept[i].timestamp.toDouble();
      if (t < visibleMinX || t > visibleMaxX) continue;
      final painter = TextPainter(
        text: TextSpan(text: kept[i].displayName, style: labelStyle),
        // Deliberately LTR regardless of locale: fl_chart's painter lays
        // vertical-line labels out with TextDirection.ltr
        // (axis_chart_painter.dart), and this measurement must match the
        // width it will actually paint with.
        textDirection: TextDirection.ltr,
      )..layout();
      final anchorY =
          ((_depthAtTimestamp(t) - visibleMinDepth) / rangeY * plotH).clamp(
            0.0,
            plotH,
          );
      inWindow.add(i);
      specs.add(
        EventLabelSpec(
          xPx: xPx(t),
          anchorYPx: anchorY,
          textWidth: painter.width,
          textHeight: painter.height,
        ),
      );
      painter.dispose();
    }
    final placements = placeEventLabels(
      specs,
      plotWidth: plotW,
      plotHeight: plotH,
    );
    final labelByEvent = <int, (EventLabelSpec, EventLabelPlacement)>{
      for (var j = 0; j < inWindow.length; j++)
        inWindow[j]: (specs[j], placements[j]),
    };

    return [
      for (var i = 0; i < kept.length; i++)
        _eventVerticalLine(kept[i], labelByEvent[i], colorScheme),
    ];
  }

  VerticalLine _eventVerticalLine(
    ProfileEvent event,
    (EventLabelSpec, EventLabelPlacement)? label,
    ColorScheme colorScheme,
  ) {
    final spec = label?.$1;
    final placement = label?.$2;
    final color = _eventSeverityColor(event.severity, colorScheme);
    // fl_chart lays the label out inside
    // Rect.fromLTRB(x - padding.right - textWidth, padding.top,
    //               x + padding.left, ...)
    // and Alignment.topLeft draws the text with its top-left corner at
    // (rect.left, rect.top). Solving rect.left == placement.leftPx gives
    // padding.right = xPx - leftPx - textWidth, which may be negative for a
    // label centred on (or clamped across) the line - fl_chart's painter is
    // pure arithmetic, so negative padding is well-defined here. padding.top
    // is the pixel offset from the plot top; placements share that space.
    final padding = placement == null || spec == null
        ? EdgeInsets.zero
        : EdgeInsets.only(
            top: placement.topPx,
            right: spec.xPx - placement.leftPx - spec.textWidth,
          );
    return VerticalLine(
      x: event.timestamp.toDouble(),
      color: color,
      strokeWidth: 1,
      dashArray: [3, 3],
      label: VerticalLineLabel(
        show: placement?.showText ?? false,
        alignment: Alignment.topLeft,
        padding: padding,
        style: TextStyle(
          color: color,
          fontSize: 9,
          backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
        ),
        labelResolver: (line) => event.displayName,
      ),
    );
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
    MetricBand band, {
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
          band,
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
    MetricBand band, {
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
        yPosition = -band.map(marker.value!, minPressure, maxPressure);
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
      case ProfileRightAxisMetric.o2CellMv:
        return widget.o2CellMvCurves != null &&
            widget.o2CellMvCurves!.any((c) => c.any((v) => v != null));
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

  /// Memo for the o2CellMv case of [_getMetricRange], keyed by curve-list
  /// identity. That case is the only one in the switch that scans nested
  /// (cells x samples) data rather than a single flat curve, and the range is
  /// read from three call sites -- including [_plotInsets], which runs on
  /// gesture callbacks outside the normal build path -- so an unmemoized scan
  /// there repeats real work on every pan/zoom frame.
  final Map<List<List<int?>>, int> _o2CellMvMaxCache =
      HashMap<List<List<int?>>, int>.identity();

  int? _o2CellMvMax(List<List<int?>> curves) {
    final cached = _o2CellMvMaxCache[curves];
    if (cached != null) return cached;
    int? maxMv;
    for (final curve in curves) {
      for (final v in curve) {
        if (v != null && (maxMv == null || v > maxMv)) maxMv = v;
      }
    }
    if (maxMv != null) _o2CellMvMaxCache[curves] = maxMv;
    return maxMv;
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

      case ProfileRightAxisMetric.o2CellMv:
        final curves = widget.o2CellMvCurves;
        if (curves == null) return null;
        // Zero-anchored and data-driven, so levels stay comparable across
        // dives. Cells sit around 30-70 mV.
        final maxMv = _o2CellMvMax(curves);
        if (maxMv == null) return null;
        return (min: 0.0, max: maxMv * 1.2);
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
      case ProfileRightAxisMetric.o2CellMv:
        return value.toStringAsFixed(0);
    }
  }

  /// Build axis label text for the right axis (e.g. "Temp (°C)").
  String _rightAxisLabel(ProfileRightAxisMetric metric, UnitFormatter units) {
    final l10n = context.l10n;
    final name = profileMetricShortName(l10n, metric);
    final perMin = l10n.units_profileMetric_min;
    switch (metric) {
      case ProfileRightAxisMetric.temperature:
        return '$name (${units.temperatureSymbol})';
      case ProfileRightAxisMetric.pressure:
        return '$name (${units.pressureSymbol})';
      case ProfileRightAxisMetric.meanDepth:
        return '$name (${units.depthSymbol})';
      case ProfileRightAxisMetric.sac:
        return '$name (${units.pressureSymbol}/$perMin)';
      case ProfileRightAxisMetric.ascentRate:
        return '$name (${units.depthSymbol}/$perMin)';
      default:
        final suffix = profileMetricUnitSuffix(l10n, metric);
        if (suffix != null) return '$name ($suffix)';
        return name;
    }
  }
}

/// Localized display name for a right-axis metric.
///
/// [ProfileRightAxisMetric.displayName] is a hardcoded English literal baked
/// into the enum, so the axis picker rendered English under every locale.
/// The `enum_profileMetric_*` keys already ship translated.
String profileMetricName(
  AppLocalizations l10n,
  ProfileRightAxisMetric metric,
) => switch (metric) {
  ProfileRightAxisMetric.temperature => l10n.enum_profileMetric_temperature,
  ProfileRightAxisMetric.pressure => l10n.enum_profileMetric_pressure,
  ProfileRightAxisMetric.heartRate => l10n.enum_profileMetric_heartRate,
  ProfileRightAxisMetric.sac => l10n.enum_profileMetric_sacRate,
  ProfileRightAxisMetric.ascentRate => l10n.enum_profileMetric_ascentRate,
  ProfileRightAxisMetric.ndl => l10n.enum_profileMetric_ndl,
  ProfileRightAxisMetric.ppO2 => l10n.enum_profileMetric_ppO2,
  ProfileRightAxisMetric.ppN2 => l10n.enum_profileMetric_ppN2,
  ProfileRightAxisMetric.ppHe => l10n.enum_profileMetric_ppHe,
  ProfileRightAxisMetric.gasDensity => l10n.enum_profileMetric_gasDensity,
  ProfileRightAxisMetric.gf => l10n.enum_profileMetric_gf,
  ProfileRightAxisMetric.surfaceGf => l10n.enum_profileMetric_surfaceGf,
  ProfileRightAxisMetric.meanDepth => l10n.enum_profileMetric_meanDepth,
  ProfileRightAxisMetric.tts => l10n.enum_profileMetric_tts,
  ProfileRightAxisMetric.cns => l10n.enum_profileMetric_cns,
  ProfileRightAxisMetric.otu => l10n.enum_profileMetric_otu,
  ProfileRightAxisMetric.o2CellMv => l10n.enum_profileMetric_o2CellMv,
};

/// Localized short name for a right-axis metric, used on the axis itself
/// where there is only room for an abbreviation.
String profileMetricShortName(
  AppLocalizations l10n,
  ProfileRightAxisMetric metric,
) => switch (metric) {
  ProfileRightAxisMetric.temperature =>
    l10n.enum_profileMetric_temperature_short,
  ProfileRightAxisMetric.pressure => l10n.enum_profileMetric_pressure_short,
  ProfileRightAxisMetric.heartRate => l10n.enum_profileMetric_heartRate_short,
  ProfileRightAxisMetric.sac => l10n.enum_profileMetric_sacRate_short,
  ProfileRightAxisMetric.ascentRate => l10n.enum_profileMetric_ascentRate_short,
  ProfileRightAxisMetric.ndl => l10n.enum_profileMetric_ndl_short,
  ProfileRightAxisMetric.ppO2 => l10n.enum_profileMetric_ppO2_short,
  ProfileRightAxisMetric.ppN2 => l10n.enum_profileMetric_ppN2_short,
  ProfileRightAxisMetric.ppHe => l10n.enum_profileMetric_ppHe_short,
  ProfileRightAxisMetric.gasDensity => l10n.enum_profileMetric_gasDensity_short,
  ProfileRightAxisMetric.gf => l10n.enum_profileMetric_gf_short,
  ProfileRightAxisMetric.surfaceGf => l10n.enum_profileMetric_surfaceGf_short,
  ProfileRightAxisMetric.meanDepth => l10n.enum_profileMetric_meanDepth_short,
  ProfileRightAxisMetric.tts => l10n.enum_profileMetric_tts_short,
  ProfileRightAxisMetric.cns => l10n.enum_profileMetric_cns_short,
  ProfileRightAxisMetric.otu => l10n.enum_profileMetric_otu_short,
  ProfileRightAxisMetric.o2CellMv => l10n.enum_profileMetric_o2CellMv_short,
};

/// Localized unit suffix for the metrics whose unit is fixed rather than
/// taken from the diver's unit settings. Metrics that go through
/// [UnitFormatter] (temperature, pressure, mean depth, SAC, ascent rate)
/// return null: the caller appends the formatter's own symbol.
String? profileMetricUnitSuffix(
  AppLocalizations l10n,
  ProfileRightAxisMetric metric,
) => switch (metric) {
  ProfileRightAxisMetric.heartRate => l10n.units_profileMetric_bpm,
  ProfileRightAxisMetric.ndl ||
  ProfileRightAxisMetric.tts => l10n.units_profileMetric_min,
  ProfileRightAxisMetric.ppO2 ||
  ProfileRightAxisMetric.ppN2 ||
  ProfileRightAxisMetric.ppHe => l10n.units_pressure_bar,
  ProfileRightAxisMetric.gasDensity => l10n.units_profileMetric_gPerL,
  ProfileRightAxisMetric.gf ||
  ProfileRightAxisMetric.surfaceGf ||
  ProfileRightAxisMetric.cns => l10n.units_profileMetric_percent,
  _ => null,
};

/// Localized header for a metric category in the right-axis picker.
String profileMetricCategoryName(
  AppLocalizations l10n,
  ProfileMetricCategory category,
) => switch (category) {
  ProfileMetricCategory.primary => l10n.enum_profileMetricCategory_primary,
  ProfileMetricCategory.decompression =>
    l10n.enum_profileMetricCategory_decompression,
  ProfileMetricCategory.gasAnalysis =>
    l10n.enum_profileMetricCategory_gasAnalysis,
  ProfileMetricCategory.gradientFactor =>
    l10n.enum_profileMetricCategory_gradientFactor,
  ProfileMetricCategory.other => l10n.enum_profileMetricCategory_other,
};

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
              spots: [
                // Descend from the surface so the silhouette reaches the left
                // edge, matching the full chart (issue #684).
                if (shouldDrawSurfaceLeadIn(profile)) const FlSpot(0, 0),
                ...profile.map(
                  (p) => FlSpot(p.timestamp.toDouble(), -p.depth),
                ), // Negate for inverted axis
              ],
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
