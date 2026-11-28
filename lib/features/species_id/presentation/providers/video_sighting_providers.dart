import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/domain/services/species_crops.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

/// Identifies one species on one video.
typedef VideoSpeciesKey = ({String mediaId, String speciesId});

/// When [VideoSpeciesKey.speciesId] was seen on the video
/// [VideoSpeciesKey.mediaId], in time order: the accepted tracks of that
/// species merged into stretches, as the crop sheet's "Seen at" chips show
/// them. Empty for a photo, or for a video tagged by hand with no track.
///
/// The viewer opened from a sighting row's photo chip starts each video at
/// the first and marks them all on the scrub bar (issue #5084). Ticks on any
/// identification write, so a scan that finishes while the viewer is open
/// shows. Released once no bar watches it, so a video paged past stops
/// re-reading on every write.
final videoSpeciesSightingsProvider = FutureProvider.autoDispose
    .family<List<VideoStretch>, VideoSpeciesKey>((ref, key) async {
      final repository = ref.watch(mediaIdentificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final identifications = await repository.forMedia(key.mediaId);
      return videoStretches(cropsOfSpecies(identifications, key.speciesId));
    });
