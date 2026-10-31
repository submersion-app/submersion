import 'package:submersion/core/deco/ascent/loop_ascent_gas.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

/// The closed-circuit loop expressed as a depth-dependent ascent gas: the
/// constant-ppO2 inspired pressures of [ClosedCircuit], at the setpoint in
/// force at each depth (see [LoopAscentGas]).
class CcrLoopAscentGas extends LoopAscentGas {
  CcrLoopAscentGas({
    required this.environment,
    required this.setpointLow,
    required this.setpointHigh,
    required this.switchDepth,
    required this.diluentFO2,
    this.diluentFHe = 0.0,
  });

  @override
  final DiveEnvironment environment;
  final double setpointLow;
  final double setpointHigh;

  /// Deeper than this the loop runs [setpointHigh]; at or above it,
  /// [setpointLow].
  final double switchDepth;
  final double diluentFO2;
  final double diluentFHe;

  /// Setpoint in force at [depthMeters].
  double setpointAt(double depthMeters) =>
      depthMeters > switchDepth ? setpointHigh : setpointLow;

  @override
  double get supplyFO2 => diluentFO2;

  @override
  double get supplyFHe => diluentFHe;

  @override
  BreathingConfig breathingAt(double depthMeters) => ClosedCircuit(
    setpoint: setpointAt(depthMeters),
    diluentFO2: diluentFO2,
    diluentFHe: diluentFHe,
  );

  @override
  List<double> switchDepthsBetween(double deeperDepth, double shallowerDepth) {
    // A setpoint change is a gas change: split ascent legs at the switch.
    if (switchDepth > shallowerDepth + 1e-9 &&
        switchDepth < deeperDepth - 1e-9) {
      return [switchDepth];
    }
    return const [];
  }
}
