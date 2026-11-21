import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/one_line_overflow_row.dart';

/// Children on one line, as many as fit, then a count of the rest (issue
/// #4825).
void main() {
  Key item(int k) => ValueKey('item_$k');
  Key count(int hidden) => ValueKey('count_$hidden');

  Future<void> pump(
    WidgetTester tester, {
    int items = 3,
    double width = 300,
    double spacing = 0,
    double Function(int k)? itemWidth,
    TextDirection direction = TextDirection.ltr,
    void Function(int k)? onItemTap,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: OneLineOverflowRow(
              spacing: spacing,
              overflowBuilder: (context, hidden) =>
                  SizedBox(key: count(hidden), width: 50, height: 16),
              children: [
                for (var k = 0; k < items; k++)
                  GestureDetector(
                    key: item(k),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onItemTap?.call(k),
                    child: Semantics(
                      label: 'item $k',
                      child: SizedBox(
                        width: itemWidth?.call(k) ?? 100,
                        height: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whether [key]'s child is drawn and laid out on the line.
  bool shown(WidgetTester tester, Key key) =>
      tester.any(find.byKey(key, skipOffstage: true)) &&
      tester.getSize(find.byKey(key)).width > 0 &&
      _painted(tester, key);

  testWidgets('shows every child when they fit, and no count', (tester) async {
    await pump(tester);
    for (var k = 0; k < 3; k++) {
      expect(shown(tester, item(k)), isTrue);
    }
    expect(_painted(tester, count(1)), isFalse);
    expect(tester.getTopLeft(find.byKey(item(2))).dx, 200);
  });

  testWidgets('shows what fits, then the count of the rest', (tester) async {
    await pump(tester, items: 5);
    expect(shown(tester, item(0)), isTrue);
    expect(shown(tester, item(1)), isTrue);
    for (var k = 2; k < 5; k++) {
      expect(_painted(tester, item(k)), isFalse, reason: 'item $k');
    }
    expect(_painted(tester, count(3)), isTrue);
    expect(tester.getTopLeft(find.byKey(count(3))).dx, 200);
    for (final other in [1, 2, 4, 5]) {
      expect(_painted(tester, count(other)), isFalse);
    }
  });

  testWidgets('never grows past one line', (tester) async {
    await pump(tester, items: 40);
    expect(tester.getSize(find.byType(OneLineOverflowRow)).height, 20);
    expect(tester.getSize(find.byType(OneLineOverflowRow)).width, 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a first chip wider than the line leaves only the count', (
    tester,
  ) async {
    await pump(tester, items: 3, itemWidth: (k) => k == 0 ? 400 : 100);
    expect(_painted(tester, item(0)), isFalse);
    expect(_painted(tester, item(1)), isFalse);
    expect(_painted(tester, count(3)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out from the right in a right-to-left direction', (
    tester,
  ) async {
    await pump(tester, items: 5, direction: TextDirection.rtl);
    expect(tester.getTopRight(find.byKey(item(0))).dx, 300);
    expect(tester.getTopRight(find.byKey(item(1))).dx, 200);
    expect(tester.getTopRight(find.byKey(count(3))).dx, 100);
  });

  testWidgets('spacing counts towards what fits', (tester) async {
    await pump(tester, items: 5, spacing: 30);
    expect(_painted(tester, item(0)), isTrue);
    expect(_painted(tester, item(1)), isFalse);
    expect(_painted(tester, count(4)), isTrue);
    expect(tester.getTopLeft(find.byKey(count(4))).dx, 130);
  });

  testWidgets('children of different heights are centred on the line', (
    tester,
  ) async {
    await pump(tester, items: 5);
    // The count is 16 tall on a 20 tall line.
    expect(tester.getTopLeft(find.byKey(count(3))).dy, 2);
  });

  testWidgets('hidden children take no taps and are not announced', (
    tester,
  ) async {
    final tapped = <int>[];
    final semantics = tester.ensureSemantics();
    await pump(tester, items: 5, onItemTap: tapped.add);
    // Where item 2 would be, the count is.
    await tester.tapAt(const Offset(225, 10));
    expect(tapped, isEmpty);
    await tester.tapAt(const Offset(150, 10));
    expect(tapped, [1]);
    expect(find.bySemanticsLabel('item 1'), findsOneWidget);
    expect(find.bySemanticsLabel('item 3'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a screen reader follows the line when it widens', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, items: 5);
    expect(find.bySemanticsLabel('item 3'), findsNothing);
    await pump(tester, items: 5, width: 600);
    expect(find.bySemanticsLabel('item 3'), findsOneWidget);
    await pump(tester, items: 5);
    expect(find.bySemanticsLabel('item 3'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a screen reader follows a child that narrows on the same '
      'line', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, items: 5);
    expect(find.bySemanticsLabel('item 2'), findsNothing);
    // The first child shrinks: one more now fits before the count.
    await pump(tester, items: 5, itemWidth: (k) => k == 0 ? 50 : 100);
    expect(_painted(tester, item(2)), isTrue);
    expect(find.bySemanticsLabel('item 2'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('follows a change of spacing and direction on rebuild', (
    tester,
  ) async {
    await pump(tester, items: 5);
    expect(_painted(tester, item(1)), isTrue);
    await pump(tester, items: 5, spacing: 30);
    expect(_painted(tester, item(1)), isFalse);
    await pump(tester, items: 5, spacing: 30, direction: TextDirection.rtl);
    expect(tester.getTopRight(find.byKey(item(0))).dx, 300);
    // Fewer items: every count past the new end is gone.
    await pump(tester, items: 2, spacing: 30, direction: TextDirection.rtl);
    expect(_painted(tester, item(1)), isTrue);
    expect(find.byKey(count(3)), findsNothing);
  });

  testWidgets('answers its size when a parent asks before laying it out', (
    tester,
  ) async {
    Widget row(int items) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: IntrinsicWidth(
          child: IntrinsicHeight(
            child: OneLineOverflowRow(
              spacing: 10,
              overflowBuilder: (context, hidden) =>
                  SizedBox(key: count(hidden), width: 50, height: 16),
              children: [
                for (var k = 0; k < items; k++)
                  SizedBox(key: item(k), width: 100, height: 20),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(row(3));
    // Its widest is every child with the spacing; its height the tallest.
    expect(
      tester.getSize(find.byType(OneLineOverflowRow)),
      const Size(320, 20),
    );
    final box = tester.renderObject<RenderOneLineOverflow>(
      find.byType(OneLineOverflowRow),
    );
    expect(box.getMinIntrinsicWidth(20), 0);
    expect(box.getMaxIntrinsicWidth(20), 320);
    expect(box.getMinIntrinsicHeight(320), 20);
    expect(
      box.getDryLayout(const BoxConstraints(maxWidth: 260)),
      const Size(260, 20),
    );
    expect(
      box.getDryLayout(const BoxConstraints(maxHeight: 40)),
      const Size(320, 20),
    );
  });

  testWidgets('nothing to show draws nothing', (tester) async {
    await pump(tester, items: 0);
    expect(tester.getSize(find.byType(OneLineOverflowRow)).height, 0);
  });
}

/// Whether the child under [key] is painted: hidden children are laid out
/// but never painted.
bool _painted(WidgetTester tester, Key key) {
  final finder = find.byKey(key);
  if (!tester.any(finder)) return false;
  final box = tester.renderObject<RenderBox>(finder);
  var child = box as RenderObject;
  RenderObject? parent = child.parent;
  while (parent != null) {
    if (parent is RenderOneLineOverflow) {
      return parent.isShown(child as RenderBox);
    }
    child = parent;
    parent = parent.parent;
  }
  return false;
}
