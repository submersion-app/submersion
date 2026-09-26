import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<bool> _tableExists(AppDatabase db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(table)],
      )
      .get();
  return rows.isNotEmpty;
}

void main() {
  test('v231 creates dive_scenarios with the hlc column', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 230');
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    expect(await _tableExists(db, 'dive_scenarios'), isTrue);
    final cols = await _columns(db, 'dive_scenarios');
    expect(
      cols,
      containsAll([
        'id',
        'dive_id',
        'name',
        'notes',
        'branch_seconds',
        'mode',
        'interventions_json',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_dive_scenarios_dive_id'",
        )
        .get();
    expect(idx, hasLength(1));
  });

  test('backstop heals a 231 database that lacks the table', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 231');
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());
    expect(await _tableExists(db, 'dive_scenarios'), isTrue);
  });

  test('v231 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(231));
    expect(AppDatabase.migrationVersions, contains(231));
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.migrationStepCount(230), 1);
    // A new table is additive: the compatibility floor stays put.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('fresh database exposes the scenarios table via Drift', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());
    expect(await db.select(db.diveScenarios).get(), isEmpty);
  });
}
