import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

import 'entity_table_test_harness.dart';

/// A muted row and a cell trailing widget (#3379, closed dive centers).
void main() {
  const open = TestEntity('a', 'Open Center', 1);
  const closed = TestEntity('b', 'Closed Center', 2);

  Finder mutedAround(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate(
      (w) => w is Opacity && w.opacity == kEntityTableMutedOpacity,
    ),
  );

  testWidgets('only the muted row is greyed', (tester) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: const [open, closed],
        isEntityMuted: (e) => e.id == 'b',
      ),
    );
    await tester.pump();

    expect(mutedAround('Closed Center'), findsOneWidget);
    expect(mutedAround('2'), findsOneWidget);
    expect(mutedAround('Open Center'), findsNothing);
  });

  testWidgets('a cell trailing widget sits in its own cell only', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: const [open, closed],
        cellTrailingBuilder: (e, f) =>
            e.id == 'b' && f == TestField.entityName ? const Text('TAG') : null,
      ),
    );
    await tester.pump();

    expect(find.text('TAG'), findsOneWidget);
    final tagRow = tester.getCenter(find.text('TAG')).dy;
    expect(tester.getCenter(find.text('Closed Center')).dy, tagRow);
  });

  testWidgets('without either callback nothing is muted', (tester) async {
    await tester.pumpWidget(buildTestTable(entities: const [open, closed]));
    await tester.pump();

    expect(mutedAround('Closed Center'), findsNothing);
  });
}
