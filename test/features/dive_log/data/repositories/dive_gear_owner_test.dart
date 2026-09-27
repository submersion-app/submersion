import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['owner', 'wife']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'bcd',
            name: 'bcd',
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('owner'),
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive1',
            diveDateTime: t,
            createdAt: t,
            updatedAt: t,
            diverId: const Value('wife'),
          ),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(diveId: 'dive1', equipmentId: 'bcd'),
        );
  });

  tearDown(tearDownTestDatabase);

  test('a single dive gear item carries its owner', () async {
    final dive = await DiveRepository().getDiveById('dive1');
    expect(dive!.equipment.single.diverId, 'owner');
  });

  test('getAllDives gear carries its owner', () async {
    final dives = await DiveRepository().getAllDives(diverId: 'wife');
    expect(dives.single.equipment.single.diverId, 'owner');
  });
}
