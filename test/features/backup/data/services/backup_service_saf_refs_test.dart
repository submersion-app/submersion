import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

import '../../../../helpers/mock_channels.dart';

class _NoopAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {}

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/data/live.db';

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

class _RecordingSafPort implements BackupSafPort {
  final List<String> deleted = [];
  final Set<String> existing = {};

  @override
  Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  }) async => 'content://doc';

  @override
  Future<void> readBackup({
    required String documentUri,
    required String destPath,
  }) async {}

  @override
  Future<bool> delete(String documentUri) async {
    deleted.add(documentUri);
    return true;
  }

  @override
  Future<bool> exists(String documentUri) async =>
      existing.contains(documentUri);

  @override
  Future<String?> resolveTree(String treeUri) async => 'Backups';
}

BackupRecord _saf(String id, String uri) => BackupRecord(
  id: id,
  filename: 'f.db',
  timestamp: DateTime(2026),
  sizeBytes: 1,
  location: BackupLocation.local,
  diveCount: 0,
  siteCount: 0,
  localPath: uri,
);

/// Per-file temp root, so the backup service's fixed `Submersion/Backups`
/// subtree does not collide with the other suites that mock path_provider the
/// same way. `flutter test` runs files in parallel isolates against one real
/// $TMPDIR, so sharing it let one suite truncate or encrypt another's artifact
/// mid-assert.
final _isolatedTempDir = Directory.systemTemp.createTempSync('saf_refs_pp_');

void main() {
  tearDownAll(() {
    if (_isolatedTempDir.existsSync()) {
      _isolatedTempDir.deleteSync(recursive: true);
    }
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupPreferences prefs;
  late _RecordingSafPort port;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => _isolatedTempDir.path,
        );
  });
  tearDownAll(clearPathAndShareChannelMocks);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = BackupPreferences(await SharedPreferences.getInstance());
    port = _RecordingSafPort();
  });

  BackupService service() => BackupService(
    dbAdapter: _NoopAdapter(),
    preferences: prefs,
    safPort: port,
  );

  test('deleteBackup routes a SAF ref to the port', () async {
    final r = _saf('1', 'content://doc/1');
    await prefs.addRecord(r);
    await service().deleteBackup(r);
    expect(port.deleted, ['content://doc/1']);
  });

  test(
    'getValidatedBackupHistory keeps a SAF record whose doc still exists',
    () async {
      port.existing.add('content://doc/keep');
      await prefs.addRecord(_saf('keep', 'content://doc/keep'));
      await prefs.addRecord(_saf('gone', 'content://doc/gone'));
      final valid = await service().getValidatedBackupHistory();
      expect(valid.map((r) => r.id), ['keep']);
    },
  );

  test('deleteBackup removes a filesystem-path backup file', () async {
    final tmp = await Directory.systemTemp.createTemp('del_fs_');
    addTearDown(() => tmp.delete(recursive: true));
    final file = File('${tmp.path}/b.db');
    await file.writeAsString('x');
    final r = _saf('fs', file.path);
    await prefs.addRecord(r);

    await service().deleteBackup(r);

    expect(file.existsSync(), isFalse);
    expect(port.deleted, isEmpty); // filesystem path must not route to SAF
  });
}
