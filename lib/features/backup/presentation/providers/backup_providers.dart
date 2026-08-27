import 'dart:async';
import 'dart:io';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';
import 'package:submersion/features/backup/data/services/backup_encryption_service.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;
import 'package:submersion/features/backup/domain/exceptions/backup_encrypted_exception.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/features/backup/presentation/providers/post_restore_safety_review.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion_saf/submersion_saf.dart';

// =============================================================================
// Repository & Service Providers
// =============================================================================

/// Backup preferences (SharedPreferences wrapper)
final backupPreferencesProvider = Provider<BackupPreferences>((ref) {
  return BackupPreferences(ref.watch(sharedPreferencesProvider));
});

/// Backup service with all dependencies injected
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    dbAdapter: DefaultBackupDatabaseAdapter(DatabaseService.instance),
    preferences: ref.watch(backupPreferencesProvider),
    cloudProvider: ref.watch(cloudStorageProviderProvider),
    epochStore: LibraryEpochStore(ref.watch(sharedPreferencesProvider)),
    postRestoreSyncStore: PostRestoreSyncStore(
      ref.watch(sharedPreferencesProvider),
    ),
    encryptionKeyStore: ref.watch(encryptionKeyStoreProvider),
    syncPreferences: ref.watch(syncPreferencesProvider),
    backupEncryptionKeyStore: ref.watch(backupEncryptionKeyStoreProvider),
  );
});

/// Backup-encryption key custody (issue #580), independent of sync encryption.
final backupEncryptionKeyStoreProvider = Provider<BackupEncryptionKeyStore>((
  ref,
) {
  return BackupEncryptionKeyStore();
});

/// Backup-encryption key lifecycle (enable / change / regenerate).
final backupEncryptionServiceProvider = Provider<BackupEncryptionService>((
  ref,
) {
  return BackupEncryptionService(
    keyStore: ref.watch(backupEncryptionKeyStoreProvider),
  );
});

// =============================================================================
// Settings
// =============================================================================

/// Notifier for backup settings (enabled, frequency, retention, cloud)
class BackupSettingsNotifier extends StateNotifier<BackupSettings> {
  final BackupPreferences _prefs;

  BackupSettingsNotifier(this._prefs) : super(_prefs.getSettings());

