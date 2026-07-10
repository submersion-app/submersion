import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';

class _FakeLocation implements DatabaseLocationService {
  _FakeLocation(this.path);
  final String path;

  @override
  Future<String> getDatabasePath() async => path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ws5-isolate-test');
    dbPath = p.join(tempDir.path, 'submersion.db');
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    // Strict close so any open handle is definitely released before we
    // delete the temp dir — a non-strict close could swallow a timeout and
    // leave a handle open, making delete flaky (notably on Windows). The
    // reset + delete still run even if the close throws.
    try {
      await DatabaseService.instance.close(strict: true);
    } finally {
      DatabaseService.instance.resetForTesting();
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'fresh database opens on the background executor and self-heals',
    () async {
      await DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
      );
      expect(
        DatabaseService.instance.lastOpenMode,
        DatabaseOpenMode.background,
      );

      final db = DatabaseService.instance.database;
      final one = await db.customSelect('SELECT 1 AS v').getSingle();
      expect(one.read<int>('v'), 1);

      // beforeOpen ran through the remote executor: the built-in dive-type
      // seed (re-asserted on every open) is present.
      final diveTypes = await db
          .customSelect('SELECT COUNT(*) AS c FROM dive_types')
          .getSingle();
      expect(diveTypes.read<int>('c'), greaterThan(0));

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, AppDatabase.currentSchemaVersion);
    },
  );

  test('pending migration runs on the synchronous executor first, then '
      'reopens in background', () async {
    // Seed a current-schema file, then rewind user_version by one so the
    // next open sees a pending upgrade ladder.
    final seed = AppDatabase(NativeDatabase(File(dbPath)));
    await seed.customSelect('SELECT 1').get();
    await seed.close();
    final raw = sqlite3.sqlite3.open(dbPath);
    raw.execute(
      'PRAGMA user_version = ${AppDatabase.currentSchemaVersion - 1}',
    );
    raw.dispose();

    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(dbPath),
    );
    expect(
      DatabaseService.instance.lastOpenMode,
      DatabaseOpenMode.migrationThenBackground,
    );

    final db = DatabaseService.instance.database;
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, AppDatabase.currentSchemaVersion);
    final one = await db.customSelect('SELECT 1 AS v').getSingle();
    expect(one.read<int>('v'), 1);
  });

  test('a database newer than the app is rejected before any open', () async {
    // Seed a current-schema file, then bump user_version PAST the app's
    // version so the single synchronous read in _openDatabase trips the
    // newer-than-app guard.
    final seed = AppDatabase(NativeDatabase(File(dbPath)));
    await seed.customSelect('SELECT 1').get();
    await seed.close();
    final raw = sqlite3.sqlite3.open(dbPath);
    raw.execute(
      'PRAGMA user_version = ${AppDatabase.currentSchemaVersion + 1}',
    );
    raw.dispose();

    await expectLater(
      DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
      ),
      throwsA(isA<DatabaseVersionMismatchException>()),
    );
  });

  test('reinitializeAtPath reopens on the background executor', () async {
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(dbPath),
    );

    final otherPath = p.join(tempDir.path, 'other.db');
    await DatabaseService.instance.reinitializeAtPath(otherPath);

    expect(DatabaseService.instance.lastOpenMode, DatabaseOpenMode.background);
    final one = await DatabaseService.instance.database
        .customSelect('SELECT 1 AS v')
        .getSingle();
    expect(one.read<int>('v'), 1);
  });
}
