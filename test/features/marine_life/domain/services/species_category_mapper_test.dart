import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/domain/services/species_category_mapper.dart';

List<TaxonAncestor> _animal(List<(String, String)> rest) => [
  const TaxonAncestor('kingdom', 'Animalia'),
  const TaxonAncestor('phylum', 'Chordata'),
  for (final (rank, name) in rest) TaxonAncestor(rank, name),
];

void main() {
  test('whale shark: Chondrichthyes without a batoid order is a shark', () {
    final ancestry = _animal([
      ('class', 'Chondrichthyes'),
      ('subclass', 'Elasmobranchii'),
      ('order', 'Orectolobiformes'),
    ]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.shark);
  });

  test('manta ray: Chondrichthyes with Myliobatiformes is a ray', () {
    final ancestry = _animal([
      ('class', 'Chondrichthyes'),
      ('order', 'Myliobatiformes'),
    ]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.ray);
  });

  test('clownfish: Actinopterygii is a fish', () {
    final ancestry = _animal([('class', 'Actinopterygii')]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.fish);
  });

  test('green sea turtle: Testudines is a turtle', () {
    final ancestry = _animal([('class', 'Reptilia'), ('order', 'Testudines')]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.turtle);
  });

  test('dolphin: Mammalia is a mammal', () {
    final ancestry = _animal([('class', 'Mammalia')]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.mammal);
  });

  test('staghorn coral: Anthozoa is coral', () {
    const ancestry = [
      TaxonAncestor('kingdom', 'Animalia'),
      TaxonAncestor('phylum', 'Cnidaria'),
      TaxonAncestor('class', 'Anthozoa'),
      TaxonAncestor('order', 'Scleractinia'),
    ];
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.coral);
  });

  test('magnificent anemone: Anthozoa with Actiniaria is an invertebrate', () {
    const ancestry = [
      TaxonAncestor('kingdom', 'Animalia'),
      TaxonAncestor('class', 'Anthozoa'),
      TaxonAncestor('order', 'Actiniaria'),
    ];
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.invertebrate);
  });

  test('giant kelp (Chromista) and seagrass (Plantae) are plants', () {
    expect(
      speciesCategoryFromAncestry(const [
        TaxonAncestor('kingdom', 'Chromista'),
      ]),
      SpeciesCategory.plant,
    );
    expect(
      speciesCategoryFromAncestry(const [TaxonAncestor('kingdom', 'Plantae')]),
      SpeciesCategory.plant,
    );
  });

  test('sea snake: non-turtle Reptilia is other', () {
    final ancestry = _animal([('class', 'Reptilia'), ('order', 'Squamata')]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.other);
  });

  test('nudibranch: any other animal is an invertebrate', () {
    const ancestry = [
      TaxonAncestor('kingdom', 'Animalia'),
      TaxonAncestor('phylum', 'Mollusca'),
      TaxonAncestor('class', 'Gastropoda'),
    ];
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.invertebrate);
  });

  test('unknown ancestry is other', () {
    expect(speciesCategoryFromAncestry(const []), SpeciesCategory.other);
    expect(
      speciesCategoryFromAncestry(const [TaxonAncestor('kingdom', 'Fungi')]),
      SpeciesCategory.other,
    );
  });
}
