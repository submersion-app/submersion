import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/core/profile/surfacing_pressure.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/cylinder_breath_starts.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_time_suggestions.dart';

/// A moment the cylinder pressures say the diver started breathing a
/// cylinder, as stored in a missing-switch finding's params (issue #165).
///
/// [tankPosition] is the cylinder's 0-based index in dive order, as the
/// transmitter role finding stores it; its text adds one for the number the
/// switch editor and the cylinders card show.
typedef MissedSwitch = ({
  String tankId,
  int tankPosition,
  int t,
  double depth,
  double o2Percent,
  double hePercent,
});

/// A start deeper than its gas's MOD, with that MOD in meters.
typedef DeepStart = ({MissedSwitch start, double modMeters});

/// The switches a dive's cylinder pressures show although no computer
/// logged one: [addable] are safe to write as gas switches, [deep] started
/// deeper than their gas's MOD and are only reported. [unplaced] is a
/// cylinder breathed again after a pause on a dive with more than two
/// cylinders: another was breathed in between and the pressures cannot say
/// which, so nothing is [addable].
typedef MissedSwitches = ({
  List<MissedSwitch> addable,
  List<DeepStart> deep,
  MissedSwitch? unplaced,
});

const MissedSwitches _none = (
  addable: <MissedSwitch>[],
  deep: <DeepStart>[],
  unplaced: null,
);

