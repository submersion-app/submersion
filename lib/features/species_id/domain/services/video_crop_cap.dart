/// Which identification crops a video keeps (issue #5032).
///
/// A school of fish gives dozens of tracks of one species, each with its
/// own crop, and the named ones sync to every device. A video keeps the
/// clearest few of each species: [videoCropsKept] synced crops and as many
/// files, plus every track the diver named from the frame. Rows are never
/// touched, only crops: playback, labels and decisions read the rows.
library;

import 'package:collection/collection.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

/// How many crops of one species a video keeps, named and unnamed each.
const int videoCropsKept = 3;

/// The group a track's crop competes in: what it is shown as.
///
/// A claimed track groups under its claimed species. An accepted track
/// whose best name is not the species the diver accepted it as (they chose
/// another) groups under that species, when its tag is among [tags].
/// Every other track groups under its best name's GBIF key, which is also
/// what a species tag matches when it accepts tracks, so an accepted track
/// and an undecided one of the same fish share a group.
String cropGroupKey(
  MediaIdentification i, {
  List<TaggedSpecies> tags = const [],
}) {
  final claimed = i.claimedSpeciesId;
  if (claimed != null) return 'claim:$claimed';
  final top = i.top;
  final decided = i.decidedSpeciesId;
  if (i.decision == IdentificationDecision.accepted && decided != null) {
    final tag = tags.firstWhereOrNull((t) => t.speciesId == decided);
    if (top == null || (tag != null && !candidateMatches(top.candidate, tag))) {
      return 'species:$decided';
    }
  }
  if (top == null) return 'id:${i.id}';
  return 'gbif:${top.candidate.gbifKey}';
}

/// The tracks of [rows] whose crop goes. Photos, pending tracks and
/// claimed tracks are never among them.
Set<String> videoCropsToDrop(
  List<MediaIdentification> rows, {
  List<TaggedSpecies> tags = const [],
}) {
  final ranked = rows.where(
    (i) => i.isTrack && !i.isPending && i.claimedSpeciesId == null,
  );
  final groups = ranked.groupListsBy(
    (i) => (named: isNamed(i), key: cropGroupKey(i, tags: tags)),
  );
  return {
    for (final MapEntry(key: (:named, key: _), value: group) in groups.entries)
      for (final i
          in group
              .sorted(named ? _byTierThenSize : _bySize)
              .skip(videoCropsKept))
        i.id,
  };
}

/// The track in [missing]'s group whose crop is in [present], largest box
/// first: what to show for a crop the cap dropped. Null when the group has
/// none left.
MediaIdentification? keptStandIn(
  List<MediaIdentification> rows,
  MediaIdentification missing,
  Set<String> present, {
  List<TaggedSpecies> tags = const [],
}) {
  final key = cropGroupKey(missing, tags: tags);
  return rows
      .where(
        (i) =>
            i.isTrack &&
            present.contains(i.id) &&
            cropGroupKey(i, tags: tags) == key,
      )
      .sorted(_bySize)
      .firstOrNull;
}

/// Accepted first, then what the app would suggest, then the rest.
int _tier(MediaIdentification i) {
  if (i.decision == IdentificationDecision.accepted) return 0;
  if (i.decision == IdentificationDecision.undecided && i.suggestable) {
    return 1;
  }
  return 2;
}

int _byTierThenSize(MediaIdentification a, MediaIdentification b) {
  final byTier = _tier(a).compareTo(_tier(b));
  return byTier != 0 ? byTier : _bySize(a, b);
}

/// Largest box first; a total order, so every device ranks alike.
int _bySize(MediaIdentification a, MediaIdentification b) {
  final byArea = (b.boxPixelWidth * b.boxPixelHeight).compareTo(
    a.boxPixelWidth * a.boxPixelHeight,
  );
  if (byArea != 0) return byArea;
  final byScore = b.detectorScore.compareTo(a.detectorScore);
  return byScore != 0 ? byScore : a.id.compareTo(b.id);
}
