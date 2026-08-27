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
  /// data are unchanged.
  factory DiveEnvironment.forConditions({
    double? altitudeMeters,
    WaterType? waterType,
    double? surfacePressureBar,
  }) {
    final surface =
        surfacePressureBar ??
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
