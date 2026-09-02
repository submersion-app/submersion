import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/terrain_ceiling.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// One contour level ready to march: meters for geometry, a display-unit
/// label for chrome, and an optional user color (custom mode).
class ResolvedContourLevel {
  final double depthMeters;
  final bool isMajor;
  final String label;
  final int? colorArgb;

  const ResolvedContourLevel({
    required this.depthMeters,
    required this.isMajor,
    required this.label,
    this.colorArgb,
  });
}

String _formatLevel(double displayValue, String depthSymbol) {
  final text = displayValue % 1 == 0
      ? displayValue.toStringAsFixed(0)
      : displayValue.toStringAsFixed(1);
  return '$text $depthSymbol';
}

/// Resolves the contour levels for a terrain of [maxDepthMeters]. Auto mode
/// picks the smallest nice step (1/2/5 x 10^n, in the DIVER'S display unit)
/// that yields at most 15 levels, floored at 1 display unit so flat sites
/// never get centimeter contours; majors every 5th; fewer than 2 fitting
/// levels means none (flat-site guard). Custom mode uses the user's list
/// (sorted, every level labeled and treated as major); an empty list falls
/// back to auto.
List<ResolvedContourLevel> resolvedContourLevels({
  required double maxDepthMeters,
  required double displayUnitInMeters,
  required String depthSymbol,
  required SeascapeAppearance appearance,
}) {
  if (appearance.contourMode == SeascapeContourMode.custom &&
      appearance.customLevels.isNotEmpty) {
    final sorted = [...appearance.customLevels]
      ..sort((a, b) => a.depthMeters.compareTo(b.depthMeters));
    return [
      for (final l in sorted)
        ResolvedContourLevel(
          depthMeters: l.depthMeters,
          isMajor: true,
          label: _formatLevel(l.depthMeters / displayUnitInMeters, depthSymbol),
          colorArgb: l.colorArgb,
        ),
    ];
  }

  if (maxDepthMeters <= 0 || displayUnitInMeters <= 0) return const [];
  final spanDisplay = maxDepthMeters / displayUnitInMeters;
  final step = math.max(niceStep(spanDisplay / 15), 1.0);
  if (step <= 0) return const [];
  final count = (spanDisplay / step + 1e-9).floor();
  if (count < 2) return const [];
  return [
    for (var k = 1; k <= count; k++)
      ResolvedContourLevel(
        depthMeters: k * step * displayUnitInMeters,
        isMajor: k % 5 == 0,
        label: _formatLevel(k * step, depthSymbol),
      ),
  ];
}

/// A joined isobath polyline in local east/north METERS (flat pairs).
class ContourPolyline {
  final List<double> pointsEastNorth;
  const ContourPolyline(this.pointsEastNorth);
}

