import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The nav Species page's query (#2365): over the species this diver has
/// sighted. Held apart from the catalog's, as each page's search is.
final seenSpeciesQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The species catalog's (Manage page) query.
final speciesCatalogQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The diver's sighted species narrowed to the query's ids; the page's own
/// search, category chips and sort still apply on top, in Dart.
final filteredSeenSpeciesProvider = Provider<AsyncValue<List<SeenSpecies>>>(
  (ref) => narrowByQuery(
    ref,
    ref.watch(seenSpeciesProvider),
    speciesQueryEntity,
    ref.watch(seenSpeciesQueryProvider),
    (s) => s.species.id,
  ),
);

/// The catalog narrowed to the query's ids; the Manage page's search and
/// category chips still apply on top.
final filteredSpeciesCatalogProvider = Provider<AsyncValue<List<Species>>>(
  (ref) => narrowByQuery(
    ref,
    ref.watch(speciesListNotifierProvider),
    speciesQueryEntity,
    ref.watch(speciesCatalogQueryProvider),
    (s) => s.id,
  ),
);
