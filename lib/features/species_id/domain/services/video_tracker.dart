/// Links the boxes the detector finds in a video's sampled frames into one
/// track per animal (issue #4675). Pure Dart, so every engine shares it.
library;

import 'dart:math' as math;

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';

/// The version of how a video's tracks are linked and named, stored in its
/// run so a video scanned by an earlier version is scanned again. 2: a
/// fish may continue to a nearby box it barely overlaps ([TrackLink], issue
/// #4729). 3: a track is named from its most decided view, not an average
/// of its views (issue #4736). 4: only a view a second away agrees with it
/// (issue #4747). 5: a small fish is cropped with more of its
/// surroundings (`VisionModels.momentPadding`, issue #4882).
const int videoTrackerVersion = 5;

/// How far apart a scan samples a video's frames, in milliseconds.
const int videoSampleIntervalMs = 250;

/// What a video's run stores as its detector id: the pack's detector set
/// and the tracker version. A change to either scans the video again.
String videoRunDetectorId(String detectorSetId) =>
    '$detectorSetId#tracker$videoTrackerVersion';

/// Whether a box in the next sampled frame can continue a track, and how
/// well (issue #4729).
///
/// A box overlapping the track's last box by [minOverlap] or more continues
/// it. So does a box of alike size ([minAreaRatio]) whose centre is at most
/// [maxShift] boxes away, across in box widths and down in box heights: a
/// small fish swims most of its length between two samples a quarter of a
/// second apart, and a moving camera shifts every box, so their overlap
/// falls under [minOverlap] though the fish is the same. Measured in boxes,
/// the reach is the same on a portrait video as on a landscape one.
class TrackLink {
  /// [minOverlap] is above 0: an overlap link scores above 1 only then
  /// ([isOverlap]), and at 0 every pair of boxes would be one.
  const TrackLink({
    this.minOverlap = 0.3,
    this.maxShift = 1.0,
    this.minAreaRatio = 0.4,
  }) : assert(minOverlap > 0 && minOverlap <= 1),
       assert(maxShift >= 0),
       assert(minAreaRatio >= 0 && minAreaRatio <= 1);

  final double minOverlap;
  final double maxShift;
  final double minAreaRatio;

  /// How well [next] continues a track last seen at [last], higher is
  /// better, or null when it cannot: 1 plus the overlap for an overlap
  /// link (above 1), 1 less the shift for a nearby one (0 to 1).
  double? score(IdentificationBox last, IdentificationBox next) {
    final overlap = last.iou(next);
    if (overlap >= minOverlap) return 1 + overlap;
    final larger = math.max(last.area, next.area);
    if (larger <= 0 || math.min(last.area, next.area) / larger < minAreaRatio) {
      return null;
    }
    final across =
        ((last.x + last.width / 2) - (next.x + next.width / 2)).abs() /
        math.max(last.width, next.width);
    final down =
        ((last.y + last.height / 2) - (next.y + next.height / 2)).abs() /
        math.max(last.height, next.height);
    final shift = math.sqrt(across * across + down * down);
    return shift <= maxShift ? 1 - shift : null;
  }

  /// Whether [score] is an overlap link's.
  static bool isOverlap(double score) => score > 1;
}

/// One-to-one pairs of `from` and `to` indexes by [score] (a [TrackLink]
/// score, null for none), the best first. The overlap links are made
/// first. A nearby link is made only when neither end has another nearby
/// candidate among those the overlap links left: in a school, a box
/// between two fish could be either, and handing it to the wrong one would
/// mix two animals into one track and one name. A fish that continues on a
/// box it overlaps is no longer one of the two.
List<({int from, int to})> matchLinks(
  int fromCount,
  int toCount,
  double? Function(int from, int to) score,
) {
  final overlaps = <({int from, int to, double score})>[];
  final nearby = <({int from, int to, double score})>[];
  for (var f = 0; f < fromCount; f++) {
    for (var t = 0; t < toCount; t++) {
      final s = score(f, t);
      if (s == null) continue;
      (TrackLink.isOverlap(s) ? overlaps : nearby).add((
        from: f,
        to: t,
        score: s,
      ));
    }
  }
  final usedFrom = <int>{};
  final usedTo = <int>{};
  final pairs = <({int from, int to})>[];
  void take(List<({int from, int to, double score})> links) {
    // Ties in index order, as List.sort is not stable.
    final ranked = [...links]
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final byFrom = a.from.compareTo(b.from);
        return byFrom != 0 ? byFrom : a.to.compareTo(b.to);
      });
    for (final c in ranked) {
      if (usedFrom.contains(c.from) || usedTo.contains(c.to)) continue;
      usedFrom.add(c.from);
      usedTo.add(c.to);
      pairs.add((from: c.from, to: c.to));
    }
  }

  take(overlaps);
  final left = [
    for (final c in nearby)
      if (!usedFrom.contains(c.from) && !usedTo.contains(c.to)) c,
  ];
  final fromCandidates = <int, int>{};
  final toCandidates = <int, int>{};
  for (final c in left) {
    fromCandidates.update(c.from, (n) => n + 1, ifAbsent: () => 1);
    toCandidates.update(c.to, (n) => n + 1, ifAbsent: () => 1);
  }
  take([
    for (final c in left)
      if (fromCandidates[c.from] == 1 && toCandidates[c.to] == 1) c,
  ]);
  return pairs;
}

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
/// tracks by [link] ([matchLinks]); a box left over opens a track. A track
/// missed for more than [maxGapSamples] frames in a row is closed. A track
/// seen in one frame only is dropped as flicker.
class VideoTracker {
  VideoTracker({
    this.link = const TrackLink(),
    this.maxGapSamples = defaultMaxGapSamples,
  });

  /// How many frames in a row a track may be missed in and still go on. A
  /// video's labels ride over the gaps this leaves (`labelMaxGapMs`).
  static const int defaultMaxGapSamples = 2;

  /// Which box continues a track.
  final TrackLink link;
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
    final pairs = matchLinks(
      _open.length,
      frame.boxes.length,
      (t, b) => link.score(
        _open[t].animal.points.last.detection.box,
        frame.boxes[b].box,
      ),
    );
    final matchedTracks = <int>{};
    final matchedBoxes = <int>{};
    for (final pair in pairs) {
      matchedTracks.add(pair.from);
      matchedBoxes.add(pair.to);
      _open[pair.from]
        ..missed = 0
        ..animal.points.add((ms: frame.ms, detection: frame.boxes[pair.to]));
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

/// How far apart a track's best moments are taken ([bestMoments]): views
/// this far apart are of the animal at different moments, not nearly the
/// same frame.
const int momentSpacingMs = 1000;

/// Up to [max] moments of [track] worth cropping and naming: the highest
/// detector score times box area first, at least [minSpacingMs] apart.
/// When spacing leaves fewer than [max], the next best fill in.
List<({int ms, DetectedBox detection})> bestMoments(
  TrackedAnimal track, {
  int max = 3,
  int minSpacingMs = momentSpacingMs,
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
