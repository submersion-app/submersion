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
  });
}
