/// Discrete level-of-detail stages for the 3D site seascape's additional
/// terrain patch. `overview` is the always-loaded 8 km base square (see
/// [BathymetryResolver.defaultSpanMeters] in `bathymetry_resolver.dart`)
/// and needs no extra fetch; `medium` and `fine` are smaller, additional
/// grids fetched on top of it when the diver zooms in.
///
/// Deliberately a small, fixed number of steps rather than a continuous
/// span-from-zoom formula, to bound how many distinct grids the bathymetry
/// cache ends up holding per site.
enum BathymetryLodStage {
  overview(8000),
  medium(2000),
  fine(500);

  /// The request-box width this stage fetches, in meters. `overview`'s
  /// value matches [BathymetryResolver.defaultSpanMeters] but is not fetched
  /// again for that stage -- the base square is already loaded.
  final double spanMeters;

  const BathymetryLodStage(this.spanMeters);
}

/// The zoom thresholds below which each finer stage kicks in. The 3D
/// viewport's zoom is a private, unitless camera scalar (see
/// `Dive3dInteractiveViewport`'s `_minZoom`/`_maxZoom`, 0.4-8.0), not a
/// meter distance, so these are fixed scalar cutoffs rather than a
/// distance-based formula.
const double _mediumZoomThreshold = 2.0;
const double _fineZoomThreshold = 4.5;

/// The LOD stage that applies at [zoom]: `overview` below
/// [_mediumZoomThreshold], `medium` from there up to (excluding)
/// [_fineZoomThreshold], `fine` at or above it.
BathymetryLodStage bathymetryLodStageForZoom(double zoom) {
  if (zoom >= _fineZoomThreshold) return BathymetryLodStage.fine;
  if (zoom >= _mediumZoomThreshold) return BathymetryLodStage.medium;
  return BathymetryLodStage.overview;
}
