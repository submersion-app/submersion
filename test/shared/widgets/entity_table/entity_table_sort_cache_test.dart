import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_header_cell.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

import 'entity_table_test_harness.dart';

/// Counts extractions per field, so a test can tell a sort of every row from
/// the few cells on screen.
class _CountingAdapter extends TestAdapter {
  final _counts = <TestField, int>{};

  int countOf(TestField field) => _counts[field] ?? 0;

  @override
  dynamic extractValue(TestField field, TestEntity entity) {
    _counts[field] = countOf(field) + 1;
    return super.extractValue(field, entity);
  }
}

/// Orders counts backwards, as a change to what an adapter reads could.
class _NegatingAdapter extends _CountingAdapter {
  @override
  dynamic extractValue(TestField field, TestEntity entity) {
    final value = super.extractValue(field, entity);
    return value is int ? -value : value;
  }
}

/// Holds a value that is not Comparable, so a sort reads [formatValue].
class _FormattedAdapter extends _CountingAdapter {
  int formats = 0;

  @override
  dynamic extractValue(TestField field, TestEntity entity) =>
      field == TestField.entityCount
      ? [entity.count]
      : super.extractValue(field, entity);

  @override
  String formatValue(TestField field, dynamic value, UnitFormatter units) {
    if (value is! List) return super.formatValue(field, value, units);
    formats++;
    final count = value.single as int;
    return units.settings.depthUnit == DepthUnit.feet
        ? '${9 - count}'
        : '$count';
  }
}

const _rowCount = 1000;

/// Sorted on a field with no column: cells never read it, so every extraction
/// of it belongs to a sort.
final _sortedByHiddenCount = EntityTableViewConfig<TestField>(
  columns: [
    EntityTableColumnConfig(field: TestField.entityName, isPinned: true),
  ],
  sortField: TestField.entityCount,
);

final _rows = [
  for (var i = 0; i < _rowCount; i++)
    TestEntity('id-$i', 'row-$i', (i * 7919) % _rowCount),
];

/// Top-to-bottom names on screen, read from the pinned column.
List<String> _namesOnScreen(WidgetTester tester, Iterable<String> names) {
  final shown = [
    for (final name in names)
      if (find.text(name).evaluate().isNotEmpty) name,
  ];
  shown.sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return shown;
}

