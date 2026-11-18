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
}
