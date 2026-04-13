import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/pre_migration_backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

void main() {
  test('end-to-end: seeds v63 DB, backs up, verifies bytes + record', () async {
    final tmp = await Directory.systemTemp.createTemp('pmbs_int_');
    addTearDown(() => tmp.delete(recursive: true));

    final livePath = p.join(tmp.path, 'submersion.db');
    final backupsDir = p.join(tmp.path, 'backups');
    await Directory(backupsDir).create(recursive: true);

    // Seed a v63 sqlite file with user_version + sentinel data.
    final seed = sqlite3.sqlite3.open(livePath);
    try {
      seed.execute('PRAGMA user_version = 63');
      seed.execute('CREATE TABLE sentinel (id INTEGER PRIMARY KEY)');
      seed.execute('INSERT INTO sentinel VALUES (42)');
    } finally {
      seed.dispose();
    }

    SharedPreferences.setMockInitialValues({});
    final prefs = BackupPreferences(await SharedPreferences.getInstance());

    final service = PreMigrationBackupService(
      livePathProvider: () async => livePath,
      backupsDirProvider: () async => backupsDir,
      preferences: prefs,
      clock: () => DateTime.utc(2026, 4, 12, 8, 12, 1),
      idGenerator: () => 'integration-id',
    );

    await service.backupIfMigrationPending(
      stored: 63,
      target: 64,
      appVersion: '1.6.0.1241',
    );

    // Assert backup .db exists and matches live bytes.
    final backupPath = p.join(backupsDir, '20260412-081201000-v63-v64.db');
    expect(await File(backupPath).exists(), isTrue);
    expect(
      await File(backupPath).readAsBytes(),
      await File(livePath).readAsBytes(),
    );

    // Assert the backup DB itself reads user_version == 63 and sentinel data.
    final verify = sqlite3.sqlite3.open(
      backupPath,
      mode: sqlite3.OpenMode.readOnly,
    );
    try {
      expect(verify.select('PRAGMA user_version').first.values.first, 63);
      expect(verify.select('SELECT id FROM sentinel').first.values.first, 42);
    } finally {
      verify.dispose();
    }

    // Assert the BackupRecord is in the registry with the right shape.
    final records = prefs.getHistory();
    expect(records, hasLength(1));
    expect(records.single.type, BackupType.preMigration);
    expect(records.single.fromSchemaVersion, 63);
    expect(records.single.toSchemaVersion, 64);
  });
}