  Future<void> setEnabled(bool value) async {
    await _prefs.setEnabled(value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setBackupEncryptionEnabled(bool value) async {
    await _prefs.setBackupEncryptionEnabled(value);
    state = state.copyWith(backupEncryptionEnabled: value);
  }

  Future<void> setFrequency(BackupFrequency frequency) async {
    await _prefs.setFrequency(frequency);
    state = state.copyWith(frequency: frequency);
  }

  Future<void> setRetentionCount(int count) async {
    await _prefs.setRetentionCount(count);
    state = state.copyWith(retentionCount: count);
  }

  /// Cloud backup and a custom backup location are mutually exclusive
  /// destinations: enabling cloud backup reverts the location to the
  /// default, and choosing a custom location turns cloud backup off.
  ///
  /// The two keys are persisted in separate awaited steps, so the conflicting
  /// key is always cleared BEFORE the new one is set. That way a crash between
  /// the writes can only leave a "both off" state, never the invalid "cloud
  /// backup on + custom location set" combination.
  Future<void> setCloudBackupEnabled(bool value) async {
    if (value) await _prefs.setBackupLocation(null);
    await _prefs.setCloudBackupEnabled(value);
    state = _prefs.getSettings();
  }

  Future<void> setBackupLocation(String? path) async {
    if (path != null) await _prefs.setCloudBackupEnabled(false);
    await _prefs.setBackupLocation(path);
    state = _prefs.getSettings();
  }

  /// Sets a custom backup location together with its security-scoped bookmark
  /// (Apple platforms). The bookmark is what lets the location survive an app
  /// restart; a null bookmark is fine on desktop, where bare paths persist.
  ///
  /// Like [setBackupLocation], choosing a custom location turns cloud backup
  /// off -- the conflicting cloud key is cleared before the location is set.
  Future<void> setBackupLocationWithBookmark(
    String path,
    List<int>? bookmark,
  ) async {
    await _prefs.setCloudBackupEnabled(false);
    await _prefs.setBackupLocation(path);
    await _prefs.setBackupLocationBookmark(bookmark);
    state = _prefs.getSettings();
  }

  /// Android SAF: persist a `content://` tree URI as the location plus its human
  /// label for display. Turns cloud backup off, like any custom location.
  Future<void> setSafBackupLocation(String uri, String label) async {
    await _prefs.setCloudBackupEnabled(false);
    await _prefs.setBackupLocation(uri);
    await _prefs.setBackupLocationLabel(label);
    state = _prefs.getSettings();
  }

  /// Display label for a custom location (e.g. the SAF folder name), or null.
  String? get locationLabel => _prefs.backupLocationLabel;

  /// Sign-out hook: cloud sync is being disabled, so cloud backup loses its
  /// destination. Resets the location to default only when cloud backup was
  /// actually on -- an unrelated custom location is none of sync's business.
  Future<void> disableCloudBackup() async {
    if (!state.cloudBackupEnabled) return;
    await _prefs.setCloudBackupEnabled(false);
    await _prefs.setBackupLocation(null);
    state = _prefs.getSettings();
  }

  /// Refresh state from SharedPreferences (e.g. after a backup updates lastBackupTime)
  void refresh() {
    state = _prefs.getSettings();
  }
}

final backupSettingsProvider =
    StateNotifierProvider<BackupSettingsNotifier, BackupSettings>((ref) {
      return BackupSettingsNotifier(ref.watch(backupPreferencesProvider));
    });

// =============================================================================
// Operation State
// =============================================================================

/// Status of a backup operation
enum BackupOperationStatus { idle, inProgress, success, restoreComplete, error }

/// Progress of the whole-library safety review sweep that runs at the end of a
/// restore. Structured rather than a pre-formatted string so the restore
/// barrier can render it in the user's language.
class SafetyReviewSweepProgress {
  final int done;
  final int total;

  const SafetyReviewSweepProgress({required this.done, required this.total});
}

/// State for backup/restore operations
class BackupOperationState {
  final BackupOperationStatus status;
  final String? message;
  final BackupRecord? lastRecord;

  /// True only while a database *restore* is running (a subset of the
  /// [BackupOperationStatus.inProgress] states). Restore briefly closes and
  /// reopens the database, so the whole app must be blocked from interaction
  /// until it finishes — but routine backups/exports/deletes, which also use
  /// `inProgress`, must NOT block the app. The global restore barrier keys off
  /// this flag, not `status`.
  final bool isRestoring;

  /// Non-null only while the post-restore safety sweep is running.
  final SafetyReviewSweepProgress? sweepProgress;

  const BackupOperationState({
    this.status = BackupOperationStatus.idle,
    this.message,
    this.lastRecord,
    this.isRestoring = false,
    this.sweepProgress,
  });

  /// [clearSweepProgress] separates "leave the sweep progress alone" from
  /// "clear it". Omitting [sweepProgress] means unchanged, matching every other
  /// field, so an unrelated `copyWith` cannot silently blank an in-flight
  /// sweep; pass `clearSweepProgress: true` to actually null it out.
  BackupOperationState copyWith({
    BackupOperationStatus? status,
    String? message,
    BackupRecord? lastRecord,
    bool? isRestoring,
    SafetyReviewSweepProgress? sweepProgress,
    bool clearSweepProgress = false,
  }) {
    return BackupOperationState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastRecord: lastRecord ?? this.lastRecord,
      isRestoring: isRestoring ?? this.isRestoring,
      sweepProgress: clearSweepProgress
          ? null
          : (sweepProgress ?? this.sweepProgress),
    );
  }
}

/// Notifier managing backup/restore/delete operations with state transitions
class BackupOperationNotifier extends StateNotifier<BackupOperationState> {
  final Ref _ref;
  final _log = LoggerService.forClass(BackupOperationNotifier);
  Timer? _desktopBackupTimer;
  bool _sweepSkipped = false;

  BackupOperationNotifier(this._ref) : super(const BackupOperationState()) {
    _startDesktopTimerIfNeeded();
  }

  /// Localizations for the operation messages this notifier publishes.
  ///
  /// A provider has no BuildContext, so the persisted locale setting is
  /// resolved through the same helper SyncNotifier uses. This is the string
  /// half of what [SafetyReviewSweepProgress] already does structurally.
  AppLocalizations get _l10n => l10nForLocaleTag(_ref.read(localeProvider));

  BackupService get _service => _ref.read(backupServiceProvider);

  /// After a restore, realign the active diver from the restored database's
  /// Settings table (shared with the sync library adoption flow).
  Future<void> _syncActiveDiverAfterRestore() async {
    await realignActiveDiverAfterDataReplace(
      _ref.read(sharedPreferencesProvider),
    );
  }

  /// Stops the post-restore safety sweep at the next dive boundary.
  ///
  /// Lossless: unswept dives still compute lazily when opened, and
  /// Settings > Safety > "Analyze all dives" remains available.
  void skipSafetyReviewSweep() {
    _sweepSkipped = true;
  }

