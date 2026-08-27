import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/forms/responsive_form_columns.dart';

Future<void> _pump(WidgetTester tester, Size size, {int? splitIndex}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ResponsiveFormColumns(
          splitIndex: splitIndex,
          children: const [
            Text('A', key: Key('A')),
            Text('B', key: Key('B')),
            Text('C', key: Key('C')),
            Text('D', key: Key('D')),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('narrow width stacks all sections in one column', (tester) async {
    await _pump(tester, const Size(700, 1200));
    final a = tester.getTopLeft(find.byKey(const Key('A')));
    final b = tester.getTopLeft(find.byKey(const Key('B')));
    final c = tester.getTopLeft(find.byKey(const Key('C')));
    // Every section sits below the previous one, sharing a column.
    expect(b.dy, greaterThan(a.dy));
    expect(c.dy, greaterThan(b.dy));
    expect(b.dx, closeTo(a.dx, 0.5));
    expect(c.dx, closeTo(a.dx, 0.5));
  });

  testWidgets('wide width splits into two columns at splitIndex', (
    tester,
  ) async {
    await _pump(tester, const Size(1300, 1200), splitIndex: 2);
    final a = tester.getTopLeft(find.byKey(const Key('A')));
    final b = tester.getTopLeft(find.byKey(const Key('B')));
    final c = tester.getTopLeft(find.byKey(const Key('C')));
    final d = tester.getTopLeft(find.byKey(const Key('D')));

    // Left column: A then B, top-aligned at the left.
    expect(b.dx, closeTo(a.dx, 0.5));
    expect(b.dy, greaterThan(a.dy));
    // Right column starts at the split (C), to the right and top-aligned with A.
    expect(c.dx, greaterThan(a.dx));
    expect(c.dy, closeTo(a.dy, 0.5));
    // D follows C down the right column.
    expect(d.dx, closeTo(c.dx, 0.5));
    expect(d.dy, greaterThan(c.dy));
  });

  testWidgets('wide width defaults to an even split when none is given', (
    tester,
  ) async {
    await _pump(tester, const Size(1300, 1200));
    // ceil(4 / 2) == 2, so C still begins the right column beside A.
    final a = tester.getTopLeft(find.byKey(const Key('A')));
    final c = tester.getTopLeft(find.byKey(const Key('C')));
    expect(c.dx, greaterThan(a.dx));
    expect(c.dy, closeTo(a.dy, 0.5));
  });
}
