import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';

import '../../../../helpers/test_database.dart';

/// Which of a deleted profile's gear other profiles need, and who gets it
/// (issue #2852).
void main() {
  late AppDatabase db;
  late EquipmentTransferService service;

  Future<void> addDiver(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
        );
  }

  Future<void> addItem(String id, String owner, {String? host}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'other',
            createdAt: t,
            updatedAt: t,
            diverId: Value(owner),
            parentEquipmentId: Value(host),
          ),
        );
  }

  Future<void> addDive(String id, String owner, int entryMs) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(owner),
          diveDateTime: entryMs,
          createdAt: entryMs,
          updatedAt: entryMs,
          entryTime: Value(entryMs),
        ),
      );

  Future<void> link(String dive, String item) => db
      .into(db.diveEquipment)
      .insert(DiveEquipmentCompanion.insert(diveId: dive, equipmentId: item));

  setUp(() async {
    db = await setUpTestDatabase();
    service = EquipmentTransferService();
    for (final d in ['bill', 'anna', 'tom']) {
      await addDiver(d);
    }
  });

  tearDown(tearDownTestDatabase);

  test('a shared item goes to its earliest sharee', () async {
    await addItem('light', 'bill');
    final shares = EquipmentShareRepository();
    await shares.shareMany(
      equipmentIds: ['light'],
      diverIds: ['tom'],
      actingDiverId: 'bill',
    );
    await db
        .update(db.equipmentShares)
        .write(const EquipmentSharesCompanion(createdAt: Value(1)));
    await shares.shareMany(
      equipmentIds: ['light'],
      diverIds: ['anna'],
      actingDiverId: 'bill',
    );
    final kept = await service.keptUnitsForDiver('bill');
    expect(kept.single.unit, {'light'});
    expect(kept.single.heirId, 'tom');
  });

  test(
    'an unshared item on another profile dive goes to the latest such dive',
    () async {
      await addItem('reg', 'bill');
      await addDive('d1', 'anna', 1000);
      await addDive('d2', 'tom', 2000);
      await addDive('d3', 'bill', 3000);
      await link('d1', 'reg');
      await link('d2', 'reg');
      await link('d3', 'reg');
      final kept = await service.keptUnitsForDiver('bill');
      expect(kept.single.heirId, 'tom');
    },
  );

  test('a cylinder or regulator on another profile tank counts', () async {
    await addItem('tank', 'bill');
    await addItem('reg', 'bill');
    await addDive('d1', 'anna', 1000);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'dt1',
            diveId: 'd1',
            equipmentId: const Value('tank'),
            regulatorEquipmentId: const Value('reg'),
          ),
        );
    final kept = await service.keptUnitsForDiver('bill');
    expect({for (final k in kept) ...k.unit}, {'tank', 'reg'});
    expect(kept.every((k) => k.heirId == 'anna'), isTrue);
  });

  test('the whole unit is kept when one of its items is needed', () async {
    await addItem('ccr', 'bill');
    await addItem('cell', 'bill', host: 'ccr');
    await addDive('d1', 'anna', 1000);
    await link('d1', 'cell');
    final kept = await service.keptUnitsForDiver('bill');
    expect(kept.single.unit, {'ccr', 'cell'});
    expect(await service.keptEquipmentCount('bill'), 2);
  });

  test(
    'unused, unshared gear and gear only on own dives is not kept',
    () async {
      await addItem('spare', 'bill');
      await addItem('fins', 'bill');
      await addDive('d1', 'bill', 1000);
      await link('d1', 'fins');
      expect(await service.keptUnitsForDiver('bill'), isEmpty);
      expect(await service.keptEquipmentCount('bill'), 0);
    },
  );
}
