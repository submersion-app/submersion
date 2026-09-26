import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

import '../../../../helpers/test_database.dart';

/// The per-set diver figure switch round-trips through the repository, and
/// a set saved without it reads off.
void main() {
  late EquipmentSetRepository repo;

  setUp(() async {
    final db = await setUpTestDatabase();
    repo = EquipmentSetRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  EquipmentSet newSet({bool? showFigure}) {
    final set = EquipmentSet(
      id: 's1',
      diverId: 'd1',
      name: 'Reef set',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return showFigure == null ? set : set.copyWith(showFigure: showFigure);
  }

  test('a set is off unless the diver turns the figure on', () async {
    final created = await repo.createSet(newSet());
    expect(created.showFigure, isFalse);
    expect((await repo.getSetById(created.id))!.showFigure, isFalse);
  });

  test('turning it on persists through create and update', () async {
    final created = await repo.createSet(newSet(showFigure: true));
    expect((await repo.getSetById(created.id))!.showFigure, isTrue);

    await repo.updateSet(created.copyWith(showFigure: false));
    expect((await repo.getSetById(created.id))!.showFigure, isFalse);
  });
}
