import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';

/// Discrete level-of-detail stages for the 3D site seascape's additional
/// terrain patch. `overview` is the always-loaded 8 km base square (see
/// [BathymetryResolver.defaultSpanMeters] in `bathymetry_resolver.dart`)
/// and needs no extra fetch; `medium`, `fine` and `superFine` are smaller,
/// additional grids fetched on top of it when the diver zooms in.
///
/// Deliberately a small, fixed number of steps rather than a continuous
/// span-from-zoom formula, to bound how many distinct grids the bathymetry
/// cache ends up holding per site.
enum BathymetryLodStage {
  overview(BathymetryResolver.defaultSpanMeters, 120),
  medium(6000, 120),
  fine(4000, 120),
  // maxGridDim 600 over a 1 km span is a ceiling above what any shipped
  // source resolves there (swissBATHY3D is typically ~2 m, i.e. ~500 cells
  // across 1 km) -- the point is to stay OUT OF THE WAY so downsampleTo
  // never coarsens this stage below the source's own native resolution,
  // not to target a specific meter figure. downsampleTo only ever
  // coarsens; it cannot sharpen a source past what it actually has.
  superFine(1000, 600);

  /// The request-box width this stage fetches, in meters. `overview`'s
  /// value matches [BathymetryResolver.defaultSpanMeters] but is not fetched
  /// again for that stage -- the base square is already loaded.
  final double spanMeters;

  /// The downsample cap ([BathymetryRepository.maxGridDim]'s default is
  /// 120) this stage's fetch is capped at. Only `superFine` overrides it --
  /// a small span already keeps its cell count, and so its render cost,
  /// bounded even with a much higher cap.
  final int maxGridDim;

  const BathymetryLodStage(this.spanMeters, this.maxGridDim);
}

/// The zoom thresholds below which each finer stage kicks in. The 3D
/// viewport's zoom is a private, unitless camera scalar (see
/// `Dive3dInteractiveViewport`'s `_minZoom`/`_maxZoom`, 0.4-8.0), not a
/// meter distance, so these are fixed scalar cutoffs rather than a
/// distance-based formula.
const double _mediumZoomThreshold = 2.0;
const double _fineZoomThreshold = 4.5;
const double _superFineZoomThreshold = 6.5;

/// The LOD stage that applies at [zoom]: `overview` below
/// [_mediumZoomThreshold], `medium` from there up to (excluding)
/// [_fineZoomThreshold], `fine` from there up to (excluding)
/// [_superFineZoomThreshold], `superFine` at or above it.
BathymetryLodStage bathymetryLodStageForZoom(double zoom) {
  if (zoom >= _superFineZoomThreshold) return BathymetryLodStage.superFine;
  if (zoom >= _fineZoomThreshold) return BathymetryLodStage.fine;
  if (zoom >= _mediumZoomThreshold) return BathymetryLodStage.medium;
  return BathymetryLodStage.overview;
}
