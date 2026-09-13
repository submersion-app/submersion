import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Dives per batched profile read in [attachMergedProfiles]; the logbook PDF
/// export reads in runs of the same size.
const int kUddfProfileChunkSize = 50;

/// [dives] with each one's recorded profile attached, in the same order.
///
/// `DiveRepository.getAllDives` leaves `Dive.profile` empty for list-view
/// performance, and the UDDF builders write `<samples>` from it (every
/// `<tankpressure>` too, since those live inside a sample), so a backup built
/// straight from that list carried no recorded samples at all (issue #1874).
///
/// Profiles come from [DiveRepository.getMergedProfilesForDives], the same
/// merge `getDiveById` shows, [chunkSize] dives per read, so no read binds or
/// holds more than one chunk's series rows. Unlike the logbook PDF, which
/// thins each chunk, a backup must be lossless, so every sample is kept: the
/// chunking bounds the reads, not the result.
///
/// A dive with no recorded samples keeps its empty profile.
Future<List<Dive>> attachMergedProfiles(
  DiveRepository repository,
  List<Dive> dives, {
  int chunkSize = kUddfProfileChunkSize,
}) async {
  final result = <Dive>[];
  final ids = [for (final dive in dives) dive.id];
  for (final chunk in seriesIdChunks(ids, size: chunkSize)) {
    final profiles = await repository.getMergedProfilesForDives(chunk);
    for (final id in chunk) {
      final dive = dives[result.length];
      final profile = profiles[id];
      result.add(profile == null ? dive : dive.copyWith(profile: profile));
    }
  }
  return result;
}
