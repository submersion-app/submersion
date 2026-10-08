import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/site_scape/presentation/patch_aware_hover_picker.dart';

class _FixedHoverPicker implements HoverPicker {
  final ScenePick? result;
  _FixedHoverPicker(this.result);

  @override
  ScenePick? pick(SceneProjector projector, Offset cursor) => result;
}

BathymetryGrid _grid(String sourceId) => BathymetryGrid(
  originLat: 0,
  originLon: 0,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 1,
  cols: 1,
  depthsMeters: const [10],
  sourceId: sourceId,
  resolutionMeters: 10,
  fetchedAt: DateTime.utc(2026, 1, 1),
);

ScenePick _pick() =>
    const ScenePick(x: 0, y: 0, z: 0, screenPos: Offset.zero, payload: 'pick');

void main() {
  final projector = SceneProjector(
    size: const Size(300, 300),
    bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 10),
  );

  test('prefers the patch picker when it hits, and reports its grid', () {
    final patchGrid = _grid('patch');
    final baseGrid = _grid('base');
    BathymetryGrid? used;
    final picker = PatchAwareHoverPicker(
      patchPicker: _FixedHoverPicker(_pick()),
      patchGrid: patchGrid,
      basePicker: _FixedHoverPicker(_pick()),
      baseGrid: baseGrid,
      onGridUsed: (g) => used = g,
    );

    final result = picker.pick(projector, Offset.zero);

    expect(result, isNotNull);
    expect(used, patchGrid);
  });

  test('falls back to the base picker when the patch picker misses', () {
    final patchGrid = _grid('patch');
    final baseGrid = _grid('base');
    BathymetryGrid? used;
    final picker = PatchAwareHoverPicker(
      patchPicker: _FixedHoverPicker(null),
      patchGrid: patchGrid,
      basePicker: _FixedHoverPicker(_pick()),
      baseGrid: baseGrid,
      onGridUsed: (g) => used = g,
    );

    final result = picker.pick(projector, Offset.zero);

    expect(result, isNotNull);
    expect(used, baseGrid);
  });

  test('uses only the base picker when there is no patch', () {
    final baseGrid = _grid('base');
    BathymetryGrid? used;
    final picker = PatchAwareHoverPicker(
      patchPicker: null,
      patchGrid: null,
      basePicker: _FixedHoverPicker(_pick()),
      baseGrid: baseGrid,
      onGridUsed: (g) => used = g,
    );

    final result = picker.pick(projector, Offset.zero);

    expect(result, isNotNull);
    expect(used, baseGrid);
  });

  test('returns null, reporting nothing, when neither picker hits', () {
    final baseGrid = _grid('base');
    BathymetryGrid? used;
    final picker = PatchAwareHoverPicker(
      patchPicker: _FixedHoverPicker(null),
      patchGrid: _grid('patch'),
      basePicker: _FixedHoverPicker(null),
      baseGrid: baseGrid,
      onGridUsed: (g) => used = g,
    );

    final result = picker.pick(projector, Offset.zero);

    expect(result, isNull);
    expect(used, isNull);
  });
}
