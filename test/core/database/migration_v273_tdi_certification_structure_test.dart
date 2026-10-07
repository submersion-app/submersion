import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

/// TDI's own certification structure (v273, issue #3072): rewrites the
/// eight unambiguous legacy TDI certification levels and extends the
/// currency rules that named the old ones.
NativeDatabase setupDb({int userVersion = 272}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
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
          level TEXT,
          buddy_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE certification_currency_rules (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          clock_kind TEXT NOT NULL,
          applicable_agencies TEXT NOT NULL DEFAULT '[]',
          applicable_levels TEXT NOT NULL DEFAULT '[]',
          lapse_days INTEGER NOT NULL,
          lead_days INTEGER NOT NULL,
          counted_dive_type_ids TEXT NOT NULL DEFAULT '[]',
          counted_dive_modes TEXT NOT NULL DEFAULT '[]',
          advisory_key TEXT,
          advisory_text TEXT,
          supersedes_rule_id TEXT,
          is_built_in INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      void insertCert(String id, String agency, String? level) {
        rawDb.execute(
          'INSERT INTO certifications '
          '(id, name, agency, level, created_at, updated_at) '
          "VALUES ('$id', 'cert', '$agency', "
          "${level == null ? 'NULL' : "'$level'"}, 0, 0)",
        );
      }

      // The eight unambiguous legacy values, on TDI.
      for (final level in const [
        'nitrox',
        'advancedNitrox',
        'decompression',
        'extendedRange',
        'trimix',
        'advancedTrimix',
        'sidemount',
        'cavern',
      ]) {
        insertCert('tdi-$level', 'tdi', level);
      }
      // A deliberately ambiguous legacy value: untouched.
      insertCert('tdi-cave', 'tdi', 'cave');
      // Same old generic value, but a different agency: untouched, the
      // rewrite is scoped to TDI only.
      insertCert('iantd-nitrox', 'iantd', 'nitrox');
      // A buddy-owned certification (nullable diverId/buddyId; this
      // fixture only needs the column to exist): the rewrite is agency/
      // level scoped, not ownership scoped, so this moves too.
      rawDb.execute(
        'INSERT INTO certifications '
        '(id, name, agency, level, buddy_id, created_at, updated_at) '
        "VALUES ('buddy-tdi-nitrox', 'cert', 'tdi', 'nitrox', 'b1', 0, 0)",
      );

      // A minimal stand-in for the four pre-existing built-in rules this
      // rung extends, seeded as v271 left them (no TDI values yet in the
      // ones that need them).
      void insertRule(String id, String levels) {
        rawDb.execute(
          'INSERT INTO certification_currency_rules '
          '(id, name, clock_kind, applicable_levels, lapse_days, lead_days, '
          'is_built_in, created_at, updated_at) '
          "VALUES ('$id', '$id', 'activity', '$levels', 365, 90, 1, 0, 0)",
        );
      }

      insertRule('pro_membership_annual', '["instructor"]');
      insertRule('deco_currency', '["decompression","trimix"]');
      insertRule('cave_currency', '["cave","cavern"]');
      insertRule('rebreather_currency', '["rebreather"]');
      // generic_refresher as it existed before v273: "tdi" still in its
      // agencies, seeded alongside the other agencies that share it.
      rawDb.execute(
        'INSERT INTO certification_currency_rules '
        '(id, name, clock_kind, applicable_agencies, applicable_levels, '
        'lapse_days, lead_days, is_built_in, created_at, updated_at) VALUES '
        "('generic_refresher', 'Refresher', 'activity', "
        '\'["naui","sdi","tdi","raid","other"]\', '
        '\'["openWater","nitrox","cave","rebreather","instructor"]\', '
        "365, 185, 1, 0, 0)",
      );
      // A diver-tuned custom rule sharing one of those ids' name is not
      // possible (ids are the primary key); a non-built-in row with its
      // own id must stay untouched by the WHERE is_built_in = 1 guard.
      rawDb.execute(
        'INSERT INTO certification_currency_rules '
        '(id, name, clock_kind, applicable_levels, lapse_days, lead_days, '
        "is_built_in, created_at, updated_at) VALUES "
        "('custom-1', 'Club rule', 'activity', '[\"cave\"]', 1, 1, 0, 0, 0)",
      );
    },
  );
}

Future<Map<String, String?>> levelsByCertId(AppDatabase db) async {
  final rows = await db
      .customSelect('SELECT id, level FROM certifications')
      .get();
  return {for (final r in rows) r.read<String>('id'): r.read<String?>('level')};
}

Future<String> applicableAgenciesOf(AppDatabase db, String ruleId) async {
  final row = await db
      .customSelect(
        'SELECT applicable_agencies FROM certification_currency_rules '
        'WHERE id = ?',
        variables: [Variable<String>(ruleId)],
      )
      .getSingle();
  return row.read<String>('applicable_agencies');
}

Future<String> applicableLevelsOf(AppDatabase db, String ruleId) async {
  final row = await db
      .customSelect(
        'SELECT applicable_levels FROM certification_currency_rules '
        'WHERE id = ?',
        variables: [Variable<String>(ruleId)],
      )
      .getSingle();
  return row.read<String>('applicable_levels');
}

