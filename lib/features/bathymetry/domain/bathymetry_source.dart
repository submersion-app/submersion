import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Thrown on any TRANSIENT bathymetry failure (network error, timeout,
/// non-200, unparseable body). Callers must never cache this as an answer.
class BathymetryFetchException implements Exception {
  final String message;
  const BathymetryFetchException(this.message);

  @override
  String toString() => 'BathymetryFetchException: $message';
}

/// One bathymetry provider in the resolver tier.
abstract interface class BathymetrySource {
  String get id;

  /// Whether this source covers the whole globe. Only a dry grid from a
  /// global source proves a coordinate is definitively on land.
  bool get global;

  bool covers(GeoPoint center);

  /// Fetches a depth grid roughly [spanMeters] across centered on [center].
  /// Throws [BathymetryFetchException] on transient failure.
  Future<BathymetryGrid> fetch(GeoPoint center, {required double spanMeters});
}
