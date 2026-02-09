import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// Marine species entity
class Species extends Equatable {
  final String id;
  final String commonName;
  final String? scientificName;
  final SpeciesCategory category;
  final String? taxonomyClass;
  final String? description;
  final String? photoPath;
  final bool isBuiltIn;

  const Species({
    required this.id,
    required this.commonName,
    this.scientificName,
    required this.category,
    this.taxonomyClass,
    this.description,
    this.photoPath,
    this.isBuiltIn = false,
  });

  /// Display name with scientific name if available
  String get displayName {
    if (scientificName != null && scientificName!.isNotEmpty) {
      return '$commonName ($scientificName)';
    }
    return commonName;
  }

  Species copyWith({
    String? id,
    String? commonName,
    String? scientificName,
    SpeciesCategory? category,
    String? taxonomyClass,
    String? description,
    String? photoPath,
    bool? isBuiltIn,
  }) {
    return Species(
      id: id ?? this.id,
      commonName: commonName ?? this.commonName,
      scientificName: scientificName ?? this.scientificName,
      category: category ?? this.category,
      taxonomyClass: taxonomyClass ?? this.taxonomyClass,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  List<Object?> get props => [
    id,
    commonName,
    scientificName,
    category,
    taxonomyClass,
    description,
    photoPath,
    isBuiltIn,
  ];
}

/// Aggregated species sighting data for a dive site
class SiteSpeciesSummary extends Equatable {
  final String speciesId;
  final String speciesName;
  final SpeciesCategory category;
  final int sightingCount; // Total times spotted across all dives at site
  final int diveCount; // Number of dives where spotted

  const SiteSpeciesSummary({
    required this.speciesId,
    required this.speciesName,
    required this.category,
    required this.sightingCount,
    required this.diveCount,
  });

  @override
  List<Object?> get props => [
    speciesId,
    speciesName,
    category,
    sightingCount,
    diveCount,
  ];
}

/// Expected species entry for a dive site (manually curated)
class SiteSpeciesEntry extends Equatable {
  final String id;
  final String siteId;
  final String speciesId;
  final String speciesName;
  final SpeciesCategory category;
  final String notes;
  final DateTime createdAt;

  const SiteSpeciesEntry({
    required this.id,
    required this.siteId,
    required this.speciesId,
    required this.speciesName,
    required this.category,
    this.notes = '',
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    siteId,
    speciesId,
    speciesName,
    category,
    notes,
    createdAt,
  ];
}

/// A sighting of a species during a dive
class Sighting extends Equatable {
  final String id;
  final String diveId;
  final String speciesId;
  final String speciesName; // Denormalized for easy display
  final SpeciesCategory? speciesCategory;
  final int count;
  final String notes;

  const Sighting({
    required this.id,
    required this.diveId,
    required this.speciesId,
    required this.speciesName,
    this.speciesCategory,
    this.count = 1,
    this.notes = '',
  });

  Sighting copyWith({
    String? id,
    String? diveId,
    String? speciesId,
    String? speciesName,
    SpeciesCategory? speciesCategory,
    int? count,
    String? notes,
  }) {
    return Sighting(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      speciesId: speciesId ?? this.speciesId,
      speciesName: speciesName ?? this.speciesName,
      speciesCategory: speciesCategory ?? this.speciesCategory,
      count: count ?? this.count,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    speciesId,
    speciesName,
    speciesCategory,
    count,
    notes,
  ];
}
