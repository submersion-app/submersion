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

/// Passive-addition semi-closed rebreather (pSCR), Subsurface's steady-state
/// model.
///
/// A passive SCR vents a fixed fraction of each breath and replaces it with
/// fresh supply gas; the recirculated loop is depleted of O2 by metabolism.
/// This is a faithful port of Subsurface's `pscr_o2` (core/gas.cpp): the
/// inspired ppO2 is the supply ppO2 minus a depth-INDEPENDENT metabolic drop,
///
///   drop_bar = (1 - fO2_supply) * o2Consumption / (sac * pscrRatio) * 1000
///
/// clamped at zero (a hypoxic loop). The remaining pressure is inert, split by
/// the supply He:N2 ratio — exactly matching Subsurface's `fill_pressures`
/// PSCR branch. Following that source, ambient pressure is used directly: this
/// is a deliberate exception to the alveolar water-vapor subtraction the
/// open-circuit and CCR configs in this file apply, so the two models are not
/// directly comparable at the same ambient pressure.
///
/// Rates are in surface mL/min to match Subsurface's stored units; the defaults
/// are Subsurface's own (o2Consumption 720, sac 20000, pscrRatio 100), which
/// give a ~0.285 bar O2 drop on air. Because the drop is a fixed pressure, a
/// lean gas is hypoxic near the surface (drop exceeds the supply ppO2) but
/// breathable at depth — the real behavior that makes pSCR demand rich gas.
class PassiveScr extends BreathingConfig {
  PassiveScr({
    required this.supplyFO2,
    this.supplyFHe = 0.0,
    this.o2ConsumptionMlMin = 720.0,
    this.sacMlMin = 20000.0,
    this.pscrRatio = 100.0,
  });

  /// Supply gas O2 fraction (0-1).
  final double supplyFO2;

  /// Supply gas He fraction (0-1).
  final double supplyFHe;

  /// Metabolic O2 consumption in surface mL/min (Subsurface `o2consumption`).
  final double o2ConsumptionMlMin;

  /// Bottom surface air consumption in mL/min (Subsurface `bottomsac`).
  final double sacMlMin;

  /// pSCR ratio (Subsurface `pscr_ratio`, default 100). Larger values dump/add
  /// more fresh gas and shrink the O2 drop.
  final double pscrRatio;

  /// Supply gas N2 fraction (0-1).
  double get supplyFN2 => 1.0 - supplyFO2 - supplyFHe;

  /// The depth-independent inspired-O2 drop (bar) from metabolic consumption of
  /// the recirculated loop gas. ~0.285 bar for air at the default settings.
  double get o2DropBar =>
      (1.0 - supplyFO2) * o2ConsumptionMlMin / (sacMlMin * pscrRatio) * 1000.0;

  @override
  InspiredGas inspiredAt(double ambientPressureBar) {
    final pO2 = math.max(0.0, supplyFO2 * ambientPressureBar - o2DropBar);
    final inert = ambientPressureBar - pO2;
    final supplyInert = supplyFHe + supplyFN2; // == 1 - supplyFO2
    if (supplyInert <= 0) {
      return InspiredGas(pN2: 0, pHe: 0, pO2: pO2);
    }
    return InspiredGas(
      pN2: inert * (supplyFN2 / supplyInert),
      pHe: inert * (supplyFHe / supplyInert),
      pO2: pO2,
    );
  }

  /// True when the loop is hypoxic at [ambientPressureBar] — inspired ppO2
  /// below the 0.16 bar hypoxia threshold. pSCR loops go hypoxic shallow, so
  /// this is depth-dependent (unlike a fixed loop fraction).
  bool hypoxicAt(double ambientPressureBar) =>
      inspiredAt(ambientPressureBar).pO2 < 0.16;
}
