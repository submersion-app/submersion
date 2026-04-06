import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_table_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestTableConfigNotifier extends TableViewConfigNotifier {
  _TestTableConfigNotifier(TableViewConfig config) {
    state = config;
  }
}

final _testConfig = TableViewConfig(
  columns: [
    TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
    TableColumnConfig(field: DiveField.siteName, isPinned: true),
    TableColumnConfig(field: DiveField.dateTime),
    TableColumnConfig(field: DiveField.maxDepth),
    TableColumnConfig(field: DiveField.bottomTime),
  ],
);

Dive _makeDive({
  required String id,
  int? diveNumber,
  double? maxDepth,
  Duration? bottomTime,
}) {
  return Dive(
    id: id,
    dateTime: DateTime(2024, 6, 1),
    diveNumber: diveNumber,
    maxDepth: maxDepth,
    bottomTime: bottomTime,
  );
}

Widget _buildTable({
  required List<Dive> dives,
  void Function(String)? onDiveTap,
  void Function(String)? onDiveLongPress,
  void Function(String)? onDiveDoubleTap,
  Set<String>? selectedIds,
  bool isSelectionMode = false,
  TableViewConfig? config,
}) {
  return testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      tableViewConfigProvider.overrideWith(
        (ref) => _TestTableConfigNotifier(config ?? _testConfig),
      ),
    ],
    child: DiveTableView(
      dives: dives,
      onDiveTap: onDiveTap ?? (_) {},
      onDiveLongPress: onDiveLongPress,
      onDiveDoubleTap: onDiveDoubleTap,
      selectedIds: selectedIds ?? const {},
      isSelectionMode: isSelectionMode,
    ),
  );
}

