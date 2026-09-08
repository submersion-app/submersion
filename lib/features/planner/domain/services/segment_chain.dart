import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/segment_phase.dart';

/// A [PlanSegment] plus the geometry a segment cannot know on its own.
///
/// A segment is authored as a waypoint - a target depth and a duration - so
/// where it starts and what it is doing only exist relative to its neighbours.
/// Everything downstream of authoring (the deco model, the chart, gas
/// consumption, contingencies) consumes resolved legs rather than raw
/// segments.
class ResolvedLeg extends Equatable {
  const ResolvedLeg({
    required this.segment,
    required this.startDepth,
    required this.phase,
    required this.runtimeSeconds,
  });

  final PlanSegment segment;

  /// Where this leg begins: the previous leg's target, or the surface.
  final double startDepth;

  /// Derived from the geometry; never stored.
  final SegmentPhase phase;

  /// Elapsed dive time at the END of this leg, in seconds.
  ///
  /// The slate's RT column for the authored part of the dive: the running
  /// total of every leg up to and including this one. The computed deco tail
  /// continues from the last leg's value.
  final int runtimeSeconds;

  double get endDepth => segment.targetDepth;
  int get durationSeconds => segment.durationSeconds;
  String get tankId => segment.tankId;
  GasMix get gasMix => segment.gasMix;

  double get avgDepth => (startDepth + endDepth) / 2;

  /// The deeper of the two ends, for the worst-case ppO2 and density checks.
  double get deeperEnd => math.max(startDepth, endDepth);

  bool get isDepthChange => startDepth != endDepth;

  /// Signed metres per minute, positive descending.
  ///
  /// Null when the leg has no duration, which is the only case where a rate is
  /// undefined rather than merely zero.
  double? get rate {
    if (durationSeconds == 0) return null;
    return (endDepth - startDepth) / (durationSeconds / 60.0);
  }

  /// Elapsed dive time when this leg BEGINS, in seconds.
  int get startRuntimeSeconds => runtimeSeconds - durationSeconds;

  @override
  List<Object?> get props => [segment, startDepth, phase, runtimeSeconds];
}

/// Resolves authored waypoints into the profile they describe.
///
/// Pure: no Flutter, no clock, no I/O.
class SegmentChain {
  const SegmentChain();

  /// Chains [segments] into legs, in the order given.
  ///
  /// List order is authoritative - callers that hold segments out of order
  /// (a repository read, a reorder in progress) sort by `order` first. The
  /// first leg starts at the surface, and every later leg starts where its
  /// predecessor finished, so a depth discontinuity is not representable.
  List<ResolvedLeg> resolve(List<PlanSegment> segments) {
    if (segments.isEmpty) return const [];

    final maxDepth = segments.fold<double>(
      0,
      (deepest, s) => math.max(deepest, s.targetDepth),
    );

    // deepestAfter[i] is the deepest target strictly after i, so a flat leg
    // can tell "the dive still goes deeper later" from "we are on the way up".
    final deepestAfter = List<double>.filled(
      segments.length,
      double.negativeInfinity,
    );
    for (var i = segments.length - 2; i >= 0; i--) {
      deepestAfter[i] = math.max(
        segments[i + 1].targetDepth,
        deepestAfter[i + 1],
      );
    }

    final legs = <ResolvedLeg>[];
    var startDepth = 0.0;
    var runtime = 0;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final endDepth = segment.targetDepth;
      runtime += segment.durationSeconds;

      final SegmentPhase phase;
      if (endDepth > startDepth) {
        phase = SegmentPhase.descent;
      } else if (endDepth < startDepth) {
        phase = SegmentPhase.ascent;
      } else {
        // Flat. It is a stop only once the profile has begun its final
        // ascent: shallower than the deepest point, with nothing deeper
        // still to come. A flat leg at max depth is the bottom, and a flat
        // leg in a multi-level dive that later drops deeper is another
        // bottom, not a stop.
        phase = endDepth < maxDepth && deepestAfter[i] <= endDepth
            ? SegmentPhase.stop
            : SegmentPhase.level;
      }

      legs.add(
        ResolvedLeg(
          segment: segment,
          startDepth: startDepth,
          phase: phase,
          runtimeSeconds: runtime,
        ),
      );
      startDepth = endDepth;
    }
    return legs;
  }

  /// Index of the leg that is "the bottom" of the dive, or null if the diver
  /// has authored no level leg at all.
  ///
  /// The deepest [SegmentPhase.level] leg; the last one wins on a tie, so a
  /// bottom split into two legs at the same depth extends at its far end.
  /// Replaces the old "first segment whose type is bottom" lookups.
  int? bottomLegIndex(List<ResolvedLeg> legs) {
    int? best;
    for (var i = 0; i < legs.length; i++) {
      if (legs[i].phase != SegmentPhase.level) continue;
      if (best == null || legs[i].endDepth >= legs[best].endDepth) best = i;
    }
    return best;
  }
}