/// Marching squares over a callback grid. A cell is skipped when ANY of its
/// four corners is null (nodata) or <= 0 (land): contours stop at the edge
/// of known wet data instead of interpolating fiction. Inside = depth >=
/// level. Ambiguous saddle cases (5, 10) are resolved by the cell-center
/// average. Segments are then chained into polylines by shared endpoints.
List<ContourPolyline> marchGrid({
  required int rows,
  required int cols,
  required double? Function(int r, int c) depthAt,
  required double Function(int c) eastOf,
  required double Function(int r) northOf,
  required double levelMeters,
}) {
  final segments = <List<double>>[]; // [e1, n1, e2, n2]

  for (var r = 0; r < rows - 1; r++) {
    for (var c = 0; c < cols - 1; c++) {
      final sw = depthAt(r, c);
      final se = depthAt(r, c + 1);
      final nw = depthAt(r + 1, c);
      final ne = depthAt(r + 1, c + 1);
      if (sw == null || se == null || nw == null || ne == null) continue;
      if (sw <= 0 || se <= 0 || nw <= 0 || ne <= 0) continue;

      final e0 = eastOf(c), e1 = eastOf(c + 1);
      final n0 = northOf(r), n1 = northOf(r + 1);
      final l = levelMeters;

      var idx = 0;
      if (sw >= l) idx |= 1;
      if (se >= l) idx |= 2;
      if (ne >= l) idx |= 4;
      if (nw >= l) idx |= 8;
      if (idx == 0 || idx == 15) continue;

      double frac(double a, double b) => (l - a) / (b - a);
      // Crossing points on the four cell edges.
      List<double> south() => [e0 + (e1 - e0) * frac(sw, se), n0];
      List<double> east() => [e1, n0 + (n1 - n0) * frac(se, ne)];
      List<double> north() => [e0 + (e1 - e0) * frac(nw, ne), n1];
      List<double> west() => [e0, n0 + (n1 - n0) * frac(sw, nw)];

      void seg(List<double> a, List<double> b) =>
          segments.add([a[0], a[1], b[0], b[1]]);

      switch (idx) {
        case 1 || 14:
          seg(west(), south());
        case 2 || 13:
          seg(south(), east());
        case 3 || 12:
          seg(west(), east());
        case 4 || 11:
          seg(east(), north());
        case 6 || 9:
          seg(south(), north());
        case 7 || 8:
          seg(west(), north());
        case 5:
          final centerInside = (sw + se + ne + nw) / 4 >= l;
          if (centerInside) {
            seg(west(), north());
            seg(south(), east());
          } else {
            seg(west(), south());
            seg(east(), north());
          }
        case 10:
          final centerInside = (sw + se + ne + nw) / 4 >= l;
          if (centerInside) {
            seg(south(), west());
            seg(north(), east());
          } else {
            seg(south(), east());
            seg(north(), west());
          }
      }
    }
  }
  return _joinSegments(segments);
}

/// Scene-Y lift above the terrain surface so contour ribbons never z-fight
/// the mesh they trace (scene ySpan is 6.0).
const double contourLiftSceneUnits = 0.03;
const double _labelExtraLift = 0.05;
const double _minorHalfWidth = 0.016;
const double _majorHalfWidth = 0.030;
const Color _contourInk = Color(0xFFF8FAFC);
const double _minorOpacity = 0.5;
const double _majorOpacity = 0.85;
const int _labelAnchorCount = 5;

/// A labeled contour: the display-unit text plus candidate anchor points
/// (flat xyz scene-space triplets). The chrome painter picks the candidate
/// nearest the camera each frame.
class ContourLabelSpec {
  final String text;
  final List<double> anchorsXyz;
  const ContourLabelSpec({required this.text, required this.anchorsXyz});
}

/// Everything the geometry services fold into a scene for contours.
class ContourBuildResult {
  final List<SceneLayer> layers;
  final List<ContourLabelSpec> labels;
  const ContourBuildResult({required this.layers, required this.labels});
  static const ContourBuildResult empty = ContourBuildResult(
    layers: [],
    labels: [],
  );
}

