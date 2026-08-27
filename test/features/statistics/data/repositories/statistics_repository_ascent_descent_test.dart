import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> diver(String id) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> dive(String id, {String? diverId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            diverId: Value(diverId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> computer(String id) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Inserts profile samples as (timestamp seconds, depth meters) pairs.
  Future<void> profile(
    String diveId,
    List<(int, double)> samples, {
    bool isPrimary = true,
    String? computerId,
    String idPrefix = 'row',
  }) async {
    await db.batch((batch) {
      for (final (index, sample) in samples.indexed) {
        batch.insert(
          db.diveProfiles,
          DiveProfilesCompanion(
            id: Value('$diveId-${computerId ?? 'dc'}-$idPrefix-$index'),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            timestamp: Value(sample.$1),
            depth: Value(sample.$2),
          ),
        );
      }
    });
  }

  /// A textbook profile sampled every 15 s with exactly known rates:
  ///   descent 0 -> 30 m over 120 s  = 15 m/min
  ///   bottom  30 m from 135 to 600 s = 0 m/min
  ///   ascent  30 -> 0 m over 300 s  = 6 m/min
  List<(int, double)> textbookProfile() {
    final samples = <(int, double)>[];
    for (var j = 0; j <= 8; j++) {
      samples.add((j * 15, j * 3.75));
    }
    for (var t = 135; t <= 600; t += 15) {
      samples.add((t, 30.0));
    }
    for (var k = 1; k <= 20; k++) {
      samples.add((600 + k * 15, 30.0 - k * 1.5));
    }
    return samples;
  }

  test(
    'derives rates from depth samples when ascent_rate is never stored',
    () async {
      await dive('a');
      await profile('a', textbookProfile());

      final rates = await repo.getAscentDescentRates();

      expect(rates.avgAscent, isNotNull);
      expect(rates.avgDescent, isNotNull);
    },
  );

  test('reports ascent as ascent and descent as descent', () async {
    await dive('a');
    await profile('a', textbookProfile());

    final rates = await repo.getAscentDescentRates();

    // Going shallower is the ascent (6 m/min); going deeper is the descent
    // (15 m/min). Swapping the sign convention would invert these.
    expect(rates.avgAscent, closeTo(6.0, 0.01));
    expect(rates.avgDescent, closeTo(15.0, 0.01));
  });

  test('ignores level-depth samples so the bottom phase does not dilute the '
      'averages', () async {
    await dive('a');
    // Same ascent and descent legs, but a bottom phase four times as long.
    final long = <(int, double)>[];
    for (var j = 0; j <= 8; j++) {
      long.add((j * 15, j * 3.75));
    }
    for (var t = 135; t <= 2400; t += 15) {
      long.add((t, 30.0));
    }
    for (var k = 1; k <= 20; k++) {
      long.add((2400 + k * 15, 30.0 - k * 1.5));
    }
    await profile('a', long);

    final rates = await repo.getAscentDescentRates();

    expect(rates.avgAscent, closeTo(6.0, 0.01));
    expect(rates.avgDescent, closeTo(15.0, 0.01));
  });

  test(
    'excludes slow multi-level drift below the sustained-transit floor',
    () async {
      await dive('a');
      // Descent and ascent legs as above, but the bottom phase now drifts up and
      // down by 0.5 m every 15 s -- a real 2 m/min movement, still far short of
      // ascending or descending. Counting it would pull the ascent average from
      // 6 m/min down to about 4.2.
      final drifting = <(int, double)>[];
      for (var j = 0; j <= 8; j++) {
        drifting.add((j * 15, j * 3.75));
      }
      for (var m = 0; m < 32; m++) {
        drifting.add((135 + m * 15, m.isEven ? 29.5 : 30.0));
      }
      for (var k = 1; k <= 20; k++) {
        drifting.add((600 + k * 15, 30.0 - k * 1.5));
      }
      await profile('a', drifting);

      final rates = await repo.getAscentDescentRates();

      expect(rates.avgAscent, closeTo(6.0, 0.01));
      expect(rates.avgDescent, closeTo(15.0, 0.01));
    },
  );

  test('is unaffected by exact duplicate profile rows', () async {
    await dive('a');
    // A repeated import stores every sample twice. Point-to-point rates halve
    // on this data (the duplicate contributes a zero-length interval), which is
    // why getDiveById and getMergedProfile collapse duplicates before analysis.
    // Averaging depth per time bucket weights the repeats evenly, so the
    // bucket means -- and the rates between them -- are unchanged.
    await profile('a', textbookProfile());
    await profile('a', textbookProfile(), idPrefix: 'reimport');

    final rates = await repo.getAscentDescentRates();

    expect(rates.avgAscent, closeTo(6.0, 0.01));
    expect(rates.avgDescent, closeTo(15.0, 0.01));
  });

  test('counts only the primary profile of a multi-computer dive', () async {
    await dive('a');
    await computer('dc-primary');
    await computer('dc-secondary');
    await profile('a', textbookProfile(), computerId: 'dc-primary');
    // A second computer logged the same dive twice as fast. Its samples are
    // demoted, so they must not contribute to the averages.
    await profile(
      'a',
      [for (var k = 0; k <= 20; k++) (k * 15, k * 3.0)],
      isPrimary: false,
      computerId: 'dc-secondary',
    );

    final rates = await repo.getAscentDescentRates();

    expect(rates.avgAscent, closeTo(6.0, 0.01));
    expect(rates.avgDescent, closeTo(15.0, 0.01));
  });

  test('returns null rates for a profile that never changes depth', () async {
    await dive('a');
    await profile('a', [for (var t = 0; t <= 600; t += 15) (t, 18.0)]);

    final rates = await repo.getAscentDescentRates();

    expect(rates.avgAscent, isNull);
    expect(rates.avgDescent, isNull);
  });

  test('applies the statistics dive filter', () async {
    await db
        .into(db.tags)
        .insert(
          TagsCompanion(
            id: const Value('deep'),
            name: const Value('deep'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await dive('a');
    await profile('a', textbookProfile());
    await dive('b');
    // Twice as fast, and not carrying the tag.
    await profile('b', [
      for (var j = 0; j <= 4; j++) (j * 15, j * 7.5),
      for (var k = 1; k <= 10; k++) (60 + k * 15, 30.0 - k * 3.0),
    ]);
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion(
            id: const Value('a-deep'),
            diveId: const Value('a'),
            tagId: const Value('deep'),
            createdAt: Value(now),
          ),
        );

    final unfiltered = await repo.getAscentDescentRates();
    expect(unfiltered.avgDescent, isNot(closeTo(15.0, 0.01)));

    final filtered = await repo.getAscentDescentRates(
      filter: const DiveFilterState(tagIds: ['deep']),
    );
    expect(filtered.avgAscent, closeTo(6.0, 0.01));
    expect(filtered.avgDescent, closeTo(15.0, 0.01));
  });

  test('scopes the averages to the requested diver', () async {
    await diver('diver-1');
    await diver('diver-2');
    await dive('a', diverId: 'diver-1');
    await profile('a', textbookProfile());
    await dive('b', diverId: 'diver-2');
    // Diver 2 descends and ascends twice as fast.
    await profile('b', [
      for (var j = 0; j <= 4; j++) (j * 15, j * 7.5),
      for (var k = 1; k <= 10; k++) (60 + k * 15, 30.0 - k * 3.0),
    ]);

    final first = await repo.getAscentDescentRates(diverId: 'diver-1');
    expect(first.avgAscent, closeTo(6.0, 0.01));
    expect(first.avgDescent, closeTo(15.0, 0.01));

    final second = await repo.getAscentDescentRates(diverId: 'diver-2');
    expect(second.avgAscent, closeTo(12.0, 0.01));
    expect(second.avgDescent, closeTo(30.0, 0.01));
  });
}
