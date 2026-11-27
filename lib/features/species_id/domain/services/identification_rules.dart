/// The rules that keep the app's identifications in step with the diver's
/// species tags, decide what to offer, and decide when a photo must be
/// looked at again. Pure functions, so every engine and screen shares them.
library;

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/pack_versions.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';

/// How much two boxes must overlap to be taken for the same animal.
const double sameAnimalOverlap = 0.5;

/// How many alternative names a suggestion's crop view offers.
const int suggestionAlternatives = 3;

String _sciKey(String name) => name.trim().toLowerCase();

/// Whether [candidate] is the tagged species: by catalogue id, or by
/// scientific name ignoring case and surrounding space.
bool candidateMatches(PackCandidate candidate, TaggedSpecies tagged) {
  if (candidate.catalogId != null && candidate.catalogId == tagged.speciesId) {
    return true;
  }
  final sci = tagged.scientificName;
  return sci != null && _sciKey(sci) == _sciKey(candidate.scientificName);
}

/// The identifications whose decision the photo's current tags change.
///
/// - Undecided: a tag accepts every identification whose best name is its
///   species. A tag that is no identification's best name accepts the one
///   identification that ranks it highest (the diver corrected the app's
///   guess). A neighbouring fish that only lists the species lower down
///   keeps its own suggestion (decided 2026-11-17, issue #4668).
/// - On a video (issue #4675), an animal the diver named from the frame (a
///   claim) is decided by its claim alone, and the name rules consider
///   only animals the app could suggest: one tag must not label every
///   distant fish whose weak guess is that species (decided 2026-11-17).
/// - Accepted, whose species is no longer tagged: rejected.
/// - Rejected: never changed here.
List<MediaIdentification> reconcileDecisions(
  List<MediaIdentification> all,
  List<TaggedSpecies> tagged, {
  required DateTime now,
}) {
  final accepting = _acceptingTags(all, tagged);
  final taggedIds = {for (final t in tagged) t.speciesId};
  final changed = <MediaIdentification>[];
  for (final identification in all) {
    switch (identification.decision) {
      case IdentificationDecision.undecided:
        final match = accepting[identification.id];
        if (match != null) {
          changed.add(
            identification.copyWith(
              decision: IdentificationDecision.accepted,
              decidedSpeciesId: match.speciesId,
              decidedAt: now,
            ),
          );
        }
      case IdentificationDecision.accepted:
        if (!taggedIds.contains(identification.decidedSpeciesId)) {
          changed.add(
            identification.copyWith(
              decision: IdentificationDecision.rejected,
              decidedAt: now,
            ),
          );
        }
      case IdentificationDecision.rejected:
        break;
    }
  }
  return changed;
}

/// The tag each undecided identification is accepted as, by id: best-name
/// matches first, then each remaining tag's single best lower match.
Map<String, TaggedSpecies> _acceptingTags(
  List<MediaIdentification> all,
  List<TaggedSpecies> tagged,
) {
  final byId = {for (final t in tagged) t.speciesId: t};
  final accepting = <String, TaggedSpecies>{};
  final undecided = <MediaIdentification>[];
  for (final i in all) {
    if (i.decision != IdentificationDecision.undecided) continue;
    final claim = i.claimedSpeciesId;
    if (claim != null) {
      final tag = byId[claim];
      if (tag != null) accepting[i.id] = tag;
      continue;
    }
    if (i.isTrack && !i.suggestable) continue;
    undecided.add(i);
  }
  final unnamed = <TaggedSpecies>[];
  for (final t in tagged) {
    var named = false;
    for (final i in undecided) {
      final top = i.top;
      if (top != null && candidateMatches(top.candidate, t)) {
        accepting.putIfAbsent(i.id, () => t);
        named = true;
      }
    }
    // A tag the diver gave one animal from the frame is not a correction
    // of some other animal's guess.
    final claimed = accepting.values.any((c) => c.speciesId == t.speciesId);
    if (!named && !claimed) unnamed.add(t);
  }
  for (final t in unnamed) {
    MediaIdentification? best;
    var bestRank = 0;
    var bestScore = 0.0;
    for (final i in undecided) {
      if (accepting.containsKey(i.id)) continue;
      final rank = i.candidates.indexWhere(
        (n) => candidateMatches(n.candidate, t),
      );
      if (rank < 0) continue;
      final score = i.candidates[rank].score;
      if (best == null ||
          rank < bestRank ||
          (rank == bestRank && score > bestScore)) {
        best = i;
        bestRank = rank;
        bestScore = score;
      }
    }
    if (best != null) accepting[best.id] = t;
  }
  return accepting;
}

