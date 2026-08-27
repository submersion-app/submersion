import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Force open so onCreate + beforeOpen run.
    await db.customSelect('SELECT 1').get();

    final names = await indexNames(db);
    for (final idx in kPerformanceIndexes) {
      expect(names, contains(idx.name), reason: '${idx.name} missing');
    }
  });

  test('ensurePerformanceIndexes is idempotent', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final created = await ensurePerformanceIndexes(db);
    expect(created, isEmpty);
  });

  test('ensurePerformanceIndexes heals a dropped index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    await db.customStatement('DROP INDEX idx_dive_profiles_dive_id');
    expect(await indexNames(db), isNot(contains('idx_dive_profiles_dive_id')));

    final created = await ensurePerformanceIndexes(db);
    expect(created, equals(['idx_dive_profiles_dive_id']));
    expect(await indexNames(db), contains('idx_dive_profiles_dive_id'));
  });
}
