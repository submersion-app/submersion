import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_shape_painter.dart';

GpsTrackPoint p(double lat, double lon) =>
    GpsTrackPoint(timestamp: 0, latitude: lat, longitude: lon);

({double min, double max}) _xRange(List<Offset> offsets) => (
  min: offsets.map((o) => o.dx).reduce((a, b) => a < b ? a : b),
  max: offsets.map((o) => o.dx).reduce((a, b) => a > b ? a : b),
);

({double min, double max}) _yRange(List<Offset> offsets) => (
  min: offsets.map((o) => o.dy).reduce((a, b) => a < b ? a : b),
  max: offsets.map((o) => o.dy).reduce((a, b) => a > b ? a : b),
);

void main() {
  group('trackShapeOffsets', () {
    const size = Size(120, 60);

    test('a dead-straight north-south track is horizontally centred', () {
      // lonSpan is 0, so an arbitrary span of 1.0 keeps the scale finite.
      // Uncorrected, every point landed on the LEADING edge of a box that
      // wide rather than at its midpoint, pushing the line left of centre.
      final offsets = trackShapeOffsets([
        p(0.0, 10.0),
        p(0.5, 10.0),
        p(1.0, 10.0),
      ], size);
      final x = _xRange(offsets);
      expect(x.min, closeTo(size.width / 2, 0.01));
      expect(x.max, closeTo(size.width / 2, 0.01));
    });

    test('a dead-straight east-west track is vertically centred', () {
      final offsets = trackShapeOffsets([
        p(10.0, 0.0),
        p(10.0, 0.5),
        p(10.0, 1.0),
      ], size);
      final y = _yRange(offsets);
      expect(y.min, closeTo(size.height / 2, 0.01));
      expect(y.max, closeTo(size.height / 2, 0.01));
    });

    test('an ordinary track stays centred on both axes', () {
      final offsets = trackShapeOffsets([
        p(0.0, 10.0),
        p(0.5, 10.5),
        p(1.0, 11.0),
      ], size);
      final x = _xRange(offsets);
      final y = _yRange(offsets);
      expect((x.min + x.max) / 2, closeTo(size.width / 2, 0.01));
      expect((y.min + y.max) / 2, closeTo(size.height / 2, 0.01));
    });

    test('every offset stays inside the canvas', () {
      final offsets = trackShapeOffsets([
        p(0.0, 10.0),
        p(0.5, 10.0),
        p(1.0, 10.0),
      ], size);
      for (final o in offsets) {
        expect(o.dx, inInclusiveRange(0, size.width));
        expect(o.dy, inInclusiveRange(0, size.height));
      }
    });

    test('fewer than two points draws nothing', () {
      expect(trackShapeOffsets([p(0, 0)], size), isEmpty);
      expect(trackShapeOffsets(const [], size), isEmpty);
    });
  });

  group('shouldRepaint', () {
    test('repaints when the points change', () {
      final a = TrackShapePainter(
        points: [p(0, 0), p(1, 1)],
        color: Colors.blue,
      );
      final b = TrackShapePainter(
        points: [p(0, 0), p(2, 2)],
        color: Colors.blue,
      );
      expect(b.shouldRepaint(a), isTrue);
    });

    test('repaints when the colour changes', () {
      final points = [p(0, 0), p(1, 1)];
      final a = TrackShapePainter(points: points, color: Colors.blue);
      final b = TrackShapePainter(points: points, color: Colors.red);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('does not repaint for an identical point list instance', () {
      final points = [p(0, 0), p(1, 1)];
      final a = TrackShapePainter(points: points, color: Colors.blue);
      final b = TrackShapePainter(points: points, color: Colors.blue);
      expect(b.shouldRepaint(a), isFalse);
    });
  });

  group('TrackShapeChip', () {
    testWidgets('renders at the requested size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TrackShapeChip(
                points: [p(0, 0), p(0.01, 0.01), p(0, 0.02)],
                width: 88,
                height: 64,
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(TrackShapeChip));
      expect(size.width, 88);
      expect(size.height, 64);
    });

    testWidgets('renders an empty track without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TrackShapeChip(points: [], width: 88, height: 64),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a single-point track without dividing by zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TrackShapeChip(points: [p(5, 5)], width: 88, height: 64),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a due-north track without producing NaN', (
      tester,
    ) async {
      // Zero longitude span: the scale would divide by zero unguarded.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TrackShapeChip(
                points: [p(0.0, 5.0), p(0.01, 5.0), p(0.02, 5.0)],
                width: 88,
                height: 64,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
