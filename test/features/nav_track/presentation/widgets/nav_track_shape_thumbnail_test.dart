import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_shape_thumbnail.dart';

const _points = [
  NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 1),
  NavTrackPoint(timestamp: 10, north: 20, east: 5, depth: 2),
  NavTrackPoint(timestamp: 20, north: 10, east: -10, depth: 3),
];

Future<void> _pump(WidgetTester tester, List<NavTrackPoint> points) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: NavTrackShapeThumbnail(points: points)),
      ),
    ),
  );
}

void main() {
  testWidgets('renders a CustomPaint at the default size for a normal route', (
    tester,
  ) async {
    await _pump(tester, _points);

    final box = tester.getSize(find.byType(NavTrackShapeThumbnail));
    expect(box, const Size(40, 40));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('respects a custom size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NavTrackShapeThumbnail(points: _points, size: 80),
          ),
        ),
      ),
    );

    final box = tester.getSize(find.byType(NavTrackShapeThumbnail));
    expect(box, const Size(80, 80));
  });

  testWidgets('renders without throwing for a single-point route', (
    tester,
  ) async {
    await _pump(tester, const [
      NavTrackPoint(timestamp: 0, north: 5, east: 5, depth: 1),
    ]);

    expect(tester.takeException(), isNull);
    expect(find.byType(NavTrackShapeThumbnail), findsOneWidget);
  });

  testWidgets('renders without throwing for an empty route', (tester) async {
    await _pump(tester, const []);

    expect(tester.takeException(), isNull);
    expect(find.byType(NavTrackShapeThumbnail), findsOneWidget);
  });

  testWidgets('renders without throwing when every point is identical', (
    tester,
  ) async {
    // Zero span in both axes: the painter's scale factor would divide by
    // zero if not guarded (span <= 0 -> scale 0.0).
    await _pump(tester, const [
      NavTrackPoint(timestamp: 0, north: 5, east: 5, depth: 1),
      NavTrackPoint(timestamp: 10, north: 5, east: 5, depth: 1),
      NavTrackPoint(timestamp: 20, north: 5, east: 5, depth: 1),
    ]);

    expect(tester.takeException(), isNull);
  });
}
