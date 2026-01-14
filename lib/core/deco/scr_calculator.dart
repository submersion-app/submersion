/// SCR (Semi-Closed Rebreather) Calculator
///
/// Provides calculations for SCR dive planning and analysis:
/// - Steady-state loop FO₂ calculation
/// - ppO₂ range at depth
/// - Time constant for FO₂ stabilization
///
/// SCR types supported:
/// - CMF (Constant Mass Flow): e.g., Drager Dolphin
/// - PASCR (Passive Addition): e.g., KISS GEM, Halcyon RB80
/// - ESCR (Electronically Controlled)
class ScrCalculator {
  /// Default metabolic oxygen consumption rate (L/min)
  /// Average resting: 0.25 L/min
  /// Average working: 1.3 L/min
  /// Hard working: 2.0 L/min
  static const double defaultVo2 = 1.3;

  /// Minimum VO₂ at rest
  static const double restingVo2 = 0.25;

  /// Maximum VO₂ at hard work
  static const double hardWorkVo2 = 2.0;

  /// Calculate steady-state loop FO₂ for Constant Mass Flow (CMF) SCR
  ///
  /// Formula: FO₂ = (Qmix × Fmix - VO₂) / (Qmix - VO₂)
  ///
  /// Where:
  /// - Qmix = injection rate in L/min (at surface)
  /// - Fmix = supply gas O₂ fraction (0-1)
  /// - VO₂ = oxygen consumption in L/min
  ///
  /// Returns: Loop O₂ fraction (0-1), or null if calculation is invalid
  static double? calculateCmfSteadyStateFo2({
    required double injectionRateLpm,
    required double supplyO2Percent,
    double vo2 = defaultVo2,
  }) {
    // Convert O₂% to fraction
    final supplyO2Fraction = supplyO2Percent / 100.0;

    // Check for invalid conditions
    if (injectionRateLpm <= vo2) {
      // Insufficient flow - dangerous hypoxia risk
      return null;
    }

    final fo2 =
        (injectionRateLpm * supplyO2Fraction - vo2) / (injectionRateLpm - vo2);

    // Sanity check - FO₂ should be between 0 and supply gas fraction
    if (fo2 < 0 || fo2 > supplyO2Fraction) {
      return null;
    }

    return fo2;
  }

  /// Calculate ppO₂ at depth given loop FO₂
  ///
  /// ppO₂ = ambientPressure × loopFo2
  static double calculatePpO2AtDepth({
    required double loopFo2,
    required double depthMeters,
  }) {
    final ambientPressure = 1.0 + (depthMeters / 10.0);
    return ambientPressure * loopFo2;
  }

  /// Calculate minimum (worst-case) loop FO₂ at maximum workload
  ///
  /// This represents the hypoxia risk - lowest O₂ the diver will breathe
  /// during hard swimming.
  static double? calculateMinLoopFo2({
    required double injectionRateLpm,
    required double supplyO2Percent,
    double maxVo2 = hardWorkVo2,
  }) {
    return calculateCmfSteadyStateFo2(
      injectionRateLpm: injectionRateLpm,
      supplyO2Percent: supplyO2Percent,
      vo2: maxVo2,
    );
  }

  /// Calculate maximum (rest) loop FO₂
  ///
  /// This represents the hyperoxia risk - highest O₂ the diver will breathe
  /// at rest.
  static double? calculateMaxLoopFo2({
    required double injectionRateLpm,
    required double supplyO2Percent,
    double minVo2 = restingVo2,
  }) {
    return calculateCmfSteadyStateFo2(
      injectionRateLpm: injectionRateLpm,
      supplyO2Percent: supplyO2Percent,
      vo2: minVo2,
    );
  }

  /// Calculate ppO₂ range for SCR dive at given depth
  ///
  /// Returns min and max ppO₂ based on workload extremes.
  /// Min ppO₂ = hard work (hypoxia risk)
  /// Max ppO₂ = at rest (hyperoxia risk)
  static ({double? minPpO2, double? maxPpO2}) calculatePpO2Range({
    required double injectionRateLpm,
    required double supplyO2Percent,
    required double depthMeters,
    double minVo2 = restingVo2,
    double maxVo2 = hardWorkVo2,
  }) {
    final minFo2 = calculateMinLoopFo2(
      injectionRateLpm: injectionRateLpm,
      supplyO2Percent: supplyO2Percent,
      maxVo2: maxVo2,
    );

    final maxFo2 = calculateMaxLoopFo2(
      injectionRateLpm: injectionRateLpm,
      supplyO2Percent: supplyO2Percent,
      minVo2: minVo2,
    );

    return (
      minPpO2: minFo2 != null
          ? calculatePpO2AtDepth(loopFo2: minFo2, depthMeters: depthMeters)
          : null,
      maxPpO2: maxFo2 != null
          ? calculatePpO2AtDepth(loopFo2: maxFo2, depthMeters: depthMeters)
          : null,
    );
  }

