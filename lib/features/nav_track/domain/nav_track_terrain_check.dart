import 'dart:math' as math;

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bilinear_depth_interpolation.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/nav_track_georef.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A grid resolution at or above this (metres) is too coarse for the
/// below-seafloor test to mean anything: EMODnet (115 m) and ETOPO (450 m)
/// tiles only support the on-land test (spec
/// 2026-09-10-underwater-nav-track-design.md, "Terrain verification and
/// cleanup").
const double _coarseResolutionThresholdMeters = 100;

/// How a single corrected route sample compares to the seafloor beneath it.
enum NavTrackTerrainClass {
  /// The seafloor at this point is at or above the waterline.
  onLand,

  /// The route's depth exceeds the seafloor depth by more than the
  /// resolution-scaled tolerance.
  belowSeafloor,

  /// No bathymetry reading is available here (outside the grid, or a
  /// nodata cell).
  unknown,

  /// Neither on land nor below the seafloor.
  ok,
}

/// The result of checking a corrected route against a bathymetry grid.
///
/// [classifications] and [penetrationMeters] are one entry per input point,
/// same order, so a caller can zip them back against the route (e.g. to
/// highlight conflicting points on the map).
class NavTrackTerrainCheckResult {
  /// One classification per input point.
  final List<NavTrackTerrainClass> classifications;

  /// How far below the seafloor each point sits, or 0 for points that are
  /// not [NavTrackTerrainClass.belowSeafloor]. Same length/order as
  /// [classifications].
  final List<double> penetrationMeters;

  /// Whether [grid]'s resolution is fine enough for [belowSeafloorCount] to
  /// mean anything -- see [_coarseResolutionThresholdMeters]. False on a
  /// coarse grid: only [onLandCount] is meaningful there, and the readout
  /// should say so.
  final bool resolutionSupportsBelowSeafloorCheck;

  const NavTrackTerrainCheckResult({
    required this.classifications,
    required this.penetrationMeters,
    required this.resolutionSupportsBelowSeafloorCheck,
  });

  int get total => classifications.length;

  int _count(NavTrackTerrainClass c) =>
      classifications.where((k) => k == c).length;

  int get onLandCount => _count(NavTrackTerrainClass.onLand);
  int get belowSeafloorCount => _count(NavTrackTerrainClass.belowSeafloor);
  int get unknownCount => _count(NavTrackTerrainClass.unknown);
  int get okCount => _count(NavTrackTerrainClass.ok);

  /// The deepest penetration below the seafloor found anywhere on the
  /// route, in metres, or 0 when nothing is below the seafloor.
  double get maxPenetrationMeters {
    var max = 0.0;
    for (final p in penetrationMeters) {
      if (p > max) max = p;
    }
    return max;
  }

  /// Indices of every point classed as [NavTrackTerrainClass.onLand] or
  /// [NavTrackTerrainClass.belowSeafloor] -- what the align page highlights
  /// as red dots on the route.
  List<int> get conflictingIndices => [
    for (var i = 0; i < classifications.length; i++)
      if (classifications[i] == NavTrackTerrainClass.onLand ||
          classifications[i] == NavTrackTerrainClass.belowSeafloor)
        i,
  ];

  /// A one-line human summary, e.g. "0 points on land, 2 of 3 below the
  /// seafloor (max 13.0 m), 0 unknown", with a caveat appended when the
  /// grid is too coarse for the below-seafloor count to be meaningful.
  String summaryLine(AppLocalizations l10n) {
    final maxPart = belowSeafloorCount > 0
        ? l10n.navTrack_terrain_maxPart(maxPenetrationMeters.toStringAsFixed(1))
        : '';
    final coarsePart = resolutionSupportsBelowSeafloorCheck
        ? ''
        : l10n.navTrack_terrain_coarsePart;
    return l10n.navTrack_terrain_summary(
      onLandCount,
      belowSeafloorCount,
      total,
      unknownCount,
      maxPart,
      coarsePart,
    );
  }
}

/// Checks a corrected route against bathymetry (spec
/// 2026-09-10-underwater-nav-track-design.md, "Terrain verification and
/// cleanup"): a diver cannot be inside the seafloor or on land.
///
/// Pure: reads [correctedPoints] (already rotated and drift-corrected by
/// [NavTrackCorrector]) and a [BathymetryGrid] already fetched for
/// [anchor]'s quantized cell; never mutates either.
class NavTrackTerrainCheck {
  const NavTrackTerrainCheck._();

  static NavTrackTerrainCheckResult run(
    List<CorrectedNavTrackPoint> correctedPoints,
    GeoPoint anchor,
    BathymetryGrid grid,
  ) {
    final tolerance = math.max(2.0, 0.15 * grid.resolutionMeters);
    final classifications = <NavTrackTerrainClass>[];
    final penetrations = <double>[];

    for (final point in correctedPoints) {
      final geo = offsetToGeoPoint(
        anchor,
        east: point.east,
        north: point.north,
      );
      final seafloorDepth = bilinearInterpolateDepth(
        grid,
        geo.latitude,
        geo.longitude,
      );
      if (seafloorDepth == null) {
        classifications.add(NavTrackTerrainClass.unknown);
        penetrations.add(0);
        continue;
      }
      if (seafloorDepth <= 0) {
        classifications.add(NavTrackTerrainClass.onLand);
        penetrations.add(0);
        continue;
      }
      final penetration = point.depth - seafloorDepth;
      if (penetration > tolerance) {
        classifications.add(NavTrackTerrainClass.belowSeafloor);
        penetrations.add(penetration);
      } else {
        classifications.add(NavTrackTerrainClass.ok);
        penetrations.add(0);
      }
    }

    return NavTrackTerrainCheckResult(
      classifications: classifications,
      penetrationMeters: penetrations,
      resolutionSupportsBelowSeafloorCheck:
          grid.resolutionMeters < _coarseResolutionThresholdMeters,
    );
  }
}
