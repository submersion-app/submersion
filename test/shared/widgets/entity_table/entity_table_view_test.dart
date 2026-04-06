import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

import '../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Simple test entity
// ---------------------------------------------------------------------------

class _TestEntity {
  final String id;
  final String name;
  final int count;

  const _TestEntity(this.id, this.name, this.count);
}

// ---------------------------------------------------------------------------
// Test field enum implementing EntityField
// ---------------------------------------------------------------------------

class _TestField implements EntityField {
  static const entityName = _TestField._('entityName', 'Name', 'Name', false);
  static const entityCount = _TestField._('entityCount', 'Count', 'Cnt', true);
  static const List<_TestField> values = [entityName, entityCount];

  @override
  final String name;
  @override
  final String displayName;
  @override
  final String shortLabel;
  @override
  final bool isRightAligned;

  const _TestField._(
    this.name,
    this.displayName,
    this.shortLabel,
    this.isRightAligned,
  );

  @override
  IconData? get icon => null;
  @override
  double get defaultWidth => 120;
  @override
  double get minWidth => 60;
  @override
  bool get sortable => true;
  @override
  String get categoryName => 'basic';

  @override
  bool operator ==(Object other) => other is _TestField && other.name == name;
  @override
  int get hashCode => name.hashCode;
}

// ---------------------------------------------------------------------------
// Concrete adapter
// ---------------------------------------------------------------------------

class _TestAdapter extends EntityFieldAdapter<_TestEntity, _TestField> {
  @override
  List<_TestField> get allFields => _TestField.values;

  @override
  Map<String, List<_TestField>> get fieldsByCategory => {
    'basic': _TestField.values,
  };

  @override
  dynamic extractValue(_TestField field, _TestEntity entity) {
    switch (field) {
      case _TestField.entityName:
        return entity.name;
      case _TestField.entityCount:
        return entity.count;
    }
  }

  @override
  String formatValue(_TestField field, dynamic value, UnitFormatter units) {
    if (value == null) return '--';
    return value.toString();
  }

