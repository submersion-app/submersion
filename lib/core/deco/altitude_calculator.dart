import 'dart:math' as math;

/// Warning levels for altitude diving.
///
/// Higher severity levels indicate increased risk and
/// should trigger more prominent UI warnings.
enum AltitudeWarningLevel {
  /// No warning - sea level diving
  none,

  /// Informational notice - minor altitude adjustment
  info,

  /// Caution - moderate altitude, slower ascent recommended
  caution,

  /// Warning - significant altitude, specialty training recommended
  warning,

  /// Severe - extreme altitude, calculations less reliable
  severe,
}

/// Altitude groups for dive planning, following PADI/SSI conventions.
///
/// Each group represents a range of altitudes with specific
/// decompression considerations and recommended procedures.
enum AltitudeGroup {
  /// Sea level: 0-300m (0-984ft)
  /// No altitude adjustment needed for dive tables.
  seaLevel(
    displayName: 'Sea Level',
    rangeDescription: '0-300m (0-984ft)',
    minAltitude: 0,
    maxAltitude: 300,
    warningLevel: AltitudeWarningLevel.none,
    recommendedMaxAscentRate: 9.0,
  ),

  /// Group 1: 300-900m (984-2953ft)
  /// Minor adjustment to NDL limits.
  group1(
    displayName: 'Altitude Group 1',
    rangeDescription: '300-900m (984-2953ft)',
    minAltitude: 300,
    maxAltitude: 900,
    warningLevel: AltitudeWarningLevel.info,
    recommendedMaxAscentRate: 9.0,
  ),

  /// Group 2: 900-1800m (2953-5906ft)
  /// Moderate adjustment, slower ascent rate recommended.
  group2(
    displayName: 'Altitude Group 2',
    rangeDescription: '900-1800m (2953-5906ft)',
    minAltitude: 900,
    maxAltitude: 1800,
    warningLevel: AltitudeWarningLevel.caution,
    recommendedMaxAscentRate: 7.5,
  ),

  /// Group 3: 1800-2700m (5906-8858ft)
  /// Significant adjustment, altitude diving training recommended.
  group3(
    displayName: 'Altitude Group 3',
    rangeDescription: '1800-2700m (5906-8858ft)',
    minAltitude: 1800,
    maxAltitude: 2700,
    warningLevel: AltitudeWarningLevel.warning,
    recommendedMaxAscentRate: 6.0,
  ),

  /// Extreme: >2700m (>8858ft)
  /// Very high altitude, calculations may be less reliable.
  extreme(
    displayName: 'Extreme Altitude',
    rangeDescription: '>2700m (>8858ft)',
    minAltitude: 2700,
    maxAltitude: double.infinity,
    warningLevel: AltitudeWarningLevel.severe,
    recommendedMaxAscentRate: 5.0,
  );

  final String displayName;
  final String rangeDescription;
  final double minAltitude;
  final double maxAltitude;
  final AltitudeWarningLevel warningLevel;
  final double recommendedMaxAscentRate;

  const AltitudeGroup({
    required this.displayName,
    required this.rangeDescription,
    required this.minAltitude,
    required this.maxAltitude,
    required this.warningLevel,
    required this.recommendedMaxAscentRate,
  });

  /// Whether this altitude group requires decompression adjustments.
  bool get requiresAdjustment => this != seaLevel;

  /// Determine the altitude group for a given altitude in meters.
  ///
  /// Returns [seaLevel] for null or negative altitudes.
  static AltitudeGroup fromAltitude(double? altitudeMeters) {
    if (altitudeMeters == null || altitudeMeters < 0) {
      return seaLevel;
    }

    if (altitudeMeters < 300) return seaLevel;
    if (altitudeMeters < 900) return group1;
    if (altitudeMeters < 1800) return group2;
    if (altitudeMeters < 2700) return group3;
    return extreme;
  }
}

/// Calculator for altitude-related pressure conversions.
///
/// Uses the International Standard Atmosphere (ISA) barometric formula
/// to convert between altitude and atmospheric pressure.
///
/// The formula is: P = P0 * (1 - L*h/T0)^(g*M/(R*L))
///
/// Where:
/// - P0 = 1.01325 bar (sea level standard pressure)
/// - L = 0.0065 K/m (temperature lapse rate)
/// - T0 = 288.15 K (sea level standard temperature)
/// - g = 9.80665 m/s^2 (gravitational acceleration)
/// - M = 0.0289644 kg/mol (molar mass of dry air)
/// - R = 8.31447 J/(mol*K) (universal gas constant)
///
/// The exponent g*M/(R*L) simplifies to approximately 5.25588.
class AltitudeCalculator {
  AltitudeCalculator._();

