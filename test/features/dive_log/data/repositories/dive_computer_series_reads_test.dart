import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveComputerRepository computers;
  late ProfileSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    computers = DiveComputerRepository();
    series = ProfileSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final computer in ['comp-1', 'comp-2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: computer,
              name: computer,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('computer ids and the primary computer come from the series', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
      now: now,
    );
    expect((await computers.getComputerIdsForDive('dive-1')).toSet(), {
      'comp-1',
      'comp-2',
    });
    expect(await computers.getPrimaryComputerId('dive-1'), 'comp-1');
  });

  test('a dive whose only series has a null computer id has no computer ids '
      'and no primary computer', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    expect(await computers.getComputerIdsForDive('dive-1'), isEmpty);
    expect(await computers.getPrimaryComputerId('dive-1'), isNull);
  });

  test('a dive with no series has no computers', () async {
    expect(await computers.getComputerIdsForDive('dive-1'), isEmpty);
    expect(await computers.getPrimaryComputerId('dive-1'), isNull);
  });
}
