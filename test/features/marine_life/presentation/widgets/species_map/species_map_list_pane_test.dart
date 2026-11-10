import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_list_pane.dart';

import 'species_map_harness.dart';

const _manta = Species(
  id: 'manta',
  commonName: 'Reef Manta Ray',
  scientificName: 'Mobula alfredi',
  category: SpeciesCategory.ray,
);
const _mola = Species(
  id: 'mola',
  commonName: 'Ocean Sunfish',
  scientificName: 'Mola mola',
  category: SpeciesCategory.fish,
);

SeenSpecies _seenOf(Species species, int sightings) => SeenSpecies(
  species: species,
  totalSightings: sightings,
  diveCount: sightings,
  siteCount: 2,
  firstSeen: DateTime.utc(2024),
  lastSeen: DateTime.utc(2025),
);

Future<List<String?>> _pump(
  WidgetTester tester, {
  List<SeenSpecies>? seen,
  bool seenFails = false,
  bool catalogFails = false,
}) async {
  final picked = <String?>[];
  await tester.pumpWidget(
    await speciesMapHarness(
      overrides: [
        allSpeciesProvider.overrideWith(
          (ref) async =>
              catalogFails ? throw StateError('db') : [_manta, _mola],
        ),
        seenSpeciesProvider.overrideWith(
          (ref) async =>
              seenFails ? throw StateError('db') : seen ?? [_seenOf(_manta, 9)],
        ),
      ],
      child: SpeciesMapListPane(
        selectedSpeciesId: null,
        onSelected: picked.add,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets('lists seen species with their counts', (tester) async {
    await _pump(tester);

    expect(find.text('Reef Manta Ray'), findsOneWidget);
    expect(find.text('9 sightings, 2 sites'), findsOneWidget);
    expect(find.text('Ocean Sunfish'), findsNothing);
  });

  testWidgets('search finds an unseen catalog species, marked Not seen yet', (
    tester,
  ) async {
    final picked = await _pump(tester);

    await tester.enterText(find.byType(TextField), 'mola');
    await tester.pumpAndSettle();

    expect(find.text('Ocean Sunfish'), findsOneWidget);
    expect(find.text('Not seen yet'), findsOneWidget);
    expect(find.text('Reef Manta Ray'), findsNothing);

    await tester.tap(find.text('Ocean Sunfish'));
    expect(picked, ['mola']);
  });

  testWidgets('a failed read says so instead of an empty list', (tester) async {
    await _pump(tester, seenFails: true);

    expect(find.text('Could not load the species map.'), findsOneWidget);
    // The places view stays one tap away.
    expect(find.text('All sites'), findsOneWidget);
  });

  testWidgets('a failed catalog read still lists the seen species', (
    tester,
  ) async {
    // The seen list carries its own species; only the search needs the
    // catalog.
    final picked = await _pump(tester, catalogFails: true);

    expect(find.text('Could not load the species map.'), findsNothing);
    await tester.tap(find.text('Reef Manta Ray'));
    expect(picked, ['manta']);

    await tester.enterText(find.byType(TextField), 'mola');
    await tester.pumpAndSettle();
    expect(find.text('Could not load the species map.'), findsOneWidget);
  });

  testWidgets('a failed seen read still searches the catalog', (tester) async {
    await _pump(tester, seenFails: true);

    await tester.enterText(find.byType(TextField), 'mola');
    await tester.pumpAndSettle();

    expect(find.text('Ocean Sunfish'), findsOneWidget);
    expect(find.text('Could not load the species map.'), findsNothing);
  });

  testWidgets('species seen equally often are listed by name', (tester) async {
    await _pump(tester, seen: [_seenOf(_manta, 3), _seenOf(_mola, 3)]);

    final manta = tester.getTopLeft(find.text('Reef Manta Ray')).dy;
    final mola = tester.getTopLeft(find.text('Ocean Sunfish')).dy;
    expect(mola, lessThan(manta));
  });

  testWidgets('the all sites row clears the pick', (tester) async {
    final picked = await _pump(tester);

    await tester.tap(find.text('All sites'));

    expect(picked, [null]);
  });
}
