import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/altitude_calculator.dart';

/// Physical environment of a dive: what decompression, oxygen exposure, gas
/// curves and consumption all read pressure from.
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

  /// Typical open-ocean salinity (ppt) that maps onto [saltWaterDensity].
  static const double typicalSeaSalinityPpt = 35.0;

  /// Legacy-equivalent default: 1.0 bar surface, exactly 10 m/bar.
  static const DiveEnvironment standard = DiveEnvironment();

  /// Density from practical salinity, pinned to this engine's fresh
  /// (0 ppt → 1000 kg/m3) and salt (35 ppt → 1025 kg/m3) constants.
  ///
  /// Salinity is clamped at 0 ppt: a corrupted or imported plan carrying a
  /// negative value would otherwise produce a density below fresh water and
  /// cascade into unrealistic pressures and deco.
  static double densityFromSalinityPpt(double ppt) =>
      freshWaterDensity +
      (saltWaterDensity - freshWaterDensity) *
          (clampSalinityPpt(ppt) / typicalSeaSalinityPpt);

  /// Salinity floored at fresh water. NaN is treated as absent salinity and
  /// also floors, for the same reason.
  static double clampSalinityPpt(double ppt) => ppt > 0 ? ppt : 0.0;

  /// The surface a diver off-gasses at between a dive in [previous] and the
  /// next one in [next].
  ///
  /// Two dives at one altitude share their surface. Across a change of
  /// altitude the log does not say when the diver travelled, so this takes
  /// the higher pressure: a lower one would off-gas further than the diver
  /// may have, and start the next dive with too little residual gas.
  static DiveEnvironment surfaceIntervalBetween(
    DiveEnvironment previous,
    DiveEnvironment next,
  ) => next.surfacePressureBar > previous.surfacePressureBar ? next : previous;

  /// Inverse of [densityFromSalinityPpt].
  static double salinityPptFromDensity(double densityKgM3) =>
      (densityKgM3 - freshWaterDensity) /
      (saltWaterDensity - freshWaterDensity) *
      typicalSeaSalinityPpt;

  /// Build an environment from dive conditions.
  ///
  /// An explicit [surfacePressureBar] wins over [altitudeMeters]. A null
  /// altitude keeps the legacy 1.0 bar surface so dives without altitude
  /// data are unchanged. Neither counts unless it gives a positive pressure:
  /// a logged 0 or an altitude past the top of the barometric formula (which
  /// gives NaN) would otherwise be divided by.
  ///
  /// Density precedence: [waterDensityKgM3], then [salinityPpt], then
  /// [waterType], then EN13319.
  factory DiveEnvironment.forConditions({
    double? altitudeMeters,
    WaterType? waterType,
    double? surfacePressureBar,
    double? salinityPpt,
    double? waterDensityKgM3,
  }) {
    double? usable(double? bar) => bar != null && bar > 0 ? bar : null;
    final surface =
        usable(surfacePressureBar) ??
        usable(
          altitudeMeters == null
              ? null
              : AltitudeCalculator.calculateBarometricPressure(altitudeMeters),
        ) ??
        1.0;
    final density =
        waterDensityKgM3 ??
        (salinityPpt != null
            ? densityFromSalinityPpt(salinityPpt)
            : switch (waterType) {
                WaterType.fresh => freshWaterDensity,
                WaterType.brackish => brackishWaterDensity,
                WaterType.salt => saltWaterDensity,
                null => en13319Density,
              });
    return DiveEnvironment(
      surfacePressureBar: surface,
      waterDensityKgM3: density,
    );
  }

  static const double _gravity = 9.80665;

  /// Pressure increase per meter of depth, in bar.
  ///
  /// EN13319 is defined by this figure, and [en13319Density] only rounds it:
  /// through the density it comes out 1e-10 high, enough to carry a ppO2 that
  /// sits exactly on a limit over it.
  double get barPerMeter => waterDensityKgM3 == en13319Density
      ? 0.1
      : waterDensityKgM3 * _gravity / 100000.0;

  /// Absolute ambient pressure at [depthMeters], in bar.
  double pressureAtDepth(double depthMeters) =>
      surfacePressureBar + depthMeters * barPerMeter;

  /// Depth in meters at absolute [pressureBar].
  double depthAtPressure(double pressureBar) =>
      (pressureBar - surfacePressureBar) / barPerMeter;

  @override
  List<Object?> get props => [surfacePressureBar, waterDensityKgM3];
}
