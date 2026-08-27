import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('v139 is in the migration ladder', () {
    // greaterThanOrEqualTo, not ==: a higher version merging first must not
    // turn this into a false failure. See the schema-version ladder
    // convention.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(139));
    expect(AppDatabase.migrationVersions, contains(139));
  });

  test('a fresh database has both cylinder config tables', () async {
    final configCols = await db
        .customSelect("PRAGMA table_info('cylinder_configs')")
        .get();
    expect(
      configCols.map((c) => c.read<String>('name')).toSet(),
      containsAll([
        'id',
        'diver_id',
        'equipment_id',
        'name',
        'description',
        'sort_order',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );

    final itemCols = await db
        .customSelect("PRAGMA table_info('cylinder_config_items')")
        .get();
    expect(
      itemCols.map((c) => c.read<String>('name')).toSet(),
      containsAll([
        'id',
        'config_id',
        'sort_order',
        'label',
        'tank_role',
        'volume_l',
        'working_pressure_bar',
        'tank_material',
        'o2_percent',
        'he_percent',
        'default_start_pressure_bar',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test(
    'deleting the owning equipment demotes the config, not deletes it',
    () async {
      // Drift's in-memory default leaves foreign keys OFF, which would make
      // this assertion pass whether or not ON DELETE SET NULL is wired.
      await db.customStatement('PRAGMA foreign_keys = ON');

      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        "INSERT INTO equipment (id, name, type, created_at, updated_at) "
        "VALUES ('rb-1', 'JJ', 'rebreather', $now, $now)",
      );
      await db.customStatement(
        "INSERT INTO cylinder_configs "
        "(id, equipment_id, name, description, sort_order, "
        " created_at, updated_at) "
        "VALUES ('c1', 'rb-1', 'Trimix', '', 0, $now, $now)",
      );

      await db.customStatement("DELETE FROM equipment WHERE id = 'rb-1'");

      final rows = await db
          .customSelect(
            "SELECT id, equipment_id FROM cylinder_configs WHERE id = 'c1'",
          )
          .get();
      expect(rows, hasLength(1), reason: 'config must survive unit deletion');
      expect(rows.single.read<String?>('equipment_id'), isNull);
    },
  );

  test('deleting a config cascades to its items', () async {
    await db.customStatement('PRAGMA foreign_keys = ON');

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO cylinder_configs "
      "(id, name, description, sort_order, created_at, updated_at) "
      "VALUES ('c1', 'Doubles', '', 0, $now, $now)",
    );
    await db.customStatement(
      "INSERT INTO cylinder_config_items "
      "(id, config_id, sort_order, tank_role, o2_percent, he_percent, "
      " created_at, updated_at) "
      "VALUES ('i1', 'c1', 0, 'backGas', 21, 0, $now, $now)",
    );

    await db.customStatement("DELETE FROM cylinder_configs WHERE id = 'c1'");

    final items = await db
        .customSelect('SELECT id FROM cylinder_config_items')
        .get();
    expect(items, isEmpty);
  });

  test('gas columns carry non-null defaults matching dive_tanks', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      "INSERT INTO cylinder_configs "
      "(id, name, description, sort_order, created_at, updated_at) "
      "VALUES ('c1', 'Air', '', 0, $now, $now)",
    );
    await db.customStatement(
      "INSERT INTO cylinder_config_items "
      "(id, config_id, sort_order, tank_role, created_at, updated_at) "
      "VALUES ('i1', 'c1', 0, 'backGas', $now, $now)",
    );

    final row = await db
        .customSelect(
          'SELECT o2_percent, he_percent FROM cylinder_config_items',
        )
        .getSingle();
    expect(row.read<double>('o2_percent'), 21.0);
    expect(row.read<double>('he_percent'), 0.0);
  });

  test(
    'a database stranded below v139 self-heals via the schema assert',
    () async {
      await db.customStatement('DROP TABLE IF EXISTS cylinder_config_items');
      await db.customStatement('DROP TABLE IF EXISTS cylinder_configs');

      await db.assertCylinderConfigSchemaForTest();

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name LIKE 'cylinder_config%'",
          )
          .get();
      expect(tables.map((t) => t.read<String>('name')).toSet(), {
        'cylinder_configs',
        'cylinder_config_items',
      });

      // Idempotent: running it again over healed tables is a no-op.
      await db.assertCylinderConfigSchemaForTest();
    },
  );

  test('fresh install has the cylinder config indexes', () async {
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name LIKE 'idx_cylinder_config%'",
        )
        .get();
    expect(
      idx.map((r) => r.read<String>('name')),
      containsAll([
        'idx_cylinder_configs_equipment',
        'idx_cylinder_config_items_config',
      ]),
    );
  });
}
