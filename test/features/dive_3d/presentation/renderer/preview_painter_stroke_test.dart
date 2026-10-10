import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';

const _size = ui.Size(200, 150);
const _bounds = SceneBounds(
  durationSeconds: 1,
  maxDepthMeters: 10,
  sceneMinY: -SceneBounds.ySpan,
  sceneMaxY: 0,
);
const _halfWidthPx = 2.0;

/// A red line from x=2 to x=8 through the scene center, as a stroke: both
/// members of each pair sit on the centerline.
MeshData _stroke({double? strokeHalfWidthPx = _halfWidthPx}) => MeshData(
  positions: Float32List.fromList([
    2, -3, 0, //
    2, -3, 0,
    8, -3, 0,
    8, -3, 0,
  ]),
  indices: Uint32List.fromList([0, 1, 2, 1, 3, 2]),
  colors: Float32List.fromList([1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0]),
  strokeHalfWidthPx: strokeHalfWidthPx,
);

Future<ui.Image> _render(MeshData mesh, {double zoom = 1.0}) async {
  final recorder = ui.PictureRecorder();
  Dive3dScenePainter(
    scene: Scene3d(
      layers: [SceneLayer(mesh)],
      markers: const [],
      bounds: _bounds,
    ),
    yawDegrees: chartYawDegrees,
    pitchDegrees: chartPitchDegrees,
    zoom: zoom,
  ).paint(ui.Canvas(recorder), _size);
  return recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
}

/// Rows painted red in the column through the line's midpoint.
Future<int> _redRowsAtCenter(ui.Image image) async {
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final x = image.width ~/ 2;
  var rows = 0;
  for (var y = 0; y < image.height; y++) {
    final o = (y * image.width + x) * 4;
    if (bytes.getUint8(o) > 128 && bytes.getUint8(o + 1) < 64) rows++;
  }
  return rows;
}

