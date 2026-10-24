import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';

/// Persists backup settings and history to SharedPreferences.
///
/// Backup metadata is stored outside the SQLite database intentionally:
/// restoring an old backup would overwrite the current backup history
/// if it lived in the database being restored.
class BackupPreferences {
  static const String _enabledKey = 'backup_enabled';
  static const String _frequencyKey = 'backup_frequency';
  static const String _retentionCountKey = 'backup_retention_count';
  static const String _crossDeviceRetentionAccountKey =
      'backup_retention_all_devices_account';
  static const String _pinMarkersSyncedKey = 'backup_pin_markers_synced';
  static const String _lastBackupTimeKey = 'backup_last_time';
  static const String _cloudBackupEnabledKey = 'backup_cloud_enabled';
  static const String _backupLocationKey = 'backup_location';
  static const String _backupLocationBookmarkKey = 'backup_location_bookmark';
  static const String _backupLocationLabelKey = 'backup_location_label';
  static const String _historyKey = 'backup_history';
  static const String _backupEncryptionEnabledKey = 'backup_encryption_enabled';
  static const String _lastScheduledFailureAtKey =
      'backup_last_scheduled_failure_at';
  static const String _lastScheduledFailureMessageKey =
      'backup_last_scheduled_failure_message';
  static const String _lastCloudCopyMissingKey =
      'backup_last_cloud_copy_missing';
  static const String _lastBackupDestinationKey = 'backup_last_destination';
  static const String _lastBackupCloudAccountIdKey =
      'backup_last_cloud_account_id';
  static const String _copyAccountIdKey = 'backup_copy_account_id';
  static const String _copyAccountKindKey = 'backup_copy_account_kind';

  final SharedPreferences _prefs;

  BackupPreferences(this._prefs);

  // ===========================================================================
  // Settings
  // ===========================================================================

