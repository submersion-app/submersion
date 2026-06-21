import 'dart:async';
import 'dart:io';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

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

/// State for backup/restore operations
class BackupOperationState {
  final BackupOperationStatus status;
  final String? message;
  final BackupRecord? lastRecord;

  const BackupOperationState({
    this.status = BackupOperationStatus.idle,
    this.message,
    this.lastRecord,
  });

  BackupOperationState copyWith({
    BackupOperationStatus? status,
    String? message,
    BackupRecord? lastRecord,
  }) {
    return BackupOperationState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastRecord: lastRecord ?? this.lastRecord,
    );
  }
}

/// Notifier managing backup/restore/delete operations with state transitions
class BackupOperationNotifier extends StateNotifier<BackupOperationState> {
  final Ref _ref;
  Timer? _desktopBackupTimer;

  BackupOperationNotifier(this._ref) : super(const BackupOperationState()) {
    _startDesktopTimerIfNeeded();
  }

  BackupService get _service => _ref.read(backupServiceProvider);

  /// After a restore, realign the active diver from the restored database's
  /// Settings table (shared with the sync library adoption flow).
  Future<void> _syncActiveDiverAfterRestore() async {
    await realignActiveDiverAfterDataReplace(
      _ref.read(sharedPreferencesProvider),
    );
  }

  /// Perform a manual backup
  Future<void> performBackup() async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Creating backup...',
    );

    try {
      final record = await _service.performBackup();
      state = BackupOperationState(
        status: BackupOperationStatus.success,
        message: 'Backup created: ${record.formattedSize}',
        lastRecord: record,
      );
      _ref.read(backupSettingsProvider.notifier).refresh();
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Backup failed: $e',
      );
    }
  }

  /// Restore from a specific backup record
  Future<void> restoreFromBackup(
    BackupRecord record, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Restoring backup...',
    );

    try {
      await _service.restoreFromBackup(record, mode: mode);
      await _syncActiveDiverAfterRestore();
      state = const BackupOperationState(
        status: BackupOperationStatus.restoreComplete,
      );
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Restore failed: $e',
      );
    }
  }

  /// Delete a specific backup
  Future<void> deleteBackup(BackupRecord record) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Deleting backup...',
    );

    try {
      await _service.deleteBackup(record);
      state = const BackupOperationState(
        status: BackupOperationStatus.success,
        message: 'Backup deleted',
      );
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Delete failed: $e',
      );
    }
  }

  /// Export backup to a user-chosen file path
  Future<void> exportToPath(String destinationPath) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Exporting backup...',
    );

    try {
      final record = await _service.exportBackupToPath(destinationPath);
      state = BackupOperationState(
        status: BackupOperationStatus.success,
        message: 'Backup exported: ${record.formattedSize}',
        lastRecord: record,
      );
      _ref.read(backupSettingsProvider.notifier).refresh();
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Export failed: $e',
      );
    }
  }

  /// Export backup to temp file for sharing
  Future<File?> exportForSharing() async {
    if (state.status == BackupOperationStatus.inProgress) return null;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Preparing backup for sharing...',
    );

    try {
      final file = await _service.exportBackupToTemp();
      state = const BackupOperationState(
        status: BackupOperationStatus.success,
        message: 'Backup ready for sharing',
      );
      return file;
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Export failed: $e',
      );
      return null;
    }
  }

  /// Restore from an arbitrary file path
  Future<void> restoreFromFilePath(
    String filePath, {
    RestoreMode mode = RestoreMode.merge,
  }) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Validating backup file...',
    );

    try {
      // Validate first
      final validation = await _service.validateBackupFile(filePath);
      if (!validation.isValid) {
        state = BackupOperationState(
          status: BackupOperationStatus.error,
          message: validation.error ?? 'Invalid backup file',
        );
        return;
      }

      state = const BackupOperationState(
        status: BackupOperationStatus.inProgress,
        message: 'Restoring backup...',
      );

      await _service.restoreFromFile(filePath, mode: mode);
      await _syncActiveDiverAfterRestore();
      state = const BackupOperationState(
        status: BackupOperationStatus.restoreComplete,
      );
      _ref.invalidate(backupHistoryProvider);
    } catch (e) {
      state = BackupOperationState(
        status: BackupOperationStatus.error,
        message: 'Restore failed: $e',
      );
    }
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
