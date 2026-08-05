import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// Terminal states for the site seascape. The provider ALWAYS resolves to
/// one of these — a null/silent-spinner path does not exist (PR #659).
sealed class SiteSeascapeState {
  const SiteSeascapeState();
}

class SiteSeascapeReady extends SiteSeascapeState {
  final Scene3d scene;
  final String sourceId;
  final double resolutionMeters;
  final SeascapeAxisInputs axisInputs;

  /// The (downsampled) grid the terrain was built from — hover inspection
  /// reads per-cell coordinates and depth from it.
  final BathymetryGrid grid;

  const SiteSeascapeReady({
    required this.scene,
    required this.sourceId,
    required this.resolutionMeters,
    required this.axisInputs,
    required this.grid,
  });
}

class SiteSeascapeNoCoordinates extends SiteSeascapeState {
  const SiteSeascapeNoCoordinates();
}

class SiteSeascapeNoData extends SiteSeascapeState {
  const SiteSeascapeNoData();
}

/// Heaviest sites stay readable: newest dives first, capped.
const int _maxDivePaths = 30;

/// Below this cell count the scene builds synchronously (widget-test
/// FakeAsync deadlock rule); above it, in a compute() isolate.
const int _isolateCellThreshold = 4000;

final siteSeascapeProvider = FutureProvider.family<SiteSeascapeState, String>((
  ref,
  siteId,
) async {
  final site = await ref.watch(siteProvider(siteId).future);
  final center = site?.location;
  if (site == null || center == null) {
    return const SiteSeascapeNoCoordinates();
  }

  final grid = await ref.watch(
    bathymetryGridProvider(BathymetryRepository.quantize(center)).future,
  );
  if (grid == null) return const SiteSeascapeNoData();

  final allDives = await ref.watch(divesProvider.future);
  final atSite = allDives.where((d) => d.site?.id == siteId).toList()
    ..sort(
      (a, b) =>
          (b.entryTime ?? b.dateTime).compareTo(a.entryTime ?? a.dateTime),
    );
  // Reconstruct all paths concurrently: each resolution touches the DB and
  // does dead-reckoning work, so N sequential awaits would stack latency.
  final kept = atSite.take(_maxDivePaths).toList();
  final paths = await Future.wait(
    kept.map((d) => ref.watch(spatialReckonedPathProvider(d.id).future)),
  );
  final divePaths = <SiteDivePathInput>[];
  for (var i = 0; i < kept.length; i++) {
    final path = paths[i];
    if (path == null || path.points.length < 2) continue;
    final entry = kept[i].entryLocation;
    divePaths.add(
      SiteDivePathInput(
        diveId: kept[i].id,
        path: path,
        anchor: entry == null
            ? (east: 0.0, north: 0.0)
            : enuOffsetMeters(center, entry),
      ),
    );
  }

  final box = BathymetryTerrainBuilder.enuBounds(grid, center);
  final sites = await ref.watch(sitesProvider.future);
  final nearby = <NearbySiteInput>[];
  for (final s in sites) {
    final sLoc = s.location;
    if (s.id == siteId || sLoc == null) continue;
    final off = enuOffsetMeters(center, sLoc);
    final inside =
        off.east >= box.minEast &&
        off.east <= box.maxEast &&
        off.north >= box.minNorth &&
        off.north <= box.maxNorth;
    if (inside) {
      nearby.add(NearbySiteInput(siteId: s.id, name: s.name, offset: off));
    }
  }

  final input = SiteSeascapeInput(
    grid: grid,
    center: center,
    siteName: site.name,
    siteMaxDepth: site.maxDepth,
    divePaths: divePaths,
    nearbySites: nearby,
  );
  final scene = grid.rows * grid.cols > _isolateCellThreshold
      ? await compute(_buildScene, input)
      : const SiteSeascapeGeometryService().build(input);
  // Mirrors SiteSeascapeGeometryService's depth budget so the axes and the
  // terrain agree on the scene frame.
  final maxDepth = math.max(
    math.max(grid.maxDepthMeters, site.maxDepth ?? 0),
    1.0,
  );
  return SiteSeascapeReady(
    scene: scene,
    sourceId: grid.sourceId,
    resolutionMeters: grid.resolutionMeters,
    grid: grid,
    axisInputs: (
      minEast: box.minEast,
      maxEast: box.maxEast,
      minNorth: box.minNorth,
      maxNorth: box.maxNorth,
      maxDepth: maxDepth,
    ),
  );
});

Scene3d _buildScene(SiteSeascapeInput input) =>
    const SiteSeascapeGeometryService().build(input);
