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
      'keeps newest 3 unpinned pre-migration backups, deletes older',
      () async {
        final f = await _makeFixture();
        addTearDown(f.dispose);
        for (var i = 0; i < 4; i++) {
          final ts = DateTime.utc(2026, 1, 1 + i);
          final name = '${_ts(ts)}-v$i-v${i + 1}.db';
          final file = File(p.join(f.backupsDir, name));
          await file.writeAsBytes([i]);
          await f.prefs.addRecord(
            BackupRecord(
              id: 'r$i',
              filename: name,
              timestamp: ts,
              sizeBytes: 1,
              location: BackupLocation.local,
              localPath: file.path,
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
          clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
          idGenerator: () => 'new',
        );

        await service.backupIfMigrationPending(
          stored: 63,
          target: 64,
          appVersion: '1.6.0.1241',
        );

        final remaining = f.prefs
            .getHistory()
            .where((r) => r.type == BackupType.preMigration)
            .toList();
        expect(remaining, hasLength(3));
        expect(
          remaining.map((r) => r.id),
          containsAll(<String>['new', 'r3', 'r2']),
        );
        expect(remaining.map((r) => r.id), isNot(contains('r0')));
        expect(remaining.map((r) => r.id), isNot(contains('r1')));
        expect(
          await File(
            p.join(f.backupsDir, '${_ts(DateTime.utc(2026, 1, 1))}-v0-v1.db'),
          ).exists(),
          isFalse,
        );
        expect(
          await File(
            p.join(f.backupsDir, '${_ts(DateTime.utc(2026, 1, 2))}-v1-v2.db'),
          ).exists(),
          isFalse,
        );
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
