import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/combine_source_slot_stamp.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/lone_download_source_repair.dart';
import 'package:submersion/features/dive_log/domain/services/source_ownership.dart';

/// v380, issue #4847: a dive whose only source is a download that is not
/// primary was stamped as a combined dive by v356, after which a re-parse
/// refused it for good. A Combine of a download with a hand-logged dive
/// carries one row too, so the row count cannot tell them apart; the dive's
/// runtime can, because a Combine is sequential and always widens the dive
/// beyond any one segment.
void main() {
  Future<void> insertDive(AppDatabase db, String id, {int? runtime}) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 0,
          runtime: Value(runtime),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<void> insertSource(
    AppDatabase db,
    String id,
    String diveId, {
    bool isPrimary = false,
    int? mergeSourceSlot,
    String? computerId,
    int? duration,
    DateTime? entryTime,
    DateTime? exitTime,
    int createdSecond = 0,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: diveId,
          isPrimary: Value(isPrimary),
          mergeSourceSlot: Value(mergeSourceSlot),
          computerId: Value(computerId),
          duration: Value(duration),
          entryTime: Value(entryTime),
          exitTime: Value(exitTime),
          rawData: Value(Uint8List.fromList([1, 2, 3])),
          importedAt: DateTime.utc(2026, 11, 1),
          createdAt: DateTime.utc(2026, 11, 1, 0, 0, createdSecond),
        ),
      );

  Future<List<DiveDataSourcesData>> rowsOf(AppDatabase db, String diveId) =>
      (db.select(db.diveDataSources)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// A series [sourceId] owns, from [start] to [end] seconds; with no
  /// source, one [computerId] owns by the pre-v154 convention.
  Future<void> insertSeries(
    AppDatabase db,
    String id,
    String diveId,
    String? sourceId, {
    String? computerId,
    bool isPrimary = true,
    required int start,
    required int end,
  }) => db
      .into(db.diveProfileSeries)
      .insert(
        DiveProfileSeriesCompanion.insert(
          id: id,
          diveId: diveId,
          sourceId: Value(sourceId),
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          sampleCount: 2,
          startTimestamp: start,
          endTimestamp: end,
          maxDepth: 30,
          firstDepth: 0,
          lastDepth: 0,
          codecVersion: 1,
          samples: Uint8List(0),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<DiveDataSourcesData> rowOf(AppDatabase db, String id) => (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(id))).getSingle();

  group('stampCombinedDiveSourceSlots and a lone download', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
      addTearDown(db.close);
    });

    test('a lone download whose dive spans only its own recording takes '
        'no slot', () async {
      await insertDive(db, 'lone', runtime: 3000);
      await insertSource(db, 'download', 'lone', duration: 3000);

      expect(await stampCombinedDiveSourceSlots(db), 0);
      expect((await rowOf(db, 'download')).mergeSourceSlot, isNull);
    });

    test('a download combined with a hand-logged dive still takes a slot: '
        'the dive spans more than the download', () async {
      // 50 minutes of download, a 10 minute surface gap and a 30 minute
      // hand-logged segment.
      await insertDive(db, 'combined', runtime: 5400);
      await insertSource(db, 'carried', 'combined', duration: 3000);

      expect(await stampCombinedDiveSourceSlots(db), 1);
      expect((await rowOf(db, 'carried')).mergeSourceSlot, 0);
    });

    test('a lone row whose samples sit later on the timeline is '
        'stamped', () async {
      await insertDive(db, 'shifted', runtime: 3000);
      await insertSource(db, 'carried', 'shifted', duration: 3000);
      await insertSeries(
        db,
        'series',
        'shifted',
        'carried',
        start: 2400,
        end: 5400,
      );

      expect(await stampCombinedDiveSourceSlots(db), 1);
    });

    test('a lone row it cannot measure is stamped as before', () async {
      await insertDive(db, 'no-runtime');
      await insertSource(db, 'a', 'no-runtime', duration: 3000);
      await insertDive(db, 'no-span', runtime: 3000);
      await insertSource(db, 'b', 'no-span');

      expect(await stampCombinedDiveSourceSlots(db), 2);
    });
  });

  group('repairLoneDownloadSources', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
      addTearDown(db.close);
    });

    test(
      'a slotted lone download becomes primary and re-parseable again',
      () async {
        await insertDive(db, 'lone', runtime: 3000);
        await insertSource(
          db,
          'download',
          'lone',
          mergeSourceSlot: 0,
          duration: 3000,
        );

        expect(await repairLoneDownloadSources(db), 1);

        final rows = await rowsOf(db, 'lone');
        expect(rows.single.isPrimary, isTrue);
        expect(rows.single.mergeSourceSlot, isNull);
        expect(sourceOwnsProfileStrand(rows.single, rows), isTrue);
      },
    );

    test('an unslotted lone download becomes primary too', () async {
      await insertDive(db, 'lone', runtime: 3000);
      await insertSource(db, 'download', 'lone', duration: 3000);

      expect(await repairLoneDownloadSources(db), 1);
      expect((await rowOf(db, 'download')).isPrimary, isTrue);
    });

    test('a runtime within a minute of the recording still fits', () async {
      await insertDive(db, 'lone', runtime: 3060);
      await insertSource(db, 'download', 'lone', duration: 3000);

      expect(await repairLoneDownloadSources(db), 1);
    });

    test('a runtime far shorter than the recording is left alone', () async {
      await insertDive(db, 'short', runtime: 600);
      await insertSource(
        db,
        'download',
        'short',
        mergeSourceSlot: 0,
        duration: 3000,
      );

      expect(await repairLoneDownloadSources(db), 0);
      expect((await rowOf(db, 'download')).isPrimary, isFalse);
    });

    test('the recording span falls back to its entry and exit times', () async {
      await insertDive(db, 'lone', runtime: 3000);
      await insertSource(
        db,
        'download',
        'lone',
        mergeSourceSlot: 0,
        entryTime: DateTime.utc(2026, 10, 1, 9),
        exitTime: DateTime.utc(2026, 10, 1, 9, 50),
      );

      expect(await repairLoneDownloadSources(db), 1);
      expect((await rowOf(db, 'download')).isPrimary, isTrue);
    });

    test(
      'a download combined with a hand-logged dive keeps its slot',
      () async {
        await insertDive(db, 'combined', runtime: 5400);
        await insertSource(
          db,
          'carried',
          'combined',
          mergeSourceSlot: 0,
          duration: 3000,
        );

        expect(await repairLoneDownloadSources(db), 0);
        final row = await rowOf(db, 'carried');
        expect(row.isPrimary, isFalse);
        expect(row.mergeSourceSlot, 0);
      },
    );

    test(
      'a download whose samples start on its own clock is repaired',
      () async {
        await insertDive(db, 'lone', runtime: 3000);
        await insertSource(
          db,
          'download',
          'lone',
          mergeSourceSlot: 0,
          duration: 3000,
        );
        await insertSeries(
          db,
          'series',
          'lone',
          'download',
          start: 10,
          end: 3000,
        );

        expect(await repairLoneDownloadSources(db), 1);
      },
    );

    test('a download whose samples sit later on the timeline keeps its '
        'slot', () async {
      // What an Uncombine leaves when a hand-logged stretch came first: the
      // kept download's runtime is its own span again, but its samples are
      // still shifted by the stretch and the gap.
      await insertDive(db, 'kept', runtime: 3000);
      await insertSource(
        db,
        'download',
        'kept',
        mergeSourceSlot: 0,
        duration: 3000,
      );
      await insertSeries(
        db,
        'series',
        'kept',
        'download',
        start: 2400,
        end: 5400,
      );

      expect(await repairLoneDownloadSources(db), 0);
      expect((await rowOf(db, 'download')).isPrimary, isFalse);
    });

    test(
      'a series that belongs to the row by its computer counts too',
      () async {
        // Written before v154, a series names its computer and no source; it
        // still belongs to the row of that computer.
        await db
            .into(db.diveComputers)
            .insert(
              DiveComputersCompanion.insert(
                id: 'comp-a',
                name: 'Computer A',
                createdAt: 0,
                updatedAt: 0,
              ),
            );
        await insertDive(db, 'kept', runtime: 3000);
        await insertSource(
          db,
          'download',
          'kept',
          mergeSourceSlot: 0,
          computerId: 'comp-a',
          duration: 3000,
        );
        await insertSeries(
          db,
          'legacy',
          'kept',
          null,
          computerId: 'comp-a',
          start: 2400,
          end: 5400,
        );
        // A hand-logged stretch's samples carry neither, and are not the row's.
        await insertSeries(db, 'hand', 'kept', null, start: 0, end: 1800);

        expect(await repairLoneDownloadSources(db), 0);
      },
    );

    test("a hand-logged stretch is never read as a file row's own", () async {
      await insertDive(db, 'lone', runtime: 3000);
      await insertSource(
        db,
        'file',
        'lone',
        mergeSourceSlot: 0,
        duration: 3000,
      );
      await insertSeries(db, 'own', 'lone', 'file', start: 2400, end: 5400);
      await insertSeries(db, 'hand', 'lone', null, start: 0, end: 1800);

      expect(await repairLoneDownloadSources(db), 0);
    });

    test('the live samples decide, not a demoted generation', () async {
      // History on its own clock beneath a live profile that is not.
      await insertDive(db, 'kept', runtime: 3000);
      await insertSource(
        db,
        'download',
        'kept',
        mergeSourceSlot: 0,
        duration: 3000,
      );
      await insertSeries(
        db,
        'old',
        'kept',
        'download',
        isPrimary: false,
        start: 0,
        end: 3000,
      );
      await insertSeries(
        db,
        'live',
        'kept',
        'download',
        start: 2400,
        end: 5400,
      );

      expect(await repairLoneDownloadSources(db), 0);
    });

    test('a lone download already made primary loses its slot', () async {
      // "Set as primary" sets the flag and leaves the slot, which still
      // refused the re-parse.
      await insertDive(db, 'lone', runtime: 3000);
      await insertSource(
        db,
        'download',
        'lone',
        isPrimary: true,
        mergeSourceSlot: 0,
        duration: 3000,
      );

      expect(await repairLoneDownloadSources(db), 1);

      final rows = await rowsOf(db, 'lone');
      expect(rows.single.isPrimary, isTrue);
      expect(rows.single.mergeSourceSlot, isNull);
      expect(sourceOwnsProfileStrand(rows.single, rows), isTrue);
    });

    test('a combined dive whose carried row was made primary keeps its '
        'slot', () async {
      await insertDive(db, 'combined', runtime: 5400);
      await insertSource(
        db,
        'carried',
        'combined',
        isPrimary: true,
        mergeSourceSlot: 0,
        duration: 3000,
      );

      expect(await repairLoneDownloadSources(db), 0);
      expect((await rowOf(db, 'carried')).mergeSourceSlot, 0);
    });

    test('a dive it cannot measure is left alone', () async {
      await insertDive(db, 'no-runtime');
      await insertSource(db, 'a', 'no-runtime', mergeSourceSlot: 0);
      await insertDive(db, 'no-span', runtime: 3000);
      await insertSource(db, 'b', 'no-span', mergeSourceSlot: 0);

      expect(await repairLoneDownloadSources(db), 0);
    });

    test('a dive with two sources or a primary one is left alone', () async {
      await insertDive(db, 'two', runtime: 3000);
      await insertSource(db, 'x', 'two', mergeSourceSlot: 0, duration: 3000);
      await insertSource(
        db,
        'y',
        'two',
        mergeSourceSlot: 1,
        duration: 3000,
        createdSecond: 1,
      );
      await insertDive(db, 'primary', runtime: 3000);
      await insertSource(db, 'p', 'primary', isPrimary: true, duration: 3000);

      expect(await repairLoneDownloadSources(db), 0);
      expect((await rowOf(db, 'x')).mergeSourceSlot, 0);
      expect((await rowOf(db, 'y')).mergeSourceSlot, 1);
    });

    test('a scoped run reads only the dives it names, in chunks', () async {
      await insertDive(db, 'named', runtime: 3000);
      await insertSource(db, 'named-src', 'named', duration: 3000);
      await insertDive(db, 'other', runtime: 3000);
      await insertSource(db, 'other-src', 'other', duration: 3000);
      final ids = [for (var i = 0; i < 1200; i++) 'absent-$i', 'named'];

      expect(await repairLoneDownloadSources(db, diveIds: ids), 1);
      expect((await rowOf(db, 'other-src')).isPrimary, isFalse);
      expect(await repairLoneDownloadSources(db, diveIds: const []), 0);
    });

    test('a second run finds nothing to do', () async {
      await insertDive(db, 'lone', runtime: 3000);
      await insertSource(db, 'download', 'lone', duration: 3000);

      await repairLoneDownloadSources(db);
      expect(await repairLoneDownloadSources(db), 0);
    });
  });

  group('the v380 rung', () {
    Future<int> changeLogEvents(AppDatabase db) async =>
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
                .getSingle())
            .read<int>('n');

    late int seededEvents;

    /// A database file holding one lone download stamped as combined, at
    /// [userVersion] and closed, ready to reopen.
    Future<File> databaseAt(int userVersion) async {
      final dir = Directory.systemTemp.createTempSync('v380_lone_download');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'submersion.db'));

      final db = AppDatabase(
        NativeDatabase(file, setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);
      await insertDive(db, 'lone', runtime: 3000);
      await insertSource(
        db,
        'download',
        'lone',
        mergeSourceSlot: 0,
        duration: 3000,
      );
      await db.customStatement(
        "UPDATE dive_data_sources SET hlc = 'hlc-download'",
      );
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

    test('v380 is in the ladder and keeps the floor', () {
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(380));
      expect(AppDatabase.migrationVersions, contains(380));
      expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(380));
    });

    test('an upgrade makes the lone download primary again', () async {
      final db = reopen(await databaseAt(379));

      final row = await rowOf(db, 'download');
      expect(row.isPrimary, isTrue);
      expect(row.mergeSourceSlot, isNull);
    });

    test('the rung leaves the sync stamp and the change log alone', () async {
      final db = reopen(await databaseAt(379));

      expect((await rowOf(db, 'download')).hlc, 'hlc-download');
      expect(seededEvents, greaterThan(0), reason: 'the triggers must be live');
      expect(await changeLogEvents(db), seededEvents);
    });
  });
}
