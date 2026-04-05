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
  Map<String, Duration?>? surfaceIntervals,
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
      surfaceIntervals: surfaceIntervals ?? const {},
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
  });
}
