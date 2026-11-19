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

  Future<Species> resolve(PackCandidate candidate) async =>
      (await resolveWithOrigin(candidate)).species;

  /// [resolve], saying whether the species was created for it (issue
  /// #4727): a tag the app applies records that, so rejecting the tag can
  /// take the species too.
  Future<({Species species, bool created})> resolveWithOrigin(
    PackCandidate candidate,
  ) async {
    final catalogId = candidate.catalogId;
    if (catalogId != null) {
      final builtIn = await _species.getSpeciesById(catalogId);
      if (builtIn != null) return (species: builtIn, created: false);
    }
    final existing = await _species.findSpeciesByScientificName(
      candidate.scientificName,
    );
    if (existing != null) return (species: existing, created: false);
    final created = await _species.createSpecies(
      commonName: candidate.commonName,
      scientificName: candidate.scientificName,
      category: candidate.category,
    );
    return (species: created, created: true);
  }
}
