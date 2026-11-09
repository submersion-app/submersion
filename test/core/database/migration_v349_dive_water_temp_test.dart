import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_water_temp_fill.dart';

/// v349: a download kept the water temperature it measured on its source row
/// only, leaving the dive's own column empty (issue #4333). The query field,
/// the dive table and the agent's documents read that column, so a downloaded
/// dive had no water temperature there. The rung fills an empty column from
/// the dive's source rows, leaves the sync clocks alone, and writes nothing to
/// the change log.
void main() {
  Future<void> insertDive(AppDatabase db, String id, {double? waterTemp}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 0,
          createdAt: 0,
          updatedAt: 22,
          waterTemp: Value(waterTemp),
          hlc: Value('hlc-$id'),
        ),
      );

  Future<void> insertSource(
    AppDatabase db,
    String id,
    String diveId, {
    double? waterTemp,
    bool isPrimary = true,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: diveId,
          isPrimary: Value(isPrimary),
          waterTemp: Value(waterTemp),
          importedAt: DateTime.utc(2026, 11, 1),
          createdAt: DateTime.utc(2026, 11, 1),
        ),
      );

  /// A dive as a download before the fix left it: empty, its source not.
  Future<void> seedDownloaded(AppDatabase db, String id) async {
    await insertDive(db, id);
    await insertSource(db, '$id-src', id, waterTemp: 21.5);
  }

  Future<Map<String, Object?>> dive(AppDatabase db, String id) async =>
      (await db
              .customSelect(
                'SELECT water_temp, updated_at, hlc FROM dives '
                "WHERE id = '$id'",
              )
              .getSingle())
          .data;

  group('fillDiveWaterTempsFromSources', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
      addTearDown(db.close);
    });

    test('an empty dive takes its source\'s temperature', () async {
      await seedDownloaded(db, 'downloaded');

      expect(await fillDiveWaterTempsFromSources(db), 1);
      expect((await dive(db, 'downloaded'))['water_temp'], 21.5);
    });

    test('a dive that holds a temperature keeps it', () async {
      await insertDive(db, 'entered', waterTemp: 19);
      await insertSource(db, 'entered-src', 'entered', waterTemp: 21.5);

      expect(await fillDiveWaterTempsFromSources(db), 0);
      expect((await dive(db, 'entered'))['water_temp'], 19);
    });

    test('the primary source wins over a colder secondary', () async {
      await insertDive(db, 'two');
      await insertSource(db, 'two-a', 'two', waterTemp: 22);
      await insertSource(db, 'two-b', 'two', waterTemp: 18, isPrimary: false);

      await fillDiveWaterTempsFromSources(db);

      expect((await dive(db, 'two'))['water_temp'], 22);
    });

    test('with no primary reading, the coldest source counts', () async {
      await insertDive(db, 'combined');
      await insertSource(
        db,
        'c-1',
        'combined',
        waterTemp: 16,
        isPrimary: false,
      );
      await insertSource(db, 'c-2', 'combined', waterTemp: 8, isPrimary: false);

      await fillDiveWaterTempsFromSources(db);

      expect((await dive(db, 'combined'))['water_temp'], 8);
    });

    test('a primary with no temperature falls back to the others', () async {
      await insertDive(db, 'sensorless');
      await insertSource(db, 's-a', 'sensorless');
      await insertSource(
        db,
        's-b',
        'sensorless',
        waterTemp: 17,
        isPrimary: false,
      );

      await fillDiveWaterTempsFromSources(db);

      expect((await dive(db, 'sensorless'))['water_temp'], 17);
    });

    test('a dive with no source temperature stays empty', () async {
      await insertDive(db, 'manual');
      await insertDive(db, 'blank');
      await insertSource(db, 'blank-src', 'blank');

      expect(await fillDiveWaterTempsFromSources(db), 0);
      expect((await dive(db, 'manual'))['water_temp'], isNull);
      expect((await dive(db, 'blank'))['water_temp'], isNull);
    });

    test('an implausible source value is not copied', () async {
      await insertDive(db, 'glitch');
      await insertSource(db, 'glitch-src', 'glitch', waterTemp: 255);

      expect(await fillDiveWaterTempsFromSources(db), 0);
      expect((await dive(db, 'glitch'))['water_temp'], isNull);
    });

    test('a scoped run reads only the dives it names', () async {
      await seedDownloaded(db, 'named');
      await seedDownloaded(db, 'other');

      expect(await fillDiveWaterTempsFromSources(db, diveIds: ['named']), 1);
      expect((await dive(db, 'named'))['water_temp'], 21.5);
      expect((await dive(db, 'other'))['water_temp'], isNull);
      expect(await fillDiveWaterTempsFromSources(db, diveIds: const []), 0);
    });

    test('a scoped run larger than one chunk reaches every dive', () async {
      await seedDownloaded(db, 'downloaded');
      final ids = [for (var i = 0; i < 1200; i++) 'absent-$i', 'downloaded'];

      expect(await fillDiveWaterTempsFromSources(db, diveIds: ids), 1);
      expect((await dive(db, 'downloaded'))['water_temp'], 21.5);
    });

    test('a second run finds nothing to do', () async {
      await seedDownloaded(db, 'downloaded');

      await fillDiveWaterTempsFromSources(db);
      expect(await fillDiveWaterTempsFromSources(db), 0);
    });
  });

  group('the v349 rung', () {
    Future<int> changeLogEvents(AppDatabase db) async =>
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
                .getSingle())
            .read<int>('n');

    late int seededEvents;

    /// A database file holding one downloaded dive, stamped at [userVersion]
    /// and closed, ready to reopen. The change log triggers stay, as they are
    /// in a real library, so the upgrade has to get past them.
    Future<File> databaseAt(int userVersion) async {
      final dir = Directory.systemTemp.createTempSync('v349_dive_water_temp');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'submersion.db'));

      final db = AppDatabase(
        NativeDatabase(file, setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);
      await seedDownloaded(db, 'downloaded');
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

    test('v349 is in the ladder', () {
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(349));
      expect(AppDatabase.migrationVersions, contains(349));
    });

    test('an upgrade fills a downloaded dive', () async {
      final db = reopen(await databaseAt(347));

      expect((await dive(db, 'downloaded'))['water_temp'], 21.5);
    });

    test('the rung leaves the sync clocks alone', () async {
      final db = reopen(await databaseAt(347));

      final row = await dive(db, 'downloaded');
      expect(row['updated_at'], 22);
      expect(row['hlc'], 'hlc-downloaded');
    });

    test('the rung adds nothing to the change log', () async {
      final db = reopen(await databaseAt(347));

      expect(seededEvents, greaterThan(0), reason: 'the triggers must be live');
      expect(await changeLogEvents(db), seededEvents);
    });
  });
}
