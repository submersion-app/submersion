import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_snapshot.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/nearby_species_tier.dart';

import '../../../../helpers/l10n_test_helpers.dart';

ReefSnapshot _snapshot(ReefPart<NearbySpecies> species) => ReefSnapshot(
  habitat: const ReefPart.empty(),
  health: const ReefPart.empty(),
  protection: const ReefPart.empty(),
  species: species,
);

const _catalogSpecies = Species(
  id: 'sp_whale_shark',
  commonName: 'Whale Shark',
  scientificName: 'Rhincodon typus',
  category: SpeciesCategory.shark,
  isBuiltIn: true,
);

/// Records the ids the tier asks to add, so a tap can be asserted end to end.
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

Widget _harness(
  GeoPoint location,
  ReefSnapshot snapshot, {
  List<Species> catalog = const [_catalogSpecies],
  SpeciesRepository? repository,
}) => ProviderScope(
  overrides: [
    reefSnapshotProvider(
      ReefSnapshotRequest(location: location),
    ).overrideWith((ref) async => snapshot),
    allSpeciesProvider.overrideWith((ref) async => catalog),
    if (repository != null)
      speciesRepositoryProvider.overrideWithValue(repository),
  ],
  child: localizedMaterialApp(
    locale: const Locale('en'),
    home: Scaffold(
      body: NearbySpeciesTier(siteId: 'site-1', location: location),
    ),
  ),
);

void main() {
  testWidgets('renders matched species above unmatched scientific names', (
    tester,
  ) async {
    const location = GeoPoint(12.16, -68.28);
    final snapshot = _snapshot(
      const ReefPart.ok(
        NearbySpecies(
          matched: [
            MatchedNearbySpecies(
              speciesId: 'sp_whale_shark',
              occurrenceCount: 42,
            ),
          ],
          unmatchedNames: ['Aplysina archeri'],
        ),
      ),
    );

    await tester.pumpWidget(_harness(location, snapshot));
    await tester.pumpAndSettle();

    expect(find.textContaining('Recorded nearby'), findsOneWidget);
    // Catalog match renders with its common name, not a bare Latin binomial.
    expect(find.text('Whale Shark'), findsOneWidget);
    expect(find.textContaining('Aplysina archeri'), findsOneWidget);
  });

  testWidgets('renders as chips rather than full-width rows', (tester) async {
    const location = GeoPoint(12.16, -68.28);
    final snapshot = _snapshot(
      const ReefPart.ok(
        NearbySpecies(
          matched: [
            MatchedNearbySpecies(
              speciesId: 'sp_whale_shark',
              occurrenceCount: 42,
            ),
          ],
          unmatchedNames: ['Aplysina archeri'],
        ),
      ),
    );

    await tester.pumpWidget(_harness(location, snapshot));
    await tester.pumpAndSettle();

    expect(find.byType(RawChip), findsNWidgets(2));
    expect(find.byType(ListTile), findsNothing);
  });

  // Issue #1036: a rich reef site returns dozens of records, and rendering
  // them all pushed every section below this one off the page.
  testWidgets('caps the list and reveals the rest on demand', (tester) async {
    const location = GeoPoint(12.16, -68.28);
    final snapshot = _snapshot(
      ReefPart.ok(
        NearbySpecies(
          matched: const [
            MatchedNearbySpecies(
              speciesId: 'sp_whale_shark',
              occurrenceCount: 99,
            ),
          ],
          unmatchedNames: [for (var i = 0; i < 30; i++) 'Genus species$i'],
        ),
      ),
    );

    await tester.pumpWidget(_harness(location, snapshot));
    await tester.pumpAndSettle();

    // The total is surfaced so the count is knowable without expanding.
    expect(find.text('31'), findsOneWidget);
    expect(find.byType(RawChip), findsNWidgets(12));
    expect(find.text('Genus species29'), findsNothing);

    await tester.tap(find.text('Show all 31'));
    await tester.pumpAndSettle();

    expect(find.byType(RawChip), findsNWidgets(31));
    expect(find.text('Genus species29'), findsOneWidget);

    await tester.tap(find.text('Show fewer'));
    await tester.pumpAndSettle();

    expect(find.byType(RawChip), findsNWidgets(12));
  });

  testWidgets('does not offer a toggle when nothing is hidden', (tester) async {
    const location = GeoPoint(12.16, -68.28);
    final snapshot = _snapshot(
      const ReefPart.ok(NearbySpecies(unmatchedNames: ['Aplysina archeri'])),
    );

    await tester.pumpWidget(_harness(location, snapshot));
    await tester.pumpAndSettle();

    expect(find.textContaining('Show all'), findsNothing);
    expect(find.text('Show fewer'), findsNothing);
  });

  testWidgets('matched chips carry the add-to-expected action', (tester) async {
    const location = GeoPoint(12.16, -68.28);
    final snapshot = _snapshot(
      const ReefPart.ok(
        NearbySpecies(
          matched: [
            MatchedNearbySpecies(
              speciesId: 'sp_whale_shark',
              occurrenceCount: 42,
            ),
          ],
          unmatchedNames: ['Aplysina archeri'],
        ),
      ),
    );

    await tester.pumpWidget(_harness(location, snapshot));
    await tester.pumpAndSettle();

    // Only the catalog match is actionable; the long tail has no local id to
    // add, so it must not sprout a dead button.
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('tapping a matched chip adds that species to expected', (
    tester,
  ) async {
    const location = GeoPoint(12.16, -68.28);
    final repository = _RecordingSpeciesRepository();
    final snapshot = _snapshot(
      const ReefPart.ok(
        NearbySpecies(
          matched: [
            MatchedNearbySpecies(
              speciesId: 'sp_whale_shark',
              occurrenceCount: 42,
            ),
          ],
          unmatchedNames: ['Aplysina archeri'],
        ),
      ),
    );

    await tester.pumpWidget(
      _harness(location, snapshot, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    expect(repository.added, ['sp_whale_shark']);
  });

  // Review catch on #1156: routing the add through Chip's delete slot built a
  // separate semantics node holding the tooltip alone, so a screen reader
  // announced "add to expected species" with no way to tell which species.
  // One node must carry the name and the action together.
  testWidgets('the add action and the species name share one semantics node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const location = GeoPoint(12.16, -68.28);
    final snapshot = _snapshot(
      const ReefPart.ok(
        NearbySpecies(
          matched: [
            MatchedNearbySpecies(
              speciesId: 'sp_whale_shark',
              occurrenceCount: 42,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_harness(location, snapshot));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byType(ActionChip).first);
    expect(node.label, contains('Whale Shark'));
    expect(
      node,
      isSemantics(
        tooltip: 'Add to expected species',
        isButton: true,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets('renders nothing when no species were recorded nearby', (
    tester,
  ) async {
    const location = GeoPoint(1, 2);
    await tester.pumpWidget(
      _harness(location, _snapshot(const ReefPart.empty())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RawChip), findsNothing);
    expect(find.textContaining('Recorded nearby'), findsNothing);
  });

  testWidgets('renders nothing when the species provider is unavailable', (
    tester,
  ) async {
    const location = GeoPoint(3, 4);
    await tester.pumpWidget(
      _harness(location, _snapshot(const ReefPart.unavailable())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Recorded nearby'), findsNothing);
  });
}
