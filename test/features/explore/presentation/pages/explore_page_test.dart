import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/presentation/providers/explore_name_index_provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/pages/explore_page.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

import '../../domain/explore_query_parts.dart';

class _Engine implements NlEngine {
  _Engine(this.json, {this.downloadStream});
  final String json;
  final Stream<double> Function()? downloadStream;
  bool prepared = false;
  int compiled = 0;

  @override
  Future<NlAvailability> availability(String localeTag) async =>
      NlAvailability.available;

  @override
  Future<void> prepare() async => prepared = true;

  @override
  Stream<double> download() => downloadStream?.call() ?? const Stream.empty();

  @override
  Future<String> compile(String sentence, {required String localeTag}) async {
    compiled++;
    return json;
  }
}

void main() {
  const turtles =
      '{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth",'
      '"op":"gt","value":20,"unit":"m","text":"below 20m"}],"mentions":'
      '[{"kind":"place","text":"Bonaire"},{"kind":"species","text":"turtles"}],'
      '"time":null,"unplaced":["maybe"]}';

  DiveSummary summary(String id) => DiveSummary(
    id: id,
    diveNumber: 1,
    dateTime: DateTime(2025, 6, 1),
    sortTimestamp: 0,
  );

  List<dynamic> commonOverrides(
    _Engine engine, {
    NlAvailability? availability,
    List<RecentQuery> recent = const [],
  }) => [
    if (availability != null)
      exploreAvailabilityProvider.overrideWith((ref) async => availability),
    nlEngineProvider.overrideWithValue(engine),
    explorePlatformSupportedProvider.overrideWithValue(true),
    localeProvider.overrideWithValue('en'),
    queryUnitPrefsProvider.overrideWithValue(
      const UnitPrefs(
        depth: DepthUnit.meters,
        temperature: TemperatureUnit.celsius,
        pressure: PressureUnit.bar,
        weight: WeightUnit.kilograms,
        volume: VolumeUnit.liters,
      ),
    ),
    exploreNameIndexProvider.overrideWith(
      (ref) async => NameIndex(const [
        NameEntry(
          subject: QuerySubject.sites,
          label: 'Bonaire',
          ids: ['s1', 's2'],
          target: NameTarget.sitePlace,
        ),
        NameEntry(
          subject: QuerySubject.species,
          label: 'Green Turtle',
          ids: ['sp1'],
          target: NameTarget.speciesId,
        ),
        NameEntry(
          subject: QuerySubject.species,
          label: 'Hawksbill Turtle',
          ids: ['sp2'],
          target: NameTarget.speciesId,
        ),
      ]),
    ),
    recentQueryRecorderProvider.overrideWithValue((s, l, p) async {}),
    recentQueriesProvider.overrideWith((ref) async => recent),
    exploreResultsProvider.overrideWith(
      (ref) async => ref.watch(exploreFilterProvider).hasActiveFilters
          ? [summary('d1'), summary('d2')]
          : const [],
    ),
    exploreCountProvider.overrideWith(
      (ref) async => ref.watch(exploreFilterProvider).hasActiveFilters ? 2 : 0,
    ),
    exploreChartDataProvider.overrideWith(
      (ref, req) async => const ExploreChartData(),
    ),
  ];

  Future<(ProviderContainer, _Engine)> pump(WidgetTester tester) async {
    final engine = _Engine(turtles);
    final router = GoRouter(
      initialLocation: '/dives/explore',
      routes: [
        GoRoute(path: '/dives/explore', builder: (_, _) => const ExplorePage()),
        GoRoute(path: '/dives', builder: (_, _) => const Text('dive list')),
        GoRoute(path: '/insights', builder: (_, _) => const Text('insights')),
        GoRoute(
          path: '/dives/:id',
          builder: (_, s) => Text('dive ${s.pathParameters['id']}'),
        ),
      ],
    );
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [...base, ...commonOverrides(engine)],
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ExplorePage)),
    );
    return (container, engine);
  }

  Future<void> ask(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('explore-sentence')),
      'Turtles below 20m in Bonaire',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'prewarms the engine on open and renders understood and attention rows',
    (tester) async {
      final (container, engine) = await pump(tester);
      expect(engine.prepared, isTrue);
      await ask(tester);
      expect(find.text('Depth at least 20m'), findsOneWidget);
      expect(find.text('Bonaire'), findsOneWidget);
      expect(find.text('turtles'), findsOneWidget);
      expect(find.text('maybe'), findsOneWidget);
      expect(find.text('2 dives'), findsOneWidget);
      expect(refIdsIn(container.read(exploreFilterProvider).query, ['site']), [
        's1',
        's2',
      ]);
    },
  );

  testWidgets('keeps Explore\'s name index loaded while the page is up', (
    tester,
  ) async {
    // The notifier only reads the index; the page's listener is what keeps
    // it active, so a dive write reloads the legacy buddy names at once
    // rather than leaving them a tick stale (#2641).
    final (container, _) = await pump(tester);
    expect(container.exists(exploreNameIndexProvider), isTrue);
    expect(container.read(exploreNameIndexProvider).hasValue, isTrue);
  });

  testWidgets('tapping an unresolved chip offers candidates and resolves', (
    tester,
  ) async {
    final (container, _) = await pump(tester);
    await ask(tester);
    await tester.tap(find.text('turtles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Green Turtle').last);
    await tester.pumpAndSettle();
    expect(
      refIdsIn(container.read(exploreFilterProvider).query, [
        'sightings',
        'species',
      ]),
      ['sp1'],
    );
    expect(find.text('turtles'), findsNothing);
  });

  testWidgets('removing a chip recompiles', (tester) async {
    final (container, _) = await pump(tester);
    await ask(tester);
    final chip = find.widgetWithText(InputChip, 'Depth at least 20m');
    await tester.tap(
      find.descendant(of: chip, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();
    expect(
      boundIn(
        container.read(exploreFilterProvider).query,
        'depth',
        QueryOp.gte,
      ),
      isNull,
    );
    expect(refIdsIn(container.read(exploreFilterProvider).query, ['site']), [
      's1',
      's2',
    ]);
  });

  testWidgets('handoffs copy the filter and navigate', (tester) async {
    final (container, _) = await pump(tester);
    await ask(tester);
    await tester.tap(find.text('Open in dive list'));
    await tester.pumpAndSettle();
    expect(refIdsIn(container.read(diveFilterProvider).query, ['site']), [
      's1',
      's2',
    ]);
    expect(find.text('dive list'), findsOneWidget);
  });

  testWidgets('the handoff carries named refs', (tester) async {
    final (container, _) = await pump(tester);
    await ask(tester);
    // "turtles" names two species: the diver picks one, as on the page.
    await tester.tap(find.text('turtles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Green Turtle').last);
    await tester.pumpAndSettle();
    final scope = container.read(exploreQueryNodeProvider);
    expect(scope, isNotNull);
    await tester.tap(find.text('Open in dive list'));
    await tester.pumpAndSettle();
    final handed = container.read(diveFilterProvider);
    expect(handed.query, scope);
    // Only the query: no legacy axis is set beside it.
    expect(handed.minDepth, isNull);
    expect(handed.siteIds, isEmpty);
    final species = conditionsIn(handed.query, [
      'sightings',
      'species',
    ], QueryOp.inList).single;
    // A named ref, so the dive list's chip reads the name and a saved query
    // stores it.
    expect((species.value! as ListValue).items, const [
      RefValue('sp1', 'Green Turtle'),
    ]);
  });

  testWidgets('insights handoff writes the insights filter', (tester) async {
    final (container, _) = await pump(tester);
    await ask(tester);
    await tester.tap(find.text('Open in Insights'));
    await tester.pumpAndSettle();
    expect(
      boundIn(
        container.read(insightsFilterProvider).query,
        'depth',
        QueryOp.gte,
      ),
      20,
    );
    expect(find.text('insights'), findsOneWidget);
  });

  testWidgets('a result tile pushes the dive detail', (tester) async {
    await pump(tester);
    await ask(tester);
    // The results sit below the chart cards in the page's lazy list.
    final tile = find.byKey(const ValueKey('explore-result-d1'));
    await tester.scrollUntilVisible(
      tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('dive d1'), findsOneWidget);
  });

  testWidgets('a downloadable model offers a download and then re-probes', (
    tester,
  ) async {
    final engine = _Engine(turtles);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        child: const ExplorePage(),
        locale: const Locale('en'),
        overrides: [
          ...base,
          ...commonOverrides(engine, availability: NlAvailability.downloadable),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final en = AppLocalizationsEn();
    expect(find.text(en.explore_download_button), findsOneWidget);
    await tester.tap(find.text(en.explore_download_button));
    await tester.pumpAndSettle();
  });

  testWidgets('a download in flight shows progress instead of the button', (
    tester,
  ) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        child: const ExplorePage(),
        locale: const Locale('en'),
        overrides: [
          ...base,
          ...commonOverrides(
            _Engine(turtles),
            availability: NlAvailability.downloading,
          ),
        ],
      ),
    );
    // The progress spinner animates forever, so this never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final en = AppLocalizationsEn();
    expect(find.text(en.explore_download_running), findsOneWidget);
    expect(find.text(en.explore_download_button), findsNothing);
  });

  testWidgets('a recent query re-runs without calling the model', (
    tester,
  ) async {
    final engine = _Engine(turtles);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        child: const ExplorePage(),
        locale: const Locale('en'),
        overrides: [
          ...base,
          ...commonOverrides(
            engine,
            recent: [
              RecentQuery(
                sentence: 'deep dives in Bonaire',
                locale: 'en',
                parsed: ParsedQuery.fromDecoded(jsonDecode(turtles)),
                lastUsedAt: DateTime(2026, 9, 1),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizationsEn().explore_recent_title),
      findsOneWidget,
    );
    await tester.tap(find.text('deep dives in Bonaire'));
    await tester.pumpAndSettle();
    expect(find.text('Depth at least 20m'), findsOneWidget);
    // The stored parse is reused, so the model is never asked again.
    expect(engine.compiled, 0);
  });

  testWidgets('an engine error shows its message and keeps the field', (
    tester,
  ) async {
    final engine = _Engine('{"schemaVersion":9}');
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        child: const ExplorePage(),
        locale: const Locale('en'),
        overrides: [...base, ...commonOverrides(engine)],
      ),
    );
    await tester.pumpAndSettle();
    await ask(tester);
    expect(
      find.text(
        'Could not understand this. Update the app if this keeps happening.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('explore-sentence')), findsOneWidget);
  });

  group('model download', () {
    // Counts availability probes, so a re-probe after the download is
    // visible to the test.
    Future<(int Function(), List<dynamic>)> downloadOverrides(
      _Engine engine,
    ) async {
      var probes = 0;
      final base = await getBaseOverrides();
      return (
        () => probes,
        [
          ...base,
          ...commonOverrides(engine),
          exploreAvailabilityProvider.overrideWith((ref) async {
            probes++;
            return NlAvailability.downloadable;
          }),
        ],
      );
    }

    testWidgets('a failed download re-probes instead of throwing', (
      tester,
    ) async {
      final engine = _Engine(
        turtles,
        downloadStream: () =>
            Stream<double>.error(const NlException(NlError.modelNotReady)),
      );
      final (probes, overrides) = await downloadOverrides(engine);
      await tester.pumpWidget(
        testApp(
          child: const ExplorePage(),
          locale: const Locale('en'),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();
      final before = probes();
      await tester.tap(find.text(AppLocalizationsEn().explore_download_button));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(probes(), greaterThan(before));
    });

    testWidgets('a download finishing after leaving the page is harmless', (
      tester,
    ) async {
      final controller = StreamController<double>();
      final engine = _Engine(turtles, downloadStream: () => controller.stream);
      final (_, overrides) = await downloadOverrides(engine);
      await tester.pumpWidget(
        testApp(
          child: const ExplorePage(),
          locale: const Locale('en'),
          overrides: overrides,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppLocalizationsEn().explore_download_button));
      await tester.pump();
      // Leave Explore: the prompt widget and its ref are disposed.
      await tester.pumpWidget(
        testApp(
          child: const SizedBox.shrink(),
          locale: const Locale('en'),
          overrides: overrides,
        ),
      );
      controller.add(1);
      await controller.close();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
