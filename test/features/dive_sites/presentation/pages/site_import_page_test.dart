import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_import_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_search_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_info_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_import_site_card.dart';
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
  ExternalSiteSearchState state, {
  Locale locale = const Locale('en'),
}) async {
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
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const SiteImportPage(),
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

  testWidgets('a card says where the site is as the picker does, island '
      'included', (tester) async {
    await _pump(
      tester,
      const ExternalSiteSearchState(
        query: 'bari',
        sites: [
          CatalogueSite(
            id: 'osm_node_3',
            name: 'Bari Reef',
            country: 'Caribbean Netherlands',
            island: 'Bonaire',
            source: 'osm',
          ),
        ],
      ),
    );

    expect(find.text('Bonaire, Caribbean Netherlands'), findsOneWidget);
  });

  testWidgets('a site with no place says so in the diver\'s language', (
    tester,
  ) async {
    await _pump(
      tester,
      const ExternalSiteSearchState(
        query: 'wreck',
        sites: [CatalogueSite(id: 'osm_node_4', name: 'Wreck', source: 'osm')],
      ),
      locale: const Locale('de'),
    );

    expect(find.text('Standort unbekannt'), findsOneWidget);
    expect(find.text('Location unknown'), findsNothing);
  });

  group('the details of a result', () {
    const wreck = CatalogueSite(
      id: 'osm_node_5',
      name: 'Thistlegorm',
      location: GeoPoint(27.81, 33.92),
      country: 'Egypt',
      minDepth: 16,
      maxDepth: 30,
      typeIds: ['wreck'],
      entryMethods: [EntryMethod.boat],
      hazards: 'Strong current',
      website: 'https://example.org/thistlegorm',
      source: 'osm',
    );

    testWidgets('are the same ones the picker shows: hazards, entry, depth '
        'range and website', (tester) async {
      await _pump(
        tester,
        const ExternalSiteSearchState(query: 'this', sites: [wreck]),
      );

      await tester.tap(find.text('Thistlegorm'));
      await tester.pumpAndSettle();

      expect(find.byType(BuiltInSiteInfoCard), findsOneWidget);
      expect(find.text('Strong current'), findsOneWidget);
      expect(find.text('Boat'), findsOneWidget);
      expect(find.text('16m–30m'), findsOneWidget);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Source: OpenStreetMap contributors'), findsOneWidget);
      expect(find.text('Import to My Sites'), findsOneWidget);
    });

    testWidgets('offer no import for a site the diver already has', (
      tester,
    ) async {
      await _pump(
        tester,
        const ExternalSiteSearchState(
          query: 'this',
          sites: [wreck],
          linkedCatalogueIds: {'osm_node_5'},
        ),
      );

      await tester.tap(find.text('Thistlegorm'));
      await tester.pumpAndSettle();

      expect(find.text('Import to My Sites'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Already Imported'),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  testWidgets('a result card: Import to My Sites closes the details and '
      'imports once', (tester) async {
    var imports = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _Settings()),
          siteCatalogueProvider.overrideWithValue(
            FakeSiteCatalogue(const [_abuDabab], const {'osm': _osm}),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => CatalogueImportSiteCard(
                site: _abuDabab,
                isImported: false,
                units: ref.watch(unitFormatterProvider),
                onImport: () => imports++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abu Dabab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import to My Sites'));
    await tester.pumpAndSettle();

    expect(imports, 1);
    expect(find.byType(BuiltInSiteInfoCard), findsNothing);
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
