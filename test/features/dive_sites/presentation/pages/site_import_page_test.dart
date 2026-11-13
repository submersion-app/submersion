import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_import_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_search_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_site_catalogue.dart';

const _osm = CatalogueSource(
  key: 'osm',
  name: 'OpenStreetMap',
  licence: 'ODbL-1.0',
  credit: 'OpenStreetMap contributors',
);

const _abuDabab = CatalogueSite(
  id: 'osm_node_1',
  name: 'Abu Dabab',
  location: GeoPoint(25.34, 34.74),
  country: 'Egypt',
  bodyOfWater: 'Red Sea',
  typeIds: ['reef'],
  source: 'osm',
);
const _elphinstone = CatalogueSite(
  id: 'osm_node_2',
  name: 'Elphinstone',
  location: GeoPoint(25.31, 34.86),
  country: 'Egypt',
  bodyOfWater: 'Red Sea',
  source: 'osm',
);

class _Settings extends StateNotifier<AppSettings> implements SettingsNotifier {
  _Settings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The page's search, holding the results a test gives it and recording
/// what the page asks for.
class _SeededSearch extends StateNotifier<ExternalSiteSearchState>
    implements ExternalSiteSearchNotifier {
  _SeededSearch(super.state);

  final searches = <String>[];

  @override
  Future<void> search(String query) async => searches.add(query);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_SeededSearch> _pump(
  WidgetTester tester,
  ExternalSiteSearchState state,
) async {
  final search = _SeededSearch(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _Settings()),
        siteCatalogueProvider.overrideWithValue(
          FakeSiteCatalogue(
            const [_abuDabab, _elphinstone],
            const {'osm': _osm},
          ),
        ),
        externalSiteSearchProvider.overrideWith((ref) => search),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SiteImportPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return search;
}

/// The "Import from Database" page: what it shows for a search of the
/// built-in catalogue.
void main() {
  const found = ExternalSiteSearchState(
    query: 'Red Sea',
    sites: [_abuDabab, _elphinstone],
  );

  testWidgets('lists the catalogue matches under their count', (tester) async {
    await _pump(tester, found);

    expect(find.text('Import from Database (2)'), findsOneWidget);
    expect(find.text('Abu Dabab'), findsOneWidget);
    expect(find.text('Elphinstone'), findsOneWidget);
  });

  testWidgets('says when the catalogue has more matches than it lists', (
    tester,
  ) async {
    await _pump(
      tester,
      const ExternalSiteSearchState(
        query: 'Red Sea',
        sites: [_abuDabab, _elphinstone],
        isTruncated: true,
      ),
    );

    expect(
      find.text(
        'Showing the first 2 sites. Search for something more specific to '
        'see the rest.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('says nothing of the kind when every match is listed', (
    tester,
  ) async {
    await _pump(tester, found);

    expect(find.textContaining('Showing the first'), findsNothing);
  });

  testWidgets('a site the diver already has reads Imported, the rest offer '
      'Import', (tester) async {
    await _pump(
      tester,
      const ExternalSiteSearchState(
        query: 'Red Sea',
        sites: [_abuDabab, _elphinstone],
        linkedCatalogueIds: {'osm_node_1'},
      ),
    );

    final abuDabab = find.ancestor(
      of: find.text('Abu Dabab'),
      matching: find.byType(Card),
    );
    final elphinstone = find.ancestor(
      of: find.text('Elphinstone'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: abuDabab, matching: find.text('Imported')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: abuDabab, matching: find.text('Import')),
      findsNothing,
    );
    expect(
      find.descendant(of: elphinstone, matching: find.text('Import')),
      findsOneWidget,
    );
  });

  testWidgets('a quick-search chip searches for its place', (tester) async {
    final search = await _pump(tester, const ExternalSiteSearchState());

    await tester.tap(find.text('Red Sea'));
    await tester.pumpAndSettle();

    expect(search.searches, ['Red Sea']);
  });

  testWidgets('a search with no match says so', (tester) async {
    await _pump(tester, const ExternalSiteSearchState(query: 'Atlantis'));

    expect(find.text('No Results'), findsOneWidget);
  });
}
