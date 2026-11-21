import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4827: a passport id is minted on the device that first opens the
/// item's passport, and reaches the others only on its next sync. Minting is
/// a pure function of the equipment id, so a device holding the item but
/// not yet its id still knows the label is its own.
void main() {
  late AppDatabase db;
  late CylinderPassportRepository repo;

  String mintFor(String equipmentId) =>
      const Uuid().v5(kCylinderPassportNamespace, equipmentId);

  Future<void> seedEquipment(
    String eq, {
    String diver = 'd1',
    String type = 'regulator',
  }) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: eq,
            name: eq,
            type: type,
            createdAt: t,
            updatedAt: t,
            diverId: Value(diver),
          ),
        );
  }

  /// Stores [passportId] on [equipmentId] the way a sync pull lands it,
  /// without the holder checks a diver's link runs.
  Future<void> storePassportId(String equipmentId, String passportId) =>
      EquipmentRepository().saveAttributes(equipmentId, [
        EquipmentAttribute.curated(
          equipmentId: equipmentId,
          key: EquipmentAttrKeys.passportId,
          valueText: passportId,
        ),
      ]);

  setUp(() async {
    db = await setUpTestDatabase();
    repo = CylinderPassportRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final d in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(id: d, name: d, createdAt: t, updatedAt: t),
          );
    }
    await seedEquipment('eq-reg');
    await seedEquipment('eq-tank', type: 'tank');
    await seedEquipment('eq-2');
  });

  tearDown(tearDownTestDatabase);

  group('findHolderByPassportId', () {
    test('finds an item whose minted id has not synced here yet', () async {
      final holder = await repo.findHolderByPassportId(
        mintFor('eq-reg'),
        diverId: 'd1',
      );
      expect(holder?.equipmentId, 'eq-reg');
      expect(holder?.type, EquipmentType.regulator);
    });

    test('matches the minted id whatever its case', () async {
      final holder = await repo.findHolderByPassportId(
        mintFor('eq-reg').toUpperCase(),
        diverId: 'd1',
      );
      expect(holder?.equipmentId, 'eq-reg');
    });

    test('finds a cylinder the tank editor narrows to', () async {
      expect(
        await repo.findEquipmentIdByPassportId(
          mintFor('eq-tank'),
          diverId: 'd1',
          type: EquipmentType.tank,
        ),
        'eq-tank',
      );
      expect(
        await repo.findEquipmentIdByPassportId(
          mintFor('eq-reg'),
          diverId: 'd1',
          type: EquipmentType.tank,
        ),
        isNull,
      );
    });

    test('answers only for gear the diver can see', () async {
      await seedEquipment('eq-other', diver: 'd2');
      expect(
        await repo.findHolderByPassportId(mintFor('eq-other'), diverId: 'd1'),
        isNull,
      );
      expect(
        (await repo.findHolderByPassportId(
          mintFor('eq-other'),
          diverId: 'd2',
        ))?.equipmentId,
        'eq-other',
      );
    });

    test('an item holding another id does not answer to its mint', () async {
      await storePassportId('eq-reg', '11111111-2222-4333-8444-555555555555');
      expect(
        await repo.findHolderByPassportId(mintFor('eq-reg'), diverId: 'd1'),
        isNull,
      );
    });

    test('a stored holder wins over an item that only mints it', () async {
      await storePassportId('eq-2', mintFor('eq-reg'));
      expect(
        (await repo.findHolderByPassportId(
          mintFor('eq-reg'),
          diverId: 'd1',
        ))?.equipmentId,
        'eq-2',
      );
    });

    test('an id no item mints stays foreign', () async {
      expect(
        await repo.findHolderByPassportId(
          '11111111-2222-4333-8444-555555555555',
          diverId: 'd1',
        ),
        isNull,
      );
    });
  });

  group('writes respect an id minted elsewhere', () {
    test('ensurePassportId still stores the minted id', () async {
      final minted = await repo.ensurePassportId('eq-reg', diverId: 'd1');
      expect(minted, mintFor('eq-reg'));
      expect(await repo.getPassportId('eq-reg'), minted);
    });

    test('linking another item to that label is refused', () async {
      await expectLater(
        repo.assignPassportId(
          equipmentId: 'eq-2',
          passportId: mintFor('eq-reg'),
          diverId: 'd1',
        ),
        throwsA(
          isA<PassportIdInUse>().having(
            (e) => e.equipmentId,
            'equipmentId',
            'eq-reg',
          ),
        ),
      );
      expect(await repo.getPassportId('eq-2'), isNull);
    });

    test('an item out of service gives its unsynced label up', () async {
      await (db.update(db.equipment)..where((t) => t.id.equals('eq-reg')))
          .write(const EquipmentCompanion(status: Value('retired')));
      await repo.assignPassportId(
        equipmentId: 'eq-2',
        passportId: mintFor('eq-reg'),
        diverId: 'd1',
      );
      expect(await repo.getPassportId('eq-2'), mintFor('eq-reg'));
      expect(
        (await repo.findHolderByPassportId(
          mintFor('eq-reg'),
          diverId: 'd1',
        ))?.equipmentId,
        'eq-2',
      );
    });

    test('fittedHolderOf names the item that mints the id', () async {
      expect(
        await repo.fittedHolderOf(
          mintFor('eq-reg'),
          exceptEquipmentId: 'eq-2',
          diverId: 'd1',
        ),
        'eq-reg',
      );
    });

    test('an import does not put that id on another item', () async {
      expect(
        await repo.adoptImportedPassportId(
          equipmentId: 'eq-2',
          passportId: mintFor('eq-reg'),
          diverId: 'd1',
        ),
        isFalse,
      );
      expect(
        await repo.adoptImportedPassportId(
          equipmentId: 'eq-reg',
          passportId: mintFor('eq-reg'),
          diverId: 'd1',
        ),
        isTrue,
      );
      expect(await repo.getPassportId('eq-reg'), mintFor('eq-reg'));
    });
  });
}
