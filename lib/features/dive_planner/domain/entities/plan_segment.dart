import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;

/// A single authored waypoint in a dive plan.
///
/// A segment says where the diver is going and how long they spend getting
/// there and staying: a target depth and a duration. It deliberately does not
/// carry a start depth or a declared type. Both are properties of the segment's
/// position in the profile rather than of the segment, and storing them let
/// them drift out of agreement with each other - a segment declared Descent
/// could hold a shallower target than its start, and a reorder could leave one
/// segment ending at 30 m and the next starting at 12 m, which the deco model
/// then integrated as an 18 m ascent in zero time.
///
/// `SegmentChain.resolve` turns a list of these into `ResolvedLeg`s carrying
/// start depth, phase and rate. Everything downstream consumes those.
///
/// Example plan, as authored:
/// 1. target 30 m, 3 min  -> resolves to a descent 0 m to 30 m
/// 2. target 30 m, 20 min -> resolves to the bottom, level at 30 m
/// 3. target 6 m, 3 min   -> resolves to an ascent 30 m to 6 m
/// 4. target 6 m, 5 min   -> resolves to a stop at 6 m
///
/// A gas switch is not a segment. It is a segment carrying a different
/// [tankId] than the one before it, which is exactly what the engine charges
/// gas against.
class PlanSegment extends Equatable {
  /// Unique identifier for this segment.
  final String id;

  /// The depth in metres this segment arrives at and holds.
  ///
  /// Equal to the previous segment's target for a flat leg. Persisted in the
  /// `end_depth` column, whose meaning is unchanged.
  final double targetDepth;

  /// Duration of this segment in seconds.
  final int durationSeconds;

  /// Reference to the tank being breathed during this segment.
  final String tankId;

  /// The gas mix being breathed during this segment.
  /// Stored directly for convenience, should match the referenced tank.
  final GasMix gasMix;

  /// Per-segment CCR setpoint override in bar; null = the plan's depth-based
  /// setpoint (Subsurface per-segment setpoint, v120).
  final double? setpointBar;

  /// Per-segment dive-mode override; null = the plan's mode. Models mid-plan
  /// bailout (e.g. a CCR plan with an OC segment), v120.
  final PlanMode? diveModeOverride;

  /// Order of this segment in the plan (0-indexed).
  final int order;

  const PlanSegment({
    required this.id,
    required this.targetDepth,
    required this.durationSeconds,
    required this.tankId,
    required this.gasMix,
    this.setpointBar,
    this.diveModeOverride,
    this.order = 0,
  });

  /// Duration formatted as MM:SS.
  String get durationFormatted {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create a copy with updated fields.
  PlanSegment copyWith({
    String? id,
    double? targetDepth,
    int? durationSeconds,
    String? tankId,
    GasMix? gasMix,
    double? setpointBar,
    PlanMode? diveModeOverride,
    int? order,
    bool clearSetpointBar = false,
    bool clearDiveModeOverride = false,
  }) {
    return PlanSegment(
      id: id ?? this.id,
      targetDepth: targetDepth ?? this.targetDepth,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      tankId: tankId ?? this.tankId,
      gasMix: gasMix ?? this.gasMix,
      setpointBar: clearSetpointBar ? null : (setpointBar ?? this.setpointBar),
      diveModeOverride: clearDiveModeOverride
          ? null
          : (diveModeOverride ?? this.diveModeOverride),
      order: order ?? this.order,
    );
  }

  /// Seconds a depth change of [metres] takes at [ratePerMinute].
  ///
  /// A non-positive rate has no defined travel time, so it yields zero rather
  /// than an infinity that would propagate into the schedule.
  static int travelSeconds({
    required double metres,
    required double ratePerMinute,
  }) {
    if (ratePerMinute <= 0) return 0;
    return ((metres.abs() / ratePerMinute) * 60).round();
  }

  /// A waypoint reached by travelling from [fromDepth] at [ratePerMinute].
  ///
  /// Replaces the old `descent` and `ascent` factories: the direction is the
  /// sign of `targetDepth - fromDepth`, so there is only one factory and no
  /// way to declare a direction the depths contradict.
  factory PlanSegment.travel({
    required String id,
    required double fromDepth,
    required double targetDepth,
    required String tankId,
    required GasMix gasMix,
    required double ratePerMinute,
    double? setpointBar,
    PlanMode? diveModeOverride,
    int order = 0,
  }) {
    return PlanSegment(
      id: id,
      targetDepth: targetDepth,
      durationSeconds: travelSeconds(
        metres: targetDepth - fromDepth,
        ratePerMinute: ratePerMinute,
      ),
      tankId: tankId,
      gasMix: gasMix,
      setpointBar: setpointBar,
      diveModeOverride: diveModeOverride,
      order: order,
    );
  }

  /// A waypoint that holds [depth] for [durationMinutes].
  ///
  /// Replaces the old `bottom`, `decoStop` and `safetyStop` factories, which
  /// differed only in the type they stamped on an otherwise identical segment.
  /// Whether this reads as the bottom or as a stop is decided by where it
  /// lands in the profile.
  factory PlanSegment.hold({
    required String id,
    required double depth,
    required int durationMinutes,
    required String tankId,
    required GasMix gasMix,
    double? setpointBar,
    PlanMode? diveModeOverride,
    int order = 0,
  }) {
    return PlanSegment(
      id: id,
      targetDepth: depth,
      durationSeconds: durationMinutes * 60,
      tankId: tankId,
      gasMix: gasMix,
      setpointBar: setpointBar,
      diveModeOverride: diveModeOverride,
      order: order,
    );
  }

  @override
  List<Object?> get props => [
    id,
    targetDepth,
    durationSeconds,
    tankId,
    gasMix,
    setpointBar,
    diveModeOverride,
    order,
  ];
}
