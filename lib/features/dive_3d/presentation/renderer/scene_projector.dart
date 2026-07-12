import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// Orthographic projector: yaw about Y then pitch about X, drop view z,
/// fit to canvas, scale by zoom. The single camera model for every dive_3d
/// renderer -- preview card, interactive viewport, and deterministic tests.
/// No GL involved.
class SceneProjector {
  final double _cy, _sy, _cp, _sp;
  // The scene's actual vertical center, so scenes that override the Y range
  // (e.g. the tissue surface with sceneMinY: 0) orbit around the right pivot
  // instead of the default depth midpoint.
  final double _yCenter;
  late final double _scale;
  late final Offset _offset;

  SceneProjector({
    required Size size,
    required SceneBounds bounds,
    double yawDegrees = -32,
    double pitchDegrees = 22,
    double zoom = 1.0,
  }) : _cy = math.cos(yawDegrees * math.pi / 180),
       _sy = math.sin(yawDegrees * math.pi / 180),
       _cp = math.cos(pitchDegrees * math.pi / 180),
       _sp = math.sin(pitchDegrees * math.pi / 180),
       _yCenter = (bounds.sceneMinY + bounds.sceneMaxY) / 2 {
    // Fit: project the scene box corners at unit scale, then scale and
    // center the bounding box into the canvas with a margin.
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final x in const [0.0, SceneBounds.xSpan]) {
      for (final y in [bounds.sceneMinY, bounds.sceneMaxY]) {
        for (final z in [bounds.sceneMinZ, bounds.sceneMaxZ]) {
          final v = _view(x, y, z);
          minX = math.min(minX, v.$1);
          maxX = math.max(maxX, v.$1);
          minY = math.min(minY, -v.$2);
          maxY = math.max(maxY, -v.$2);
        }
      }
    }
    const margin = 0.92;
    _scale =
        zoom *
        margin *
        math.min(size.width / (maxX - minX), size.height / (maxY - minY));
    _offset = Offset(
      (size.width - (maxX + minX) * _scale) / 2,
      (size.height - (maxY + minY) * _scale) / 2,
    );
  }

  /// Rotated view-space coordinates (x right, y up, z toward camera).
  (double, double, double) _view(double x, double y, double z) {
    final cx = x - SceneBounds.xSpan / 2;
    final cyy = y - _yCenter;
    final rx = cx * _cy + z * _sy;
    final rz = -cx * _sy + z * _cy;
    final ry = cyy * _cp - rz * _sp;
    final rz2 = cyy * _sp + rz * _cp;
    return (rx, ry, rz2);
  }

  Offset project(double x, double y, double z) => projectView(_view(x, y, z));

  /// Full rotated view-space position (x right, y up, z toward camera).
  /// The renderer uses it for flat-shading face normals and depth sorting
  /// without paying for the rotation twice per vertex.
  (double, double, double) viewOf(double x, double y, double z) =>
      _view(x, y, z);

  /// Projects an already-rotated view-space position onto the canvas.
  Offset projectView((double, double, double) v) =>
      Offset(v.$1 * _scale, -v.$2 * _scale) + _offset;

  /// Larger = nearer to camera. Used for back-to-front triangle sorting.
  double viewDepth(double x, double y, double z) => _view(x, y, z).$3;
}
