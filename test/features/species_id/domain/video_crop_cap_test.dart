import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/services/video_crop_cap.dart';

import 'identification_rules_fixtures.dart';

/// A track on video v1 followed for a second, with a box of [area] pixels
/// (one pixel high) and [candidate] as its best name.
MediaIdentification track(
  String id, {
  int area = 100,
  double score = 0.8,
  IdentificationDecision decision = IdentificationDecision.accepted,
  bool suggestable = true,
  bool specific = true,
  String? decided,
  String? claimed,
  PackCandidate candidate = chromis,
  bool pending = false,
  bool video = true,
}) => MediaIdentification(
  id: id,
  mediaId: 'v1',
  box: const IdentificationBox(x: 0.1, y: 0.1, width: 0.1, height: 0.1),
  boxPixelWidth: area,
  boxPixelHeight: 1,
  detectorScore: score,
  openScore: 0.5,
  candidates: [NamedCandidate(candidate: candidate, score: 0.9)],
  locationLimited: true,
  suggestable: suggestable,
  specific: specific,
  decision: decision,
  decidedSpeciesId:
      decided ??
      (decision == IdentificationDecision.accepted ? 'sp_chromis' : null),
  claimedSpeciesId: claimed,
  createdAt: ruleEarlier,
  startMs: video ? 0 : null,
  endMs: video ? 1000 : null,
  bestMs: video && !pending ? 500 : null,
);

/// An animal the model could not name: neither specific nor suggestable.
MediaIdentification unnamed(String id, {int area = 100}) => track(
  id,
  area: area,
  decision: IdentificationDecision.undecided,
  suggestable: false,
  specific: false,
);

void main() {
  group('videoCropsToDrop', () {
    test(
      'keeps the 3 largest named tracks of one species and drops the rest',
      () {
        final rows = [
          track('a', area: 500),
          track('b', area: 400),
          track('c', area: 300),
          track('d', area: 200),
          track('e', area: 100),
        ];
        expect(videoCropsToDrop(rows), {'d', 'e'});
      },
    );

    test('ranks accepted before suggestable before specific-only', () {
      final rows = [
        track('accepted', area: 10),
        track('s1000', area: 1000, decision: IdentificationDecision.undecided),
        track(
          'specific',
          area: 5000,
          decision: IdentificationDecision.undecided,
          suggestable: false,
        ),
        track('s900', area: 900, decision: IdentificationDecision.undecided),
        track('s800', area: 800, decision: IdentificationDecision.undecided),
      ];
      expect(videoCropsToDrop(rows), {'specific', 's800'});
    });

    test('caps unnamed tracks separately at 3', () {
      final rows = [
        track('n1', area: 10),
        track('n2', area: 20),
        track('n3', area: 30),
        unnamed('u1', area: 500),
        unnamed('u2', area: 400),
        unnamed('u3', area: 300),
        unnamed('u4', area: 200),
        unnamed('u5', area: 100),
      ];
      expect(videoCropsToDrop(rows), {'u4', 'u5'});
    });

    test('never drops a claimed track', () {
      final rows = [
        track('a', area: 400),
        track('b', area: 300),
        track('c', area: 200),
        track('d', area: 100),
        track(
          'claimed',
          area: 1,
          decision: IdentificationDecision.undecided,
          claimed: 'sp_chromis',
        ),
      ];
      expect(videoCropsToDrop(rows), {'d'});
    });

    test('drops nothing for 3 or fewer tracks', () {
      expect(videoCropsToDrop([track('a'), track('b'), track('c')]), isEmpty);
    });

    test('drops nothing on a photo', () {
      expect(
        videoCropsToDrop([
          for (var k = 0; k < 6; k++) track('p$k', area: k, video: false),
        ]),
        isEmpty,
      );
    });

    test('leaves pending tracks out of the ranking', () {
      final rows = [
        track('a', area: 400),
        track('b', area: 300),
        track('c', area: 200),
        track('pending', area: 900, pending: true),
      ];
      expect(videoCropsToDrop(rows), isEmpty);
    });

    test('separate species are separate groups', () {
      final rows = [
        for (var k = 0; k < 4; k++) track('c$k', area: 100 - k),
        for (var k = 0; k < 4; k++)
          track('t$k', area: 100 - k, candidate: tang, decided: 'sp_blue_tang'),
      ];
      expect(videoCropsToDrop(rows), {'c3', 't3'});
    });

    test('ties break by detector score, then id', () {
      final rows = [
        track('d', score: 0.9),
        track('c', score: 0.5),
        track('b', score: 0.5),
        track('a', score: 0.5),
      ];
      expect(videoCropsToDrop(rows), {'c'});
    });
  });

  group('cropGroupKey', () {
    test('groups by the best name', () {
      expect(cropGroupKey(track('a')), 'gbif:${chromis.gbifKey}');
    });

    test('a claimed track groups under its claimed species', () {
      expect(
        cropGroupKey(
          track(
            'a',
            decision: IdentificationDecision.undecided,
            claimed: 'sp_x',
          ),
        ),
        'claim:sp_x',
      );
    });

    test('an accepted track corrected to another species groups under it', () {
      final corrected = track('a', candidate: parrotfish, decided: 'sp_grunt');
      expect(
        cropGroupKey(
          corrected,
          tags: const [
            TaggedSpecies(
              speciesId: 'sp_grunt',
              scientificName: 'Haemulon flavolineatum',
            ),
          ],
        ),
        'species:sp_grunt',
      );
    });

    test('an accepted track matching its tag keeps its best name', () {
      final accepted = track(
        'a',
        candidate: parrotfish,
        decided: 'sp_queen_parrotfish',
      );
      expect(
        cropGroupKey(
          accepted,
          tags: const [TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        ),
        'gbif:${parrotfish.gbifKey}',
      );
    });
  });

  group('keptStandIn', () {
    test('picks the largest present crop of the group', () {
      final rows = [
        track('a', area: 100),
        track('b', area: 300),
        track('c', area: 200),
        track('t', area: 900, candidate: tang, decided: 'sp_blue_tang'),
      ];
      expect(keptStandIn(rows, rows.first, {'c', 't'})?.id, 'c');
    });

    test('is null when the group has no crop left', () {
      final rows = [
        track('a'),
        track('t', candidate: tang, decided: 'sp_blue_tang'),
      ];
      expect(keptStandIn(rows, rows.first, {'t'}), isNull);
    });
  });
}
