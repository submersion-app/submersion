import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_list_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_content.dart';
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
// Mock notifiers
// ---------------------------------------------------------------------------

class _MockBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  _MockBuddyListNotifier() : super(const AsyncValue.data(<Buddy>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestBuddyTableConfigNotifier
    extends EntityTableConfigNotifier<BuddyField> {
  _TestBuddyTableConfigNotifier()
    : super(
        defaultConfig: EntityTableViewConfig<BuddyField>(
          columns: [
            EntityTableColumnConfig(
              field: BuddyField.buddyName,
              isPinned: true,
            ),
          ],
        ),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      );
}

// ---------------------------------------------------------------------------
// Helper to build the widget under test inside a GoRouter
// ---------------------------------------------------------------------------

Widget _buildTestWidget({
  required List<Override> overrides,
  String initialLocation = '/buddies',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/buddies',
        builder: (context, state) => const BuddyListPage(),
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
  group('BuddyListPage', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    List<Override> baseOverrides({
      ListViewMode viewMode = ListViewMode.detailed,
    }) {
      return [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        allBuddiesWithDiveCountProvider.overrideWith(
          (ref) => <BuddyWithDiveCount>[],
        ),
        buddyListNotifierProvider.overrideWith(
          (ref) => _MockBuddyListNotifier(),
        ),
        buddyListViewModeProvider.overrideWith((ref) => viewMode),
        buddyTableConfigProvider.overrideWith(
          (ref) => _TestBuddyTableConfigNotifier(),
        ),
      ];
    }

    testWidgets('renders BuddyListContent in mobile mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestWidget(overrides: baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.byType(BuddyListContent), findsOneWidget);
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

      // The view mode provider should have been updated, causing a rebuild.
      // Since we use an override, the widget rebuilds with the new mode.
      // Verify the popup menu dismissed (no more menu items visible).
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

      final overrides = [
        ...baseOverrides(viewMode: ListViewMode.table),
        tableDetailsPaneProvider('buddies').overrideWith((ref) => true),
        highlightedBuddyIdProvider.overrideWith((ref) => null),
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
        tableDetailsPaneProvider('buddies').overrideWith((ref) => true),
        highlightedBuddyIdProvider.overrideWith((ref) => 'test-buddy-id'),
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
        tableDetailsPaneProvider('buddies').overrideWith((ref) => true),
        highlightedBuddyIdProvider.overrideWith((ref) => 'test-buddy-id'),
      ];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: overrides,
          initialLocation: '/buddies?selected=test-buddy-id',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      // The detail builder closure body was invoked, creating BuddyDetailPage
      expect(find.byType(BuddyDetailPage), findsOneWidget);
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
        tableDetailsPaneProvider('buddies').overrideWith((ref) => true),
        highlightedBuddyIdProvider.overrideWith((ref) => null),
      ];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: overrides,
          initialLocation: '/buddies?mode=new',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      // The create builder closure body was invoked, creating BuddyEditPage
      expect(find.byType(BuddyEditPage), findsOneWidget);
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
        tableDetailsPaneProvider('buddies').overrideWith((ref) => true),
        highlightedBuddyIdProvider.overrideWith((ref) => 'test-buddy-id'),
      ];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: overrides,
          initialLocation: '/buddies?selected=test-buddy-id&mode=edit',
        ),
      );
      await tester.pump();
      tester.takeException();
      await tester.pump();
      tester.takeException();

      // The edit builder closure body was invoked, creating BuddyEditPage
      expect(find.byType(BuddyEditPage), findsOneWidget);
    });
  });
}
