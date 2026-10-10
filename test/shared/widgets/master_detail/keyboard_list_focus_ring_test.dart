import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// The ring a 2px inside border paints around [rrect].
PaintPattern _ringAround(RRect rrect) =>
    paints..drrect(outer: rrect, inner: rrect.deflate(2));

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
    // The card paints its own outline first; the ring goes over it.
    expect(
      _ringedRow(tester),
      paints
        ..drrect()
        ..drrect(outer: ring, inner: ring.deflate(2)),
    );
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
}
