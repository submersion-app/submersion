import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_menu.dart';

import 'entity_table_test_harness.dart';

/// Header and cell context menus on every table (#2984).
void main() {
  const rows = [TestEntity('a', 'Alpha', 1), TestEntity('b', 'Beta', 2)];

  Future<void> rightClick(WidgetTester tester, Finder target) async {
    await tester.tap(target, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  testWidgets('right-click on a header offers Hide column', (tester) async {
    TestField? hidden;
    await tester.pumpWidget(
      buildTestTable(entities: rows, onHideColumn: (f) => hidden = f),
    );
    await rightClick(tester, find.text('Count'));
    await tester.tap(find.text('Hide column'));
    await tester.pumpAndSettle();
    expect(hidden, TestField.entityCount);
  });

  testWidgets('long-press on a header opens the same menu', (tester) async {
    await tester.pumpWidget(
      buildTestTable(entities: rows, onHideColumn: (_) {}),
    );
    await tester.longPress(find.text('Count'));
    await tester.pumpAndSettle();
    expect(find.text('Hide column'), findsOneWidget);
  });

  testWidgets('Hide column is disabled on the last column', (tester) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: rows,
        config: testSingleColumnConfig,
        onHideColumn: (_) {},
      ),
    );
    await rightClick(tester, find.text('Name'));
    final item = tester.widget<PopupMenuItem<EntityTableMenuAction>>(
      find.ancestor(
        of: find.text('Hide column'),
        matching: find.byType(PopupMenuItem<EntityTableMenuAction>),
      ),
    );
    expect(item.enabled, isFalse);
  });

  testWidgets('header builder items come before Hide column', (tester) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: rows,
        onHideColumn: (_) {},
        headerMenuBuilder: (_, f) => [
          EntityTableMenuAction(label: 'Extra ${f.name}', onSelected: () {}),
        ],
      ),
    );
    await rightClick(tester, find.text('Count'));
    final extra = tester.getTopLeft(find.text('Extra entityCount')).dy;
    final hide = tester.getTopLeft(find.text('Hide column')).dy;
    expect(extra, lessThan(hide));
  });

  testWidgets('a header with no menu opens nothing on right-click', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestTable(entities: rows));
    await rightClick(tester, find.text('Count'));
    expect(find.byType(PopupMenuItem<EntityTableMenuAction>), findsNothing);
  });

  testWidgets('a cell menu opens on right-click and on long-press', (
    tester,
  ) async {
    final picked = <String>[];
    await tester.pumpWidget(
      buildTestTable(
        entities: rows,
        cellMenuBuilder: (_, e, f) => [
          EntityTableMenuAction(
            label: 'Pick ${e.id}',
            onSelected: () => picked.add(e.id),
          ),
        ],
      ),
    );
    await rightClick(tester, find.text('Beta'));
    await tester.tap(find.text('Pick b'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick a'));
    await tester.pumpAndSettle();
    expect(picked, ['b', 'a']);
  });

  testWidgets('without a cell builder no row registers a long-press', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestTable(entities: rows));
    final detectors = tester.widgetList<RawGestureDetector>(
      find.byType(RawGestureDetector),
    );
    expect(detectors, isNotEmpty);
    for (final d in detectors) {
      expect(d.gestures.containsKey(LongPressGestureRecognizer), isFalse);
    }
  });

  testWidgets('a filtered column shows the indicator', (tester) async {
    await tester.pumpWidget(
      buildTestTable(
        entities: rows,
        isColumnFiltered: (f) => f == TestField.entityCount,
      ),
    );
    expect(
      find.byKey(const ValueKey('entity-table-filtered-entityCount')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('entity-table-filtered-entityName')),
      findsNothing,
    );
  });
}
