import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

/// v247 adds dive_derived_metrics (issue #2195, Explore phase 2): what only a
/// profile decode can answer about a dive. Device-local: no hlc column, and
/// the sync floor stays at 240.

const _expectedColumns = {
  'dive_id',
  'engine_version',
  'source_updated_at',
  'computed_at',
  'final_stop_kind',
  'final_stop_state',
  'final_stop_start_s',
  'final_stop_duration_s',
  'final_stop_depth_stddev_m',
  'final_stop_max_excursion_m',
  'sac_mean_bar_min',
  'sac_slope_bar_min_per_min',
  'sac_trend',
  'sac_change_pct',
  'runtime_s',
  'unsupported_reason',
};

Future<Set<String>> _columns(AppDatabase db) async {
  final rows = await db
      .customSelect("PRAGMA table_info('dive_derived_metrics')")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

/// A full current schema written to a file, then the table dropped and the
/// stored version set to [storedVersion], as a database from an older build
/// or a restored copy has it. Reopened for the test.
Future<AppDatabase> _reopenWithout({required int storedVersion}) async {
  final dir = await Directory.systemTemp.createTemp('derived_metrics_rung');
  addTearDown(() => dir.delete(recursive: true));
  final file = File(p.join(dir.path, 'app.db'));
  final first = AppDatabase(NativeDatabase(file));
  await first.customStatement('DROP TABLE dive_derived_metrics');
  await first.customStatement('PRAGMA user_version = $storedVersion');
  await first.close();
  final reopened = AppDatabase(NativeDatabase(file));
  addTearDown(reopened.close);
  return reopened;
}

void main() {
  test('v247 is in the ladder', () {
    // Relaxed once v248 (trip_equipment) and v249 (the trip fill forecast) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(247));
    expect(AppDatabase.migrationVersions, contains(247));
    expect(AppDatabase.migrationStepCount(245), greaterThanOrEqualTo(1));
    // A device-local table: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has the table and no hlc column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final columns = await _columns(db);
    expect(columns, _expectedColumns);
    expect(columns, isNot(contains('hlc')));
  });

  test('a database from a v244 build gains the table', () async {
    final db = await _reopenWithout(storedVersion: 244);
    expect(await _columns(db), _expectedColumns);
  });

  test('a database already at the current version gains it', () async {
    // Only the beforeOpen backstop reaches it: the ladder has nothing to run.
    final db = await _reopenWithout(
      storedVersion: AppDatabase.currentSchemaVersion,
    );
    expect(await _columns(db), _expectedColumns);
  });

  test('deleting a dive deletes its metrics', () async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final now = DateTime(2026, 9, 28).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveDerivedMetricsRows)
        .insert(
          DiveDerivedMetricsRowsCompanion.insert(
            diveId: 'd1',
            engineVersion: 1,
            sourceUpdatedAt: now,
            computedAt: now,
          ),
        );
    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();
    expect(await db.select(db.diveDerivedMetricsRows).get(), isEmpty);
  });
}
