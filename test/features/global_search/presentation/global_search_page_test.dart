import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_query_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/global_search_navigation.dart';
import 'package:submersion/features/global_search/presentation/pages/global_search_page.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/core/constants/enums.dart' show SpeciesCategory;
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _StubSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettings() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _query = TextNode(['reef']);

GlobalSearchSection _section(GlobalSearchKind kind, int count, {int? total}) =>
    GlobalSearchSection(
      kind: kind,
      total: total ?? count,
      query: _query,
      hasList: !const {
        GlobalSearchKind.equipmentSets,
        GlobalSearchKind.documents,
        GlobalSearchKind.divePlans,
        GlobalSearchKind.gpsTracks,
        GlobalSearchKind.underwaterRoutes,
      }.contains(kind),
      ids: [for (var i = 0; i < count; i++) 'id$i'],
    );

late SharedPreferences _prefs;
final _now = DateTime(2026, 10, 30);

/// What the Buddies list holds: `Hit 0`, `Hit 1`, and so on.
final _buddies = [
  for (var i = 0; i < 10; i++)
    BuddyWithDiveCount(
      buddy: Buddy(
        id: 'id$i',
        name: 'Hit $i',
        createdAt: _now,
        updatedAt: _now,
      ),
      diveCount: 0,
    ),
];

/// What the equipment sets hold: `Set 0`, `Set 1`, and so on.
final _sets = [
  for (var i = 0; i < 10; i++)
    EquipmentSet(id: 'id$i', name: 'Set $i', createdAt: _now, updatedAt: _now),
];

/// The list routes See all can land on, each a page naming its address.
List<RouteBase> _routes() => [
  GoRoute(path: '/search', builder: (c, s) => const GlobalSearchPage()),
  for (final path in const [
    '/dives',
    '/sites',
    '/trips',
    '/equipment',
    '/buddies',
    '/dive-centers',
    '/certifications',
    '/courses',
    '/species/manage',
    '/buddies/:id',
  ])
    GoRoute(
      path: path,
      builder: (c, s) => Scaffold(body: Text('page ${s.uri.path}')),
    ),
];

