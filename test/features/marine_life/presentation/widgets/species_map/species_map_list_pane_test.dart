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

Future<List<String?>> _pump(WidgetTester tester) async {
  final picked = <String?>[];
  await tester.pumpWidget(
    await speciesMapHarness(
      overrides: [
        allSpeciesProvider.overrideWith((ref) async => [_manta, _mola]),
        seenSpeciesProvider.overrideWith(
          (ref) async => [
            SeenSpecies(
              species: _manta,
              totalSightings: 9,
              diveCount: 5,
              siteCount: 2,
              firstSeen: DateTime.utc(2024),
              lastSeen: DateTime.utc(2025),
            ),
          ],
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

  testWidgets('the all sites row clears the pick', (tester) async {
    final picked = await _pump(tester);

    await tester.tap(find.text('All sites'));

    expect(picked, [null]);
  });
}
