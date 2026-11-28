import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/site_derived_dive_values.dart';

/// v395 (issue #5040): a dive reads its site's altitude and water type
/// rather than storing a copy, so the copies linking a site used to make are
/// cleared, leaving the dive to read the site's current value. Entry and
/// exit methods stay the dive's own, and an empty one is filled from a site
/// that lists exactly one, as linking the site does. The rung leaves the
/// sync clocks alone and writes nothing to the change log.
void main() {
  Future<void> insertSite(
    AppDatabase db,
    String id, {
    double? altitude,
    String? waterType,
    String? entryMethod,
    String? exitMethod,
  }) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: 'Site $id',
          altitude: Value(altitude),
          waterType: Value(waterType),
          entryMethod: Value(entryMethod),
          exitMethod: Value(exitMethod),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<void> insertDive(
    AppDatabase db,
    String id, {
    String? siteId,
    double? altitude,
    String? waterType,
    String? entryMethod,
    String? exitMethod,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: 0,
          createdAt: 0,
          updatedAt: 22,
          siteId: Value(siteId),
          altitude: Value(altitude),
          waterType: Value(waterType),
          entryMethod: Value(entryMethod),
          exitMethod: Value(exitMethod),
          hlc: Value('hlc-$id'),
        ),
      );

  Future<Map<String, Object?>> dive(AppDatabase db, String id) async =>
      (await db
              .customSelect(
                'SELECT altitude, water_type, entry_method, exit_method, '
                "updated_at, hlc FROM dives WHERE id = '$id'",
              )
              .getSingle())
          .data;

  group('clearSiteCopiedDiveValues', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
      addTearDown(db.close);
    });

    test("a copy of the site's altitude and water type is cleared", () async {
      await insertSite(db, 'lake', altitude: 450, waterType: 'fresh');
      await insertDive(
        db,
        'copied',
        siteId: 'lake',
        altitude: 450,
        waterType: 'fresh',
      );

      expect(await clearSiteCopiedDiveValues(db), 1);
      final row = await dive(db, 'copied');
      expect(row['altitude'], isNull);
      expect(row['water_type'], isNull);
    });

    test('a value of the dive\'s own is kept', () async {
      await insertSite(db, 'lake', altitude: 450, waterType: 'fresh');
      await insertDive(
        db,
        'own',
        siteId: 'lake',
        altitude: 1200,
        waterType: 'salt',
      );

      expect(await clearSiteCopiedDiveValues(db), 0);
      final row = await dive(db, 'own');
      expect(row['altitude'], 1200);
      expect(row['water_type'], 'salt');
    });

    test('each column is judged on its own', () async {
      await insertSite(db, 'lake', altitude: 450, waterType: 'fresh');
      await insertDive(
        db,
        'mixed',
        siteId: 'lake',
        altitude: 450,
        waterType: 'brackish',
      );

      await clearSiteCopiedDiveValues(db);

      final row = await dive(db, 'mixed');
      expect(row['altitude'], isNull);
      expect(row['water_type'], 'brackish');
    });

    test('a dive with no site keeps its values', () async {
      await insertDive(db, 'gps', altitude: 450, waterType: 'fresh');

      expect(await clearSiteCopiedDiveValues(db), 0);
      expect((await dive(db, 'gps'))['altitude'], 450);
    });

    test('a site with no value clears nothing', () async {
      await insertSite(db, 'bare');
      await insertDive(
        db,
        'own',
        siteId: 'bare',
        altitude: 450,
        waterType: 'fresh',
      );

      expect(await clearSiteCopiedDiveValues(db), 0);
    });

    test('a scoped run reads only the dives it names', () async {
      await insertSite(db, 'lake', altitude: 450);
      await insertDive(db, 'named', siteId: 'lake', altitude: 450);
      await insertDive(db, 'other', siteId: 'lake', altitude: 450);

      expect(await clearSiteCopiedDiveValues(db, diveIds: ['named']), 1);
      expect((await dive(db, 'named'))['altitude'], isNull);
      expect((await dive(db, 'other'))['altitude'], 450);
      expect(await clearSiteCopiedDiveValues(db, diveIds: const []), 0);
    });

    test('a scoped run larger than one chunk reaches every dive', () async {
      await insertSite(db, 'lake', altitude: 450);
      await insertDive(db, 'copied', siteId: 'lake', altitude: 450);
      final ids = [for (var i = 0; i < 1200; i++) 'absent-$i', 'copied'];

      expect(await clearSiteCopiedDiveValues(db, diveIds: ids), 1);
    });
  });

  group('fillDiveEntryExitFromSites', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
      addTearDown(db.close);
    });

    test("a site's single entry fills both, the exit following", () async {
      await insertSite(db, 'beach', entryMethod: 'shore');
      await insertDive(db, 'empty', siteId: 'beach');

      expect(await fillDiveEntryExitFromSites(db), 1);
      final row = await dive(db, 'empty');
      expect(row['entry_method'], 'shore');
      expect(row['exit_method'], 'shore');
    });

    test("a site's single exit fills the exit", () async {
      await insertSite(db, 'jetty', entryMethod: 'boat', exitMethod: 'ladder');
      await insertDive(db, 'empty', siteId: 'jetty');

      await fillDiveEntryExitFromSites(db);

      final row = await dive(db, 'empty');
      expect(row['entry_method'], 'boat');
      expect(row['exit_method'], 'ladder');
    });

    test('a site listing several entries fills no entry', () async {
      await insertSite(db, 'both', entryMethod: 'shore,boat');
      await insertDive(db, 'empty', siteId: 'both');

      expect(await fillDiveEntryExitFromSites(db), 0);
      final row = await dive(db, 'empty');
      expect(row['entry_method'], isNull);
      expect(row['exit_method'], isNull);
    });

    test('an exit does not follow an entry when the site lists several '
        'exits', () async {
      await insertSite(
        db,
        'pier',
        entryMethod: 'giantStride',
        exitMethod: 'ladder,shore',
      );
      await insertDive(db, 'empty', siteId: 'pier');

      await fillDiveEntryExitFromSites(db);

      final row = await dive(db, 'empty');
      expect(row['entry_method'], 'giantStride');
      expect(row['exit_method'], isNull);
    });

    test('a value the dive has is never replaced', () async {
      await insertSite(db, 'jetty', entryMethod: 'boat', exitMethod: 'ladder');
      await insertDive(
        db,
        'set',
        siteId: 'jetty',
        entryMethod: 'shore',
        exitMethod: 'shore',
      );

      expect(await fillDiveEntryExitFromSites(db), 0);
      final row = await dive(db, 'set');
      expect(row['entry_method'], 'shore');
      expect(row['exit_method'], 'shore');
    });

    test("an entry of the dive's own does not become its exit", () async {
      await insertSite(db, 'beach', entryMethod: 'shore');
      await insertDive(db, 'own', siteId: 'beach', entryMethod: 'boat');

      await fillDiveEntryExitFromSites(db);

      final row = await dive(db, 'own');
      expect(row['entry_method'], 'boat');
      expect(row['exit_method'], isNull);
    });

    test('a site method this version does not know fills nothing', () async {
      await insertSite(db, 'odd', entryMethod: 'jetpack');
      await insertDive(db, 'empty', siteId: 'odd');

      expect(await fillDiveEntryExitFromSites(db), 0);
    });

    test('a second run finds nothing to do', () async {
      await insertSite(db, 'beach', entryMethod: 'shore');
      await insertDive(db, 'empty', siteId: 'beach');

      await fillDiveEntryExitFromSites(db);
      expect(await fillDiveEntryExitFromSites(db), 0);
    });

    test('a scoped run reads only the dives it names', () async {
      await insertSite(db, 'beach', entryMethod: 'shore');
      await insertDive(db, 'named', siteId: 'beach');
      await insertDive(db, 'other', siteId: 'beach');

      expect(await fillDiveEntryExitFromSites(db, diveIds: ['named']), 1);
      expect((await dive(db, 'other'))['entry_method'], isNull);
    });
  });

  group('the v395 rung', () {
    Future<int> changeLogEvents(AppDatabase db) async =>
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM change_log_events')
                .getSingle())
            .read<int>('n');

    late int seededEvents;

    /// A database file holding a dive with a copy of its site's altitude
    /// and no entry method, stamped at [userVersion] and closed.
    Future<File> databaseAt(int userVersion) async {
      final dir = Directory.systemTemp.createTempSync('v395_site_values');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'submersion.db'));

      final db = AppDatabase(
        NativeDatabase(file, setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);
      await insertSite(
        db,
        'lake',
        altitude: 450,
        waterType: 'fresh',
        entryMethod: 'shore',
      );
      await insertDive(
        db,
        'linked',
        siteId: 'lake',
        altitude: 450,
        waterType: 'fresh',
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

    test('v395 is in the ladder and raises the floor', () {
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(395));
      expect(AppDatabase.migrationVersions, contains(395));
      // A peer below 395 reads no site altitude (see the floor's doc).
      expect(
        AppDatabase.minimumCompatibleSchemaVersion,
        greaterThanOrEqualTo(395),
      );
    });

    test('an upgrade clears the copies and fills the methods', () async {
      final db = reopen(await databaseAt(389));

      final row = await dive(db, 'linked');
      expect(row['altitude'], isNull);
      expect(row['water_type'], isNull);
      expect(row['entry_method'], 'shore');
      expect(row['exit_method'], 'shore');
    });

    test('the rung leaves the sync clocks alone', () async {
      final db = reopen(await databaseAt(389));

      final row = await dive(db, 'linked');
      expect(row['updated_at'], 22);
      expect(row['hlc'], 'hlc-linked');
    });

    test('the rung adds nothing to the change log', () async {
      final db = reopen(await databaseAt(389));

      expect(seededEvents, greaterThan(0), reason: 'the triggers must be live');
      expect(await changeLogEvents(db), seededEvents);
    });
  });
}
