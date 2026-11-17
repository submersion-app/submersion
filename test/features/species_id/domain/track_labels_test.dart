import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/services/track_labels.dart';

import '../data/identification_fixtures.dart';

/// Which label each fish gets over a video, and where (issue #4675).
void main() {
  group('labelKind', () {
    TrackLabelKind? kind(MediaIdentification t, {required bool playing}) =>
        labelKind(t, playing: playing);

    test('an accepted fish has a filled pill, playing or paused', () {
      final t = track(
        'a',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_a',
      );
      expect(kind(t, playing: true), TrackLabelKind.accepted);
      expect(kind(t, playing: false), TrackLabelKind.accepted);
    });

    test('a dismissed fish has nothing, not even a dot', () {
      final t = track('a', decision: IdentificationDecision.rejected);
      expect(kind(t, playing: true), isNull);
      expect(kind(t, playing: false), isNull);
    });

    test('a confident fish has a pill, playing or paused', () {
      final t = track('a', confident: true);
      expect(kind(t, playing: true), TrackLabelKind.confident);
      expect(kind(t, playing: false), TrackLabelKind.confident);
    });

    test('a suggestion under the confident bar has a pill only paused', () {
      final t = track('a', confident: false);
      expect(kind(t, playing: true), isNull);
      expect(kind(t, playing: false), TrackLabelKind.suggestion);
    });

    test('an unnamed fish has a dot only paused', () {
      final t = track('a', suggestable: false, confident: false);
      expect(kind(t, playing: true), isNull);
      expect(kind(t, playing: false), TrackLabelKind.dot);
    });

    test('a dot needs a crop that looks like something', () {
      final t = track(
        'a',
        suggestable: false,
        confident: false,
        specific: false,
      );
      expect(kind(t, playing: false), isNull);
    });

    test('a dot needs a track of at least a second', () {
      final short = track(
        'a',
        endMs: 1750,
        suggestable: false,
        confident: false,
      );
      expect(kind(short, playing: false), isNull);
      final second = track(
        'a',
        endMs: 2000,
        suggestable: false,
        confident: false,
      );
      expect(kind(second, playing: false), TrackLabelKind.dot);
    });
  });

  group('boxAt', () {
    final t = track('a'); // 1000..2000 every 250 ms, x from 0.1 by 0.01

    test('is null before the start and after the end', () {
      expect(boxAt(t, 999), isNull);
      expect(boxAt(t, 2001), isNull);
    });

    test('is the sample at a sample', () {
      expect(boxAt(t, 1250)!.x, closeTo(0.11, 1e-9));
    });

    test('interpolates between samples', () {
      expect(boxAt(t, 1125)!.x, closeTo(0.105, 1e-9));
      expect(boxAt(t, 1125)!.width, closeTo(0.2, 1e-9));
    });

    test('is null across a gap longer than half a second', () {
      final gappy = t.copyWith(
        path: const [
          TrackSample(
            ms: 1000,
            box: IdentificationBox(x: 0.1, y: 0.4, width: 0.2, height: 0.1),
          ),
          TrackSample(
            ms: 1600,
            box: IdentificationBox(x: 0.2, y: 0.4, width: 0.2, height: 0.1),
          ),
        ],
        endMs: () => 1600,
      );
      expect(boxAt(gappy, 1300), isNull);
      expect(boxAt(gappy, 1000), isNotNull);
    });

    test('a photo identification and an empty path have none', () {
      expect(boxAt(identification('p'), 1000), isNull);
      expect(boxAt(t.copyWith(path: const []), 1500), isNull);
    });
  });

  group('labelsAt', () {
    test('lists each visible fish with its kind, box and name', () {
      final elsewhere = track(
        'b',
        decision: IdentificationDecision.accepted,
        decidedSpeciesId: 'sp_b',
      );
      final labels = labelsAt(
        [
          track('a', confident: true),
          elsewhere.copyWith(
            path: [
              for (final s in elsewhere.path)
                s.copyWith(box: s.box.copyWith(y: 0.8)),
            ],
          ),
        ],
        1500,
        playing: true,
      );
      expect(labels.map((l) => l.kind), [
        TrackLabelKind.confident,
        TrackLabelKind.accepted,
      ]);
      expect(labels.first.candidate!.candidate.commonName, 'Queen Parrotfish');
      expect(labels.last.speciesId, 'sp_b');
      expect(labels.first.box.x, closeTo(0.12, 1e-9));
    });

    test('keeps at most six, largest first', () {
      final tracks = [
        for (var k = 0; k < 8; k++)
          track('t$k').copyWith(
            path: [
              for (var ms = 1000; ms <= 2000; ms += 250)
                TrackSample(
                  ms: ms,
                  // Eight fish in a row, each a little bigger.
                  box: IdentificationBox(
                    x: k * 0.12,
                    y: 0.1,
                    width: 0.05 + k * 0.005,
                    height: 0.1,
                  ),
                ),
            ],
          ),
      ];
      final labels = labelsAt(tracks, 1500, playing: true);
      expect(labels, hasLength(6));
      expect(labels.first.identificationId, 't7');
      expect(labels.last.identificationId, 't2');
    });

    test('two tracks on the same fish draw one label, the diver\'s first', () {
      final labels = labelsAt(
        [
          track('app', confident: true),
          track(
            'diver',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_b',
          ),
        ],
        1500,
        playing: true,
      );
      expect(labels.map((l) => l.identificationId), ['diver']);
    });

    test('a pill wins over a dot on the same fish', () {
      final labels = labelsAt(
        [
          track('dot', suggestable: false, confident: false),
          track('pill', confident: false),
        ],
        1500,
        playing: false,
      );
      expect(labels.map((l) => l.identificationId), ['pill']);
    });

    test('fish side by side keep their own labels', () {
      final apart = track('b', confident: true).copyWith(
        path: [
          for (final s in track('b').path)
            s.copyWith(box: s.box.copyWith(x: s.box.x + 0.5)),
        ],
      );
      expect(
        labelsAt([track('a', confident: true), apart], 1500, playing: true),
        hasLength(2),
      );
    });

    test('ignores photo identifications and fish not on screen', () {
      expect(
        labelsAt([identification('p'), track('a')], 5000, playing: true),
        isEmpty,
      );
    });
  });
}