Widget _app(
  Future<List<GlobalSearchSection>> Function(String text) answer, {
  List<dynamic> overrides = const [],
}) {
  final router = GoRouter(initialLocation: '/search', routes: _routes());
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      settingsProvider.overrideWith((ref) => _StubSettings()),
      certificationCatalogSyncProvider.overrideWithValue(
        CertificationCatalog.builtInOnly,
      ),
      globalSearchProvider.overrideWith((ref, text) => answer(text)),
      queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
      queryUnitPrefsProvider.overrideWithValue(kMetricPrefs),
      allBuddiesWithDiveCountProvider.overrideWith((ref) async => _buddies),
      equipmentSetsProvider.overrideWith((ref) async => _sets),
      // The other lists stay empty: See all reads the section, not its rows.
      globalSearchDivesProvider.overrideWith((ref, key) async => const []),
      sitesWithCountsProvider.overrideWith((ref) async => const []),
      allTripsWithStatsProvider.overrideWith((ref) async => const []),
      allEquipmentProvider.overrideWith((ref) async => const []),
      allDiveCentersProvider.overrideWith((ref) async => const []),
      allCertificationsProvider.overrideWith((ref) async => const []),
      allCoursesProvider.overrideWith((ref) async => const []),
      allSpeciesProvider.overrideWith((ref) async => const []),
      ...overrides.cast(),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const ValueKey('global-search-field')),
    text,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('prompts before anything is typed, with the field focused', (
    tester,
  ) async {
    await tester.pumpWidget(_app((_) async => const []));
    await tester.pumpAndSettle();

    expect(
      find.text('Find dives, sites, trips, gear, buddies, documents and more'),
      findsOneWidget,
    );
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('global-search-field')),
    );
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('shows a section per record type, with totals', (tester) async {
    await tester.pumpWidget(
      _app(
        (_) async => [
          _section(GlobalSearchKind.buddies, 2),
          _section(GlobalSearchKind.equipmentSets, 1),
        ],
      ),
    );
    await _search(tester, 'reef');

    expect(find.text('Buddies'), findsOneWidget);
    expect(find.text('Equipment Sets'), findsOneWidget);
    expect(find.text('Hit 1'), findsOneWidget);
    expect(find.text('Set 0'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('says so when nothing matches', (tester) async {
    await tester.pumpWidget(_app((_) async => const []));
    await _search(tester, 'nothing');

    expect(find.text('No results for "nothing"'), findsOneWidget);
  });

  testWidgets('explains a refusal the field did not see coming', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        (_) async => throw const GlobalSearchRefused(
          QueryError(QueryErrorCode.unterminatedQuote),
        ),
      ),
    );
    await _search(tester, 'reef');

    expect(find.textContaining('quote'), findsOneWidget);
  });

  group('the query language', () {
    testWidgets('underlines text no record type can read', (tester) async {
      await tester.pumpWidget(_app((_) async => const []));
      await _search(tester, '"oops');

      expect(find.textContaining('quote'), findsOneWidget);
    });

    testWidgets('half a query leaves the last results up', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(
        _app((text) async {
          asked.add(text);
          return [_section(GlobalSearchKind.buddies, 1)];
        }),
      );
      await _search(tester, 'depth > 30m');
      await _search(tester, 'depth >');

      expect(find.text('Hit 0'), findsOneWidget);
      expect(asked, ['depth > 30m']);
    });

    testWidgets('offers the fields of every record type', (tester) async {
      await tester.pumpWidget(_app((_) async => const []));
      await _search(tester, 'expir');

      await tester.tap(find.widgetWithText(ActionChip, 'expiryDate'));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('global-search-field')),
      );
      expect(field.controller!.text, 'expiryDate');
    });

    testWidgets('searches by a field only one record type has', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(
        _app((text) async {
          asked.add(text);
          return const [];
        }),
      );
      await _search(tester, 'expires < 2028');

      expect(asked, ['expires < 2028']);
    });
  });

  testWidgets('reports a failed search', (tester) async {
    await tester.pumpWidget(_app((_) async => throw StateError('boom')));
    await _search(tester, 'reef');

    expect(find.text('Search failed. Please try again.'), findsOneWidget);
  });

  testWidgets('a result opens its record over the results', (tester) async {
    await tester.pumpWidget(
      _app((_) async => [_section(GlobalSearchKind.buddies, 1)]),
    );
    await _search(tester, 'reef');

    await tester.tap(find.text('Hit 0'));
    await tester.pumpAndSettle();
    expect(find.text('page /buddies/id0'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('Hit 0'), findsOneWidget);
  });

  testWidgets('a short section offers no See all', (tester) async {
    await tester.pumpWidget(
      _app((_) async => [_section(GlobalSearchKind.buddies, 5)]),
    );
    await _search(tester, 'reef');

    expect(find.textContaining('See all'), findsNothing);
  });

  testWidgets('a section with no list expands in place', (tester) async {
    await tester.pumpWidget(
      _app((_) async => [_section(GlobalSearchKind.equipmentSets, 7)]),
    );
    await _search(tester, 'reef');

    expect(find.text('Set 4'), findsOneWidget);
    expect(find.text('Set 5'), findsNothing);
    await tester.tap(find.text('See all 7'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Set 6'),
      100,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Set 6'), findsOneWidget);
    expect(find.text('See all 7'), findsNothing);
  });

  testWidgets('a new search starts with its sections collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        (text) async => [
          GlobalSearchSection(
            kind: GlobalSearchKind.equipmentSets,
            total: 7,
            hasList: false,
            query: TextNode([text]),
            ids: _section(GlobalSearchKind.equipmentSets, 7).ids,
          ),
        ],
      ),
    );
    await _search(tester, 'one');
    await tester.tap(find.text('See all 7'));
    await tester.pumpAndSettle();
    expect(find.text('See all 7'), findsNothing);

    await _search(tester, 'two');
    expect(find.text('See all 7'), findsOneWidget);
  });

  group('a request from a list\'s Search everything row', () {
    testWidgets('made before the page opens is searched on arrival', (
      tester,
    ) async {
      final asked = <String>[];
      await tester.pumpWidget(
        _app(
          (text) async {
            asked.add(text);
            return [_section(GlobalSearchKind.buddies, 1)];
          },
          overrides: [
            globalSearchRequestProvider.overrideWith(
              (ref) => GlobalSearchRequest('wreck'),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(asked, ['wreck']);
      expect(find.text('Hit 0'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSearchPage)),
      );
      expect(container.read(globalSearchRequestProvider), isNull);
    });

    testWidgets('made while the page is up replaces its text', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(
        _app((text) async {
          asked.add(text);
          return const [];
        }),
      );
      await _search(tester, 'reef');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSearchPage)),
      );
      container.read(globalSearchRequestProvider.notifier).state =
          GlobalSearchRequest('wreck');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(asked, ['reef', 'wreck']);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('global-search-field')),
      );
      expect(field.controller!.text, 'wreck');
      expect(field.focusNode!.hasFocus, isTrue);
    });
  });

  testWidgets('Esc clears the field and keeps the caret in it', (tester) async {
    await tester.pumpWidget(_app((_) async => const []));
    await _search(tester, 'reef');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('global-search-field')),
    );
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('the focus tick selects the text in the field', (tester) async {
    await tester.pumpWidget(_app((_) async => const []));
    await _search(tester, 'reef');
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('global-search-field')),
    );
    field.focusNode!.unfocus();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GlobalSearchPage)),
    );
    container.read(globalSearchFocusTickProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(field.focusNode!.hasFocus, isTrue);
    expect(field.controller!.selection.textInside('reef'), 'reef');
  });

  group('See all hands the search to the list', () {
    Future<ProviderContainer> seeAll(
      WidgetTester tester,
      GlobalSearchKind kind,
    ) async {
      await tester.pumpWidget(_app((_) async => [_section(kind, 5, total: 9)]));
      await _search(tester, 'reef');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSearchPage)),
      );
      await tester.tap(find.text('See all 9'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('dives', (tester) async {
      final container = await seeAll(tester, GlobalSearchKind.dives);
      expect(find.text('page /dives'), findsOneWidget);
      expect(container.read(diveFilterProvider).query, _query);
    });

    testWidgets('sites', (tester) async {
      final container = await seeAll(tester, GlobalSearchKind.sites);
      expect(find.text('page /sites'), findsOneWidget);
      expect(container.read(siteFilterProvider).query, _query);
    });

    testWidgets('trips', (tester) async {
      final container = await seeAll(tester, GlobalSearchKind.trips);
      expect(find.text('page /trips'), findsOneWidget);
      expect(container.read(tripFilterProvider).query, _query);
    });

    testWidgets('equipment, across every status', (tester) async {
      final container = await seeAll(tester, GlobalSearchKind.equipment);
      expect(find.text('page /equipment'), findsOneWidget);
      final filter = container.read(equipmentFilterProvider);
      expect(filter.query, _query);
      expect(filter.allStatuses, isTrue);
    });

    testWidgets('buddies', (tester) async {
      final container = await seeAll(tester, GlobalSearchKind.buddies);
      expect(find.text('page /buddies'), findsOneWidget);
      expect(container.read(buddyQueryProvider), _query);
    });

    testWidgets('dive centers', (tester) async {
      final container = await seeAll(tester, GlobalSearchKind.diveCenters);
      expect(find.text('page /dive-centers'), findsOneWidget);
      expect(container.read(diveCenterQueryProvider), _query);
    });

    testWidgets('certifications, leaving the attention scope', (tester) async {
      await tester.pumpWidget(
        _app(
          (_) async => [_section(GlobalSearchKind.certifications, 5, total: 9)],
          overrides: [
            certificationAttentionFilterProvider.overrideWith((ref) => true),
          ],
        ),
      );
      await _search(tester, 'reef');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSearchPage)),
      );
      await tester.tap(find.text('See all 9'));
      await tester.pumpAndSettle();

      expect(find.text('page /certifications'), findsOneWidget);
      expect(container.read(certificationQueryProvider), _query);
      expect(container.read(certificationAttentionFilterProvider), isFalse);
    });

    testWidgets('courses', (tester) async {
      final container = await seeAll(tester, GlobalSearchKind.courses);
      expect(find.text('page /courses'), findsOneWidget);
      expect(container.read(courseFilterProvider).query, _query);
    });

    testWidgets('species, to the catalog, its category chip cleared', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app((_) async => [_section(GlobalSearchKind.species, 5, total: 9)]),
      );
      await _search(tester, 'reef');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlobalSearchPage)),
      );
      // A catalog already under the results keeps its chip alive; stand in
      // for it, since the stub page here watches nothing.
      final chip = container.listen(
        speciesCatalogCategoryProvider,
        (previous, next) {},
      );
      addTearDown(chip.close);
      container.read(speciesCatalogCategoryProvider.notifier).state =
          SpeciesCategory.fish;
      await tester.tap(find.text('See all 9'));
      await tester.pumpAndSettle();

      expect(find.text('page /species/manage'), findsOneWidget);
      expect(container.read(speciesCatalogQueryProvider), _query);
      expect(container.read(speciesCatalogCategoryProvider), isNull);
    });
  });

  testWidgets('a kind with no list refuses to open one', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            for (final kind in const [
              GlobalSearchKind.equipmentSets,
              GlobalSearchKind.documents,
              GlobalSearchKind.divePlans,
              GlobalSearchKind.gpsTracks,
              GlobalSearchKind.underwaterRoutes,
            ]) {
              expect(
                () => openGlobalSearchList(context, ref, kind, _query),
                throwsStateError,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  test('every kind has a location', () {
    final locations = {
      for (final kind in GlobalSearchKind.values)
        globalSearchLocation(kind, 'x'),
    };
    expect(locations, hasLength(GlobalSearchKind.values.length));
    expect(locations, contains('/tracks/underwater/x'));
    expect(locations, contains('/planning/dive-planner/x'));
  });
}