  /// Analyze the restored library so safety findings and dive-list badges are
  /// present immediately, instead of only after each dive is opened.
  ///
  /// Deliberately cannot fail the restore: by the time this runs the database
  /// swap and the sync re-baseline have already succeeded, so a sweep error is
  /// logged and swallowed rather than turning a completed restore into a
  /// failed one. isRestoring stays true so the barrier keeps the app blocked.
  Future<void> _runPostRestoreSafetyReview() async {
    _sweepSkipped = false;
    try {
      await _ref
          .read(postRestoreSafetyReviewProvider)
          .run(
            onProgress: (done, total) {
              if (!mounted || total == 0) return;
              state = BackupOperationState(
                status: BackupOperationStatus.inProgress,
                isRestoring: true,
                sweepProgress: SafetyReviewSweepProgress(
                  done: done,
                  total: total,
                ),
              );
            },
            isCancelled: () => _sweepSkipped,
          );
    } catch (e, st) {
      _log.error(
        'Post-restore safety review failed; the restore itself is unaffected',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Perform a manual backup
  Future<void> performBackup() async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: _l10n.backup_backingUp,
    );

    try {
      final record = await _service.performBackup();
      state = BackupOperationState(
        status: BackupOperationStatus.success,
        message: _l10n.backup_operation_created(record.formattedSize),
        lastRecord: record,
      );
      _ref.read(backupSettingsProvider.notifier).refresh();
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: _l10n.backup_operation_backupFailed('$e'),
      );
    }
  }

