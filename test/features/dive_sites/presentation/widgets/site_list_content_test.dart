import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/dense_site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/selection_contract.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void _setMobileTestSurfaceSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(500, 844);

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

final _now = DateTime.now();

SiteWithDiveCount _makeSite({
  required String id,
  required String name,
  int diveCount = 0,
  bool isShared = false,
  double? minDepth,
  double? maxDepth,
}) {
  return SiteWithDiveCount(
    site: DiveSite(
      id: id,
      name: name,
      isShared: isShared,
      minDepth: minDepth,
      maxDepth: maxDepth,
    ),
    diveCount: diveCount,
  );
}

Diver _makeDiver(String id) {
  return Diver(id: id, name: 'Diver $id', createdAt: _now, updatedAt: _now);
}

/// Mutable source for the contract test's filter step, so the visible list
/// can be narrowed mid-test the way a real filter or search would.
final _visibleSitesProvider = StateProvider<List<SiteWithDiveCount>>(
  (ref) => const [],
);

Future<List<Override>> _buildPhoneOverrides({
  required List<SiteWithDiveCount> sites,
  required ListViewMode viewMode,
  String? highlightedSiteId,
  List<Diver>? divers,
  AppSettings? settings,
  SiteFilterState? filter,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (filter != null) siteFilterProvider.overrideWith((ref) => filter),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    sortedSitesWithCountsProvider.overrideWithValue(AsyncValue.data(sites)),
    siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
    siteListViewModeProvider.overrideWith((ref) => viewMode),
    highlightedSiteIdProvider.overrideWith((ref) => highlightedSiteId),
    if (divers != null) allDiversProvider.overrideWith((ref) async => divers),
  ];
}

