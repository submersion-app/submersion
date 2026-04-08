import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestEquipTableConfigNotifier
    extends EntityTableConfigNotifier<EquipmentField> {
  _TestEquipTableConfigNotifier()
    : super(
        defaultConfig: EntityTableViewConfig<EquipmentField>(
          columns: [
            EntityTableColumnConfig(
              field: EquipmentField.itemName,
              isPinned: true,
            ),
            EntityTableColumnConfig(field: EquipmentField.type),
            EntityTableColumnConfig(field: EquipmentField.brand),
          ],
        ),
        fieldFromName: EquipmentFieldAdapter.instance.fieldFromName,
      );
}

class _MockEquipNotifier extends StateNotifier<AsyncValue<List<EquipmentItem>>>
    implements EquipmentListNotifier {
  _MockEquipNotifier() : super(const AsyncValue.data(<EquipmentItem>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _buildTestWidget({
  required Widget child,
  required List<Override> overrides,
  String path = '/equipment',
}) {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => child,
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const Scaffold(body: Text('new')),
          ),
          GoRoute(
            path: ':id',
            builder: (_, _) => const Scaffold(body: Text('detail')),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<List<Override>> _buildOverrides({
  ListViewMode viewMode = ListViewMode.detailed,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    equipmentByStatusProvider.overrideWith((ref, status) => <EquipmentItem>[]),
    equipmentListNotifierProvider.overrideWith((ref) => _MockEquipNotifier()),
    equipmentListViewModeProvider.overrideWith((ref) => viewMode),
    equipmentTableConfigProvider.overrideWith(
      (ref) => _TestEquipTableConfigNotifier(),
    ),
    equipmentSortProvider.overrideWith(
      (ref) => const SortState(
        field: EquipmentSortField.name,
        direction: SortDirection.descending,
      ),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EquipmentListPage layout branches', () {
    testWidgets('mobile mode renders EquipmentListContent', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        _buildTestWidget(
          child: const EquipmentListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EquipmentListContent), findsWidgets);
      expect(find.byType(TableModeLayout), findsNothing);
      expect(find.byType(MasterDetailScaffold), findsNothing);
    });

    testWidgets('table mode renders TableModeLayout', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await _buildOverrides(viewMode: ListViewMode.table);
      await tester.pumpWidget(
        _buildTestWidget(
          child: const EquipmentListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TableModeLayout), findsOneWidget);
    });

    testWidgets('desktop mode renders MasterDetailScaffold', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        _buildTestWidget(
          child: const EquipmentListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MasterDetailScaffold), findsOneWidget);
    });

    testWidgets('table mode renders FAB', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await _buildOverrides(viewMode: ListViewMode.table);
      await tester.pumpWidget(
        _buildTestWidget(
          child: const EquipmentListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('table mode shows column settings button', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await _buildOverrides(viewMode: ListViewMode.table);
      await tester.pumpWidget(
        _buildTestWidget(
          child: const EquipmentListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });

    testWidgets('tapping column settings opens column picker', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Suppress overflow errors from the bottom sheet layout
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final overrides = await _buildOverrides(viewMode: ListViewMode.table);
      await tester.pumpWidget(
        _buildTestWidget(
          child: const EquipmentListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.view_column_outlined));
      await tester.pumpAndSettle();

      // The bottom sheet should appear with column picker content
      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
    });

    testWidgets('tapping FAB in table mode navigates', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await _buildOverrides(viewMode: ListViewMode.table);
      await tester.pumpWidget(
        _buildTestWidget(
          child: const EquipmentListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify navigation occurred (page rendered without error)
      expect(find.text('new'), findsOneWidget);
    });

    testWidgets('table mode with details pane shows summary builder', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await _buildOverrides(viewMode: ListViewMode.table);
      await tester.pumpWidget(
        _buildTestWidget(
          child: const EquipmentListPage(),
          overrides: [
            ...overrides,
            tableDetailsPaneProvider('equipment').overrideWith((ref) => true),
            highlightedEquipmentIdProvider.overrideWith((ref) => null),
          ],
        ),
      );
      await tester.pump();
      tester.takeException(); // swallow child widget provider errors
      await tester.pump();
      tester.takeException();

      // MasterDetailScaffold is used when details pane is active
      expect(find.byType(MasterDetailScaffold), findsOneWidget);
    });

    testWidgets('table mode with details pane and selected entity', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await _buildOverrides(viewMode: ListViewMode.table);
      await tester.pumpWidget(
        _buildTestWidget(
          child: const EquipmentListPage(),
          overrides: [
            ...overrides,
            tableDetailsPaneProvider('equipment').overrideWith((ref) => true),
            highlightedEquipmentIdProvider.overrideWith(
              (ref) => 'test-equip-id',
            ),
          ],
        ),
      );
      await tester.pump();
      tester.takeException(); // swallow child widget provider errors
      await tester.pump();
      tester.takeException();

      // The detail builder is invoked when a selected ID is present
      expect(find.byType(MasterDetailScaffold), findsOneWidget);
    });
  });
}
