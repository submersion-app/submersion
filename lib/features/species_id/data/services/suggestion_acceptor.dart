import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';

/// Turns a suggested candidate into the species to tag (issue #4668), in
/// the order the species picker uses when it creates one: the built-in
/// catalogue species; else one already in the catalogue with the same
/// scientific name; else a new species of the diver's own.
class SuggestionAcceptor {
  SuggestionAcceptor({required SpeciesRepository species}) : _species = species;

  final SpeciesRepository _species;

  Future<Species> resolve(PackCandidate candidate) async {
    final catalogId = candidate.catalogId;
    if (catalogId != null) {
      final builtIn = await _species.getSpeciesById(catalogId);
      if (builtIn != null) return builtIn;
    }
    final existing = await _species.findSpeciesByScientificName(
      candidate.scientificName,
    );
    if (existing != null) return existing;
    return _species.createSpecies(
      commonName: candidate.commonName,
      scientificName: candidate.scientificName,
      category: candidate.category,
    );
  }
}
