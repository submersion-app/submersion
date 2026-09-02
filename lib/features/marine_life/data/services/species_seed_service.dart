import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/bundled_species_catalog.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

class SpeciesSeedService {
  static BundledSpeciesCatalog? _cached;

  /// Decodes the asset text. A catalog without a `version` is version 1: the
  /// value shipped before versioning meant anything.
  static BundledSpeciesCatalog parseCatalog(String jsonString) {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final version = data['version'] is int ? data['version'] as int : 1;
    final speciesList = data['species'] as List<dynamic>;
    final species = speciesList.map((item) {
      final map = item as Map<String, dynamic>;
      return Species(
        id: map['id'] as String,
        commonName: map['commonName'] as String,
        scientificName: map['scientificName'] as String?,
        category: SpeciesCategory.values.firstWhere(
          (c) => c.name == map['category'],
          orElse: () => SpeciesCategory.other,
        ),
        taxonomyClass: map['taxonomyClass'] as String?,
        description: map['description'] as String?,
        isBuiltIn: true,
      );
    }).toList();
    return BundledSpeciesCatalog(version: version, species: species);
  }

  /// Load the bundled catalog, cached after the first read (the reset and
  /// the seed both use it).
  static Future<BundledSpeciesCatalog> loadBundledCatalog() async {
    final cached = _cached;
    if (cached != null) return cached;
    final jsonString = await rootBundle.loadString('assets/data/species.json');
    return _cached = parseCatalog(jsonString);
  }

  /// Load built-in species from the bundled JSON asset.
  static Future<List<Species>> loadBundledSpecies() async =>
      (await loadBundledCatalog()).species;

  /// Seeds the cache so tests can run the seed against a small catalog.
  @visibleForTesting
  static void overrideCatalog(BundledSpeciesCatalog catalog) {
    _cached = catalog;
  }

  /// Clear the cached catalog (useful for testing).
  static void clearCache() {
    _cached = null;
  }
}
