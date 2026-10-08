import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/widgets/query_filter_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/trips/presentation/pages/trip_list_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/select_items_menu_entries.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/providers/table_details_pane_provider.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/select_items_menu.dart';

// ---------------------------------------------------------------------------
// Mock notifiers
// ---------------------------------------------------------------------------

class _MockTripListNotifier
    extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  _MockTripListNotifier() : super(const AsyncValue.data(<TripWithStats>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestTripTableConfigNotifier
    extends EntityTableConfigNotifier<TripField> {
  _TestTripTableConfigNotifier()
    : super(
        defaultConfig: EntityTableViewConfig<TripField>(
          columns: [
            EntityTableColumnConfig(field: TripField.tripName, isPinned: true),
          ],
        ),
        fieldFromName: TripFieldAdapter.instance.fieldFromName,
      );
}

// ---------------------------------------------------------------------------
// Helper to build the widget under test inside a GoRouter
// ---------------------------------------------------------------------------

Widget _buildTestWidget({
  required List<Override> overrides,
  String initialLocation = '/trips',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/trips',
        builder: (context, state) => const TripListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const Scaffold(body: Text('new')),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => const Scaffold(body: Text('detail')),
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TripListPage', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    List<Override> baseOverrides({
      ListViewMode viewMode = ListViewMode.detailed,
      List<TripWithStats> trips = const [],
    }) {
      return [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        tripListNotifierProvider.overrideWith((ref) => _MockTripListNotifier()),
        sortedFilteredTripsProvider.overrideWith(
          (ref) => AsyncValue.data(trips),
        ),
        tripListViewModeProvider.overrideWith((ref) => viewMode),
        tripTableConfigProvider.overrideWith(
          (ref) => _TestTripTableConfigNotifier(),
        ),
      ];
    }

    testWidgets('renders TripListContent in mobile mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestWidget(overrides: baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.byType(TripListContent), findsOneWidget);
      expect(find.byType(TableModeLayout), findsNothing);
      expect(find.byType(MasterDetailScaffold), findsNothing);
    });

    testWidgets('renders TableModeLayout in table mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
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
      expect(find.byType(MasterDetailScaffold), findsNothing);
    });

    testWidgets('renders MasterDetailScaffold in desktop mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.detailed),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MasterDetailScaffold), findsOneWidget);
      expect(find.byType(TableModeLayout), findsNothing);
    });

    testWidgets('table mode renders FAB', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
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

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
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

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
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

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // The sort bottom sheet should appear with sort field options
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('End Date'), findsOneWidget);
    });

    testWidgets('table mode query filter button opens the query sheet', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(QueryFilterButton));
      await tester.pumpAndSettle();
      expect(find.byType(QueryFilterSheet), findsOneWidget);
    });

    testWidgets('table mode search button opens search', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
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

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
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

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
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

        final now = DateTime(2024, 1, 1);
        await tester.pumpWidget(
          _buildTestWidget(
            overrides: baseOverrides(
              viewMode: ListViewMode.table,
              trips: [
                TripWithStats(
                  trip: Trip(
                    id: 't1',
                    name: 'Maldives Trip',
                    startDate: DateTime(2024, 6, 1),
                    endDate: DateTime(2024, 6, 7),
                    createdAt: now,
                    updatedAt: now,
                  ),
                  diveCount: 0,
                ),
              ],
            ),
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

      testWidgets('is the first overflow entry and enters selection', (
        tester,
      ) async {
        await pumpTablePage(tester);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(selectItemsMenuKey)).dy,
          lessThan(tester.getTopLeft(find.text('Detailed')).dy),
        );

        await tester.tap(find.byKey(selectItemsMenuKey));
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
          tester.element(find.byType(TripListPage)),
        );
        container.read(tripListViewModeProvider.notifier).state =
            ListViewMode.detailed;
        await tester.pumpAndSettle();
        container.read(tripListViewModeProvider.notifier).state =
            ListViewMode.table;
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('selection_exit')), findsNothing);
      });
    });

    testWidgets('table mode popup menu changes view mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
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

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
        ),
      );
      await tester.pumpAndSettle();

      // Open the sort bottom sheet
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      // Tap a sort field option to trigger onSortChanged
      await tester.tap(find.text('End Date'));
      await tester.pumpAndSettle();

      // The sort bottom sheet should have closed after selection
      expect(find.text('End Date'), findsNothing);
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

      final overrides = [
        ...baseOverrides(viewMode: ListViewMode.table),
        tableDetailsPaneProvider('trips').overrideWith((ref) => true),
        highlightedTripIdProvider.overrideWith((ref) => null),
      ];

      await tester.pumpWidget(_buildTestWidget(overrides: overrides));
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

      final overrides = [
        ...baseOverrides(viewMode: ListViewMode.table),
        tableDetailsPaneProvider('trips').overrideWith((ref) => true),
        highlightedTripIdProvider.overrideWith((ref) => 'test-trip-id'),
      ];

      await tester.pumpWidget(_buildTestWidget(overrides: overrides));
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

      final overrides = [
        ...baseOverrides(viewMode: ListViewMode.table),
        tableDetailsPaneProvider('trips').overrideWith((ref) => true),
        highlightedTripIdProvider.overrideWith((ref) => 'test-trip-id'),
      ];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: overrides,
          initialLocation: '/trips?selected=test-trip-id',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      expect(find.byType(TripDetailPage), findsOneWidget);
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

      final overrides = [
        ...baseOverrides(viewMode: ListViewMode.table),
        tableDetailsPaneProvider('trips').overrideWith((ref) => true),
        highlightedTripIdProvider.overrideWith((ref) => null),
      ];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: overrides,
          initialLocation: '/trips?mode=new',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      expect(find.byType(TripEditPage), findsOneWidget);
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

      final overrides = [
        ...baseOverrides(viewMode: ListViewMode.table),
        tableDetailsPaneProvider('trips').overrideWith((ref) => true),
        highlightedTripIdProvider.overrideWith((ref) => 'test-trip-id'),
      ];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: overrides,
          initialLocation: '/trips?selected=test-trip-id&mode=edit',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      expect(find.byType(TripEditPage), findsOneWidget);
    });

    // The Plan row's edit lands on Planning in the pane too (#2880).
    for (final viewMode in [ListViewMode.detailed, ListViewMode.table]) {
      testWidgets(
        '${viewMode.name} edit pane opens at the section in the URL',
        (tester) async {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = const Size(1200, 800);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            _buildTestWidget(
              overrides: [
                ...baseOverrides(viewMode: viewMode),
                tableDetailsPaneProvider('trips').overrideWith((ref) => true),
                highlightedTripIdProvider.overrideWith((ref) => 'test-trip-id'),
              ],
              initialLocation:
                  '/trips?selected=test-trip-id&mode=edit&section=planning',
            ),
          );
          await tester.pump();
          tester.takeException();
          await tester.pump();
          tester.takeException();

          final page = tester.widget<TripEditPage>(find.byType(TripEditPage));
          expect(page.embedded, isTrue);
          expect(page.initialSection, TripEditSection.planning);
        },
      );
    }
  });
}
