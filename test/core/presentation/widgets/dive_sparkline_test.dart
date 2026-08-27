import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/presentation/widgets/dive_sparkline.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

List<DiveProfilePoint> _makeProfile(int count) {
  return List.generate(
    count,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: (i % 5) * 3.0),
  );
}

void main() {
  group('DiveSparkline', () {
    testWidgets('renders LineChart when profile is non-empty', (tester) async {
      final profile = _makeProfile(10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DiveSparkline(profile: profile)),
        ),
      );

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when profile is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DiveSparkline(profile: [])),
        ),
      );

      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('respects custom width and height', (tester) async {
      final profile = _makeProfile(10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveSparkline(profile: profile, width: 120, height: 48),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(LineChart),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, 120);
      expect(sizedBox.height, 48);
    });

    testWidgets('uses provided color', (tester) async {
      final profile = _makeProfile(10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveSparkline(profile: profile, color: Colors.red),
          ),
        ),
      );

      // Widget renders (color is applied internally to LineChartBarData)
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('uses default dimensions when not specified', (tester) async {
      final profile = _makeProfile(10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DiveSparkline(profile: profile)),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(LineChart),
          matching: find.byType(SizedBox),
        ),
      );
      expect(sizedBox.width, 80);
      expect(sizedBox.height, 32);
    });

    testWidgets('renders at most the default 40 spots for a dense profile', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DiveSparkline(profile: _makeProfile(500))),
        ),
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots.length, 40);
    });

    testWidgets('honors a custom maxPoints for higher-fidelity previews', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveSparkline(profile: _makeProfile(500), maxPoints: 200),
          ),
        ),
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots.length, 200);
    });

    testWidgets('draws no overlay bar when highlightBands is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DiveSparkline(profile: _makeProfile(30))),
        ),
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.length, 1);
    });

    testWidgets('overlays a distinct-coloured bar for each highlight band', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiveSparkline(
              profile: _makeProfile(30), // timestamps 0..290
              highlightBands: const [(startX: 100.0, endX: 200.0)],
              highlightColor: Colors.orange,
            ),
          ),
        ),
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final bars = chart.data.lineBarsData;
      expect(bars.length, 2); // main line + one surface overlay
      final overlay = bars.last;
      expect(overlay.color, Colors.orange);
      expect(overlay.spots.length, greaterThan(1));
      expect(overlay.spots.every((s) => s.x >= 100 && s.x <= 200), isTrue);
    });
  });

  group('DiveSparkline.downsample', () {
    test('returns original list when at or below maxPoints', () {
      final points = _makeProfile(30);
      final result = DiveSparkline.downsample(points, maxPoints: 40);
      expect(result, same(points));
    });

    test('returns original list when exactly at maxPoints', () {
      final points = _makeProfile(40);
      final result = DiveSparkline.downsample(points, maxPoints: 40);
      expect(result, same(points));
    });

    test('downsamples to maxPoints when above threshold', () {
      final points = _makeProfile(200);
      final result = DiveSparkline.downsample(points, maxPoints: 40);
      expect(result.length, 40);
    });

    test('preserves first and last points', () {
      final points = _makeProfile(200);
      final result = DiveSparkline.downsample(points, maxPoints: 40);
      expect(result.first, points.first);
      expect(result.last, points.last);
    });

    test('handles minimal input gracefully', () {
      final single = _makeProfile(1);
      expect(DiveSparkline.downsample(single, maxPoints: 40), same(single));

      final two = _makeProfile(2);
      expect(DiveSparkline.downsample(two, maxPoints: 40), same(two));
    });

    test('clamps maxPoints below 2 instead of dividing by zero', () {
      final points = _makeProfile(200);
      // maxPoints 0/1 would make the stride divisor (maxPoints - 1) zero.
      for (final tiny in [0, 1]) {
        final result = DiveSparkline.downsample(points, maxPoints: tiny);
        expect(result.length, 2);
        expect(result.first, points.first);
        expect(result.last, points.last);
      }
    });
  });
}
