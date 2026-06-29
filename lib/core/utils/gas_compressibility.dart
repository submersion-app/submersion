/// Standard atmospheric pressure in bar.
const double standardAtmBar = 1.01325;

/// Converts bar to atmospheres.
double barToAtm(double bar) => bar / standardAtmBar;

/// Computes the gas compressibility factor (Z) using virial coefficients.
///
/// Based on Perry's Chemical Engineers' Handbook data, matching
/// the cubic virial model used by Subsurface.
/// Z = 1 + C0*P + C1*P^2 + C2*P^3 (linear mixing by gas fraction).
///
/// [o2Percent] and [hePercent] are 0–100 scale.
double gasCompressibilityFactor({
  required double o2Percent,
  double hePercent = 0,
  required double bar,
}) {
  assert(bar >= 0, 'Pressure must be non-negative');
  const o2Coeff = [-7.18092073703e-04, 2.81852572808e-06, -1.50290620492e-09];
  const n2Coeff = [-2.19260353292e-04, 2.92844845532e-06, -2.07613482075e-09];
  const heCoeff = [4.87320026468e-04, -8.83632921053e-08, 5.33304543646e-11];

  final p = bar.clamp(0.0, 500.0);

  double virial(List<double> c) => p * c[0] + p * p * c[1] + p * p * p * c[2];

  final o2Frac = o2Percent / 100.0;
  final heFrac = hePercent / 100.0;
  final n2Frac = 1.0 - o2Frac - heFrac;

  return 1.0 +
      virial(o2Coeff) * o2Frac +
      virial(heCoeff) * heFrac +
      virial(n2Coeff) * n2Frac;
}

/// Computes the actual gas volume (liters at surface) in a cylinder at the
/// given pressure, accounting for compressibility.
///
/// Returns liters at 1 atm.
/// [o2Percent] and [hePercent] are 0–100 scale.
double gasVolume({
  required double tankSizeLiters,
  required double pressureBar,
  required double o2Percent,
  double hePercent = 0,
}) {
  if (pressureBar <= 0) return 0;
  final z = gasCompressibilityFactor(
    o2Percent: o2Percent,
    hePercent: hePercent,
    bar: pressureBar,
  );
  return tankSizeLiters * barToAtm(pressureBar) / z;
}
