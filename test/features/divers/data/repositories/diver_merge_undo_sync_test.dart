import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// Two devices, one diver merge, then its undo (#2670).
///
/// Device A merges a duplicate diver into the keeper and syncs; device B
/// pulls the merge. A then undoes it and syncs again, and B must end up
/// with the library it had before the merge: the duplicate diver back, every
/// row it owned (a dive, an item, a gear share) pointing at it again, the
/// rows the merge deleted (a share, a view config) restored, and the buddy
/// link and ownership event naming it once more.
///
/// Before the fix the undo restored each row's pre-merge clock and dropped
/// its pending marks, so A published nothing and B kept the merge.
void main() {
  late AppDatabase dbA;
  late AppDatabase dbB;
  late FakeCloudStorageProvider cloud;
  final t = DateTime.utc(2026, 9, 1).millisecondsSinceEpoch;

  setUp(() {
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
    await dbA.close();
    await dbB.close();
  });

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  /// Makes [db] the active device and re-seeds the clock from it.
  void switchTo(AppDatabase db) {
    DatabaseService.instance.setTestDatabase(db);
    SyncClock.instance.reset();
  }

  Future<void> sync(String what) async {
    final result = await buildService().performSync();
    expect(
      result.isSuccess,
      isTrue,
      reason: '$what failed: ${result.status} (${result.message})',
    );
  }

  Future<void> seed(AppDatabase db) async {
    for (final id in ['keep', 'dup', 'son']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    for (final (id, owner) in [
      ('son-bcd', 'son'), // shared with keep AND dup: collision
      ('keep-reg', 'keep'), // shared with dup: would become a self-share
      ('dup-mask', 'dup'), // shared with keep: item moves to keep
      ('son-fins', 'son'), // shared with dup only: plain repoint
    ]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'bcd',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
            ),
          );
    }
    for (final (id, item, diver) in [
      ('s-keep-bcd', 'son-bcd', 'keep'),
      ('s-dup-bcd', 'son-bcd', 'dup'),
      ('s-dup-reg', 'keep-reg', 'dup'),
      ('s-keep-mask', 'dup-mask', 'keep'),
      ('s-dup-fins', 'son-fins', 'dup'),
    ]) {
      await db
          .into(db.equipmentShares)
          .insert(
            EquipmentSharesCompanion.insert(
              id: id,
              equipmentId: item,
              diverId: diver,
              createdAt: t,
            ),
          );
    }
    await db
        .into(db.equipmentOwnershipEvents)
        .insert(
          EquipmentOwnershipEventsCompanion.insert(
            id: 'ev',
            equipmentId: 'son-fins',
            kind: 'shared',
            occurredAt: t,
            fromDiverId: const Value('son'),
            toDiverId: const Value('dup'),
          ),
        );
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'buddy-dup',
            name: 'Dup',
            createdAt: t,
            updatedAt: t,
          ).copyWith(
            diverId: const Value('son'),
            linkedDiverId: const Value('dup'),
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-dup',
            diveDateTime: t,
            diverId: const Value('dup'),
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final owner in ['keep', 'dup']) {
      await db
          .into(db.viewConfigs)
          .insert(
            ViewConfigsCompanion.insert(
              id: 'vc-$owner',
              diverId: owner,
              viewMode: 'table',
              configJson: '{}',
              updatedAt: t,
            ),
          );
    }
  }

  /// Everything the merge changes, as plain values.
  Future<Map<String, Object?>> library(AppDatabase db) async => {
    'divers': {for (final d in await db.select(db.divers).get()) d.id},
    'equipment': {
      for (final e in await db.select(db.equipment).get()) e.id: e.diverId,
    },
    'shares': {
      for (final s in await db.select(db.equipmentShares).get())
        s.id: s.diverId,
    },
    'event': [
      for (final e in await db.select(db.equipmentOwnershipEvents).get())
        '${e.fromDiverId}->${e.toDiverId}',
    ],
    'buddyLink': [
      for (final b in await db.select(db.buddies).get()) b.linkedDiverId,
    ],
    'dives': {for (final d in await db.select(db.dives).get()) d.id: d.diverId},
    'viewConfigs': {
      for (final v in await db.select(db.viewConfigs).get()) v.id: v.diverId,
    },
  };

  test('an undone diver merge reaches a peer that synced the merge', () async {
    dbB = await setUpTestDatabase();
    dbA = await setUpTestDatabase();

    switchTo(dbA);
    await seed(dbA);
    await sync('A seed push');
    final beforeMerge = await library(dbA);

    switchTo(dbB);
    await sync('B seed pull');
    expect(await library(dbB), beforeMerge, reason: 'B starts where A is');

    switchTo(dbA);
    final repo = DiverMergeRepository();
    final snapshot = await repo.mergeDivers(
      keeperId: 'keep',
      duplicateId: 'dup',
    );
    await sync('A merge push');

    switchTo(dbB);
    await sync('B merge pull');
    final merged = await library(dbB);
    expect(merged, await library(dbA), reason: 'B takes the merge');
    expect(merged, isNot(beforeMerge));

    switchTo(dbA);
    await repo.undoMerge(snapshot);
    expect(await library(dbA), beforeMerge, reason: 'A is undone locally');
    await sync('A undo push');

    switchTo(dbB);
    await sync('B undo pull');
    expect(
      await library(dbB),
      beforeMerge,
      reason: 'the undo must reach B, which already held the merge',
    );
  });
}
