import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/compaction/compact_database_file.dart';
import 'package:submersion/core/database/compaction/database_compaction_prefs.dart';
import 'package:submersion/core/database/compaction/database_space.dart';

import '../../../helpers/test_database.dart';

const _mb = 1024 * 1024;

DatabaseSpace _space(int fileMb, int freeMb) => DatabaseSpace(
  pageSize: 4096,
  pageCount: fileMb * _mb ~/ 4096,
  freePages: freeMb * _mb ~/ 4096,
);

void main() {
  group('worthCompacting', () {
    test('needs at least 50 MB free', () {
      expect(_space(100, 49).worthCompacting, isFalse);
    });
    test('needs at least a quarter of the file free', () {
      expect(_space(400, 60).worthCompacting, isFalse);
    });
    test('both met', () {
      expect(_space(200, 60).worthCompacting, isTrue);
      expect(_space(200, 60).reclaimableBytes, 60 * _mb);
      expect(_space(200, 60).fileBytes, 200 * _mb);
    });
  });

  group('DatabaseCompactionPrefs', () {
    late DateTime now;
    late DatabaseCompactionPrefs prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 10, 13);
      prefs = DatabaseCompactionPrefs(
        await SharedPreferences.getInstance(),
        now: () => now,
      );
    });

    test('request and cancel', () async {
      expect(prefs.isRequested, isFalse);
      await prefs.request();
      expect(prefs.isRequested, isTrue);
      await prefs.cancel();
      expect(prefs.isRequested, isFalse);
    });

    test(
      'declining withdraws the request and holds automatic ones off',
      () async {
        await prefs.request();
        await prefs.decline();
        expect(prefs.isRequested, isFalse);
        expect(prefs.inBackoff, isTrue);
      },
    );

    test('a failure holds further attempts off for a week', () async {
      expect(prefs.inBackoff, isFalse);
      await prefs.recordFailure();
      expect(prefs.inBackoff, isTrue);
      now = now.add(const Duration(days: 6));
      expect(prefs.inBackoff, isTrue);
      now = now.add(const Duration(days: 2));
      expect(prefs.inBackoff, isFalse);
    });
  });

  test('readDatabaseSpace counts the free pages a delete leaves', () async {
    final db = await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    await db.customStatement('CREATE TABLE junk (b BLOB)');
    final blob = Uint8List(2 * _mb);
    for (var i = 0; i < 3; i++) {
      await db.customStatement('INSERT INTO junk VALUES (?)', [blob]);
    }
    final before = await readDatabaseSpace(db);
    await db.customStatement('DELETE FROM junk');
    final after = await readDatabaseSpace(db);
    expect(after.reclaimableBytes, greaterThan(5 * _mb));
    expect(after.reclaimableBytes, greaterThan(before.reclaimableBytes));
    expect(after.fileBytes, greaterThanOrEqualTo(after.reclaimableBytes));
  });

  test('compactDatabaseFile shrinks a WAL file with free pages', () async {
    final dir = await Directory.systemTemp.createTemp('compact_');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'db.sqlite');
    final raw = sqlite3.sqlite3.open(path);
    raw.execute('PRAGMA journal_mode = WAL');
    raw.execute('CREATE TABLE t (b BLOB)');
    final blob = Uint8List(_mb);
    for (var i = 0; i < 20; i++) {
      raw.execute('INSERT INTO t VALUES (?)', [blob]);
    }
    // Leave the WAL un-checkpointed, as a closed app may.
    raw.execute('PRAGMA wal_checkpoint(PASSIVE)');
    raw.execute('DELETE FROM t');
    raw.close();
    final before = File(path).lengthSync();
    expect(before, greaterThan(15 * _mb));

    await compactDatabaseFile(path);

    expect(File(path).lengthSync(), lessThan(before ~/ 4));
    final wal = File('$path-wal');
    expect(!wal.existsSync() || wal.lengthSync() == 0, isTrue);
  });
}
