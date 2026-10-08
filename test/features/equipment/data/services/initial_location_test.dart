import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/services/initial_location.dart';

import '../../../../helpers/test_database.dart';

void main() {
  test('records the first move and reports success', () async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.equipmentLocations)
        .insert(
          EquipmentLocationsCompanion.insert(
            id: 'g',
            name: 'Garage',
            createdAt: 1,
            updatedAt: 1,
            diverId: const Value(null),
          ),
        );
    final moves = EquipmentLocationMoveRepository();
    expect(
      await recordInitialLocation(
        moves: moves,
        equipmentId: 'reg',
        locationId: 'g',
      ),
      isTrue,
    );
    expect(await moves.getCurrentLocationIds(), {'reg': 'g'});
  });

  test('reports a failed write instead of throwing', () async {
    // No database: the write throws, and the caller is told so it can warn
    // the diver that the item was saved without its location.
    expect(
      await recordInitialLocation(
        moves: EquipmentLocationMoveRepository(),
        equipmentId: 'reg',
        locationId: 'g',
      ),
      isFalse,
    );
  });
}
