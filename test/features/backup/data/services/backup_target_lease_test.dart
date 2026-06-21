import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/backup_bookmark_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/data/services/backup_target.dart';

class _FakeSafPort implements BackupSafPort {
  _FakeSafPort({this.tree});
  final String? tree; // resolveTree result

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
  Future<bool> delete(String documentUri) async => true;

  @override
  Future<bool> exists(String documentUri) async => true;

  @override
  Future<String?> resolveTree(String treeUri) async => tree;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupPreferences preferences;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = BackupPreferences(await SharedPreferences.getInstance());
  });
  tearDown(() => BackupBookmarkService.debugSupportedOverride = null);

  test('content:// location + live grant -> SafBackupTarget', () async {
    await preferences.setBackupLocation('content://tree/1');
    final lease = await BackupService.resolveBackupTargetLeased(
      preferences,
      saf: _FakeSafPort(tree: 'Backups'),
    );
    expect(lease.target, isA<SafBackupTarget>());
    await lease.release();
  });

  test(
    'content:// location + dead grant -> self-heal to filesystem default',
    () async {
      await preferences.setBackupLocation('content://tree/gone');
      final lease = await BackupService.resolveBackupTargetLeased(
        preferences,
        saf: _FakeSafPort(tree: null),
      );
      expect(lease.target, isA<FilesystemBackupTarget>());
      expect(preferences.getSettings().backupLocation, isNull);
    },
  );

  test(
    'filesystem location -> FilesystemBackupTarget (delegates to existing resolver)',
    () async {
      final tmp = await Directory.systemTemp.createTemp('btl_');
      addTearDown(() => tmp.delete(recursive: true));
      await preferences.setBackupLocation(tmp.path);
      BackupBookmarkService.debugSupportedOverride = false;
      final lease = await BackupService.resolveBackupTargetLeased(preferences);
      expect(lease.target, isA<FilesystemBackupTarget>());
    },
  );
}
