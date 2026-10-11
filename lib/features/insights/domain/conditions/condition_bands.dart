import 'package:submersion/core/constants/units.dart';

/// One band of a numeric condition and how many dives fell in it (#3118).
///
/// [lower] is inclusive and [upper] exclusive, both in the display unit the
/// edges were defined in. Null leaves that side open, so the first band is
/// "below" and the last "at or above".
typedef BandCount = ({double? lower, double? upper, int count});

/// The unit choices the condition statistics bin in.
///
/// Wind, surface pressure and swell all follow the depth unit, as
/// `UnitFormatter` does: metric is km/h, mbar and metres; imperial is knots,
/// inHg and feet.
class ConditionsUnits {
  const ConditionsUnits({required this.temperature, required this.depth});

  final TemperatureUnit temperature;
  final DepthUnit depth;

  bool get isMetric => depth == DepthUnit.meters;

  @override
  bool operator ==(Object other) =>
      other is ConditionsUnits &&
      other.temperature == temperature &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(temperature, depth);
}

/// Air temperature edges. Each unit has its own round numbers rather than
/// one set converted, as `waterTempBandEdges` does.
List<double> airTempBandEdges(TemperatureUnit unit) => switch (unit) {
  TemperatureUnit.celsius => const <double>[10, 20, 25, 30],
  TemperatureUnit.fahrenheit => const <double>[50, 70, 80, 90],
};

/// Wind edges, roughly Beaufort 2 to 6 in each unit.
List<double> windSpeedBandEdges({required bool metric}) =>
    metric ? const <double>[10, 20, 30, 40] : const <double>[5, 10, 15, 20];

/// Relative humidity edges, in percent.
const List<double> humidityBandEdges = <double>[40, 60, 80];

/// Surface pressure edges: below 900 mbar is altitude, 1000 to 1020 is a
/// normal sea-level day.
List<double> surfacePressureBandEdges({required bool metric}) =>
    metric ? const <double>[900, 1000, 1020] : const <double>[27, 29.5, 30.1];

/// Swell height edges in the depth unit.
List<double> swellHeightBandEdges(DepthUnit unit) => switch (unit) {
  DepthUnit.meters => const <double>[0.5, 1, 2],
  DepthUnit.feet => const <double>[2, 3, 6],
};

/// m/s to km/h or knots, with the factors `UnitFormatter.convertWindSpeed`
/// uses. The domain cannot depend on settings, so the factors are repeated
/// here and a test pins them to the formatter's.
double windSpeedForDisplay(double metersPerSecond, {required bool metric}) =>
    metric ? metersPerSecond * 3.6 : metersPerSecond * 1.94384;

/// bar to mbar or inHg, with the factors `UnitFormatter.formatSurfacePressure`
/// uses.
double surfacePressureForDisplay(double bar, {required bool metric}) =>
    metric ? bar * 1000 : bar * 29.53;

/// Counts [values], already in the display unit, into the bands [edges]
/// define.
///
/// Each value is first rounded to the [decimals] the app displays it at, so a
/// reading shown as "20.0" lands in the band that starts at 20 even when it
/// is stored as 19.96. Every band is returned, empty ones included.
List<BandCount> countIntoBands(
  Iterable<double> values,
  List<double> edges, {
  required int decimals,
}) {
  int bandOf(double value) {
    final shown = double.parse(value.toStringAsFixed(decimals));
    return edges.lastIndexWhere((edge) => shown >= edge) + 1;
  }

  final indexes = values.map(bandOf).toList();
  return [
    for (var band = 0; band <= edges.length; band++)
      (
        lower: band == 0 ? null : edges[band - 1],
        upper: band == edges.length ? null : edges[band],
        count: indexes.where((i) => i == band).length,
      ),
  ];
}
