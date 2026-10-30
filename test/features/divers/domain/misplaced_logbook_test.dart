import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/domain/misplaced_logbook.dart';

Diver _diver(String id, {bool isDefault = false, int createdAt = 0}) {
  final at = DateTime.fromMillisecondsSinceEpoch(createdAt);
  return Diver(
    id: id,
    name: 'Diver $id',
    isDefault: isDefault,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  group('findMisplacedLogbook', () {
    test('names the other profile when the active one has no dives', () {
      final found = findMisplacedLogbook(
        activeDiverId: 'empty',
        divers: [_diver('empty'), _diver('main')],
        diveCounts: {'main': 212},
      );
      expect(found, isNotNull);
      expect(found!.active.id, 'empty');
      expect(found.target.id, 'main');
      expect(found.targetDiveCount, 212);
      expect(found.canMerge, isTrue);
    });

    test('is null when the active profile has dives', () {
      final found = findMisplacedLogbook(
        activeDiverId: 'a',
        divers: [_diver('a'), _diver('b')],
        diveCounts: {'a': 1, 'b': 50},
      );
      expect(found, isNull);
    });

    test('is null when no other profile has dives', () {
      final found = findMisplacedLogbook(
        activeDiverId: 'a',
        divers: [_diver('a'), _diver('b')],
        diveCounts: const {},
      );
      expect(found, isNull);
    });

    test('is null without an active diver, or when it names no profile', () {
      final divers = [_diver('a'), _diver('b')];
      const counts = {'b': 3};
      expect(
        findMisplacedLogbook(
          activeDiverId: null,
          divers: divers,
          diveCounts: counts,
        ),
        isNull,
      );
      expect(
        findMisplacedLogbook(
          activeDiverId: 'gone',
          divers: divers,
          diveCounts: counts,
        ),
        isNull,
      );
    });

    test('ignores dive counts for ids that are not profiles', () {
      final found = findMisplacedLogbook(
        activeDiverId: 'a',
        divers: [_diver('a'), _diver('b')],
        diveCounts: {'deleted-diver': 40},
      );
      expect(found, isNull);
    });

    test('is null when the user kept both profiles', () {
      final found = findMisplacedLogbook(
        activeDiverId: 'empty',
        divers: [_diver('empty'), _diver('main')],
        diveCounts: {'main': 5},
        keptBoth: {misplacedLogbookPairKey('empty', 'main')},
      );
      expect(found, isNull);
    });

    test('a kept pair does not hide a different pair', () {
      final found = findMisplacedLogbook(
        activeDiverId: 'empty',
        divers: [_diver('empty'), _diver('main')],
        diveCounts: {'main': 5},
        keptBoth: {misplacedLogbookPairKey('other', 'main')},
      );
      expect(found, isNotNull);
    });

    test('names the profile with the most dives and offers no merge when '
        'several hold dives', () {
      final found = findMisplacedLogbook(
        activeDiverId: 'empty',
        divers: [_diver('empty'), _diver('spouse'), _diver('me')],
        diveCounts: {'spouse': 30, 'me': 400},
      );
      expect(found!.target.id, 'me');
      expect(found.canMerge, isFalse);
    });

    test('breaks a tie on dive count by default profile, then oldest', () {
      final byDefault = findMisplacedLogbook(
        activeDiverId: 'empty',
        divers: [
          _diver('empty'),
          _diver('older', createdAt: 100),
          _diver('default', isDefault: true, createdAt: 900),
        ],
        diveCounts: {'older': 10, 'default': 10},
      );
      expect(byDefault!.target.id, 'default');

      final byAge = findMisplacedLogbook(
        activeDiverId: 'empty',
        divers: [
          _diver('empty'),
          _diver('newer', createdAt: 900),
          _diver('older', createdAt: 100),
        ],
        diveCounts: {'newer': 10, 'older': 10},
      );
      expect(byAge!.target.id, 'older');
    });
  });

  test('otherDiveHolderIds lists the other profiles with dives', () {
    expect(otherDiveHolderIds({'me': 4, 'a': 2, 'b': 0, 'c': 7}, 'me'), {
      'a',
      'c',
    });
    expect(otherDiveHolderIds(const {}, 'me'), isEmpty);
  });
}
