import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_focus.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';

/// The zoom and screen pan that frame [focus] in a [size] canvas under the
/// given camera angle, for [Dive3dInteractiveViewport]'s focus framing.
///
/// [SceneProjector] centres the whole scene box in the canvas, so a zoom
/// change scales every projected point about the canvas centre. The fit
/// therefore projects the focus corners once at zoom 1, takes the zoom that
/// fills [margin] of the canvas with them, and pans their centre back onto
/// the canvas centre. It never zooms out past the whole-scene view.
({double zoom, Offset pan}) fitSceneFocus({
  required Size size,
  required SceneBounds bounds,
  required double yawDegrees,
  required double pitchDegrees,
  required SceneFocus focus,
  double margin = 0.85,
}) {
  final projector = SceneProjector(
    size: size,
    bounds: bounds,
    yawDegrees: yawDegrees,
    pitchDegrees: pitchDegrees,
  );
  var minX = double.infinity, maxX = double.negativeInfinity;
  var minY = double.infinity, maxY = double.negativeInfinity;
  for (final x in [focus.minX, focus.maxX]) {
    for (final y in [focus.minY, focus.maxY]) {
      for (final z in [focus.minZ, focus.maxZ]) {
        final p = projector.project(x, y, z);
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
    }
  }
  const tiny = 1e-6;
  final zoom = math.max(
    1.0,
    margin *
        math.min(
          size.width / math.max(maxX - minX, tiny),
          size.height / math.max(maxY - minY, tiny),
        ),
  );
  final centre = Offset((minX + maxX) / 2, (minY + maxY) / 2);
  final canvasCentre = Offset(size.width / 2, size.height / 2);
  return (zoom: zoom, pan: -(centre - canvasCentre) * zoom);
}
