/// Which label each animal gets over a video, and where (issue #4675).
/// Pure functions, so the rules are tested without widgets.
library;

import 'package:equatable/equatable.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';

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
  for (var k = 0; k < path.length; k++) {
    final here = path[k];
    if (here.ms == ms) return here.box;
    if (k + 1 >= path.length) break;
    final next = path[k + 1];
    if (ms < here.ms || ms > next.ms) continue;
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
  return null;
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
  // Largest first; ties keep their stored order (List.sort is not stable).
  final order = [for (var k = 0; k < labels.length; k++) k]
    ..sort((a, b) {
      final byArea = labels[b].box.area.compareTo(labels[a].box.area);
      return byArea != 0 ? byArea : a.compareTo(b);
    });
  return [for (final k in order.take(maxLabels)) labels[k]];
}
