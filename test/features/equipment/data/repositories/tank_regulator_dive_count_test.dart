import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// A regulator on a tank, first or extra, is a dive on that regulator in
/// the Dives row (issue #3375).
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;
  const t = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    for (final id in ['r1', 'r2']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    // Two tanks of one dive both carry r1; r2 is an extra on the first.
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: 'k1', diveId: 'd1').copyWith(
            regulatorEquipmentId: const Value('r1'),
            extraRegulatorIds: const Value('["r2"]'),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k2',
            diveId: 'd1',
          ).copyWith(extraRegulatorIds: const Value('["r1"]')),
        );
  });
  tearDown(tearDownTestDatabase);

  test('a first tank regulator counts the dive once', () async {
    expect(await repo.getDiveCountForEquipment('r1'), 1);
  });

  test('an extra tank regulator counts the dive', () async {
    expect(await repo.getDiveCountForEquipment('r2'), 1);
  });
}
