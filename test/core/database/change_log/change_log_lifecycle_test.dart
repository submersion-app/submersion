import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';

import 'change_log_support.dart';

File _tempDatabase() {
  final dir = Directory.systemTemp.createTempSync('change_log_lifecycle');
  addTearDown(() => dir.deleteSync(recursive: true));
  return File(p.join(dir.path, 'submersion.db'));
}

AppDatabase _open(File file) {
  final db = AppDatabase(NativeDatabase(file, setup: registerAppSqlFunctions));
  addTearDown(db.close);
  return db;
}

int _expectedTriggers(AppDatabase db) {
  var count = 0;
  for (final spec in changeLogSpecsFor(db)) {
    count += buildChangeLogTriggers(
      spec,
      changeLogTables[spec.table]!,
      schemaVersion: AppDatabase.currentSchemaVersion,
    ).length;
  }
  return count;
}

Future<String?> _storedHash(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT trigger_hash FROM change_log_context')
      .getSingle();
  return row.data['trigger_hash'] as String?;
}

const _marker = '${kChangeLogTriggerPrefix}dives_u';

/// Swaps one trigger for a harmless one that a rewrite would replace.
Future<void> _replaceWithMarker(AppDatabase db) async {
  await db.customStatement('DROP TRIGGER "$_marker"');
  await db.customStatement(
    'CREATE TRIGGER "$_marker" AFTER UPDATE ON dives BEGIN '
    "SELECT 'marker'; END",
  );
}

Future<String> _triggerSql(AppDatabase db, String name) async {
  final row = await db
      .customSelect(
        'SELECT sql FROM sqlite_master WHERE name = ?',
        variables: [Variable.withString(name)],
      )
      .getSingle();
  return row.read<String>('sql');
}

void main() {
  test('open installs every generated trigger', () async {
    final db = _open(_tempDatabase());
    await db.customSelect('SELECT 1').get();

    expect(await installedTriggers(db), hasLength(_expectedTriggers(db)));
    expect(await _storedHash(db), isNotNull);
  });

  test('recursive triggers are on', () async {
    final db = _open(_tempDatabase());
    final row = await db.customSelect('PRAGMA recursive_triggers').getSingle();

    expect(row.data.values.single, 1);
  });

  test('opening twice does not rewrite triggers', () async {
    final file = _tempDatabase();
    final first = _open(file);
    final hash = await _storedHash(first);
    await _replaceWithMarker(first);
    await first.close();

    final second = _open(file);

    expect(await _triggerSql(second, _marker), contains('marker'));
    expect(await _storedHash(second), hash);
  });

  test('a stale hash rewrites triggers', () async {
    final file = _tempDatabase();
    final first = _open(file);
    final hash = await _storedHash(first);
    await _replaceWithMarker(first);
    await first.customStatement(
      "UPDATE change_log_context SET trigger_hash = 'old'",
    );
    await first.close();

    final second = _open(file);

    expect(await _storedHash(second), hash);
    expect(await _triggerSql(second, _marker), isNot(contains('marker')));
  });

  test('a missing trigger is put back', () async {
    final file = _tempDatabase();
    final first = _open(file);
    final before = await installedTriggers(first);
    await first.customStatement(
      'DROP TRIGGER "${kChangeLogTriggerPrefix}dives_u"',
    );
    await first.close();

    final second = _open(file);

    expect((await installedTriggers(second)).keys.toSet(), before.keys.toSet());
  });

  test('an open leaves the context row alone', () async {
    final file = _tempDatabase();
    final first = _open(file);
    final until = DateTime.now().millisecondsSinceEpoch + 60000;
    await first.customStatement(
      "UPDATE change_log_context SET operation_id = 'op', "
      'scope_expires_at = $until, suppressed_until = $until',
    );
    await first.close();

    final second = _open(file);
    final row = await second
        .customSelect('SELECT * FROM change_log_context')
        .getSingle();

    expect(row.data['operation_id'], 'op');
    expect(row.data['scope_expires_at'], until);
    expect(row.data['suppressed_until'], until);
  });

  test('a column the file lacks gets no trigger reference', () async {
    final file = _tempDatabase();
    final first = _open(file);
    await insertDiver(first, 'diver');
    await insertDive(first, 'dive', diverId: 'diver');
    await dropChangeLogTriggers(first);
    await first.customStatement(
      'ALTER TABLE dives DROP COLUMN surface_interval_seconds',
    );
    await first.close();

    final second = _open(file);

    // Drift cannot read this row now, but a raw write must still work.
    await second.customStatement(
      "UPDATE dives SET notes = 'Saved' WHERE id = 'dive'",
    );
    expect((await logEvents(second)).last['table_name'], 'dives');
  });

  test('an upgrade with old triggers can drop a column', () async {
    final file = _tempDatabase();
    final first = _open(file);
    await first.customStatement(
      'ALTER TABLE diver_settings ADD COLUMN ppo2_deco_band1 REAL',
    );
    await first.customStatement(
      'CREATE TRIGGER "${kChangeLogTriggerPrefix}stale" '
      'AFTER UPDATE ON diver_settings BEGIN '
      'UPDATE change_log_context SET suppressed_until = OLD.ppo2_deco_band1; '
      'END',
    );
    await first.customStatement('PRAGMA user_version = 326');
    await first.close();

    final second = _open(file);

    final columns = await second
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    expect(
      columns.map((c) => c.read<String>('name')),
      isNot(contains('ppo2_deco_band1')),
    );
    expect(
      await installedTriggers(second),
      isNot(contains('${kChangeLogTriggerPrefix}stale')),
    );
  });

  test('a failing trigger install does not stop open', () async {
    final file = _tempDatabase();
    final first = _open(file);
    await insertDiver(first, 'diver');
    await dropChangeLogTriggers(first);
    await first.customStatement('DROP TABLE change_log_context');
    await first.customStatement(
      'CREATE TABLE change_log_context (id INTEGER PRIMARY KEY)',
    );
    await first.close();

    final second = _open(file);

    await second.customStatement(
      "UPDATE divers SET name = 'Still saves' WHERE id = 'diver'",
    );
    expect(await installedTriggers(second), isEmpty);
  });
}