/// Builds the contour SceneLayers + label anchors for a real bathymetry
/// grid. Pure and sendable: safe inside compute() isolates.
ContourBuildResult buildContourLayers({
  required BathymetryGrid grid,
  required GeoPoint center,
  required SpatialProjection projection,
  required SeascapeAppearance appearance,
  required double displayUnitInMeters,
  required String depthSymbol,
}) {
  final levels = resolvedContourLevels(
    maxDepthMeters: grid.maxDepthMeters,
    displayUnitInMeters: displayUnitInMeters,
    depthSymbol: depthSymbol,
    appearance: appearance,
  );
  if (levels.isEmpty || grid.rows < 2 || grid.cols < 2) {
    return ContourBuildResult.empty;
  }

  final mLon = metersPerDegreeLongitude(center.latitude);
  double eastOf(int c) =>
      (grid.originLon + grid.cellSizeLonDeg * c - center.longitude) * mLon;
  double northOf(int r) =>
      (grid.originLat + grid.cellSizeLatDeg * r - center.latitude) *
      BathymetryTerrainBuilder.metersPerDegLat;

  final ceiling = TerrainCeiling(
    grid: grid,
    center: center,
    projection: projection,
  );
  final layers = <SceneLayer>[];
  final labels = <ContourLabelSpec>[];
  for (final level in levels) {
    final polylines = marchGrid(
      rows: grid.rows,
      cols: grid.cols,
      depthAt: grid.depthAt,
      eastOf: eastOf,
      northOf: northOf,
      levelMeters: level.depthMeters,
    );
    if (polylines.isEmpty) continue;

    final y = projection.yOf(level.depthMeters) + contourLiftSceneUnits;
    final sceneLines = <List<double>>[];
    for (final line in polylines) {
      final pts = line.pointsEastNorth;
      final xyz = List<double>.filled(pts.length ~/ 2 * 3, 0);
      for (var i = 0; i < pts.length ~/ 2; i++) {
        xyz[i * 3] = projection.xOf(pts[i * 2]);
        xyz[i * 3 + 1] = y;
        xyz[i * 3 + 2] = projection.zOf(pts[i * 2 + 1]);
      }
      sceneLines.add(xyz);
      layers.add(
        SceneLayer(
          _ribbonMesh(
            xyz,
            isMajor: level.isMajor,
            colorArgb: level.colorArgb,
            ceiling: ceiling,
          ),
          overlay: SceneOverlay.contours,
          drapedOnTerrain: true,
        ),
      );
    }

    if (level.isMajor) {
      // Anchor candidates ride the longest polyline of the level.
      sceneLines.sort((a, b) => b.length.compareTo(a.length));
      final longest = sceneLines.first;
      final vertexCount = longest.length ~/ 3;
      final anchors = <double>[];
      for (var k = 0; k < _labelAnchorCount; k++) {
        final vi = vertexCount <= 1
            ? 0
            : (k * (vertexCount - 1) / (_labelAnchorCount - 1)).round();
        anchors
          ..add(longest[vi * 3])
          ..add(longest[vi * 3 + 1] + _labelExtraLift)
          ..add(longest[vi * 3 + 2]);
      }
      labels.add(ContourLabelSpec(text: level.label, anchorsXyz: anchors));
    }
  }
  return ContourBuildResult(layers: layers, labels: labels);
}

