import 'dart:async';
import 'dart:io';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
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

  Future<void> setCloudBackupEnabled(bool value) async {
    await _prefs.setCloudBackupEnabled(value);
    state = state.copyWith(cloudBackupEnabled: value);
  }

  Future<void> setBackupLocation(String? path) async {
    await _prefs.setBackupLocation(path);
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

  /// After a restore, read the active diver ID from the restored database's
  /// Settings table and push it into SharedPreferences so the app picks up
  /// the correct diver on restart.
  Future<void> _syncActiveDiverAfterRestore() async {
    try {
      final repository = DiverRepository();
      final prefs = _ref.read(sharedPreferencesProvider);

      // Read the active diver ID that was stored in the restored DB
      var restoredId = await repository.getActiveDiverIdFromSettings();

      // Validate it actually exists in the restored divers table
      if (restoredId != null) {
        final diver = await repository.getDiverById(restoredId);
        if (diver == null) {
          restoredId = null;
        }
      }

      // Fall back to the default diver if the stored ID was invalid
      if (restoredId == null) {
        final defaultDiver = await repository.getDefaultDiver();
        restoredId = defaultDiver?.id;
      }

      // Sync to SharedPreferences so startup picks up the right diver
      if (restoredId != null) {
        await prefs.setString(currentDiverIdKey, restoredId);
      }
    } catch (_) {
      // Non-fatal: startup validation in CurrentDiverIdNotifier will handle it
    }
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
  Future<void> restoreFromBackup(BackupRecord record) async {
    if (state.status == BackupOperationStatus.inProgress) return;

    state = const BackupOperationState(
      status: BackupOperationStatus.inProgress,
      message: 'Restoring backup...',
    );

    try {
      await _service.restoreFromBackup(record);
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
  Future<void> restoreFromFilePath(String filePath) async {
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

      await _service.restoreFromFile(filePath);
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
