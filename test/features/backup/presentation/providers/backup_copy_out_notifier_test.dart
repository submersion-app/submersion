// Share and Save for an existing backup from the history (issue #3650): the
// operation state they drive, where the copy lands, and what is cleaned up.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_copy_guard.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

class _NoopAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath, {String? note}) async {}

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

/// Hands back a prepared file the test controls.
class _PreparingService extends BackupService {
  _PreparingService(BackupPreferences prefs)
    : super(dbAdapter: _NoopAdapter(), preferences: prefs);

  PreparedBackupFile? next;
  Object? error;

  /// When set, a prepare waits for it: a download still running.
  Completer<void>? hold;
  int calls = 0;
  BackupCopyPurpose? lastPurpose;

  @override
  Future<PreparedBackupFile> prepareBackupCopy(
    BackupRecord record, {
    required BackupCopyPurpose purpose,
  }) async {
    calls++;
    lastPurpose = purpose;
    await hold?.future;
    final e = error;
    if (e != null) throw e;
    return next!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const safChannel = MethodChannel('app.submersion/saf');

  late SharedPreferences prefs;
  late Directory tmp;
  late _PreparingService service;
  late List<MethodCall> safCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmp = await Directory.systemTemp.createTemp('copy_out_notifier_');
    service = _PreparingService(BackupPreferences(prefs));
    safCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(safChannel, (call) async {
          safCalls.add(call);
          return 'content://tree/doc/9';
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

  final record = BackupRecord(
    id: 'r1',
    filename: 'submersion_backup_2026-10-27.db',
    timestamp: DateTime(2026, 10, 27, 19, 42),
    sizeBytes: 3,
    location: BackupLocation.cloud,
    cloudFileId: 'f1',
  );

  Future<File> tempCopy(String name) async {
    final dir = await Directory(p.join(tmp.path, 'temp')).create();
    final f = File(p.join(dir.path, name));
    await f.writeAsBytes([7, 8, 9]);
    // As the service does: the temp copy goes out under the backup's name.
    service.next = PreparedBackupFile(
      f.path,
      isTemp: true,
      fileName: record.filename,
    );
    return f;
  }

  group('prepareBackupForSharing', () {
    test('returns the file and ends in success', () async {
      final copy = await tempCopy(record.filename);
      final container = makeContainer();

      final file = await container
          .read(backupOperationProvider.notifier)
          .prepareBackupForSharing(record);

      expect(file!.path, copy.path);
      expect(service.lastPurpose, BackupCopyPurpose.share);
      expect(
        container.read(backupOperationProvider).status,
        BackupOperationStatus.success,
      );
      expect(
        copy.existsSync(),
        isTrue,
        reason: 'the receiving app may read it only when the diver sends',
      );
    });

    test('is a no-op while busy', () async {
      await tempCopy(record.filename);
      service.hold = Completer<void>();
      final container = makeContainer();
      final notifier = container.read(backupOperationProvider.notifier);

      // A second tap while the first share is still downloading.
      final first = notifier.prepareBackupForSharing(record);
      expect(await notifier.prepareBackupForSharing(record), isNull);
      expect(service.calls, 1);

      service.hold!.complete();
      expect(await first, isNotNull);
    });

    test('maps another account to the copyInOtherAccount message', () async {
      service.error = const BackupCopyInOtherAccountException('theirs');
      final container = makeContainer();

      final file = await container
          .read(backupOperationProvider.notifier)
          .prepareBackupForSharing(record);

      final state = container.read(backupOperationProvider);
      expect(file, isNull);
      expect(state.status, BackupOperationStatus.error);
      expect(state.message, contains('in another account'));
    });

    test('maps other errors to exportFailed', () async {
      service.error = const BackupException('gone');
      final container = makeContainer();

      await container
          .read(backupOperationProvider.notifier)
          .prepareBackupForSharing(record);

      final state = container.read(backupOperationProvider);
      expect(state.status, BackupOperationStatus.error);
      expect(state.message, startsWith('Export failed'));
    });
  });

  group('saveBackupCopyToDirectory', () {
    test('copies and discards the temp copy', () async {
      final copy = await tempCopy('restore-x-${record.filename}');
      final dest = await Directory(p.join(tmp.path, 'dest')).create();
      final container = makeContainer();

      await container
          .read(backupOperationProvider.notifier)
          .saveBackupCopyToDirectory(record, dest.path);

      final saved = File(p.join(dest.path, record.filename));
      expect(await saved.readAsBytes(), [7, 8, 9]);
      expect(copy.existsSync(), isFalse);
      expect(service.lastPurpose, BackupCopyPurpose.save);
      final state = container.read(backupOperationProvider);
      expect(state.status, BackupOperationStatus.success);
      expect(state.message, startsWith('Backup exported'));
      expect(BackupPreferences(prefs).getHistory(), isEmpty);
    });

    test('names the saved copy from the prepared file', () async {
      // A cloud copy that came back as an encrypted envelope under a .db
      // record name is saved as .sbe.
      final copy = await tempCopy('restore-x-${record.filename}');
      service.next = PreparedBackupFile(
        copy.path,
        isTemp: true,
        fileName: 'submersion_backup_2026-10-27.sbe',
      );
      final dest = await Directory(p.join(tmp.path, 'dest')).create();
      final container = makeContainer();

      await container
          .read(backupOperationProvider.notifier)
          .saveBackupCopyToDirectory(record, dest.path);

      expect(
        File(
          p.join(dest.path, 'submersion_backup_2026-10-27.sbe'),
        ).existsSync(),
        isTrue,
      );
    });

    test('save into the source folder never overwrites the source', () async {
      final source = File(p.join(tmp.path, record.filename));
      await source.writeAsBytes([1, 1, 1]);
      service.next = PreparedBackupFile(source.path, isTemp: false);
      final container = makeContainer();

      await container
          .read(backupOperationProvider.notifier)
          .saveBackupCopyToDirectory(record, tmp.path);

      expect(await source.readAsBytes(), [1, 1, 1]);
      expect(
        File(
          p.join(tmp.path, 'submersion_backup_2026-10-27 (1).db'),
        ).existsSync(),
        isTrue,
      );
    });

    test('discards the temp copy on failure', () async {
      final copy = await tempCopy('restore-x-${record.filename}');
      final container = makeContainer();

      await container
          .read(backupOperationProvider.notifier)
          .saveBackupCopyToDirectory(record, p.join(tmp.path, 'missing'));

      expect(
        container.read(backupOperationProvider).status,
        BackupOperationStatus.error,
      );
      expect(copy.existsSync(), isFalse);
    });
  });

  group('saveBackupCopyToSafTree', () {
    test(
      'writes with replaceExisting false and discards the temp copy',
      () async {
        final copy = await tempCopy('restore-x-${record.filename}');
        final container = makeContainer();

        await container
            .read(backupOperationProvider.notifier)
            .saveBackupCopyToSafTree(record, 'content://tree/primary%3ADocs');

        final args = safCalls.single.arguments as Map;
        expect(safCalls.single.method, 'writeBackup');
        expect(args['treeUri'], 'content://tree/primary%3ADocs');
        expect(args['fileName'], record.filename);
        expect(args['sourcePath'], copy.path);
        expect(args['replaceExisting'], isFalse);
        expect(copy.existsSync(), isFalse);
        expect(
          container.read(backupOperationProvider).status,
          BackupOperationStatus.success,
        );
        expect(BackupPreferences(prefs).getHistory(), isEmpty);
      },
    );
  });
}