void main() {
  group('DiveTableView', () {
    testWidgets('renders header row with column names from config', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTable(dives: []));
      await tester.pumpAndSettle();

      // Verify pinned column headers
      expect(find.text('#'), findsOneWidget);
      expect(find.text('Site'), findsOneWidget);

      // Verify scrollable column headers
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Max D'), findsOneWidget);
      expect(find.text('BT'), findsOneWidget);
    });

    testWidgets('renders one row per dive', (tester) async {
      final dives = [
        _makeDive(id: 'd1', diveNumber: 1, maxDepth: 20.0),
        _makeDive(id: 'd2', diveNumber: 2, maxDepth: 30.0),
        _makeDive(id: 'd3', diveNumber: 3, maxDepth: 15.0),
      ];

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      // Each dive number should appear as formatted text
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
    });

    testWidgets('tapping a row calls onDiveTap with the correct dive ID', (
      tester,
    ) async {
      String? tappedId;
      final dives = [_makeDive(id: 'dive-abc', diveNumber: 42, maxDepth: 25.0)];

      await tester.pumpWidget(
        _buildTable(dives: dives, onDiveTap: (id) => tappedId = id),
      );
      await tester.pumpAndSettle();

      // Tap on the dive number cell in the pinned column
      await tester.tap(find.text('#42'));
      await tester.pumpAndSettle();

      expect(tappedId, equals('dive-abc'));
    });

    testWidgets('fires onDiveDoubleTap on double-tap', (tester) async {
      String? doubleTappedId;
      await tester.pumpWidget(
        _buildTable(
          dives: [_makeDive(id: 'a', diveNumber: 1)],
          onDiveTap: (_) {},
          onDiveDoubleTap: (id) => doubleTappedId = id,
        ),
      );
      await tester.pump();

      // Double-tap on a row cell
      final cell = find.text('#1');
      await tester.tap(cell);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(cell);
      await tester.pumpAndSettle();

      expect(doubleTappedId, 'a');
    });

    testWidgets('fires onDiveLongPress on long press', (tester) async {
      String? longPressedId;
      await tester.pumpWidget(
        _buildTable(
          dives: [_makeDive(id: 'lp-1', diveNumber: 7)],
          onDiveTap: (_) {},
          onDiveLongPress: (id) => longPressedId = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('#7'));
      await tester.pumpAndSettle();

      expect(longPressedId, 'lp-1');
    });

    testWidgets('selection mode shows checkboxes', (tester) async {
      final dives = [
        _makeDive(id: 's1', diveNumber: 10),
        _makeDive(id: 's2', diveNumber: 11),
      ];

      await tester.pumpWidget(
        _buildTable(dives: dives, isSelectionMode: true, selectedIds: {'s1'}),
      );
      await tester.pumpAndSettle();

      // Should find Checkbox widgets for each row
      expect(find.byType(Checkbox), findsNWidgets(2));
    });

    testWidgets('selected row checkbox is checked', (tester) async {
      final dives = [
        _makeDive(id: 'sel-1', diveNumber: 20),
        _makeDive(id: 'sel-2', diveNumber: 21),
      ];

      await tester.pumpWidget(
        _buildTable(
          dives: dives,
          isSelectionMode: true,
          selectedIds: {'sel-1'},
        ),
      );
      await tester.pumpAndSettle();

      // First checkbox should be checked, second unchecked
      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes[0].value, isTrue);
      expect(checkboxes[1].value, isFalse);
    });

    testWidgets('maxDepth column shows formatted depth value', (tester) async {
      final dives = [_makeDive(id: 'fmt-1', diveNumber: 1, maxDepth: 20.0)];

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      // UnitFormatter.formatDepth with default (meters) => "20.0m"
      expect(find.text('20.0m'), findsOneWidget);
    });

    testWidgets('bottomTime column shows formatted minutes', (tester) async {
      final dives = [
        _makeDive(
          id: 'bt-1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
        ),
      ];

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      // _formatDuration produces "45min" (no space)
      expect(find.text('45min'), findsOneWidget);
    });

    testWidgets('empty state renders only headers with no body rows', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTable(dives: []));
      await tester.pumpAndSettle();

      // Headers present
      expect(find.text('#'), findsOneWidget);
      expect(find.text('Site'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Max D'), findsOneWidget);
      expect(find.text('BT'), findsOneWidget);

      // No dive data rows
      expect(find.text('#1'), findsNothing);
    });

    testWidgets('highlighted row renders without crash', (tester) async {
      final dives = [
        _makeDive(id: 'hl-1', diveNumber: 1),
        _makeDive(id: 'hl-2', diveNumber: 2),
      ];

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            tableViewConfigProvider.overrideWith(
              (ref) => _TestTableConfigNotifier(_testConfig),
            ),
          ],
          child: DiveTableView(
            dives: dives,
            onDiveTap: (_) {},
            highlightedId: 'hl-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both dives render
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    testWidgets('tapping checkbox in selection mode calls onDiveTap', (
      tester,
    ) async {
      String? tappedId;
      final dives = [_makeDive(id: 'cb-1', diveNumber: 50)];

      await tester.pumpWidget(
        _buildTable(
          dives: dives,
          isSelectionMode: true,
          selectedIds: const {},
          onDiveTap: (id) => tappedId = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(tappedId, 'cb-1');
    });

    testWidgets('multiple dives render correct dive numbers', (tester) async {
      final dives = [
        _makeDive(id: 'm1', diveNumber: 100, maxDepth: 10.0),
        _makeDive(id: 'm2', diveNumber: 101, maxDepth: 20.0),
        _makeDive(id: 'm3', diveNumber: 102, maxDepth: 30.0),
      ];

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      expect(find.text('#100'), findsOneWidget);
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('#102'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Sort toggling via header tap
    // -----------------------------------------------------------------------

    testWidgets('tapping column header triggers sort', (tester) async {
      final dives = [
        _makeDive(id: 's1', diveNumber: 3, maxDepth: 30.0),
        _makeDive(id: 's2', diveNumber: 1, maxDepth: 10.0),
        _makeDive(id: 's3', diveNumber: 2, maxDepth: 20.0),
      ];

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      // Tap the '#' header (diveNumber) to trigger ascending sort
      await tester.tap(find.text('#'));
      await tester.pumpAndSettle();

      // After ascending sort, dive numbers should be ordered 1,2,3
      // All three should still be present
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Sort toggling cycles through ascending -> descending -> clear
    // -----------------------------------------------------------------------

    testWidgets('sort cycles ascending -> descending -> clear', (tester) async {
      final dives = [
        _makeDive(id: 'c1', diveNumber: 2, maxDepth: 20.0),
        _makeDive(id: 'c2', diveNumber: 1, maxDepth: 10.0),
      ];

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      // First tap: ascending
      await tester.tap(find.text('#'));
      await tester.pumpAndSettle();

      // Second tap: descending
      await tester.tap(find.text('#'));
      await tester.pumpAndSettle();

      // Third tap: clear sort
      await tester.tap(find.text('#'));
      await tester.pumpAndSettle();

      // Both dives still render
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // waterTemp column shows formatted temperature
    // -----------------------------------------------------------------------

    testWidgets('waterTemp column shows formatted temperature value', (
      tester,
    ) async {
      final dive = Dive(
        id: 'wt-1',
        dateTime: DateTime(2024, 6, 1),
        diveNumber: 1,
        maxDepth: 20.0,
        waterTemp: 24.0,
      );

      final configWithTemp = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.waterTemp),
        ],
      );

      await tester.pumpWidget(
        _buildTable(dives: [dive], config: configWithTemp),
      );
      await tester.pumpAndSettle();

      // Default metric units: 24.0C
      expect(find.textContaining('24'), findsAtLeastNWidgets(1));
    });

    // -----------------------------------------------------------------------
    // Highlighted row renders with distinct background
    // -----------------------------------------------------------------------

    testWidgets('highlighted row renders with ColoredBox', (tester) async {
      final dives = [
        _makeDive(id: 'h1', diveNumber: 1, maxDepth: 10.0),
        _makeDive(id: 'h2', diveNumber: 2, maxDepth: 20.0),
      ];

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            tableViewConfigProvider.overrideWith(
              (ref) => _TestTableConfigNotifier(_testConfig),
            ),
          ],
          child: DiveTableView(
            dives: dives,
            onDiveTap: (_) {},
            highlightedId: 'h1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both rows render, and ColoredBox is used for row background
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.byType(ColoredBox), findsAtLeastNWidgets(2));
    });

    // -----------------------------------------------------------------------
    // Many columns trigger horizontal scroll
    // -----------------------------------------------------------------------

    testWidgets('many columns render with horizontal scroll area', (
      tester,
    ) async {
      final manyColsConfig = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.siteName),
          TableColumnConfig(field: DiveField.dateTime),
          TableColumnConfig(field: DiveField.maxDepth),
          TableColumnConfig(field: DiveField.avgDepth),
          TableColumnConfig(field: DiveField.bottomTime),
          TableColumnConfig(field: DiveField.runtime),
          TableColumnConfig(field: DiveField.waterTemp),
        ],
      );

      final dives = [_makeDive(id: 'mc1', diveNumber: 1, maxDepth: 10.0)];

      await tester.pumpWidget(
        _buildTable(dives: dives, config: manyColsConfig),
      );
      await tester.pumpAndSettle();

      // Should have SingleChildScrollViews for horizontal scrolling
      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(2));
    });

    // -----------------------------------------------------------------------
    // Selection mode with multiple selected rows
    // -----------------------------------------------------------------------

    testWidgets('multiple selected rows have checked checkboxes', (
      tester,
    ) async {
      final dives = [
        _makeDive(id: 'ms1', diveNumber: 1),
        _makeDive(id: 'ms2', diveNumber: 2),
        _makeDive(id: 'ms3', diveNumber: 3),
      ];

      await tester.pumpWidget(
        _buildTable(
          dives: dives,
          isSelectionMode: true,
          selectedIds: {'ms1', 'ms3'},
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes.length, 3);
      expect(checkboxes[0].value, isTrue); // ms1 selected
      expect(checkboxes[1].value, isFalse); // ms2 not selected
      expect(checkboxes[2].value, isTrue); // ms3 selected
    });

    // -----------------------------------------------------------------------
    // Dives with null fields render gracefully
    // -----------------------------------------------------------------------

    testWidgets('dive with null maxDepth renders without crash', (
      tester,
    ) async {
      final dives = [_makeDive(id: 'nd1', diveNumber: 1, maxDepth: null)];

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Row hover effect via MouseRegion
    // -----------------------------------------------------------------------

    testWidgets('rows have MouseRegion for hover effect', (tester) async {
      final dives = [_makeDive(id: 'mr1', diveNumber: 1, maxDepth: 10.0)];

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      expect(find.byType(MouseRegion), findsAtLeastNWidgets(1));
    });

    // -----------------------------------------------------------------------
    // GestureDetector exists for tap/double-tap/long-press
    // -----------------------------------------------------------------------

    testWidgets('rows have GestureDetector for interaction', (tester) async {
      final dives = [_makeDive(id: 'gd1', diveNumber: 1, maxDepth: 10.0)];

      await tester.pumpWidget(
        _buildTable(
          dives: dives,
          onDiveLongPress: (_) {},
          onDiveDoubleTap: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsAtLeastNWidgets(1));
    });

    // -----------------------------------------------------------------------
    // Scrollable body columns render ListView
    // -----------------------------------------------------------------------

    testWidgets('body contains multiple ListViews for pinned and scrollable', (
      tester,
    ) async {
      final dives = [
        _makeDive(id: 'lv1', diveNumber: 1, maxDepth: 10.0),
        _makeDive(id: 'lv2', diveNumber: 2, maxDepth: 20.0),
      ];

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      // Two ListViews: one for pinned columns, one for scrollable columns
      expect(find.byType(ListView), findsAtLeastNWidgets(2));
    });

    // -----------------------------------------------------------------------
    // didUpdateWidget with new highlightedId
    // -----------------------------------------------------------------------

    testWidgets('changing highlightedId does not crash', (tester) async {
      final dives = [
        _makeDive(id: 'du1', diveNumber: 1, maxDepth: 10.0),
        _makeDive(id: 'du2', diveNumber: 2, maxDepth: 20.0),
      ];

      // First build with highlightedId = du1
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            tableViewConfigProvider.overrideWith(
              (ref) => _TestTableConfigNotifier(_testConfig),
            ),
          ],
          child: DiveTableView(
            dives: dives,
            onDiveTap: (_) {},
            highlightedId: 'du1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rebuild with highlightedId = du2 to trigger didUpdateWidget
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            tableViewConfigProvider.overrideWith(
              (ref) => _TestTableConfigNotifier(_testConfig),
            ),
          ],
          child: DiveTableView(
            dives: dives,
            onDiveTap: (_) {},
            highlightedId: 'du2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both rows still render
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Runtime column shows formatted hours:minutes for long dives
    // -----------------------------------------------------------------------

    testWidgets('runtime column shows formatted runtime', (tester) async {
      final dive = Dive(
        id: 'rt-1',
        dateTime: DateTime(2024, 6, 1),
        diveNumber: 1,
        maxDepth: 20.0,
        runtime: const Duration(minutes: 75),
      );

      final configWithRuntime = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.runtime),
        ],
      );

      await tester.pumpWidget(
        _buildTable(dives: [dive], config: configWithRuntime),
      );
      await tester.pumpAndSettle();

      // 75 min is 1h 15min
      expect(find.textContaining('1h'), findsAtLeastNWidgets(1));
    });

    // -----------------------------------------------------------------------
    // avgDepth column
    // -----------------------------------------------------------------------

    testWidgets('avgDepth column shows formatted depth', (tester) async {
      final dive = Dive(
        id: 'ad-1',
        dateTime: DateTime(2024, 6, 1),
        diveNumber: 1,
        avgDepth: 15.5,
      );

      final configWithAvg = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.avgDepth),
        ],
      );

      await tester.pumpWidget(
        _buildTable(dives: [dive], config: configWithAvg),
      );
      await tester.pumpAndSettle();

      expect(find.text('15.5m'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // airTemp column
    // -----------------------------------------------------------------------

    testWidgets('airTemp column shows formatted temperature', (tester) async {
      final dive = Dive(
        id: 'at-1',
        dateTime: DateTime(2024, 6, 1),
        diveNumber: 1,
        airTemp: 30.0,
      );

      final configWithAir = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.airTemp),
        ],
      );

      await tester.pumpWidget(
        _buildTable(dives: [dive], config: configWithAir),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('30'), findsAtLeastNWidgets(1));
    });

    // -----------------------------------------------------------------------
    // Large dive list in table
    // -----------------------------------------------------------------------

    testWidgets('large dive list renders with table view', (tester) async {
      final dives = List.generate(
        30,
        (i) => _makeDive(id: 'lg$i', diveNumber: i + 1, maxDepth: 10.0 + i),
      );

      await tester.pumpWidget(_buildTable(dives: dives));
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table with sort indicator icon
    // -----------------------------------------------------------------------

    testWidgets('ascending sort shows up arrow icon', (tester) async {
      final sortedConfig = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.maxDepth),
        ],
        sortField: DiveField.diveNumber,
        sortAscending: true,
      );

      await tester.pumpWidget(_buildTable(dives: [], config: sortedConfig));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('descending sort shows down arrow icon', (tester) async {
      final sortedConfig = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.maxDepth),
        ],
        sortField: DiveField.diveNumber,
        sortAscending: false,
      );

      await tester.pumpWidget(_buildTable(dives: [], config: sortedConfig));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table without optional callbacks
    // -----------------------------------------------------------------------

    testWidgets('table renders without optional callbacks', (tester) async {
      final dives = [_makeDive(id: 'nc1', diveNumber: 1, maxDepth: 10.0)];

      await tester.pumpWidget(
        _buildTable(dives: dives, onDiveLongPress: null, onDiveDoubleTap: null),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('10.0m'), findsOneWidget);
    });
  });
}
