import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';
import 'package:submersion/shared/models/entity_table_config.dart';

import 'entity_table_test_harness.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import '../../../helpers/test_app.dart';

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

  testWidgets('a trailing tag in a narrow column shrinks instead of '
      'overflowing', (tester) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: const [closed],
        config: EntityTableViewConfig<TestField>(
          columns: [
            EntityTableColumnConfig(
              field: TestField.entityName,
              isPinned: true,
              width: 60,
            ),
          ],
        ),
        cellTrailingBuilder: (e, f) => const Text(
          'Geschlossen geschlossen',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a trailing widget keeps a right-aligned cell on the right', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: const [closed],
        cellTrailingBuilder: (e, f) =>
            f == TestField.entityCount ? const Text('T') : null,
      ),
    );
    await tester.pump();

    final tag = tester.getRect(find.text('T'));
    final count = tester.getRect(find.text('2'));
    final header = tester.getRect(find.text('Count'));
    // Both sit in the right half of the count column.
    expect(count.left, greaterThan(header.center.dx - 60));
    expect(tag.right, greaterThan(count.right));
    expect(tag.right, closeTo(header.right + 8, 40));
  });

  testWidgets('a muted row greys its leading widget too', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: EntityTableView<TestEntity, TestField>(
          entities: const [open, closed],
          idExtractor: (e) => e.id,
          adapter: TestAdapter(),
          config: testTableConfig,
          units: const UnitFormatter(AppSettings()),
          onSortFieldChanged: (_) {},
          onResizeColumn: (_, _) {},
          onEntityTap: (_) {},
          isEntityMuted: (e) => e.id == 'b',
          leadingBuilder: (e) => Text('lead-${e.id}'),
        ),
      ),
    );
    await tester.pump();

    expect(mutedAround('lead-b'), findsOneWidget);
    expect(mutedAround('lead-a'), findsNothing);
  });
}
