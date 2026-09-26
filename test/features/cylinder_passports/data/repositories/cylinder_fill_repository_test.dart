import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late CylinderFillRepository repo;
  final t0 = DateTime(2026, 9, 1, 10);

  Future<void> seedEquipment(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  }

  CylinderFill fill(String id, DateTime at, {String? equipmentId = 'eq-1'}) =>
      CylinderFill(
        id: id,
        diverId: 'd1',
        passportId: 'pp-1',
        equipmentId: equipmentId,
        filledAt: at,
        o2Percent: 32,
        pressureBar: 220,
        createdAt: at,
        updatedAt: at,
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = CylinderFillRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await seedEquipment('eq-1');
  });

  tearDown(tearDownTestDatabase);

  test('create mints an id and reads back newest first', () async {
    await repo.create(fill('', t0));
    await repo.create(fill('', t0.add(const Duration(days: 2))));
    await repo.create(fill('', t0.add(const Duration(days: 1))));

    final fills = await repo.getForCylinder(
      passportId: 'pp-1',
      equipmentId: 'eq-1',
    );
    expect(fills.map((f) => f.filledAt.day), [3, 2, 1]);
    expect(fills.every((f) => f.id.isNotEmpty), isTrue);
    expect(fills.first.filledAt.day, 3);
    expect(
      await repo.getForCylinder(passportId: 'pp-none', equipmentId: 'eq-none'),
      isEmpty,
    );
  });

  test('getForEquipment reads through the gear link', () async {
    await repo.create(fill('a', t0));
    await repo.create(fill('b', t0, equipmentId: null));
    expect(
      (await repo.getForCylinder(
        passportId: null,
        equipmentId: 'eq-1',
      )).map((f) => f.id),
      ['a'],
    );
  });

  test('update and delete round trip', () async {
    final created = await repo.create(fill('a', t0));
    await repo.update(created.copyWith(o2Percent: 36, notes: 'checked'));
    final read = await repo.getById('a');
    expect(read!.o2Percent, 36);
    expect(read.notes, 'checked');
    await repo.delete('a');
    expect(await repo.getById('a'), isNull);
  });

  test('a fill is marked pending for sync on create', () async {
    await repo.create(fill('a', t0));
    final pending = (await db.select(db.syncRecords).get())
        .where((r) => r.entityType == 'cylinderFills' && r.recordId == 'a')
        .toList();
    expect(pending, hasLength(1));
  });

  test('relink after delete keeps every fill once', () async {
    await repo.create(fill('a', t0));
    await repo.create(fill('b', t0.add(const Duration(days: 1))));
    await EquipmentRepository().deleteEquipment('eq-1');

    var fills = await repo.getForCylinder(
      passportId: 'pp-1',
      equipmentId: 'eq-gone',
    );
    expect(fills.length, 2);
    expect(fills.every((f) => f.equipmentId == null), isTrue);

    await seedEquipment('eq-2');
    final count = await repo.relinkToEquipment(
      passportId: 'pp-1',
      equipmentId: 'eq-2',
    );
    expect(count, 2);
    fills = await repo.getForCylinder(passportId: 'pp-1', equipmentId: 'eq-2');
    expect(fills.length, 2);
    expect(fills.every((f) => f.equipmentId == 'eq-2'), isTrue);
    expect(
      (await repo.getForCylinder(passportId: null, equipmentId: 'eq-2')).length,
      2,
    );
  });

  test('getForCylinder reads by passport id or gear link, once each', () async {
    await repo.create(fill('a', t0));
    await repo.create(
      fill('b', t0.add(const Duration(days: 1))).copyWith(passportId: 'pp-old'),
    );
    await repo.create(
      fill('c', t0.add(const Duration(days: 2)), equipmentId: null),
    );
    await repo.create(
      fill('d', t0, equipmentId: null).copyWith(passportId: 'pp-else'),
    );
    final fills = await repo.getForCylinder(
      passportId: 'pp-1',
      equipmentId: 'eq-1',
    );
    expect(fills.map((f) => f.id), ['c', 'b', 'a']);
  });

  test('rekeyPassport moves the fills of one cylinder to a new id', () async {
    await repo.create(fill('a', t0));
    await repo.create(fill('b', t0, equipmentId: null));
    final moved = await repo.rekeyPassport(
      from: 'pp-1',
      to: 'pp-2',
      equipmentId: 'eq-1',
    );
    expect(moved, 1);
    expect((await repo.getById('a'))!.passportId, 'pp-2');
    // A fill with no gear link under the old id is some other cylinder's
    // history (a rental, a deleted row); it stays where it was.
    expect((await repo.getById('b'))!.passportId, 'pp-1');
  });

  test('relinking never takes a fill from another live cylinder', () async {
    await seedEquipment('eq-2');
    await repo.create(fill('mine', t0, equipmentId: null));
    await repo.create(fill('theirs', t0, equipmentId: 'eq-2'));
    final moved = await repo.relinkToEquipment(
      passportId: 'pp-1',
      equipmentId: 'eq-1',
    );
    expect(moved, 1);
    expect((await repo.getById('mine'))!.equipmentId, 'eq-1');
    expect((await repo.getById('theirs'))!.equipmentId, 'eq-2');
  });

  test('getForCylinder skips a fill another cylinder owns', () async {
    await seedEquipment('eq-2');
    await repo.create(fill('mine', t0));
    await repo.create(fill('theirs', t0, equipmentId: 'eq-2'));
    final fills = await repo.getForCylinder(
      passportId: 'pp-1',
      equipmentId: 'eq-1',
    );
    expect(fills.map((f) => f.id), ['mine']);
  });

  test('recent station and analyzer names, newest first, once each', () async {
    await repo.create(
      fill('a', t0).copyWith(stationName: 'Blue Water', analyzer: 'Divesoft'),
    );
    await repo.create(
      fill(
        'b',
        t0.add(const Duration(days: 2)),
      ).copyWith(stationName: 'Reef Air', analyzer: 'Analox'),
    );
    await repo.create(
      fill(
        'c',
        t0.add(const Duration(days: 1)),
      ).copyWith(stationName: 'Blue Water'),
    );
    await repo.create(
      fill('d', t0.add(const Duration(days: 3))).copyWith(stationName: '  '),
    );
    expect(await repo.recentStationNames(), ['Reef Air', 'Blue Water']);
    expect(await repo.recentAnalyzers(), ['Analox', 'Divesoft']);
  });
}
