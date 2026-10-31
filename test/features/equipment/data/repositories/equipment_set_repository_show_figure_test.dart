import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

import '../../../../helpers/test_database.dart';

/// The per-set diver figure switch round-trips through the repository, and
/// a set saved without it reads on.
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

  test('a set is on unless the diver hides the figure', () async {
    final created = await repo.createSet(newSet());
    expect(created.showFigure, isTrue);
    expect((await repo.getSetById(created.id))!.showFigure, isTrue);
  });

  test('turning it off persists through create and update', () async {
    final created = await repo.createSet(newSet(showFigure: false));
    expect((await repo.getSetById(created.id))!.showFigure, isFalse);

    await repo.updateSet(created.copyWith(showFigure: true));
    expect((await repo.getSetById(created.id))!.showFigure, isTrue);
  });

  test(
    'setShowFigure writes only the flag, never the rest of the set',
    () async {
      final created = await repo.createSet(newSet(showFigure: false));
      // Another device renamed the set after a copy of it was loaded here.
      await repo.updateSet(
        (await repo.getSetById(created.id))!.copyWith(name: 'Renamed'),
      );

      await repo.setShowFigure(created.id, true);

      final saved = (await repo.getSetById(created.id))!;
      expect(saved.showFigure, isTrue);
      expect(saved.name, 'Renamed');

      await repo.setShowFigure(created.id, false);
      expect((await repo.getSetById(created.id))!.showFigure, isFalse);
    },
  );
}
