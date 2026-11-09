import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

/// Each of [diveIds]' sightings as the [MarineSighting]s a [Dive] carries,
/// by dive id; a dive with none is absent. One batched read.
///
/// The dive list leaves sightings out, so the documents that print or carry
/// a dive's marine life (the PDF logbook and the UDDF export) read them here
/// (issue #4337 follow-up). The name is the stored one; a reader that
/// shows built-in species in the diver's language localizes it by id.
Future<Map<String, List<MarineSighting>>> loadMarineSightings(
  SpeciesRepository repository,
  List<String> diveIds,
) async {
  final byDive = await repository.getSightingsForDives(diveIds);
  return {
    for (final entry in byDive.entries)
      entry.key: [
        for (final s in entry.value)
          MarineSighting(
            id: s.id,
            speciesId: s.speciesId,
            speciesName: s.speciesName,
            abundance: s.abundance,
            count: s.count,
            notes: s.notes,
          ),
      ],
  };
}

/// [dives] in the same order, each with its sightings from the database.
/// A dive that already carries sightings keeps them, so a caller that built
/// its dives in memory is not overwritten.
Future<List<Dive>> hydrateMarineSightings(
  List<Dive> dives, {
  SpeciesRepository? repository,
}) async {
  final missing = [
    for (final dive in dives)
      if (dive.sightings.isEmpty) dive.id,
  ];
  if (missing.isEmpty) return dives;
  final byDive = await loadMarineSightings(
    repository ?? SpeciesRepository(),
    missing,
  );
  return [
    for (final dive in dives)
      if (dive.sightings.isEmpty && byDive[dive.id] != null)
        dive.copyWith(sightings: byDive[dive.id])
      else
        dive,
  ];
}
