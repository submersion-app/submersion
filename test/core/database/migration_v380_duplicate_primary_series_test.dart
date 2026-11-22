import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/duplicate_primary_series_repair.dart';

/// v380, issue #4847, second part: the v182 pack made one series per
/// `(computer_id, source_id, is_primary)` of a dive's legacy rows, so a
/// profile whose rows carried mixed computer ids came out as two live series
/// of one source over the same minutes, one of them labelled with a computer
/// the source does not name. The chart zips the two together. The repair
/// demotes the mislabelled one where the source's own computer is the other.
void main() {
  Future<void> insertComputer(AppDatabase db, String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion.insert(
          id: id,
          name: 'Computer $id',
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<void> insertDive(AppDatabase db, String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<void> insertSource(
    AppDatabase db,
    String id,
    String diveId, {
    String? computerId,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: diveId,
          isPrimary: const Value(true),
          computerId: Value(computerId),
          importedAt: DateTime.utc(2026, 11, 1),
          createdAt: DateTime.utc(2026, 11, 1),
        ),
      );

  Future<void> insertSeries(
    AppDatabase db,
    String id,
    String diveId, {
    required String? sourceId,
    required String? computerId,
    bool isPrimary = true,
    bool? isEdit,
    int start = 0,
    int end = 3000,
  }) => db
      .into(db.diveProfileSeries)
      .insert(
        DiveProfileSeriesCompanion.insert(
          id: id,
          diveId: diveId,
          computerId: Value(computerId),
          sourceId: Value(sourceId),
          isPrimary: Value(isPrimary),
          isEdit: Value(isEdit),
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

  Future<Map<String, bool>> primaryFlags(AppDatabase db, String diveId) async {
    final rows = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.diveId.equals(diveId))).get();
    return {for (final r in rows) r.id: r.isPrimary};
  }

  /// A dive whose download from `comp-a` holds two live series over the
  /// same minutes, one labelled `comp-a`, one `comp-b`.
  Future<void> seedPair(AppDatabase db, {String diveId = 'dive'}) async {
    await insertDive(db, diveId);
    await insertSource(db, '$diveId-src', diveId, computerId: 'comp-a');
    await insertSeries(
      db,
      '$diveId-own',
      diveId,
      sourceId: '$diveId-src',
      computerId: 'comp-a',
    );
    await insertSeries(
      db,
      '$diveId-stray',
      diveId,
      sourceId: '$diveId-src',
      computerId: 'comp-b',
      start: 4,
      end: 2996,
    );
  }

  group('demoteDuplicatePrimarySeries', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
      addTearDown(db.close);
      await insertComputer(db, 'comp-a');
      await insertComputer(db, 'comp-b');
    });

    test('demotes the series labelled with another computer and keeps the '
        "source's own", () async {
      await seedPair(db);

      expect(await demoteDuplicatePrimarySeries(db), 1);
      expect(await primaryFlags(db, 'dive'), {
        'dive-own': true,
        'dive-stray': false,
      });
    });

    test('leaves the computer label alone', () async {
      await seedPair(db);

      await demoteDuplicatePrimarySeries(db);

      final stray = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.id.equals('dive-stray'))).getSingle();
      expect(stray.computerId, 'comp-b');
    });

    test('a series over other minutes is a segment, not a duplicate', () async {
      await insertDive(db, 'dive');
      await insertSource(db, 'src', 'dive', computerId: 'comp-a');
      await insertSeries(
        db,
        'own',
        'dive',
        sourceId: 'src',
        computerId: 'comp-a',
      );
      await insertSeries(
        db,
        'later',
        'dive',
        sourceId: 'src',
        computerId: 'comp-b',
        start: 3600,
        end: 6000,
      );

      expect(await demoteDuplicatePrimarySeries(db), 0);
      expect(await primaryFlags(db, 'dive'), {'own': true, 'later': true});
    });

    test('two series that both match, or neither, are left alone', () async {
      await insertDive(db, 'both');
      await insertSource(db, 'both-src', 'both', computerId: 'comp-a');
      await insertSeries(
        db,
        'b1',
        'both',
        sourceId: 'both-src',
        computerId: 'comp-a',
      );
      await insertSeries(
        db,
        'b2',
        'both',
        sourceId: 'both-src',
        computerId: 'comp-a',
      );
      await insertDive(db, 'neither');
      await insertSource(db, 'neither-src', 'neither', computerId: 'comp-a');
      await insertSeries(
        db,
        'n1',
        'neither',
        sourceId: 'neither-src',
        computerId: 'comp-b',
      );
      await insertSeries(
        db,
        'n2',
        'neither',
        sourceId: 'neither-src',
        computerId: null,
      );

      expect(await demoteDuplicatePrimarySeries(db), 0);
      expect(await primaryFlags(db, 'both'), {'b1': true, 'b2': true});
      expect(await primaryFlags(db, 'neither'), {'n1': true, 'n2': true});
    });

    test('a dive whose source holds a marked edit is left alone', () async {
      await seedPair(db);
      await insertSeries(
        db,
        'dive-edit',
        'dive',
        sourceId: 'dive-src',
        computerId: null,
        isEdit: true,
        start: 3600,
        end: 4000,
      );

      expect(await demoteDuplicatePrimarySeries(db), 0);
    });

    test('a dive whose source holds an edit by shape is left alone', () async {
      // A live no-computer series over a demoted generation of its source.
      await insertDive(db, 'dive');
      await insertSource(db, 'src', 'dive');
      await insertSeries(db, 'edit', 'dive', sourceId: 'src', computerId: null);
      await insertSeries(
        db,
        'original',
        'dive',
        sourceId: 'src',
        computerId: null,
        isPrimary: false,
      );
      await insertSeries(
        db,
        'stray',
        'dive',
        sourceId: 'src',
        computerId: 'comp-b',
      );

      expect(await demoteDuplicatePrimarySeries(db), 0);
      expect((await primaryFlags(db, 'dive'))['stray'], isTrue);
    });

    test("a file source's own series is the one with no computer", () async {
      await insertDive(db, 'dive');
      await insertSource(db, 'file', 'dive');
      await insertSeries(db, 'own', 'dive', sourceId: 'file', computerId: null);
      await insertSeries(
        db,
        'stray',
        'dive',
        sourceId: 'file',
        computerId: 'comp-b',
      );

      expect(await demoteDuplicatePrimarySeries(db), 1);
      expect(await primaryFlags(db, 'dive'), {'own': true, 'stray': false});
    });

    test('series of different sources are never compared', () async {
      await insertDive(db, 'dive');
      await insertSource(db, 'src-a', 'dive', computerId: 'comp-a');
      await insertSource(db, 'src-b', 'dive', computerId: 'comp-b');
      await insertSeries(
        db,
        'a',
        'dive',
        sourceId: 'src-a',
        computerId: 'comp-a',
      );
      await insertSeries(
        db,
        'b',
        'dive',
        sourceId: 'src-b',
        computerId: 'comp-b',
      );

      expect(await demoteDuplicatePrimarySeries(db), 0);
    });

    test('a scoped run reads only the dives it names, in chunks', () async {
      await seedPair(db, diveId: 'named');
      await seedPair(db, diveId: 'other');
      final ids = [for (var i = 0; i < 1200; i++) 'absent-$i', 'named'];

      expect(await demoteDuplicatePrimarySeries(db, diveIds: ids), 1);
      expect((await primaryFlags(db, 'other'))['other-stray'], isTrue);
      expect(await demoteDuplicatePrimarySeries(db, diveIds: const []), 0);
    });

    test('a second run finds nothing to do', () async {
      await seedPair(db);

      await demoteDuplicatePrimarySeries(db);
      expect(await demoteDuplicatePrimarySeries(db), 0);
    });
  });

  group('the v380 rung', () {
    Future<int> changeLogEvents(AppDatabase db) async =>
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
                .getSingle())
            .read<int>('n');

    late int seededEvents;

    Future<File> databaseAt(int userVersion) async {
      final dir = Directory.systemTemp.createTempSync('v380_duplicate_series');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'submersion.db'));

      final db = AppDatabase(
        NativeDatabase(file, setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);
      await insertComputer(db, 'comp-a');
      await insertComputer(db, 'comp-b');
      await seedPair(db);
      await db.customStatement(
        "UPDATE dive_profile_series SET hlc = 'hlc-series'",
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

    test('an upgrade demotes the duplicate', () async {
      final db = reopen(await databaseAt(379));

      expect(await primaryFlags(db, 'dive'), {
        'dive-own': true,
        'dive-stray': false,
      });
    });

    test('the rung leaves the sync stamp and the change log alone', () async {
      final db = reopen(await databaseAt(379));

      final stray = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.id.equals('dive-stray'))).getSingle();
      expect(stray.hlc, 'hlc-series');
      expect(seededEvents, greaterThan(0), reason: 'the triggers must be live');
      expect(await changeLogEvents(db), seededEvents);
    });
  });
}
