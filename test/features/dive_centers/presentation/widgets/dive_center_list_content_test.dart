import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/bulk_delete_contract.dart';
import '../../../../helpers/selection_contract.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestDCTableConfigNotifier
    extends EntityTableConfigNotifier<DiveCenterField> {
  _TestDCTableConfigNotifier(EntityTableViewConfig<DiveCenterField> config)
    : super(
        defaultConfig: config,
        fieldFromName: DiveCenterFieldAdapter.instance.fieldFromName,
      );
}

class _MockDCListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDCListNotifier(List<DiveCenter> centers)
    : super(AsyncValue.data(centers));

  /// Narrow the visible list, standing in for a filter change.
  void showOnly(List<DiveCenter> centers) {
    state = AsyncValue.data(centers);
  }

  /// Ids bulk delete actually asked to remove.
  final deleted = <String>[];

  @override
  Future<void> deleteDiveCenter(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _testConfig = EntityTableViewConfig<DiveCenterField>(
  columns: [
    EntityTableColumnConfig(field: DiveCenterField.centerName, isPinned: true),
    EntityTableColumnConfig(field: DiveCenterField.city),
    EntityTableColumnConfig(field: DiveCenterField.country),
    EntityTableColumnConfig(field: DiveCenterField.phone),
    EntityTableColumnConfig(field: DiveCenterField.diveCount),
    EntityTableColumnConfig(field: DiveCenterField.rating),
  ],
);

final _now = DateTime.now();

DiveCenter _makeCenter({
  required String id,
  required String name,
  String? city,
  String? country,
  String? phone,
  double? rating,
}) {
  return DiveCenter(
    id: id,
    name: name,
    city: city,
    country: country,
    phone: phone,
    rating: rating,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<List<Override>> _buildOverrides({
  required List<DiveCenter> centers,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    diveCenterListNotifierProvider.overrideWith(
      (ref) => _MockDCListNotifier(centers),
    ),
    diveCenterListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    diveCenterTableConfigProvider.overrideWith(
      (ref) => _TestDCTableConfigNotifier(_testConfig),
    ),
    // Override dive count provider so it returns 0 for any center
    diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
  ];
}

Future<List<Override>> _buildPhoneOverrides({
  required List<DiveCenter> centers,
  ListViewMode viewMode = ListViewMode.detailed,
  String? highlightedDiveCenterId,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    diveCenterListNotifierProvider.overrideWith(
      (ref) => _MockDCListNotifier(centers),
    ),
    diveCenterListViewModeProvider.overrideWith((ref) => viewMode),
    diveCenterTableConfigProvider.overrideWith(
      (ref) => _TestDCTableConfigNotifier(_testConfig),
    ),
    diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
    highlightedDiveCenterIdProvider.overrideWith(
      (ref) => highlightedDiveCenterId,
    ),
  ];
}

void main() {
  group('bulk delete', () {
    late _MockDCListNotifier notifier;

    Future<Widget> host(List<dynamic> rows) async {
      notifier = _MockDCListNotifier(rows.cast());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveCenterListNotifierProvider.overrideWith((ref) => notifier),
          diveCenterListViewModeProvider.overrideWith(
            (ref) => ListViewMode.detailed,
          ),
          diveCenterTableConfigProvider.overrideWith(
            (ref) => _TestDCTableConfigNotifier(_testConfig),
          ),
          diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
          highlightedDiveCenterIdProvider.overrideWith((ref) => null),
        ],
        child: const DiveCenterListContent(showAppBar: true),
      );
    }

    testWidgets('deletes every checked row and reports the count', (
      tester,
    ) async {
      final widget = await host([
        _makeCenter(id: 'd1', name: 'Aaa Center'),
        _makeCenter(id: 'd2', name: 'Bbb Center'),
      ]);

      await verifyBulkDelete(
        tester,
        build: () => widget,
        selectButton: find.byKey(const ValueKey('enter_selection')),
        expectedDeletedCount: 2,
      );

      expect(notifier.deleted, ['d1', 'd2']);
      expect(find.text('2 deleted'), findsOneWidget);
    });

    testWidgets('cancelling deletes nothing and keeps the selection', (
      tester,
    ) async {
      final widget = await host([_makeCenter(id: 'd1', name: 'Aaa Center')]);

      await verifyBulkDeleteCancels(
        tester,
        build: () => widget,
        selectButton: find.byKey(const ValueKey('enter_selection')),
      );

      expect(notifier.deleted, isEmpty);
    });
  });

  group('selection contract', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      final all = <DiveCenter>[
        _makeCenter(id: 'd1', name: 'Aaa Center'),
        _makeCenter(id: 'd2', name: 'Bbb Center'),
        _makeCenter(id: 'd3', name: 'Ccc Center'),
      ];
      final notifier = _MockDCListNotifier(all);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final overrides = <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        diveCenterListNotifierProvider.overrideWith((ref) => notifier),
        diveCenterListViewModeProvider.overrideWith(
          (ref) => ListViewMode.detailed,
        ),
        diveCenterTableConfigProvider.overrideWith(
          (ref) => _TestDCTableConfigNotifier(_testConfig),
        ),
        diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
        highlightedDiveCenterIdProvider.overrideWith((ref) => null),
      ];

      await verifySelectionContract(
        tester,
        build: () => testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const DiveCenterListContent(showAppBar: true),
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        rowRoot: find.ancestor(
          of: find.text('Aaa Center'),
          matching: find.byType(DiveCenterListTile),
        ),
        firstRow: find.text('Aaa Center'),
        applyFilter: (tester) async {
          notifier.showOnly([all.first]);
        },
        visibleAfterFilter: 1,
      );
    });
  });

  group('DiveCenterListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final centers = [
        _makeCenter(
          id: 'dc1',
          name: 'Blue Water Dive',
          city: 'Cairns',
          country: 'Australia',
          rating: 4.5,
        ),
        _makeCenter(
          id: 'dc2',
          name: 'Red Sea Divers',
          city: 'Sharm El Sheikh',
          country: 'Egypt',
          rating: 4.8,
        ),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers from displayName values
      expect(find.text('Name'), findsWidgets);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Country'), findsOneWidget);
    });

    testWidgets('renders rows for each dive center', (tester) async {
      final centers = [
        _makeCenter(id: 'dc1', name: 'Blue Water Dive'),
        _makeCenter(id: 'dc2', name: 'Red Sea Divers'),
        _makeCenter(id: 'dc3', name: 'Pacific Reef Dive'),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Blue Water Dive'), findsOneWidget);
      expect(find.text('Red Sea Divers'), findsOneWidget);
      expect(find.text('Pacific Reef Dive'), findsOneWidget);
    });

    testWidgets('shows empty state when no centers', (tester) async {
      final overrides = await _buildOverrides(centers: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.store_outlined), findsOneWidget);
    });

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Coral Reef Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.text('Coral Reef Center'), findsOneWidget);
    });

    testWidgets(
      'compact bar omits map button in table mode (managed by layout)',
      (tester) async {
        final overrides = await _buildOverrides(
          centers: [_makeCenter(id: 'dc1', name: 'Coral Reef Center')],
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const DiveCenterListContent(showAppBar: false),
          ),
        );
        await tester.pump();

        // Map toggle is managed by TableModeLayout, not the compact bar
        expect(find.byIcon(Icons.map), findsNothing);
      },
    );

    testWidgets('table renders dive center data in cells', (tester) async {
      final centers = [
        _makeCenter(
          id: 'dc1',
          name: 'Blue Water Dive',
          city: 'Cairns',
          country: 'Australia',
          rating: 4.5,
        ),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Blue Water Dive'), findsOneWidget);
      expect(find.text('Cairns'), findsOneWidget);
      expect(find.text('Australia'), findsOneWidget);
    });

    testWidgets('renders centers with null optional fields', (tester) async {
      final centers = [
        _makeCenter(
          id: 'null1',
          name: 'Basic Center',
          city: null,
          country: null,
          phone: null,
          rating: null,
        ),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Basic Center'), findsOneWidget);
    });

    testWidgets('renders many centers without crash', (tester) async {
      final centers = List.generate(
        10,
        (i) => _makeCenter(
          id: 'mc$i',
          name: 'Center $i',
          city: 'City $i',
          country: 'Country $i',
        ),
      );

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Center 0'), findsOneWidget);
    });

    testWidgets('renders with phone and rating data', (tester) async {
      final centers = [
        _makeCenter(
          id: 'pr1',
          name: 'Phone Center',
          phone: '+1-555-1234',
          rating: 4.0,
        ),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Phone Center'), findsOneWidget);
    });

    testWidgets('tapping a row sets highlighted dive center id', (
      tester,
    ) async {
      final centers = [
        _makeCenter(id: 'dc1', name: 'Reef Explorers'),
        _makeCenter(id: 'dc2', name: 'Blue Planet'),
      ];

      final overrides = await _buildOverrides(centers: centers);

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const Scaffold(
                  body: DiveCenterListContent(showAppBar: true),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap on a dive center row
      await tester.tap(find.text('Reef Explorers'));
      // Pump past the DoubleTapGestureRecognizer's 300ms timeout
      await tester.pump(const Duration(milliseconds: 350));

      // The tap should have set the highlighted dive center ID
      expect(container.read(highlightedDiveCenterIdProvider), 'dc1');
    });

    testWidgets('double-tapping a row navigates to dive center detail', (
      tester,
    ) async {
      final centers = [_makeCenter(id: 'dc1', name: 'Reef Explorers')];

      final overrides = await _buildOverrides(centers: centers);

      String? pushedPath;
      final router = GoRouter(
        initialLocation: '/dive-centers',
        routes: [
          GoRoute(
            path: '/dive-centers',
            builder: (context, state) =>
                const Scaffold(body: DiveCenterListContent(showAppBar: true)),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  pushedPath = state.uri.toString();
                  return const Scaffold(body: SizedBox());
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      // Double-tap on a dive center row
      await tester.tap(find.text('Reef Explorers'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Reef Explorers'));
      await tester.pumpAndSettle();

      expect(pushedPath, '/dive-centers/dc1');
    });
  });

  group('phone-mode highlight', () {
    testWidgets(
      'phone detailed view highlights dive center when highlightedDiveCenterIdProvider is set',
      (tester) async {
        final centers = [
          _makeCenter(id: 'c1', name: 'Alpha Dive'),
          _makeCenter(id: 'c2', name: 'Bravo Dive'),
        ];

        final overrides = await _buildPhoneOverrides(
          centers: centers,
          viewMode: ListViewMode.detailed,
          highlightedDiveCenterId: 'c2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const DiveCenterListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<DiveCenterListTile>(find.byType(DiveCenterListTile))
            .toList();
        final alpha = tiles.firstWhere((t) => t.center.id == 'c1');
        final bravo = tiles.firstWhere((t) => t.center.id == 'c2');

        expect(alpha.isSelected, isFalse);
        expect(bravo.isSelected, isTrue);
      },
    );

    testWidgets(
      'phone compact view highlights dive center when highlightedDiveCenterIdProvider is set',
      (tester) async {
        final centers = [
          _makeCenter(id: 'c1', name: 'Alpha Dive'),
          _makeCenter(id: 'c2', name: 'Bravo Dive'),
        ];

        final overrides = await _buildPhoneOverrides(
          centers: centers,
          viewMode: ListViewMode.compact,
          highlightedDiveCenterId: 'c2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const DiveCenterListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<CompactDiveCenterListTile>(
              find.byType(CompactDiveCenterListTile),
            )
            .toList();
        final alpha = tiles.firstWhere((t) => t.center.id == 'c1');
        final bravo = tiles.firstWhere((t) => t.center.id == 'c2');

        expect(alpha.isSelected, isFalse);
        expect(bravo.isSelected, isTrue);
      },
    );
  });

  group('map view navigation', () {
    // Both map buttons must push, not go: go() replaces the stack and leaves
    // the Android system back button with nothing to pop (#647).
    Future<bool> tapMapAction(
      WidgetTester tester, {
      required List<Override> overrides,
      required Widget child,
      required Finder mapButton,
    }) async {
      var reachedMap = false;
      final router = GoRouter(
        initialLocation: '/dive-centers',
        routes: [
          GoRoute(
            path: '/dive-centers',
            builder: (context, state) => child,
            routes: [
              GoRoute(
                path: 'map',
                builder: (context, state) {
                  reachedMap = true;
                  return const Scaffold(body: Text('Map view'));
                },
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(mapButton);
      await tester.pumpAndSettle();

      // The list stays underneath, so back returns to it.
      expect(router.routerDelegate.canPop(), isTrue);
      return reachedMap;
    }

    testWidgets('app bar map action pushes the map view', (tester) async {
      // Table mode short-circuits to its own scaffold, so the app bar action
      // only exists in detailed/compact mode.
      final overrides = await _buildPhoneOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Reef Explorers')],
      );

      final reached = await tapMapAction(
        tester,
        overrides: overrides,
        child: const Scaffold(body: DiveCenterListContent(showAppBar: true)),
        mapButton: find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byIcon(Icons.map),
            )
            .first,
      );

      expect(reached, isTrue);
    });

    testWidgets('compact bar map action pushes the map view', (tester) async {
      final overrides = await _buildPhoneOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Reef Explorers')],
      );

      final reached = await tapMapAction(
        tester,
        overrides: overrides,
        child: const Scaffold(body: DiveCenterListContent(showAppBar: false)),
        mapButton: find.byIcon(Icons.map).first,
      );

      expect(reached, isTrue);
    });
  });
}
