import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/tank_regulator_sql.dart';

import '../../../../helpers/test_database.dart';

/// The shared "this tank's regulators" SQL (issue #3375).
void main() {
  late AppDatabase db;
  const t = 1000;

  Future<void> addDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: t,
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> addTank(String id, String dive, String? first, String? extras) =>
      db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: id, diveId: dive).copyWith(
              regulatorEquipmentId: Value(first),
              extraRegulatorIds: Value(extras),
            ),
          );

  setUp(() async {
    db = await setUpTestDatabase();
    for (final i in ['r1', 'r2', 'r3', 'r9']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: i,
              name: i,
              type: 'regulator',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await addDive('d1');
    await addDive('d2');
    await addTank('k1', 'd1', 'r1', '["r2"]');
    await addTank('k2', 'd2', null, 'not json');
    await addTank('k3', 'd2', 'r3', null);
    // Valid JSON that is not an array: Dart reads it as no extras, so SQL
    // must too.
    await addTank('k4', 'd2', null, '"r9"');
    await addTank('k5', 'd2', null, '{"a":"r9"}');
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> tanksNaming(String id) async => {
    for (final r
        in await db
            .customSelect(
              'SELECT t.id FROM dive_tanks t '
              'WHERE ${tankNamesAnyRegulatorSql('t', '?1')}',
              variables: [Variable.withString(id)],
            )
            .get())
      r.read<String>('id'),
  };

  test('a tank names its first regulator and each extra', () async {
    expect(await tanksNaming('r1'), {'k1'});
    expect(await tanksNaming('r2'), {'k1'});
    expect(await tanksNaming('r3'), {'k3'});
    expect(await tanksNaming('r9'), isEmpty);
  });

  test('a malformed list reads as no extras instead of failing', () async {
    expect(await tanksNaming('not json'), isEmpty);
  });

  test('valid JSON that is not an array names nothing', () async {
    expect(await tanksNaming('r9'), isEmpty);
  });

  test('any of several ids', () async {
    final rows = await db
        .customSelect(
          'SELECT t.id FROM dive_tanks t '
          "WHERE ${tankNamesAnyRegulatorSql('t', '?, ?')}",
          // The list appears twice in the fragment, so it is bound twice.
          variables: [
            for (var i = 0; i < 2; i++) ...[
              Variable.withString('r2'),
              Variable.withString('r3'),
            ],
          ],
        )
        .get();
    expect({for (final r in rows) r.read<String>('id')}, {'k1', 'k3'});
  });

  test('the dives whose tanks name a regulator', () async {
    final rows = await db
        .customSelect(
          'SELECT id FROM dives WHERE id IN (${tankRegulatorDiveIdsSql('?1')})',
          variables: [Variable.withString('r2')],
        )
        .get();
    expect([for (final r in rows) r.read<String>('id')], ['d1']);
  });

  test('non-string entries are no regulators', () async {
    await addTank('k6', 'd1', null, '[1,null,"r3"]');
    final ids = await db
        .customSelect("SELECT * FROM (${tankRegulatorIdsOfDiveSql("'d1'")})")
        .get();
    expect([
      for (final r in ids) r.data.values.single,
    ], everyElement(isA<String>()));
    final rows = await db
        .customSelect('SELECT regulator_id FROM ($tankExtraRegulatorRowsSql)')
        .get();
    expect([
      for (final r in rows) r.data['regulator_id'],
    ], everyElement(isA<String>()));
  });

  test('every regulator on a dive\'s tanks', () async {
    final rows = await db
        .customSelect(
          "SELECT id FROM equipment WHERE id IN "
          "(${tankRegulatorIdsOfDiveSql("'d1'")})",
        )
        .get();
    expect({for (final r in rows) r.read<String>('id')}, {'r1', 'r2'});
  });
}
