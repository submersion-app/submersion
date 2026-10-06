import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_grouping_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/select_items_menu.dart';
import '../../../../helpers/test_app.dart';

SiteWithDiveCount _site(
  String id,
  String name, {
  String? country,
  String? region,
}) => SiteWithDiveCount(
  site: DiveSite(id: id, name: name, country: country, region: region),
  diveCount: 0,
);

final _sites = [
  _site('au1', 'Cod Hole', country: 'Australia', region: 'Queensland'),
  _site('eg1', 'Blue Hole', country: 'Egypt'),
  _site('xx1', 'Mystery Lake'),
];

/// A country header by its label; a site row can repeat the same word in its
/// location line.
Finder _header(String label) => find.widgetWithText(SiteCountryHeader, label);

String _key(String country) =>
    siteCountryKey(DiveSite(id: 'x', name: 'x', country: country));

class _MockSiteListNotifier extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _MockSiteListNotifier() : super(const AsyncValue.data(<DiveSite>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pumpGrouped(
  WidgetTester tester, {
  ListViewMode viewMode = ListViewMode.detailed,
  SiteGroupBy groupBy = SiteGroupBy.location,
  String? selectedId,
  String? highlightedId,
  List<SiteWithDiveCount>? sites,
  Set<String>? storedExpansion,
  bool showAppBar = true,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(500, 844);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        sortedSitesWithCountsProvider.overrideWithValue(
          AsyncValue.data(sites ?? _sites),
        ),
        siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
        siteListViewModeProvider.overrideWith((ref) => viewMode),
        highlightedSiteIdProvider.overrideWith((ref) => highlightedId),
        siteGroupByProvider.overrideWith((ref) => groupBy),
        if (storedExpansion != null)
          siteListExpandedCountriesProvider.overrideWith(
            (ref) => storedExpansion,
          ),
      ],
      child: SiteListContent(showAppBar: showAppBar, selectedId: selectedId),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('grouped list starts collapsed with country headers', (
    tester,
  ) async {
    await _pumpGrouped(tester);
    expect(find.text('Australia'), findsOneWidget);
    expect(find.text('Egypt'), findsOneWidget);
    expect(find.text('No country'), findsOneWidget);
    expect(find.byType(SiteListTile), findsNothing);

    await tester.tap(_header('Australia'));
    await tester.pumpAndSettle();
    expect(find.text('Queensland'), findsOneWidget);
    expect(find.byType(SiteListTile), findsOneWidget);
    expect(find.text('Cod Hole'), findsOneWidget);
  });

  testWidgets('ungrouped by default lists every site flat', (tester) async {
    await _pumpGrouped(tester, groupBy: SiteGroupBy.none);
    expect(find.text('Australia'), findsNothing);
    expect(find.byType(SiteListTile), findsNWidgets(3));
  });

  testWidgets('opens the country of the site shown in the detail pane', (
    tester,
  ) async {
    await _pumpGrouped(tester, selectedId: 'eg1');
    expect(find.byType(SiteListTile), findsOneWidget);
    expect(find.text('Blue Hole'), findsWidgets);
  });

  testWidgets('expansion is kept in a provider across rebuilds', (
    tester,
  ) async {
    await _pumpGrouped(tester);
    await tester.tap(_header('Egypt'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SiteListContent)),
    );
    expect(
      container.read(siteListExpandedCountriesProvider),
      contains(_key('Egypt')),
    );

    await tester.tap(_header('Egypt'));
    await tester.pumpAndSettle();
    expect(
      container.read(siteListExpandedCountriesProvider),
      isNot(contains(_key('Egypt'))),
    );
    expect(find.byType(SiteListTile), findsNothing);
  });

  testWidgets('compact mode groups too', (tester) async {
    await _pumpGrouped(tester, viewMode: ListViewMode.compact);
    await tester.tap(_header('No country'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactSiteListTile), findsOneWidget);
  });

  testWidgets('a header tap in selection mode toggles, never selects', (
    tester,
  ) async {
    await _pumpGrouped(tester, showAppBar: false);
    await tester.tap(_header('Egypt'));
    await tester.pumpAndSettle();
    await enterSelectionViaMenu(tester);
    await tester.tap(find.text('Blue Hole'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(_header('Australia'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Queensland'), findsOneWidget);
  });

  testWidgets('select all includes sites in collapsed groups', (tester) async {
    await _pumpGrouped(tester, showAppBar: false);
    await tester.tap(_header('Egypt'));
    await tester.pumpAndSettle();
    await enterSelectionViaMenu(tester);
    await tester.tap(find.text('Blue Hole'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
  });

  testWidgets('the sort sheet offers Group by outside table mode', (
    tester,
  ) async {
    await _pumpGrouped(tester, groupBy: SiteGroupBy.none);
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    expect(find.text('Group by'), findsOneWidget);

    await tester.tap(find.text('Country & region'));
    await tester.pumpAndSettle();
    expect(find.text('Group by'), findsNothing);
    expect(find.text('Australia'), findsOneWidget);
    expect(find.byType(SiteListTile), findsNothing);
  });

  // Table mode's sort button is on SiteListPage's own header, which passes
  // no footer, so it never offers Group by; the grid itself must stay flat.
  testWidgets('table mode stays flat even when grouping is on', (tester) async {
    await _pumpGrouped(tester, viewMode: ListViewMode.table);
    expect(_header('Australia'), findsNothing);
    expect(find.text('Cod Hole'), findsOneWidget);
  });

  testWidgets('shift-click never selects sites in a collapsed group', (
    tester,
  ) async {
    await _pumpGrouped(
      tester,
      showAppBar: false,
      highlightedId: 'au1',
      sites: [
        _site('au1', 'Cod Hole', country: 'Australia'),
        _site('bz1', 'Great Blue Hole', country: 'Belize'),
        _site('bz2', 'Turneffe Wall', country: 'Belize'),
        _site('eg1', 'Blue Hole', country: 'Egypt'),
      ],
    );
    await tester.tap(_header('Australia'));
    await tester.pumpAndSettle();
    await tester.tap(_header('Egypt'));
    await tester.pumpAndSettle();
    expect(find.text('Great Blue Hole'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Blue Hole'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    // Belize stays collapsed, so its two sites are not part of the range.
    expect(find.text('2 selected'), findsOneWidget);
  });

  // A site selected from outside the list (map, a new site, a deep link)
  // must not stay hidden in a country the diver collapsed earlier.
  testWidgets('an outside selection opens its collapsed country', (
    tester,
  ) async {
    await _pumpGrouped(tester, selectedId: 'eg1', storedExpansion: const {});
    expect(find.byType(SiteListTile), findsOneWidget);
    expect(find.text('Blue Hole'), findsWidgets);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SiteListContent)),
    );
    expect(
      container.read(siteListExpandedCountriesProvider),
      contains(_key('Egypt')),
    );
  });
}
