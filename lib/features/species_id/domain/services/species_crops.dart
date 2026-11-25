import 'package:collection/collection.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

/// The identifications whose crops show what [speciesId] looks like on one
/// photo or video (issue #5024): those accepted as that species, the
/// diver's own or the app's awaiting confirmation. A video track not named
/// yet has no crop and is left out.
///
/// A photo's run left to right, then top to bottom, as they sit in it; a
/// video's by when each animal first appears. [all] is never changed.
List<MediaIdentification> cropsOfSpecies(
  Iterable<MediaIdentification> all,
  String speciesId,
) {
  final crops = all.where(
    (i) =>
        i.decision == IdentificationDecision.accepted &&
        i.decidedSpeciesId == speciesId &&
        !i.isPending,
  );
  final video = crops.isNotEmpty && crops.every((i) => i.isTrack);
  return crops.sorted(
    video
        ? (a, b) => a.startMs!.compareTo(b.startMs!)
        : (a, b) {
            final byX = a.box.x.compareTo(b.box.x);
            return byX != 0 ? byX : a.box.y.compareTo(b.box.y);
          },
  );
}
