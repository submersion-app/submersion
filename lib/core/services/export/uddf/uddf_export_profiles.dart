import 'package:submersion/core/services/export/uddf/uddf_dive_chunk.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_sightings_hydration.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

/// Dives per run of the full UDDF backup (see [databaseUddfDiveChunks]); the
/// logbook PDF export reads its profiles in runs of the same size.
const int kUddfProfileChunkSize = 50;

/// Reads a full UDDF backup's runs of dives from the database: each dive's
/// recorded profile, its tank pressure series, and its data source rows from
/// [fetchSources].
///
/// `DiveRepository.getAllDives` leaves `Dive.profile` empty for list-view
/// performance, and the UDDF builders write `<samples>` from it (every
/// `<tankpressure>` too, since those live inside a sample), so a backup built
/// straight from that list carried no recorded samples at all (issue #1874).
/// Profiles come from [DiveRepository.getMergedProfilesForDives], the same
/// merge `getDiveById` shows. Unlike the logbook PDF, which thins each run,
/// a backup must be lossless, so every sample is kept.
///
/// The backup asks for one run at a time and lets it go once written, so
/// neither the reads nor the export hold more than one run's recordings
/// (issue #4249). A dive with no recorded samples keeps its empty profile.
UddfDiveChunkLoader databaseUddfDiveChunks({
  required DiveRepository diveRepository,
  required TankPressureRepository tankPressureRepository,
  required Future<List<DiveSourceExport>> Function(List<String> diveIds)
  fetchSources,
  SpeciesRepository? speciesRepository,
}) => (dives) async {
  final ids = [for (final dive in dives) dive.id];
  final profiles = await diveRepository.getMergedProfilesForDives(ids);
  final pressures = await tankPressureRepository.getTankPressuresForDives(ids);
  // The dive list carries no sightings either, so the export wrote none
  // (issue #4337 follow-up).
  final sightings = await loadMarineSightings(
    speciesRepository ?? SpeciesRepository(),
    ids,
  );
  return UddfDiveChunk(
    dives: [
      for (final dive in dives)
        dive.copyWith(
          profile: profiles[dive.id] ?? dive.profile,
          sightings: dive.sightings.isEmpty
              ? sightings[dive.id] ?? const []
              : dive.sightings,
        ),
    ],
    tankPressures: pressures,
    sources: await fetchSources(ids),
  );
};
