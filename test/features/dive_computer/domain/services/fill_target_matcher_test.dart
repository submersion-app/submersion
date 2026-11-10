import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/domain/services/fill_target_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Each download as a 45-minute window from its start: the plan rule reads
/// only the start.
List<({DateTime start, DateTime end})> windows(List<DateTime> starts) => [
  for (final s in starts) (start: s, end: s.add(const Duration(minutes: 45))),
];

void main() {
  const matcher = FillTargetMatcher();
  Dive planned(String id, DateTime at) =>
      Dive(id: id, dateTime: at, isPlanned: true);

  test('pairs a download with the only planned dive on the same day', () {
    final pairs = matcher.pair(
      incoming: windows([DateTime(2026, 6, 1, 14)]),
      targets: [planned('p1', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, {0: 'p1'});
  });

  test('ignores a planned dive on another day', () {
    final pairs = matcher.pair(
      incoming: windows([DateTime(2026, 6, 3, 9)]),
      targets: [planned('p1', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, isEmpty);
  });

  test('pairs several downloads and planned dives in start-time order', () {
    final pairs = matcher.pair(
      incoming: windows([
        DateTime(2026, 6, 1, 14),
        DateTime(2026, 6, 1, 9, 30),
      ]),
      targets: [
        planned('pm', DateTime(2026, 6, 1, 13)),
        planned('am', DateTime(2026, 6, 1, 9)),
      ],
    );
    expect(pairs, {1: 'am', 0: 'pm'});
  });

  test('never suggests one planned dive twice', () {
    final pairs = matcher.pair(
      incoming: windows([DateTime(2026, 6, 1, 9), DateTime(2026, 6, 1, 14)]),
      targets: [planned('p1', DateTime(2026, 6, 1, 9))],
    );
    expect(pairs, {0: 'p1'});
  });

  test('leaves a plan unfilled when there are more plans than downloads', () {
    final pairs = matcher.pair(
      incoming: windows([DateTime(2026, 6, 1, 9)]),
      targets: [
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
      matcher.pair(incoming: windows([DateTime(2026, 6, 1, 8)]), targets: [p]),
      {0: 'p'},
    );
  });

  // Dive times are the dive's wall clock flagged UTC, downloads and plans
  // alike, so the day they fall on is their own date, wherever the device
  // is. Converting them to the device's zone moved the day boundary by its
  // UTC offset. These fail on a machine outside UTC (west of it for the
  // first, east for the third, either side for the second) when that
  // conversion comes back; in UTC CI,
  // test/architecture/dive_time_to_local_single_source_test.dart guards it.
  group('pairs by the dives\' own wall-clock day', () {
    test('a download just after midnight fills that day\'s plan', () {
      final pairs = matcher.pair(
        incoming: windows([DateTime.utc(2026, 9, 14, 0, 30)]),
        targets: [planned('p', DateTime.utc(2026, 9, 14, 9))],
      );
      expect(pairs, {0: 'p'});
    });

    test('a download after midnight fills the previous evening\'s plan', () {
      final pairs = matcher.pair(
        incoming: windows([DateTime.utc(2026, 9, 15, 1)]),
        targets: [planned('p', DateTime.utc(2026, 9, 14, 23))],
      );
      expect(pairs, {0: 'p'});
    });

    test('a plan just before midnight takes that day\'s morning download', () {
      final pairs = matcher.pair(
        incoming: windows([DateTime.utc(2026, 9, 14, 8)]),
        targets: [planned('p', DateTime.utc(2026, 9, 14, 23, 30))],
      );
      expect(pairs, {0: 'p'});
    });
  });

  group('the planned day or the day after', () {
    test('rejects a plan two days before the download', () {
      final pairs = matcher.pair(
        incoming: windows([DateTime.utc(2026, 9, 16, 9)]),
        targets: [planned('p', DateTime.utc(2026, 9, 14, 23))],
      );
      expect(pairs, isEmpty);
    });

    test('rejects a plan on the day after the download', () {
      final pairs = matcher.pair(
        incoming: windows([DateTime.utc(2026, 9, 14, 23)]),
        targets: [planned('p', DateTime.utc(2026, 9, 15, 1))],
      );
      expect(pairs, isEmpty);
    });

    test('after midnight the previous night beats the next morning', () {
      final pairs = matcher.pair(
        incoming: windows([DateTime.utc(2026, 9, 15, 0, 30)]),
        targets: [
          planned('night', DateTime.utc(2026, 9, 14, 23)),
          planned('morning', DateTime.utc(2026, 9, 15, 9)),
        ],
      );
      expect(pairs, {0: 'night'});
    });

    test('a day-old plan loses to the same day plan closer in time', () {
      final pairs = matcher.pair(
        incoming: windows([DateTime.utc(2026, 9, 15, 9)]),
        targets: [
          planned('sat', DateTime.utc(2026, 9, 14, 11)),
          planned('sun', DateTime.utc(2026, 9, 15, 8)),
        ],
      );
      expect(pairs, {0: 'sun'});
    });

    test('each plan still fills once when both days have downloads', () {
      final pairs = matcher.pair(
        incoming: windows([
          DateTime.utc(2026, 9, 15, 9),
          DateTime.utc(2026, 9, 15, 14),
        ]),
        targets: [
          planned('sat', DateTime.utc(2026, 9, 14, 12)),
          planned('sun', DateTime.utc(2026, 9, 15, 13)),
        ],
      );
      expect(pairs, {0: 'sat', 1: 'sun'});
    });

    test('a window across a DST change still means one calendar day', () {
      // Clocks change on 2026-03-08 in US zones, 2026-03-29 in the EU.
      for (final day in [8, 29]) {
        final pairs = matcher.pair(
          incoming: windows([DateTime.utc(2026, 3, day + 1, 1)]),
          targets: [planned('p', DateTime.utc(2026, 3, day, 23))],
        );
        expect(pairs, {0: 'p'});
      }
    });
  });

  test('empty inputs pair nothing', () {
    expect(matcher.pair(incoming: const [], targets: const []), {});
  });

  group('drafts (#637)', () {
    Dive draft(String id, DateTime entry, [DateTime? exit]) => Dive(
      id: id,
      dateTime: entry,
      entryTime: entry,
      exitTime: exit,
      isDraft: true,
    );
    ({DateTime start, DateTime end}) dive(DateTime start, DateTime end) =>
        (start: start, end: end);

    test('a download overlapping a draft fills it', () {
      expect(
        matcher.pair(
          incoming: [
            dive(DateTime(2026, 6, 1, 10, 2), DateTime(2026, 6, 1, 10, 50)),
          ],
          targets: [
            draft('d', DateTime(2026, 6, 1, 10), DateTime(2026, 6, 1, 10, 52)),
          ],
        ),
        {0: 'd'},
      );
    });

    test('a download a little early for the tap still fits (clock drift)', () {
      expect(
        matcher.pair(
          incoming: [
            dive(DateTime(2026, 6, 1, 9, 30), DateTime(2026, 6, 1, 9, 52)),
          ],
          targets: [
            draft('d', DateTime(2026, 6, 1, 10), DateTime(2026, 6, 1, 10, 52)),
          ],
        ),
        {0: 'd'},
      );
    });

    test('a download outside the tolerance does not fit', () {
      expect(
        matcher.pair(
          incoming: [
            dive(DateTime(2026, 6, 1, 9, 10), DateTime(2026, 6, 1, 9, 48)),
          ],
          targets: [
            draft('d', DateTime(2026, 6, 1, 10), DateTime(2026, 6, 1, 10, 52)),
          ],
        ),
        isEmpty,
      );
    });

    test('a download fitting two drafts is left for the diver, and not '
        'offered to a plan', () {
      final result = matcher.match(
        incoming: [dive(DateTime(2026, 6, 1, 10), DateTime(2026, 6, 1, 11))],
        targets: [
          draft('a', DateTime(2026, 6, 1, 9, 40), DateTime(2026, 6, 1, 10, 10)),
          draft('b', DateTime(2026, 6, 1, 10, 30), DateTime(2026, 6, 1, 11)),
          planned('p', DateTime(2026, 6, 1, 10)),
        ],
      );
      expect(result.pairs, isEmpty);
      expect(result.ambiguous, {
        0: unorderedEquals(['a', 'b']),
      });
    });

    test('a dive across midnight pairs with its draft', () {
      expect(
        matcher.pair(
          incoming: [
            dive(DateTime(2026, 6, 1, 23, 52), DateTime(2026, 6, 2, 0, 38)),
          ],
          targets: [
            draft(
              'd',
              DateTime(2026, 6, 1, 23, 50),
              DateTime(2026, 6, 2, 0, 40),
            ),
          ],
        ),
        {0: 'd'},
      );
    });

    test('an open draft reaches three hours past its entry', () {
      expect(
        matcher.pair(
          incoming: [
            dive(DateTime(2026, 6, 1, 12, 40), DateTime(2026, 6, 1, 13, 20)),
          ],
          targets: [draft('d', DateTime(2026, 6, 1, 10))],
        ),
        {0: 'd'},
      );
    });

    test('a draft beats yesterday\'s plan for the same download', () {
      expect(
        matcher.pair(
          incoming: [
            dive(DateTime(2026, 6, 2, 10), DateTime(2026, 6, 2, 10, 50)),
          ],
          targets: [
            planned('yesterday', DateTime(2026, 6, 1, 15)),
            draft('d', DateTime(2026, 6, 2, 10), DateTime(2026, 6, 2, 10, 52)),
          ],
        ),
        {0: 'd'},
      );
    });

    test('plans and drafts in one batch each take their own download', () {
      expect(
        matcher.pair(
          incoming: [
            dive(DateTime(2026, 6, 1, 9), DateTime(2026, 6, 1, 9, 50)),
            dive(DateTime(2026, 6, 1, 14), DateTime(2026, 6, 1, 14, 45)),
          ],
          targets: [
            draft(
              'morning',
              DateTime(2026, 6, 1, 9),
              DateTime(2026, 6, 1, 9, 52),
            ),
            planned('afternoon', DateTime(2026, 6, 1, 14)),
          ],
        ),
        {0: 'morning', 1: 'afternoon'},
      );
    });

    test('a target with both flags is matched as a draft', () {
      final both = draft(
        'both',
        DateTime(2026, 6, 1, 10),
        DateTime(2026, 6, 1, 10, 50),
      ).copyWith(isPlanned: true);
      expect(
        matcher.pair(
          incoming: [
            dive(DateTime(2026, 6, 2, 9), DateTime(2026, 6, 2, 9, 40)),
          ],
          targets: [both],
        ),
        isEmpty,
        reason:
            'as a plan it would take a next-day download; as a draft it '
            'needs its own window',
      );
    });
  });
}
