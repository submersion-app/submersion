import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

void main() {
  const species = Species(
    id: 'sp_whale_shark',
    commonName: 'Whale Shark',
    scientificName: 'Rhincodon typus',
    category: SpeciesCategory.shark,
    isBuiltIn: true,
  );

  SeenSpecies entry() => SeenSpecies(
    species: species,
    totalSightings: 5,
    diveCount: 3,
    siteCount: 2,
    firstSeen: DateTime(2023, 5, 1),
    lastSeen: DateTime(2024, 1, 15),
  );

  test('two entries with the same values are equal', () {
    expect(entry(), equals(entry()));
  });

  test('copyWith replaces only the given fields', () {
    final copy = entry().copyWith(totalSightings: 9, siteCount: 4);

    expect(copy.totalSightings, 9);
    expect(copy.siteCount, 4);
    expect(copy.diveCount, 3);
    expect(copy.species, species);
    expect(copy.firstSeen, DateTime(2023, 5, 1));
    expect(copy.lastSeen, DateTime(2024, 1, 15));
  });
}
