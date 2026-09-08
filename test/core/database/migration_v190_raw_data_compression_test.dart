import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/raw_dive_data_codec.dart';

/// v190 (issue #227): recompress `dive_data_sources.raw_data` in place.
///
/// No DDL. The column's SQL type does not change; only the stored bytes move,
/// and the self-describing header means a row the rung skips keeps reading
/// correctly forever. That is what lets the rung be guarded per row: a blob
/// left uncompressed costs space and nothing else, and nothing about one bad
/// row justifies refusing to open the database that holds the diver's log.
///
/// Numbered 190 because main took 188 (insurer phone numbers) and 189 (media
/// equipment link) while this branch was open.
void main() {
  Uint8List teric() => Uint8List.fromList(
    File(
      'packages/libdivecomputer_plugin/android/src/androidTest/assets/'
      'shearwater_teric_dive.bin',
    ).readAsBytesSync(),
  );

  // Stamped at 189 so ONLY the v190 step runs, isolating what is asserted.
  NativeDatabase setupDb(void Function(dynamic rawDb) seed) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 189');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            raw_data BLOB,
            raw_fingerprint BLOB
          )
        ''');
        rawDb.execute("INSERT INTO dives (id) VALUES ('d1')");
        seed(rawDb);
      },
    );
  }

  void insertSource(dynamic rawDb, String id, Uint8List? raw) {
    rawDb.execute(
      'INSERT INTO dive_data_sources '
      '(id, dive_id, is_primary, imported_at, created_at, raw_data) '
      'VALUES (?, ?, 0, 0, 0, ?)',
      [id, 'd1', raw],
    );
  }

  Future<Uint8List?> storedBytes(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          'SELECT raw_data FROM dive_data_sources WHERE id = ?',
          variables: [Variable(id)],
        )
        .getSingle();
    return row.readNullable<Uint8List>('raw_data');
  }

  test('v190 is the current schema version and is in the ladder', () {
    // The latest-version tripwire lives in the newest migration's test.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(190));
    expect(AppDatabase.migrationVersions, contains(190));
  });

  test('compresses existing rows without changing what they mean', () async {
    final raw = teric();
    final db = AppDatabase(setupDb((rawDb) => insertSource(rawDb, 's1', raw)));
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    final stored = (await storedBytes(db, 's1'))!;
    expect(isCompressedRawDiveData(stored), isTrue);
    expect(stored.length, lessThan(raw.length));
    // Decoded by hand rather than through `db.select(db.diveDataSources)`:
    // the fixture table above carries only the columns this rung reads, so a
    // Drift select over the full table would fail on the absent ones. The
    // converter test already proves the column is wired to this codec.
    expect(decodeRawDiveData(stored), equals(raw));
    expect(db.recompressedRawBlobs, isTrue);
    expect(db.hasUnreclaimedPages, isTrue);
  });

  test('leaves a row alone when compression would not help', () async {
    final incompressible = Uint8List.fromList(
      List<int>.generate(24, (i) => (i * 31 + 7) & 0xFF),
    );
    final db = AppDatabase(
      setupDb((rawDb) => insertSource(rawDb, 's2', incompressible)),
    );
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    expect(await storedBytes(db, 's2'), equals(incompressible));
    expect(db.recompressedRawBlobs, isFalse);
  });

  test('a database with no raw data does not claim a reclaim', () async {
    final db = AppDatabase(setupDb((rawDb) => insertSource(rawDb, 's3', null)));
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    expect(db.recompressedRawBlobs, isFalse);
    expect(db.hasUnreclaimedPages, isFalse);
  });

  test('is idempotent: a second run re-packs nothing', () async {
    final raw = teric();
    final db = AppDatabase(setupDb((rawDb) => insertSource(rawDb, 's4', raw)));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    final afterFirst = await storedBytes(db, 's4');

    await db.recompressRawDiveDataForTest();

    expect(await storedBytes(db, 's4'), equals(afterFirst));
  });

  test('a row the encoder cannot pack leaves the database openable', () async {
    // The v182 profile-series rung had an unguarded pack step that could
    // leave a database that would not open. This rung must not repeat it, so
    // an oversized blob (which the encoder declines) has to be a no-op for
    // that row and a non-event for every other one.
    final raw = teric();
    final oversized = Uint8List(kMaxRawDiveBlobBytes + 1);
    final db = AppDatabase(
      setupDb((rawDb) {
        insertSource(rawDb, 's5', oversized);
        insertSource(rawDb, 's6', raw);
      }),
    );
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    expect(await storedBytes(db, 's5'), equals(oversized));
    expect(isCompressedRawDiveData((await storedBytes(db, 's6'))!), isTrue);
  });

  test('names recompression as the reason the pages need reclaiming', () async {
    // The VACUUM warning interpolates this. The message it replaced still
    // said "the dropped sample pages" after the gate widened to cover this
    // rung, so a failed reclaim would have blamed a step that never ran.
    final raw = teric();
    final db = AppDatabase(setupDb((rawDb) => insertSource(rawDb, 's7', raw)));
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    expect(db.unreclaimedPagesReason, 'raw dive data was recompressed');
  });

  test('says so plainly when nothing earned a reclaim', () async {
    final db = AppDatabase(setupDb((rawDb) => insertSource(rawDb, 's8', null)));
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    expect(
      db.unreclaimedPagesReason,
      'no reclaiming step reported on this connection',
    );
  });

  test('packs every row of a corpus larger than one page', () async {
    // The rung pages through the table with a keyset cursor. A single-row
    // fixture would never exercise the cursor, and an off-by-one there would
    // silently leave most of a real library uncompressed.
    final raw = teric();
    final db = AppDatabase(
      setupDb((rawDb) {
        for (var i = 0; i < 250; i++) {
          insertSource(rawDb, 'p${i.toString().padLeft(4, '0')}', raw);
        }
      }),
    );
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();

    // The magic as a BLOB literal, not the string 'SRD1'. SQLite never
    // equates a BLOB with a TEXT value, so a text comparison here would be
    // true for every row and the test would pass no matter what the rung did.
    final unpacked = await db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM dive_data_sources '
          "WHERE raw_data IS NOT NULL AND substr(raw_data, 1, 4) != x'53524431'",
        )
        .getSingle();
    expect(unpacked.data['cnt'], 0);

    // And the inverse, so a query that matches nothing cannot pass either.
    final packed = await db
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM dive_data_sources '
          "WHERE substr(raw_data, 1, 4) = x'53524431'",
        )
        .getSingle();
    expect(packed.data['cnt'], 250);
  });
}
