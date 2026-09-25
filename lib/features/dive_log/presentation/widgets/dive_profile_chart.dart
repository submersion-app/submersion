import 'dart:collection';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/utils/gtr_format.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/data/services/gas_usage_segments_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart'
    show ProfileAnalysis;
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_surface_lead_in.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/presentation/utils/gas_consumption_tooltip.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_series_cache.dart';
import 'package:submersion/features/dive_log/presentation/widgets/chart_touch_recognizer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/deco_stop_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_legend.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_bands.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_bar_window.dart';
import 'package:submersion/features/dive_log/presentation/widgets/ascent_rate_bar_overlay.dart';
import 'package:submersion/core/constants/o2_cell_unit.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_readout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/o2_cell_spread.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_cursor_lines.dart';
import 'package:submersion/features/dive_log/presentation/widgets/partial_pressure_line_builders.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_line_builders.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_right_axis_metric_labels.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_line_builders.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_selection_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_timeline_strip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_layout.dart';
import 'package:submersion/features/dive_log/presentation/widgets/photo_marker_overlay.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_cursor_tooltip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_line_hover.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_findings_overlay.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_event_labels.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';
import 'package:submersion/core/ui/trackpad_zoom_recognizer.dart';
import 'package:submersion/features/dive_log/presentation/formatters/profile_event_label.dart';

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

/// Non-axis lines that can still be hover-highlighted and have their
/// tooltip row emphasised, even though they have no [ProfileRightAxisMetric]
/// of their own: they are drawn at their real depth rather than stretched
/// across a banded scale (issue #2228 follow-up), so they never drive the
/// right axis, but that is no reason to leave them out of the same
/// hover-highlight/bold-row treatment every axis-driven metric gets.
enum ChartOnlyMetric { ceiling, decoStop, mod, depth }

/// Which of the three mutually exclusive ways [DiveProfileChart] shows the
/// touched/hovered sample's readout.
enum TooltipPresentation {
  /// The default: a custom, cursor-following box drawn as a chart overlay
  /// ([ProfileCursorTooltip]), clamped to the plot rect.
  inChart,

  /// fl_chart's own built-in tooltip bubble (dark, positioned above the
  /// chart box by fl_chart itself, not clipped to the plot rect) instead of
  /// [inChart]'s [ProfileCursorTooltip]. This is the pre-issue-#2228
  /// in-chart presentation, restored for the dive detail page's embedded
  /// chart specifically: it needs the box to land in exactly the same place
  /// it always has, not a new approximation of that placement. The
  /// fullscreen page keeps [inChart].
  nativeBubble,

  /// The built-in tooltip is suppressed; tooltip data is emitted via
  /// [DiveProfileChart.onTooltipData] instead, so callers can render it
  /// externally (e.g. below the chart in the profile panel).
  external,
}

/// One drawn bar together with the metric it represents (a
/// [ProfileRightAxisMetric], a [ChartOnlyMetric], an [O2CellMetric], or null
/// for a bar with no matching metric at all), so the two can never drift
/// out of positional sync the way two separately-built, equal-length lists
/// could.
typedef BarWithTag = ({LineChartBarData bar, Object? tag});

/// Pairs every bar in [bars] with the same [tag] -- the common case behind
/// most [BarWithTag] groups, where a whole line-builder's output shares one
/// metric identity.
List<BarWithTag> _tagAll(List<LineChartBarData> bars, Object? tag) => [
  for (final bar in bars) (bar: bar, tag: tag),
];

/// One physical O2 sensor's millivolt line/tooltip row (issue #2228
/// follow-up). All cells previously shared the single
/// [ProfileRightAxisMetric.o2CellMv] tag, so hovering any one cell's line
/// highlighted every cell's line and bolded every "Sensor N" row at once --
/// this identifies each cell individually instead. The touch callback still
/// maps it back to [ProfileRightAxisMetric.o2CellMv] for the right-axis
/// switch, since that part should still happen the same as for any other
/// o2CellMv line.
class O2CellMetric {
  final int cell;
  const O2CellMetric(this.cell);

  @override
  bool operator ==(Object other) => other is O2CellMetric && other.cell == cell;

  @override
  int get hashCode => cell.hashCode;
}

/// Structured row emitted via [DiveProfileChart.onTooltipData] so callers
/// can render the tooltip externally (e.g., below the chart).
class TooltipRow {
  final String label;
  final String value;
  final Color bulletColor;

  /// True for a photo/depth/pressure-threshold marker row: rendered with a
  /// diamond bullet instead of every other row's circle, so it stands out
  /// among several stacked metric rows (matches this chart's pre-#2228
  /// native-bubble rendering).
  final bool diamondBullet;

  /// The metric this row reads from -- a [ProfileRightAxisMetric] or a
  /// [ChartOnlyMetric] -- or null for a row with no line identity of its
  /// own (Time, an overlay comparison row, ...). Lets a tooltip presentation
  /// emphasise the row matching whichever line is currently
  /// hover-highlighted, the same identity [lineMetricTags] tags each bar
  /// with.
  final Object? metric;

  const TooltipRow({
    required this.label,
    required this.value,
    required this.bulletColor,
    this.diamondBullet = false,
    this.metric,
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
    this.analysis,
    this.tintByMetric = true,
  });

  final String sourceId;
  final String name;

  /// The source's identity colour (source-bar chip, tank rings). Traces only
  /// use it directly when [tintByMetric] is false.
  final Color color;
  final String? computerId;
  final List<DiveProfilePoint> points;

  /// When true (the default for overlaid dive computers) every trace is drawn
  /// in a lighter tint of its metric's own colour via [overlayTint], so the
  /// metric stays recognisable across computers. Set false for overlays that
  /// are a different thing entirely (a planned profile), which keep [color].
  final bool tintByMetric;

  /// This source's own computed analysis (NDL/ceiling/deco stops/etc, index-
  /// aligned with [points]), driving every overlay curve except depth and
  /// temperature, which are read straight off [points]. Null while still
  /// loading.
  final ProfileAnalysis? analysis;
}

class DiveProfileChart extends ConsumerStatefulWidget {
  final List<DiveProfilePoint> profile;
  final Duration? diveDuration;
  final double? maxDepth;
  final bool showTemperature;
  final bool showPressure;
  final void Function(int? index)? onPointSelected;

  /// Dive time in seconds under the cursor, reported with every
  /// [onPointSelected]: the selected sample's timestamp, or 0 on the surface
  /// lead-in vertex before the first sample (which has no profile index).
  /// Null when the selection clears.
  final void Function(int? seconds)? onTimeSelected;

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

  /// Owning dive computer's colour for each tank id, on multi-source dives
  /// only. Forwarded to [ProfileLegendConfig] so the Cylinders / Tank
  /// Pressures rows can mark which computer a tank belongs to.
  final Map<String, Color>? tankSourceColors;

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

  /// Width of the border fl_chart draws around the plot. fl_chart lays the
  /// plot out inside it, so it counts toward the plot insets.
  static const double _plotBorderWidth = 1.0;

  /// How much thicker the hovered/touched metric line is drawn than its
  /// neighbours (issue #2228 follow-up: hover-highlight + axis auto-switch).
  /// A small, deliberately subtle bump -- not meant to dominate the chart.
  static const double hoverHighlightBarWidthDelta = 1.0;

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

  /// Whether step-through playback is currently auto-advancing
  /// [highlightedTimestamp]. While true, the in-chart cursor tooltip
  /// ([TooltipPresentation.inChart]) follows the playback position instead
  /// of the mouse, since the pointer sitting still somewhere else must not
  /// keep the tooltip pinned to a stale sample while the playback line
  /// sweeps past it. Regains the mouse's own position as soon as this turns
  /// false (paused or stopped).
  final bool playbackIsPlaying;

  /// Optional time range to emphasize (e.g. the selected safety finding).
  /// Renders as a translucent vertical band with edge lines; short and
  /// instant ranges inflate to a minimum on-screen width.
  final ProfileHighlightRange? highlightRange;

  /// Ranges drawn as plain bands behind [highlightRange], without edge
  /// lines, and only while the O2 cell overlay is on: the cell divergence
  /// runs from the dive's sensor summary (condition phase 2).
  final List<ProfileHighlightRange> secondaryRanges;

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

  /// Range-statistics selection in seconds from the start of the dive, or
  /// null when range mode is off. Drawn as draggable handles over the plot
  /// rect; [maxSeconds] is the profile's last timestamp, where the end
  /// handle stops.
  final ({int startSeconds, int endSeconds, int maxSeconds})? rangeSelection;

  /// New range reported while a handle is dragged.
  final void Function(int startSeconds, int endSeconds)? onRangeChanged;

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

  /// Gas time remaining curve in seconds; a null sample is a blank (the
  /// line breaks there rather than dropping to zero)
  final List<int?>? gtrCurve;

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

  /// Which of the three mutually exclusive tooltip presentations this chart
  /// uses. See [TooltipPresentation].
  final TooltipPresentation tooltipPresentation;

  /// Called with structured tooltip row data whenever a point is touched,
  /// while [tooltipPresentation] is [TooltipPresentation.external] -- the
  /// dive-list panel's own fixed-below overlay is the only consumer, since
  /// the in-chart tooltip presentations render themselves. Null clears it
  /// (an active touch ending).
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

  /// Column widths for [tooltipRowText], used by this widget's own native
  /// bubble ([TooltipPresentation.nativeBubble]) to align its monospace
  /// label/value columns.
  static const tooltipLabelChars = 8;
  static const tooltipValueChars = 16;

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
    this.onTimeSelected,
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
    this.tankSourceColors,
    this.gasSegments,
    this.diveDurationSeconds,
    this.exportKey,
    this.playbackTimestamp,
    this.highlightedTimestamp,
    this.playbackIsPlaying = false,
    this.highlightRange,
    this.secondaryRanges = const [],
    this.safetyFindings,
    this.selectedSafetyFindingId,
    this.onSafetyFindingTap,
    this.onSafetyFindingDismiss,
    this.onSafetyFindingDetails,
    this.rangeSelection,
    this.onRangeChanged,
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
    this.gtrCurve,
    this.cnsCurve,
    this.otuCurve,
    this.overlays,
    this.activeComputerId,
    this.computerNames,
    this.tooltipPresentation = TooltipPresentation.inChart,
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

