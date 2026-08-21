import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// Loop setpoints for a rebreather remainder: high below [switchDepth], low
/// above, inert gas from [diluent].
class LoopSetpoints {
  const LoopSetpoints({
    required this.low,
    required this.high,
    required this.switchDepth,
    required this.diluent,
  });
  final double low;
  final double high;
  final double switchDepth;
  final GasMix diluent;
}

class SynthesizedRemainder {
  const SynthesizedRemainder({
    required this.timestamps,
    required this.depths,
    required this.gasSegments,
    required this.tankSwitches,
    required this.bottomEndTimestamp,
  });
  final List<int> timestamps;
  final List<double> depths;
  final List<ProfileGasSegment> gasSegments;
  final List<ScenarioGasSwitch> tankSwitches;

  /// Timestamp where the plan's user segments end and the computed ascent
  /// starts (consumption switches from bottom to deco SAC here).
  final int bottomEndTimestamp;
}

class _Builder {
  _Builder(this.plan, this.loop, this.step) : tanks = plan.tanks;
  final domain.DivePlan plan;
  final LoopSetpoints? loop;
  final int step;
  final List<DiveTank> tanks;
  final timestamps = <int>[];
  final depths = <double>[];
  final gasSegments = <ProfileGasSegment>[];
  final tankSwitches = <ScenarioGasSwitch>[];
  double? _fN2;
  double? _fHe;
  double? _setpoint;
  String? _tankId;

  int get now => timestamps.last;

  void sample(int t, double d) {
    if (timestamps.isNotEmpty && t <= timestamps.last) return;
    timestamps.add(t);
    depths.add(d);
  }

  void gas({
    required int t,
    required double fN2,
    required double fHe,
    String? tankId,
    double? setpoint,
  }) {
    if (_fN2 == fN2 && _fHe == fHe && _setpoint == setpoint) return;
    gasSegments.add(
      ProfileGasSegment(
        startTimestamp: t,
        fN2: fN2,
        fHe: fHe,
        setpoint: setpoint,
      ),
    );
    _fN2 = fN2;
    _fHe = fHe;
    _setpoint = setpoint;
    if (tankId != null && tankId != _tankId) {
      tankSwitches.add(ScenarioGasSwitch(timestamp: t, tankId: tankId));
      _tankId = tankId;
    }
  }

  /// Gas in force at [depth] on the computed ascent.
  void ascentGasAt(int t, double depth, AscentGasPlan ascentPlan) {
    final l = loop;
    if (l != null) {
      gas(
        t: t,
        fN2: fN2Of(l.diluent),
        fHe: l.diluent.he / 100.0,
        setpoint: depth > l.switchDepth ? l.high : l.low,
      );
      return;
    }
    final g = ascentPlan.gasForDepth(depth);
    final fO2 = 1.0 - g.fN2 - g.fHe;
    gas(t: t, fN2: g.fN2, fHe: g.fHe, tankId: tankIdForMix(tanks, fO2, g.fHe));
  }

  /// Linear leg from the current depth to [toDepth] over [seconds], sampled
  /// every [step] seconds; gas re-evaluated at each sample.
  void leg(double toDepth, int seconds, void Function(int t, double d) gasAt) {
    if (seconds <= 0) return;
    final fromDepth = depths.last;
    final start = now;
    for (var s = step; s < seconds; s += step) {
      final d = fromDepth + (toDepth - fromDepth) * s / seconds;
      sample(start + s, d);
      gasAt(start + s, d);
    }
    sample(start + seconds, toDepth);
    gasAt(start + seconds, toDepth);
  }
}

/// The carried tank whose mix matches [fO2]/[fHe]; deco/stage roles win
/// ties (mirrors PlanEngine's private rule).
String? tankIdForMix(List<DiveTank> tanks, double fO2, double fHe) {
  DiveTank? match;
  for (final tank in tanks) {
    final tankFO2 = tank.gasMix.o2 / 100.0;
    final tankFHe = tank.gasMix.he / 100.0;
    if ((tankFO2 - fO2).abs() < 0.005 && (tankFHe - fHe).abs() < 0.005) {
      final isDeco = tank.role == TankRole.deco || tank.role == TankRole.stage;
      if (match == null ||
          (isDeco &&
              match.role != TankRole.deco &&
              match.role != TankRole.stage)) {
        match = tank;
      }
    }
  }
  return match?.id;
}

