import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/data/services/bulk_equipment_tag_service.dart';

import '../../../../helpers/test_database.dart';

/// Bulk equipment tag edits and their undo (issue #1942).
void main() {
  late AppDatabase db;
  late EquipmentTagRepository repository;
  late BulkEquipmentTagService service;

  const ids = ['e1', 'e2', 'e3'];

  setUp(() async {
    db = await setUpTestDatabase();
    repository = EquipmentTagRepository();
    service = BulkEquipmentTagService(repository);
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) VALUES "
      "('e1', 'Wing', 'bcd', 0, 0), ('e2', 'Reg', 'regulator', 0, 0), "
      "('e3', 'Fins', 'fins', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) VALUES "
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1), "
      "('t3', 'Cold water', 0, 0, 0, 0, 1)",
    );
    // Partial overlap: e1 has Travel kit, e2 Travel kit and Rental, e3 none.
    // Seeded in SQL, so no sync record exists before the service runs.
    await db.customStatement(
      "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
      "VALUES ('l1', 'e1', 't1', 0), ('l2', 'e2', 't1', 1), "
      "('l3', 'e2', 't2', 2)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<Map<String, Set<String>>> tagSets() async {
    final byItem = await repository.getTagIdsByEquipment(ids);
    return {for (final id in ids) id: (byItem[id] ?? const <String>[]).toSet()};
  }

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('n');

  test(
    'apply adds and removes on every item and returns the prior sets',
    () async {
      final prior = await service.apply(
        equipmentIds: ids,
        addTagIds: {'t3'},
        removeTagIds: {'t1'},
      );

      expect(await tagSets(), {
        'e1': {'t3'},
        'e2': {'t2', 't3'},
        'e3': {'t3'},
      });
      // Every item is in the snapshot, e3 with an empty list, so Undo can take
      // the new tag back off an item that had none.
      expect(prior.map((id, tags) => MapEntry(id, tags.toSet())), {
        'e1': {'t1'},
        'e2': {'t1', 't2'},
        'e3': <String>{},
      });
    },
  );

  test(
    'undo restores the exact prior sets, including partial overlap',
    () async {
      final before = await tagSets();
      final prior = await service.apply(
        equipmentIds: ids,
        addTagIds: {'t2', 't3'},
        removeTagIds: {'t1'},
      );

      await service.undo(prior);

      expect(await tagSets(), before);
    },
  );

  test('neither apply nor undo marks an equipment row pending', () async {
    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t3'},
      removeTagIds: {'t1'},
    );
    await service.undo(prior);

    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipment'",
      ),
      0,
    );
    expect(
      await count("SELECT COUNT(*) AS n FROM equipment WHERE updated_at != 0"),
      0,
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipmentTags'",
      ),
      greaterThan(0),
    );
  });

  test('adding a tag an item already has is a no-op', () async {
    await service.apply(
      equipmentIds: const ['e1'],
      addTagIds: {'t1'},
      removeTagIds: const {},
    );

    final rows = await db
        .customSelect("SELECT id FROM equipment_tags WHERE equipment_id = 'e1'")
        .get();
    expect(rows.map((r) => r.read<String>('id')), ['l1']);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipmentTags'",
      ),
      0,
    );
  });

  test(
    'an empty change writes nothing and returns an empty snapshot',
    () async {
      final prior = await service.apply(
        equipmentIds: ids,
        addTagIds: const {},
        removeTagIds: const {},
      );

      expect(prior, isEmpty);
      expect(await count("SELECT COUNT(*) AS n FROM sync_records"), 0);
    },
  );

  test('apply and undo each notify once', () async {
    var notifications = 0;
    final sub = SyncEventBus.changes.listen((_) => notifications++);
    addTearDown(sub.cancel);

    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t3'},
      removeTagIds: {'t1'},
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 1);

    await service.undo(prior);
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 2);
  });

  test('a failure partway through apply leaves every item as it was', () async {
    final before = await tagSets();
    // The removal runs after the additions, so this aborts the transaction
    // with the new rows already written.
    await db.customStatement(
      'CREATE TEMP TRIGGER fail_removal BEFORE DELETE ON equipment_tags '
      "BEGIN SELECT RAISE(ABORT, 'removal refused'); END",
    );

    await expectLater(
      service.apply(equipmentIds: ids, addTagIds: {'t3'}, removeTagIds: {'t1'}),
      throwsA(anything),
    );

    expect(await tagSets(), before);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipmentTags'",
      ),
      0,
    );
  });

  test('an item edit made between apply and undo survives the undo', () async {
    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t3'},
      removeTagIds: const {},
    );
    await db.customStatement(
      "UPDATE equipment SET name = 'Travel wing' WHERE id = 'e1'",
    );

    await service.undo(prior);

    final row = await db
        .customSelect("SELECT name FROM equipment WHERE id = 'e1'")
        .getSingle();
    expect(row.read<String>('name'), 'Travel wing');
    expect((await tagSets())['e1'], {'t1'});
  });

  test('undo skips an item and a tag deleted since apply', () async {
    final prior = await service.apply(
      equipmentIds: ids,
      addTagIds: {'t3'},
      removeTagIds: {'t2'},
    );
    await db.customStatement("DELETE FROM equipment WHERE id = 'e3'");
    await db.customStatement("DELETE FROM tags WHERE id = 't2'");

    await service.undo(prior);

    expect(await tagSets(), {
      'e1': {'t1'},
      'e2': {'t1'},
      'e3': <String>{},
    });
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM equipment_tags WHERE equipment_id = 'e3'",
      ),
      0,
    );
  });
}
