import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v271 (issue #2267): the certification currency tables and the seeded
/// built-in rule catalog.
NativeDatabase setupDb({int userVersion = 270}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      // divers and buddies exist on every real ladder. A beforeOpen backstop
      // gives certifications a buddy_id REFERENCES buddies, and the currency
      // rules reference divers, so a fixture missing either fails FK
      // resolution rather than anything this rung got wrong.
      rawDb.execute('''
        CREATE TABLE buddies (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE divers (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE certifications (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          agency TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    },
  );
}

Future<Set<String>> columnsOf(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v271 is at or below the current schema version and in the ladder', () {
    // Relaxed once v272 (the role junctions, #1221) landed on top; the
    // newest rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(271));
    expect(AppDatabase.migrationVersions, contains(271));
    expect(
      AppDatabase.migrationStepCount(270),
      AppDatabase.migrationStepCount(271) + 1,
    );
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a v270 database upgrades and gains the three tables', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(await columnsOf(db, 'certification_currency_rules'), {
      'id',
      'diver_id',
      'name',
      'clock_kind',
      'applicable_agencies',
      'applicable_levels',
      'lapse_days',
      'lead_days',
      'counted_dive_type_ids',
      'counted_dive_modes',
      'advisory_key',
      'advisory_text',
      'supersedes_rule_id',
      'is_built_in',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(await columnsOf(db, 'certification_currency_prefs'), {
      'id',
      'certification_id',
      'rule_id',
      'lapse_days_override',
      'lead_days_override',
      'counted_dive_type_ids',
      'counted_dive_modes',
      'muted',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(await columnsOf(db, 'certification_currency_events'), {
      'id',
      'certification_id',
      'rule_id',
      'event_type',
      'event_date',
      'provider',
      'notes',
      'created_at',
      'updated_at',
      'hlc',
    });
  });

  test('the upgrade seeds exactly the ten built-in rules', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT id FROM certification_currency_rules WHERE is_built_in = 1',
        )
        .get();
    expect(rows.map((r) => r.read<String>('id')).toSet(), {
      'padi_reactivate',
      'ssi_skills_update',
      'generic_refresher',
      'first_aid_24mo',
      'pro_membership_annual',
      'gue_revalidation',
      'ffessm_licence_annual',
      'cave_currency',
      'rebreather_currency',
      'deco_currency',
    });
  });

  test('the seeded scopes name levels that still exist', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    // A seed naming a level this build does not have is a rule that silently
    // matches nothing, which no test would otherwise notice.
    final row = await db
        .customSelect(
          'SELECT applicable_levels FROM certification_currency_rules '
          "WHERE id = 'first_aid_24mo'",
        )
        .getSingle();
    expect(
      row.read<String>('applicable_levels'),
      '["firstAid","oxygenProvider","danBls","danEmergencyOxygen",'
      '"danDfaPro","danDemp","danAdvancedOxygen",'
      '"danNeurologicalAssessment","danMarineLifeInjuries"]',
    );
  });

  test('re-seeding is idempotent and never rewrites a diver edit', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    await db.customStatement(
      'UPDATE certification_currency_rules SET lapse_days = 999 '
      "WHERE id = 'cave_currency'",
    );
    // The beforeOpen backstop runs on every open; simulate a second one.
    await db.customStatement(kSeedBuiltInCurrencyRulesSql);

    final row = await db
        .customSelect(
          'SELECT lapse_days, COUNT(*) AS n FROM certification_currency_rules '
          "WHERE id = 'cave_currency'",
        )
        .getSingle();
    expect(row.read<int>('n'), 1);
    expect(
      row.read<int>('lapse_days'),
      999,
      reason: 'INSERT OR IGNORE must not overwrite a tuned built-in',
    );
  });

  test('prefs and events cascade when their certification goes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    await db.customStatement(
      'INSERT INTO certifications (id, name, agency, created_at, updated_at) '
      "VALUES ('c1', 'OW', 'padi', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO certification_currency_prefs '
      '(id, certification_id, rule_id, muted, created_at, updated_at) '
      "VALUES ('p1', 'c1', 'cave_currency', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO certification_currency_events '
      '(id, certification_id, rule_id, event_type, event_date, notes, '
      'created_at, updated_at) '
      "VALUES ('e1', 'c1', 'cave_currency', 'refresher', 100, '', 0, 0)",
    );
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement("DELETE FROM certifications WHERE id = 'c1'");

    final prefs = await db
        .customSelect('SELECT id FROM certification_currency_prefs')
        .get();
    final events = await db
        .customSelect('SELECT id FROM certification_currency_events')
        .get();
    expect(prefs, isEmpty);
    expect(events, isEmpty);
  });

  test('a fresh install seeds the same ten built-ins', () async {
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    final row = await fresh
        .customSelect(
          'SELECT COUNT(*) AS n FROM certification_currency_rules '
          'WHERE is_built_in = 1',
        )
        .getSingle();
    expect(row.read<int>('n'), 10);
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    for (final table in const [
      'certification_currency_rules',
      'certification_currency_prefs',
      'certification_currency_events',
    ]) {
      expect(
        await columnsOf(upgraded, table),
        await columnsOf(fresh, table),
        reason: '$table must be identical on both paths',
      );
    }
  });
}
