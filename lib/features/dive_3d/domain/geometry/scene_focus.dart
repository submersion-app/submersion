import 'dart:math' as math;

import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';

/// A scene-space box the camera frames by default, in place of the whole
/// [SceneBounds] box: a measured route (issue #1445) spans tens of metres
/// inside a terrain tile kilometres wide, and fitting the tile leaves the
/// route a dot.
class SceneFocus {
  const SceneFocus({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.minZ,
    required this.maxZ,
  });

  final double minX, maxX, minY, maxY, minZ, maxZ;

  /// The box around [path], padded on every horizontal side by
  /// [padFraction] of its larger horizontal span (at least [minPad] scene
  /// units) so the route does not touch the frame. Null for an empty path.
  static SceneFocus? ofPath(
    ScrubPath path, {
    double padFraction = 0.25,
    double minPad = 0.01,
  }) {
    if (path.xs.isEmpty) return null;
    final zs = path.zs ?? List<double>.filled(path.xs.length, 0);
    final minX = path.xs.reduce(math.min), maxX = path.xs.reduce(math.max);
    final minZ = zs.reduce(math.min), maxZ = zs.reduce(math.max);
    final pad = math.max(
      minPad,
      math.max(maxX - minX, maxZ - minZ) * padFraction,
    );
    return SceneFocus(
      minX: minX - pad,
      maxX: maxX + pad,
      minY: path.ys.reduce(math.min),
      maxY: path.ys.reduce(math.max),
      minZ: minZ - pad,
      maxZ: maxZ + pad,
    );
  }

  /// The dive views' default framing: a measured route's own box, so its
  /// shape is visible at first sight. An estimated path (dead reckoning,
  /// straight line) keeps the whole-scene view, as before.
  static SceneFocus? forRoute(ScrubPath? path, PathProvenance provenance) =>
      path == null || provenance != PathProvenance.measured
      ? null
      : ofPath(path);

  @override
  bool operator ==(Object other) =>
      other is SceneFocus &&
      other.minX == minX &&
      other.maxX == maxX &&
      other.minY == minY &&
      other.maxY == maxY &&
      other.minZ == minZ &&
      other.maxZ == maxZ;

  @override
  int get hashCode => Object.hash(minX, maxX, minY, maxY, minZ, maxZ);
}
