import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

/// Looks a species up online. The iNaturalist implementation is the only
/// production one; widgets depend on this interface so tests can stub it.
abstract class SpeciesLookupService {
  /// Autocomplete hits for [query] with common names in [locale].
  Future<List<SpeciesLookupHit>> search(String query, {required String locale});

  /// The fields a species row needs for one hit, category included.
  Future<SpeciesLookupResult> resolve(int taxonId, {required String locale});
}
