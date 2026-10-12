import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// Finds the species an imported sighting names, creating it only when no
/// existing row fits (issue #3033).
///
/// The scientific name is tried first because it is the same in every
/// language: a French "Pieuvre commune" with *Octopus vulgaris* attaches to
/// the built-in Common Octopus instead of minting a twin. The common name is
/// the fallback, and it never crosses a conflicting scientific name, since
/// two rows called "Octopus" with different binomials are different animals.
///
/// A matched species is never modified; the import only links to it.
class ImportedSpeciesResolver {
  ImportedSpeciesResolver(this._repository);

  final SpeciesRepository _repository;

  Future<Species> resolve({
    required String commonName,
    String? scientificName,
    SpeciesCategory? category,
    String? taxonomyClass,
    String? description,
  }) async {
    final name = commonName.trim();
    final scientific = trimmedOrNull(scientificName);

    if (scientific != null) {
      final match = await _repository.findSpeciesByScientificName(scientific);
      if (match != null) return match;
    }

    final namesakes = await _repository.findSpeciesByCommonName(name);
    for (final candidate in namesakes) {
      if (_compatible(candidate.scientificName, scientific)) return candidate;
    }

    return _repository.createSpecies(
      commonName: name,
      scientificName: scientific,
      category: category ?? SpeciesCategory.other,
      taxonomyClass: trimmedOrNull(taxonomyClass),
      description: trimmedOrNull(description),
    );
  }

  /// Two scientific names conflict only when both are present and differ.
  static bool _compatible(String? existing, String? incoming) {
    final a = trimmedOrNull(existing)?.toLowerCase();
    final b = incoming?.toLowerCase();
    return a == null || b == null || a == b;
  }
}
