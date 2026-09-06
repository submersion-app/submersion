import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

Future<_Fixture> _makeFixture() async {
  final tmp = await Directory.systemTemp.createTemp('pmbs_test_');
  final live = File(p.join(tmp.path, 'submersion.db'));
  await live.writeAsBytes(List<int>.generate(1024, (i) => i % 256));
  final backupsDir = Directory(p.join(tmp.path, 'backups'));
  await backupsDir.create();
  SharedPreferences.setMockInitialValues({});
  final prefs = BackupPreferences(await SharedPreferences.getInstance());
  return _Fixture(
    tmp: tmp,
    livePath: live.path,
    backupsDir: backupsDir.path,
    prefs: prefs,
  );
}

class _Fixture {
  final Directory tmp;
  final String livePath;
  final String backupsDir;
  final BackupPreferences prefs;
  _Fixture({
    required this.tmp,
    required this.livePath,
    required this.backupsDir,
    required this.prefs,
  });
  Future<void> dispose() async => tmp.delete(recursive: true);
}

void main() {
  group('PreMigrationBackupService happy path', () {
    test('copies live DB bytes into backups folder', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'test-id-1',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      const expectedName = '20260412-081201000-v63-v64.db';
      final backupFile = File(p.join(f.backupsDir, expectedName));
      expect(await backupFile.exists(), isTrue);
      expect(
        await backupFile.readAsBytes(),
        await File(f.livePath).readAsBytes(),
      );
    });

    test(
      'registers BackupRecord with preMigration type + schema pair',
      () async {
        final f = await _makeFixture();
        addTearDown(f.dispose);
        final service = PreMigrationBackupService(
          livePathProvider: () async => f.livePath,
          backupsDirProvider: () async => f.backupsDir,
          preferences: f.prefs,
          clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
          idGenerator: () => 'test-id-1',
        );

        await service.backupIfMigrationPending(
          stored: 63,
          target: 64,
          appVersion: '1.6.0.1241',
        );

        final history = f.prefs.getHistory();
        expect(history, hasLength(1));
        final record = history.single;
        expect(record.id, 'test-id-1');
        expect(record.type, BackupType.preMigration);
        expect(record.fromSchemaVersion, 63);
        expect(record.toSchemaVersion, 64);
        expect(record.appVersion, '1.6.0.1241');
        expect(record.filename, '20260412-081201000-v63-v64.db');
        expect(record.diveCount, isNull);
        expect(record.siteCount, isNull);
        expect(record.pinned, false);
        expect(record.isAutomatic, true);
        expect(record.location, BackupLocation.local);
        expect(record.localPath, p.join(f.backupsDir, record.filename));
        expect(record.sizeBytes, 1024);
      },
    );

    test('skips when stored == target (no-op)', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12),
        idGenerator: () => 'x',
      );

      await service.backupIfMigrationPending(
        stored: 64,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      expect(await Directory(f.backupsDir).list().isEmpty, isTrue);
      expect(f.prefs.getHistory(), isEmpty);
    });

    test('skips when stored > target (newer database, no-op)', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 7, 28),
        idGenerator: () => 'x',
      );

      // A database written by a newer app version: the startup version guard
      // rejects it before Drift opens, so no backup must be taken and the
      // file must not be touched.
      await service.backupIfMigrationPending(
        stored: 137,
        target: 136,
        appVersion: '1.8.0.5601',
      );

      expect(await Directory(f.backupsDir).list().isEmpty, isTrue);
      expect(f.prefs.getHistory(), isEmpty);
    });

    test('skips when live DB file does not exist', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      await File(f.livePath).delete();
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12),
        idGenerator: () => 'x',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      expect(await Directory(f.backupsDir).list().isEmpty, isTrue);
      expect(f.prefs.getHistory(), isEmpty);
    });
  });

  group('.tmp sweep', () {
    test('deletes leftover .tmp files in backups dir before backup', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final stale = File(
        p.join(f.backupsDir, '.20260101-000000-v62-v63.db.tmp'),
      );
      await stale.writeAsBytes([1, 2, 3]);
      expect(await stale.exists(), isTrue);

      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'id',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      expect(await stale.exists(), isFalse);
    });

    test('does not delete non-.tmp files', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final keep = File(p.join(f.backupsDir, '20260101-000000-manual.db'));
      await keep.writeAsBytes([1, 2, 3]);

      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'id',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      expect(await keep.exists(), isTrue);
    });

    test('does not delete .tmp files that are not our own form', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      // User-dropped file that happens to end in .tmp - must NOT be deleted.
      final notOurs = File(p.join(f.backupsDir, 'notes.tmp'));
      await notOurs.writeAsBytes([1, 2, 3]);

      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'id',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      expect(await notOurs.exists(), isTrue);
    });
  });

  group('retention prune', () {
    test(
      'keeps the lowest fromSchemaVersion copy in place of the third-newest',
      () async {
        // Recoverability runs oldest-first: the copy that matters is the one
        // whose schema is low enough for an older build to open, which is the
        // lowest fromSchemaVersion, not the third-newest by timestamp.
        final f = await _makeFixture();
        addTearDown(f.dispose);
        await _seedPreMigration(f, id: 'floor', day: 1, fromSchemaVersion: 175);
        await _seedPreMigration(f, id: 'mid', day: 2, fromSchemaVersion: 180);
        await _seedPreMigration(f, id: 'third', day: 3, fromSchemaVersion: 185);
        await _seedPreMigration(
          f,
          id: 'second',
          day: 4,
          fromSchemaVersion: 188,
        );

        await _runMigration(f, stored: 190, target: 191);

        final remaining = _preMigrationIds(f);
        expect(
          remaining,
          hasLength(3),
          reason: 'the retained count must not change',
        );
        expect(remaining, containsAll(<String>['new', 'second', 'floor']));
        expect(remaining, isNot(contains('third')));
        expect(remaining, isNot(contains('mid')));
        expect(await _preMigrationFile(f, 'floor').exists(), isTrue);
        expect(await _preMigrationFile(f, 'mid').exists(), isFalse);
        expect(await _preMigrationFile(f, 'third').exists(), isFalse);
      },
    );

    test(
      'prefers the newer copy when two share the lowest fromSchemaVersion',
      () async {
        // Both open in the same older build, so the tie goes to the one
        // holding more of the diver's data.
        final f = await _makeFixture();
        addTearDown(f.dispose);
        await _seedPreMigration(
          f,
          id: 'older-175',
          day: 1,
          fromSchemaVersion: 175,
        );
        await _seedPreMigration(
          f,
          id: 'newer-175',
          day: 2,
          fromSchemaVersion: 175,
        );
        await _seedPreMigration(f, id: 'v180', day: 3, fromSchemaVersion: 180);
        await _seedPreMigration(f, id: 'v185', day: 4, fromSchemaVersion: 185);

        await _runMigration(f, stored: 190, target: 191);

        final remaining = _preMigrationIds(f);
        expect(remaining, hasLength(3));
        expect(remaining, containsAll(<String>['new', 'v185', 'newer-175']));
        expect(remaining, isNot(contains('older-175')));
      },
    );

    test(
      'a record with no fromSchemaVersion never takes the floor slot',
      () async {
        // Legacy records predate the schema pair. Reading a missing version as
        // the lowest would keep a copy whose openability is unknown and delete
        // the one that is known to work.
        final f = await _makeFixture();
        addTearDown(f.dispose);
        await _seedPreMigration(
          f,
          id: 'legacy',
          day: 1,
          fromSchemaVersion: null,
        );
        await _seedPreMigration(f, id: 'floor', day: 2, fromSchemaVersion: 175);
        await _seedPreMigration(f, id: 'v180', day: 3, fromSchemaVersion: 180);
        await _seedPreMigration(f, id: 'v185', day: 4, fromSchemaVersion: 185);

        await _runMigration(f, stored: 190, target: 191);

        final remaining = _preMigrationIds(f);
        expect(remaining, hasLength(3));
        expect(remaining, containsAll(<String>['new', 'v185', 'floor']));
        expect(remaining, isNot(contains('legacy')));
      },
    );

    test('pinned pre-migration backups are never pruned', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      for (var i = 0; i < 5; i++) {
        final ts = DateTime.utc(2026, 1, 1 + i);
        final name = '${_ts(ts)}-v$i-v${i + 1}.db';
        await File(p.join(f.backupsDir, name)).writeAsBytes([i]);
        await f.prefs.addRecord(
          BackupRecord(
            id: 'pinned-$i',
            filename: name,
            timestamp: ts,
            sizeBytes: 1,
            location: BackupLocation.local,
            localPath: p.join(f.backupsDir, name),
            type: BackupType.preMigration,
            fromSchemaVersion: i,
            toSchemaVersion: i + 1,
            pinned: true,
          ),
        );
      }

      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12),
        idGenerator: () => 'new',
      );
      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      final preMigrationRecords = f.prefs
          .getHistory()
          .where((r) => r.type == BackupType.preMigration)
          .toList();
      expect(preMigrationRecords, hasLength(6));
    });

    test('does nothing when only 2 unpinned exist', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      for (var i = 0; i < 2; i++) {
        final ts = DateTime.utc(2026, 1, 1 + i);
        final name = '${_ts(ts)}-v$i-v${i + 1}.db';
        await File(p.join(f.backupsDir, name)).writeAsBytes([i]);
        await f.prefs.addRecord(
          BackupRecord(
            id: 'r$i',
            filename: name,
            timestamp: ts,
            sizeBytes: 1,
            location: BackupLocation.local,
            localPath: p.join(f.backupsDir, name),
            type: BackupType.preMigration,
            fromSchemaVersion: i,
            toSchemaVersion: i + 1,
          ),
        );
      }

      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12),
        idGenerator: () => 'new',
      );
      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      final count = f.prefs
          .getHistory()
          .where((r) => r.type == BackupType.preMigration)
          .length;
      expect(count, 3);
    });

    test('does not touch manual-backup records', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      for (var i = 0; i < 5; i++) {
        final name = 'manual-$i.db';
        await File(p.join(f.backupsDir, name)).writeAsBytes([i]);
        await f.prefs.addRecord(
          BackupRecord(
            id: 'm$i',
            filename: name,
            timestamp: DateTime.utc(2026, 1, 1 + i),
            sizeBytes: 1,
            location: BackupLocation.local,
            localPath: p.join(f.backupsDir, name),
            type: BackupType.manual,
          ),
        );
      }

      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12),
        idGenerator: () => 'new',
      );
      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      final manualCount = f.prefs
          .getHistory()
          .where((r) => r.type == BackupType.manual)
          .length;
      expect(manualCount, 5);
    });
  });

  group('error handling', () {
    test('wraps directory-creation errors as BackupFailedException '
        '(backupsDir path is a regular file)', () async {
      // Trigger a file-system error without needing ENOSPC by pointing the
      // backupsDir at a path that already exists as a regular file.
      final tmp = await Directory.systemTemp.createTemp('pmbs_err_');
      addTearDown(() => tmp.delete(recursive: true));
      final live = File(p.join(tmp.path, 'submersion.db'));
      await live.writeAsBytes([1, 2, 3]);
      final conflicting = File(p.join(tmp.path, 'not-a-dir'));
      await conflicting.writeAsBytes([0]);
      SharedPreferences.setMockInitialValues({});
      final prefs = BackupPreferences(await SharedPreferences.getInstance());

      final service = PreMigrationBackupService(
        livePathProvider: () async => live.path,
        backupsDirProvider: () async => conflicting.path,
        preferences: prefs,
        clock: () => DateTime.utc(2026, 4, 12),
        idGenerator: () => 'id',
      );

      expect(
        () async => service.backupIfMigrationPending(
          stored: 63,
          target: 64,
          appVersion: '1.6.0.1241',
        ),
        throwsA(isA<BackupFailedException>()),
      );
    });
  });

  group('fallback to default location', () {
    test('falls back to the default backups dir when the preferred location '
        'cannot be created', () async {
      // Reproduces the iOS report: the stored custom backup_location is an
      // iCloud-Drive path whose security scope is gone, so resolving/creating
      // it throws EPERM. With a fallback provider the pre-migration backup
      // must still succeed by writing into the app sandbox instead of
      // bricking startup.
      final tmp = await Directory.systemTemp.createTemp('pmbs_fallback_');
      addTearDown(() => tmp.delete(recursive: true));
      final live = File(p.join(tmp.path, 'submersion.db'));
      await live.writeAsBytes(List<int>.generate(512, (i) => i % 256));
      final fallbackDir = Directory(p.join(tmp.path, 'default_backups'));
      SharedPreferences.setMockInitialValues({});
      final prefs = BackupPreferences(await SharedPreferences.getInstance());

      final service = PreMigrationBackupService(
        livePathProvider: () async => live.path,
        backupsDirProvider: () async => throw const FileSystemException(
          'Creation failed',
          '/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs',
          OSError('Operation not permitted', 1),
        ),
        fallbackBackupsDirProvider: () async => fallbackDir.path,
        preferences: prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'fallback-id',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      const expectedName = '20260412-081201000-v63-v64.db';
      final backupFile = File(p.join(fallbackDir.path, expectedName));
      expect(
        await backupFile.exists(),
        isTrue,
        reason: 'backup should land in the fallback directory',
      );
      expect(await backupFile.readAsBytes(), await live.readAsBytes());
      final history = prefs.getHistory();
      expect(history, hasLength(1));
      expect(history.single.localPath, backupFile.path);
    });

    test(
      'rethrows when both preferred and fallback locations are unusable',
      () async {
        final tmp = await Directory.systemTemp.createTemp('pmbs_fb_fail_');
        addTearDown(() => tmp.delete(recursive: true));
        final live = File(p.join(tmp.path, 'submersion.db'));
        await live.writeAsBytes([1, 2, 3]);
        // Fallback path is a regular file, so creating it as a dir fails too.
        final conflicting = File(p.join(tmp.path, 'not-a-dir'));
        await conflicting.writeAsBytes([0]);
        SharedPreferences.setMockInitialValues({});
        final prefs = BackupPreferences(await SharedPreferences.getInstance());

        final service = PreMigrationBackupService(
          livePathProvider: () async => live.path,
          backupsDirProvider: () async =>
              throw const FileSystemException('primary unavailable'),
          fallbackBackupsDirProvider: () async => conflicting.path,
          preferences: prefs,
          clock: () => DateTime.utc(2026, 4, 12),
          idGenerator: () => 'id',
        );

        await expectLater(
          service.backupIfMigrationPending(
            stored: 63,
            target: 64,
            appVersion: '1.6.0.1241',
          ),
          throwsA(isA<BackupFailedException>()),
        );
      },
    );

    test(
      'without a fallback provider, a preferred-location failure still throws',
      () async {
        // Preserves the original (no-fallback) contract used by callers that
        // want strict behavior.
        final tmp = await Directory.systemTemp.createTemp('pmbs_no_fb_');
        addTearDown(() => tmp.delete(recursive: true));
        final live = File(p.join(tmp.path, 'submersion.db'));
        await live.writeAsBytes([1, 2, 3]);
        SharedPreferences.setMockInitialValues({});
        final prefs = BackupPreferences(await SharedPreferences.getInstance());

        final service = PreMigrationBackupService(
          livePathProvider: () async => live.path,
          backupsDirProvider: () async =>
              throw const FileSystemException('primary unavailable'),
          preferences: prefs,
          clock: () => DateTime.utc(2026, 4, 12),
          idGenerator: () => 'id',
        );

        await expectLater(
          service.backupIfMigrationPending(
            stored: 63,
            target: 64,
            appVersion: '1.6.0.1241',
          ),
          throwsA(isA<BackupFailedException>()),
        );
      },
    );

    test(
      'falls back when the preferred dir exists but the copy into it fails',
      () async {
        // The variant the reporter could also hit: an iCloud dir that EXISTS
        // but whose write scope is gone. create() is a no-op (it exists) and
        // the copy into it throws -- the fallback must still rescue startup.
        final tmp = await Directory.systemTemp.createTemp('pmbs_copyfail_');
        addTearDown(() => tmp.delete(recursive: true));
        final live = File(p.join(tmp.path, 'submersion.db'));
        await live.writeAsBytes(List<int>.generate(256, (i) => i % 256));
        final preferred = Directory(p.join(tmp.path, 'preferred'));
        await preferred.create();
        await Process.run('chmod', ['000', preferred.path]);
        addTearDown(() => Process.run('chmod', ['755', preferred.path]));
        final fallback = Directory(p.join(tmp.path, 'fallback'));
        SharedPreferences.setMockInitialValues({});
        final prefs = BackupPreferences(await SharedPreferences.getInstance());

        final service = PreMigrationBackupService(
          livePathProvider: () async => live.path,
          backupsDirProvider: () async => preferred.path,
          fallbackBackupsDirProvider: () async => fallback.path,
          preferences: prefs,
          clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
          idGenerator: () => 'copyfail-id',
        );

        await service.backupIfMigrationPending(
          stored: 63,
          target: 64,
          appVersion: '1.6.0.1241',
        );

        final landed = File(
          p.join(fallback.path, '20260412-081201000-v63-v64.db'),
        );
        expect(
          await landed.exists(),
          isTrue,
          reason: 'backup should land in the fallback when the copy fails',
        );
        final history = prefs.getHistory();
        expect(history, hasLength(1));
        expect(history.single.localPath, landed.path);
      },
      skip: Platform.isWindows
          ? 'chmod-based permission denial is not portable to Windows'
          : null,
    );
  });

  group('construction', () {
    test('default idGenerator produces a UUID-shaped id', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      final history = f.prefs.getHistory();
      expect(history, hasLength(1));
      final id = history.single.id;
      // UUID v4 canonical form: 8-4-4-4-12 hex.
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
        r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuid.hasMatch(id), isTrue, reason: 'id was "$id"');
    });
  });

  group('atomicity', () {
    test('final .db exists only under non-.tmp name after success', () async {
      final f = await _makeFixture();
      addTearDown(f.dispose);
      final service = PreMigrationBackupService(
        livePathProvider: () async => f.livePath,
        backupsDirProvider: () async => f.backupsDir,
        preferences: f.prefs,
        clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
        idGenerator: () => 'id',
      );

      await service.backupIfMigrationPending(
        stored: 63,
        target: 64,
        appVersion: '1.6.0.1241',
      );

      final entries = await Directory(f.backupsDir).list().toList();
      final names = entries.map((e) => p.basename(e.path)).toList();
      expect(names.any((n) => n.endsWith('.tmp')), isFalse);
      expect(names, contains('20260412-081201000-v63-v64.db'));
    });
  });
}

