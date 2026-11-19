import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';

import '../data/identification_fixtures.dart';

/// A label glides with its fish rather than jumping between the detector's
/// noisy samples, and rides over the short gaps the tracker bridges (issue
/// #4759).
void main() {
  /// [base] with the sample at [ms] moved down by [dy].
  MediaIdentification bumped(MediaIdentification base, int ms, double dy) =>
      base.copyWith(
        path: [
          for (final s in base.path)
            s.ms == ms ? s.copyWith(box: s.box.copyWith(y: s.box.y + dy)) : s,
        ],
      );

  /// [base] without the samples at [drop].
  MediaIdentification without(MediaIdentification base, Set<int> drop) =>
      base.copyWith(
        path: [
          for (final s in base.path)
            if (!drop.contains(s.ms)) s,
        ],
      );

  group('smoothedBoxAt', () {
    final steady = track('a', startMs: 0, endMs: 4000);

    test('is where a fish moving steadily is: no lag, no lead', () {
      for (final ms in [600, 1125, 2000, 3333]) {
        final raw = boxAt(steady, ms)!;
        final smooth = smoothedBoxAt(steady, ms)!;
        expect(smooth.x, closeTo(raw.x, 1e-9), reason: 'at $ms');
        expect(smooth.y, closeTo(raw.y, 1e-9), reason: 'at $ms');
        expect(smooth.width, closeTo(raw.width, 1e-9), reason: 'at $ms');
      }
    });

    test('one noisy sample moves the label much less than the sample', () {
      final noisy = bumped(steady, 2000, 0.1);
      final smooth = smoothedBoxAt(noisy, 2000)!;
      expect(boxAt(noisy, 2000)!.y, closeTo(0.5, 1e-9));
      expect(smooth.y - 0.4, lessThan(0.1 / 2));
      expect(smooth.y, greaterThan(0.4));
    });

    test('glides without a jump from one millisecond to the next', () {
      // Every other sample off the line, the worst wobble.
      final zigzag = steady.copyWith(
        path: [
          for (final (k, s) in steady.path.indexed)
            s.copyWith(box: s.box.copyWith(y: s.box.y + (k.isEven ? 0 : 0.05))),
        ],
      );
      var before = smoothedBoxAt(zigzag, 0)!;
      var largest = 0.0;
      for (var ms = 1; ms <= 4000; ms++) {
        final now = smoothedBoxAt(zigzag, ms)!;
        final step = (now.y - before.y).abs();
        if (step > largest) largest = step;
        before = now;
      }
      // The raw path climbs 0.05 in 250 ms: 0.0002 a millisecond. A sample
      // dropping out of the window all at once would jump ten times that;
      // the window shrinking towards the ends only steepens the slope.
      expect(largest, lessThan(0.0005));
    });

    test('is the sample itself at either end, and null outside', () {
      final noisy = bumped(bumped(steady, 0, 0.1), 4000, 0.1);
      expect(smoothedBoxAt(noisy, 0)!.y, closeTo(0.5, 1e-9));
      expect(smoothedBoxAt(noisy, 4000)!.y, closeTo(0.5, 1e-9));
      expect(smoothedBoxAt(noisy, -1), isNull);
      expect(smoothedBoxAt(noisy, 4001), isNull);
    });

    test('does not reach across a gap it will not bridge', () {
      final gappy = bumped(
        without(steady, {1250, 1500, 1750, 2000, 2250}),
        2500,
        0.3,
      );
      // Before the gap, nothing of the far side pulls the label down.
      expect(smoothedBoxAt(gappy, 1000)!.y, closeTo(0.4, 1e-9));
      expect(smoothedBoxAt(gappy, 1800), isNull);
    });

    test('a path out of time order narrows the window, it does not throw', () {
      // No scan stores one, and nothing checks a stored path's order. Here
      // the sample at index 8 reads 3250 ms, ahead of the 2250 ms after it:
      // halving for 3000 ms is sent below it, onto what looks like a
      // 1500 ms gap. Boxes on such a path may be wrong, as boxAt's always
      // were; the label layer must not throw.
      final misordered = steady.copyWith(
        path: [
          for (final (k, s) in steady.path.indexed)
            k == 8 ? TrackSample(ms: 3250, box: s.box) : s,
        ],
      );
      expect(smoothedBoxAt(misordered, 3500), isNotNull);
    });

    test('a photo identification and an empty path have none', () {
      expect(smoothedBoxAt(identification('p'), 1000), isNull);
      expect(smoothedBoxAt(steady.copyWith(path: const []), 1500), isNull);
    });
  });

  group('labelsAt over the tracker\'s gaps', () {
    test('a label rides over every step the tracker bridges', () {
      expect(
        labelMaxGapMs,
        greaterThan((VideoTracker().maxGapSamples + 1) * videoSampleIntervalMs),
      );
    });

    test('a label stays on across samples the tracker missed', () {
      // The tracker bridges two missed samples: 750 ms between samples,
      // stored a millisecond either side of the scan's beat.
      final full = track('a', startMs: 0, endMs: 4000);
      final missed = full.copyWith(
        path: [
          for (final s in full.path)
            if (s.ms != 1250 && s.ms != 1500)
              s.ms == 1750 ? TrackSample(ms: 1751, box: s.box) : s,
        ],
      );
      for (final ms in [1000, 1200, 1400, 1600, 1751]) {
        expect(
          labelsAt([missed], ms, playing: true),
          hasLength(1),
          reason: 'at $ms',
        );
      }
    });

    test('a label still goes across a longer gap, where the fish is lost', () {
      final lost = without(track('a', startMs: 0, endMs: 4000), {
        1250,
        1500,
        1750,
        2000,
      });
      expect(labelsAt([lost], 1600, playing: true), isEmpty);
      expect(labelsAt([lost], 1000, playing: true), hasLength(1));
      expect(labelsAt([lost], 2250, playing: true), hasLength(1));
    });

    test('labels are drawn at the smoothed box', () {
      final noisy = bumped(track('a', startMs: 0, endMs: 4000), 2000, 0.1);
      final label = labelsAt([noisy], 2000, playing: true).single;
      expect(label.box, smoothedBoxAt(noisy, 2000));
      expect(label.box.y, lessThan(0.5));
    });
  });
}
