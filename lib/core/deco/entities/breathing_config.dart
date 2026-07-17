import 'dart:math' as math;

import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/scr_calculator.dart';

/// Partial pressures of the inspired gas at some ambient pressure.
class InspiredGas {
  const InspiredGas({required this.pN2, required this.pHe, required this.pO2});

  final double pN2;
  final double pHe;
  final double pO2;
}

/// What the diver is breathing, independent of depth.
///
/// The engine asks a BreathingConfig for inspired partial pressures at an
/// ambient pressure; open circuit, constant-ppO2 CCR, and steady-state SCR
/// answer differently. All account for alveolar water vapor.
sealed class BreathingConfig {
  const BreathingConfig();

  /// Inspired partial pressures at [ambientPressureBar].
  InspiredGas inspiredAt(double ambientPressureBar);
}

/// Open circuit: fixed gas fractions at ambient pressure.
class OpenCircuit extends BreathingConfig {
  const OpenCircuit({required this.fO2, this.fHe = 0.0});

  final double fO2;
  final double fHe;

  double get fN2 => 1.0 - fO2 - fHe;

  @override
  InspiredGas inspiredAt(double ambientPressureBar) {
    final pAlv = math.max(ambientPressureBar - waterVaporPressure, 0.0);
    return InspiredGas(pN2: pAlv * fN2, pHe: pAlv * fHe, pO2: pAlv * fO2);
  }
}

/// Closed-circuit rebreather at a constant ppO2 setpoint.
///
/// Inspired inert pressure is what remains of the alveolar pressure after
/// the setpoint's O2, split by the diluent's N2:He ratio. Shallower than
/// the setpoint the loop is effectively pure O2 (the O2 pressure is capped
/// by the available alveolar pressure).
class ClosedCircuit extends BreathingConfig {
  const ClosedCircuit({
    required this.setpoint,
    required this.diluentFO2,
    this.diluentFHe = 0.0,
  });

  final double setpoint;
  final double diluentFO2;
  final double diluentFHe;

  double get diluentFN2 => 1.0 - diluentFO2 - diluentFHe;

  @override
  InspiredGas inspiredAt(double ambientPressureBar) {
    final pAlv = math.max(ambientPressureBar - waterVaporPressure, 0.0);
    final pO2 = math.min(setpoint, pAlv);
    final pInert = math.max(pAlv - pO2, 0.0);
    final inertFraction = diluentFN2 + diluentFHe;
    if (inertFraction <= 0) {
      return InspiredGas(pN2: 0, pHe: 0, pO2: pAlv);
    }
    final n2Share = diluentFN2 / inertFraction;
    return InspiredGas(
      pN2: pInert * n2Share,
      pHe: pInert * (1.0 - n2Share),
      pO2: pO2,
    );
  }
}

/// CMF semi-closed rebreather at steady state.
///
/// The loop behaves like open circuit on the steady-state loop mix derived
/// from the supply gas via [ScrCalculator.calculateCmfSteadyStateFo2]. The
/// supply's He:N2 ratio is preserved in the loop (metabolism only removes
/// O2). If the flow is insufficient (hypoxic), the supply mix is used and
/// callers surface that as a warning.
class Scr extends BreathingConfig {
  Scr({
    required this.supplyFO2,
    this.supplyFHe = 0.0,
    required this.injectionRateLpm,
    this.vo2 = ScrCalculator.defaultVo2,
  }) : _loop = _steadyStateLoop(supplyFO2, supplyFHe, injectionRateLpm, vo2);

  final double supplyFO2;
  final double supplyFHe;
  final double injectionRateLpm;
  final double vo2;
  final OpenCircuit _loop;

  static OpenCircuit _steadyStateLoop(
    double supplyFO2,
    double supplyFHe,
    double injectionRateLpm,
    double vo2,
  ) {
    final loopFO2 =
        ScrCalculator.calculateCmfSteadyStateFo2(
          injectionRateLpm: injectionRateLpm,
          supplyO2Percent: supplyFO2 * 100.0,
          vo2: vo2,
        ) ??
        supplyFO2;
    final supplyInert = 1.0 - supplyFO2;
    final heShare = supplyInert > 0 ? supplyFHe / supplyInert : 0.0;
    final loopInert = 1.0 - loopFO2;
    return OpenCircuit(fO2: loopFO2, fHe: loopInert * heShare);
  }

