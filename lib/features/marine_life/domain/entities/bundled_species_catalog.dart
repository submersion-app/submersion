import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// The bundled species asset: its rows plus the catalog version that gates
/// the re-seed upgrade pass (see SpeciesRepository.seedBuiltInSpecies).
class BundledSpeciesCatalog {
  const BundledSpeciesCatalog({required this.version, required this.species});

  final int version;
  final List<Species> species;
}