/// What to offer for a photo: suggestable, undecided identifications whose
/// top species is not already tagged, one entry per species, best first.
List<SpeciesSuggestion> groupSuggestions(
  List<MediaIdentification> all,
  List<TaggedSpecies> tagged,
) {
  final groups = <int, List<MediaIdentification>>{};
  for (final identification in all) {
    final top = identification.top;
    if (top == null ||
        !identification.suggestable ||
        identification.decision != IdentificationDecision.undecided ||
        tagged.any((t) => candidateMatches(top.candidate, t))) {
      continue;
    }
    groups.putIfAbsent(top.candidate.gbifKey, () => []).add(identification);
  }
  final suggestions = [for (final group in groups.values) _suggestionFor(group)]
    ..sort((a, b) => b.score.compareTo(a.score));
  return suggestions;
}

SpeciesSuggestion _suggestionFor(List<MediaIdentification> group) {
  var best = group.first;
  for (final identification in group.skip(1)) {
    if (identification.top!.score > best.top!.score) best = identification;
  }
  return SpeciesSuggestion(
    top: best.top!,
    score: best.top!.score,
    count: group.length,
    cropIdentificationId: best.id,
    identificationIds: [for (final i in group) i.id],
    alternatives: best.candidates.take(suggestionAlternatives).toList(),
  );
}

/// What a name means for the labels over a video (issue #4675), decided
/// when it is named and stored with it, so the labels keep working after
/// the model is removed.
///
/// - confident: suggestable, and its top score is at or above the
///   confident bar for its case: `confidentScore` when its candidates were
///   limited to a place, `confidentScoreNoLocation` otherwise (issue
///   #4725). The scorer measures the two bars on those two cases apart, so
///   a crop with no usable place is never held to a bar measured only on
///   crops with one.
/// - specific: its open score is at or above the floor, so it looks like
///   something in particular rather than a hand or open water.
({bool confident, bool specific}) namingFlags(
  NamingResult result,
  NamingConfig config,
) {
  final top = result.candidates.isEmpty ? null : result.candidates.first;
  final bar = result.locationLimited
      ? config.confidentScore
      : config.confidentScoreNoLocation;
  return (
    confident: result.suggestable && top != null && top.score >= bar,
    specific: result.openScore >= config.minOpenScore,
  );
}

/// [stored] as the tags [shown] would leave them, worked out in memory and
/// written nowhere: what the labels over a video draw while a sitting holds
/// tags that are not saved yet (issue #4675).
List<MediaIdentification> decisionsAsShown(
  List<MediaIdentification> stored,
  List<TaggedSpecies> shown, {
  required DateTime now,
}) {
  final changed = {
    for (final i in reconcileDecisions(stored, shown, now: now)) i.id: i,
  };
  return [for (final i in stored) changed[i.id] ?? i];
}

enum RefreshAction {
  /// Nothing the stored result depends on has changed.
  none,

  /// Name the stored crops again from their embeddings.
  rename,

  /// Run the models over the image again.
  analyse,
}

/// What a photo with [run] needs, given the installed pack and where the
/// photo is now.
RefreshAction decideRefresh({
  required MediaIdentificationRun? run,
  required String packVersion,
  required String detectorId,
  required String classifierId,
  required int? cell,
  required bool cropsPresent,
  required bool embeddingsPresent,
  bool madeHere = true,
}) {
  // A run another device made is trusted (issue #4876): its crops and
  // embeddings are that device's, and its place was its own. Only newer
  // models here analyse it again.
  if (run != null && !madeHere) {
    return hasNewerModels(
          packVersion: packVersion,
          detectorId: detectorId,
          classifierId: classifierId,
          runPackVersion: run.packVersion,
          runDetectorId: run.detectorId,
          runClassifierId: run.classifierId,
        )
        ? RefreshAction.analyse
        : RefreshAction.none;
  }
  if (run == null ||
      !cropsPresent ||
      run.detectorId != detectorId ||
      run.classifierId != classifierId) {
    return RefreshAction.analyse;
  }
  if (run.packVersion != packVersion || run.locationCell != cell) {
    return embeddingsPresent ? RefreshAction.rename : RefreshAction.analyse;
  }
  return RefreshAction.none;
}

/// [stored]'s dismissed rows, undecided again: what a re-analysis the
/// diver asked for does to them before it runs (issue #4825). Each keeps
/// [now] as its decision time, which marks it
/// ([MediaIdentification.reopened]) as one the app never tags by itself.
/// Only the changed rows are returned.
List<MediaIdentification> reopenDismissed(
  List<MediaIdentification> stored, {
  required DateTime now,
}) => [
  for (final i in stored)
    if (i.decision == IdentificationDecision.rejected) _reopenedAt(i, now),
];

/// [i] undecided again since [now], naming no species: a row a tag was
/// removed from still names that tag's species.
MediaIdentification _reopenedAt(MediaIdentification i, DateTime now) =>
    MediaIdentification(
      id: i.id,
      mediaId: i.mediaId,
      box: i.box,
      boxPixelWidth: i.boxPixelWidth,
      boxPixelHeight: i.boxPixelHeight,
      detectorScore: i.detectorScore,
      openScore: i.openScore,
      candidates: i.candidates,
      locationLimited: i.locationLimited,
      suggestable: i.suggestable,
      decision: IdentificationDecision.undecided,
      decidedAt: now,
      createdAt: i.createdAt,
      startMs: i.startMs,
      endMs: i.endMs,
      bestMs: i.bestMs,
      path: i.path,
      claimedSpeciesId: i.claimedSpeciesId,
      confident: i.confident,
      specific: i.specific,
      runId: i.runId,
    );

