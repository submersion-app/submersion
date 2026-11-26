import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/query/presentation/providers/entity_search_providers.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_browse_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_gallery_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/life_list_header.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/features/query/presentation/widgets/query_chips_frame.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../media/presentation/support/media_widget_harness.dart';

final _whaleShark = SeenSpecies(
  species: const Species(
    id: 'sp_whale_shark',
    commonName: 'Whale Shark',
    scientificName: 'Rhincodon typus',
    category: SpeciesCategory.shark,
    isBuiltIn: true,
  ),
  totalSightings: 5,
  diveCount: 4,
  siteCount: 2,
  firstSeen: DateTime(2023, 5, 1),
  lastSeen: DateTime(2024, 1, 15),
);

final _turtle = SeenSpecies(
  species: const Species(
    id: 'sp_green_sea_turtle',
    commonName: 'Green Sea Turtle',
    scientificName: 'Chelonia mydas',
    category: SpeciesCategory.turtle,
    isBuiltIn: true,
  ),
  totalSightings: 3,
  diveCount: 3,
  siteCount: 1,
  firstSeen: DateTime(2023, 8, 1),
  lastSeen: DateTime(2024, 6, 1),
);

GoRouter _router() => GoRouter(
  initialLocation: '/species',
  routes: [
    GoRoute(
      path: '/species',
      builder: (context, state) => const SpeciesPage(),
      routes: [
        GoRoute(
          path: 'manage',
          builder: (context, state) =>
              const Scaffold(body: Text('MANAGE PAGE')),
        ),
        GoRoute(
          path: 'map',
          builder: (context, state) => const Scaffold(body: Text('MAP PAGE')),
        ),
        GoRoute(
          path: ':speciesId',
          builder: (context, state) => Scaffold(
            body: Text('DETAIL ${state.pathParameters['speciesId']}'),
          ),
        ),
      ],
    ),
  ],
);

