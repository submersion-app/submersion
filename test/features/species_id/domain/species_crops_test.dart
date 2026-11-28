import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/species_crops.dart';

import 'identification_rules_fixtures.dart';

/// The crops a species tag opens on a locked photo or video (issue #5024).
void main() {
  const accepted = IdentificationDecision.accepted;

  IdentificationBox at(double x, double y) =>
      IdentificationBox(x: x, y: y, width: 0.1, height: 0.1);

  List<String> ids(List<MediaIdentification> list) => [
    for (final i in list) i.id,
  ];

  test('keeps only accepted identifications of the species', () {
    final all = [
      ruleId('undecided'),
      ruleId(
        'rejected',
        decision: IdentificationDecision.rejected,
        decidedSpeciesId: 'sp_grunt',
      ),
      ruleId('other', decision: accepted, decidedSpeciesId: 'sp_tang'),
      ruleId('mine', decision: accepted, decidedSpeciesId: 'sp_grunt'),
    ];
    expect(ids(cropsOfSpecies(all, 'sp_grunt')), ['mine']);
  });

  test('drops a pending track', () {
    final all = [
      ruleId(
        'pending',
        decision: accepted,
        decidedSpeciesId: 'sp_grunt',
      ).copyWith(startMs: () => 1000, endMs: () => 2000),
      ruleId(
        'named',
        decision: accepted,
        decidedSpeciesId: 'sp_grunt',
      ).copyWith(startMs: () => 3000, endMs: () => 4000, bestMs: () => 3500),
    ];
    expect(ids(cropsOfSpecies(all, 'sp_grunt')), ['named']);
  });

  test("orders a photo's crops left to right, then top to bottom", () {
    MediaIdentification grunt(String id, IdentificationBox box) =>
        ruleId(id, decision: accepted, decidedSpeciesId: 'sp_grunt', box: box);
    final all = [
      grunt('right', at(0.7, 0.1)),
      grunt('left_low', at(0.2, 0.6)),
      grunt('left_high', at(0.2, 0.3)),
    ];
    expect(ids(cropsOfSpecies(all, 'sp_grunt')), [
      'left_high',
      'left_low',
      'right',
    ]);
  });

  test("orders a video's crops by when the animal first appears", () {
    MediaIdentification track(String id, int startMs, double x) =>
        ruleId(
          id,
          decision: accepted,
          decidedSpeciesId: 'sp_grunt',
          box: at(x, 0.1),
        ).copyWith(
          startMs: () => startMs,
          endMs: () => startMs + 500,
          bestMs: () => startMs,
        );
    final all = [
      track('late', 9000, 0.1),
      track('early', 1000, 0.9),
      track('middle', 4000, 0.5),
    ];
    expect(ids(cropsOfSpecies(all, 'sp_grunt')), ['early', 'middle', 'late']);
  });

  test('never changes the list it is given', () {
    final all = List<MediaIdentification>.unmodifiable([
      ruleId(
        'b',
        decision: accepted,
        decidedSpeciesId: 'sp_grunt',
        box: at(0.6, 0.1),
      ),
      ruleId(
        'a',
        decision: accepted,
        decidedSpeciesId: 'sp_grunt',
        box: at(0.1, 0.1),
      ),
    ]);
    expect(ids(cropsOfSpecies(all, 'sp_grunt')), ['a', 'b']);
  });

  group('videoStretches (issue #5032)', () {
    MediaIdentification seen(String id, int start, int end) => ruleId(
      id,
      decision: accepted,
      decidedSpeciesId: 'sp_grunt',
    ).copyWith(startMs: () => start, endMs: () => end, bestMs: () => start);

    test('merges overlapping and near tracks', () {
      expect(
        videoStretches([
          seen('a', 4000, 9000),
          seen('b', 2000, 5000),
          seen('c', 9500, 12000),
        ]),
        [(startMs: 2000, endMs: 12000)],
      );
    });

    test('keeps far tracks apart', () {
      expect(videoStretches([seen('b', 20000, 21000), seen('a', 0, 3000)]), [
        (startMs: 0, endMs: 3000),
        (startMs: 20000, endMs: 21000),
      ]);
    });

    test('leaves out photos', () {
      expect(videoStretches([ruleId('photo')]), isEmpty);
    });
  });

  group('nextStretchStart (issue #5084)', () {
    const stretches = <VideoStretch>[
      (startMs: 10000, endMs: 20000),
      (startMs: 60000, endMs: 70000),
      (startMs: 120000, endMs: 125000),
    ];

    test('from the start, goes to the first sighting', () {
      expect(nextStretchStart(stretches, 0), 10000);
    });

    test('sitting on a sighting, goes to the one after it', () {
      expect(nextStretchStart(stretches, 10000), 60000);
    });

    test('within the lead of a sighting, skips past it', () {
      expect(nextStretchStart(stretches, 59600), 120000);
    });

    test('after the last, wraps to the first', () {
      expect(nextStretchStart(stretches, 130000), 10000);
    });

    test('with no sightings, there is none', () {
      expect(nextStretchStart(const [], 0), isNull);
    });
  });
}
