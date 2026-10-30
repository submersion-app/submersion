import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/performance_indexes.dart';

Future<Set<String>> indexNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('fresh database has every canonical performance index', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    // Force open so onCreate + beforeOpen run.
    await db.customSelect('SELECT 1').get();

    final names = await indexNames(db);
    for (final idx in kPerformanceIndexes) {
      expect(names, contains(idx.name), reason: '${idx.name} missing');
    }
  });

  test('ensurePerformanceIndexes is idempotent', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final created = await ensurePerformanceIndexes(db);
    expect(created, isEmpty);
  });

  test('ensurePerformanceIndexes heals a dropped index', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    await db.customStatement('DROP INDEX idx_dive_profile_series_dive_primary');
    expect(
      await indexNames(db),
      isNot(contains('idx_dive_profile_series_dive_primary')),
    );

    final created = await ensurePerformanceIndexes(db);
    expect(created, equals(['idx_dive_profile_series_dive_primary']));
    expect(
      await indexNames(db),
      contains('idx_dive_profile_series_dive_primary'),
    );
  });

  // Without this index every per-dive media read walks the whole library,
  // so a trip's cost was dives times library size (issue #3832).
  test('a dive finds its media through idx_media_dive_taken', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT * FROM media '
          "WHERE dive_id = 'd1' ORDER BY taken_at",
        )
        .get();
    final plan = rows.map((r) => r.read<String>('detail')).join('\n');

    expect(plan, contains('idx_media_dive_taken'));
    expect(plan, isNot(contains('TEMP B-TREE')));
  });
}
