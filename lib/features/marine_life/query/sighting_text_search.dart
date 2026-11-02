import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/marine_life/query/species_text_search.dart';

/// A dive with a sighting of a built-in species [builtInSpeciesIdsMatching]
/// finds, so a word in any app language reaches the dive as it reaches the
/// species (#3457). A custom species has a UUID id, so it can never be one of
/// the values; the stored name search covers those.
const kSightingTranslatedTextSearch = TextSearchExpansion(
  sql:
      'EXISTS (SELECT 1 FROM sightings tsgx WHERE tsgx.dive_id = {r}.id '
      'AND tsgx.species_id IN ({values}))',
  values: builtInSpeciesIdsMatching,
);
