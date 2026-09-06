import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/database_provenance_recorder.dart';
import 'package:submersion/core/database/database_version_exception.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/database_service.dart';

/// The read half of the frozen contract (issue #1593): an OLDER build reading
/// provenance out of a file a NEWER build wrote, right next to the guard that
/// is about to refuse the file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('db_provenance_test_');
  });

  tearDown(() {
    DatabaseProvenanceRecorder.enabledInTests = false;
    DatabaseProvenanceRecorder.resetPackageInfoLoader();
    tempDir.deleteSync(recursive: true);
  });

  /// A database file at [userVersion] holding exactly [rows] of provenance.
  String seed(
    String name, {
    required int userVersion,
    Map<String, String>? rows,
    bool withTable = true,
  }) {
    final path = p.join(tempDir.path, name);
    final db = sqlite3.sqlite3.open(path);
    db.execute('PRAGMA user_version = $userVersion');
    if (withTable) {
      db.execute(
        'CREATE TABLE database_provenance ('
        'key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
      );
      for (final entry in (rows ?? const <String, String>{}).entries) {
        db.execute(
          'INSERT INTO database_provenance (key, value) VALUES (?, ?)',
          [entry.key, entry.value],
        );
      }
    }
    db.close();
    return path;
  }

  group('DatabaseService.readProvenance', () {
    test('returns null for a file that does not exist', () {
      expect(
        DatabaseService.readProvenance(p.join(tempDir.path, 'missing.db')),
        isNull,
      );
    });

    test('returns null when the table has never existed', () {
      // Every database written before v194, which is the whole population
      // stranded by issue #1568.
      final path = seed('legacy.db', userVersion: 175, withTable: false);
      expect(DatabaseService.readProvenance(path), isNull);
    });

    test('returns null for a table that exists but is empty', () {
      final path = seed('empty.db', userVersion: 194);
      expect(DatabaseService.readProvenance(path), isNull);
    });

    test('reads a record a future build wrote', () {
      final path = seed(
        'future.db',
        // Deliberately far past anything this build supports: that is the
        // case the reader exists for.
        userVersion: AppDatabase.currentSchemaVersion + 25,
        rows: {
          'app_version': '9.9.9.9999',
          'release_train': 'beta',
          'schema_version': '${AppDatabase.currentSchemaVersion + 25}',
          'written_at': '2027-01-02T03:04:05.000Z',
          'upgrade_app_version': '9.9.9.9999',
          'upgrade_to_schema_version':
              '${AppDatabase.currentSchemaVersion + 25}',
          'upgrade_from_schema_version': '${AppDatabase.currentSchemaVersion}',
          'a_key_from_the_future': 'ignored',
        },
      );

      final record = DatabaseService.readProvenance(path)!;
      expect(record.lastOpen!.appVersion, '9.9.9.9999');
      expect(record.lastOpen!.releaseTrain, 'beta');
      expect(
        record.lastUpgrade!.fromSchemaVersion,
        AppDatabase.currentSchemaVersion,
      );
    });

    test('does not write to the file it reads', () {
      // The guard's whole promise is that nothing writes to a database this
      // build does not understand, so the read is read-only.
      final path = seed(
        'untouched.db',
        userVersion: AppDatabase.currentSchemaVersion + 1,
        rows: const {'app_version': '9.9.9.9999'},
      );
      final before = File(path).lastModifiedSync();
      final bytesBefore = File(path).readAsBytesSync();

      DatabaseService.readProvenance(path);

      expect(File(path).lastModifiedSync(), before);
      expect(File(path).readAsBytesSync(), bytesBefore);
      expect(File('$path-wal').existsSync(), isFalse);
      expect(File('$path-journal').existsSync(), isFalse);
    });

    test('a table of the wrong shape degrades to null', () {
      // Nothing enforces the frozen shape on a file this build did not write.
      final path = p.join(tempDir.path, 'wrong_shape.db');
      final db = sqlite3.sqlite3.open(path);
      db.execute('PRAGMA user_version = 194');
      db.execute('CREATE TABLE database_provenance (whatever TEXT)');
      db.close();

      expect(DatabaseService.readProvenance(path), isNull);
    });
  });

  group('the version-mismatch guard', () {
    test('carries the provenance of the file it refuses', () async {
      final path = seed(
        'newer.db',
        userVersion: AppDatabase.currentSchemaVersion + 1,
        rows: const {
          'app_version': '1.7.7.8064',
          'release_train': 'beta',
          'upgrade_app_version': '1.7.7.8064',
          'upgrade_release_train': 'beta',
        },
      );

      final service = DatabaseService.instance;
      addTearDown(service.resetForTesting);

      await expectLater(
        service.initialize(locationService: _FixedLocation(path)),
        throwsA(
          isA<DatabaseVersionMismatchException>().having(
            (e) => e.provenance?.lastUpgrade?.appVersion,
            'provenance.lastUpgrade.appVersion',
            '1.7.7.8064',
          ),
        ),
      );
    });

    test('is unchanged for a database written before v194', () async {
      final path = seed(
        'newer_legacy.db',
        userVersion: AppDatabase.currentSchemaVersion + 1,
        withTable: false,
      );

      final service = DatabaseService.instance;
      addTearDown(service.resetForTesting);

      await expectLater(
        service.initialize(locationService: _FixedLocation(path)),
        throwsA(
          isA<DatabaseVersionMismatchException>().having(
            (e) => e.provenance,
            'provenance',
            isNull,
          ),
        ),
      );
    });
  });

  test('opening a database records the build that opened it', () async {
    DatabaseProvenanceRecorder.enabledInTests = true;
    DatabaseProvenanceRecorder.packageInfoLoader = () async => PackageInfo(
      appName: 'Submersion',
      packageName: 'app.submersion',
      version: '1.7.7',
      buildNumber: '8064',
    );

    final path = p.join(tempDir.path, 'fresh.db');
    final service = DatabaseService.instance;
    addTearDown(service.resetForTesting);

    await service.initialize(locationService: _FixedLocation(path));
    // Drift opens lazily under flutter test; force the open before closing.
    await service.database.customSelect('SELECT 1').get();
    await service.close();

    final record = DatabaseService.readProvenance(path)!;
    expect(record.lastOpen!.appVersion, '1.7.7.8064');
    expect(record.lastOpen!.schemaVersion, AppDatabase.currentSchemaVersion);
    // No BUILD_TRAIN define in a test binary, and none in any build shipping
    // today until #1592 stamps the beta workflow. Recording nothing is the
    // honest answer; defaulting to 'stable' would have a beta-written file
    // claim the stable train.
    expect(record.lastOpen!.releaseTrain, isNull);
    // A file this build created is a file this build put on its current rung,
    // which is the question the mismatch screen asks.
    expect(record.lastUpgrade!.appVersion, '1.7.7.8064');
    expect(record.lastUpgrade!.fromSchemaVersion, 0);
  });
}

class _FixedLocation implements DatabaseLocationService {
  _FixedLocation(this.path);

  final String path;

  @override
  Future<String> getDatabasePath() async => path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
