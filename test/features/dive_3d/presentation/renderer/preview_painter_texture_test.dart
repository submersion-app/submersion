import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

MeshData texturedTri() => MeshData(
  positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([1, 1, 1, 1, 1, 1, 1, 1, 1]),
  textureCoordinates: Float32List.fromList([0, 0, 1, 0, 0, 1]),
);

MeshData plainTri() => MeshData(
  positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([1, 0, 0, 1, 0, 0, 1, 0, 0]),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('soupTextureCoords scales UVs to pixels and fills the white texel', () {
    final coords = Dive3dScenePainter.soupTextureCoords(
      [texturedTri(), plainTri()],
      (u: 0.5, v: 0.9),
      100,
      50,
    );
    // Terrain vertices: normalized UV times image dimensions.
    expect(coords.sublist(0, 6), [0, 0, 100, 0, 0, 50]);
    // UV-less mesh: every vertex samples the white texel.
    expect(coords.sublist(6, 12), [50, 45, 50, 45, 50, 45]);
  });

  test('textured merged paint runs without error', () async {
    final recorder = ui.PictureRecorder();
    final imageRecorder = ui.PictureRecorder();
    ui.Canvas(imageRecorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 4, 4),
      ui.Paint()..color = const ui.Color(0xFF00FF00),
    );
    final image = await imageRecorder.endRecording().toImage(4, 4);
    addTearDown(image.dispose);

    final scene = Scene3d(
      layers: [
        SceneLayer(texturedTri()),
        SceneLayer(
          plainTri(),
          overlay: SceneOverlay.contours,
          drapedOnTerrain: true,
        ),
      ],
      markers: const [],
      bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 10),
    );
    Dive3dScenePainter(
      scene: scene,
      terrainImagery: image,
      imageryWhiteTexel: (u: 0.5, v: 0.9),
    ).paint(ui.Canvas(recorder), const ui.Size(200, 150));
    recorder.endRecording();
  });

  test('without imagery the painter still paints textured meshes', () {
    final recorder = ui.PictureRecorder();
    final scene = Scene3d(
      layers: [SceneLayer(texturedTri())],
      markers: const [],
      bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 10),
    );
    Dive3dScenePainter(
      scene: scene,
    ).paint(ui.Canvas(recorder), const ui.Size(200, 150));
    recorder.endRecording();
  });
}
