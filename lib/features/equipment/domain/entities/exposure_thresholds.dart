import 'package:equatable/equatable.dart';

/// The lines that classify a dive as cold, deep or high-O2 for exposure
/// clocks. Stored metric; the settings page converts at the edge.
class ExposureThresholds extends Equatable {
  /// Dives with a minimum water temperature below this count as cold.
  /// 10 C is the EN 250 cold-water line.
  final double coldWaterC;

  /// Dives reaching this depth count as a deep cycle.
  final double deepDiveM;

  /// Contact with a mix above this O2 fraction counts as high-O2 service.
  final double highO2Fraction;

  const ExposureThresholds({
    this.coldWaterC = 10.0,
    this.deepDiveM = 30.0,
    this.highO2Fraction = 0.40,
  });

  static const defaults = ExposureThresholds();

  @override
  List<Object?> get props => [coldWaterC, deepDiveM, highO2Fraction];
}
