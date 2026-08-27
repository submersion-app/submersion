import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Quantizes coordinates to roughly 110 m for reef-data cache keys.
///
/// Three decimal places is finer than every provider's own resolution: NOAA
/// works on a 5 km grid, GBIF on a 5 km radius, and the reef polygons are
/// buffered to 300 m. Nearby sites therefore share a cache entry, and editing
/// a site's location misses the cache automatically.
///
/// The quantized point is used for the outbound query as well as the key, so a
/// cached entry is exactly what its key describes.
class ReefCoordinateKey {
  const ReefCoordinateKey._();

  static const int _decimals = 3;
  static const double _factor = 1000.0;

  static GeoPoint quantize(GeoPoint point) {
    return GeoPoint(_round(point.latitude), _round(point.longitude));
  }

  /// Stable string form used as the `coordKey` column value.
  static String format(GeoPoint point) {
    final q = quantize(point);
    return '${q.latitude.toStringAsFixed(_decimals)},'
        '${q.longitude.toStringAsFixed(_decimals)}';
  }

  static double _round(double value) {
    final rounded = (value * _factor).roundToDouble() / _factor;
    // Rounding a small negative coordinate yields -0.0, and toStringAsFixed
    // keeps the sign, so "-0.000" and "0.000" would be separate cache rows for
    // the same quantized point. Normalize the sign away.
    return rounded == 0 ? 0.0 : rounded;
  }
}
