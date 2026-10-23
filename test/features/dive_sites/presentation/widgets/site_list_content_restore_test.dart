import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_grouping_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/master_detail/remembered_selection.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _MockSiteListNotifier extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _MockSiteListNotifier() : super(const AsyncValue.data(<DiveSite>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _sites = [
  for (var i = 0; i < 60; i++)
    SiteWithDiveCount(
      site: DiveSite(id: 's$i', name: 'Site ${i.toString().padLeft(2, '0')}'),
      diveCount: 1,
    ),
];

Finder _tile(String id) =>
    find.byWidgetPredicate((w) => w is SiteListTile && w.entry.site.id == id);

/// The site list as the page sees it, so a test can start it loading.
final _sitesState = StateProvider<AsyncValue<List<SiteWithDiveCount>>>(
  (ref) => AsyncData(_sites),
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required String? highlighted,
  bool startLoading = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(500, 844);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // A router, so a tapped site can open its page as it does on a phone.
  final router = GoRouter(
    initialLocation: '/sites',
    routes: [
      GoRoute(
        path: '/sites',
        builder: (_, _) =>
            const Scaffold(body: SiteListContent(showAppBar: true)),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                Scaffold(body: Text('PAGE ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    testAppRouter(
      router: router,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        _sitesState.overrideWith(
          (ref) => startLoading ? const AsyncLoading() : AsyncData(_sites),
        ),
        sortedSitesWithCountsProvider.overrideWith(
          (ref) => ref.watch(_sitesState),
        ),
        siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
        siteListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        siteGroupByProvider.overrideWith((ref) => SiteGroupBy.none),
        highlightedSiteIdProvider.overrideWith((ref) => highlighted),
      ],
    ),
  );
  // A loading list shows a spinner, which never settles.
  startLoading ? await tester.pump() : await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

/// The site list, built again after the diver left it, comes back to the
/// site they last opened (#3301).
void main() {
  testWidgets('scrolls to the highlighted site', (tester) async {
    await _pump(tester, highlighted: 's50');

    expect(_tile('s50'), findsOneWidget);
    expect(_tile('s0'), findsNothing);
  });

  testWidgets('a list still loading when built comes back once it loads', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      highlighted: 's50',
      startLoading: true,
    );

    container.read(_sitesState.notifier).state = AsyncData(_sites);
    await tester.pumpAndSettle();

    expect(_tile('s50'), findsOneWidget);
  });

  testWidgets('opening a site on a phone forgets a pane closed on it', (
    tester,
  ) async {
    final container = await _pump(tester, highlighted: null);
    container.read(closedPaneRecordProvider.notifier).state = const {
      'sites': 's0',
      'dives': 'd1',
    };

    await tester.tap(_tile('s0'));
    await tester.pumpAndSettle();

    expect(find.text('PAGE s0'), findsOneWidget);
    expect(container.read(closedPaneRecordProvider), {'dives': 'd1'});
  });

  testWidgets('a site the list does not hold leaves it at the top', (
    tester,
  ) async {
    await _pump(tester, highlighted: 'deleted');

    expect(_tile('s0'), findsOneWidget);
  });
}
