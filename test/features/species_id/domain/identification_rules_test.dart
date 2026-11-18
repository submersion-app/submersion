import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

final _now = DateTime.utc(2026, 11, 17, 12);
final _earlier = DateTime.utc(2026, 11, 1);

const _parrotfish = PackCandidate(
  gbifKey: 1,
  scientificName: 'Scarus vetula',
  commonName: 'Queen Parrotfish',
  category: SpeciesCategory.fish,
  catalogId: 'sp_queen_parrotfish',
);
const _chromis = PackCandidate(
  gbifKey: 2,
  scientificName: 'Chromis multilineata',
  commonName: 'Brown Chromis',
  category: SpeciesCategory.fish,
);
const _tang = PackCandidate(
  gbifKey: 3,
  scientificName: 'Acanthurus coeruleus',
  commonName: 'Blue Tang',
  category: SpeciesCategory.fish,
  catalogId: 'sp_blue_tang',
);

MediaIdentification _id(
  String id, {
  List<(PackCandidate, double)> candidates = const [(_parrotfish, 0.9)],
  bool suggestable = true,
  IdentificationDecision decision = IdentificationDecision.undecided,
  String? decidedSpeciesId,
  IdentificationBox box = const IdentificationBox(
    x: 0.1,
    y: 0.1,
    width: 0.2,
    height: 0.2,
  ),
}) => MediaIdentification(
  id: id,
  mediaId: 'm1',
  box: box,
  boxPixelWidth: 200,
  boxPixelHeight: 150,
  detectorScore: 0.8,
  openScore: 0.5,
  candidates: [
    for (final (c, s) in candidates) NamedCandidate(candidate: c, score: s),
  ],
  locationLimited: true,
  suggestable: suggestable,
  decision: decision,
  decidedSpeciesId: decidedSpeciesId,
  decidedAt: decision == IdentificationDecision.undecided ? null : _earlier,
  createdAt: _earlier,
);

MediaIdentificationRun _run({
  String pack = '2026.11.1',
  String detector = 'det-a',
  String classifier = 'clf-a',
  int? cell = 1462,
}) => MediaIdentificationRun(
  mediaId: 'm1',
  packVersion: pack,
  detectorId: detector,
  classifierId: classifier,
  locationCell: cell,
  analysedAt: _earlier,
  imageWidth: 4000,
  imageHeight: 3000,
  detectionCount: 1,
);

