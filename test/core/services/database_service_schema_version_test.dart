import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/services/database_service.dart';

void main() {
  group('DatabaseService.getStoredSchemaVersion', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('db_version_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns null when database file does not exist', () {
      final path = p.join(tempDir.path, 'nonexistent.db');
      final version = DatabaseService.getStoredSchemaVersion(path);
      expect(version, isNull);
    });

    test('returns 0 for a fresh database with no version set', () {
      final path = p.join(tempDir.path, 'fresh.db');
      final db = sqlite3.sqlite3.open(path);
      db.execute('CREATE TABLE dummy (id INTEGER)');
      db.dispose();

      final version = DatabaseService.getStoredSchemaVersion(path);
      expect(version, 0);
    });

    test('returns the stored schema version', () {
      final path = p.join(tempDir.path, 'versioned.db');
      final db = sqlite3.sqlite3.open(path);
      db.execute('PRAGMA user_version = 42');
      db.dispose();

      final version = DatabaseService.getStoredSchemaVersion(path);
      expect(version, 42);
    });
  });

  group('DatabaseService.recoverHotJournal', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('db_recovery_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns true for a file that does not exist', () {
      final path = p.join(tempDir.path, 'nonexistent.db');
      expect(DatabaseService.recoverHotJournal(path), isTrue);
    });

    test('returns true for a healthy database (no recovery needed)', () {
      final path = p.join(tempDir.path, 'healthy.db');
      final db = sqlite3.sqlite3.open(path);
      db.execute('PRAGMA user_version = 69');
      db.execute('CREATE TABLE t (id INTEGER)');
      db.execute('INSERT INTO t VALUES (1), (2), (3)');
      db.dispose();

      expect(DatabaseService.recoverHotJournal(path), isTrue);
    });

    test('leaves a healthy database readable at its original version', () {
      final path = p.join(tempDir.path, 'readable.db');
      final db = sqlite3.sqlite3.open(path);
      db.execute('PRAGMA user_version = 42');
      db.dispose();

      DatabaseService.recoverHotJournal(path);

      expect(DatabaseService.getStoredSchemaVersion(path), 42);
    });
  });

  group('DatabaseService.isRecoverableReadonlyError', () {
    test('true for SQLITE_READONLY primary code', () {
      final e = sqlite3.SqliteException(8, 'attempt to write a readonly db');
      expect(DatabaseService.isRecoverableReadonlyError(e), isTrue);
    });

    test('true for SQLITE_READONLY_ROLLBACK extended code 776', () {
      final e = sqlite3.SqliteException(776, 'attempt to write a readonly db');
      expect(DatabaseService.isRecoverableReadonlyError(e), isTrue);
    });

    test('true for SQLITE_READONLY_DIRECTORY extended code 1544', () {
      final e = sqlite3.SqliteException(1544, 'readonly directory');
      expect(DatabaseService.isRecoverableReadonlyError(e), isTrue);
    });

    test('false for unrelated SQLite errors (e.g. SQLITE_BUSY)', () {
      final e = sqlite3.SqliteException(5, 'database is locked');
      expect(DatabaseService.isRecoverableReadonlyError(e), isFalse);
    });

    test('false for non-SqliteException', () {
      expect(
        DatabaseService.isRecoverableReadonlyError(Exception('other')),
        isFalse,
      );
    });
  });
}
