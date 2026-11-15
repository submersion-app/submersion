import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/paired_cards_row.dart';

/// A card whose content is [height] tall, as a detail page builds one.
Widget _card(String label, double height) => Card(
  margin: EdgeInsets.zero,
  child: SizedBox(height: height, child: Text(label)),
);

/// A card whose height a test can change after the first frame.
Widget _changing(String label, ValueNotifier<double> height) =>
    ValueListenableBuilder<double>(
      valueListenable: height,
      builder: (context, value, _) => _card(label, value),
    );

Future<void> _pump(
  WidgetTester tester, {
  required Widget first,
  required Widget second,
  Widget? slot,
  double width = 700,
  double columnGap = 16,
  double rowGap = 24,
  bool holdPlacement = false,
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
                child: PairedCardsRow(
                  first: first,
                  second: second,
                  slot: slot,
                  columnGap: columnGap,
                  rowGap: rowGap,
                  holdPlacement: holdPlacement,
                ),
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

double _rowHeight(WidgetTester tester) =>
    tester.getSize(find.byType(PairedCardsRow)).height;

void main() {
  group('two cards', () {
    testWidgets('the shorter card grows to the taller one', (tester) async {
      await _pump(
        tester,
        first: _card('SHORT', 40),
        second: _card('TALL', 200),
      );

      expect(_cardRect(tester, 'SHORT').height, 200);
      expect(_cardRect(tester, 'TALL').height, 200);
      expect(_rowHeight(tester), 200);
    });

    testWidgets('the shorter card keeps its content at the top', (
      tester,
    ) async {
      await _pump(
        tester,
        first: _card('SHORT', 40),
        second: _card('TALL', 200),
      );

      expect(
        tester.getTopLeft(find.text('SHORT')).dy,
        tester.getTopLeft(find.text('TALL')).dy,
      );
    });

    testWidgets('the columns share the width equally around the gap', (
      tester,
    ) async {
      await _pump(
        tester,
        first: _card('A', 40),
        second: _card('B', 80),
        columnGap: 20,
      );

      final a = _cardRect(tester, 'A');
      final b = _cardRect(tester, 'B');
      expect(a.width, 340);
      expect(b.width, 340);
      expect(b.left - a.right, 20);
    });

    testWidgets('right to left, the first card sits on the right', (
      tester,
    ) async {
      await _pump(
        tester,
        first: _card('A', 40),
        second: _card('B', 80),
        textDirection: TextDirection.rtl,
      );

      expect(
        _cardRect(tester, 'A').left,
        greaterThan(_cardRect(tester, 'B').left),
      );
    });

    // IntrinsicHeight, the old way to share a height, asks every child for
    // its intrinsic height, which a LayoutBuilder (a map, a chart) cannot
    // give.
    testWidgets('a card holding a LayoutBuilder lays out without error', (
      tester,
    ) async {
      await _pump(
        tester,
        first: Card(
          margin: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) =>
                const SizedBox(height: 60, child: Text('BUILT')),
          ),
        ),
        second: _card('TALL', 150),
      );

      expect(tester.takeException(), isNull);
      expect(_cardRect(tester, 'BUILT').height, 150);
    });

    testWidgets('a taller card that shrinks takes the shorter one with it', (
      tester,
    ) async {
      final height = ValueNotifier<double>(200);
      addTearDown(height.dispose);
      await _pump(
        tester,
        first: _card('SHORT', 40),
        second: _changing('TALL', height),
      );
      expect(_cardRect(tester, 'SHORT').height, 200);

      height.value = 100;
      await tester.pumpAndSettle();

      expect(_cardRect(tester, 'SHORT').height, 100);
      expect(_cardRect(tester, 'TALL').height, 100);
    });

    // The stretched card must still tell the row when it grows: data
    // arriving after the first frame (a tide record, a signature) makes it
    // taller.
    testWidgets('a stretched card that grows past the row takes it along', (
      tester,
    ) async {
      final height = ValueNotifier<double>(40);
      addTearDown(height.dispose);
      await _pump(
        tester,
        first: _changing('GROWS', height),
        second: _card('TALL', 200),
      );
      expect(_cardRect(tester, 'GROWS').height, 200);

      height.value = 320;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_cardRect(tester, 'GROWS').height, 320);
      expect(_cardRect(tester, 'TALL').height, 320);
      expect(_rowHeight(tester), 320);
    });

    testWidgets('taps reach the card in each column', (tester) async {
      final tapped = <String>[];
      Widget tappable(String label, double height) => GestureDetector(
        onTap: () => tapped.add(label),
        child: _card(label, height),
      );
      await _pump(tester, first: tappable('A', 40), second: tappable('B', 120));

      // Below A's own content, in the space it now fills.
      final a = _cardRect(tester, 'A');
      await tester.tapAt(Offset(a.center.dx, a.bottom - 10));
      await tester.tap(find.text('B'));

      expect(tapped, ['A', 'B']);
    });

    testWidgets('a new gap and text direction move the columns', (
      tester,
    ) async {
      await _pump(
        tester,
        first: _card('A', 40),
        second: _card('B', 80),
        columnGap: 20,
      );
      expect(
        _cardRect(tester, 'A').left,
        lessThan(_cardRect(tester, 'B').left),
      );

      await _pump(
        tester,
        first: _card('A', 40),
        second: _card('B', 80),
        columnGap: 60,
        textDirection: TextDirection.rtl,
      );

      final a = _cardRect(tester, 'A');
      final b = _cardRect(tester, 'B');
      expect(a.left, greaterThan(b.left));
      expect(a.left - b.right, 60);
    });
  });

  group('a slot card', () {
    testWidgets('that fits sits under the shorter card, columns level', (
      tester,
    ) async {
      await _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: _card('SLOT', 80),
      );

      final short = _cardRect(tester, 'SHORT');
      final slot = _cardRect(tester, 'SLOT');
      expect(slot.left, short.left);
      expect(slot.width, short.width);
      expect(slot.top - short.bottom, 24);
      // The slot takes what is left, so its column ends with the tall one.
      expect(slot.bottom, _cardRect(tester, 'TALL').bottom);
      expect(short.height, 100);
      expect(_rowHeight(tester), 300);
    });

    testWidgets('goes under whichever card is shorter', (tester) async {
      await _pump(
        tester,
        first: _card('SHORT', 100),
        second: _card('TALL', 300),
        slot: _card('SLOT', 80),
      );

      expect(_cardRect(tester, 'SLOT').left, _cardRect(tester, 'SHORT').left);
    });

    testWidgets('that does not fit goes full width below the row', (
      tester,
    ) async {
      await _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: _card('SLOT', 250),
      );

      final slot = _cardRect(tester, 'SLOT');
      expect(slot.left, 0);
      expect(slot.width, 700);
      expect(slot.top, 300 + 24);
      expect(slot.height, 250);
      // The row ends level as it does without a slot.
      expect(_cardRect(tester, 'SHORT').height, 300);
      expect(_rowHeight(tester), 300 + 24 + 250);
    });

    testWidgets('beside cards of equal height goes below the row', (
      tester,
    ) async {
      await _pump(
        tester,
        first: _card('A', 200),
        second: _card('B', 200),
        slot: _card('SLOT', 10),
      );

      expect(_cardRect(tester, 'SLOT').top, 200 + 24);
      expect(_cardRect(tester, 'SLOT').width, 700);
    });

    testWidgets('right to left, it follows the shorter card', (tester) async {
      await _pump(
        tester,
        first: _card('SHORT', 100),
        second: _card('TALL', 300),
        slot: _card('SLOT', 80),
        textDirection: TextDirection.rtl,
      );

      final short = _cardRect(tester, 'SHORT');
      expect(short.left, greaterThan(_cardRect(tester, 'TALL').left));
      expect(_cardRect(tester, 'SLOT').left, short.left);
    });

    testWidgets('that grows too tall moves below the row', (tester) async {
      final height = ValueNotifier<double>(80);
      addTearDown(height.dispose);
      await _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: _changing('SLOT', height),
      );
      expect(_cardRect(tester, 'SLOT').width, lessThan(700));

      height.value = 260;
      await tester.pumpAndSettle();

      expect(_cardRect(tester, 'SLOT').width, 700);
      expect(_cardRect(tester, 'SLOT').top, 300 + 24);
    });

    testWidgets('below the row that shrinks enough moves into the column', (
      tester,
    ) async {
      final height = ValueNotifier<double>(260);
      addTearDown(height.dispose);
      await _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: _changing('SLOT', height),
      );
      expect(_cardRect(tester, 'SLOT').width, 700);

      height.value = 80;
      await tester.pumpAndSettle();

      expect(_cardRect(tester, 'SLOT').left, _cardRect(tester, 'SHORT').left);
    });

    // A card being edited must not jump out from under the diver.
    testWidgets('held in the column, it stays there and its partner grows', (
      tester,
    ) async {
      final height = ValueNotifier<double>(80);
      addTearDown(height.dispose);
      Future<void> pumpHeld(bool hold) => _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: _changing('SLOT', height),
        holdPlacement: hold,
      );
      await pumpHeld(false);
      await pumpHeld(true);

      height.value = 400;
      await tester.pumpAndSettle();

      final short = _cardRect(tester, 'SHORT');
      final slot = _cardRect(tester, 'SLOT');
      expect(slot.left, short.left);
      expect(slot.height, 400);
      expect(_cardRect(tester, 'TALL').height, 100 + 24 + 400);
      expect(_rowHeight(tester), 100 + 24 + 400);
    });

    testWidgets('held below the row, it stays there when it would fit', (
      tester,
    ) async {
      final height = ValueNotifier<double>(260);
      addTearDown(height.dispose);
      Future<void> pumpHeld(bool hold) => _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: _changing('SLOT', height),
        holdPlacement: hold,
      );
      await pumpHeld(false);
      await pumpHeld(true);

      height.value = 80;
      await tester.pumpAndSettle();

      expect(_cardRect(tester, 'SLOT').width, 700);
    });

    testWidgets('held, a different card in the slot is placed afresh', (
      tester,
    ) async {
      Future<void> pumpSlot(String label, double height) => _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: KeyedSubtree(key: ValueKey(label), child: _card(label, height)),
        holdPlacement: true,
      );
      await pumpSlot('SMALL', 80);
      expect(_cardRect(tester, 'SMALL').width, lessThan(700));

      // Too tall for the space: the column it held was chosen for SMALL.
      await pumpSlot('BIG', 260);

      expect(_cardRect(tester, 'BIG').width, 700);
      expect(_cardRect(tester, 'BIG').top, 300 + 24);
    });

    // Opening a card's editor swaps the widgets inside its frame; it is still
    // the same card, under the same key, and keeps its place.
    testWidgets('held, the same card with new insides keeps its place', (
      tester,
    ) async {
      Future<void> pumpSlot(Widget inside) => _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: KeyedSubtree(key: const ValueKey('NOTES'), child: inside),
        holdPlacement: true,
      );
      await pumpSlot(_card('NOTES', 80));
      final before = _cardRect(tester, 'NOTES');
      expect(before.width, lessThan(700));

      await pumpSlot(
        Padding(padding: EdgeInsets.zero, child: _card('NOTES', 260)),
      );

      final after = _cardRect(tester, 'NOTES');
      expect(after.left, before.left);
      expect(after.top, before.top);
      expect(after.width, before.width);
    });

    testWidgets('keeps its state when it moves', (tester) async {
      final height = ValueNotifier<double>(80);
      addTearDown(height.dispose);
      final slotKey = GlobalKey<_CounterState>();
      await _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: ValueListenableBuilder<double>(
          valueListenable: height,
          builder: (context, value, _) => _Counter(key: slotKey, height: value),
        ),
      );
      slotKey.currentState!.bump();

      height.value = 260;
      await tester.pumpAndSettle();

      expect(slotKey.currentState!.count, 1);
    });

    testWidgets('taps reach the slot in the column and below', (tester) async {
      final tapped = <String>[];
      final height = ValueNotifier<double>(80);
      addTearDown(height.dispose);
      await _pump(
        tester,
        first: _card('TALL', 300),
        second: _card('SHORT', 100),
        slot: GestureDetector(
          onTap: () => tapped.add('SLOT'),
          child: _changing('SLOT', height),
        ),
      );
      await tester.tap(find.text('SLOT'));
      height.value = 260;
      await tester.pumpAndSettle();
      await tester.tap(find.text('SLOT'));

      expect(tapped, ['SLOT', 'SLOT']);
    });
  });

  group('sizing without layout', () {
    RenderPairedCardsRow rowOf(WidgetTester tester) =>
        tester.renderObject<RenderPairedCardsRow>(find.byType(PairedCardsRow));

    // Fixed-size children answer every query the same way, so the row's
    // answers can be checked by arithmetic.
    Future<RenderPairedCardsRow> pumpBoxes(
      WidgetTester tester, {
      Widget? slot,
    }) async {
      await _pump(
        tester,
        first: const SizedBox(width: 100, height: 300),
        second: const SizedBox(width: 150, height: 100),
        slot: slot,
        columnGap: 10,
      );
      return rowOf(tester);
    }

    testWidgets('intrinsic widths give each column the wider card', (
      tester,
    ) async {
      final row = await pumpBoxes(tester);

      expect(row.getMinIntrinsicWidth(double.infinity), 150 * 2 + 10);
      expect(row.getMaxIntrinsicWidth(double.infinity), 150 * 2 + 10);
    });

    testWidgets('a slot wider than the pair sets the intrinsic width', (
      tester,
    ) async {
      final row = await pumpBoxes(
        tester,
        slot: const SizedBox(width: 600, height: 20),
      );

      expect(row.getMinIntrinsicWidth(double.infinity), 600);
      expect(row.getMaxIntrinsicWidth(double.infinity), 600);
    });

    testWidgets('intrinsic heights are the taller card', (tester) async {
      final row = await pumpBoxes(tester);

      expect(row.getMinIntrinsicHeight(700), 300);
      expect(row.getMaxIntrinsicHeight(700), 300);
    });

    testWidgets('intrinsic heights place the slot as layout does', (
      tester,
    ) async {
      final fits = await pumpBoxes(tester, slot: const SizedBox(height: 80));
      expect(fits.getMaxIntrinsicHeight(700), 300);

      final below = await pumpBoxes(tester, slot: const SizedBox(height: 250));
      expect(below.getMinIntrinsicHeight(700), 300 + 24 + 250);
    });

    testWidgets('a dry layout matches layout', (tester) async {
      final row = await pumpBoxes(tester, slot: const SizedBox(height: 250));

      expect(
        row.getDryLayout(const BoxConstraints(maxWidth: 700)),
        const Size(700, 300 + 24 + 250),
      );
    });
  });

  testWidgets('the row reports its cards\' baseline', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 600);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('LABEL'),
              Expanded(
                child: PairedCardsRow(
                  first: const Text('LEFT'),
                  second: const Text('RIGHT'),
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

/// A card with state of its own, to show that moving it keeps that state.
class _Counter extends StatefulWidget {
  const _Counter({super.key, required this.height});

  final double height;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  void bump() => setState(() => count++);

  @override
  Widget build(BuildContext context) => _card('SLOT $count', widget.height);
}
