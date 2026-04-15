import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
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

SiteWithDiveCount _makeSite({
  required String id,
  required String name,
  int diveCount = 0,
}) {
  return SiteWithDiveCount(
    site: DiveSite(id: id, name: name),
    diveCount: diveCount,
  );
}

Future<List<Override>> _buildPhoneOverrides({
  required List<SiteWithDiveCount> sites,
  required ListViewMode viewMode,
  String? highlightedSiteId,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    sortedSitesWithCountsProvider.overrideWithValue(AsyncValue.data(sites)),
    siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
    siteListViewModeProvider.overrideWith((ref) => viewMode),
    highlightedSiteIdProvider.overrideWith((ref) => highlightedSiteId),
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

      await tester.longPress(find.text('Alpha Site'));
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
