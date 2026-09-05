// Uint8List and Value come from the drift import, which re-exports them.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> insertDive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// A profile series row with no sourceId, the state the adoption exists for.
  Future<void> insertUnattributedSeries(String diveId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveProfileSeries)
        .insert(
          DiveProfileSeriesCompanion(
            id: Value('series-$diveId'),
            diveId: Value(diveId),
            sourceId: const Value.absent(),
            sampleCount: const Value(2),
            startTimestamp: const Value(0),
            endTimestamp: const Value(60),
            maxDepth: const Value(10.0),
            firstDepth: const Value(0.0),
            lastDepth: const Value(0.0),
            codecVersion: const Value(1),
            samples: Value(Uint8List.fromList([0, 1, 2, 3])),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<String?> sourceIdOfSeries(String diveId) async {
    final row = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.diveId.equals(diveId))).getSingle();
    return row.sourceId;
  }

  Future<int> countSources(String diveId) async {
    final rows = await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.equals(diveId))).get();
    return rows.length;
  }

  DiveDataSourcesCompanion reading(
    String id,
    String diveId, {
    bool isPrimary = false,
  }) {
    final stamp = DateTime(2019, 6, 2, 18, 41, 7);
    return DiveDataSourcesCompanion(
      id: Value(id),
      diveId: Value(diveId),
      isPrimary: Value(isPrimary),
      importedAt: Value(stamp),
      createdAt: Value(stamp),
    );
  }

  test(
    'adopts unattributed profiles when the batch leaves one source',
    () async {
      await insertDive('dive-1');
      await insertUnattributedSeries('dive-1');

      await repository.saveComputerReadings([
        reading('src-a', 'dive-1', isPrimary: true),
      ]);

      expect(await sourceIdOfSeries('dive-1'), 'src-a');
    },
  );

  test('does not adopt when the batch leaves more than one source', () async {
    // The guard exists because with two sources the unattributed rows could
    // belong to either. Inserting one at a time would let the first row claim
    // everything before the second row exists, so a restored two computer
    // dive would attribute the whole profile to whichever went in first.
    await insertDive('dive-1');
    await insertUnattributedSeries('dive-1');

    await repository.saveComputerReadings([
      reading('src-a', 'dive-1', isPrimary: true),
      reading('src-b', 'dive-1'),
    ]);

    expect(await sourceIdOfSeries('dive-1'), isNull);
    expect(await countSources('dive-1'), 2);
  });

  test('inserts every row in the batch', () async {
    await insertDive('dive-1');

    await repository.saveComputerReadings([
      reading('src-a', 'dive-1', isPrimary: true),
      reading('src-b', 'dive-1'),
      reading('src-c', 'dive-1'),
    ]);

    expect(await countSources('dive-1'), 3);
  });

  test('an empty batch is a no-op', () async {
    await repository.saveComputerReadings(const []);
  });
}
