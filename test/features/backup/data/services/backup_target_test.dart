import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backup_target.dart';

class _FakeAdapter implements BackupDatabaseAdapter {
  _FakeAdapter(this.dbPath);
  final String dbPath;
  String? copiedTo;

  @override
  Future<void> backup(String destinationPath) async {
    copiedTo = destinationPath;
    await File(dbPath).copy(destinationPath);
  }

  @override
  Future<void> restore(String backupPath) async {}

  @override
  Future<String> get databasePath async => dbPath;

  @override
  AppDatabase get database => throw UnimplementedError();
}

class _FakeSafPort implements BackupSafPort {
  String? wroteSource;
  String? wroteName;

  @override
  Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  }) async {
    wroteSource = sourcePath;
    wroteName = fileName;
    return 'content://tree/1/doc/$fileName';
  }

  @override
  Future<void> readBackup({
    required String documentUri,
    required String destPath,
  }) async {}

  @override
  Future<bool> delete(String documentUri) async => true;

  @override
  Future<bool> exists(String documentUri) async => true;

  @override
  Future<String?> resolveTree(String treeUri) async => 'Backups';
}

void main() {
  test('isSafRef detects content URIs', () {
    expect(isSafRef('content://x/y'), isTrue);
    expect(isSafRef('/storage/emulated/0/x.db'), isFalse);
  });

  test(
    'FilesystemBackupTarget delegates to adapter.backup and returns the path',
    () async {
      final tmp = await Directory.systemTemp.createTemp('fbt_');
      addTearDown(() => tmp.delete(recursive: true));
      final src = File(p.join(tmp.path, 'src.db'));
      await src.writeAsString('db');
      final adapter = _FakeAdapter(src.path);

      final ref = await FilesystemBackupTarget(
        tmp.path,
      ).write(adapter, 'out.db');

      expect(ref, p.join(tmp.path, 'out.db'));
      expect(adapter.copiedTo, ref);
      expect(File(ref).existsSync(), isTrue);
    },
  );

  test(
    'SafBackupTarget writes the source DB via the port, returns the doc URI',
    () async {
      final port = _FakeSafPort();
      final adapter = _FakeAdapter('/data/live.db');

      final ref = await SafBackupTarget(
        'content://tree/1',
        port,
      ).write(adapter, 'out.db');

      expect(ref, 'content://tree/1/doc/out.db');
      expect(port.wroteSource, '/data/live.db');
      expect(port.wroteName, 'out.db');
    },
  );
}
