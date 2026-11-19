/// Links the boxes the detector finds in a video's sampled frames into one
/// track per animal (issue #4675). Pure Dart, so every engine shares it.
library;

import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';

/// One animal followed through consecutive sampled frames.
class TrackedAnimal {
  /// [pending]: the stored row was kept without a name when a scan
  /// stopped, so all of [points] still count as new and it is named.
  TrackedAnimal(
    this.points, {
    this.storedId,
    bool pending = false,
    this.namedWorth,
  }) : storedLength = storedId == null || pending ? 0 : points.length;

  TrackedAnimal._copy(TrackedAnimal other)
    : points = [...other.points],
      storedId = other.storedId,
      storedLength = other.storedLength,
      namedWorth = other.namedWorth;

  /// Stored as [storedId] with all of [points]: what is seen next is new.
  TrackedAnimal._stored(
    List<({int ms, DetectedBox detection})> points, {
    required this.storedId,
    required this.namedWorth,
  }) : points = [...points],
       storedLength = points.length;

  /// Where it was seen, oldest first.
  final List<({int ms, DetectedBox detection})> points;

  /// The stored row this continues, when a scan resumed while the animal
  /// was still in view; null for a track found in this scan.
  final String? storedId;

  /// How many of [points] were already stored and named.
  final int storedLength;

  /// The worth ([momentWorth]) of the moment it was last named from, so a
  /// clearly better view can name it again (issue #4709); null when it has
  /// no name yet.
  final double? namedWorth;

  /// Whether it has been seen since it was named, or is not named yet.
  bool get hasNewPoints => points.length > storedLength;

  int get startMs => points.first.ms;
  int get endMs => points.last.ms;

  List<TrackSample> get samples => [
    for (final p in points) TrackSample(ms: p.ms, box: p.detection.box),
  ];
}

class _Open {
  _Open(this.animal);

  final TrackedAnimal animal;

  /// Frames in a row it was not matched in.
  var missed = 0;
}

/// Feeds on frames in time order. A frame's boxes are matched to the open
/// tracks greedily, the most overlapping pair first; a box left over opens
/// a track. A track missed for more than [maxGapSamples] frames in a row
/// is closed. A track seen in one frame only is dropped as flicker.
class VideoTracker {
  VideoTracker({this.linkOverlap = 0.3, this.maxGapSamples = 2});

  /// The least intersection over union for a box to continue a track.
  final double linkOverlap;
  final int maxGapSamples;

  final _open = <_Open>[];

  int get openCount => _open.length;

  /// The open animals, oldest first.
  List<TrackedAnimal> get openTracks => [for (final open in _open) open.animal];

  /// Records that the open track [animal] is stored as [storedId], named
  /// from a moment worth [namedWorth] (null: kept without a name). It stays
  /// open, and only what is seen from now on counts as new (issue #4709).
  void markStored(
    TrackedAnimal animal, {
    required String storedId,
    required double? namedWorth,
  }) {
    for (var k = 0; k < _open.length; k++) {
      final open = _open[k];
      if (!identical(open.animal, animal)) continue;
      _open[k] = _Open(
        TrackedAnimal._stored(
          animal.points,
          storedId: storedId,
          namedWorth: namedWorth,
        ),
      )..missed = open.missed;
      return;
    }
  }

  /// The open tracks as they are now, for [restore].
  VideoTrackerState save() => VideoTrackerState._([
    for (final open in _open)
      (animal: TrackedAnimal._copy(open.animal), missed: open.missed),
  ]);

  /// Back to the open tracks [state] saved: frames added since are undone.
  void restore(VideoTrackerState state) {
    _open
      ..clear()
      ..addAll([
        for (final open in state._open)
          _Open(TrackedAnimal._copy(open.animal))..missed = open.missed,
      ]);
  }

  /// Adds [frame]; returns the tracks it closed.
  List<TrackedAnimal> add(FrameDetections frame) {
    final pairs = <({int track, int box, double overlap})>[];
    for (var t = 0; t < _open.length; t++) {
      final last = _open[t].animal.points.last.detection.box;
      for (var b = 0; b < frame.boxes.length; b++) {
        final overlap = last.iou(frame.boxes[b].box);
        if (overlap >= linkOverlap) {
          pairs.add((track: t, box: b, overlap: overlap));
        }
      }
    }
    pairs.sort((a, b) => b.overlap.compareTo(a.overlap));
    final matchedTracks = <int>{};
    final matchedBoxes = <int>{};
    for (final pair in pairs) {
      if (matchedTracks.contains(pair.track) ||
          matchedBoxes.contains(pair.box)) {
        continue;
      }
      matchedTracks.add(pair.track);
      matchedBoxes.add(pair.box);
      _open[pair.track]
        ..missed = 0
        ..animal.points.add((ms: frame.ms, detection: frame.boxes[pair.box]));
    }
    final closed = <TrackedAnimal>[];
    final still = <_Open>[];
    for (var t = 0; t < _open.length; t++) {
      final open = _open[t];
      if (!matchedTracks.contains(t) && ++open.missed > maxGapSamples) {
        if (open.animal.points.length > 1) closed.add(open.animal);
      } else {
        still.add(open);
      }
    }
    _open
      ..clear()
      ..addAll(still);
    for (var b = 0; b < frame.boxes.length; b++) {
      if (matchedBoxes.contains(b)) continue;
      _open.add(
        _Open(TrackedAnimal([(ms: frame.ms, detection: frame.boxes[b])])),
      );
    }
    return closed;
  }

  /// Continues [animal] as an open track, last matched [missed] frames ago:
  /// one a stopped scan was following when it stopped.
  void resume(TrackedAnimal animal, {int missed = 0}) {
    _open.add(_Open(animal)..missed = missed);
  }

  /// Closes every open track: the end of the video, or the scan stopping.
  List<TrackedAnimal> closeAll() {
    final closed = [
      for (final open in _open)
        if (open.animal.points.length > 1) open.animal,
    ];
    _open.clear();
    return closed;
  }
}

/// What [VideoTracker.save] keeps: its open tracks at one moment.
class VideoTrackerState {
  const VideoTrackerState._(this._open);

  final List<({TrackedAnimal animal, int missed})> _open;
}

/// How good a view of an animal [detection] is: its detector score times
/// its box's area.
double momentWorth(DetectedBox detection) =>
    detection.score * detection.box.area;

/// Up to [max] moments of [track] worth cropping and naming: the highest
/// detector score times box area first, at least [minSpacingMs] apart.
/// When spacing leaves fewer than [max], the next best fill in.
List<({int ms, DetectedBox detection})> bestMoments(
  TrackedAnimal track, {
  int max = 3,
  int minSpacingMs = 1000,
}) {
  double worth(({int ms, DetectedBox detection}) p) => momentWorth(p.detection);
  final ranked = [...track.points]
    ..sort((a, b) {
      final byWorth = worth(b).compareTo(worth(a));
      return byWorth != 0 ? byWorth : a.ms.compareTo(b.ms);
    });
  final chosen = <({int ms, DetectedBox detection})>[];
  for (final p in ranked) {
    if (chosen.length >= max) break;
    if (chosen.every((c) => (c.ms - p.ms).abs() >= minSpacingMs)) {
      chosen.add(p);
    }
  }
  for (final p in ranked) {
    if (chosen.length >= max) break;
    if (!chosen.contains(p)) chosen.add(p);
  }
  return chosen;
}