void main() {
  group('candidateMatches', () {
    test('by catalogue id', () {
      expect(
        candidateMatches(
          _parrotfish,
          const TaggedSpecies(speciesId: 'sp_queen_parrotfish'),
        ),
        isTrue,
      );
    });

    test('by scientific name, ignoring case and spaces', () {
      expect(
        candidateMatches(
          _chromis,
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
          _parrotfish,
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
          _tang,
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
        [_id('a')],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: _now,
      );
      expect(changed.single.id, 'a');
      expect(changed.single.decision, IdentificationDecision.accepted);
      expect(changed.single.decidedSpeciesId, 'sp_queen_parrotfish');
      expect(changed.single.decidedAt, _now);
    });

    test('a lower-ranked candidate matching still accepts', () {
      final changed = reconcileDecisions(
        [
          _id('a', candidates: [(_parrotfish, 0.6), (_chromis, 0.3)]),
        ],
        [
          const TaggedSpecies(
            speciesId: 'uuid-1',
            scientificName: 'Chromis multilineata',
          ),
        ],
        now: _now,
      );
      expect(changed.single.decision, IdentificationDecision.accepted);
      expect(changed.single.decidedSpeciesId, 'uuid-1');
    });

    test('a tag accepts the fish it names first, not a neighbour that lists '
        'it lower', () {
      final changed = reconcileDecisions(
        [
          _id('a', candidates: [(_parrotfish, 0.8), (_chromis, 0.1)]),
          _id('b', candidates: [(_chromis, 0.7), (_parrotfish, 0.2)]),
        ],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: _now,
      );
      expect(changed.map((i) => i.id), ['a']);
    });

    test('every fish named first as the tagged species is accepted', () {
      final changed = reconcileDecisions(
        [
          _id('a', candidates: [(_parrotfish, 0.8)]),
          _id('b', candidates: [(_parrotfish, 0.6)]),
        ],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: _now,
      );
      expect(changed.map((i) => i.id), unorderedEquals(['a', 'b']));
    });

    test('a tag no fish names first accepts only the fish that ranks it '
        'highest', () {
      final changed = reconcileDecisions(
        [
          _id(
            'a',
            candidates: [(_parrotfish, 0.6), (_tang, 0.1), (_chromis, 0.05)],
          ),
          _id('b', candidates: [(_parrotfish, 0.5), (_chromis, 0.3)]),
        ],
        [
          const TaggedSpecies(
            speciesId: 'uuid-1',
            scientificName: 'Chromis multilineata',
          ),
        ],
        now: _now,
      );
      expect(changed.map((i) => i.id), ['b']);
      expect(changed.single.decidedSpeciesId, 'uuid-1');
    });

    test('a fish named first by one tag is not taken by another tag\'s '
        'lower match', () {
      final changed = reconcileDecisions(
        [
          _id('a', candidates: [(_parrotfish, 0.6), (_chromis, 0.3)]),
        ],
        [
          const TaggedSpecies(
            speciesId: 'uuid-1',
            scientificName: 'Chromis multilineata',
          ),
          const TaggedSpecies(speciesId: 'sp_queen_parrotfish'),
        ],
        now: _now,
      );
      expect(changed.single.decidedSpeciesId, 'sp_queen_parrotfish');
    });

    test('an accepted identification whose species is untagged becomes '
        'rejected', () {
      final changed = reconcileDecisions(
        [
          _id(
            'a',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_queen_parrotfish',
          ),
        ],
        const [],
        now: _now,
      );
      expect(changed.single.decision, IdentificationDecision.rejected);
      expect(changed.single.decidedAt, _now);
    });

    test('a rejected identification never changes', () {
      final changed = reconcileDecisions(
        [_id('a', decision: IdentificationDecision.rejected)],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: _now,
      );
      expect(changed, isEmpty);
    });

    test('nothing that already agrees with the tags is returned', () {
      final changed = reconcileDecisions(
        [
          _id('a'),
          _id(
            'b',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_blue_tang',
          ),
        ],
        [const TaggedSpecies(speciesId: 'sp_blue_tang')],
        now: _now,
      );
      expect(changed, isEmpty);
    });
  });

  group('reconcileDecisions on a video (issue #4675)', () {
    MediaIdentification fish(
      String id, {
      List<(PackCandidate, double)> candidates = const [(_parrotfish, 0.9)],
      bool suggestable = true,
      String? claim,
    }) => _id(id, candidates: candidates, suggestable: suggestable).copyWith(
      startMs: () => 0,
      endMs: () => 2000,
      claimedSpeciesId: () => claim,
    );

    test('a claim accepts its track when its species is tagged', () {
      final changed = reconcileDecisions(
        [
          fish(
            'a',
            candidates: [(_chromis, 0.9)],
            claim: 'sp_queen_parrotfish',
          ),
        ],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: _now,
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
        now: _now,
      );
      expect(changed.single.decidedSpeciesId, 'own-7');
    });

    test('a claim with no tag stays undecided', () {
      expect(
        reconcileDecisions([fish('a', claim: 'own-7')], const [], now: _now),
        isEmpty,
      );
    });

    test('a claimed track takes its claim, not the name rules', () {
      final changed = reconcileDecisions(
        [
          fish('a', candidates: [(_parrotfish, 0.9)], claim: 'sp_blue_tang'),
          fish('b', candidates: [(_parrotfish, 0.8)]),
        ],
        [
          const TaggedSpecies(speciesId: 'sp_queen_parrotfish'),
          const TaggedSpecies(speciesId: 'sp_blue_tang'),
        ],
        now: _now,
      );
      final byId = {for (final c in changed) c.id: c.decidedSpeciesId};
      expect(byId['a'], 'sp_blue_tang');
      expect(byId['b'], 'sp_queen_parrotfish');
    });

    test('a tag a claim took does not also take a neighbour by rank', () {
      final changed = reconcileDecisions(
        [
          fish('dot', suggestable: false, claim: 'sp_blue_tang'),
          fish('other', candidates: [(_parrotfish, 0.7), (_tang, 0.2)]),
        ],
        [const TaggedSpecies(speciesId: 'sp_blue_tang')],
        now: _now,
      );
      expect(changed.map((i) => i.id), ['dot']);
    });

    test('on video, a weak best guess is not accepted by name', () {
      expect(
        reconcileDecisions(
          [fish('a', suggestable: false)],
          [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
          now: _now,
        ),
        isEmpty,
      );
    });

    test('on video, the fallback skips tracks that are not suggestable', () {
      final changed = reconcileDecisions(
        [
          fish(
            'weak',
            candidates: [(_tang, 0.5), (_chromis, 0.4)],
            suggestable: false,
          ),
          fish('named', candidates: [(_tang, 0.8), (_chromis, 0.1)]),
        ],
        [
          const TaggedSpecies(
            speciesId: 'uuid-1',
            scientificName: 'Chromis multilineata',
          ),
        ],
        now: _now,
      );
      expect(changed.map((i) => i.id), ['named']);
    });

    test('photos still accept a best name that is not suggestable', () {
      final changed = reconcileDecisions(
        [_id('a', suggestable: false)],
        [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        now: _now,
      );
      expect(changed.single.decision, IdentificationDecision.accepted);
    });

    test('decisionsAsShown applies held tags in memory', () {
      final stored = [
        fish('a'),
        fish('b', candidates: [(_chromis, 0.9)]),
      ];
      final shown = decisionsAsShown(stored, [
        const TaggedSpecies(speciesId: 'sp_queen_parrotfish'),
      ], now: _now);
      expect(shown.map((i) => i.id), ['a', 'b']);
      expect(shown[0].decision, IdentificationDecision.accepted);
      expect(shown[1].decision, IdentificationDecision.undecided);
      expect(stored[0].decision, IdentificationDecision.undecided);
    });
  });

  group('groupSuggestions', () {
    test('merges detections of one species, keeping the best crop', () {
      final suggestions = groupSuggestions([
        _id('a', candidates: [(_parrotfish, 0.7)]),
        _id('b', candidates: [(_parrotfish, 0.9), (_tang, 0.05)]),
        _id('c', candidates: [(_parrotfish, 0.8)]),
      ], const []);

      expect(suggestions, hasLength(1));
      final s = suggestions.single;
      expect(s.top.candidate, _parrotfish);
      expect(s.score, 0.9);
      expect(s.count, 3);
      expect(s.cropIdentificationId, 'b');
      expect(s.identificationIds, unorderedEquals(['a', 'b', 'c']));
      expect(s.alternatives.map((c) => c.candidate), [_parrotfish, _tang]);
    });

    test('best score first', () {
      final suggestions = groupSuggestions([
        _id('a', candidates: [(_chromis, 0.6)]),
        _id('b', candidates: [(_tang, 0.95)]),
      ], const []);
      expect(suggestions.map((s) => s.top.candidate), [_tang, _chromis]);
    });

    test('at most three alternatives', () {
      final suggestions = groupSuggestions([
        _id(
          'a',
          candidates: [
            (_parrotfish, 0.7),
            (_tang, 0.1),
            (_chromis, 0.1),
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
          [_id('a')],
          [const TaggedSpecies(speciesId: 'sp_queen_parrotfish')],
        ),
        isEmpty,
      );
    });

    test('a detection that is not suggestable is not suggested', () {
      expect(
        groupSuggestions([_id('a', suggestable: false)], const []),
        isEmpty,
      );
    });

    test('a decided detection is not suggested', () {
      expect(
        groupSuggestions([
          _id('a', decision: IdentificationDecision.rejected),
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
      expect(decide(run: _run()), RefreshAction.none);
    });

    test('a missing crop analyses', () {
      expect(decide(run: _run(), crops: false), RefreshAction.analyse);
    });

    test('a different detector or classifier analyses', () {
      expect(decide(run: _run(), detector: 'det-b'), RefreshAction.analyse);
      expect(decide(run: _run(), classifier: 'clf-b'), RefreshAction.analyse);
    });

    test('a new pack version with the same models renames', () {
      expect(decide(run: _run(), pack: '2026.12.1'), RefreshAction.rename);
    });

    test('a different cell renames, including gaining or losing one', () {
      expect(decide(run: _run(), cell: 1463), RefreshAction.rename);
      expect(decide(run: _run(cell: null), cell: 1462), RefreshAction.rename);
      expect(decide(run: _run(), cell: null), RefreshAction.rename);
    });

    test('renaming without embeddings analyses instead', () {
      expect(
        decide(run: _run(), pack: '2026.12.1', embeddings: false),
        RefreshAction.analyse,
      );
    });
  });

  group('carryDecisions', () {
    const overlapping = IdentificationBox(
      x: 0.12,
      y: 0.1,
      width: 0.2,
      height: 0.2,
    );
    const elsewhere = IdentificationBox(
      x: 0.7,
      y: 0.7,
      width: 0.2,
      height: 0.2,
    );

    test('a fresh detection over a rejected one of the same species carries '
        'the rejection and replaces it', () {
      final result = carryDecisions(
        previous: [_id('old', decision: IdentificationDecision.rejected)],
        fresh: [_id('new', box: overlapping)],
      );
      expect(result.insert.single.id, 'new');
      expect(result.insert.single.decision, IdentificationDecision.rejected);
      expect(result.insert.single.decidedAt, _earlier);
      expect(result.deleteIds, ['old']);
      expect(result.keep, isEmpty);
    });

    test('a fresh detection of another species over a rejected one stays '
        'undecided', () {
      final result = carryDecisions(
        previous: [_id('old', decision: IdentificationDecision.rejected)],
        fresh: [
          _id('new', box: overlapping, candidates: [(_tang, 0.9)]),
        ],
      );
      expect(result.insert.single.decision, IdentificationDecision.undecided);
      expect(result.keep.single.id, 'old');
      expect(result.deleteIds, isEmpty);
    });

    test('a decided row no fresh detection matches is kept', () {
      final result = carryDecisions(
        previous: [_id('old', decision: IdentificationDecision.accepted)],
        fresh: [_id('new', box: elsewhere)],
      );
      expect(result.keep.single.id, 'old');
      expect(result.insert.single.decision, IdentificationDecision.undecided);
    });

    test('old undecided rows are replaced', () {
      final result = carryDecisions(
        previous: [_id('old')],
        fresh: [_id('new', box: overlapping)],
      );
      expect(result.deleteIds, ['old']);
      expect(result.insert.single.id, 'new');
      expect(result.insert.single.decision, IdentificationDecision.undecided);
    });

    test('one decided row is carried to one fresh detection only', () {
      final result = carryDecisions(
        previous: [_id('old', decision: IdentificationDecision.rejected)],
        fresh: [
          _id('n1', box: overlapping),
          _id('n2', box: overlapping),
        ],
      );
      expect(result.insert.map((i) => i.decision), [
        IdentificationDecision.rejected,
        IdentificationDecision.undecided,
      ]);
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
    }) => NamingResult(
      openScore: open,
      candidates: [NamedCandidate(candidate: fish, score: top)],
      locationLimited: true,
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
