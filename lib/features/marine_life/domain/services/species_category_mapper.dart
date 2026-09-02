import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

/// Batoid orders under Chondrichthyes; everything else in the class is a
/// shark (or a chimaera, which divers file with the sharks).
const Set<String> _batoidOrders = {
  'Rajiformes',
  'Myliobatiformes',
  'Torpediniformes',
  'Rhinopristiformes',
};

/// Maps a taxon's named ancestry to the app's category. First rule wins.
///
/// iNaturalist's `iconic_taxon_name` is too coarse (a shark is "Animalia"),
/// which is why the caller fetches the taxon's ancestors before mapping.
SpeciesCategory speciesCategoryFromAncestry(List<TaxonAncestor> ancestors) {
  bool has(String rank, String name) =>
      ancestors.any((a) => a.rank == rank && a.name == name);
  bool hasName(String name) => ancestors.any((a) => a.name == name);

  if (has('class', 'Chondrichthyes')) {
    return _batoidOrders.any(hasName)
        ? SpeciesCategory.ray
        : SpeciesCategory.shark;
  }
  if (has('class', 'Actinopterygii')) return SpeciesCategory.fish;
  if (has('class', 'Mammalia')) return SpeciesCategory.mammal;
  if (has('order', 'Testudines')) return SpeciesCategory.turtle;
  if (has('class', 'Anthozoa')) {
    return has('order', 'Actiniaria')
        ? SpeciesCategory.invertebrate
        : SpeciesCategory.coral;
  }
  if (has('kingdom', 'Plantae') || has('kingdom', 'Chromista')) {
    return SpeciesCategory.plant;
  }
  if (has('class', 'Aves') ||
      has('class', 'Reptilia') ||
      has('class', 'Amphibia')) {
    return SpeciesCategory.other;
  }
  if (has('kingdom', 'Animalia')) return SpeciesCategory.invertebrate;
  return SpeciesCategory.other;
}
