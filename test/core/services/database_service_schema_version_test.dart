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
}
