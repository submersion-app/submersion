import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

/// The closed-circuit loop expressed as a depth-dependent ascent gas.
///
/// At a constant depth the loop's inspired partial pressures (constant-ppO2
/// via [ClosedCircuit]) divide by the alveolar pressure to give EXACT
/// effective inert fractions — so the unchanged Bühlmann stop-search
/// machinery (which multiplies fractions back by alveolar pressure)
/// reproduces constant-ppO2 loading at every stop. Ascent legs use the
/// fraction at the leg's deeper end, the same approximation open-circuit
/// legs already make.
class CcrLoopAscentGas extends AscentGasPlan {
  CcrLoopAscentGas({
    required this.environment,
    required this.setpointLow,
    required this.setpointHigh,
    required this.switchDepth,
    required this.diluentFO2,
    this.diluentFHe = 0.0,
  });

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
  AscentGas gasForDepth(double depthMeters) {
    final ambient = environment.pressureAtDepth(depthMeters);
    final pAlv = ambient - waterVaporPressure;
    if (pAlv <= 0) return const AscentGas(fN2: 0, fHe: 0);
    final inspired = ClosedCircuit(
      setpoint: setpointAt(depthMeters),
      diluentFO2: diluentFO2,
      diluentFHe: diluentFHe,
    ).inspiredAt(ambient);
    return AscentGas(fN2: inspired.pN2 / pAlv, fHe: inspired.pHe / pAlv);
  }

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
