import 'dart:math' as math;

import 'package:submersion/core/deco/ascent/ccr_loop_ascent_gas.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';

/// [stretch] of the leg [segment] describes, cut where it crosses [plan]'s
/// setpoint switch depth: the loop changes setpoint there, so breathing the
/// whole stretch on one setpoint would load the tissues and the O2 clocks with
/// the wrong one for part of it (#4009).
///
/// Only what is breathed is cut. A ramp stays one leg to the rest of the
/// engine: nearly every CCR descent crosses the switch, and none of them gains
/// a line in the table for it.
///
/// The cut lands on the whole second nearest the crossing, because a
/// [DecoSegment] counts whole seconds, and the depth there is the switch
/// itself, so each piece's mean depth is on its own side of it. A crossing
/// that rounds to either end of the stretch leaves no time to cut off.
///
/// A leg off the loop or on a fixed per-segment setpoint has no switch to
/// cross, so it comes back as it went in, as does a stretch that only reaches
/// the switch without passing it.
List<DecoSegment> splitAtSetpointSwitch(
  domain.DivePlan plan,
  PlanSegment segment,
  DecoSegment stretch,
) {
  if (modeFor(plan, segment) != domain.PlanMode.ccr ||
      segment.setpointBar != null) {
    return [stretch];
  }
  final switchDepth = plan.effectiveSetpointSwitchDepth;
  final start = stretch.startDepth;
  final end = stretch.endDepth;
  if (!CcrLoopAscentGas.crossesSwitch(
    switchDepth,
    deeperDepth: math.max(start, end),
    shallowerDepth: math.min(start, end),
  )) {
    return [stretch];
  }
  final seconds = stretch.durationSeconds;
  final firstSeconds = (seconds * (switchDepth - start) / (end - start))
      .round();
  if (firstSeconds <= 0 || firstSeconds >= seconds) return [stretch];
  return [
    DecoSegment(
      startDepth: start,
      endDepth: switchDepth,
      durationSeconds: firstSeconds,
    ),
    DecoSegment(
      startDepth: switchDepth,
      endDepth: end,
      durationSeconds: seconds - firstSeconds,
    ),
  ];
}
