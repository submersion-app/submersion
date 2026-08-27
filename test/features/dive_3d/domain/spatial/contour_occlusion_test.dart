import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A Bonaire-shaped shelf: land to the east, a narrow reef top, then a drop
/// to ~700 m westward. [noise] roughens each cell the way a real ~115 m
/// EMODnet grid is rough, which is the condition that used to bury contours.
BathymetryGrid _shelfGrid({int n = 40, double noise = 0.18}) {
  final rnd = math.Random(7);
  final depths = <double?>[];
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      final t = c / (n - 1);
      final shore = 0.72 + 0.04 * math.sin(r / n * 6.28);
      double d;
      if (t >= shore) {
        d = -20.0 * (t - shore) / (1 - shore);
      } else {
        final u = (shore - t) / shore;
        d = 700 * math.pow(u, 1.6).toDouble();
      }
      if (d > 0) d *= 1 + noise * (rnd.nextDouble() * 2 - 1);
      depths.add(d);
    }
  }
  return BathymetryGrid(
    originLat: 12.05,
    originLon: -68.32,
    cellSizeLatDeg: 8000 / 110540.0 / (n - 1),
    cellSizeLonDeg: 8000 / 108800.0 / (n - 1),
    rows: n,
    cols: n,
    depthsMeters: depths,
    sourceId: 'emodnet',
    resolutionMeters: 115,
    fetchedAt: DateTime.utc(2026, 1, 1),
  );
}

Scene3d _sceneFor(BathymetryGrid grid) =>
    const SiteSeascapeGeometryService().build(
      SiteSeascapeInput(
        grid: grid,
        center: const GeoPoint(12.09, -68.27),
        siteName: 'Alice in Wonderland',
        divePaths: [],
        nearbySites: [],
        displayUnitInMeters: 0.3048,
        depthSymbol: 'ft',
      ),
    );

/// The scene Y the painter sorts a vertex at: [MeshData.sortHeights] when
/// the mesh carries them, the drawn height otherwise.
double _sortY(MeshData m, int vertex) =>
    m.sortHeights?[vertex] ?? m.positions[vertex * 3 + 1];

double _meanSortY(MeshData m, int tri) =>
    (_sortY(m, m.indices[tri * 3]) +
        _sortY(m, m.indices[tri * 3 + 1]) +
        _sortY(m, m.indices[tri * 3 + 2])) /
    3;

double _meanDrawnY(MeshData m, int tri) =>
    (m.positions[m.indices[tri * 3] * 3 + 1] +
        m.positions[m.indices[tri * 3 + 1] * 3 + 1] +
        m.positions[m.indices[tri * 3 + 2] * 3 + 1]) /
    3;

({double x, double z}) _centroidXz(MeshData m, int tri) {
  final i0 = m.indices[tri * 3], i1 = m.indices[tri * 3 + 1];
  final i2 = m.indices[tri * 3 + 2];
  return (
    x: (m.positions[i0 * 3] + m.positions[i1 * 3] + m.positions[i2 * 3]) / 3,
    z:
        (m.positions[i0 * 3 + 2] +
            m.positions[i1 * 3 + 2] +
            m.positions[i2 * 3 + 2]) /
        3,
  );
}

bool _containsXz(MeshData m, int tri, double px, double pz) {
  final i0 = m.indices[tri * 3], i1 = m.indices[tri * 3 + 1];
  final i2 = m.indices[tri * 3 + 2];
  final ax = m.positions[i0 * 3], az = m.positions[i0 * 3 + 2];
  final bx = m.positions[i1 * 3], bz = m.positions[i1 * 3 + 2];
  final cx = m.positions[i2 * 3], cz = m.positions[i2 * 3 + 2];
  double cross(double x1, double z1, double x2, double z2) => x1 * z2 - z1 * x2;
  final d1 = cross(bx - ax, bz - az, px - ax, pz - az);
  final d2 = cross(cx - bx, cz - bz, px - bx, pz - bz);
  final d3 = cross(ax - cx, az - cz, px - cx, pz - cz);
  return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0));
}

void main() {
  // In the chart pose (pitch 90) the painter's view-space depth key IS the
  // scene Y and screen position depends only on scene X/Z, so paint order
  // can be checked exactly here with 2D containment -- no projection needed.
  test('no draped triangle sorts behind the terrain it rides', () {
    final scene = _sceneFor(_shelfGrid());
    final merged = Dive3dScenePainter.partitionLayers(scene, {
      SceneOverlay.contours,
      SceneOverlay.steepWalls,
    }).merged;
    final terrain = merged.first;
    final contours = merged.skip(1).toList();
    expect(contours, isNotEmpty);

    var checked = 0;
    final buried = <String>[];
    for (final m in contours) {
      for (var tri = 0; tri < m.triangleCount; tri++) {
        final p = _centroidXz(m, tri);
        final key = _meanSortY(m, tri);
        checked++;
        for (var tt = 0; tt < terrain.triangleCount; tt++) {
          if (!_containsXz(terrain, tt, p.x, p.z)) continue;
          if (_meanSortY(terrain, tt) > key) {
            buried.add(
              'contour at y=${_meanDrawnY(m, tri).toStringAsFixed(3)} '
              'sorts ${(_meanSortY(terrain, tt) - key).toStringAsFixed(3)} '
              'behind terrain',
            );
          }
        }
      }
    }
    expect(checked, greaterThan(500), reason: 'the fixture must be rough');
    expect(buried, isEmpty, reason: '${buried.length}/$checked buried');
  });

  test('sort heights lift contours no higher than the local cell ceiling', () {
    final scene = _sceneFor(_shelfGrid());
    final merged = Dive3dScenePainter.partitionLayers(scene, {
      SceneOverlay.contours,
    }).merged;
    final terrain = merged.first;
    var terrainCeiling = double.negativeInfinity;
    for (var i = 0; i < terrain.vertexCount; i++) {
      terrainCeiling = math.max(terrainCeiling, terrain.positions[i * 3 + 1]);
    }

    for (final m in merged.skip(1)) {
      expect(m.sortHeights, isNotNull);
      for (var i = 0; i < m.vertexCount; i++) {
        // Never sorts below where it is drawn, and never floats above the
        // whole terrain: the lift is bounded by local relief, so a contour
        // can still hide behind a distant hill in the orbit views.
        expect(_sortY(m, i), greaterThanOrEqualTo(m.positions[i * 3 + 1]));
        expect(_sortY(m, i), lessThanOrEqualTo(terrainCeiling + 0.1));
      }
    }
  });

  test('a smooth grid needs no meaningful lift', () {
    final scene = _sceneFor(_shelfGrid(noise: 0));
    final merged = Dive3dScenePainter.partitionLayers(scene, {
      SceneOverlay.contours,
    }).merged;
    var maxLift = 0.0;
    for (final m in merged.skip(1)) {
      for (var i = 0; i < m.vertexCount; i++) {
        maxLift = math.max(maxLift, _sortY(m, i) - m.positions[i * 3 + 1]);
      }
    }
    expect(maxLift, lessThan(0.35));
  });
}
