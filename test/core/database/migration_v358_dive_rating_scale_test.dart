import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/change_log/change_log_rewrites.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_rating_repair.dart';

/// v358: a dive's rating is 1 to 5 stars, but a UDDF import stored the file's
/// 1 to 10 `<ratingvalue>` as it was, and 0 for an unrated dive, until this
/// version (issue #4415). The edit form saves neither, so the rung halves a
/// rating above 5 and clears one of 0 or below. It leaves the sync clocks
/// alone and writes nothing to the diver's change log, because the diver
/// changed nothing.
void main() {
  late int seededEvents;

  Future<int> changeLogEvents(AppDatabase db) async =>
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
              .getSingle())
          .read<int>('n');

  const seeded = <String, int?>{
    'six': 6,
    'seven': 7,
    'eight': 8,
    'ten': 10,
    'zero': 0,
    'negative': -1,
    'three': 3,
    'five': 5,
    'unrated': null,
  };

  Future<void> seed(AppDatabase db) async {
    for (final MapEntry(key: id, value: rating) in seeded.entries) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: 0,
              createdAt: 0,
              updatedAt: 22,
              rating: Value(rating),
              hlc: Value('hlc-$id'),
            ),
          );
    }
  }

  /// A database file holding one dive per stored rating, stamped at
  /// [userVersion] and closed, ready to reopen. The change log triggers stay,
  /// as they are in a real library, so the upgrade has to get past them.
  Future<File> databaseAt(int userVersion) async {
    final dir = Directory.systemTemp.createTempSync('v358_dive_rating');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'submersion.db'));

    final db = AppDatabase(
      NativeDatabase(file, setup: registerAppSqlFunctions),
    );
    // Closed below before the reopen; this covers a failure on the way
    // there, so the temp directory is not left with an open handle.
    addTearDown(db.close);
    await seed(db);
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
                'SELECT rating, updated_at, hlc FROM dives WHERE id = ?',
                variables: [Variable<String>(id)],
              )
              .getSingle())
          .data;

  Future<Map<String, int?>> ratings(AppDatabase db) async => {
    for (final id in seeded.keys) id: (await dive(db, id))['rating'] as int?,
  };

  const repaired = <String, int?>{
    'six': 3,
    'seven': 4,
    'eight': 4,
    'ten': 5,
    'zero': null,
    'negative': null,
    'three': 3,
    'five': 5,
    'unrated': null,
  };

  test('v358 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(358));
    expect(AppDatabase.migrationVersions, contains(358));
  });

  test('a revert will not put back a rating from before the rung', () {
    expect(changeLogRewrittenColumns['dives.rating'], 358);
  });

  test('a rating above 5 is halved and one of 0 or below is cleared', () async {
    final db = reopen(await databaseAt(357));

    expect(await ratings(db), repaired);
  });

  test('the rung leaves the sync clocks alone', () async {
    final db = reopen(await databaseAt(357));

    final row = await dive(db, 'six');
    expect(row['updated_at'], 22);
    expect(row['hlc'], 'hlc-six');
  });

  test('the rung adds nothing to the change log', () async {
    final db = reopen(await databaseAt(357));

    expect(seededEvents, greaterThan(0), reason: 'the triggers must be live');
    expect(await changeLogEvents(db), seededEvents);
  });

  test(
    'the repair a sync apply runs reports the dives it rewrote, once',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);
      await seed(db);

      expect(await repairOutOfScaleDiveRatings(db), 6);
      expect(await ratings(db), repaired);
      expect(await repairOutOfScaleDiveRatings(db), 0);
    },
  );
}
