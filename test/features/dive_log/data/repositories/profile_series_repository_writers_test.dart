import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProfileSeriesRepository repo;

  Future<void> seedParents(AppDatabase target) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await target
        .into(target.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await target
        .into(target.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Comp 1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await target
        .into(target.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-1',
            diveId: 'dive-1',
            computerId: const Value('comp-1'),
            isPrimary: const Value(true),
            importedAt: DateTime.fromMillisecondsSinceEpoch(now),
            createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await seedParents(db);
    repo = ProfileSeriesRepository();
  });

  tearDown(tearDownTestDatabase);

  test(
    'insertSeries sorts by timestamp and keeps input order for ties',
    () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        samples: const [
          ProfileSample(timestamp: 20, depth: 2.0),
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 10, depth: 1.0),
          ProfileSample(timestamp: 10, depth: 1.5),
        ],
        now: 1000,
      );
      final series = await repo.getSeriesById(id);
      expect(series!.samples.map((s) => (s.timestamp, s.depth)).toList(), [
        (0, 0.0),
        (10, 1.0),
        (10, 1.5),
        (20, 2.0),
      ]);
    },
  );

  test(
    'hasSeriesForComputer is true only for the computer that contributed',
    () async {
      await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      // A null-computer series never satisfies a specific computer's guard.
      await repo.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );
      expect(await repo.hasSeriesForComputer('dive-1', 'comp-1'), isTrue);
      expect(await repo.hasSeriesForComputer('dive-1', 'comp-2'), isFalse);
    },
  );

  test('hasAnySeries is false before and true after an insert', () async {
    expect(await repo.hasAnySeries('dive-1'), isFalse);
    await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    expect(await repo.hasAnySeries('dive-1'), isTrue);
  });

  test(
    'ownsAny follows the FK first, then the null-source computer rule',
    () async {
      await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: null,
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      expect(
        await repo.ownsAny('dive-1', sourceId: 'src-1', computerId: 'comp-1'),
        isTrue,
      );
      expect(
        await repo.ownsAny(
          'dive-1',
          sourceId: 'src-other',
          computerId: 'comp-x',
        ),
        isFalse,
      );
      expect(
        await repo.ownsAny('dive-1', sourceId: 'src-other', computerId: null),
        isFalse,
      );
    },
  );

  test(
    'adoptUnattributed stamps only null-source series and restamps hlc',
    () async {
      final orphan = await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final owned = await repo.insertSeries(
        diveId: 'dive-1',
        sourceId: 'src-1',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );
      final before = (await db.select(db.diveProfileSeries).get())
          .firstWhere((r) => r.id == orphan)
          .hlc;
      expect(await repo.adoptUnattributed('dive-1', 'src-1', now: 2000), 1);
      final rows = await db.select(db.diveProfileSeries).get();
      final adopted = rows.firstWhere((r) => r.id == orphan);
      expect(adopted.sourceId, 'src-1');
      expect(adopted.updatedAt, 2000);
      expect(adopted.hlc, isNot(before));
      expect(rows.firstWhere((r) => r.id == owned).sourceId, 'src-1');
      expect(await repo.adoptUnattributed('dive-1', 'src-1'), 0);
    },
  );

  test(
    'deleteByComputer matches the computer or the null-computer series',
    () async {
      final byComp = await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final manual = await repo.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );
      expect(await repo.deleteByComputer('dive-1', 'comp-1'), [byComp]);
      expect(await repo.deleteByComputer('dive-1', null), [manual]);
      expect(await repo.getSeriesForDive('dive-1'), isEmpty);
      final tombstones = await db.select(db.deletionLog).get();
      expect(tombstones.map((t) => t.recordId).toSet(), {byComp, manual});
      expect(tombstones.map((t) => t.entityType).toSet(), {
        'diveProfileSeries',
      });
    },
  );

  test(
    'deleteByIds deletes exactly the ids given and tolerates an empty list',
    () async {
      final a = await repo.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final b = await repo.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );
      expect(await repo.deleteByIds(const []), isEmpty);
      expect(await repo.deleteByIds([a]), [a]);
      expect((await repo.getSeriesForDive('dive-1')).map((s) => s.id), [b]);
    },
  );

  test('getRowsForDives returns raw rows for the given dives only', () async {
    final a = await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    expect(await repo.getRowsForDives(const []), isEmpty);
    final rows = await repo.getRowsForDives(['dive-1', 'dive-none']);
    expect(rows.map((r) => r.id), [a]);
    expect(rows.single.samples, isNotEmpty);
  });

  test('getRowsForDives and getSeriesForDives chunk past the SQL variable '
      'ceiling', () async {
    const count = 2000;
    final diveIds = [for (var i = 0; i < count; i++) 'chunk-dive-$i'];
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.batch(
      (b) => b.insertAll(db.dives, [
        for (final id in diveIds)
          DivesCompanion.insert(
            id: id,
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
      ]),
    );
    final first = await repo.insertSeries(
      diveId: diveIds.first,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final last = await repo.insertSeries(
      diveId: diveIds.last,
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );

    final rows = await repo.getRowsForDives(diveIds);
    expect(rows.map((r) => r.id), [first, last]);

    final byDive = await repo.getSeriesForDives(diveIds);
    expect(byDive.keys.toSet(), {diveIds.first, diveIds.last});
  });

  test(
    'a repository bound to a private database never touches the global one',
    () async {
      final private = AppDatabase(NativeDatabase.memory());
      addTearDown(private.close);
      await seedParents(private);
      final bound = ProfileSeriesRepository(
        database: private,
        syncRepository: SyncRepository(database: private),
      );
      final id = await bound.insertSeries(
        diveId: 'dive-1',
        samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
        now: 1000,
      );
      expect((await bound.getSeriesForDive('dive-1')).map((s) => s.id), [id]);
      expect(await repo.getSeriesForDive('dive-1'), isEmpty);
      final privateRow =
          (await private.select(private.diveProfileSeries).get()).single;
      expect(privateRow.hlc, isNotNull);
    },
  );
}