String _ts(DateTime utc) {
  String two(int v) => v.toString().padLeft(2, '0');
  String three(int v) => v.toString().padLeft(3, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}-'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}'
      '${three(utc.millisecond)}';
}

/// Registers an unpinned pre-migration record backed by a real file, named
/// after [id] so prune assertions can look for it on disk. [day] places the
/// record in January 2026, so a higher day is a newer copy.
Future<void> _seedPreMigration(
  _Fixture f, {
  required String id,
  required int day,
  required int? fromSchemaVersion,
}) async {
  final file = _preMigrationFile(f, id);
  await file.writeAsBytes([day]);
  await f.prefs.addRecord(
    BackupRecord(
      id: id,
      filename: p.basename(file.path),
      timestamp: DateTime.utc(2026, 1, day),
      sizeBytes: 1,
      location: BackupLocation.local,
      localPath: file.path,
      type: BackupType.preMigration,
      fromSchemaVersion: fromSchemaVersion,
      toSchemaVersion: fromSchemaVersion == null ? null : fromSchemaVersion + 1,
    ),
  );
}

File _preMigrationFile(_Fixture f, String id) =>
    File(p.join(f.backupsDir, '$id.db'));

/// Runs one pre-migration backup, registered as 'new' and newer than anything
/// [_seedPreMigration] writes, so the prune it triggers can be observed.
Future<void> _runMigration(
  _Fixture f, {
  required int stored,
  required int target,
}) async {
  final service = PreMigrationBackupService(
    livePathProvider: () async => f.livePath,
    backupsDirProvider: () async => f.backupsDir,
    preferences: f.prefs,
    clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
    idGenerator: () => 'new',
  );
  await service.backupIfMigrationPending(
    stored: stored,
    target: target,
    appVersion: '1.6.0.1241',
  );
}

List<String> _preMigrationIds(_Fixture f) => f.prefs
    .getHistory()
    .where((r) => r.type == BackupType.preMigration)
    .map((r) => r.id)
    .toList();
