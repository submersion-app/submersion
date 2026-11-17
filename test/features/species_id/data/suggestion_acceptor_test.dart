import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';

import '../presentation/species_id_fakes.dart';

/// Answers from a fixed list; records what it creates.
class _Species extends SpeciesRepository {
  _Species(this.byId);

  final Map<String, Species> byId;
  final created = <Species>[];

  @override
  Future<Species?> getSpeciesById(String id) async => byId[id];

  @override
  Future<Species?> findSpeciesByScientificName(String scientificName) async {
    for (final s in [...byId.values, ...created]) {
      if (s.scientificName?.toLowerCase() == scientificName.toLowerCase()) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<Species> createSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
    String? taxonomyClass,
    String? description,
  }) async {
    final s = Species(
      id: 'new-${created.length}',
      commonName: commonName,
      scientificName: scientificName,
      category: category,
    );
    created.add(s);
    return s;
  }
}

const _builtIn = Species(
  id: 'sp_queen_parrotfish',
  commonName: 'Queen Parrotfish',
  scientificName: 'Scarus vetula',
  category: SpeciesCategory.fish,
  isBuiltIn: true,
);

void main() {
  test('a catalogue candidate is its catalogue species', () async {
    final repo = _Species({'sp_queen_parrotfish': _builtIn});
    expect(
      await SuggestionAcceptor(species: repo).resolve(parrotfish),
      _builtIn,
    );
    expect(repo.created, isEmpty);
  });

  test(
    'a catalogue species that is gone falls back to the scientific name',
    () async {
      const renamedOwn = Species(
        id: 'own-7',
        commonName: 'My parrotfish',
        scientificName: 'Scarus vetula',
        category: SpeciesCategory.fish,
      );
      final repo = _Species({'own-7': renamedOwn});
      expect(
        await SuggestionAcceptor(species: repo).resolve(parrotfish),
        renamedOwn,
      );
      expect(repo.created, isEmpty);
    },
  );

  test('an unknown species is created from the candidate', () async {
    final repo = _Species({});
    final species = await SuggestionAcceptor(species: repo).resolve(chromis);
    expect(species.commonName, 'Brown Chromis');
    expect(species.scientificName, 'Chromis multilineata');
    expect(species.category, SpeciesCategory.fish);
    expect(repo.created, hasLength(1));
  });
}
