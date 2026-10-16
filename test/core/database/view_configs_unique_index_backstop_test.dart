import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Issue #3343: only a database that upgraded through v62 got the unique
/// index on view_configs(diver_id, view_mode); a fresh install never did, so
/// it could hold two rows for one view, and syncing such a row to an upgraded
/// device failed on that index. The beforeOpen backstop collapses each
/// duplicate group onto its lowest id, carrying the newest config, then
/// creates the index.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('subm_view_configs_index');
    path = p.join(dir.path, 'test.db');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  AppDatabase open() =>
      AppDatabase(NativeDatabase(File(path), setup: registerAppSqlFunctions));

  Future<List<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'view_configs'",
        )
        .get();
    return [for (final r in rows) r.read<String>('name')];
  }

  test('a fresh database gets the unique index', () async {
    final db = open();
    addTearDown(db.close);

    expect(await indexNames(db), contains('idx_view_configs_unique'));
  });

  test('reopening collapses duplicates onto the lowest id with the newest '
      'config, then indexes', () async {
    // Create the schema, then strip the index the way a fresh install of an
    // earlier version lacked it, and seed the duplicates sync could leave.
    final first = open();
    await first.customSelect('SELECT 1').get();
    await first.close();

    final raw = sqlite3.open(path);
    raw.execute('DROP INDEX IF EXISTS idx_view_configs_unique');
    raw.execute(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Diver', 1, 1)",
    );
    raw.execute(
      'INSERT INTO view_configs (id, diver_id, view_mode, config_json, '
      "updated_at, hlc) VALUES "
      "('b-newest', 'd1', 'table', '{\"v\":\"newest\"}', 3000, 'hlc-3'), "
      "('a-oldest', 'd1', 'table', '{\"v\":\"oldest\"}', 1000, 'hlc-1'), "
      "('c-middle', 'd1', 'table', '{\"v\":\"middle\"}', 2000, 'hlc-2'), "
      "('z-alone', 'd1', 'card', '{\"v\":\"card\"}', 500, NULL)",
    );
    raw.close();

    final db = open();
    addTearDown(db.close);

    final rows = await (db.select(
      db.viewConfigs,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    expect(
      [for (final r in rows) '${r.id}|${r.configJson}|${r.updatedAt}|${r.hlc}'],
      ['a-oldest|{"v":"newest"}|3000|hlc-3', 'z-alone|{"v":"card"}|500|null'],
    );
    expect(await indexNames(db), contains('idx_view_configs_unique'));
  });
}
