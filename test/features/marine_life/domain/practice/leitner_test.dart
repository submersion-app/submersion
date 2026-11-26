import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/practice/leitner.dart';

void main() {
  final now = DateTime.utc(2026, 11, 25, 12);

  PracticeState state(String id, {int box = 1, DateTime? due}) =>
      PracticeState(speciesId: id, box: box, dueAt: due ?? now);

  test('right answer in box 1 moves to box 2 due in 1 day', () {
    final next = applyAnswer(state('a'), correct: true, now: now);
    expect(next.box, 2);
    expect(next.dueAt, now.add(const Duration(days: 1)));
    expect(next.rightCount, 1);
    expect(next.lastPractisedAt, now);
  });

  test('box 5 stays 5 and is due in 21 days', () {
    final next = applyAnswer(state('a', box: 5), correct: true, now: now);
    expect(next.box, 5);
    expect(next.dueAt, now.add(const Duration(days: 21)));
  });

  test('box 3 and 4 wait 3 and 7 days', () {
    expect(
      applyAnswer(state('a', box: 2), correct: true, now: now).dueAt,
      now.add(const Duration(days: 3)),
    );
    expect(
      applyAnswer(state('a', box: 3), correct: true, now: now).dueAt,
      now.add(const Duration(days: 7)),
    );
  });

  test('wrong answer goes to box 1 due now and counts wrong', () {
    final next = applyAnswer(state('a', box: 4), correct: false, now: now);
    expect(next.box, 1);
    expect(next.dueAt, now);
    expect(next.wrongCount, 1);
    expect(next.rightCount, 0);
  });

  test('fresh state is box 1 due now', () {
    final fresh = PracticeState.fresh('a', now);
    expect(fresh.box, 1);
    expect(fresh.dueAt, now);
  });

  test('session takes due species first, lowest box first', () {
    final session = pickPracticeSession(
      pool: const ['a', 'b', 'c', 'd'],
      states: {
        'a': state('a', box: 3, due: now.subtract(const Duration(days: 1))),
        'b': state('b', box: 1, due: now),
        'c': state('c', box: 2, due: now.add(const Duration(days: 2))),
        'd': state('d', box: 2, due: now.subtract(const Duration(hours: 1))),
      },
      now: now,
      random: Random(1),
    );
    expect(session.take(3), ['b', 'd', 'a']);
    expect(session.last, 'c');
  });

  test('then never practised, then the rest', () {
    final session = pickPracticeSession(
      pool: const ['due', 'new1', 'new2', 'later'],
      states: {
        'due': state('due', due: now),
        'later': state('later', box: 4, due: now.add(const Duration(days: 5))),
      },
      now: now,
      random: Random(1),
    );
    expect(session.first, 'due');
    expect(session.sublist(1, 3).toSet(), {'new1', 'new2'});
    expect(session.last, 'later');
  });

  test('session is at most 10 and never repeats', () {
    final pool = [for (var i = 0; i < 30; i++) 's$i'];
    final session = pickPracticeSession(
      pool: pool,
      states: const {},
      now: now,
      random: Random(1),
    );
    expect(session, hasLength(10));
    expect(session.toSet(), hasLength(10));
  });

  test('pool of 6 gives a session of 6', () {
    final session = pickPracticeSession(
      pool: const ['a', 'b', 'c', 'd', 'e', 'f'],
      states: const {},
      now: now,
      random: Random(1),
    );
    expect(session.toSet(), {'a', 'b', 'c', 'd', 'e', 'f'});
  });

  const categories = {
    'grouper': SpeciesCategory.fish,
    'snapper': SpeciesCategory.fish,
    'grunt': SpeciesCategory.fish,
    'wrasse': SpeciesCategory.fish,
    'manta': SpeciesCategory.ray,
    'turtle': SpeciesCategory.turtle,
  };

  test('distractors prefer the same category', () {
    final picks = pickDistractors(
      answer: 'grouper',
      categoryOf: categories,
      random: Random(3),
    );
    expect(picks.toSet(), {'snapper', 'grunt', 'wrasse'});
  });

  test(
    'distractors top up from other categories when the category is small',
    () {
      final picks = pickDistractors(
        answer: 'manta',
        categoryOf: categories,
        random: Random(3),
      );
      expect(picks, hasLength(3));
      expect(picks.toSet(), hasLength(3));
    },
  );

  test('distractors never include the answer', () {
    for (var seed = 0; seed < 20; seed++) {
      final picks = pickDistractors(
        answer: 'turtle',
        categoryOf: categories,
        random: Random(seed),
      );
      expect(picks, isNot(contains('turtle')));
    }
  });
}
