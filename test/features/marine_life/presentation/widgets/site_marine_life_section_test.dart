import 'package:flutter/material.dart';
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
/// is the one way to change them (issue #4527, phase 2, plan 7).
void main() {
  final l = AppLocalizationsEn();
  const location = GeoPoint(12.16, -68.28);

  Future<_RecordingSpeciesRepository> pump(WidgetTester tester) async {
    final repository = _RecordingSpeciesRepository();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(
              child: SiteMarineLifeSection(
                siteId: 'site-1',
                location: location,
                species: [],
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
          ).overrideWith((ref) async => const []),
          reefNearbySpeciesProvider(location).overrideWith(
            (ref) async => const ReefPart<NearbySpecies>.ok(
              NearbySpecies(
                matched: [
                  MatchedNearbySpecies(
                    speciesId: 'sp_whale_shark',
                    occurrenceCount: 42,
                  ),
                ],
                unmatchedNames: [],
              ),
            ),
          ),
          allSpeciesProvider.overrideWith((ref) async => const [_whaleShark]),
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
}