void main() {
  group('Dive3dScenePainter stroke meshes', () {
    test('keep their pixel width when the camera zooms in', () async {
      final atZoom1 = await _redRowsAtCenter(await _render(_stroke()));
      final atZoom3 = await _redRowsAtCenter(
        await _render(_stroke(), zoom: 3.0),
      );
      expect(atZoom1, inInclusiveRange(3, 5));
      expect((atZoom3 - atZoom1).abs(), lessThanOrEqualTo(1));
    });

    test(
      'collapse to nothing without a stroke width: the pairs coincide',
      () async {
        final rows = await _redRowsAtCenter(
          await _render(_stroke(strokeHalfWidthPx: null)),
        );
        expect(rows, 0);
      },
    );

    test('are drawn in their vertex color, not flat-shaded', () async {
      final image = await _render(_stroke());
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final o = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
      // A lit face toward the camera would come out at ambient + diffuse *
      // light.z, well under full red.
      expect(bytes.getUint8(o), 255);
      expect(bytes.getUint8(o + 1), 0);
      expect(bytes.getUint8(o + 2), 0);
    });
  });

  group('Dive3dScenePainter.strokeScreenEdges', () {
    test('pushes each pair apart perpendicular to the on-screen run', () {
      final sx = Float32List.fromList([10, 10, 50, 50]);
      final sy = Float32List.fromList([20, 20, 20, 20]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 2,
        halfWidthPx: 3,
      );
      expect(sx, [10, 10, 50, 50]);
      expect(sy, [17, 23, 17, 23]);
    });

    test('keeps the previous side across a zero-length run', () {
      // Pairs 1 and 2 sit on the same canvas point (a stationary stop
      // between two moves east); they must not pinch to a point.
      final sx = Float32List.fromList([0, 0, 10, 10, 10, 10, 20, 20]);
      final sy = Float32List.fromList([5, 5, 5, 5, 5, 5, 5, 5]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 4,
        halfWidthPx: 1,
      );
      expect(sy, [4, 6, 4, 6, 4, 6, 4, 6]);
      expect(sx, [0, 0, 10, 10, 10, 10, 20, 20]);
    });

    test('miters the corner so both quads share the edge at full width', () {
      // East then north, a right angle. The corner pair sits on the
      // diagonal between the two runs' normals, stretched by sqrt(2) so
      // the stroke measures a full 2 px across either run there.
      final sx = Float32List.fromList([0, 0, 10, 10, 10, 10]);
      final sy = Float32List.fromList([0, 0, 0, 0, 10, 10]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 3,
        halfWidthPx: 1,
      );
      expect(sy.sublist(0, 2), [-1, 1]);
      expect(sx[2], closeTo(11, 1e-5));
      expect(sy[2], closeTo(-1, 1e-5));
      expect(sx[3], closeTo(9, 1e-5));
      expect(sy[3], closeTo(1, 1e-5));
      expect(sx.sublist(4), [11, 9]);
    });

    test('a stop at a turn joins like the turn itself', () {
      // Two copies of the corner point (a stationary sample at the turn):
      // both look past the zero-length run to the north leg, so the quad
      // before the stop and the quad after it meet at the same edge.
      final sx = Float32List.fromList([0, 0, 10, 10, 10, 10, 10, 10]);
      final sy = Float32List.fromList([0, 0, 0, 0, 0, 0, 10, 10]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 4,
        halfWidthPx: 1,
      );
      for (final k in [1, 2]) {
        expect(sx[k * 2], closeTo(11, 1e-5), reason: 'pair $k');
        expect(sy[k * 2], closeTo(-1, 1e-5), reason: 'pair $k');
        expect(sx[k * 2 + 1], closeTo(9, 1e-5), reason: 'pair $k');
        expect(sy[k * 2 + 1], closeTo(1, 1e-5), reason: 'pair $k');
      }
      expect(sx.sublist(6), [11, 9]);
    });

    test('joins a closed line across its seam', () {
      // A square whose last point is its first: the seam pair is a corner
      // like any other, offset along the miter of the last and first run,
      // identically at both ends.
      final sx = Float32List.fromList([0, 0, 10, 10, 10, 10, 0, 0, 0, 0]);
      final sy = Float32List.fromList([0, 0, 0, 0, 10, 10, 10, 10, 0, 0]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 5,
        halfWidthPx: 1,
      );
      expect(sx[0], closeTo(-1, 1e-5));
      expect(sy[0], closeTo(-1, 1e-5));
      expect(sx[1], closeTo(1, 1e-5));
      expect(sy[1], closeTo(1, 1e-5));
      expect(sx.sublist(8), sx.sublist(0, 2));
      expect(sy.sublist(8), sy.sublist(0, 2));
    });

    test('a stroke that never moves still gets a width', () {
      final sx = Float32List.fromList([5, 5, 5, 5]);
      final sy = Float32List.fromList([5, 5, 5, 5]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 2,
        halfWidthPx: 1,
      );
      expect(sy, [4, 6, 4, 6]);
    });

    test('keeps both edges on their sides through a reversal', () {
      // Out east and straight back: the return run's normal points the
      // other way, and taken as is it would cross the edges into a
      // bow-tie that draws nothing. Flipped to agree with the outbound
      // side, every pair keeps edge 0 below and edge 1 above.
      final sx = Float32List.fromList([0, 0, 10, 10, 0, 0]);
      final sy = Float32List.fromList([5, 5, 5, 5, 5, 5]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 3,
        halfWidthPx: 1,
      );
      expect(sy, [4, 6, 4, 6, 4, 6]);
      expect(sx, [0, 0, 10, 10, 0, 0]);
    });

    test('faces the first real run when the stroke starts stationary', () {
      final sx = Float32List.fromList([10, 10, 10, 10, 10, 10]);
      final sy = Float32List.fromList([0, 0, 0, 0, 40, 40]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 3,
        halfWidthPx: 2,
      );
      // The run is straight down the canvas, so the side is horizontal.
      expect(sx, [12, 8, 12, 8, 12, 8]);
      expect(sy, [0, 0, 0, 0, 40, 40]);
    });

    test('only touches the vertices from start on', () {
      final sx = Float32List.fromList([99, 99, 0, 0, 10, 10]);
      final sy = Float32List.fromList([99, 99, 0, 0, 0, 0]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 2,
        pairCount: 2,
        halfWidthPx: 1,
      );
      expect(sx.sublist(0, 2), [99, 99]);
      expect(sy.sublist(0, 2), [99, 99]);
      expect(sy.sublist(2), [-1, 1, -1, 1]);
    });
  });
}
