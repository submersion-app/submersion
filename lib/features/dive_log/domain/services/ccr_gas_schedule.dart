import 'package:equatable/equatable.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// What a recorded gas switch means on a closed-circuit dive (issue #577).
enum CcrGasChangeKind {
  /// The diver is on the loop, breathing over this diluent.
  diluent,

  /// The diver has bailed out and breathes this cylinder open circuit.
  openCircuit,
}

/// A change of breathing gas on a CCR dive, derived from a gas switch and
/// the role of the cylinder switched to.
class CcrGasChange extends Equatable {
  const CcrGasChange({
    required this.timestamp,
    required this.kind,
    required this.fN2,
    this.fHe = 0.0,
  });

  /// Seconds from dive start.
  final int timestamp;
  final CcrGasChangeKind kind;

  /// Nitrogen fraction (0.0-1.0) of the diluent or open-circuit gas.
  final double fN2;

  /// Helium fraction (0.0-1.0) of the diluent or open-circuit gas.
  final double fHe;

  @override
  List<Object?> get props => [timestamp, kind, fN2, fHe];
}

/// Classifies a CCR dive's gas switches by the role of the cylinder switched
/// to. A diluent switch puts the diver on the loop over that diluent (ending a
/// bailout); a switch to any open-circuit cylinder is a bailout onto it. The
/// O2 supply feeds the loop, so a switch to it while on the loop is dropped;
/// once bailed out it is open circuit on O2.
///
/// [TankRole.backGas] is the role a file import gives a cylinder it knows
/// nothing about, so on a CCR dive it is read as loop gas, never as a
/// bailout: the O2 supply when it holds pure O2, otherwise a diluent (the
/// same tank [resolveCcrDiluentMix] falls back to). Only a cylinder
/// explicitly marked bailout, deco, stage, pony or sidemount starts one.
///
/// [tanks] is the cylinder set the analysed computer breathed: a switch to a
/// cylinder outside it is dropped. The result is ordered by timestamp, ties
/// broken by switch id as the open-circuit schedule does.
List<CcrGasChange> classifyCcrGasChanges(
  List<GasSwitchWithTank> switches,
  List<DiveTank> tanks,
) {
  final roles = {for (final tank in tanks) tank.id: ccrCylinderRole(tank)};
  final ordered =
      switches.where((s) => roles.containsKey(s.gasSwitch.tankId)).toList()
        ..sort((a, b) {
          final byTime = a.gasSwitch.timestamp.compareTo(b.gasSwitch.timestamp);
          return byTime != 0
              ? byTime
              : a.gasSwitch.id.compareTo(b.gasSwitch.id);
        });

  var onLoop = true;
  final changes = <CcrGasChange>[];
  for (final gasSwitch in ordered) {
    final kind = switch (roles[gasSwitch.gasSwitch.tankId]!) {
      TankRole.diluent => CcrGasChangeKind.diluent,
      TankRole.oxygenSupply => onLoop ? null : CcrGasChangeKind.openCircuit,
      _ => CcrGasChangeKind.openCircuit,
    };
    if (kind == null) continue;
    onLoop = kind == CcrGasChangeKind.diluent;
    changes.add(
      CcrGasChange(
        timestamp: gasSwitch.gasSwitch.timestamp,
        kind: kind,
        fN2: gasSwitch.isAir ? airN2Fraction : gasSwitch.n2Fraction,
        fHe: gasSwitch.heFraction,
      ),
    );
  }
  return changes;
}

/// The role a CCR dive's cylinder plays in [classifyCcrGasChanges] and in
/// its bailout ascent gases: an untagged (back gas) cylinder is loop gas, the
/// O2 supply when it holds pure O2 and otherwise a diluent (see
/// [classifyCcrGasChanges]).
TankRole ccrCylinderRole(DiveTank tank) {
  if (tank.role != TankRole.backGas) return tank.role;
  return tank.gasMix.o2 >= 99.0 ? TankRole.oxygenSupply : TankRole.diluent;
}

