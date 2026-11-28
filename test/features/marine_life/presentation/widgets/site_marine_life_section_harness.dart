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
import 'package:submersion/features/marine_life/presentation/widgets/site_marine_life_section.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_tier_header.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// The site page's Marine life card on its own, with the species it lists
// given directly: shared by the card's test files (issue #5128).

const whaleShark = Species(
  id: 'sp_whale_shark',
  commonName: 'Whale Shark',
  scientificName: 'Rhincodon typus',
  category: SpeciesCategory.shark,
  isBuiltIn: true,
);

const octopus = Species(
  id: 'sp_octopus',
  commonName: 'Common Octopus',
  scientificName: 'Octopus vulgaris',
  category: SpeciesCategory.invertebrate,
  isBuiltIn: true,
);

const nearbyWhaleShark = NearbySpecies(
  matched: [
    MatchedNearbySpecies(speciesId: 'sp_whale_shark', occurrenceCount: 42),
  ],
  unmatchedNames: [],
);

const cardLocation = GeoPoint(12.16, -68.28);

SiteSpeciesSummary spottedSummary(
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

SiteSpeciesEntry expectedEntry(
  String id,
  String name,
  SpeciesCategory category,
) => SiteSpeciesEntry(
  id: 'entry-$id',
  siteId: 'site-1',
  speciesId: id,
  speciesName: name,
  category: category,
  createdAt: DateTime(2026),
);

/// [n] expected fish named Fish 0, Fish 1, ...
List<SiteSpeciesEntry> expectedFish(int n) => [
  for (var i = 0; i < n; i++)
    expectedEntry('f$i', 'Fish $i', SpeciesCategory.fish),
];

/// Records any expected species written, so a tap that writes is caught.
class RecordingSpeciesRepository extends Fake implements SpeciesRepository {
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

/// Pumps the card for site-1 and settles it.
///
/// [below] stands in for the site page's other cards beneath this one.
/// [boldText] and [textScaler] stand in for the system's accessibility
/// settings, which the card reads through [MediaQuery].
Future<RecordingSpeciesRepository> pumpCard(
  WidgetTester tester, {
  List<SiteSpeciesSummary> spotted = const [],
  List<SiteSpeciesEntry> expected = const [],
  NearbySpecies? nearby = nearbyWhaleShark,
  List<Species> catalog = const [whaleShark],
  GeoPoint? siteLocation = cardLocation,
  double below = 0,
  Locale locale = const Locale('en'),
  bool boldText = false,
  TextScaler? textScaler,
  ThemeData? theme,
}) async {
  final repository = RecordingSpeciesRepository();
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
        reefNearbySpeciesProvider(cardLocation).overrideWith(
          (ref) async => nearby == null
              ? const ReefPart<NearbySpecies>.unavailable()
              : ReefPart<NearbySpecies>.ok(nearby),
        ),
        allSpeciesProvider.overrideWith((ref) async => catalog),
        speciesRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: theme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            boldText: boldText,
            textScaler: textScaler ?? MediaQuery.textScalerOf(context),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// The style [text] (its first occurrence) is painted in.
TextStyle renderedStyle(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text).first).text.style!;

/// The chip whose label is [label].
Rect chipRect(WidgetTester tester, String label) => tester.getRect(
  find.ancestor(of: find.text(label), matching: find.byType(Chip)).first,
);

/// The section header titled [title].
Finder tierHeader(String title) => find.ancestor(
  of: find.text(title),
  matching: find.byType(SpeciesTierHeader),
);

/// Whether the (first) [text] is laid out on a single line.
bool isOneLine(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text).first);
  return paragraph.size.height <=
      paragraph.getMinIntrinsicHeight(double.infinity);
}
