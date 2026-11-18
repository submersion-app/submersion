/// When a video is scanned or named again, and which of the diver's
/// decisions survive a rescan (issue #4675). Pure functions.
library;

import 'dart:math' as math;

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';

enum VideoRefreshAction {
  /// Nothing the stored tracks depend on has changed.
  none,

  /// Carry on from where the scan stopped.
  resume,

  /// Scan from the start: never scanned, a crop is gone, or new models.
  rescan,

  /// Name the stored tracks again from their embeddings.
  rename,
}

/// What a video with [run] needs, given the installed pack and where the
/// video is now. An unfinished scan resumes even when the pack or place
/// also changed, as long as the stored tracks can be named again from their
/// embeddings: the service does that first.
VideoRefreshAction decideVideoRefresh({
  required MediaIdentificationRun? run,
  required String packVersion,
  required String detectorId,
  required String classifierId,
  required int? cell,
  required bool cropsPresent,
  required bool embeddingsPresent,
}) {
  if (run == null ||
      !cropsPresent ||
      run.detectorId != detectorId ||
      run.classifierId != classifierId) {
    return VideoRefreshAction.rescan;
  }
  final stale = run.packVersion != packVersion || run.locationCell != cell;
  // Names that are stale and cannot be worked out again from embeddings
  // mean scanning again, finished or not.
  if (stale && !embeddingsPresent) return VideoRefreshAction.rescan;
  if (!run.scanComplete) return VideoRefreshAction.resume;
  return stale ? VideoRefreshAction.rename : VideoRefreshAction.none;
}

/// The diver's say on [decided] tracks (a decision or a claim), carried to
/// the [fresh] tracks of a rescan that follow the same animal: their time
/// ranges overlap by at least half the shorter one, and at the fresh
/// track's samples in that overlap their boxes overlap by at least
/// [sameAnimalOverlap] on average. Each decided track is carried at most
/// once; those carried are in `deleteIds`, replaced by the fresh track.
({List<MediaIdentification> insert, List<String> deleteIds})
carryTrackDecisions({
  required List<MediaIdentification> decided,
  required List<MediaIdentification> fresh,
}) {
  final taken = <String>{};
  final insert = <MediaIdentification>[];
  for (final f in fresh) {
    MediaIdentification? match;
    for (final d in decided) {
      if (!taken.contains(d.id) && _sameAnimal(d, f)) {
        match = d;
        break;
      }
    }
    if (match == null) {
      insert.add(f);
      continue;
    }
    taken.add(match.id);
    insert.add(
      f.copyWith(
        decision: match.decision,
        decidedSpeciesId: match.decidedSpeciesId,
        decidedAt: match.decidedAt,
        claimedSpeciesId: () => match!.claimedSpeciesId,
      ),
    );
  }
  return (
    insert: insert,
    deleteIds: [
      for (final d in decided)
        if (taken.contains(d.id)) d.id,
    ],
  );
}

bool _sameAnimal(MediaIdentification a, MediaIdentification b) {
  if (!a.isTrack || !b.isTrack) return false;
  final from = math.max(a.startMs!, b.startMs!);
  final to = math.min(a.endMs!, b.endMs!);
  final shorter = math.min(a.durationMs, b.durationMs);
  if (to - from < shorter / 2) return false;
  var total = 0.0;
  var count = 0;
  for (final sample in b.path) {
    if (sample.ms < from || sample.ms > to) continue;
    final other = boxAt(a, sample.ms);
    if (other == null) continue;
    total += other.iou(sample.box);
    count++;
  }
  return count > 0 && total / count >= sameAnimalOverlap;
}
