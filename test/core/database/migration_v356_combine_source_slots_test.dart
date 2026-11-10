import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/combine_source_slot_stamp.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/services/data_source_strand.dart';
import 'package:submersion/features/dive_log/domain/services/source_ownership.dart';

/// v356: a dive combined before v184 whose rows the v184 backfill could not
/// classify carries no merge slot (issue #4367). While it has no primary row
/// a re-parse refuses it for that alone, but consolidating it with another
/// import gives it one, and the re-parse then put its samples back at the
/// download's own timestamps. The rung stamps a slot on every row of a dive
/// that has no primary row and no slot yet, one per display strand, so the
/// chips the dive shows do not change.
void main() {
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

  Future<void> insertSource(
    AppDatabase db,
    String id,
    String diveId, {
    bool isPrimary = false,
    String? computerId,
    int? mergeSourceSlot,
    String? computerModel,
    DateTime? entryTime,
    int? duration,
    double? maxDepth,
    int createdSecond = 0,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion.insert(
          id: id,
          diveId: diveId,
          isPrimary: Value(isPrimary),
          computerId: Value(computerId),
          mergeSourceSlot: Value(mergeSourceSlot),
          computerModel: Value(computerModel),
          entryTime: Value(entryTime),
          duration: Value(duration),
          maxDepth: Value(maxDepth),
          rawData: Value(Uint8List.fromList([1, 2, 3])),
          importedAt: DateTime.utc(2026, 11, 1),
          createdAt: DateTime.utc(2026, 11, 1, 0, 0, createdSecond),
        ),
      );

  Future<List<DiveDataSourcesData>> rowsOf(AppDatabase db, String diveId) =>
      (db.select(db.diveDataSources)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPrimary),
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  Future<Map<String, int?>> slots(AppDatabase db, String diveId) async => {
    for (final r in await rowsOf(db, diveId)) r.id: r.mergeSourceSlot,
  };

  /// The chips a dive shows: its rows grouped by display strand.
  Future<Set<Set<String>>> chips(AppDatabase db, String diveId) async {
    final keys = dataSourceStrandKeysById(await rowsOf(db, diveId));
    final byKey = <String, Set<String>>{};
    keys.forEach((id, key) => (byKey[key] ??= {}).add(id));
    return {for (final ids in byKey.values) ids};
  }

  group('stampCombinedDiveSourceSlots', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
      addTearDown(db.close);
    });

    test('a combined dive with one carried row takes a slot, which keeps '
        'a re-parse off it once it has a primary row', () async {
      // A download combined with a hand-logged dive carries one row, so the
      // v184 backfill, which wanted two, skipped it.
      await insertDive(db, 'combined');
      await insertSource(db, 'carried', 'combined');

      expect(await stampCombinedDiveSourceSlots(db), 1);
      expect(await slots(db, 'combined'), {'carried': 0});

      // What a consolidation does to it: a primary row of its own.
      await insertSource(db, 'backfilled', 'combined', isPrimary: true);
      final rows = await rowsOf(db, 'combined');
      final carried = rows.firstWhere((r) => r.id == 'carried');
      expect(sourceOwnsProfileStrand(carried, rows), isFalse);
    });

    test('rows of one computer share a slot, another computer takes the '
        'next', () async {
      await insertComputer(db, 'comp-a');
      await insertComputer(db, 'comp-b');
      await insertDive(db, 'combined');
      await insertSource(db, 'a1', 'combined', computerId: 'comp-a');
      await insertSource(
        db,
        'a2',
        'combined',
        computerId: 'comp-a',
        createdSecond: 1,
      );
      await insertSource(
        db,
        'b1',
        'combined',
        computerId: 'comp-b',
        createdSecond: 2,
      );

      await stampCombinedDiveSourceSlots(db);

      expect(await slots(db, 'combined'), {'a1': 0, 'a2': 0, 'b1': 1});
    });

    test('rows with no computer keep the chips they showed', () async {
      // Two imports of one recording collapse into one chip (issue #3654);
      // a third row is a recording of its own.
      final start = DateTime.utc(2026, 10, 1, 9);
      await insertDive(db, 'combined');
      await insertSource(
        db,
        'perdix-1',
        'combined',
        computerModel: 'Shearwater Perdix 2',
        entryTime: start,
        duration: 3000,
        maxDepth: 30,
      );
      await insertSource(
        db,
        'perdix-2',
        'combined',
        computerModel: 'Perdix 2',
        entryTime: start,
        duration: 3000,
        maxDepth: 30,
        createdSecond: 1,
      );
      await insertSource(db, 'other', 'combined', createdSecond: 2);
      final before = await chips(db, 'combined');
      expect(before, hasLength(2));

      await stampCombinedDiveSourceSlots(db);

      expect(await chips(db, 'combined'), before);
      final after = await slots(db, 'combined');
      expect(after.values, everyElement(isNotNull));
      expect(after['perdix-1'], after['perdix-2']);
      expect(after['other'], isNot(after['perdix-1']));
    });

    test('a dive with a primary row is left alone', () async {
      await insertDive(db, 'imported');
      await insertSource(db, 'primary', 'imported', isPrimary: true);
      await insertSource(db, 'second', 'imported', createdSecond: 1);

      expect(await stampCombinedDiveSourceSlots(db), 0);
      expect(await slots(db, 'imported'), {'primary': null, 'second': null});
    });

    test('a dive that already carries a slot is left alone', () async {
      await insertDive(db, 'combined');
      await insertSource(db, 'slotted', 'combined', mergeSourceSlot: 0);
      await insertSource(db, 'loose', 'combined', createdSecond: 1);

      expect(await stampCombinedDiveSourceSlots(db), 0);
      expect(await slots(db, 'combined'), {'slotted': 0, 'loose': null});
    });

    test('a scoped run reads only the dives it names', () async {
      await insertDive(db, 'named');
      await insertSource(db, 'named-src', 'named');
      await insertDive(db, 'other');
      await insertSource(db, 'other-src', 'other');

      expect(await stampCombinedDiveSourceSlots(db, diveIds: ['named']), 1);
      expect(await slots(db, 'named'), {'named-src': 0});
      expect(await slots(db, 'other'), {'other-src': null});
      expect(await stampCombinedDiveSourceSlots(db, diveIds: const []), 0);
    });

    test('a scoped run larger than one chunk reaches every dive', () async {
      await insertDive(db, 'combined');
      await insertSource(db, 'carried', 'combined');
      final ids = [for (var i = 0; i < 1200; i++) 'absent-$i', 'combined'];

      expect(await stampCombinedDiveSourceSlots(db, diveIds: ids), 1);
    });

    test('a second run finds nothing to do', () async {
      await insertDive(db, 'combined');
      await insertSource(db, 'carried', 'combined');

      await stampCombinedDiveSourceSlots(db);
      expect(await stampCombinedDiveSourceSlots(db), 0);
    });
  });

  group('the v356 rung', () {
    Future<int> changeLogEvents(AppDatabase db) async =>
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
                .getSingle())
            .read<int>('n');

    late int seededEvents;

    /// A database file holding one combined dive with no slot, stamped at
    /// [userVersion] and closed, ready to reopen. The change log triggers
    /// stay, as they are in a real library.
    Future<File> databaseAt(int userVersion) async {
      final dir = Directory.systemTemp.createTempSync('v356_combine_slots');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'submersion.db'));

      final db = AppDatabase(
        NativeDatabase(file, setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);
      await insertDive(db, 'combined');
      await insertSource(db, 'carried', 'combined');
      await db.customStatement(
        "UPDATE dive_data_sources SET hlc = 'hlc-carried'",
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

    test('v356 is in the ladder', () {
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(356));
      expect(AppDatabase.migrationVersions, contains(356));
    });

    test('an upgrade stamps the combined dive', () async {
      final db = reopen(await databaseAt(355));

      expect(await slots(db, 'combined'), {'carried': 0});
    });

    test('the rung leaves the sync stamp alone', () async {
      final db = reopen(await databaseAt(355));

      final rows = await rowsOf(db, 'combined');
      expect(rows.single.hlc, 'hlc-carried');
    });

    test('the rung adds nothing to the change log', () async {
      final db = reopen(await databaseAt(355));

      expect(seededEvents, greaterThan(0), reason: 'the triggers must be live');
      expect(await changeLogEvents(db), seededEvents);
    });
  });
}
