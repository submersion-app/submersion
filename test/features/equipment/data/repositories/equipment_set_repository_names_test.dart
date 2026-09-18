import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

import '../../../../helpers/test_database.dart';

/// [EquipmentSetRepository.getSetNamesById], the lookup the printed logbook
/// uses to name the sets a dive's gear came from (#2031).
void main() {
  late EquipmentSetRepository repo;

  setUp(() async {
    final db = await setUpTestDatabase();
    repo = EquipmentSetRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['d1', 'd2']) {
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
  });

  tearDown(tearDownTestDatabase);

  EquipmentSet newSet(String id, String name, String diverId) => EquipmentSet(
    id: id,
    diverId: diverId,
    name: name,
    equipmentIds: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  test('is empty when no set exists', () async {
    expect(await repo.getSetNamesById(), isEmpty);
  });

  test('names every set by id, across divers', () async {
    // Not diver-scoped: a dive names its set by id, and an id is unique, so
    // a bulk export never needs to know whose set it was.
    await repo.createSet(newSet('winter', 'Winter kit', 'd1'));
    await repo.createSet(newSet('photo', 'Photo rig', 'd2'));
    expect(await repo.getSetNamesById(), {
      'winter': 'Winter kit',
      'photo': 'Photo rig',
    });
  });

  test('equipmentSetNamesOrEmpty passes a successful read through', () async {
    await repo.createSet(newSet('winter', 'Winter kit', 'd1'));
    expect(await equipmentSetNamesOrEmpty(repo), {'winter': 'Winter kit'});
  });

  test('equipmentSetNamesOrEmpty falls back to no names when the read '
      'fails', () async {
    // The logbook still exports, with its sets unnamed, rather than failing.
    expect(await equipmentSetNamesOrEmpty(_FailingSetRepository()), isEmpty);
  });
}

class _FailingSetRepository extends EquipmentSetRepository {
  @override
  Future<Map<String, String>> getSetNamesById() =>
      Future.error(StateError('database closed'));
}
