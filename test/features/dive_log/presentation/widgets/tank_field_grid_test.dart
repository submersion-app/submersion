import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_field_grid.dart';

/// The wrapping field row of the cylinder editor (issue #4962).
void main() {
  group('columnsFor', () {
    int columns(double width, int count) => TankFieldGrid.columnsFor(
      width: width,
      count: count,
      minFieldWidth: 100,
      spacing: 12,
    );

    test('fits as many columns as the width allows, up to the count', () {
      expect(columns(900, 3), 3);
      expect(columns(324, 3), 3);
      expect(columns(323, 3), 2);
      expect(columns(212, 3), 2);
      expect(columns(211, 3), 1);
    });

    test('never fewer than one column, however narrow', () {
      expect(columns(40, 3), 1);
    });

    test('one field, or an unbounded width, keeps every field on a line', () {
      expect(columns(40, 1), 1);
      expect(columns(double.infinity, 3), 3);
    });
  });

  Future<void> pumpGrid(
    WidgetTester tester, {
    required double width,
    required int fields,
    int? slots,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: TankFieldGrid(
              slots: slots,
              minFieldWidth: 100,
              children: [
                for (var i = 0; i < fields; i++)
                  SizedBox(key: ValueKey(i), height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a field that wraps keeps the column width', (tester) async {
    await pumpGrid(tester, width: 300, fields: 3);

    final first = tester.getRect(find.byKey(const ValueKey(0)));
    final second = tester.getRect(find.byKey(const ValueKey(1)));
    final third = tester.getRect(find.byKey(const ValueKey(2)));
    expect(first.width, 144);
    expect(second.left, first.right + 12);
    expect(third.top, first.bottom + 12);
    expect(third.left, first.left);
    expect(third.width, first.width);
  });

  testWidgets('a focused field that changes line when the columns change '
      'keeps its focus and text', (tester) async {
    late StateSetter setOuter;
    var width = 360.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return SizedBox(
                  width: width,
                  child: const TankFieldGrid(
                    minFieldWidth: 100,
                    children: [
                      TextField(key: ValueKey(0)),
                      TextField(key: ValueKey(1)),
                      TextField(key: ValueKey(2)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey(2)));
    await tester.enterText(find.byKey(const ValueKey(2)), '232');
    final top = tester.getRect(find.byKey(const ValueKey(0))).top;
    expect(tester.getRect(find.byKey(const ValueKey(2))).top, top);

    // Narrower, as on a rotation back to portrait: the third field moves
    // to a second line.
    setOuter(() => width = 300);
    await tester.pump();

    expect(tester.getRect(find.byKey(const ValueKey(2))).top, greaterThan(top));
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey(2)),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.focusNode.hasFocus, isTrue);
    expect(field.controller.text, '232');
  });

  testWidgets('slots size a lone field as one column of a fuller row', (
    tester,
  ) async {
    await pumpGrid(tester, width: 600, fields: 1, slots: 3);

    expect(tester.getSize(find.byKey(const ValueKey(0))).width, 192);
  });

  testWidgets('the minimum width grows with the text scale', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: TankFieldGrid(
                minFieldWidth: 100,
                children: [
                  for (var i = 0; i < 2; i++)
                    SizedBox(key: ValueKey(i), height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Two fields of 150 need 312 with the gap, so each takes a line.
    expect(
      tester.getRect(find.byKey(const ValueKey(1))).top,
      greaterThan(tester.getRect(find.byKey(const ValueKey(0))).bottom),
    );
  });
}