/// The gas switches [ctx]'s recorded cylinder pressures show on an
/// open-circuit dive that logged none (issue #165).
///
/// Each cylinder's turns come from [cylinderBreathTurns], the detector the
/// switch editor's time chips use (#4089). The dive starts on its first
/// cylinder in dive order, the one the gas timeline assumes, so a turn is a
/// switch only when it moves the diver off the cylinder in use. A cylinder
/// that feeds a rebreather loop drains whatever the diver breathes and is
/// left out, and so are rebreather dives, whose bailout the role checks
/// judge, and a dive whose empty switch list the diver left that way in the
/// editor. A turn deeper than its gas's MOD (with the switch-depth check's
/// tolerance) is never offered as a switch, and leaves the cylinder in use
/// unchanged.
///
/// A start follows a hold, so a start on the cylinder in use means the
/// diver left it for another one when its breathing before stopped: on a
/// two-cylinder dive, the other one, and the return is a switch too. With
/// more cylinders the pressures cannot say which, and no switch is offered.
/// A cylinder that held from its first reading was never breathed before,
/// so its start on the first cylinder adds nothing. On a two-cylinder dive
/// the cylinder in use last, left for good while the diver stayed in the
/// water for a hold's length, hands over to the other one as well.
MissedSwitches missedGasSwitches(DiveQualityContext ctx) {
  if (ctx.gasSwitches.isNotEmpty) return _none;
  if (ctx.dive.gasSwitchesEdited) return _none;
  if (ctx.dive.diveMode != DiveMode.oc) return _none;
  if (ctx.primarySamples.isEmpty) return _none;

  final ordered = [...ctx.tanks]..sort((a, b) => a.order.compareTo(b.order));
  final breathed = [
    for (final tank in ordered)
      if (hasBreathingStarts(tank)) tank,
  ];
  if (breathed.length < 2) return _none;

  final positionById = {
    for (var i = 0; i < ordered.length; i++) ordered[i].id: i,
  };
  final lastSampleT = ctx.primarySamples.last.t;
  final turnsById = {
    for (final tank in breathed)
      tank.id: cylinderBreathTurns([
        for (final p in ctx.pressuresByTankId[tank.id] ?? const [])
          (t: p.t, bar: p.bar),
      ]),
  };
  // Ties go to dive order, so two cylinders starting on one second give the
  // same suggestion on every scan (List.sort is not stable).
  final turns =
      <({DiveTank tank, int t, int? previousEnd})>[
        for (final tank in breathed)
          for (final turn in turnsById[tank.id]!.starts)
            if (turn.t <= lastSampleT)
              (tank: tank, t: turn.t, previousEnd: turn.previousEnd),
      ]..sort((a, b) {
        final byTime = a.t.compareTo(b.t);
        return byTime != 0
            ? byTime
            : positionById[a.tank.id]!.compareTo(positionById[b.tank.id]!);
      });

  MissedSwitch startOf(DiveTank tank, int t) => (
    tankId: tank.id,
    tankPosition: positionById[tank.id]!,
    t: t,
    depth: _depthAt(ctx.primarySamples, t),
    o2Percent: tank.gasMix.o2,
    hePercent: tank.gasMix.he,
  );

  final addable = <MissedSwitch>[];
  final deep = <DeepStart>[];
  var inUse = ordered.first.id;

  // Offers a switch to [tank] at [t], unless it shares the last switch's
  // second (the switch editor allows one a second) or lies deeper than the
  // gas's MOD. [reported] says whether a too-deep one is named.
  void offer(DiveTank tank, int t, {bool reported = true}) {
    if (addable.isNotEmpty && addable.last.t == t) return;
    final missed = startOf(tank, t);
    final mod = maxOperatingDepthMeters(
      tank.gasMix.o2 / 100.0,
      maxPpO2: ctx.ppO2MaxBar,
      environment: ctx.dive.environment,
    );
    if (missed.depth > mod + QualityThresholds.modToleranceMeters) {
      if (reported) deep.add((start: missed, modMeters: mod));
      return;
    }
    addable.add(missed);
    inUse = tank.id;
  }

  // On a two-cylinder dive, the diver left the cylinder in use at [left]
  // for the other one. A too-deep start of that one at the same moment is
  // already named; naming the inferred switch too would say it twice.
  void handOver(int left) {
    final other = breathed.firstWhere((c) => c.id != inUse);
    offer(
      other,
      left,
      reported: !deep.any(
        (d) =>
            d.start.tankId == other.id &&
            (d.start.t - left).abs() <= kGasSwitchClaimSeconds,
      ),
    );
  }

  for (final turn in turns) {
    if (turn.tank.id == inUse) {
      final left = turn.previousEnd;
      if (left == null) continue;
      if (breathed.length != 2) {
        return (
          addable: const <MissedSwitch>[],
          deep: deep,
          unplaced: startOf(turn.tank, turn.t),
        );
      }
      handOver(left);
      if (turn.tank.id == inUse) continue;
    }
    offer(turn.tank, turn.t);
  }

  final heldFrom = turnsById[inUse]?.heldFrom;
  final inWaterEnd = lastTimeBelowSurfaceThreshold(
    ctx.primarySamples.map((s) => (t: s.t, depth: s.depth)),
  );
  if (breathed.length == 2 &&
      heldFrom != null &&
      (addable.isEmpty || heldFrom > addable.last.t) &&
      inWaterEnd != null &&
      inWaterEnd - heldFrom >= kBreathHoldSeconds) {
    handOver(heldFrom);
  }
  return (addable: addable, deep: deep, unplaced: null);
}

/// The depth at [t], interpolated linearly between the bracketing samples
/// as the switch editor's profile lookup does (`profileDepthAt`), and the
/// nearest end sample's depth outside them. [samples] is in time order.
double _depthAt(List<QualitySample> samples, int t) {
  if (t <= samples.first.t) return samples.first.depth;
  if (t >= samples.last.t) return samples.last.depth;
  // The last sample at or before t; the one after it is strictly later.
  var lo = 0;
  var hi = samples.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (samples[mid].t <= t) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  final a = samples[lo];
  final b = samples[lo + 1];
  final span = b.t - a.t;
  if (span <= 0) return b.depth;
  return a.depth + (b.depth - a.depth) * (t - a.t) / span;
}

/// [missed] as a JSON-safe map for a finding's params.
Map<String, Object?> missedSwitchParams(MissedSwitch missed, {double? mod}) => {
  'tankId': missed.tankId,
  'tankPosition': missed.tankPosition,
  't': missed.t,
  'depth': missed.depth,
  'o2Percent': missed.o2Percent,
  'hePercent': missed.hePercent,
  'modMeters': ?mod,
};
