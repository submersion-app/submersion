import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

const _size = ui.Size(200, 150);
const _bounds = SceneBounds(
  durationSeconds: 1,
  maxDepthMeters: 10,
  sceneMinY: -SceneBounds.ySpan,
  sceneMaxY: 0,
);

/// One big terrain triangle that falls steeply across its own width, the
/// way a rough bathymetry cell does. Its CENTROID sits at y = -2, nearer
/// the camera than the drape at y = -2.5 that rides its far half.
final _terrain = MeshData(
  positions: Float32List.fromList([2, -3, -0.8, 8, -3, -0.8, 5, 0, 0.8]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([1, 0, 0, 1, 0, 0, 1, 0, 0]),
);

MeshData _drape({bool withSortHeights = true}) => MeshData(
  positions: Float32List.fromList([
    4.8, -2.5, -0.4, //
    5.2, -2.5, -0.4,
    5.0, -2.5, -0.1,
  ]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([0, 1, 0, 0, 1, 0, 0, 1, 0]),
  // The ceiling of the terrain it rides.
  sortHeights: withSortHeights ? Float32List.fromList([0, 0, 0]) : null,
);

Future<ui.Image> _render(MeshData drape) async {
  final recorder = ui.PictureRecorder();
  Dive3dScenePainter(
    scene: Scene3d(
      layers: [
        SceneLayer(_terrain),
        SceneLayer(
          drape,
          overlay: SceneOverlay.contours,
          drapedOnTerrain: true,
        ),
      ],
      markers: const [],
      bounds: _bounds,
    ),
    yawDegrees: chartYawDegrees,
    pitchDegrees: chartPitchDegrees,
  ).paint(ui.Canvas(recorder), _size);
  return recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
}

/// The rgb at the drape's projected centroid. Flat shading darkens the
/// vertex colors, so tests compare channels rather than exact values.
Future<({int r, int g})> _pixelAtDrape(ui.Image image) async {
  final projector = SceneProjector(
    size: _size,
    bounds: _bounds,
    yawDegrees: chartYawDegrees,
    pitchDegrees: chartPitchDegrees,
  );
  final p = projector.project(5.0, -2.5, -0.3);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final offset = (p.dy.round() * image.width + p.dx.round()) * 4;
  return (r: bytes.getUint8(offset), g: bytes.getUint8(offset + 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sort heights must carry one entry per vertex', () {
    // The renderer indexes sortHeights by vertex; a short list would throw a
    // RangeError deep in the paint loop instead of at the mistake.
    expect(
      () => MeshData(
        positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
        indices: Uint32List.fromList([0, 1, 2]),
        colors: Float32List.fromList([1, 1, 1, 1, 1, 1, 1, 1, 1]),
        sortHeights: Float32List.fromList([0, 0]),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('a drape sorted at the cell ceiling paints over the terrain', () async {
    final image = await _render(_drape());
    addTearDown(image.dispose);
    final px = await _pixelAtDrape(image);
    expect(px.g, greaterThan(px.r), reason: 'the drape should be visible');
  });

  test('without sort heights the same drape is buried', () async {
    final image = await _render(_drape(withSortHeights: false));
    addTearDown(image.dispose);
    final px = await _pixelAtDrape(image);
    // Documents the bug this mechanism exists to fix: centroid ordering
    // alone hands the pixel to the terrain triangle underneath.
    expect(px.r, greaterThan(px.g));
  });
}