  /// Whether the app's own computed events are drawn (issue #1523). Synced
  /// from the legend provider in [build]; seeded off for dives that carry the
  /// computer's own events.
  bool _showComputedEvents = true;

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
  bool _showO2Cells = false;
  O2CellUnit _o2CellUnit = O2CellUnit.ppO2;
  bool _showMod = false;
  bool _showDensity = false;
  bool _showGf = false;
  bool _showSurfaceGf = false;
  bool _showMeanDepth = false;
  bool _showTts = false;
  bool _showGtr = false;
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
  /// dive_profile_series, dive_profile_events and tank_pressure_series rows;
  /// see database.dart) or the active source's own computer always draws.
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
    final index = _overlayIndexAt(overlay, timestamp);
    return index == null ? null : overlay.points[index];
  }

  /// Index into [overlay.points] (and, since it is computed from those same
  /// points, into any curve on [overlay.analysis]) nearest [timestamp],
  /// within 10 seconds; null when the overlay has no sample near that time
  /// (e.g. the overlaid computer surfaced earlier). Overlay points are
  /// time-ordered, so a binary-search lower bound finds the window start and
  /// only its immediate neighborhood is scanned (tooltips rebuild on every
  /// hover move, so this must not be O(n) in profile length).
  int? _overlayIndexAt(ChartSourceOverlay overlay, int timestamp) {
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

    int? best;
    var bestDelta = 11;
    for (var i = lo; i < points.length; i++) {
      final p = points[i];
      if (p.timestamp > timestamp + 10) break;
      final delta = (p.timestamp - timestamp).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = i;
      }
    }
    return best;
  }

  /// Trace colour for [overlay]'s rendering of a metric the active source
  /// draws in [base]: a lighter tint of [base] for overlaid computers, or the
  /// overlay's own identity colour when it opted out of tinting.
  Color _overlayColor(ChartSourceOverlay overlay, Color base) {
    if (!overlay.tintByMetric) return overlay.color;
    final index = widget.overlays?.indexOf(overlay) ?? 0;
    return overlayTint(base, index < 0 ? 0 : index);
  }

  /// Shared tooltip-row builder for overlay curves that are a simple
  /// per-point `List<T>` on [ChartSourceOverlay.analysis] -- ppO2/ppN2/ppHe,
  /// MOD, density, GF%, surface GF%, mean depth, CNS%, OTU. Reads the
  /// overlay's own resolved value at [timestamp] directly (no lead-in
  /// reinterpretation, matching the ceiling/NDL/TTS overlay rows this
  /// mirrors); [skip] filters out samples the primary row also hides (e.g.
  /// ppHe below the trimix threshold). GTR is not built through this: its
  /// curve is nullable per-point and needs the primary row's bespoke
  /// gap/format handling.
  List<TooltipRow> _overlayCurveRows<T extends num>({
    required int timestamp,
    required List<T>? Function(ProfileAnalysis) curveOf,
    required String label,
    required Color color,
    required String Function(T) formatValue,
    bool Function(T)? skip,
  }) {
    final rows = <TooltipRow>[];
    for (final overlay in widget.overlays ?? const <ChartSourceOverlay>[]) {
      final analysis = overlay.analysis;
      if (analysis == null) continue;
      final idx = _overlayIndexAt(overlay, timestamp);
      if (idx == null) continue;
      final curve = curveOf(analysis);
      if (curve == null || idx >= curve.length) continue;
      final value = curve[idx];
      if (skip != null && skip(value)) continue;
      rows.add(
        TooltipRow(
          label: '$label · ${overlay.name}',
          value: formatValue(value),
          bulletColor: _overlayColor(overlay, color),
        ),
      );
    }
    return rows;
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

  // Zoom/pan state; see core/ui/chart_viewport.dart.
  ChartViewport _viewport = ChartViewport.reset;

  // Measured height of the legend row above the plot, so the in-chart
  // cursor tooltip knows how much further it may grow upward -- past the
  // plot's own top edge, into the legend -- before its text has to start
  // shrinking (issue #2228 follow-up). Read after each frame rather than
  // computed, since the legend wraps to a second row once enough metrics
  // are active, and its real height is not otherwise known ahead of layout.
  final _legendKey = GlobalKey();
  double _legendHeight = 0;

  void _measureLegendHeight() {
    final height = _legendKey.currentContext?.size?.height;
    if (height != null && height != _legendHeight) {
      setState(() => _legendHeight = height);
    }
  }

  // Snapshot of the viewport at the start of a continuous gesture; continuous
  // gestures report cumulative scale/pan, so we apply them against this.
  ChartViewport _gestureStartViewport = ChartViewport.reset;

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

  // True while a range-selection handle is being dragged. The handle's
  // recognizer wins the arena, but this Listener sees the same pointer
  // moves (it is an ancestor), so without this the chart would pan under
  // the handle. Only event handlers read it, so no rebuild is needed.
  bool _rangeDragActive = false;

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
  bool _lastHoverOnLeadIn = false;

  // Whether fl_chart's touch callback resolved a sample for the pointer's
  // latest event. It runs before the pointer-hover fallback for the same
  // event, and its sample is the one the tooltip and focus dot show.
  bool _chartTouchSelecting = false;

  // Last raw pointer position during a drag; used to compute per-move deltas
  // in the Listener.onPointerMove mouse-pan path (bypasses gesture arena).
  Offset? _lastPointerLocal;

  // Number of pointers currently down. onPointerMove only pans for a genuine
  // single-pointer drag, so a multi-finger touch never leaks into the pan path
  // (this is what keeps Task 7's double-tap-hold pan single-finger-only).
  int _activePointerCount = 0;

  // Rows for the in-chart cursor tooltip ([ProfileCursorTooltip]), the
  // [TooltipPresentation.inChart] path's counterpart to onTooltipData.
  // Populated from the same shared row builder as onTooltipData
  // ([_buildTooltipRowsForIndex]), via the touch callback below, and cleared
  // on touch end.
  List<TooltipRow> _liveCursorTooltipRows = const [];

  // Memoizes the native bubble's getTooltipItems result
  // ([TooltipPresentation.nativeBubble]) so a pointer sitting still over the
  // same sample -- fl_chart calls this on
  // every touch/hover event, including repeated ones with nothing changed --
  // rebuilds nothing. Keyed on everything the built rows/styling actually
  // depend on: the resolved sample, whether it's the surface lead-in vertex,
  // and which metric renders bold (added after this cache existed originally,
  // so it must invalidate the cache too, or hovering a different line at the
  // same sample would keep showing a stale bold row).
  int? _lastTooltipSpotIndex;
  bool _lastTooltipOnLeadIn = false;
  Object? _lastTooltipHighlightedMetric;
  List<LineTooltipItem?> _lastTooltipItems = const [];

  // Transient, non-persisted right-axis override: which metric's line is
  // currently under the cursor/touch, so the axis briefly shows that
  // metric's scale instead of the persisted preference (issue #2228
  // follow-up). Null reverts the axis to [ProfileLegendState
  // .getEffectiveRightAxisMetric]. Never written back to the provider --
  // purely a per-frame visual state, reset whenever the touch/hover leaves
  // every tagged line (see [lineMetricTags] and the touchCallback below).
  ProfileRightAxisMetric? _hoverRightAxisMetric;

  // barIndex (into the same list handed to lineBarsData, pre- or
  // post-window -- windowing keeps a 1:1 index correspondence, see
  // [_windowedBars]) of the line currently drawn slightly thicker because
  // the cursor/touch is nearest to it. Null draws every line at its normal
  // width.
  int? _hoverHighlightedBarIndex;

  // The metric (a [ProfileRightAxisMetric] or a [ChartOnlyMetric])
  // [_hoverHighlightedBarIndex]'s line is tagged with, kept alongside it
  // since [_hoverRightAxisMetric] only ever holds an axis-driving metric --
  // a highlighted [ChartOnlyMetric] line (ceiling, deco stop, MOD) would
  // otherwise have no way to tell the matching tooltip row to render bold
  // too (see [_highlightedTooltipMetric]).
  Object? _hoverHighlightedMetric;

  // The touched/hovered sample's timestamp, for AscentRateBarOverlay to light
  // up its own nearest bar -- ascent-rate bars have no fl_chart line of their
  // own, so they cannot participate in [_hoverHighlightedBarIndex] above.
  int? _hoveredAscentRateTimestamp;

  // Profile index of the touched/hovered sample, for a custom-drawn deco
  // stop focus dot. The deco stop band's own fl_chart spots are compressed
  // to its step transitions (see buildDecoStopBand), so fl_chart's built-in
  // touched-spot indicator is suppressed for that bar (getTouchedSpotIndicator
  // below) and this dot is drawn independently instead, positioned from the
  // resolved touch like [_hoveredAscentRateTimestamp] rather than from the
  // bar's own (too sparse) spots.
  int? _decoStopTouchIndex;

  // The metric whose tooltip row should render emphasised (issue #2228
  // follow-up): [_hoverHighlightedMetric] for a tagged line (axis-driving or
  // not), or [ProfileRightAxisMetric.ascentRate] when the ascent-rate bars
  // are lit up instead (they have no line of their own to tag, see
  // [_hoveredAscentRateTimestamp]). Read by both tooltip presentations
  // (the native bubble's getTooltipItems and [ProfileCursorTooltip]) against
  // each [TooltipRow.metric].
  Object? get _highlightedTooltipMetric =>
      _hoverHighlightedMetric ??
      (_hoveredAscentRateTimestamp != null
          ? ProfileRightAxisMetric.ascentRate
          : null);

  /// Drops the cursor-following tooltip and the hover-driven highlight/axis
  /// override. Called from every place a pointer stops actively hovering the
  /// chart (mouse exit, pointer up, pointer cancel) -- each of these used to
  /// only need to reset pan/gesture bookkeeping, before this state existed,
  /// so unlike [Listener.onPointerMove] they do not already run inside a
  /// `setState`; skip the call entirely when nothing would actually change,
  /// so a plain pointer-up on a chart that was never hovered does not force
  /// an unnecessary rebuild.
  void _clearCursorHoverState() {
    if (_lastPointerLocal == null &&
        _liveCursorTooltipRows.isEmpty &&
        _hoverRightAxisMetric == null &&
        _hoverHighlightedBarIndex == null &&
        _hoverHighlightedMetric == null &&
        _hoveredAscentRateTimestamp == null &&
        _decoStopTouchIndex == null) {
      return;
    }
    setState(() {
      _lastPointerLocal = null;
      _liveCursorTooltipRows = const [];
      _hoverRightAxisMetric = null;
      _hoverHighlightedBarIndex = null;
      _hoverHighlightedMetric = null;
      _hoveredAscentRateTimestamp = null;
      _decoStopTouchIndex = null;
    });
  }

  // A bar the each group's `_barsCache.series` factory builds is always
  // paired with its metric tag directly (see `BarWithTag` and the 'base'
  // group in [_buildChart]), rather than the pairing being maintained by
  // convention across two separately-built, equal-length lists -- a bar
  // added to one without its matching tag would otherwise silently misalign
  // every tag after it. The tag is a [ProfileRightAxisMetric] for a line
  // that can drive the right axis, a [ChartOnlyMetric] for one that cannot
  // (real-depth lines with no axis of their own, still worth highlighting),
  // or null when the bar has no matching metric at all (a marker, an
  // overlay comparison trace, or ascent-rate -- which is drawn by
  // [AscentRateBarOverlay], never an fl_chart line).

  // The readout last reported through onTooltipData, by either cursor. Lets
  // the external-cursor path skip a reading the pointer already reported,
  // which is every sample on a chart that feeds its own selection back in as
  // highlightedTimestamp (the detail panel).
  //
  // Carries the lead-in flag, not just the index: on a profile whose first
  // sample sits one interval in, the synthetic surface vertex and that first
  // sample are BOTH index 0 but read differently (t=0 at the surface versus
  // the sample's own time and depth). Keyed on the index alone, the crossing
  // from one to the other would be swallowed and the card would sit at 0:00
  // until the second sample.
  ({int index, bool onLeadIn})? _lastEmittedCursor;

  // Depth-band touched spots whose built-in focus indicator is hidden, so
  // velocity colouring shows a single depth dot instead of one per band.
  // Set from the touch response in the LineTouchData touchCallback and read by
  // getTouchedSpotIndicator during paint. See [velocityIndicatorSuppression].
  List<({double x, double y})> _suppressedDepthIndicatorSpots = const [];

  // The spots of the latest touch response. fl_chart keeps each touched
  // spot's index across rebuilds, and once the series under it is re-cut (a
  // pan, see [_windowedBars]) or re-decimated that index names a different
  // sample; getTouchedSpotIndicator only draws a marker whose spot is still
  // one of these.
  List<({double x, double y})> _touchedIndicatorSpots = const [];

  // The bars last handed to fl_chart, cut to the visible window when zoomed,
  // and the inputs they were cut for (see [_windowedBars]).
  WindowedBars _barWindow = const WindowedBars([], []);
  List<LineChartBarData>? _barWindowSource;
  ({double minX, double maxX, double minY})? _barWindowRange;

  // Memoized lineBarsData, each paired with its metric tag (see BarWithTag).
  // The chart's series builders are pure w.r.t. interaction state, so the
  // assembled bars are reused across playback / hover / zoom rebuilds and
  // only reconstructed when the underlying data, units, visibility, or
  // theme change (see [_barsSignature]).
  final ChartSeriesCache<BarWithTag> _barsCache =
      ChartSeriesCache<BarWithTag>();

  // The flattened, windowable bars behind the same 'combined' group as
  // [_barsCache] -- kept in its own cache, rather than derived from
  // [_barsCache]'s cached pairs on every build, so it is the identical List
  // instance across a cache hit (a fresh `[for (p in pairs) p.bar]` would
  // not be, defeating [_windowedBars]'s own identical()-based memoization).
  final ChartSeriesCache<LineChartBarData> _flatBarsCache =
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
  final Map<List<num?>, List<int>> _decimatedNullableIndicesCache =
      HashMap<List<num?>, List<int>>.identity();

  /// Indices of [curve] to render: gaps excluded before decimation ever sees
  /// them (envelope decimation has no "this doesn't count" input, so a
  /// present-only view is the only way to keep it from treating a gap as a
  /// value), then decimated to [_curvePointBudget] over the same
  /// visible-window slice [_decimatedCurveIndices] uses.
  List<int> _decimatedNullableCurveIndices(List<num?> curve) =>
      _decimatedNullableIndicesCache.putIfAbsent(
        curve,
        () => _computeDecimatedNullableCurveIndices(curve),
      );

  List<int> _computeDecimatedNullableCurveIndices(List<num?> curve) {
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

  /// Overlay variant of [_decimatedCurveIndices] for a computed analysis
  /// curve (ceiling/NDL/TTS/etc), rather than a raw [DiveProfilePoint] field.
  /// [curve] must be index-aligned with the overlay's own points -- true for
  /// every curve on [ChartSourceOverlay.analysis], which is computed FROM
  /// those same points. Budget-only, like [_decimatedOverlayIndices].
  List<int> _decimatedOverlayCurveIndices<T extends num>(List<T> curve) {
    if (curve.length <= _curvePointBudget) {
      return List<int>.generate(curve.length, (i) => i);
    }
    return decimateSeriesIndices([
      for (final v in curve) v.toDouble(),
    ], targetPoints: _curvePointBudget);
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
    _scheduleComputedEventsSeed();
  }

  @override
  void didUpdateWidget(covariant DiveProfileChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final profileChanged = oldWidget.profile != widget.profile;
    if (profileChanged) {
      _liveCursorTooltipRows = const [];
      _lastTooltipSpotIndex = null;
      _lastTooltipItems = const [];
    }
    if (oldWidget.tankPressures != widget.tankPressures) {
      _scheduleTankPressureVisibilityInitialization();
    }
    if (oldWidget.events != widget.events) {
      _scheduleComputedEventsSeed();
    }
    // The external cursor reports when it moves, and again when the profile
    // under a stationary cursor is replaced: switching source keeps the
    // timestamp but changes which reading it names, so the card would
    // otherwise keep describing the source the user just switched away from.
    // Gated on having reported something already, so a chart whose cursor is
    // merely carried over (the detail panel's shared tracking index) does not
    // open its tooltip on a source switch the user did not scrub.
    final hadReadout = _lastEmittedCursor != null;
    if (profileChanged) _lastEmittedCursor = null;
    if (oldWidget.highlightedTimestamp != widget.highlightedTimestamp ||
        (profileChanged && hadReadout)) {
      _scheduleCursorReadout();
    }
  }

  /// Report the sample under the external cursor through
  /// [DiveProfileChart.onTooltipData].
  ///
  /// The cursor is whatever moves [DiveProfileChart.highlightedTimestamp]:
  /// playback's ticker and the fullscreen minimap scrubber both do, and before
  /// issue #2180 neither reached the readout, so its values sat frozen on the
  /// last hovered sample while the cursor line swept the dive.
  ///
  /// Post-frame because the consumer rebuilds on these rows, and this runs
  /// inside the parent's own build pass. Emitting only on a changed sample
  /// keeps a chart whose cursor follows its own touch (the detail panel, which
  /// feeds its tracking index straight back in) from reporting the same sample
  /// twice per scrub tick.
  ///
  /// A cleared cursor emits nothing rather than null: null means "no reading"
  /// and empties the panel's tooltip, whereas a paused or released cursor
  /// should leave the last values standing.
  void _scheduleCursorReadout() {
    if (widget.tooltipPresentation != TooltipPresentation.external ||
        widget.onTooltipData == null) {
      return;
    }
    final timestamp = widget.highlightedTimestamp;
    if (timestamp == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Re-read: several cursor moves can coalesce into one frame, and only
      // the position the chart actually painted should be reported.
      final current = widget.highlightedTimestamp;
      if (current == null) return;
      final index = indexForTimestamp(widget.profile, current);
      if (index == null) return;
      final onLeadIn =
          current < widget.profile.first.timestamp &&
          shouldDrawSurfaceLeadIn(widget.profile);
      final last = _lastEmittedCursor;
      if (last != null && last.index == index) {
        // Same sample: only a change of lead-in state is worth restating,
        // and not even that while the pointer is the thing that selected it.
        // A chart that echoes its own selection back as the cursor (the
        // detail panel, via its shared tracking index) can only echo a
        // sample's timestamp, which for the synthetic surface vertex is the
        // FIRST SAMPLE's timestamp; resolving that echo would overwrite the
        // pointer's correct 0:00 surface rows with the first sample's.
        if (last.onLeadIn == onLeadIn || _chartTouchSelecting) return;
      }
      _emitTooltipRowsForIndex(
        index,
        onLeadIn: onLeadIn,
        units: UnitFormatter(ref.read(settingsProvider)),
        colorScheme: Theme.of(context).colorScheme,
      );
    });
  }

  /// The in-chart cursor tooltip's rows and position for the current
  /// playback timestamp, used in place of the mouse-driven `_lastPointerLocal`
  /// / `_liveCursorTooltipRows` while [DiveProfileChart.playbackIsPlaying] is
  /// true.
  ///
  /// Mirrors the pixel geometry used elsewhere to place overlays at a given
  /// timestamp (e.g. `_buildEventVerticalLines`'s `xPx`/`anchorY`): a
  /// timestamp and the depth curve's value at it convert to the same
  /// Stack-local coordinate space [ProfileCursorTooltip.cursorLocal] expects.
  /// Returns null when there's nothing to show -- no highlighted timestamp,
  /// no matching sample, or it currently sits outside the visible (zoomed)
  /// window.
  ({Offset cursorLocal, List<TooltipRow> rows})? _playbackCursorTooltipData({
    required ({double left, double top, double right, double bottom})
    plotInsets,
    required double availableWidth,
    required double availableHeight,
    required double visibleMinX,
    required double visibleMaxX,
    required double visibleMinDepth,
    required double visibleMaxDepth,
  }) {
    final timestamp = widget.highlightedTimestamp;
    if (timestamp == null ||
        timestamp < visibleMinX ||
        timestamp > visibleMaxX) {
      return null;
    }
    final index = indexForTimestamp(widget.profile, timestamp);
    if (index == null) return null;
    final onLeadIn =
        timestamp < widget.profile.first.timestamp &&
        shouldDrawSurfaceLeadIn(widget.profile);
    final units = UnitFormatter(ref.read(settingsProvider));
    final rows = _buildTooltipRowsForIndex(
      index,
      onLeadIn: onLeadIn,
      units: units,
      colorScheme: Theme.of(context).colorScheme,
    );
    if (rows.isEmpty) return null;

    final plotWidth = (availableWidth - plotInsets.left - plotInsets.right)
        .clamp(1.0, double.infinity);
    final plotHeight = (availableHeight - plotInsets.top - plotInsets.bottom)
        .clamp(1.0, double.infinity);
    final rangeX = (visibleMaxX - visibleMinX).clamp(1e-9, double.infinity);
    final rangeY = (visibleMaxDepth - visibleMinDepth).clamp(
      1e-9,
      double.infinity,
    );
    // visibleMinDepth/visibleMaxDepth are in the diver's display unit (see
    // _totalMaxDepth), but _depthAtTimestamp reads DiveProfilePoint.depth
    // directly, which is always meters -- converting here is what keeps an
    // imperial-unit diver's playback cursor landing at the right height
    // instead of a raw-meters value plotted against a feet-scaled range.
    final depth = units.convertDepth(_depthAtTimestamp(timestamp.toDouble()));
    final x = plotInsets.left + (timestamp - visibleMinX) / rangeX * plotWidth;
    final y = plotInsets.top + (depth - visibleMinDepth) / rangeY * plotHeight;
    return (cursorLocal: Offset(x, y), rows: rows);
  }

  void _scheduleTankPressureVisibilityInitialization() {
    if (!_hasMultiTankPressure) return;
    final tankIds = widget.tankPressures!.keys.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || tankIds.isEmpty) return;
      ref.read(profileLegendProvider.notifier).initializeTankPressures(tankIds);
    });
  }

  /// Whether this dive carries the computer's own (imported) events.
  bool get _diveHasImportedEvents =>
      widget.events?.any((e) => e.source == EventSource.imported) ?? false;

  /// Seed the legend's "Computed events" toggle from this dive: hidden when the
  /// dive carries the computer's own events, shown otherwise (issue #1523). The
  /// chart's own first paint already reflects this (see [build]); the post-frame
  /// hop keeps the shared provider -- and the legend checkbox -- in step.
  void _scheduleComputedEventsSeed() {
    final events = widget.events;
    if (events == null || events.isEmpty) return;
    final hasImported = _diveHasImportedEvents;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(profileLegendProvider.notifier)
          .seedComputedEventsVisibility(diveHasImportedEvents: hasImported);
    });
  }

  void _resetZoom() {
    setState(() => _viewport = ChartViewport.reset);
  }

  /// Resolve a touch callback's touched spots to the profile's global
  /// sample index and whether that sample is the synthetic surface lead-in
  /// vertex, or null when no touched spot lands on the depth line.
  ///
  /// The depth line may be split into per-band bars (velocity colouring), so
  /// a touched spot's spotIndex is local to its bar; [starts] is the start
  /// index of each bar (see [_depthBarStartIndices]). Shared by the touch
  /// callback's own selection reporting and the in-chart cursor tooltip.
  ({int index, bool onLeadIn})? _resolveDepthTouch(
    List<LineBarSpot> spots,
    List<int> starts,
  ) {
    final depthBarCount = starts.length;
    final depthSpot = spots
        .where((s) => s.barIndex < depthBarCount)
        .firstOrNull;
    if (depthSpot == null) return null;
    final index = DiveProfileChart.depthSpotProfileIndex(
      profile: widget.profile,
      depthBarStarts: starts,
      barIndex: depthSpot.barIndex,
      spotIndex: _sourceSpotIndex(depthSpot),
      spotX: depthSpot.x,
      multiComputer: false,
    );
    if (index < 0 || index >= widget.profile.length) return null;
    final onLeadIn =
        _sourceSpotIndex(depthSpot) == 0 &&
        starts[depthSpot.barIndex] < 0 &&
        shouldDrawSurfaceLeadIn(widget.profile);
    return (index: index, onLeadIn: onLeadIn);
  }

  /// Build and emit [TooltipRow] data for external rendering when
  /// [DiveProfileChart.tooltipPresentation] is [TooltipPresentation.external].
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
        : math.max(0, starts[touched.barIndex] + _sourceSpotIndex(touched));
    if (touched == null || index < 0 || index >= widget.profile.length) {
      _lastEmittedCursor = null;
      widget.onTooltipData!(null);
      return;
    }
    // On the lead-in vertex the cursor is before the first sample, so the
    // readout must describe t=0 rather than repeat the first sample's values.
    _emitTooltipRowsForIndex(
      index,
      onLeadIn:
          _sourceSpotIndex(touched) == 0 &&
          starts[touched.barIndex] < 0 &&
          shouldDrawSurfaceLeadIn(widget.profile),
      units: units,
      colorScheme: colorScheme,
    );
  }

  /// Build and emit the readout rows describing profile sample [index].
  ///
  /// Shared by both cursors that can drive the external readout: a pointer on
  /// the chart (via [_emitExternalTooltip]) and the external
  /// [DiveProfileChart.highlightedTimestamp], which is what playback and the
  /// fullscreen minimap move (issue #2180). One row builder for both is what
  /// keeps a played-back dive and a hand-scrubbed one reading identically.
  ///
  /// [onLeadIn] marks the synthetic surface vertex drawn before the first
  /// sample: the rows then describe t=0 and are flagged as interpolated,
  /// rather than repeating the first sample's values.
  void _emitTooltipRowsForIndex(
    int index, {
    required bool onLeadIn,
    required UnitFormatter units,
    required ColorScheme colorScheme,
  }) {
    if (widget.onTooltipData == null) return;
    _lastEmittedCursor = (index: index, onLeadIn: onLeadIn);
    widget.onTooltipData!(
      _buildTooltipRowsForIndex(
        index,
        onLeadIn: onLeadIn,
        units: units,
        colorScheme: colorScheme,
      ),
    );
  }

  /// `curve[index]` if in range, else null -- the "does this sample have a
  /// reading" lookup every curve-backed tooltip row in
  /// [_buildTooltipRowsForIndex] starts from, replacing that method's
  /// repeated `final hasX = curve != null && index < curve!.length;` guard.
  static T? _curveValueAt<T>(List<T>? curve, int index) =>
      curve != null && index < curve.length ? curve[index] : null;

  /// Build the readout rows describing profile sample [index], without
  /// emitting them anywhere.
  ///
  /// The single row builder behind all in-chart and external tooltip
  /// consumers: the [DiveProfileChart.onTooltipData] external readout (via
  /// [_emitTooltipRowsForIndex]), the cursor-following in-chart tooltip
  /// ([ProfileCursorTooltip], via the touch callback below), and
  /// [TooltipPresentation.nativeBubble]'s own `getTooltipItems` below.
  /// Keeping one builder is what keeps a played-back dive and a
  /// hand-scrubbed one, and every tooltip presentation, reading identically.
  ///
  /// [onLeadIn] marks the synthetic surface vertex drawn before the first
  /// sample: the rows then describe t=0 and are flagged as interpolated,
  /// rather than repeating the first sample's values.
  List<TooltipRow> _buildTooltipRowsForIndex(
    int index, {
    required bool onLeadIn,
    required UnitFormatter units,
    required ColorScheme colorScheme,
  }) {
    final spot = (spotIndex: index);
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
          bulletColor: _overlayColor(overlay, ProfileMetricColors.depth),
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
          metric: ProfileRightAxisMetric.temperature,
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
            bulletColor: _overlayColor(overlay, colorScheme.tertiary),
          ),
        );
      }
    }

    // Ceiling (always shown once enabled, even where the curve has no data
    // for this sample -- a toggled-on row disappearing entirely reads as the
    // toggle having silently failed, issue #2228 follow-up).
    if (_showCeiling) {
      final ceiling = _curveValueAt(widget.ceilingCurve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_ceiling,
          value: ceiling != null && ceiling > 0
              ? units.formatDepth(ceiling)
              : '-',
          bulletColor: const Color(0xFF7B1FA2),
          metric: ChartOnlyMetric.ceiling,
        ),
      );
    }
    if (_showCeiling) {
      for (final overlay in widget.overlays ?? const <ChartSourceOverlay>[]) {
        final idx = _overlayIndexAt(overlay, point.timestamp);
        final curve = overlay.analysis?.ceilingCurve;
        if (idx == null || curve == null || idx >= curve.length) continue;
        final ceiling = curve[idx];
        rows.add(
          TooltipRow(
            label: '${l10n.diveLog_tooltip_ceiling} · ${overlay.name}',
            value: ceiling > 0 ? units.formatDepth(ceiling) : '-',
            bulletColor: _overlayColor(overlay, ProfileMetricColors.ceiling),
          ),
        );
      }
    }

    // Deco stop. Mirrors the in-chart tooltip row so the panel and fullscreen
    // readouts report the band they are already drawing. Unlike the other
    // rows in this method, a null curve omits the row entirely rather than
    // showing a placeholder: no deco-stop curve at all means the dive never
    // had an obligation, and a permanent "-" row would be pure clutter on
    // every recreational dive. An in-range-but-short curve (decimation edge
    // case) still falls back to a placeholder, same as every other row.
    if (_showDecoStops && widget.decoStopCurve != null) {
      final stop = _curveValueAt(widget.decoStopCurve, spot.spotIndex) ?? 0.0;
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_decoStop,
          value: stop > 0 ? units.formatDepth(stop) : '-',
          bulletColor: decoStopBandColor,
          metric: ChartOnlyMetric.decoStop,
        ),
      );
    }
    if (_showDecoStops) {
      for (final overlay in widget.overlays ?? const <ChartSourceOverlay>[]) {
        final idx = _overlayIndexAt(overlay, point.timestamp);
        final curve = overlay.analysis?.decoStopCurve;
        if (idx == null || curve == null || idx >= curve.length) continue;
        final stop = curve[idx];
        rows.add(
          TooltipRow(
            label: '${l10n.diveLog_tooltip_decoStop} · ${overlay.name}',
            value: stop > 0 ? units.formatDepth(stop) : '-',
            bulletColor: _overlayColor(overlay, ProfileMetricColors.decoStops),
          ),
        );
      }
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
          metric: ProfileRightAxisMetric.ascentRate,
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
          metric: ProfileRightAxisMetric.heartRate,
        ),
      );
    }

    // Gas consumption: SAC, or RMV when the diver shows only that lane.
    if (_showSac &&
        widget.sacCurve != null &&
        spot.spotIndex < widget.sacCurve!.length) {
      final sacBarPerMin = widget.sacCurve![spot.spotIndex];
      var row = (label: context.l10n.gasConsumption_sac, value: '-');
      if (sacBarPerMin > 0) {
        row = gasConsumptionTooltipRow(
          l10n: context.l10n,
          units: units,
          display: ref.read(gasConsumptionDisplayProvider),
          sacBarPerMin: sacBarPerMin * widget.sacNormalizationFactor,
          tankVolume: widget.tankVolume,
        );
      }
      rows.add(
        TooltipRow(
          label: row.label,
          value: row.value,
          bulletColor: Colors.teal,
          metric: ProfileRightAxisMetric.sac,
        ),
      );
    }

    // NDL (always shown once enabled; see the comment on the Ceiling row).
    if (_showNdl) {
      final hasNdl =
          widget.ndlCurve != null && spot.spotIndex < widget.ndlCurve!.length;
      String ndlValue;
      if (!hasNdl) {
        ndlValue = '-';
      } else {
        final ndl = widget.ndlCurve![spot.spotIndex];
        if (ndl < 0) {
          ndlValue = l10n.diveLog_playbackStats_deco;
        } else if (ndl < 3600) {
          final min = ndl ~/ 60;
          final sec = ndl % 60;
          ndlValue = '$min:${sec.toString().padLeft(2, '0')}';
        } else {
          ndlValue = l10n.diveLog_tooltip_ndlOverMax;
        }
      }
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_ndl,
          value: ndlValue,
          bulletColor: Colors.yellow.shade700,
          metric: ProfileRightAxisMetric.ndl,
        ),
      );
    }
    if (_showNdl) {
      for (final overlay in widget.overlays ?? const <ChartSourceOverlay>[]) {
        final idx = _overlayIndexAt(overlay, point.timestamp);
        final curve = overlay.analysis?.ndlCurve;
        if (idx == null || curve == null || idx >= curve.length) continue;
        final ndl = curve[idx];
        String overlayNdlValue;
        if (ndl < 0) {
          overlayNdlValue = l10n.diveLog_playbackStats_deco;
        } else if (ndl < 3600) {
          final min = ndl ~/ 60;
          final sec = ndl % 60;
          overlayNdlValue = '$min:${sec.toString().padLeft(2, '0')}';
        } else {
          overlayNdlValue = l10n.diveLog_tooltip_ndlOverMax;
        }
        rows.add(
          TooltipRow(
            label: '${l10n.diveLog_tooltip_ndl} · ${overlay.name}',
            value: overlayNdlValue,
            bulletColor: _overlayColor(overlay, ProfileMetricColors.ndl),
          ),
        );
      }
    }

    // ppO2 (computer-supplied value or O2 cell average) plus each sensor
    // cell. Always shown once enabled; see the comment on the Ceiling row.
    if (_showPpO2) {
      final ppO2 = _curveValueAt(widget.ppO2Curve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: widget.ppO2FromSensorAverage
              ? '${context.l10n.diveLog_tooltip_ppO2} ${context.l10n.diveLog_tooltip_avgCalculated}'
              : context.l10n.diveLog_tooltip_ppO2,
          value: ppO2 != null
              ? '${_readoutValue(ppO2, onLeadIn).toStringAsFixed(2)} ${l10n.units_pressure_bar}'
              : '-',
          bulletColor: const Color(0xFF00ACC1),
          metric: ProfileRightAxisMetric.ppO2,
        ),
      );
    }

    if (_showPpO2) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.ppO2Curve,
          color: ProfileMetricColors.ppO2,
          label: l10n.diveLog_tooltip_ppO2,
          formatValue: (v) =>
              '${v.toStringAsFixed(2)} ${l10n.units_pressure_bar}',
        ),
      );
    }

    // One row per physical cell, plus the agreement verdict (#810). Gated on
    // the cells' own toggles, not on the ppO2 line: hiding the loop ppO2 must
    // not take the sensor readings with it.
    if (_showPpO2 || _showO2Cells) {
      rows.addAll(_buildO2CellTooltipRows(spot.spotIndex));
    }

    // ppN2 (always shown once enabled; see the comment on the Ceiling row).
    if (_showPpN2) {
      final ppN2 = _curveValueAt(widget.ppN2Curve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_ppN2,
          value: ppN2 != null
              ? '${_readoutValue(ppN2, onLeadIn).toStringAsFixed(2)} ${l10n.units_pressure_bar}'
              : '-',
          bulletColor: Colors.indigo,
          metric: ProfileRightAxisMetric.ppN2,
        ),
      );
    }
    if (_showPpN2) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.ppN2Curve,
          color: ProfileMetricColors.ppN2,
          label: l10n.diveLog_tooltip_ppN2,
          formatValue: (v) =>
              '${v.toStringAsFixed(2)} ${l10n.units_pressure_bar}',
        ),
      );
    }

    // ppHe (always shown once enabled, even on a non-trimix dive or where
    // the curve has no data for this sample; see the Ceiling row comment).
    if (_showPpHe) {
      final ppHe = _curveValueAt(widget.ppHeCurve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_ppHe,
          value: ppHe != null && ppHe > 0.001
              ? '${_readoutValue(ppHe, onLeadIn).toStringAsFixed(2)} ${l10n.units_pressure_bar}'
              : '-',
          bulletColor: Colors.pink.shade300,
          metric: ProfileRightAxisMetric.ppHe,
        ),
      );
    }
    if (_showPpHe) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.ppHeCurve,
          color: ProfileMetricColors.ppHe,
          label: l10n.diveLog_tooltip_ppHe,
          formatValue: (v) =>
              '${v.toStringAsFixed(2)} ${l10n.units_pressure_bar}',
          skip: (v) => v <= 0.001,
        ),
      );
    }

    // MOD (always shown once enabled; see the comment on the Ceiling row).
    if (_showMod) {
      final mod = _curveValueAt(widget.modCurve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_mod,
          value: mod != null && mod > 0 && mod < 200
              ? units.formatDepth(mod)
              : '-',
          bulletColor: const Color(0xFFFFB300),
          metric: ChartOnlyMetric.mod,
        ),
      );
    }
    if (_showMod) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.modCurve,
          color: ProfileMetricColors.mod,
          label: l10n.diveLog_tooltip_mod,
          formatValue: units.formatDepth,
          skip: (v) => !(v > 0 && v < 200),
        ),
      );
    }

    // Gas density (always shown once enabled; see the Ceiling row comment).
    if (_showDensity) {
      final density = _curveValueAt(widget.densityCurve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_density,
          value: density != null
              ? '${_readoutValue(density, onLeadIn).toStringAsFixed(2)} ${l10n.units_profileMetric_gPerL}'
              : '-',
          bulletColor: const Color(0xFF827717),
          metric: ProfileRightAxisMetric.gasDensity,
        ),
      );
    }
    if (_showDensity) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.densityCurve,
          color: ProfileMetricColors.density,
          label: l10n.diveLog_tooltip_density,
          formatValue: (v) =>
              '${v.toStringAsFixed(2)} ${l10n.units_profileMetric_gPerL}',
        ),
      );
    }

    // GF% (always shown once enabled; see the Ceiling row comment).
    if (_showGf) {
      final gf = _curveValueAt(widget.gfCurve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_gfPercent,
          value: gf != null ? '${gf.toStringAsFixed(0)}%' : '-',
          bulletColor: Colors.deepPurple,
          metric: ProfileRightAxisMetric.gf,
        ),
      );
    }
    if (_showGf) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.gfCurve,
          color: ProfileMetricColors.gf,
          label: l10n.diveLog_tooltip_gfPercent,
          formatValue: (v) => '${v.toStringAsFixed(0)}%',
        ),
      );
    }

    // Surface GF (always shown once enabled; see the Ceiling row comment).
    if (_showSurfaceGf) {
      final surfaceGf = _curveValueAt(widget.surfaceGfCurve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_srfGf,
          value: surfaceGf != null ? '${surfaceGf.toStringAsFixed(0)}%' : '-',
          bulletColor: Colors.purple.shade300,
          metric: ProfileRightAxisMetric.surfaceGf,
        ),
      );
    }
    if (_showSurfaceGf) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.surfaceGfCurve,
          color: ProfileMetricColors.surfaceGf,
          label: l10n.diveLog_tooltip_srfGf,
          formatValue: (v) => '${v.toStringAsFixed(0)}%',
        ),
      );
    }

    // Mean depth (always shown once enabled; see the Ceiling row comment).
    if (_showMeanDepth) {
      final meanDepth = _curveValueAt(widget.meanDepthCurve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_mean,
          value: meanDepth != null ? units.formatDepth(meanDepth) : '-',
          bulletColor: Colors.blueGrey,
          metric: ProfileRightAxisMetric.meanDepth,
        ),
      );
    }
    if (_showMeanDepth) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.meanDepthCurve,
          color: ProfileMetricColors.meanDepth,
          label: l10n.diveLog_tooltip_mean,
          formatValue: units.formatDepth,
        ),
      );
    }

    // TTS (always shown once enabled; see the Ceiling row comment).
    if (_showTts) {
      final hasTts =
          widget.ttsCurve != null && spot.spotIndex < widget.ttsCurve!.length;
      final tts = hasTts ? widget.ttsCurve![spot.spotIndex] : 0;
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_tts,
          value: !hasTts
              ? '-'
              : tts > 0
              ? '${(tts / 60).ceil()} ${l10n.units_profileMetric_min}'
              : '0 ${l10n.units_profileMetric_min}',
          bulletColor: const Color(0xFFAD1457),
          metric: ProfileRightAxisMetric.tts,
        ),
      );
    }
    if (_showTts) {
      for (final overlay in widget.overlays ?? const <ChartSourceOverlay>[]) {
        final idx = _overlayIndexAt(overlay, point.timestamp);
        final curve = overlay.analysis?.ttsCurve;
        if (idx == null || curve == null || idx >= curve.length) continue;
        final tts = curve[idx];
        rows.add(
          TooltipRow(
            label: '${l10n.diveLog_tooltip_tts} · ${overlay.name}',
            value: tts > 0
                ? '${(tts / 60).ceil()} ${l10n.units_profileMetric_min}'
                : '0 ${l10n.units_profileMetric_min}',
            bulletColor: _overlayColor(overlay, ProfileMetricColors.tts),
          ),
        );
      }
    }

    // GTR (always shown once enabled; see the Ceiling row comment).
    if (_showGtr) {
      final hasGtr =
          widget.gtrCurve != null && spot.spotIndex < widget.gtrCurve!.length;
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_gtr,
          // GTR's blank placeholder is '--' (formatGtrMinutes' own default),
          // deliberately distinct from every other row's '-' -- pre-existing
          // and test-verified, not something this refactor should change.
          value: formatGtrMinutes(
            hasGtr ? widget.gtrCurve![spot.spotIndex] : null,
            minuteUnit: l10n.units_profileMetric_min,
          ),
          bulletColor: ProfileRightAxisMetric.gtr.color!,
          metric: ProfileRightAxisMetric.gtr,
        ),
      );
    }
    if (_showGtr) {
      for (final overlay in widget.overlays ?? const <ChartSourceOverlay>[]) {
        final idx = _overlayIndexAt(overlay, point.timestamp);
        final curve = overlay.analysis?.gtrCurve;
        if (idx == null || curve == null || idx >= curve.length) continue;
        rows.add(
          TooltipRow(
            label: '${l10n.diveLog_tooltip_gtr} · ${overlay.name}',
            value: formatGtrMinutes(
              curve[idx],
              minuteUnit: l10n.units_profileMetric_min,
            ),
            bulletColor: _overlayColor(overlay, ProfileMetricColors.gtr),
          ),
        );
      }
    }

    // CNS% (always shown once enabled; see the Ceiling row comment).
    if (_showCns) {
      final cns = _curveValueAt(widget.cnsCurve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_cns,
          value: cns != null ? '${cns.toStringAsFixed(1)}%' : '-',
          bulletColor: const Color(0xFFE65100),
          metric: ProfileRightAxisMetric.cns,
        ),
      );
    }
    if (_showCns) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.cnsCurve,
          color: ProfileMetricColors.cns,
          label: l10n.diveLog_tooltip_cns,
          formatValue: (v) => '${v.toStringAsFixed(1)}%',
        ),
      );
    }

    // OTU (always shown once enabled; see the Ceiling row comment).
    if (_showOtu) {
      final otu = _curveValueAt(widget.otuCurve, spot.spotIndex);
      rows.add(
        TooltipRow(
          label: l10n.diveLog_tooltip_otu,
          value: otu != null ? otu.toStringAsFixed(0) : '-',
          bulletColor: const Color(0xFF6D4C41),
          metric: ProfileRightAxisMetric.otu,
        ),
      );
    }
    if (_showOtu) {
      rows.addAll(
        _overlayCurveRows<double>(
          timestamp: point.timestamp,
          curveOf: (a) => a.otuCurve,
          color: ProfileMetricColors.otu,
          label: l10n.diveLog_tooltip_otu,
          formatValue: (v) => v.toStringAsFixed(0),
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
            metric: ProfileRightAxisMetric.pressure,
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
              diamondBullet: true,
            ),
          );
        }
      }
    }

    return onLeadIn
        ? _markInterpolatedRows(rows, _exactAtSurfaceLabels(context))
        : rows;
  }

  /// The plot-rect insets (reserved axis gutters) for the current build: the
  /// single source of the plot rect, both for mapping a gesture's local
  /// position to a plot-area fraction and for positioning every layer drawn
  /// over the chart (gas strip, cursors, photo markers, safety lane, range
  /// handles). These must match what fl_chart itself reserves from the
  /// FlTitlesData below, which reserves a side only while that side shows an
  /// axis name or side titles. Top has no titles, so its inset is 0.
  ({double left, double top, double right, double bottom}) _plotInsets(
    double availableWidth,
    UnitFormatter units,
  ) {
    // _hoverRightAxisMetric wins over the persisted preference here for the
    // same reason as in build() -- so the plot rect (and so the gesture math
    // keyed on it) never disagrees with what the axis is showing this frame.
    // Still ref.read, per the note just below: this runs from gesture
    // callbacks too, outside build.
    final legendNotifier = ref.read(profileLegendProvider.notifier);
    final preferredMetric = legendNotifier.getEffectiveRightAxisMetric();
    final effectiveRightAxisMetric =
        _hoverRightAxisMetric ??
        (preferredMetric != null
            ? _getEffectiveRightAxisMetric(preferredMetric)
            : null);
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

    const border = DiveProfileChart._plotBorderWidth;
    return (
      left:
          DiveProfileChart._leftRightAxisNameSize +
          DiveProfileChart.leftAxisSize(availableWidth) +
          border,
      top: border,
      // fl_chart reserves a side's tick gutter only while that side shows
      // titles, and the right axis shows none without a metric -- so with no
      // right-axis metric the plot rect runs to the chart's border.
      right:
          (hasRightAxisName
              ? DiveProfileChart._leftRightAxisNameSize +
                    DiveProfileChart.rightAxisSize(availableWidth)
              : 0) +
          border,
      bottom:
          DiveProfileChart._bottomAxisNameSize +
          DiveProfileChart._bottomTickReservedSize +
          (hasGasStrip ? DiveProfileChart.gasTimelineHeight : 0) +
          (_hasSafetyLane ? DiveProfileChart.safetyLaneHeight : 0) +
          border,
    );
  }

  /// Nearest profile sample under a hover at [localPos], or null if the
  /// profile is empty. Maps the cursor X through the current viewport to a
  /// timestamp, then finds the closest sample. [onLeadIn] is true when the
  /// surface lead-in vertex at t=0 is closer than the first sample; [index]
  /// is then 0.
  ({int index, bool onLeadIn})? _hoverSelection(
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
    if (shouldDrawSurfaceLeadIn(widget.profile) &&
        t < widget.profile.first.timestamp / 2) {
      return (index: 0, onLeadIn: true);
    }
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < widget.profile.length; i++) {
      final d = (widget.profile[i].timestamp - t).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return (index: best, onLeadIn: false);
  }

  /// Reports a selection to [DiveProfileChart.onPointSelected] and
  /// [DiveProfileChart.onTimeSelected]. [onLeadIn] marks the surface lead-in
  /// vertex, whose time is 0 rather than the first sample's.
  void _reportSelection(int? index, {bool onLeadIn = false}) {
    widget.onPointSelected?.call(index);
    final onTimeSelected = widget.onTimeSelected;
    if (onTimeSelected == null) return;
    if (index == null || index < 0 || index >= widget.profile.length) {
      onTimeSelected(null);
    } else {
      onTimeSelected(onLeadIn ? 0 : widget.profile[index].timestamp);
    }
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
    _showComputedEvents = legendState.showComputedEvents;
    // Issue #1523: the provider default is `true`, and for a dive that carries
    // the computer's own events the post-frame seed only flips it to `false`
    // after the first frame -- long enough to flash the computed markers. Until
    // the user takes over the toggle, mirror the seed's decision here so the
    // first paint is already right (and stays right when switching dives).
    if (ref.read(profileLegendProvider.notifier).computedEventsFollowsDive) {
      _showComputedEvents = !_diveHasImportedEvents;
    }
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
    _showO2Cells = legendState.showO2Cells;
    _o2CellUnit = legendState.o2CellUnit;
    _showMod = legendState.showMod;
    _showDensity = legendState.showDensity;
    _showGf = legendState.showGf;
    _showSurfaceGf = legendState.showSurfaceGf;
    _showMeanDepth = legendState.showMeanDepth;
    _showTts = legendState.showTts;
    _showGtr = legendState.showGtr;
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
      units.rmvSymbol,
      units.settings.gasConsumptionDisplay.name,
      colorScheme.hashCode,
      metricBandSig,
    ]);
    _baseSig = _sigOf([
      commonSig,
      identityHashCode(widget.ascentRates),
      identityHashCode(widget.gasSwitches),
      identityHashCode(widget.tanks),
      identityHashCode(widget.tankPressures),
      identityHashCode(widget.tankSourceColors),
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
      identityHashCode(widget.gtrCurve),
      identityHashCode(widget.cnsCurve),
      identityHashCode(widget.otuCurve),
      identityHashCode(widget.o2SensorCurves),
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
    final hasO2CellData = _o2CellBarCurves != null || _o2CellMvCurves != null;
    final hasBothO2CellUnits =
        _o2CellBarCurves != null && _o2CellMvCurves != null;
    final hasDensityData =
        widget.densityCurve != null && widget.densityCurve!.isNotEmpty;
    final hasGfData = widget.gfCurve != null && widget.gfCurve!.isNotEmpty;
    final hasSurfaceGfData =
        widget.surfaceGfCurve != null && widget.surfaceGfCurve!.isNotEmpty;
    final hasMeanDepthData =
        widget.meanDepthCurve != null && widget.meanDepthCurve!.isNotEmpty;
    final hasTtsData = widget.ttsCurve != null && widget.ttsCurve!.isNotEmpty;
    final hasGtrData =
        widget.gtrCurve != null && widget.gtrCurve!.any((v) => v != null);
    final hasCnsData = widget.cnsCurve != null && widget.cnsCurve!.isNotEmpty;
    final hasOtuData = widget.otuCurve != null && widget.otuCurve!.isNotEmpty;

    // Build legend config based on available data
    final legendConfig = ProfileLegendConfig(
      activeSourceName: widget.activeComputerId == null
          ? null
          : widget.computerNames?[widget.activeComputerId!],
      overlays: _legendOverlays(),
      hasTemperatureData: hasTemperatureData,
      hasPressureData: hasPressureData,
      hasHeartRateData: hasHeartRateData,
      hasSacCurve: widget.sacCurve != null && widget.sacCurve!.isNotEmpty,
      hasCeilingCurve: widget.ceilingCurve != null,
      hasDecoStopCurve:
          widget.decoStopCurve != null && widget.decoStopCurve!.isNotEmpty,
      hasAscentRates: widget.ascentRates != null,
      hasEvents: widget.events != null && widget.events!.isNotEmpty,
      hasComputedEvents:
          widget.events?.any((e) => e.source == EventSource.computed) ?? false,
      hasImportedEvents:
          widget.events?.any((e) => e.source == EventSource.imported) ?? false,
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
      tankSourceColors: widget.tankSourceColors,
      hasNdlData: hasNdlData,
      hasPpO2Data: hasPpO2Data,
      hasPpN2Data: hasPpN2Data,
      hasPpHeData: hasPpHeData,
      hasO2CellData: hasO2CellData,
      hasBothO2CellUnits: hasBothO2CellUnits,
      hasModData: hasModData,
      hasDensityData: hasDensityData,
      hasGfData: hasGfData,
      hasSurfaceGfData: hasSurfaceGfData,
      hasMeanDepthData: hasMeanDepthData,
      hasTtsData: hasTtsData,
      hasGtrData: hasGtrData,
      hasCnsData: hasCnsData,
      hasOtuData: hasOtuData,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureLegendHeight();
    });

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
              key: _legendKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.legendLeading != null) widget.legendLeading!,
                Expanded(
                  child: DiveProfileLegend(
                    config: legendConfig,
                    zoomLevel: _viewport.zoom,
                    minZoom: ChartViewport.minZoom,
                    maxZoom: ChartViewport.maxZoom,
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
            // in unbounded contexts such as inline scroll views. The zoom
            // hint and the plot share a Stack (not separate Column children)
            // so the hint paints first, behind the plot -- an oversized
            // in-chart tooltip is allowed to spill past the plot's own
            // bounds (issue #2228 follow-up: legibility over occlusion for a
            // pathological number of active metrics), and with the hint as a
            // later Column sibling it used to paint over that overflow
            // instead of the other way around.
            if (constraints.hasBoundedHeight)
              Expanded(child: _plotWithZoomHint(context, plot))
            else
              SizedBox(height: 200, child: _plotWithZoomHint(context, plot)),
          ],
        );
      },
    );
  }

  /// Stacks the zoom hint behind [plot] instead of laying it out below as a
  /// separate Column child (see the call site's comment for why).
  ///
  /// The Stack and both slots exist at every zoom level; only the hint's
  /// content toggles. Returning the bare plot at 1x changed the plot's
  /// ancestors the moment a gesture lifted the zoom off 1x, which remounted
  /// the plot and disposed the trackpad recognizer mid-pinch, so zooming in
  /// from the full view stalled after one tiny step. The inline chart hid
  /// this because its exportKey (a GlobalKey) reparents the plot instead.
  Widget _plotWithZoomHint(BuildContext context, Widget plot) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: !_viewport.isZoomed
              ? const SizedBox.shrink()
              : IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      context.l10n.diveLog_profile_zoomHint(
                        _viewport.zoom.toStringAsFixed(1),
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
        ),
        Positioned.fill(child: plot),
      ],
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
                if (_rangeDragActive) return;
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
                _clearCursorHoverState();
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
                _clearCursorHoverState();
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
                // Tracked for the in-chart cursor tooltip's position (see
                // ProfileCursorTooltip below), which otherwise only moved on
                // a drag: a plain mouse hover carries no PointerDownEvent or
                // PointerMoveEvent through this Listener, only this one.
                if (_lastPointerLocal != event.localPosition) {
                  setState(() => _lastPointerLocal = event.localPosition);
                }
                // fl_chart's touch callback already handled this event; when
                // it resolved a sample that sample is the selection, so this
                // fallback only covers the cursor outside the plot rect or
                // with no sample within fl_chart's touch threshold. Reporting
                // both let the two disagree by a sample on every move.
                if (_chartTouchSelecting) {
                  _lastHoverIndex = null;
                  _lastHoverOnLeadIn = false;
                  return;
                }
                final hit = _hoverSelection(
                  event.localPosition,
                  constraints.biggest,
                  _plotInsets(constraints.maxWidth, units),
                );
                if (hit?.index != _lastHoverIndex ||
                    (hit?.onLeadIn ?? false) != _lastHoverOnLeadIn) {
                  _lastHoverIndex = hit?.index;
                  _lastHoverOnLeadIn = hit?.onLeadIn ?? false;
                  _reportSelection(hit?.index, onLeadIn: _lastHoverOnLeadIn);
                }
              },
              child: MouseRegion(
                onExit: (_) {
                  if (_lastHoverIndex != null) {
                    _lastHoverIndex = null;
                    _lastHoverOnLeadIn = false;
                    _reportSelection(null);
                  }
                  // The mouse leaving the chart entirely (not just panning
                  // off the touched sample) must also drop the in-chart
                  // tooltip and the hover-driven highlight/axis-override --
                  // otherwise they freeze at their last position instead of
                  // disappearing (issue #2228 follow-up).
                  _clearCursorHoverState();
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
    _reportSelection(null);
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
    _reportSelection(null);
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
        _viewport = ChartViewport.reset;
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
    const heartRateColor = ProfileMetricColors.heartRate;

    // Calculate full data bounds (all values stored in meters, convert for
    // display). Overlaid sources widen the extents so a deeper or longer
    // overlay trace is never clipped.
    final overlayPoints = (widget.overlays ?? const <ChartSourceOverlay>[])
        .expand((o) => o.points);
    final totalMaxTime = [
      widget.profile.map((p) => p.timestamp).reduce(math.max),
      ...overlayPoints.map((p) => p.timestamp),
    ].reduce(math.max).toDouble();

    // Apply zoom and pan to calculate visible bounds (see ChartViewport).
    final visibleRangeX = totalMaxTime * _viewport.visibleWidth;
    final visibleRangeY = totalMaxDepth * _viewport.visibleHeight;

    final visibleMinX = _viewport.offsetX * totalMaxTime;
    final visibleMaxX = visibleMinX + visibleRangeX;

    final visibleMinDepth = _viewport.offsetY * totalMaxDepth;
    final visibleMaxDepth = visibleMinDepth + visibleRangeY;

    // One plot rect for every layer drawn over the chart (highlight band, gas
    // strip, cursor extensions, photo markers, safety lane, range handles):
    // they all have to agree with fl_chart's own axis reservations, so they
    // all read them from here.
    final plotInsets = _plotInsets(availableWidth, units);

    // Highlight band, inflated to a 12 px minimum so short/instant findings
    // stay visible (spec: safety-findings-lane). Computed once and shared by
    // the band annotation and its edge lines.
    ({double x1, double x2})? highlightSpan;
    if (widget.highlightRange != null) {
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
    // A non-null _hoverRightAxisMetric (the cursor/touch sitting on a tagged
    // line, see lineMetricTags below) takes priority over the persisted
    // preference, purely for this render -- it is never written back to the
    // provider (issue #2228 follow-up).
    final legendNotifier = ref.read(profileLegendProvider.notifier);
    final preferredMetric = legendNotifier.getEffectiveRightAxisMetric();
    final effectiveRightAxisMetric =
        _hoverRightAxisMetric ??
        (preferredMetric != null
            ? _getEffectiveRightAxisMetric(preferredMetric)
            : null);
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

    final combinedSig = _sigOf([
      _baseSig,
      _sacSig,
      _ascentSig,
      _analysisSig,
      _markersSig,
      _overlaysSig,
    ]);
    final combinedPairs = _barsCache.series(
      'combined',
      combinedSig,
      () => [
        ..._barsCache.series('base', _baseSig, () {
          // Depth line segments (colored by active gas if present). Tagged
          // with ChartOnlyMetric.depth, not a ProfileRightAxisMetric: depth
          // is the chart's own primary/left axis, so hovering it highlights
          // the line (issue #2228 follow-up) but never drives the right
          // axis the way a secondary metric's tag does.
          final depthLines = _buildGasColoredDepthLines(colorScheme, units);

          // Gas switch markers (if showing and data available).
          // Zero-width dot markers, not a metric line.
          final gasSwitchMarkers = _showGasSwitchMarkers
              ? _buildGasSwitchMarkers(units)
              : const <LineChartBarData>[];

          // Temperature line (if showing).
          final temperatureLines =
              (_showTemperature &&
                  hasTemperatureData &&
                  minTemp != null &&
                  maxTemp != null)
              ? _buildTemperatureLines(
                  colorScheme,
                  metricBand,
                  minTemp,
                  maxTemp,
                  units,
                )
              : const <LineChartBarData>[];

          // Multi-tank pressure lines (per-tank visibility
          // controlled inside _buildMultiTankPressureLines via
          // _showTankPressure).
          final tankPressureLines = _hasMultiTankPressure
              ? _buildMultiTankPressureLines(metricBand)
              : const <LineChartBarData>[];

          // Heart rate line (if showing)
          final heartRateLines =
              (_showHeartRate &&
                  hasHeartRateData &&
                  minHR != null &&
                  maxHR != null)
              ? [_buildHeartRateLine(heartRateColor, metricBand, minHR, maxHR)]
              : const <LineChartBarData>[];

          return [
            ..._tagAll(depthLines, ChartOnlyMetric.depth),
            ..._tagAll(gasSwitchMarkers, null),
            ..._tagAll(temperatureLines, ProfileRightAxisMetric.temperature),
            ..._tagAll(tankPressureLines, ProfileRightAxisMetric.pressure),
            ..._tagAll(heartRateLines, ProfileRightAxisMetric.heartRate),
          ];
        }),
        ..._barsCache.series('sac', _sacSig, () {
          // SAC curve line (if showing)
          final sacLines =
              (_showSac && hasSacData && minSac != null && maxSac != null)
              ? [_buildSacLine(metricBand, minSac, maxSac)]
              : const <LineChartBarData>[];
          return _tagAll(sacLines, ProfileRightAxisMetric.sac);
        }),
        // Ascent-rate magnitude is drawn by [AscentRateBarOverlay], a
        // widget layer below (bars from the plot's vertical centre,
        // not an fl_chart line bar), so this cache series is empty. The
        // signature stays wired so a rate-data change still invalidates
        // the shared bars cache key.
        ..._barsCache.series('ascent', _ascentSig, () => const []),
        ..._barsCache.series('analysis', _analysisSig, () {
          // Deco stop band, drawn before the ceiling line so the
          // dashed curve stays legible on top of the fill. A
          // fill/band, not a right-axis metric line.
          final decoStopBand = (_showDecoStops && widget.decoStopCurve != null)
              ? [
                  buildDecoStopBand(
                    decoStopCurve: widget.decoStopCurve!,
                    timestamps: [for (final p in widget.profile) p.timestamp],
                    units: units,
                  ),
                ]
              : const <LineChartBarData>[];

          // Ceiling line (if showing and data available). There is
          // no ProfileRightAxisMetric.ceiling, so this never
          // drives the right axis.
          final ceilingLines = (_showCeiling && widget.ceilingCurve != null)
              ? [_buildCeilingLine(units)]
              : const <LineChartBarData>[];

          // NDL line (if showing)
          final ndlLines = (_showNdl && widget.ndlCurve != null)
              ? [_buildNdlLine(metricBand)]
              : const <LineChartBarData>[];

          // ppO2 line (if showing)
          final ppO2Lines = (_showPpO2 && widget.ppO2Curve != null)
              ? [_buildPpO2Line(metricBand)]
              : const <LineChartBarData>[];

          // ppN2 line (if showing)
          final ppN2Lines = (_showPpN2 && widget.ppN2Curve != null)
              ? [_buildPpN2Line(metricBand)]
              : const <LineChartBarData>[];

          // ppHe line (if showing and has helium data)
          final ppHeLines =
              (_showPpHe &&
                  widget.ppHeCurve != null &&
                  widget.ppHeCurve!.any((v) => v > 0.001))
              ? [_buildPpHeLine(metricBand)]
              : const <LineChartBarData>[];

          // O2 cell agreement rug: a per-run agreement strip, not
          // the mV values themselves, so it is left untagged
          // (null) rather than attributed to o2CellMv.
          final o2CellRug = _showO2Cells
              ? _buildO2CellRug(metricBand)
              : const <LineChartBarData>[];

          // One line per cell (if showing), in whichever unit
          // _effectiveO2CellUnit resolves to for this dive, tagged with the
          // physical cell it belongs to so hovering one cell's line
          // highlights only that cell (see O2CellMetric) rather than
          // every cell line at once.
          final o2CellCells = _showO2Cells
              ? (_effectiveO2CellUnit == O2CellUnit.ppO2
                    ? _buildO2CellPpO2Lines(metricBand)
                    : _buildO2CellMvLines(metricBand, units))
              : const <({int cell, LineChartBarData bar})>[];

          // MOD line (if showing). There is no
          // ProfileRightAxisMetric.mod, so this never drives the
          // right axis.
          final modLines = (_showMod && widget.modCurve != null)
              ? [_buildModLine(units)]
              : const <LineChartBarData>[];

          // Gas density line (if showing)
          final densityLines = (_showDensity && widget.densityCurve != null)
              ? [_buildDensityLine(metricBand)]
              : const <LineChartBarData>[];

          // GF% line (if showing)
          final gfLines = (_showGf && widget.gfCurve != null)
              ? [_buildGfLine(metricBand)]
              : const <LineChartBarData>[];

          // Surface GF line (if showing)
          final surfaceGfLines =
              (_showSurfaceGf && widget.surfaceGfCurve != null)
              ? [_buildSurfaceGfLine(metricBand)]
              : const <LineChartBarData>[];

          // Mean depth line (if showing)
          final meanDepthLines =
              (_showMeanDepth && widget.meanDepthCurve != null)
              ? [_buildMeanDepthLine(units)]
              : const <LineChartBarData>[];

          // TTS line (if showing)
          final ttsLines = (_showTts && widget.ttsCurve != null)
              ? [_buildTtsLine(metricBand)]
              : const <LineChartBarData>[];

          // GTR line (if showing)
          final gtrLines = (_showGtr && widget.gtrCurve != null)
              ? [_buildGtrLine(metricBand)]
              : const <LineChartBarData>[];

          // CNS% curve (if showing)
          final cnsLines = (_showCns && widget.cnsCurve != null)
              ? [_buildCnsLine(metricBand)]
              : const <LineChartBarData>[];

          // OTU curve (if showing)
          final otuLines = (_showOtu && widget.otuCurve != null)
              ? [_buildOtuLine(metricBand)]
              : const <LineChartBarData>[];

          return [
            ..._tagAll(decoStopBand, ChartOnlyMetric.decoStop),
            ..._tagAll(ceilingLines, ChartOnlyMetric.ceiling),
            ..._tagAll(ndlLines, ProfileRightAxisMetric.ndl),
            ..._tagAll(ppO2Lines, ProfileRightAxisMetric.ppO2),
            ..._tagAll(ppN2Lines, ProfileRightAxisMetric.ppN2),
            ..._tagAll(ppHeLines, ProfileRightAxisMetric.ppHe),
            ..._tagAll(o2CellRug, null),
            for (final entry in o2CellCells)
              (bar: entry.bar, tag: O2CellMetric(entry.cell)),
            ..._tagAll(modLines, ChartOnlyMetric.mod),
            ..._tagAll(densityLines, ProfileRightAxisMetric.gasDensity),
            ..._tagAll(gfLines, ProfileRightAxisMetric.gf),
            ..._tagAll(surfaceGfLines, ProfileRightAxisMetric.surfaceGf),
            ..._tagAll(meanDepthLines, ProfileRightAxisMetric.meanDepth),
            ..._tagAll(ttsLines, ProfileRightAxisMetric.tts),
            ..._tagAll(gtrLines, ProfileRightAxisMetric.gtr),
            ..._tagAll(cnsLines, ProfileRightAxisMetric.cns),
            ..._tagAll(otuLines, ProfileRightAxisMetric.otu),
          ];
        }),
        ..._barsCache.series('markers', _markersSig, () {
          // Profile markers (max depth, pressure thresholds):
          // zero-width dot markers, not right-axis metric lines.
          final markerLines = _buildMarkerLines(
            units,
            metricBand,
            minPressure: minPressure,
            maxPressure: maxPressure,
          );
          return _tagAll(markerLines, null);
        }),
        ..._barsCache.series('overlays', _overlaysSig, () {
          // Overlaid comparison sources — LAST, so depth bars keep
          // occupying the leading barIndex range (_depthBarCount).
          //
          // Left entirely untagged (null): a single overlay can
          // contribute a data-dependent number of lines across
          // several different metrics (depth, temperature, deco
          // band, ceiling, NDL, TTS, ppO2, ...), each gated by its
          // own nested "if data present" check inside
          // _buildOverlayLines. Re-deriving, per overlay, which
          // metric each returned bar corresponds to would mean
          // duplicating that whole conditional chain a second
          // time here, with every duplication a chance to
          // miscount and mislabel a bar -- exactly the failure
          // mode called out as higher-risk than simply not
          // highlighting an overlay line.
          final overlayLines = _buildOverlayLines(
            units,
            metricBand,
            minTemp,
            maxTemp,
          );
          return _tagAll(overlayLines, null);
        }),
      ],
    );

    // The flattened bars alone, cached under the same signature so this is
    // the identical List instance across a 'combined' cache hit (see
    // _flatBarsCache) -- a fresh `[for (p in combinedPairs) p.bar]` on every
    // build would defeat _windowedBars' own identical()-based memoization
    // even when nothing changed.
    final flatBars = _flatBarsCache.series(
      'combined',
      combinedSig,
      () => [for (final pair in combinedPairs) pair.bar],
    );
    final combinedBars = _windowedBars(
      flatBars,
      visibleMinX: visibleMinX,
      visibleRangeX: visibleRangeX,
      chartMinY: -visibleMaxDepth,
    );

    // Parallel to combinedBars: the metric each bar represents, or null when
    // it has none. Built from the same [combinedPairs] the bars themselves
    // came from, so it cannot drift out of positional sync the way two
    // separately-built, equal-length lists could. Windowing (_windowedBars)
    // keeps a strict 1:1 index correspondence (it only cuts each bar's own
    // spots, never reorders or drops a whole bar), so these indices stay
    // valid against the windowed bars fl_chart is actually given.
    final lineMetricTags = [for (final pair in combinedPairs) pair.tag];

    // The line under the cursor/touch (see the touchCallback below) is
    // drawn slightly thicker than its neighbours.
    final highlightedBarIndex = _hoverHighlightedBarIndex;
    final displayedLineBars =
        highlightedBarIndex != null &&
            highlightedBarIndex >= 0 &&
            highlightedBarIndex < combinedBars.length
        ? [
            for (var i = 0; i < combinedBars.length; i++)
              i == highlightedBarIndex
                  ? combinedBars[i].copyWith(
                      barWidth:
                          combinedBars[i].barWidth +
                          DiveProfileChart.hoverHighlightBarWidthDelta,
                    )
                  : combinedBars[i],
          ]
        : combinedBars;

    // While playback is running, the in-chart cursor tooltip follows the
    // playback position instead of wherever the mouse happens to be sitting
    // idle -- otherwise it stayed pinned to the last hovered sample while
    // the playback line swept right past it. Null (falls back to the mouse
    // below) once playback stops, and also whenever the playback timestamp
    // itself resolves to nothing showable (out of the visible window, no
    // matching sample).
    final playbackCursorTooltip = widget.playbackIsPlaying
        ? _playbackCursorTooltipData(
            plotInsets: plotInsets,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            visibleMinX: visibleMinX,
            visibleMaxX: visibleMaxX,
            visibleMinDepth: visibleMinDepth,
            visibleMaxDepth: visibleMaxDepth,
          )
        : null;
    final tooltipCursorLocal =
        playbackCursorTooltip?.cursorLocal ?? _lastPointerLocal;
    final tooltipRows = playbackCursorTooltip?.rows ?? _liveCursorTooltipRows;

    return Stack(
      // Clip.none: with many active metrics the cursor tooltip's real
      // height can exceed the plot's own vertical space despite its text
      // already shrinking to fit (ProfileCursorTooltip's scale estimate
      // does not perfectly match the real, as-laid-out row height), which
      // otherwise clipped its top rows away instead of letting it spill
      // above the plot the way it already does horizontally past the
      // cursor (issue #2228 follow-up).
      clipBehavior: Clip.none,
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
              border: Border.all(
                color: colorScheme.outlineVariant,
                width: DiveProfileChart._plotBorderWidth,
              ),
            ),
            // Bar order is invariant: depth bars first (velocity suppression
            // and tooltip resolution key off the leading barIndex range),
            // overlays last (see _depthBarCount). The groups scope cache
            // invalidation; the combined key memoizes the concatenation so a
            // playback-only rebuild returns the identical outer list (fl_chart
            // listEquals short-circuits on identity).
            lineBarsData: displayedLineBars,
            rangeAnnotations: RangeAnnotations(
              verticalRangeAnnotations: _buildHighlightRangeAnnotations(
                highlightSpan,
                visibleMinX: visibleMinX,
                visibleMaxX: visibleMaxX,
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: _buildO2CellRugTrack(metricBand, colorScheme),
              verticalLines: [
                ...buildPlaybackCursor(colorScheme, widget.playbackTimestamp),
                ...buildHighlightCursor(
                  colorScheme,
                  widget.highlightedTimestamp,
                ),
                ...buildHighlightRangeLines(
                  highlightSpan,
                  widget.highlightRange?.color,
                ),
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
                // The deco stop band's spots are compressed to its step
                // transitions only (see buildDecoStopBand), so fl_chart's
                // nearest-spot touch resolution can land on the transition
                // at the start of the current stop level instead of the
                // cursor's actual position anywhere within that flat run --
                // the dot then reads as stuck instead of tracking the
                // cursor, even though the tooltip's own Deco stop row
                // already reads the correct value at the true cursor
                // position. No indicator is clearer than a wrong one.
                if (barData.isStepLineChart) {
                  return List<TouchedSpotIndicatorData?>.filled(
                    spotIndexes.length,
                    null,
                  );
                }
                final suppressed = _suppressedDepthIndicatorSpots;
                // spotIndexes can reference a touch captured against a
                // previous frame's bar data (e.g. a consolidate-dive merge
                // shortens the profile mid-touch); indexing barData.spots
                // with a stale, now out-of-range index throws in fl_chart's
                // own defaultTouchedIndicators, so drop those here first.
                // Hide the built-in focus dot on the extra velocity bands so a
                // single depth dot remains; every other line keeps its default
                // indicator. See [velocityIndicatorSuppression].
                return [
                  for (final index in spotIndexes)
                    if (index < 0 || index >= barData.spots.length)
                      null
                    else if (suppressed.isNotEmpty &&
                        _isSpotAt(barData, index, suppressed))
                      null
                    else if (!_isSpotAt(barData, index, _touchedIndicatorSpots))
                      null
                    else
                      _thinTouchedIndicator(barData, index),
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
                _touchedIndicatorSpots = active
                    ? [for (final s in spots) (x: s.x, y: s.y)]
                    : const [];
                _suppressedDepthIndicatorSpots = active
                    ? DiveProfileChart.velocityIndicatorSuppression([
                        for (final s in spots)
                          (barIndex: s.barIndex, x: s.x, y: s.y),
                      ], starts.length)
                    : const [];

                _chartTouchSelecting = false;
                // Resolved once and reused below (selection reporting, the
                // in-chart tooltip's rows, and the ascent-rate bar
                // highlight): it is a pure lookup from the same `spots`, and
                // this callback already runs on every pointer-move frame.
                final resolvedTouch = active
                    ? _resolveDepthTouch(spots, starts)
                    : null;
                if (widget.onPointSelected != null ||
                    widget.onTimeSelected != null ||
                    widget.onTooltipData != null) {
                  final isExternal =
                      widget.tooltipPresentation ==
                      TooltipPresentation.external;
                  if (isTouchEnd) {
                    _reportSelection(null);
                    if (isExternal) {
                      widget.onTooltipData?.call(null);
                    }
                  } else if (resolvedTouch != null) {
                    _chartTouchSelecting = true;
                    // The lead-in vertex reads as t=0 in the tooltip, so
                    // report that time rather than the first sample's.
                    _reportSelection(
                      resolvedTouch.index,
                      onLeadIn: resolvedTouch.onLeadIn,
                    );
                    if (isExternal && widget.onTooltipData != null) {
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
                // The in-chart cursor tooltip's rows: only the
                // ProfileCursorTooltip path (TooltipPresentation.inChart)
                // reads _liveCursorTooltipRows, so building it elsewhere
                // would be wasted work every pointer move.
                if (widget.tooltipPresentation == TooltipPresentation.inChart) {
                  final rows = resolvedTouch == null
                      ? const <TooltipRow>[]
                      : _buildTooltipRowsForIndex(
                          resolvedTouch.index,
                          onLeadIn: resolvedTouch.onLeadIn,
                          units: UnitFormatter(ref.read(settingsProvider)),
                          colorScheme: Theme.of(context).colorScheme,
                        );
                  if (rows.isNotEmpty || _liveCursorTooltipRows.isNotEmpty) {
                    setState(() => _liveCursorTooltipRows = rows);
                  }
                }

                // Hover-highlight the touched line and auto-switch the right
                // axis to its metric (issue #2228 follow-up). Independent of
                // tooltipPresentation: it highlights the chart's own lines
                // regardless of which tooltip surface is showing their
                // values.
                final cursor = _lastPointerLocal;
                int? nearestBarIndex;
                if (active && cursor != null) {
                  final maxY = -visibleMinDepth;
                  final minY = -visibleMaxDepth;
                  final plotHeight =
                      (availableHeight - plotInsets.top - plotInsets.bottom)
                          .clamp(1.0, double.infinity);
                  double toPixelY(double dataY) =>
                      plotInsets.top +
                      (maxY - dataY) / (maxY - minY) * plotHeight;
                  nearestBarIndex = nearestHoveredBarIndex(
                    spots: [
                      for (final s in spots) (barIndex: s.barIndex, dataY: s.y),
                    ],
                    cursorPixelY: cursor.dy,
                    toPixelY: toPixelY,
                  );
                }
                // The nearest bar's tag, whatever kind it is -- a
                // ProfileRightAxisMetric (drives the right axis too, below)
                // or a ChartOnlyMetric (highlighted the same way, but has no
                // axis to switch to). Null when the nearest reported spot is
                // an untagged bar (a marker, a fill, an overlay trace) with
                // a tagged line further away, in which case nothing
                // highlights.
                final nearestTag =
                    nearestBarIndex != null &&
                        nearestBarIndex >= 0 &&
                        nearestBarIndex < lineMetricTags.length
                    ? lineMetricTags[nearestBarIndex]
                    : null;
                // Never resurrect the right axis over an explicit "None":
                // the user hiding it is a deliberate choice, and hovering a
                // line must not silently reappear it and shift the plot
                // width for the duration of the hover.
                final rightAxisExplicitlyHidden = ref
                    .read(profileLegendProvider)
                    .rightAxisHidden;
                // An O2CellMetric tags one physical cell's line for
                // highlighting (see O2CellMetric), but every cell still
                // reads on the one shared o2CellMv axis.
                final nearestAxisMetric = nearestTag is ProfileRightAxisMetric
                    ? nearestTag
                    : (nearestTag is O2CellMetric
                          ? ProfileRightAxisMetric.o2CellMv
                          : null);
                final newHoverMetric = !rightAxisExplicitlyHidden
                    ? nearestAxisMetric
                    : null;
                final newHighlightedBarIndex = nearestTag != null
                    ? nearestBarIndex
                    : null;
                if (newHoverMetric != _hoverRightAxisMetric ||
                    newHighlightedBarIndex != _hoverHighlightedBarIndex ||
                    nearestTag != _hoverHighlightedMetric) {
                  setState(() {
                    _hoverRightAxisMetric = newHoverMetric;
                    _hoverHighlightedBarIndex = newHighlightedBarIndex;
                    _hoverHighlightedMetric = newHighlightedBarIndex != null
                        ? nearestTag
                        : null;
                  });
                }

                // Ascent/descent rate bars have no fl_chart bar of their own
                // (see AscentRateBarOverlay), so they cannot be tagged into
                // lineMetricTags above; light up only when the cursor is
                // actually over the bar drawn for the touched sample's rate
                // -- otherwise every hover anywhere in the chart would light
                // them up regardless of position, and they would stay lit
                // while hovering an unrelated line.
                int? hoveredAscentRateTimestamp;
                final ascentRates = widget.ascentRates;
                if (_showAscentRateLine &&
                    ascentRates != null &&
                    resolvedTouch != null &&
                    cursor != null &&
                    resolvedTouch.index < ascentRates.length) {
                  final rate =
                      ascentRates[resolvedTouch.index].rateMetersPerMin;
                  final maxAbsRate =
                      _ascentRateAxisRange(ascentRates)?.max ?? 0;
                  if (maxAbsRate > 0 && rate != 0) {
                    final barPlotHeight =
                        (availableHeight - plotInsets.top - plotInsets.bottom)
                            .clamp(1.0, double.infinity);
                    final baselineY = plotInsets.top + barPlotHeight / 2;
                    final halfBand = barPlotHeight / 2;
                    final magnitude = (rate.abs() / maxAbsRate).clamp(0.0, 1.0);
                    final barLength = magnitude * halfBand;
                    final descending = rate < 0;
                    final endY = descending
                        ? baselineY + barLength
                        : baselineY - barLength;
                    final barTop = descending ? baselineY : endY;
                    final barBottom = descending ? endY : baselineY;
                    // A little slack around the drawn bar: matching it
                    // pixel-for-pixel would make short (low-rate) bars
                    // nearly impossible to hover.
                    const hitTolerance = 10.0;
                    if (cursor.dy >= barTop - hitTolerance &&
                        cursor.dy <= barBottom + hitTolerance) {
                      hoveredAscentRateTimestamp =
                          widget.profile[resolvedTouch.index].timestamp;
                    }
                  }
                }
                if (hoveredAscentRateTimestamp != _hoveredAscentRateTimestamp) {
                  setState(
                    () => _hoveredAscentRateTimestamp =
                        hoveredAscentRateTimestamp,
                  );
                }

                // Deco stop focus dot: positioned from the resolved touch
                // rather than the band's own (sparse) spots -- see
                // [_decoStopTouchIndex].
                final decoStopCurve = widget.decoStopCurve;
                final decoStopTouchIndex =
                    (_showDecoStops &&
                        decoStopCurve != null &&
                        resolvedTouch != null &&
                        resolvedTouch.index < decoStopCurve.length &&
                        // 0 means no deco obligation at that sample (see
                        // quantizeCeilingToStops) -- without this, hovering a
                        // no-deco dive drew a stray focus dot pinned to the
                        // surface line at every sample.
                        decoStopCurve[resolvedTouch.index] > 0)
                    ? resolvedTouch.index
                    : null;
                if (decoStopTouchIndex != _decoStopTouchIndex) {
                  setState(() => _decoStopTouchIndex = decoStopTouchIndex);
                }
              },
              touchTooltipData: LineTouchTooltipData(
                // fl_chart's own bubble is suppressed for
                // TooltipPresentation.external (rendered externally via
                // widget.onTooltipData) and for .inChart (rendered by
                // ProfileCursorTooltip, a Stack layer below, instead).
                // .nativeBubble restores this bubble exactly as it rendered
                // before issue #2228 introduced ProfileCursorTooltip:
                // fitInsideVertically: false with showOnTopOfTheChartBoxArea:
                // true lets it sit above the whole chart box rather than
                // being fitted -- and therefore repositioned or clipped --
                // against the plot.
                maxContentWidth: 320,
                fitInsideHorizontally: true,
                fitInsideVertically: false,
                showOnTopOfTheChartBoxArea: true,
                tooltipMargin: 0,
                getTooltipColor:
                    widget.tooltipPresentation ==
                        TooltipPresentation.nativeBubble
                    ? (_) => Theme.of(context).colorScheme.inverseSurface
                    : (_) => Colors.transparent,
                getTooltipItems: (touchedSpots) {
                  if (widget.tooltipPresentation !=
                      TooltipPresentation.nativeBubble) {
                    return touchedSpots.map((_) => null).toList();
                  }
                  final starts = _depthBarStartIndices();
                  final depthBarCount = starts.length;
                  final depthSpot = touchedSpots
                      .where((s) => s.barIndex < depthBarCount)
                      .firstOrNull;
                  final resolvedTouch = _resolveDepthTouch(
                    touchedSpots,
                    starts,
                  );
                  if (depthSpot == null || resolvedTouch == null) {
                    return touchedSpots.map((_) => null).toList();
                  }
                  final highlightedMetric = _highlightedTooltipMetric;
                  // Same sample, same lead-in state, same highlighted metric,
                  // same touched-bar count as last time: nothing the built
                  // items depend on has changed, so return the cached list
                  // rather than rebuilding every row and TextSpan again. The
                  // length check matters because fl_chart requires the
                  // returned list to match touchedSpots.length, and that can
                  // change under a parked cursor (a metric toggled, a data
                  // provider refreshing) even while the sample doesn't.
                  if (resolvedTouch.index == _lastTooltipSpotIndex &&
                      resolvedTouch.onLeadIn == _lastTooltipOnLeadIn &&
                      highlightedMetric == _lastTooltipHighlightedMetric &&
                      _lastTooltipItems.length == touchedSpots.length) {
                    return _lastTooltipItems;
                  }
                  final colorScheme = Theme.of(context).colorScheme;
                  final rows = _buildTooltipRowsForIndex(
                    resolvedTouch.index,
                    onLeadIn: resolvedTouch.onLeadIn,
                    units: UnitFormatter(ref.read(settingsProvider)),
                    colorScheme: colorScheme,
                  );
                  final onSurface = colorScheme.onInverseSurface;
                  final rowStyle = TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 14,
                    color: onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  );
                  // fl_chart tooltips are a single TextSpan tree, so columns
                  // are aligned with monospace padding rather than layout
                  // widgets, matching how this bubble rendered before issue
                  // #2228.
                  const rowWidth =
                      DiveProfileChart.tooltipLabelChars +
                      DiveProfileChart.tooltipValueChars;
                  final rowFiller = List.filled(rowWidth, '0').join();
                  final lines = <TextSpan>[];
                  for (final row in rows) {
                    if (lines.isNotEmpty) {
                      lines.add(const TextSpan(text: '\n'));
                    }
                    lines.add(
                      TextSpan(
                        text: row.diamondBullet ? '◆ ' : '● ',
                        style: TextStyle(
                          color: row.bulletColor,
                          fontSize: row.diamondBullet ? 10 : 12,
                        ),
                      ),
                    );
                    final rowText = DiveProfileChart.tooltipRowText(
                      row.label,
                      row.value,
                      DiveProfileChart.tooltipLabelChars,
                      DiveProfileChart.tooltipValueChars,
                    );
                    final isRowHighlighted =
                        row.metric != null && row.metric == highlightedMetric;
                    lines.add(
                      TextSpan(
                        text: rowText,
                        style: isRowHighlighted
                            ? rowStyle.copyWith(fontWeight: FontWeight.bold)
                            : rowStyle,
                      ),
                    );
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
                  final result = touchedSpots.map((touched) {
                    if (!identical(touched, depthSpot)) return null;
                    return LineTooltipItem(
                      '', // Empty base text, using children instead.
                      TextStyle(color: onSurface),
                      children: lines,
                      textAlign: TextAlign.start,
                    );
                  }).toList();
                  _lastTooltipSpotIndex = resolvedTouch.index;
                  _lastTooltipOnLeadIn = resolvedTouch.onLeadIn;
                  _lastTooltipHighlightedMetric = highlightedMetric;
                  _lastTooltipItems = result;
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
        // X-axis tick labels. Sized to exactly the chart's plot width from
        // the shared plot rect, and offset from the bottom so it lands in
        // the gap reserved above by `_hasGasStrip`
        // (_bottomAxisNameSize + _bottomTickReservedSize).
        if (_hasGasStrip)
          Positioned(
            left: plotInsets.left,
            right: plotInsets.right,
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
            insets: plotInsets,
            availableWidth: availableWidth,
            visibleMinX: visibleMinX,
            visibleMaxX: visibleMaxX,
          ),
        // Ascent/descent rate bars: a widget layer (not an fl_chart line),
        // so its variable bar length and colour intensity are painted
        // directly rather than forced through LineChartBarData. Replaces the
        // old lime rate line under the same legend toggle (issue #2228
        // follow-up): a bar from the plot's fixed vertical centre reads the
        // signed rate more directly than a scaled curve does.
        if (_showAscentRateLine && widget.ascentRates != null)
          Positioned.fill(
            child: AscentRateBarOverlay(
              ascentRates: widget.ascentRates!,
              visibleMinSeconds: visibleMinX,
              visibleMaxSeconds: visibleMaxX,
              insets: plotInsets,
              maxAbsRateMetersPerMin:
                  _ascentRateAxisRange(widget.ascentRates)?.max ?? 0,
              highlightedTimestamp: _hoveredAscentRateTimestamp,
            ),
          ),
        // Deco stop focus dot: a widget layer positioned from the resolved
        // touch (see [_decoStopTouchIndex]) rather than fl_chart's own
        // touched-spot indicator, which is suppressed for this bar
        // (getTouchedSpotIndicator above) because its spots are too sparse
        // to track the cursor continuously within a flat stop level.
        if (_decoStopTouchIndex != null &&
            widget.decoStopCurve != null &&
            _decoStopTouchIndex! < widget.decoStopCurve!.length &&
            _decoStopTouchIndex! < widget.profile.length)
          Builder(
            builder: (context) {
              final index = _decoStopTouchIndex!;
              final plotWidth =
                  availableWidth - plotInsets.left - plotInsets.right;
              final plotHeight =
                  availableHeight - plotInsets.top - plotInsets.bottom;
              final visibleRangeX = visibleMaxX - visibleMinX;
              final maxY = -visibleMinDepth;
              final minY = -visibleMaxDepth;
              if (plotWidth <= 0 ||
                  plotHeight <= 0 ||
                  visibleRangeX <= 0 ||
                  maxY <= minY) {
                return const SizedBox.shrink();
              }
              final t = widget.profile[index].timestamp.toDouble();
              final dataY = -units.convertDepth(widget.decoStopCurve![index]);
              final x =
                  plotInsets.left +
                  (t - visibleMinX) / visibleRangeX * plotWidth;
              final y =
                  plotInsets.top + (maxY - dataY) / (maxY - minY) * plotHeight;
              const dotRadius = 5.0;
              return Positioned(
                left: x - dotRadius,
                top: y - dotRadius,
                child: IgnorePointer(
                  child: Container(
                    width: dotRadius * 2,
                    height: dotRadius * 2,
                    decoration: const BoxDecoration(
                      color: decoStopBandColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
        // Photo markers: tappable camera chips at each photo's (time, depth).
        // A widget layer (not an fl_chart element) so its taps never enter
        // the chart's gesture arena; positioned by the shared plot rect.
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
              insets: plotInsets,
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
              insets: plotInsets,
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
        // Range-statistics handles. Topmost so a handle wins the pointer
        // over the layers below it, and inside the chart so it shares the
        // plot rect and visible window (issue #1579).
        if (widget.rangeSelection != null)
          Positioned.fill(
            child: RangeSelectionOverlay(
              startSeconds: widget.rangeSelection!.startSeconds,
              endSeconds: widget.rangeSelection!.endSeconds,
              maxSeconds: widget.rangeSelection!.maxSeconds,
              visibleMinSeconds: visibleMinX,
              visibleMaxSeconds: visibleMaxX,
              insets: plotInsets,
              onRangeChanged: widget.onRangeChanged ?? (_, _) {},
              onDragActiveChanged: (active) => _rangeDragActive = active,
            ),
          ),
        // In-chart cursor tooltip: TooltipPresentation.inChart's own
        // rendering of the touched/hovered sample -- or, while playback is
        // running, of the playback position instead (see
        // [playbackCursorTooltip] above). IgnorePointer, like the other
        // widget-layer overlays above, so it never steals the touch/hover
        // that positions it.
        if (widget.tooltipPresentation == TooltipPresentation.inChart &&
            tooltipCursorLocal != null &&
            tooltipRows.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ProfileCursorTooltip(
                rows: tooltipRows,
                cursorLocal: tooltipCursorLocal,
                insets: plotInsets,
                // No hover-highlighted line while playback drives the
                // tooltip: highlighting follows the mouse's nearest line,
                // which is meaningless while the mouse isn't what is
                // selecting the shown sample.
                highlightedMetric: playbackCursorTooltip != null
                    ? null
                    : _highlightedTooltipMetric,
                extraHeadroomAbove: _legendHeight,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds vertical line extensions over the gas timeline strip for any
  /// active cursors (hover highlight + step-through playback) so the line
  /// visually continues past the chart's plot area.
  List<Widget> _buildGasStripCursorExtensions({
    required ({double left, double top, double right, double bottom}) insets,
    required double availableWidth,
    required double visibleMinX,
    required double visibleMaxX,
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

    final left = insets.left;
    final right = insets.right;
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
          .where(
            (m) =>
                // Ascent rate is drawn by AscentRateBarOverlay (bars from the
                // plot's centre, gated on its own legend toggle), not as a
                // LineChartBarData against this axis's scale -- selecting it
                // here would show a scale with no traceable line against it.
                m != ProfileRightAxisMetric.ascentRate && _hasDataForMetric(m),
          )
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

  /// Whether [barData]'s spot at [index] is one of [spots]. Matches on the
  /// spot coordinate because fl_chart hands the indicator callback a copied
  /// bar without its position in the bar list. Used both to hide the focus
  /// indicator velocity colouring already shows on another band (see
  /// [velocityIndicatorSuppression]) and to drop a stale touched index (see
  /// [_touchedIndicatorSpots]).
  bool _isSpotAt(
    LineChartBarData barData,
    int index,
    List<({double x, double y})> spots,
  ) {
    if (index < 0 || index >= barData.spots.length) return false;
    final spot = barData.spots[index];
    const epsilon = 1e-6;
    for (final s in spots) {
      if ((s.x - spot.x).abs() < epsilon && (s.y - spot.y).abs() < epsilon) {
        return true;
      }
    }
    return false;
  }

  /// Same shape as fl_chart's own [defaultTouchedIndicators], but thinner and
  /// with a smaller dot: the built-in defaults (4px line, 10px dot radius)
  /// competed with the chart's own data lines after they were thinned to 1px
  /// (issue #2228), and read as oversized once the rest of the chart was.
  TouchedSpotIndicatorData _thinTouchedIndicator(
    LineChartBarData barData,
    int index,
  ) {
    const indicatorStrokeWidth = 2.0;
    // Radius, not diameter (fl_chart's own default is a 10px radius when a
    // bar's own dotData is off, i.e. a 20px-wide circle -- half that here).
    const dotRadius = 5.0;
    final defaultIndicator = defaultTouchedIndicators(barData, [index]).first;
    final dotColor =
        barData.gradient?.colors.first ?? barData.color ?? Colors.blueGrey;
    return TouchedSpotIndicatorData(
      defaultIndicator.indicatorBelowLine.copyWith(
        strokeWidth: indicatorStrokeWidth,
      ),
      FlDotData(
        getDotPainter: (spot, percent, bar, i) =>
            FlDotCirclePainter(radius: dotRadius, color: dotColor),
      ),
    );
  }

  /// The bars fl_chart is handed: [bars] cut to the visible window when
  /// zoomed, so no path runs far off screen (see [windowBars]). Memoized on
  /// the source list and the snapped window: a horizontal pan that stays
  /// inside one eighth-window step hands fl_chart the identical list, which
  /// keeps its touched spot indices valid and lets its listEquals
  /// short-circuit. [chartMinY] is in the key too, since the cut bars' fill
  /// gradients are placed against it.
  List<LineChartBarData> _windowedBars(
    List<LineChartBarData> bars, {
    required double visibleMinX,
    required double visibleRangeX,
    required double chartMinY,
  }) {
    final snapped = snappedBarWindow(minX: visibleMinX, width: visibleRangeX);
    final range = _viewport.isZoomed
        ? (minX: snapped.minX, maxX: snapped.maxX, minY: chartMinY)
        : null;
    if (identical(bars, _barWindowSource) && range == _barWindowRange) {
      return _barWindow.bars;
    }
    _barWindowSource = bars;
    _barWindowRange = range;
    _barWindow = range == null
        ? WindowedBars.unwindowed(bars)
        : windowBars(
            bars,
            minX: range.minX,
            maxX: range.maxX,
            chartMinY: range.minY,
          );
    return _barWindow.bars;
  }

  /// [spot]'s index in its source bar, before [_windowedBars] cut it.
  /// fl_chart reports touches against the cut bars it was handed.
  int _sourceSpotIndex(LineBarSpot spot) =>
      _barWindow.sourceSpotIndex(spot.barIndex, spot.spotIndex);

  /// Build every overlaid source's lines: dashed depth, dimmed temperature
  /// (when the temperature metric is enabled), and computer-reported
  /// ceiling/NDL (when those metrics are enabled), all in the overlay's
  /// color. Appended AFTER every other bar so the depth-bar indexing
  /// contract (depth bars occupy `barIndex` `[0, _depthBarCount())`) stays
  /// valid for the tooltip's spot-to-sample mapping.
  /// The overlays as the legend needs them: which metrics each one has data
  /// for, so the legend lists exactly the overlay traces [_buildOverlayLines]
  /// draws. The presence tests mirror that method's, including the ppHe and
  /// MOD value filters that can leave a non-empty curve drawing nothing.
  List<LegendOverlaySource> _legendOverlays() {
    final overlays = widget.overlays;
    if (overlays == null) return const [];
    return [
      for (final overlay in overlays)
        if (overlay.points.isNotEmpty)
          LegendOverlaySource(
            name: overlay.name,
            tintByMetric: overlay.tintByMetric,
            color: overlay.color,
            metrics: _overlayMetrics(overlay),
          ),
    ];
  }

  Set<LegendMetric> _overlayMetrics(ChartSourceOverlay overlay) {
    final analysis = overlay.analysis;
    bool has(List<Object?>? curve) => curve != null && curve.isNotEmpty;
    return {
      LegendMetric.depth,
      if (overlay.points.any((p) => p.temperature != null))
        LegendMetric.temperature,
      if (has(analysis?.decoStopCurve)) LegendMetric.decoStops,
      if (analysis?.ceilingCurve.any((c) => c > 0) ?? false)
        LegendMetric.ceiling,
      if (analysis?.ndlCurve.any((n) => n > 0) ?? false) LegendMetric.ndl,
      if (has(analysis?.ttsCurve)) LegendMetric.tts,
      if (analysis?.gtrCurve?.any((g) => g != null) ?? false) LegendMetric.gtr,
      if (has(analysis?.cnsCurve)) LegendMetric.cns,
      if (has(analysis?.otuCurve)) LegendMetric.otu,
      if (has(analysis?.ppO2Curve)) LegendMetric.ppO2,
      if (has(analysis?.ppN2Curve)) LegendMetric.ppN2,
      if (analysis?.ppHeCurve?.any((p) => p > 0.001) ?? false)
        LegendMetric.ppHe,
      if (analysis?.modCurve?.any((m) => m > 0 && m < 200) ?? false)
        LegendMetric.mod,
      if (has(analysis?.densityCurve)) LegendMetric.density,
      if (has(analysis?.gfCurve)) LegendMetric.gf,
      if (has(analysis?.surfaceGfCurve)) LegendMetric.surfaceGf,
      if (has(analysis?.meanDepthCurve)) LegendMetric.meanDepth,
    };
  }

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
          color: _overlayColor(overlay, ProfileMetricColors.depth),
          barWidth: 1,
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
              color: _overlayColor(
                overlay,
                Theme.of(context).colorScheme.tertiary,
              ),
              barWidth: 1,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: const [5, 3],
            ),
          );
        }
      }

      // Deco stop band, computed for this source specifically (no raw
      // per-point device field carries a stepped stop level).
      if (_showDecoStops) {
        final decoStopCurve = overlay.analysis?.decoStopCurve;
        if (decoStopCurve != null && decoStopCurve.isNotEmpty) {
          lines.add(
            buildDecoStopBand(
              decoStopCurve: decoStopCurve,
              timestamps: [for (final p in overlay.points) p.timestamp],
              units: units,
              fillColor: _overlayColor(overlay, ProfileMetricColors.decoStops),
            ),
          );
        }
      }

      // Ceiling, from this source's own computed analysis (already resolved
      // computer-vs-calculated the same way the active ceiling line is, via
      // overlayComputerDecoData) -- reading the raw device field directly
      // here instead would show a different resolution than the active
      // line's default and, for a computer whose raw ceiling is noisy,
      // render as a jagged mess instead of the smoothed calculated curve.
      if (_showCeiling) {
        final ceilingCurve = overlay.analysis?.ceilingCurve;
        if (ceilingCurve != null && ceilingCurve.isNotEmpty) {
          final length = math.min(ceilingCurve.length, overlay.points.length);
          final spots = <FlSpot>[];
          var pendingBreak = false;
          for (final i in _decimatedOverlayCurveIndices(
            ceilingCurve.sublist(0, length),
          )) {
            final ceiling = ceilingCurve[i];
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
                overlay.points[i].timestamp.toDouble(),
                -units.convertDepth(ceiling),
              ),
            );
          }
          if (spots.isNotEmpty) {
            lines.add(
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.2,
                color: _overlayColor(overlay, ProfileMetricColors.ceiling),
                barWidth: 1,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                dashArray: const [4, 4],
              ),
            );
          }
        }
      }

      // NDL, from this source's own computed analysis -- same resolution and
      // in-deco line-break semantics as the active NDL line (see
      // _buildNdlLine); see the ceiling comment above for why this reads the
      // computed curve rather than the raw device field.
      if (_showNdl) {
        final maxNdlSeconds = ProfileMetricBands.ndl.fixedMax;
        final ndlCurve = overlay.analysis?.ndlCurve;
        if (ndlCurve != null && ndlCurve.isNotEmpty) {
          final length = math.min(ndlCurve.length, overlay.points.length);
          final spots = <FlSpot>[];
          for (final i in _decimatedOverlayCurveIndices(
            ndlCurve.sublist(0, length),
          )) {
            if (ndlCurve[i] <= 0) {
              if (spots.isNotEmpty && spots.last != FlSpot.nullSpot) {
                spots.add(FlSpot.nullSpot);
              }
              continue;
            }
            final ndl = ndlCurve[i].clamp(0, maxNdlSeconds.toInt()).toDouble();
            spots.add(
              FlSpot(
                overlay.points[i].timestamp.toDouble(),
                -band.mapNormalized(ndl / maxNdlSeconds),
              ),
            );
          }
          if (spots.isNotEmpty) {
            lines.add(
              LineChartBarData(
                spots: _withFlatSurfaceLeadIn(spots, owner: overlay.points),
                isCurved: false,
                color: _overlayColor(overlay, ProfileMetricColors.ndl),
                barWidth: 1,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                dashArray: ProfileMetricBands.ndl.dashArray,
              ),
            );
          }
        }
      }

      // TTS, from this source's own computed analysis, on the same
      // normalized scale as the active TTS line (see _buildTtsLine and
      // _getTtsMaxScale); see the ceiling comment above for why this reads
      // the computed curve rather than the raw device field.
      if (_showTts) {
        final maxTtsSeconds = _getTtsMaxScale();
        final ttsCurve = overlay.analysis?.ttsCurve;
        if (ttsCurve != null && ttsCurve.isNotEmpty) {
          final length = math.min(ttsCurve.length, overlay.points.length);
          final spots = <FlSpot>[
            for (final i in _decimatedOverlayCurveIndices(
              ttsCurve.sublist(0, length),
            ))
              FlSpot(
                overlay.points[i].timestamp.toDouble(),
                -band.mapNormalized(
                  ttsCurve[i].clamp(0, maxTtsSeconds.toInt()).toDouble() /
                      maxTtsSeconds,
                ),
              ),
          ];
          lines.add(
            LineChartBarData(
              spots: _withFlatSurfaceLeadIn(spots, owner: overlay.points),
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: _seriesGetsLeadIn(
                spots,
                overlay.points,
              ),
              color: _overlayColor(overlay, ProfileMetricColors.tts),
              barWidth: 1,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: ProfileMetricBands.tts.dashArray,
            ),
          );
        }
      }

      // ppO2, from this source's own computed analysis, on the same band as
      // the active ppO2 line (see _buildPpO2Line and _getPpO2MaxScale); see
      // the ceiling comment above for why this reads the computed curve
      // rather than the raw device field.
      if (_showPpO2) {
        _addOverlayBandLine(
          lines,
          overlay: overlay,
          band: band,
          curve: overlay.analysis?.ppO2Curve,
          spec: ProfileMetricBands.ppO2,
          max: _getPpO2MaxScale(),
          leadIn: _OverlayLeadIn.computed,
        );
      }

      // ppN2, same shape as ppO2 above but on the active ppN2 line's band
      // (see _buildPpN2Line and _getPpN2MaxScale).
      if (_showPpN2) {
        _addOverlayBandLine(
          lines,
          overlay: overlay,
          band: band,
          curve: overlay.analysis?.ppN2Curve,
          spec: ProfileMetricBands.ppN2,
          max: _getPpN2MaxScale(),
          leadIn: _OverlayLeadIn.computed,
        );
      }

      // ppHe, same shape as ppO2/ppN2 above but on the active ppHe line's
      // band (see _buildPpHeLine and _getPpHeMaxScale), and only where
      // helium is actually present -- the same ppHe > 0.001 filter the
      // active line uses so a non-trimix overlay draws nothing.
      if (_showPpHe) {
        _addOverlayBandLine(
          lines,
          overlay: overlay,
          band: band,
          curve: overlay.analysis?.ppHeCurve,
          spec: ProfileMetricBands.ppHe,
          max: _getPpHeMaxScale(),
          leadIn: _OverlayLeadIn.computed,
          include: (value) => value > 0.001,
        );
      }

      // MOD, from this source's own computed analysis, in the active
      // profile's depth unit (see _buildModLine). Held flat like the active
      // line: MOD is a property of the gas, not of depth.
      if (_showMod) {
        final modCurve = overlay.analysis?.modCurve;
        if (modCurve != null && modCurve.isNotEmpty) {
          final length = math.min(modCurve.length, overlay.points.length);
          final curve = modCurve.sublist(0, length);
          final spots = <FlSpot>[
            for (final i in _decimatedOverlayCurveIndices(curve))
              if (curve[i] > 0 && curve[i] < 200)
                FlSpot(
                  overlay.points[i].timestamp.toDouble(),
                  -units.convertDepth(curve[i]),
                ),
          ];
          if (spots.isNotEmpty) {
            lines.add(
              LineChartBarData(
                spots: _withFlatSurfaceLeadIn(spots, owner: overlay.points),
                isCurved: false,
                color: _overlayColor(overlay, ProfileMetricColors.mod),
                barWidth: 1,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                dashArray: ProfileMetricBands.mod.dashArray,
              ),
            );
          }
        }
      }

      // Gas density, from this source's own computed analysis, on the same
      // band as the active density line (see _buildDensityLine and
      // _getDensityMaxScale).
      if (_showDensity) {
        _addOverlayBandLine(
          lines,
          overlay: overlay,
          band: band,
          curve: overlay.analysis?.densityCurve,
          spec: ProfileMetricBands.density,
          max: _getDensityMaxScale(),
          leadIn: _OverlayLeadIn.computed,
        );
      }

      // GF%, from this source's own computed analysis, on the same band as
      // the active GF% line (see _buildGfLine and _getGfMaxScale).
      if (_showGf) {
        _addOverlayBandLine(
          lines,
          overlay: overlay,
          band: band,
          curve: overlay.analysis?.gfCurve,
          spec: ProfileMetricBands.gf,
          max: _getGfMaxScale(),
        );
      }

      // Surface GF%, from this source's own computed analysis, on the same
      // band as the active surface GF% line (see _buildSurfaceGfLine and
      // _getSurfaceGfMaxScale).
      if (_showSurfaceGf) {
        _addOverlayBandLine(
          lines,
          overlay: overlay,
          band: band,
          curve: overlay.analysis?.surfaceGfCurve,
          spec: ProfileMetricBands.surfaceGf,
          max: _getSurfaceGfMaxScale(),
        );
      }

      // Mean depth, from this source's own computed analysis, in the active
      // profile's depth unit (see _buildMeanDepthLine).
      if (_showMeanDepth) {
        final meanDepthCurve = overlay.analysis?.meanDepthCurve;
        if (meanDepthCurve != null && meanDepthCurve.isNotEmpty) {
          final length = math.min(meanDepthCurve.length, overlay.points.length);
          final curve = meanDepthCurve.sublist(0, length);
          final spots = <FlSpot>[
            for (final i in _decimatedOverlayCurveIndices(curve))
              FlSpot(
                overlay.points[i].timestamp.toDouble(),
                -units.convertDepth(curve[i]),
              ),
          ];
          lines.add(
            LineChartBarData(
              spots: _withFlatSurfaceLeadIn(spots, owner: overlay.points),
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: _seriesGetsLeadIn(
                spots,
                overlay.points,
              ),
              color: _overlayColor(overlay, ProfileMetricColors.meanDepth),
              barWidth: 1,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: ProfileMetricBands.meanDepth.dashArray,
            ),
          );
        }
      }

      // GTR, from this source's own computed analysis, on the same 0-60 min
      // band as NDL/TTS (see _buildGtrLine). Nulls (the computer blanked its
      // GTR display) break the line rather than bridging or dropping to
      // zero, same as the active line; no surface lead-in, since GTR is
      // blank on the surface by definition.
      if (_showGtr) {
        final maxGtrSeconds = ProfileMetricBands.gtr.fixedMax;
        final gtrCurve = overlay.analysis?.gtrCurve;
        if (gtrCurve != null && gtrCurve.isNotEmpty) {
          final length = math.min(gtrCurve.length, overlay.points.length);
          final curve = gtrCurve.sublist(0, length);
          final presentIndices = <int>[];
          final presentValues = <double>[];
          for (var i = 0; i < curve.length; i++) {
            final v = curve[i];
            if (v == null) continue;
            presentIndices.add(i);
            presentValues.add(v.toDouble());
          }
          if (presentValues.isNotEmpty) {
            final spots = <FlSpot>[];
            var previous = -1;
            for (final k in _decimatedOverlayCurveIndices(presentValues)) {
              final i = presentIndices[k];
              if (previous >= 0 && gtrGapBetween(curve, previous, i)) {
                spots.add(FlSpot.nullSpot);
              }
              final normalized =
                  curve[i]!.toDouble().clamp(0, maxGtrSeconds) / maxGtrSeconds;
              spots.add(
                FlSpot(
                  overlay.points[i].timestamp.toDouble(),
                  -band.mapNormalized(normalized),
                ),
              );
              previous = i;
            }
            if (spots.isNotEmpty) {
              lines.add(
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: _overlayColor(overlay, ProfileMetricColors.gtr),
                  barWidth: 1,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  dashArray: ProfileMetricBands.gtr.dashArray,
                ),
              );
            }
          }
        }
      }

      // CNS%, from this source's own computed analysis, on the SAME dynamic
      // scale as the active CNS% line (_getCnsMaxScale reads the active
      // widget.cnsCurve, not this overlay's own values) -- otherwise the two
      // curves would be scaled independently and not be visually comparable
      // (see _buildCnsLine).
      if (_showCns) {
        _addOverlayBandLine(
          lines,
          overlay: overlay,
          band: band,
          curve: overlay.analysis?.cnsCurve,
          spec: ProfileMetricBands.cns,
          max: _getCnsMaxScale(),
        );
      }

      // OTU, from this source's own computed analysis, on the SAME dynamic
      // scale as the active OTU line (see the CNS% comment above and
      // _buildOtuLine).
      if (_showOtu) {
        _addOverlayBandLine(
          lines,
          overlay: overlay,
          band: band,
          curve: overlay.analysis?.otuCurve,
          spec: ProfileMetricBands.otu,
          max: _getOtuMaxScale(),
        );
      }
    }
    return lines;
  }

  /// Adds one overlaid computer's trace of a metric drawn as a banded curve.
  ///
  /// Eight metrics are plotted identically: take that source's own analysis
  /// curve, clamp it into the metric's band, decimate it, map it onto the
  /// shared right-hand axis and stroke it in the overlay's tint of the metric
  /// colour. Only the curve, the band and the lead-in differ, so those are
  /// parameters rather than another copy of the block. The metrics that are
  /// genuinely different stay written out: depth-mapped (MOD, mean depth),
  /// gap-broken (ceiling, NDL, GTR) and normalised (TTS).
  void _addOverlayBandLine(
    List<LineChartBarData> lines, {
    required ChartSourceOverlay overlay,
    required MetricBand band,
    required List<double>? curve,
    required ProfileMetricBand spec,
    // Overrides the spec's maximum for the metrics scaled to the dive.
    double? max,
    _OverlayLeadIn leadIn = _OverlayLeadIn.flat,
    // Drops points that should not be plotted at all, such as helium on a
    // dive that carried none.
    bool Function(double value)? include,
  }) {
    if (curve == null || curve.isEmpty) return;

    final min = spec.min;
    final limit = max ?? spec.fixedMax;

    // The curve is computed from these very points, so the lengths agree in
    // practice; the bound is here so a mismatched pair cannot index past the
    // end, not because a mismatch is expected.
    final length = math.min(curve.length, overlay.points.length);
    final values = curve.sublist(0, length);

    final spots = <FlSpot>[
      for (final i in _decimatedOverlayCurveIndices(values))
        if (include == null || include(values[i]))
          FlSpot(
            overlay.points[i].timestamp.toDouble(),
            -band.map(values[i].clamp(min, limit), min, limit),
          ),
    ];
    // A filtered metric can end up with nothing to draw.
    if (spots.isEmpty) return;

    lines.add(
      LineChartBarData(
        spots: leadIn == _OverlayLeadIn.flat
            ? _withFlatSurfaceLeadIn(spots, owner: overlay.points)
            : _withSurfaceLeadIn(
                spots,
                -band.map(
                  _overlaySurfaceValueOf(
                    values.first,
                    overlay.points,
                  ).clamp(min, limit),
                  min,
                  limit,
                ),
                owner: overlay.points,
              ),
        isCurved: true,
        curveSmoothness: 0.2,
        preventCurveOverShooting: _seriesGetsLeadIn(spots, overlay.points),
        color: _overlayColor(overlay, spec.color),
        barWidth: 1,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        dashArray: spec.dashArray,
      ),
    );
  }

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

  /// Extend a curve back to the t=0 axis origin with a lead-in vertex at
  /// [surfaceY] (already in chart y-space, i.e. negated/normalised the same way
  /// the curve's own points are).
  ///
  /// Computers do not sample at t=0, so without this every line starts one
  /// sample interval inside the chart and the left edge reads as ragged
  /// (issue #684). No-ops when the profile already starts at zero, when the gap
  /// is too wide to attribute to the sampling rate, or when the curve drew no
  /// points at all.
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

  /// [_surfaceValueOf], but keyed to an overlay's own first sample rather
  /// than the active profile's -- an overlaid computer descends at its own
  /// rate, so its lead-in has to extrapolate from its own depth, not the
  /// active source's.
  double _overlaySurfaceValueOf(
    double valueAtFirstSample,
    List<DiveProfilePoint> points,
  ) => points.isEmpty
      ? valueAtFirstSample
      : surfaceValueAtOneBar(valueAtFirstSample, points.first.depth);

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
      barWidth: 1,
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
  List<LineChartBarData> _buildGasSwitchMarkers(UnitFormatter units) =>
      buildGasSwitchMarkers(
        units,
        widget.gasSwitches,
        _showTankPressure,
        _findDepthAtTimestamp,
      );

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
      barWidth: 1,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      // Solid: see the comment on _buildNdlLine's dashArray removal. The
      // overlaid source's own temperature line keeps its own, independent
      // dash (see _buildOverlayLines), so this is unaffected either way.
    );
  }

  /// Build multiple pressure lines for multi-tank visualization
  List<LineChartBarData> _buildMultiTankPressureLines(MetricBand band) =>
      buildMultiTankPressureLines(
        band,
        hasMultiTankPressure: _hasMultiTankPressure,
        tankPressures: widget.tankPressures,
        showTankPressure: _showTankPressure,
        estimatedTankIds: widget.estimatedTankIds,
        profile: widget.profile,
        sortedTankIds: _sortedTankIds,
        tankComputerIds: _tankComputerIds,
        isComputerVisible: _isComputerVisible,
        getTankById: _getTankById,
        getTankColor: _getTankColor,
        getTankDashPattern: _getTankDashPattern,
        withFlatSurfaceLeadIn: _withFlatSurfaceLeadIn,
        seriesGetsLeadIn: _seriesGetsLeadIn,
      );

  LineChartBarData _buildHeartRateLine(
    Color color,
    MetricBand band,
    double minHR,
    double maxHR,
  ) => buildHeartRateLine(color, band, minHR, maxHR, widget.profile);

  /// Build SAC (Surface Air Consumption) curve line
  LineChartBarData _buildSacLine(
    MetricBand band,
    double minSac,
    double maxSac,
  ) => buildSacLine(
    band,
    minSac,
    maxSac,
    widget.sacCurve!,
    widget.profile,
    _decimatedCurveIndices,
    _withFlatSurfaceLeadIn,
    _seriesGetsLeadIn,
  );

  double _calculateDepthInterval(double maxDepth) =>
      calculateDepthInterval(maxDepth);

  double _calculateTimeInterval(double maxTime) =>
      calculateTimeInterval(maxTime);

  /// Build the ceiling line (decompression ceiling)
  LineChartBarData _buildCeilingLine(UnitFormatter units) => buildCeilingLine(
    units,
    widget.ceilingCurve!,
    widget.profile,
    _decimatedCurveIndices,
    _withFlatSurfaceLeadIn,
    _seriesGetsLeadIn,
  );

  /// Build NDL (No Decompression Limit) line
  /// NDL values are in seconds; shows time remaining before deco obligation
  LineChartBarData _buildNdlLine(MetricBand band) => buildNdlLine(
    band,
    widget.ndlCurve!,
    widget.profile,
    _decimatedCurveIndices,
    _withFlatSurfaceLeadIn,
  );

  /// Build ppO2 (partial pressure of oxygen) line
  /// Values typically range from 0.21 (surface air) to 1.6+ (critical)
  LineChartBarData _buildPpO2Line(MetricBand band) => buildPpO2Line(
    band,
    widget.ppO2Curve!,
    _getPpO2MaxScale(),
    widget.profile,
    _decimatedCurveIndices,
    _withSurfaceLeadIn,
    _surfaceValueOf,
    _seriesGetsLeadIn,
  );

  List<AscentRatePoint>? _ascentRateAxisRangeSource;
  ({double min, double max})? _ascentRateAxisRangeCached;
  bool _ascentRateAxisRangeCacheValid = false;

  /// [DiveProfileChart.ascentRateAxisRange], memoized on the source identity.
  ///
  /// Called every build/hover frame (both by [AscentRateBarOverlay]'s
  /// saturation range and by the right-axis range lookup), and it is an O(n)
  /// scan over every ascent-rate sample -- worth avoiding on a hot path for a
  /// long technical dive with thousands of samples (issue #2228 follow-up).
  ({double min, double max})? _ascentRateAxisRange(
    List<AscentRatePoint>? ascentRates,
  ) {
    if (identical(_ascentRateAxisRangeSource, ascentRates) &&
        _ascentRateAxisRangeCacheValid) {
      return _ascentRateAxisRangeCached;
    }
    _ascentRateAxisRangeSource = ascentRates;
    _ascentRateAxisRangeCached = DiveProfileChart.ascentRateAxisRange(
      ascentRates,
    );
    _ascentRateAxisRangeCacheValid = true;
    return _ascentRateAxisRangeCached;
  }

  List<List<num?>>? _o2SpreadSource;
  List<double?>? _o2SpreadCached;

  /// Smoothed cell spread (max minus min), memoized on the source identity.
  ///
  /// Both the ribbon and the axis need it, and a rolling median per frame would
  /// be wasteful. Smoothed because millivolts are whole numbers: without it the
  /// ribbon flickers a full millivolt wider and narrower on pure rounding.
  List<double?> _o2CellSpread(List<List<num?>> cellCurves) {
    if (identical(_o2SpreadSource, cellCurves) && _o2SpreadCached != null) {
      return _o2SpreadCached!;
    }
    final window = o2CellSpreadWindowSamples([
      for (final p in widget.profile) p.timestamp,
    ]);
    _o2SpreadSource = cellCurves;
    _o2SpreadCached = smoothO2CellSpread([
      computeO2CellRange(cellCurves),
    ], windowSamples: window).single;
    return _o2SpreadCached!;
  }

  /// The curves the spread is read from, and the unit that reads them.
  ///
  /// Millivolts when the dive logs them, since that is the raw output and
  /// needs no calibration to be comparable; the derived ppO2 otherwise, so a
  /// dive that carries only bar still gets the rug.
  (List<List<num?>>, O2CellUnit)? get _o2SpreadInput {
    final mv = _o2CellMvCurves;
    if (mv != null) return (mv, O2CellUnit.millivolts);
    final bar = _o2CellBarCurves;
    if (bar != null) return (bar, O2CellUnit.ppO2);
    return null;
  }

  /// Cell spread at one sample, for the tooltip. Null when fewer than two cells
  /// reported there.
  double? _o2CellRangeAt(int sampleIndex) {
    final input = _o2SpreadInput;
    if (input == null) return null;
    final spread = _o2CellSpread(input.$1);
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
    final unit = _o2SpreadInput!.$2;
    final level = o2CellAgreementFor(spread, unit: unit);
    final value = switch (unit) {
      O2CellUnit.ppO2 =>
        '${spread.toStringAsFixed(2)} ${context.l10n.units_pressure_bar}',
      O2CellUnit.millivolts =>
        '${spread.toStringAsFixed(0)} '
            '${context.l10n.units_profileMetric_millivolts}',
    };
    return '${_agreementWord(level)} ($value)';
  }

  /// One row per physical cell -- ppO2 when the calibration is trustworthy,
  /// the raw output when it is not, both when both are available -- plus the
  /// agreement verdict row (#810). Shared by both tooltip layouts so they
  /// cannot drift apart; callers must gate this on `_showPpO2 || _showO2Cells`
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
          metric: O2CellMetric(cell),
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
            o2CellAgreementFor(
              _o2CellRangeAt(spotIndex)!,
              unit: _o2SpreadInput!.$2,
            ),
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
    if (!_showO2Cells) return const [];
    if (_o2SpreadInput == null) return const [];

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
    final input = _o2SpreadInput;
    if (input == null) return const [];

    final spread = _o2CellSpread(input.$1);
    final runs = o2CellAgreementRuns(spread, unit: input.$2);
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

  /// Cell ppO2 curves, when any cell reported one.
  List<List<double?>>? get _o2CellBarCurves {
    final curves = widget.o2SensorCurves;
    if (curves == null) return null;
    return curves.any((c) => c.any((v) => v != null)) ? curves : null;
  }

  /// Cell millivolt curves, when any cell reported one.
  List<List<int?>>? get _o2CellMvCurves {
    final curves = widget.o2CellMvCurves;
    if (curves == null) return null;
    return curves.any((c) => c.any((v) => v != null)) ? curves : null;
  }

  /// The unit actually drawn: the chosen one when the dive carries it, the
  /// other when it does not. Both are the same measurement one calibration
  /// constant apart, so drawing both would be the same curve twice.
  O2CellUnit get _effectiveO2CellUnit {
    if (_o2CellUnit == O2CellUnit.ppO2 && _o2CellBarCurves != null) {
      return O2CellUnit.ppO2;
    }
    if (_o2CellUnit == O2CellUnit.millivolts && _o2CellMvCurves != null) {
      return O2CellUnit.millivolts;
    }
    return _o2CellBarCurves != null ? O2CellUnit.ppO2 : O2CellUnit.millivolts;
  }

  /// One cell's readings as spots, broken wherever the cell stopped
  /// reporting.
  ///
  /// The break has to be decided from the source curve, not from the rendered
  /// indices: decimation drops present samples too, and treating every skipped
  /// index as a gap would shatter a healthy line. Only a null actually sitting
  /// between two rendered samples is a dropout.
  List<FlSpot> _o2CellSpots(List<num?> curve, double Function(num) toY) {
    final indices = _decimatedNullableCurveIndices(curve);
    if (indices.isEmpty) return const [];

    final breaks = _o2CellDropouts(curve);
    final spots = <FlSpot>[];
    var nextBreak = 0;
    var previous = -1;
    for (final i in indices) {
      // Any dropout the decimator skipped over still has to break the line,
      // so the breaks are consumed against the source index, not matched to
      // the rendered one.
      var dropped = false;
      while (nextBreak < breaks.length && breaks[nextBreak] <= i) {
        if (breaks[nextBreak] > previous) dropped = true;
        nextBreak++;
      }
      if (dropped && spots.isNotEmpty) spots.add(FlSpot.nullSpot);
      spots.add(FlSpot(widget.profile[i].timestamp.toDouble(), toY(curve[i]!)));
      previous = i;
    }
    return spots;
  }

  /// Sample indices where [curve] resumes after the cell genuinely stopped
  /// reporting, in ascending order.
  ///
  /// Not every null is a dropout. libdc clears the cell fields on each sample
  /// (`libdc_download.c`), so a computer that logs its cells on their own
  /// second leaves a null between every pair of readings; breaking on those
  /// would shatter a healthy trace into single points, which fl_chart draws as
  /// a scatter of round caps rather than a line. A dropout is a silence that
  /// is long against the cadence the cell itself keeps.
  List<int> _o2CellDropouts(List<num?> curve) {
    final n = math.min(widget.profile.length, curve.length);
    final present = <int>[];
    for (var i = 0; i < n; i++) {
      if (curve[i] != null) present.add(i);
    }
    if (present.length < 3) return const [];

    final deltas = <int>[];
    for (var k = 1; k < present.length; k++) {
      final delta =
          widget.profile[present[k]].timestamp -
          widget.profile[present[k - 1]].timestamp;
      if (delta > 0) deltas.add(delta);
    }
    if (deltas.isEmpty) return const [];
    deltas.sort();
    final cadence = deltas[deltas.length ~/ 2];
    if (cadence <= 0) return const [];

    // Three cadences: a single missed reading is noise, a silence this long is
    // the cell having stopped.
    final threshold = cadence * 3;
    final breaks = <int>[];
    for (var k = 1; k < present.length; k++) {
      final delta =
          widget.profile[present[k]].timestamp -
          widget.profile[present[k - 1]].timestamp;
      if (delta > threshold) breaks.add(present[k]);
    }
    return breaks;
  }

  /// Per-cell ppO2 lines, on the aggregate's own axis (#854).
  ///
  /// Drawn against the aggregate rather than on a scale of their own, because
  /// the aggregate is precisely what hides a failing cell: a voted or averaged
  /// value stays plausible while one cell walks away from the others. The
  /// divergence is only legible as a fan opening between the traces and the
  /// line they are supposed to agree with.
  List<({int cell, LineChartBarData bar})> _buildO2CellPpO2Lines(
    MetricBand band,
  ) {
    final curves = widget.o2SensorCurves;
    if (curves == null) return const [];

    final minPpO2 = ProfileMetricBands.ppO2.min;
    final maxPpO2 = ProfileMetricBands.ppO2.fixedMax;

    final lines = <({int cell, LineChartBarData bar})>[];
    for (var cell = 0; cell < curves.length; cell++) {
      final spots = _o2CellSpots(
        curves[cell],
        (v) =>
            -band.map(v.toDouble().clamp(minPpO2, maxPpO2), minPpO2, maxPpO2),
      );
      if (spots.isEmpty) continue;
      lines.add((
        cell: cell,
        bar: LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: o2CellColor(cell),
          // Thinner than the aggregate: the cells are the supporting detail,
          // the voted reading stays the headline.
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      ));
    }
    return lines;
  }

  /// Per-cell millivolt lines, drawn alongside the agreement rug: the rug
  /// reads the whole dive at a glance, the lines give the detail behind it.
  /// On an absolute scale the ppO2 swing dominates and the disagreement
  /// between cells is invisible, which is why the rug exists at all.
  List<({int cell, LineChartBarData bar})> _buildO2CellMvLines(
    MetricBand band,
    UnitFormatter units,
  ) {
    final mvCurves = widget.o2CellMvCurves;
    if (mvCurves == null) return const [];
    final range = _getMetricRange(ProfileRightAxisMetric.o2CellMv, units);
    if (range == null || range.max <= range.min) return const [];

    final lines = <({int cell, LineChartBarData bar})>[];
    for (var cell = 0; cell < mvCurves.length; cell++) {
      final spots = _o2CellSpots(
        mvCurves[cell],
        (mv) => -band.map(
          mv.toDouble().clamp(range.min, range.max),
          range.min,
          range.max,
        ),
      );
      if (spots.isEmpty) continue;
      lines.add((
        cell: cell,
        bar: LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: o2CellColor(cell),
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
        ),
      ));
    }
    return lines;
  }

  /// Build ppN2 (partial pressure of nitrogen) line
  LineChartBarData _buildPpN2Line(MetricBand band) => buildPpN2Line(
    band,
    widget.ppN2Curve!,
    _getPpN2MaxScale(),
    widget.profile,
    _decimatedCurveIndices,
    _withSurfaceLeadIn,
    _surfaceValueOf,
    _seriesGetsLeadIn,
  );

  /// Build ppHe (partial pressure of helium) line for trimix dives
  LineChartBarData _buildPpHeLine(MetricBand band) => buildPpHeLine(
    band,
    widget.ppHeCurve!,
    _getPpHeMaxScale(),
    widget.profile,
    _decimatedCurveIndices,
    _withSurfaceLeadIn,
    _surfaceValueOf,
    _seriesGetsLeadIn,
  );

  /// Build MOD (Maximum Operating Depth) line
  /// Shows the MOD limit as a horizontal reference line
  LineChartBarData _buildModLine(UnitFormatter units) => buildModLine(
    units,
    widget.modCurve!,
    widget.profile,
    _decimatedCurveIndices,
    _withFlatSurfaceLeadIn,
  );

  /// Build gas density line (g/L)
  /// High density (>5.7 g/L) increases work of breathing
  LineChartBarData _buildDensityLine(MetricBand band) => buildDensityLine(
    band,
    widget.densityCurve!,
    _getDensityMaxScale(),
    widget.profile,
    _decimatedCurveIndices,
    _withSurfaceLeadIn,
    _surfaceValueOf,
    _seriesGetsLeadIn,
  );

  /// Build GF% (Gradient Factor percentage) line at current depth
  /// Shows how close tissues are to M-value limit
  LineChartBarData _buildGfLine(MetricBand band) => buildGfLine(
    band,
    widget.gfCurve!,
    _getGfMaxScale(),
    widget.profile,
    _decimatedCurveIndices,
    _withFlatSurfaceLeadIn,
    _seriesGetsLeadIn,
  );

  /// Build Surface GF% line (what GF would be if surfaced now)
  /// Values >100% indicate deco obligation
  LineChartBarData _buildSurfaceGfLine(MetricBand band) => buildSurfaceGfLine(
    band,
    widget.surfaceGfCurve!,
    _getSurfaceGfMaxScale(),
    widget.profile,
    _decimatedCurveIndices,
    _withFlatSurfaceLeadIn,
    _seriesGetsLeadIn,
  );

  /// Build mean depth line (running average from start)
  LineChartBarData _buildMeanDepthLine(UnitFormatter units) =>
      buildMeanDepthLine(
        units,
        widget.meanDepthCurve!,
        widget.profile,
        _decimatedCurveIndices,
        _withFlatSurfaceLeadIn,
        _seriesGetsLeadIn,
      );

  /// Compute dynamic max scale for TTS based on actual data. See
  /// [_getGfMaxScale] -- a long/deep technical dive's TTS can genuinely
  /// exceed the usual 60-minute floor.
  double _getTtsMaxScale() {
    final curve = widget.ttsCurve;
    if (curve == null || curve.isEmpty) return ProfileMetricBands.tts.fixedMax;
    final actualMax = curve.reduce(math.max).toDouble();
    return math.max(actualMax, ProfileMetricBands.tts.fixedMax);
  }

  /// Build TTS (Time To Surface) line
  /// Shows total time including deco stops to reach surface
  LineChartBarData _buildTtsLine(MetricBand band) => buildTtsLine(
    band,
    widget.ttsCurve!,
    _getTtsMaxScale(),
    widget.profile,
    _decimatedCurveIndices,
    _withFlatSurfaceLeadIn,
    _seriesGetsLeadIn,
  );

  /// Build the gas time remaining line.
  ///
  /// Null samples are where the computer (or the calculation) blanked the
  /// value, so the line breaks there instead of dropping to zero. No surface
  /// lead-in: GTR is blank on the surface by definition.
  LineChartBarData _buildGtrLine(MetricBand band) => buildGtrLine(
    band,
    widget.gtrCurve!,
    widget.profile,
    _decimatedNullableCurveIndices,
  );

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

  /// Compute dynamic max scale for GF% based on actual data. Floors at the
  /// usual 0-120% band so a normal dive looks the same as before; a dive
  /// whose GF genuinely exceeds that (an over-pressure excursion) scales the
  /// axis to that exact peak instead of clipping to it and, on the chart
  /// itself, spilling past the plot's own top edge (issue #2228 follow-up).
  /// No headroom multiplier: the peak sample sits exactly at the plot's top
  /// edge, same as every other sample sits at its own real value.
  double _getGfMaxScale() {
    final curve = widget.gfCurve;
    if (curve == null || curve.isEmpty) return ProfileMetricBands.gf.fixedMax;
    final actualMax = curve.reduce(math.max);
    return math.max(actualMax, ProfileMetricBands.gf.fixedMax);
  }

  /// Compute dynamic max scale for Surface GF% based on actual data. See
  /// [_getGfMaxScale] -- surface GF routinely runs past 100% and can exceed
  /// even the usual 150% floor on a demanding dive.
  double _getSurfaceGfMaxScale() {
    final curve = widget.surfaceGfCurve;
    if (curve == null || curve.isEmpty) {
      return ProfileMetricBands.surfaceGf.fixedMax;
    }
    final actualMax = curve.reduce(math.max);
    return math.max(actualMax, ProfileMetricBands.surfaceGf.fixedMax);
  }

  /// Compute dynamic max scale for ppO2 based on actual data. See
  /// [_getGfMaxScale] -- a CCR loop malfunction or deep bailout can genuinely
  /// exceed the usual 2.0 bar floor.
  double _getPpO2MaxScale() {
    final curve = widget.ppO2Curve;
    if (curve == null || curve.isEmpty) return ProfileMetricBands.ppO2.fixedMax;
    final actualMax = curve.reduce(math.max);
    return math.max(actualMax, ProfileMetricBands.ppO2.fixedMax);
  }

  /// Compute dynamic max scale for ppN2 based on actual data. See
  /// [_getGfMaxScale].
  double _getPpN2MaxScale() {
    final curve = widget.ppN2Curve;
    if (curve == null || curve.isEmpty) return ProfileMetricBands.ppN2.fixedMax;
    final actualMax = curve.reduce(math.max);
    return math.max(actualMax, ProfileMetricBands.ppN2.fixedMax);
  }

  /// Compute dynamic max scale for ppHe based on actual data. See
  /// [_getGfMaxScale].
  double _getPpHeMaxScale() {
    final curve = widget.ppHeCurve;
    if (curve == null || curve.isEmpty) return ProfileMetricBands.ppHe.fixedMax;
    final actualMax = curve.reduce(math.max);
    return math.max(actualMax, ProfileMetricBands.ppHe.fixedMax);
  }

  /// Compute dynamic max scale for gas density based on actual data. See
  /// [_getGfMaxScale].
  double _getDensityMaxScale() {
    final curve = widget.densityCurve;
    if (curve == null || curve.isEmpty) {
      return ProfileMetricBands.density.fixedMax;
    }
    final actualMax = curve.reduce(math.max);
    return math.max(actualMax, ProfileMetricBands.density.fixedMax);
  }

  /// Build cumulative CNS% line
  LineChartBarData _buildCnsLine(MetricBand band) => buildCnsLine(
    band,
    widget.cnsCurve!,
    _getCnsMaxScale(),
    widget.profile,
    _decimatedCurveIndices,
    _withFlatSurfaceLeadIn,
    _seriesGetsLeadIn,
  );

  /// Build cumulative OTU line
  LineChartBarData _buildOtuLine(MetricBand band) => buildOtuLine(
    band,
    widget.otuCurve!,
    _getOtuMaxScale(),
    widget.profile,
    _decimatedCurveIndices,
    _withFlatSurfaceLeadIn,
    _seriesGetsLeadIn,
  );

  /// Translucent band for the externally highlighted time range. [span] is
  /// precomputed by [_buildChart] via [highlightBandSpan]: clamped to the
  /// visible window and inflated to the 12 px minimum, so instants and short
  /// ranges render the same visible band as wide ones.
  ///
  /// The secondary ranges (cell divergence runs) come first so the primary
  /// band paints over them; they are clamped to the visible window and
  /// drawn only while the O2 cell overlay is on, since that is the overlay
  /// they explain.
  List<VerticalRangeAnnotation> _buildHighlightRangeAnnotations(
    ({double x1, double x2})? span, {
    required double visibleMinX,
    required double visibleMaxX,
  }) {
    final annotations = <VerticalRangeAnnotation>[];
    if (_showO2Cells) {
      for (final range in widget.secondaryRanges) {
        final visible = visibleHighlightSpan(
          range,
          visibleMinX: visibleMinX,
          visibleMaxX: visibleMaxX,
        );
        if (visible == null) continue;
        annotations.add(
          VerticalRangeAnnotation(
            x1: visible.x1,
            x2: visible.x2,
            color: range.color.withValues(alpha: 0.10),
          ),
        );
      }
    }
    final range = widget.highlightRange;
    if (range != null && span != null) {
      annotations.add(
        VerticalRangeAnnotation(
          x1: span.x1,
          x2: span.x2,
          color: range.color.withValues(alpha: 0.12),
        ),
      );
    }
    return annotations;
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

    // Drop events attributed to a computer that's been toggled off (a null
    // computerId is treated as the primary computer, see _isComputerVisible),
    // and the app's own computed events when that legend toggle is off
    // (issue #1523).
    final visibleEvents = events
        .where(
          (e) =>
              _isComputerVisible(e.computerId) &&
              (_showComputedEvents || e.source != EventSource.computed),
        )
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
        text: TextSpan(
          text: kept[i].eventType.localizedName(context.l10n),
          style: labelStyle,
        ),
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
        labelResolver: (line) => event.eventType.localizedName(context.l10n),
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
  bool _hasDataForMetric(ProfileRightAxisMetric metric) => hasDataForMetric(
    metric,
    widget,
    hasMultiTankPressure: _hasMultiTankPressure,
  );

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
  ) => getMetricRange(
    metric,
    units,
    widget,
    hasMultiTankPressure: _hasMultiTankPressure,
    cnsMaxScale: _getCnsMaxScale(),
    otuMaxScale: _getOtuMaxScale(),
    gfMaxScale: _getGfMaxScale(),
    surfaceGfMaxScale: _getSurfaceGfMaxScale(),
    ttsMaxScale: _getTtsMaxScale(),
    ppO2MaxScale: _getPpO2MaxScale(),
    ppN2MaxScale: _getPpN2MaxScale(),
    ppHeMaxScale: _getPpHeMaxScale(),
    densityMaxScale: _getDensityMaxScale(),
    o2CellMvMax: _o2CellMvMax,
    ascentRateAxisRange: _ascentRateAxisRange,
  );

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
      case ProfileRightAxisMetric.gtr:
        return (value / 60).round().toString();
      case ProfileRightAxisMetric.cns:
      case ProfileRightAxisMetric.otu:
        return value.toStringAsFixed(0);
      case ProfileRightAxisMetric.o2CellMv:
        return value.toStringAsFixed(0);
    }
  }

  /// Build axis label text for the right axis (e.g. "Temp (°C)").
  String _rightAxisLabel(ProfileRightAxisMetric metric, UnitFormatter units) =>
      rightAxisLabel(metric, units, context.l10n);
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

/// How an overlay trace reaches the left edge of the chart.
enum _OverlayLeadIn {
  /// Hold the first value flat back to the surface.
  flat,

  /// Compute the value the metric would have had at the surface.
  computed,
}
