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

  List<double> restTags(
    ({List<MeshData> merged, List<List<MeshData>> restGroups}) parts,
  ) => parts.restGroups.expand((g) => g).map(tagOf).toList();

  test('visible draped layers merge with the terrain, the rest keep order', () {
    final parts = Dive3dScenePainter.partitionLayers(scene, {
      SceneOverlay.contours,
      SceneOverlay.water,
    });
    expect(parts.merged.map(tagOf).toList(), [0, 10]); // walls toggled off
    expect(restTags(parts), [30, 40]);
    expect(parts.restGroups.map((g) => g.length).toList(), [1, 1]);
  });

  test('null visibility (preview card) merges every draped layer', () {
    final parts = Dive3dScenePainter.partitionLayers(scene, null);
    expect(parts.merged.map(tagOf).toList(), [0, 10, 20]);
    expect(restTags(parts), [30, 40]);
  });

  test('all overlays off leaves the bare structural layers', () {
    final parts = Dive3dScenePainter.partitionLayers(scene, const {});
    expect(parts.merged.map(tagOf).toList(), [0]);
    expect(restTags(parts), [30]);
  });

  test('a scene with no draped layers is unchanged in behavior', () {
    final analytical = Scene3d(
      layers: [SceneLayer(mesh(0)), SceneLayer(mesh(30))],
      markers: const [],
      bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 10),
    );
    final parts = Dive3dScenePainter.partitionLayers(analytical, null);
    expect(parts.merged.map(tagOf).toList(), [0]);
    expect(restTags(parts), [30]);
  });

  test('rest layers sharing a localMergeGroup batch into one group', () {
    final grouped = Scene3d(
      layers: [
        SceneLayer(mesh(0)), // base terrain
        SceneLayer(mesh(30)), // plain rest layer, ungrouped
        SceneLayer(mesh(100), localMergeGroup: 'patch'),
        SceneLayer(
          mesh(110),
          overlay: SceneOverlay.contours,
          localMergeGroup: 'patch',
        ),
        SceneLayer(
          mesh(120),
          overlay: SceneOverlay.steepWalls,
          localMergeGroup: 'patch',
        ),
        SceneLayer(mesh(40), overlay: SceneOverlay.water),
      ],
      markers: const [],
      bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 10),
    );
    final parts = Dive3dScenePainter.partitionLayers(grouped, null);
    expect(parts.merged.map(tagOf).toList(), [0]);
    expect(parts.restGroups.map((g) => g.map(tagOf).toList()).toList(), [
      [30],
      [100, 110, 120],
      [40],
    ]);
  });
}
