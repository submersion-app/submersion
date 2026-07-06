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
