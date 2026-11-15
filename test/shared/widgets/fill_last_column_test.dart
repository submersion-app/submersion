import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/fill_last_column.dart';

Widget _box(String label, double height) =>
    SizedBox(height: height, child: Text(label));

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 2000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 300, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(SizedBox)).first,
);

void main() {
  testWidgets('offered no height, children stack at their own heights', (
    tester,
  ) async {
    await _pump(
      tester,
      FillLastColumn(children: [_box('A', 40), _box('B', 60)]),
    );

    expect(_rect(tester, 'A'), const Rect.fromLTWH(0, 0, 300, 40));
    expect(_rect(tester, 'B'), const Rect.fromLTWH(0, 40, 300, 60));
    expect(tester.getSize(find.byType(FillLastColumn)).height, 100);
  });

  testWidgets('made taller, the last child takes the extra height', (
    tester,
  ) async {
    await _pump(
      tester,
      SizedBox(
        height: 250,
        child: FillLastColumn(children: [_box('A', 40), _box('B', 60)]),
      ),
    );

    expect(_rect(tester, 'A'), const Rect.fromLTWH(0, 0, 300, 40));
    expect(_rect(tester, 'B'), const Rect.fromLTWH(0, 40, 300, 210));
  });

  testWidgets('a stretched last child that grows takes the column along', (
    tester,
  ) async {
    final height = ValueNotifier<double>(60);
    addTearDown(height.dispose);
    await _pump(
      tester,
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 250),
        child: FillLastColumn(
          children: [
            _box('A', 40),
            ValueListenableBuilder<double>(
              valueListenable: height,
              builder: (context, value, _) => _box('B', value),
            ),
          ],
        ),
      ),
    );
    expect(_rect(tester, 'B').height, 210);

    height.value = 300;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_rect(tester, 'B').height, 300);
    expect(tester.getSize(find.byType(FillLastColumn)).height, 340);
  });

  testWidgets('with no children it is empty', (tester) async {
    await _pump(tester, const FillLastColumn(children: []));

    expect(tester.getSize(find.byType(FillLastColumn)).height, 0);
  });

  group('sizing without layout', () {
    // Fixed-size children answer every query the same way, so the column's
    // answers can be checked by arithmetic.
    Future<RenderFillLastColumn> pumpBoxes(WidgetTester tester) async {
      await _pump(
        tester,
        const FillLastColumn(
          children: [
            SizedBox(width: 120, height: 40),
            SizedBox(width: 80, height: 60),
          ],
        ),
      );
      return tester.renderObject<RenderFillLastColumn>(
        find.byType(FillLastColumn),
      );
    }

    testWidgets('intrinsic widths are the widest child', (tester) async {
      final column = await pumpBoxes(tester);

      expect(column.getMinIntrinsicWidth(double.infinity), 120);
      expect(column.getMaxIntrinsicWidth(double.infinity), 120);
    });

    testWidgets('intrinsic heights add the children up', (tester) async {
      final column = await pumpBoxes(tester);

      expect(column.getMinIntrinsicHeight(300), 100);
      expect(column.getMaxIntrinsicHeight(300), 100);
    });

    testWidgets('a dry layout is as tall as its children', (tester) async {
      final column = await pumpBoxes(tester);

      expect(
        column.getDryLayout(const BoxConstraints(maxWidth: 300)),
        const Size(300, 100),
      );
    });
  });

  testWidgets('taps reach each child', (tester) async {
    final tapped = <String>[];
    Widget tappable(String label) =>
        GestureDetector(onTap: () => tapped.add(label), child: _box(label, 50));
    await _pump(
      tester,
      FillLastColumn(children: [tappable('A'), tappable('B')]),
    );

    await tester.tap(find.text('A'));
    await tester.tap(find.text('B'));

    expect(tapped, ['A', 'B']);
  });

  testWidgets('the column reports its first child\'s baseline', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('LABEL'),
              Expanded(
                child: FillLastColumn(children: [Text('FIRST'), Text('NEXT')]),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getBottomLeft(find.text('FIRST')).dy,
      tester.getBottomLeft(find.text('LABEL')).dy,
    );
  });
}
