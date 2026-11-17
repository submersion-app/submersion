import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart'
    as domain;
import 'package:submersion/features/equipment/data/services/cylinder_from_tank_service.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/services/tank_cylinder_matching.dart';

import '../../../../helpers/test_database.dart';

/// Cylinders made from a download's tanks (issue #4494): one transaction
/// creates the items, links the tanks, writes a corrected spec back and adds
/// the gear.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<void> dive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: const Value('me'),
          diveDateTime: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  /// Inserts a tank row and returns the reference the matcher would build.
  Future<TankRef> tank(
    String diveId,
    String id, {
    int order = 0,
    double volume = 11.1,
    double? pressure = 206.843,
    String? material = 'aluminum',
    String? presetName = 'al80',
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: id,
            diveId: diveId,
            volume: Value(volume),
            workingPressure: Value(pressure),
            tankMaterial: Value(material),
            presetName: Value(presetName),
            tankOrder: Value(order),
          ),
        );
    return TankRef(
      diveId: diveId,
      tank: domain.DiveTank(
        id: id,
        volume: volume,
        workingPressure: pressure,
        material: material == null
            ? null
            : TankMaterial.values.byName(material),
        order: order,
        presetName: presetName,
      ),
    );
  }

  CylinderDraft unchanged(CylinderProposal p, String name) => CylinderDraft(
    proposal: p,
    name: name,
    volumeL: p.volumeL,
    workingPressureBar: p.workingPressureBar,
    material: p.material,
  );

  Future<DiveTank> tankRow(String id) =>
      (db.select(db.diveTanks)..where((t) => t.id.equals(id))).getSingle();

  Future<Set<String>> gearOf(String diveId) async => {
    for (final r in await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get())
      r.equipmentId,
  };

  test('creates one item linked to every dive', () async {
    final refs = <TankRef>[];
    for (final d in ['a', 'b', 'c']) {
      await dive(d);
      refs.add(await tank(d, 't-$d'));
    }
    final proposal = proposeCylinders(
      refs,
      owned: const [],
      ownedPairs: const [],
    ).single;

    final created = await CylinderFromTankService().create([
      unchanged(proposal, 'AL80'),
    ], diverId: 'me');

    expect(created, hasLength(1));
    final item = created.single;
    expect(item.name, 'AL80');
    expect(item.type, EquipmentType.tank);
    expect(item.diverId, 'me');
    expect(item.volumeL, 11.1);
    expect(item.workingPressureBar, 206.843);
    expect(item.tankMaterial, TankMaterial.aluminum);
    for (final d in ['a', 'b', 'c']) {
      final row = await tankRow('t-$d');
      expect(row.equipmentId, item.id);
      expect(row.volume, 11.1);
      expect(row.presetName, 'al80');
      expect(await gearOf(d), contains(item.id));
    }
  });

  test('two cylinders split by tank order', () async {
    final refs = <TankRef>[];
    for (final d in ['a', 'b']) {
      await dive(d);
      refs.add(await tank(d, '$d-left'));
      refs.add(await tank(d, '$d-right', order: 1));
    }
    final proposal = proposeCylinders(
      refs,
      owned: const [],
      ownedPairs: const [],
    ).single;

    final created = await CylinderFromTankService().create([
      unchanged(proposal, 'AL80'),
    ], diverId: 'me');

    expect(created.map((i) => i.name), ['AL80 1', 'AL80 2']);
    expect((await tankRow('a-left')).equipmentId, created[0].id);
    expect((await tankRow('b-left')).equipmentId, created[0].id);
    expect((await tankRow('a-right')).equipmentId, created[1].id);
    expect(await gearOf('a'), containsAll([created[0].id, created[1].id]));
  });

  test('a skipped cylinder leaves the one made unnumbered', () async {
    await dive('a');
    final refs = [
      await tank('a', 'a-left'),
      await tank('a', 'a-right', order: 1),
    ];
    final proposal = proposeCylinders(
      refs,
      owned: const [],
      ownedPairs: const [],
    ).single;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'other',
            name: 'Other',
            type: 'tank',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await (db.update(db.diveTanks)..where((t) => t.id.equals('a-left'))).write(
      const DiveTanksCompanion(equipmentId: Value('other')),
    );

    final created = await CylinderFromTankService().create([
      unchanged(proposal, 'AL80'),
    ], diverId: 'me');

    expect(created.map((i) => i.name), ['AL80']);
    expect((await tankRow('a-right')).equipmentId, created.single.id);
  });

  test('a corrected spec is written back to the tanks', () async {
    await dive('a');
    final ref = await tank('a', 't-a');
    final proposal = proposalForTank(ref);

    final created = await CylinderFromTankService().create([
      CylinderDraft(
        proposal: proposal,
        name: 'Steel 12',
        volumeL: 12.0,
        workingPressureBar: 232,
        material: TankMaterial.steel,
      ),
    ], diverId: 'me');

    final row = await tankRow('t-a');
    expect(row.volume, 12.0);
    expect(row.workingPressure, 232);
    expect(row.tankMaterial, 'steel');
    expect(row.presetName, isNot('al80'));
    expect(created.single.volumeL, 12.0);
    expect(created.single.attrText(EquipmentAttrKeys.tankMaterial), 'steel');
  });

  test('an unchanged spec leaves the tank as logged', () async {
    await dive('a');
    final ref = await tank('a', 't-a', pressure: null, material: null);
    await CylinderFromTankService().create([
      unchanged(proposalForTank(ref), 'Mine'),
    ], diverId: 'me');
    final row = await tankRow('t-a');
    expect(row.workingPressure, isNull);
    expect(row.tankMaterial, isNull);
    expect(row.presetName, 'al80');
  });

  test('suit inflation makes a suit inflation cylinder', () async {
    await dive('a');
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'argon',
            diveId: 'a',
            volume: const Value(0.85),
            tankRole: const Value('suitInflation'),
          ),
        );
    final proposal = proposalForTank(
      const TankRef(
        diveId: 'a',
        tank: domain.DiveTank(
          id: 'argon',
          volume: 0.85,
          role: TankRole.suitInflation,
        ),
      ),
    );
    final created = await CylinderFromTankService().create([
      unchanged(proposal, 'Argon'),
    ], diverId: 'me');
    expect(created.single.isSuitInflationCylinder, isTrue);
  });

  test('a Twin Set tank makes a cylinder worn as a twin set (#4641)', () async {
    await dive('a');
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'd12',
            diveId: 'a',
            volume: const Value(24),
            tankRole: const Value('twinSet'),
          ),
        );
    final proposal = proposalForTank(
      const TankRef(
        diveId: 'a',
        tank: domain.DiveTank(id: 'd12', volume: 24, role: TankRole.twinSet),
      ),
    );
    final created = await CylinderFromTankService().create([
      unchanged(proposal, 'D12'),
    ], diverId: 'me');
    expect(created.single.isWornAsTwinSet, isTrue);
  });

  test('never overwrites an existing link', () async {
    await dive('a');
    final ref = await tank('a', 't-a');
    final proposal = proposalForTank(ref);
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'other',
            name: 'Other',
            type: 'tank',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await (db.update(db.diveTanks)..where((t) => t.id.equals('t-a'))).write(
      const DiveTanksCompanion(equipmentId: Value('other')),
    );

    await CylinderFromTankService().create([
      unchanged(proposal, 'AL80'),
    ], diverId: 'me');

    expect((await tankRow('t-a')).equipmentId, 'other');
  });

  test('makes no item when every tank was linked meanwhile', () async {
    await dive('a');
    final ref = await tank('a', 't-a');
    final proposal = proposalForTank(ref);
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'other',
            name: 'Other',
            type: 'tank',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await (db.update(db.diveTanks)..where((t) => t.id.equals('t-a'))).write(
      const DiveTanksCompanion(equipmentId: Value('other')),
    );

    final created = await CylinderFromTankService().create([
      unchanged(proposal, 'AL80'),
    ], diverId: 'me');

    expect(created, isEmpty);
    final items = await db.select(db.equipment).get();
    expect(items.map((e) => e.id), ['other']);
  });

  test('marks linked tanks pending for sync', () async {
    await dive('a');
    final ref = await tank('a', 't-a');
    await CylinderFromTankService().create([
      unchanged(proposalForTank(ref), 'AL80'),
    ], diverId: 'me');
    final pending = await (db.select(
      db.syncRecords,
    )..where((r) => r.entityType.equals('diveTanks'))).get();
    expect(pending.map((r) => r.recordId), contains('t-a'));
  });

  test('linkTank adds the gear, unlinkTank clears only the link', () async {
    await dive('a');
    await tank('a', 't-a');
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'mine',
            name: 'Mine',
            type: 'tank',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final service = CylinderFromTankService();

    await service.linkTank(diveId: 'a', tankId: 't-a', equipmentId: 'mine');
    expect((await tankRow('t-a')).equipmentId, 'mine');
    expect((await tankRow('t-a')).volume, 11.1);
    expect(await gearOf('a'), contains('mine'));

    expect(
      await service.unlinkTank(tankId: 't-a', equipmentId: 'mine'),
      isTrue,
    );
    expect((await tankRow('t-a')).equipmentId, isNull);
    expect(await gearOf('a'), contains('mine'));
  });

  test('linkTank keeps a link made while the picker was open', () async {
    await dive('a');
    await tank('a', 't-a');
    for (final id in ['mine', 'other']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'tank',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    await (db.update(db.diveTanks)..where((t) => t.id.equals('t-a'))).write(
      const DiveTanksCompanion(equipmentId: Value('other')),
    );

    final linked = await CylinderFromTankService().linkTank(
      diveId: 'a',
      tankId: 't-a',
      equipmentId: 'mine',
    );

    expect(linked, isFalse);
    expect((await tankRow('t-a')).equipmentId, 'other');
    expect(await gearOf('a'), isNot(contains('mine')));
  });

  test('unlinkTank keeps a link changed since the menu opened', () async {
    await dive('a');
    await tank('a', 't-a');
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'other',
            name: 'other',
            type: 'tank',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await (db.update(db.diveTanks)..where((t) => t.id.equals('t-a'))).write(
      const DiveTanksCompanion(equipmentId: Value('other')),
    );

    final unlinked = await CylinderFromTankService().unlinkTank(
      tankId: 't-a',
      equipmentId: 'mine',
    );

    expect(unlinked, isFalse);
    expect((await tankRow('t-a')).equipmentId, 'other');
  });
}