void main() {
  test('v273 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(273));
    expect(AppDatabase.migrationVersions, contains(273));
    expect(AppDatabase.migrationStepCount(272), 1);
    // The combined jump from 271: v272's relaxed assertion only pins a
    // floor, so this is what actually pins the total at exactly two steps.
    expect(AppDatabase.migrationStepCount(271), 2);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('rewrites the eight unambiguous legacy TDI levels', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final levels = await levelsByCertId(db);
    expect(levels['tdi-nitrox'], 'tdiNitroxDiver');
    expect(levels['tdi-advancedNitrox'], 'tdiAdvancedNitroxDiver');
    expect(levels['tdi-decompression'], 'tdiDecompressionProceduresDiver');
    expect(levels['tdi-extendedRange'], 'tdiExtendedRangeDiver');
    expect(levels['tdi-trimix'], 'tdiTrimixDiver');
    expect(levels['tdi-advancedTrimix'], 'tdiAdvancedTrimixDiver');
    expect(levels['tdi-sidemount'], 'tdiSidemountDiver');
    expect(levels['tdi-cavern'], 'tdiCavernDiver');
  });

  test('leaves ambiguous legacy TDI levels untouched', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final levels = await levelsByCertId(db);
    expect(levels['tdi-cave'], 'cave');
  });

  test('never rewrites the same legacy level under another agency', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final levels = await levelsByCertId(db);
    expect(levels['iantd-nitrox'], 'nitrox');
  });

  test('rewrites a buddy-owned TDI certification the same way', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final levels = await levelsByCertId(db);
    expect(levels['buddy-tdi-nitrox'], 'tdiNitroxDiver');
  });

  test('merges the new TDI levels into the four currency rules', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await applicableLevelsOf(db, 'pro_membership_annual'),
      '["instructor","tdiTechnicalDivemaster","tdiInstructor","tdiInstructorTrainer","tdiNonDivingSpecialtyInstructor"]',
    );
    expect(
      await applicableLevelsOf(db, 'deco_currency'),
      '["decompression","trimix","tdiDecompressionProceduresDiver",'
      '"tdiTrimixDiver","tdiAdvancedTrimixDiver","tdiAdvancedNitroxDiver",'
      '"tdiExtendedRangeDiver","tdiHelitroxDiver"]',
    );
    expect(
      await applicableLevelsOf(db, 'cave_currency'),
      '["cave","cavern","tdiCavernDiver","tdiIntroToCaveDiver",'
      '"tdiFullCaveDiver","tdiRebreatherCavernDiver",'
      '"tdiRebreatherIntroCaveDiver","tdiRebreatherFullCaveDiver",'
      '"tdiCaveSurveyingDiver","tdiStageCaveDiver","tdiDpvCaveDiver"]',
    );
    expect(
      await applicableLevelsOf(db, 'rebreather_currency'),
      '["rebreather","tdiAirDiluentCcrDiver","tdiSemiClosedRebreatherDiver",'
      '"tdiAirDiluentDecoCcrDiver","tdiHelitroxCcrDiver",'
      '"tdiMixedGasCcrDiver","tdiAdvancedMixedGasCcrDiver",'
      '"tdiRebreatherCavernDiver","tdiRebreatherIntroCaveDiver",'
      '"tdiRebreatherFullCaveDiver"]',
    );
  });

  test('removes tdi from generic_refresher, leaving the other agencies and '
      'the old ambiguous levels untouched', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await applicableAgenciesOf(db, 'generic_refresher'),
      '["naui","sdi","raid","other"]',
    );
    expect(
      await applicableLevelsOf(db, 'generic_refresher'),
      '["openWater","nitrox","cave","rebreather","instructor"]',
    );
  });

  test(
    'never touches a non-built-in rule even if it names the old levels',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);

      final row = await db
          .customSelect(
            "SELECT applicable_levels FROM certification_currency_rules "
            "WHERE id = 'custom-1'",
          )
          .getSingle();
      expect(row.read<String>('applicable_levels'), '["cave"]');
    },
  );

  test('re-running the migration is a no-op (idempotent)', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    // Simulate a second pass over an already-migrated database.
    await db.customStatement(
      "UPDATE certifications SET level = 'tdiNitroxDiver' "
      "WHERE agency = 'tdi' AND level = 'nitrox'",
    );
    final before = await applicableLevelsOf(db, 'deco_currency');

    final levels = await levelsByCertId(db);
    expect(levels['tdi-nitrox'], 'tdiNitroxDiver');
    expect(await applicableLevelsOf(db, 'deco_currency'), before);
  });

  test('a fresh install never ran the rung, so there is nothing to rewrite '
      'and the new rule already carries the TDI levels', () async {
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    expect(
      await applicableLevelsOf(fresh, 'tdi_refresher'),
      contains('tdiNitroxDiver'),
    );
    // A fresh install's generic_refresher must match an upgraded-then-
    // migrated database's: no "tdi", since tdi_refresher is now TDI's own.
    expect(
      CurrencyScopeCodec.decodeStrings(
        await applicableAgenciesOf(fresh, 'generic_refresher'),
      ),
      isNot(contains('tdi')),
    );
  });
}
