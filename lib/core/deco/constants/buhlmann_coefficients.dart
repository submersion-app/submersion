/// Bühlmann ZH-L16C decompression model coefficients.
///
/// The ZH-L16C model uses 16 tissue compartments with different half-times
/// for nitrogen (N2) and helium (He). Each compartment has M-value coefficients
/// (a and b) that define the maximum tolerated supersaturation.
///
/// References:
/// - Bühlmann, A.A. "Decompression-Decompression Sickness" (1984)
/// - Erik Baker's "Understanding M-values" (1998)
/// - ZH-L16C coefficients from various validated sources
library;

/// ZH-L16C Nitrogen half-times in minutes for each compartment (1-16).
const List<double> zhl16cN2HalfTimes = [
  4.0, // Compartment 1
  8.0, // Compartment 2
  12.5, // Compartment 3
  18.5, // Compartment 4
  27.0, // Compartment 5
  38.3, // Compartment 6
  54.3, // Compartment 7
  77.0, // Compartment 8
  109.0, // Compartment 9
  146.0, // Compartment 10
  187.0, // Compartment 11
  239.0, // Compartment 12
  305.0, // Compartment 13
  390.0, // Compartment 14
  498.0, // Compartment 15
  635.0, // Compartment 16
];

/// ZH-L16C Helium half-times in minutes for each compartment (1-16).
/// Helium half-times are approximately 2.65x faster than N2.
const List<double> zhl16cHeHalfTimes = [
  1.51, // Compartment 1
  3.02, // Compartment 2
  4.72, // Compartment 3
  6.99, // Compartment 4
  10.21, // Compartment 5
  14.48, // Compartment 6
  20.53, // Compartment 7
  29.11, // Compartment 8
  41.20, // Compartment 9
  55.19, // Compartment 10
  70.69, // Compartment 11
  90.34, // Compartment 12
  115.29, // Compartment 13
  147.42, // Compartment 14
  188.24, // Compartment 15
  240.03, // Compartment 16
];

/// ZH-L16C N2 'a' coefficients (bar) for each compartment.
/// The 'a' coefficient affects the M-value intercept.
const List<double> zhl16cN2A = [
  1.2599, // Compartment 1
  1.0000, // Compartment 2
  0.8618, // Compartment 3
  0.7562, // Compartment 4
  0.6200, // Compartment 5
  0.5043, // Compartment 6
  0.4410, // Compartment 7
  0.4000, // Compartment 8
  0.3750, // Compartment 9
  0.3500, // Compartment 10
  0.3295, // Compartment 11
  0.3065, // Compartment 12
  0.2835, // Compartment 13
  0.2610, // Compartment 14
  0.2480, // Compartment 15
  0.2327, // Compartment 16
];

/// ZH-L16C N2 'b' coefficients (dimensionless) for each compartment.
/// The 'b' coefficient affects the M-value slope.
const List<double> zhl16cN2B = [
  0.5050, // Compartment 1
  0.6514, // Compartment 2
  0.7222, // Compartment 3
  0.7825, // Compartment 4
  0.8126, // Compartment 5
  0.8434, // Compartment 6
  0.8693, // Compartment 7
  0.8910, // Compartment 8
  0.9092, // Compartment 9
  0.9222, // Compartment 10
  0.9319, // Compartment 11
  0.9403, // Compartment 12
  0.9477, // Compartment 13
  0.9544, // Compartment 14
  0.9602, // Compartment 15
  0.9653, // Compartment 16
];

/// ZH-L16C He 'a' coefficients (bar) for each compartment.
const List<double> zhl16cHeA = [
  1.7424, // Compartment 1
  1.3830, // Compartment 2
  1.1919, // Compartment 3
  1.0458, // Compartment 4
  0.9220, // Compartment 5
  0.8205, // Compartment 6
  0.7305, // Compartment 7
  0.6502, // Compartment 8
  0.5950, // Compartment 9
  0.5545, // Compartment 10
  0.5333, // Compartment 11
  0.5189, // Compartment 12
  0.5181, // Compartment 13
  0.5176, // Compartment 14
  0.5172, // Compartment 15
  0.5119, // Compartment 16
];

