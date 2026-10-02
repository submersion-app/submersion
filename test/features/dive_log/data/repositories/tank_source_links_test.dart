import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_source_links.dart';

import '../../../../helpers/test_database.dart';

/// Issue #2716: the data source a tank row came from.
void main() {
  late AppDatabase db;
  late SyncRepository sync;

  Future<void> dive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 1,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> computer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion.insert(
          id: id,
          name: id,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> source(String id, String diveId, {String? computerId}) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: diveId,
          importedAt: DateTime.utc(2026),
          createdAt: DateTime.utc(2026),
        ).copyWith(computerId: Value(computerId)),
      );

  Future<void> tank(
    String id,
    String diveId, {
    String? computerId,
    String? sourceId,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: diveId,
        ).copyWith(computerId: Value(computerId), sourceId: Value(sourceId)),
      );

  Future<void> series(String id, String diveId, String tankId, String? src) =>
      db
          .into(db.tankPressureSeries)
          .insert(
            TankPressureSeriesCompanion.insert(
              id: id,
              diveId: diveId,
              tankId: tankId,
              sampleCount: 1,
              startTimestamp: 0,
              endTimestamp: 0,
              codecVersion: 1,
              samples: Uint8List(0),
              createdAt: 1,
              updatedAt: 1,
            ).copyWith(sourceId: Value(src)),
          );

  Future<Map<String, String?>> sources() async => {
    for (final t in await db.select(db.diveTanks).get()) t.id: t.sourceId,
  };

  Future<Set<String>> pendingTanks() async => {
    for (final r in await sync.getPendingRecords())
      if (r.entityType == 'diveTanks') r.recordId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    sync = SyncRepository();
    await computer('c1');
    await computer('c2');
  });

  tearDown(tearDownTestDatabase);

  group('attributeTankSources', () {
    test('a single-source dive gives every tank its source', () async {
      await dive('d1');
      await source('s1', 'd1');
      await tank('t1', 'd1');
      await tank('t2', 'd1');
      expect(await attributeTankSources(db, sync, 'd1', now: 5), 2);
      expect(await sources(), {'t1': 's1', 't2': 's1'});
      expect(await pendingTanks(), {'t1', 't2'});
    });

    test('a single source never claims another computer\'s tank', () async {
      await dive('d1');
      await source('s1', 'd1', computerId: 'c1');
      await tank('t1', 'd1', computerId: 'c1');
      await tank('t2', 'd1'); // hand-added: the source's
      await tank('t3', 'd1', computerId: 'c2');
      await attributeTankSources(db, sync, 'd1', now: 5);
      expect(await sources(), {'t1': 's1', 't2': 's1', 't3': null});
    });

    test('a tank takes the one source of its computer', () async {
      await dive('d1');
      await source('sa', 'd1', computerId: 'c1');
      await source('sb', 'd1', computerId: 'c2');
      await tank('t1', 'd1', computerId: 'c1');
      await tank('t2', 'd1', computerId: 'c2');
      await attributeTankSources(db, sync, 'd1', now: 5);
      expect(await sources(), {'t1': 'sa', 't2': 'sb'});
    });

    test('a computer-less tank takes the one source of its series', () async {
      await dive('d1');
      await source('sa', 'd1');
      await source('sb', 'd1');
      await tank('t1', 'd1');
      await tank('t2', 'd1');
      await tank('t3', 'd1'); // no series: nothing to go on
      await tank('t4', 'd1'); // a merged cylinder: series from both
      await series('p1', 'd1', 't1', 'sa');
      await series('p2', 'd1', 't2', 'sb');
      await series('p4a', 'd1', 't4', 'sa');
      await series('p4b', 'd1', 't4', 'sb');
      await attributeTankSources(db, sync, 'd1', now: 5);
      expect(await sources(), {'t1': 'sa', 't2': 'sb', 't3': null, 't4': null});
      expect(await pendingTanks(), {'t1', 't2'});
    });

    test('a tank that already has a source keeps it', () async {
      await dive('d1');
      await source('sa', 'd1');
      await source('sb', 'd1');
      await tank('t1', 'd1', sourceId: 'sb');
      await series('p1', 'd1', 't1', 'sa');
      expect(await attributeTankSources(db, sync, 'd1', now: 5), 0);
      expect(await sources(), {'t1': 'sb'});
      expect(await pendingTanks(), isEmpty);
    });

    test('a dive with no source leaves its tanks alone', () async {
      await dive('d1');
      await tank('t1', 'd1');
      expect(await attributeTankSources(db, sync, 'd1', now: 5), 0);
      expect(await sources(), {'t1': null});
    });
  });

  test('resolveTankSources reads, and never writes or stages', () async {
    await dive('d1');
    await source('sa', 'd1');
    await source('sb', 'd1');
    await tank('t1', 'd1', sourceId: 'sb'); // recorded
    await tank('t2', 'd1'); // by its series
    await tank('t3', 'd1'); // nothing to go on
    await series('p2', 'd1', 't2', 'sa');
    expect(await resolveTankSources(db, 'd1'), {'t1': 'sb', 't2': 'sa'});
    expect(await sources(), {'t1': 'sb', 't2': null, 't3': null});
    expect(await pendingTanks(), isEmpty);
  });

  test('clearTankSourceLinks nulls and stages the tanks of a source', () async {
    await dive('d1');
    await source('sa', 'd1');
    await source('sb', 'd1');
    await tank('t1', 'd1', sourceId: 'sa');
    await tank('t2', 'd1', sourceId: 'sb');
    final cleared = await clearTankSourceLinks(
      db,
      sync,
      (t) => t.sourceId.equals('sa'),
      now: 5,
    );
    expect(cleared, 1);
    expect(await sources(), {'t1': null, 't2': 'sb'});
    expect(await pendingTanks(), {'t1'});
  });
}