Future<void> _pumpPage(
  WidgetTester tester,
  List<SeenSpecies> entries, {
  Locale locale = const Locale('en'),
  Map<String, MediaItem> covers = const {},
  List<Override> extra = const [],
  VoidCallback? onBestCrops,
  bool settle = true,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testAppRouter(
      router: _router(),
      locale: locale,
      overrides: [
        ...overrides,
        mediaResolverOverride(),
        seenSpeciesProvider.overrideWith((ref) async => entries),
        speciesCoverMediaProvider.overrideWith((ref) async => covers),
        speciesBestCropsProvider.overrideWith((ref) async {
          onBestCrops?.call();
          return const <String, SpeciesCrop>{};
        }),
        speciesCoverCropsProvider.overrideWith(
          (ref) async => const <String, SpeciesCrop>{},
        ),
        speciesCoverPhotosProvider.overrideWith(
          (ref) async => const <String, MediaItem>{},
        ),
        speciesPracticeStatesProvider.overrideWith((ref) async => const {}),
        speciesPlacesProvider.overrideWith(
          (ref) async => const SpeciesPlaces(
            tripsBySpecies: {},
            sitesBySpecies: {},
            firstTripBySpecies: {},
            firstSiteBySpecies: {},
          ),
        ),
        ...extra,
      ],
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

/// Where [text] reads in the grid: by row, then left to right.
double _top(WidgetTester tester, String text) {
  final at = tester.getTopLeft(find.text(text));
  return at.dy * 10000 + at.dx;
}

void main() {
  testWidgets('lists seen species with a summary line', (tester) async {
    await _pumpPage(tester, [_whaleShark, _turtle]);

    expect(find.text('Whale Shark'), findsOneWidget);
    expect(find.text('Green Sea Turtle'), findsOneWidget);
    expect(find.text('2 species · 8 sightings'), findsOneWidget);
  });

  testWidgets('with no model it offers the download (#4773)', (tester) async {
    await _pumpPage(
      tester,
      [_whaleShark],
      extra: [speciesDownloadPromptProvider.overrideWithValue(true)],
    );
    expect(
      find.byKey(const ValueKey('species_download_prompt')),
      findsOneWidget,
    );
  });

  testWidgets('sorts by most dives by default', (tester) async {
    await _pumpPage(tester, [_turtle, _whaleShark]);

    expect(
      _top(tester, 'Whale Shark'),
      lessThan(_top(tester, 'Green Sea Turtle')),
    );
  });

  /// Answers a typed word the way the database would: the species whose
  /// name contains it.
  Override idsByName(List<SeenSpecies> entries) =>
      entityQueryIdsProvider.overrideWith((ref, key) async {
        final node = key.query;
        if (node is! TextNode) return const <String>{};
        return {
          for (final e in entries)
            if (node.words.every(
              (w) => e.species.commonName.toLowerCase().contains(w),
            ))
              e.species.id,
        };
      });

  Future<void> typeInto(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.pump(kEntitySearchDebounce);
    await tester.pumpAndSettle();
  }

  testWidgets('typing narrows the list and clearing restores it', (
    tester,
  ) async {
    final entries = [_whaleShark, _turtle];
    await _pumpPage(tester, entries, extra: [idsByName(entries)]);

    await typeInto(tester, 'turtle');
    expect(find.text('Whale Shark'), findsNothing);
    expect(find.text('Green Sea Turtle'), findsOneWidget);
    expect(find.text('1 species · 3 sightings'), findsOneWidget);

    // The field's own clear, not the chip's delete icon.
    await tester.tap(
      find.descendant(
        of: find.byType(TextField),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pump();
    await tester.pump(kEntitySearchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('Whale Shark'), findsOneWidget);
    expect(find.text('Green Sea Turtle'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing has been logged', (
    tester,
  ) async {
    await _pumpPage(tester, const []);

    expect(find.text('No species yet'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows the no-match state for a query nothing matches', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      [_whaleShark],
      extra: [
        idsByName([_whaleShark]),
      ],
    );

    await typeInto(tester, 'zzz');
    // The query's no-match state, as a filter sheet query shows it.
    expect(find.byType(QueryNoMatchState), findsOneWidget);
  });

  testWidgets('tapping a species opens its detail page', (tester) async {
    await _pumpPage(tester, [_whaleShark]);

    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL sp_whale_shark'), findsOneWidget);
  });

  testWidgets('the map action opens the species map', (tester) async {
    await _pumpPage(tester, [_whaleShark]);

    await tester.tap(find.byKey(const ValueKey('species_map')));
    await tester.pumpAndSettle();
    expect(find.text('MAP PAGE'), findsOneWidget);
  });

  testWidgets('the manage action opens the catalog manager', (tester) async {
    await _pumpPage(tester, [_whaleShark]);

    await tester.tap(find.byKey(const ValueKey('manage_catalog')));
    await tester.pumpAndSettle();
    expect(find.text('MANAGE PAGE'), findsOneWidget);
  });

  testWidgets('search matches the localized name', (tester) async {
    await _pumpPage(tester, [_whaleShark, _turtle], locale: const Locale('de'));
    expect(find.text('Walhai'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'walh');
    await tester.pump();
    expect(find.text('Walhai'), findsOneWidget);
    expect(find.text('Green Sea Turtle'), findsNothing);
  });

  testWidgets('cards show the photo only for species that have one', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      [_whaleShark, _turtle],
      covers: {'sp_whale_shark': testMediaItem(id: 'p1', diveId: 'd1')},
    );

    expect(find.byType(MediaItemView), findsOneWidget);
    expect(find.byKey(const ValueKey('species_category_tile')), findsOneWidget);
  });

  testWidgets('group by persists across rebuilds', (tester) async {
    await _pumpPage(tester, [_whaleShark, _turtle]);
    await tester.tap(find.byKey(const ValueKey('species_group_by_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category').last);
    await tester.pumpAndSettle();

    expect(find.text('Shark · 1 species'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpeciesPage)),
    );
    expect(container.read(speciesGroupByProvider), SpeciesGroupBy.category);
  });

  testWidgets('no-photo chip filters', (tester) async {
    await _pumpPage(
      tester,
      [_whaleShark, _turtle],
      covers: {'sp_whale_shark': testMediaItem(id: 'p1', diveId: 'd1')},
    );
    expect(find.text('1 without a photo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('species_no_photo_chip')));
    await tester.pumpAndSettle();

    expect(find.text('Whale Shark'), findsNothing);
    expect(find.text('Green Sea Turtle'), findsOneWidget);
  });

  testWidgets('header ignores the category filter', (tester) async {
    await _pumpPage(tester, [_whaleShark, _turtle]);
    await tester.tap(find.text('Shark').first);
    await tester.pumpAndSettle();

    expect(find.text('Green Sea Turtle'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(LifeListHeader),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('600 species build without per-card queries', (tester) async {
    var calls = 0;
    final many = [
      for (var i = 0; i < 600; i++)
        _whaleShark.copyWith(
          species: _whaleShark.species.copyWith(id: 'sp_$i', commonName: 'S$i'),
        ),
    ];
    await _pumpPage(tester, many, onBestCrops: () => calls++);

    expect(calls, 1);
    expect(find.text('600 species · 3000 sightings'), findsOneWidget);
  });

  group('query (#2365)', () {
    final sharks = ConditionNode(
      FieldPath(['category']),
      QueryOp.eq,
      const EnumValue('shark'),
    );

    testWidgets('the query narrows the sighted species', (tester) async {
      await _pumpPage(
        tester,
        [_whaleShark, _turtle],
        extra: [
          seenSpeciesQueryProvider.overrideWith((ref) => sharks),
          entityQueryIdsProvider.overrideWith(
            (ref, key) async => {'sp_whale_shark'},
          ),
        ],
      );
      expect(find.text('Whale Shark'), findsOneWidget);
      expect(find.text('Green Sea Turtle'), findsNothing);
      expect(
        find.widgetWithText(InputChip, 'category = shark'),
        findsOneWidget,
      );
    });

    testWidgets('a query that keeps nothing shows the no-match state', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        [_whaleShark, _turtle],
        extra: [
          seenSpeciesQueryProvider.overrideWith((ref) => sharks),
          entityQueryIdsProvider.overrideWith((ref, key) async => const {}),
        ],
      );
      expect(find.byType(QueryNoMatchState), findsOneWidget);
    });
  });

  testWidgets('no photo count waits for the pictures', (tester) async {
    await _pumpPage(
      tester,
      [_whaleShark, _turtle],
      extra: [
        speciesPicturesProvider.overrideWith(
          (ref) => Completer<Map<String, SpeciesPicture>>().future,
        ),
      ],
      settle: false,
    );
    expect(find.byKey(const ValueKey('species_no_photo_chip')), findsNothing);
  });
}
