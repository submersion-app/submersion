import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

/// Builds a 3D extrusion of the Subsurface-style tissue loading heat map.
///
/// It consumes the exact same [DecoStatus] time-series and the exact same
/// [subsurfacePercentage] value and [TissueColorFn] color scale as the 2D
/// heat map, then lifts each cell's value into height. So the scene reads as
/// "the tissue loading graph, in 3D":
/// - X = dive time (columns), Z = the 16 compartments (fast -> slow),
/// - Height & color = subsurfacePercentage (0-50 undersaturated /
///   on-gassing, 50 = ambient, 100 = M-value limit, >100 past the limit).
/// A translucent plane at 100% marks the M-value (deco) limit.
class SubsurfaceTissueBuilder {
  /// Scene-Y height for 100% (the M-value limit).
  static const double referenceHeight = 3.0;

  /// Percentage cap for the height axis (past-M-value pokes above 100%).
  static const double maxPercent = 130.0;

  /// Target time columns after decimation.
  static const int targetColumns = 220;

  static const Color _mLimitPlane = Color(0xFFEF5350);

  static double _zOf(int compartment, int count) {
    if (count <= 1) return 0;
    final t = compartment / (count - 1);
    return -SceneBounds.zSlabHalfWidth + t * 2 * SceneBounds.zSlabHalfWidth;
  }

  static double _height(double percent) =>
      (percent.clamp(0.0, maxPercent) / 100.0) * referenceHeight;

  /// Evenly-sampled indices into [length], at most [targetColumns].
  static List<int> _columnIndices(int length) {
    if (length <= targetColumns) {
      return [for (var i = 0; i < length; i++) i];
    }
    final step = length / targetColumns;
    return [
      for (var i = 0; i < targetColumns; i++) (i * step).floor(),
      length - 1,
    ];
  }

  static Scene3d build(
    List<DecoStatus> statuses, {
    required TissueColorFn colorFn,
  }) {
    if (statuses.length < 2 || statuses.first.compartments.isEmpty) {
      return const Scene3d(
        layers: [],
        markers: [],
        bounds: SceneBounds(durationSeconds: 1, maxDepthMeters: 1),
      );
    }

    final cols = _columnIndices(statuses.length);
    final k = statuses.first.compartments.length;
    final n = cols.length;

    final positions = Float32List(n * k * 3);
    final colors = Float32List(n * k * 3);
    // Per-column cursor target: the hottest (max %) compartment.
    final cursorXs = <double>[];
    final cursorYs = <double>[];
    final cursorZs = <double>[];
    final normalizedTimes = <double>[];

    for (var ci = 0; ci < n; ci++) {
      final status = statuses[cols[ci]];
      final ambient = status.ambientPressureBar;
      final x = (ci / (n - 1)) * SceneBounds.xSpan;
      var hotPct = -1.0;
      var hotZ = 0.0;
      for (var c = 0; c < k; c++) {
        final pct = subsurfacePercentage(status.compartments[c], ambient);
        final vi = (ci * k + c) * 3;
        final z = _zOf(c, k);
        positions[vi] = x;
        positions[vi + 1] = _height(pct);
        positions[vi + 2] = z;
        final color = colorFn(pct);
        colors[vi] = color.r;
        colors[vi + 1] = color.g;
        colors[vi + 2] = color.b;
        if (pct > hotPct) {
          hotPct = pct;
          hotZ = z;
        }
      }
      cursorXs.add(x);
      cursorYs.add(_height(hotPct));
      cursorZs.add(hotZ);
      normalizedTimes.add(n == 1 ? 0 : ci / (n - 1));
    }

    final surface = MeshData(
      positions: positions,
      indices: _gridIndices(n, k),
      colors: colors,
    );

    const bounds = SceneBounds(
      durationSeconds: 1,
      maxDepthMeters: 1,
      sceneMinY: 0,
      sceneMaxY: referenceHeight * (maxPercent / 100.0),
    );

    return Scene3d(
      layers: [SceneLayer(surface), SceneLayer(_mValuePlane())],
      markers: const [],
      bounds: bounds,
      scrubPath: ScrubPath(
        normalizedTimes: normalizedTimes,
        xs: cursorXs,
        ys: cursorYs,
        zs: cursorZs,
      ),
    );
  }

  /// Translucent plane at 100% = the M-value (deco) limit.
  static MeshData _mValuePlane() {
    const z = SceneBounds.zSlabHalfWidth;
    final positions = Float32List.fromList([
      0,
      referenceHeight,
      -z,
      SceneBounds.xSpan,
      referenceHeight,
      -z,
      0,
      referenceHeight,
      z,
      SceneBounds.xSpan,
      referenceHeight,
      z,
    ]);
    final colors = Float32List(4 * 3);
    for (var i = 0; i < 4; i++) {
      colors[i * 3] = _mLimitPlane.r;
      colors[i * 3 + 1] = _mLimitPlane.g;
      colors[i * 3 + 2] = _mLimitPlane.b;
    }
    return MeshData(
      positions: positions,
      indices: Uint32List.fromList([0, 1, 2, 1, 3, 2]),
      colors: colors,
      opacity: 0.14,
    );
  }

  static Uint32List _gridIndices(int cols, int k) {
    final indices = Uint32List((cols - 1) * (k - 1) * 6);
    var q = 0;
    for (var col = 0; col < cols - 1; col++) {
      for (var c = 0; c < k - 1; c++) {
        final a = col * k + c;
        final b = col * k + c + 1;
        final cc = (col + 1) * k + c;
        final dd = (col + 1) * k + c + 1;
        indices[q++] = a;
        indices[q++] = b;
        indices[q++] = cc;
        indices[q++] = b;
        indices[q++] = dd;
        indices[q++] = cc;
      }
    }
    return indices;
  }
}
