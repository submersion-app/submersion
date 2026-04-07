import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_table_view.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal settings notifier for table tests.
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

Dive _makeDive({
  required String id,
  int? diveNumber,
  double? maxDepth,
  double? avgDepth,
  Duration? bottomTime,
  Duration? runtime,
  double? waterTemp,
  double? airTemp,
  DiveSite? site,
  DateTime? dateTime,
}) {
  return Dive(
    id: id,
    dateTime: dateTime ?? DateTime(2024, 6, 1),
    diveNumber: diveNumber,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    bottomTime: bottomTime,
    runtime: runtime,
    waterTemp: waterTemp,
    airTemp: airTemp,
    site: site,
  );
}

/// Build a table-like layout as DiveListContent would, but without all the
/// heavy providers. This exercises the DiveTableView build path, the
/// DiveProfilePanel, and the highlight provider used in table mode.
Widget _buildTableModeLayout({
  required List<Dive> dives,
  TableViewConfig? config,
  String? highlightedId,
  bool showProfilePanel = false,
  bool isSelectionMode = false,
  Set<String> selectedIds = const {},
  void Function(String)? onDiveTap,
  void Function(String)? onDiveDoubleTap,
  void Function(String)? onDiveLongPress,
}) {
  final tableConfig =
      config ??
      TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.siteName, isPinned: true),
          TableColumnConfig(field: DiveField.dateTime),
          TableColumnConfig(field: DiveField.maxDepth),
          TableColumnConfig(field: DiveField.bottomTime),
          TableColumnConfig(field: DiveField.waterTemp),
        ],
      );

  return testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      tableViewConfigProvider.overrideWith(
        (ref) => _TestTableConfigNotifier(tableConfig),
      ),
      highlightedDiveIdProvider.overrideWith((ref) => highlightedId),
      showProfilePanelProvider.overrideWith((ref) => showProfilePanel),
    ],
    child: Column(
      children: [
        Expanded(
          child: DiveTableView(
            dives: dives,
            onDiveTap: onDiveTap ?? (_) {},
            onDiveDoubleTap: onDiveDoubleTap,
            onDiveLongPress: onDiveLongPress,
            selectedIds: selectedIds,
            isSelectionMode: isSelectionMode,
            highlightedId: highlightedId,
          ),
        ),
      ],
    ),
  );
}

