import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/models/dive_match_record.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';

/// Counts the pairs the checker scores, which is what the time index exists
/// to keep down (issue #3855).
class _CountingMatcher extends DiveMatcher {
  int scored = 0;

  @override
  double calculateMatchScore({
    required DateTime wearableStartTime,
    required double wearableMaxDepth,
    required int wearableDurationSeconds,
    required DateTime existingStartTime,
    required double existingMaxDepth,
    required int existingDurationSeconds,
  }) {
    scored++;
    return super.calculateMatchScore(
      wearableStartTime: wearableStartTime,
      wearableMaxDepth: wearableMaxDepth,
      wearableDurationSeconds: wearableDurationSeconds,
      existingStartTime: existingStartTime,
      existingMaxDepth: existingMaxDepth,
      existingDurationSeconds: existingDurationSeconds,
    );
  }
}

Map<int, DiveMatchResult> matchesFor(
  List<Map<String, dynamic>> incoming,
  List<DiveMatchRecord> stored, {
  DiveMatcher matcher = const DiveMatcher(),
  Map<String, String> sourceUuids = const {},
  bool checkIntraBatch = false,
}) {
  return const ImportDuplicateChecker()
      .check(
        payload: ImportPayload(entities: {ImportEntityType.dives: incoming}),
        existingDives: stored,
        existingSites: const [],
        existingTrips: const [],
        existingEquipment: const [],
        existingBuddies: const [],
        existingDiveCenters: const [],
        existingCertifications: const [],
        existingTags: const [],
        existingDiveTypes: const [],
        existingSourceUuidByDiveId: sourceUuids,
        matcher: matcher,
        checkIntraBatch: checkIntraBatch,
      )
      .diveMatches;
}

DiveMatchRecord storedDive(String id, DateTime at, {String? siteName}) =>
    DiveMatchRecord(
      id: id,
      dateTime: at,
      maxDepth: 20,
      runtime: const Duration(minutes: 50),
      siteName: siteName,
    );

Map<String, dynamic> incomingDive(DateTime at, {String? sourceUuid}) => {
  'dateTime': at,
  'maxDepth': 20.0,
  'runtime': const Duration(minutes: 50),
  'sourceUuid': ?sourceUuid,
};

/// The fuzzy pass as it was before the index: every stored dive in turn.
DiveMatchResult? bestByScoringEveryDive(
  Map<String, dynamic> dive,
  List<DiveMatchRecord> stored,
) {
  const matcher = DiveMatcher();
  final at = dive['dateTime'] as DateTime?;
  if (at == null) return null;
  final depth = dive['maxDepth'] as double? ?? 0;
  final seconds = (dive['runtime'] as Duration?)?.inSeconds ?? 0;
  DiveMatchResult? best;
  for (final existing in stored) {
    final score = matcher.calculateMatchScore(
      wearableStartTime: at,
      wearableMaxDepth: depth,
      wearableDurationSeconds: seconds,
      existingStartTime: existing.dateTime,
      existingMaxDepth: existing.maxDepth ?? 0,
      existingDurationSeconds: existing.durationSeconds,
    );
    if (matcher.isPossibleDuplicate(score) &&
        (best == null || score > best.score)) {
      best = DiveMatchResult(
        diveId: existing.id,
        score: score,
        timeDifferenceMs: at.difference(existing.dateTime).inMilliseconds.abs(),
      );
    }
  }
  return best;
}

/// The batch pass as it was before the index: every earlier dive in turn,
/// the first possible duplicate winning. Dive index to earlier index.
Map<int, int> pairsByComparingEveryEarlierDive(
  List<Map<String, dynamic>> dives,
) {
  const matcher = DiveMatcher();
  double depthOf(Map<String, dynamic> dive) => dive['maxDepth'] as double? ?? 0;
  int secondsOf(Map<String, dynamic> dive) =>
      (dive['runtime'] as Duration?)?.inSeconds ?? 0;

  final pairs = <int, int>{};
  for (var i = 1; i < dives.length; i++) {
    final at = dives[i]['dateTime'] as DateTime?;
    if (at == null) continue;
    for (var j = 0; j < i; j++) {
      if (pairs.containsKey(j)) continue;
      final otherAt = dives[j]['dateTime'] as DateTime?;
      if (otherAt == null) continue;
      final score = matcher.calculateMatchScore(
        wearableStartTime: at,
        wearableMaxDepth: depthOf(dives[i]),
        wearableDurationSeconds: secondsOf(dives[i]),
        existingStartTime: otherAt,
        existingMaxDepth: depthOf(dives[j]),
        existingDurationSeconds: secondsOf(dives[j]),
      );
      if (matcher.isPossibleDuplicate(score)) {
        pairs[i] = j;
        break;
      }
    }
  }
  return pairs;
}

