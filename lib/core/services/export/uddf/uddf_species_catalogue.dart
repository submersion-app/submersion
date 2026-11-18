import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// The species a full UDDF backup declares (issue #4578): every custom
/// species in [all], and each bundled one that a sighting on an exported dive
/// names ([sighted]).
///
/// A bundled species no dive references is left out. Every install ships
/// the same catalogue and the importer finds a sighting's species by name,
/// so writing all of it only made the file larger. A custom species stays
/// even when no dive uses it, since the backup is its only copy.
///
/// Keeps [all]'s order; a sighted species missing from [all] goes last.
List<Species> uddfBackupSpecies({
  required List<Species> all,
  required List<Species> sighted,
}) {
  final sightedIds = {for (final s in sighted) s.id};
  final kept = [
    for (final s in all)
      if (!s.isBuiltIn || sightedIds.contains(s.id)) s,
  ];
  final keptIds = {for (final s in kept) s.id};
  return [
    ...kept,
    for (final s in sighted)
      if (!keptIds.contains(s.id)) s,
  ];
}
