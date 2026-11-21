import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

import 'identification_rules_fixtures.dart';

void main() {
  group('candidateMatches', () {
    test('by catalogue id', () {
      expect(
        candidateMatches(
          parrotfish,
          const TaggedSpecies(speciesId: 'sp_queen_parrotfish'),
        ),
        isTrue,
      );
    });

    test('by scientific name, ignoring case and spaces', () {
      expect(
        candidateMatches(
          chromis,
          const TaggedSpecies(
            speciesId: 'uuid-1',
            scientificName: '  chromis MULTILINEATA ',
          ),
        ),
        isTrue,
      );
    });

    test('a catalogue candidate still matches a renamed own species by '
        'scientific name', () {
      expect(
        candidateMatches(
          parrotfish,
          const TaggedSpecies(
            speciesId: 'uuid-2',
            scientificName: 'Scarus vetula',
          ),
        ),
        isTrue,
      );
    });

    test('nothing in common is no match', () {
      expect(
        candidateMatches(
          tang,
          const TaggedSpecies(speciesId: 'uuid-3', scientificName: 'X y'),
        ),
        isFalse,
      );
    });
  });

  group('reconcileDecisions', () {
    test('an undecided identification becomes accepted when its species is '
        'tagged', () {
      final changed = reconcileDecisions(
        [ruleId('a')],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: ruleNow,
      );
      expect(changed.single.id, 'a');
      expect(changed.single.decision, IdentificationDecision.accepted);
      expect(changed.single.decidedSpeciesId, 'sp_queen_parrotfish');
      expect(changed.single.decidedAt, ruleNow);
    });

    test('a lower-ranked candidate matching still accepts', () {
      final changed = reconcileDecisions(
        [
          ruleId('a', candidates: [(parrotfish, 0.6), (chromis, 0.3)]),
        ],
        [
          const TaggedSpecies(
            speciesId: 'uuid-1',
            scientificName: 'Chromis multilineata',
          ),
        ],
        now: ruleNow,
      );
      expect(changed.single.decision, IdentificationDecision.accepted);
      expect(changed.single.decidedSpeciesId, 'uuid-1');
    });

    test('a tag accepts the fish it names first, not a neighbour that lists '
        'it lower', () {
      final changed = reconcileDecisions(
        [
          ruleId('a', candidates: [(parrotfish, 0.8), (chromis, 0.1)]),
          ruleId('b', candidates: [(chromis, 0.7), (parrotfish, 0.2)]),
        ],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: ruleNow,
      );
      expect(changed.map((i) => i.id), ['a']);
    });

    test('every fish named first as the tagged species is accepted', () {
      final changed = reconcileDecisions(
        [
          ruleId('a', candidates: [(parrotfish, 0.8)]),
          ruleId('b', candidates: [(parrotfish, 0.6)]),
        ],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: ruleNow,
      );
      expect(changed.map((i) => i.id), unorderedEquals(['a', 'b']));
    });

    test('a tag no fish names first accepts only the fish that ranks it '
        'highest', () {
      final changed = reconcileDecisions(
        [
          ruleId(
            'a',
            candidates: [(parrotfish, 0.6), (tang, 0.1), (chromis, 0.05)],
          ),
          ruleId('b', candidates: [(parrotfish, 0.5), (chromis, 0.3)]),
        ],
        [
          const TaggedSpecies(
            speciesId: 'uuid-1',
            scientificName: 'Chromis multilineata',
          ),
        ],
        now: ruleNow,
      );
      expect(changed.map((i) => i.id), ['b']);
      expect(changed.single.decidedSpeciesId, 'uuid-1');
    });

    test('a fish named first by one tag is not taken by another tag\'s '
        'lower match', () {
      final changed = reconcileDecisions(
        [
          ruleId('a', candidates: [(parrotfish, 0.6), (chromis, 0.3)]),
        ],
        [
          const TaggedSpecies(
            speciesId: 'uuid-1',
            scientificName: 'Chromis multilineata',
          ),
          const TaggedSpecies(speciesId: 'sp_queen_parrotfish'),
        ],
        now: ruleNow,
      );
      expect(changed.single.decidedSpeciesId, 'sp_queen_parrotfish');
    });

    test('an accepted identification whose species is untagged becomes '
        'rejected', () {
      final changed = reconcileDecisions(
        [
          ruleId(
            'a',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_queen_parrotfish',
          ),
        ],
        const [],
        now: ruleNow,
      );
      expect(changed.single.decision, IdentificationDecision.rejected);
      expect(changed.single.decidedAt, ruleNow);
    });

    test('a rejected identification never changes', () {
      final changed = reconcileDecisions(
        [ruleId('a', decision: IdentificationDecision.rejected)],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: ruleNow,
      );
      expect(changed, isEmpty);
    });

    test('nothing that already agrees with the tags is returned', () {
      final changed = reconcileDecisions(
        [
          ruleId('a'),
          ruleId(
            'b',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_blue_tang',
          ),
        ],
        [const TaggedSpecies(speciesId: 'sp_blue_tang')],
        now: ruleNow,
      );
      expect(changed, isEmpty);
    });
  });

  group('reconcileDecisions on a video (issue #4675)', () {
    MediaIdentification fish(
      String id, {
      List<(PackCandidate, double)> candidates = const [(parrotfish, 0.9)],
      bool suggestable = true,
      String? claim,
    }) => ruleId(id, candidates: candidates, suggestable: suggestable).copyWith(
      startMs: () => 0,
      endMs: () => 2000,
      claimedSpeciesId: () => claim,
    );

    test('a claim accepts its track when its species is tagged', () {
      final changed = reconcileDecisions(
        [
          fish('a', candidates: [(chromis, 0.9)], claim: 'sp_queen_parrotfish'),
        ],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: ruleNow,
      );
      expect(changed.single.decision, IdentificationDecision.accepted);
      expect(changed.single.decidedSpeciesId, 'sp_queen_parrotfish');
    });

    test('a claim outside the candidates still accepts', () {
      final changed = reconcileDecisions(
        [fish('a', suggestable: false, claim: 'own-7')],
        [
          const TaggedSpecies(
            speciesId: 'own-7',
            scientificName: 'Gramma loreto',
          ),
        ],
        now: ruleNow,
      );
      expect(changed.single.decidedSpeciesId, 'own-7');
    });

    test('a claim with no tag stays undecided', () {
      expect(
        reconcileDecisions([fish('a', claim: 'own-7')], const [], now: ruleNow),
        isEmpty,
      );
    });

    test('a claimed track takes its claim, not the name rules', () {
      final changed = reconcileDecisions(
        [
          fish('a', candidates: [(parrotfish, 0.9)], claim: 'sp_blue_tang'),
          fish('b', candidates: [(parrotfish, 0.8)]),
        ],
        [
          const TaggedSpecies(speciesId: 'sp_queen_parrotfish'),
          const TaggedSpecies(speciesId: 'sp_blue_tang'),
        ],
        now: ruleNow,
      );
      final byId = {for (final c in changed) c.id: c.decidedSpeciesId};
      expect(byId['a'], 'sp_blue_tang');
      expect(byId['b'], 'sp_queen_parrotfish');
    });

    test('a tag a claim took does not also take a neighbour by rank', () {
      final changed = reconcileDecisions(
        [
          fish('dot', suggestable: false, claim: 'sp_blue_tang'),
          fish('other', candidates: [(parrotfish, 0.7), (tang, 0.2)]),
        ],
        [const TaggedSpecies(speciesId: 'sp_blue_tang')],
        now: ruleNow,
      );
      expect(changed.map((i) => i.id), ['dot']);
    });

    test('on video, a weak best guess is not accepted by name', () {
      expect(
        reconcileDecisions(
          [fish('a', suggestable: false)],
          [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
          now: ruleNow,
        ),
        isEmpty,
      );
    });

    test('on video, the fallback skips tracks that are not suggestable', () {
      final changed = reconcileDecisions(
        [
          fish(
            'weak',
            candidates: [(tang, 0.5), (chromis, 0.4)],
            suggestable: false,
          ),
          fish('named', candidates: [(tang, 0.8), (chromis, 0.1)]),
        ],
        [
          const TaggedSpecies(
            speciesId: 'uuid-1',
            scientificName: 'Chromis multilineata',
          ),
        ],
        now: ruleNow,
      );
      expect(changed.map((i) => i.id), ['named']);
    });

    test('photos still accept a best name that is not suggestable', () {
      final changed = reconcileDecisions(
        [ruleId('a', suggestable: false)],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: ruleNow,
      );
      expect(changed.single.decision, IdentificationDecision.accepted);
    });

    test('decisionsAsShown applies held tags in memory', () {
      final stored = [
        fish('a'),
        fish('b', candidates: [(chromis, 0.9)]),
      ];
      final shown = decisionsAsShown(stored, [
        const TaggedSpecies(speciesId: 'sp_queen_parrotfish'),
      ], now: ruleNow);
      expect(shown.map((i) => i.id), ['a', 'b']);
      expect(shown[0].decision, IdentificationDecision.accepted);
      expect(shown[1].decision, IdentificationDecision.undecided);
      expect(stored[0].decision, IdentificationDecision.undecided);
    });
  });

  group('groupSuggestions', () {
    test('merges detections of one species, keeping the best crop', () {
      final suggestions = groupSuggestions([
        ruleId('a', candidates: [(parrotfish, 0.7)]),
        ruleId('b', candidates: [(parrotfish, 0.9), (tang, 0.05)]),
        ruleId('c', candidates: [(parrotfish, 0.8)]),
      ], const []);

      expect(suggestions, hasLength(1));
      final s = suggestions.single;
      expect(s.top.candidate, parrotfish);
      expect(s.score, 0.9);
      expect(s.count, 3);
      expect(s.cropIdentificationId, 'b');
      expect(s.identificationIds, unorderedEquals(['a', 'b', 'c']));
      expect(s.alternatives.map((c) => c.candidate), [parrotfish, tang]);
    });

    test('best score first', () {
      final suggestions = groupSuggestions([
        ruleId('a', candidates: [(chromis, 0.6)]),
        ruleId('b', candidates: [(tang, 0.95)]),
      ], const []);
      expect(suggestions.map((s) => s.top.candidate), [tang, chromis]);
    });

    test('at most three alternatives', () {
      final suggestions = groupSuggestions([
        ruleId(
          'a',
          candidates: [
            (parrotfish, 0.7),
            (tang, 0.1),
            (chromis, 0.1),
            (
              const PackCandidate(
                gbifKey: 9,
                scientificName: 'A b',
                commonName: 'A',
                category: SpeciesCategory.fish,
              ),
              0.1,
            ),
          ],
        ),
      ], const []);
      expect(suggestions.single.alternatives, hasLength(3));
    });

    test('a tagged species is not suggested', () {
      expect(
        groupSuggestions(
          [ruleId('a')],
          [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        ),
        isEmpty,
      );
    });

    test('a detection that is not suggestable is not suggested', () {
      expect(
        groupSuggestions([ruleId('a', suggestable: false)], const []),
        isEmpty,
      );
    });

    test('a decided detection is not suggested', () {
      expect(
        groupSuggestions([
          ruleId('a', decision: IdentificationDecision.rejected),
        ], const []),
        isEmpty,
      );
    });
  });

  group('decideRefresh', () {
    RefreshAction decide({
      MediaIdentificationRun? run,
      String pack = '2026.11.1',
      String detector = 'det-a',
      String classifier = 'clf-a',
      int? cell = 1462,
      bool crops = true,
      bool embeddings = true,
    }) => decideRefresh(
      run: run,
      packVersion: pack,
      detectorId: detector,
      classifierId: classifier,
      cell: cell,
      cropsPresent: crops,
      embeddingsPresent: embeddings,
    );

    test('no run analyses', () {
      expect(decide(), RefreshAction.analyse);
    });

    test('nothing changed does nothing', () {
      expect(decide(run: ruleRun()), RefreshAction.none);
    });

    test('a missing crop analyses', () {
      expect(decide(run: ruleRun(), crops: false), RefreshAction.analyse);
    });

    test('a different detector or classifier analyses', () {
      expect(decide(run: ruleRun(), detector: 'det-b'), RefreshAction.analyse);
      expect(
        decide(run: ruleRun(), classifier: 'clf-b'),
        RefreshAction.analyse,
      );
    });

    test('a new pack version with the same models renames', () {
      expect(decide(run: ruleRun(), pack: '2026.12.1'), RefreshAction.rename);
    });

    test('a different cell renames, including gaining or losing one', () {
      expect(decide(run: ruleRun(), cell: 1463), RefreshAction.rename);
      expect(
        decide(run: ruleRun(cell: null), cell: 1462),
        RefreshAction.rename,
      );
      expect(decide(run: ruleRun(), cell: null), RefreshAction.rename);
    });

    test('renaming without embeddings analyses instead', () {
      expect(
        decide(run: ruleRun(), pack: '2026.12.1', embeddings: false),
        RefreshAction.analyse,
      );
    });
  });

  group('namingFlags (issue #4675)', () {
    const config = NamingConfig(
      provisional: true,
      minCropSide: 64,
      minOpenScore: 0.15,
      suggestScore: 0.50,
      confidentScore: 0.70,
      suggestScoreNoLocation: 0.70,
      minAllowedCandidates: 200,
      topK: 5,
    );
    const fish = PackCandidate(
      gbifKey: 1,
      scientificName: 'Scarus vetula',
      commonName: 'Queen Parrotfish',
      category: SpeciesCategory.fish,
    );
    NamingResult result({
      double top = 0.8,
      double open = 0.5,
      bool suggestable = true,
      bool limited = true,
    }) => NamingResult(
      openScore: open,
      candidates: [NamedCandidate(candidate: fish, score: top)],
      locationLimited: limited,
      suggestable: suggestable,
    );

    test('a suggestable name over the confident bar is confident', () {
      expect(namingFlags(result(top: 0.71), config).confident, isTrue);
      expect(namingFlags(result(top: 0.70), config).confident, isTrue);
    });

    test('a suggestable name under the confident bar is not', () {
      expect(namingFlags(result(top: 0.69), config).confident, isFalse);
    });

    test('a name that is not suggestable is never confident', () {
      expect(
        namingFlags(result(top: 0.9, suggestable: false), config).confident,
        isFalse,
      );
    });

    test('nothing named is neither', () {
      final flags = namingFlags(NamingResult.unusable, config);
      expect(flags.confident, isFalse);
      expect(flags.specific, isFalse);
    });

    test('specific follows the open score floor', () {
      expect(namingFlags(result(open: 0.15), config).specific, isTrue);
      expect(namingFlags(result(open: 0.149), config).specific, isFalse);
    });

    group('a crop named without a place (issue #4725)', () {
      final noPlaceBar = config.copyWith(confidentScoreNoLocation: 0.90);

      test('is held to the no-location confident bar', () {
        expect(
          namingFlags(result(top: 0.89, limited: false), noPlaceBar).confident,
          isFalse,
        );
        expect(
          namingFlags(result(top: 0.90, limited: false), noPlaceBar).confident,
          isTrue,
        );
      });

      test('leaves a crop named with a place at the confident bar', () {
        expect(namingFlags(result(top: 0.70), noPlaceBar).confident, isTrue);
      });

      test('is never confident when the no-location bar is never', () {
        final never = config.copyWith(confidentScoreNoLocation: 1.01);
        expect(
          namingFlags(result(top: 1.0, limited: false), never).confident,
          isFalse,
        );
        expect(namingFlags(result(top: 0.70), never).confident, isTrue);
      });

      test('uses the confident bar when the pack has no no-location bar', () {
        expect(
          namingFlags(result(top: 0.70, limited: false), config).confident,
          isTrue,
        );
        expect(
          namingFlags(result(top: 0.69, limited: false), config).confident,
          isFalse,
        );
      });
    });
  });

  group('IdentificationBox.iou', () {
    test('identical boxes are 1, disjoint ones 0', () {
      const a = IdentificationBox(x: 0, y: 0, width: 0.5, height: 0.5);
      const b = IdentificationBox(x: 0.5, y: 0.5, width: 0.5, height: 0.5);
      expect(a.iou(a), 1);
      expect(a.iou(b), 0);
    });

    test('half overlapping', () {
      const a = IdentificationBox(x: 0, y: 0, width: 0.4, height: 0.2);
      const b = IdentificationBox(x: 0.2, y: 0, width: 0.4, height: 0.2);
      // Intersection 0.2 x 0.2, union 0.08 + 0.08 - 0.04.
      expect(a.iou(b), closeTo(0.04 / 0.12, 1e-9));
    });
  });
}
