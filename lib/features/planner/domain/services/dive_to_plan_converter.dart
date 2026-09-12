import 'dart:math' as math;

import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:uuid/uuid.dart';

/// A waypoint of the simplified profile: elapsed seconds from the first
/// sample and the snapped depth in metres. Consecutive breakpoints become
/// plan segments (target depth plus duration), so a pair at the same depth is
/// a hold and a pair at different depths is a ramp.
class PlanBreakpoint {
  const PlanBreakpoint({required this.timeSeconds, required this.depth});

  final int timeSeconds;
  final double depth;
}

/// Converts a logged [Dive] into an unsaved [DivePlanState] the "What if..."
/// flow opens in the planner: the diver can then nudge depth, time or gas and
/// see how it changes deco and gas need relative to what they actually did.
///
/// The profile is reduced to waypoints in two layers:
///
/// 1. Core milestones, always present regardless of detail: the start of the
///    dive, the start and end of the bottom phase and every gas switch, plus a
///    coarse Ramer-Douglas-Peucker pass that keeps every large change of
///    shape (a second working level, the start of the ascent). Level 1 is
///    exactly these, so even the coarsest plan keeps the real descent time
///    and the real bottom time.
/// 2. Detail points, added between milestones by a finer RDP pass whose
///    tolerance shrinks as [convert]'s `levels` grows, so higher detail only
///    ever adds segments between the milestones.
///
/// The plan is authored only up to the last hold at working depth (at or
/// deeper than half the max depth). The ascent, any decompression stops and
/// the surfacing are deliberately not authored: the plan engine computes them
/// from that point, so the planner shows its own TTS and deco schedule for the
/// diver to compare against what the dive computer actually did.
class DiveToPlanConverter {
  const DiveToPlanConverter();

  /// Detail levels supported by [convert] and [breakpoints].
  static const int minLevels = 1;
  static const int maxLevels = 5;

  /// RDP tolerance as a fraction of max depth for levels 1..5. Level 1 is the
  /// coarse milestone pass; each further level refines between milestones.
  static const List<double> _toleranceFractions = [
    0.25,
    0.15,
    0.09,
    0.05,
    0.025,
  ];

  /// The bottom phase is every sample at or deeper than this fraction of
  /// max depth.
  static const double _bottomFraction = 0.9;

  /// Samples at or deeper than this fraction of max depth are working depth;
  /// the plan is authored up to the last of them, shallower stops are left
  /// for the engine to plan.
  static const double _workingLevelFraction = 0.5;

  /// A final waypoint within this fraction of max depth of the level before
  /// it is treated as the end of that level rather than a new ramp.
  static const double _levelSnapFraction = 0.15;

  /// Detail points closer than this to their predecessor are dropped so no
  /// segment is shorter than a planner would ever author.
  static const int _minSegmentSeconds = 30;