/// A thin horizontal ribbon along a scene-space polyline (constant y), the
/// same perpendicular-extrusion pattern as SpatialPathBuilder.buildRibbon.
///
/// Every vertex also carries a sort height: the ribbon is DRAWN on the
/// isobath but SORTED at the ceiling of the terrain cell it crosses, so the
/// rough cells that used to paint over it now lose the comparison. See
/// [TerrainCeiling].
MeshData _ribbonMesh(
  List<double> xyz, {
  required bool isMajor,
  required int? colorArgb,
  required TerrainCeiling ceiling,
}) {
  final n = xyz.length ~/ 3;
  if (n < 2) {
    return MeshData(
      positions: Float32List(0),
      indices: Uint32List(0),
      colors: Float32List(0),
    );
  }
  final halfWidth = isMajor ? _majorHalfWidth : _minorHalfWidth;
  final color = colorArgb != null ? Color(colorArgb) : _contourInk;
  final opacity = colorArgb != null
      ? _majorOpacity
      : (isMajor ? _majorOpacity : _minorOpacity);

  final positions = Float32List(n * 6);
  final colors = Float32List(n * 6);
  final sortHeights = Float32List(n * 2);
  for (var i = 0; i < n; i++) {
    final j = i < n - 1 ? i : i - 1;
    var tx = xyz[(j + 1) * 3] - xyz[j * 3];
    var tz = xyz[(j + 1) * 3 + 2] - xyz[j * 3 + 2];
    final len = math.sqrt(tx * tx + tz * tz);
    if (len > 1e-9) {
      tx /= len;
      tz /= len;
    }
    // Perpendicular in xz, rotated the way the map frame turns: scene Z
    // runs SOUTH (see SpatialProjection), so the sense is (tz, -tx). Get
    // it backwards and the ribbon's two edges swap array slots while the
    // strip indices below stay put, which splits every quad along the
    // other diagonal and shifts the triangle sort keys for free.
    final px = tz, pz = -tx;
    final vi = i * 6;
    positions[vi] = xyz[i * 3] - px * halfWidth;
    positions[vi + 1] = xyz[i * 3 + 1];
    positions[vi + 2] = xyz[i * 3 + 2] - pz * halfWidth;
    positions[vi + 3] = xyz[i * 3] + px * halfWidth;
    positions[vi + 4] = xyz[i * 3 + 1];
    positions[vi + 5] = xyz[i * 3 + 2] + pz * halfWidth;
    for (var s = 0; s < 2; s++) {
      colors[vi + s * 3] = color.r;
      colors[vi + s * 3 + 1] = color.g;
      colors[vi + s * 3 + 2] = color.b;
      // Each edge of the ribbon can straddle a different cell on rough
      // ground, so each asks for its own ceiling. The same lift that keeps
      // the ribbon off the mesh keeps its sort height off the ceiling.
      final si = vi + s * 3;
      sortHeights[i * 2 + s] = math.max(
        positions[si + 1],
        ceiling.atScene(positions[si], positions[si + 2]) +
            contourLiftSceneUnits,
      );
    }
  }
  final indices = Uint32List((n - 1) * 6);
  var q = 0;
  for (var i = 0; i < n - 1; i++) {
    final a = i * 2, b = i * 2 + 1, c = i * 2 + 2, d = i * 2 + 3;
    indices[q++] = a;
    indices[q++] = b;
    indices[q++] = c;
    indices[q++] = b;
    indices[q++] = d;
    indices[q++] = c;
  }
  return MeshData(
    positions: positions,
    indices: indices,
    colors: colors,
    opacity: opacity,
    sortHeights: sortHeights,
  );
}

/// Chains raw segments into polylines by matching endpoints (quantized to
/// a fine key so float noise never breaks a chain).
List<ContourPolyline> _joinSegments(List<List<double>> segments) {
  String key(double e, double n) => '${(e * 1e6).round()}:${(n * 1e6).round()}';

  final unused = List<bool>.filled(segments.length, true);
  final byEndpoint = <String, List<int>>{};
  for (var i = 0; i < segments.length; i++) {
    final s = segments[i];
    byEndpoint.putIfAbsent(key(s[0], s[1]), () => []).add(i);
    byEndpoint.putIfAbsent(key(s[2], s[3]), () => []).add(i);
  }

  int? takeAt(double e, double n) {
    final list = byEndpoint[key(e, n)];
    if (list == null) return null;
    for (final i in list) {
      if (unused[i]) return i;
    }
    return null;
  }

  final polylines = <ContourPolyline>[];
  for (var start = 0; start < segments.length; start++) {
    if (!unused[start]) continue;
    unused[start] = false;
    final s = segments[start];
    final pts = <double>[s[0], s[1], s[2], s[3]];
    // Extend forward from the tail.
    var extended = true;
    while (extended) {
      extended = false;
      final i = takeAt(pts[pts.length - 2], pts[pts.length - 1]);
      if (i != null) {
        unused[i] = false;
        final t = segments[i];
        final matchesHead =
            key(t[0], t[1]) == key(pts[pts.length - 2], pts[pts.length - 1]);
        pts.addAll(matchesHead ? [t[2], t[3]] : [t[0], t[1]]);
        extended = true;
      }
    }
    // Extend backward from the head.
    extended = true;
    while (extended) {
      extended = false;
      final i = takeAt(pts[0], pts[1]);
      if (i != null) {
        unused[i] = false;
        final t = segments[i];
        final matchesHead = key(t[0], t[1]) == key(pts[0], pts[1]);
        pts.insertAll(0, matchesHead ? [t[2], t[3]] : [t[0], t[1]]);
        extended = true;
      }
    }
    polylines.add(ContourPolyline(pts));
  }
  return polylines;
}