/// Builds the CCR gas schedule for decompression analysis: the loop ppO2 as
/// each loop segment's setpoint over the diluent breathed at that point, so
/// the engine loads tissues at constant ppO2 (inspired inert = ambient - loop
/// ppO2, split by the diluent's He:N2 ratio) and holds the setpoint through
/// the TTS ascent.
///
/// [loopPpO2Curve] is the per-sample resolved loop ppO2, aligned with
/// [timestamps]. On the loop a new segment starts when the value moves more
/// than [setpointTolerance] bar from the active setpoint, tracking real
/// setpoint switches without a segment per noisy cell sample.
/// [fallbackSetpoint] (the dive-level setpoint) stands in when no curve
/// exists. Returns null when neither exists: with no loop ppO2 information the
/// loop cannot be modelled.
///
/// [gasChanges] ([classifyCcrGasChanges], time-ordered) switch the diluent or
/// bail out (issue #577). A bailout segment carries no setpoint: the diver
/// breathes that cylinder open circuit, and loop ppO2 movement is ignored
/// until a diluent change returns them to the loop, re-seeded from the loop
/// ppO2 at the switch. A change between two samples takes the loop ppO2 of the
/// sample before it. Changes before the first sample are dropped; one at the
/// first sample replaces the seed.
///
/// The first segment starts at the first profile timestamp, which on a
/// secondary computer's own bucket of a multi-source dive can be negative.
List<ProfileGasSegment>? buildCcrProfileGasSegments({
  required List<int> timestamps,
  required List<double>? loopPpO2Curve,
  required GasMix diluentMix,
  double? fallbackSetpoint,
  double setpointTolerance = 0.05,
  List<CcrGasChange> gasChanges = const [],
}) {
  final curve =
      timestamps.isNotEmpty &&
          loopPpO2Curve != null &&
          loopPpO2Curve.length == timestamps.length
      ? loopPpO2Curve
      : null;
  if (curve == null && fallbackSetpoint == null) return null;
  double setpointAt(int index) =>
      curve != null ? curve[index] : fallbackSetpoint!;

  final seed = timestamps.isEmpty ? 0 : timestamps.first;
  var loopFN2 = diluentMix.isAir
      ? airN2Fraction
      : (100.0 - diluentMix.o2 - diluentMix.he) / 100.0;
  var loopFHe = diluentMix.he / 100.0;
  var onLoop = true;
  var openFN2 = 0.0;
  var openFHe = 0.0;

  ProfileGasSegment segmentAt(int start, double setpoint) => onLoop
      ? ProfileGasSegment(
          startTimestamp: start,
          fN2: loopFN2,
          fHe: loopFHe,
          setpoint: setpoint,
        )
      : ProfileGasSegment(startTimestamp: start, fN2: openFN2, fHe: openFHe);

  final segments = <ProfileGasSegment>[];
  void emit(ProfileGasSegment next) {
    if (segments.isNotEmpty &&
        segments.last.startTimestamp == next.startTimestamp) {
      segments.removeLast();
    }
    if (segments.isNotEmpty && _sameGas(segments.last, next)) return;
    segments.add(next);
  }

  final changes = gasChanges.where((c) => c.timestamp >= seed).toList();
  var nextChange = 0;
  for (var i = 0; i < timestamps.length; i++) {
    final timestamp = timestamps[i];
    while (nextChange < changes.length &&
        changes[nextChange].timestamp <= timestamp) {
      final change = changes[nextChange++];
      if (change.kind == CcrGasChangeKind.diluent) {
        loopFN2 = change.fN2;
        loopFHe = change.fHe;
        onLoop = true;
      } else {
        openFN2 = change.fN2;
        openFHe = change.fHe;
        onLoop = false;
      }
      final setpointIndex = change.timestamp < timestamp ? i - 1 : i;
      emit(segmentAt(change.timestamp, setpointAt(setpointIndex)));
    }
    // A change landing on this sample already carries its loop ppO2, so the
    // tolerance check below is a no-op for it; one landing between samples
    // still needs this sample's reading checked.
    if (segments.isEmpty) {
      emit(segmentAt(seed, setpointAt(0)));
    } else if (onLoop &&
        (setpointAt(i) - segments.last.setpoint!).abs() > setpointTolerance) {
      emit(segmentAt(timestamp, setpointAt(i)));
    }
  }
  if (segments.isEmpty) emit(segmentAt(seed, fallbackSetpoint!));
  return segments;
}

/// Whether a CCR loop schedule from [buildCcrProfileGasSegments] contains a
/// bailout: a segment with no setpoint, breathed open circuit.
bool hasOpenCircuitBailout(List<ProfileGasSegment>? loopSchedule) =>
    loopSchedule != null && loopSchedule.any((s) => s.setpoint == null);

bool _sameGas(ProfileGasSegment a, ProfileGasSegment b) =>
    a.fN2 == b.fN2 &&
    a.fHe == b.fHe &&
    a.setpoint == b.setpoint &&
    a.loopHoldsSetpoint == b.loopHoldsSetpoint;

/// The ppO2 a CCR diver breathed at each sample, for display: the loop's own
/// resolved [loopCurve] while on the loop, and the analysed open-circuit ppO2
/// ([analysedCurve], ambient x FO2) on samples after a bailout, where the O2
/// cells read a loop no longer breathed (issue #577).
List<double> breathedPpO2Curve({
  required List<double> loopCurve,
  required List<double> analysedCurve,
  required List<int> timestamps,
  required List<ProfileGasSegment> segments,
}) {
  // Both lists are time-ordered, so one index walks the segments once.
  var active = 0;
  return List<double>.generate(timestamps.length, (i) {
    while (active + 1 < segments.length &&
        segments[active + 1].startTimestamp <= timestamps[i]) {
      active++;
    }
    final openCircuit =
        segments.isNotEmpty && segments[active].setpoint == null;
    return openCircuit ? analysedCurve[i] : loopCurve[i];
  });
}
