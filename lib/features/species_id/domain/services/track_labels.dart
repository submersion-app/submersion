/// Which label each animal gets over a video, and where (issue #4675).
/// Pure functions, so the rules are tested without widgets.
library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

enum TrackLabelKind {
  /// The app's confident name: an outlined pill, playing or paused.
  confident,

  /// A name the app could suggest under the confident bar: an outlined
  /// pill, playing or paused (issue #4709).
  suggestion,

  /// The species the diver tagged: a filled pill, playing or paused.
  accepted,

  /// An animal with no name: a plain dot, paused only.
  dot,
}

/// One label to draw at one moment.
class TrackLabel extends Equatable {
  const TrackLabel({
    required this.identificationId,
    required this.kind,
    required this.box,
    this.candidate,
    this.speciesId,
  });

  final String identificationId;
  final TrackLabelKind kind;

  /// Where the animal is at that moment, normalised to the video.
  final IdentificationBox box;

  /// The app's name, for [TrackLabelKind.confident] and
  /// [TrackLabelKind.suggestion].
  final NamedCandidate? candidate;

  /// The tagged species, for [TrackLabelKind.accepted].
  final String? speciesId;

  TrackLabel copyWith({
    String? identificationId,
    TrackLabelKind? kind,
    IdentificationBox? box,
    NamedCandidate? Function()? candidate,
    String? Function()? speciesId,
  }) => TrackLabel(
    identificationId: identificationId ?? this.identificationId,
    kind: kind ?? this.kind,
    box: box ?? this.box,
    candidate: candidate == null ? this.candidate : candidate(),
    speciesId: speciesId == null ? this.speciesId : speciesId(),
  );

  @override
  List<Object?> get props => [
    identificationId,
    kind,
    box,
    candidate,
    speciesId,
  ];
}

/// The label [track] gets, or null for none. [minDotMs] keeps a fleeting
/// box (a fin, a bubble) from showing a dot. An accepted track whose tag
/// the app applied and the diver has not confirmed ([unconfirmed]) keeps
/// the outlined pill of the app's confident name (issue #4727).
TrackLabelKind? labelKind(
  MediaIdentification track, {
  required bool playing,
  int minDotMs = 1000,
  bool unconfirmed = false,
}) {
  switch (track.decision) {
    case IdentificationDecision.accepted:
      return unconfirmed ? TrackLabelKind.confident : TrackLabelKind.accepted;
    case IdentificationDecision.rejected:
      return null;
    case IdentificationDecision.undecided:
      if (track.confident) return TrackLabelKind.confident;
      if (track.suggestable) return TrackLabelKind.suggestion;
      if (playing) return null;
      if (track.specific && track.durationMs >= minDotMs) {
        return TrackLabelKind.dot;
      }
      return null;
  }
}

/// Where [track] is at [ms]: its box between the two samples around [ms],
/// in proportion. Null outside the track, and across a gap longer than
/// [maxGapMs], where nothing is known of where it went.
IdentificationBox? boxAt(
  MediaIdentification track,
  int ms, {
  int maxGapMs = 500,
}) {
  if (!track.isTrack) return null;
  return _pathBoxAt(track.path, ms.toDouble(), maxGapMs);
}

/// [boxAt] on [path] at a moment between whole milliseconds.
IdentificationBox? _pathBoxAt(List<TrackSample> path, double ms, int maxGapMs) {
  if (path.isEmpty || ms < path.first.ms || ms > path.last.ms) return null;
  final low = _lastAtOrBefore(path, ms);
  final here = path[low];
  if (here.ms == ms || low + 1 >= path.length) return here.box;
  final next = path[low + 1];
  if (next.ms - here.ms > maxGapMs) return null;
  final t = (ms - here.ms) / (next.ms - here.ms);
  double mix(double a, double b) => a + (b - a) * t;
  return IdentificationBox(
    x: mix(here.box.x, next.box.x),
    y: mix(here.box.y, next.box.y),
    width: mix(here.box.width, next.box.width),
    height: mix(here.box.height, next.box.height),
  );
}

