/// Gas density at depth (work-of-breathing limit checks).
///
/// High breathing-gas density increases CO2 retention risk. Community
/// guidance (Anthony & Mitchell): keep density at or below 5.2 g/L; 6.2 g/L
/// is the hard ceiling.
library;

/// Recommended maximum gas density (g/L).
const double gasDensityWarnGPerL = 5.2;

/// Hard maximum gas density (g/L).
const double gasDensityCriticalGPerL = 6.2;

/// Molecular weights (g/mol) and molar volume shared with the dive-details
/// density curve — keep these in lockstep with any display of density.
const double _o2MolWeight = 32.0;
const double _n2MolWeight = 28.0;
const double _heMolWeight = 4.0;
const double _molarVolumeLPerMol = 24.04; // L/mol at STP

/// Density in g/L of a breathing gas at [ambientPressureBar].
///
/// Formula: ambient x sum(fraction x molecular weight) / 24.04, with
/// fN2 = 1 - fO2 - fHe.
double gasDensityGPerL({
  required double fO2,
  required double fHe,
  required double ambientPressureBar,
}) {
  final fN2 = 1.0 - fO2 - fHe;
  final avgMolWeight =
      (fO2 * _o2MolWeight) + (fN2 * _n2MolWeight) + (fHe * _heMolWeight);
  return avgMolWeight / _molarVolumeLPerMol * ambientPressureBar;
}

/// Universal gas constant in L bar / (mol K).
const double gasConstantLBarPerMolK = 0.083144626;

/// Molar masses (g/mol) used by [gasDensityFromPartialPressures].
///
/// Deliberately not the rounded weights above: those stay with
/// [gasDensityGPerL] and its existing callers (Best Mix, planner, profile
/// curve) until they move to this function, which changes their values and
/// is left to its own change.
const double o2MolarMassGPerMol = 31.998;
const double n2MolarMassGPerMol = 28.014;
const double heMolarMassGPerMol = 4.0026;

/// Density in g/L of a breathing gas given by its partial pressures, at
/// [temperatureC].
///
/// Ideal gas: `sum(p_i * M_i) / (R * T)`. Pressures are in bar, which is the
/// unit [gasConstantLBarPerMolK] is expressed in, so no molar volume at a
/// fixed reference condition is involved. At breathing-gas pressures the
/// real-gas correction is well under 1 % and is deliberately left out.
///
/// Taking partial pressures rather than fractions lets a caller describe a
/// CCR loop, whose composition is not a fixed mix.
///
/// Throws [ArgumentError] for a negative partial pressure or a temperature
/// at or below absolute zero.
double gasDensityFromPartialPressures({
  required double pO2Bar,
  required double pN2Bar,
  required double pHeBar,
  required double temperatureC,
}) {
  if (pO2Bar < 0 || pN2Bar < 0 || pHeBar < 0) {
    throw ArgumentError('Partial pressures must not be negative');
  }
  final kelvin = temperatureC + 273.15;
  if (kelvin <= 0) {
    throw ArgumentError.value(
      temperatureC,
      'temperatureC',
      'must be above absolute zero',
    );
  }
  final gramsPerMolTimesBar =
      pO2Bar * o2MolarMassGPerMol +
      pN2Bar * n2MolarMassGPerMol +
      pHeBar * heMolarMassGPerMol;
  return gramsPerMolTimesBar / (gasConstantLBarPerMolK * kelvin);
}
