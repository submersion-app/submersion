import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/marine_life/presentation/widgets/site_marine_life_section.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_tier_header.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

const _whaleShark = Species(
  id: 'sp_whale_shark',
  commonName: 'Whale Shark',
  scientificName: 'Rhincodon typus',
  category: SpeciesCategory.shark,
  isBuiltIn: true,
);

const _octopus = Species(
  id: 'sp_octopus',
  commonName: 'Common Octopus',
  scientificName: 'Octopus vulgaris',
  category: SpeciesCategory.invertebrate,
  isBuiltIn: true,
);

const _nearbyWhaleShark = NearbySpecies(
  matched: [
    MatchedNearbySpecies(speciesId: 'sp_whale_shark', occurrenceCount: 42),
  ],
  unmatchedNames: [],
);

SiteSpeciesSummary _spotted(
  String id,
  String name,
  SpeciesCategory category, {
  int count = 1,
}) => SiteSpeciesSummary(
  speciesId: id,
  speciesName: name,
  category: category,
  sightingCount: count,
  animalCount: count,
  diveCount: count,
);

SiteSpeciesEntry _expected(String id, String name, SpeciesCategory category) =>
    SiteSpeciesEntry(
      id: 'entry-$id',
      siteId: 'site-1',
      speciesId: id,
      speciesName: name,
      category: category,
      createdAt: DateTime(2026),
    );

/// Records any expected species written, so a tap that writes is caught.
class _RecordingSpeciesRepository extends Fake implements SpeciesRepository {
  final List<String> added = [];

  @override
  Future<List<SiteSpeciesEntry>> getExpectedSpeciesForSite(
    String siteId,
  ) async => const [];

  @override
  Future<SiteSpeciesEntry> addExpectedSpecies({
    required String siteId,
    required String speciesId,
    String notes = '',
    bool stampLibrary = true,
    String? actingDiverId,
  }) async {
    added.add(speciesId);
    return SiteSpeciesEntry(
      id: 'entry-1',
      siteId: siteId,
      speciesId: speciesId,
      speciesName: 'Whale Shark',
      category: SpeciesCategory.shark,
      createdAt: DateTime(2026),
    );
  }
}