  @override
  InspiredGas inspiredAt(double ambientPressureBar) =>
      _loop.inspiredAt(ambientPressureBar);
}

/// Passive-addition semi-closed rebreather (pSCR) at steady state.
///
/// Where CMF [Scr] injects a constant mass flow, a passive SCR vents a fixed
/// fraction of each breath and replaces it with fresh supply gas, so the
/// fresh-gas flow is coupled to ventilation: `fresh = rmv * dumpFraction`
/// (a 1:10 unit dumps 1/10 of each breath, dumpFraction = 0.1). At steady
/// state the loop then behaves like open circuit on a mix whose O2 is depleted
/// from the supply by metabolism relative to that fresh-gas flow — the same
/// well-mixed-loop balance the CMF calculation uses, only with the effective
/// injection rate derived from breathing rate.
///
/// This is the physically-rigorous mass-balance model (constant loop fraction,
/// so inspired ppO2 scales with depth). It differs from Subsurface's `pscr_o2`,
/// which uses a depth-independent absolute ppO2-drop approximation; the pSCR
/// *mode* is the parity feature, not that specific numeric approximation.
///
/// The supply He:N2 ratio is preserved (metabolism removes only O2). If the
/// fresh-gas flow cannot outpace metabolic consumption ([hypoxicLoop] true),
/// the model falls back to the supply mix and [loopFO2] equals [supplyFO2];
/// callers should surface the hypoxia risk.
class PassiveScr extends BreathingConfig {
  PassiveScr({
    required this.supplyFO2,
    this.supplyFHe = 0.0,
    required this.dumpFraction,
    this.rmvLpm = 15.0,
    this.vo2 = ScrCalculator.defaultVo2,
  }) : loopFO2 =
           ScrCalculator.calculatePascrSteadyStateFo2(
             supplyO2Percent: supplyFO2 * 100.0,
             additionRatio: dumpFraction,
             vo2: vo2,
             rmv: rmvLpm,
           ) ??
           supplyFO2,
       _loop = _steadyStateLoop(
         supplyFO2,
         supplyFHe,
         dumpFraction,
         rmvLpm,
         vo2,
       );

  /// Supply gas O2 fraction (0-1).
  final double supplyFO2;

  /// Supply gas He fraction (0-1).
  final double supplyFHe;

  /// Fraction of each breath vented and replaced with fresh gas (e.g. 0.1 for
  /// a 1:10 unit). Fresh-gas flow = [rmvLpm] * dumpFraction.
  final double dumpFraction;

  /// Respiratory minute volume (surface L/min); sets the fresh-gas flow.
  final double rmvLpm;

  /// Metabolic O2 consumption (surface L/min).
  final double vo2;

  /// Steady-state loop O2 fraction the diver actually breathes. Equals
  /// [supplyFO2] when the loop is hypoxic (fallback); see [hypoxicLoop].
  final double loopFO2;

  final OpenCircuit _loop;

  /// True when the fresh-gas flow cannot sustain the loop (metabolic O2
  /// consumption outpaces addition), so [loopFO2] fell back to [supplyFO2].
  bool get hypoxicLoop =>
      ScrCalculator.calculatePascrSteadyStateFo2(
        supplyO2Percent: supplyFO2 * 100.0,
        additionRatio: dumpFraction,
        vo2: vo2,
        rmv: rmvLpm,
      ) ==
      null;

  static OpenCircuit _steadyStateLoop(
    double supplyFO2,
    double supplyFHe,
    double dumpFraction,
    double rmvLpm,
    double vo2,
  ) {
    final loopFO2 =
        ScrCalculator.calculatePascrSteadyStateFo2(
          supplyO2Percent: supplyFO2 * 100.0,
          additionRatio: dumpFraction,
          vo2: vo2,
          rmv: rmvLpm,
        ) ??
        supplyFO2;
    final supplyInert = 1.0 - supplyFO2;
    final heShare = supplyInert > 0 ? supplyFHe / supplyInert : 0.0;
    final loopInert = 1.0 - loopFO2;
    return OpenCircuit(fO2: loopFO2, fHe: loopInert * heShare);
  }

  @override
  InspiredGas inspiredAt(double ambientPressureBar) =>
      _loop.inspiredAt(ambientPressureBar);
}