/// Samples for the counterfactual remainder: the plan's segments, then the
/// engine's ascent and stops, then the final leg to the surface.
SynthesizedRemainder synthesizeRemainder({
  required domain.DivePlan plan,
  required PlanOutcome outcome,
  required int startTimestamp,
  required double startDepth,
  required AscentGasPlan ascentPlan,
  LoopSetpoints? loop,
  int stepSeconds = 10,
  int extraLastStopSeconds = 0,
}) {
  final b = _Builder(plan, loop, stepSeconds);
  b.sample(startTimestamp, startDepth);

  final segments = List<PlanSegment>.from(plan.segments)
    ..sort((x, y) => x.order.compareTo(y.order));
  void segmentGas(PlanSegment s) => b.gas(
    t: b.now,
    fN2: fN2Of(s.gasMix),
    fHe: s.gasMix.he / 100.0,
    tankId: s.tankId,
    setpoint: loop == null
        ? null
        : (s.avgDepth > loop.switchDepth ? loop.high : loop.low),
  );
  for (final s in segments) {
    segmentGas(s);
    if (s.durationSeconds <= 0) {
      // A zero-duration hold (ascend-now anchor) adds no time.
      continue;
    }
    b.leg(s.endDepth, s.durationSeconds, (t, d) => segmentGas(s));
  }
  final bottomEnd = b.now;

  var depth = b.depths.last;
  final stops = outcome.stops;
  for (var k = 0; k < stops.length; k++) {
    final stop = stops[k];
    final legSeconds = ((depth - stop.depthMeters) / plan.ascentRate * 60)
        .round();
    b.leg(
      stop.depthMeters,
      legSeconds,
      (t, d) => b.ascentGasAt(t, d, ascentPlan),
    );
    b.ascentGasAt(b.now, stop.depthMeters, ascentPlan);
    final hold =
        stop.durationSeconds +
        (k == stops.length - 1 ? extraLastStopSeconds : 0);
    b.leg(stop.depthMeters, hold, (t, d) => b.ascentGasAt(t, d, ascentPlan));
    depth = stop.depthMeters;
  }
  if (depth > 0) {
    final legSeconds = (depth / plan.ascentRate * 60).round();
    b.leg(0.0, legSeconds, (t, d) => b.ascentGasAt(t, d, ascentPlan));
  }
  if (b.depths.last != 0.0) {
    b.sample(b.now + 1, 0.0);
  }
  if (b.gasSegments.isEmpty) {
    b.ascentGasAt(startTimestamp, startDepth, ascentPlan);
  }
  return SynthesizedRemainder(
    timestamps: b.timestamps,
    depths: b.depths,
    gasSegments: b.gasSegments,
    tankSwitches: b.tankSwitches,
    bottomEndTimestamp: bottomEnd,
  );
}

class SplicedProfile {
  const SplicedProfile({
    required this.timestamps,
    required this.depths,
    required this.gasSegments,
  });
  final List<int> timestamps;
  final List<double> depths;
  final List<ProfileGasSegment> gasSegments;
}

/// Actual samples 0..[branchIndex] followed by [remainder] (whose first
/// sample is the branch sample itself and is dropped). Gas segments: the
/// actual ones in force before the branch, then the remainder's.
SplicedProfile spliceCounterfactual({
  required List<int> actualTimestamps,
  required List<double> actualDepths,
  required List<ProfileGasSegment> actualGasSegments,
  required int branchIndex,
  required SynthesizedRemainder remainder,
}) {
  final branchTs = actualTimestamps[branchIndex];
  final timestamps = <int>[...actualTimestamps.sublist(0, branchIndex + 1)];
  final depths = <double>[...actualDepths.sublist(0, branchIndex + 1)];
  for (var i = 0; i < remainder.timestamps.length; i++) {
    if (remainder.timestamps[i] <= branchTs) continue;
    timestamps.add(remainder.timestamps[i]);
    depths.add(remainder.depths[i]);
  }
  final gas = <ProfileGasSegment>[
    for (final g in actualGasSegments)
      if (g.startTimestamp < branchTs) g,
  ];
  for (final g in remainder.gasSegments) {
    if (gas.isNotEmpty && gas.last.startTimestamp == g.startTimestamp) {
      gas[gas.length - 1] = g;
    } else {
      gas.add(g);
    }
  }
  if (gas.isEmpty || gas.first.startTimestamp > timestamps.first) {
    gas.insert(
      0,
      actualGasSegments.isNotEmpty
          ? actualGasSegments.first
          : remainder.gasSegments.first,
    );
  }
  return SplicedProfile(
    timestamps: timestamps,
    depths: depths,
    gasSegments: gas,
  );
}
