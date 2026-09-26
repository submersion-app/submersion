import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CylinderPassportRepository repo;
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  Future<void> seedEquipment(String eq, {String diver = 'd1'}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: eq,
            name: eq,
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: Value(diver),
          ),
        );
  }

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
    await seedEquipment('eq-1');
    await seedEquipment('eq-2');
    await seedEquipment('eq-other', diver: 'd2');
  });

  tearDown(tearDownTestDatabase);

  test('assign, read and look up by passport id', () async {
    expect(await repo.getPassportId('eq-1'), isNull);
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    expect(await repo.getPassportId('eq-1'), id);
    expect(await repo.findEquipmentIdByPassportId(id, diverId: 'd1'), 'eq-1');
    expect(await repo.findEquipmentIdByPassportId(id, diverId: 'd2'), isNull);
    expect(await repo.findEquipmentIdByPassportId(id), 'eq-1');
  });

  test('ensurePassportId mints once and is stable', () async {
    final first = await repo.ensurePassportId('eq-1', diverId: 'd1');
    final second = await repo.ensurePassportId('eq-1', diverId: 'd1');
    expect(first, second);
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(first),
      isTrue,
    );
  });

  test('refuses an id another visible cylinder holds', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    expect(
      () => repo.assignPassportId(
        equipmentId: 'eq-2',
        passportId: id,
        diverId: 'd1',
      ),
      throwsA(
        isA<PassportIdInUse>().having((e) => e.equipmentId, 'holder', 'eq-1'),
      ),
    );
    // Re-assigning the same id to the same item is a no-op, not a conflict.
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
  });

  test('assigning relinks orphaned fills under that id', () async {
    final fills = CylinderFillRepository();
    final t = DateTime(2026, 9, 1);
    await fills.create(
      CylinderFill(
        id: 'a',
        passportId: id,
        filledAt: t,
        o2Percent: 21,
        createdAt: t,
        updatedAt: t,
      ),
    );
    await repo.assignPassportId(
      equipmentId: 'eq-2',
      passportId: id,
      diverId: 'd1',
    );
    expect((await fills.getById('a'))!.equipmentId, 'eq-2');
  });

  test('fills logged before linking an old tag follow the cylinder', () async {
    final fills = CylinderFillRepository();
    final minted = await repo.ensurePassportId('eq-1', diverId: 'd1');
    final t = DateTime(2026, 9, 1);
    await fills.create(
      CylinderFill(
        id: 'a',
        passportId: minted,
        equipmentId: 'eq-1',
        filledAt: t,
        o2Percent: 32,
        createdAt: t,
        updatedAt: t,
      ),
    );
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    expect((await fills.getById('a'))!.passportId, id);
    final underOld = (await db.select(db.cylinderFills).get()).where(
      (r) => r.passportId == minted,
    );
    expect(underOld, isEmpty);
  });

  test('two devices minting for the same cylinder agree', () async {
    final first = await repo.ensurePassportId('eq-1', diverId: 'd1');
    // The other device never saw this row: drop it and mint again.
    await (db.delete(
      db.equipmentAttributes,
    )..where((t) => t.equipmentId.equals('eq-1'))).go();
    final second = await repo.ensurePassportId('eq-1', diverId: 'd1');
    expect(second, first);
    expect(await repo.ensurePassportId('eq-2', diverId: 'd1'), isNot(first));
  });

  Future<void> putId(String eq, String value) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipmentAttributes)
        .insert(
          EquipmentAttributesCompanion.insert(
            id: 'attr_${eq}_passport_id',
            equipmentId: eq,
            attrKey: 'passport_id',
            valueText: Value(value),
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  Future<void> retire(String eq) =>
      (db.update(db.equipment)..where((t) => t.id.equals(eq))).write(
        const EquipmentCompanion(status: Value('retired')),
      );

  test('two rows sharing an id resolve to the fitted, older one', () async {
    // Written behind the repository's back, as an old import could have.
    await putId('eq-2', id);
    await putId('eq-1', id);
    await retire('eq-2');
    expect(await repo.findEquipmentIdByPassportId(id, diverId: 'd1'), 'eq-1');
  });

  test('a retired cylinder gives its tag up to a new one', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    await retire('eq-1');
    await repo.assignPassportId(
      equipmentId: 'eq-2',
      passportId: id,
      diverId: 'd1',
    );
    expect(await repo.getPassportId('eq-2'), id);
    expect(await repo.getPassportId('eq-1'), isNull);
  });

  test('a fitted cylinder still keeps its tag', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    expect(
      () => repo.assignPassportId(
        equipmentId: 'eq-2',
        passportId: id,
        diverId: 'd1',
      ),
      throwsA(isA<PassportIdInUse>()),
    );
  });

  test('an equipment save that never saw the passport id keeps it', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    // The edit form's save: only the fields it shows, retyped or opened
    // before a synced id arrived.
    await EquipmentRepository().saveAttributes('eq-1', [
      EquipmentAttribute.curated(
        equipmentId: 'eq-1',
        key: 'valve_type',
        valueText: 'din',
      ),
    ]);
    expect(await repo.getPassportId('eq-1'), id);
  });

  test('releasing a tag still removes the id', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    await EquipmentRepository().saveAttributes(
      'eq-1',
      const [],
      preserveSystem: false,
    );
    expect(await repo.getPassportId('eq-1'), isNull);
  });

  test('a failure part-way through a tag move changes nothing', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    await retire('eq-1');
    final failing = CylinderPassportRepository(fills: _FailingFills());
    await expectLater(
      failing.assignPassportId(
        equipmentId: 'eq-2',
        passportId: id,
        diverId: 'd1',
      ),
      throwsA(isA<StateError>()),
    );
    // Rolled back: the old holder keeps the tag, the new one has none.
    expect(await repo.getPassportId('eq-1'), id);
    expect(await repo.getPassportId('eq-2'), isNull);
  });

  test('two cylinders linking one tag at once leave one holder', () async {
    Future<String> attempt(String eq) => repo
        .assignPassportId(equipmentId: eq, passportId: id, diverId: 'd1')
        .then((_) => 'linked')
        .catchError((Object e) => e is PassportIdInUse ? 'refused' : throw e);
    final outcomes = await Future.wait([attempt('eq-1'), attempt('eq-2')]);
    expect(outcomes, unorderedEquals(['linked', 'refused']));
    final holders = [
      for (final eq in ['eq-1', 'eq-2'])
        if (await repo.getPassportId(eq) == id) eq,
    ];
    expect(holders, hasLength(1));
  });

  Future<void> retype(String eq, String type) =>
      (db.update(db.equipment)..where((t) => t.id.equals(eq))).write(
        EquipmentCompanion(type: Value(type)),
      );

  test(
    'an item retyped away from a cylinder no longer holds the tag',
    () async {
      await repo.assignPassportId(
        equipmentId: 'eq-1',
        passportId: id,
        diverId: 'd1',
      );
      await retype('eq-1', 'regulator');
      expect(await repo.findEquipmentIdByPassportId(id, diverId: 'd1'), isNull);
    },
  );

  test('linking a tag a retyped item still carries moves it', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    await retype('eq-1', 'regulator');
    await repo.assignPassportId(
      equipmentId: 'eq-2',
      passportId: id,
      diverId: 'd1',
    );
    expect(await repo.getPassportId('eq-2'), id);
    expect(await repo.getPassportId('eq-1'), isNull);
  });

  test('a retype undone keeps the tag', () async {
    await repo.assignPassportId(
      equipmentId: 'eq-1',
      passportId: id,
      diverId: 'd1',
    );
    await retype('eq-1', 'regulator');
    await retype('eq-1', 'tank');
    expect(await repo.findEquipmentIdByPassportId(id, diverId: 'd1'), 'eq-1');
  });
}

class _FailingFills extends CylinderFillRepository {
  @override
  Future<int> relinkToEquipment({
    required String passportId,
    required String equipmentId,
  }) async => throw StateError('disk full');
}
