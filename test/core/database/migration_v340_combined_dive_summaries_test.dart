import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/combined_dive_summary_repair.dart';
import 'package:submersion/core/database/database.dart';

/// v340: a Combine copied the water temperature, the CNS at the end and the
/// OTU from its first segment (issue #4136). The rung recomputes them from
/// the segments' source rows: the coldest temperature, the last CNS, the sum
/// of the doses. It touches only a column still holding the first segment's
/// value, leaves the sync clocks alone, and writes nothing to the change log.
void main() {
  final firstEntry = DateTime.utc(2021, 8, 1, 11, 47);
  final firstExit = DateTime.utc(2021, 8, 1, 12, 5);
  final secondEntry = DateTime.utc(2021, 8, 1, 12, 15);
  final secondExit = DateTime.utc(2021, 8, 1, 13, 3);

  Future<void> insertDive(
    AppDatabase db,
    String id, {
    double? waterTemp,
    double? cnsEnd,
    double? otu,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 0,
          createdAt: 0,
          updatedAt: 22,
          waterTemp: Value(waterTemp),
          cnsEnd: Value(cnsEnd),
          otu: Value(otu),
          hlc: Value('hlc-$id'),
        ),
      );

  Future<void> insertSource(
    AppDatabase db,
    String id,
    String diveId, {
    required DateTime entry,
    required DateTime exit,
    double? waterTemp,
    double? cns,
    double? otu,
    bool isPrimary = false,
    int? mergeSourceSlot = 0,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: diveId,
          isPrimary: Value(isPrimary),
          mergeSourceSlot: Value(mergeSourceSlot),
          entryTime: Value(entry),
          exitTime: Value(exit),
          waterTemp: Value(waterTemp),
          cns: Value(cns),
          otu: Value(otu),
          importedAt: DateTime.utc(2021, 8, 2),
          createdAt: DateTime.utc(2021, 8, 2),
        ),
      );

  /// A dive combined from two segments, holding the first segment's values
  /// as a Combine before the fix wrote them.
  Future<void> seedCombined(
    AppDatabase db,
    String id, {
    double waterTemp = 16,
    double cnsEnd = 12,
    double otu = 30,
    bool overlapping = false,
    bool primary = false,
  }) async {
    await insertDive(db, id, waterTemp: waterTemp, cnsEnd: cnsEnd, otu: otu);
    await insertSource(
      db,
      '$id-1',
      id,
      entry: firstEntry,
      exit: overlapping ? secondExit : firstExit,
      waterTemp: 16,
      cns: 12,
      otu: 30,
      isPrimary: primary,
    );
    await insertSource(
      db,
      '$id-2',
      id,
      entry: secondEntry,
      exit: secondExit,
      waterTemp: 8,
      cns: 21,
      otu: 45,
    );
  }

  Future<Map<String, Object?>> dive(AppDatabase db, String id) async =>
      (await db
              .customSelect(
                'SELECT water_temp, cns_end, otu, updated_at, hlc FROM dives '
                "WHERE id = '$id'",
              )
              .getSingle())
          .data;

  group('repairCombinedDiveSummaries', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
      addTearDown(db.close);
    });

    test('a combined dive takes the whole dive\'s values', () async {
      await seedCombined(db, 'combined');

      expect(await repairCombinedDiveSummaries(db), 1);
      final row = await dive(db, 'combined');
      expect(row['water_temp'], 8);
      expect(row['cns_end'], 21);
      expect(row['otu'], 75);
    });

    test('a value the diver changed stays', () async {
      await seedCombined(db, 'edited', waterTemp: 10, cnsEnd: 25, otu: 80);

      expect(await repairCombinedDiveSummaries(db), 0);
      final row = await dive(db, 'edited');
      expect(row['water_temp'], 10);
      expect(row['cns_end'], 25);
      expect(row['otu'], 80);
    });

    test('a second run finds nothing to do', () async {
      await seedCombined(db, 'combined');

      await repairCombinedDiveSummaries(db);
      expect(await repairCombinedDiveSummaries(db), 0);
      expect((await dive(db, 'combined'))['otu'], 75);
    });

    test('two computers over the same minutes are not a Combine', () async {
      await seedCombined(db, 'overlap', overlapping: true);

      expect(await repairCombinedDiveSummaries(db), 0);
      expect((await dive(db, 'overlap'))['otu'], 30);
    });

    test('a dive with a primary source is not a Combine', () async {
      await seedCombined(db, 'primary', primary: true);

      expect(await repairCombinedDiveSummaries(db), 0);
      expect((await dive(db, 'primary'))['water_temp'], 16);
    });

    test('a single-source dive is left alone', () async {
      await insertDive(db, 'single', waterTemp: 16, otu: 30);
      await insertSource(
        db,
        'single-1',
        'single',
        entry: firstEntry,
        exit: firstExit,
        waterTemp: 16,
        otu: 30,
      );

      expect(await repairCombinedDiveSummaries(db), 0);
    });

    test('a column no segment reports keeps its value', () async {
      await insertDive(db, 'partial', waterTemp: 16, otu: 30);
      await insertSource(
        db,
        'partial-1',
        'partial',
        entry: firstEntry,
        exit: firstExit,
        waterTemp: 16,
        otu: 30,
      );
      await insertSource(
        db,
        'partial-2',
        'partial',
        entry: secondEntry,
        exit: secondExit,
        waterTemp: 8,
      );

      expect(await repairCombinedDiveSummaries(db), 1);
      final row = await dive(db, 'partial');
      expect(row['water_temp'], 8);
      expect(row['otu'], 30, reason: 'one dose is not a sum to rewrite');
      expect(row['cns_end'], isNull);
    });
  });

  group('the v340 rung', () {
    Future<int> changeLogEvents(AppDatabase db) async =>
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
                .getSingle())
            .read<int>('n');

    late int seededEvents;

    /// A database file holding one combined dive, stamped at [userVersion]
    /// and closed, ready to reopen. The change log triggers stay, as they are
    /// in a real library, so the upgrade has to get past them.
    Future<File> databaseAt(int userVersion) async {
      final dir = Directory.systemTemp.createTempSync('v340_combined_dive');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'submersion.db'));

      final db = AppDatabase(
        NativeDatabase(file, setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);
      await seedCombined(db, 'combined');
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

    test('v340 is in the ladder', () {
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(340));
      expect(AppDatabase.migrationVersions, contains(340));
    });

    test('an upgrade repairs a combined dive', () async {
      final db = reopen(await databaseAt(339));

      final row = await dive(db, 'combined');
      expect(row['water_temp'], 8);
      expect(row['cns_end'], 21);
      expect(row['otu'], 75);
    });

    test('the rung leaves the sync clocks alone', () async {
      final db = reopen(await databaseAt(339));

      final row = await dive(db, 'combined');
      expect(row['updated_at'], 22);
      expect(row['hlc'], 'hlc-combined');
    });

    test('the rung adds nothing to the change log', () async {
      final db = reopen(await databaseAt(339));

      expect(seededEvents, greaterThan(0), reason: 'the triggers must be live');
      expect(await changeLogEvents(db), seededEvents);
    });
  });
}
