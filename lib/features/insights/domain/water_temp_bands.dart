import 'package:submersion/core/constants/units.dart';

/// One water-temperature band and how many dives fell in it (issue #1827).
///
/// [lower] and [upper] are whole degrees in the unit the bands were defined
/// in. [lower] is inclusive and [upper] exclusive; null leaves that side of
/// the band open, so the first band is "below" and the last "at or above".
typedef WaterTempBandCount = ({int? lower, int? upper, int count});

/// Ascending band edges for the water-temperature distribution, in [unit].
///
/// Each unit has its own round numbers rather than one set converted: an
/// imperial diver thinks in 50, 65 and 75 °F, not in 64.4 and 75.2 °F. The
/// two sets sit close together (10 °C is 50 °F), so both describe the same
/// cold, temperate, warm and tropical split.
List<int> waterTempBandEdges(TemperatureUnit unit) => switch (unit) {
  TemperatureUnit.celsius => const [10, 18, 24],
  TemperatureUnit.fahrenheit => const [50, 65, 75],
};