/// What to store after a photo is analysed again.
///
/// Old undecided identifications are replaced by [fresh]. A decided one is
/// kept, unless a fresh detection of the same top species overlaps it by at
/// least [sameAnimalOverlap]: then the fresh detection carries its decision
/// and replaces it, so a dismissal survives and the crop is restored.
///
/// A reopened one ([MediaIdentification.reopened]) is carried the same
/// way, so the app goes on leaving it to the diver; one no fresh detection
/// matches is dropped, being only an old guess.
///
/// A name the diver gave an animal from the picture and has not saved as
/// a tag yet (a claim on an undecided row, issue #4825) is carried by
/// place alone, to the fresh detection that overlaps it most: the diver
/// named that animal, whatever the app calls it now. With none, the row is
/// kept as it is.
({
  List<MediaIdentification> keep,
  List<MediaIdentification> insert,
  List<String> deleteIds,
})
carryDecisions({
  required List<MediaIdentification> previous,
  required List<MediaIdentification> fresh,
}) {
  // A name given from the picture, on a row with no decision (reopened or
  // not), follows the animal by place.
  bool claimOnly(MediaIdentification p) =>
      p.decision == IdentificationDecision.undecided &&
      p.claimedSpeciesId != null;
  final decided = [
    for (final p in previous)
      if (p.saidByDiver && !claimOnly(p)) p,
  ];
  final claimed = [
    for (final p in previous)
      if (claimOnly(p)) p,
  ];
  final deleteIds = [
    for (final p in previous)
      if (!p.saidByDiver) p.id,
  ];
  final carried = <String>{};
  final insert = <MediaIdentification>[];
  for (final f in fresh) {
    final match = _matchFor(f, decided, carried);
    if (match == null) {
      insert.add(f);
      continue;
    }
    carried.add(match.id);
    deleteIds.add(match.id);
    insert.add(
      f.copyWith(
        decision: match.decision,
        decidedSpeciesId: match.decidedSpeciesId,
        decidedAt: match.decidedAt,
        claimedSpeciesId: () => match.claimedSpeciesId,
      ),
    );
  }
  final keptClaims = <MediaIdentification>[];
  for (final claim in claimed) {
    int? best;
    var bestOverlap = sameAnimalOverlap;
    for (var k = 0; k < insert.length; k++) {
      if (insert[k].saidByDiver) continue;
      final overlap = insert[k].box.iou(claim.box);
      if (overlap >= bestOverlap) {
        best = k;
        bestOverlap = overlap;
      }
    }
    if (best == null) {
      keptClaims.add(claim);
      continue;
    }
    insert[best] = insert[best].copyWith(
      claimedSpeciesId: () => claim.claimedSpeciesId,
      decidedAt: claim.decidedAt,
    );
    deleteIds.add(claim.id);
  }
  for (final d in decided) {
    if (d.reopened && !carried.contains(d.id)) deleteIds.add(d.id);
  }
  return (
    keep: [
      for (final d in decided)
        if (!carried.contains(d.id) && !d.reopened) d,
      ...keptClaims,
    ],
    insert: insert,
    deleteIds: deleteIds,
  );
}

MediaIdentification? _matchFor(
  MediaIdentification fresh,
  List<MediaIdentification> decided,
  Set<String> taken,
) {
  final key = fresh.top?.candidate.gbifKey;
  if (key == null) return null;
  for (final d in decided) {
    if (taken.contains(d.id) || d.top?.candidate.gbifKey != key) continue;
    if (d.box.iou(fresh.box) >= sameAnimalOverlap) return d;
  }
  return null;
}

/// [rows] as shown (issue #4876): a run's own rows, and every row the diver
/// said something on. An undecided, unclaimed row from another run is a
/// leftover of a run that lost a sync race (two devices analysed the same
/// media before syncing), and is hidden until the next analysis here
/// deletes it. With no run, or a run from before run ids, every row shows.
List<MediaIdentification> visibleRows(
  MediaIdentificationRun? run,
  List<MediaIdentification> rows,
) {
  final runId = run?.runId;
  if (runId == null) return rows;
  return [
    for (final i in rows)
      if (i.runId == null || i.runId == runId || i.saidByDiver) i,
  ];
}

/// Whether [i] has a name to show anywhere (issue #4876): it looks like
/// something in particular, is suggested, or the diver said something on
/// it. Its crop then syncs with the logbook; an unnamed one's stays a file
/// on the device that analysed it.
bool isNamed(MediaIdentification i) =>
    i.specific || i.suggestable || i.saidByDiver;
