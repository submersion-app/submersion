import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_service_status_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['a', 'b', 'c']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test(
    'replaceAll writes the map exactly and leaves unchanged rows alone',
    () async {
      final repo = EquipmentServiceStatusRepository();
      await repo.replaceAll({
        'a': (severity: 'overdue', dueDate: 1),
        'b': (severity: 'ok', dueDate: null),
      }, computedAt: 10);
      expect(await repo.severities(), {'a': 'overdue', 'b': 'ok'});

      var ticks = 0;
      final sub = db
          .tableUpdates(TableUpdateQuery.onTable(db.equipmentServiceStatus))
          .listen((_) => ticks++);
      addTearDown(sub.cancel);
      // Same verdicts, later clock: no write, so no list re-query.
      await repo.replaceAll({
        'a': (severity: 'overdue', dueDate: 1),
        'b': (severity: 'ok', dueDate: null),
      }, computedAt: 20);
      await pumpEventQueue();
      expect(ticks, 0);

      // 'b' goes, 'c' arrives, 'a' changes.
      await repo.replaceAll({
        'a': (severity: 'dueSoon', dueDate: 2),
        'c': (severity: 'ok', dueDate: null),
      }, computedAt: 30);
      expect(await repo.severities(), {'a': 'dueSoon', 'c': 'ok'});
    },
  );

  test('a verdict for an item deleted mid-evaluation is skipped', () async {
    // The engine evaluated 'ghost', then it was deleted before the write:
    // the cache keeps the live items instead of failing the whole write on
    // the equipment foreign key.
    final repo = EquipmentServiceStatusRepository();
    await repo.replaceAll({
      'a': (severity: 'overdue', dueDate: 1),
      'ghost': (severity: 'dueSoon', dueDate: 2),
    }, computedAt: 10);
    expect(await repo.severities(), {'a': 'overdue'});
  });
}
