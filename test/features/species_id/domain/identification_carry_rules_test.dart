import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';

import 'identification_rules_fixtures.dart';

/// What survives looking at a photo again, and bringing dismissals back
/// for a fresh analysis (issues #4675, #4825).
void main() {
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
        previous: [ruleId('old', decision: IdentificationDecision.rejected)],
        fresh: [ruleId('new', box: overlapping)],
      );
      expect(result.insert.single.id, 'new');
      expect(result.insert.single.decision, IdentificationDecision.rejected);
      expect(result.insert.single.decidedAt, ruleEarlier);
      expect(result.deleteIds, ['old']);
      expect(result.keep, isEmpty);
    });

    test('a fresh detection of another species over a rejected one stays '
        'undecided', () {
      final result = carryDecisions(
        previous: [ruleId('old', decision: IdentificationDecision.rejected)],
        fresh: [
          ruleId('new', box: overlapping, candidates: [(tang, 0.9)]),
        ],
      );
      expect(result.insert.single.decision, IdentificationDecision.undecided);
      expect(result.keep.single.id, 'old');
      expect(result.deleteIds, isEmpty);
    });

    test('a decided row no fresh detection matches is kept', () {
      final result = carryDecisions(
        previous: [ruleId('old', decision: IdentificationDecision.accepted)],
        fresh: [ruleId('new', box: elsewhere)],
      );
      expect(result.keep.single.id, 'old');
      expect(result.insert.single.decision, IdentificationDecision.undecided);
    });

    test('old undecided rows are replaced', () {
      final result = carryDecisions(
        previous: [ruleId('old')],
        fresh: [ruleId('new', box: overlapping)],
      );
      expect(result.deleteIds, ['old']);
      expect(result.insert.single.id, 'new');
      expect(result.insert.single.decision, IdentificationDecision.undecided);
    });

    test('one decided row is carried to one fresh detection only', () {
      final result = carryDecisions(
        previous: [ruleId('old', decision: IdentificationDecision.rejected)],
        fresh: [
          ruleId('n1', box: overlapping),
          ruleId('n2', box: overlapping),
        ],
      );
      expect(result.insert.map((i) => i.decision), [
        IdentificationDecision.rejected,
        IdentificationDecision.undecided,
      ]);
    });

    test('a decided match keeps the name the diver gave it', () {
      final result = carryDecisions(
        previous: [
          ruleId(
            'old',
            decision: IdentificationDecision.accepted,
            decidedSpeciesId: 'sp_x',
          ).copyWith(claimedSpeciesId: () => 'sp_x'),
        ],
        fresh: [ruleId('new', box: overlapping)],
      );
      expect(result.insert.single.decision, IdentificationDecision.accepted);
      expect(result.insert.single.claimedSpeciesId, 'sp_x');
    });

    group('a reopened detection (issue #4825)', () {
      final reopened = ruleId('old').copyWith(decidedAt: ruleEarlier);

      test('is carried to the fresh detection of the same animal', () {
        final result = carryDecisions(
          previous: [reopened],
          fresh: [ruleId('new', box: overlapping)],
        );
        expect(result.insert.single.decision, IdentificationDecision.undecided);
        expect(result.insert.single.decidedAt, ruleEarlier);
        expect(result.insert.single.reopened, isTrue);
        expect(result.deleteIds, ['old']);
        expect(result.keep, isEmpty);
      });

      test('is dropped when the fresh run does not find it again', () {
        final result = carryDecisions(
          previous: [reopened],
          fresh: [ruleId('new', box: elsewhere)],
        );
        expect(result.deleteIds, ['old']);
        expect(result.keep, isEmpty);
        expect(result.insert.single.reopened, isFalse);
      });

      test('is not carried to an animal the app names differently', () {
        final result = carryDecisions(
          previous: [reopened],
          fresh: [
            ruleId('new', box: overlapping, candidates: [(tang, 0.9)]),
          ],
        );
        expect(result.insert.single.reopened, isFalse);
        expect(result.deleteIds, ['old']);
      });
    });

    group('a name the diver gave a detection, not yet tagged', () {
      final claimed = ruleId('old').copyWith(claimedSpeciesId: () => 'sp_x');

      test('is carried by overlap alone, whatever the app now calls it', () {
        final result = carryDecisions(
          previous: [claimed],
          fresh: [
            ruleId('new', box: overlapping, candidates: [(tang, 0.9)]),
          ],
        );
        expect(result.insert.single.id, 'new');
        expect(result.insert.single.claimedSpeciesId, 'sp_x');
        expect(result.deleteIds, ['old']);
        expect(result.keep, isEmpty);
      });

      test('goes to the fresh detection that overlaps it most', () {
        const closer = IdentificationBox(
          x: 0.1,
          y: 0.1,
          width: 0.2,
          height: 0.2,
        );
        final result = carryDecisions(
          previous: [claimed],
          fresh: [
            ruleId('n1', box: overlapping),
            ruleId('n2', box: closer),
          ],
        );
        expect(result.insert.map((i) => i.claimedSpeciesId), [null, 'sp_x']);
      });

      test('is kept as it is when no fresh detection overlaps it', () {
        final result = carryDecisions(
          previous: [claimed],
          fresh: [ruleId('new', box: elsewhere)],
        );
        expect(result.keep.single.id, 'old');
        expect(result.keep.single.claimedSpeciesId, 'sp_x');
        expect(result.deleteIds, isEmpty);
        expect(result.insert.single.claimedSpeciesId, isNull);
      });

      test('on a reopened row is carried by overlap too, still reopened', () {
        final result = carryDecisions(
          previous: [claimed.copyWith(decidedAt: ruleEarlier)],
          fresh: [
            ruleId('new', box: overlapping, candidates: [(tang, 0.9)]),
          ],
        );
        expect(result.insert.single.claimedSpeciesId, 'sp_x');
        expect(result.insert.single.reopened, isTrue);
        expect(result.deleteIds, ['old']);
      });

      test('never takes the fresh detection a decision was carried to', () {
        final result = carryDecisions(
          previous: [
            ruleId('gone', decision: IdentificationDecision.rejected),
            claimed,
          ],
          fresh: [ruleId('new', box: overlapping)],
        );
        expect(result.insert.single.decision, IdentificationDecision.rejected);
        expect(result.insert.single.claimedSpeciesId, isNull);
        expect(result.keep.single.id, 'old');
      });
    });
  });

  group('reopenDismissed (issue #4825)', () {
    final later = DateTime.utc(2026, 11, 21);

    test('turns a dismissal into an undecided row that remembers it', () {
      final changed = reopenDismissed([
        ruleId('a', decision: IdentificationDecision.rejected),
        ruleId('b'),
        ruleId('c', decision: IdentificationDecision.accepted),
      ], now: later);
      expect(changed.map((i) => i.id), ['a']);
      expect(changed.single.decision, IdentificationDecision.undecided);
      expect(changed.single.decidedAt, later);
      expect(changed.single.reopened, isTrue);
      expect(changed.single.saidByDiver, isTrue);
    });

    test('a reopened row names no species: it was dismissed, not tagged', () {
      final changed = reopenDismissed([
        ruleId(
          'a',
          decision: IdentificationDecision.rejected,
          decidedSpeciesId: 'sp_x',
        ),
      ], now: later);
      expect(changed.single.decidedSpeciesId, isNull);
      expect(changed.single.reopened, isTrue);
    });

    test('an ordinary undecided row is neither reopened nor said', () {
      expect(ruleId('b').reopened, isFalse);
      expect(ruleId('b').saidByDiver, isFalse);
    });

    test('a reopened row is offered again as a suggestion', () {
      final changed = reopenDismissed([
        ruleId('a', decision: IdentificationDecision.rejected),
      ], now: later);
      expect(groupSuggestions(changed, const []), hasLength(1));
    });
  });
}
