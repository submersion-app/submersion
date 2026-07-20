/// Neoprene exposure-suit buoyancy versus pressure, and the drysuit gas
/// budget. Pure math; pressures come from DiveEnvironment at call sites.
///
/// Model: suit buoyancy = incompressible residual + gas fraction obeying
/// Boyle's law. The residual fraction is a global engine constant; the
/// per-diver anchor value comes from the fitted weight model (which
/// represents the suit near the safety stop) and is inverted to a surface
/// value through [surfaceFromAnchor].
class SuitCompression {
  /// Fraction of surface buoyancy that does not compress (solid rubber,
  /// trapped-cell floor). Initial value from published neoprene
  /// compression data; recompute test vectors if changed.
  static const double kNeopreneResidualFraction = 0.3;

  /// Inversion guard: a fitted anchor can be noisy; the recovered surface
  /// buoyancy is clamped to [anchorKg, kMaxSurfaceToAnchorRatio*anchorKg].
  static const double kMaxSurfaceToAnchorRatio = 3.0;

  static double surfaceFromAnchor({
    required double anchorKg,
    required double anchorPressureBar,
    required double surfacePressureBar,
  }) {
    if (anchorKg <= 0) return 0.0;
    final pRel = anchorPressureBar / surfacePressureBar;
    const r = kNeopreneResidualFraction;
    final surface = anchorKg / (r + (1 - r) / pRel);
    return surface.clamp(anchorKg, kMaxSurfaceToAnchorRatio * anchorKg);
  }

  static double buoyancyAtPressure({
    required double surfaceKg,
    required double pressureBar,
    required double surfacePressureBar,
  }) {
    final pRel = pressureBar / surfacePressureBar;
    const r = kNeopreneResidualFraction;
    return surfaceKg * (r + (1 - r) / pRel);
  }

  static double loftLitersFromBuoyancy({
    required double suitTermKg,
    required double waterDensityKgL,
  }) => suitTermKg <= 0 ? 0.0 : suitTermKg / waterDensityKgL;

  /// Surface-equivalent liters the diver must add to hold constant loft
  /// across the descents in [pressuresBar] (vents on ascent are free).
  static double drysuitGasLiters({
    required double loftLiters,
    required List<double> pressuresBar,
  }) {
    var total = 0.0;
    for (var i = 1; i < pressuresBar.length; i++) {
      final delta = pressuresBar[i] - pressuresBar[i - 1];
      if (delta > 0) total += loftLiters * delta;
    }
    return total;
  }
}
