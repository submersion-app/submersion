import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/import_equipment_location_linker.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ImportEquipmentLocationLinker linker;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final id in ['reg', 'bcd']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
              diverId: const Value('me'),
            ),
          );
    }
    linker = ImportEquipmentLocationLinker(
      places: EquipmentLocationRepository(),
      moves: EquipmentLocationMoveRepository(),
    );
  });

  tearDown(tearDownTestDatabase);

  test('matches a place by name ignoring case, or creates it, and records '
      'one move', () async {
    await EquipmentLocationRepository().createLocation(
      diverId: 'me',
      name: 'Garage',
      kind: EquipmentLocationKind.storage,
    );
    await linker.link(
      items: [
        {'uddfId': 'a', 'name': 'reg', 'locationName': 'garage'},
        {'uddfId': 'b', 'name': 'bcd', 'locationName': 'Boat locker'},
      ],
      equipmentIdMapping: {'a': 'reg', 'b': 'bcd'},
      diverId: 'me',
    );
    final places = await EquipmentLocationRepository().getLocations(
      diverId: 'me',
    );
    expect(
      places.map((p) => p.name),
      unorderedEquals(['Garage', 'Boat locker']),
    );
    final boat = places.firstWhere((p) => p.name == 'Boat locker');
    expect(boat.kind, EquipmentLocationKind.other);
    final current = await EquipmentLocationMoveRepository()
        .getCurrentLocationIds();
    expect(current['bcd'], boat.id);
    expect(current['reg'], places.firstWhere((p) => p.name == 'Garage').id);
  });

  test('re-import onto an item already there writes no move', () async {
    final items = [
      {'uddfId': 'a', 'name': 'reg', 'locationName': 'Garage'},
    ];
    await linker.link(
      items: items,
      equipmentIdMapping: {'a': 'reg'},
      diverId: 'me',
    );
    await linker.link(
      items: items,
      equipmentIdMapping: {'a': 'reg'},
      diverId: 'me',
    );
    expect(
      await EquipmentLocationMoveRepository().getMovesFor('reg'),
      hasLength(1),
    );
  });

  test(
    'an item the import did not resolve, or a blank name, is skipped',
    () async {
      await linker.link(
        items: [
          {'uddfId': 'x', 'name': 'ghost', 'locationName': 'Garage'},
          {'uddfId': 'a', 'name': 'reg', 'locationName': '  '},
        ],
        equipmentIdMapping: {'a': 'reg'},
        diverId: 'me',
      );
      expect(await db.select(db.equipmentLocationMoves).get(), isEmpty);
      expect(await db.select(db.equipmentLocations).get(), isEmpty);
    },
  );
}
