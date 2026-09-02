import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// The library-wide statistics aggregates want primary series only. Asking
/// SQL for them beats reading every row and filtering in Dart: a demoted
/// original is a whole packed blob, and on a dive edited or logged twice it
/// is the larger half of the table.
void main() {
  late AppDatabase db;
  late ProfileSeriesRepository repo;
  const now = 1750000000000;

  const samples = [
    ProfileSample(timestamp: 0, depth: 0.0),
    ProfileSample(timestamp: 10, depth: 12.0),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ProfileSeriesRepository();
    for (final id in ['dive-1', 'dive-2']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diveDateTime: const Value(now),
              createdAt: const Value(now),
              updatedAt: const Value(now),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test(
    'getPrimaryRowsForDives leaves the demoted rows in the database',
    () async {
      await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        id: 'primary-1',
        now: now,
      );
      await repo.insertSeries(
        diveId: 'dive-1',
        isPrimary: false,
        samples: samples,
        id: 'demoted-1',
        now: now,
      );

      final all = await repo.getRowsForDives(['dive-1']);
      final primary = await repo.getPrimaryRowsForDives(['dive-1']);

      expect(all.map((r) => r.id), containsAll(['primary-1', 'demoted-1']));
      expect(primary.map((r) => r.id), ['primary-1']);
    },
  );

  test('getPrimaryRowsForDives keeps the order getRowsForDives uses', () async {
    await repo.insertSeries(
      diveId: 'dive-2',
      samples: samples,
      id: 'b',
      now: now,
    );
    await repo.insertSeries(
      diveId: 'dive-1',
      samples: samples,
      id: 'a',
      now: now,
    );
    await repo.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      samples: samples,
      id: 'demoted',
      now: now,
    );

    final primary = await repo.getPrimaryRowsForDives(['dive-2', 'dive-1']);
    final filtered = [
      for (final r in await repo.getRowsForDives(['dive-2', 'dive-1']))
        if (r.isPrimary) r.id,
    ];

    expect(primary.map((r) => r.id), filtered);
  });

  test(
    'getPrimaryRowsForDives on no dives asks nothing of the database',
    () async {
      expect(await repo.getPrimaryRowsForDives(const []), isEmpty);
    },
  );
}
