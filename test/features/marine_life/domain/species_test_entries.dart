import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// A seen species for domain tests. Dates are wall-clock-as-UTC, as dive
/// times are stored.
SeenSpecies seenEntry(
  String id, {
  SpeciesCategory category = SpeciesCategory.fish,
  int dives = 2,
  DateTime? first,
  DateTime? last,
}) {
  final firstSeen = first ?? DateTime.utc(2024, 1, 1);
  return SeenSpecies(
    species: Species(id: id, commonName: id, category: category),
    totalSightings: dives,
    diveCount: dives,
    siteCount: 1,
    firstSeen: firstSeen,
    lastSeen: last ?? firstSeen,
  );
}
