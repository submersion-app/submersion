import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

/// A one-triangle mesh whose first position doubles as an identity tag.
MeshData mesh(double tag) => MeshData(
  positions: Float32List.fromList([tag, 0, 0, tag + 1, 0, 0, tag, 1, 0]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([1, 1, 1, 1, 1, 1, 1, 1, 1]),
);

double tagOf(MeshData m) => m.positions[0];

void main() {
  final scene = Scene3d(
    layers: [
      SceneLayer(mesh(0)), // terrain (structural, always visible)
      SceneLayer(
        mesh(10),
        overlay: SceneOverlay.contours,
        drapedOnTerrain: true,
      ),
      SceneLayer(
        mesh(20),
        overlay: SceneOverlay.steepWalls,
        drapedOnTerrain: true,
      ),
      SceneLayer(mesh(30)), // dive path ribbon
      SceneLayer(mesh(40), overlay: SceneOverlay.water),
    ],
    markers: const [],
    bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 10),
  );

  test('visible draped layers merge with the terrain, the rest keep order', () {
    final parts = Dive3dScenePainter.partitionLayers(scene, {
      SceneOverlay.contours,
      SceneOverlay.water,
    });
    expect(parts.merged.map(tagOf).toList(), [0, 10]); // walls toggled off
    expect(parts.rest.map(tagOf).toList(), [30, 40]);
  });

  test('null visibility (preview card) merges every draped layer', () {
    final parts = Dive3dScenePainter.partitionLayers(scene, null);
    expect(parts.merged.map(tagOf).toList(), [0, 10, 20]);
    expect(parts.rest.map(tagOf).toList(), [30, 40]);
  });

  test('all overlays off leaves the bare structural layers', () {
    final parts = Dive3dScenePainter.partitionLayers(scene, const {});
    expect(parts.merged.map(tagOf).toList(), [0]);
    expect(parts.rest.map(tagOf).toList(), [30]);
  });

  test('a scene with no draped layers is unchanged in behavior', () {
    final analytical = Scene3d(
      layers: [SceneLayer(mesh(0)), SceneLayer(mesh(30))],
      markers: const [],
      bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 10),
    );
    final parts = Dive3dScenePainter.partitionLayers(analytical, null);
    expect(parts.merged.map(tagOf).toList(), [0]);
    expect(parts.rest.map(tagOf).toList(), [30]);
  });
}
