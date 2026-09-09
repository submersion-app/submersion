import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  test('returns the regulator from the newest dive using the preset', () async {
    Future<void> dive(String id, int ms, String preset, String? reg) async {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: ms,
              createdAt: ms,
              updatedAt: ms,
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: 't-$id', diveId: id).copyWith(
              presetName: Value(preset),
              regulatorEquipmentId: Value(reg),
            ),
          );
    }

    // The regulator ids are foreign keys, so the items must exist.
    for (final id in ['reg-a', 'reg-b', 'reg-c']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await dive('old', 1000, 'al80', 'reg-a');
    await dive('new', 2000, 'al80', 'reg-b');
    await dive('newest-unset', 3000, 'al80', null);
    await dive('other', 4000, 'hp100', 'reg-c');

    final repo = EquipmentRepository();
    expect(await repo.getLastRegulatorForPreset('al80'), 'reg-b');
    expect(await repo.getLastRegulatorForPreset('hp100'), 'reg-c');
    expect(await repo.getLastRegulatorForPreset('lp85'), isNull);
  });
}