  /// Restore from a specific backup record
  Future<void> restoreFromBackup(
    BackupRecord record, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
  }) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: _l10n.backup_operation_restoring,
      isRestoring: true,
    );

    try {
      await _service.restoreFromBackup(
        record,
        mode: mode,
        encryptionSecret: encryptionSecret,
        onMigrationProgress: _onRestoreMigrationProgress,
      );
      await _syncActiveDiverAfterRestore();
      await _runPostRestoreSafetyReview();
      state = const BackupOperationState(
        status: BackupOperationStatus.restoreComplete,
      );
      _ref.invalidate(backupHistoryProvider);
    } on BackupEncryptedException {
      // The page prompts for the passphrase and retries with the secret.
      state = const BackupOperationState(status: BackupOperationStatus.idle);
      rethrow;
    } on WrongPassphraseException {
      // A wrong secret during the retry must reach the passphrase dialog so it
      // can keep itself open and show the inline error; the generic catch below
      // would swallow it into an error state and close the dialog on success.
      state = const BackupOperationState(status: BackupOperationStatus.idle);
      rethrow;
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: _l10n.backup_operation_restoreFailed('$e'),
      );
    }
  }

  /// Delete a specific backup
  Future<void> deleteBackup(BackupRecord record) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: _l10n.backup_operation_deleting,
    );

    try {
      await _service.deleteBackup(record);
      state = BackupOperationState(
        status: BackupOperationStatus.success,
        message: _l10n.backup_operation_deleted,
      );
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: _l10n.backup_operation_deleteFailed('$e'),
      );
    }
  }

  /// Export backup to a user-chosen file path
  Future<void> exportToPath(String destinationPath) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: _l10n.backup_operation_exporting,
    );

    try {
      final record = await _service.exportBackupToPath(destinationPath);
      state = BackupOperationState(
        status: BackupOperationStatus.success,
        message: _l10n.backup_operation_exported(record.formattedSize),
        lastRecord: record,
      );
      _ref.read(backupSettingsProvider.notifier).refresh();
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: _l10n.backup_operation_exportFailed('$e'),
      );
    }
  }

  /// Export backup to temp file for sharing
  Future<File?> exportForSharing() async {
    if (state.status == BackupOperationStatus.inProgress) return null;

    state = BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: _l10n.backup_operation_preparingShare,
    );

    try {
      final file = await _service.exportBackupToTemp();
      state = BackupOperationState(
        status: BackupOperationStatus.success,
        message: _l10n.backup_operation_shareReady,
      );
      return file;
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: _l10n.backup_operation_exportFailed('$e'),
      );
      return null;
    }
  }

  /// Export a backup into an Android SAF tree, streaming it in.
  ///
  /// The Android counterpart to [exportToPath]. Scoped storage gives no
  /// writable filesystem path for a user-chosen folder, and file_picker 12's
  /// `saveFile` requires the whole artifact in memory as bytes, which a large
  /// dive library cannot afford. So the artifact is built in temp (encrypted
  /// when backup encryption is on, exactly as every other export path does)
  /// and then streamed into the tree by the same platform channel the
  /// scheduled backup uses.
  Future<void> exportToSafTree({
    required String treeUri,
    required String fileName,
  }) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Exporting backup...',
    );

    File? temp;
    try {
      temp = await _service.exportBackupToTemp();
      await SubmersionSaf.writeBackup(
        treeUri: treeUri,
        fileName: fileName,
        sourcePath: temp.path,
      );
      state = const BackupOperationState(
        status: BackupOperationStatus.success,
        message: 'Backup exported',
      );
      _ref.read(backupSettingsProvider.notifier).refresh();
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Export failed: $e',
      );
    } finally {
      // The temp artifact is a full copy of the library, and when encryption
      // is off it is plaintext. Never leave it behind.
      if (temp != null && await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {
          // best-effort temp cleanup
        }
      }
    }
  }

  /// Restore from an arbitrary file path
  Future<void> restoreFromFilePath(
    String filePath, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
  }) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: _l10n.backup_import_validating,
      isRestoring: true,
    );

    try {
      // Validate first
      final validation = await _service.validateBackupFile(filePath);
      if (!validation.isValid) {
        state = BackupOperationState(
          status: BackupOperationStatus.error,
          message: validation.error ?? _l10n.backup_import_invalidFile,
        );
        return;
      }

      state = BackupOperationState(
        status: BackupOperationStatus.inProgress,
        message: _l10n.backup_operation_restoring,
        isRestoring: true,
      );

      await _service.restoreFromFile(
        filePath,
        mode: mode,
        encryptionSecret: encryptionSecret,
        onMigrationProgress: _onRestoreMigrationProgress,
      );
      await _syncActiveDiverAfterRestore();
      await _runPostRestoreSafetyReview();
      state = const BackupOperationState(
        status: BackupOperationStatus.restoreComplete,
      );
      _ref.invalidate(backupHistoryProvider);
    } on BackupEncryptedException {
      // The page prompts for the passphrase and retries with the secret.
      state = const BackupOperationState(status: BackupOperationStatus.idle);
      rethrow;
    } on WrongPassphraseException {
      // A wrong secret during the retry must reach the passphrase dialog so it
      // can keep itself open and show the inline error; the generic catch below
      // would swallow it into an error state and close the dialog on success.
      state = const BackupOperationState(status: BackupOperationStatus.idle);
      rethrow;
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: _l10n.backup_operation_restoreFailed('$e'),
      );
    }
  }

  /// Surface migration-ladder progress while a restored older-schema backup
  /// upgrades to the current schema — the only long phase of the swap, and
  /// otherwise a silent stall behind the restore barrier.
  void _onRestoreMigrationProgress(int currentStep, int totalSteps) {
    state = BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: _l10n.backup_operation_upgrading(currentStep, totalSteps),
      isRestoring: true,
    );
  }

  /// Reset status back to idle
  void resetStatus() {
    state = const BackupOperationState();
  }

  /// On desktop (no WorkManager), periodically check if backup is due
  void _startDesktopTimerIfNeeded() {
    if (Platform.isIOS || Platform.isAndroid) return;

    _desktopBackupTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _checkDesktopBackup(),
    );
  }

  Future<void> _checkDesktopBackup() async {
    final settings = _ref.read(backupSettingsProvider);
    if (!settings.enabled || !settings.isBackupDue) return;
    if (state.status == BackupOperationStatus.inProgress) return;

    try {
      await _service.performBackup(isAutomatic: true);
      _ref.read(backupSettingsProvider.notifier).refresh();
      _ref.invalidate(backupHistoryProvider);
    } catch (_) {
      // Desktop automatic backup failure is silent — no notification system
    }
  }

  @override
  void dispose() {
    _desktopBackupTimer?.cancel();
    super.dispose();
  }
}

final backupOperationProvider =
    StateNotifierProvider<BackupOperationNotifier, BackupOperationState>((ref) {
      return BackupOperationNotifier(ref);
    });

// =============================================================================
// History
// =============================================================================

/// Backup history sorted newest-first
final backupHistoryProvider = FutureProvider<List<BackupRecord>>((ref) async {
  final service = ref.watch(backupServiceProvider);
  return service.getValidatedBackupHistory();
});

// =============================================================================
// Convenience Providers
// =============================================================================

/// Last backup time for display on the settings page
final lastBackupTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(backupSettingsProvider).lastBackupTime;
});

/// Whether a backup operation is currently running
final isBackupInProgressProvider = Provider<bool>((ref) {
  return ref.watch(backupOperationProvider).status ==
      BackupOperationStatus.inProgress;
});
