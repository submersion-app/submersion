import 'package:equatable/equatable.dart';

import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// One species the diver has logged at least once, with its sighting
/// aggregates across every dive.
///
/// Produced by `SeenSpeciesRepository.getSeenSpecies`. A species with no
/// sightings never becomes a [SeenSpecies]; that is what makes the Species
/// page a logbook rather than the catalog.
class SeenSpecies extends Equatable {
  final Species species;

  /// Sum of `sightings.count` over every dive.
  final int totalSightings;

  /// Number of distinct dives with at least one sighting.
  final int diveCount;

  /// Number of distinct sites among those dives. Dives without a site do
  /// not count.
  final int siteCount;

  /// Date of the earliest dive with a sighting.
  final DateTime firstSeen;

  /// Date of the latest dive with a sighting.
  final DateTime lastSeen;

  const SeenSpecies({
    required this.species,
    required this.totalSightings,
    required this.diveCount,
    required this.siteCount,
    required this.firstSeen,
    required this.lastSeen,
  });

  SeenSpecies copyWith({
    Species? species,
    int? totalSightings,
    int? diveCount,
    int? siteCount,
    DateTime? firstSeen,
    DateTime? lastSeen,
  }) {
    return SeenSpecies(
      species: species ?? this.species,
      totalSightings: totalSightings ?? this.totalSightings,
      diveCount: diveCount ?? this.diveCount,
      siteCount: siteCount ?? this.siteCount,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  List<Object?> get props => [
    species,
    totalSightings,
    diveCount,
    siteCount,
    firstSeen,
    lastSeen,
  ];
}
