import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v239: the built-in regulator service and O2 clean kinds apply to
/// first and second stages (issue #2275).
///
/// Issue #1487 split a regulator into first stage, second stage and hose
/// items, but both built-in kinds still named only `regulator`. A diver who
/// entered a new second stage could offer it nothing but "General service".
void main() {
  const regulatorTypes = '["regulator","firstStage","secondStage"]';
  const o2CleanTypes = '["tank","regulator","firstStage","secondStage"]';

  /// A v238 database whose built-in kinds carry the pre-v239 type lists.
  /// Minimal parents, as the v234 fixture: the beforeOpen backstops heal
  /// every older rung.
  NativeDatabase setupDb() {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 238');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE service_kinds (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            applicable_types TEXT NOT NULL DEFAULT '[]',
            default_interval_days INTEGER, default_interval_dives INTEGER,
            default_interval_hours REAL,
            exposure_intervals TEXT NOT NULL DEFAULT '{}',
            default_cost REAL, default_currency TEXT, default_category TEXT,
            auto_attach INTEGER NOT NULL DEFAULT 0,
            is_built_in INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
            hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO service_kinds (id, name, applicable_types, "
          "default_interval_days, default_interval_dives, auto_attach, "
          "default_category, exposure_intervals, is_built_in, created_at, "
          "updated_at) VALUES ('regulator-service', 'Regulator service', "
          "'[\"regulator\"]', 365, 100, 1, 'annual', '{\"coldDives\":50}', "
          "1, 5, 5)",
        );
        rawDb.execute(
          "INSERT INTO service_kinds (id, name, applicable_types, "
          "default_interval_days, auto_attach, default_category, "
          "exposure_intervals, is_built_in, created_at, updated_at) VALUES "
          "('o2-clean', 'O2 clean', '[\"tank\",\"regulator\"]', 365, 0, "
          "'cleaning', '{\"o2Hours\":50}', 1, 5, 5)",
        );
        // A diver's own kind scoped to regulators: never widened.
        rawDb.execute(
          "INSERT INTO service_kinds (id, name, applicable_types, "
          "is_built_in, created_at, updated_at) VALUES "
          "('custom-reg', 'Reg tune', '[\"regulator\"]', 0, 5, 5)",
        );
      },
    );
  }

  Future<Map<String, Object?>> kind(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          'SELECT applicable_types, auto_attach, default_interval_days, '
          'default_interval_dives, exposure_intervals, updated_at '
          'FROM service_kinds WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingle();
    return row.data;
  }

  test('v239 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 239);
    expect(AppDatabase.migrationVersions, contains(239));
    expect(AppDatabase.migrationStepCount(238), 1);
    // Reference-data rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('a fresh database seeds the regulator parts on both kinds', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(
      (await kind(db, 'regulator-service'))['applicable_types'],
      regulatorTypes,
    );
    expect((await kind(db, 'o2-clean'))['applicable_types'], o2CleanTypes);
  });

  test('an upgraded database widens both built-in kinds', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final reg = await kind(db, 'regulator-service');
    expect(reg['applicable_types'], regulatorTypes);
    // Only the type list moves; the kind's clocks and flags are untouched.
    expect(reg['auto_attach'], 1);
    expect(reg['default_interval_days'], 365);
    expect(reg['default_interval_dives'], 100);
    expect(reg['exposure_intervals'], '{"coldDives":50}');
    expect(reg['updated_at'], 5);

    final o2 = await kind(db, 'o2-clean');
    expect(o2['applicable_types'], o2CleanTypes);
    expect(o2['auto_attach'], 0);
  });

  test('a custom kind keeps the types its diver chose', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect((await kind(db, 'custom-reg'))['applicable_types'], '["regulator"]');
  });

  test('the backfill and the seed agree on both type lists', () async {
    // The seed is INSERT OR IGNORE, so it cannot fix an existing row, and the
    // backfill runs from the v239 rung only. The two must name the same
    // types or a fresh install and an upgraded one would disagree.
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);

    for (final id in ['regulator-service', 'o2-clean']) {
      expect(
        (await kind(upgraded, id))['applicable_types'],
        (await kind(fresh, id))['applicable_types'],
        reason: id,
      );
    }
  });
}
