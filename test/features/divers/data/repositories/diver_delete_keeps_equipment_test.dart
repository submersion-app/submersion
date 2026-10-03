import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';

import '../../../../helpers/test_database.dart';

/// Deleting a profile keeps the gear other profiles use and hands it to
/// them (issue #2852).
void main() {
  late AppDatabase db;

  Future<void> addDiver(String id, {bool isDefault = false}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: id,
            createdAt: t,
            updatedAt: t,
            isDefault: Value(isDefault),
          ),
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

  Future<void> addDive(String id, String owner, int at) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(owner),
          diveDateTime: at,
          createdAt: at,
          updatedAt: at,
        ),
      );

  Future<String?> ownerOf(String id) async => (await (db.select(
    db.equipment,
  )..where((t) => t.id.equals(id))).getSingleOrNull())?.diverId;

  setUp(() async {
    db = await setUpTestDatabase();
    await addDiver('bill');
    await addDiver('anna', isDefault: true);
    await addDiver('tom');
  });

  tearDown(tearDownTestDatabase);

  test(
    'shared gear survives and lands on the earliest sharee; others keep access',
    () async {
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
      final result = await DiverRepository().deleteDiverWithReassignment(
        'bill',
      );
      expect(await ownerOf('light'), 'tom');
      final left = await db.select(db.equipmentShares).get();
      expect(left.map((s) => s.diverId), ['anna']);
      expect(result.keptEquipmentCount, 1);
      expect(result.keptEquipmentHeirNames, ['tom']);
      expect(result.hasKeptEquipment, isTrue);
    },
  );

  test(
    'gear on another profile dive survives and stays on that dive',
    () async {
      await addItem('reg', 'bill');
      await addDive('d1', 'tom', 1000);
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'reg'),
          );
      await DiverRepository().deleteDiverWithReassignment('bill');
      expect(await ownerOf('reg'), 'tom');
      expect(await db.select(db.diveEquipment).get(), hasLength(1));
    },
  );

  test('unused, unshared gear is still deleted', () async {
    await addItem('spare', 'bill');
    final result = await DiverRepository().deleteDiverWithReassignment('bill');
    expect(await ownerOf('spare'), isNull);
    expect(result.hasKeptEquipment, isFalse);
  });

  test(
    'a moved dive computer keeps its links on other profiles dives',
    () async {
      await addItem('perdix', 'bill');
      await addDive('d1', 'tom', 1000);
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion.insert(diveId: 'd1', equipmentId: 'perdix'),
          );
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'c1',
              name: 'c1',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('bill'),
              equipmentId: const Value('perdix'),
            ),
          );
      await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
        const DivesCompanion(computerId: Value('c1')),
      );
      await DiverRepository().deleteDiverWithReassignment('bill');
      final c = await (db.select(
        db.diveComputers,
      )..where((r) => r.id.equals('c1'))).getSingleOrNull();
      expect(c?.diverId, 'tom');
      final d = await (db.select(
        db.dives,
      )..where((r) => r.id.equals('d1'))).getSingle();
      expect(d.computerId, 'c1');
    },
  );

  test('a clashing transmitter is deleted as before', () async {
    await addItem('tank', 'bill');
    await addDive('d1', 'tom', 1000);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'dt1',
            diveId: 'd1',
            equipmentId: const Value('tank'),
          ),
        );
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final (id, owner) in [('tx1', 'bill'), ('tx2', 'tom')]) {
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: id,
              label: id,
              tankRole: 'backGas',
              createdAt: t,
              updatedAt: t,
              diverId: Value(owner),
              transmitterSerial: const Value('A1'),
              equipmentId: Value(id == 'tx1' ? 'tank' : null),
            ),
          );
    }
    await DiverRepository().deleteDiverWithReassignment('bill');
    final ids = (await db.select(db.transmitters).get()).map((r) => r.id);
    expect(ids, ['tx2']);
    expect(await ownerOf('tank'), 'tom');
  });

  test(
    'trips still go to the default profile alongside the gear handover',
    () async {
      await addItem('light', 'bill');
      await EquipmentShareRepository().shareMany(
        equipmentIds: ['light'],
        diverIds: ['tom'],
        actingDiverId: 'bill',
      );
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.trips)
          .insert(
            TripsCompanion.insert(
              id: 'trip1',
              name: 'trip',
              startDate: t,
              endDate: t,
              createdAt: t,
              updatedAt: t,
              diverId: const Value('bill'),
              isShared: const Value(true),
            ),
          );
      final result = await DiverRepository().deleteDiverWithReassignment(
        'bill',
      );
      expect(result.reassignedToDiverId, 'anna');
      expect(result.reassignedTripsCount, 1);
      expect(await ownerOf('light'), 'tom');
    },
  );

  test('the transferred event reads a deleted profile afterwards', () async {
    await addItem('light', 'bill');
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['light'],
      diverIds: ['tom'],
      actingDiverId: 'bill',
    );
    await DiverRepository().deleteDiverWithReassignment('bill');
    final transferred = await (db.select(
      db.equipmentOwnershipEvents,
    )..where((e) => e.kind.equals('transferred'))).getSingle();
    expect(transferred.fromDiverId, isNull);
    expect(transferred.toDiverId, 'tom');
  });

  test(
    'a kept cylinder keeps the fills its old owner logged, under the heir',
    () async {
      await addItem('tank', 'bill');
      await EquipmentShareRepository().shareMany(
        equipmentIds: ['tank'],
        diverIds: ['tom'],
        actingDiverId: 'bill',
      );
      const t = 1000;
      await db
          .into(db.cylinderFills)
          .insert(
            CylinderFillsCompanion.insert(
              id: 'fill1',
              passportId: 'pp1',
              filledAt: t,
              o2Percent: 32,
              createdAt: t,
              updatedAt: t,
              diverId: const Value('bill'),
              equipmentId: const Value('tank'),
            ),
          );
      await DiverRepository().deleteDiverWithReassignment('bill');
      final fill = await (db.select(
        db.cylinderFills,
      )..where((f) => f.id.equals('fill1'))).getSingleOrNull();
      expect(fill?.diverId, 'tom');
      final pending = await db
          .customSelect(
            "SELECT record_id FROM sync_records WHERE entity_type = 'cylinderFills'",
          )
          .get();
      expect(pending.map((r) => r.read<String>('record_id')), ['fill1']);
    },
  );

  test('a linked transmitter moves with kept gear, and a failed rescan does '
      'not fail the delete', () async {
    await addItem('tank', 'bill');
    await addDive('d1', 'tom', 1000);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'dt1',
            diveId: 'd1',
            equipmentId: const Value('tank'),
          ),
        );
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 'tx1',
            label: 'tx1',
            tankRole: 'backGas',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('bill'),
            transmitterSerial: const Value('A1'),
            equipmentId: const Value('tank'),
          ),
        );
    final rescanned = <String>[];
    final repository = DiverRepository(
      equipmentTransferService: EquipmentTransferService(
        rescanTransmitters: (ids) async {
          rescanned.addAll(ids);
          throw StateError('rescan failed');
        },
      ),
    );
    final result = await repository.deleteDiverWithReassignment('bill');
    expect(result.keptEquipmentCount, 1);
    expect(rescanned, ['tx1']);
    final tx = await (db.select(
      db.transmitters,
    )..where((r) => r.id.equals('tx1'))).getSingleOrNull();
    expect(tx?.diverId, 'tom');
  });

  test('keptEquipmentCount reports the items a delete would keep', () async {
    await addItem('light', 'bill');
    await addItem('spare', 'bill');
    await EquipmentShareRepository().shareMany(
      equipmentIds: ['light'],
      diverIds: ['tom'],
      actingDiverId: 'bill',
    );
    expect(await DiverRepository().keptEquipmentCount('bill'), 1);
  });
}
