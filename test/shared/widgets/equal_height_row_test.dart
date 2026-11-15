import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/equal_height_row.dart';

/// A card whose content is [height] tall, as a detail page builds one.
Widget _card(String label, double height) => Card(
  margin: EdgeInsets.zero,
  child: SizedBox(height: height, child: Text(label)),
);

Future<void> _pump(
  WidgetTester tester,
  List<Widget> children, {
  double width = 700,
  double gap = 16,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1000, 2000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          // A detail page scrolls, so the row is offered an unbounded height.
          body: SingleChildScrollView(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(
                width: width,
                child: EqualHeightRow(gap: gap, children: children),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _cardRect(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(Card)),
);

void main() {
  testWidgets('the shorter card grows to the taller one', (tester) async {
    await _pump(tester, [_card('SHORT', 40), _card('TALL', 200)]);

    expect(_cardRect(tester, 'SHORT').height, 200);
    expect(_cardRect(tester, 'TALL').height, 200);
    expect(tester.getSize(find.byType(EqualHeightRow)).height, 200);
  });

  testWidgets('the shorter card keeps its content at the top', (tester) async {
    await _pump(tester, [_card('SHORT', 40), _card('TALL', 200)]);

    expect(
      tester.getTopLeft(find.text('SHORT')).dy,
      tester.getTopLeft(find.text('TALL')).dy,
    );
  });

  testWidgets('columns share the width equally around the gap', (tester) async {
    await _pump(tester, [_card('A', 40), _card('B', 80)], width: 700, gap: 20);

    final a = _cardRect(tester, 'A');
    final b = _cardRect(tester, 'B');
    expect(a.width, 340);
    expect(b.width, 340);
    expect(b.left - a.right, 20);
    expect(a.left, lessThan(b.left));
  });

  testWidgets('right to left, the first child sits on the right', (
    tester,
  ) async {
    await _pump(tester, [
      _card('A', 40),
      _card('B', 80),
    ], textDirection: TextDirection.rtl);

    expect(
      _cardRect(tester, 'A').left,
      greaterThan(_cardRect(tester, 'B').left),
    );
  });

  // IntrinsicHeight, the old way to share a height, asks every child for its
  // intrinsic height, which a LayoutBuilder (a map, a chart) cannot give.
  testWidgets('a child holding a LayoutBuilder lays out without error', (
    tester,
  ) async {
    await _pump(tester, [
      Card(
        margin: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              const SizedBox(height: 60, child: Text('BUILT')),
        ),
      ),
      _card('TALL', 150),
    ]);

    expect(tester.takeException(), isNull);
    expect(_cardRect(tester, 'BUILT').height, 150);
  });

  testWidgets('a taller card that shrinks takes the shorter one with it', (
    tester,
  ) async {
    final height = ValueNotifier<double>(200);
    addTearDown(height.dispose);
    await _pump(tester, [
      _card('SHORT', 40),
      ValueListenableBuilder<double>(
        valueListenable: height,
        builder: (context, value, _) => _card('TALL', value),
      ),
    ]);
    expect(_cardRect(tester, 'SHORT').height, 200);

    height.value = 100;
    await tester.pumpAndSettle();

    expect(_cardRect(tester, 'SHORT').height, 100);
    expect(_cardRect(tester, 'TALL').height, 100);
  });

  // The stretched card must still tell the row when it grows: data arriving
  // after the first frame (a tide record, a signature) makes it taller.
  testWidgets('a stretched card that grows past the row takes the row along', (
    tester,
  ) async {
    final height = ValueNotifier<double>(40);
    addTearDown(height.dispose);
    await _pump(tester, [
      ValueListenableBuilder<double>(
        valueListenable: height,
        builder: (context, value, _) => _card('GROWS', value),
      ),
      _card('TALL', 200),
    ]);
    expect(_cardRect(tester, 'GROWS').height, 200);

    height.value = 320;
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_cardRect(tester, 'GROWS').height, 320);
    expect(_cardRect(tester, 'TALL').height, 320);
    expect(tester.getSize(find.byType(EqualHeightRow)).height, 320);
  });

  testWidgets('taps reach the card in each column', (tester) async {
    final tapped = <String>[];
    Widget tappable(String label, double height) => GestureDetector(
      onTap: () => tapped.add(label),
      child: _card(label, height),
    );
    await _pump(tester, [tappable('A', 40), tappable('B', 120)]);

    // Below A's own content, in the space it now fills.
    final a = _cardRect(tester, 'A');
    await tester.tapAt(Offset(a.center.dx, a.bottom - 10));
    await tester.tap(find.text('B'));

    expect(tapped, ['A', 'B']);
  });

  testWidgets('a new gap and text direction move the columns', (tester) async {
    await _pump(tester, [_card('A', 40), _card('B', 80)], gap: 20);
    expect(_cardRect(tester, 'A').left, lessThan(_cardRect(tester, 'B').left));

    await _pump(
      tester,
      [_card('A', 40), _card('B', 80)],
      gap: 60,
      textDirection: TextDirection.rtl,
    );

    final a = _cardRect(tester, 'A');
    final b = _cardRect(tester, 'B');
    expect(a.left, greaterThan(b.left));
    expect(a.left - b.right, 60);
  });

  group('sizing without layout', () {
    RenderEqualHeightRow rowOf(WidgetTester tester) =>
        tester.renderObject<RenderEqualHeightRow>(find.byType(EqualHeightRow));

    // Fixed-size children answer every query the same way, so the row's
    // answers can be checked by arithmetic.
    Future<RenderEqualHeightRow> pumpBoxes(WidgetTester tester) async {
      await _pump(tester, const [
        SizedBox(width: 100, height: 40),
        SizedBox(width: 150, height: 90),
      ], gap: 10);
      return rowOf(tester);
    }

    testWidgets('intrinsic widths give every column the widest child', (
      tester,
    ) async {
      final row = await pumpBoxes(tester);

      expect(row.getMinIntrinsicWidth(double.infinity), 150 * 2 + 10);
      expect(row.getMaxIntrinsicWidth(double.infinity), 150 * 2 + 10);
    });

    testWidgets('intrinsic heights are the tallest child', (tester) async {
      final row = await pumpBoxes(tester);

      expect(row.getMinIntrinsicHeight(700), 90);
      expect(row.getMaxIntrinsicHeight(700), 90);
    });

    testWidgets('a dry layout is as tall as the tallest child', (tester) async {
      final row = await pumpBoxes(tester);

      expect(
        row.getDryLayout(const BoxConstraints(maxWidth: 500)),
        const Size(500, 90),
      );
    });
  });

  testWidgets('the row reports its children\'s baseline', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 600);
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
                child: EqualHeightRow(
                  gap: 8,
                  children: [Text('LEFT'), Text('RIGHT')],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getBottomLeft(find.text('LEFT')).dy,
      tester.getBottomLeft(find.text('LABEL')).dy,
    );
  });
}
