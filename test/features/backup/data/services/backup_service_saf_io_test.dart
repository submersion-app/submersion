import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_saf_port.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

/// Adapter whose [databasePath] points at a real file (so size reads work) and
/// whose [backup] copies it, mirroring the production filesystem copy.
class _FileWritingAdapter implements BackupDatabaseAdapter {
  _FileWritingAdapter(this.dbPath);
  final String dbPath;
  int restoreCalls = 0;

  @override
  Future<void> backup(String destinationPath) async {
    final f = File(destinationPath);
    await f.parent.create(recursive: true);
    await File(dbPath).copy(destinationPath);
  }

  @override
  Future<void> restore(String backupPath) async => restoreCalls++;

  @override
  Future<String> get databasePath async => dbPath;

  @override
  AppDatabase get database => throw UnimplementedError();
}

class _FakeSafPort implements BackupSafPort {
  _FakeSafPort({this.validSourcePath});

  /// If set, [readBackup] copies this (valid) DB to the requested temp path.
  final String? validSourcePath;
  String? wroteFrom;

  @override
  Future<String> writeBackup({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  }) async {
    wroteFrom = sourcePath;
    return 'content://tree/doc/$fileName';
  }

  @override
  Future<void> readBackup({
    required String documentUri,
    required String destPath,
  }) async {
    final src = validSourcePath;
    if (src != null) await File(src).copy(destPath);
  }

  @override
  Future<bool> delete(String documentUri) async => true;

  @override
  Future<bool> exists(String documentUri) async => true;

  @override
  Future<String?> resolveTree(String treeUri) async => 'Backups';
}

class _SpySync extends SyncRepository {
  int rebaselineCalls = 0;

  @override
  Future<String> getDeviceId() async => 'live';

  @override
  Future<String?> getLastAcceptedEpochId() async => null;

  @override
  Future<void> rebaselineAfterRestore({
    String? preserveDeviceId,
    String? preserveEpochId,
  }) async => rebaselineCalls++;
}

String _validDb(String dir, String name) {
  final path = '$dir/$name';
  final db = sqlite3.sqlite3.open(path);
  db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
  db.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
  db.dispose();
  return path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackupPreferences prefs;
  late Directory tmp;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = BackupPreferences(await SharedPreferences.getInstance());
    tmp = await Directory.systemTemp.createTemp('saf_io_');
  });
  tearDown(() => tmp.delete(recursive: true));

  test(
    'performBackup to a SAF location writes via the port + records the URI',
    () async {
      final live = _validDb(tmp.path, 'live.db');
      await prefs.setBackupLocation('content://tree/1');
      final port = _FakeSafPort();
      final service = BackupService(
        dbAdapter: _FileWritingAdapter(live),
        preferences: prefs,
        safPort: port,
      );

      final record = await service.performBackup();

      expect(record.localPath, startsWith('content://tree/doc/'));
      expect(record.sizeBytes, greaterThan(0));
      expect(port.wroteFrom, live);
    },
  );

  test(
    'restoreFromBackup streams a SAF backup to a temp file and restores it',
    () async {
      final source = _validDb(tmp.path, 'backup.db');
      final adapter = _FileWritingAdapter(_validDb(tmp.path, 'live.db'));
      final spy = _SpySync();
      final service = BackupService(
        dbAdapter: adapter,
        preferences: prefs,
        safPort: _FakeSafPort(validSourcePath: source),
        syncRepository: spy,
      );

      final record = BackupRecord(
        id: 'r',
        filename: 'restore_me.db',
        timestamp: DateTime(2026),
        sizeBytes: 1,
        location: BackupLocation.local,
        localPath: 'content://tree/doc/x',
      );

      await service.restoreFromBackup(record);

      expect(adapter.restoreCalls, 1);
      expect(spy.rebaselineCalls, 1);
    },
  );

  test('restoreFromBackup throws when the SAF document is gone', () async {
    final port = _FakeSafPort()..wroteFrom = null;
    // exists() returns true in the fake; override via a record whose doc is
    // absent by using a port that reports missing.
    final service = BackupService(
      dbAdapter: _FileWritingAdapter(_validDb(tmp.path, 'live.db')),
      preferences: prefs,
      safPort: _MissingSafPort(),
      syncRepository: _SpySync(),
    );
    final record = BackupRecord(
      id: 'r',
      filename: 'gone.db',
      timestamp: DateTime(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
      localPath: 'content://tree/doc/gone',
    );

    expect(() => service.restoreFromBackup(record), throwsA(isA<Exception>()));
    expect(port.wroteFrom, isNull);
  });
}

class _MissingSafPort extends _FakeSafPort {
  @override
  Future<bool> exists(String documentUri) async => false;
}
