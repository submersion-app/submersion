import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backup_target.dart';

class _FakeAdapter implements BackupDatabaseAdapter {
  _FakeAdapter(this.dbPath, {this.exportBytes});
  final String dbPath;

  /// What the export writes when it should differ from the live file, which a
  /// real one always does: it is compacted and it folds in the WAL.
  final String? exportBytes;
  String? copiedTo;

  @override
  Future<void> backup(String destinationPath) async {
    copiedTo = destinationPath;
    final bytes = exportBytes;
    if (bytes != null) {
      await File(destinationPath).writeAsString(bytes);
      return;
    }
    await File(dbPath).copy(destinationPath);
  }

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => dbPath;

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

class _FakeSafPort implements BackupSafPort {
  _FakeSafPort({this.failWrite = false});

  final bool failWrite;
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
    if (failWrite) throw Exception('SAF write failed');
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

      final result = await FilesystemBackupTarget(
        tmp.path,
      ).write(adapter, 'out.db');

      expect(result.ref, p.join(tmp.path, 'out.db'));
      expect(adapter.copiedTo, result.ref);
      expect(File(result.ref).existsSync(), isTrue);
      expect(result.sizeBytes, File(result.ref).lengthSync());
    },
  );

  test(
    'SafBackupTarget streams an exported artifact, never the live DB file',
    () async {
      final tmp = await Directory.systemTemp.createTemp('sbt_');
      addTearDown(() => tmp.delete(recursive: true));
      final live = File(p.join(tmp.path, 'live.db'));
      await live.writeAsString('live database bytes');
      final port = _FakeSafPort();
      final adapter = _FakeAdapter(live.path);

      final result = await SafBackupTarget(
        'content://tree/1',
        port,
        tempDir: () async => tmp,
      ).write(adapter, 'out.db');

      expect(result.ref, 'content://tree/1/doc/out.db');
      expect(port.wroteName, 'out.db');
      // Handing the port the live path streams `<db>` alone: under WAL that
      // omits the committed rows still in the sidecar, and under database
      // password protection it writes ciphertext to a backup that is meant to
      // be portable plaintext.
      expect(port.wroteSource, isNot(live.path));
      expect(adapter.copiedTo, port.wroteSource);
    },
  );

  test(
    'SafBackupTarget reports the artifact size, not the live DB size',
    () async {
      final tmp = await Directory.systemTemp.createTemp('sbt_size_');
      addTearDown(() => tmp.delete(recursive: true));
      final live = File(p.join(tmp.path, 'live.db'));
      // The export is compacted and carries the sidecar's rows, so it is never
      // safe to assume it is the same size as the live file.
      await live.writeAsString('x' * 900);
      final adapter = _FakeAdapter(live.path, exportBytes: 'y' * 40);

      final result = await SafBackupTarget(
        'content://tree/1',
        _FakeSafPort(),
        tempDir: () async => tmp,
      ).write(adapter, 'out.db');

      expect(result.sizeBytes, 40);
    },
  );

  test('SafBackupTarget deletes its staged export afterwards', () async {
    final tmp = await Directory.systemTemp.createTemp('sbt_clean_');
    addTearDown(() => tmp.delete(recursive: true));
    final live = File(p.join(tmp.path, 'live.db'));
    await live.writeAsString('db');
    final port = _FakeSafPort();
    final adapter = _FakeAdapter(live.path);

    await SafBackupTarget(
      'content://tree/1',
      port,
      tempDir: () async => tmp,
    ).write(adapter, 'out.db');

    // A plaintext copy of the whole library must not be left in the temp dir.
    expect(File(port.wroteSource!).existsSync(), isFalse);
  });

  test(
    'SafBackupTarget deletes its staged export when the port fails',
    () async {
      final tmp = await Directory.systemTemp.createTemp('sbt_fail_');
      addTearDown(() => tmp.delete(recursive: true));
      final live = File(p.join(tmp.path, 'live.db'));
      await live.writeAsString('db');
      final port = _FakeSafPort(failWrite: true);
      final adapter = _FakeAdapter(live.path);

      await expectLater(
        SafBackupTarget(
          'content://tree/1',
          port,
          tempDir: () async => tmp,
        ).write(adapter, 'out.db'),
        throwsA(isA<Exception>()),
      );

      expect(adapter.copiedTo, isNotNull);
      expect(File(adapter.copiedTo!).existsSync(), isFalse);
    },
  );

  test(
    'FilesystemBackupTarget.writeSource copies a pre-made file into the dir',
    () async {
      final tmp = await Directory.systemTemp.createTemp('fbt_ws_');
      addTearDown(() => tmp.delete(recursive: true));
      final src = File(p.join(tmp.path, 'src.sbe'));
      await src.writeAsString('ENCRYPTED');

      final ref = await FilesystemBackupTarget(
        tmp.path,
      ).writeSource(src.path, 'backup.sbe');

      expect(ref, p.join(tmp.path, 'backup.sbe'));
      expect(File(ref).readAsStringSync(), 'ENCRYPTED');
    },
  );

  test(
    'SafBackupTarget.writeSource streams the given source via the port',
    () async {
      final port = _FakeSafPort();

      final ref = await SafBackupTarget(
        'content://tree/1',
        port,
      ).writeSource('/tmp/enc.sbe', 'backup.sbe');

      expect(ref, 'content://tree/1/doc/backup.sbe');
      expect(port.wroteSource, '/tmp/enc.sbe');
      expect(port.wroteName, 'backup.sbe');
    },
  );
}
