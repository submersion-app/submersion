import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_focus.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_focus_fit.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';

/// A site-sized scene: an ~8 km tile mapped onto the 10-unit scene box.
const _bounds = SceneBounds(
  durationSeconds: 3000,
  maxDepthMeters: 40,
  sceneMinY: -6,
  sceneMaxY: 0,
  sceneMinZ: -5,
  sceneMaxZ: 5,
);

/// An ~80 m route near one corner: a tenth of a scene unit across.
const _route = SceneFocus(
  minX: 7.0,
  maxX: 7.1,
  minY: -1.2,
  maxY: -0.8,
  minZ: 2.0,
  maxZ: 2.1,
);

const _size = Size(800, 600);

List<Offset> _corners(SceneProjector projector, SceneFocus f, Offset pan) => [
  for (final x in [f.minX, f.maxX])
    for (final y in [f.minY, f.maxY])
      for (final z in [f.minZ, f.maxZ]) projector.project(x, y, z) + pan,
];

void main() {
  group('SceneFocus.ofPath', () {
    test('boxes the path and pads it on every horizontal side', () {
      final focus = SceneFocus.ofPath(
        const ScrubPath(
          normalizedTimes: [0, 0.5, 1],
          xs: [1.0, 2.0, 1.5],
          ys: [-0.5, -1.0, -0.2],
          zs: [3.0, 3.5, 4.0],
        ),
      )!;

      // Horizontal span is 1.0 (x) and 1.0 (z), padded by a quarter.
      expect(focus.minX, closeTo(0.75, 1e-9));
      expect(focus.maxX, closeTo(2.25, 1e-9));
      expect(focus.minZ, closeTo(2.75, 1e-9));
      expect(focus.maxZ, closeTo(4.25, 1e-9));
      expect(focus.minY, -1.0);
      expect(focus.maxY, -0.2);
    });

    test('is null for an empty path', () {
      expect(
        SceneFocus.ofPath(const ScrubPath(normalizedTimes: [], xs: [], ys: [])),
        isNull,
      );
    });
  });

  group('SceneFocus.forRoute', () {
    const path = ScrubPath(
      normalizedTimes: [0, 1],
      xs: [1.0, 2.0],
      ys: [-0.5, -1.0],
      zs: [3.0, 4.0],
    );

    test('frames a measured route', () {
      expect(
        SceneFocus.forRoute(path, PathProvenance.measured),
        SceneFocus.ofPath(path),
      );
    });

    test('leaves an estimated path to the whole-scene view', () {
      expect(SceneFocus.forRoute(path, PathProvenance.deadReckoned), isNull);
      expect(SceneFocus.forRoute(path, PathProvenance.straightLine), isNull);
      expect(SceneFocus.forRoute(null, PathProvenance.measured), isNull);
    });
  });

  group('fitSceneFocus', () {
    test('zooms the focus to fill the view and centres it', () {
      final fit = fitSceneFocus(
        size: _size,
        bounds: _bounds,
        yawDegrees: -32,
        pitchDegrees: 22,
        focus: _route,
      );

      expect(fit.zoom, greaterThan(20));
      final projector = SceneProjector(
        size: _size,
        bounds: _bounds,
        yawDegrees: -32,
        pitchDegrees: 22,
        zoom: fit.zoom,
      );
      final pts = _corners(projector, _route, fit.pan);
      final xs = pts.map((p) => p.dx);
      final ys = pts.map((p) => p.dy);
      final minX = xs.reduce((a, b) => a < b ? a : b);
      final maxX = xs.reduce((a, b) => a > b ? a : b);
      final minY = ys.reduce((a, b) => a < b ? a : b);
      final maxY = ys.reduce((a, b) => a > b ? a : b);

      // Inside the canvas, filling most of one dimension, centred.
      expect(minX, greaterThanOrEqualTo(0));
      expect(maxX, lessThanOrEqualTo(_size.width));
      expect(minY, greaterThanOrEqualTo(0));
      expect(maxY, lessThanOrEqualTo(_size.height));
      expect(
        (maxX - minX) / _size.width > 0.8 || (maxY - minY) / _size.height > 0.8,
        isTrue,
      );
      expect((minX + maxX) / 2, closeTo(_size.width / 2, 1));
      expect((minY + maxY) / 2, closeTo(_size.height / 2, 1));
    });

    test('never zooms out past the whole-scene view', () {
      final fit = fitSceneFocus(
        size: _size,
        bounds: _bounds,
        yawDegrees: -32,
        pitchDegrees: 22,
        focus: const SceneFocus(
          minX: -20,
          maxX: 30,
          minY: -6,
          maxY: 0,
          minZ: -20,
          maxZ: 20,
        ),
      );

      expect(fit.zoom, 1.0);
    });
  });
}
