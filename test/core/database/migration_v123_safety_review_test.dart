import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-safety-review shape: a dives table (FK target for the safety
/// tables) and a diver_settings table with at least one column (so the ALTER
/// guard fires). Stamped at v114 so the full 114->123 upgrade path runs; the
/// intervening v120/v121/v122 blocks are all self-guarding on this partial
/// fixture.
NativeDatabase _dbAt114() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 114');
      rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY
        )
      ''');
      rawDb.execute(
        "INSERT INTO dives (id, created_at, updated_at) "
        "VALUES ('dive-1', 0, 0)",
      );
      rawDb.execute("INSERT INTO diver_settings (id) VALUES ('settings')");
    },
  );
}

void main() {
  test('v123 creates the safety review tables', () async {
    final db = AppDatabase(_dbAt114());
    addTearDown(() => db.close());

    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name IN ('dive_safety_reviews', 'dive_safety_findings')",
        )
        .get();
    expect(tables.map((r) => r.read<String>('name')).toSet(), {
      'dive_safety_reviews',
      'dive_safety_findings',
    });
  });

  test('v123 adds the safety review columns to diver_settings', () async {
    final db = AppDatabase(_dbAt114());
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(
      names,
      containsAll(['safety_review_enabled', 'safety_review_disabled_rules']),
    );
  });

  test('v123 tables accept round-trip rows through the Drift API', () async {
    final db = AppDatabase(_dbAt114());
    addTearDown(() => db.close());

    await db
        .into(db.diveSafetyReviews)
        .insert(
          DiveSafetyReviewsCompanion.insert(
            diveId: 'dive-1',
            engineVersion: 1,
            reviewedAt: 1000,
          ),
        );
    await db
        .into(db.diveSafetyFindings)
        .insert(
          DiveSafetyFindingsCompanion.insert(
            id: 'finding-1',
            diveId: 'dive-1',
            ruleId: 'rapidAscent',
            severity: 'significant',
            engineVersion: 1,
            createdAt: 1000,
            value: const Value(14.2),
          ),
        );

    final reviews = await db.select(db.diveSafetyReviews).get();
    final findings = await db.select(db.diveSafetyFindings).get();
    expect(reviews.single.diveId, 'dive-1');
    expect(findings.single.value, 14.2);
  });

  test('index on dive_safety_findings.dive_id exists', () async {
    final db = AppDatabase(_dbAt114());
    addTearDown(() => db.close());
    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_dive_safety_findings_dive_id'",
        )
        .get();
    expect(indexes, hasLength(1));
  });

  test('version ladder includes 123', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(123));
    expect(AppDatabase.migrationVersions, contains(123));
  });
}
