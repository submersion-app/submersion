import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v346: an item's last service date is its newest service record's date,
/// but logging an older record wrote that older date until this version
/// (issue #4201), so the rung moves such items forward to their newest
/// record. It leaves the sync clocks alone, as every device makes the same
/// repair, and writes nothing to the diver's change log, because the diver
/// changed nothing.
void main() {
  // 2025-03-01, 2026-03-01 and 2026-06-01 at noon UTC, in milliseconds.
  const older = 1740830400000;
  const newer = 1772366400000;
  const newest = 1780315200000;

  late int seededEvents;

  Future<int> changeLogEvents(AppDatabase db) async =>
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
              .getSingle())
          .read<int>('n');

  /// A database file holding one item per case, stamped at [userVersion] and
  /// closed, ready to reopen. The change log triggers stay, as they are in a
  /// real library, so the upgrade has to get past them.
  Future<File> databaseAt(int userVersion) async {
    final dir = Directory.systemTemp.createTempSync('v346_last_service_date');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'submersion.db'));

    final db = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    // Closed below before the reopen; this covers a failure on the way
    // there, so the temp directory is not left with an open handle.
    addTearDown(db.close);
    for (final (id, stored, recordDays) in [
      // An older record logged after a newer one moved the date back.
      ('stale', older, [newer, older]),
      ('current', newer, [older, newer]),
      // Set by an import, later than any record: not this bug's doing.
      ('ahead', newest, [newer]),
      ('unset', null, [newer]),
      ('no-records', older, <int>[]),
    ]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 0,
              updatedAt: 22,
              lastServiceDate: Value(stored),
              hlc: Value('hlc-$id'),
            ),
          );
      for (final (i, day) in recordDays.indexed) {
        await db.customStatement(
          'INSERT INTO service_records '
          '(id, equipment_id, service_category, service_date, created_at, '
          'updated_at) VALUES (?, ?, ?, ?, 0, 0)',
          ['$id-$i', id, 'annual', day],
        );
      }
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

  Future<Map<String, Object?>> item(AppDatabase db, String id) async =>
      (await db
              .customSelect(
                'SELECT last_service_date, updated_at, hlc FROM equipment '
                "WHERE id = '$id'",
              )
              .getSingle())
          .data;

  test('v346 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(346));
    expect(AppDatabase.migrationVersions, contains(346));
  });

  test('a date older than the newest record moves forward to it', () async {
    final db = reopen(await databaseAt(342));

    expect((await item(db, 'stale'))['last_service_date'], newer);
  });

  test('an item with records but no date takes the newest', () async {
    final db = reopen(await databaseAt(342));

    expect((await item(db, 'unset'))['last_service_date'], newer);
  });

  test('a current date, a later one and one with no records stay', () async {
    final db = reopen(await databaseAt(342));

    expect((await item(db, 'current'))['last_service_date'], newer);
    expect((await item(db, 'ahead'))['last_service_date'], newest);
    expect((await item(db, 'no-records'))['last_service_date'], older);
  });

  test('the rung leaves the sync clocks alone', () async {
    final db = reopen(await databaseAt(342));

    final row = await item(db, 'stale');
    expect(row['updated_at'], 22);
    expect(row['hlc'], 'hlc-stale');
  });

  test('the rung adds nothing to the change log', () async {
    final db = reopen(await databaseAt(342));

    expect(seededEvents, greaterThan(0), reason: 'the triggers must be live');
    expect(await changeLogEvents(db), seededEvents);
  });
}
