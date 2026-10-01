import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../helpers/test_database.dart';

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

/// An existing library already at the current schema version: a
/// diver_settings table carrying the source columns at their calculated
/// column default, holding [stored] in every one of them. No rung runs on
/// open, so this isolates the beforeOpen backstops.
NativeDatabase _existingLibrary({required int stored}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute(
        'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
      );
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
  // The computer default for a new diver lives in AppSettings (#1859). The
  // columns keep DEFAULT 1 because sync fills a key missing from an older
  // peer's payload with the column default and writes it over the local row;
  // a 0 there would move existing libraries to computer.
  test('the source columns keep their calculated column default', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    for (final name in _sourceColumns) {
      final column = cols.firstWhere((c) => c.read<String>('name') == name);
      expect(
        column.read<String?>('dflt_value'),
        '1',
        reason: '$name must stay calculated so sync never fills computer',
      );
    }
  });

  group('a new diver', () {
    late AppDatabase db;

    setUp(() async {
      db = await setUpTestDatabase();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('is stored with the dive computer for every source', () async {
      await DiverSettingsRepository().createSettingsForDiver('d1');

      final row = await db
          .customSelect(
            'SELECT ${_sourceColumns.join(', ')} FROM diver_settings '
            "WHERE diver_id = 'd1'",
          )
          .getSingle();
      for (final name in _sourceColumns) {
        expect(
          MetricDataSource.fromInt(row.read<int>(name)),
          MetricDataSource.computer,
          reason: '$name should be written as computer',
        );
      }
    });
  });

  // The computer default is for new divers only (#1859). A 0/1 column cannot
  // tell a deliberate Calculated choice from an untouched default, so opening
  // an existing library must never rewrite what it stored. The v133 and v177
  // migration tests cover the same guarantee across the ladder.
  test('opening an existing library keeps stored calculated sources', () async {
    final db = AppDatabase(_existingLibrary(stored: 1));
    addTearDown(db.close);

    expect(await _storedSources(db), {for (final c in _sourceColumns) c: 1});
  });

  test('opening an existing library keeps stored computer sources', () async {
    final db = AppDatabase(_existingLibrary(stored: 0));
    addTearDown(db.close);

    expect(await _storedSources(db), {for (final c in _sourceColumns) c: 0});
  });
}
