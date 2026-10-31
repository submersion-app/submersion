import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

/// A rebreather loop expressed as a depth-dependent ascent gas.
///
/// The loop's inspired partial pressures divide by the alveolar pressure to
/// give EXACT effective inert fractions, so the unchanged Bühlmann stop-search
/// machinery (which multiplies fractions back by alveolar pressure) reproduces
/// the loop's loading at every stop. Ascent legs use the fraction at the leg's
/// deeper end, the same approximation open-circuit legs already make.
///
/// Those fractions are bookkeeping for the tissue simulation, not a mix anyone
/// breathes: they can drift with depth on one unchanged supply gas, and on a
/// hypoxic passive loop they sum past 1. Read [supplyFO2]/[supplyFHe] for what
/// the cylinder holds and [inspiredPpO2At] for what the diver inspires.
abstract class LoopAscentGas extends AscentGasPlan {
  /// The water and surface conditions the loop's depths are measured in.
  DiveEnvironment get environment;

  /// O2 fraction of the gas feeding the loop: its cylinder's mix.
  double get supplyFO2;

  /// He fraction of the gas feeding the loop: its cylinder's mix.
  double get supplyFHe;

  /// What the diver breathes on the loop at [depthMeters].
  BreathingConfig breathingAt(double depthMeters);

  /// The loop's real inspired ppO2 at [depthMeters].
  double inspiredPpO2At(double depthMeters) => breathingAt(
    depthMeters,
  ).inspiredAt(environment.pressureAtDepth(depthMeters)).pO2;

  @override
  AscentGas gasForDepth(double depthMeters) {
    final ambient = environment.pressureAtDepth(depthMeters);
    final pAlv = ambient - waterVaporPressure;
    if (pAlv <= 0) return const AscentGas(fN2: 0, fHe: 0);
    final inspired = breathingAt(depthMeters).inspiredAt(ambient);
    return AscentGas(fN2: inspired.pN2 / pAlv, fHe: inspired.pHe / pAlv);
  }
}

/// A semi-closed loop, constant-mass-flow ([Scr]) or passive ([PassiveScr]),
/// held from the bottom to the surface.
///
/// It stays on [breathing] the whole way up: the diver has no setpoint to
/// change and no reason to leave the loop for the richer gas that feeds it, so
/// there is never a switch to split an ascent leg at.
class SemiClosedLoopAscentGas extends LoopAscentGas {
  SemiClosedLoopAscentGas({required this.environment, required this.breathing});

  @override
  final DiveEnvironment environment;

  /// The loop the diver is on. Depth-independent as a value: it answers per
  /// ambient pressure.
  final SemiClosedBreathing breathing;

  @override
  double get supplyFO2 => breathing.supplyFO2;

  @override
  double get supplyFHe => breathing.supplyFHe;

  @override
  BreathingConfig breathingAt(double depthMeters) => breathing;

  @override
  List<double> switchDepthsBetween(double deeperDepth, double shallowerDepth) =>
      const [];
}
