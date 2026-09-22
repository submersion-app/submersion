import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/domain/services/planned_dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const matcher = PlannedDiveMatcher();
  Dive planned(String id, DateTime at) =>
      Dive(id: id, dateTime: at, isPlanned: true);

  test('pairs a download with the only planned dive on the same day', () {
    final pairs = matcher.pair(
      incomingStarts: [DateTime(2026, 6, 1, 14)],
      plannedDives: [planned('p1', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, {0: 'p1'});
  });

  test('ignores a planned dive on another day', () {
    final pairs = matcher.pair(
      incomingStarts: [DateTime(2026, 6, 2, 9)],
      plannedDives: [planned('p1', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, isEmpty);
  });

  test('pairs several downloads and planned dives in start-time order', () {
    final pairs = matcher.pair(
      incomingStarts: [DateTime(2026, 6, 1, 14), DateTime(2026, 6, 1, 9, 30)],
      plannedDives: [
        planned('pm', DateTime(2026, 6, 1, 13)),
        planned('am', DateTime(2026, 6, 1, 9)),
      ],
    );
    expect(pairs, {1: 'am', 0: 'pm'});
  });

  test('never suggests one planned dive twice', () {
    final pairs = matcher.pair(
      incomingStarts: [DateTime(2026, 6, 1, 9), DateTime(2026, 6, 1, 14)],
      plannedDives: [planned('p1', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, {0: 'p1'});
  });

  test('leaves a plan unfilled when there are more plans than downloads', () {
    final pairs = matcher.pair(
      incomingStarts: [DateTime(2026, 6, 1, 9)],
      plannedDives: [
        planned('a', DateTime(2026, 6, 1, 8)),
        planned('b', DateTime(2026, 6, 1, 12)),
      ],
    );
    expect(pairs, {0: 'a'});
  });

  test('uses entryTime over dateTime when present', () {
    final p = Dive(
      id: 'p',
      dateTime: DateTime(2026, 5, 31, 23),
      entryTime: DateTime(2026, 6, 1, 1),
      isPlanned: true,
    );
    expect(
      matcher.pair(
        incomingStarts: [DateTime(2026, 6, 1, 8)],
        plannedDives: [p],
      ),
      {0: 'p'},
    );
  });

  test('empty inputs pair nothing', () {
    expect(matcher.pair(incomingStarts: const [], plannedDives: const []), {});
  });
}
