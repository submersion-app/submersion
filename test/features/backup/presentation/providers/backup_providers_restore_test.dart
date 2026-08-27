import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/post_restore_safety_review.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/test_database.dart';

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

/// Records restore invocations so the notifier's threading of [RestoreMode]
/// and its post-restore fix-ups can be asserted without real file IO.
class _RecordingBackupService extends BackupService {
  final List<String> calls = [];
  RestoreMode? lastMode;
  String? lastSecret;

  /// When true, restore throws [BackupEncryptedException] UNLESS a secret is
  /// supplied -- modelling the "encrypted artifact needs a passphrase" path.
  bool requireSecret = false;

  /// The only secret that unlocks; any other non-null secret throws
  /// [WrongPassphraseException], modelling a wrong passphrase on retry.
  String? correctSecret;

  /// When set, restore awaits this before returning, so a test can observe the
  /// in-flight (mid-restore) state.
  Completer<void>? restoreGate;

  /// When set, restore fires the caller's onMigrationProgress with these
  /// (currentStep, totalSteps) values, modelling an older-schema backup whose
  /// post-swap reopen runs the migration ladder.
  (int, int)? migrationProgressToEmit;

  _RecordingBackupService(BackupPreferences prefs)
    : super(dbAdapter: _NoopAdapter(), preferences: prefs);

  void _gate(String? secret) {
    if (requireSecret && secret == null) {
      throw const BackupEncryptedException();
    }
    if (correctSecret != null && secret != null && secret != correctSecret) {
      throw const WrongPassphraseException();
    }
  }

  @override
  Future<BackupValidationResult> validateBackupFile(
    String filePath, {
    bool allowLiveDatabaseEncryption = false,
  }) async => const BackupValidationResult.valid(sizeBytes: 1);

