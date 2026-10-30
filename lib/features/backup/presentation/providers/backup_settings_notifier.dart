import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';

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

  /// Turns "count backups from all devices" on for [accountKey], or off when
  /// null (issue #3503). Re-read rather than copied: copyWith cannot clear.
  Future<void> setCrossDeviceRetentionAccount(String? accountKey) async {
    await _prefs.setCrossDeviceRetentionAccount(accountKey);
    state = _prefs.getSettings();
  }

  /// The cloud copy and a backup folder are independent (spec section 8.2):
  /// turning the copy on or off never touches the folder, and choosing a
  /// folder never touches the copy.
  Future<void> setCloudBackupEnabled(bool value) async {
    await _prefs.setCloudBackupEnabled(value);
    state = _prefs.getSettings();
  }

  /// The copy goes to [row], an account's sync-role row, and is on.
  Future<void> setCopyTo(ConnectedAccount row) async {
    await _prefs.setCopyDestination(accountId: row.id, kind: row.kind);
    await _prefs.setCloudBackupEnabled(true);
    state = _prefs.getSettings();
  }

  /// The copy goes to whichever account sync uses, and is on.
  Future<void> setCopyFollowsSync() async {
    await _prefs.setCopyDestination(accountId: null, kind: null);
    await _prefs.setCloudBackupEnabled(true);
    state = _prefs.getSettings();
  }

  /// No copy off this device: the diver's own choice, or the effect of a
  /// confirmation that named it. Turned off before the destination is
  /// cleared, so a crash between the writes never leaves the copy on and
  /// silently following sync instead of the account it was pinned to.
  Future<void> setNoCopy() async {
    await _prefs.setCloudBackupEnabled(false);
    await _prefs.setCopyDestination(accountId: null, kind: null);
    state = _prefs.getSettings();
  }

  /// Stores [row] as the destination without turning the copy on or off,
  /// so a copy that followed sync keeps going to the same place when sync
  /// stops (spec section 8.1).
  Future<void> pinCopyTo(ConnectedAccount row) async {
    await _prefs.setCopyDestination(accountId: row.id, kind: row.kind);
    state = _prefs.getSettings();
  }

  Future<void> setBackupLocation(String? path) async {
    await _prefs.setBackupLocation(path);
    state = _prefs.getSettings();
  }

  /// Back to the app's own backups folder: the folder, its bookmark and its
  /// label go together.
  Future<void> useDefaultBackupLocation() => setBackupLocation(null);

  /// Sets a custom backup location together with its security-scoped bookmark
  /// (Apple platforms). The bookmark is what lets the location survive an app
  /// restart; a null bookmark is fine on desktop, where bare paths persist.
  Future<void> setBackupLocationWithBookmark(
    String path,
    List<int>? bookmark,
  ) async {
    await _prefs.setBackupLocation(path);
    await _prefs.setBackupLocationBookmark(bookmark);
    state = _prefs.getSettings();
  }

  /// Android SAF: persist a `content://` tree URI as the location plus its human
  /// label for display.
  Future<void> setSafBackupLocation(String uri, String label) async {
    await _prefs.setBackupLocation(uri);
    await _prefs.setBackupLocationLabel(label);
    state = _prefs.getSettings();
  }

  /// Display label for a custom location (e.g. the SAF folder name), or null.
  String? get locationLabel => _prefs.backupLocationLabel;

  /// Refresh state from SharedPreferences (e.g. after a backup updates lastBackupTime)
  void refresh() {
    state = _prefs.getSettings();
  }

  /// Like [refresh], but first re-reads what the WorkManager isolate may
  /// have written since this isolate cached its preferences.
  Future<void> reloadFromDisk() async {
    await _prefs.reload();
    if (!mounted) return;
    refresh();
  }

  /// Records a failed scheduled backup for Settings > Data health.
  Future<void> recordScheduledFailure(String message) async {
    final at = DateTime.now();
    await _prefs.setLastScheduledFailure(at, message);
    if (!mounted) return;
    state = state.copyWith(
      lastScheduledFailureAt: at,
      lastScheduledFailureMessage: message,
    );
  }
}
