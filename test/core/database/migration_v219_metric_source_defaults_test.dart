import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// The six per-metric data-source columns on diver_settings. A
/// MetricDataSource index: 0 = computer, 1 = calculated.
const _sourceColumns = [
  'default_ndl_source',
  'default_ceiling_source',
  'default_deco_stop_source',
  'default_tts_source',
  'default_cns_source',
  'default_gtr_source',
];

/// Minimal pre-v219 shape: a diver_settings table carrying the source
/// columns at their old calculated default, stamped at v218 so only the
/// v219 rung runs.
NativeDatabase _dbAt218({int stored = 1}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 218');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          ${_sourceColumns.map((c) => '$c INTEGER NOT NULL DEFAULT 1').join(',\n          ')}
        )
      ''');
      rawDb.execute(
        'INSERT INTO diver_settings (id, ${_sourceColumns.join(', ')}) '
        "VALUES ('settings', ${List.filled(_sourceColumns.length, stored).join(', ')})",
      );
    },
  );
}

Future<Map<String, int>> _storedSources(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT ${_sourceColumns.join(', ')} FROM diver_settings')
      .getSingle();
  return {for (final c in _sourceColumns) c: row.read<int>(c)};
}

void main() {
  test('v219 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 219);
    expect(AppDatabase.migrationVersions, contains(219));
  });

  test('a fresh database defaults every source column to computer', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    for (final name in _sourceColumns) {
      final column = cols.firstWhere((c) => c.read<String>('name') == name);
      expect(
        column.read<String?>('dflt_value'),
        '0',
        reason: '$name should default to computer',
      );
    }
  });

  test('stored calculated sources survive the upgrade to v219', () async {
    final db = AppDatabase(_dbAt218());
    addTearDown(db.close);

    expect(await _storedSources(db), {for (final c in _sourceColumns) c: 1});
  });

  test('rows already on computer are left alone', () async {
    final db = AppDatabase(_dbAt218(stored: 0));
    addTearDown(db.close);

    expect(await _storedSources(db), {for (final c in _sourceColumns) c: 0});
  });

  test('a database at v218 without diver_settings still opens', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 218');
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
