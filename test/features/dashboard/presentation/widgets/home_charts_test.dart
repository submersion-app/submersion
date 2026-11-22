import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';

/// The painter [chart] draws with, after pumping it at a fixed size.
Future<CustomPainter> _paint(
  WidgetTester tester,
  Widget chart, {
  ColorScheme? scheme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: scheme ?? const ColorScheme.light()),
      home: Center(child: SizedBox(width: 300, height: 100, child: chart)),
    ),
  );
  // MaterialApp animates a theme change: settle so the new colours are in.
  await tester.pumpAndSettle();
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(chart.runtimeType),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return paint.painter!;
}

void main() {
  // The bars are painted left to right in every language, so their labels
  // must run the same way: under a right-to-left locale a mirrored label row
  // would put each month under the wrong bar.
  testWidgets('bar labels run left to right in a right-to-left locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 100,
              child: HomeBars([1, 2, 3], labels: ['first', 'mid', 'last']),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getCenter(find.text('first')).dx,
      lessThan(tester.getCenter(find.text('last')).dx),
    );
  });

  group('sparkline points', () {
    const size = Size(258, 100);

    test('without x values the points are evenly spaced', () {
      final points = homeSparklinePoints([0, 10, 10, 0], size);
      expect(points.map((p) => p.dx), [0, 86, 172, 258]);
    });

    // A profile whose samples are not evenly spaced keeps its shape: a
    // two-minute descent takes a sliver of the width, not a third of it.
    test('with x values each point sits at its own x', () {
      final points = homeSparklinePoints(
        [0, 10, 10, 0],
        size,
        xs: [0, 120, 2400, 2580],
      );
      expect(points.map((p) => p.dx), [0, 12, 240, 258]);
    });

    test('x values that do not match the values are ignored', () {
      final points = homeSparklinePoints([0, 10, 0], size, xs: [0, 5]);
      expect(points.map((p) => p.dx), [0, 129, 258]);
    });
  });

  // Every input a painter reads must make it repaint when it changes, or
  // the chart keeps drawing the old one.
  group('a sparkline repaints when', () {
    const values = [1.0, 3.0, 2.0];

    testWidgets('fill changes', (tester) async {
      final before = await _paint(tester, const HomeSparkline(values));
      final after = await _paint(
        tester,
        const HomeSparkline(values, fill: true),
      );
      expect(after.shouldRepaint(before), isTrue);
    });

    testWidgets('invert changes', (tester) async {
      final before = await _paint(tester, const HomeSparkline(values));
      final after = await _paint(
        tester,
        const HomeSparkline(values, invert: true),
      );
      expect(after.shouldRepaint(before), isTrue);
    });
  });

  testWidgets('bars repaint when only their colours change', (tester) async {
    final before = await _paint(
      tester,
      const HomeBars([1, 2], colors: [Colors.red, Colors.blue]),
    );
    final after = await _paint(
      tester,
      const HomeBars([1, 2], colors: [Colors.green, Colors.blue]),
    );
    expect(after.shouldRepaint(before), isTrue);
  });

  group('the day grid repaints when', () {
    final counts = {DateTime(2026, 3, 2): 1};
    final to = DateTime(2026, 3, 10);

    testWidgets('only the empty-day colour changes', (tester) async {
      final grid = HomeDayGrid(
        counts: counts,
        from: DateTime(2026, 1, 1),
        to: to,
      );
      final before = await _paint(tester, grid);
      final after = await _paint(
        tester,
        grid,
        scheme: const ColorScheme.light().copyWith(
          outlineVariant: Colors.orange,
        ),
      );
      expect(after.shouldRepaint(before), isTrue);
    });

    // Jan 1 and Jan 2 2026 fall in the same week: the week count holds.
    testWidgets('only the range changes', (tester) async {
      final before = await _paint(
        tester,
        HomeDayGrid(counts: counts, from: DateTime(2026, 1, 1), to: to),
      );
      final after = await _paint(
        tester,
        HomeDayGrid(counts: counts, from: DateTime(2026, 1, 2), to: to),
      );
      expect(after.shouldRepaint(before), isTrue);
    });
  });
}
