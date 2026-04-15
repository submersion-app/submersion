import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_content.dart';
import 'package:submersion/features/buddies/presentation/widgets/dense_buddy_list_tile.dart';
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

class _TestBuddyTableConfigNotifier
    extends EntityTableConfigNotifier<BuddyField> {
  _TestBuddyTableConfigNotifier(EntityTableViewConfig<BuddyField> config)
    : super(
        defaultConfig: config,
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      );
}

class _MockBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  _MockBuddyListNotifier() : super(const AsyncValue.data(<Buddy>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _testConfig = EntityTableViewConfig<BuddyField>(
  columns: [
    EntityTableColumnConfig(field: BuddyField.buddyName, isPinned: true),
    EntityTableColumnConfig(field: BuddyField.certificationLevel),
    EntityTableColumnConfig(field: BuddyField.certificationAgency),
    EntityTableColumnConfig(field: BuddyField.email),
    EntityTableColumnConfig(field: BuddyField.diveCount),
  ],
);

final _now = DateTime.now();

BuddyWithDiveCount _makeBuddy({
  required String id,
  required String name,
  String? email,
  CertificationLevel? certLevel,
  CertificationAgency? certAgency,
  int diveCount = 0,
}) {
  return BuddyWithDiveCount(
    buddy: Buddy(
      id: id,
      name: name,
      email: email,
      certificationLevel: certLevel,
      certificationAgency: certAgency,
      createdAt: _now,
      updatedAt: _now,
    ),
    diveCount: diveCount,
  );
}

Future<List<Override>> _buildOverrides({
  required List<BuddyWithDiveCount> buddies,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    allBuddiesWithDiveCountProvider.overrideWith((ref) => buddies),
    buddyListNotifierProvider.overrideWith((ref) => _MockBuddyListNotifier()),
    buddyListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    buddyTableConfigProvider.overrideWith(
      (ref) => _TestBuddyTableConfigNotifier(_testConfig),
    ),
  ];
}

Future<List<Override>> _buildPhoneOverrides({
  required List<BuddyWithDiveCount> buddies,
  ListViewMode viewMode = ListViewMode.detailed,
  String? highlightedBuddyId,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    allBuddiesWithDiveCountProvider.overrideWith((ref) => buddies),
    buddyListNotifierProvider.overrideWith((ref) => _MockBuddyListNotifier()),
    buddyListViewModeProvider.overrideWith((ref) => viewMode),
    buddyTableConfigProvider.overrideWith(
      (ref) => _TestBuddyTableConfigNotifier(_testConfig),
    ),
    highlightedBuddyIdProvider.overrideWith((ref) => highlightedBuddyId),
  ];
}

void main() {
  group('BuddyListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final buddies = [
        _makeBuddy(
          id: 'b1',
          name: 'Alice Smith',
          certLevel: CertificationLevel.openWater,
          certAgency: CertificationAgency.padi,
          email: 'alice@example.com',
          diveCount: 10,
        ),
        _makeBuddy(
          id: 'b2',
          name: 'Bob Jones',
          certLevel: CertificationLevel.advancedOpenWater,
          certAgency: CertificationAgency.ssi,
          email: 'bob@example.com',
          diveCount: 25,
        ),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers from the config (displayName values)
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Certification Level'), findsOneWidget);
      expect(find.text('Certification Agency'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Dive Count'), findsOneWidget);
    });

    testWidgets('renders rows for each buddy', (tester) async {
      final buddies = [
        _makeBuddy(id: 'b1', name: 'Alice Smith', diveCount: 10),
        _makeBuddy(id: 'b2', name: 'Bob Jones', diveCount: 25),
        _makeBuddy(id: 'b3', name: 'Carol White', diveCount: 3),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Each buddy name should appear
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Carol White'), findsOneWidget);
    });

    testWidgets('shows empty state when no buddies', (tester) async {
      final overrides = await _buildOverrides(buddies: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Should show the empty state, not a table
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    // Column settings are now provided by TableModeLayout, not the content
    // widget. The compact bar provides sort, search, and view mode controls.

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      // Should still render the buddy name in the table
      expect(find.text('Test Buddy'), findsOneWidget);
    });

    testWidgets('table renders cell data for buddy fields', (tester) async {
      final buddies = [
        _makeBuddy(
          id: 'b1',
          name: 'Alice Smith',
          certLevel: CertificationLevel.openWater,
          certAgency: CertificationAgency.padi,
          email: 'alice@example.com',
          diveCount: 10,
        ),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify actual cell data appears
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('renders buddies with various cert levels', (tester) async {
      final buddies = [
        _makeBuddy(
          id: 'cl1',
          name: 'Diver A',
          certLevel: CertificationLevel.openWater,
          diveCount: 5,
        ),
        _makeBuddy(
          id: 'cl2',
          name: 'Diver B',
          certLevel: CertificationLevel.advancedOpenWater,
          diveCount: 15,
        ),
        _makeBuddy(
          id: 'cl3',
          name: 'Diver C',
          certLevel: CertificationLevel.diveMaster,
          diveCount: 100,
        ),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Diver A'), findsOneWidget);
      expect(find.text('Diver B'), findsOneWidget);
      expect(find.text('Diver C'), findsOneWidget);
    });

    testWidgets('renders buddy with null cert info', (tester) async {
      final buddies = [
        _makeBuddy(
          id: 'nc1',
          name: 'Novice Diver',
          certLevel: null,
          certAgency: null,
          diveCount: 0,
        ),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Novice Diver'), findsOneWidget);
    });

    testWidgets('renders many buddies without crash', (tester) async {
      final buddies = List.generate(
        15,
        (i) => _makeBuddy(id: 'mb$i', name: 'Buddy $i', diveCount: i * 5),
      );

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Buddy 0'), findsOneWidget);
    });

    testWidgets('tapping a row sets highlighted buddy id', (tester) async {
      final buddies = [
        _makeBuddy(id: 'b1', name: 'Alice Smith', diveCount: 10),
        _makeBuddy(id: 'b2', name: 'Bob Jones', diveCount: 25),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

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
                return const Scaffold(body: BuddyListContent(showAppBar: true));
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap on a buddy row (the name cell in the pinned column)
      await tester.tap(find.text('Alice Smith'));
      // Pump past the DoubleTapGestureRecognizer's 300ms timeout so the
      // single-tap callback fires.
      await tester.pump(const Duration(milliseconds: 350));

      // The tap should have set the highlighted buddy ID
      expect(container.read(highlightedBuddyIdProvider), 'b1');
    });

    group('phone-mode highlight', () {
      testWidgets(
        'phone detailed view highlights buddy when highlightedBuddyIdProvider is set',
        (tester) async {
          final buddies = [
            _makeBuddy(id: 'b1', name: 'Alice'),
            _makeBuddy(id: 'b2', name: 'Bob'),
          ];

          final overrides = await _buildPhoneOverrides(
            buddies: buddies,
            viewMode: ListViewMode.detailed,
            highlightedBuddyId: 'b2',
          );

          await tester.pumpWidget(
            testApp(
              overrides: overrides,
              child: const BuddyListContent(showAppBar: false),
            ),
          );
          await tester.pumpAndSettle();

          final tiles = tester
              .widgetList<BuddyListTile>(find.byType(BuddyListTile))
              .toList();
          final alice = tiles.firstWhere((t) => t.buddy.id == 'b1');
          final bob = tiles.firstWhere((t) => t.buddy.id == 'b2');

          expect(alice.isSelected, isFalse);
          expect(bob.isSelected, isTrue);
        },
      );

      testWidgets('phone dense view highlights buddy via isHighlighted param', (
        tester,
      ) async {
        final buddies = [
          _makeBuddy(id: 'b1', name: 'Alice'),
          _makeBuddy(id: 'b2', name: 'Bob'),
        ];

        final overrides = await _buildPhoneOverrides(
          buddies: buddies,
          viewMode: ListViewMode.dense,
          highlightedBuddyId: 'b2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const BuddyListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<DenseBuddyListTile>(find.byType(DenseBuddyListTile))
            .toList();
        final alice = tiles.firstWhere((t) => t.buddy.id == 'b1');
        final bob = tiles.firstWhere((t) => t.buddy.id == 'b2');

        expect(alice.isHighlighted, isFalse);
        expect(bob.isHighlighted, isTrue);
        expect(alice.isSelected, isFalse); // not bulk-checked
        expect(bob.isSelected, isFalse);
      });
    });

    testWidgets('double-tapping a row navigates to buddy detail', (
      tester,
    ) async {
      final buddies = [
        _makeBuddy(id: 'b1', name: 'Alice Smith', diveCount: 10),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      String? pushedPath;
      final router = GoRouter(
        initialLocation: '/buddies',
        routes: [
          GoRoute(
            path: '/buddies',
            builder: (context, state) =>
                const Scaffold(body: BuddyListContent(showAppBar: true)),
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

      // Double-tap on a buddy row
      await tester.tap(find.text('Alice Smith'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Alice Smith'));
      await tester.pumpAndSettle();

      expect(pushedPath, '/buddies/b1');
    });
  });
}
