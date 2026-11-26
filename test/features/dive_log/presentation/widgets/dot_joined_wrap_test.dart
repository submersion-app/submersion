import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dot_joined_wrap.dart';

/// The test font draws every glyph a full em wide, so at 10 px a word of n
/// letters is n * 10 px wide and the separator ' · ' is 30 px.
const _style = TextStyle(fontSize: 10, height: 1);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required List<Widget> children,
  TextDirection textDirection = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: textDirection,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: DefaultTextStyle(
          style: _style,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: DotJoinedWrap(children: children),
            ),
          ),
        ),
      ),
    ),
  );
}

RenderDotJoinedWrap _render(WidgetTester tester) =>
    tester.renderObject<RenderDotJoinedWrap>(find.byType(DotJoinedWrap));

void main() {
  testWidgets('items that fit share a line, a dot right after each', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 400,
      children: const [Text('aa'), Text('bb'), Text('cc')],
    );

    final dots = _render(tester).separatorRects;
    expect(dots, hasLength(2));
    // Each dot starts where its item ends, on the item's line.
    expect(dots[0].left, tester.getTopRight(find.text('aa')).dx);
    expect(dots[1].left, tester.getTopRight(find.text('bb')).dx);
    expect(
      tester.getTopLeft(find.text('cc')).dy,
      tester.getTopLeft(find.text('aa')).dy,
    );
  });

  testWidgets('a dot that would end a line is not drawn', (tester) async {
    // 'aaaa' + ' · ' + 'bbbb' is 110 px: the second item starts a new line.
    await _pump(
      tester,
      width: 100,
      children: const [Text('aaaa'), Text('bbbb'), Text('cc')],
    );

    final dots = _render(tester).separatorRects;
    // 'bbbb · cc' is 90 px and shares the second line.
    expect(dots, hasLength(1));
    expect(dots.single.left, tester.getTopRight(find.text('bbbb')).dx);
    expect(
      tester.getTopLeft(find.text('bbbb')).dy,
      greaterThan(tester.getTopLeft(find.text('aaaa')).dy),
    );
  });

  testWidgets('when every item has its own line there are no dots', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 60,
      children: const [Text('aaaa'), Text('bbbb'), Text('cccc')],
    );

    expect(_render(tester).separatorRects, isEmpty);
  });

  testWidgets('an item wider than the line wraps alone, with no edge dot', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 100,
      children: const [Text('aaaa bbbb cccc'), Text('dd')],
    );

    expect(tester.takeException(), isNull);
    expect(_render(tester).separatorRects, isEmpty);
    expect(
      tester.getTopLeft(find.text('dd')).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.text('aaaa bbbb cccc')).dy,
      ),
    );
  });

  testWidgets('right to left, items run from the right with the dot after', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 400,
      textDirection: TextDirection.rtl,
      children: const [Text('aa'), Text('bb')],
    );

    final dots = _render(tester).separatorRects;
    expect(dots, hasLength(1));
    expect(
      tester.getTopLeft(find.text('aa')).dx,
      greaterThan(tester.getTopLeft(find.text('bb')).dx),
    );
    // The dot sits between them, right against the first item's start.
    expect(dots.single.right, tester.getTopLeft(find.text('aa')).dx);
  });

  testWidgets('the dots are not read out, the items are', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, width: 400, children: const [Text('aa'), Text('bb')]);

    expect(find.bySemanticsLabel(RegExp('·')), findsNothing);
    expect(find.bySemanticsLabel('aa'), findsOneWidget);
    expect(find.bySemanticsLabel('bb'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('one item is shown as it is, and none takes no room', (
    tester,
  ) async {
    await _pump(tester, width: 400, children: const [Text('aa')]);
    expect(find.text('aa'), findsOneWidget);

    await _pump(tester, width: 400, children: const []);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap reaches an item', (tester) async {
    var tapped = 0;
    await _pump(
      tester,
      width: 400,
      children: [
        const Text('aa'),
        GestureDetector(onTap: () => tapped++, child: const Text('bb')),
      ],
    );

    await tester.tap(find.text('bb'));
    expect(tapped, 1);
  });

  group('sizing for its parent', () {
    Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: DefaultTextStyle(
          style: _style,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );

    testWidgets('its natural width is the items and dots on one line', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const IntrinsicWidth(
            child: DotJoinedWrap(children: [Text('aa'), Text('bb')]),
          ),
        ),
      );

      // 'aa' + ' · ' + 'bb': 20 + 30 + 20.
      expect(tester.getSize(find.byType(DotJoinedWrap)).width, 70);
      final render = _render(tester);
      expect(render.getMinIntrinsicWidth(double.infinity), 20);
      expect(render.getMaxIntrinsicWidth(double.infinity), 70);
    });

    testWidgets('its natural height follows the lines at a width', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 60,
            child: IntrinsicHeight(
              child: DotJoinedWrap(children: [Text('aaaa'), Text('bbbb')]),
            ),
          ),
        ),
      );

      // Two 10 px lines with 2 px between them.
      expect(tester.getSize(find.byType(DotJoinedWrap)).height, 22);
      final render = _render(tester);
      expect(render.getMinIntrinsicHeight(60), 22);
      expect(render.getMaxIntrinsicHeight(60), 22);
      expect(
        render.getDryLayout(const BoxConstraints(maxWidth: 60)).height,
        22,
      );
    });

    testWidgets('it lines up on its first item\'s baseline', (tester) async {
      await tester.pumpWidget(
        host(
          const Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('x', style: TextStyle(fontSize: 30, height: 1)),
              DotJoinedWrap(children: [Text('aa'), Text('bb')]),
            ],
          ),
        ),
      );

      // The test font's ascent is 0.75 em, so a baseline sits that far
      // below each text's top.
      expect(
        tester.getTopLeft(find.text('aa')).dy + 0.75 * 10,
        tester.getTopLeft(find.text('x')).dy + 0.75 * 30,
      );
    });
  });

  group('when its surroundings change', () {
    Future<void> pumpWith(
      WidgetTester tester, {
      TextStyle style = _style,
      double scale = 1,
      bool bold = false,
      TextDirection direction = TextDirection.ltr,
    }) => tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            boldText: bold,
          ),
          child: DefaultTextStyle(
            style: style,
            child: const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: DotJoinedWrap(children: [Text('aa'), Text('bb')]),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('a larger text size widens the dots', (tester) async {
      await pumpWith(tester);
      expect(_render(tester).separatorRects.single.width, 30);

      await pumpWith(tester, scale: 2);
      expect(_render(tester).separatorRects.single.width, 60);
    });

    testWidgets('a new text style redraws the dots in it', (tester) async {
      await pumpWith(tester);
      await pumpWith(tester, style: _style.copyWith(fontSize: 20));
      expect(_render(tester).separatorRects.single.width, 60);
    });

    testWidgets('a new direction moves the dots', (tester) async {
      await pumpWith(tester);
      final before = _render(tester).separatorRects.single.left;
      await pumpWith(tester, direction: TextDirection.rtl);
      expect(_render(tester).separatorRects.single.left, isNot(before));
    });

    testWidgets('bold text draws the dots bold, as the items are', (
      tester,
    ) async {
      await pumpWith(tester, bold: true);
      final widget = tester.widget<MultiChildRenderObjectWidget>(
        find
            .descendant(
              of: find.byType(DotJoinedWrap),
              matching: find.byWidgetPredicate(
                (w) => w is MultiChildRenderObjectWidget,
              ),
            )
            .first,
      );
      expect((widget as dynamic).separatorStyle.fontWeight, FontWeight.bold);
    });
  });
}
