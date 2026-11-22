import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/auto_apply_rules.dart';

import '../data/identification_fixtures.dart';

/// Whether the installed pack can ever tag a match on its own (issue
/// #4727): only when one of its confident bars is reachable. A bar above 1
/// is "never", since a score is a share of at most 1.
void main() {
  NamingConfig naming({required double withPlace, required double noPlace}) =>
      NamingConfig(
        provisional: false,
        minCropSide: 64,
        minOpenScore: 0.39,
        suggestScore: 0.64,
        confidentScore: withPlace,
        suggestScoreNoLocation: 0.79,
        confidentScoreNoLocation: noPlace,
        minAllowedCandidates: 200,
        topK: 5,
      );

  test('both bars never: the pack cannot apply', () {
    final n = naming(withPlace: 1.01, noPlace: 1.01);
    expect(packCanApply(n), isFalse);
    expect(packAppliesOnlyWithPlace(n), isFalse);
  });

  test('a bar only with a place: applies, only with a location', () {
    final n = naming(withPlace: 0.95, noPlace: 1.01);
    expect(packCanApply(n), isTrue);
    expect(packAppliesOnlyWithPlace(n), isTrue);
  });

  test('both bars reachable: applies everywhere', () {
    final n = naming(withPlace: 0.95, noPlace: 0.97);
    expect(packCanApply(n), isTrue);
    expect(packAppliesOnlyWithPlace(n), isFalse);
  });

  group('identificationsToApply', () {
    final sure = identification('a').copyWith(confident: true);

    List<String> species(
      List<MediaIdentification> all, {
      List<TaggedSpecies> tagged = const [],
      bool isVideo = false,
      bool scanComplete = true,
    }) => [
      for (final s in identificationsToApply(
        all,
        tagged,
        isVideo: isVideo,
        scanComplete: scanComplete,
      ))
        '${s.candidate.candidate.scientificName}:${s.identificationIds.join(',')}',
    ];

    test('a detection the diver dismissed and a re-analysis brought back '
        'is never applied (issue #4825)', () {
      final reopened = sure.copyWith(decidedAt: fixtureT0);
      expect(reopened.reopened, isTrue);
      expect(species([reopened]), isEmpty);
      expect(species([sure]), hasLength(1));
    });

    test('a confident, undecided crop is applied', () {
      expect(species([sure]), ['Scarus vetula:a']);
    });

    test('one that is not confident is not', () {
      expect(species([identification('a')]), isEmpty);
    });

    test('a decided one is never reconsidered', () {
      expect(
        species([
          sure.copyWith(decision: IdentificationDecision.rejected),
          identification('b')
              .copyWith(confident: true)
              .copyWith(decision: IdentificationDecision.accepted),
        ]),
        isEmpty,
      );
    });

    test('two confident crops of one species are one tag', () {
      expect(species([sure, identification('b').copyWith(confident: true)]), [
        'Scarus vetula:a,b',
      ]);
    });

    test('a species already tagged is skipped', () {
      expect(
        species(
          [sure],
          tagged: const [TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        ),
        isEmpty,
      );
    });

    test('a video is applied only once its whole length is scanned', () {
      final fish = track('t1');
      expect(species([fish], isVideo: true, scanComplete: false), isEmpty);
      expect(species([fish], isVideo: true), hasLength(1));
    });

    test('on a video, a track the app could not suggest is skipped', () {
      final fish = track('t1', suggestable: false);
      expect(species([fish], isVideo: true), isEmpty);
    });
  });
}