/// The site page's Marine life card shows the site's species only: the lock
/// is the one way to change them (issue #4527, phase 2, plan 7). Its three
/// sections read as sections, each category beside its chips (issue #5128).
void main() {
  final l = AppLocalizationsEn();
  const location = GeoPoint(12.16, -68.28);

  Future<_RecordingSpeciesRepository> pump(
    WidgetTester tester, {
    List<SiteSpeciesSummary> spotted = const [],
    List<SiteSpeciesEntry> expected = const [],
    NearbySpecies? nearby = _nearbyWhaleShark,
    List<Species> catalog = const [_whaleShark],
    GeoPoint? siteLocation = location,
    // The site page's other cards, below this one.
    double below = 0,
  }) async {
    final repository = _RecordingSpeciesRepository();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SiteMarineLifeSection(
                    siteId: 'site-1',
                    location: siteLocation,
                    species: expected,
                  ),
                  SizedBox(height: below),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/species/:id',
          builder: (_, state) => Text('SPECIES ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          siteSpottedSpeciesProvider(
            'site-1',
          ).overrideWith((ref) async => spotted),
          reefNearbySpeciesProvider(location).overrideWith(
            (ref) async => nearby == null
                ? const ReefPart<NearbySpecies>.unavailable()
                : ReefPart<NearbySpecies>.ok(nearby),
          ),
          allSpeciesProvider.overrideWith((ref) async => catalog),
          speciesRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  TextStyle renderedStyle(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text).first).text.style!;

  Rect chipRect(WidgetTester tester, String label) => tester.getRect(
    find.ancestor(of: find.text(label), matching: find.byType(Chip)).first,
  );

  Finder header(String title) => find.ancestor(
    of: find.text(title),
    matching: find.byType(SpeciesTierHeader),
  );

  testWidgets('a species recorded nearby opens its page and adds nothing', (
    tester,
  ) async {
    final repository = await pump(tester);

    expect(find.byTooltip(l.reef_species_addToExpected), findsNothing);
    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(find.text('SPECIES sp_whale_shark'), findsOneWidget);
    expect(repository.added, isEmpty);
  });

  testWidgets('the card has no pencil of its own for the expected species', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(SiteMarineLifeSection),
        matching: find.byIcon(Icons.edit),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'the three section titles share one style, above the category labels',
    (tester) async {
      await pump(
        tester,
        spotted: [_spotted('a', 'Blue Tang', SpeciesCategory.fish)],
        expected: [_expected('b', 'Tarpon', SpeciesCategory.fish)],
      );

      final context = tester.element(find.byType(SiteMarineLifeSection));
      final onSurface = Theme.of(context).colorScheme.onSurface;
      final spotted = renderedStyle(
        tester,
        l.marineLife_siteSection_spottedHere,
      );
      final expectedTitle = renderedStyle(
        tester,
        l.marineLife_siteSection_expectedSpecies,
      );
      final nearby = renderedStyle(tester, l.reef_species_recordedNearby);
      final category = renderedStyle(
        tester,
        SpeciesCategory.fish.localizedName(l),
      );

      for (final title in [spotted, expectedTitle, nearby]) {
        expect(title.fontSize, spotted.fontSize);
        expect(title.fontWeight, spotted.fontWeight);
        expect(title.color, onSurface);
      }
      expect(spotted.fontSize, greaterThan(category.fontSize!));
      // Each title is a heading for assistive tech too, its count read
      // with it rather than as a bare number after it.
      expect(
        tester.getSemantics(find.text(l.marineLife_siteSection_spottedHere)),
        matchesSemantics(
          label: '${l.marineLife_siteSection_spottedHere}\n1',
          isHeader: true,
        ),
      );
    },
  );

  testWidgets('each section title counts the species under it', (tester) async {
    await pump(
      tester,
      spotted: [
        _spotted('a', 'Blue Tang', SpeciesCategory.fish, count: 4),
        _spotted('b', 'Trumpetfish', SpeciesCategory.fish),
        _spotted('c', 'Green Sea Turtle', SpeciesCategory.turtle),
      ],
      expected: [
        _expected('d', 'Tarpon', SpeciesCategory.fish),
        _expected('e', 'Hawksbill Turtle', SpeciesCategory.turtle),
      ],
    );

    expect(
      find.descendant(
        of: header(l.marineLife_siteSection_spottedHere),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: header(l.marineLife_siteSection_expectedSpecies),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: header(l.reef_species_recordedNearby),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a spotted chip is announced once, with its count in words', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      spotted: [_spotted('a', 'Blue Tang', SpeciesCategory.fish, count: 4)],
    );

    expect(
      find.bySemanticsLabel(
        l.marineLife_siteSection_spottedCountSemantics('Blue Tang', 4),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Blue Tang (4)'), findsNothing);
    handle.dispose();
  });

  testWidgets('an empty section counts nothing', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: header(l.marineLife_siteSection_spottedHere),
        matching: find.text('0'),
      ),
      findsNothing,
    );
    expect(find.text(l.marineLife_siteSection_noSpotted), findsOneWidget);
  });

  testWidgets('a divider separates each section from the next', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(SiteMarineLifeSection),
        matching: find.byType(Divider),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('no divider is left for a nearby tier that draws nothing', (
    tester,
  ) async {
    await pump(tester, nearby: null);

    expect(find.text(l.reef_species_recordedNearby), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SiteMarineLifeSection),
        matching: find.byType(Divider),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a category label sits beside its chips, on their first line', (
    tester,
  ) async {
    await pump(
      tester,
      spotted: [
        _spotted('a', 'Blue Tang', SpeciesCategory.fish),
        _spotted('b', 'Trumpetfish', SpeciesCategory.fish),
        _spotted('c', 'Green Sea Turtle', SpeciesCategory.turtle),
      ],
    );

    final fishLabel = tester.getRect(
      find.text(SpeciesCategory.fish.localizedName(l)),
    );
    final turtleLabel = tester.getRect(
      find.text(SpeciesCategory.turtle.localizedName(l)),
    );
    final blueTang = chipRect(tester, 'Blue Tang (1)');
    final turtle = chipRect(tester, 'Green Sea Turtle (1)');

    // Beside: the label ends before its chips start.
    expect(fishLabel.right, lessThanOrEqualTo(blueTang.left));
    expect(turtleLabel.right, lessThanOrEqualTo(turtle.left));
    // On the first line: the label is level with its first chip, so a
    // category of one species takes one line, not two.
    expect(fishLabel.center.dy, closeTo(blueTang.center.dy, 4));
    expect(turtleLabel.center.dy, closeTo(turtle.center.dy, 4));
    expect(turtle.top, greaterThanOrEqualTo(blueTang.bottom));
    // Both categories' chips start in one column.
    expect(turtle.left, blueTang.left);
  });

  testWidgets('a category reads in one colour wherever the card shows it', (
    tester,
  ) async {
    await pump(
      tester,
      spotted: [
        _spotted('x', 'Caribbean Reef Squid', SpeciesCategory.invertebrate),
      ],
      nearby: const NearbySpecies(
        matched: [
          MatchedNearbySpecies(speciesId: 'sp_octopus', occurrenceCount: 3),
        ],
        unmatchedNames: [],
      ),
      catalog: const [_octopus],
    );

    final icons = tester
        .widgetList<Icon>(
          find.byIcon(iconForSpeciesCategory(SpeciesCategory.invertebrate)),
        )
        .toList();
    expect(icons, hasLength(2));
    final brightness = Theme.of(
      tester.element(find.byType(SiteMarineLifeSection)),
    ).brightness;
    for (final icon in icons) {
      expect(
        icon.color,
        colorForSpeciesCategory(SpeciesCategory.invertebrate, brightness),
      );
    }
  });

  testWidgets('a long list on a narrow phone lays out without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(
      tester,
      spotted: [
        for (var i = 0; i < 40; i++)
          _spotted(
            's$i',
            'Long-named Reef Species Number $i',
            SpeciesCategory.values[i % SpeciesCategory.values.length],
            count: i + 1,
          ),
      ],
      expected: [
        for (var i = 0; i < 15; i++)
          _expected(
            'e$i',
            'Expected Species $i',
            SpeciesCategory.values[i % SpeciesCategory.values.length],
          ),
      ],
    );

    expect(tester.takeException(), isNull);
    // The label column stays narrow enough to leave the chips most of it.
    final card = tester.getRect(find.byType(SiteMarineLifeSection));
    final label = tester.getRect(
      find.text(SpeciesCategory.invertebrate.localizedName(l)).first,
    );
    expect(label.width, lessThanOrEqualTo(card.width * 0.35));
  });

  testWidgets('every section starts its chips in one column', (tester) async {
    // Spotted has only a short category name, Expected a long one: the
    // chips still line up down the card.
    await pump(
      tester,
      spotted: [_spotted('a', 'Blue Tang', SpeciesCategory.fish)],
      expected: [
        _expected('b', 'Caribbean Reef Squid', SpeciesCategory.invertebrate),
      ],
    );

    expect(
      chipRect(tester, 'Blue Tang (1)').left,
      chipRect(tester, 'Caribbean Reef Squid').left,
    );
  });

  testWidgets('a long name on a narrow phone wraps and keeps its count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const name = 'Caribbean Reef Squid With A Very Long Name (12)';

    await pump(
      tester,
      spotted: [
        _spotted(
          'a',
          'Caribbean Reef Squid With A Very Long Name',
          SpeciesCategory.invertebrate,
          count: 12,
        ),
      ],
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
    // Not faded out at the chip's edge, which is how a chip cuts a label,
    // but wrapped onto a second line.
    expect(paragraph.debugHasOverflowShader, isFalse);
    expect(
      paragraph.size.height,
      greaterThan(paragraph.getMinIntrinsicHeight(double.infinity)),
    );
    expect(tester.takeException(), isNull);
  });

  group('a long section collapses', () {
    List<SiteSpeciesEntry> expectedFish(int n) => [
      for (var i = 0; i < n; i++)
        _expected('f$i', 'Fish $i', SpeciesCategory.fish),
    ];

    testWidgets('to 12 species, with Show all and Show fewer', (tester) async {
      await pump(tester, expected: expectedFish(20));

      expect(find.text('Fish 11'), findsOneWidget);
      expect(find.text('Fish 12'), findsNothing);
      final showAll = find.text(l.marineLife_speciesDetail_showAll(20));
      expect(showAll, findsOneWidget);

      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      expect(find.text('Fish 19'), findsOneWidget);

      final showFewer = find.text(l.marineLife_speciesDetail_showFewer);
      await tester.ensureVisible(showFewer);
      await tester.tap(showFewer);
      await tester.pumpAndSettle();
      expect(find.text('Fish 12'), findsNothing);
      expect(find.text(l.marineLife_speciesDetail_showAll(20)), findsOneWidget);
    });

    testWidgets('not at all when it holds 12 or fewer', (tester) async {
      await pump(tester, expected: expectedFish(12));

      expect(find.text('Fish 11'), findsOneWidget);
      expect(find.text(l.marineLife_speciesDetail_showAll(12)), findsNothing);
    });

    testWidgets('Spotted and Expected each on their own', (tester) async {
      await pump(
        tester,
        spotted: [
          for (var i = 0; i < 14; i++)
            _spotted('s$i', 'Seen $i', SpeciesCategory.fish),
        ],
        expected: expectedFish(16),
      );

      expect(find.text(l.marineLife_speciesDetail_showAll(14)), findsOneWidget);
      expect(find.text(l.marineLife_speciesDetail_showAll(16)), findsOneWidget);

      final showAll = find.text(l.marineLife_speciesDetail_showAll(14));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      expect(find.text('Seen 13 (1)'), findsOneWidget);
      expect(find.text('Fish 15'), findsNothing);
    });

    testWidgets('dropping a category the limit leaves out entirely', (
      tester,
    ) async {
      await pump(
        tester,
        expected: [
          ...expectedFish(12),
          _expected('t1', 'Hawksbill Turtle', SpeciesCategory.turtle),
        ],
      );

      expect(find.text(SpeciesCategory.turtle.localizedName(l)), findsNothing);
      final showAll = find.text(l.marineLife_speciesDetail_showAll(13));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      expect(
        find.text(SpeciesCategory.turtle.localizedName(l)),
        findsOneWidget,
      );
      expect(find.text('Hawksbill Turtle'), findsOneWidget);
    });

    testWidgets('in the order the chips are drawn, grouped', (tester) async {
      // Listed fish, turtle, fish: drawn as all the fish, then the turtle.
      // The first 12 drawn are fish, so Show all adds the turtle after
      // them rather than slotting it in among those already shown.
      await pump(
        tester,
        expected: [
          ...expectedFish(11),
          _expected('t1', 'Hawksbill Turtle', SpeciesCategory.turtle),
          _expected('f11', 'Fish 11', SpeciesCategory.fish),
          _expected('f12', 'Fish 12', SpeciesCategory.fish),
        ],
      );

      expect(find.text('Fish 11'), findsOneWidget);
      expect(find.text('Hawksbill Turtle'), findsNothing);
    });

    testWidgets('Show fewer at the foot of a long list keeps it in view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, expected: expectedFish(120), below: 3000);

      final showAll = find.text(l.marineLife_speciesDetail_showAll(120));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      final showFewer = find.text(l.marineLife_speciesDetail_showFewer);
      await tester.ensureVisible(showFewer);
      await tester.pumpAndSettle();
      await tester.tap(showFewer);
      await tester.pumpAndSettle();

      final toggle = tester.getRect(
        find.text(l.marineLife_speciesDetail_showAll(120)),
      );
      expect(toggle.top, greaterThanOrEqualTo(0));
      expect(toggle.bottom, lessThanOrEqualTo(600));
    });

    testWidgets('again when another site opens in the same card', (
      tester,
    ) async {
      final siteId = ValueNotifier('site-1');
      addTearDown(siteId.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
            for (final id in ['site-1', 'site-2'])
              siteSpottedSpeciesProvider(
                id,
              ).overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder<String>(
                  valueListenable: siteId,
                  builder: (_, id, _) => SiteMarineLifeSection(
                    siteId: id,
                    species: expectedFish(20),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final showAll = find.text(l.marineLife_speciesDetail_showAll(20));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      expect(find.text('Fish 19'), findsOneWidget);

      siteId.value = 'site-2';
      await tester.pumpAndSettle();
      expect(find.text('Fish 19'), findsNothing);
      expect(find.text(l.marineLife_speciesDetail_showAll(20)), findsOneWidget);
    });
  });
}
