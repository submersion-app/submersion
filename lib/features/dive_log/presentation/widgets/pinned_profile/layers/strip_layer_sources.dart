import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show ChartSourceOverlay;
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_layer_data.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_layers.dart'
    show kPinnedStripPointBudget;
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_bands.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_segment_colors.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';

/// How strongly a phase band tints the strip.
const double kStripPhaseAlpha = 0.18;

/// How strongly a safety finding's window tints the strip.
const double kStripFindingAlpha = 0.22;

/// The colours and names the layers are drawn with: the diver's chart
/// colours, the theme, and how a tank is named.
@immutable
class StripLayerStyle {
  const StripLayerStyle({
    required this.palette,
    required this.brightness,
    required this.colorScheme,
    required this.tankLabel,
  });

  final ProfileMetricPalette palette;
  final Brightness brightness;
  final ColorScheme colorScheme;

  /// The name of [tank], the [index]th in the dive's order (null when the
  /// series names a tank the dive no longer has).
  final String Function(DiveTank? tank, int index) tankLabel;
}

/// The dive data the strip's layers are made from, each as the full chart
/// or its card reads it.
@immutable
class StripLayerInputs {
  const StripLayerInputs({
    required this.profile,
    this.analysis,
    this.tanks,
    this.diveTanks = const [],
    this.gasSwitches = const [],
    this.phases,
    this.media = const [],
    this.annotations = const [],
    this.computerEvents = const [],
    this.findings = const [],
    this.plan,
    this.otherSources = const [],
    this.sacScale = 1,
  });

  /// The series the chart draws (the active source's).
  final List<DiveProfilePoint> profile;
  final ProfileAnalysis? analysis;

  /// Per-tank pressures, estimates included where the full chart draws them.
  final EstimatedTankPressures? tanks;
  final List<DiveTank> diveTanks;
  final List<GasSwitchWithTank> gasSwitches;
  final List<SacSegment>? phases;

  /// When each photo or video was taken, and the depth there.
  final List<({int seconds, double depthMeters})> media;
  final List<ProfileEvent> annotations;
  final List<ProfileEvent> computerEvents;
  final List<SafetyFinding> findings;
  final ChartSourceOverlay? plan;
  final List<ChartSourceOverlay> otherSources;

  /// What the SAC curve is scaled by so it agrees with the dive's own SAC,
  /// as the full chart scales it (`calculateSacNormalizationFactor`).
  final double sacScale;

  /// Whether every input is the same object as [other]'s, so data built
  /// from one serves the other.
  bool sameAs(StripLayerInputs other) =>
      identical(profile, other.profile) &&
      identical(analysis, other.analysis) &&
      identical(tanks, other.tanks) &&
      identical(diveTanks, other.diveTanks) &&
      identical(gasSwitches, other.gasSwitches) &&
      identical(phases, other.phases) &&
      identical(media, other.media) &&
      identical(annotations, other.annotations) &&
      identical(computerEvents, other.computerEvents) &&
      identical(findings, other.findings) &&
      identical(plan, other.plan) &&
      sacScale == other.sacScale &&
      _sameList(otherSources, other.otherSources);

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}

