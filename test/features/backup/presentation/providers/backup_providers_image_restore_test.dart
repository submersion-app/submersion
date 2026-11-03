import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/post_restore_safety_review.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/test_database.dart';

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

class _ImageRecordingService extends BackupService {
  _ImageRecordingService(BackupPreferences prefs)
    : super(dbAdapter: _NoopAdapter(), preferences: prefs);

  Uint8List? lastBytes;
  RestoreMode? lastMode;
  String? lastSecret;
  Object? error;

  @override
  Future<void> restoreFromImage(
    Uint8List bytes, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
    Future<void> Function()? safetyCopy,
  }) async {
    lastBytes = bytes;
    lastMode = mode;
    lastSecret = encryptionSecret;
    if (error != null) throw error!;
    await safetyCopy?.call();
  }
}

class _NoSweep implements PostRestoreSafetyReview {
  @override
  Future<SafetyReviewSweepResult> run({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async =>
      const SafetyReviewSweepResult(swept: 0, failed: 0, cancelled: false);
}

/// A browser restores from the bytes its picker read (issue #4121), with a
/// copy of its library downloaded first as the stand-in for a file backup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _ImageRecordingService service;
  late int safetyCopies;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = _ImageRecordingService(BackupPreferences(prefs));
    safetyCopies = 0;
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWithValue('en'),
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        backupServiceProvider.overrideWithValue(service),
        postRestoreSafetyReviewProvider.overrideWithValue(_NoSweep()),
        browserSafetyCopyProvider.overrideWithValue(() async => safetyCopies++),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final bytes = Uint8List.fromList([1, 2, 3]);

  test(
    'restores the bytes with the browser safety copy and completes',
    () async {
      final container = makeContainer();

      await container
          .read(backupOperationProvider.notifier)
          .restoreFromImage(bytes, mode: RestoreMode.replace);

      expect(service.lastBytes, bytes);
      expect(service.lastMode, RestoreMode.replace);
      expect(safetyCopies, 1);
      expect(
        container.read(backupOperationProvider).status,
        BackupOperationStatus.restoreComplete,
      );
    },
  );

  test('an encrypted backup hands the passphrase question back', () async {
    final container = makeContainer();
    service.error = const BackupEncryptedException();

    await expectLater(
      container.read(backupOperationProvider.notifier).restoreFromImage(bytes),
      throwsA(isA<BackupEncryptedException>()),
    );
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.idle,
    );
  });

  test('a wrong passphrase reaches the dialog', () async {
    final container = makeContainer();
    service.error = const WrongPassphraseException();

    await expectLater(
      container
          .read(backupOperationProvider.notifier)
          .restoreFromImage(bytes, encryptionSecret: 'nope'),
      throwsA(isA<WrongPassphraseException>()),
    );
    expect(service.lastSecret, 'nope');
  });

  test('any other failure is reported and nothing is restored', () async {
    final container = makeContainer();
    service.error = const BackupException('File is not a valid database');

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromImage(bytes);

    final state = container.read(backupOperationProvider);
    expect(state.status, BackupOperationStatus.error);
    expect(state.message, contains('File is not a valid database'));
  });
}