/// ZH-L16C He 'b' coefficients (dimensionless) for each compartment.
const List<double> zhl16cHeB = [
  0.4245, // Compartment 1
  0.5747, // Compartment 2
  0.6527, // Compartment 3
  0.7223, // Compartment 4
  0.7582, // Compartment 5
  0.7957, // Compartment 6
  0.8279, // Compartment 7
  0.8553, // Compartment 8
  0.8757, // Compartment 9
  0.8903, // Compartment 10
  0.8997, // Compartment 11
  0.9073, // Compartment 12
  0.9122, // Compartment 13
  0.9171, // Compartment 14
  0.9217, // Compartment 15
  0.9267, // Compartment 16
];

/// Number of tissue compartments in the ZH-L16 model.
const int zhl16CompartmentCount = 16;

/// Standard atmospheric pressure at sea level in bar.
const double atmosphericPressureBar = 1.01325;

/// Simplified atmospheric pressure for calculations (1 bar).
const double surfacePressureBar = 1.0;

/// Water pressure gradient (bar per 10 meters of seawater).
const double waterPressureGradient = 1.0;

/// Nitrogen fraction in air.
const double airN2Fraction = 0.79;

/// Oxygen fraction in air.
const double airO2Fraction = 0.21;

/// Water vapor pressure in lungs at 37°C (bar).
const double waterVaporPressure = 0.0627;

/// Respiratory quotient (CO2 produced / O2 consumed).
const double respiratoryQuotient = 0.9;

/// Standard ascent rate in meters per minute.
const double standardAscentRate = 9.0;

/// Standard descent rate in meters per minute.
const double standardDescentRate = 18.0;

/// Minimum deco stop depth in meters.
const double minDecoStopDepth = 3.0;

/// Deco stop depth increment in meters.
const double decoStopIncrement = 3.0;

/// Calculate inspired N2 pressure at a given ambient pressure.
///
/// [ambientPressure] is the total pressure in bar.
/// [fN2] is the nitrogen fraction (0.0-1.0).
/// Returns inspired N2 pressure in bar, accounting for water vapor.
double calculateInspiredN2(double ambientPressure, double fN2) {
  return (ambientPressure - waterVaporPressure) * fN2;
}

/// Calculate inspired He pressure at a given ambient pressure.
///
/// [ambientPressure] is the total pressure in bar.
/// [fHe] is the helium fraction (0.0-1.0).
/// Returns inspired He pressure in bar, accounting for water vapor.
double calculateInspiredHe(double ambientPressure, double fHe) {
  return (ambientPressure - waterVaporPressure) * fHe;
}

/// Calculate ambient pressure at a given depth.
///
/// [depthMeters] is the depth in meters.
/// [surfacePressure] is the surface pressure in bar (default 1.0).
/// Returns ambient pressure in bar.
double calculateAmbientPressure(
  double depthMeters, {
  double surfacePressure = 1.0,
}) {
  return surfacePressure + (depthMeters / 10.0);
}

/// Calculate depth from ambient pressure.
///
/// [ambientPressure] is the pressure in bar.
/// [surfacePressure] is the surface pressure in bar (default 1.0).
/// Returns depth in meters.
double calculateDepthFromPressure(
  double ambientPressure, {
  double surfacePressure = 1.0,
}) {
  return (ambientPressure - surfacePressure) * 10.0;
}

/// Common gradient factor presets.
class GradientFactorPresets {
  /// Conservative preset (30/70) - Good for recreational diving
  static const (int, int) conservative = (30, 70);

  /// Moderate preset (40/80) - Standard technical diving
  static const (int, int) moderate = (40, 80);

  /// Liberal preset (55/90) - Experienced technical divers
  static const (int, int) liberal = (55, 90);

  /// Very conservative (20/60) - Maximum safety margin
  static const (int, int) veryConservative = (20, 60);

  /// Get display name for a preset
  static String getPresetName(int low, int high) {
    if (low == 30 && high == 70) return 'Conservative (30/70)';
    if (low == 40 && high == 80) return 'Moderate (40/80)';
    if (low == 55 && high == 90) return 'Liberal (55/90)';
    if (low == 20 && high == 60) return 'Very Conservative (20/60)';
    return 'Custom ($low/$high)';
  }
}
