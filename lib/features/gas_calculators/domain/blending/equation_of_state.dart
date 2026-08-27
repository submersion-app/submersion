import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// Which equation of state converts between cylinder pressure and amount of
/// gas while blending.
///
/// This is deliberately separate from the app-wide `GasModel` preference.
/// Blending is the one place a diver wants to match whatever software their
/// fill station runs, and [vanDerWaals] would be meaningless applied to a SAC
/// rate.
enum BlendGasModel {
  /// `p = rho R T`. Matches hand calculation and most published blending
  /// tables.
  ideal,

  /// Van der Waals with one-fluid mixing. The only model here whose constants
  /// carry a temperature dependence of their own, and the least accurate at
  /// fill pressure. See the accuracy note on [molarDensity].
  vanDerWaals,

  /// Virial compressibility factor. The most accurate of the three at
  /// cylinder pressures, and what the blender used unconditionally before the
  /// picker existed.
  zFactor;

  /// Parse a stored value, falling back to [zFactor] so an unreadable
  /// preference never silently changes a fill procedure.
  static BlendGasModel fromName(String? name) {
    for (final model in BlendGasModel.values) {
      if (model.name == name) return model;
    }
    return BlendGasModel.zFactor;
  }
}

/// Universal gas constant in L bar / (mol K).
const double kGasConstant = 0.083144626;

/// The temperature a cylinder pressure is quoted at when the diver has not
/// said otherwise. Also the temperature the virial coefficients below are fit
/// at.
const double kReferenceTempC = 20.0;

double celsiusToKelvin(double celsius) => celsius + 273.15;

// Virial coefficients (bar) for the compressibility factor of each component.
const List<double> _o2Coef = [
  -7.18092073703e-04,
  2.81852572808e-06,
  -1.50290620492e-09,
];
const List<double> _n2Coef = [
  -2.19260353292e-04,
  2.92844845532e-06,
  -2.07613482075e-09,
];
const List<double> _heCoef = [
  4.87320026468e-04,
  -8.83632921053e-08,
  5.33304543646e-11,
];

// Van der Waals constants, in L^2 bar / mol^2 and L / mol.
const double _aO2 = 1.382;
const double _bO2 = 0.03186;
const double _aN2 = 1.370;
const double _bN2 = 0.0387;
const double _aHe = 0.0346;
const double _bHe = 0.0238;

double _virial(double p, List<double> c) =>
    c[0] * p + c[1] * p * p + c[2] * p * p * p;

double _fO2(GasMix m) => m.o2 / 100;
double _fHe(GasMix m) => m.he / 100;
double _fN2(GasMix m) => (100 - m.o2 - m.he) / 100;

/// The pressure beyond which the virial fit stops meaning anything.
///
/// A cubic diverges outside the range it was fitted over: for air the p^3 term
/// takes Z negative somewhere past 1000 bar, which sends the fixed-point
/// iteration in [pressureAt] to NaN rather than to an answer. Clamping matches
/// what `core/utils/gas_compressibility.dart` has always done, and 500 bar is
/// far above any cylinder a diver fills.
const double _virialMaxBar = 500.0;

/// Real-gas compressibility factor Z of [m] at pressure [p] bar.
double zFactor(double p, GasMix m) {
  final clamped = p.clamp(0.0, _virialMaxBar);
  return 1 +
      _fO2(m) * _virial(clamped, _o2Coef) +
      _fHe(m) * _virial(clamped, _heCoef) +
      _fN2(m) * _virial(clamped, _n2Coef);
}

/// One-fluid van der Waals mixing: `a_mix = (sum x_i sqrt(a_i))^2`.
double _aMix(GasMix m) {
  final root =
      _fO2(m) * math.sqrt(_aO2) +
      _fHe(m) * math.sqrt(_aHe) +
      _fN2(m) * math.sqrt(_aN2);
  return root * root;
}

/// One-fluid van der Waals mixing: `b_mix = sum x_i b_i`.
double _bMix(GasMix m) => _fO2(m) * _bO2 + _fHe(m) * _bHe + _fN2(m) * _bN2;

/// Moles of [mix] per litre of cylinder at [bar] and [kelvin].
///
/// Molar density is the quantity the blender conserves, because mixing adds
/// moles exactly while it adds neither pressure nor volume exactly.
///
/// Accuracy, worth knowing before choosing a model:
///
/// * [BlendGasModel.zFactor] is the most accurate here, but its virial
///   coefficients are a fit at roughly [kReferenceTempC]. It therefore treats
///   Z as a function of pressure and composition only, and carries temperature
///   solely through the ideal `R T` factor.
/// * [BlendGasModel.vanDerWaals] is the only model whose own constants carry
///   temperature, but it is quantitatively poor at fill pressure. At 200 bar
///   and 20 C it puts Z for air at 0.982 against a measured 1.036, and for
///   helium at 1.187 against 1.094. It does not sit between ideal and
///   accurate: it overshoots past accurate by roughly as much as ideal
///   undershoots.
/// * [BlendGasModel.ideal] is exact only as a limit and runs a few percent
///   off at cylinder pressures, but it is what most published blending tables
///   assume.
double molarDensity(
  BlendGasModel model,
  double bar,
  GasMix mix,
  double kelvin,
) {
  if (bar <= 0) return 0;
  switch (model) {
    case BlendGasModel.ideal:
      return bar / (kGasConstant * kelvin);
    case BlendGasModel.zFactor:
      return bar / (zFactor(bar, mix) * kGasConstant * kelvin);
    case BlendGasModel.vanDerWaals:
      // p(rho) is strictly increasing across the whole bracket at any
      // blending temperature: every component's critical temperature (O2
      // 154 K, N2 126 K, He 5.2 K) is far below freezing, so there is no van
      // der Waals loop to bracket around and a bisection is exact.
      var lo = 0.0;
      var hi = 0.95 / _bMix(mix);
      for (var i = 0; i < 80; i++) {
        final mid = (lo + hi) / 2;
        if (pressureAt(model, mid, mix, kelvin) > bar) {
          hi = mid;
        } else {
          lo = mid;
        }
      }
      return (lo + hi) / 2;
  }
}

/// The pressure at which [mix] holds [density] mol/L at [kelvin]. The inverse
/// of [molarDensity].
double pressureAt(
  BlendGasModel model,
  double density,
  GasMix mix,
  double kelvin,
) {
  if (density <= 0) return 0;
  switch (model) {
    case BlendGasModel.ideal:
      return density * kGasConstant * kelvin;
    case BlendGasModel.vanDerWaals:
      final a = _aMix(mix);
      final b = _bMix(mix);
      return density * kGasConstant * kelvin / (1 - b * density) -
          a * density * density;
    case BlendGasModel.zFactor:
      // Z depends on the pressure being sought, so iterate. Converges in a
      // handful of passes across the cylinder pressure range.
      var p = density * kGasConstant * kelvin;
      for (var i = 0; i < 100; i++) {
        final next = density * zFactor(p, mix) * kGasConstant * kelvin;
        if ((next - p).abs() < 0.0001) return next;
        p = next;
      }
      return p;
  }
}
