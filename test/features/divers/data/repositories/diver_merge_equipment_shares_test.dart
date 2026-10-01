import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final t = DateTime.utc(2026, 9, 1).millisecondsSinceEpoch;

  Future<void> share(String id, String item, String diver) => db
      .into(db.equipmentShares)
      .insert(
        EquipmentSharesCompanion.insert(
          id: id,
          equipmentId: item,
          diverId: diver,
          createdAt: t,
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
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
    await share('s-keep-bcd', 'son-bcd', 'keep');
    await share('s-dup-bcd', 'son-bcd', 'dup');
    await share('s-dup-reg', 'keep-reg', 'dup');
    await share('s-keep-mask', 'dup-mask', 'keep');
    await share('s-dup-fins', 'son-fins', 'dup');
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
  });

  tearDown(tearDownTestDatabase);

  Future<Map<String, String>> sharesByItem() async => {
    for (final s in await db.select(db.equipmentShares).get())
      '${s.equipmentId}/${s.id}': s.diverId,
  };

  test('merge drops colliding and self shares and moves the rest', () async {
    await DiverMergeRepository().mergeDivers(
      keeperId: 'keep',
      duplicateId: 'dup',
    );
    final shares = await db.select(db.equipmentShares).get();
    expect(
      {for (final s in shares) '${s.equipmentId}/${s.diverId}'},
      {'son-bcd/keep', 'son-fins/keep'},
    );
    // A share is an (item, diver) pair that peers apply insert-only, so a
    // moved share is re-created for the keeper rather than edited in place
    // (#2670): the original id is gone.
    expect(shares.map((s) => s.id), isNot(contains('s-dup-fins')));
    final owners = {
      for (final e in await db.select(db.equipment).get()) e.id: e.diverId,
    };
    for (final s in shares) {
      expect(owners[s.equipmentId], isNot(s.diverId), reason: 'no self-share');
    }
    final deleted = {
      for (final r in await db.select(db.deletionLog).get())
        if (r.entityType == 'equipmentShares') r.recordId,
    };
    expect(
      deleted,
      containsAll(['s-dup-bcd', 's-dup-reg', 's-keep-mask', 's-dup-fins']),
    );
  });

  test('the re-created share is pending under its own clock', () async {
    await DiverMergeRepository().mergeDivers(
      keeperId: 'keep',
      duplicateId: 'dup',
    );
    final moved = await (db.select(
      db.equipmentShares,
    )..where((s) => s.equipmentId.equals('son-fins'))).getSingle();
    expect(moved.hlc, isNotNull);
    final pending = [
      for (final r in await db.select(db.syncRecords).get())
        if (r.entityType == 'equipmentShares') r.recordId,
    ];
    expect(pending, contains(moved.id));
  });

  test('merge repoints event divers', () async {
    await DiverMergeRepository().mergeDivers(
      keeperId: 'keep',
      duplicateId: 'dup',
    );
    final ev = await db.select(db.equipmentOwnershipEvents).getSingle();
    expect(ev.toDiverId, 'keep');
    expect(ev.fromDiverId, 'son');
  });

  test('undo restores shares, their tombstones and event divers', () async {
    final before = await sharesByItem();
    final repo = DiverMergeRepository();
    final snapshot = await repo.mergeDivers(
      keeperId: 'keep',
      duplicateId: 'dup',
    );
    final created = {
      for (final s in await db.select(db.equipmentShares).get()) s.id,
    }.difference(before.keys.map((k) => k.split('/').last).toSet());
    expect(created, hasLength(1), reason: 'the share moved to the keeper');
    await repo.undoMerge(snapshot);
    expect(await sharesByItem(), before);
    final tombstones = [
      for (final r in await db.select(db.deletionLog).get())
        if (r.entityType == 'equipmentShares') r.recordId,
    ];
    // Only the share the merge created, which the undo removes.
    expect(tombstones, created.toList());
    final ev = await db.select(db.equipmentOwnershipEvents).getSingle();
    expect(ev.toDiverId, 'dup');
  });
  test('a group merge undone newest first restores every share', () async {
    // A second duplicate who owns the item the first one's share moves to
    // the keeper: merging it drops the keeper's share the first merge made.
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'dup2',
            name: 'dup2',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'dup2-light',
            name: 'dup2-light',
            type: 'light',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('dup2'),
          ),
        );
    await share('s-dup-light', 'dup2-light', 'dup');
    final before = await sharesByItem();

    final repo = DiverMergeRepository();
    final first = await repo.mergeDivers(keeperId: 'keep', duplicateId: 'dup');
    final second = await repo.mergeDivers(
      keeperId: 'keep',
      duplicateId: 'dup2',
    );
    final dropped = second.deletedShareRows.singleWhere(
      (r) => r['equipment_id'] == 'dup2-light',
    );
    expect(
      first.createdShareIds,
      contains(dropped['id']),
      reason: "the second merge drops the keeper's share of dup2's own item",
    );

    for (final snapshot in [second, first]) {
      await repo.undoMerge(snapshot);
    }
    expect(await sharesByItem(), before);
    final tombstones = {
      for (final r in await db.select(db.deletionLog).get())
        if (r.entityType == 'equipmentShares') r.recordId,
    };
    expect(tombstones, first.createdShareIds.toSet());
  });
}
