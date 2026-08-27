import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A v159 service_kinds table carrying one built-in and one custom kind.
  NativeDatabase seededV159() => NativeDatabase.memory(
    setup: (db) {
      db.execute('PRAGMA user_version = 159');
      db.execute('''
        CREATE TABLE service_kinds (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          applicable_types TEXT NOT NULL DEFAULT '[]',
          default_interval_days INTEGER,
          default_interval_dives INTEGER,
          default_interval_hours REAL,
          default_cost REAL,
          default_currency TEXT,
          auto_attach INTEGER NOT NULL DEFAULT 0,
          is_built_in INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      db.execute(
        "INSERT INTO service_kinds (id, name, is_built_in, created_at, "
        "updated_at) VALUES ('hydro', 'Hydrostatic test', 1, 1, 1)",
      );
      db.execute(
        "INSERT INTO service_kinds (id, name, is_built_in, created_at, "
        "updated_at) VALUES ('disinfect', 'Disinfect', 0, 1, 1)",
      );
    },
  );

  test('v160 adds default_category and seeds built-ins only', () async {
    final db = AppDatabase(seededV159());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('service_kinds')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    expect(byName.containsKey('default_category'), isTrue);
    expect(
      byName['default_category']!.read<String>('type').toUpperCase(),
      'TEXT',
    );

    final hydro = await db
        .customSelect(
          "SELECT default_category FROM service_kinds WHERE id = 'hydro'",
        )
        .getSingle();
    expect(hydro.read<String?>('default_category'), 'inspection');

    final custom = await db
        .customSelect(
          "SELECT default_category FROM service_kinds WHERE id = 'disinfect'",
        )
        .getSingle();
    expect(
      custom.read<String?>('default_category'),
      isNull,
      reason: 'a custom kind has no opinion until the diver gives it one',
    );
  });

  test('the migration itself inserts no kinds', () async {
    final db = AppDatabase(seededV159());
    addTearDown(db.close);

    // The v160 step is an UPDATE keyed on existing ids, so it can only ever
    // touch rows already present. Any row beyond the two seeded here came
    // from kSeedBuiltInServiceKindsSql in beforeOpen, never from the
    // migration, which is what keeps a deleted built-in deleted.
    final ids = await db
        .customSelect(
          "SELECT id, default_category FROM service_kinds "
          "WHERE id = 'disinfect'",
        )
        .get();
    expect(ids, hasLength(1));
    expect(ids.single.read<String?>('default_category'), isNull);
  });

  test('the helper no-ops when service_kinds is absent', () async {
    final native = NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA user_version = 159'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('migration list includes v160 and schema is at least 160', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(160));
    expect(AppDatabase.migrationVersions, contains(160));
  });

  test(
    'v160 renames service_type to service_category, preserving values',
    () async {
      final native = NativeDatabase.memory(
        setup: (db) {
          db.execute('PRAGMA user_version = 159');
          db.execute('''
          CREATE TABLE service_records (
            id TEXT NOT NULL PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            service_type TEXT NOT NULL,
            service_kind_id TEXT,
            service_date INTEGER NOT NULL,
            provider TEXT,
            cost REAL,
            currency TEXT NOT NULL DEFAULT 'USD',
            next_service_due INTEGER,
            notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
          db.execute(
            "INSERT INTO service_records (id, equipment_id, service_type, "
            "service_date, created_at, updated_at) "
            "VALUES ('r1', 'e1', 'overhaul', 1, 1, 1)",
          );
        },
      );
      final db = AppDatabase(native);
      addTearDown(db.close);

      final row = await db
          .customSelect(
            'SELECT service_category, service_kind_id '
            'FROM service_records',
          )
          .getSingle();
      expect(row.read<String>('service_category'), 'overhaul');
      expect(
        row.read<String?>('service_kind_id'),
        isNull,
        reason:
            'the migration must not attach a kind, which would move a clock',
      );
    },
  );

  test(
    'the rename is idempotent when service_category already exists',
    () async {
      final native = NativeDatabase.memory(
        setup: (db) {
          db.execute('PRAGMA user_version = 159');
          db.execute('''
          CREATE TABLE service_records (
            id TEXT NOT NULL PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            service_category TEXT NOT NULL,
            service_kind_id TEXT,
            service_date INTEGER NOT NULL,
            provider TEXT,
            cost REAL,
            currency TEXT NOT NULL DEFAULT 'USD',
            next_service_due INTEGER,
            notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        },
      );
      final db = AppDatabase(native);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('service_records')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toList();
      expect(names.where((n) => n == 'service_category').length, 1);
      expect(names, isNot(contains('service_type')));
    },
  );

  test('the compatibility floor records the rename', () {
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      160,
      reason: 'renaming a synced column is breaking under the #1089 rules',
    );
  });

  // The seed SQL writes its category literals inline rather than reading the
  // map, because it is a const SQL string. These two tests are what actually
  // keeps the pair in step: the first pins the slug set, the second pins the
  // category each slug is seeded with. Without them a fresh install and an
  // upgraded install could disagree about what "hydro" defaults to.
  test('every built-in slug in the seed SQL has a category', () {
    for (final slug in kBuiltInServiceKindCategories.keys) {
      expect(
        kSeedBuiltInServiceKindsSql,
        contains("'$slug'"),
        reason: 'the category map names a slug the seed SQL does not create',
      );
    }
  });

  test('a fresh install seeds the same categories the migration would', () async {
    // A database created from scratch runs the seed SQL, never the migration.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT id, default_category FROM service_kinds WHERE is_built_in = 1',
        )
        .get();
    final seeded = {
      for (final r in rows)
        r.read<String>('id'): r.read<String?>('default_category'),
    };

    expect(
      seeded.keys.toSet(),
      kBuiltInServiceKindCategories.keys.toSet(),
      reason: 'the seed SQL and the category map disagree about the slug set',
    );
    for (final entry in kBuiltInServiceKindCategories.entries) {
      expect(
        seeded[entry.key],
        entry.value,
        reason:
            'seed SQL seeds ${entry.key} as ${seeded[entry.key]}, but the map '
            'the migration reads says ${entry.value}',
      );
    }
  });
}
