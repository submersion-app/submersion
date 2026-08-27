import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/services/background_service.dart';
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
    tempDir = await Directory.systemTemp.createTemp('headless-guard-test');
    // The DEFAULT location, because openHeadlessDatabase resolves it: the
    // headless isolate registers no DatabaseLocationService.
    dbPath = p.join(tempDir.path, 'Submersion', 'submersion.db');
    await Directory(p.dirname(dbPath)).create(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    DatabaseService.instance.resetForTesting();
  });

  tearDown(() async {
    try {
      await DatabaseService.instance.close(strict: true);
    } finally {
      DatabaseService.instance.resetForTesting();
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedDatabaseFile() async {
    final seeded = AppDatabase(NativeDatabase(File(dbPath)));
    await seeded.customSelect('SELECT 1').get();
    await seeded.close();
  }

  void rollBackStoredVersion() {
    final db = DatabaseService.openRaw(dbPath);
    db.execute('PRAGMA user_version = ${AppDatabase.currentSchemaVersion - 1}');
    db.close();
  }

  test('a no-upgrade open refuses a database that still needs one', () async {
    await seedDatabaseFile();
    rollBackStoredVersion();

    await expectLater(
      DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
        allowSchemaUpgrade: false,
      ),
      throwsA(isA<SchemaUpgradePendingException>()),
    );

    // No drift connection was handed out, and -- the part that matters --
    // the stored version is untouched, so the foreground still owns the
    // upgrade. (The version probe does open and close the file to read
    // PRAGMA user_version; the guarantee is that nothing WROTE to it.)
    expect(DatabaseService.instance.databaseOrNull, isNull);
    final probe = DatabaseService.openRaw(dbPath);
    addTearDown(probe.close);
    expect(
      probe.select('PRAGMA user_version').single.values.first,
      AppDatabase.currentSchemaVersion - 1,
    );
  });

  test('a no-upgrade open proceeds when the schema is current', () async {
    await seedDatabaseFile();

    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(dbPath),
      allowSchemaUpgrade: false,
    );

    final one = await DatabaseService.instance.database
        .customSelect('SELECT 1 AS v')
        .getSingle();
    expect(one.read<int>('v'), 1);
  });

  test('a fresh database is still created by a no-upgrade open', () async {
    // No file yet: creation is onCreate, not the upgrade ladder, so a
    // headless task on a first-ever run must not be blocked by the guard.
    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(dbPath),
      allowSchemaUpgrade: false,
    );
    // drift opens lazily, so the file appears on the first statement.
    await DatabaseService.instance.database.customSelect('SELECT 1').get();

    expect(await File(dbPath).exists(), isTrue);
  });

  group('openHeadlessDatabase', () {
    test('skips the task when an upgrade is pending', () async {
      await seedDatabaseFile();
      rollBackStoredVersion();

      expect(await openHeadlessDatabase(), isFalse);
      expect(DatabaseService.instance.databaseOrNull, isNull);
    });

    test('opens when the schema is current', () async {
      await seedDatabaseFile();

      expect(await openHeadlessDatabase(), isTrue);
      expect(DatabaseService.instance.databaseOrNull, isNotNull);
    });
  });
}