void main() {
  group('EntityTableView sort reuse (#3850)', () {
    testWidgets('sorting reads each row once, not once per comparison', (
      tester,
    ) async {
      final adapter = _CountingAdapter();
      await tester.pumpWidget(
        buildTestTable(
          entities: _rows,
          adapter: adapter,
          config: _sortedByHiddenCount,
        ),
      );

      expect(adapter.countOf(TestField.entityCount), _rowCount);
    });

    testWidgets('sorting formats each row once, not once per comparison', (
      tester,
    ) async {
      final adapter = _FormattedAdapter();
      await tester.pumpWidget(
        buildTestTable(
          entities: _rows,
          adapter: adapter,
          config: _sortedByHiddenCount,
        ),
      );

      expect(adapter.formats, _rowCount);
    });

    testWidgets('hovering across rows does not sort again', (tester) async {
      final adapter = _CountingAdapter();
      await tester.pumpWidget(
        buildTestTable(
          entities: _rows,
          adapter: adapter,
          config: _sortedByHiddenCount,
        ),
      );
      final sorts = adapter.countOf(TestField.entityCount);
      final cellReads = adapter.countOf(TestField.entityName);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final header = tester.getCenter(find.byType(EntityTableHeaderCell));
      for (var row = 1; row < 8; row++) {
        await mouse.moveTo(header.translate(0, row * kEntityTableRowHeight));
        await tester.pump();
      }

      expect(
        adapter.countOf(TestField.entityName),
        greaterThan(cellReads),
        reason: 'the hover must rebuild the rows for this test to mean much',
      );
      expect(adapter.countOf(TestField.entityCount), sorts);
    });

    testWidgets('dragging a column edge does not sort again', (tester) async {
      final adapter = _CountingAdapter();
      await tester.pumpWidget(
        buildTestTable(
          entities: _rows,
          adapter: adapter,
          config: _sortedByHiddenCount,
        ),
      );
      final sorts = adapter.countOf(TestField.entityCount);
      final header = find.byType(EntityTableHeaderCell);
      final startWidth = tester.getSize(header).width;

      final rect = tester.getRect(header);
      final drag = await tester.startGesture(
        Offset(rect.right - 2, rect.center.dy),
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 5; i++) {
        await drag.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      expect(tester.getSize(header).width, startWidth + 50);
      await drag.up();
      await tester.pump();

      expect(adapter.countOf(TestField.entityCount), sorts);
    });

    testWidgets('a saved column width keeps the sort', (tester) async {
      final adapter = _CountingAdapter();
      Widget table(double width) => buildTestTable(
        entities: _rows,
        adapter: adapter,
        config: EntityTableViewConfig<TestField>(
          columns: [
            EntityTableColumnConfig(
              field: TestField.entityName,
              width: width,
              isPinned: true,
            ),
          ],
          sortField: TestField.entityCount,
        ),
      );
      await tester.pumpWidget(table(150));
      final sorts = adapter.countOf(TestField.entityCount);

      await tester.pumpWidget(table(200));

      expect(tester.getSize(find.byType(EntityTableHeaderCell)).width, 200);
      expect(adapter.countOf(TestField.entityCount), sorts);
    });

    testWidgets('revealing a highlighted row reuses the sort', (tester) async {
      final adapter = _CountingAdapter();
      Widget table(String? highlightedId) => buildTestTable(
        entities: _rows,
        adapter: adapter,
        config: _sortedByHiddenCount,
        highlightedId: highlightedId,
      );
      await tester.pumpWidget(table(null));
      final sorts = adapter.countOf(TestField.entityCount);

      await tester.pumpWidget(table('id-500'));
      await tester.pumpAndSettle();

      expect(find.text('row-500'), findsOneWidget);
      expect(adapter.countOf(TestField.entityCount), sorts);
    });

    testWidgets('edited rows arrive as a new list and are sorted', (
      tester,
    ) async {
      const rows = [TestEntity('a', 'Alpha', 1), TestEntity('b', 'Bravo', 2)];
      Widget table(List<TestEntity> entities) =>
          buildTestTable(entities: entities, config: _sortedByHiddenCount);
      await tester.pumpWidget(table(rows));
      expect(_namesOnScreen(tester, ['Alpha', 'Bravo']), ['Alpha', 'Bravo']);

      await tester.pumpWidget(
        table(const [TestEntity('a', 'Alpha', 3), TestEntity('b', 'Bravo', 2)]),
      );

      expect(_namesOnScreen(tester, ['Alpha', 'Bravo']), ['Bravo', 'Alpha']);
    });

    testWidgets('a new adapter sorts again by what it now reads', (
      tester,
    ) async {
      const rows = [TestEntity('a', 'Alpha', 1), TestEntity('b', 'Bravo', 2)];
      Widget table(TestAdapter adapter) => buildTestTable(
        entities: rows,
        adapter: adapter,
        config: _sortedByHiddenCount,
      );
      await tester.pumpWidget(table(_CountingAdapter()));
      expect(_namesOnScreen(tester, ['Alpha', 'Bravo']), ['Alpha', 'Bravo']);

      await tester.pumpWidget(table(_NegatingAdapter()));

      expect(_namesOnScreen(tester, ['Alpha', 'Bravo']), ['Bravo', 'Alpha']);
    });

    testWidgets('new units sort again when the order reads formatted text', (
      tester,
    ) async {
      const rows = [TestEntity('a', 'Alpha', 1), TestEntity('b', 'Bravo', 2)];
      final adapter = _FormattedAdapter();
      Widget table(AppSettings settings) => buildTestTable(
        entities: rows,
        adapter: adapter,
        config: _sortedByHiddenCount,
        units: UnitFormatter(settings),
      );
      await tester.pumpWidget(table(const AppSettings()));
      expect(_namesOnScreen(tester, ['Alpha', 'Bravo']), ['Alpha', 'Bravo']);

      await tester.pumpWidget(
        table(const AppSettings(depthUnit: DepthUnit.feet)),
      );

      expect(_namesOnScreen(tester, ['Alpha', 'Bravo']), ['Bravo', 'Alpha']);
    });

    testWidgets('a new sort direction or field applies at once', (
      tester,
    ) async {
      const rows = [TestEntity('a', 'Bravo', 1), TestEntity('b', 'Alpha', 2)];
      Widget table(TestField field, {required bool ascending}) =>
          buildTestTable(
            entities: rows,
            config: EntityTableViewConfig<TestField>(
              columns: testTableConfig.columns,
              sortField: field,
              sortAscending: ascending,
            ),
          );
      await tester.pumpWidget(table(TestField.entityCount, ascending: true));
      expect(_namesOnScreen(tester, ['Alpha', 'Bravo']), ['Bravo', 'Alpha']);

      await tester.pumpWidget(table(TestField.entityCount, ascending: false));
      expect(_namesOnScreen(tester, ['Alpha', 'Bravo']), ['Alpha', 'Bravo']);

      await tester.pumpWidget(table(TestField.entityName, ascending: false));
      expect(_namesOnScreen(tester, ['Alpha', 'Bravo']), ['Bravo', 'Alpha']);
    });
  });
}
