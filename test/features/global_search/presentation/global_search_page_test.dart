import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_error_code.dart';
import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_query_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/global_search/domain/global_search_models.dart';
import 'package:submersion/features/global_search/presentation/global_search_navigation.dart';
import 'package:submersion/features/global_search/presentation/pages/global_search_page.dart';
import 'package:submersion/features/global_search/presentation/providers/global_search_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
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

GlobalSearchSection _section(
  GlobalSearchKind kind,
  int count, {
  int? total,
  String prefix = 'Hit',
}) => GlobalSearchSection(
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
  hits: [
    for (var i = 0; i < count; i++)
      GlobalSearchHit(kind: kind, id: 'id$i', title: '$prefix $i'),
  ],
);

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
    '/sites/:id',
    '/documents/:id',
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
      settingsProvider.overrideWith((ref) => _StubSettings()),
      certificationCatalogSyncProvider.overrideWithValue(
        CertificationCatalog.builtInOnly,
      ),
      globalSearchProvider.overrideWith((ref, text) => answer(text)),
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
          _section(GlobalSearchKind.sites, 2),
          _section(GlobalSearchKind.buddies, 1, prefix: 'Buddy'),
        ],
      ),
    );
    await _search(tester, 'reef');

    expect(find.text('Sites'), findsOneWidget);
    expect(find.text('Buddies'), findsOneWidget);
    expect(find.text('Hit 1'), findsOneWidget);
    expect(find.text('Buddy 0'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('says so when nothing matches', (tester) async {
    await tester.pumpWidget(_app((_) async => const []));
    await _search(tester, 'nothing');

    expect(find.text('No results for "nothing"'), findsOneWidget);
  });

  testWidgets('explains text no record type can read', (tester) async {
    await tester.pumpWidget(
      _app(
        (_) async => throw const GlobalSearchRefused(
          QueryError(QueryErrorCode.unterminatedQuote),
        ),
      ),
    );
    await _search(tester, '"oops');

    expect(find.textContaining('quote'), findsOneWidget);
  });

  testWidgets('reports a failed search', (tester) async {
    await tester.pumpWidget(_app((_) async => throw StateError('boom')));
    await _search(tester, 'reef');

    expect(find.text('Search failed. Please try again.'), findsOneWidget);
  });

  testWidgets('a result opens its record over the results', (tester) async {
    await tester.pumpWidget(
      _app((_) async => [_section(GlobalSearchKind.sites, 1)]),
    );
    await _search(tester, 'reef');

    await tester.tap(find.text('Hit 0'));
    await tester.pumpAndSettle();
    expect(find.text('page /sites/id0'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.text('Hit 0'), findsOneWidget);
  });

  testWidgets('a short section offers no See all', (tester) async {
    await tester.pumpWidget(
      _app((_) async => [_section(GlobalSearchKind.sites, 5)]),
    );
    await _search(tester, 'reef');

    expect(find.textContaining('See all'), findsNothing);
  });

  testWidgets('a section with no list expands in place', (tester) async {
    await tester.pumpWidget(
      _app((_) async => [_section(GlobalSearchKind.documents, 7)]),
    );
    await _search(tester, 'reef');

    expect(find.text('Hit 4'), findsOneWidget);
    expect(find.text('Hit 5'), findsNothing);
    await tester.tap(find.text('See all 7'));
    await tester.pumpAndSettle();
    expect(find.text('Hit 6'), findsOneWidget);
    expect(find.text('See all 7'), findsNothing);
  });

  testWidgets('a new search starts with its sections collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        (text) async => [
          GlobalSearchSection(
            kind: GlobalSearchKind.documents,
            total: 7,
            hasList: false,
            query: TextNode([text]),
            hits: _section(GlobalSearchKind.documents, 7).hits,
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

    testWidgets('species, to the catalog', (tester) async {
      final container = await seeAll(tester, GlobalSearchKind.species);
      expect(find.text('page /species/manage'), findsOneWidget);
      expect(container.read(speciesCatalogQueryProvider), _query);
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
        globalSearchHitLocation(GlobalSearchHit(kind: kind, id: 'x')),
    };
    expect(locations, hasLength(GlobalSearchKind.values.length));
    expect(locations, contains('/tracks/underwater/x'));
    expect(locations, contains('/planning/dive-planner/x'));
  });
}
