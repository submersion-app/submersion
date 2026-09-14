import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';

import '../../../../helpers/bound_variables.dart';
import '../../../../helpers/test_database.dart';

/// The equipment tag junction (issue #1942).
void main() {
  late EquipmentTagRepository repository;

  Future<void> seed() async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1), ('e2', 'Fins', 'fins', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1)",
    );
  }

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentTagRepository();
    await seed();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<int> count(String sql) async {
    final row = await DatabaseService.instance.database
        .customSelect(sql)
        .getSingle();
    return row.read<int>('n');
  }

  Future<Set<String>> tagIdsOf(String equipmentId) async =>
      ((await repository.getTagIdsByEquipment([equipmentId]))[equipmentId] ??
              const <String>[])
          .toSet();

  test('replaceTags sets the exact set and reads it back by name', () async {
    await repository.replaceTags('e1', ['t1', 't2']);
    final tags = await repository.getTagsForEquipment('e1');
    expect(tags.map((t) => t.name), ['Rental', 'Travel kit']);
  });

  test(
    'replaceTags removes only what left the set and tombstones it',
    () async {
      final db = DatabaseService.instance.database;
      await repository.replaceTags('e1', ['t1', 't2']);
      final before = await db.select(db.equipmentTags).get();
      final keptId = before.firstWhere((r) => r.tagId == 't1').id;
      final droppedId = before.firstWhere((r) => r.tagId == 't2').id;

      await repository.replaceTags('e1', ['t1']);

      final after = await db.select(db.equipmentTags).get();
      expect(after.map((r) => r.id), [
        keptId,
      ], reason: 'a kept pair keeps its row');
      final tombstones = await db.select(db.deletionLog).get();
      expect(
        tombstones
            .where((t) => t.entityType == 'equipmentTags')
            .map((t) => t.recordId),
        [droppedId],
      );
    },
  );

  test('a failing replaceTags leaves the previous set whole', () async {
    await repository.replaceTags('e1', ['t1']);

    // 'missing' has no tags row, so its insert fails the foreign key after
    // t1's row was already deleted inside the same transaction.
    await expectLater(
      repository.replaceTags('e1', ['t2', 'missing']),
      throwsA(anything),
    );

    expect(await tagIdsOf('e1'), {'t1'});
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      0,
    );
  });

  test('addTags unions across items and never removes', () async {
    await repository.addTags(['e1'], ['t1']);
    await repository.addTags(['e1', 'e2'], ['t1', 't2']);

    expect(await tagIdsOf('e1'), {'t1', 't2'});
    expect(await tagIdsOf('e2'), {'t1', 't2'});
    expect(await count('SELECT COUNT(*) AS n FROM equipment_tags'), 4);
  });

  test('a duplicate add is a no-op', () async {
    final db = DatabaseService.instance.database;
    await repository.addTags(['e1'], ['t1']);
    final first = (await db.select(db.equipmentTags).get()).single;
    await SyncRepository().clearAllSyncRecords();

    await repository.addTags(['e1', 'e1'], ['t1', 't1']);

    final rows = await db.select(db.equipmentTags).get();
    expect(rows.map((r) => r.id), [first.id]);
    expect(await count('SELECT COUNT(*) AS n FROM sync_records'), 0);
  });

  test('removeTags drops only the named pairs and tombstones each', () async {
    await repository.addTags(['e1'], ['t1', 't2']);
    await repository.addTags(['e2'], ['t1']);

    await repository.removeTags(['e1', 'e2'], ['t1']);

    expect(await tagIdsOf('e1'), {'t2'});
    expect(await tagIdsOf('e2'), isEmpty);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      2,
    );
  });

  test('junction writes mark the rows pending, never the item', () async {
    await repository.replaceTags('e1', ['t1']);
    await repository.addTags(['e1', 'e2'], ['t2']);
    await repository.removeTags(['e2'], ['t2']);

    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records "
        "WHERE entity_type = 'equipmentTags'",
      ),
      3,
      reason: 'one pending mark per inserted row',
    );
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = 'equipment'",
      ),
      0,
    );
    expect(
      await count('SELECT COUNT(*) AS n FROM equipment WHERE updated_at <> 1'),
      0,
    );
    expect(
      await count('SELECT COUNT(*) AS n FROM equipment_tags WHERE hlc IS NULL'),
      0,
      reason: 'marking a link pending stamps its own clock',
    );
  });

  test('batch reads group by item', () async {
    await repository.replaceTags('e1', ['t1']);
    await repository.replaceTags('e2', ['t1', 't2']);

    final byItem = await repository.getTagsByEquipment();
    expect(byItem['e1']!.map((t) => t.name), ['Travel kit']);
    expect(byItem['e2']!.map((t) => t.name), ['Rental', 'Travel kit']);

    final ids = await repository.getTagIdsByEquipment(['e1', 'e2', 'e9']);
    expect(ids['e1'], ['t1']);
    expect(ids['e2'], ['t1', 't2'], reason: 'oldest link first');
    expect(ids.containsKey('e9'), isFalse);

    expect(await repository.tagCountsForEquipment(['e1', 'e2']), {
      't1': 2,
      't2': 1,
    });
    expect(await repository.tagCountsForEquipment(['e2']), {'t1': 1, 't2': 1});
  });

  test('empty inputs read and write nothing', () async {
    expect(await repository.getTagIdsByEquipment(const []), isEmpty);
    expect(await repository.tagCountsForEquipment(const []), isEmpty);
    await repository.addTags(const [], ['t1']);
    await repository.addTags(['e1'], const []);
    await repository.removeTags(['e1'], const []);
    expect(await count('SELECT COUNT(*) AS n FROM equipment_tags'), 0);
  });

  test('deleteLinksForEquipment deletes and tombstones one item', () async {
    await repository.addTags(['e1', 'e2'], ['t1']);

    await repository.deleteLinksForEquipment('e1');

    expect(await tagIdsOf('e1'), isEmpty);
    expect(await tagIdsOf('e2'), {'t1'});
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log "
        "WHERE entity_type = 'equipmentTags'",
      ),
      1,
    );
  });

  test('watchChanges emits on a link change', () async {
    final emitted = <void>[];
    final sub = repository.watchChanges().listen(emitted.add);
    addTearDown(sub.cancel);

    await repository.addTags(['e1'], ['t1']);
    await pumpEventQueue();

    expect(emitted, isNotEmpty);
  });

  test('a large selection binds within SQLite\'s variable limit', () async {
    await tearDownTestDatabase();
    final db = setUpLoggingTestDatabase();
    repository = EquipmentTagRepository();
    final ids = [for (var i = 0; i < 1000; i++) 'e$i'];
    await quietly(() async {
      await db.customStatement(
        'WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n '
        'WHERE i < 999) '
        'INSERT INTO equipment (id, name, type, created_at, updated_at) '
        "SELECT 'e' || i, 'Item', 'bcd', 0, 0 FROM n",
      );
      await db.customStatement(
        "INSERT INTO tags (id, name, created_at, updated_at, "
        "applies_to_equipment) VALUES ('t1', 'Travel kit', 0, 0, 1)",
      );
    });

    final most = await maxBoundVariables(() async {
      await repository.addTags(ids, ['t1']);
      await repository.getTagIdsByEquipment(ids);
      await repository.tagCountsForEquipment(ids);
      await repository.removeTags(ids, ['t1']);
    });

    expect(most, lessThanOrEqualTo(sqliteVariableLimit));
  });
}
