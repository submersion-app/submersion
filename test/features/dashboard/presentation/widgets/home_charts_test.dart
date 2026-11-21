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