  BackupSettings getSettings() {
    final lastBackupMs = _prefs.getInt(_lastBackupTimeKey);
    final failedMs = _prefs.getInt(_lastScheduledFailureAtKey);
    // An id without a kind this build knows is no destination: the copy
    // then goes where sync goes, as it did before destinations existed.
    final copyKind = AccountKind.values
        .asNameMap()[_prefs.getString(_copyAccountKindKey)];
    final copyId = copyKind == null
        ? null
        : _prefs.getString(_copyAccountIdKey);
    return BackupSettings(
      enabled: _prefs.getBool(_enabledKey) ?? false,
      frequency: _parseFrequency(_prefs.getString(_frequencyKey)),
      retentionCount: _prefs.getInt(_retentionCountKey) ?? 10,
      lastBackupTime: lastBackupMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastBackupMs)
          : null,
      cloudBackupEnabled: _prefs.getBool(_cloudBackupEnabledKey) ?? false,
      backupLocation: _prefs.getString(_backupLocationKey),
      backupEncryptionEnabled:
          _prefs.getBool(_backupEncryptionEnabledKey) ?? false,
      lastScheduledFailureAt: failedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(failedMs)
          : null,
      lastScheduledFailureMessage: _prefs.getString(
        _lastScheduledFailureMessageKey,
      ),
      lastCloudCopyMissing: _prefs.getBool(_lastCloudCopyMissingKey) ?? false,
      lastBackupDestination: LastBackupDestination.values
          .asNameMap()[_prefs.getString(_lastBackupDestinationKey)],
      lastBackupCloudAccountId: _prefs.getString(_lastBackupCloudAccountIdKey),
      copyAccountId: copyId,
      copyAccountKind: copyId == null ? null : copyKind,
      crossDeviceRetentionAccount: _prefs.getString(
        _crossDeviceRetentionAccountKey,
      ),
    );
  }

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_enabledKey, value);
  }

  Future<void> setBackupEncryptionEnabled(bool value) async {
    await _prefs.setBool(_backupEncryptionEnabledKey, value);
  }

  Future<void> setFrequency(BackupFrequency frequency) async {
    await _prefs.setString(_frequencyKey, frequency.name);
  }

  Future<void> setRetentionCount(int count) async {
    await _prefs.setInt(_retentionCountKey, count);
  }

  /// Turns the cross-device retention switch on for the cloud folder
  /// [accountKey] names, or off when null (issue #3503).
  Future<void> setCrossDeviceRetentionAccount(String? accountKey) async {
    if (accountKey == null) {
      await _prefs.remove(_crossDeviceRetentionAccountKey);
    } else {
      await _prefs.setString(_crossDeviceRetentionAccountKey, accountKey);
    }
  }

  /// What the last successful pin-marker reconcile mirrored (issue #3503):
  /// the folder key and the pinned stems. A prune lists the cloud folder to
  /// reconcile only when this no longer matches the pins.
  String? getPinMarkersSynced() => _prefs.getString(_pinMarkersSyncedKey);

  Future<void> setPinMarkersSynced(String state) async {
    await _prefs.setString(_pinMarkersSyncedKey, state);
  }

  Future<void> setLastBackupTime(DateTime time) async {
    await _prefs.setInt(_lastBackupTimeKey, time.millisecondsSinceEpoch);
  }

  /// Re-reads values another isolate (the WorkManager backup job) wrote.
  Future<void> reload() => _prefs.reload();

  /// Records a failed scheduled backup (Settings > Data health, #3394).
  Future<void> setLastScheduledFailure(DateTime at, String message) async {
    await _prefs.setInt(_lastScheduledFailureAtKey, at.millisecondsSinceEpoch);
    await _prefs.setString(_lastScheduledFailureMessageKey, message);
  }

  /// Whether the most recent backup's requested cloud copy is missing.
  Future<void> setLastCloudCopyMissing(bool value) async {
    await _prefs.setBool(_lastCloudCopyMissingKey, value);
  }

  /// Where the most recent backup went (Settings > Data, #3482), and for a
  /// cloud copy the sync account it went to. Any other destination drops the
  /// account, so an old cloud account is never named for a local backup.
  Future<void> setLastBackupDestination(
    LastBackupDestination value, {
    String? cloudAccountId,
  }) async {
    await _prefs.setString(_lastBackupDestinationKey, value.name);
    if (value == LastBackupDestination.cloud && cloudAccountId != null) {
      await _prefs.setString(_lastBackupCloudAccountIdKey, cloudAccountId);
    } else {
      await _prefs.remove(_lastBackupCloudAccountIdKey);
    }
  }

  /// The roster row the cloud copy goes to (Settings > Data, #3482); null
  /// for both means the same account as sync. The kind is written first and
  /// removed last, so a crash between the writes never leaves an id that
  /// reads without its kind.
  Future<void> setCopyDestination({
    required String? accountId,
    required AccountKind? kind,
  }) async {
    if (accountId == null || kind == null) {
      await _prefs.remove(_copyAccountIdKey);
      await _prefs.remove(_copyAccountKindKey);
      return;
    }
    await _prefs.setString(_copyAccountKindKey, kind.name);
    await _prefs.setString(_copyAccountIdKey, accountId);
  }

  Future<void> setCloudBackupEnabled(bool value) async {
    await _prefs.setBool(_cloudBackupEnabledKey, value);
  }

  Future<void> setBackupLocation(String? path) async {
    if (path == null) {
      await _prefs.remove(_backupLocationKey);
      // The bookmark only has meaning paired with a location, so clearing the
      // location (reset to default) must drop the bookmark too -- otherwise a
      // dangling security-scoped bookmark would linger.
      await _prefs.remove(_backupLocationBookmarkKey);
      // The label is likewise meaningless without a location.
      await _prefs.remove(_backupLocationLabelKey);
    } else {
      await _prefs.setString(_backupLocationKey, path);
    }
  }

  /// Persists the security-scoped bookmark bytes for the custom backup
  /// location (Apple platforms), stored as base64. Null removes it.
  Future<void> setBackupLocationBookmark(List<int>? bytes) async {
    if (bytes == null) {
      await _prefs.remove(_backupLocationBookmarkKey);
    } else {
      await _prefs.setString(_backupLocationBookmarkKey, base64Encode(bytes));
    }
  }

  /// Reads the stored backup-location bookmark bytes, or null if none is set.
  Uint8List? getBackupLocationBookmark() {
    final encoded = _prefs.getString(_backupLocationBookmarkKey);
    if (encoded == null) return null;
    return base64Decode(encoded);
  }

  /// Human label for the custom backup location (e.g. the SAF folder's display
  /// name on Android), shown in settings instead of a raw `content://` URI.
  Future<void> setBackupLocationLabel(String? label) async {
    if (label == null) {
      await _prefs.remove(_backupLocationLabelKey);
    } else {
      await _prefs.setString(_backupLocationLabelKey, label);
    }
  }

  String? get backupLocationLabel => _prefs.getString(_backupLocationLabelKey);

  // ===========================================================================
  // History
  // ===========================================================================

  List<BackupRecord> getHistory() {
    final json = _prefs.getString(_historyKey);
    if (json == null || json.isEmpty) return [];

    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => BackupRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addRecord(BackupRecord record) async {
    final history = getHistory();
    final updated = [record, ...history];
    await _saveHistory(updated);
  }

  Future<void> removeRecord(String recordId) async {
    final history = getHistory();
    final updated = history.where((r) => r.id != recordId).toList();
    await _saveHistory(updated);
  }

  Future<void> updateRecord(BackupRecord record) async {
    final history = getHistory();
    final updated = history.map((r) => r.id == record.id ? record : r).toList();
    await _saveHistory(updated);
  }

  Future<void> setHistory(List<BackupRecord> records) async {
    await _saveHistory(records);
  }

  Future<void> _saveHistory(List<BackupRecord> records) async {
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    await _prefs.setString(_historyKey, json);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  BackupFrequency _parseFrequency(String? value) {
    if (value == null) return BackupFrequency.weekly;
    return BackupFrequency.values.asNameMap()[value] ?? BackupFrequency.weekly;
  }
}
