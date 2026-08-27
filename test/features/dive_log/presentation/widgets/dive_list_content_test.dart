import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_table_view.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/selection_contract.dart';
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
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

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
            selectedIds: selectedIds,
            isSelectionMode: isSelectionMode,
            highlightedId: highlightedId,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Phone-mode helpers
// ---------------------------------------------------------------------------

class _MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _MockPaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  /// Narrow the visible list, standing in for a filter or search change.
  void showOnly(List<DiveSummary> dives) {
    state = AsyncValue.data(
      PaginatedDiveListState(dives: dives, hasMore: false),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<List<Override>> _buildPhoneOverrides({
  required List<Dive> dives,
  required ListViewMode viewMode,
  required String? highlightedDiveId,
}) async {
  final summaries = dives.map(DiveSummary.fromDive).toList();
  final base = await getBaseOverrides();
  return [
    ...base,
    diveListViewModeProvider.overrideWith((ref) => viewMode),
    highlightedDiveIdProvider.overrideWith((ref) => highlightedDiveId),
    paginatedDiveListProvider.overrideWith(
      (ref) => _MockPaginatedNotifier(summaries),
    ),
  ];
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
    // Long-press is not a selection gesture in table mode
    // -----------------------------------------------------------------------

    testWidgets('long-press on a table row does not check it', (tester) async {
      final dives = [_makeDive(id: 'lp-1', diveNumber: 7, maxDepth: 20.0)];

      await tester.pumpWidget(_buildTableModeLayout(dives: dives));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('#7'));
      await tester.pumpAndSettle();

      // No checkbox column means the table never entered selection mode.
      expect(find.byType(Checkbox), findsNothing);
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

  // -------------------------------------------------------------------------
  // Phone-mode highlight
  // -------------------------------------------------------------------------

  group('phone-mode highlight', () {
    testWidgets(
      'phone detailed view highlights dive when highlightedDiveIdProvider is set',
      (tester) async {
        final dives = [
          _makeDive(
            id: 'd1',
            diveNumber: 1,
            site: const DiveSite(id: 's1', name: 'Site One'),
          ),
          _makeDive(
            id: 'd2',
            diveNumber: 2,
            site: const DiveSite(id: 's2', name: 'Site Two'),
          ),
        ];

        final overrides = await _buildPhoneOverrides(
          dives: dives,
          viewMode: ListViewMode.detailed,
          highlightedDiveId: 'd2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const DiveListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<DiveListTile>(find.byType(DiveListTile))
            .toList();
        final tileOne = tiles.firstWhere((t) => t.diveId == 'd1');
        final tileTwo = tiles.firstWhere((t) => t.diveId == 'd2');

        // Highlight and checked are independent channels: a highlighted row
        // is not in the bulk selection.
        expect(tileOne.isHighlighted, isFalse);
        expect(tileTwo.isHighlighted, isTrue);
        expect(tileTwo.isChecked, isFalse);
      },
    );

    testWidgets(
      'phone compact view highlights dive when highlightedDiveIdProvider is set',
      (tester) async {
        final dives = [
          _makeDive(
            id: 'd1',
            diveNumber: 1,
            site: const DiveSite(id: 's1', name: 'Site One'),
          ),
          _makeDive(
            id: 'd2',
            diveNumber: 2,
            site: const DiveSite(id: 's2', name: 'Site Two'),
          ),
        ];

        final overrides = await _buildPhoneOverrides(
          dives: dives,
          viewMode: ListViewMode.compact,
          highlightedDiveId: 'd2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const DiveListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<CompactDiveListTile>(find.byType(CompactDiveListTile))
            .toList();
        final one = tiles.firstWhere((t) => t.diveId == 'd1');
        final two = tiles.firstWhere((t) => t.diveId == 'd2');

        expect(one.isHighlighted, isFalse);
        expect(two.isHighlighted, isTrue);
        expect(two.isChecked, isFalse);
      },
    );
  });

  group('phone-mode selection', () {
    List<Dive> fourDives() => [
      _makeDive(
        id: 'd1',
        diveNumber: 1,
        site: const DiveSite(id: 's1', name: 'Aaa'),
      ),
      _makeDive(
        id: 'd2',
        diveNumber: 2,
        site: const DiveSite(id: 's2', name: 'Bbb'),
      ),
      _makeDive(
        id: 'd3',
        diveNumber: 3,
        site: const DiveSite(id: 's3', name: 'Ccc'),
      ),
      _makeDive(
        id: 'd4',
        diveNumber: 4,
        site: const DiveSite(id: 's4', name: 'Ddd'),
      ),
    ];

    testWidgets(
      'Select enters selection; shift-tap selects a range; tap toggles',
      (tester) async {
        final overrides = await _buildPhoneOverrides(
          dives: fourDives(),
          viewMode: ListViewMode.detailed,
          highlightedDiveId: null,
        );
        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const DiveListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        DiveListTile tile(String id) => tester
            .widgetList<DiveListTile>(find.byType(DiveListTile))
            .firstWhere((t) => t.diveId == id);
        Finder tileFinder(String id) =>
            find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

        // Select, then check d1 -> selection mode with d1 as the anchor.
        await tester.tap(find.byKey(const ValueKey('enter_selection')));
        await tester.pumpAndSettle();
        await tester.tap(tileFinder('d1'));
        await tester.pumpAndSettle();
        expect(tile('d1').isSelectionMode, isTrue);
        expect(tile('d1').isChecked, isTrue);

        // Shift-tap d3 -> the d1..d3 span becomes selected.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tap(tileFinder('d3'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(tile('d1').isChecked, isTrue);
        expect(tile('d2').isChecked, isTrue);
        expect(tile('d3').isChecked, isTrue);
        expect(tile('d4').isChecked, isFalse);

        // Plain tap d2 -> toggles it back off.
        await tester.tap(tileFinder('d2'));
        await tester.pumpAndSettle();
        expect(tile('d2').isChecked, isFalse);
      },
    );

    // Table rows carry an onDoubleTap, so onDiveTap only resolves once the
    // double-tap timer expires, and the modifier has to stay held across that
    // wait. The tap-down handler must not move the highlight in the meantime:
    // that highlight is the anchor the shift-click extends from.
    testWidgets('table mode: shift-tap extends from the tapped row', (
      tester,
    ) async {
      final dives = fourDives();
      final base = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...base,
            diveListViewModeProvider.overrideWith((ref) => ListViewMode.table),
            highlightedDiveIdProvider.overrideWith((ref) => null),
            allDivesForTableProvider.overrideWithValue(AsyncValue.data(dives)),
            tableViewConfigProvider.overrideWith(
              (ref) => _TestTableConfigNotifier(
                TableViewConfig(
                  columns: [
                    TableColumnConfig(
                      field: DiveField.siteName,
                      isPinned: true,
                    ),
                    TableColumnConfig(field: DiveField.maxDepth),
                  ],
                ),
              ),
            ),
          ],
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      // Plain tap highlights the first row. Settle past the double-tap window
      // so the next tap is not read as a double-tap.
      await tester.tap(find.text('Aaa'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Ccc'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('modifier-tap checks the highlighted dive too', (tester) async {
      // Cmd on macOS, Control elsewhere -- mirrors
      // SelectableListScope.isModifierPressed so this passes on the macOS dev
      // machine and the Linux CI runner alike.
      final modifierKey = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;

      final overrides = await _buildPhoneOverrides(
        dives: fourDives(),
        viewMode: ListViewMode.compact,
        highlightedDiveId: 'd2',
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      CompactDiveListTile tile(String id) => tester
          .widgetList<CompactDiveListTile>(find.byType(CompactDiveListTile))
          .firstWhere((t) => t.diveId == id);
      Finder tileFinder(String id) => find.byWidgetPredicate(
        (w) => w is CompactDiveListTile && w.diveId == id,
      );

      await tester.sendKeyDownEvent(modifierKey);
      await tester.tap(tileFinder('d4'));
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pumpAndSettle();

      // The highlighted row was the user's on-screen selection, so it joins
      // the checked set rather than vanishing.
      expect(tile('d2').isChecked, isTrue);
      expect(tile('d4').isChecked, isTrue);
      expect(tile('d1').isChecked, isFalse);
      expect(tile('d3').isChecked, isFalse);
    });

    testWidgets('compact view: Select enters selection and tap toggles', (
      tester,
    ) async {
      final overrides = await _buildPhoneOverrides(
        dives: fourDives(),
        viewMode: ListViewMode.compact,
        highlightedDiveId: null,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      CompactDiveListTile tile(String id) => tester
          .widgetList<CompactDiveListTile>(find.byType(CompactDiveListTile))
          .firstWhere((t) => t.diveId == id);
      Finder tileFinder(String id) => find.byWidgetPredicate(
        (w) => w is CompactDiveListTile && w.diveId == id,
      );

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      expect(tile('d1').isSelectionMode, isTrue);

      await tester.tap(tileFinder('d2'));
      await tester.pumpAndSettle();
      expect(tile('d2').isChecked, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Selection toolbar: Deselect All button presence and ordering
  //
  // Both selection toolbars (the phone full AppBar from _buildSelectionAppBar
  // and the master-detail compact bar from _buildSelectionBar) must offer a
  // Deselect All action, positioned immediately after Select All so the two
  // read as a pair.
  // -------------------------------------------------------------------------

  group('selection toolbar deselect-all', () {
    List<Dive> fourDives() => [
      _makeDive(
        id: 'd1',
        diveNumber: 1,
        site: const DiveSite(id: 's1', name: 'Aaa'),
      ),
      _makeDive(
        id: 'd2',
        diveNumber: 2,
        site: const DiveSite(id: 's2', name: 'Bbb'),
      ),
      _makeDive(
        id: 'd3',
        diveNumber: 3,
        site: const DiveSite(id: 's3', name: 'Ccc'),
      ),
      _makeDive(
        id: 'd4',
        diveNumber: 4,
        site: const DiveSite(id: 's4', name: 'Ddd'),
      ),
    ];

    Finder tileFinder(String id) =>
        find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

    /// Enter selection mode (one dive selected, three unselected) and assert
    /// that the Deselect All button is present and laid out immediately after
    /// Select All. [showAppBar] picks the phone AppBar (true) vs the
    /// master-detail compact bar (false).
    ///
    /// The two bars diverge on what follows the Select/Deselect pair: the
    /// full-width AppBar keeps date-range as a top-level icon, while the narrow
    /// master-pane bar collapses date-range (and the other situational actions)
    /// into an overflow (...) menu to avoid overflowing the pane.
    Future<void> expectDeselectAfterSelectAll(
      WidgetTester tester, {
      required bool showAppBar,
    }) async {
      final overrides = await _buildPhoneOverrides(
        dives: fourDives(),
        viewMode: ListViewMode.detailed,
        highlightedDiveId: null,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: DiveListContent(showAppBar: showAppBar),
        ),
      );
      await tester.pumpAndSettle();

      // Enter selection mode and check d1 as the only selection. With 1 of 4
      // selected, both Select All and Deselect All are visible.
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(tileFinder('d1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.select_all), findsOneWidget);
      expect(find.byIcon(Icons.deselect), findsOneWidget);

      final selectAllX = tester.getCenter(find.byIcon(Icons.select_all)).dx;
      final deselectX = tester.getCenter(find.byIcon(Icons.deselect)).dx;

      // Deselect All sits immediately after Select All so they read as a pair.
      expect(selectAllX, lessThan(deselectX));

      if (showAppBar) {
        // Full-width AppBar: date-range is a top-level action to the right.
        expect(find.byIcon(Icons.date_range), findsOneWidget);
        final dateRangeX = tester.getCenter(find.byIcon(Icons.date_range)).dx;
        expect(deselectX, lessThan(dateRangeX));
      } else {
        // Master-pane bar: date-range lives in the overflow (...) menu, which
        // sits to the right of the Select/Deselect pair.
        expect(find.byIcon(Icons.date_range), findsNothing);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
        final moreX = tester.getCenter(find.byIcon(Icons.more_vert)).dx;
        expect(deselectX, lessThan(moreX));
      }
    }

    testWidgets(
      'master-detail compact bar shows Deselect All next to Select All',
      (tester) async {
        await expectDeselectAfterSelectAll(tester, showAppBar: false);
      },
    );

    testWidgets('phone AppBar shows Deselect All next to Select All', (
      tester,
    ) async {
      await expectDeselectAfterSelectAll(tester, showAppBar: true);
    });

    testWidgets('Compare in 3D action appears only with 2+ selected', (
      tester,
    ) async {
      final overrides = await _buildPhoneOverrides(
        dives: fourDives(),
        viewMode: ListViewMode.detailed,
        highlightedDiveId: null,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();

      final compare = find.byKey(const ValueKey('selection_action_compare3d'));

      // One dive checked -> Compare is visible but disabled. Actions below
      // their minCount render disabled rather than hidden, so the action set
      // stays stable and users can see what an action needs.
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(tileFinder('d1'));
      await tester.pumpAndSettle();
      expect(compare, findsOneWidget);
      expect(tester.widget<IconButton>(compare).onPressed, isNull);

      // Check a second dive -> Compare in 3D enables.
      await tester.tap(tileFinder('d2'));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(compare).onPressed, isNotNull);
    });

    testWidgets('satisfies the shared selection contract', (tester) async {
      final all = fourDives().map(DiveSummary.fromDive).toList();
      final notifier = _MockPaginatedNotifier(all);
      final base = await getBaseOverrides();
      final overrides = [
        ...base,
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        highlightedDiveIdProvider.overrideWith((ref) => null),
        paginatedDiveListProvider.overrideWith((ref) => notifier),
      ];

      await verifySelectionContract(
        tester,
        build: () => testApp(
          overrides: overrides,
          child: const DiveListContent(showAppBar: true),
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        rowRoot: find.byType(DiveListTile).first,
        firstRow: find.byWidgetPredicate(
          (w) => w is DiveListTile && w.diveId == 'd1',
        ),
        applyFilter: (tester) async {
          // Narrowing to a single dive stands in for a filter or search
          // change; the selection must prune to what remains visible.
          notifier.showOnly([all.first]);
        },
        visibleAfterFilter: 1,
      );
    });
  });

  group('navigation pushes sub-pages', () {
    // Sub-pages must push, not go: go() replaces the shell's stack and leaves
    // the Android system back button with nothing to pop (#647).
    Future<GoRouter> pumpList(
      WidgetTester tester, {
      required List<Override> overrides,
      required bool showAppBar,
    }) async {
      final router = GoRouter(
        initialLocation: '/dives',
        routes: [
          GoRoute(
            path: '/dives',
            builder: (_, _) =>
                Scaffold(body: DiveListContent(showAppBar: showAppBar)),
            routes: [
              // Declared before ':diveId' so the static segment wins.
              GoRoute(
                path: 'search',
                builder: (_, _) => const Text('search page'),
              ),
              GoRoute(
                path: ':diveId',
                builder: (context, state) =>
                    Text('detail:${state.pathParameters['diveId']}'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        testAppRouter(
          router: router,
          overrides: overrides,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    Future<List<Override>> detailedOverrides() => _buildPhoneOverrides(
      dives: [
        _makeDive(
          id: 'd1',
          diveNumber: 1,
          site: const DiveSite(id: 's1', name: 'Site One'),
        ),
      ],
      viewMode: ListViewMode.detailed,
      highlightedDiveId: null,
    );

    testWidgets('standalone tile tap pushes the dive detail', (tester) async {
      final router = await pumpList(
        tester,
        overrides: await detailedOverrides(),
        showAppBar: false,
      );

      // No onItemSelected callback, so this is standalone mode: the tile
      // navigates rather than driving a master-detail pane.
      await tester.tap(find.byType(DiveListTile).first);
      await tester.pumpAndSettle();

      expect(find.text('detail:d1'), findsOneWidget);
      expect(router.routerDelegate.canPop(), isTrue);
    });

    for (final showAppBar in const [true, false]) {
      final bar = showAppBar ? 'app bar' : 'compact bar';
      testWidgets('$bar advanced search pushes the search page', (
        tester,
      ) async {
        final router = await pumpList(
          tester,
          overrides: await detailedOverrides(),
          showAppBar: showAppBar,
        );

        await tester.tap(find.byIcon(Icons.more_vert).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Advanced Search').last);
        await tester.pumpAndSettle();

        expect(find.text('search page'), findsOneWidget);
        expect(router.routerDelegate.canPop(), isTrue);
      });
    }
  });
}
