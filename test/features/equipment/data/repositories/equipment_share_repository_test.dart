import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentShareRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentShareRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife', 'son']) {
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
      ('bcd', 'owner'),
      ('reg', 'owner'),
      ('mask', 'wife'),
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
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> pending(String entityType) async => {
    for (final r
        in await db
            .customSelect(
              'SELECT record_id FROM sync_records WHERE entity_type = ?',
              variables: [Variable<String>(entityType)],
            )
            .get())
      r.read<String>('record_id'),
  };

  Future<Set<String>> tombstones(String entityType) async => {
    for (final r in await db.select(db.deletionLog).get())
      if (r.entityType == entityType) r.recordId,
  };

  test('shareMany adds one row and one shared event per pair', () async {
    final result = await repo.shareMany(
      equipmentIds: ['bcd', 'reg'],
      diverIds: ['wife', 'son'],
      actingDiverId: 'owner',
    );
    expect(result.added, 4);
    expect(result.itemsChanged, 2);
    final shares = await repo.getSharesForItems(['bcd', 'reg']);
    expect({for (final s in shares['bcd']!) s.diverId}, {'wife', 'son'});
    final events = await repo.getEventsFor('bcd');
    expect(events, hasLength(2));
    expect(
      events.every((e) => e.kind == EquipmentOwnershipEventKind.shared),
      isTrue,
    );
    expect(events.every((e) => e.fromDiverId == 'owner'), isTrue);
    expect({for (final e in events) e.toDiverId}, {'wife', 'son'});
    expect(await pending('equipmentShares'), hasLength(4));
    expect(await pending('equipmentOwnershipEvents'), hasLength(4));
  });

  test('a share to the owner or to an unknown profile is rejected', () async {
    final result = await repo.shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['owner', 'ghost'],
      actingDiverId: 'owner',
    );
    expect(result.added, 0);
    expect(result.rejected, 2);
    expect(await repo.getSharesFor('bcd'), isEmpty);
    expect(await repo.getEventsFor('bcd'), isEmpty);
  });

  test('an existing pair is ignored and logs no second event', () async {
    await repo.shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['wife'],
      actingDiverId: 'owner',
    );
    final again = await repo.shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['wife'],
      actingDiverId: 'owner',
    );
    expect(again.added, 0);
    expect(await repo.getSharesFor('bcd'), hasLength(1));
    expect(await repo.getEventsFor('bcd'), hasLength(1));
  });

  test('a sharee cannot share or unshare an item it does not own', () async {
    await repo.shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['wife'],
      actingDiverId: 'owner',
    );
    final share = await repo.shareMany(
      equipmentIds: ['bcd', 'mask'],
      diverIds: ['son'],
      actingDiverId: 'wife',
    );
    expect(share.skippedNotOwned, 1);
    expect(share.added, 1); // the mask is the wife's own
    final unshare = await repo.unshare(
      equipmentId: 'bcd',
      diverId: 'wife',
      actingDiverId: 'wife',
    );
    expect(unshare.skippedNotOwned, 1);
    expect(await repo.getSharesFor('bcd'), hasLength(1));
  });

  test('unshare deletes the row, tombstones it and logs unshared', () async {
    await repo.shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['wife'],
      actingDiverId: 'owner',
    );
    final shareId = (await repo.getSharesFor('bcd')).single.id;
    final result = await repo.unshare(
      equipmentId: 'bcd',
      diverId: 'wife',
      actingDiverId: 'owner',
    );
    expect(result.removed, 1);
    expect(await repo.getSharesFor('bcd'), isEmpty);
    expect(await tombstones('equipmentShares'), contains(shareId));
    final events = await repo.getEventsFor('bcd');
    expect(events.map((e) => e.kind), [
      EquipmentOwnershipEventKind.shared,
      EquipmentOwnershipEventKind.unshared,
    ]);
    expect(events.last.toDiverId, 'wife');
  });

  test('setShares adds and removes to match, oldest event first', () async {
    await repo.shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['wife'],
      actingDiverId: 'owner',
    );
    final result = await repo.setShares(
      equipmentId: 'bcd',
      diverIds: {'son'},
      actingDiverId: 'owner',
    );
    expect(result.added, 1);
    expect(result.removed, 1);
    expect(
      {for (final s in await repo.getSharesFor('bcd')) s.diverId},
      {'son'},
    );
    final kinds = [for (final e in await repo.getEventsFor('bcd')) e.kind];
    expect(kinds.first, EquipmentOwnershipEventKind.shared);
    expect(
      kinds,
      containsAll([
        EquipmentOwnershipEventKind.unshared,
        EquipmentOwnershipEventKind.shared,
      ]),
    );
  });

  test('shareAllForDiver shares only the owner items', () async {
    final result = await repo.shareAllForDiver(
      ownerId: 'owner',
      diverIds: ['son'],
    );
    expect(result.added, 2);
    expect(result.itemsChanged, 2);
    expect(await repo.getSharesFor('mask'), isEmpty);
  });

  test('watchChanges fires on a share', () async {
    final fired = repo.watchChanges().first;
    await repo.shareMany(
      equipmentIds: ['bcd'],
      diverIds: ['wife'],
      actingDiverId: 'owner',
    );
    await expectLater(fired, completes);
  });
}
