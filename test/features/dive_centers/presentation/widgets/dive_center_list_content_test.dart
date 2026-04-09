import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

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

void main() {
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
}
