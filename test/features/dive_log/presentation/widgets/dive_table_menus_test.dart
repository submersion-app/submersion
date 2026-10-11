import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_table_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_count_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/saved_query_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

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

/// Column and cell filter menus on the dive table (#2984).
void main() {
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 4, 1, 9),
    diveNumber: 7,
    maxDepth: 23.4167,
    site: const DiveSite(id: 's1', name: 'Salt Pier'),
  );

  Future<ProviderContainer> pumpDiveTable(
    WidgetTester tester, {
    List<DiveField> columns = const [
      DiveField.diveNumber,
      DiveField.siteName,
      DiveField.maxDepth,
    ],
    void Function(String)? onDiveTap,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          diveSurfaceIntervalsProvider.overrideWith((ref) async => const {}),
          tableViewConfigProvider.overrideWith(
            (ref) => _TestTableConfigNotifier(
              TableViewConfig(
                columns: [
                  for (final (i, f) in columns.indexed)
                    TableColumnConfig(field: f, isPinned: i == 0),
                ],
              ),
            ),
          ),
          refineMatchCountProvider.overrideWith((ref, draft) async => 0),
          savedQueryLoadsProvider('dives').overrideWith((ref) async => []),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
        ],
        child: DiveTableView(
          dives: [dive],
          diveTypeLabelResolver: Dive.diveTypeDisplayName,
          onDiveTap: onDiveTap ?? (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(DiveTableView)),
    );
  }

  Future<void> rightClick(WidgetTester tester, Finder target) async {
    await tester.tap(target, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
  }

  testWidgets('right-click a site cell, Only Salt Pier adds the rule', (
    tester,
  ) async {
    final container = await pumpDiveTable(tester);
    await rightClick(tester, find.text('Salt Pier'));
    await tester.tap(find.text('Only Salt Pier'));
    await tester.pumpAndSettle();
    expect(
      container.read(diveFilterProvider).query,
      ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('s1', 'Salt Pier'),
      ),
    );
  });

  testWidgets('long-press on a cell opens the filter menu, not a tap', (
    tester,
  ) async {
    var tapped = 0;
    await pumpDiveTable(tester, onDiveTap: (_) => tapped++);
    await tester.longPress(find.text('Salt Pier'));
    await tester.pumpAndSettle();
    expect(find.text('Exclude Salt Pier'), findsOneWidget);
    expect(tapped, 0);
  });

  testWidgets('a filtered column shows the indicator and Reset clears it', (
    tester,
  ) async {
    final container = await pumpDiveTable(tester);
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      siteId: 's1',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('entity-table-filtered-siteName')),
      findsOneWidget,
    );
    await rightClick(tester, find.text('Site Name'));
    await tester.tap(find.text('Reset filter'));
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider).siteId, isNull);
    expect(
      find.byKey(const ValueKey('entity-table-filtered-siteName')),
      findsNothing,
    );
  });

  testWidgets('Reset filter is disabled while the column is unfiltered', (
    tester,
  ) async {
    await pumpDiveTable(tester);
    await rightClick(tester, find.text('Site Name'));
    final item = tester.widget<PopupMenuItem<Object?>>(
      find.ancestor(
        of: find.text('Reset filter'),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      ),
    );
    expect(item.enabled, isFalse);
  });

  testWidgets('an unfilterable column header offers only Hide column', (
    tester,
  ) async {
    await pumpDiveTable(
      tester,
      columns: const [DiveField.diveNumber, DiveField.altitude],
    );
    await rightClick(tester, find.text('Altitude'));
    expect(find.text('Add filter'), findsNothing);
    expect(find.text('Hide column'), findsOneWidget);
  });

  testWidgets('Add filter on Max Depth opens Refine with a depth rule', (
    tester,
  ) async {
    await pumpDiveTable(tester);
    await rightClick(tester, find.text('Max Depth'));
    await tester.tap(find.text('Add filter'));
    await tester.pumpAndSettle();
    final tabs = tester.widget<TabBar>(find.byType(TabBar).first);
    expect(tabs.controller!.index, 1, reason: 'opens on the Builder tab');
  });
}
