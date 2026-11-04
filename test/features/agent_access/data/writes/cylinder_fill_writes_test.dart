import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Cylinder fills and passport ids, as the log fill sheet and the tag
/// dialog keep them: a possible mix on a tank, its passport minted on the
/// first fill, and a tag that moves its fills with it.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;
  const passport = '0f8b3c2e-1d4a-4b6f-9a7e-2c5d8e1f3a6b';

  Future<void> gear(
    String id,
    String type, {
    String status = 'active',
    bool active = true,
  }) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Gear $id',
          type: type,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
          status: Value(status),
          isActive: Value(active),
        ),
      );

  Map<String, Object?> fill(Map<String, Object?> more) => {
    'equipment_id': 'al80',
    'o2_fraction': 0.32,
    ...more,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
    await gear('al80', 'tank');
  });
  tearDown(() => tearDownTestDatabase());

  test('a fill is logged, edited and deleted', () async {
    final id = (await h.run([
      createOp('cylinder_fills', fill({'pressure_bar': 200.0})),
    ])).created.single.id;
    final doc = (await h.one('cylinder_fills', id))!;
    expect(doc['o2_fraction'], 0.32);
    expect(doc['he_fraction'], 0.0);
    expect(doc['pressure_bar'], 200.0);
    expect(doc['source'], 'manual');

    // Writing back what a read lists changes nothing.
    final again = await h.preview([
      updateOp('cylinder_fills', id, {
        'o2_fraction': doc['o2_fraction'],
        'he_fraction': doc['he_fraction'],
      }),
    ]);
    expect(again.unchanged.single.id, id);

    await h.run([
      updateOp('cylinder_fills', id, {'notes': 'Top-up'}),
    ]);
    expect((await h.one('cylinder_fills', id))!['notes'], 'Top-up');
    await h.run([deleteOp('cylinder_fills', id)]);
    expect(await h.one('cylinder_fills', id), isNull);
  });

  test('a fill on a tank with no passport mints one, listed', () async {
    final plan = await h.preview([createOp('cylinder_fills', fill({}))]);
    expect(plan.items.single.alsoCreates, {'equipment_attributes': 1});
    await h.apply(plan);

    expect(await CylinderPassportRepository().getPassportId('al80'), isNotNull);
  });

  test('an impossible mix, a non-tank or 401 bar is refused', () async {
    await gear('reg', 'regulator');

    final plan = await h.preview([
      createOp('cylinder_fills', fill({'o2_fraction': 0.0})),
      createOp(
        'cylinder_fills',
        fill({'o2_fraction': 0.5, 'he_fraction': 0.51}),
      ),
      createOp('cylinder_fills', fill({'equipment_id': 'reg'})),
      createOp('cylinder_fills', fill({'pressure_bar': 401.0})),
    ]);

    for (final item in plan.items) {
      expect(item.block, isNotNull, reason: '${item.values}');
    }
  });

  // A signature covers the values it was given; the app never edits one.
  test('a signed fill is not edited', () async {
    final signed = await CylinderFillRepository().create(
      CylinderFill(
        id: 'signed',
        diverId: kDiverA,
        passportId: passport,
        equipmentId: 'al80',
        filledAt: DateTime.utc(2026, 1, 1),
        o2Percent: 32,
        signedRecord: 'sig',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    final plan = await h.preview([
      updateOp('cylinder_fills', signed.id, {'notes': 'Changed'}),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.notPermitted);
  });

  test('a passport id is assigned and its fills follow, listed', () async {
    await CylinderFillRepository().create(
      CylinderFill(
        id: 'loose',
        diverId: kDiverA,
        passportId: passport,
        filledAt: DateTime.utc(2026, 1, 1),
        o2Percent: 21,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );

    final plan = await h.preview([
      updateOp('equipment', 'al80', {'passport_id': passport}),
    ]);
    expect(plan.items.single.alsoChanges, {'cylinder_fills': 1});
    await h.apply(plan);

    expect((await h.one('cylinder_fills', 'loose'))!['equipment_id'], 'al80');
    expect((await h.one('equipment', 'al80'))!['passport_id'], passport);
  });

  test('a passport id another in-service item holds is refused', () async {
    await gear('steel', 'tank');
    await CylinderPassportRepository().assignPassportId(
      equipmentId: 'steel',
      passportId: passport,
      diverId: kDiverA,
    );

    final plan = await h.preview([
      updateOp('equipment', 'al80', {'passport_id': passport}),
      updateOp('equipment', 'al80', {'passport_id': passport.toUpperCase()}),
    ]);

    expect(plan.items.first.block!.reason, BlockReason.duplicateRecord);
    expect(plan.items.last.block, isNotNull);
  });

  // The store would refuse the second at apply; the preview sees it first.
  test('two items given one passport id in a set are refused', () async {
    await gear('steel', 'tank');

    final plan = await h.preview([
      updateOp('equipment', 'al80', {'passport_id': passport}),
      updateOp('equipment', 'steel', {'passport_id': passport}),
    ]);

    expect(plan.items.first.block, isNull);
    expect(plan.items.last.block!.reason, BlockReason.duplicateRecord);
  });

  // The store keeps a tenth of a percent, so the plan lists the fraction
  // the read will return.
  test('a fraction finer than the store keeps is listed as stored', () async {
    final plan = await h.preview([
      createOp('cylinder_fills', fill({'o2_fraction': 0.3256})),
    ]);
    expect(plan.items.single.fields['o2_fraction']!.newValue, 0.326);

    final id = (await h.apply(plan)).created.single.id;
    expect((await h.one('cylinder_fills', id))!['o2_fraction'], 0.326);
  });

  // assignPassportId takes the tag off a holder no longer in service.
  test('a passport id moving off a retired item lists that item', () async {
    await gear('steel', 'tank');
    await CylinderPassportRepository().assignPassportId(
      equipmentId: 'steel',
      passportId: passport,
      diverId: kDiverA,
    );
    await (db.update(db.equipment)..where((e) => e.id.equals('steel'))).write(
      const EquipmentCompanion(status: Value('retired')),
    );

    final plan = await h.preview([
      updateOp('equipment', 'al80', {'passport_id': passport}),
    ]);

    expect(plan.items.single.alsoChanges['equipment'], 1);
  });

  // assignPassportId only releases holders the owner sees.
  test('a retired holder of another profile is not listed', () async {
    await gear('theirs', 'tank', status: 'retired');
    await (db.update(db.equipment)..where((e) => e.id.equals('theirs'))).write(
      const EquipmentCompanion(diverId: Value(kDiverB)),
    );
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion.insert(
            id: 'attr-theirs',
            equipmentId: 'theirs',
            attrKey: EquipmentAttrKeys.passportId,
            valueText: const Value(passport),
            createdAt: t,
            updatedAt: t,
          ),
        );

    final plan = await h.preview([
      updateOp('equipment', 'al80', {'passport_id': passport}),
    ]);

    expect(plan.items.single.alsoChanges['equipment'], isNull);
  });
}