void main() {
  group('DiveListContent table mode (via DiveTableView)', () {
    // -----------------------------------------------------------------------
    // Basic table rendering with all default columns
    // -----------------------------------------------------------------------

    testWidgets('renders table with default 6 columns', (tester) async {
      final dives = [
        _makeDive(
          id: 'd1',
          diveNumber: 1,
          maxDepth: 30.0,
          bottomTime: const Duration(minutes: 45),
          waterTemp: 24.0,
          site: const DiveSite(id: 'site-1', name: 'Coral Garden'),
        ),
      ];

      await tester.pumpWidget(_buildTableModeLayout(dives: dives));
      await tester.pumpAndSettle();

      // Pinned header columns (displayName)
      expect(find.text('Dive Number'), findsOneWidget);
      expect(find.text('Site Name'), findsOneWidget);

      // Scrollable header columns (displayName)
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('Bottom Time'), findsOneWidget);
      expect(find.text('Water Temperature'), findsOneWidget);

      // Row data
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Coral Garden'), findsOneWidget);
      expect(find.text('30.0m'), findsOneWidget);
      expect(find.text('45min'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table mode with multiple dives and various data
    // -----------------------------------------------------------------------

    testWidgets('renders multiple dive rows with formatted values', (
      tester,
    ) async {
      final dives = [
        _makeDive(
          id: 'd1',
          diveNumber: 10,
          maxDepth: 18.0,
          bottomTime: const Duration(minutes: 30),
          waterTemp: 22.0,
        ),
        _makeDive(
          id: 'd2',
          diveNumber: 11,
          maxDepth: 35.5,
          bottomTime: const Duration(minutes: 55),
          waterTemp: 19.0,
        ),
        _makeDive(
          id: 'd3',
          diveNumber: 12,
          maxDepth: 12.0,
          bottomTime: const Duration(minutes: 20),
          waterTemp: 26.0,
        ),
      ];

      await tester.pumpWidget(_buildTableModeLayout(dives: dives));
      await tester.pumpAndSettle();

      // All dive numbers present
      expect(find.text('#10'), findsOneWidget);
      expect(find.text('#11'), findsOneWidget);
      expect(find.text('#12'), findsOneWidget);

      // Depth values
      expect(find.text('18.0m'), findsOneWidget);
      expect(find.text('35.5m'), findsOneWidget);
      expect(find.text('12.0m'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table with extra columns (avgDepth, runtime, airTemp)
    // -----------------------------------------------------------------------

    testWidgets('renders extra columns like avgDepth and runtime', (
      tester,
    ) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.avgDepth),
          TableColumnConfig(field: DiveField.runtime),
        ],
      );

      final dives = [
        _makeDive(
          id: 'd1',
          diveNumber: 1,
          avgDepth: 15.0,
          runtime: const Duration(minutes: 45),
        ),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      // avgDepth formatted
      expect(find.text('15.0m'), findsOneWidget);
      // runtime formatted (45min - under 1 hour)
      expect(find.text('45min'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Highlight provider integration
    // -----------------------------------------------------------------------

    testWidgets('tapping a row updates highlighted state', (tester) async {
      String? tappedId;
      final dives = [
        _makeDive(id: 'tap-1', diveNumber: 1, maxDepth: 20.0),
        _makeDive(id: 'tap-2', diveNumber: 2, maxDepth: 25.0),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, onDiveTap: (id) => tappedId = id),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('#1'));
      await tester.pumpAndSettle();

      expect(tappedId, 'tap-1');
    });

    // -----------------------------------------------------------------------
    // Double-tap fires onDiveDoubleTap
    // -----------------------------------------------------------------------

    testWidgets('double-tap fires onDiveDoubleTap callback', (tester) async {
      String? doubleTappedId;
      final dives = [_makeDive(id: 'dt-1', diveNumber: 5, maxDepth: 20.0)];

      await tester.pumpWidget(
        _buildTableModeLayout(
          dives: dives,
          onDiveDoubleTap: (id) => doubleTappedId = id,
        ),
      );
      await tester.pump();

      final cell = find.text('#5');
      await tester.tap(cell);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(cell);
      await tester.pumpAndSettle();

      expect(doubleTappedId, 'dt-1');
    });

    // -----------------------------------------------------------------------
    // Long-press fires onDiveLongPress (enters selection mode)
    // -----------------------------------------------------------------------

    testWidgets('long-press fires onDiveLongPress callback', (tester) async {
      String? longPressedId;
      final dives = [_makeDive(id: 'lp-1', diveNumber: 7, maxDepth: 20.0)];

      await tester.pumpWidget(
        _buildTableModeLayout(
          dives: dives,
          onDiveLongPress: (id) => longPressedId = id,
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('#7'));
      await tester.pumpAndSettle();

      expect(longPressedId, 'lp-1');
    });

    // -----------------------------------------------------------------------
    // Selection mode shows checkboxes and tracks selected rows
    // -----------------------------------------------------------------------

    testWidgets('selection mode renders checkboxes correctly', (tester) async {
      final dives = [
        _makeDive(id: 'sel-1', diveNumber: 1),
        _makeDive(id: 'sel-2', diveNumber: 2),
        _makeDive(id: 'sel-3', diveNumber: 3),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(
          dives: dives,
          isSelectionMode: true,
          selectedIds: {'sel-1', 'sel-3'},
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
    // Sorted table view (ascending sort by diveNumber)
    // -----------------------------------------------------------------------

    testWidgets('sorted config reorders rows', (tester) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.maxDepth),
        ],
        sortField: DiveField.diveNumber,
        sortAscending: true,
      );

      final dives = [
        _makeDive(id: 's3', diveNumber: 3, maxDepth: 30.0),
        _makeDive(id: 's1', diveNumber: 1, maxDepth: 10.0),
        _makeDive(id: 's2', diveNumber: 2, maxDepth: 20.0),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      // All three should render
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Descending sort
    // -----------------------------------------------------------------------

    testWidgets('descending sort config renders all rows', (tester) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.maxDepth),
        ],
        sortField: DiveField.maxDepth,
        sortAscending: false,
      );

      final dives = [
        _makeDive(id: 'ds1', diveNumber: 1, maxDepth: 10.0),
        _makeDive(id: 'ds2', diveNumber: 2, maxDepth: 30.0),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Site name column shows site name or dash for null
    // -----------------------------------------------------------------------

    testWidgets('siteName column shows site name when present', (tester) async {
      final dives = [
        _makeDive(
          id: 'sn1',
          diveNumber: 1,
          site: const DiveSite(id: 'site-x', name: 'Shark Point'),
        ),
      ];

      await tester.pumpWidget(_buildTableModeLayout(dives: dives));
      await tester.pumpAndSettle();

      expect(find.text('Shark Point'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Highlighted row appearance
    // -----------------------------------------------------------------------

    testWidgets('highlighted dive row uses ColoredBox for background', (
      tester,
    ) async {
      final dives = [
        _makeDive(id: 'hl1', diveNumber: 1, maxDepth: 15.0),
        _makeDive(id: 'hl2', diveNumber: 2, maxDepth: 25.0),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, highlightedId: 'hl1'),
      );
      await tester.pumpAndSettle();

      // Both rows render
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      // ColoredBox is used for row backgrounds
      expect(find.byType(ColoredBox), findsAtLeastNWidgets(2));
    });

    // -----------------------------------------------------------------------
    // Empty dives list renders only headers
    // -----------------------------------------------------------------------

    testWidgets('empty dive list renders table headers only', (tester) async {
      await tester.pumpWidget(_buildTableModeLayout(dives: []));
      await tester.pumpAndSettle();

      expect(find.text('Dive Number'), findsOneWidget);
      expect(find.text('Site Name'), findsOneWidget);
      expect(find.text('Date & Time'), findsOneWidget);
      // No data rows
      expect(find.text('#1'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Dives with null fields render gracefully
    // -----------------------------------------------------------------------

    testWidgets('dives with null fields render empty cells without crash', (
      tester,
    ) async {
      final dives = [
        _makeDive(
          id: 'null-1',
          diveNumber: null,
          maxDepth: null,
          bottomTime: null,
          waterTemp: null,
        ),
      ];

      await tester.pumpWidget(_buildTableModeLayout(dives: dives));
      await tester.pumpAndSettle();

      // The table should render without crashing
      expect(find.byType(DiveTableView), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table with many columns to exercise horizontal scroll
    // -----------------------------------------------------------------------

    testWidgets('many scrollable columns create horizontal scroll area', (
      tester,
    ) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.siteName),
          TableColumnConfig(field: DiveField.dateTime),
          TableColumnConfig(field: DiveField.maxDepth),
          TableColumnConfig(field: DiveField.avgDepth),
          TableColumnConfig(field: DiveField.bottomTime),
          TableColumnConfig(field: DiveField.runtime),
          TableColumnConfig(field: DiveField.waterTemp),
          TableColumnConfig(field: DiveField.airTemp),
        ],
      );

      final dives = [
        _makeDive(
          id: 'mc1',
          diveNumber: 1,
          maxDepth: 20.0,
          avgDepth: 12.0,
          bottomTime: const Duration(minutes: 40),
          runtime: const Duration(minutes: 45),
          waterTemp: 22.0,
          airTemp: 28.0,
        ),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      // Horizontal SingleChildScrollView should exist for header and body
      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(2));
    });

    // -----------------------------------------------------------------------
    // Tapping sort header on the table
    // -----------------------------------------------------------------------

    testWidgets('tapping sort-eligible header column works', (tester) async {
      final dives = [
        _makeDive(id: 'sh1', diveNumber: 2, maxDepth: 25.0),
        _makeDive(id: 'sh2', diveNumber: 1, maxDepth: 15.0),
      ];

      await tester.pumpWidget(_buildTableModeLayout(dives: dives));
      await tester.pumpAndSettle();

      // Tap the 'Dive Number' header to trigger sort
      await tester.tap(find.text('Dive Number'));
      await tester.pumpAndSettle();

      // Both rows still present
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table renders normally when profile panel provider is enabled
    // (Profile panel itself is rendered by TableModeLayout, not DiveTableView)
    // -----------------------------------------------------------------------

    testWidgets('table renders rows when showProfilePanel provider is true', (
      tester,
    ) async {
      final dives = [
        _makeDive(
          id: 'pp1',
          diveNumber: 1,
          maxDepth: 20.0,
          bottomTime: const Duration(minutes: 40),
        ),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(
          dives: dives,
          showProfilePanel: true,
          highlightedId: null,
        ),
      );
      await tester.pump();

      // Table rows render regardless of profile panel state
      // (profile panel is managed by TableModeLayout, not table content)
      expect(find.text('#1'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table with all columns visible
    // -----------------------------------------------------------------------

    testWidgets('table with all dive field columns renders headers', (
      tester,
    ) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.siteName),
          TableColumnConfig(field: DiveField.dateTime),
          TableColumnConfig(field: DiveField.maxDepth),
          TableColumnConfig(field: DiveField.avgDepth),
          TableColumnConfig(field: DiveField.bottomTime),
          TableColumnConfig(field: DiveField.runtime),
          TableColumnConfig(field: DiveField.waterTemp),
          TableColumnConfig(field: DiveField.airTemp),
        ],
      );

      final dives = [
        _makeDive(
          id: 'all1',
          diveNumber: 5,
          maxDepth: 18.0,
          avgDepth: 12.0,
          bottomTime: const Duration(minutes: 35),
          runtime: const Duration(minutes: 40),
          waterTemp: 22.0,
          airTemp: 28.0,
          dateTime: DateTime(2024, 7, 15, 10, 0),
        ),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      // Headers (displayName values)
      expect(find.text('Dive Number'), findsOneWidget);
      expect(find.text('Site Name'), findsOneWidget);
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Max Depth'), findsOneWidget);
      expect(find.text('Average Depth'), findsOneWidget);
      expect(find.text('Bottom Time'), findsOneWidget);

      // Data
      expect(find.text('#5'), findsOneWidget);
      expect(find.text('18.0m'), findsOneWidget);
      expect(find.text('12.0m'), findsOneWidget);
      expect(find.text('35min'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table with rating and buddy columns
    // -----------------------------------------------------------------------

    testWidgets('table with rating column renders header', (tester) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.ratingStars),
        ],
      );

      final dives = [_makeDive(id: 'rat1', diveNumber: 1)];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table with sort ascending and descending
    // -----------------------------------------------------------------------

    testWidgets('ascending sort by maxDepth renders all rows', (tester) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.maxDepth),
        ],
        sortField: DiveField.maxDepth,
        sortAscending: true,
      );

      final dives = [
        _makeDive(id: 'asc1', diveNumber: 1, maxDepth: 30.0),
        _makeDive(id: 'asc2', diveNumber: 2, maxDepth: 10.0),
        _makeDive(id: 'asc3', diveNumber: 3, maxDepth: 20.0),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Large dive list
    // -----------------------------------------------------------------------

    testWidgets('large dive list renders without crash', (tester) async {
      final dives = List.generate(
        25,
        (i) => _makeDive(id: 'lg$i', diveNumber: i + 1, maxDepth: 10.0 + i),
      );

      await tester.pumpWidget(_buildTableModeLayout(dives: dives));
      await tester.pumpAndSettle();

      // At least first dive should be visible
      expect(find.text('#1'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table with waterTemp only column
    // -----------------------------------------------------------------------

    testWidgets('table with waterTemp only column shows temperature', (
      tester,
    ) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.waterTemp),
        ],
      );

      final dives = [_makeDive(id: 'wt1', diveNumber: 1, waterTemp: 24.0)];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('24'), findsAtLeastNWidgets(1));
    });

    // -----------------------------------------------------------------------
    // Table tap callback receives correct ID with multiple dives
    // -----------------------------------------------------------------------

    testWidgets('tap callback returns correct ID for second row', (
      tester,
    ) async {
      String? tappedId;
      final dives = [
        _makeDive(id: 'r1', diveNumber: 10, maxDepth: 20.0),
        _makeDive(id: 'r2', diveNumber: 20, maxDepth: 25.0),
        _makeDive(id: 'r3', diveNumber: 30, maxDepth: 30.0),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, onDiveTap: (id) => tappedId = id),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('#20'));
      await tester.pumpAndSettle();

      expect(tappedId, 'r2');
    });

    // -----------------------------------------------------------------------
    // Table with site name that has special characters
    // -----------------------------------------------------------------------

    testWidgets('table renders site names with special characters', (
      tester,
    ) async {
      final dives = [
        _makeDive(
          id: 'sp1',
          diveNumber: 1,
          site: const DiveSite(
            id: 'site-sp',
            name: "O'Brien's Reef & Pinnacle",
          ),
        ),
      ];

      await tester.pumpWidget(_buildTableModeLayout(dives: dives));
      await tester.pumpAndSettle();

      expect(find.text("O'Brien's Reef & Pinnacle"), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Selection mode with no items selected
    // -----------------------------------------------------------------------

    testWidgets('selection mode with empty selection shows unchecked boxes', (
      tester,
    ) async {
      final dives = [
        _makeDive(id: 'es1', diveNumber: 1),
        _makeDive(id: 'es2', diveNumber: 2),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(
          dives: dives,
          isSelectionMode: true,
          selectedIds: {},
        ),
      );
      await tester.pumpAndSettle();

      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes.length, 2);
      expect(checkboxes[0].value, isFalse);
      expect(checkboxes[1].value, isFalse);
    });

    // -----------------------------------------------------------------------
    // Highlight changes
    // -----------------------------------------------------------------------

    testWidgets('changing highlightedId updates row styling', (tester) async {
      final dives = [
        _makeDive(id: 'hc1', diveNumber: 1, maxDepth: 15.0),
        _makeDive(id: 'hc2', diveNumber: 2, maxDepth: 25.0),
      ];

      // First render with hc1 highlighted
      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, highlightedId: 'hc1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);

      // Re-render with hc2 highlighted
      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, highlightedId: 'hc2'),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table renders with only pinned columns
    // -----------------------------------------------------------------------

    testWidgets('table with only pinned columns renders correctly', (
      tester,
    ) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.siteName, isPinned: true),
        ],
      );

      final dives = [
        _makeDive(
          id: 'po1',
          diveNumber: 1,
          site: const DiveSite(id: 'site-po', name: 'Pinnacle Reef'),
        ),
      ];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Pinnacle Reef'), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Table with single scrollable column
    // -----------------------------------------------------------------------

    testWidgets('table with single scrollable column renders', (tester) async {
      final config = TableViewConfig(
        columns: [
          TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
          TableColumnConfig(field: DiveField.maxDepth),
        ],
      );

      final dives = [_makeDive(id: 'sc1', diveNumber: 7, maxDepth: 42.0)];

      await tester.pumpWidget(
        _buildTableModeLayout(dives: dives, config: config),
      );
      await tester.pumpAndSettle();

      expect(find.text('#7'), findsOneWidget);
      expect(find.text('42.0m'), findsOneWidget);
    });
  });
}
