import 'dart:math' as math;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bilinear_depth_interpolation.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The fraction of a measured route's span added around it, and the floor
/// in metres: the same padding `SpatialGeometryService` gives the path, so
/// the scene frame (terrain box joined with the padded path) is exactly
/// this window.
const double _padFraction = 0.25;
const double _minPadMeters = 2.0;

/// [tile] resampled onto the window around a measured [route] placed at
/// [anchor] (local east/north metres from [center]), for a route-scale dive
/// scene (issue #1445).
///
/// A measured route spans tens of metres inside a terrain tile kilometres
/// wide. Built on the whole tile, the scene sized every ribbon, pin and
/// axis for kilometres and left the route a dot. On this window the scene
/// frame is the route's own, so everything drawn is at route scale. The
/// depths are the tile's own, bilinearly interpolated, and keep its source
/// and resolution: nothing is invented, the seafloor is just sampled more
/// finely than its real detail.
///
/// Null when the window falls outside the tile (or on nodata), so the
/// caller keeps the scene it would otherwise build.
BathymetryGrid? routeWindowGrid(
  BathymetryGrid tile,
  GeoPoint center,
  ReckonedPath route, {
  required ({double east, double north}) anchor,
  int samples = 24,
}) {
  final padE = math.max(
    (route.maxEast - route.minEast) * _padFraction,
    _minPadMeters,
  );
  final padN = math.max(
    (route.maxNorth - route.minNorth) * _padFraction,
    _minPadMeters,
  );
  final minE = route.minEast + anchor.east - padE;
  final maxE = route.maxEast + anchor.east + padE;
  final minN = route.minNorth + anchor.north - padN;
  final maxN = route.maxNorth + anchor.north + padN;

  final mLon = metersPerDegreeLongitude(center.latitude);
  const mLat = BathymetryTerrainBuilder.metersPerDegLat;
  // enuBounds measures from cell centres, so the first and last samples sit
  // on the window's edges and the grid spans exactly the window.
  final originLat = center.latitude + minN / mLat;
  final originLon = center.longitude + minE / mLon;
  final cellLat = (maxN - minN) / mLat / (samples - 1);
  final cellLon = (maxE - minE) / mLon / (samples - 1);

  final depths = <double?>[];
  for (var r = 0; r < samples; r++) {
    for (var c = 0; c < samples; c++) {
      final d = bilinearInterpolateDepth(
        tile,
        originLat + r * cellLat,
        originLon + c * cellLon,
      );
      if (d == null) return null;
      depths.add(d);
    }
  }
  return BathymetryGrid(
    originLat: originLat,
    originLon: originLon,
    cellSizeLatDeg: cellLat,
    cellSizeLonDeg: cellLon,
    rows: samples,
    cols: samples,
    depthsMeters: depths,
    sourceId: tile.sourceId,
    resolutionMeters: tile.resolutionMeters,
    fetchedAt: tile.fetchedAt,
  );
}
