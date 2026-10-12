/// Resolves each sighting's `speciesref` against the file's
/// `<applicationdata><submersion><species>` section (issue #3033).
///
/// A sighting carries only the ref. Without this the importer rebuilt a name
/// from the ref text, filed the species as "other" and dropped the scientific
/// name, so every new species needed fixing by hand. A Submersion export
/// writes refs as `species_<uuid>`, which made a re-import name its species
/// after a UUID.
abstract final class UddfSightingSpecies {
  /// Copies the parsed spec fields onto every sighting in [dives] whose
  /// `speciesRef` matches the `uddfId` of an entry in [species].
  ///
  /// Only the fields the spec has are written, so a ref the section does not
  /// declare is left for the importer's name-from-ref fallback.
  static void resolve(
    List<Map<String, dynamic>> dives,
    List<Map<String, dynamic>> species,
  ) {
    final specsById = <String, Map<String, dynamic>>{
      for (final spec in species)
        if (spec['uddfId'] case final String id) id: spec,
    };
    if (specsById.isEmpty) return;

    for (final dive in dives) {
      final sightings = dive['sightings'];
      if (sightings is! List) continue;
      for (final sighting in sightings) {
        if (sighting is! Map<String, dynamic>) continue;
        final spec = specsById[sighting['speciesRef']];
        if (spec == null) continue;
        for (final (from, to) in _fields) {
          final value = spec[from];
          if (value != null) sighting[to] = value;
        }
      }
    }
  }

  /// Spec field to the sighting key the importer reads.
  static const _fields = [
    ('commonName', 'speciesName'),
    ('scientificName', 'speciesScientificName'),
    ('category', 'speciesCategory'),
    ('taxonomyClass', 'speciesTaxonomyClass'),
    ('description', 'speciesDescription'),
  ];
}