class _MockSiteListNotifier extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _MockSiteListNotifier() : super(const AsyncValue.data(<DiveSite>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late SharedPreferences prefs;
  late SiteRepository siteRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    siteRepository = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets(
    'merge completion exits multi-select mode and selects the merged survivor',
    (tester) async {
      _setMobileTestSurfaceSize(tester);

      await siteRepository.createSite(
        const DiveSite(id: 'site-1', name: 'Alpha Site'),
      );
      await siteRepository.createSite(
        const DiveSite(id: 'site-2', name: 'Bravo Site'),
      );
      await siteRepository.createSite(
        const DiveSite(id: 'site-3', name: 'Charlie Site'),
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const _SiteListSelectionHarness(),
          ),
          GoRoute(
            path: '/sites/merge',
            builder: (context, state) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      context.pop(const SiteMergeResult(survivorId: 'site-1')),
                  child: const Text('Complete Merge'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            siteRepositoryProvider.overrideWithValue(siteRepository),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha Site'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Bravo Site'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Charlie Site'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.merge_type));
      await tester.pumpAndSettle();
      expect(find.text('Complete Merge'), findsOneWidget);

      await tester.tap(find.text('Complete Merge'));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsNothing);
      expect(find.text('2 selected'), findsNothing);
      expect(find.text('1 selected'), findsNothing);
      expect(find.text('selected:site-1'), findsOneWidget);
      expect(find.text('Dive Sites'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Overflow-menu entry into selection mode (discoverable merge)
  // ---------------------------------------------------------------------------

  group('overflow menu "Select sites"', () {
    testWidgets('enters selection mode from the compact app bar', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [
          _makeSite(id: 's1', name: 'Alpha Site'),
          _makeSite(id: 's2', name: 'Bravo Site'),
        ],
        viewMode: ListViewMode.detailed,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      // No selection UI before opening the menu.
      expect(find.byIcon(Icons.select_all), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select sites'));
      await tester.pumpAndSettle();

      // Selection app bar is now shown (select-all affordance present).
      expect(find.byIcon(Icons.select_all), findsOneWidget);
    });

    testWidgets('enters selection mode from the wide app bar', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final overrides = await _buildPhoneOverrides(
        sites: [
          _makeSite(id: 's1', name: 'Alpha Site'),
          _makeSite(id: 's2', name: 'Bravo Site'),
        ],
        viewMode: ListViewMode.detailed,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.select_all), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select sites'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.select_all), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Phone-mode highlight
  // ---------------------------------------------------------------------------

  group('phone-mode highlight', () {
    testWidgets(
      'phone detailed view highlights site when highlightedSiteIdProvider is set',
      (tester) async {
        final sites = [
          _makeSite(id: 's1', name: 'Alpha Site'),
          _makeSite(id: 's2', name: 'Bravo Site'),
        ];

        final overrides = await _buildPhoneOverrides(
          sites: sites,
          viewMode: ListViewMode.detailed,
          highlightedSiteId: 's2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const SiteListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<SiteListTile>(find.byType(SiteListTile))
            .toList();
        final alpha = tiles.firstWhere((t) => t.name == 'Alpha Site');
        final bravo = tiles.firstWhere((t) => t.name == 'Bravo Site');

        expect(alpha.isSelected, isFalse);
        expect(bravo.isSelected, isTrue);
      },
    );

    testWidgets(
      'phone compact view highlights site when highlightedSiteIdProvider is set',
      (tester) async {
        final sites = [
          _makeSite(id: 's1', name: 'Alpha Site'),
          _makeSite(id: 's2', name: 'Bravo Site'),
        ];

        final overrides = await _buildPhoneOverrides(
          sites: sites,
          viewMode: ListViewMode.compact,
          highlightedSiteId: 's2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const SiteListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<CompactSiteListTile>(find.byType(CompactSiteListTile))
            .toList();
        final alpha = tiles.firstWhere((t) => t.name == 'Alpha Site');
        final bravo = tiles.firstWhere((t) => t.name == 'Bravo Site');

        expect(alpha.isHighlighted, isFalse);
        expect(bravo.isHighlighted, isTrue);
        expect(alpha.isSelected, isFalse);
        expect(bravo.isSelected, isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Shared icon tests — exercises detailed, compact, and dense view modes.
  // ---------------------------------------------------------------------------
  group('shared icon', () {
    testWidgets(
      'detailed view: renders people_outline icon for shared site when 2+ divers',
      (tester) async {
        final sites = [
          _makeSite(id: 's1', name: 'Shared Reef', isShared: true),
          _makeSite(id: 's2', name: 'Private Reef', isShared: false),
        ];

        final overrides = await _buildPhoneOverrides(
          sites: sites,
          viewMode: ListViewMode.detailed,
          divers: [_makeDiver('d1'), _makeDiver('d2')],
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const SiteListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);

        final sharedTile = find.ancestor(
          of: find.text('Shared Reef'),
          matching: find.byType(SiteListTile),
        );
        expect(
          find.descendant(
            of: sharedTile,
            matching: find.byIcon(Icons.people_outline),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'compact view: renders people_outline icon for shared site when 2+ divers',
      (tester) async {
        final sites = [
          _makeSite(id: 's1', name: 'Shared Reef', isShared: true),
          _makeSite(id: 's2', name: 'Private Reef', isShared: false),
        ];

        final overrides = await _buildPhoneOverrides(
          sites: sites,
          viewMode: ListViewMode.compact,
          divers: [_makeDiver('d1'), _makeDiver('d2')],
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const SiteListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);

        final sharedTile = find.ancestor(
          of: find.text('Shared Reef'),
          matching: find.byType(CompactSiteListTile),
        );
        expect(
          find.descendant(
            of: sharedTile,
            matching: find.byIcon(Icons.people_outline),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'dense view: renders people_outline icon for shared site when 2+ divers',
      (tester) async {
        final sites = [
          _makeSite(id: 's1', name: 'Shared Reef', isShared: true),
          _makeSite(id: 's2', name: 'Private Reef', isShared: false),
        ];

        final overrides = await _buildPhoneOverrides(
          sites: sites,
          viewMode: ListViewMode.dense,
          divers: [_makeDiver('d1'), _makeDiver('d2')],
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const SiteListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.people_outline), findsOneWidget);

        final sharedTile = find.ancestor(
          of: find.text('Shared Reef'),
          matching: find.byType(DenseSiteListTile),
        );
        expect(
          find.descendant(
            of: sharedTile,
            matching: find.byIcon(Icons.people_outline),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('does not render icon when only one diver (detailed view)', (
      tester,
    ) async {
      final sites = [_makeSite(id: 's1', name: 'Shared Reef', isShared: true)];

      final overrides = await _buildPhoneOverrides(
        sites: sites,
        viewMode: ListViewMode.detailed,
        divers: [_makeDiver('d1')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.people_outline), findsNothing);
    });

    testWidgets('does not render icon when only one diver (compact view)', (
      tester,
    ) async {
      final sites = [_makeSite(id: 's1', name: 'Shared Reef', isShared: true)];

      final overrides = await _buildPhoneOverrides(
        sites: sites,
        viewMode: ListViewMode.compact,
        divers: [_makeDiver('d1')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.people_outline), findsNothing);
    });

    testWidgets('does not render icon when only one diver (dense view)', (
      tester,
    ) async {
      final sites = [_makeSite(id: 's1', name: 'Shared Reef', isShared: true)];

      final overrides = await _buildPhoneOverrides(
        sites: sites,
        viewMode: ListViewMode.dense,
        divers: [_makeDiver('d1')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.people_outline), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Phone app bar: search, sort, filter, view-mode popup menu.
  // ---------------------------------------------------------------------------
  group('phone app bar actions', () {
    testWidgets('compact app bar (showAppBar=false) exposes key actions', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [_makeSite(id: 's1', name: 'Alpha Site')],
        viewMode: ListViewMode.detailed,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search), findsWidgets);
      expect(find.byIcon(Icons.sort), findsWidgets);
      expect(find.byIcon(Icons.more_vert), findsWidgets);
    });

    testWidgets('tapping sort icon opens sort bottom sheet', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [_makeSite(id: 's1', name: 'Alpha Site')],
        viewMode: ListViewMode.detailed,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.sort).first);
      await tester.pumpAndSettle();
      // Sort sheet should appear.
      expect(find.textContaining('Sort'), findsWidgets);
    });

    testWidgets('tapping more menu opens view mode choices', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [_makeSite(id: 's1', name: 'Alpha Site')],
        viewMode: ListViewMode.detailed,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------
  group('empty state', () {
    testWidgets('renders empty state icon when no sites', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [],
        viewMode: ListViewMode.detailed,
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
      // Empty state icon or message.
      expect(find.byType(SiteListContent), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------
  group('error state', () {
    testWidgets('renders error UI on load error', (tester) async {
      _setMobileTestSurfaceSize(tester);
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        testApp(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(p),
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            currentDiverIdProvider.overrideWith(
              (ref) => MockCurrentDiverIdNotifier(),
            ),
            siteListNotifierProvider.overrideWith(
              (ref) => _MockSiteListNotifier(),
            ),
            siteListViewModeProvider.overrideWith(
              (ref) => ListViewMode.detailed,
            ),
            sortedSitesWithCountsProvider.overrideWithValue(
              AsyncValue.error(Exception('site-list-boom'), StackTrace.current),
            ),
          ],
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Selection mode flows (exercises _toggleSelection, select-all,
  // deselect-all, close selection mode).
  // ---------------------------------------------------------------------------
  group('selection contract', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final all = <SiteWithDiveCount>[
        _makeSite(id: 's1', name: 'Aaa Site'),
        _makeSite(id: 's2', name: 'Bbb Site'),
        _makeSite(id: 's3', name: 'Ccc Site'),
      ];

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final overrides = <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        _visibleSitesProvider.overrideWith((ref) => all),
        // Reads the mutable provider so narrowing it narrows the list.
        sortedSitesWithCountsProvider.overrideWith(
          (ref) => AsyncValue.data(ref.watch(_visibleSitesProvider)),
        ),
        siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
        siteListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        highlightedSiteIdProvider.overrideWith((ref) => null),
      ];

      await verifySelectionContract(
        tester,
        build: () => testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const SiteListContent(showAppBar: true),
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        rowRoot: find.byType(SiteListTile).first,
        firstRow: find.text('Aaa Site'),
        applyFilter: (tester) async {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(SiteListContent)),
          );
          container.read(_visibleSitesProvider.notifier).state = [all.first];
        },
        visibleAfterFilter: 1,
      );
    });
  });

  group('selection mode', () {
    testWidgets(
      'long press enters selection mode and shows selection app bar',
      (tester) async {
        _setMobileTestSurfaceSize(tester);
        await siteRepository.createSite(
          const DiveSite(id: 's1', name: 'First Site'),
        );
        await siteRepository.createSite(
          const DiveSite(id: 's2', name: 'Second Site'),
        );
        await siteRepository.createSite(
          const DiveSite(id: 's3', name: 'Third Site'),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              siteRepositoryProvider.overrideWithValue(siteRepository),
              validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SiteListContent(showAppBar: false)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('enter_selection')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('First Site'));
        await tester.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);

        // Tap select-all.
        await tester.tap(find.byIcon(Icons.select_all));
        await tester.pumpAndSettle();
        expect(find.text('3 selected'), findsOneWidget);

        // Tap deselect-all.
        await tester.tap(find.byIcon(Icons.deselect));
        await tester.pumpAndSettle();
        expect(find.text('0 selected'), findsOneWidget);

        // Tap close to exit selection mode.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.text('0 selected'), findsNothing);
      },
    );

    testWidgets('long-press on a site does not enter selection mode', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await siteRepository.createSite(
        const DiveSite(id: 's1', name: 'Held Site'),
      );
      final opened = <String?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            siteRepositoryProvider.overrideWithValue(siteRepository),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Routed through the callback rather than context.push: with no
            // long-press handler the hold resolves as an ordinary tap on
            // release, which would otherwise try to navigate.
            home: Scaffold(
              body: SiteListContent(
                showAppBar: false,
                onItemSelected: opened.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Held Site'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);
      expect(find.byKey(const ValueKey('enter_selection')), findsOneWidget);
      expect(opened, ['s1']);
    });

    testWidgets('unchecking the last site keeps the deliberate mode open', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      await siteRepository.createSite(
        const DiveSite(id: 's1', name: 'Toggle Site'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            siteRepositoryProvider.overrideWithValue(siteRepository),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SiteListContent(showAppBar: false)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toggle Site'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.text('Toggle Site'));
      await tester.pumpAndSettle();
      // The Select button is a deliberate entry, so emptying the selection
      // leaves the bar standing at zero rather than dropping the user out.
      // Only an implicit entry (modifier-click) evaporates.
      expect(find.text('0 selected'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Item tap with callback
  // ---------------------------------------------------------------------------
  group('item tap callback', () {
    testWidgets('tapping a site with onItemSelected invokes callback', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final sites = [_makeSite(id: 's1', name: 'Callback Site')];
      final overrides = await _buildPhoneOverrides(
        sites: sites,
        viewMode: ListViewMode.detailed,
      );
      String? selectedId;
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: SiteListContent(
            showAppBar: false,
            onItemSelected: (id) => selectedId = id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Callback Site'));
      await tester.pumpAndSettle();
      expect(selectedId, 's1');
    });
  });

  // ---------------------------------------------------------------------------
  // Mini-map background (SiteListTile renders a FlutterMap when the site has a
  // location and the showMapBackgroundOnSiteCards setting is enabled).
  // ---------------------------------------------------------------------------
  group('site card mini-map', () {
    testWidgets('SiteListTile renders a FlutterMap for a located site when map '
        'background is enabled', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...await getBaseOverrides(),
            showMapBackgroundOnSiteCardsProvider.overrideWithValue(true),
          ],
          child: const SiteListTile(
            entry: SiteWithDiveCount(
              site: DiveSite(
                id: 'blue-hole',
                name: 'Blue Hole',
                country: 'Belize',
                location: GeoPoint(17.3155, -87.5346),
              ),
              diveCount: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SiteListTile), findsOneWidget);
      expect(find.byType(FlutterMap), findsWidgets);
    });

    testWidgets(
      'SiteListContent detailed view renders a mini-map for a located site',
      (tester) async {
        _setMobileTestSurfaceSize(tester);
        SharedPreferences.setMockInitialValues({});
        final p = await SharedPreferences.getInstance();

        final sites = [
          const SiteWithDiveCount(
            site: DiveSite(
              id: 's1',
              name: 'Located Reef',
              location: GeoPoint(17.3155, -87.5346),
            ),
            diveCount: 0,
          ),
        ];

        await tester.pumpWidget(
          testApp(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(p),
              settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
              showMapBackgroundOnSiteCardsProvider.overrideWithValue(true),
              currentDiverIdProvider.overrideWith(
                (ref) => MockCurrentDiverIdNotifier(),
              ),
              sortedSitesWithCountsProvider.overrideWithValue(
                AsyncValue.data(sites),
              ),
              siteListNotifierProvider.overrideWith(
                (ref) => _MockSiteListNotifier(),
              ),
              siteListViewModeProvider.overrideWith(
                (ref) => ListViewMode.detailed,
              ),
              highlightedSiteIdProvider.overrideWith((ref) => null),
            ],
            child: const SiteListContent(showAppBar: false),
          ),
        );
        await tester.pump();

        expect(find.byType(FlutterMap), findsWidgets);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Modifier and shift clicks seeded by the highlighted row.
  //
  // A plain click highlights a site without checking it, so the highlight is
  // the user's on-screen selection. Shift and Cmd/Ctrl clicks must both treat
  // it as the origin, the way the dive list does.
  // ---------------------------------------------------------------------------

  group('selection seeded by the highlighted site', () {
    List<SiteWithDiveCount> fourSites() => [
      _makeSite(id: 's1', name: 'Alpha Site'),
      _makeSite(id: 's2', name: 'Bravo Site'),
      _makeSite(id: 's3', name: 'Charlie Site'),
      _makeSite(id: 's4', name: 'Delta Site'),
    ];

    // Cmd on macOS, Control elsewhere -- mirrors
    // SelectableListScope.isModifierPressed so the test passes on both the
    // macOS dev machine and the Linux CI runner.
    final modifierKey = defaultTargetPlatform == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;

    Future<CompactSiteListTile Function(String)> pumpList(
      WidgetTester tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: fourSites(),
        viewMode: ListViewMode.compact,
        highlightedSiteId: 's2',
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      return (String name) => tester
          .widgetList<CompactSiteListTile>(find.byType(CompactSiteListTile))
          .firstWhere((t) => t.name == name);
    }

    testWidgets('shift-tap extends from the highlighted site', (tester) async {
      final tile = await pumpList(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Delta Site'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(tile('Alpha Site').isSelected, isFalse);
      expect(tile('Bravo Site').isSelected, isTrue);
      expect(tile('Charlie Site').isSelected, isTrue);
      expect(tile('Delta Site').isSelected, isTrue);
    });

    testWidgets('modifier-tap checks the highlighted site too', (tester) async {
      final tile = await pumpList(tester);

      await tester.sendKeyDownEvent(modifierKey);
      await tester.tap(find.text('Delta Site'));
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pumpAndSettle();

      expect(tile('Bravo Site').isSelected, isTrue);
      expect(tile('Delta Site').isSelected, isTrue);
      expect(tile('Alpha Site').isSelected, isFalse);
      expect(tile('Charlie Site').isSelected, isFalse);
    });

    // Detailed mode paints the highlight through SiteListTile.isSelected,
    // which -- unlike the compact and dense tiles -- is not gated on being
    // outside selection mode. A highlight left set there is what the user
    // sees as "highlighted, but not selected".
    testWidgets('detailed view leaves no highlighted-but-unchecked row', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: fourSites(),
        viewMode: ListViewMode.detailed,
        highlightedSiteId: 's2',
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(modifierKey);
      await tester.tap(find.text('Delta Site'));
      await tester.sendKeyUpEvent(modifierKey);
      await tester.pumpAndSettle();

      for (final tile in tester.widgetList<SiteListTile>(
        find.byType(SiteListTile),
      )) {
        expect(
          tile.isSelected && !tile.isChecked,
          isFalse,
          reason:
              '${tile.name} reads as highlighted while no bulk action '
              'would touch it',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Depth unit localization (issue #1257)
  // ---------------------------------------------------------------------------

  group('detailed view depth respects the diver depth unit', () {
    testWidgets('renders a max-only depth in feet when the diver is imperial', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [_makeSite(id: 's1', name: 'Alpha Site', maxDepth: 40)],
        viewMode: ListViewMode.detailed,
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      // 40 m -> 131.23 ft, rendered without decimals.
      expect(find.text('131ft'), findsOneWidget);
      expect(find.text('40m'), findsNothing);
    });

    testWidgets('renders a depth range in feet with a single trailing symbol', (
      tester,
    ) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [
          _makeSite(id: 's1', name: 'Alpha Site', minDepth: 5, maxDepth: 30),
        ],
        viewMode: ListViewMode.detailed,
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      // 5 m -> 16.40 ft, 30 m -> 98.43 ft.
      expect(find.text('16-98ft'), findsOneWidget);
    });

    testWidgets('still renders meters for a metric diver', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [
          _makeSite(id: 's1', name: 'Alpha Site', minDepth: 5, maxDepth: 30),
        ],
        viewMode: ListViewMode.detailed,
        settings: const AppSettings(),
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5-30m'), findsOneWidget);
    });
  });

  group('active depth filter chip respects the diver depth unit', () {
    testWidgets('labels a both-ended range in feet', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [_makeSite(id: 's1', name: 'Alpha Site', maxDepth: 20)],
        viewMode: ListViewMode.detailed,
        settings: const AppSettings(depthUnit: DepthUnit.feet),
        // Filter bounds are stored in meters, like every other depth value.
        filter: const SiteFilterState(minDepth: 5, maxDepth: 30),
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('16-98ft'), findsOneWidget);
    });

    testWidgets('labels a max-only bound in feet', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [_makeSite(id: 's1', name: 'Alpha Site', maxDepth: 20)],
        viewMode: ListViewMode.detailed,
        settings: const AppSettings(depthUnit: DepthUnit.feet),
        filter: const SiteFilterState(maxDepth: 30),
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Up to 98ft'), findsOneWidget);
    });

    testWidgets('labels a min-only bound in feet', (tester) async {
      _setMobileTestSurfaceSize(tester);
      final overrides = await _buildPhoneOverrides(
        sites: [_makeSite(id: 's1', name: 'Alpha Site', maxDepth: 20)],
        viewMode: ListViewMode.detailed,
        settings: const AppSettings(depthUnit: DepthUnit.feet),
        filter: const SiteFilterState(minDepth: 5),
      );
      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const SiteListContent(showAppBar: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('16ft+'), findsOneWidget);
    });
  });
}

class _SiteListSelectionHarness extends StatefulWidget {
  const _SiteListSelectionHarness();

  @override
  State<_SiteListSelectionHarness> createState() =>
      _SiteListSelectionHarnessState();
}

class _SiteListSelectionHarnessState extends State<_SiteListSelectionHarness> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text("selected:${_selectedId ?? 'none'}"),
          Expanded(
            child: SiteListContent(
              showAppBar: false,
              selectedId: _selectedId,
              onItemSelected: (id) {
                setState(() {
                  _selectedId = id;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
