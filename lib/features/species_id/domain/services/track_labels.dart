/// Which label each animal gets over a video, and where (issue #4675).
/// Pure functions, so the rules are tested without widgets.
library;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

enum TrackLabelKind {
  /// The app's confident name: an outlined pill, playing or paused.
  confident,

  /// A name the app could suggest under the confident bar: an outlined
  /// pill, paused only.
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
/// box (a fin, a bubble) from showing a dot.
TrackLabelKind? labelKind(
  MediaIdentification track, {
  required bool playing,
  int minDotMs = 1000,
}) {
  switch (track.decision) {
    case IdentificationDecision.accepted:
      return TrackLabelKind.accepted;
    case IdentificationDecision.rejected:
      return null;
    case IdentificationDecision.undecided:
      if (track.confident) return TrackLabelKind.confident;
      if (playing) return null;
      if (track.suggestable) return TrackLabelKind.suggestion;
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
  final path = track.path;
  if (!track.isTrack || path.isEmpty) return null;
  if (ms < path.first.ms || ms > path.last.ms) return null;
  // The last sample at or before [ms], found by halving: this runs for
  // every visible fish on every position tick.
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

/// The labels to draw at [ms]: one per visible animal, at most
/// [maxLabels], the largest first so a school does not bury the picture.
List<TrackLabel> labelsAt(
  List<MediaIdentification> shown,
  int ms, {
  required bool playing,
  int maxLabels = 6,
}) {
  final labels = <TrackLabel>[];
  for (final track in shown) {
    if (!track.isTrack) continue;
    final kind = labelKind(track, playing: playing);
    if (kind == null) continue;
    final box = boxAt(track, ms);
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