/// Every layer the strip can draw for this dive (issue #4562).
PinnedStripLayerData buildStripLayerData(
  StripLayerInputs inputs,
  StripLayerStyle style,
) {
  final profile = inputs.profile;
  if (profile.length < 2) return PinnedStripLayerData.empty;
  final analysis = inputs.analysis;
  final end = profile.last.timestamp;
  Color colorOf(ProfileMetric metric) => style.palette.colorOf(metric);

  StripLine? indexed(
    StripLayer layer,
    ProfileMetric metric,
    List<double?>? curve, {
    double? min,
    double? max,
    double? maxFloor,
    double pad = 0,
    bool breakAtNull = false,
  }) {
    if (curve == null) return null;
    final count = math.min(curve.length, profile.length);
    final runs = _runs([
      for (var i = 0; i < count; i++)
        curve[i] == null
            ? null
            : StripPoint(profile[i].timestamp, curve[i]!.toDouble()),
    ], breakAtNull: breakAtNull);
    return _line(
      layer,
      layer.name,
      colorOf(metric),
      runs,
      min: min,
      max: max,
      maxFloor: maxFloor,
      pad: pad,
      byIndex: List.unmodifiable(curve.take(count)),
    );
  }

  final lines = <StripLine?>[
    // A degree of room each side, as the full chart's temperature axis.
    indexed(StripLayer.temperature, ProfileMetric.temperature, [
      for (final p in profile) p.temperature,
    ], pad: 1),
    indexed(
      StripLayer.cns,
      ProfileMetric.cns,
      analysis?.cnsCurve,
      min: ProfileMetricBands.cns.min,
    ),
    indexed(
      StripLayer.surfaceGf,
      ProfileMetric.surfaceGf,
      analysis?.surfaceGfCurve,
      min: ProfileMetricBands.surfaceGf.min,
      // As the full chart: its band, or past it when the dive goes higher.
      maxFloor: ProfileMetricBands.surfaceGf.fixedMax,
    ),
    ..._tankLines(inputs, style, end),
    indexed(
      StripLayer.gtr,
      ProfileMetric.gtr,
      [for (final s in analysis?.gtrCurve ?? const <int?>[]) s?.toDouble()],
      min: ProfileMetricBands.gtr.min,
      max: ProfileMetricBands.gtr.fixedMax,
      breakAtNull: true,
    ),
    // The smoothed curve, as the full chart draws it: the raw one swings
    // sample to sample. A sample with no rate is a gap, not a zero.
    indexed(StripLayer.sac, ProfileMetric.sac, [
      for (final v in analysis?.smoothedSacCurve ?? const <double>[])
        v > 0 ? v * inputs.sacScale : null,
    ]),
    indexed(
      StripLayer.tts,
      ProfileMetric.tts,
      [for (final s in analysis?.ttsCurve ?? const <int>[]) s.toDouble()],
      min: ProfileMetricBands.tts.min,
      maxFloor: ProfileMetricBands.tts.fixedMax,
    ),
    indexed(StripLayer.heartRate, ProfileMetric.heartRate, [
      for (final p in profile) p.heartRate?.toDouble(),
    ]),
  ];

  return PinnedStripLayerData(
    lines: List.unmodifiable(lines.nonNulls),
    bands: List.unmodifiable([
      ..._phaseBands(inputs.phases, style),
      ..._findingBands(inputs.findings, style),
    ]),
    ticks: List.unmodifiable(_ticks(inputs, style)),
    dots: List.unmodifiable([
      for (final m in inputs.media)
        if (m.seconds <= end)
          StripDot(seconds: m.seconds, depthMeters: m.depthMeters),
    ]),
    ghosts: List.unmodifiable(
      [
        if (inputs.plan case final plan?)
          _ghost(StripLayer.plannedDepth, plan, end),
        for (final source in inputs.otherSources)
          _ghost(StripLayer.sourceDepths, source, end),
      ].nonNulls,
    ),
  );
}

/// [points] (null where there is no value) as runs: one run skipping the
/// nulls, or a new run after each null when [breakAtNull].
List<List<StripPoint>> _runs(
  List<StripPoint?> points, {
  required bool breakAtNull,
}) {
  final runs = <List<StripPoint>>[];
  var current = <StripPoint>[];
  for (final p in points) {
    if (p != null) {
      current.add(p);
    } else if (breakAtNull && current.isNotEmpty) {
      runs.add(current);
      current = <StripPoint>[];
    }
  }
  if (current.isNotEmpty) runs.add(current);
  return runs;
}

/// A line through [runs], each thinned to the strip's point budget, ranging
/// [min] to [max] where given and over its own values otherwise. Null with
/// no points.
StripLine? _line(
  StripLayer layer,
  String key,
  Color color,
  List<List<StripPoint>> runs, {
  double? min,
  double? max,
  double? maxFloor,
  double pad = 0,
  bool estimated = false,
  String? label,
  List<double?>? byIndex,
  List<TankPressurePoint>? pressures,
}) {
  if (runs.isEmpty) return null;
  final values = [
    for (final run in runs)
      for (final p in run) p.value,
  ];
  final thinned = [for (final run in runs) _thinned(run)];
  final dropped = Iterable<int>.generate(
    runs.length,
  ).any((i) => thinned[i].length != runs[i].length);
  final low = min ?? values.reduce(math.min) - pad;
  var high = max ?? values.reduce(math.max) + pad;
  if (maxFloor != null) high = math.max(high, maxFloor);
  // A fixed floor with nothing above it (no CNS at all) keeps its line at
  // the floor: a flat series on its own range would sit half way up.
  if (min != null && high <= low) high = low + 1;
  return StripLine(
    layer: layer,
    key: key,
    color: color,
    runs: List.unmodifiable(thinned),
    valueRuns: dropped
        ? List<List<StripPoint>>.unmodifiable([
            for (final run in runs) List<StripPoint>.unmodifiable(run),
          ])
        : null,
    min: low,
    max: high,
    estimated: estimated,
    label: label,
    byIndex: byIndex,
    pressures: pressures,
  );
}

List<StripPoint> _thinned(List<StripPoint> run) {
  final kept = decimateSeriesIndices([
    for (final p in run) p.value,
  ], targetPoints: kPinnedStripPointBudget);
  return List.unmodifiable(
    kept.length == run.length ? run : [for (final i in kept) run[i]],
  );
}

