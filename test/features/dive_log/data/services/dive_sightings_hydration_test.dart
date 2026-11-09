import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_sightings_hydration.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';

import '../../../../helpers/test_database.dart';

/// The PDF logbook and the UDDF export carry a dive's marine life, which
/// the dive list does not load (issue #4337 follow-up).
void main() {
  late SpeciesRepository species;
  late String jackId;

  setUp(() async {
    await setUpTestDatabase();
    species = SpeciesRepository();
    for (final id in ['d1', 'd2']) {
      await DiveRepository().createDive(
        Dive(id: id, dateTime: DateTime.utc(2026, 3, 1, 9)),
      );
    }
    jackId = (await species.createSpecies(
      commonName: 'Test Jack',
      category: SpeciesCategory.fish,
    )).id;
    await species.addSighting(
      diveId: 'd1',
      speciesId: jackId,
      abundance: SightingAbundance.few,
      notes: 'On the wall',
    );
  });

  tearDown(tearDownTestDatabase);

  test('loads each dive its sightings with name and abundance', () async {
    final byDive = await loadMarineSightings(species, ['d1', 'd2']);

    expect(byDive.keys, ['d1']);
    final sighting = byDive['d1']!.single;
    expect(sighting.speciesId, jackId);
    expect(sighting.speciesName, 'Test Jack');
    expect(sighting.amount, (abundance: SightingAbundance.few, count: 1));
    expect(sighting.notes, 'On the wall');
  });

  test('hydrates the dives it is given, in order', () async {
    final dives = [
      Dive(id: 'd2', dateTime: DateTime.utc(2026, 3, 1, 9)),
      Dive(id: 'd1', dateTime: DateTime.utc(2026, 3, 1, 9)),
    ];

    final hydrated = await hydrateMarineSightings(dives, repository: species);

    expect(hydrated.map((d) => d.id), ['d2', 'd1']);
    expect(hydrated[0].sightings, isEmpty);
    expect(hydrated[1].sightings.single.speciesName, 'Test Jack');
  });

  test('keeps sightings a dive already carries', () async {
    const carried = MarineSighting(
      id: 'm1',
      speciesId: 'x',
      speciesName: 'Already here',
    );
    final dives = [
      Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 3, 1, 9),
        sightings: const [carried],
      ),
    ];

    final hydrated = await hydrateMarineSightings(dives, repository: species);

    expect(hydrated.single.sightings, [carried]);
  });
}
