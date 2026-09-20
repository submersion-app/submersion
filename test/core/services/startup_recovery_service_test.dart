import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/security/database_security_sidecar.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/core/services/startup_recovery_service.dart';
import 'package:submersion/features/backup/data/services/backup_crypto.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';

/// Writes a file that looks enough like a Submersion dive log to be adopted.
void _writeDiveLog(
  String path, {
  int dives = 0,
  int sites = 0,
  bool includeDivesTable = true,
}) {
  final db = sqlite3.sqlite3.open(path);
  try {
    if (includeDivesTable) {
      db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
      for (var i = 0; i < dives; i++) {
        db.execute("INSERT INTO dives (id) VALUES ('dive-$i')");
      }
    }
    db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
    for (var i = 0; i < sites; i++) {
      db.execute("INSERT INTO dive_sites (id) VALUES ('site-$i')");
    }
  } finally {
    db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bookmarkChannel = MethodChannel(
    'app.submersion/security_scoped_bookmark',
  );

  /// Method names the service sent down the bookmark channel, in order.
  late List<String> bookmarkCalls;

  setUp(() {
    // State the platform rather than inheriting the host's. Bookmarks exist
    // only on macOS and iOS, so without this the bookmark expectations below
    // pass on a developer's Mac and fail on the Linux CI shards.
    SecurityScopedBookmarkService.debugSupportedOverride = true;
    addTearDown(
      () => SecurityScopedBookmarkService.debugSupportedOverride = null,
    );

    // Adopting a folder creates a security-scoped bookmark, over a channel
    // with no host implementation under test. The binary messenger is
    // process-global, so the handler is removed again after each test rather
    // than leaking into later ones.
    bookmarkCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bookmarkChannel, (call) async {
          bookmarkCalls.add(call.method);
          if (call.method == 'createBookmark') {
            return Uint8List.fromList(const [1, 2, 3, 4]);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bookmarkChannel, null),
    );
  });

  /// A service whose live database is `<liveFolder>/submersion.db`.
  ///
  /// The live location is pinned to a real temp folder rather than the app
  /// default so nothing here depends on a path_provider host.
  Future<StartupRecoveryService> serviceFor(Directory liveFolder) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final locationService = DatabaseLocationService(prefs);
    await locationService.saveStorageConfig(
      StorageConfig(
        mode: StorageLocationMode.customFolder,
        customFolderPath: liveFolder.path,
      ),
    );
    return StartupRecoveryService(locationService);
  }

  Directory makeTempDir(String prefix) {
    final dir = Directory.systemTemp.createTempSync(prefix);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return dir;
  }

  group('inspectFolder', () {
    test('reports no dive log when the folder holds none', () async {
      final live = makeTempDir('startup-recovery-live');
      final candidate = makeTempDir('startup-recovery-candidate');
      final service = await serviceFor(live);

      expect(
        await service.inspectFolder(candidate.path),
        isA<NoDiveLogInFolder>(),
      );
    });

    test('reports the dive log and its contents when one is there', () async {
      final live = makeTempDir('startup-recovery-live');
      final candidate = makeTempDir('startup-recovery-candidate');
      final dbPath = p.join(
        candidate.path,
        DatabaseLocationService.databaseFilename,
      );
      _writeDiveLog(dbPath, dives: 3, sites: 2);
      final service = await serviceFor(live);

      final found = await service.inspectFolder(candidate.path);

      expect(found, isA<AdoptableDiveLog>());
      final log = found as AdoptableDiveLog;
      expect(log.path, dbPath);
      expect(log.diveCount, 3);
      expect(log.siteCount, 2);
      expect(log.sizeBytes, greaterThan(0));
    });

    test('rejects a file that is not a database at all', () async {
      final live = makeTempDir('startup-recovery-live');
      final candidate = makeTempDir('startup-recovery-candidate');
      File(
        p.join(candidate.path, DatabaseLocationService.databaseFilename),
      ).writeAsStringSync('this is not a database');
      final service = await serviceFor(live);

      expect(
        await service.inspectFolder(candidate.path),
        isA<UnusableDiveLogInFolder>(),
      );
    });

    // A valid SQLite file that is not a dive log would otherwise be adopted
    // and then migrated by the schema ladder, which writes Submersion tables
    // into somebody else's database.
    test('rejects a valid SQLite file that is not a dive log', () async {
      final live = makeTempDir('startup-recovery-live');
      final candidate = makeTempDir('startup-recovery-candidate');
      _writeDiveLog(
        p.join(candidate.path, DatabaseLocationService.databaseFilename),
        includeDivesTable: false,
      );
      final service = await serviceFor(live);

      expect(
        await service.inspectFolder(candidate.path),
        isA<UnusableDiveLogInFolder>(),
      );
    });

    test('reads a dive log the diver has already adopted', () async {
      final live = makeTempDir('startup-recovery-live');
      _writeDiveLog(
        p.join(live.path, DatabaseLocationService.databaseFilename),
        dives: 1,
      );
      final service = await serviceFor(live);

      expect(await service.inspectFolder(live.path), isA<AdoptableDiveLog>());
    });
  });

  group('adopt', () {
    test('points the storage config at the folder holding the log', () async {
      final live = makeTempDir('startup-recovery-live');
      final candidate = makeTempDir('startup-recovery-candidate');
      _writeDiveLog(
        p.join(candidate.path, DatabaseLocationService.databaseFilename),
        dives: 7,
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final locationService = DatabaseLocationService(prefs);
      await locationService.saveStorageConfig(
        StorageConfig(
          mode: StorageLocationMode.customFolder,
          customFolderPath: live.path,
        ),
      );
      final service = StartupRecoveryService(locationService);

      final found =
          await service.inspectFolder(candidate.path) as AdoptableDiveLog;
      await service.adopt(found);

      final config = await locationService.getStorageConfig();
      expect(config.mode, StorageLocationMode.customFolder);
      expect(config.customFolderPath, candidate.path);
      expect(await locationService.getDatabasePath(), found.path);
    });

    // Without a bookmark the adopted folder is unreachable on the next launch
    // of a sandboxed macOS build, which is exactly where iCloud Drive lives.
    test('stores a security-scoped bookmark for the folder', () async {
      final live = makeTempDir('startup-recovery-live');
      final candidate = makeTempDir('startup-recovery-candidate');
      _writeDiveLog(
        p.join(candidate.path, DatabaseLocationService.databaseFilename),
      );
      final service = await serviceFor(live);

      final found =
          await service.inspectFolder(candidate.path) as AdoptableDiveLog;
      await service.adopt(found);

      expect(bookmarkCalls, contains('createBookmark'));
    });

    // The screen this is offered from has exactly one other action: quit. A
    // bookmark that could not be made must not take the adoption down with
    // it, or the diver is back to quitting.
    test('still adopts when the bookmark cannot be made', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bookmarkChannel, (call) async {
            throw PlatformException(code: 'bookmark_failed');
          });
      final live = makeTempDir('startup-recovery-live');
      final candidate = makeTempDir('startup-recovery-candidate');
      _writeDiveLog(
        p.join(candidate.path, DatabaseLocationService.databaseFilename),
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final locationService = DatabaseLocationService(prefs);
      await locationService.saveStorageConfig(
        StorageConfig(
          mode: StorageLocationMode.customFolder,
          customFolderPath: live.path,
        ),
      );
      final service = StartupRecoveryService(locationService);

      final found =
          await service.inspectFolder(candidate.path) as AdoptableDiveLog;
      await service.adopt(found);

      expect(
        (await locationService.getStorageConfig()).customFolderPath,
        candidate.path,
      );
    });

    // Windows, Linux and Android have no security-scoped bookmarks at all, so
    // the folder stays reachable by path and there is nothing to store. The
    // adoption itself must be identical.
    test('adopts without a bookmark where bookmarks do not exist', () async {
      SecurityScopedBookmarkService.debugSupportedOverride = false;
      final live = makeTempDir('startup-recovery-live');
      final candidate = makeTempDir('startup-recovery-candidate');
      _writeDiveLog(
        p.join(candidate.path, DatabaseLocationService.databaseFilename),
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final locationService = DatabaseLocationService(prefs);
      await locationService.saveStorageConfig(
        StorageConfig(
          mode: StorageLocationMode.customFolder,
          customFolderPath: live.path,
        ),
      );
      final service = StartupRecoveryService(locationService);

      final found =
          await service.inspectFolder(candidate.path) as AdoptableDiveLog;
      await service.adopt(found);

      expect(bookmarkCalls, isEmpty);
      expect(
        (await locationService.getStorageConfig()).customFolderPath,
        candidate.path,
      );
    });

    test('leaves the unreadable database where it is', () async {
      final live = makeTempDir('startup-recovery-live');
      final livePath = p.join(
        live.path,
        DatabaseLocationService.databaseFilename,
      );
      File(livePath).writeAsStringSync('damaged');
      final candidate = makeTempDir('startup-recovery-candidate');
      _writeDiveLog(
        p.join(candidate.path, DatabaseLocationService.databaseFilename),
      );
      final service = await serviceFor(live);

      final found =
          await service.inspectFolder(candidate.path) as AdoptableDiveLog;
      await service.adopt(found);

      expect(File(livePath).readAsStringSync(), 'damaged');
    });
  });

  group('classifyBackupFile', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<StartupRecoveryService> service() async {
      final live = makeTempDir('startup-recovery-live');
      return serviceFor(live);
    }

    test('accepts a backup that validates', () async {
      final dir = makeTempDir('startup-recovery-backup');
      final path = p.join(dir.path, 'submersion-backup.db');
      _writeDiveLog(path, dives: 5);

      final choice = await (await service()).classifyBackupFile(
        path,
        prefs,
        validate: (_) async => const BackupValidationResult.valid(),
      );

      expect(choice, isA<RestorableBackupFile>());
      expect((choice as RestorableBackupFile).path, path);
    });

    // The validator's own words name the actual problem (wrong extension,
    // empty file, missing Submersion tables) far better than a paraphrase.
    test('carries the validator reason through when it refuses', () async {
      final dir = makeTempDir('startup-recovery-backup');
      final path = p.join(dir.path, 'notes.txt');
      File(path).writeAsStringSync('not a backup');

      final choice = await (await service()).classifyBackupFile(
        path,
        prefs,
        validate: (_) async =>
            const BackupValidationResult.invalid('Invalid file extension'),
      );

      expect(choice, isA<UnusableBackupFile>());
      expect((choice as UnusableBackupFile).reason, 'Invalid file extension');
    });

    // Running the REAL validator, not the seam: a hand-picked file has never
    // been checked, and restore() leaves a file that fails its reopen live.
    test(
      'refuses a file that is not a database, through the real validator',
      () async {
        final dir = makeTempDir('startup-recovery-backup');
        final path = p.join(dir.path, 'pretend.db');
        File(path).writeAsStringSync('this is not a database');

        final choice = await (await service()).classifyBackupFile(path, prefs);

        expect(choice, isA<UnusableBackupFile>());
      },
    );

    test('refuses a file that is not there', () async {
      final dir = makeTempDir('startup-recovery-backup');

      final choice = await (await service()).classifyBackupFile(
        p.join(dir.path, 'gone.db'),
        prefs,
      );

      expect(choice, isA<UnusableBackupFile>());
    });

    // An encrypted backup is a VALID artifact that cannot be opened from a
    // screen with no passphrase prompt. Reporting it as damaged would send a
    // diver looking for a corruption that does not exist.
    test(
      'recognises an encrypted backup rather than calling it damaged',
      () async {
        final dir = makeTempDir('startup-recovery-backup');
        final path = p.join(dir.path, 'backup${BackupCrypto.fileExtension}');
        // The real SBE1 magic and a plausible header length, rather than a full
        // encryption run: what is under test is the classification, and taking
        // the magic from SyncEnvelope means this cannot drift from the format.
        File(
          path,
        ).writeAsBytesSync([...SyncEnvelope.magic, ...List<int>.filled(32, 7)]);

        final choice = await (await service()).classifyBackupFile(path, prefs);

        expect(choice, isA<EncryptedBackupFile>());
      },
    );
  });

  group('setAsideUnreadableDatabase', () {
    test('moves the database and its sidecars into one folder', () async {
      final live = makeTempDir('startup-recovery-live');
      final dbPath = p.join(
        live.path,
        DatabaseLocationService.databaseFilename,
      );
      File(dbPath).writeAsStringSync('damaged');
      File('$dbPath-wal').writeAsStringSync('wal');
      File('$dbPath-shm').writeAsStringSync('shm');
      final service = await serviceFor(live);

      final movedTo = await service.setAsideUnreadableDatabase();

      expect(File(dbPath).existsSync(), isFalse);
      expect(File('$dbPath-wal').existsSync(), isFalse);
      expect(File('$dbPath-shm').existsSync(), isFalse);
      final moved = p.join(movedTo, DatabaseLocationService.databaseFilename);
      expect(File(moved).readAsStringSync(), 'damaged');
      expect(File('$moved-wal').readAsStringSync(), 'wal');
      expect(File('$moved-shm').readAsStringSync(), 'shm');
    });

    // The keyslot sidecar is the durable unlock for an encrypted database and
    // is named by its FOLDER, not by the database file. Left behind it would
    // both strand the set-aside copy and make the startup gate treat the new
    // empty database as an interrupted encryption change.
    test('takes the keyslot sidecar with the database', () async {
      final live = makeTempDir('startup-recovery-live');
      final dbPath = p.join(
        live.path,
        DatabaseLocationService.databaseFilename,
      );
      File(dbPath).writeAsStringSync('damaged');
      File(DatabaseSecuritySidecar.pathFor(dbPath)).writeAsStringSync('keys');
      final service = await serviceFor(live);

      final movedTo = await service.setAsideUnreadableDatabase();

      expect(DatabaseSecuritySidecar.existsFor(dbPath), isFalse);
      final movedDb = p.join(movedTo, DatabaseLocationService.databaseFilename);
      expect(
        File(DatabaseSecuritySidecar.pathFor(movedDb)).readAsStringSync(),
        'keys',
      );
    });

    // WAL is not guaranteed: `PRAGMA journal_mode = WAL` can be declined (a
    // network volume, a read-only mount) and applyMainDatabaseSetup then
    // leaves the connection in rollback-journal mode. Left beside the new
    // empty database, a stale -journal is replayed against it.
    test('moves the rollback journal too', () async {
      final live = makeTempDir('startup-recovery-live');
      final dbPath = p.join(
        live.path,
        DatabaseLocationService.databaseFilename,
      );
      File(dbPath).writeAsStringSync('damaged');
      File('$dbPath-journal').writeAsStringSync('journal');
      final service = await serviceFor(live);

      final movedTo = await service.setAsideUnreadableDatabase();

      expect(File('$dbPath-journal').existsSync(), isFalse);
      final moved = p.join(movedTo, DatabaseLocationService.databaseFilename);
      expect(File('$moved-journal').readAsStringSync(), 'journal');
    });

    // A half-moved set is worse than not moving at all: the canonical path is
    // empty, so the next launch creates a fresh database, and the diver's
    // artifacts are split across two folders with no way to pair them again.
    test('puts everything back when one move fails', () async {
      final live = makeTempDir('startup-recovery-live');
      final dbPath = p.join(
        live.path,
        DatabaseLocationService.databaseFilename,
      );
      File(dbPath).writeAsStringSync('damaged');
      File('$dbPath-wal').writeAsStringSync('wal');
      File('$dbPath-shm').writeAsStringSync('shm');
      File(DatabaseSecuritySidecar.pathFor(dbPath)).writeAsStringSync('keys');
      StartupRecoveryService.debugFailMoveFor = '$dbPath-shm';
      addTearDown(() => StartupRecoveryService.debugFailMoveFor = null);
      final service = await serviceFor(live);

      await expectLater(
        service.setAsideUnreadableDatabase(),
        throwsA(anything),
      );

      expect(File(dbPath).readAsStringSync(), 'damaged');
      expect(File('$dbPath-wal').readAsStringSync(), 'wal');
      expect(File('$dbPath-shm').readAsStringSync(), 'shm');
      expect(
        File(DatabaseSecuritySidecar.pathFor(dbPath)).readAsStringSync(),
        'keys',
      );
      // And no half-built set-aside folder left behind to confuse a retry.
      expect(
        live
            .listSync()
            .whereType<Directory>()
            .where((d) => p.basename(d.path).startsWith('unreadable-'))
            .toList(),
        isEmpty,
      );
    });

    test('never deletes anything', () async {
      final live = makeTempDir('startup-recovery-live');
      final dbPath = p.join(
        live.path,
        DatabaseLocationService.databaseFilename,
      );
      File(dbPath).writeAsStringSync('the only copy of my dive log');
      final service = await serviceFor(live);

      final movedTo = await service.setAsideUnreadableDatabase();

      expect(
        File(
          p.join(movedTo, DatabaseLocationService.databaseFilename),
        ).readAsStringSync(),
        'the only copy of my dive log',
      );
    });

    test('keeps each set-aside copy when it runs twice', () async {
      final live = makeTempDir('startup-recovery-live');
      final dbPath = p.join(
        live.path,
        DatabaseLocationService.databaseFilename,
      );
      final service = await serviceFor(live);

      File(dbPath).writeAsStringSync('first');
      final first = await service.setAsideUnreadableDatabase();
      File(dbPath).writeAsStringSync('second');
      final second = await service.setAsideUnreadableDatabase();

      expect(first, isNot(second));
      expect(
        File(
          p.join(first, DatabaseLocationService.databaseFilename),
        ).readAsStringSync(),
        'first',
      );
      expect(
        File(
          p.join(second, DatabaseLocationService.databaseFilename),
        ).readAsStringSync(),
        'second',
      );
    });

    test('succeeds when there is nothing at the database path', () async {
      final live = makeTempDir('startup-recovery-live');
      final service = await serviceFor(live);

      final movedTo = await service.setAsideUnreadableDatabase();

      expect(Directory(movedTo).existsSync(), isTrue);
    });
  });
}
