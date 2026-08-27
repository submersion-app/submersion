import 'package:submersion/core/constants/gas_model.dart';

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

/// Computes the free gas volume in a cylinder at the given pressure under
/// [model].
///
/// Returns liters at 1 bar. That reference matters: callers divide this by an
/// ambient pressure ratio expressed as `depth / 10 + 1`, which is also in bar,
/// so both sides must share a reference for the quotient to be meaningful.
/// Referencing volume to 1 atm while the ambient ratio stayed in bar
/// understated every volumetric SAC rate by ~1.3% (issue #828).
///
/// [o2Percent] and [hePercent] are 0–100 scale.
double gasVolume({
  required double tankSizeLiters,
  required double pressureBar,
  required double o2Percent,
  double hePercent = 0,
  required GasModel model,
}) {
  if (pressureBar <= 0) return 0;
  if (model == GasModel.ideal) return tankSizeLiters * pressureBar;
  final z = gasCompressibilityFactor(
    o2Percent: o2Percent,
    hePercent: hePercent,
    bar: pressureBar,
  );
  return tankSizeLiters * pressureBar / z;
}

/// Cylinder pressure remaining after consuming [litersConsumed] liters at
/// 1 bar, under [model].
///
/// The ideal model inverts [gasVolume] directly. The real model has no closed
/// form, so it solves gasVolume(start) - gasVolume(end) == litersConsumed by
/// bisection.
///
/// Returns 0 when the demand exceeds the cylinder's content.
double pressureAfterConsuming({
  required double tankSizeLiters,
  required double startPressureBar,
  required double litersConsumed,
  required double o2Percent,
  double hePercent = 0,
  required GasModel model,
}) {
  if (startPressureBar <= 0 || tankSizeLiters <= 0) return 0;
  final startVolume = gasVolume(
    tankSizeLiters: tankSizeLiters,
    pressureBar: startPressureBar,
    o2Percent: o2Percent,
    hePercent: hePercent,
    model: model,
  );
  final target = startVolume - litersConsumed;
  if (target <= 0) return 0;

  if (model == GasModel.ideal) return target / tankSizeLiters;

  double lo = 0.0;
  double hi = startPressureBar;
  for (int i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    final v = gasVolume(
      tankSizeLiters: tankSizeLiters,
      pressureBar: mid,
      o2Percent: o2Percent,
      hePercent: hePercent,
      model: model,
    );
    if (v > target) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return (lo + hi) / 2;
}

/// Cylinder pressure at which [tankSizeLiters] holds [litersRequired] liters
/// at 1 bar, under [model]. The inverse of [gasVolume].
///
/// Used to price a gas requirement as a pressure, such as a rock-bottom
/// reserve.
///
/// The two models differ in whichever direction Z points at the pressure
/// involved, and for air Z crosses 1 at about 121 bar. So a reserve-sized
/// demand costs slightly LESS pressure under the real model, while filling a
/// cylinder to working pressure yields less gas than the ideal law promises.
///
/// Returns 0 for a non-positive demand.
double pressureHoldingVolume({
  required double tankSizeLiters,
  required double litersRequired,
  required double o2Percent,
  double hePercent = 0,
  required GasModel model,
}) {
  if (tankSizeLiters <= 0 || litersRequired <= 0) return 0;
  if (model == GasModel.ideal) return litersRequired / tankSizeLiters;

  // Z stays within a few percent of 1 across the cylinder's range, so the
  // ideal pressure padded generously is a safe upper bracket.
  double lo = 0.0;
  double hi = (litersRequired / tankSizeLiters) * 1.5 + 1.0;
  for (int i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    final v = gasVolume(
      tankSizeLiters: tankSizeLiters,
      pressureBar: mid,
      o2Percent: o2Percent,
      hePercent: hePercent,
      model: model,
    );
    if (v > litersRequired) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return (lo + hi) / 2;
}
