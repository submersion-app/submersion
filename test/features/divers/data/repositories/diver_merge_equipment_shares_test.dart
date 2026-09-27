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

  test('merge drops colliding and self shares and repoints the rest', () async {
    await DiverMergeRepository().mergeDivers(
      keeperId: 'keep',
      duplicateId: 'dup',
    );
    final shares = await db.select(db.equipmentShares).get();
    expect({for (final s in shares) s.id}, {'s-keep-bcd', 's-dup-fins'});
    expect(shares.firstWhere((s) => s.id == 's-dup-fins').diverId, 'keep');
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
    expect(deleted, containsAll(['s-dup-bcd', 's-dup-reg', 's-keep-mask']));
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
    await repo.undoMerge(snapshot);
    expect(await sharesByItem(), before);
    final tombstones = [
      for (final r in await db.select(db.deletionLog).get())
        if (r.entityType == 'equipmentShares') r.recordId,
    ];
    expect(tombstones, isEmpty);
    final ev = await db.select(db.equipmentOwnershipEvents).getSingle();
    expect(ev.toDiverId, 'dup');
  });
}
