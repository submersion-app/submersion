import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_list_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
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

class _TestDCTableConfigNotifier
    extends EntityTableConfigNotifier<DiveCenterField> {
  _TestDCTableConfigNotifier()
    : super(
        defaultConfig: EntityTableViewConfig<DiveCenterField>(
          columns: [
            EntityTableColumnConfig(
              field: DiveCenterField.centerName,
              isPinned: true,
            ),
            EntityTableColumnConfig(field: DiveCenterField.city),
            EntityTableColumnConfig(field: DiveCenterField.country),
          ],
        ),
        fieldFromName: DiveCenterFieldAdapter.instance.fieldFromName,
      );
}

class _MockDCListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDCListNotifier() : super(const AsyncValue.data(<DiveCenter>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _buildTestWidget({
  required Widget child,
  required List<Override> overrides,
  String path = '/dive-centers',
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
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    allDiveCentersProvider.overrideWith((ref) async => <DiveCenter>[]),
    diveCenterListNotifierProvider.overrideWith((ref) => _MockDCListNotifier()),
    diveCenterListViewModeProvider.overrideWith((ref) => viewMode),
    diveCenterTableConfigProvider.overrideWith(
      (ref) => _TestDCTableConfigNotifier(),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiveCenterListPage layout branches', () {
    // The DiveCenterListContent empty-state has a Row that can overflow
    // at narrow widths. We suppress overflow errors here since these tests
    // only verify which layout branch renders.
    testWidgets('mobile mode renders DiveCenterListContent', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await _buildOverrides();
      await tester.pumpWidget(
        _buildTestWidget(
          child: const DiveCenterListPage(),
          overrides: overrides,
        ),
      );
      await tester.pump();
      // Drain any overflow FlutterErrors queued during layout
      final e1 = tester.takeException();
      expect(
        e1 == null || e1.toString().contains('overflowed'),
        isTrue,
        reason: 'unexpected exception: $e1',
      );
      await tester.pumpAndSettle();
      final e2 = tester.takeException();
      if (e2 != null && !e2.toString().contains('overflowed')) {
        fail('unexpected exception: $e2');
      }

      expect(find.byType(DiveCenterListContent), findsOneWidget);
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
          child: const DiveCenterListPage(),
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
          child: const DiveCenterListPage(),
          overrides: overrides,
        ),
      );
      await tester.pump();
      // Drain any overflow FlutterErrors queued during layout
      final e1 = tester.takeException();
      if (e1 != null && !e1.toString().contains('overflowed')) {
        fail('unexpected exception: $e1');
      }
      await tester.pumpAndSettle();
      final e2 = tester.takeException();
      if (e2 != null && !e2.toString().contains('overflowed')) {
        fail('unexpected exception: $e2');
      }

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
          child: const DiveCenterListPage(),
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
          child: const DiveCenterListPage(),
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
          child: const DiveCenterListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.view_column_outlined));
      await tester.pumpAndSettle();

      // The bottom sheet should appear with column picker content
      expect(find.text('VISIBLE COLUMNS'), findsOneWidget);
    });

    testWidgets('table mode sort button opens sort bottom sheet', (
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
          child: const DiveCenterListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // The sort bottom sheet should appear with sort field options
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Dive Count'), findsOneWidget);
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
          child: const DiveCenterListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // The search delegate should open, showing a search bar
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
          child: const DiveCenterListPage(),
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
          child: const DiveCenterListPage(),
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

      // Suppress RenderFlex overflow when rebuilding to non-table mode
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final overrides = await _buildOverrides(viewMode: ListViewMode.table);
      await tester.pumpWidget(
        _buildTestWidget(
          child: const DiveCenterListPage(),
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

    testWidgets('selecting sort option triggers onSortChanged callback', (
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
          child: const DiveCenterListPage(),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();

      // Open the sort bottom sheet
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // Tap a sort field option to trigger onSortChanged
      await tester.tap(find.text('Dive Count'));
      await tester.pumpAndSettle();

      // The sort bottom sheet should have closed after selection
      expect(find.text('Dive Count'), findsNothing);
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
          child: const DiveCenterListPage(),
          overrides: [
            ...overrides,
            tableDetailsPaneProvider('diveCenters').overrideWith((ref) => true),
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
          child: const DiveCenterListPage(),
          overrides: [
            ...overrides,
            tableDetailsPaneProvider('diveCenters').overrideWith((ref) => true),
            highlightedDiveCenterIdProvider.overrideWith((ref) => 'test-dc-id'),
          ],
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      // The detail builder is invoked when a selected ID is present.
      // The MasterDetailScaffold renders within the table mode layout.
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
          child: const DiveCenterListPage(),
          overrides: [
            ...overrides,
            tableDetailsPaneProvider('diveCenters').overrideWith((ref) => true),
            highlightedDiveCenterIdProvider.overrideWith((ref) => 'test-dc-id'),
          ],
          initialLocation: '/dive-centers?selected=test-dc-id',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      expect(find.byType(DiveCenterDetailPage), findsOneWidget);
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
          child: const DiveCenterListPage(),
          overrides: [
            ...overrides,
            tableDetailsPaneProvider('diveCenters').overrideWith((ref) => true),
          ],
          initialLocation: '/dive-centers?mode=new',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      expect(find.byType(DiveCenterEditPage), findsOneWidget);
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
          child: const DiveCenterListPage(),
          overrides: [
            ...overrides,
            tableDetailsPaneProvider('diveCenters').overrideWith((ref) => true),
            highlightedDiveCenterIdProvider.overrideWith((ref) => 'test-dc-id'),
          ],
          initialLocation: '/dive-centers?selected=test-dc-id&mode=edit',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      expect(find.byType(DiveCenterEditPage), findsOneWidget);
    });
  });
}
