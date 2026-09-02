import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_snapshot.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/nearby_species_tier.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _location = GeoPoint(12.16, -68.28);

ReefSnapshot _snapshotWithUnmatched(List<String> names) => ReefSnapshot(
  habitat: const ReefPart.empty(),
  health: const ReefPart.empty(),
  protection: const ReefPart.empty(),
  species: ReefPart.ok(NearbySpecies(matched: const [], unmatchedNames: names)),
);

class _FakeLookup implements SpeciesLookupService {
  _FakeLookup(this.hits, {this.gate});

  final List<SpeciesLookupHit> hits;
  final List<int> resolved = [];
  final List<String> searched = [];

  /// When set, `search` parks on it so a test can tap again mid-lookup.
  final Completer<void>? gate;

  @override
  Future<List<SpeciesLookupHit>> search(
    String query, {
    required String locale,
  }) async {
    searched.add(query);
    if (gate != null) await gate!.future;
    return hits;
  }

  @override
  Future<SpeciesLookupResult> resolve(
    int taxonId, {
    required String locale,
  }) async {
    resolved.add(taxonId);
    return const SpeciesLookupResult(
      taxonId: 7,
      commonName: 'Stove-pipe Sponge',
      scientificName: 'Aplysina archeri',
      category: SpeciesCategory.invertebrate,
      taxonomyClass: 'Demospongiae',
    );
  }
}

class _RecordingRepository extends Fake implements SpeciesRepository {
  final List<String> created = [];
  final List<String> added = [];

  @override
  Future<List<SiteSpeciesEntry>> getExpectedSpeciesForSite(
    String siteId,
  ) async => const [];

  @override
  Future<Species?> findSpeciesByScientificName(String scientificName) async =>
      null;

  @override
  Future<Species> createSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
    String? taxonomyClass,
    String? description,
  }) async {
    created.add(scientificName ?? commonName);
    return Species(
      id: 'new-1',
      commonName: commonName,
      scientificName: scientificName,
      category: category,
    );
  }

  @override
  Future<SiteSpeciesEntry> addExpectedSpecies({
    required String siteId,
    required String speciesId,
    String notes = '',
  }) async {
    added.add(speciesId);
    return SiteSpeciesEntry(
      id: 'entry-1',
      siteId: siteId,
      speciesId: speciesId,
      speciesName: 'Stove-pipe Sponge',
      category: SpeciesCategory.invertebrate,
      createdAt: DateTime(2026),
    );
  }
}

Widget _harness(_FakeLookup lookup, _RecordingRepository repository) =>
    ProviderScope(
      overrides: [
        reefSnapshotProvider(
          const ReefSnapshotRequest(location: _location),
        ).overrideWith(
          (ref) async => _snapshotWithUnmatched(['Aplysina archeri']),
        ),
        allSpeciesProvider.overrideWith(
          (ref) async => const [
            Species(
              id: 'sp_x',
              commonName: 'Filler',
              category: SpeciesCategory.fish,
            ),
          ],
        ),
        speciesRepositoryProvider.overrideWithValue(repository),
        speciesLookupServiceProvider.overrideWithValue(lookup),
        speciesLookupLocaleProvider.overrideWithValue('en'),
      ],
      child: localizedMaterialApp(
        locale: const Locale('en'),
        home: const Scaffold(
          body: NearbySpeciesTier(siteId: 'site-1', location: _location),
        ),
      ),
    );

const _exact = SpeciesLookupHit(
  taxonId: 7,
  scientificName: 'Aplysina archeri',
  rank: 'species',
  rankLevel: 10,
  commonName: 'Stove-pipe Sponge',
  observationCount: 12,
);

void main() {
  testWidgets('a single exact match creates the species and adds it to the '
      'site without opening the sheet', (tester) async {
    final lookup = _FakeLookup(const [_exact]);
    final repository = _RecordingRepository();
    await tester.pumpWidget(_harness(lookup, repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplysina archeri'));
    await tester.pumpAndSettle();

    expect(lookup.resolved, [7]);
    expect(repository.created, ['Aplysina archeri']);
    expect(repository.added, ['new-1']);
    expect(find.text('Look up a species'), findsNothing);
  });

  testWidgets('a second tap while the lookup is in flight adds the species '
      'once', (tester) async {
    final gate = Completer<void>();
    final lookup = _FakeLookup(const [_exact], gate: gate);
    final repository = _RecordingRepository();
    await tester.pumpWidget(_harness(lookup, repository));
    await tester.pumpAndSettle();

    // The lookup is a network call, so a second tap easily lands before the
    // first one has created anything.
    await tester.tap(find.text('Aplysina archeri'));
    await tester.pump();
    await tester.tap(find.text('Aplysina archeri'));
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(lookup.searched, ['Aplysina archeri']);
    expect(repository.created, ['Aplysina archeri']);
    expect(repository.added, ['new-1']);
  });

  testWidgets('an ambiguous answer opens the sheet prefilled', (tester) async {
    final lookup = _FakeLookup(const [
      _exact,
      // A second taxon carrying the same binomial (a synonym) makes the
      // answer ambiguous.
      SpeciesLookupHit(
        taxonId: 8,
        scientificName: 'Aplysina archeri',
        rank: 'species',
        rankLevel: 10,
        observationCount: 1,
      ),
    ]);
    final repository = _RecordingRepository();
    await tester.pumpWidget(_harness(lookup, repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplysina archeri'));
    await tester.pumpAndSettle();

    expect(find.text('Look up a species'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Aplysina archeri'), findsOneWidget);
    expect(repository.created, isEmpty);
  });
}
