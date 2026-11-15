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

  testWidgets('with no children it is empty', (tester) async {
    await _pump(tester, const FillLastColumn(children: []));

    expect(tester.getSize(find.byType(FillLastColumn)).height, 0);
  });
}
