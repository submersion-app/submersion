import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/change_log/change_log_rewrites.dart';
import 'package:submersion/core/database/database.dart';

/// v337: `dives.weather_fetched_at` is Unix seconds, but the bulk conditions
/// fill wrote milliseconds until this version (issue #4119), so the rung turns
/// those rows back into seconds. A stored value says which unit it is in. It
/// leaves the sync clocks alone, so an upgrade here cannot outrank a newer
/// change made on another device, and it writes nothing to the diver's change
/// log, because the diver changed nothing.
void main() {
  /// 2024-05-01T12:00:00Z.
  const inSeconds = 1714564800;
  const inMillis = inSeconds * 1000;

  late int seededEvents;

  Future<int> changeLogEvents(AppDatabase db) async =>
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
              .getSingle())
          .read<int>('n');

  /// A database file holding one dive per stored shape, stamped at
  /// [userVersion] and closed, ready to reopen. The change log triggers stay,
  /// as they are in a real library, so the upgrade has to get past them.
  Future<File> databaseAt(int userVersion) async {
    final dir = Directory.systemTemp.createTempSync('v337_weather_fetched_at');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'submersion.db'));

    final db = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    // Closed below before the reopen; this covers a failure on the way
    // there, so the temp directory is not left with an open handle.
    addTearDown(db.close);
    for (final (id, stamp) in [
      ('millis', inMillis),
      ('seconds', inSeconds),
      ('empty', null),
    ]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: 0,
              createdAt: 0,
              updatedAt: 22,
              weatherFetchedAt: Value(stamp),
              hlc: Value('hlc-$id'),
            ),
          );
    }
    seededEvents = await changeLogEvents(db);
    await db.customStatement('PRAGMA user_version = $userVersion');
    await db.close();
    return file;
  }

  AppDatabase reopen(File file) {
    final db = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    return db;
  }

  Future<Map<String, Object?>> dive(AppDatabase db, String id) async =>
      (await db
              .customSelect(
                'SELECT weather_fetched_at, updated_at, hlc FROM dives '
                "WHERE id = '$id'",
              )
              .getSingle())
          .data;

  test('v337 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(337));
    expect(AppDatabase.migrationVersions, contains(337));
  });

  test('a revert will not put back a stamp from before the rung', () {
    expect(changeLogRewrittenColumns['dives.weather_fetched_at'], 337);
  });

  test('a stamp stored in milliseconds becomes seconds', () async {
    final db = reopen(await databaseAt(336));

    expect((await dive(db, 'millis'))['weather_fetched_at'], inSeconds);
  });

  test('a stamp already in seconds and an empty one stay', () async {
    final db = reopen(await databaseAt(336));

    expect((await dive(db, 'seconds'))['weather_fetched_at'], inSeconds);
    expect((await dive(db, 'empty'))['weather_fetched_at'], isNull);
  });

  test('the rung leaves the sync clocks alone', () async {
    final db = reopen(await databaseAt(336));

    final row = await dive(db, 'millis');
    expect(row['updated_at'], 22);
    expect(row['hlc'], 'hlc-millis');
  });

  test('the rung adds nothing to the change log', () async {
    final db = reopen(await databaseAt(336));

    expect(seededEvents, greaterThan(0), reason: 'the triggers must be live');
    expect(await changeLogEvents(db), seededEvents);
  });
}
