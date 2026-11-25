import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// The bundled species asset: its rows plus the catalog version that gates
/// the re-seed upgrade pass (see SpeciesRepository.seedBuiltInSpecies).
class BundledSpeciesCatalog {
  const BundledSpeciesCatalog({
    required this.version,
    required this.species,
    this.retired = const {},
  });

  final int version;
  final List<Species> species;

  /// Built-in ids the catalog no longer ships, each mapped to the row that
  /// replaces it (issue #4966: four twins of the same animal). The upgrade
  /// pass moves what points at a retired id onto its replacement and deletes
  /// the retired row.
  final Map<String, String> retired;
}
