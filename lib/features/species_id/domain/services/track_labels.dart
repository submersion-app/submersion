/// Which label each animal gets over a video, and where (issue #4675).
/// Pure functions, so the rules are tested without widgets.
library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';

enum TrackLabelKind {
  /// The app's confident name: an outlined pill, playing or paused.
  confident,

  /// A name the app could suggest under the confident bar: an outlined
  /// pill, playing or paused (issue #4709).
  suggestion,

  /// The species the diver tagged: a filled pill, playing or paused.
  accepted,

  /// An animal with no name: a plain dot. In [LabelMode.names] only on a
  /// paused video or a photo; in [LabelMode.allLife] always.
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

/// The label [track] gets in [mode], or null for none (issue #4825).
///
/// A named animal has its pill in [LabelMode.names] and
/// [LabelMode.allLife] alike. An accepted one whose tag the app applied
/// and the diver has not confirmed ([unconfirmed]) keeps the outlined pill
/// of the app's confident name (issue #4727). On a photo, a tag fills the
/// pill only on a detection the app could suggest or the diver named from
/// the picture: a photo's tag is matched to every detection whose best
/// guess is its species, however weak, and the weak ones draw as unnamed.
///
/// An unnamed animal has a dot. In [LabelMode.allLife], always. In
/// [LabelMode.names], only where the diver can stop and name it: on a
/// paused video, when it looks like something in particular and was
/// followed for [minDotMs] (a fin or a bubble is not), and on a photo,
/// which is always still, when it looks like something in particular.
TrackLabelKind? labelKind(
  MediaIdentification track, {
  required bool playing,
  LabelMode mode = LabelMode.names,
  int minDotMs = 1000,
  bool unconfirmed = false,
}) {
  if (mode == LabelMode.off) return null;
  switch (track.decision) {
    case IdentificationDecision.accepted:
      final sure =
          track.isTrack || track.suggestable || track.claimedSpeciesId != null;
      if (!sure) return _unnamedKind(track, playing, mode, minDotMs);
      return unconfirmed ? TrackLabelKind.confident : TrackLabelKind.accepted;
    case IdentificationDecision.rejected:
      return null;
    case IdentificationDecision.undecided:
      if (track.confident) return TrackLabelKind.confident;
      if (track.suggestable) return TrackLabelKind.suggestion;
      return _unnamedKind(track, playing, mode, minDotMs);
  }
}

/// A dot, or nothing, for an animal with no name to show.
TrackLabelKind? _unnamedKind(
  MediaIdentification found,
  bool playing,
  LabelMode mode,
  int minDotMs,
) {
  if (mode == LabelMode.allLife) return TrackLabelKind.dot;
  if (!found.specific) return null;
  if (!found.isTrack) return TrackLabelKind.dot;
  return !playing && found.durationMs >= minDotMs ? TrackLabelKind.dot : null;
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
  if (!_within(path, ms)) return null;
  return _boxFrom(path, _lastAtOrBefore(path, ms), ms, maxGapMs);
}

bool _within(List<TrackSample> path, double ms) =>
    path.isNotEmpty && ms >= path.first.ms && ms <= path.last.ms;

/// The box at [ms] from [low], the last sample at or before it.
IdentificationBox? _boxFrom(
  List<TrackSample> path,
  int low,
  double ms,
  int maxGapMs,
) {
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
/// found by halving: smoothing runs it nine times for each fish in view on
/// every frame while the video plays.
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
/// detector's noise (issue #4759). From one 250 ms sample to the next, the
/// stored boxes wander off a fish's line by a fiftieth of the frame at the
/// 90th percentile, and by as much as a fifth; a second's window steadies
/// that without trailing far behind a fish that turns.
const int labelSmoothingMs = 500;

/// The longest step between two samples a label rides over (issue #4759):
/// every step the tracker bridges, so a label never blinks out where the
/// fish is still followed. A sample's time is its frame's, which lands off
/// the scan's beat: stored steps over two missed samples reach 764 ms.
const int labelMaxGapMs =
    (VideoTracker.defaultMaxGapSamples + 1) * videoSampleIntervalMs +
    _frameSlackMs;

/// How far a sample's frame time may land from the scan's beat, with room
/// to spare over the 14 ms seen in real logs.
const int _frameSlackMs = 50;

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
  if (!_within(path, ms.toDouble())) return null;
  final at = _lastAtOrBefore(path, ms.toDouble());
  final centre = _boxFrom(path, at, ms.toDouble(), maxGapMs);
  if (centre == null) return null;
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
    final before = _pathBoxAt(path, ms - offset, maxGapMs);
    final after = _pathBoxAt(path, ms + offset, maxGapMs);
    // Every moment in the run has a box while the path is in time order,
    // as every scan stores it; nothing checks a stored one, so a moment
    // without a box stops the window there, both sides alike.
    if (before == null || after == null) break;
    final weight = (_taps + 1 - k).toDouble();
    add(before, weight);
    add(after, weight);
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

/// The labels to draw at [ms] in [mode]: one per visible animal, the
/// largest first, however many there are (issue #4825).
/// [unconfirmedSpeciesIds] are the video's tags the app applied and the
/// diver has not confirmed (issue #4727).
List<TrackLabel> labelsAt(
  List<MediaIdentification> shown,
  int ms, {
  required bool playing,
  LabelMode mode = LabelMode.names,
  Set<String> unconfirmedSpeciesIds = const {},
}) {
  final labels = <TrackLabel>[];
  for (final track in shown) {
    if (!track.isTrack) continue;
    final kind = labelKind(
      track,
      playing: playing,
      mode: mode,
      unconfirmed: _unconfirmed(track, unconfirmedSpeciesIds),
    );
    if (kind == null) continue;
    final box = smoothedBoxAt(track, ms);
    if (box == null) continue;
    labels.add(_label(track, kind, box));
  }
  return _oneEach(labels);
}

/// The labels to draw on a photo in [mode]: one per animal found on it,
/// the largest first (issue #4825). A photo is a still frame, so it is
/// labelled as a paused video is.
List<TrackLabel> photoLabels(
  List<MediaIdentification> shown, {
  LabelMode mode = LabelMode.names,
  Set<String> unconfirmedSpeciesIds = const {},
}) {
  final labels = <TrackLabel>[];
  for (final found in shown) {
    if (found.isTrack) continue;
    final kind = labelKind(
      found,
      playing: false,
      mode: mode,
      unconfirmed: _unconfirmed(found, unconfirmedSpeciesIds),
    );
    if (kind == null) continue;
    labels.add(_label(found, kind, found.box));
  }
  return _oneEach(labels);
}

/// Whether [found]'s tag is one the app applied and the diver has not
/// confirmed. An animal the diver named from the picture is theirs,
/// whatever the tag.
bool _unconfirmed(MediaIdentification found, Set<String> unconfirmed) =>
    found.decision == IdentificationDecision.accepted &&
    found.claimedSpeciesId == null &&
    unconfirmed.contains(found.decidedSpeciesId);

TrackLabel _label(
  MediaIdentification found,
  TrackLabelKind kind,
  IdentificationBox box,
) => TrackLabel(
  identificationId: found.id,
  kind: kind,
  box: box,
  candidate:
      kind == TrackLabelKind.confident || kind == TrackLabelKind.suggestion
      ? found.top
      : null,
  speciesId: kind == TrackLabelKind.accepted ? found.decidedSpeciesId : null,
);

/// [labels] with one label an animal, the largest first.
///
/// Two detections of one animal (a decided row a rescan could not carry,
/// or the tracker splitting a fish) draw one label: the diver's tag first,
/// then the app's surest name, a dot last.
List<TrackLabel> _oneEach(List<TrackLabel> labels) {
  final rank = [for (var k = 0; k < labels.length; k++) k]
    ..sort((a, b) {
      final byKind = _precedence(
        labels[a].kind,
      ).compareTo(_precedence(labels[b].kind));
      return byKind != 0 ? byKind : a.compareTo(b);
    });
  final kept = <int>[];
  for (final k in rank) {
    final sameAnimal = kept.any(
      (j) => labels[j].box.iou(labels[k].box) >= sameAnimalOverlap,
    );
    if (!sameAnimal) kept.add(k);
  }
  // Largest first; ties keep their stored order (List.sort is not stable).
  kept.sort((a, b) {
    final byArea = labels[b].box.area.compareTo(labels[a].box.area);
    return byArea != 0 ? byArea : a.compareTo(b);
  });
  return [for (final k in kept) labels[k]];
}

int _precedence(TrackLabelKind kind) => switch (kind) {
  TrackLabelKind.accepted => 0,
  TrackLabelKind.confident => 1,
  TrackLabelKind.suggestion => 2,
  TrackLabelKind.dot => 3,
};
