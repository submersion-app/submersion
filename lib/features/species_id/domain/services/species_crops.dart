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

/// When in a video [tracks] were seen (issue #5032): one stretch per run
/// of tracks that overlap or start within [gapMs] of the last one's end,
/// in time order. Photos have no time and are left out.
List<({int startMs, int endMs})> videoStretches(
  List<MediaIdentification> tracks, {
  int gapMs = 1000,
}) {
  final timed = [
    for (final t in tracks)
      if (t.startMs != null && t.endMs != null) (t.startMs!, t.endMs!),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final stretches = <({int startMs, int endMs})>[];
  for (final (start, end) in timed) {
    final last = stretches.lastOrNull;
    if (last != null && start <= last.endMs + gapMs) {
      stretches[stretches.length - 1] = (
        startMs: last.startMs,
        endMs: end > last.endMs ? end : last.endMs,
      );
    } else {
      stretches.add((startMs: start, endMs: end));
    }
  }
  return stretches;
}
