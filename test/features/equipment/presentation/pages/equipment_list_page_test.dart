import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_routes.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/selection/select_items_menu_entries.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';

import '../../../../helpers/equipment_query_fakes.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/select_items_menu.dart';

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
  String? initialLocation,
}) {
  final router = GoRouter(
    initialLocation: initialLocation ?? path,
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
    // The view mode is read from the diver's saved settings (#3748).
    settingsProvider.overrideWith(
      (ref) =>
          MockSettingsNotifier(AppSettings(equipmentListViewMode: viewMode)),
    ),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    equipmentByStatusProvider.overrideWith((ref, status) => <EquipmentItem>[]),
    activeEquipmentProvider.overrideWith((ref) async => <EquipmentItem>[]),
    equipmentListNotifierProvider.overrideWith((ref) => _MockEquipNotifier()),
    // The add form's Tags field (issue #1942) watches the tag list, whose
    // repository needs a database this harness does not open.
    tagListNotifierProvider.overrideWith((ref) => _EmptyTagList()),
    fakeEquipmentQueryIds(),
    allEquipmentProvider.overrideWith((ref) async => <EquipmentItem>[]),
    equipmentTableConfigProvider.overrideWith(
      (ref) => _TestEquipTableConfigNotifier(),
    ),
  ];
}

