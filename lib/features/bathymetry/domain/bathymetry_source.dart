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

/// What a source claims it can deliver at one coordinate. Declared, not
/// measured: a source reports the finest grid it believes it holds there,
/// which the resolver uses only to ORDER candidates. The wet-cell and
/// known-cell floors are what actually reject bad data, after a fetch.
class SourceCapability {
  /// Best available cell size in meters at the probed point.
  final double cellSizeMeters;

  /// Provenance detail for the caption, e.g. the dataset or DEM name.
  final String detail;

  const SourceCapability({required this.cellSizeMeters, required this.detail});
}

/// One bathymetry provider in the resolver tier.
abstract interface class BathymetrySource {
  String get id;

  /// Whether this source covers the whole globe. Only a dry grid from a
  /// global source proves a coordinate is definitively on land.
  bool get global;

  /// What this source can deliver at [center], or null when it does not
  /// cover the point. May make a network call, so a probe that fails for
  /// any reason must return null rather than throw: one unreachable source
  /// must never block the others.
  Future<SourceCapability?> probe(GeoPoint center);

  /// Fetches a depth grid roughly [spanMeters] across centered on [center].
  /// Throws [BathymetryFetchException] on transient failure.
  Future<BathymetryGrid> fetch(GeoPoint center, {required double spanMeters});
}
