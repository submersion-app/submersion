import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
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

/// Routes getApplicationDocumentsDirectory into the test sandbox so any path
/// that falls back to the default location resolves there.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

int _pragma(sqlite3.Database raw, String pragma) {
  return raw.select('PRAGMA $pragma').first.values.first! as int;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('v183-vacuum-test');
    dbPath = p.join(tempDir.path, 'submersion.db');
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

  /// Creates the current schema in a file, then hands the raw handle to
  /// [shape] so a test can rewind `user_version` and add legacy bulk.
  Future<void> seedFile(void Function(sqlite3.Database raw) shape) async {
    final seed = AppDatabase(NativeDatabase(File(dbPath)));
    await seed.customSelect('SELECT 1').get();
    await seed.close();
    final raw = sqlite3.sqlite3.open(dbPath);
    try {
      shape(raw);
    } finally {
      raw.close();
    }
  }

  /// Reads the on-disk page accounting after the service has let go of the
  /// file. Reading it through the live connection would race the beforeOpen
  /// self-heals, which write.
  int freelistOnDisk() {
    final raw = sqlite3.sqlite3.open(dbPath);
    try {
      return _pragma(raw, 'freelist_count');
    } finally {
      raw.close();
    }
  }

  int storedVersionOnDisk() {
    final raw = sqlite3.sqlite3.open(dbPath);
    try {
      return _pragma(raw, 'user_version');
    } finally {
      raw.close();
    }
  }

  test(
    'a pre-183 file is VACUUMed once, reclaiming the dropped sample pages',
    () async {
      await seedFile((raw) {
        // The row-per-sample table as it stood before v183, with enough rows
        // that dropping it frees a page count no incidental write can hide.
        // The dive id is deliberately dangling so the packer skips the group
        // as an orphan: this test is about the pages, not the packing.
        raw.execute('DROP TABLE IF EXISTS dive_profiles');
        raw.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            source_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL,
            temperature REAL
          )
        ''');
        raw.execute(
          'CREATE INDEX idx_dive_profiles_dive_id ON dive_profiles(dive_id)',
        );
        final stmt = raw.prepare(
          'INSERT INTO dive_profiles (id, dive_id, timestamp, depth, '
          'temperature) VALUES (?, ?, ?, ?, ?)',
        );
        raw.execute('BEGIN');
        for (var i = 0; i < 20000; i++) {
          stmt.execute(['sample-$i', 'ghost-dive', i, i % 40 + 0.5, 21.0]);
        }
        raw.execute('COMMIT');
        stmt.close();
        raw.execute('PRAGMA user_version = 182');
      });

      expect(freelistOnDisk(), 0);

      final reports = <(int, int)>[];
      await DatabaseService.instance.initialize(
        locationService: _FakeLocation(dbPath),
        onMigrationProgress: (current, total) => reports.add((current, total)),
      );
      // The VACUUM is a step of its own. Without it in the count the ladder
      // reports itself finished and the bar sits at 100% while a large file
      // is rewritten, which is where a mobile watchdog kills the process.
      final ladderSteps = AppDatabase.migrationStepCount(182);
      expect(
        reports,
        contains((ladderSteps, ladderSteps + 1)),
        reason: 'the VACUUM is announced before it starts',
      );
      expect(reports.last, (ladderSteps + 1, ladderSteps + 1));
      expect(reports.map((r) => r.$2).toSet(), {
        ladderSteps + 1,
      }, reason: 'every report of this open counts the VACUUM');
      expect(
        DatabaseService.instance.lastOpenMode,
        DatabaseOpenMode.migrationThenBackground,
      );
      expect(
        DatabaseService.getStoredSchemaVersion(dbPath),
        AppDatabase.currentSchemaVersion,
      );
      await DatabaseService.instance.close(strict: true);

      expect(storedVersionOnDisk(), AppDatabase.currentSchemaVersion);
      // Only VACUUM returns the dropped table's pages to the filesystem; a
      // plain DROP leaves them on the freelist.
      expect(freelistOnDisk(), 0);
    },
  );

  test('a file at the current version whose legacy table the BACKSTOP drops '
      'is VACUUMed', () async {
    // The v183 rung is explicitly allowed to skip its drop: its own pack
    // threw, the series table's foreign-key parents were absent, or the
    // residue count found rows no series covered. The file is stamped past
    // that rung either way, and the beforeOpen backstop drops the tables on
    // the first later open whose pack succeeds. That open has no pending
    // ladder, so a reclamation keyed on the stored version never runs for it,
    // and there is no other VACUUM of the live database anywhere in the app:
    // the diver's file keeps every freed page forever.
    await seedFile((raw) {
      raw.execute('DROP TABLE IF EXISTS dive_profiles');
      raw.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            source_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL,
            temperature REAL
          )
        ''');
      raw.execute(
        'CREATE INDEX idx_dive_profiles_dive_id ON dive_profiles(dive_id)',
      );
      final stmt = raw.prepare(
        'INSERT INTO dive_profiles (id, dive_id, timestamp, depth, '
        'temperature) VALUES (?, ?, ?, ?, ?)',
      );
      raw.execute('BEGIN');
      for (var i = 0; i < 20000; i++) {
        // Dangling dive id, as in the test above: the rows are skipped as
        // orphans, so the residue is zero and the backstop drops the table.
        stmt.execute(['sample-$i', 'ghost-dive', i, i % 40 + 0.5, 21.0]);
      }
      raw.execute('COMMIT');
      stmt.close();
      // No rewind: seedFile leaves the file at the current version, so there
      // is no ladder to run. Pinning a literal here made this case quietly
      // stop being the one it describes as soon as a rung was added.
    });

    expect(freelistOnDisk(), 0);

    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(dbPath),
    );
    expect(DatabaseService.instance.lastOpenMode, DatabaseOpenMode.background);
    await DatabaseService.instance.close(strict: true);

    expect(
      freelistOnDisk(),
      0,
      reason: 'the pages the backstop freed have to come back',
    );
  });

  test('a file already at the current version is not VACUUMed', () async {
    await seedFile((raw) {
      // A freelist the open must leave alone: pages freed by a bulk delete
      // in a scratch table, with no pending migration to trigger the VACUUM.
      raw.execute('CREATE TABLE scratch (id TEXT NOT NULL PRIMARY KEY)');
      final stmt = raw.prepare('INSERT INTO scratch (id) VALUES (?)');
      raw.execute('BEGIN');
      for (var i = 0; i < 20000; i++) {
        stmt.execute(['row-$i-with-enough-text-to-fill-a-few-hundred-pages']);
      }
      raw.execute('COMMIT');
      stmt.close();
      raw.execute('DROP TABLE scratch');
    });

    final before = freelistOnDisk();
    expect(before, greaterThan(0));

    await DatabaseService.instance.initialize(
      locationService: _FakeLocation(dbPath),
    );
    expect(DatabaseService.instance.lastOpenMode, DatabaseOpenMode.background);
    await DatabaseService.instance.close(strict: true);

    expect(freelistOnDisk(), greaterThan(0));
  });
}