/// One line per tank, sharing one pressure range so they compare at a
/// glance, in the dive's tank order.
List<StripLine> _tankLines(
  StripLayerInputs inputs,
  StripLayerStyle style,
  int end,
) {
  final series = inputs.tanks;
  if (series == null) return const [];
  final ordered = series.pressures.keys.toList()
    ..sort((a, b) {
      int order(String id) {
        final i = inputs.diveTanks.indexWhere((t) => t.id == id);
        return i < 0 ? inputs.diveTanks.length : i;
      }

      return order(a).compareTo(order(b));
    });
  final runs = {
    for (final id in ordered)
      id: [
        for (final p in series.pressures[id]!)
          if (p.timestamp <= end) StripPoint(p.timestamp, p.pressure),
      ],
  }..removeWhere((_, points) => points.isEmpty);
  if (runs.isEmpty) return const [];
  final all = [
    for (final points in runs.values)
      for (final p in points) p.value,
  ];
  final min = all.reduce(math.min);
  final max = all.reduce(math.max);
  return [
    for (final (i, id) in runs.keys.indexed)
      ?_line(
        StripLayer.tankPressure,
        id,
        _tankColor(inputs.diveTanks, id, style),
        [runs[id]!],
        min: min,
        max: max,
        estimated: series.estimatedTankIds.contains(id),
        label: style.tankLabel(_tank(inputs.diveTanks, id), i),
        // Read whole, as the Cylinders card reads it at the cursor.
        pressures: series.pressures[id],
      ),
  ];
}

DiveTank? _tank(List<DiveTank> tanks, String id) {
  for (final t in tanks) {
    if (t.id == id) return t;
  }
  return null;
}

Color _tankColor(List<DiveTank> tanks, String id, StripLayerStyle style) {
  final tank = _tank(tanks, id);
  return tank == null
      ? style.palette.colorOf(ProfileMetric.pressure)
      : GasColors.forGasMix(tank.gasMix);
}

/// Each phase once: the breakdown repeats a phase for every tank breathed
/// in it.
List<StripBand> _phaseBands(List<SacSegment>? phases, StripLayerStyle style) {
  if (phases == null) return const [];
  final seen = <(int, int, DivePhase)>{};
  return [
    for (final s in phases)
      if (s.phase case final phase?)
        if (seen.add((s.startTimestamp, s.endTimestamp, phase)))
          StripBand(
            layer: StripLayer.phases,
            start: s.startTimestamp,
            end: s.endTimestamp,
            color: SacSegmentColors.forPhase(phase, style.brightness),
            alpha: kStripPhaseAlpha,
            phase: phase,
          ),
  ];
}

/// The windows of the findings the diver has not dismissed; one with no
/// end is a tick ([_ticks]) and one with no start is not drawn.
List<StripBand> _findingBands(
  List<SafetyFinding> findings,
  StripLayerStyle style,
) => [
  for (final f in findings)
    if (f.dismissedAt == null &&
        f.startTimestamp != null &&
        f.endTimestamp != null)
      StripBand(
        layer: StripLayer.safetyFindings,
        start: f.startTimestamp!,
        end: f.endTimestamp!,
        color: safetySeverityColor(f.severity, style.colorScheme),
        alpha: kStripFindingAlpha,
        finding: f,
      ),
];

List<StripTick> _ticks(StripLayerInputs inputs, StripLayerStyle style) {
  const annotationColor = ProfileMetricColors.annotation;
  return [
    for (final s in inputs.gasSwitches)
      StripTick(
        layer: StripLayer.gasSwitches,
        seconds: s.gasSwitch.timestamp,
        color: GasColors.forMixFraction(s.o2Fraction, s.heFraction),
        edge: StripTickEdge.bottom,
      ),
    for (final a in inputs.annotations)
      StripTick(
        layer: StripLayer.annotations,
        seconds: a.timestamp,
        color: annotationColor,
        edge: StripTickEdge.top,
      ),
    for (final e in inputs.computerEvents)
      if (e.eventType == ProfileEventType.bookmark)
        StripTick(
          layer: StripLayer.annotations,
          seconds: e.timestamp,
          color: annotationColor,
          edge: StripTickEdge.top,
          hollow: true,
        ),
    for (final f in inputs.findings)
      if (f.dismissedAt == null &&
          f.startTimestamp != null &&
          f.endTimestamp == null)
        StripTick(
          layer: StripLayer.safetyFindings,
          seconds: f.startTimestamp!,
          color: safetySeverityColor(f.severity, style.colorScheme),
          edge: StripTickEdge.top,
        ),
  ];
}

/// [overlay] as a ghost line, up to [end], the end of the dive: past it the
/// strip has no room, and a deeper stretch there would only squeeze the
/// dive's own depth line for nothing seen.
StripGhost? _ghost(StripLayer layer, ChartSourceOverlay overlay, int end) {
  final points = [
    for (final p in overlay.points)
      if (p.timestamp <= end) StripPoint(p.timestamp, p.depth),
  ];
  if (points.length < 2) return null;
  final thinned = _thinned(points);
  return StripGhost(
    layer: layer,
    key: overlay.sourceId,
    label: overlay.name,
    color: overlay.color,
    points: thinned,
    valuePoints: thinned.length == points.length
        ? null
        : List<StripPoint>.unmodifiable(points),
  );
}
