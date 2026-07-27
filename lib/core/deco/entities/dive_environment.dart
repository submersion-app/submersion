import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';

/// Physical environment for decompression calculations.
///
/// Replaces the engine's historical hardcoded assumptions (1.0 bar surface,
/// exactly 10 m of water per bar). [standard] reproduces those assumptions
/// exactly so existing behavior is preserved wherever no environment is
/// supplied.
class DiveEnvironment extends Equatable {
  /// Atmospheric pressure at the dive site surface, in bar.
  final double surfacePressureBar;

  /// Water density in kg/m3.
  final double waterDensityKgM3;

  const DiveEnvironment({
    this.surfacePressureBar = 1.0,
    this.waterDensityKgM3 = en13319Density,
  });

  /// Fresh water density (kg/m3).
  static const double freshWaterDensity = 1000.0;

  /// Brackish water density (kg/m3).
  static const double brackishWaterDensity = 1010.0;

  /// EN13319 dive-computer standard density: exactly 1 bar per 10 m.
  static const double en13319Density = 1019.716213;

  /// Sea water density (kg/m3).
  static const double saltWaterDensity = 1025.0;

  /// Legacy-equivalent default: 1.0 bar surface, exactly 10 m/bar.
  static const DiveEnvironment standard = DiveEnvironment();

  /// Build an environment from dive conditions.
  ///
  /// An explicit [surfacePressureBar] wins over [altitudeMeters]. A null
  /// altitude keeps the legacy 1.0 bar surface so dives without altitude
  /// data are unchanged. The surface pressure is sanitized first (see
  /// [_sanitizeSurfacePressureBar]); an implausible value is ignored so we
  /// fall back to altitude/standard pressure rather than poisoning the model.
  factory DiveEnvironment.forConditions({
    double? altitudeMeters,
    WaterType? waterType,
    double? surfacePressureBar,
  }) {
    final surface =
        _sanitizeSurfacePressureBar(surfacePressureBar) ??
        (altitudeMeters != null
            ? AltitudeCalculator.calculateBarometricPressure(altitudeMeters)
            : 1.0);
    final density = switch (waterType) {
      WaterType.fresh => freshWaterDensity,
      WaterType.brackish => brackishWaterDensity,
      WaterType.salt => saltWaterDensity,
      null => en13319Density,
    };
    return DiveEnvironment(
      surfacePressureBar: surface,
      waterDensityKgM3: density,
    );
  }

  /// Sanitizes a surface pressure that is nominally in bar.
  ///
  /// Atmospheric surface pressure is only ever ~0.5 bar (high altitude) to
  /// ~1.06 bar (sea level). Some import paths have written millibar/
  /// hectopascal values (e.g. 1013) straight into the bar-typed field. Used
  /// verbatim, a ~1000x-too-large surface pressure poisons the whole
  /// decompression model: tissue tensions of hundreds of bar, gradient
  /// factors clamped to 0, and NDL saturating at its "unlimited" sentinel.
  ///
  /// So: convert an obvious mbar/hPa value to bar, then reject anything still
  /// physically impossible (returning null) so the caller falls back to the
  /// altitude-derived or standard 1.0 bar surface instead of garbage.
  static double? _sanitizeSurfacePressureBar(double? raw) {
    if (raw == null) return null;
    var bar = raw;
    if (bar > 100.0) bar /= 1000.0; // millibar / hectopascal -> bar
    if (bar < 0.5 || bar > 1.1) return null; // implausible -> ignore
    return bar;
  }

  static const double _gravity = 9.80665;

  /// Pressure increase per meter of depth, in bar.
  double get barPerMeter => waterDensityKgM3 * _gravity / 100000.0;

  /// Absolute ambient pressure at [depthMeters], in bar.
  double pressureAtDepth(double depthMeters) =>
      surfacePressureBar + depthMeters * barPerMeter;

  /// Depth in meters at absolute [pressureBar].
  double depthAtPressure(double pressureBar) =>
      (pressureBar - surfacePressureBar) / barPerMeter;

  @override
  List<Object?> get props => [surfacePressureBar, waterDensityKgM3];
}
