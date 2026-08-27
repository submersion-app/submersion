// Covers the Android SAF export path added for file_picker 12: `saveFile` now
// demands the whole artifact as bytes, which a large dive library cannot
// afford, so the manual export streams into a SAF tree instead.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

class _NoopAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {}

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/noop';

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

/// Hands back a real temp artifact so the test can prove it is streamed and
/// then cleaned up, rather than left behind as a plaintext copy of the library.
class _TempExportingBackupService extends BackupService {
  _TempExportingBackupService(BackupPreferences prefs, this._dir)
    : super(dbAdapter: _NoopAdapter(), preferences: prefs);

  final Directory _dir;
  Object? throwOnExport;
  File? lastTemp;

  @override
  Future<File> exportBackupToTemp() async {
    final error = throwOnExport;
    if (error != null) throw error;
    final f = File('${_dir.path}/submersion_backup_2026-08-16.db');
    await f.writeAsString('library bytes');
    lastTemp = f;
    return f;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const safChannel = MethodChannel('app.submersion/saf');

  late SharedPreferences prefs;
  late Directory tmp;
  late _TempExportingBackupService service;
  late List<MethodCall> safCalls;
  Object? safError;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('backup_saf_export_test');
    service = _TempExportingBackupService(BackupPreferences(prefs), tmp);
    safCalls = [];
    safError = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(safChannel, (call) async {
          safCalls.add(call);
          final error = safError;
          if (error != null) throw error;
          return 'content://tree/doc/42';
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(safChannel, null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        backupServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('streams the artifact into the SAF tree and reports success', () async {
    final container = makeContainer();
    final notifier = container.read(backupOperationProvider.notifier);

    await notifier.exportToSafTree(
      treeUri: 'content://tree/primary%3ABackups',
      fileName: 'submersion_backup_2026-08-16.db',
    );

    expect(safCalls.single.method, 'writeBackup');
    final args = safCalls.single.arguments as Map;
    expect(args['treeUri'], 'content://tree/primary%3ABackups');
    expect(args['fileName'], 'submersion_backup_2026-08-16.db');
    expect(
      args['sourcePath'],
      service.lastTemp!.path,
      reason:
          'the platform channel streams from the temp artifact, so the '
          'library never has to fit in memory',
    );
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.success,
    );
  });

  test('deletes the temp artifact once it has been streamed out', () async {
    final container = makeContainer();

    await container
        .read(backupOperationProvider.notifier)
        .exportToSafTree(treeUri: 'content://tree/x', fileName: 'out.db');

    expect(
      service.lastTemp!.existsSync(),
      isFalse,
      reason:
          'when backup encryption is off the temp copy is plaintext, so '
          'it must never outlive the export',
    );
  });

  test('a failed SAF write surfaces an error and still cleans up', () async {
    safError = PlatformException(code: 'EACCES', message: 'permission revoked');
    final container = makeContainer();

    await container
        .read(backupOperationProvider.notifier)
        .exportToSafTree(treeUri: 'content://tree/x', fileName: 'out.db');

    final state = container.read(backupOperationProvider);
    expect(state.status, BackupOperationStatus.error);
    expect(state.message, contains('Export failed'));
    expect(
      service.lastTemp!.existsSync(),
      isFalse,
      reason: 'the finally block runs on the failure path too',
    );
  });

  test('a failed export never reaches the platform channel', () async {
    service.throwOnExport = StateError('database locked');
    final container = makeContainer();

    await container
        .read(backupOperationProvider.notifier)
        .exportToSafTree(treeUri: 'content://tree/x', fileName: 'out.db');

    expect(safCalls, isEmpty);
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.error,
    );
  });

  test('declines to start while another operation is in progress', () async {
    final container = makeContainer();
    final notifier = container.read(backupOperationProvider.notifier);

    // Drive it into the in-progress state the guard checks.
    final first = notifier.exportToSafTree(
      treeUri: 'content://tree/x',
      fileName: 'first.db',
    );
    await notifier.exportToSafTree(
      treeUri: 'content://tree/x',
      fileName: 'second.db',
    );
    await first;

    expect(safCalls.map((c) => (c.arguments as Map)['fileName']), [
      'first.db',
    ], reason: 'the second call must bail out rather than interleave');
  });
}
