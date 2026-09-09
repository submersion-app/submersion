import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';

/// The dive_equipment join carried no ORDER BY, so a dive's gear arrived in
/// whatever order the query plan produced (#1486, #1576), and both hydration
/// paths dropped the non-nullable createdAt column.
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  const diverId = 'diver-1';
  const diveId = 'dive-1';
  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  /// Inserted in an order that deliberately disagrees with (type, name) so an
  /// unordered join has a chance to surface it.
  const seeded = [
    ('gear-3', 'Faber', EquipmentType.tank),
    ('gear-1', 'Zeagle', EquipmentType.bcd),
    ('gear-2', 'Apeks', EquipmentType.regulator),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();

    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: const Value(diverId),
            name: const Value('Test Diver'),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value(diveId),
            diverId: const Value(diverId),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );

    for (final (id, name, type) in seeded) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion(
              id: Value(id),
              diverId: const Value(diverId),
              name: Value(name),
              type: Value(type.name),
              createdAt: Value(epoch),
              updatedAt: Value(epoch),
            ),
          );
      await db
          .into(db.diveEquipment)
          .insert(
            DiveEquipmentCompanion(
              diveId: const Value(diveId),
              equipmentId: Value(id),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('a dive loads its equipment in a deterministic order', () async {
    final first = await repository.getDiveById(diveId);
    final second = await repository.getDiveById(diveId);

    expect(
      first!.equipment.map((e) => e.id).toList(),
      second!.equipment.map((e) => e.id).toList(),
      reason: 'repeated reads must agree',
    );
    // type ASC then name ASC: 'bcd' < 'regulator' < 'tank'.
    expect(first.equipment.map((e) => e.type).toList(), [
      EquipmentType.bcd,
      EquipmentType.regulator,
      EquipmentType.tank,
    ]);
  });

  test('dive equipment carries createdAt from the equipment row', () async {
    final dive = await repository.getDiveById(diveId);

    expect(
      dive!.equipment.map((e) => e.createdAt),
      everyElement(isNotNull),
      reason:
          'the column is non-nullable, so a null here means the mapper drops it',
    );
  });

  test('the batch load agrees with the single load', () async {
    final single = await repository.getDiveById(diveId);
    final batch = await repository.getAllDives();
    final fromBatch = batch.firstWhere((d) => d.id == diveId);

    expect(
      fromBatch.equipment.map((e) => e.id).toList(),
      single!.equipment.map((e) => e.id).toList(),
    );
    expect(
      fromBatch.equipment.map((e) => e.createdAt),
      everyElement(isNotNull),
    );
  });
}
