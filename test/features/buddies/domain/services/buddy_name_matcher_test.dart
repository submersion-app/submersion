import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/buddy_name_matcher.dart';

MatchCandidate _c(
  String id,
  String name, {
  String? diverId = 'me',
  int dives = 0,
  int created = 0,
}) => MatchCandidate(
  id: id,
  name: name,
  diverId: diverId,
  diveCount: dives,
  createdAt: DateTime.fromMillisecondsSinceEpoch(created),
);

NameMatch _match(List<MatchCandidate> candidates, String name) =>
    BuddyNameMatcher(candidates, diverId: 'me').match(name);

void main() {
  group('exact matches', () {
    test('match case-insensitively, including non-ASCII letters', () {
      final m = _match([_c('1', 'Éric Dupont')], 'éric dupont');
      expect(
        m,
        isA<ExactMatch>()
            .having((e) => e.candidate.id, 'id', '1')
            .having((e) => e.tieCount, 'tieCount', 1),
      );
    });

    test('ignore extra whitespace', () {
      final m = _match([_c('1', 'Jim Dunfield')], '  Jim   Dunfield ');
      expect(m, isA<ExactMatch>());
    });

    test('rank the diver own record above an unowned namesake', () {
      final m =
          _match([
                _c('unowned', 'Jack Evans', diverId: null, dives: 50),
                _c('own', 'Jack Evans', created: 9),
              ], 'Jack Evans')
              as ExactMatch;
      expect(m.candidate.id, 'own');
      expect(m.tieCount, 2);
    });

    test('then the record with more linked dives', () {
      final m =
          _match([
                _c('few', 'Jack Evans', dives: 1),
                _c('many', 'Jack Evans', dives: 5),
              ], 'Jack Evans')
              as ExactMatch;
      expect(m.candidate.id, 'many');
    });

    test('then the older record', () {
      final m =
          _match([
                _c('newer', 'Jack Evans', created: 5),
                _c('older', 'Jack Evans', created: 2),
              ], 'Jack Evans')
              as ExactMatch;
      expect(m.candidate.id, 'older');
    });

    test('then the id', () {
      final m =
          _match([_c('b', 'Jack Evans'), _c('a', 'Jack Evans')], 'Jack Evans')
              as ExactMatch;
      expect(m.candidate.id, 'a');
    });

    test('win over a prefix suggestion', () {
      final m = _match([_c('leo', 'Leo'), _c('cox', 'Leo Cox')], 'Leo');
      expect(m, isA<ExactMatch>().having((e) => e.candidate.id, 'id', 'leo'));
    });
  });

  group('suggestions', () {
    test('offer a unique whole-word prefix', () {
      final m = _match([_c('cox', 'Leo Cox')], 'Leo');
      expect(
        m,
        isA<NoMatch>().having((n) => n.suggestion?.id, 'suggestion', 'cox'),
      );
    });

    test('are not offered for a partial word', () {
      expect(
        (_match([_c('cox', 'Leo Cox')], 'Le') as NoMatch).suggestion,
        isNull,
      );
      expect(
        (_match([_c('l', 'Leonard')], 'Leo') as NoMatch).suggestion,
        isNull,
      );
    });

    test('are not offered when the prefix names two people', () {
      final m = _match([_c('cox', 'Leo Cox'), _c('diaz', 'Leo Diaz')], 'Leo');
      expect((m as NoMatch).suggestion, isNull);
    });

    test('treat two records of the same name as one person', () {
      final m = _match([
        _c('a', 'Leo Cox', dives: 1),
        _c('b', 'Leo Cox', dives: 7),
      ], 'Leo');
      expect((m as NoMatch).suggestion?.id, 'b');
    });
  });

  test('a blank name never matches', () {
    final m = _match([_c('1', 'Ann')], '   ');
    expect(m, isA<NoMatch>().having((n) => n.suggestion, 'suggestion', null));
  });
}
