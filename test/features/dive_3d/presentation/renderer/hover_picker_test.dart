import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

void main() {
  const size = Size(400, 300);
  const bounds = SceneBounds(
    durationSeconds: 100,
    maxDepthMeters: 20,
    sceneMinZ: -SceneBounds.zPathHalfSpan,
    sceneMaxZ: SceneBounds.zPathHalfSpan,
  );
  final path = ScrubPath(
    normalizedTimes: const [0, 0.5, 1],
    xs: [bounds.xOf(0), bounds.xOf(50), bounds.xOf(100)],
    ys: [bounds.yOf(0), bounds.yOf(20), bounds.yOf(0)],
    zs: const [-2, 0, 2],
  );

  test('path picker returns the nearest sample within the radius', () {
    final projector = SceneProjector(size: size, bounds: bounds);
    final picker = PathHoverPicker(path);
    final target = projector.project(path.xs[1], path.ys[1], path.zs![1]);
    final pick = picker.pick(projector, target + const Offset(4, -3))!;
    expect((pick.payload as PathPick).index, 1);
    expect((pick.x, pick.y, pick.z), (path.xs[1], path.ys[1], 0.0));
    expect(pick.screenPos, target);
    expect(picker.pick(projector, target + const Offset(40, 0)), isNull);
  });

  test('withScreenPos keeps the world anchor and payload', () {
    const pick = ScenePick(
      x: 1,
      y: 2,
      z: 3,
      screenPos: Offset.zero,
      payload: PathPick(4),
    );
    final moved = pick.withScreenPos(const Offset(9, 9));
    expect((moved.x, moved.y, moved.z), (1.0, 2.0, 3.0));
    expect(moved.screenPos, const Offset(9, 9));
    expect(identical(moved.payload, pick.payload), isTrue);
  });

  test('grid picker wraps the tissue pick with its world anchor', () {
    final result = SubsurfaceTissueBuilder.buildResult(
      BuhlmannAlgorithm().processProfile(
        depths: const [0, 30, 30, 30, 0],
        timestamps: const [0, 120, 600, 1200, 1400],
      ),
      colorFn: thermalColor,
    );
    final projector = SceneProjector(size: size, bounds: result.scene.bounds);
    final picker = GridHoverPicker(result.grid);
    const col = 1, comp = 5;
    final (x, y, z) = result.grid.positionAt(col, comp);
    final pick = picker.pick(projector, projector.project(x, y, z))!;
    final tissue = pick.payload as TissuePick;
    expect((tissue.col, tissue.comp), (col, comp));
    expect((pick.x, pick.y, pick.z), (x, y, z));
  });
}
