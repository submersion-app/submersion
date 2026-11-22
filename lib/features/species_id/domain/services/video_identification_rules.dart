/// When a video is scanned or named again, and which of the diver's
/// decisions survive a rescan (issue #4675). Pure functions.
library;

import 'dart:math' as math;

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/pack_versions.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';

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
  bool madeHere = true,
}) {
  // A run another device made is trusted (issue #4876), and never resumed:
  // joining tracks across where its scan stopped needs that device's
  // embeddings. Only newer models here scan it again, from the start.
  if (run != null && !madeHere) {
    return hasNewerModels(
          packVersion: packVersion,
          detectorId: detectorId,
          classifierId: classifierId,
          runPackVersion: run.packVersion,
          runDetectorId: run.detectorId,
          runClassifierId: run.classifierId,
        )
        ? VideoRefreshAction.rescan
        : VideoRefreshAction.none;
  }
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
///
/// A tracker that links farther joins parts of a fish an earlier one split
/// apart (issue #4729), so one track may cover several decided tracks.
/// After carrying, a decided track that is the same animal as a track with
/// a say, fresh or [kept] (one this store keeps as it is), and on which the
/// diver said the same, is in `deleteIds` too: that track stands for it.
/// A decided track on which the diver said something different from that
/// track (another decision, species or claim) is kept as it is.
({List<MediaIdentification> insert, List<String> deleteIds})
carryTrackDecisions({
  required List<MediaIdentification> decided,
  required List<MediaIdentification> fresh,
  List<MediaIdentification> kept = const [],
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
  final said = [
    for (final t in [...insert, ...kept])
      if (t.saidByDiver) t,
  ];
  for (final d in decided) {
    if (taken.contains(d.id)) continue;
    if (said.any((t) => !saidDifferently(t, d) && _sameAnimal(d, t))) {
      taken.add(d.id);
    }
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

/// How long an animal still in view must have been seen before a chunk's
/// end names it (issue #4709).
const int earlyNamingMs = 1000;

/// How much better a view must be to name an animal again: its worth
/// ([momentWorth]) against the moment it was last named from.
const double betterViewMargin = 1.5;

/// Whether [track] is to be named now: it has no name yet, or a moment
/// seen since it was named is worth at least [betterViewMargin] times the
/// one it was named from.
bool namesNow(TrackedAnimal track) {
  final worth = track.namedWorth;
  if (worth == null || track.storedId == null) return true;
  for (var k = track.storedLength; k < track.points.length; k++) {
    if (momentWorth(track.points[k].detection) >= betterViewMargin * worth) {
      return true;
    }
  }
  return false;
}

/// [renamed], named again from a better view, keeping what the diver said
/// on [before], the row it replaces (issue #4709). An acceptance by a name
/// match (accepted with no claim) whose best name changed goes back to
/// undecided, for the tags to decide again. A claim, a dismissal and an
/// acceptance whose name is unchanged stay as they are.
MediaIdentification keepDecisionOnRename({
  required MediaIdentification before,
  required MediaIdentification renamed,
}) {
  final byName =
      before.decision == IdentificationDecision.accepted &&
      before.claimedSpeciesId == null;
  if (byName && !_sameName(before.top, renamed.top)) {
    return _decided(
      renamed,
      decision: IdentificationDecision.undecided,
      speciesId: null,
      at: null,
      claim: null,
    );
  }
  return _decided(
    renamed,
    decision: before.decision,
    speciesId: before.decidedSpeciesId,
    at: before.decidedAt,
    claim: before.claimedSpeciesId,
  );
}

/// The worth ([momentWorth]) a stored track was named at, as far as its row
/// tells: its best sampled box at its detector score. A scan compares new
/// views with its detector's best view ([namesNow]), but the row shows the
/// view that named it ([chooseNamingView]), which may be another (issue
/// #4736); a resumed scan reading the shown box would name it again more
/// readily than an unbroken one.
double storedWorth(MediaIdentification row) {
  double worth(IdentificationBox box) =>
      momentWorth(DetectedBox(box: box, score: row.detectorScore));
  return [
    worth(row.box),
    for (final s in row.path) worth(s.box),
  ].reduce(math.max);
}

/// Which of a track's [views] (each of its best moments that could be
/// cropped, named on its own, with the time it was seen) names the track,
/// and whether it may be suggested; null when no view has names.
///
/// The view whose name is most decided, by its open score, names it; on a
/// tie, the first, the detector's best view among those cropped. Each view
/// is named as a photo's crop is, so its scores are on the scale the bars
/// were measured on; an average of the views' embeddings never was, and
/// one poor view in it pulled every score down. Taking the best of several
/// views would also let more wrong names through, so the chosen one is
/// suggested only when another view at least [momentSpacingMs] from it
/// names the same species (issue #4747). A view nearer to it is nearly the
/// same frame and nearly always agrees: on a short track the best moments
/// are filled in from frames 250 ms apart ([bestMoments]). When every view
/// is that near the detector's best one, they are one view: the detector's
/// best names the track. A single view is judged as a photo is. A view
/// with no names (an unusable embedding) neither names nor agrees.
({int index, bool suggestable})? chooseNamingView(
  List<({NamingResult naming, int ms})> views,
) {
  final usable = [
    for (var k = 0; k < views.length; k++)
      if (views[k].naming.candidates.isNotEmpty) k,
  ];
  if (usable.isEmpty) return null;
  bool apart(int a, int b) =>
      (views[a].ms - views[b].ms).abs() >= momentSpacingMs;
  final first = usable.first;
  if (!usable.any((k) => apart(k, first))) {
    return (index: first, suggestable: views[first].naming.suggestable);
  }
  var chosen = first;
  for (final k in usable) {
    if (views[k].naming.openScore > views[chosen].naming.openScore) {
      chosen = k;
    }
  }
  final pick = views[chosen].naming;
  final agreed = usable.any(
    (k) =>
        apart(k, chosen) &&
        _sameName(views[k].naming.candidates.first, pick.candidates.first),
  );
  return (index: chosen, suggestable: pick.suggestable && agreed);
}

/// Whether [renamed], a stored identification named again from its stored
/// embedding for a new pack or place, may be suggested. A photo goes by the
/// bars. A video track was stored from one view, so whether another view
/// agrees with a new name cannot be told: it keeps a suggestion only when
/// it had one under the same name. A changed name stays unsuggested until
/// the video is scanned again, which a rename never asks for: only a new
/// detector, classifier or tracker does.
bool suggestableOnRename({
  required MediaIdentification before,
  required MediaIdentification renamed,
}) {
  if (!renamed.suggestable) return false;
  if (!before.isTrack) return true;
  return before.suggestable && _sameName(before.top, renamed.top);
}

bool _sameName(NamedCandidate? a, NamedCandidate? b) {
  if (a == null || b == null) return a == b;
  String key(String s) => s.trim().toLowerCase();
  return key(a.candidate.scientificName) == key(b.candidate.scientificName);
}

/// [i] with exactly this decision, species, time and claim, any of which
/// may be null.
MediaIdentification _decided(
  MediaIdentification i, {
  required IdentificationDecision decision,
  required String? speciesId,
  required DateTime? at,
  required String? claim,
}) => MediaIdentification(
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
  decision: decision,
  decidedSpeciesId: speciesId,
  decidedAt: at,
  claimedSpeciesId: claim,
  createdAt: i.createdAt,
  startMs: i.startMs,
  endMs: i.endMs,
  bestMs: i.bestMs,
  path: i.path,
  confident: i.confident,
  specific: i.specific,
  runId: i.runId,
);

/// Where two scanned stretches meet at [seamMs] (issue #4709): which of
/// the [open] tracks reaching the seam are the same animal as a [stored]
/// track of the later stretch. A stored track pairs when it starts within
/// [maxGapMs] after the seam and after the open track was last seen (the
/// tracker links across no longer gap), and its first box continues the
/// open track's last box by [link], as the tracker links boxes
/// ([matchLinks]), each track used once. Two parts on which the diver said
/// different things (a decision, its species, or a claim) stay apart; an
/// open track's say is on its stored row in [openRows], by id.
List<({TrackedAnimal open, MediaIdentification later})> seamJoins({
  required List<TrackedAnimal> open,
  required Map<String, MediaIdentification> openRows,
  required List<MediaIdentification> stored,
  required int seamMs,
  int maxGapMs = 750,
  TrackLink link = const TrackLink(),
}) {
  final later = [
    for (final s in stored)
      if (s.isTrack && s.path.isNotEmpty)
        if (s.startMs case final start?
            when start >= seamMs && start <= seamMs + maxGapMs)
          (row: s, start: start),
  ];
  final said = [
    for (final o in open) o.storedId == null ? null : openRows[o.storedId],
  ];
  final pairs = matchLinks(open.length, later.length, (o, l) {
    final track = open[o];
    final next = later[l];
    if (next.start - track.endMs > maxGapMs) return null;
    if (said[o] case final row? when saidDifferently(row, next.row)) {
      return null;
    }
    return link.score(track.points.last.detection.box, next.row.path.first.box);
  });
  return [for (final p in pairs) (open: open[p.from], later: later[p.to].row)];
}

/// Whether the diver said something on both [a] and [b], and not the same:
/// two parts of a track that must not be joined (issue #4709).
bool saidDifferently(MediaIdentification a, MediaIdentification b) {
  if (!a.saidByDiver || !b.saidByDiver) return false;
  return a.decision != b.decision ||
      a.decidedSpeciesId != b.decidedSpeciesId ||
      a.claimedSpeciesId != b.claimedSpeciesId;
}