  @override
  Future<void> restoreFromBackup(
    BackupRecord record, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async {
    calls.add('restoreFromBackup');
    lastMode = mode;
    lastSecret = encryptionSecret;
    _gate(encryptionSecret);
    final progress = migrationProgressToEmit;
    if (progress != null) onMigrationProgress?.call(progress.$1, progress.$2);
    if (restoreGate != null) await restoreGate!.future;
  }

  @override
  Future<void> restoreFromFile(
    String filePath, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async {
    calls.add('restoreFromFile');
    lastMode = mode;
    lastSecret = encryptionSecret;
    _gate(encryptionSecret);
    final progress = migrationProgressToEmit;
    if (progress != null) onMigrationProgress?.call(progress.$1, progress.$2);
  }
}

/// Stands in for the real post-restore sweep so the notifier can be exercised
/// without building a second provider graph.
class _FakePostRestoreSafetyReview implements PostRestoreSafetyReview {
  int calls = 0;
  bool throwOnRun = false;

  /// Progress pairs emitted before returning.
  List<(int, int)> emit = const [];

  /// Captured so a test can assert the notifier's skip flag reaches the sweep.
  bool Function()? capturedIsCancelled;

  @override
  Future<SafetyReviewSweepResult> run({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    calls++;
    capturedIsCancelled = isCancelled;
    if (throwOnRun) throw StateError('sweep exploded');
    for (final (done, total) in emit) {
      onProgress?.call(done, total);
    }
    return SafetyReviewSweepResult(
      swept: emit.isEmpty ? 0 : emit.last.$1,
      failed: 0,
      cancelled: isCancelled?.call() ?? false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _RecordingBackupService service;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = _RecordingBackupService(BackupPreferences(prefs));
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  ProviderContainer makeContainer({
    bool overrideService = true,
    PostRestoreSafetyReview? sweep,
  }) {
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWithValue('en'),
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(null),
        if (overrideService) backupServiceProvider.overrideWithValue(service),
        // Default to a no-op sweep so the pre-existing restore tests never
        // build the real one (which would open a second provider container
        // against the test database).
        postRestoreSafetyReviewProvider.overrideWithValue(
          sweep ?? _FakePostRestoreSafetyReview(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A throwaway backup file for the restoreFromFilePath entry point.
  Future<String> tempBackupPath(String tag) async {
    final tmp = File(
      '${Directory.systemTemp.path}/notifier_restore_${tag}_'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await tmp.writeAsString('db');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete();
    });
    return tmp.path;
  }

  test('restoreFromFilePath threads the mode and completes', () async {
    final container = makeContainer();
    final tmp = File(
      '${Directory.systemTemp.path}/notifier_restore_'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await tmp.writeAsString('db');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete();
    });

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(tmp.path, mode: RestoreMode.replace);

    expect(service.calls, ['restoreFromFile']);
    expect(service.lastMode, RestoreMode.replace);
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test('migration progress surfaces in the operation state message', () async {
    // An older-schema backup runs the migration ladder during the post-swap
    // reopen. The barrier renders the operation message, so each ladder step
    // must land there — otherwise a long upgrade is a silent stall.
    final container = makeContainer();
    service.migrationProgressToEmit = (3, 7);
    final messages = <String?>[];
    container.listen(
      backupOperationProvider,
      (_, next) => messages.add(next.message),
    );
    final tmp = File(
      '${Directory.systemTemp.path}/notifier_restore_migration_'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await tmp.writeAsString('db');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete();
    });

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(tmp.path);

    expect(messages, contains('Upgrading database (step 3 of 7)...'));
    // The restore still finishes normally after progress updates.
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test(
    'restore arms isRestoring while in flight and clears it on complete',
    () async {
      final container = makeContainer();
      final gate = Completer<void>();
      service.restoreGate = gate;
      final record = BackupRecord(
        id: 'r-gate',
        filename: 'b.db',
        timestamp: DateTime(2026),
        sizeBytes: 1,
        location: BackupLocation.local,
      );

      // Kick off the restore but do not await it: the notifier sets the
      // in-progress state synchronously before the first await.
      final future = container
          .read(backupOperationProvider.notifier)
          .restoreFromBackup(record);

      // Mid-restore: the global barrier flag is armed (routine backups never
      // arm it -- only restore does).
      final midState = container.read(backupOperationProvider);
      expect(midState.isRestoring, isTrue);
      expect(midState.status, BackupOperationStatus.inProgress);

      gate.complete();
      await future;

      // Completed: the flag is cleared and the app hands off to
      // RestoreCompletePage via the restoreComplete status.
      final doneState = container.read(backupOperationProvider);
      expect(doneState.isRestoring, isFalse);
      expect(doneState.status, BackupOperationStatus.restoreComplete);
    },
  );

  test('restoreFromBackup threads the mode and completes', () async {
    final container = makeContainer();
    final record = BackupRecord(
      id: 'r1',
      filename: 'b.db',
      timestamp: DateTime(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
    );

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromBackup(record);

    expect(service.calls, ['restoreFromBackup']);
    expect(service.lastMode, RestoreMode.merge);
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test(
    'realignActiveDiverAfterDataReplace persists the active diver',
    () async {
      // The restored settings table names no active diver and no default
      // diver exists, so the helper leaves prefs untouched -- but must not
      // throw against a fresh database.
      await realignActiveDiverAfterDataReplace(prefs);
      expect(prefs.getString(currentDiverIdKey), isNull);
    },
  );

  test('backupServiceProvider wires the epoch store', () {
    final container = makeContainer(overrideService: false);
    final built = container.read(backupServiceProvider);
    expect(built, isA<BackupService>());
  });

  test('restoreFromFilePath rethrows BackupEncryptedException and resets '
      'to idle so the page can prompt', () async {
    service.requireSecret = true;
    final container = makeContainer();
    final tmp = File(
      '${Directory.systemTemp.path}/notifier_enc_'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await tmp.writeAsString('db');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete();
    });

    await expectLater(
      container
          .read(backupOperationProvider.notifier)
          .restoreFromFilePath(tmp.path),
      throwsA(isA<BackupEncryptedException>()),
    );
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.idle,
    );

    // Retrying with a secret succeeds and threads it to the service.
    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(tmp.path, encryptionSecret: 'pw');
    expect(service.lastSecret, 'pw');
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test('restoreFromFilePath rethrows WrongPassphraseException and resets to '
      'idle so the passphrase dialog can show the inline error', () async {
    service
      ..requireSecret = true
      ..correctSecret = 'right';
    final container = makeContainer();
    final tmp = File(
      '${Directory.systemTemp.path}/notifier_wrongpw_'
      '${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await tmp.writeAsString('db');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete();
    });

    // A wrong secret must propagate (not become an error state), so the
    // dialog stays open with its inline error instead of closing on success.
    await expectLater(
      container
          .read(backupOperationProvider.notifier)
          .restoreFromFilePath(tmp.path, encryptionSecret: 'wrong'),
      throwsA(isA<WrongPassphraseException>()),
    );
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.idle,
    );

    // The correct secret then completes the restore.
    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(tmp.path, encryptionSecret: 'right');
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test('restoreFromBackup rethrows WrongPassphraseException and resets to '
      'idle', () async {
    service
      ..requireSecret = true
      ..correctSecret = 'right';
    final container = makeContainer();
    final record = BackupRecord(
      id: 'enc2',
      filename: 'b.sbe',
      timestamp: DateTime(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
    );

    await expectLater(
      container
          .read(backupOperationProvider.notifier)
          .restoreFromBackup(record, encryptionSecret: 'wrong'),
      throwsA(isA<WrongPassphraseException>()),
    );
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.idle,
    );
  });

  test('restoreFromBackup rethrows BackupEncryptedException and resets '
      'to idle', () async {
    service.requireSecret = true;
    final container = makeContainer();
    final record = BackupRecord(
      id: 'enc',
      filename: 'b.sbe',
      timestamp: DateTime(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
    );

    await expectLater(
      container
          .read(backupOperationProvider.notifier)
          .restoreFromBackup(record),
      throwsA(isA<BackupEncryptedException>()),
    );
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.idle,
    );

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromBackup(record, encryptionSecret: 'pw');
    expect(service.lastSecret, 'pw');
  });

  test('copyWith preserves sweep progress unless asked to clear it', () {
    const state = BackupOperationState(
      status: BackupOperationStatus.inProgress,
      isRestoring: true,
      sweepProgress: SafetyReviewSweepProgress(done: 3, total: 10),
    );

    // An unrelated copyWith must not blank an in-flight sweep.
    final touched = state.copyWith(message: 'something else');
    expect(touched.sweepProgress, isNotNull);
    expect(touched.sweepProgress!.done, 3);

    expect(state.copyWith(clearSweepProgress: true).sweepProgress, isNull);
    expect(
      state
          .copyWith(
            sweepProgress: const SafetyReviewSweepProgress(done: 4, total: 10),
          )
          .sweepProgress!
          .done,
      4,
    );
  });

  test('a restore runs the post-restore safety sweep', () async {
    final sweep = _FakePostRestoreSafetyReview();
    final container = makeContainer(sweep: sweep);

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(await tempBackupPath('sweep'));

    expect(sweep.calls, 1);
    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
    );
  });

  test('restoreFromBackup runs the sweep too', () async {
    final sweep = _FakePostRestoreSafetyReview();
    final container = makeContainer(sweep: sweep);
    final record = BackupRecord(
      id: 'r1',
      filename: 'b.db',
      timestamp: DateTime(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
    );

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromBackup(record);

    expect(sweep.calls, 1);
  });

  test('sweep progress is published while the barrier is still up', () async {
    final sweep = _FakePostRestoreSafetyReview()..emit = const [(0, 2), (1, 2)];
    final container = makeContainer(sweep: sweep);

    final seen = <BackupOperationState>[];
    final sub = container.listen(
      backupOperationProvider,
      (_, next) => seen.add(next),
    );
    addTearDown(sub.close);

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(await tempBackupPath('progress'));

    final published = seen
        .where((s) => s.sweepProgress != null)
        .map((s) => s.sweepProgress!)
        .toList();
    expect(published, isNotEmpty);
    expect(published.last.done, 1);
    expect(published.last.total, 2);
    // The barrier must stay up for the whole sweep, or the user could touch
    // the database while it is being analyzed.
    expect(
      seen.where((s) => s.sweepProgress != null).every((s) => s.isRestoring),
      isTrue,
    );
  });

  test('a sweep failure still completes the restore', () async {
    final sweep = _FakePostRestoreSafetyReview()..throwOnRun = true;
    final container = makeContainer(sweep: sweep);

    await container
        .read(backupOperationProvider.notifier)
        .restoreFromFilePath(await tempBackupPath('boom'));

    expect(
      container.read(backupOperationProvider).status,
      BackupOperationStatus.restoreComplete,
      reason: 'the data restore already succeeded; the sweep is a convenience',
    );
  });

  test('skipSafetyReviewSweep is visible to the running sweep', () async {
    final sweep = _FakePostRestoreSafetyReview();
    final container = makeContainer(sweep: sweep);

    final notifier = container.read(backupOperationProvider.notifier);
    await notifier.restoreFromFilePath(await tempBackupPath('skip'));

    expect(sweep.capturedIsCancelled, isNotNull);
    expect(sweep.capturedIsCancelled!(), isFalse);
    notifier.skipSafetyReviewSweep();
    expect(sweep.capturedIsCancelled!(), isTrue);
  });

  test('backup encryption providers wire their real dependencies', () async {
    final container = makeContainer(overrideService: false);
    // Reading the real provider bodies constructs each service with its
    // injected key store (issue #580 wiring).
    expect(container.read(backupEncryptionKeyStoreProvider), isNotNull);
    expect(container.read(backupEncryptionServiceProvider), isNotNull);
    expect(container.read(backupServiceProvider), isNotNull);
  });
}
