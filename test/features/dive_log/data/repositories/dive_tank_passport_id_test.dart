import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as rows;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// dive_tanks.passport_id, the tagged cylinder a tank came from (#2650).
void main() {
  late DiveRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  test('the passport id survives create, read and update', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tanks: const [DiveTank(id: 't1', passportId: 'p-1')],
      ),
    );
    final loaded = (await repo.getDiveById('d1'))!;
    expect(loaded.tanks.single.passportId, 'p-1');

    // An edit that rebuilds the tank keeps it.
    await repo.updateDive(
      loaded.copyWith(
        tanks: [loaded.tanks.single.copyWith(startPressure: 200)],
      ),
    );
    final edited = (await repo.getDiveById('d1'))!;
    expect(edited.tanks.single.passportId, 'p-1');

    // An explicit clear removes it.
    await repo.updateDive(
      edited.copyWith(
        tanks: [edited.tanks.single.copyWith(clearPassportId: true)],
      ),
    );
    expect((await repo.getDiveById('d1'))!.tanks.single.passportId, isNull);
  });

  test('a tank added on update carries its passport id', () async {
    await repo.createDive(createTestDiveWithBottomTime(id: 'd1'));
    final loaded = (await repo.getDiveById('d1'))!;
    await repo.updateDive(
      loaded.copyWith(
        tanks: [
          ...loaded.tanks,
          const DiveTank(id: 't9', passportId: 'p-9'),
        ],
      ),
    );
    final tanks = (await repo.getDiveById('d1'))!.tanks;
    expect(tanks.singleWhere((t) => t.id == 't9').passportId, 'p-9');
  });

  test('the preloaded list mapper carries it too', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tanks: const [DiveTank(id: 't1', passportId: 'p-1')],
      ),
    );
    final listed = await repo.getAllDives();
    expect(listed.single.tanks.single.passportId, 'p-1');
  });

  test('a bulk replace stamps it only when restoring', () async {
    await repo.createDive(createTestDiveWithBottomTime(id: 'd1'));
    await repo.createDive(createTestDiveWithBottomTime(id: 'd2'));
    const template = DiveTank(id: 'tpl', passportId: 'p-1');

    // A template copied from one tagged tank must not claim that physical
    // cylinder on every dive it lands on.
    await repo.bulkReplaceTanks(['d1'], const [template]);
    expect((await repo.getDiveById('d1'))!.tanks.single.passportId, isNull);

    await repo.bulkReplaceTanks(['d2'], const [template], restoreLinks: true);
    expect((await repo.getDiveById('d2'))!.tanks.single.passportId, 'p-1');
  });

  test('a synced tank row round-trips it', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tanks: const [DiveTank(id: 't1', passportId: 'p-1')],
      ),
    );
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('t1'))).getSingle();
    // Sync ships dive_tanks rows as their Drift JSON (the serializer's
    // diveTanks arm), so the column round-trips through toJson/fromJson.
    expect(rows.DiveTank.fromJson(row.toJson()).passportId, 'p-1');
  });
}
