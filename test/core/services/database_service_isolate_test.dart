import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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

/// Routes getApplicationDocumentsDirectory to a temp dir so paths that fall
/// back to the default location (e.g. restore -> initialize()) resolve inside
/// the test sandbox.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ws5-isolate-test');
    dbPath = p.join(tempDir.path, 'submersion.db');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
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

  test(
    'a database newer than the app is rejected before any Drift open',
    () async {
      // Seed a current-schema file, then bump user_version PAST the app's
      // version. _openDatabase's single synchronous getStoredSchemaVersion
      // read (raw sqlite3) trips the newer-than-app guard and throws before
      // any Drift executor — migrator or background — opens the file.
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
    },
  );

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

  test(
    'resetDatabase backs up, closes strictly, and recreates the db',
    () async {
      await DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
      );
      // Force the background executor to actually materialize the file so
      // resetDatabase's pre-close backup has something to copy.
      await DatabaseService.instance.database
          .customSelect('SELECT 1')
          .getSingle();
      final backupPath = p.join(tempDir.path, 'reset-backup.db');

      await DatabaseService.instance.resetDatabase(backupPath: backupPath);

      expect(File(backupPath).existsSync(), isTrue);
      // A fresh db still re-seeds the built-in dive types through the
      // background executor.
      final diveTypes = await DatabaseService.instance.database
          .customSelect('SELECT COUNT(*) AS c FROM dive_types')
          .getSingle();
      expect(diveTypes.read<int>('c'), greaterThan(0));
    },
  );

  test('a failing migration ladder closes the migrator and rethrows', () async {
    // Seed a current-schema file, then rewind user_version far back so the
    // upgrade ladder replays historical steps. An early unguarded addColumn
    // hits an already-present column ("duplicate column name"), so the
    // synchronous migrator throws — exercising _openDatabase's best-effort
    // migrator close + rethrow on the migration-failure path.
    final seed = AppDatabase(NativeDatabase(File(dbPath)));
    await seed.customSelect('SELECT 1').get();
    await seed.close();
    final raw = sqlite3.sqlite3.open(dbPath);
    raw.execute('PRAGMA user_version = 58');
    raw.dispose();

    await expectLater(
      DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
      ),
      throwsA(isA<sqlite3.SqliteException>()),
    );
  });

  test('restore closes strictly, copies the backup, and reopens', () async {
    // restore() reopens through initialize()'s default-path resolution, so
    // seed at the default layout (docs/Submersion/submersion.db) — mocked to
    // live under the temp dir — to keep source and destination aligned.
    final defaultPath = p.join(tempDir.path, 'Submersion', 'submersion.db');
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(defaultPath),
    );
    await DatabaseService.instance.database
        .customSelect('SELECT 1')
        .getSingle();
    final backupPath = p.join(tempDir.path, 'backup.db');
    await DatabaseService.instance.backup(backupPath);

    await DatabaseService.instance.restore(backupPath);

    final one = await DatabaseService.instance.database
        .customSelect('SELECT 1 AS v')
        .getSingle();
    expect(one.read<int>('v'), 1);
  });
}