  /// Calculate time constant for FO₂ stabilization
  ///
  /// tau = loopVolume / (injectionRate - vo2)
  ///
  /// Steady state is reached after approximately 3 time constants.
  ///
  /// Returns: Time constant in minutes
  static double? calculateTimeConstant({
    required double loopVolumeLiters,
    required double injectionRateLpm,
    double vo2 = defaultVo2,
  }) {
    if (injectionRateLpm <= vo2) return null;
    return loopVolumeLiters / (injectionRateLpm - vo2);
  }

  /// Calculate time to reach steady-state FO₂
  ///
  /// Returns: Time in minutes to reach ~95% of steady-state (3 tau)
  static double? calculateTimeToSteadyState({
    required double loopVolumeLiters,
    required double injectionRateLpm,
    double vo2 = defaultVo2,
  }) {
    final tau = calculateTimeConstant(
      loopVolumeLiters: loopVolumeLiters,
      injectionRateLpm: injectionRateLpm,
      vo2: vo2,
    );
    return tau != null ? tau * 3 : null;
  }

  /// Calculate Maximum Operating Depth (MOD) for SCR
  ///
  /// For SCR, MOD should be calculated using the maximum loop FO₂
  /// (at rest) to ensure hyperoxia limits aren't exceeded.
  static double? calculateMod({
    required double injectionRateLpm,
    required double supplyO2Percent,
    double ppO2Max = 1.4,
    double minVo2 = restingVo2,
  }) {
    final maxFo2 = calculateMaxLoopFo2(
      injectionRateLpm: injectionRateLpm,
      supplyO2Percent: supplyO2Percent,
      minVo2: minVo2,
    );

    if (maxFo2 == null || maxFo2 <= 0) return null;

    // MOD = (ppO2Max / FO2 - 1) × 10
    return ((ppO2Max / maxFo2) - 1) * 10;
  }

  /// Calculate minimum safe depth for SCR
  ///
  /// This is the depth where the minimum loop FO₂ (at hard work)
  /// would result in hypoxic conditions (ppO₂ < 0.16 bar).
  static double? calculateMinSafeDepth({
    required double injectionRateLpm,
    required double supplyO2Percent,
    double ppO2Min = 0.16,
    double maxVo2 = hardWorkVo2,
  }) {
    final minFo2 = calculateMinLoopFo2(
      injectionRateLpm: injectionRateLpm,
      supplyO2Percent: supplyO2Percent,
      maxVo2: maxVo2,
    );

    if (minFo2 == null || minFo2 <= 0) return null;

    // Depth where ppO₂ = ppO2Min
    // ppO2Min = (depth/10 + 1) × minFo2
    // depth = (ppO2Min / minFo2 - 1) × 10
    final depth = ((ppO2Min / minFo2) - 1) * 10;

    // Return 0 if depth is negative (safe at surface)
    return depth < 0 ? 0 : depth;
  }

  /// Get recommended orifice flow rate for Drager Dolphin/Atlantis
  ///
  /// Common orifice configurations:
  /// - 40% orifice: ~8 L/min
  /// - 50% orifice: ~10 L/min
  /// - 60% orifice: ~12 L/min
  static double? getOrificeFlowRate(String orificeSize) {
    switch (orificeSize.toLowerCase()) {
      case '40':
      case '40%':
        return 8.0;
      case '50':
      case '50%':
        return 10.0;
      case '60':
      case '60%':
        return 12.0;
      default:
        return null;
    }
  }

  /// Calculate loop FO₂ for PASCR (Passive Addition SCR)
  ///
  /// PASCR injects fresh gas on every Nth breath.
  ///
  /// Formula: FO₂ ≈ Fmix × ratio + Fin × (1 - ratio)
  ///
  /// Where:
  /// - Fmix = supply gas O₂ fraction
  /// - ratio = addition ratio (e.g., 0.33 for 1:3)
  /// - Fin = inspired FO₂ (iterative, starts at supply)
  ///
  /// This simplified version assumes steady state.
  static double? calculatePascrSteadyStateFo2({
    required double supplyO2Percent,
    required double additionRatio,
    double vo2 = defaultVo2,
    double rmv = 15.0, // Respiratory Minute Volume in L/min
  }) {
    // For PASCR, the effective injection rate is RMV × additionRatio
    final effectiveInjectionRate = rmv * additionRatio;

    // Use CMF calculation with effective injection rate
    return calculateCmfSteadyStateFo2(
      injectionRateLpm: effectiveInjectionRate,
      supplyO2Percent: supplyO2Percent,
      vo2: vo2,
    );
  }
}