  /// Sea level standard atmospheric pressure in bar.
  static const double seaLevelPressureBar = 1.01325;

  /// Pre-calculated exponent for barometric formula.
  /// g*M/(R*L) = 9.80665 * 0.0289644 / (8.31447 * 0.0065)
  static const double _barometricExponent = 5.25588;

  /// Pre-calculated coefficient for altitude term.
  /// L/T0 = 0.0065 / 288.15
  static const double _altitudeCoefficient = 0.0000225577;

  /// Calculate barometric pressure at a given altitude.
  ///
  /// [altitudeMeters] - Altitude above sea level in meters.
  ///                   Negative values represent below sea level.
  ///
  /// Returns atmospheric pressure in bar.
  static double calculateBarometricPressure(double altitudeMeters) {
    // P = P0 * (1 - L*h/T0)^exponent
    final pressureRatio = math.pow(
      1 - _altitudeCoefficient * altitudeMeters,
      _barometricExponent,
    );
    return seaLevelPressureBar * pressureRatio;
  }

  /// Calculate altitude from barometric pressure.
  ///
  /// [pressureBar] - Atmospheric pressure in bar.
  ///
  /// Returns altitude above sea level in meters.
  static double calculateAltitudeFromPressure(double pressureBar) {
    // Inverse of barometric formula:
    // h = (1 - (P/P0)^(1/exponent)) / (L/T0)
    final pressureRatio = pressureBar / seaLevelPressureBar;
    final altitudeRatio = 1 - math.pow(pressureRatio, 1 / _barometricExponent);
    return altitudeRatio / _altitudeCoefficient;
  }

  /// Calculate the equivalent ocean depth for a dive at altitude.
  ///
  /// At altitude, the reduced surface pressure means that a given
  /// actual depth represents a greater decompression stress than
  /// the same depth at sea level. The equivalent ocean depth (EOD)
  /// is the sea-level depth that produces the same pressure ratio.
  ///
  /// [actualDepth] - Actual depth of the dive in meters.
  /// [altitudeMeters] - Altitude above sea level in meters.
  ///
  /// Returns the equivalent ocean depth in meters.
  static double calculateEquivalentOceanDepth({
    required double actualDepth,
    required double altitudeMeters,
  }) {
    final surfacePressure = calculateBarometricPressure(altitudeMeters);

    // Pressure at depth = surface pressure + depth/10 (in bar)
    final ambientPressure = surfacePressure + (actualDepth / 10.0);

    // Ratio of ambient to surface pressure
    final pressureRatio = ambientPressure / surfacePressure;

    // At sea level, what depth gives this same ratio?
    // (P0 + EOD/10) / P0 = pressureRatio
    // EOD = 10 * P0 * (pressureRatio - 1)
    return 10.0 * seaLevelPressureBar * (pressureRatio - 1);
  }

  /// Calculate the actual depth from an ocean equivalent depth at altitude.
  ///
  /// Inverse of [calculateEquivalentOceanDepth].
  ///
  /// [oceanEquivalentDepth] - The equivalent ocean depth in meters.
  /// [altitudeMeters] - Altitude above sea level in meters.
  ///
  /// Returns the actual depth at altitude in meters.
  static double calculateActualDepthFromOceanEquivalent({
    required double oceanEquivalentDepth,
    required double altitudeMeters,
  }) {
    final surfacePressure = calculateBarometricPressure(altitudeMeters);

    // At sea level, what's the pressure ratio at this depth?
    final pressureRatio =
        (seaLevelPressureBar + oceanEquivalentDepth / 10.0) /
        seaLevelPressureBar;

    // At altitude, what depth gives this same pressure ratio?
    // (Ps + d/10) / Ps = pressureRatio
    // d = 10 * Ps * (pressureRatio - 1)
    return 10.0 * surfacePressure * (pressureRatio - 1);
  }

  /// Get the altitude group for a given altitude.
  ///
  /// Convenience method that delegates to [AltitudeGroup.fromAltitude].
  static AltitudeGroup getAltitudeGroup(double? altitudeMeters) {
    return AltitudeGroup.fromAltitude(altitudeMeters);
  }
}
