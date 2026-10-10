import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/master_detail/keyboard_list_focus_ring.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';

import '../../../helpers/keyboard_navigation_contract.dart';

const _rowWidth = 800.0;

/// One list row, [row], under a focused navigator whose cursor sits on it.
Future<void> _pumpRingedRow(
  WidgetTester tester,
  Widget row, {
  ThemeData? theme,
}) async {
  useDesktopFocusHighlighting();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: KeyboardListNavigator(
          keys: const ['a'],
          currentKey: null,
          onMove: (_) {},
          child: ListView(
            children: [
              KeyboardListItem(
                navigationKey: 'a',
                child: KeyedSubtree(key: const ValueKey('row-a'), child: row),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  // A click focuses the list and puts the cursor, and so the ring, on it.
  await clickWithMouse(tester, find.byKey(const ValueKey('row-a')));
  await tester.pumpAndSettle();
}

RenderObject _ringedRow(WidgetTester tester) =>
    tester.renderObject(find.byType(KeyboardListItem));

/// The ring a 2px inside border paints around [rrect], wherever it falls
/// among the row's other drawing.
PaintPattern _ringAround(RRect rrect) => paints
  ..something(
    (method, arguments) =>
        method == #drawDRRect &&
        arguments[0] == rrect &&
        arguments[1] == rrect.deflate(2),
  );

ThemeData _cardTheme(double radius, {BorderSide side = BorderSide.none}) =>
    ThemeData(
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: side,
        ),
      ),
    );

void main() {
  testWidgets('the ring traces a card inside its margin, not the margin', (
    tester,
  ) async {
    // The dive list's detailed card: a 16/4 margin around a themed Card (#3224).
    await _pumpRingedRow(
      tester,
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Card(margin: EdgeInsets.zero, child: SizedBox(height: 40)),
      ),
      theme: _cardTheme(12),
    );

    expect(
      _ringedRow(tester),
      _ringAround(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(16, 4, _rowWidth - 32, 40),
          const Radius.circular(12),
        ),
      ),
    );
  });

  testWidgets('the ring takes the corner radius of the theme\'s cards', (
    tester,
  ) async {
    // A Card's own margin, with a theme whose cards are rounder than 12 and
    // already carry an outline of their own.
    await _pumpRingedRow(
      tester,
      const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: SizedBox(height: 40),
      ),
      theme: _cardTheme(20, side: const BorderSide(color: Colors.grey)),
    );

    final ring = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 2, _rowWidth - 32, 40),
      const Radius.circular(20),
    );
    expect(_ringedRow(tester), _ringAround(ring));
  });

  testWidgets('a shaped Material behind padding is ringed the same way', (
    tester,
  ) async {
    // The dive list's trip group header.
    await _pumpRingedRow(
      tester,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        child: Material(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(height: 40),
        ),
      ),
    );

    expect(
      _ringedRow(tester),
      _ringAround(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(16, 6, _rowWidth - 32, 40),
          const Radius.circular(12),
        ),
      ),
    );
  });

  testWidgets('a row with no card of its own is ringed at its bounds', (
    tester,
  ) async {
    await _pumpRingedRow(tester, const SizedBox(height: 40));

    expect(
      _ringedRow(tester),
      _ringAround(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, _rowWidth, 40),
          const Radius.circular(12),
        ),
      ),
    );
  });

  testWidgets('a full-width Material is the row\'s surface, not a card in it', (
    tester,
  ) async {
    // A settings-style row: the unshaped Material spans the row, so the ring
    // stays at the row's bounds even with a card further down its chain.
    await _pumpRingedRow(
      tester,
      const Material(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Card(margin: EdgeInsets.zero, child: SizedBox(height: 24)),
        ),
      ),
      theme: _cardTheme(8),
    );

    expect(
      _ringedRow(tester),
      _ringAround(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, _rowWidth, 40),
          const Radius.circular(12),
        ),
      ),
    );
  });

  testWidgets(
    'a card nested among a row\'s contents is not taken for the row',
    (tester) async {
      // A dense row: a full-width strip whose contents include a small card.
      // That card is a chip inside the row, not the row's surface.
      await _pumpRingedRow(
        tester,
        const SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(child: Text('Tortuga')),
              Card(margin: EdgeInsets.zero, child: SizedBox(width: 40)),
            ],
          ),
        ),
        theme: _cardTheme(8),
      );

      expect(
        _ringedRow(tester),
        _ringAround(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, _rowWidth, 40),
            const Radius.circular(12),
          ),
        ),
      );
    },
  );

  testWidgets('a row\'s header takes clicks but stays outside its ring', (
    tester,
  ) async {
    // An upcoming trip's banner: part of the row, so a click on it moves the
    // cursor there, but the ring still traces the card below it alone.
    useDesktopFocusHighlighting();
    await tester.pumpWidget(
      MaterialApp(
        theme: _cardTheme(12),
        home: Scaffold(
          body: KeyboardListNavigator(
            keys: const ['a'],
            currentKey: null,
            onMove: (_) {},
            child: ListView(
              children: [
                const KeyboardListItem(
                  navigationKey: 'a',
                  header: SizedBox(height: 20, child: Text('banner')),
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: SizedBox(height: 40),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await clickWithMouse(tester, find.text('banner'));
    await tester.pumpAndSettle();

    expect(
      _ringedRow(tester),
      _ringAround(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(16, 24, _rowWidth - 32, 40),
          const Radius.circular(12),
        ),
      ),
    );
  });

  testWidgets('the ring repaints in a new colour while it shows', (
    tester,
  ) async {
    const card = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(margin: EdgeInsets.zero, child: SizedBox(height: 40)),
    );
    await _pumpRingedRow(
      tester,
      card,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(primary: Colors.red),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(primary: Colors.green),
        ),
        home: Scaffold(
          body: KeyboardListNavigator(
            keys: const ['a'],
            currentKey: null,
            onMove: (_) {},
            child: ListView(
              children: [
                const KeyboardListItem(
                  navigationKey: 'a',
                  child: KeyedSubtree(key: ValueKey('row-a'), child: card),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _ringedRow(tester),
      paints..something(
        (method, arguments) =>
            method == #drawDRRect &&
            (arguments[2] as Paint).color.toARGB32() == Colors.green.toARGB32(),
      ),
    );
  });

  testWidgets('outside a navigator a row shows its header and contents', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KeyboardListItem(
            navigationKey: 'a',
            header: Text('banner'),
            child: Text('card'),
          ),
        ),
      ),
    );

    expect(find.byType(KeyboardListFocusRing), findsNothing);
    expect(
      tester.getTopLeft(find.text('banner')).dy,
      lessThan(tester.getTopLeft(find.text('card')).dy),
    );
  });
}
