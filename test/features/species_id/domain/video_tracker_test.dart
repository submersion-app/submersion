import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';

/// Linking a video's detections into one track per animal (issue #4675).
IdentificationBox _box(double x, {double y = 0.4, double w = 0.2}) =>
    IdentificationBox(x: x, y: y, width: w, height: 0.1);

FrameDetections frame(
  int ms,
  List<IdentificationBox> boxes, {
  double score = 0.8,
}) => FrameDetections(
  ms: ms,
  boxes: [for (final b in boxes) DetectedBox(box: b, score: score)],
);

/// Feeds [frames] and closes what is still open, returning every track.
List<TrackedAnimal> run(VideoTracker tracker, List<FrameDetections> frames) => [
  for (final f in frames) ...tracker.add(f),
  ...tracker.closeAll(),
];

void main() {
  test('a box moving a little each frame is one track', () {
    final tracks = run(VideoTracker(), [
      for (var k = 0; k < 6; k++) frame(k * 250, [_box(0.1 + k * 0.01)]),
    ]);
    expect(tracks, hasLength(1));
    expect(tracks.single.startMs, 0);
    expect(tracks.single.endMs, 1250);
    expect(tracks.single.samples.map((s) => s.ms), [
      0,
      250,
      500,
      750,
      1000,
      1250,
    ]);
  });

  test('two separate fish are two tracks', () {
    final tracks = run(VideoTracker(), [
      for (var k = 0; k < 4; k++) frame(k * 250, [_box(0.1), _box(0.6)]),
    ]);
    expect(tracks, hasLength(2));
    expect(tracks.map((t) => t.points.length), [4, 4]);
  });

  test('a gap of two frames is bridged, three is not', () {
    final bridged = run(VideoTracker(), [
      frame(0, [_box(0.1)]),
      frame(250, [_box(0.1)]),
      frame(500, const []),
      frame(750, const []),
      frame(1000, [_box(0.1)]),
    ]);
    expect(bridged, hasLength(1));
    expect(bridged.single.endMs, 1000);

    final split = run(VideoTracker(), [
      frame(0, [_box(0.1)]),
      frame(250, [_box(0.1)]),
      frame(500, const []),
      frame(750, const []),
      frame(1000, const []),
      frame(1250, [_box(0.1)]),
      frame(1500, [_box(0.1)]),
    ]);
    expect(split, hasLength(2));
    expect(split.first.endMs, 250);
    expect(split.last.startMs, 1250);
  });

  test('a one-frame flicker is dropped', () {
    final tracks = run(VideoTracker(), [
      frame(0, [_box(0.1), _box(0.7)]),
      frame(250, [_box(0.1)]),
      frame(500, [_box(0.1)]),
      frame(750, [_box(0.1)]),
      frame(1000, [_box(0.1)]),
    ]);
    expect(tracks, hasLength(1));
    expect(tracks.single.samples.first.box.x, closeTo(0.1, 1e-9));
  });

  test('the tracker carries open tracks across add calls', () {
    final tracker = VideoTracker();
    final closed = <TrackedAnimal>[];
    for (var k = 0; k < 40; k++) {
      closed.addAll(tracker.add(frame(k * 250, [_box(0.1 + k * 0.005)])));
    }
    expect(closed, isEmpty);
    expect(tracker.openCount, 1);
    final rest = tracker.closeAll();
    expect(rest.single.startMs, 0);
    expect(rest.single.endMs, 39 * 250);
    expect(tracker.openCount, 0);
  });

  test('restore undoes the frames added since save, gaps included', () {
    final tracker = VideoTracker();
    tracker.add(frame(0, [_box(0.1)]));
    tracker.add(frame(250, [_box(0.1)]));
    tracker.add(frame(500, const []));
    final saved = tracker.save();
    // Two more misses close it; a new fish opens.
    tracker.add(frame(750, [_box(0.6)]));
    expect(tracker.add(frame(1000, [_box(0.6)])).single.endMs, 250);
    tracker.restore(saved);
    expect(tracker.openCount, 1);
    // Still one miss behind: one more frame without it keeps it open.
    expect(tracker.add(frame(750, const [])), isEmpty);
    final rest = tracker.closeAll().single;
    expect((rest.startMs, rest.endMs), (0, 250));
    expect(rest.points, hasLength(2));
  });

  test('a track is returned by the frame that closes it', () {
    final tracker = VideoTracker();
    tracker.add(frame(0, [_box(0.1)]));
    tracker.add(frame(250, [_box(0.1)]));
    expect(tracker.add(frame(500, const [])), isEmpty);
    expect(tracker.add(frame(750, const [])), isEmpty);
    final closed = tracker.add(frame(1000, const []));
    expect(closed.single.endMs, 250);
  });

  test('two fish crossing keep the higher-overlap pairing', () {
    final tracks = run(VideoTracker(), [
      frame(0, [_box(0.30), _box(0.42)]),
      frame(250, [_box(0.32), _box(0.40)]),
      frame(500, [_box(0.34), _box(0.38)]),
    ]);
    expect(tracks, hasLength(2));
    final left = tracks.firstWhere((t) => t.samples.first.box.x < 0.35);
    expect(left.samples.map((s) => s.box.x), [
      closeTo(0.30, 1e-9),
      closeTo(0.32, 1e-9),
      closeTo(0.34, 1e-9),
    ]);
  });

  test('bestMoments ranks by score times area and keeps a second apart', () {
    final tracker = VideoTracker();
    final frames = [
      for (var k = 0; k < 12; k++)
        FrameDetections(
          ms: k * 250,
          boxes: [
            DetectedBox(
              box: _box(0.1, w: k == 5 ? 0.4 : 0.2),
              score: k == 6 ? 0.95 : 0.6,
            ),
          ],
        ),
    ];
    final track = run(tracker, frames).single;
    final best = bestMoments(track);
    expect(best, hasLength(3));
    expect(best.first.ms, 1250); // the largest box
    for (var a = 0; a < best.length; a++) {
      for (var b = a + 1; b < best.length; b++) {
        expect((best[a].ms - best[b].ms).abs(), greaterThanOrEqualTo(1000));
      }
    }
  });

  test('bestMoments of a short track returns what it has', () {
    final track = run(VideoTracker(), [
      frame(0, [_box(0.1)]),
      frame(250, [_box(0.1)]),
    ]).single;
    expect(bestMoments(track), hasLength(2));
  });

  group('naming in view (issue #4709)', () {
    test('markStored keeps the track open and counts its points as '
        'stored', () {
      final tracker = VideoTracker();
      for (var k = 0; k < 4; k++) {
        tracker.add(frame(k * 250, [_box(0.1)]));
      }
      final open = tracker.openTracks.single;
      expect(open.hasNewPoints, isTrue);
      tracker.markStored(open, storedId: 'r1', namedWorth: 0.5);
      final stored = tracker.openTracks.single;
      expect(stored.storedId, 'r1');
      expect(stored.namedWorth, 0.5);
      expect(stored.storedLength, 4);
      expect(stored.hasNewPoints, isFalse);
      tracker.add(frame(1000, [_box(0.1)]));
      final later = tracker.openTracks.single;
      expect(later.hasNewPoints, isTrue);
      expect(later.storedId, 'r1');
      expect(later.namedWorth, 0.5);
    });

    test('openTracks lists the open animals, oldest first', () {
      final tracker = VideoTracker();
      tracker.add(frame(0, [_box(0.1)]));
      tracker.add(frame(250, [_box(0.1), _box(0.7)]));
      final open = tracker.openTracks;
      expect(open, hasLength(2));
      expect(open.first.startMs, 0);
      expect(open.last.startMs, 250);
    });

    test('a saved state keeps what was marked stored', () {
      final tracker = VideoTracker();
      tracker.add(frame(0, [_box(0.1)]));
      tracker.add(frame(250, [_box(0.1)]));
      tracker.markStored(
        tracker.openTracks.single,
        storedId: 'r1',
        namedWorth: 0.2,
      );
      final saved = tracker.save();
      tracker.add(frame(500, [_box(0.1)]));
      tracker.restore(saved);
      final back = tracker.openTracks.single;
      expect(back.points, hasLength(2));
      expect(back.namedWorth, 0.2);
      expect(back.hasNewPoints, isFalse);
    });

    test('momentWorth is detector score times box area', () {
      expect(
        momentWorth(DetectedBox(box: _box(0.1, w: 0.5), score: 0.8)),
        closeTo(0.8 * 0.5 * 0.1, 1e-9),
      );
    });
  });

  group('a fish that moves far between samples', () {
    /// A small fish, as a damselfish or chromis is in a reef video.
    IdentificationBox small(double x, {double w = 0.04, double h = 0.03}) =>
        IdentificationBox(x: x, y: 0.4, width: w, height: h);

    test('moving three quarters of its length each sample, it is one '
        'track', () {
      // Each step overlaps the last box by an intersection over union of
      // about 0.14, under the 0.3 an overlap link needs.
      final tracks = run(VideoTracker(), [
        for (var k = 0; k < 6; k++) frame(k * 250, [small(0.1 + k * 0.03)]),
      ]);
      expect(tracks, hasLength(1));
      expect(tracks.single.points, hasLength(6));
    });

    test('a box more than its own length away starts a new track', () {
      final tracks = run(VideoTracker(), [
        frame(0, [small(0.1)]),
        frame(250, [small(0.1)]),
        frame(500, [small(0.15)]),
        frame(750, [small(0.15)]),
      ]);
      expect(tracks, hasLength(2));
      expect(tracks.first.endMs, 250);
      expect(tracks.last.startMs, 500);
    });

    test('a nearby box of a very different size does not continue it', () {
      // Three times the area, and an overlap of about 0.23.
      final tracks = run(VideoTracker(), [
        frame(0, [small(0.1)]),
        frame(250, [small(0.1)]),
        frame(500, [small(0.11, w: 0.08, h: 0.03 * 1.5)]),
        frame(750, [small(0.11, w: 0.08, h: 0.03 * 1.5)]),
      ]);
      expect(tracks, hasLength(2));
      expect(tracks.first.endMs, 250);
    });

    test('a nearby box two fish could continue continues neither', () {
      // Two fish side by side; the next box sits between them, in reach
      // of both and overlapping neither: which one it is cannot be told.
      final tracks = run(VideoTracker(), [
        frame(0, [small(0.10), small(0.17)]),
        frame(250, [small(0.10), small(0.17)]),
        frame(500, [small(0.135)]),
      ]);
      expect(tracks.map((t) => t.endMs), [250, 250]);
    });

    test('the same box with one fish in reach continues it', () {
      final tracks = run(VideoTracker(), [
        frame(0, [small(0.10)]),
        frame(250, [small(0.10)]),
        frame(500, [small(0.135)]),
      ]);
      expect(tracks.single.endMs, 500);
    });

    test('a nearby box whose other rival keeps an overlapping box '
        'continues the fish', () {
      // The box at 0.135 is in reach of both fish, but the one at 0.10
      // has a box it overlaps: only the fish at 0.17 is left for it.
      final tracks = run(VideoTracker(), [
        frame(0, [small(0.10), small(0.17)]),
        frame(250, [small(0.10), small(0.17)]),
        frame(500, [small(0.105), small(0.135)]),
      ]);
      expect(tracks, hasLength(2));
      final second = tracks.firstWhere(
        (t) => t.points.first.detection.box.x == 0.17,
      );
      expect(second.endMs, 500);
      expect(second.samples.last.box.x, closeTo(0.135, 1e-9));
    });

    test('a fish with two nearby boxes continues to neither', () {
      final tracks = run(VideoTracker(), [
        frame(0, [small(0.135)]),
        frame(250, [small(0.135)]),
        frame(500, [small(0.10), small(0.17)]),
      ]);
      expect(tracks.single.endMs, 250);
    });

    test('an overlapping box is taken over a nearby one', () {
      final tracks = run(VideoTracker(), [
        frame(0, [_box(0.1)]),
        frame(250, [_box(0.1)]),
        frame(500, [_box(0.12), _box(0.25)]),
        frame(750, [_box(0.12), _box(0.25)]),
      ]);
      final first = tracks.firstWhere((t) => t.startMs == 0);
      expect(first.samples.last.box.x, closeTo(0.12, 1e-9));
      expect(first.endMs, 750);
    });
  });

  group('TrackLink', () {
    const link = TrackLink();

    test('an overlap of 0.3 or more scores above 1', () {
      final a = _box(0.1);
      expect(link.score(a, a), closeTo(2, 1e-9));
      expect(link.score(a, _box(0.12))!, greaterThan(1));
    });

    test('a nearby box of alike size scores 1 less its shift', () {
      // Moved 0.03 with a width of 0.04: a shift of 0.75 boxes.
      const a = IdentificationBox(x: 0.1, y: 0.4, width: 0.04, height: 0.03);
      const b = IdentificationBox(x: 0.13, y: 0.4, width: 0.04, height: 0.03);
      expect(link.score(a, b), closeTo(0.25, 1e-9));
    });

    test('the shift is in box widths across and box heights down', () {
      // A tall box moved 0.8 of its width across: 0.8 of a box, not the
      // 0.08 it would be against its height.
      const a = IdentificationBox(x: 0.1, y: 0.1, width: 0.05, height: 0.5);
      const b = IdentificationBox(x: 0.14, y: 0.1, width: 0.05, height: 0.5);
      expect(link.score(a, b), closeTo(0.2, 1e-9));
    });

    test('too far, or too different in size, does not link', () {
      const a = IdentificationBox(x: 0.1, y: 0.4, width: 0.04, height: 0.03);
      expect(
        link.score(
          a,
          const IdentificationBox(x: 0.15, y: 0.4, width: 0.04, height: 0.03),
        ),
        isNull,
      );
      expect(
        link.score(
          a,
          const IdentificationBox(x: 0.11, y: 0.4, width: 0.08, height: 0.045),
        ),
        isNull,
      );
    });

    test('an empty box links nothing', () {
      const a = IdentificationBox(x: 0.1, y: 0.4, width: 0, height: 0);
      expect(link.score(a, a), isNull);
    });

    test('an overlap link needs an overlap above 0', () {
      // At 0, every pair of boxes would be an overlap link.
      expect(() => TrackLink(minOverlap: 0), throwsAssertionError);
      expect(() => TrackLink(minAreaRatio: 1.5), throwsAssertionError);
      expect(() => TrackLink(maxShift: -1), throwsAssertionError);
    });
  });

  group('matchLinks', () {
    double? Function(int, int) scores(Map<(int, int), double> by) =>
        (f, t) => by[(f, t)];

    test('the best links first, each end used once', () {
      expect(
        matchLinks(2, 2, scores({(0, 0): 1.4, (0, 1): 1.9, (1, 1): 1.6})),
        [(from: 0, to: 1)],
      );
    });

    test('a nearby link with a rival on either end is not made', () {
      expect(matchLinks(2, 1, scores({(0, 0): 0.3, (1, 0): 0.2})), isEmpty);
      expect(matchLinks(1, 2, scores({(0, 0): 0.3, (0, 1): 0.2})), isEmpty);
    });

    test('a rival settled by an overlap link does not count', () {
      // From 0 overlaps to 0, so to 1 has only from 1 left.
      expect(
        matchLinks(2, 2, scores({(0, 0): 1.8, (0, 1): 0.2, (1, 1): 0.3})),
        [(from: 0, to: 0), (from: 1, to: 1)],
      );
    });
  });

  test('a video run names the tracker that made its tracks', () {
    expect(videoRunDetectorId('det-a+det-m'), 'det-a+det-m#tracker5');
  });
}
