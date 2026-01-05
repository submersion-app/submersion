import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// Marine species entity
class Species extends Equatable {
  final String id;
  final String commonName;
  final String? scientificName;
  final SpeciesCategory category;
  final String? description;
  final String? photoPath;

  const Species({
    required this.id,
    required this.commonName,
    this.scientificName,
    required this.category,
    this.description,
    this.photoPath,
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
    String? description,
    String? photoPath,
  }) {
    return Species(
      id: id ?? this.id,
      commonName: commonName ?? this.commonName,
      scientificName: scientificName ?? this.scientificName,
      category: category ?? this.category,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  @override
  List<Object?> get props => [
    id,
    commonName,
    scientificName,
    category,
    description,
    photoPath,
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
