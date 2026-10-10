import 'dart:math' as math;
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

    test('bevels a doubled corner: inner miter shared, outer ends square', () {
      // Two pairs on the corner, the way the builders emit them, turning
      // left from east to north. Both pairs share the inner miter point
      // (9, 1), where the legs' inner edges meet; the first ends the east
      // leg square at (10, -1), the second starts the north leg square at
      // (11, 0). The quad between them is the bevel triangle over the
      // outer corner.
      final sx = Float32List.fromList([0, 0, 10, 10, 10, 10, 10, 10]);
      final sy = Float32List.fromList([0, 0, 0, 0, 0, 0, 10, 10]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 4,
        halfWidthPx: 1,
      );
      expect(sx.sublist(2, 4), [10, 9]);
      expect(sy.sublist(2, 4), [-1, 1]);
      expect(sx.sublist(4, 6), [11, 9]);
      expect(sy.sublist(4, 6), [0, 1]);
      expect(sx.sublist(6), [11, 9]);
    });

    test('puts the inner miter on the first member when turning right', () {
      final sx = Float32List.fromList([0, 0, 10, 10, 10, 10, 10, 10]);
      final sy = Float32List.fromList([0, 0, 0, 0, 0, 0, -10, -10]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 4,
        halfWidthPx: 1,
      );
      // Inner miter (9, -1) on the first member of both pairs; the east
      // leg ends square at (10, 1), the south leg starts square at (11, 0).
      expect(sx.sublist(2, 4), [9, 10]);
      expect(sy.sublist(2, 4), [-1, 1]);
      expect(sx.sublist(4, 6), [9, 11]);
      expect(sy.sublist(4, 6), [-1, 0]);
    });

    test('a stationary stretch on a corner joins like the corner', () {
      // Three pairs on the corner point: the extra one belongs to the
      // arriving leg, so the only filler with any area is the bevel.
      final sx = Float32List.fromList([0, 0, 10, 10, 10, 10, 10, 10, 10, 10]);
      final sy = Float32List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 10, 10]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 5,
        halfWidthPx: 1,
      );
      expect(sx.sublist(2, 6), [10, 9, 10, 9]);
      expect(sy.sublist(2, 6), [-1, 1, -1, 1]);
      expect(sx.sublist(6, 8), [11, 9]);
      expect(sy.sublist(6, 8), [0, 1]);
    });

    test('joins a closed line across its seam: the lone opening pair wraps '
        'around to the last real run', () {
      // A square: a single pair at the opening point (0, 0), two pairs on
      // the (10, 0) and (0, 10) corners, a single pair again at (10, 10)
      // -- exercising both the doubled and the lone-pair corner style in
      // one polyline -- and the closing point (0, 0) doubled, the way
      // buildStrokeStrip emits a closed line. Since the opening pair is
      // not doubled, both its members take the one miter point of the 90
      // degree seam turn; member 1 of the opening pair and member 1 of the
      // closing pair's second copy both land on that same point (1, 1).
      final sx = Float32List.fromList([
        0, 0, 10, 10, 10, 10, 10, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      ]);
      final sy = Float32List.fromList([
        0, 0, 0, 0, 0, 0, 10, 10, 10, 10, 10, 10, 0, 0, 0, 0, 0, 0, //
      ]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 9,
        halfWidthPx: 1,
      );
      // Verified by running strokeScreenEdges on this exact input.
      expect(sx, [-1, 1, 10, 9, 11, 9, 11, 9, 0, 1, -1, 1, -1, 1, -1, 1, 0, 1]);
      expect(sy, [-1, 1, -1, 1, 0, 1, 11, 9, 11, 9, 10, 9, 0, 1, 0, 1, -1, 1]);
      // The opening pair's inner member and the closing pair's inner
      // member agree: both are (1, 1).
      expect(sx[1], sx[17]);
      expect(sy[1], sy[17]);
    });

    test('joins a closed line whose opening point is doubled', () {
      // Same square, but the very first point is sampled twice before the
      // east leg starts (a stationary sample right at the seam). Pairs 0
      // and 1 then form one group that wraps the seam like any other
      // doubled corner: an asymmetric leg-end member each, and the same
      // shared inner miter point on their other member.
      final sx = Float32List.fromList([
        0, 0, 0, 0, 10, 10, 10, 10, 10, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      ]);
      final sy = Float32List.fromList([
        0, 0, 0, 0, 0, 0, 0, 0, 10, 10, 10, 10, 10, 10, 0, 0, 0, 0, 0, 0, //
      ]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 10,
        halfWidthPx: 1,
      );
      // Verified by running strokeScreenEdges on this exact input.
      expect(sx, [
        -1, 1, 0, 1, 10, 9, 11, 9, 11, 9, 0, 1, -1, 1, -1, 1, -1, 1, 0, 1, //
      ]);
      expect(sy, [
        0, 1, -1, 1, -1, 1, 0, 1, 11, 9, 11, 9, 10, 9, 0, 1, 0, 1, -1, 1, //
      ]);
      // The shared inner miter (member 1) agrees across the leading
      // group's two pairs and the closing pair.
      expect(sx[1], sx[3]);
      expect(sy[1], sy[3]);
      expect(sx[3], sx[19]);
      expect(sy[3], sy[19]);
    });

    test('a doubled hairpin keeps each leg at full width with nothing '
        'crossing', () {
      // Out east and straight back, the corner point doubled: the first
      // corner pair ends the outbound leg, the second starts the return
      // leg on the flipped normal, so the return leg's quad keeps edge 0
      // and edge 1 on their own sides and the filler between the two
      // corner pairs has no area.
      final sx = Float32List.fromList([0, 0, 10, 10, 10, 10, 0, 0]);
      final sy = Float32List.fromList([5, 5, 5, 5, 5, 5, 5, 5]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 4,
        halfWidthPx: 1,
      );
      expect(sy, [4, 6, 4, 6, 4, 6, 4, 6]);
    });

    test('bevels a sharp corner: the miter is capped at sqrt(2) widths', () {
      // East, then a 135 degree turn back up-left. A true miter would
      // reach 1 / cos(67.5) = 2.6 widths out of the corner; the cap holds
      // the corner edge at sqrt(2) along the outer bisector of the two
      // normals (0, 1) and (-sqrt1_2, -sqrt1_2).
      const s = 10 * math.sqrt1_2;
      final sx = Float32List.fromList([0, 0, 10, 10, 10 - s, 10 - s]);
      final sy = Float32List.fromList([0, 0, 0, 0, s, s]);
      Dive3dScenePainter.strokeScreenEdges(
        sx,
        sy,
        start: 0,
        pairCount: 3,
        halfWidthPx: 1,
      );
      const mx = -math.sqrt1_2, my = 1 - math.sqrt1_2;
      final len = math.sqrt(mx * mx + my * my);
      final ex = mx / len * math.sqrt2, ey = my / len * math.sqrt2;
      expect(sx[2], closeTo(10 - ex, 1e-5));
      expect(sy[2], closeTo(-ey, 1e-5));
      expect(sx[3], closeTo(10 + ex, 1e-5));
      expect(sy[3], closeTo(ey, 1e-5));
    });

    test('keeps every corner bounded, inside both legs and on consistent '
        'sides, from just past a right angle to a near hairpin', () {
      for (final deg in [91.0, 135.0, 170.0]) {
        final rad = deg * math.pi / 180;
        final dx = math.cos(rad), dy = math.sin(rad);
        final sx = Float32List.fromList([
          0,
          0,
          10,
          10,
          10 + 10 * dx,
          10 + 10 * dx,
        ]);
        final sy = Float32List.fromList([0, 0, 0, 0, 10 * dy, 10 * dy]);
        Dive3dScenePainter.strokeScreenEdges(
          sx,
          sy,
          start: 0,
          pairCount: 3,
          halfWidthPx: 1,
        );
        // Signed distance to the second leg's centerline.
        double side(double x, double y) => dx * y - dy * (x - 10);
        for (final v in [2, 3]) {
          final reach = (sx[v] - 10) * (sx[v] - 10) + sy[v] * sy[v];
          expect(reach, lessThanOrEqualTo(2 + 1e-5), reason: '$deg: reach');
          expect(sy[v].abs(), lessThanOrEqualTo(1 + 1e-5), reason: '$deg');
          expect(
            side(sx[v], sy[v]).abs(),
            lessThanOrEqualTo(1 + 1e-5),
            reason: '$deg',
          );
        }
        for (final v in [0, 1]) {
          final atCorner = side(sx[2 + v], sy[2 + v]);
          final atEnd = side(sx[4 + v], sy[4 + v]);
          expect(atEnd.abs(), closeTo(1, 1e-5), reason: '$deg: edge $v');
          expect(atCorner.sign, atEnd.sign, reason: '$deg: edge $v');
        }
      }
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
