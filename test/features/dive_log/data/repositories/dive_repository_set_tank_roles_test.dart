import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3374: the Gas page re-roles the cylinders the old twin set guess
/// counted, by id, in one write that reaches sync.
void main() {
  late AppDatabase db;
  late DiveRepository repository;
  const seededAt = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(seededAt),
          createdAt: const Value(seededAt),
          updatedAt: const Value(seededAt),
        ),
      );

  Future<void> insertTank(
    String id,
    String diveId,
    int order, {
    String role = 'backGas',
    String? roleSource,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: Value(diveId),
          tankRole: Value(role),
          roleSource: Value(roleSource),
          volume: const Value(24),
          startPressure: const Value(200),
          endPressure: const Value(50),
          tankOrder: Value(order),
        ),
      );

  Future<DiveTank> tank(String id) =>
      (db.select(db.diveTanks)..where((t) => t.id.equals(id))).getSingle();

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == entityType) r.recordId,
  };

  test('changes only the named rows and keeps pressures', () async {
    await insertDive('d1');
    await insertTank('t1', 'd1', 0);
    await insertTank('t2', 'd1', 1, role: 'deco');

    final changed = await repository.setTankRoles(['t1'], TankRole.twinSet);

    expect(changed, 1);
    final t1 = await tank('t1');
    expect(t1.tankRole, 'twinSet');
    expect(t1.startPressure, 200);
    expect(t1.endPressure, 50);
    expect((await tank('t2')).tankRole, 'deco');
  });

  test('clears the transmitter-name role source', () async {
    await insertDive('d1');
    await insertTank('t1', 'd1', 0, roleSource: 'transmitterName');

    await repository.setTankRoles(['t1'], TankRole.twinSet);

    expect((await tank('t1')).roleSource, isNull);
  });

  test('marks the tank and its dive pending for sync', () async {
    await insertDive('d1');
    await insertTank('t1', 'd1', 0);

    await repository.setTankRoles(['t1'], TankRole.twinSet);

    final dive = await (db.select(
      db.dives,
    )..where((d) => d.id.equals('d1'))).getSingle();
    expect(dive.updatedAt, greaterThan(seededAt));
    expect(await pending('diveTanks'), {'t1'});
    expect(await pending('dives'), {'d1'});
  });

  test('onlyFrom leaves a row whose role has since changed', () async {
    await insertDive('d1');
    await insertTank('t1', 'd1', 0);
    await insertTank('t2', 'd1', 1, role: 'deco');

    final changed = await repository.setTankRoles(
      ['t1', 't2'],
      TankRole.twinSet,
      onlyFrom: TankRole.backGas,
    );

    expect(changed, 1);
    expect((await tank('t1')).tankRole, 'twinSet');
    expect((await tank('t2')).tankRole, 'deco');
    expect(await pending('diveTanks'), {'t1'});
  });

  test('an empty list changes nothing and returns 0', () async {
    await insertDive('d1');
    await insertTank('t1', 'd1', 0);

    expect(await repository.setTankRoles(const [], TankRole.twinSet), 0);

    expect((await tank('t1')).tankRole, 'backGas');
    expect(await pending('diveTanks'), isEmpty);
  });
}