void main() {
  final firstStored = DateTime.utc(2015);
  final yearsLater = DateTime.utc(2040);

  List<DiveMatchRecord> logbook(int size) => [
    for (var i = 0; i < size; i++)
      storedDive('dive-$i', firstStored.add(Duration(hours: 6 * i))),
  ];

  group('pairs scored', () {
    test('1,000 dives years from 5,000 stored ones score no pair', () {
      final matcher = _CountingMatcher();

      final matches = matchesFor(
        [
          for (var i = 0; i < 1000; i++)
            incomingDive(yearsLater.add(Duration(hours: i))),
        ],
        logbook(5000),
        matcher: matcher,
      );

      expect(matches, isEmpty);
      expect(matcher.scored, 0);
    });

    test('5,000 dives years from 5,000 stored ones score no pair', () {
      final matcher = _CountingMatcher();

      matchesFor(
        [
          for (var i = 0; i < 5000; i++)
            incomingDive(yearsLater.add(Duration(hours: i))),
        ],
        logbook(5000),
        matcher: matcher,
      );

      expect(matcher.scored, 0);
    });

    test('a re-import scores each dive against its neighbours alone', () {
      final stored = logbook(5000);
      final matcher = _CountingMatcher();

      final matches = matchesFor(
        [for (final dive in stored) incomingDive(dive.dateTime)],
        stored,
        matcher: matcher,
      );

      expect(matches, hasLength(5000));
      expect(matcher.scored, 5000);
    });

    test('a batch of many dives does not compare every pair with itself', () {
      final matcher = _CountingMatcher();

      final matches = matchesFor(
        [
          for (var i = 0; i < 5000; i++)
            incomingDive(yearsLater.add(Duration(hours: i))),
        ],
        const [],
        matcher: matcher,
        checkIntraBatch: true,
      );

      expect(matches, isEmpty);
      expect(matcher.scored, 0);
    });
  });

  group('matching keeps its meaning', () {
    final at = DateTime.utc(2024, 6, 1, 9);

    test('a dive just inside the window still matches', () {
      final matches = matchesFor(
        [incomingDive(at.add(const Duration(minutes: 14, seconds: 59)))],
        [storedDive('near', at)],
      );

      expect(matches[0]?.diveId, 'near');
    });

    test('a dive exactly at the window does not', () {
      final matches = matchesFor(
        [incomingDive(at.add(DiveMatcher.candidateWindow))],
        [storedDive('far', at)],
      );

      expect(matches, isEmpty);
    });

    test('a dive before the stored one matches as well as one after', () {
      final matches = matchesFor(
        [incomingDive(at.subtract(const Duration(minutes: 4)))],
        [storedDive('near', at)],
      );

      expect(matches[0]?.diveId, 'near');
    });

    test('the best score wins, wherever it sits in the logbook', () {
      final matches = matchesFor(
        [incomingDive(at)],
        [
          storedDive('ten-off', at.add(const Duration(minutes: 10))),
          storedDive('exact', at),
          storedDive('eight-off', at.subtract(const Duration(minutes: 8))),
        ],
      );

      expect(matches[0]?.diveId, 'exact');
    });

    test('a tie goes to the dive first in the logbook, either way round', () {
      final later = storedDive('later', at.add(const Duration(minutes: 3)));
      final earlier = storedDive(
        'earlier',
        at.subtract(const Duration(minutes: 3)),
      );

      expect(
        matchesFor([incomingDive(at)], [later, earlier])[0]?.diveId,
        'later',
      );
      expect(
        matchesFor([incomingDive(at)], [earlier, later])[0]?.diveId,
        'earlier',
      );
    });

    test('the match carries the stored dive\'s site name', () {
      final matches = matchesFor(
        [incomingDive(at)],
        [storedDive('dive', at, siteName: 'Blue Hole')],
      );

      expect(matches[0]?.siteName, 'Blue Hole');
    });

    test('an exact source id still matches a dive far away in time', () {
      final matches = matchesFor(
        [incomingDive(yearsLater, sourceUuid: 'uuid-1')],
        [storedDive('dive', at, siteName: 'Blue Hole')],
        sourceUuids: const {'dive': 'uuid-1'},
      );

      expect(matches[0]?.diveId, 'dive');
      expect(matches[0]?.matchedExistingSource, isTrue);
      expect(matches[0]?.siteName, 'Blue Hole');
    });

    test('a dive with no time is left unmatched', () {
      final matches = matchesFor(
        [
          {'maxDepth': 20.0},
        ],
        [storedDive('dive', at)],
      );

      expect(matches, isEmpty);
    });

    test('a stored dive with no depth or time scores as it always has', () {
      final matches = matchesFor(
        [incomingDive(at)],
        [DiveMatchRecord(id: 'bare', dateTime: at)],
      );

      // Only the time band can score, 0.5 of 1.0, which is just a possible
      // duplicate; the missing figures are reported as unknown, not zero.
      expect(matches[0]?.score, closeTo(0.5, 0.001));
      expect(matches[0]?.depthDifferenceMeters, isNull);
      expect(matches[0]?.durationDifferenceSeconds, isNull);
    });

    test('batch dives within the window still pair with the earliest', () {
      final matches = matchesFor(
        [
          incomingDive(at.add(const Duration(minutes: 2))),
          incomingDive(at),
          incomingDive(at.add(const Duration(minutes: 1))),
        ],
        const [],
        checkIntraBatch: true,
      );

      expect(matches[1]?.inBatchIndex, 0);
      expect(matches[2]?.inBatchIndex, 0);
    });

    test(
      'a batch dive flagged itself is not used as the pair for a later one',
      () {
        final matches = matchesFor(
          [
            incomingDive(at),
            incomingDive(at.add(const Duration(minutes: 13))),
            incomingDive(at.add(const Duration(minutes: 26))),
          ],
          const [],
          checkIntraBatch: true,
        );

        expect(matches[1]?.inBatchIndex, 0);
        expect(matches.containsKey(2), isFalse);
      },
    );

    test('agrees with comparing every earlier dive across a mixed batch', () {
      final random = Random(1893);
      final start = DateTime.utc(2020);
      final depths = <double?>[null, 0, 18, 20, 22, 30];
      final runtimes = <Duration?>[
        null,
        const Duration(minutes: 45),
        const Duration(minutes: 50),
        const Duration(minutes: 58),
      ];
      T pick<T>(List<T> from) => from[random.nextInt(from.length)];

      final batch = [
        for (var i = 0; i < 500; i++)
          {
            'dateTime': i % 50 == 0
                ? null
                : start.add(
                    Duration(
                      hours: 6 * random.nextInt(60),
                      minutes: random.nextInt(40),
                    ),
                  ),
            'maxDepth': pick(depths),
            'runtime': pick(runtimes),
          },
      ];

      final matches = matchesFor(batch, const [], checkIntraBatch: true);

      final expected = pairsByComparingEveryEarlierDive(batch);
      expect(expected.length, greaterThan(20), reason: 'needs some pairs');
      expect({
        for (final MapEntry(:key, :value) in matches.entries)
          key: value.inBatchIndex,
      }, expected);
    });

    test('agrees with scoring every dive across a mixed logbook', () {
      final random = Random(3855);
      final start = DateTime.utc(2020);
      DateTime clustered() => start.add(
        Duration(hours: 6 * random.nextInt(200), minutes: random.nextInt(40)),
      );
      final depths = <double?>[null, 0, 18, 20, 22, 30];
      final runtimes = <Duration?>[
        null,
        const Duration(minutes: 45),
        const Duration(minutes: 50),
        const Duration(minutes: 58),
      ];
      T pick<T>(List<T> from) => from[random.nextInt(from.length)];

      final stored = [
        for (var i = 0; i < 600; i++)
          DiveMatchRecord(
            id: 'dive-$i',
            dateTime: clustered(),
            maxDepth: pick(depths),
            runtime: pick(runtimes),
          ),
      ];
      final incoming = [
        for (var i = 0; i < 400; i++)
          {
            'dateTime': i % 40 == 0 ? null : clustered(),
            'maxDepth': pick(depths),
            'runtime': pick(runtimes),
          },
      ];

      final matches = matchesFor(incoming, stored);

      var matched = 0;
      for (var i = 0; i < incoming.length; i++) {
        final expected = bestByScoringEveryDive(incoming[i], stored);
        expect(matches[i]?.diveId, expected?.diveId, reason: 'dive $i');
        expect(matches[i]?.score, expected?.score, reason: 'dive $i');
        expect(
          matches[i]?.timeDifferenceMs,
          expected?.timeDifferenceMs,
          reason: 'dive $i',
        );
        if (expected != null) matched++;
      }
      expect(
        matched,
        greaterThan(20),
        reason: 'the data must exercise a match',
      );
    });
  });
}
