import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'entity_table_test_harness.dart';

/// Cell-level hooks for the table editor (#3422): a cell tap, a cell builder
/// and a cell background, each leaving the list views untouched when unset.
void main() {
  const a = TestEntity('r1', 'Alpha', 1);
  const b = TestEntity('r2', 'Bravo', 2);

  testWidgets('onCellTap receives the tapped entity and field', (tester) async {
    final cells = <(String, TestField)>[];
    final rows = <String>[];
    await tester.pumpWidget(
      buildTestTable(
        entities: const [a, b],
        onEntityTap: rows.add,
        onCellTap: (e, f) => cells.add((e.id, f)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('2'));
    await tester.pump();

    expect(cells, [('r2', TestField.entityCount)]);
    expect(rows, isEmpty);
  });

  testWidgets('cellBuilder replaces the text of the cell it returns a widget '
      'for', (tester) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: const [a, b],
        cellBuilder: (context, e, f, formatted) =>
            e.id == 'r1' && f == TestField.entityCount
            ? Text('edit:$formatted', key: const Key('edit'))
            : null,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('edit')), findsOneWidget);
    expect(find.text('edit:1'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('cellBackground paints a ColoredBox with the colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: const [a, b],
        cellBackground: (e, f) =>
            e.id == 'r2' && f == TestField.entityName ? Colors.amber : null,
      ),
    );
    await tester.pump();

    final painted = find.ancestor(
      of: find.text('Bravo'),
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == Colors.amber,
      ),
    );
    expect(painted, findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Alpha'),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == Colors.amber,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('without the hooks a cell tap still calls onEntityTap', (
    tester,
  ) async {
    final rows = <String>[];
    await tester.pumpWidget(
      buildTestTable(entities: const [a, b], onEntityTap: rows.add),
    );
    await tester.pump();

    await tester.tap(find.text('Bravo'));
    await tester.pump();

    expect(rows, ['r2']);
  });
}
