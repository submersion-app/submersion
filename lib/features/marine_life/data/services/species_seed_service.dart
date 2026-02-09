import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

class SpeciesSeedService {
  static List<Species>? _cachedSpecies;

  /// Load built-in species from the bundled JSON asset.
  ///
  /// Results are cached after the first load for efficient re-use
  /// (e.g. during "reset to defaults").
  static Future<List<Species>> loadBundledSpecies() async {
    if (_cachedSpecies != null) return _cachedSpecies!;

    final jsonString = await rootBundle.loadString('assets/data/species.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final speciesList = data['species'] as List<dynamic>;

    _cachedSpecies = speciesList.map((item) {
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

    return _cachedSpecies!;
  }

  /// Clear the cached species data (useful for testing).
  static void clearCache() {
    _cachedSpecies = null;
  }
}
