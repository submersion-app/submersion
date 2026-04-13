import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

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

      const expectedName = '20260412-081201-v63-v64.db';
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
        expect(record.filename, '20260412-081201-v63-v64.db');
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
}