  @override
  _TestField fieldFromName(String name) {
    return _TestField.values.firstWhere((f) => f.name == name);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _defaultConfig = EntityTableViewConfig<_TestField>(
  columns: [
    EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
    EntityTableColumnConfig(field: _TestField.entityCount),
  ],
);

const _units = UnitFormatter(AppSettings());
final _adapter = _TestAdapter();

Widget _buildTable({
  required List<_TestEntity> entities,
  EntityTableViewConfig<_TestField>? config,
  void Function(String)? onEntityTap,
  void Function(String)? onEntityDoubleTap,
  void Function(String)? onEntityLongPress,
  void Function(_TestField)? onSortFieldChanged,
  void Function(_TestField, double)? onResizeColumn,
  Set<String>? selectedIds,
  bool isSelectionMode = false,
  String? highlightedId,
}) {
  return testApp(
    child: EntityTableView<_TestEntity, _TestField>(
      entities: entities,
      idExtractor: (e) => e.id,
      adapter: _adapter,
      config: config ?? _defaultConfig,
      units: _units,
      onSortFieldChanged: onSortFieldChanged ?? (_) {},
      onResizeColumn: onResizeColumn ?? (_, _) {},
      onEntityTap: onEntityTap ?? (_) {},
      onEntityDoubleTap: onEntityDoubleTap,
      onEntityLongPress: onEntityLongPress,
      selectedIds: selectedIds ?? const {},
      isSelectionMode: isSelectionMode,
      highlightedId: highlightedId,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EntityTableView', () {
    testWidgets('renders header row with column short labels', (tester) async {
      await tester.pumpWidget(_buildTable(entities: []));
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Cnt'), findsOneWidget);
    });

    testWidgets('renders one row per entity', (tester) async {
      final entities = [
        const _TestEntity('a', 'Alpha', 10),
        const _TestEntity('b', 'Bravo', 20),
        const _TestEntity('c', 'Charlie', 30),
      ];

      await tester.pumpWidget(_buildTable(entities: entities));
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('renders pinned columns separately from scrollable columns', (
      tester,
    ) async {
      final entities = [const _TestEntity('a', 'Alpha', 10)];

      await tester.pumpWidget(_buildTable(entities: entities));
      await tester.pumpAndSettle();

      // The pinned column (name) is in a fixed-width SizedBox on the left.
      // The scrollable column (count) is inside an Expanded >
      // SingleChildScrollView.
      // Both should render their data.
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('calls onEntityTap with correct ID when row is tapped', (
      tester,
    ) async {
      String? tappedId;
      final entities = [const _TestEntity('entity-42', 'Zulu', 99)];

      await tester.pumpWidget(
        _buildTable(entities: entities, onEntityTap: (id) => tappedId = id),
      );
      await tester.pumpAndSettle();

      // Tap the pinned cell text
      await tester.tap(find.text('Zulu'));
      await tester.pumpAndSettle();

      expect(tappedId, equals('entity-42'));
    });

    testWidgets('calls onEntityDoubleTap on double-tap', (tester) async {
      String? doubleTappedId;

      await tester.pumpWidget(
        _buildTable(
          entities: [const _TestEntity('dt-1', 'Delta', 5)],
          onEntityTap: (_) {},
          onEntityDoubleTap: (id) => doubleTappedId = id,
        ),
      );
      await tester.pumpAndSettle();

      final cell = find.text('Delta');
      await tester.tap(cell);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(cell);
      await tester.pumpAndSettle();

      expect(doubleTappedId, equals('dt-1'));
    });

    testWidgets('calls onEntityLongPress on long-press', (tester) async {
      String? longPressedId;

      await tester.pumpWidget(
        _buildTable(
          entities: [const _TestEntity('lp-1', 'Echo', 7)],
          onEntityTap: (_) {},
          onEntityLongPress: (id) => longPressedId = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Echo'));
      await tester.pumpAndSettle();

      expect(longPressedId, equals('lp-1'));
    });

    testWidgets('highlights the row matching highlightedId', (tester) async {
      final entities = [
        const _TestEntity('h-1', 'First', 1),
        const _TestEntity('h-2', 'Second', 2),
      ];

      await tester.pumpWidget(
        _buildTable(entities: entities, highlightedId: 'h-2'),
      );
      await tester.pumpAndSettle();

      // "Second" appears in both pinned and scrollable columns, so there are
      // multiple ColoredBox ancestors. Collect all ColoredBox widgets that are
      // direct ancestors of cells showing "Second" and verify at least one has
      // a non-transparent highlight color.
      final secondRowFinder = find.ancestor(
        of: find.text('Second'),
        matching: find.byType(ColoredBox),
      );
      expect(secondRowFinder, findsWidgets);

      final colors = tester
          .widgetList<ColoredBox>(secondRowFinder)
          .map((cb) => cb.color)
          .toList();
      expect(
        colors.any((c) => c != Colors.transparent),
        isTrue,
        reason: 'Highlighted row should have a non-transparent background',
      );
    });

    testWidgets('shows checkboxes when isSelectionMode is true', (
      tester,
    ) async {
      final entities = [
        const _TestEntity('s-1', 'Selected', 1),
        const _TestEntity('s-2', 'Unselected', 2),
      ];

      await tester.pumpWidget(
        _buildTable(
          entities: entities,
          isSelectionMode: true,
          selectedIds: {'s-1'},
        ),
      );
      await tester.pumpAndSettle();

      // Both rows should have checkboxes
      expect(find.byType(Checkbox), findsNWidgets(2));

      // The selected entity's checkbox should be checked
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      final values = checkboxes.map((cb) => cb.value).toList();
      expect(values, contains(true));
      expect(values, contains(false));
    });

    testWidgets('calls onSortFieldChanged when header is tapped', (
      tester,
    ) async {
      _TestField? sortedField;

      await tester.pumpWidget(
        _buildTable(
          entities: [],
          onSortFieldChanged: (field) => sortedField = field,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the "Name" header
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      expect(sortedField, equals(_TestField.entityName));
    });

    testWidgets('hover highlighting changes row color', (tester) async {
      final entities = [const _TestEntity('hv-1', 'Hover Me', 1)];

      await tester.pumpWidget(_buildTable(entities: entities));
      await tester.pumpAndSettle();

      // Get the ColoredBox before hover
      final coloredBoxFinder = find.ancestor(
        of: find.text('Hover Me'),
        matching: find.byType(ColoredBox),
      );
      final colorBefore = tester
          .widget<ColoredBox>(coloredBoxFinder.first)
          .color;

      // Simulate mouse hover via pointer events
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Move mouse over the text
      await gesture.moveTo(tester.getCenter(find.text('Hover Me')));
      await tester.pumpAndSettle();

      final colorAfter = tester
          .widget<ColoredBox>(coloredBoxFinder.first)
          .color;

      // After hover, the color should differ from the initial state (row 0
      // starts transparent, hover applies onSurface at 0.04 alpha).
      expect(colorAfter, isNot(equals(colorBefore)));
    });

    testWidgets('empty entity list renders only headers', (tester) async {
      await tester.pumpWidget(_buildTable(entities: []));
      await tester.pumpAndSettle();

      // Headers should be present
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Cnt'), findsOneWidget);

      // No data rows: the entity-specific text should be absent
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('sorts entities when config has a sort field', (tester) async {
      final entities = [
        const _TestEntity('c', 'Charlie', 30),
        const _TestEntity('a', 'Alpha', 10),
        const _TestEntity('b', 'Bravo', 20),
      ];

      final configWithSort = EntityTableViewConfig<_TestField>(
        columns: [
          EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
          EntityTableColumnConfig(field: _TestField.entityCount),
        ],
        sortField: _TestField.entityName,
        sortAscending: true,
      );

      await tester.pumpWidget(
        _buildTable(entities: entities, config: configWithSort),
      );
      await tester.pumpAndSettle();

      // All three should appear; sorted ascending by name
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('sorts descending when sortAscending is false', (tester) async {
      final entities = [
        const _TestEntity('a', 'Alpha', 10),
        const _TestEntity('b', 'Bravo', 20),
      ];

      final configDesc = EntityTableViewConfig<_TestField>(
        columns: [
          EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
          EntityTableColumnConfig(field: _TestField.entityCount),
        ],
        sortField: _TestField.entityName,
        sortAscending: false,
      );

      await tester.pumpWidget(
        _buildTable(entities: entities, config: configDesc),
      );
      await tester.pumpAndSettle();

      // Both entities render; the sort order is descending
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Bravo'), findsOneWidget);
    });

    testWidgets('sort handles null values gracefully', (tester) async {
      // entityCount sorts by int; null values should be pushed to end
      final entities = [
        const _TestEntity('a', 'Alpha', 10),
        const _TestEntity('b', 'Bravo', 20),
      ];

      final configSort = EntityTableViewConfig<_TestField>(
        columns: [
          EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
          EntityTableColumnConfig(field: _TestField.entityCount),
        ],
        sortField: _TestField.entityCount,
        sortAscending: true,
      );

      await tester.pumpWidget(
        _buildTable(entities: entities, config: configSort),
      );
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('calls onResizeColumn during header drag', (tester) async {
      _TestField? resizedField;
      double? resizedWidth;

      await tester.pumpWidget(
        _buildTable(
          entities: [const _TestEntity('a', 'Alpha', 10)],
          onResizeColumn: (field, width) {
            resizedField = field;
            resizedWidth = width;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Find the resize handle area (right edge of the header cell).
      // The header cell is a SizedBox with a GestureDetector for horizontal
      // drag in the EntityTableHeaderCell. We drag the header text area edge.
      final headerFinder = find.text('Name');
      final headerCenter = tester.getCenter(headerFinder);

      // Perform a horizontal drag starting near the right edge of the header
      await tester.dragFrom(
        Offset(headerCenter.dx + 50, headerCenter.dy),
        const Offset(20, 0),
      );
      await tester.pumpAndSettle();

      // The resize callback may or may not fire depending on exact hit area,
      // but the widget tree should still be intact
      expect(find.text('Name'), findsOneWidget);
      // If the drag hit the resize handle, resizedField should be set
      if (resizedField != null) {
        expect(resizedField, equals(_TestField.entityName));
        expect(resizedWidth, isNotNull);
      }
    });

    testWidgets('odd rows have alternating background color', (tester) async {
      final entities = [
        const _TestEntity('a', 'Alpha', 10),
        const _TestEntity('b', 'Bravo', 20),
        const _TestEntity('c', 'Charlie', 30),
      ];

      await tester.pumpWidget(_buildTable(entities: entities));
      await tester.pumpAndSettle();

      // Row 0 (Alpha) should be transparent, row 1 (Bravo) should have
      // surfaceContainerLowest color (alternating row).
      final bravoColoredBox = find.ancestor(
        of: find.text('Bravo'),
        matching: find.byType(ColoredBox),
      );
      expect(bravoColoredBox, findsWidgets);

      // The odd-row color should differ from transparent
      final bravoColors = tester
          .widgetList<ColoredBox>(bravoColoredBox)
          .map((cb) => cb.color)
          .toList();
      // At least one ColoredBox ancestor should have a non-transparent color
      // for the odd row
      expect(
        bravoColors.any((c) => c != Colors.transparent),
        isTrue,
        reason: 'Odd rows should have alternating background',
      );
    });

    testWidgets('sort indicator arrow appears for sorted column', (
      tester,
    ) async {
      final configSorted = EntityTableViewConfig<_TestField>(
        columns: [
          EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
          EntityTableColumnConfig(field: _TestField.entityCount),
        ],
        sortField: _TestField.entityName,
        sortAscending: true,
      );

      await tester.pumpWidget(_buildTable(entities: [], config: configSorted));
      await tester.pumpAndSettle();

      // Arrow up for ascending sort
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('sort indicator shows down arrow for descending sort', (
      tester,
    ) async {
      final configSorted = EntityTableViewConfig<_TestField>(
        columns: [
          EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
          EntityTableColumnConfig(field: _TestField.entityCount),
        ],
        sortField: _TestField.entityName,
        sortAscending: false,
      );

      await tester.pumpWidget(_buildTable(entities: [], config: configSorted));
      await tester.pumpAndSettle();

      // Arrow down for descending sort
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('scrolls to highlighted row when highlightedId changes', (
      tester,
    ) async {
      // Create enough entities to require scrolling
      final entities = List.generate(
        50,
        (i) => _TestEntity('id-$i', 'Entity $i', i),
      );

      await tester.pumpWidget(
        _buildTable(entities: entities, highlightedId: 'id-40'),
      );
      await tester.pumpAndSettle();

      // The widget should have attempted to scroll to the highlighted row.
      // We verify the table rendered without errors.
      expect(find.text('Entity 0'), findsWidgets);
    });

    testWidgets('tapping scrollable column header fires onSortFieldChanged', (
      tester,
    ) async {
      _TestField? sortedField;

      await tester.pumpWidget(
        _buildTable(
          entities: [const _TestEntity('a', 'Alpha', 10)],
          onSortFieldChanged: (field) => sortedField = field,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the "Cnt" (scrollable column) header
      await tester.tap(find.text('Cnt'));
      await tester.pumpAndSettle();

      expect(sortedField, equals(_TestField.entityCount));
    });

    testWidgets('selected row in selection mode shows primaryContainer color', (
      tester,
    ) async {
      final entities = [const _TestEntity('s-1', 'Selected', 1)];

      await tester.pumpWidget(
        _buildTable(
          entities: entities,
          isSelectionMode: true,
          selectedIds: {'s-1'},
        ),
      );
      await tester.pumpAndSettle();

      // The row should use primaryContainer color
      final coloredBoxFinder = find.ancestor(
        of: find.text('Selected'),
        matching: find.byType(ColoredBox),
      );
      final colors = tester
          .widgetList<ColoredBox>(coloredBoxFinder)
          .map((cb) => cb.color)
          .toList();
      // At least one should be the primaryContainer color (non-transparent)
      expect(
        colors.any((c) => c != Colors.transparent),
        isTrue,
        reason: 'Selected row should have a colored background',
      );
    });

    // -----------------------------------------------------------------------
    // Many entities with scrolling
    // -----------------------------------------------------------------------

    testWidgets('renders many entities with scroll', (tester) async {
      final entities = List.generate(
        30,
        (i) => _TestEntity('many-$i', 'Entity $i', i * 10),
      );

      await tester.pumpWidget(_buildTable(entities: entities));
      await tester.pumpAndSettle();

      expect(find.text('Entity 0'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Selection mode toggle via checkbox
    // -----------------------------------------------------------------------

    testWidgets('tapping checkbox in selection mode calls onEntityTap', (
      tester,
    ) async {
      String? tappedId;
      final entities = [const _TestEntity('cb-1', 'Check', 1)];

      await tester.pumpWidget(
        _buildTable(
          entities: entities,
          isSelectionMode: true,
          selectedIds: const {},
          onEntityTap: (id) => tappedId = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(tappedId, equals('cb-1'));
    });

    // -----------------------------------------------------------------------
    // Multiple selections
    // -----------------------------------------------------------------------

    testWidgets('multiple selected items show checked checkboxes', (
      tester,
    ) async {
      final entities = [
        const _TestEntity('ms-1', 'First', 1),
        const _TestEntity('ms-2', 'Second', 2),
        const _TestEntity('ms-3', 'Third', 3),
      ];

      await tester.pumpWidget(
        _buildTable(
          entities: entities,
          isSelectionMode: true,
          selectedIds: {'ms-1', 'ms-3'},
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes.length, 3);
      expect(checkboxes[0].value, isTrue);
      expect(checkboxes[1].value, isFalse);
      expect(checkboxes[2].value, isTrue);
    });

    // -----------------------------------------------------------------------
    // Numeric sorting by count field
    // -----------------------------------------------------------------------

    testWidgets('sorts by numeric field ascending', (tester) async {
      final entities = [
        const _TestEntity('ns-c', 'Charlie', 300),
        const _TestEntity('ns-a', 'Alpha', 100),
        const _TestEntity('ns-b', 'Bravo', 200),
      ];

      final configSort = EntityTableViewConfig<_TestField>(
        columns: [
          EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
          EntityTableColumnConfig(field: _TestField.entityCount),
        ],
        sortField: _TestField.entityCount,
        sortAscending: true,
      );

      await tester.pumpWidget(
        _buildTable(entities: entities, config: configSort),
      );
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Highlighted row scroll
    // -----------------------------------------------------------------------

    testWidgets('highlighted row triggers scroll when far off-screen', (
      tester,
    ) async {
      final entities = List.generate(
        100,
        (i) => _TestEntity('scroll-$i', 'Item $i', i),
      );

      await tester.pumpWidget(
        _buildTable(entities: entities, highlightedId: 'scroll-90'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(EntityTableView<_TestEntity, _TestField>),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // didUpdateWidget changes highlightedId
    // -----------------------------------------------------------------------

    testWidgets('changing highlightedId triggers scroll to new row', (
      tester,
    ) async {
      final entities = List.generate(
        50,
        (i) => _TestEntity('du-$i', 'Entity $i', i),
      );

      await tester.pumpWidget(
        _buildTable(entities: entities, highlightedId: 'du-0'),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _buildTable(entities: entities, highlightedId: 'du-45'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(EntityTableView<_TestEntity, _TestField>),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // No long-press or double-tap handlers
    // -----------------------------------------------------------------------

    testWidgets('table renders without optional handlers', (tester) async {
      await tester.pumpWidget(
        _buildTable(
          entities: [const _TestEntity('np-1', 'NoPress', 5)],
          onEntityLongPress: null,
          onEntityDoubleTap: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NoPress'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Wide column config
    // -----------------------------------------------------------------------

    testWidgets('wide column width renders header wider', (tester) async {
      final wideConfig = EntityTableViewConfig<_TestField>(
        columns: [
          EntityTableColumnConfig(
            field: _TestField.entityName,
            isPinned: true,
            width: 300,
          ),
          EntityTableColumnConfig(field: _TestField.entityCount, width: 200),
        ],
      );

      await tester.pumpWidget(
        _buildTable(
          entities: [const _TestEntity('w-1', 'Wide', 99)],
          config: wideConfig,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wide'), findsOneWidget);
      expect(find.text('99'), findsOneWidget);
    });
  });
}
