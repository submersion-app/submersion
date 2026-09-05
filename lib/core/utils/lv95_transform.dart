/// LV95 easting/northing (meters), a.k.a. CH1903+.
class Lv95Coordinates {
  final double easting;
  final double northing;

  const Lv95Coordinates(this.easting, this.northing);
}

/// Approximate WGS84 <-> LV95 (CH1903+) conversion using swisstopo's
/// published approximation formulas ("Näherungsformeln für die Transformation
/// zwischen Schweizer Projektionskoordinaten und WGS84", swisstopo).
/// Accuracy is about 1 m within Switzerland — no external service needed.
///
/// Not valid outside the vicinity of Switzerland.
class Lv95Transform {
  const Lv95Transform._();

  /// WGS84 (degrees) -> LV95 (meters).
  static Lv95Coordinates fromWgs84(double latitudeDeg, double longitudeDeg) {
    final phiSec = latitudeDeg * 3600.0;
    final lambdaSec = longitudeDeg * 3600.0;
    final phi = (phiSec - 169028.66) / 10000.0;
    final lambda = (lambdaSec - 26782.5) / 10000.0;

    final easting =
        2600072.37 +
        211455.93 * lambda -
        10938.51 * lambda * phi -
        0.36 * lambda * phi * phi -
        44.54 * lambda * lambda * lambda;
    final northing =
        1200147.07 +
        308807.95 * phi +
        3745.25 * lambda * lambda +
        76.63 * phi * phi -
        194.56 * lambda * lambda * phi +
        119.79 * phi * phi * phi;

    return Lv95Coordinates(easting, northing);
  }

  /// LV95 (meters) -> WGS84 (degrees).
  static ({double latitude, double longitude}) toWgs84(
    double easting,
    double northing,
  ) {
    final y = (easting - 2600000.0) / 1000000.0;
    final x = (northing - 1200000.0) / 1000000.0;

    final lambda =
        2.6779094 +
        4.728982 * y +
        0.791484 * y * x +
        0.1306 * y * x * x -
        0.0436 * y * y * y;
    final phi =
        16.9023892 +
        3.238272 * x -
        0.270978 * y * y -
        0.002528 * x * x -
        0.0447 * y * y * x -
        0.0140 * x * x * x;

    return (longitude: lambda * 100.0 / 36.0, latitude: phi * 100.0 / 36.0);
  }
}