/// The index of the last sample at or before [ms], which is within [path],
/// found by halving: this runs for every visible fish on every frame.
int _lastAtOrBefore(List<TrackSample> path, double ms) {
  var low = 0;
  var high = path.length - 1;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (path[mid].ms <= ms) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

/// How far either side of a moment a label looks to smooth out the
/// detector's noise (issue #4759). The stored boxes wander off a fish's
/// line by up to a fiftieth of the frame from one 250 ms sample to the
/// next; a second's window steadies that without trailing far behind a
/// fish that turns.
const int labelSmoothingMs = 500;

/// The longest step between two samples a label rides over (issue #4759).
/// The tracker keeps a fish through two missed samples, 750 ms at the
/// scan's 250 ms beat, and a sample's time lands a millisecond or so off
/// the beat; a label that went out there blinked.
const int labelMaxGapMs = 800;

/// Where a label for [track] goes at [ms]: [boxAt], averaged over
/// [radiusMs] either side with the nearest moments counting most. Null
/// where [boxAt] is.
///
/// The window stays the same width both sides, so a fish moving steadily is
/// met exactly rather than led or trailed. Towards the track's ends, and
/// towards a gap longer than [maxGapMs], it narrows smoothly to nothing, so
/// a label never jumps as a sample leaves the window and comes to rest on
/// the last sample seen.
IdentificationBox? smoothedBoxAt(
  MediaIdentification track,
  int ms, {
  int radiusMs = labelSmoothingMs,
  int maxGapMs = labelMaxGapMs,
}) {
  if (!track.isTrack) return null;
  final path = track.path;
  final centre = _pathBoxAt(path, ms.toDouble(), maxGapMs);
  if (centre == null) return null;
  final at = _lastAtOrBefore(path, ms.toDouble());
  // The unbroken run of samples around [ms], as far as the window reaches.
  var first = at;
  while (first > 0 &&
      path[first].ms > ms - radiusMs &&
      path[first].ms - path[first - 1].ms <= maxGapMs) {
    first--;
  }
  var last = at;
  while (last + 1 < path.length &&
      path[last].ms < ms + radiusMs &&
      path[last + 1].ms - path[last].ms <= maxGapMs) {
    last++;
  }
  final reach = math.min(
    radiusMs,
    math.min(ms - path[first].ms, path[last].ms - ms),
  );
  if (reach <= 0) return centre;
  // A triangle of weights over evenly spaced moments: [_taps] each side.
  var x = 0.0, y = 0.0, width = 0.0, height = 0.0, total = 0.0;
  void add(IdentificationBox box, double weight) {
    x += box.x * weight;
    y += box.y * weight;
    width += box.width * weight;
    height += box.height * weight;
    total += weight;
  }

  add(centre, _taps + 1);
  for (var k = 1; k <= _taps; k++) {
    final offset = reach * k / _taps;
    final weight = (_taps + 1 - k).toDouble();
    add(_pathBoxAt(path, ms - offset, maxGapMs)!, weight);
    add(_pathBoxAt(path, ms + offset, maxGapMs)!, weight);
  }
  return IdentificationBox(
    x: x / total,
    y: y / total,
    width: width / total,
    height: height / total,
  );
}

/// How many moments either side of the centre [smoothedBoxAt] averages.
const int _taps = 4;

/// The labels to draw at [ms]: one per visible animal, at most
/// [maxLabels], the largest first so a school does not bury the picture.
/// [unconfirmedSpeciesIds] are the video's tags the app applied and the
/// diver has not confirmed (issue #4727).
List<TrackLabel> labelsAt(
  List<MediaIdentification> shown,
  int ms, {
  required bool playing,
  int maxLabels = 6,
  Set<String> unconfirmedSpeciesIds = const {},
}) {
  final labels = <TrackLabel>[];
  for (final track in shown) {
    if (!track.isTrack) continue;
    final kind = labelKind(
      track,
      playing: playing,
      // A fish the diver named from the frame is theirs, whatever the tag.
      unconfirmed:
          track.decision == IdentificationDecision.accepted &&
          track.claimedSpeciesId == null &&
          unconfirmedSpeciesIds.contains(track.decidedSpeciesId),
    );
    if (kind == null) continue;
    final box = smoothedBoxAt(track, ms);
    if (box == null) continue;
    labels.add(
      TrackLabel(
        identificationId: track.id,
        kind: kind,
        box: box,
        candidate:
            kind == TrackLabelKind.confident ||
                kind == TrackLabelKind.suggestion
            ? track.top
            : null,
        speciesId: kind == TrackLabelKind.accepted
            ? track.decidedSpeciesId
            : null,
      ),
    );
  }
  // Two tracks on one fish (a decided row a rescan could not carry, or the
  // tracker splitting a fish) draw one label: the diver's tag first, then
  // the app's surest name, a dot last.
  final rank = [for (var k = 0; k < labels.length; k++) k]
    ..sort((a, b) {
      final byKind = _precedence(
        labels[a].kind,
      ).compareTo(_precedence(labels[b].kind));
      return byKind != 0 ? byKind : a.compareTo(b);
    });
  final kept = <int>[];
  for (final k in rank) {
    final sameFish = kept.any(
      (j) => labels[j].box.iou(labels[k].box) >= sameAnimalOverlap,
    );
    if (!sameFish) kept.add(k);
  }
  // Largest first; ties keep their stored order (List.sort is not stable).
  kept.sort((a, b) {
    final byArea = labels[b].box.area.compareTo(labels[a].box.area);
    return byArea != 0 ? byArea : a.compareTo(b);
  });
  return [for (final k in kept.take(maxLabels)) labels[k]];
}

int _precedence(TrackLabelKind kind) => switch (kind) {
  TrackLabelKind.accepted => 0,
  TrackLabelKind.confident => 1,
  TrackLabelKind.suggestion => 2,
  TrackLabelKind.dot => 3,
};
