import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_figure.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_fill_levels.dart';

Widget _host(
  Widget child, {
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

RenderObject _painted(WidgetTester tester) => tester.renderObject(
  find.descendant(
    of: find.byType(TankFigure),
    matching: find.byType(CustomPaint),
  ),
);

TankFigure _figure({
  double? start = 200,
  double? end = 60,
  double rated = 232,
  double? volume = 11.1,
  String? usedLabel = 'Used 140 bar',
}) {
  return TankFigure(
    levels: TankFillLevels.resolve(start: start, end: end, rated: rated),
    gasColor: Colors.green,
    volumeLiters: volume,
    startLabel: 'Start ${start?.round() ?? '--'}${start == null ? '' : ' bar'}',
    endLabel: 'End ${end?.round() ?? '--'}${end == null ? '' : ' bar'}',
    usedLabel: usedLabel,
  );
}

void main() {
  testWidgets('shows the three labels', (tester) async {
    await tester.pumpWidget(_host(_figure()));

    expect(find.text('Start 200 bar'), findsOneWidget);
    expect(find.text('End 60 bar'), findsOneWidget);
    expect(find.text('Used 140 bar'), findsOneWidget);
  });

  testWidgets('no used label when none is given', (tester) async {
    await tester.pumpWidget(
      _host(_figure(start: 100, end: 150, usedLabel: null)),
    );

    expect(find.textContaining('Used'), findsNothing);
    expect(find.text('Start 100 bar'), findsOneWidget);
    expect(find.text('End 150 bar'), findsOneWidget);
  });

  testWidgets('reads the values as one node', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_figure()));

    expect(
      tester.getSemantics(find.byType(TankFigure)),
      matchesSemantics(label: 'Start 200 bar, End 60 bar, Used 140 bar'),
    );
    handle.dispose();
  });

  testWidgets('a barely used tank keeps its labels apart', (tester) async {
    await tester.pumpWidget(
      _host(_figure(start: 200, end: 195, usedLabel: 'Used 5 bar')),
    );

    final rects = [
      tester.getRect(find.text('Start 200 bar')),
      tester.getRect(find.text('Used 5 bar')),
      tester.getRect(find.text('End 195 bar')),
    ];
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j]),
          isFalse,
          reason: 'label $i overlaps label $j',
        );
      }
    }
    // Start sits above Used, which sits above End.
    expect(rects[0].top, lessThan(rects[1].top));
    expect(rects[1].top, lessThan(rects[2].top));
  });

  testWidgets('a barely used tank fits at a large text scale', (tester) async {
    await tester.pumpWidget(
      _host(
        _figure(start: 200, end: 195, volume: 3, usedLabel: 'Used 5 bar'),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    final figure = tester.getRect(find.byType(TankFigure));
    for (final label in ['Start 200 bar', 'Used 5 bar', 'End 195 bar']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.top, greaterThanOrEqualTo(figure.top - 0.01));
      expect(rect.bottom, lessThanOrEqualTo(figure.bottom + 0.01));
    }
  });

  testWidgets('a bigger tank is drawn taller', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(key: const Key('small'), child: _figure(volume: 5)),
            KeyedSubtree(key: const Key('big'), child: _figure(volume: 18)),
          ],
        ),
      ),
    );

    final small = tester.getSize(find.byKey(const Key('small')));
    final big = tester.getSize(find.byKey(const Key('big')));
    expect(big.height, greaterThan(small.height));
  });

  testWidgets('an outline figure draws no ticks or leader lines', (
    tester,
  ) async {
    // End above start: nothing honest to fill, so no label has a level to
    // point at, even when the labels are moved off the body's edges.
    await tester.pumpWidget(
      _host(_figure(start: 100, end: 150, usedLabel: null)),
    );

    expect(_painted(tester), paintsExactlyCountTimes(#drawLine, 0));
  });

  testWidgets('a filled figure draws a tick at start and end', (tester) async {
    await tester.pumpWidget(_host(_figure()));

    // Two ticks and the bracket; the labels have room, so no leaders.
    expect(_painted(tester), paintsExactlyCountTimes(#drawLine, 3));
  });

  testWidgets('right to left puts the labels on the other side', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_figure(), direction: TextDirection.rtl));

    final figure = tester.getRect(find.byType(TankFigure));
    for (final label in ['Start 200 bar', 'Used 140 bar', 'End 60 bar']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(figure.left - 0.01));
      // The cylinder (at least 18 wide) keeps the right edge.
      expect(rect.right, lessThanOrEqualTo(figure.right - 18));
    }
  });

  testWidgets('the used tint is blended over the card it sits on', (
    tester,
  ) async {
    // A translucent card fill (as in the Deep dark preset) is composited
    // over the page; the tint has to match that, not the theme's card
    // colour alone.
    const cardFill = Color(0x80FF0000);
    await tester.pumpWidget(_host(Card(color: cardFill, child: _figure())));

    final context = tester.element(find.byType(TankFigure));
    final surface = Theme.of(context).colorScheme.surface;
    final used = Color.alphaBlend(
      Colors.green.withValues(alpha: 0.35),
      Color.alphaBlend(cardFill, surface),
    );
    expect(_painted(tester), paints..rect(color: used));
  });

  testWidgets('a moved used label is joined to its bracket', (tester) async {
    // Start 200 and end 190 sit close, so the Used label is pushed off the
    // bracket's middle; its leader starts on the bracket, not beside it.
    await tester.pumpWidget(
      _host(_figure(start: 200, end: 190, usedLabel: 'Used 10 bar')),
    );

    final height = tankFigureHeight(11.1);
    final bodyWidth =
        18 +
        (height - tankFigureMinHeight) /
            (tankFigureMaxHeight - tankFigureMinHeight) *
            10;
    final bracketX = bodyWidth + 3;
    expect(
      _painted(tester),
      paints..something((method, args) {
        if (method != #drawLine) return false;
        final from = args[0] as Offset;
        final to = args[1] as Offset;
        // A leader runs sideways to a label; the bracket itself is vertical.
        return (from.dx - bracketX).abs() < 0.01 && (to.dx - from.dx) > 1;
      }),
    );
  });
}