  DivePlanState convert({
    required Dive dive,
    required List<DiveProfilePoint> profile,
    required List<GasSwitch> gasSwitches,
    required int levels,
    required String planName,
    required DivePlanState defaults,
    List<TissueCompartment>? initialTissueState,
    Duration? surfaceInterval,
    String Function()? idGenerator,
  }) {
    assert(levels >= minLevels && levels <= maxLevels);
    final newId = idGenerator ?? _defaultId;

    final tanks = _mapTanks(dive, defaults, gasSwitches);
    final points = breakpoints(
      profile: profile,
      gasSwitches: gasSwitches,
      levels: levels,
    );
    final firstTimestamp = profile.isEmpty
        ? 0
        : profile.map((p) => p.timestamp).reduce(math.min);

    final segments = _buildSegments(
      breakpoints: points,
      tanks: tanks,
      gasSwitches: gasSwitches,
      firstTimestamp: firstTimestamp,
      idGenerator: newId,
    );

    final now = DateTime.now();
    final diveWater = dive.effectiveWaterType;
    return DivePlanState(
      id: newId(),
      name: planName,
      segments: segments,
      tanks: tanks,
      // The computer's own gradient factors, when it logged them, so the
      // replanned deco is judged by the same rule the dive was run on.
      gfLow: dive.gradientFactorLow ?? defaults.gfLow,
      gfHigh: dive.gradientFactorHigh ?? defaults.gfHigh,
      altitude: dive.altitude ?? defaults.altitude,
      waterType: diveWater ?? defaults.waterType,
      salinityPpt: diveWater != null ? null : defaults.salinityPpt,
      sacRate: defaults.sacRate,
      ascentRate: defaults.ascentRate,
      intermediateAscentRate: defaults.intermediateAscentRate,
      shallowAscentRate: defaults.shallowAscentRate,
      finalAscentRate: defaults.finalAscentRate,
      lastStopDepth: defaults.lastStopDepth,
      descentRate: defaults.descentRate,
      reservePressure: defaults.reservePressure,
      surfaceInterval: surfaceInterval,
      initialTissueState: initialTissueState,
      sourceDiveId: dive.id,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Ids of the cylinders the diver actually breathed from: the one carried
  /// into the water, every switch target, and any cylinder whose logged
  /// pressure dropped. A carried cylinder outside this set was never used, so
  /// the What-if plan marks it lost to follow what really happened.
  static Set<String> usedTankIds(Dive dive, List<GasSwitch> gasSwitches) {
    if (dive.tanks.isEmpty) return const {};
    final ordered = [...dive.tanks]..sort((a, b) => a.order.compareTo(b.order));
    final used = <String>{ordered.first.id};
    for (final s in gasSwitches) {
      used.add(s.tankId);
    }
    for (final t in dive.tanks) {
      final start = t.startPressure;
      final end = t.endPressure;
      if (start != null && end != null && start - end > 0) used.add(t.id);
    }
    return used;
  }

  /// The simplified waypoints for [profile] at [levels], relative to the
  /// first sample. Exposed so a preview can draw exactly what [convert]
  /// will produce.
  List<PlanBreakpoint> breakpoints({
    required List<DiveProfilePoint> profile,
    required List<GasSwitch> gasSwitches,
    required int levels,
  }) {
    final sorted = [...profile]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (sorted.length < 2) return const [];

    final t0 = sorted.first.timestamp;
    final pts = [
      for (final p in sorted) _Point((p.timestamp - t0).toDouble(), p.depth),
    ];

    final maxDepth = pts.fold(0.0, (m, p) => math.max(m, p.y));
    if (maxDepth <= 0) return const [];

    final endIndex = _workingEndIndex(pts, maxDepth);
    final anchors = _anchorIndices(
      pts,
      endIndex: endIndex,
      maxDepth: maxDepth,
      gasSwitchTimes: [for (final g in gasSwitches) g.timestamp - t0],
    );

    final indices = <int>{...anchors.all};
    final tolerance = maxDepth * _toleranceFractions[levels - minLevels];
    for (var i = 0; i < anchors.all.length - 1; i++) {
      final start = anchors.all[i];
      final span = pts.sublist(start, anchors.all[i + 1] + 1);
      for (final k in _rdp(span, tolerance)) {
        indices.add(start + k);
      }
    }

    final ordered = indices.toList()..sort();
    // With nothing authored between the bottom milestones the bottom is one
    // hold, so give it the mean depth of the real bottom phase rather than
    // the deepest spike. Once detail points split the bottom, every waypoint
    // (the milestones included) sits on the sampled profile.
    final bottomIsSingleHold = !ordered.any(
      (i) => i > anchors.bottomStart && i < anchors.bottomEnd,
    );
    final bottomDepth = _snapDepth(
      bottomIsSingleHold
          ? _meanDepth(pts, anchors.bottomStart, anchors.bottomEnd)
          : maxDepth,
    );

    final result = <PlanBreakpoint>[];
    final resultIsAnchor = <bool>[];
    for (final i in ordered) {
      final isAnchor = anchors.all.contains(i);
      final isBottomEdge =
          bottomIsSingleHold &&
          (i == anchors.bottomStart || i == anchors.bottomEnd);
      final depth = isBottomEdge ? bottomDepth : _snapDepth(pts[i].y);
      final time = pts[i].x.round();
      if (result.isNotEmpty) {
        var gap = time - result.last.timeSeconds;
        if (gap <= 0) continue;
        if (gap < _minSegmentSeconds) {
          // Detail points yield to milestones: drop a detail point that would
          // crowd the milestone after it, and skip one that crowds the point
          // before it.
          if (!isAnchor) continue;
          if (!resultIsAnchor.last) {
            result.removeLast();
            resultIsAnchor.removeLast();
            gap = time - result.last.timeSeconds;
            if (gap <= 0) continue;
          }
        }
      }
      result.add(PlanBreakpoint(timeSeconds: time, depth: depth));
      resultIsAnchor.add(isAnchor);
    }
    return _trimTrailingRamp(result, maxDepth);
  }

  /// The plan must end on a hold so the engine ascends from a level, not from
  /// the middle of a logged ascent. A tail that has barely left the last level
  /// (the working-depth cut landing a little way into the next ascent) is
  /// folded back onto that level; a steeper tail is dropped. The bottom hold
  /// always survives.
  List<PlanBreakpoint> _trimTrailingRamp(
    List<PlanBreakpoint> points,
    double maxDepth,
  ) {
    final nearLevel = maxDepth * _levelSnapFraction;
    var trimmed = points;
    while (trimmed.length > 2) {
      final last = trimmed.last;
      final prev = trimmed[trimmed.length - 2];
      if (last.depth == prev.depth) break;
      if ((last.depth - prev.depth).abs() <= nearLevel) {
        trimmed = [
          ...trimmed.sublist(0, trimmed.length - 1),
          PlanBreakpoint(timeSeconds: last.timeSeconds, depth: prev.depth),
        ];
        break;
      }
      trimmed = trimmed.sublist(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Last sample at working depth: everything after it (the final ascent,
  /// stops, surfacing) is left to the plan engine.
  int _workingEndIndex(List<_Point> pts, double maxDepth) {
    final threshold = maxDepth * _workingLevelFraction;
    for (var i = pts.length - 1; i >= 0; i--) {
      if (pts[i].y >= threshold) return i;
    }
    return pts.length - 1;
  }

  /// Core milestone indices: start, bottom start, gas switches, bottom end,
  /// end of the working portion.
  _Anchors _anchorIndices(
    List<_Point> pts, {
    required int endIndex,
    required double maxDepth,
    required List<int> gasSwitchTimes,
  }) {
    final threshold = maxDepth * _bottomFraction;
    var bottomStart = endIndex;
    for (var i = 0; i <= endIndex; i++) {
      if (pts[i].y >= threshold) {
        bottomStart = i;
        break;
      }
    }
    var bottomEnd = bottomStart;
    for (var i = endIndex; i >= bottomStart; i--) {
      if (pts[i].y >= threshold) {
        bottomEnd = i;
        break;
      }
    }

    final switches = <int>{};
    for (final t in gasSwitchTimes) {
      final idx = _nearestIndex(pts, t.toDouble());
      if (idx > 0 && idx < endIndex) switches.add(idx);
    }

    final all = <int>{0, bottomStart, ...switches, bottomEnd, endIndex}.toList()
      ..sort();
    return _Anchors(all: all, bottomStart: bottomStart, bottomEnd: bottomEnd);
  }

  int _nearestIndex(List<_Point> pts, double time) {
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final d = (pts[i].x - time).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  static const _uuid = Uuid();

  static String _defaultId() => _uuid.v4();

  /// The dive's cylinders, limited to the ones actually breathed (see
  /// [usedTankIds]): the engine plans deco on every tank it is given, so a
  /// carried-but-unused bottle would otherwise change the schedule.
  List<DiveTank> _mapTanks(
    Dive dive,
    DivePlanState defaults,
    List<GasSwitch> gasSwitches,
  ) {
    if (dive.tanks.isEmpty) {
      return defaults.tanks.isNotEmpty ? defaults.tanks : const [];
    }
    final used = usedTankIds(dive, gasSwitches);
    return dive.tanks
        .where((t) => used.contains(t.id))
        .map(
          (t) => DiveTank(
            id: t.id,
            name: t.name,
            volume: t.volume,
            workingPressure: t.workingPressure,
            startPressure: t.startPressure,
            gasMix: t.gasMix,
            role: t.role,
            order: t.order,
          ),
        )
        .toList();
  }

  double _snapDepth(double depth) => depth.roundToDouble();

  double _meanDepth(List<_Point> pts, int from, int to) {
    if (to <= from) return pts[from].y;
    var sum = 0.0;
    for (var i = from; i <= to; i++) {
      sum += pts[i].y;
    }
    return sum / (to - from + 1);
  }

  /// Ramer-Douglas-Peucker over (time, depth); returns kept indices into
  /// [points], endpoints included. Deviation is measured vertically (metres
  /// off the straight line between the ends) so seconds and metres never mix.
  List<int> _rdp(List<_Point> points, double epsilon) {
    if (points.length < 3) return [0, points.length - 1];

    var index = -1;
    var maxDist = 0.0;
    final first = points.first;
    final last = points.last;
    for (var i = 1; i < points.length - 1; i++) {
      final dist = _verticalDistance(points[i], first, last);
      if (dist > maxDist) {
        maxDist = dist;
        index = i;
      }
    }

    if (maxDist > epsilon && index > 0) {
      final left = _rdp(points.sublist(0, index + 1), epsilon);
      final right = _rdp(points.sublist(index), epsilon);
      return [...left, for (final r in right.skip(1)) index + r];
    }
    return [0, points.length - 1];
  }

  double _verticalDistance(_Point p, _Point a, _Point b) {
    final dx = b.x - a.x;
    if (dx == 0) return (p.y - a.y).abs();
    final expected = a.y + (b.y - a.y) * (p.x - a.x) / dx;
    return (p.y - expected).abs();
  }

  List<PlanSegment> _buildSegments({
    required List<PlanBreakpoint> breakpoints,
    required List<DiveTank> tanks,
    required List<GasSwitch> gasSwitches,
    required int firstTimestamp,
    required String Function() idGenerator,
  }) {
    if (breakpoints.length < 2 || tanks.isEmpty) return const [];

    final sortedSwitches = [...gasSwitches]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    DiveTank tankAt(int absoluteTimestamp) {
      String? tankId;
      for (final s in sortedSwitches) {
        if (s.timestamp <= absoluteTimestamp) {
          tankId = s.tankId;
        } else {
          break;
        }
      }
      return tanks.firstWhere((t) => t.id == tankId, orElse: () => tanks.first);
    }

    final segments = <PlanSegment>[];
    for (var i = 0; i < breakpoints.length - 1; i++) {
      final from = breakpoints[i];
      final to = breakpoints[i + 1];
      final duration = to.timeSeconds - from.timeSeconds;
      if (duration <= 0) continue;
      // A switch logged at this waypoint applies to the leg that starts here.
      final tank = tankAt(firstTimestamp + from.timeSeconds);
      segments.add(
        PlanSegment(
          id: idGenerator(),
          targetDepth: to.depth,
          durationSeconds: duration,
          tankId: tank.id,
          gasMix: tank.gasMix,
          order: segments.length,
        ),
      );
    }
    return segments;
  }
}

class _Anchors {
  const _Anchors({
    required this.all,
    required this.bottomStart,
    required this.bottomEnd,
  });

  final List<int> all;
  final int bottomStart;
  final int bottomEnd;
}

class _Point {
  const _Point(this.x, this.y);
  final double x;
  final double y;
}
