import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/cylinder_breath_starts.dart';
import 'package:submersion/features/dive_log/domain/services/gas_switch_time_suggestions.dart';

/// A moment the cylinder pressures say the diver started breathing a
/// cylinder, as stored in a missing-switch finding's params (issue #165).
///
/// [tankPosition] is the cylinder's 1-based number in dive order, the
/// number the switch editor and the cylinders card show.
typedef MissedSwitch = ({
  String tankId,
  int tankPosition,
  int t,
  double depth,
  double o2Percent,
  double hePercent,
});

/// The switches a dive's cylinder pressures show although no computer
/// logged one: [addable] are safe to write as gas switches, [deep] started
/// deeper than their gas's MOD and are only reported, with [deepModMeters]
/// giving each one's MOD in the same order.
typedef MissedSwitches = ({
  List<MissedSwitch> addable,
  List<MissedSwitch> deep,
  List<double> deepModMeters,
});

const MissedSwitches _none = (
  addable: <MissedSwitch>[],
  deep: <MissedSwitch>[],
  deepModMeters: <double>[],
);

/// The gas switches [ctx]'s recorded cylinder pressures show on an
/// open-circuit dive that logged none (issue #165).
///
/// Each cylinder's turns come from [cylinderBreathStarts], the detector the
/// switch editor's time chips use (#4089). The dive starts on its first
/// cylinder in dive order, the one the gas timeline assumes, so a turn is a
/// switch only when it moves the diver off the cylinder in use. A cylinder
/// that feeds a rebreather loop drains whatever the diver breathes and is
/// left out, and so are rebreather dives, whose bailout the role checks
/// judge. A turn deeper than its gas's MOD (with the switch-depth check's
/// tolerance) is never offered as a switch, and leaves the cylinder in use
/// unchanged.
MissedSwitches missedGasSwitches(DiveQualityContext ctx) {
  if (ctx.gasSwitches.isNotEmpty) return _none;
  if (ctx.dive.diveMode != DiveMode.oc) return _none;
  if (ctx.primarySamples.isEmpty) return _none;

  final ordered = [...ctx.tanks]..sort((a, b) => a.order.compareTo(b.order));
  final breathed = [
    for (final tank in ordered)
      if (hasBreathingStarts(tank)) tank,
  ];
  if (breathed.length < 2) return _none;

  final lastSampleT = ctx.primarySamples.last.t;
  final turns = <({DiveTank tank, int t})>[
    for (final tank in breathed)
      for (final t in cylinderBreathStarts([
        for (final p in ctx.pressuresByTankId[tank.id] ?? const [])
          (t: p.t, bar: p.bar),
      ]))
        if (t <= lastSampleT) (tank: tank, t: t),
  ]..sort((a, b) => a.t.compareTo(b.t));
  if (turns.isEmpty) return _none;

  final positionById = {
    for (var i = 0; i < ordered.length; i++) ordered[i].id: i + 1,
  };
  final addable = <MissedSwitch>[];
  final deep = <MissedSwitch>[];
  final deepMods = <double>[];
  var inUse = ordered.first.id;
  for (final turn in turns) {
    final tank = turn.tank;
    if (tank.id == inUse) continue;
    // Two switches cannot share a second, which the switch editor enforces.
    if (addable.isNotEmpty && addable.last.t == turn.t) continue;
    final missed = (
      tankId: tank.id,
      tankPosition: positionById[tank.id]!,
      t: turn.t,
      depth: _depthAt(ctx.primarySamples, turn.t),
      o2Percent: tank.gasMix.o2,
      hePercent: tank.gasMix.he,
    );
    final mod = maxOperatingDepthMeters(
      tank.gasMix.o2 / 100.0,
      maxPpO2: ctx.ppO2MaxBar,
      environment: ctx.dive.environment,
    );
    if (missed.depth > mod + QualityThresholds.modToleranceMeters) {
      deep.add(missed);
      deepMods.add(mod);
      continue;
    }
    addable.add(missed);
    inUse = tank.id;
  }
  return (addable: addable, deep: deep, deepModMeters: deepMods);
}

/// The depth of the last sample at or before [t], or the first sample's
/// when [t] comes before them all. [samples] is in time order.
double _depthAt(List<QualitySample> samples, int t) {
  var lo = 0;
  var hi = samples.length - 1;
  if (samples.first.t >= t) return samples.first.depth;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (samples[mid].t <= t) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return samples[lo].depth;
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
