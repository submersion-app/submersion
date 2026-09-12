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

  /// The [BathymetryGrid.knownFraction] floor a fetched grid must clear
  /// to be trusted, below which the resolver treats it as "not enough
  /// data to mean anything" and falls through to the next source (see
  /// [BathymetryResolver.resolve]).
  ///
  /// Declared per source, not a single resolver-wide constant, because
  /// "unknown" means different things for different sources. For a
  /// GLOBAL survey mosaic (EMODnet's Caribbean tile: 99.96% wet on only
  /// 48% coverage is the motivating example), an unknown cell means
  /// "we don't actually know if there is water here" — genuinely
  /// untrustworthy. For a source scoped to a specific, already-confirmed
  /// water body (swissBATHY3D: [BathymetrySource.global] is false and the
  /// resolver's [SwissBathy3dSource.probe] already confirmed the fetch
  /// CENTER sits inside a real, listed lake before this source is even
  /// tried), an unknown cell within the requested span means "this cell
  /// is real, surveyed dry land" — a fact, not a gap: every tile the 8 km
  /// span expands into is independently re-resolved against the same
  /// lake table and, when a tile's own center sits outside every
  /// registered bbox, a confirmed STAC lookup found no data there, not an
  /// unchecked assumption carried over from the center. Applying the same
  /// high floor there
  /// penalizes exactly the lakes the fix is meant to serve: a narrow,
  /// elongated lake (Walensee, or a fjord-like bay of Vierwaldstättersee)
  /// legitimately fills only a small fraction of an 8 km square request
  /// centered on a real, fully-covered dive site, so a floor tuned for
  /// "is this global mosaic tile trustworthy" silently rejected genuine,
  /// complete local data and surfaced as "keine Daten verfügbar" with no
  /// visible reason -- found only once the resolver's own quality-floor
  /// rejections were logged (see [BathymetryResolver.resolve]'s
  /// `_log.debug` calls).
  double get minKnownFraction;

  /// What this source can deliver at [center], or null when it does not
  /// cover the point. May make a network call, so a probe that fails for
  /// any reason must return null rather than throw: one unreachable source
  /// must never block the others.
  Future<SourceCapability?> probe(GeoPoint center);

  /// Fetches a depth grid roughly [spanMeters] across centered on [center].
  /// Throws [BathymetryFetchException] on transient failure.
  Future<BathymetryGrid> fetch(GeoPoint center, {required double spanMeters});
}