/// No tags, and no database behind them.
class _EmptyTagList extends StateNotifier<AsyncValue<List<Tag>>>
    implements TagListNotifier {
  _EmptyTagList() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
      // Table mode titles the list with its entry count (#2669).
      expect(
        tester
            .widget<TableModeLayout>(find.byType(TableModeLayout))
            .appBarSubtitle,
        isNotNull,
      );
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

    testWidgets('compact FAB opens the full editor at /equipment/new', (
      tester,
    ) async {
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

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 'new' is the /equipment/new route stub. Adding gear must land on
      // the new item's page, which offers the type-specific attribute
      // fields (dry weight, buoyancy, ...) up front. A quick-add sheet with
      // only generic fields would force a save-then-edit round trip.
      expect(find.text('new'), findsOneWidget);
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

    testWidgets('table mode sort button opens the sort sheet, no grouping', (
      tester,
    ) async {
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

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // The Equipment sort sheet, minus the grouping: the table stays flat.
      expect(find.text('Sort Equipment'), findsOneWidget);
      expect(find.text('Purchase Date'), findsOneWidget);
      expect(find.text('Last Service'), findsOneWidget);
      expect(find.text('Service Due'), findsOneWidget);
      expect(find.text('Group by type'), findsNothing);
      // Type order is the arrangement's axis now, not an item sort field.
      expect(find.text('Type'), findsNothing);
    });

    testWidgets('table mode search button opens search', (tester) async {
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

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // The search row opens under the app bar
      expect(find.byType(TextField), findsOneWidget);
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

    testWidgets('table mode popup menu shows view mode options', (
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
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // The popup menu should show view mode options
      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
      expect(find.text('Table'), findsOneWidget);
    });

    testWidgets('table mode popup menu changes view mode', (tester) async {
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

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Tap the "Detailed" menu item to trigger onSelected
      await tester.tap(find.text('Detailed'));
      await tester.pumpAndSettle();

      // Verify the popup menu dismissed
      expect(find.text('Compact'), findsNothing);
    });

    // Table mode has no app bar inside the list, so "Select items" lives in
    // the page header's overflow menu and drives the list through the
    // controller the page hands it (issue #2775).
    group('table mode "Select items"', () {
      Future<void> pumpTablePage(WidgetTester tester) async {
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
      }

      testWidgets('shows no separate Select strip above the table', (
        tester,
      ) async {
        await pumpTablePage(tester);

        expect(find.byKey(selectItemsMenuKey), findsNothing);
        expect(find.byIcon(Icons.checklist), findsNothing);
      });

      testWidgets('follows scan a cylinder tag and enters selection', (
        tester,
      ) async {
        await pumpTablePage(tester);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        double top(Finder f) => tester.getTopLeft(f).dy;
        final select = find.byKey(selectItemsMenuKey);
        // Scan tag stays first, as on the phone menu.
        expect(
          top(find.byKey(const ValueKey('equipment_menu_scanTag'))),
          lessThan(top(select)),
        );
        expect(top(select), lessThan(top(find.text('Detailed'))));

        await tester.tap(select);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('selection_exit')), findsOneWidget);
        expect(find.text('0 selected'), findsOneWidget);
      });

      testWidgets('leaves the entry out while selecting', (tester) async {
        await pumpTablePage(tester);
        await enterSelectionViaMenu(tester);

        // The header's overflow, not the selection bar's.
        await tester.tap(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.more_vert),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Detailed'), findsOneWidget);
        expect(find.byKey(selectItemsMenuKey), findsNothing);
      });

      testWidgets('selection does not outlive leaving table mode', (
        tester,
      ) async {
        await pumpTablePage(tester);
        await enterSelectionViaMenu(tester);
        expect(find.byKey(const ValueKey('selection_exit')), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(EquipmentListPage)),
        );
        container
            .read(settingsProvider.notifier)
            .setEquipmentListViewMode(ListViewMode.detailed);
        await tester.pumpAndSettle();
        container
            .read(settingsProvider.notifier)
            .setEquipmentListViewMode(ListViewMode.table);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('selection_exit')), findsNothing);
      });
    });

    testWidgets('selecting a sort option sorts and keeps the sheet open', (
      tester,
    ) async {
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

      // Open the sort bottom sheet
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Purchase Date'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(EquipmentListPage)),
      );
      expect(
        container.read(equipmentSortProvider).field,
        EquipmentSortField.purchaseDate,
      );
      // The sheet carries several axes, so a pick leaves it open.
      expect(find.text('Sort Equipment'), findsOneWidget);
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

    testWidgets('table mode detail builder invoked via selected query param', (
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
          initialLocation: '/equipment?selected=test-equip-id',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      expect(find.byType(EquipmentDetailPage), findsOneWidget);
    });

    testWidgets('table mode create builder invoked via mode=new query param', (
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
          initialLocation: '/equipment?mode=new',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      expect(find.byType(EquipmentDetailPage), findsOneWidget);
    });

    testWidgets('table mode edit builder invoked via edit query param', (
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
          initialLocation: '/equipment?selected=test-equip-id&mode=edit',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      expect(find.byType(EquipmentDetailPage), findsOneWidget);
    });
  });

  testWidgets('the overflow menu offers scanning a cylinder tag', (
    tester,
  ) async {
    var launched = 0;
    final overrides = await _buildOverrides();
    await tester.pumpWidget(
      _buildTestWidget(
        child: const EquipmentListPage(),
        overrides: [
          ...overrides,
          passportScanLauncherProvider.overrideWithValue((context) async {
            launched++;
            return null;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment_menu_scanTag')));
    await tester.pumpAndSettle();
    expect(launched, 1);
  });

  // A new gear item opens on the item page behind the phase 3 switch
  // (issue #4527, phase 3, plan 11).
  testWidgets("the pane's new item is the page", (tester) async {
    void onSaved(String id) {}
    void onCancel() {}
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    );
    final page =
        newGearItemPane(context, onSaved, onCancel) as EquipmentDetailPage;
    expect(page.embedded, isTrue);
    expect(page.newItem, isNotNull);
    expect(page.onCreated, same(onSaved));
  });

  testWidgets('Add on a phone opens the new item once created', (tester) async {
    final router = GoRouter(
      initialLocation: '/equipment',
      routes: [
        GoRoute(
          path: '/equipment',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => openNewGearItem(context),
              child: const Text('add'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop('n1'),
                  child: const Text('NEW'),
                ),
              ),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => Text('ITEM ${state.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEW'));
    await tester.pumpAndSettle();

    expect(find.text('ITEM n1'), findsOneWidget);
  });
}
